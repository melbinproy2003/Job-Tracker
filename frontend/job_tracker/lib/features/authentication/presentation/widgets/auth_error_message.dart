import 'package:flutter/material.dart';

class AuthErrorMessage extends StatelessWidget {
  const AuthErrorMessage({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: scheme.onErrorContainer),
      ),
    );
  }
}
