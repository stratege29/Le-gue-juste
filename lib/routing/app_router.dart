import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/route_constants.dart';
import '../core/widgets/animated_page.dart';
import '../features/auth/presentation/screens/phone_input_screen.dart';
import '../features/auth/presentation/screens/otp_verification_screen.dart';
import '../features/auth/presentation/screens/profile_setup_screen.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/groups/presentation/screens/groups_list_screen.dart';
import '../features/groups/presentation/screens/group_detail_screen.dart';
import '../features/groups/presentation/screens/create_group_screen.dart';
import '../features/balances/presentation/screens/balances_screen.dart';
import '../features/auth/presentation/screens/profile_screen.dart';
import '../features/qr_code/presentation/screens/my_qr_code_screen.dart';
import '../features/qr_code/presentation/screens/qr_scanner_screen.dart';
import '../features/friends/presentation/screens/friends_screen.dart';
import '../features/notifications/presentation/screens/notifications_screen.dart';
import '../features/settlements/presentation/screens/settle_up_screen.dart';
import 'shell_scaffold.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final firebaseAuth = ref.watch(firebaseAuthProvider);

  return GoRouter(
    initialLocation: RouteConstants.splash,
    debugLogDiagnostics: true,
    refreshListenable: GoRouterRefreshStream(firebaseAuth.authStateChanges()),
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isLoggingIn = state.matchedLocation.startsWith('/auth');
      final isSplash = state.matchedLocation == RouteConstants.splash;

      // If on splash, redirect based on auth state
      if (isSplash) {
        return isLoggedIn ? RouteConstants.groups : RouteConstants.phoneInput;
      }

      // If not logged in and not on auth pages, redirect to login
      if (!isLoggedIn && !isLoggingIn) {
        return RouteConstants.phoneInput;
      }

      // If logged in and on auth pages, redirect to home
      if (isLoggedIn && isLoggingIn) {
        return RouteConstants.groups;
      }

      return null;
    },
    routes: [
      // Splash route
      GoRoute(
        path: RouteConstants.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      // Auth routes
      GoRoute(
        path: RouteConstants.phoneInput,
        pageBuilder: (context, state) => FadePage(
          key: state.pageKey,
          child: const PhoneInputScreen(),
        ),
      ),
      GoRoute(
        path: RouteConstants.otpVerification,
        pageBuilder: (context, state) {
          final phoneNumber = state.extra as String? ?? '';
          return AnimatedPage(
            key: state.pageKey,
            child: OtpVerificationScreen(phoneNumber: phoneNumber),
          );
        },
      ),
      GoRoute(
        path: RouteConstants.profileSetup,
        pageBuilder: (context, state) => AnimatedPage(
          key: state.pageKey,
          child: const ProfileSetupScreen(),
        ),
      ),

      // Main app with shell (bottom navigation)
      ShellRoute(
        builder: (context, state, child) {
          return ShellScaffold(child: child);
        },
        routes: [
          // Groups tab
          GoRoute(
            path: RouteConstants.groups,
            pageBuilder: (context, state) => FadePage(
              key: state.pageKey,
              child: const GroupsListScreen(),
            ),
            routes: [
              GoRoute(
                path: 'create',
                pageBuilder: (context, state) => SlideUpPage(
                  key: state.pageKey,
                  child: const CreateGroupScreen(),
                ),
              ),
              GoRoute(
                path: ':groupId',
                pageBuilder: (context, state) {
                  final groupId = state.pathParameters['groupId']!;
                  return AnimatedPage(
                    key: state.pageKey,
                    child: GroupDetailScreen(groupId: groupId),
                  );
                },
                routes: [
                  GoRoute(
                    path: 'settle',
                    pageBuilder: (context, state) {
                      final groupId = state.pathParameters['groupId']!;
                      return AnimatedPage(
                        key: state.pageKey,
                        child: SettleUpScreen(groupId: groupId),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),

          // Balances tab
          GoRoute(
            path: RouteConstants.balances,
            pageBuilder: (context, state) => FadePage(
              key: state.pageKey,
              child: const BalancesScreen(),
            ),
          ),

          // Profile tab
          GoRoute(
            path: RouteConstants.profile,
            pageBuilder: (context, state) => FadePage(
              key: state.pageKey,
              child: const ProfileScreen(),
            ),
            routes: [
              GoRoute(
                path: 'qr',
                pageBuilder: (context, state) => AnimatedPage(
                  key: state.pageKey,
                  child: const MyQrCodeScreen(),
                ),
              ),
            ],
          ),

          // Friends screen
          GoRoute(
            path: RouteConstants.friends,
            pageBuilder: (context, state) => AnimatedPage(
              key: state.pageKey,
              child: const FriendsScreen(),
            ),
          ),

          // Notifications screen
          GoRoute(
            path: RouteConstants.notifications,
            pageBuilder: (context, state) => AnimatedPage(
              key: state.pageKey,
              child: const NotificationsScreen(),
            ),
          ),
        ],
      ),

      // QR Scanner (full screen, outside shell)
      GoRoute(
        path: RouteConstants.scanQr,
        pageBuilder: (context, state) {
          final groupId = state.extra as String?;
          return SlideUpPage(
            key: state.pageKey,
            child: QrScannerScreen(groupId: groupId),
          );
        },
      ),
    ],
    errorBuilder: (context, state) => ErrorScreen(error: state.error),
  );
});

/// Helper class to refresh GoRouter when auth state changes
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Splash screen shown during initial load
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet,
              size: 80,
              color: Color(0xFF5C6BC0),
            ),
            SizedBox(height: 24),
            Text(
              'LeGuJuste',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5C6BC0),
              ),
            ),
            SizedBox(height: 48),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

/// Error screen for navigation errors
class ErrorScreen extends StatelessWidget {
  final Exception? error;

  const ErrorScreen({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (error != null)
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(RouteConstants.groups),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }
}
