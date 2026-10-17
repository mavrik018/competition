/// One small interface for "send a prompt, get text back", with a real
/// implementation that calls **your own Supabase Edge Function** (which
/// holds the model API key) and a fake for tests, demos and offline judging.
///
/// **This is the actual-AI layer.** Everything in `13_smart_features` is
/// rule-based or statistical and works offline; this folder is for the
/// few places where a language model genuinely adds something (free-text
/// summaries, classification of messy input, friendlier wording). Always
/// pair it with a rule-based fallback — see `ai_assistant.dart`.
///
/// **Never put a model API key in the Flutter app.** Anyone can extract it
/// from the APK/IPA. The key lives in the Edge Function's secrets; the app
/// only sends the user's JWT. A sample function is in
/// `supabase/functions/ai-complete/index.ts`.
///
/// ```dart
/// // main.dart
/// ProviderScope(overrides: [
///   aiTextClientProvider.overrideWithValue(
///     EdgeFunctionAiClient(EdgeFunctionClient.supabase(Supabase.instance.client)),
///   ),
/// ], child: const App());
///
/// // Tests / demo mode
/// aiTextClientProvider.overrideWithValue(FakeAiTextClient((req) => 'A short summary.'));
/// ```
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../10_backend/edge_function_client.dart';

/// What to ask the model.
@immutable
class AiRequest {
  const AiRequest({
    required this.prompt,
    this.system,
    this.maxTokens = 512,
    this.json = false,
  });

  /// The user-turn text. Put untrusted user content here, between clear
  /// delimiters, never in [system].
  final String prompt;

  /// Instructions: role, rules, output format.
  final String? system;
  final int maxTokens;

  /// Ask for a JSON object as the whole reply.
  final bool json;

  Map<String, dynamic> toJson() => {
    'prompt': prompt,
    if (system != null) 'system': system,
    'maxTokens': maxTokens,
    if (json) 'json': true,
  };
}

abstract interface class AiTextClient {
  /// The model's reply. Throws [EdgeFunctionFailure] on any failure (no
  /// network, limit reached, provider down, blocked content).
  Future<String> complete(AiRequest request);
}

/// Calls the `ai-complete` Edge Function (or [functionName]), which returns
/// `{ok: true, data: {text: "..."}}`.
class EdgeFunctionAiClient implements AiTextClient {
  EdgeFunctionAiClient(this._functions, {this.functionName = 'ai-complete'});

  final EdgeFunctionClient _functions;
  final String functionName;

  @override
  Future<String> complete(AiRequest request) => _functions.call(
    functionName,
    body: request.toJson(),
    parse: (data) => data['text']! as String,
  );
}

/// A test/demo double that answers with [respond] and records every
/// request. **Not production functionality** — no model is called; the
/// replies are whatever you script.
class FakeAiTextClient implements AiTextClient {
  FakeAiTextClient(this.respond);

  /// Always fails with [failure] — for testing fallbacks.
  factory FakeAiTextClient.failing([
    EdgeFunctionFailure failure = const EdgeFunctionFailure(
      code: 'provider_error',
      message: 'The AI service is unavailable.',
      retryable: true,
    ),
  ]) => FakeAiTextClient((_) => throw failure);

  final FutureOr<String> Function(AiRequest request) respond;
  final List<AiRequest> requests = [];

  @override
  Future<String> complete(AiRequest request) async {
    requests.add(request);
    return respond(request);
  }
}

/// Override in `main()` with an [EdgeFunctionAiClient], or a
/// [FakeAiTextClient] in tests and demo builds.
final aiTextClientProvider = Provider<AiTextClient>(
  (ref) => throw UnimplementedError(
    'Override aiTextClientProvider in ProviderScope (see ai_text_client.dart).',
  ),
);
