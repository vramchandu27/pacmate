import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:pacmate/core/constants/app_constants.dart';
import 'package:pacmate/features/auth/screens/login_screen.dart';

// ─── HELPERS ─────────────────────────────────────────────────────────────────

/// Routes captured by the test router.
final List<String> _navigatedRoutes = [];

GoRouter _makeRouter() {
  _navigatedRoutes.clear();
  return GoRouter(
    initialLocation: AppRoutes.login,
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (_, _) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (_, _) => const Scaffold(body: Text('SignupScreen')),
      ),
    ],
  );
}

Widget _buildTestApp() {
  return ProviderScope(
    child: MaterialApp.router(
      routerConfig: _makeRouter(),
    ),
  );
}

// ─── TESTS ────────────────────────────────────────────────────────────────────

void main() {
  group('LoginScreen — signup link', () {
    testWidgets('renders "Don\'t have an account?" and "Sign up" text',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.dontHaveAccount), findsOneWidget);
      expect(find.text(AppStrings.signupLink), findsOneWidget);
    });

    testWidgets('tapping "Sign up" text navigates to signup screen',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.signupLink));
      await tester.pumpAndSettle();

      // After navigation, the signup stub screen should be visible.
      expect(find.text('SignupScreen'), findsOneWidget);
      expect(find.text(AppStrings.signupLink), findsNothing);
    });

    testWidgets(
        'tapping anywhere in the signup row (including non-link text) navigates',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Tap the "Don't have an account?" part — should still navigate
      // because the entire row is now wrapped in GestureDetector.
      await tester.tap(find.text(AppStrings.dontHaveAccount));
      await tester.pumpAndSettle();

      expect(find.text('SignupScreen'), findsOneWidget);
    });

    testWidgets('signup row has a minimum vertical touch target of 44px',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final signupFinder = find.text(AppStrings.signupLink);
      final rect = tester.getRect(signupFinder);

      // The GestureDetector wraps the row with vertical padding:10 on each side.
      // The rendered row height should be at least 44px.
      expect(rect.height, greaterThanOrEqualTo(44.0),
          reason: 'Touch target must be at least 44px tall');
    });
  });

  group('LoginScreen — form fields', () {
    testWidgets('shows email and password fields', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('empty submit shows validation errors', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Tap the login button without filling anything
      await tester.tap(find.text('Start Adventure'));
      await tester.pump();

      expect(find.text(AppStrings.fieldRequired), findsWidgets);
    });

    testWidgets('invalid email shows email validation error', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextFormField).first, 'not-an-email');
      await tester.tap(find.text('Start Adventure'));
      await tester.pump();

      expect(find.text(AppStrings.emailInvalid), findsOneWidget);
    });

    testWidgets('password shorter than 8 chars shows length error',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextFormField).first, 'valid@email.com');
      await tester.enterText(
          find.byType(TextFormField).last, 'short');
      await tester.tap(find.text('Start Adventure'));
      await tester.pump();

      expect(find.text(AppStrings.passwordTooShort), findsOneWidget);
    });

    testWidgets('password visibility toggle changes obscure state',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // EditableText (the inner widget) exposes obscureText
      EditableText passwordEditable() => tester.widget<EditableText>(
            find.byType(EditableText).last,
          );

      // Initially obscured
      expect(passwordEditable().obscureText, isTrue);

      // Tap the visibility icon
      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();

      expect(passwordEditable().obscureText, isFalse);
    });
  });

  group('LoginScreen — forgot password link', () {
    testWidgets('renders forgot password link', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.forgotPassword), findsOneWidget);
    });
  });
}
