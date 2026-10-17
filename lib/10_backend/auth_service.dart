/// Every Supabase auth flow an app usually needs, with errors already turned
/// into [AppException]s.
///
/// Source: StudyBuddies `features/auth/data/auth_repository.dart` (native
/// Apple sign-in with a hashed nonce, OTP password reset, account deletion
/// through an Edge Function, Google OAuth launched in the external browser)
/// combined with Cookly `data/repositories/auth_repository.dart` (one
/// `_guard` that adds a timeout and maps errors, and clearing local caches
/// before sign-out). The StudyBuddies-specific `users` table writes were
/// removed: [signInWithApple] returns the name Apple provides so the app can
/// store it wherever its profiles live.
///
/// ```dart
/// final auth = AuthService(Supabase.instance.client, redirectUrl: 'com.example.app://login-callback');
/// await auth.signIn(email: email, password: password);
/// final apple = await auth.signInWithApple();
/// if (apple?.fullName != null) await profiles.saveNameIfEmpty(apple!.fullName!);
/// ```
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_exception.dart';
import 'supabase_errors.dart';

/// The result of a completed Apple sign-in.
class AppleSignInResult {
  const AppleSignInResult({required this.user, this.fullName});

  final User user;

  /// Apple sends the name **only on the first authorization** for an Apple ID
  /// and app — later sign-ins return null and there is no API to ask again.
  /// Persist it the first time it is non-null.
  final String? fullName;
}

class AuthService {
  AuthService(
    this._client, {
    this.redirectUrl,
    this.timeout = const Duration(seconds: 15),
    this.deleteAccountFunction = 'delete-account',
  });

  final SupabaseClient _client;

  /// Deep link Supabase returns to after browser-based OAuth and email
  /// confirmation, e.g. `com.example.app://login-callback`. Must also be in
  /// the dashboard's redirect allow-list and the platform manifests.
  final String? redirectUrl;
  final Duration timeout;

  /// Name of the Edge Function that deletes the caller's account using the
  /// service-role key (which must never be in the app).
  final String deleteAccountFunction;

  GoTrueClient get _auth => _client.auth;

  User? get currentUser => _auth.currentUser;
  Stream<AuthState> get changes => _auth.onAuthStateChange;

  Future<void> signUp({
    required String email,
    required String password,
    String? name,
  }) => _guard(() async {
    await _auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: redirectUrl,
      data: {
        if (name != null && name.trim().isNotEmpty) 'full_name': name.trim(),
      },
    );
  });

  Future<void> signIn({required String email, required String password}) =>
      _guard(() async {
        await _auth.signInWithPassword(email: email.trim(), password: password);
      });

  /// Opens the provider's consent page in the browser. Returns as soon as
  /// the browser opens — the session arrives later via the deep link, so
  /// watch [changes] instead of treating this as success.
  ///
  /// The external browser is forced on mobile: the default in-app Safari
  /// sheet on iOS cannot follow the custom-scheme redirect, so it stays on
  /// screen showing a blank page after sign-in has already succeeded.
  Future<void> signInWithOAuth(OAuthProvider provider) => _guard(() async {
    await _auth.signInWithOAuth(
      provider,
      redirectTo: kIsWeb ? null : redirectUrl,
      authScreenLaunchMode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
    );
  });

  /// Native Sign in with Apple. Returns null when the user closes the system
  /// sheet — that is a change of mind, not an error to show. On the web,
  /// where there is no native sheet, falls back to the OAuth flow and
  /// returns null (the session arrives through [changes]).
  ///
  /// A random nonce is generated; Apple signs its SHA-256 into the identity
  /// token and Supabase receives the raw value to compare. Without it, an
  /// intercepted token could be replayed into another session.
  Future<AppleSignInResult?> signInWithApple() async {
    if (kIsWeb) {
      await signInWithOAuth(OAuthProvider.apple);
      return null;
    }
    final rawNonce = generateNonce();
    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: sha256Hex(rawNonce),
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) return null;
      throw AppException(
        'Apple sign-in failed. Please try again.',
        kind: AppErrorKind.auth,
        cause: error,
      );
    }

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const AppException(
        'Apple did not return a sign-in token. Please try again.',
        kind: AppErrorKind.auth,
      );
    }

    return _guard(() async {
      final response = await _auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce, // the raw value: Supabase hashes it to compare
      );
      final user = response.user;
      if (user == null) return null;
      final name = [
        credential.givenName,
        credential.familyName,
      ].whereType<String>().where((part) => part.isNotEmpty).join(' ');
      return AppleSignInResult(
        user: user,
        fullName: name.isEmpty ? null : name,
      );
    });
  }

  /// Emails a one-time recovery code (the project's "Reset password" email
  /// template must show `{{ .Token }}`).
  Future<void> sendPasswordResetCode(String email) =>
      _guard(() => _auth.resetPasswordForEmail(email.trim()));

  /// Verifies the code. Success signs the user in, so the app should keep
  /// them on a "choose a new password" screen until [updatePassword].
  Future<void> verifyRecoveryCode({
    required String email,
    required String code,
  }) => _guard(() async {
    await _auth.verifyOTP(
      email: email.trim(),
      token: code.trim(),
      type: OtpType.recovery,
    );
  });

  Future<void> updatePassword(String newPassword) => _guard(() async {
    await _auth.updateUser(UserAttributes(password: newPassword));
  });

  /// Signs out. [beforeSignOut] runs first (best-effort) — clear offline
  /// caches and queues there so the next account on a shared device never
  /// sees this one's data.
  Future<void> signOut({Future<void> Function()? beforeSignOut}) =>
      _guard(() async {
        if (beforeSignOut != null) {
          try {
            await beforeSignOut();
          } catch (error) {
            debugPrint('AuthService: cleanup before sign-out failed: $error');
          }
        }
        await _auth.signOut();
      });

  /// Deletes the signed-in account through [deleteAccountFunction], then
  /// drops the local session. If the deletion request fails the user stays
  /// signed in and the error is thrown — signing out anyway (as the Couple
  /// app did) would look like success when the account still exists. Once
  /// deletion succeeds, a failing local sign-out is ignored: the token now
  /// refers to nothing.
  Future<void> deleteAccount({Future<void> Function()? beforeSignOut}) async {
    await _guard(
      () => _client.functions.invoke(
        deleteAccountFunction,
        body: const <String, dynamic>{},
      ),
    );
    try {
      if (beforeSignOut != null) await beforeSignOut();
      await _auth.signOut(scope: SignOutScope.local);
    } catch (error) {
      debugPrint('AuthService: local sign-out after deletion failed: $error');
    }
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action().timeout(timeout);
    } catch (error) {
      throw supabaseFailure(error);
    }
  }
}

/// A random string for the Apple / OIDC nonce, from a URL-safe alphabet.
String generateNonce([int length = 32, Random? random]) {
  const charset =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
  final rng = random ?? Random.secure();
  return List.generate(
    length,
    (_) => charset[rng.nextInt(charset.length)],
  ).join();
}

/// Lower-case hex SHA-256 of [input].
String sha256Hex(String input) => sha256.convert(utf8.encode(input)).toString();
