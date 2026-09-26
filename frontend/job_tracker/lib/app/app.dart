import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/authentication/presentation/controllers/auth_controller.dart';
import '../features/notifications/providers/notifications_providers.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class JobTrackerApp extends ConsumerStatefulWidget {
  const JobTrackerApp({super.key});

  @override
  ConsumerState<JobTrackerApp> createState() => _JobTrackerAppState();
}

class _JobTrackerAppState extends ConsumerState<JobTrackerApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(authControllerProvider.notifier).bootstrap();

      // Start the push pipeline for the whole session: streams first (so a tap
      // that launched the app is not lost), then device registration once a
      // user is known. The local-notification tap callback reuses the same
      // router as an FCM tap, so a locally drawn notification lands the user in
      // exactly the same place.
      await ref.read(notificationBootstrapProvider.future);
      final handler = ref.read(notificationHandlerProvider);
      await ref
          .read(notificationServiceProvider)
          .initialize(onTap: handler.handleExternalPayload);
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Job Tracker',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
