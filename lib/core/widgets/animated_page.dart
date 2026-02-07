import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_durations.dart';

/// Custom page transition with fade and slide animation.
///
/// Use this for consistent page transitions throughout the app.
class AnimatedPage<T> extends CustomTransitionPage<T> {
  AnimatedPage({
    required super.child,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  }) : super(
          transitionDuration: AppDurations.pageTransition,
          reverseTransitionDuration: AppDurations.pageTransition,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.05, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                )),
                child: child,
              ),
            );
          },
        );
}

/// Fade-only page transition
class FadePage<T> extends CustomTransitionPage<T> {
  FadePage({
    required super.child,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  }) : super(
          transitionDuration: AppDurations.pageTransition,
          reverseTransitionDuration: AppDurations.pageTransition,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
              child: child,
            );
          },
        );
}

/// Slide-up page transition (for modals/bottom sheets)
class SlideUpPage<T> extends CustomTransitionPage<T> {
  SlideUpPage({
    required super.child,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  }) : super(
          transitionDuration: AppDurations.modalTransition,
          reverseTransitionDuration: AppDurations.modalTransition,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            );
          },
        );
}

/// Scale page transition
class ScalePage<T> extends CustomTransitionPage<T> {
  ScalePage({
    required super.child,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  }) : super(
          transitionDuration: AppDurations.pageTransition,
          reverseTransitionDuration: AppDurations.pageTransition,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
              ),
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
        );
}
