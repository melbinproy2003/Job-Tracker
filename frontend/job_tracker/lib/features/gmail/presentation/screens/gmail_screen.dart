import 'package:flutter/material.dart';

import 'gmail_threads_screen.dart';

/// Entry point for the Gmail area (Phase 5).
///
/// The inbox itself lives in [GmailThreadsScreen]; this wrapper exists so the
/// router has a stable, top-level destination for `/gmail` that can grow a
/// tabbed layout (inbox / settings) later without changing the route.
class GmailScreen extends StatelessWidget {
  const GmailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GmailThreadsScreen();
  }
}
