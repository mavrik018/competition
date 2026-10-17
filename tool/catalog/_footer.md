
---

## Intentionally not extracted

| Candidate | Source | Why |
|---|---|---|
| Keepsake icon set (1,010 lines) | CP | Brand illustration, not reusable UI |
| Video and animated splash screens | KA, TD | Brand-specific; `SessionGate.loading` covers the role |
| Drift database | TD | Requires code generation, which the other apps avoid; sqflite covers the need |
| FCM push | CP | Needs Firebase project files to even compile meaningfully |
| Shared drawing canvas, photobooth, arcade games | CP | Feature-sized and bound to Couple's realtime schema |
| Paywall + subscription notifier (600–1,400 lines) | KA, SM | Bound to each app's backend tables and webhooks; the reusable seam (#60) was extracted |
| Image/video compression | CP | Two heavy native plugins; left to the caller of #57 |
| Secure storage wrapper | CP | Thin wrapper; Supabase already persists the session |
