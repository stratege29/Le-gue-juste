import 'package:flutter/material.dart';

/// A reusable staggered fade+slide animation wrapper for list cards.
///
/// Delays the animation by 80ms per [index] to create a cascading entrance
/// effect when multiple cards are displayed in a list.
class StaggeredAnimatedCard extends StatefulWidget {
  final Widget child;
  final int index;

  const StaggeredAnimatedCard({
    super.key,
    required this.child,
    required this.index,
  });

  @override
  State<StaggeredAnimatedCard> createState() => _StaggeredAnimatedCardState();
}

class _StaggeredAnimatedCardState extends State<StaggeredAnimatedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    Future.delayed(Duration(milliseconds: 80 * widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}
