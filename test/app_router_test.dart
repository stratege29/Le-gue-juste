import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:leguejuste/features/auth/presentation/providers/auth_provider.dart';
import 'package:leguejuste/routing/app_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'routerProvider returns the SAME GoRouter instance across '
      'auth/profile/splash changes (no recreation, no /splash bounce)',
      () async {
    final authController = StreamController<User?>.broadcast();

    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => authController.stream),
        currentUserProvider.overrideWith((ref) async => null),
        splashMinTimeProvider.overrideWith((ref) async => true),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(authController.close);

    final router1 = container.read(routerProvider);

    // Drive every provider the old implementation used to ref.watch —
    // each of these used to build a brand-new GoRouter starting at /splash.
    authController.add(null);
    await container.read(splashMinTimeProvider.future);
    container.invalidate(currentUserProvider);
    // Let stream events and rebuilds settle.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final router2 = container.read(routerProvider);

    expect(
      identical(router1, router2),
      isTrue,
      reason: 'GoRouter must be created once; auth/profile/splash changes '
          'must flow through refreshListenable, not provider rebuilds',
    );
  });
}
