# 14 · AI (language model) — with rule-based fallbacks

The only folder that calls an actual AI model. Everything in `13_smart_features` is rule-based or statistical; this folder adds a language model where it genuinely helps, and **every feature keeps a rule-based fallback**, so the app still works when the model is offline, slow, over quota or replies with nonsense.

| File | Contents |
|---|---|
| `ai_text_client.dart` | `AiRequest`, `AiTextClient` interface, `EdgeFunctionAiClient` (calls your Supabase Edge Function), `FakeAiTextClient` (test/demo double), `aiTextClientProvider` |
| `ai_assistant.dart` | `AiAssistant` (`summarize`, `classify`, `extractFields`, `rephrase`), `AiResult` / `AiSource`, rule-based helpers `extractiveSummary`, `keywordClassify`, `matchLabel`, `numbersIn` |
| `../../supabase/functions/ai-complete/index.ts` | the server half: verifies the user, validates input, calls Gemini with a server-held key, returns the standard envelope |

## Architecture — why a server function

```
Flutter app ──(user JWT)──▶ Edge Function ai-complete ──(GEMINI_API_KEY)──▶ Gemini
           ◀── {ok, data:{text}} | {ok:false, error:{code,message,retryable}} ──
```
**Never put a model API key in the app** — it can be extracted from any APK/IPA in minutes and billed to you. The key lives in the function's secrets; the app only proves who the user is. The client side reuses `EdgeFunctionClient` (10), so errors arrive as `EdgeFunctionFailure` with stable codes (`unauthorized`, `invalid_request`, `rate_limited`, `content_blocked`, `provider_error`, `provider_timeout`, `not_configured`, `transport`).

The function is **provider-agnostic from the app's point of view**: swap Gemini for Claude, OpenAI or Groq inside `callGemini` and nothing in Flutter changes (the source apps used the same pattern with fallbacks between providers).

## Features

| Method | AI part | Validation of the reply | Rule-based fallback |
|---|---|---|---|
| `summarize(text, maxSentences)` | abstractive summary | non-empty and shorter than the input | `extractiveSummary` — the most central sentences, quoted verbatim |
| `classify(text, labels, fallbackLabel)` | picks one of *your* labels | must match exactly one label (`matchLabel` tolerates quotes, "Label: x", trailing dots) | `keywordClassify` (keywords per label), then `fallbackLabel` |
| `extractFields(text, fields)` | JSON with *your* keys | must parse as a JSON object; unknown keys dropped, missing keys null; code fences stripped | none — returns `{}` and the error (show a form) |
| `rephrase(fact, tone)` | friendlier wording of a rule-based sentence | **every number in the original must appear in the reply** (catches invented or changed data) | the original sentence |

```dart
final ai = AiAssistant(ref.read(aiTextClientProvider), enabled: settings.aiEnabled);
final summary = await ai.summarize(note.body);
Text(summary.value);
if (!summary.usedFallback) const Chip(label: Text('✨ AI'));      // label AI output honestly
```

**Prompt injection.** User text is wrapped in `<<<` `>>>` and the system prompt says to treat it as data; outputs are checked against allowed values. That limits, but cannot fully prevent, a crafted input steering the model. **Never let model output trigger an action** (payment, delete, message) without the user confirming.

## Setup (real AI)
1. Get a Gemini API key from Google AI Studio.
2. `supabase secrets set GEMINI_API_KEY=…` (optionally `GEMINI_MODEL`, default `gemini-flash-lite-latest`).
3. `supabase functions deploy ai-complete` (JWT verification stays on).
4. In `main()`: `aiTextClientProvider.overrideWithValue(EdgeFunctionAiClient(EdgeFunctionClient.supabase(Supabase.instance.client)))`.
5. For demos without a backend: `FakeAiTextClient((req) => '…')` — **scripted, not a real model**; say so if you show it to judges.

**Before a real launch, add** per-user daily caps (count rows in an `ai_usage` table before calling the model) and moderation for user-generated prompts. Neither is included.

## Integration difficulty
★★ — one Supabase project, one secret, one deploy. Cost: Gemini Flash-Lite is cheap but not free beyond the free tier; caps protect you from abuse.

## Limitations & failure cases
* Latency of 1–5 s per call — show a spinner (`AppButton.isLoading`) and never block navigation.
* Models can be confidently wrong; validation catches format errors and changed numbers, not every factual error. Keep AI text clearly labelled.
* `extractiveSummary` is crude (word-frequency scoring, English stop-words) — it only ever quotes the text, which is its honesty guarantee.
* The Edge Function has no streaming; long outputs (> 1024 tokens) are capped.

## Tests
* `test/14_ai/ai_test.dart` — 12 Dart tests with `FakeAiTextClient` and a fake `EdgeFunctionClient` invoker: request body, envelope errors, each feature's success path, invalid replies, failures, disabled AI, and the rule-based helpers.
* `supabase/functions/ai-complete/index_test.ts` — 6 Deno tests with a fake `fetch` (no network): success envelope and request shape (token cap, JSON mode, system prompt, model), missing/invalid sign-in, input validation before any model call, provider errors → codes (429, 5xx, safety block, empty reply), missing secret, CORS. Run: `deno test supabase/functions/ai-complete/`.
* 🔶 Not tested: a live call to Gemini and a deployed function (needs a project and key).
