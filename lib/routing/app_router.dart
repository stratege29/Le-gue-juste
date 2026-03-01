import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/route_constants.dart';
import '../core/widgets/animated_page.dart';
import '../features/auth/presentation/screens/phone_input_screen.dart';
import '../features/auth/presentation/screens/otp_verification_screen.dart';
import '../features/auth/presentation/screens/profile_setup_screen.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/groups/presentation/screens/groups_list_screen.dart';
import '../features/groups/presentation/screens/group_detail_screen.dart';
import '../features/groups/presentation/screens/create_group_screen.dart';
import '../features/expenses/presentation/screens/add_expense_screen.dart';
import '../features/balances/presentation/screens/balances_screen.dart';
import '../features/auth/presentation/screens/profile_screen.dart';
import '../features/qr_code/presentation/screens/my_qr_code_screen.dart';
import '../features/qr_code/presentation/screens/qr_scanner_screen.dart';
import '../features/friends/presentation/screens/friends_screen.dart';
import '../features/notifications/presentation/screens/notifications_screen.dart';
import '../features/settlements/presentation/screens/settle_up_screen.dart';
import 'shell_scaffold.dart';

/// Minimum splash display time so animations play fully
final splashMinTimeProvider = FutureProvider<bool>((ref) async {
  await Future.delayed(const Duration(milliseconds: 2000));
  return true;
});

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final currentUser = ref.watch(currentUserProvider);
  final firebaseAuth = ref.watch(firebaseAuthProvider);
  final splashMinTime = ref.watch(splashMinTimeProvider);

  return GoRouter(
    initialLocation: RouteConstants.splash,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: GoRouterRefreshStream(firebaseAuth.authStateChanges()),
    redirect: (context, state) {
      final isSplash = state.matchedLocation == RouteConstants.splash;

      // Stay on splash until minimum display time has elapsed
      if (isSplash && splashMinTime.isLoading) {
        return null;
      }

      // While auth is still loading, stay on splash
      if (authState.isLoading) {
        return isSplash ? null : RouteConstants.splash;
      }

      final isLoggedIn = authState.valueOrNull != null;

      // If logged in but profile still loading, stay on splash
      if (isLoggedIn && currentUser.isLoading) {
        return isSplash ? null : RouteConstants.splash;
      }

      final isLoggingIn = state.matchedLocation.startsWith('/auth');
      final isProfileSetup = state.matchedLocation == RouteConstants.profileSetup;
      final hasProfile = currentUser.valueOrNull != null;

      // If on splash, redirect based on resolved auth state
      if (isSplash) {
        if (!isLoggedIn) return RouteConstants.phoneInput;
        return hasProfile ? RouteConstants.groups : RouteConstants.profileSetup;
      }

      // If not logged in and not on auth pages, redirect to login
      if (!isLoggedIn && !isLoggingIn) {
        return RouteConstants.phoneInput;
      }

      // If logged in but no profile, go to profile setup
      if (isLoggedIn && !hasProfile && !isProfileSetup) {
        return RouteConstants.profileSetup;
      }

      // If logged in with profile and still on auth pages, go to home
      if (isLoggedIn && hasProfile && isLoggingIn) {
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
        redirect: (context, state) {
          // Guard: redirect to phone input if no phone number provided (e.g. deep-link)
          if (state.extra == null || (state.extra as String).isEmpty) {
            return RouteConstants.phoneInput;
          }
          return null;
        },
        pageBuilder: (context, state) {
          final phoneNumber = state.extra as String;
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
                    path: 'add-expense',
                    pageBuilder: (context, state) {
                      final groupId = state.pathParameters['groupId']!;
                      return AnimatedPage(
                        key: state.pageKey,
                        child: AddExpenseScreen(groupId: groupId),
                      );
                    },
                  ),
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
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _shimmerController;
  late AnimationController _dotsController;

  // Staggered intervals for main animations
  late Animation<double> _overlayOpacity;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _taglineOpacity;
  late Animation<double> _taglineSlide;
  late Animation<double> _dotsOpacity;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _overlayOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );
    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.4, curve: Curves.elasticOut),
      ),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
      ),
    );
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.3, 0.6, curve: Curves.easeOut),
      ),
    );
    _taglineSlide = Tween<double>(begin: 15.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.3, 0.6, curve: Curves.easeOutCubic),
      ),
    );
    _dotsOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.5, 0.8, curve: Curves.easeOut),
      ),
    );

    _mainController.forward();
  }

  @override
  void dispose() {
    _mainController.dispose();
    _shimmerController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  double _dotScale(int index) {
    final progress = (_dotsController.value - index * 0.15) % 1.0;
    if (progress < 0.5) return 0.5 + progress;
    return 1.5 - progress;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Full-screen splash illustration background
          SizedBox(
            width: size.width,
            height: size.height,
            child: Image.asset(
              'assets/images/splash_bg.jpg',
              fit: BoxFit.cover,
            ),
          ),

          // Dark gradient overlays for readability
          AnimatedBuilder(
            animation: _mainController,
            builder: (context, _) {
              return Opacity(
                opacity: _overlayOpacity.value,
                child: Stack(
                  children: [
                    // Top overlay: dark green to transparent
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: size.height * 0.45,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFF0D4A22).withValues(alpha: 0.4),
                              const Color(0xFF0D4A22).withValues(alpha: 0.15),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.6, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Bottom overlay: transparent to dark green
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: size.height * 0.45,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              const Color(0xFF0D4A22).withValues(alpha: 0.2),
                              const Color(0xFF0D4A22).withValues(alpha: 0.55),
                            ],
                            stops: const [0.0, 0.4, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Main content
          AnimatedBuilder(
            animation: _mainController,
            builder: (context, _) {
              return SafeArea(
                bottom: true,
                child: Column(
                children: [
                  // Logo in upper portion
                  SizedBox(height: size.height * 0.08),
                  Opacity(
                    opacity: _logoOpacity.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: AnimatedBuilder(
                        animation: _shimmerController,
                        builder: (context, child) {
                          return ShaderMask(
                            shaderCallback: (bounds) {
                              final shimmerX =
                                  _shimmerController.value * 3.0 - 1.0;
                              return LinearGradient(
                                begin: Alignment(shimmerX - 0.3, 0),
                                end: Alignment(shimmerX + 0.3, 0),
                                colors: [
                                  Colors.white,
                                  Colors.white.withValues(alpha: 0.5),
                                  Colors.white,
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ).createShader(bounds);
                            },
                            blendMode: BlendMode.modulate,
                            child: child!,
                          );
                        },
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: size.width * 0.75,
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Tagline
                  Opacity(
                    opacity: _taglineOpacity.value,
                    child: Transform.translate(
                      offset: Offset(0, _taglineSlide.value),
                      child: Text(
                        'Les bons comptes font les bons amis',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Pulsing dots
                  Opacity(
                    opacity: _dotsOpacity.value,
                    child: AnimatedBuilder(
                      animation: _dotsController,
                      builder: (context, _) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(3, (index) {
                            final scale = _dotScale(index);
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: Transform.scale(
                                scale: scale,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFC49A3C),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFC49A3C)
                                            .withValues(alpha: 0.4),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ),

                  SizedBox(height: size.height * 0.08),
                ],
              ),
              );
            },
          ),
        ],
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
      appBar: AppBar(title: const Text('Erreur')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Page introuvable',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(RouteConstants.groups),
              child: const Text('Retour à l\'accueil'),
            ),
          ],
        ),
      ),
    );
  }
}
