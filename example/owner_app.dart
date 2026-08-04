import 'package:bookmyspace/app.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Minimal owner-dashboard entry point for local demonstrations.
///
/// Authentication and environment configuration are still provided by the
/// main application, so this example never embeds credentials or fake users.
void main() {
  runApp(
    const ProviderScope(
      child: BookMySpaceApp(initialLocation: AppRoutes.ownerDashboard),
    ),
  );
}
