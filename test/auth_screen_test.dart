import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsepath/core/theme/pulse_path_theme.dart';
import 'package:pulsepath/features/auth/presentation/auth_screens.dart';
import 'package:pulsepath/features/auth/providers/auth_provider.dart';

void main() {
  testWidgets('sign up validates password confirmation', (tester) async {
    await _pumpAuth(tester);
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('email_field')),
      'alex@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('signup_password')),
      'password123',
    );
    await tester.enterText(
      find.byKey(const Key('confirm_password')),
      'different',
    );
    await tester.ensureVisible(find.byKey(const Key('signup_button')));
    await tester.tap(find.byKey(const Key('signup_button')));
    await tester.pump();
    expect(find.text('Passwords do not match.'), findsOneWidget);
  });

  testWidgets('login form validates email and password', (tester) async {
    await _pumpAuth(tester);
    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pump();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
  });

  testWidgets('forgot password opens generic recovery experience', (
    tester,
  ) async {
    await _pumpAuth(tester);
    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();
    expect(find.text('Find your way back.'), findsOneWidget);
    expect(find.byKey(const Key('forgot_submit_button')), findsOneWidget);
  });
}

Future<void> _pumpAuth(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(
          (ref) => AuthController.forTesting(const AuthState.unauthenticated()),
        ),
      ],
      child: MaterialApp(theme: PulsePathTheme.dark, home: const AuthFlow()),
    ),
  );
  await tester.pumpAndSettle();
}
