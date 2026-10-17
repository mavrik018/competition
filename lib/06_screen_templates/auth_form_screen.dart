import 'package:flutter/material.dart';

import '../01_design_system/app_tokens.dart';
import '../02_ui_elements/primary_button.dart';
import '../05_forms/password_checklist.dart';
import '../05_forms/validators.dart';

enum AuthMode { signIn, signUp }

/// What the user typed, handed to [AuthFormScreen.onSubmit].
class AuthFormData {
  const AuthFormData({
    required this.mode,
    required this.email,
    required this.password,
    this.name,
  });

  final AuthMode mode;
  final String email;
  final String password;

  /// Only for [AuthMode.signUp], and only when [AuthFormScreen.askForName].
  final String? name;
}

/// A complete email + password sign-in / sign-up screen: header, validated
/// fields, show/hide password, live password rules on sign-up, inline error,
/// loading state, forgot-password link, mode switch and a slot for social
/// sign-in buttons.
///
/// Source: Cookly `auth_scaffold.dart` (shared chrome so login, sign-up and
/// reset differ only in fields) combined with the StudyBuddies and Cookly
/// sign-in/sign-up screens (400+ lines each). It owns only the text fields;
/// the request, its loading flag and its error belong to the caller — pair
/// it with `ActionController` (08) and `AuthService` (10).
///
/// ```dart
/// final authAction =
///     NotifierProvider.autoDispose<ActionController, AsyncValue<void>>(ActionController.new);
///
/// final action = ref.watch(authAction);
/// AuthFormScreen(
///   mode: mode,
///   isLoading: action.isLoading,
///   errorText: action.hasError ? AppException.from(action.error!).message : null,
///   onSubmit: (data) => ref.read(authAction.notifier).run(() =>
///       data.mode == AuthMode.signIn
///           ? auth.signIn(email: data.email, password: data.password)
///           : auth.signUp(email: data.email, password: data.password, name: data.name)),
///   onSwitchMode: () => setState(() => mode = mode == AuthMode.signIn ? AuthMode.signUp : AuthMode.signIn),
///   onForgotPassword: openReset,
/// )
/// ```
class AuthFormScreen extends StatefulWidget {
  const AuthFormScreen({
    super.key,
    required this.mode,
    required this.onSubmit,
    this.onSwitchMode,
    this.onForgotPassword,
    this.isLoading = false,
    this.errorText,
    this.title,
    this.subtitle,
    this.logo,
    this.askForName = true,
    this.passwordRules,
    this.socialButtons = const [],
    this.footer,
  });

  final AuthMode mode;
  final ValueChanged<AuthFormData> onSubmit;
  final VoidCallback? onSwitchMode;
  final VoidCallback? onForgotPassword;
  final bool isLoading;

  /// A human-readable error to show above the button.
  final String? errorText;
  final String? title;
  final String? subtitle;
  final Widget? logo;
  final bool askForName;

  /// Rules shown and enforced on sign-up. Defaults to [PasswordRule.defaults].
  final List<PasswordRule>? passwordRules;

  /// e.g. "Continue with Apple" / "Continue with Google" buttons.
  final List<Widget> socialButtons;

  /// Under everything — e.g. a `ConsentCheckbox` on sign-up.
  final Widget? footer;

  @override
  State<AuthFormScreen> createState() => _AuthFormScreenState();
}

class _AuthFormScreenState extends State<AuthFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  bool get _isSignUp => widget.mode == AuthMode.signUp;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.isLoading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    widget.onSubmit(
      AuthFormData(
        mode: widget.mode,
        email: _email.text.trim(),
        password: _password.text,
        name: _isSignUp && widget.askForName ? _name.text.trim() : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rules = widget.passwordRules ?? PasswordRule.defaults;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.gutter,
              vertical: Gap.xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.logo != null) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: widget.logo,
                        ),
                        const SizedBox(height: Gap.lg),
                      ],
                      Text(
                        widget.title ??
                            (_isSignUp
                                ? 'Create your account'
                                : 'Welcome back'),
                        style: theme.textTheme.headlineLarge,
                      ),
                      const SizedBox(height: Gap.xs),
                      Text(
                        widget.subtitle ??
                            (_isSignUp
                                ? 'It only takes a minute.'
                                : 'Sign in to continue.'),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: Gap.lg),
                      if (_isSignUp && widget.askForName) ...[
                        TextFormField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          decoration: const InputDecoration(labelText: 'Name'),
                          validator: Validators.required('Enter your name'),
                        ),
                        const SizedBox(height: Gap.md - 4),
                      ],
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: Validators.compose([
                          Validators.required('Enter your email'),
                          Validators.email(),
                        ]),
                      ),
                      const SizedBox(height: Gap.md - 4),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        autofillHints: [
                          _isSignUp
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        onChanged: _isSignUp ? (_) => setState(() {}) : null,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            tooltip: _obscure
                                ? 'Show password'
                                : 'Hide password',
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter your password';
                          }
                          if (_isSignUp && !passwordMeetsAll(value, rules)) {
                            return 'Password does not meet the requirements';
                          }
                          return null;
                        },
                      ),
                      if (_isSignUp)
                        PasswordChecklist(
                          password: _password.text,
                          rules: rules,
                        )
                      else if (widget.onForgotPassword != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: widget.isLoading
                                ? null
                                : widget.onForgotPassword,
                            child: const Text('Forgot password?'),
                          ),
                        ),
                      if (widget.errorText != null) ...[
                        const SizedBox(height: Gap.md - 4),
                        Semantics(
                          liveRegion: true,
                          child: Container(
                            padding: const EdgeInsets.all(Gap.md - 4),
                            decoration: BoxDecoration(
                              color: scheme.errorContainer,
                              borderRadius: BorderRadius.circular(Radii.md),
                            ),
                            child: Text(
                              widget.errorText!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: Gap.lg - 4),
                      PrimaryButton(
                        label: _isSignUp ? 'Create account' : 'Sign in',
                        isLoading: widget.isLoading,
                        onPressed: _submit,
                      ),
                      if (widget.socialButtons.isNotEmpty) ...[
                        const SizedBox(height: Gap.lg - 4),
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Gap.md - 4,
                              ),
                              child: Text(
                                'or',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: Gap.lg - 4),
                        for (final button in widget.socialButtons) ...[
                          button,
                          const SizedBox(height: Gap.sm + 2),
                        ],
                      ],
                      if (widget.onSwitchMode != null) ...[
                        const SizedBox(height: Gap.sm),
                        TextButton(
                          onPressed: widget.isLoading
                              ? null
                              : widget.onSwitchMode,
                          child: Text(
                            _isSignUp
                                ? 'Already have an account? Sign in'
                                : "Don't have an account? Sign up",
                          ),
                        ),
                      ],
                      if (widget.footer != null) ...[
                        const SizedBox(height: Gap.md),
                        widget.footer!,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
