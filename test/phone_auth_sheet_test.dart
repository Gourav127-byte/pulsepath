import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pulsepath/features/auth/presentation/phone_auth_sheet.dart';

void main() {
  testWidgets('PhoneAuthSheet renders phone input field and Send Code button', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: PhoneAuthSheet()),
        ),
      ),
    );

    expect(find.text('Phone Verification'), findsOneWidget);
    expect(find.byKey(const Key('phone_number_input')), findsOneWidget);
    expect(find.byKey(const Key('request_otp_button')), findsOneWidget);
  });
}
