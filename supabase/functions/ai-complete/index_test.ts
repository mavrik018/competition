// Run: deno test supabase/functions/ai-complete/
// Uses a fake fetch — no network, no real Gemini or Supabase calls.

import { type Deps, handle } from "./index.ts";

function assertEquals(actual: unknown, expected: unknown, label = "") {
  const a = JSON.stringify(actual);
  const e = JSON.stringify(expected);
  if (a !== e) throw new Error(`${label} expected ${e}, got ${a}`);
}

interface Recorded {
  url: string;
  body?: Record<string, unknown>;
}

function deps(
  gemini: () => Response | Promise<Response>,
  options: { signedIn?: boolean; env?: Record<string, string | undefined> } = {},
): Deps & { calls: Recorded[] } {
  const calls: Recorded[] = [];
  const env: Record<string, string | undefined> = {
    SUPABASE_URL: "https://project.supabase.co",
    SUPABASE_ANON_KEY: "anon",
    GEMINI_API_KEY: "secret",
    ...options.env,
  };
  return {
    calls,
    env: (name) => env[name],
    fetch: (async (input: string | URL | Request, init?: RequestInit) => {
      const url = String(input);
      calls.push({
        url,
        body: init?.body ? JSON.parse(String(init.body)) : undefined,
      });
      if (url.endsWith("/auth/v1/user")) {
        return options.signedIn === false
          ? new Response("{}", { status: 401 })
          : Response.json({ id: "user-1" });
      }
      return gemini();
    }) as typeof fetch,
  };
}

function request(body: unknown, token: string | null = "jwt"): Request {
  return new Request("http://localhost/ai-complete", {
    method: "POST",
    headers: token ? { Authorization: `Bearer ${token}` } : {},
    body: JSON.stringify(body),
  });
}

const geminiText = (text: string) =>
  Response.json({ candidates: [{ content: { parts: [{ text }] } }] });

Deno.test("returns the model text in the envelope", async () => {
  const d = deps(() => geminiText(" Hello there "));
  const res = await handle(
    request({ prompt: "Hi", system: "Be brief", maxTokens: 5000, json: true }),
    d,
  );
  assertEquals(res.status, 200);
  assertEquals(await res.json(), { ok: true, data: { text: "Hello there" } });
  const sent = d.calls[1].body!;
  assertEquals(sent.generationConfig, {
    maxOutputTokens: 1024,
    responseMimeType: "application/json",
  }, "capped tokens + json");
  assertEquals(sent.systemInstruction, { parts: [{ text: "Be brief" }] });
  assertEquals(
    d.calls[1].url.endsWith("gemini-flash-lite-latest:generateContent"),
    true,
  );
});

Deno.test("rejects missing or invalid sign-in", async () => {
  const noToken = await handle(request({ prompt: "Hi" }, null), deps(() => geminiText("x")));
  assertEquals(noToken.status, 401);
  const badToken = await handle(
    request({ prompt: "Hi" }),
    deps(() => geminiText("x"), { signedIn: false }),
  );
  assertEquals((await badToken.json()).error.code, "unauthorized");
});

Deno.test("validates the body before calling the model", async () => {
  const d = deps(() => geminiText("x"));
  const res = await handle(request({ prompt: "" }), d);
  assertEquals(res.status, 400);
  assertEquals((await res.json()).error.code, "invalid_request");
  assertEquals(d.calls.length, 1, "only the auth call");
  const tooLong = await handle(request({ prompt: "x".repeat(12_001) }), d);
  assertEquals(tooLong.status, 400);
});

Deno.test("maps provider failures to stable codes", async () => {
  const cases: Array<[() => Response, number, string, boolean]> = [
    [() => new Response("slow down", { status: 429 }), 429, "rate_limited", true],
    [() => new Response("boom", { status: 500 }), 502, "provider_error", true],
    [
      () => Response.json({ promptFeedback: { blockReason: "SAFETY" } }),
      422,
      "content_blocked",
      false,
    ],
    [() => Response.json({ candidates: [] }), 502, "provider_error", true],
  ];
  for (const [gemini, status, code, retryable] of cases) {
    const res = await handle(request({ prompt: "Hi" }), deps(gemini));
    assertEquals(res.status, status, code);
    const body = await res.json();
    assertEquals([body.ok, body.error.code, body.error.retryable], [
      false,
      code,
      retryable,
    ]);
  }
});

Deno.test("missing secret is a configuration error, not a crash", async () => {
  const res = await handle(
    request({ prompt: "Hi" }),
    deps(() => geminiText("x"), { env: { GEMINI_API_KEY: undefined } }),
  );
  assertEquals(res.status, 500);
  assertEquals((await res.json()).error.code, "not_configured");
});

Deno.test("CORS preflight", async () => {
  const res = await handle(
    new Request("http://localhost/ai-complete", { method: "OPTIONS" }),
    deps(() => geminiText("x")),
  );
  assertEquals(res.status, 200);
  assertEquals(res.headers.get("Access-Control-Allow-Origin"), "*");
});
