import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_assets.dart';
import '../../presentation/controllers/auth_controller.dart';
import '../widgets/auth_error_message.dart';
import '../widgets/google_sign_in_button.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.status == AuthenticationStatus.loading;
    final error = authState.errorMessage;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.asset(
                  AppAssets.logo,
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Job Application Tracker',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Track and manage your job applications\nin one place.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(flex: 2),
              if (error != null && error.isNotEmpty) ...[
                AuthErrorMessage(message: error),
                const SizedBox(height: 16),
              ],
              GoogleSignInButton(
                isLoading: isLoading,
                onPressed: () {
                  ref.read(authControllerProvider.notifier).signInWithGoogle();
                },
              ),
              const SizedBox(height: 32),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
