/// "Enter the 6-digit code we sent to …" — the verification step of email
/// OTP sign-in, password reset (Cookly's recovery-code screen) and phone
/// verification, with a resend cooldown and shake-on-wrong-code.
///
/// Source: Cookly `verify_recovery_code_screen.dart` (code entry, resend)
/// rebuilt from toolkit parts: `PinCodeField`, `Shake`, `CountdownController`.
///
/// ```dart
/// OtpVerificationScreen(
///   destination: email,
///   onVerify: (code) async {
///     await auth.verifyRecoveryCode(email: email, code: code);   // throws when wrong
///     if (context.mounted) Navigator.pushReplacement(context, newPasswordRoute);
///   },
///   onResend: () => auth.sendPasswordResetCode(email),
///   errorMessage: (e) => AppException.from(e).message,
/// )
/// ```
library;

import 'package:flutter/material.dart';

import '../01_design_system/app_tokens.dart';
import '../02_ui_elements/animations.dart';
import '../02_ui_elements/text_inputs.dart';
import '../08_state_management/countdown_controller.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.destination,
    required this.onVerify,
    required this.onResend,
    this.length = 6,
    this.resendCooldown = const Duration(seconds: 60),
    this.errorMessage,
    this.title = 'Enter the code',
  });

  /// Where the code was sent, shown to the user ("a@b.com", "+44 •••• 0958").
  final String destination;

  /// Throw to signal a wrong or expired code.
  final Future<void> Function(String code) onVerify;
  final Future<void> Function() onResend;
  final int length;
  final Duration resendCooldown;

  /// Turns a thrown error into a sentence. Defaults to a generic message.
  final String Function(Object error)? errorMessage;
  final String title;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _code = TextEditingController();
  final _shake = ShakeController();
  late final _cooldown = CountdownController(duration: widget.resendCooldown)
    ..start();
  bool _verifying = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _shake.dispose();
    _cooldown.dispose();
    super.dispose();
  }

  Future<void> _verify(String code) async {
    if (_verifying) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await widget.onVerify(code);
    } catch (error) {
      if (!mounted) return;
      _shake.shake();
      _code.clear();
      setState(
        () => _error =
            widget.errorMessage?.call(error) ??
            'That code is wrong or has expired.',
      );
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    try {
      await widget.onResend();
      _cooldown
        ..reset()
        ..start();
      if (mounted) setState(() => _error = null);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error =
              widget.errorMessage?.call(error) ?? "Couldn't send a new code.",
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: Insets.page,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: theme.textTheme.headlineMedium),
              const SizedBox(height: Gap.sm),
              Text(
                'We sent a ${widget.length}-digit code to ${widget.destination}.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Gap.xl),
              Shake(
                controller: _shake,
                child: PinCodeField(
                  controller: _code,
                  length: widget.length,
                  hasError: _error != null,
                  onCompleted: _verify,
                ),
              ),
              const SizedBox(height: Gap.md),
              if (_verifying) const Center(child: CircularProgressIndicator()),
              if (_error != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: Gap.lg),
              ListenableBuilder(
                listenable: _cooldown,
                builder: (context, _) => TextButton(
                  onPressed: _cooldown.isRunning ? null : _resend,
                  child: Text(
                    _cooldown.isRunning
                        ? 'Resend code in ${_cooldown.formatted}'
                        : 'Resend code',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
