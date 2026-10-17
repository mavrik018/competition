/**
 * ai-complete — the server half of `lib/14_ai/ai_text_client.dart`.
 *
 * POST { prompt, system?, maxTokens?, json? }   (with the user's JWT)
 *  → 200 { ok: true,  data: { text } }
 *  → 4xx/5xx { ok: false, error: { code, message, retryable } }
 *
 * Why a server function: the model API key must never ship inside the app.
 * It lives in this function's secrets; the app only proves who the user is.
 *
 * Deploy:
 *   supabase secrets set GEMINI_API_KEY=...            # Google AI Studio key
 *   supabase secrets set GEMINI_MODEL=gemini-flash-lite-latest   # optional
 *   supabase functions deploy ai-complete
 *
 * SUPABASE_URL and SUPABASE_ANON_KEY are provided by Supabase automatically.
 *
 * Not included (add before a real launch): per-user usage caps / rate limits
 * (e.g. count rows in an `ai_usage` table per user per day before calling
 * the model) and content moderation beyond Gemini's own safety filter.
 *
 * Dependency-free on purpose: `handle()` takes `fetch` and env access as
 * parameters so `index_test.ts` can run it with fakes (`deno test`).
 */

export interface Deps {
  fetch: typeof fetch;
  env: (name: string) => string | undefined;
}

type ErrorCode =
  | "unauthorized"
  | "invalid_request"
  | "rate_limited"
  | "content_blocked"
  | "provider_error"
  | "provider_timeout"
  | "not_configured"
  | "internal_error";

class AiError extends Error {
  constructor(
    readonly code: ErrorCode,
    message: string,
    readonly status: number,
    readonly retryable = false,
  ) {
    super(message);
  }
}

interface AiInput {
  prompt: string;
  system?: string;
  maxTokens: number;
  json: boolean;
}

const MAX_PROMPT_CHARS = 12_000;
const MAX_SYSTEM_CHARS = 4_000;
const MAX_TOKENS_CAP = 1_024;
const TIMEOUT_MS = 30_000;

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function reply(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

export async function handle(req: Request, deps: Deps): Promise<Response> {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    if (req.method !== "POST") {
      throw new AiError("invalid_request", "Use POST.", 405);
    }
    await requireUser(req, deps);
    const input = parseInput(await req.json().catch(() => null));
    const text = await callGemini(input, deps);
    return reply({ ok: true, data: { text } }, 200);
  } catch (error) {
    const e = error instanceof AiError ? error : new AiError(
      "internal_error",
      "Something went wrong. Please try again.",
      500,
      true,
    );
    if (!(error instanceof AiError)) console.error("ai-complete", error);
    return reply(
      {
        ok: false,
        error: { code: e.code, message: e.message, retryable: e.retryable },
      },
      e.status,
    );
  }
}

/** The caller must be a signed-in user (the anon key alone is not enough). */
async function requireUser(req: Request, deps: Deps): Promise<string> {
  const header = req.headers.get("Authorization") ?? "";
  const token = header.toLowerCase().startsWith("bearer ")
    ? header.slice(7).trim()
    : "";
  const url = deps.env("SUPABASE_URL");
  const anonKey = deps.env("SUPABASE_ANON_KEY");
  if (!url || !anonKey) {
    throw new AiError("not_configured", "This AI feature isn't set up yet.", 500);
  }
  if (!token) throw new AiError("unauthorized", "Please sign in first.", 401);
  const res = await deps.fetch(`${url}/auth/v1/user`, {
    headers: { apikey: anonKey, Authorization: `Bearer ${token}` },
  });
  if (!res.ok) throw new AiError("unauthorized", "Please sign in again.", 401);
  const user = await res.json();
  if (typeof user?.id !== "string") {
    throw new AiError("unauthorized", "Please sign in again.", 401);
  }
  return user.id;
}

function parseInput(body: unknown): AiInput {
  const b = (body ?? {}) as Record<string, unknown>;
  const invalid = (message: string) =>
    new AiError("invalid_request", message, 400);
  if (typeof b.prompt !== "string" || b.prompt.trim() === "") {
    throw invalid("prompt is required.");
  }
  if (b.prompt.length > MAX_PROMPT_CHARS) throw invalid("prompt is too long.");
  if (b.system !== undefined && typeof b.system !== "string") {
    throw invalid("system must be a string.");
  }
  if (typeof b.system === "string" && b.system.length > MAX_SYSTEM_CHARS) {
    throw invalid("system is too long.");
  }
  const maxTokens = typeof b.maxTokens === "number" ? b.maxTokens : 512;
  return {
    prompt: b.prompt,
    system: b.system as string | undefined,
    maxTokens: Math.max(1, Math.min(MAX_TOKENS_CAP, Math.round(maxTokens))),
    json: b.json === true,
  };
}

async function callGemini(input: AiInput, deps: Deps): Promise<string> {
  const key = deps.env("GEMINI_API_KEY");
  if (!key) {
    throw new AiError("not_configured", "This AI feature isn't set up yet.", 500);
  }
  const model = deps.env("GEMINI_MODEL") ?? "gemini-flash-lite-latest";
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;

  let res: Response;
  try {
    res = await deps.fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": key },
      signal: AbortSignal.timeout(TIMEOUT_MS),
      body: JSON.stringify({
        contents: [{ role: "user", parts: [{ text: input.prompt }] }],
        ...(input.system
          ? { systemInstruction: { parts: [{ text: input.system }] } }
          : {}),
        generationConfig: {
          maxOutputTokens: input.maxTokens,
          ...(input.json ? { responseMimeType: "application/json" } : {}),
        },
      }),
    });
  } catch (error) {
    if (error instanceof DOMException && error.name === "TimeoutError") {
      throw new AiError("provider_timeout", "The AI took too long.", 504, true);
    }
    throw new AiError("provider_error", "The AI service is unavailable.", 502, true);
  }

  if (res.status === 429) {
    throw new AiError("rate_limited", "Too many requests. Try again soon.", 429, true);
  }
  if (!res.ok) {
    console.error("gemini", res.status, (await res.text()).slice(0, 500));
    throw new AiError("provider_error", "The AI service is unavailable.", 502, true);
  }

  const data = await res.json();
  const candidate = data?.candidates?.[0];
  if (data?.promptFeedback?.blockReason || candidate?.finishReason === "SAFETY") {
    throw new AiError("content_blocked", "That request can't be answered.", 422);
  }
  const text = (candidate?.content?.parts ?? [])
    .map((p: { text?: string }) => p.text ?? "")
    .join("")
    .trim();
  if (!text) {
    throw new AiError("provider_error", "The AI returned nothing. Try again.", 502, true);
  }
  return text;
}

if (import.meta.main) {
  Deno.serve((req) => handle(req, { fetch, env: (name) => Deno.env.get(name) }));
}
