import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:job_tracker/features/authentication/presentation/widgets/google_sign_in_button.dart';
import 'package:job_tracker/features/authentication/presentation/widgets/auth_error_message.dart';

void main() {
  testWidgets('Google sign-in button shows CTA', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GoogleSignInButton(onPressed: () {})),
      ),
    );
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('Auth error message renders text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AuthErrorMessage(message: 'Sign-in failed')),
      ),
    );
    expect(find.text('Sign-in failed'), findsOneWidget);
  });
}
