/// Supabase start-up and the three providers every feature needs: the
/// client, the auth event stream, and the current user.
///
/// Source: Cookly `data/supabase_client.dart` (config through
/// `--dart-define`, PKCE auth flow, a provider seam so tests can swap the
/// client, and a `currentUser` that also reads the session restored from
/// disk — the auth stream does not replay it). Changed: no project URL or
/// key is baked in as a default, and initialisation returns its error
/// instead of throwing, so the app can show a "can't connect" screen rather
/// than crash on launch.
///
/// ```dart
/// Future<void> main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   final error = await initializeSupabase();
///   runApp(ProviderScope(child: App(startupError: error)));
/// }
///
/// // flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co \
/// //             --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
/// ```
///
/// The publishable (anon) key is designed to ship in apps; row-level
/// security is what protects data. A `service_role` key must never be in the
/// client.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_exception.dart';
import 'supabase_errors.dart';

abstract final class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}

/// Initialises Supabase. Returns null on success, or a short description of
/// what went wrong. Safe to call again after a failure (Supabase only
/// re-initialises when the previous attempt did not complete). Also registers
/// the Supabase error wording with `AppException.from`.
Future<String?> initializeSupabase({
  String url = SupabaseConfig.url,
  String publishableKey = SupabaseConfig.publishableKey,
}) async {
  if (url.isEmpty || publishableKey.isEmpty) {
    return 'Supabase is not configured. Pass SUPABASE_URL and '
        'SUPABASE_PUBLISHABLE_KEY with --dart-define.';
  }
  AppException.registerTranslator(translateSupabaseError);
  try {
    await Supabase.initialize(
      url: url,
      publishableKey: publishableKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    return null;
  } catch (error) {
    debugPrint('initializeSupabase failed: $error');
    return "Couldn't start the connection to the server.";
  }
}

/// The shared client. A provider (not the global singleton) so tests can
/// override it.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

/// Sign-in, sign-out and token-refresh events.
final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(supabaseClientProvider).auth.onAuthStateChange,
);

/// The signed-in user, or null. Re-evaluates on every auth event but reads
/// the client's current user, which includes a session restored at launch.
final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(supabaseClientProvider).auth.currentUser;
});

/// The signed-in user's id on every auth change, for `SessionSource`
/// (07_navigation) and `UserProviderScope`.
Stream<String?> userIdChanges(SupabaseClient client) =>
    client.auth.onAuthStateChange.map((event) => event.session?.user.id);
