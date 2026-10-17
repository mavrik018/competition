import 'package:competition_toolkit/01_design_system/app_palette.dart';
import 'package:competition_toolkit/01_design_system/app_theme.dart';
import 'package:competition_toolkit/05_forms/password_checklist.dart';
import 'package:competition_toolkit/06_screen_templates/auth_form_screen.dart';
import 'package:competition_toolkit/06_screen_templates/onboarding_pager.dart';
import 'package:competition_toolkit/06_screen_templates/responsive_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget home) => MaterialApp(
  theme: AppTheme.build(AppPalette.studyBlue, Brightness.light),
  home: home,
);

void main() {
  group('OnboardingPager', () {
    const slides = [
      OnboardingSlide(icon: Icons.bolt, title: 'Fast', body: 'One'),
      OnboardingSlide(icon: Icons.cloud, title: 'Synced', body: 'Two'),
    ];

    testWidgets('Next walks the slides and Get started finishes', (
      tester,
    ) async {
      var finished = 0;
      await tester.pumpWidget(
        _app(OnboardingPager(slides: slides, onFinish: () => finished++)),
      );
      expect(find.text('Fast'), findsOneWidget);
      expect(find.bySemanticsLabel('Page 1 of 2'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Synced'), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);
      await tester.tap(find.text('Get started'));
      expect(finished, 1);
    });

    testWidgets('Skip finishes immediately', (tester) async {
      var finished = 0;
      await tester.pumpWidget(
        _app(OnboardingPager(slides: slides, onFinish: () => finished++)),
      );
      await tester.tap(find.text('Skip'));
      expect(finished, 1);
    });
  });

  group('AuthFormScreen', () {
    testWidgets('validates before submitting', (tester) async {
      AuthFormData? submitted;
      await tester.pumpWidget(
        _app(
          AuthFormScreen(mode: AuthMode.signIn, onSubmit: (d) => submitted = d),
        ),
      );
      await tester.tap(find.text('Sign in'));
      await tester.pump();
      expect(find.text('Enter your email'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);
      expect(submitted, isNull);
    });

    testWidgets('sign-in submits trimmed email', (tester) async {
      AuthFormData? submitted;
      var forgot = 0;
      await tester.pumpWidget(
        _app(
          AuthFormScreen(
            mode: AuthMode.signIn,
            onSubmit: (d) => submitted = d,
            onForgotPassword: () => forgot++,
          ),
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        ' me@x.io ',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'pw',
      );
      await tester.tap(find.text('Sign in'));
      expect(submitted!.email, 'me@x.io');
      expect(submitted!.password, 'pw');
      expect(submitted!.name, isNull);
      await tester.tap(find.text('Forgot password?'));
      expect(forgot, 1);
    });

    testWidgets('sign-up enforces password rules and asks for a name', (
      tester,
    ) async {
      AuthFormData? submitted;
      await tester.pumpWidget(
        _app(
          AuthFormScreen(mode: AuthMode.signUp, onSubmit: (d) => submitted = d),
        ),
      );
      expect(find.byType(PasswordChecklist), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Sam');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'sam@x.io',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'weak',
      );
      await tester.ensureVisible(find.text('Create account'));
      await tester.tap(find.text('Create account'));
      await tester.pump();
      expect(
        find.text('Password does not meet the requirements'),
        findsOneWidget,
      );
      expect(submitted, isNull);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'Strong123',
      );
      await tester.ensureVisible(find.text('Create account'));
      await tester.tap(find.text('Create account'));
      expect(submitted!.mode, AuthMode.signUp);
      expect(submitted!.name, 'Sam');
    });

    testWidgets('shows the error and blocks submit while loading', (
      tester,
    ) async {
      var submits = 0;
      await tester.pumpWidget(
        _app(
          AuthFormScreen(
            mode: AuthMode.signIn,
            isLoading: true,
            errorText: "That email and password don't match.",
            onSubmit: (_) => submits++,
          ),
        ),
      );
      expect(find.text("That email and password don't match."), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'a@b.co',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'x',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(submits, 0);
    });

    testWidgets('shows social buttons and the mode switch', (tester) async {
      var switched = 0;
      await tester.pumpWidget(
        _app(
          AuthFormScreen(
            mode: AuthMode.signIn,
            onSubmit: (_) {},
            onSwitchMode: () => switched++,
            socialButtons: [
              OutlinedButton(
                onPressed: () {},
                child: const Text('Continue with Apple'),
              ),
            ],
          ),
        ),
      );
      expect(find.text('or'), findsOneWidget);
      expect(find.text('Continue with Apple'), findsOneWidget);
      await tester.ensureVisible(find.text("Don't have an account? Sign up"));
      await tester.tap(find.text("Don't have an account? Sign up"));
      expect(switched, 1);
    });
  });

  group('Responsive', () {
    test('adaptiveColumnCount', () {
      expect(adaptiveColumnCount(360), 2);
      expect(adaptiveColumnCount(600), 3);
      expect(adaptiveColumnCount(1200), 4);
      expect(adaptiveColumnCount(0), 2);
      expect(adaptiveColumnCount(1200, max: 6), 6);
    });

    testWidgets('MaxWidthFrame caps width and keeps child height', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          const Scaffold(
            bottomNavigationBar: MaxWidthFrame(
              maxWidth: 500,
              child: SizedBox(height: 64, child: Placeholder()),
            ),
          ),
        ),
      );
      final size = tester.getSize(find.byType(Placeholder));
      expect(size.width, 500);
      expect(size.height, 64);
    });

    testWidgets('isTablet uses the shortest side', (tester) async {
      tester.view.physicalSize = const Size(900, 500); // landscape phone
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      late bool tablet;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) {
              tablet = context.isTablet;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(tablet, isFalse);
    });
  });
}
