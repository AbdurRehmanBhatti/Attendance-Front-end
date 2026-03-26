import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Reusable custom [PageRouteBuilder] that combines a slide + fade transition.
class SlideFadeRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final SlideDirection direction;

  SlideFadeRoute({
    required this.page,
    this.direction = SlideDirection.right,
  }) : super(
          transitionDuration: AppDurations.standard,
          reverseTransitionDuration: AppDurations.standard,
          pageBuilder: (_, __, ___) => page,
          transitionsBuilder: (_, animation, __, child) {
            final offsetBegin = switch (direction) {
              SlideDirection.right => const Offset(1, 0),
              SlideDirection.left => const Offset(-1, 0),
              SlideDirection.up => const Offset(0, 1),
              SlideDirection.down => const Offset(0, -1),
            };

            final slide = Tween(begin: offsetBegin, end: Offset.zero).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
            final fade = CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
            );

            return FadeTransition(
              opacity: fade,
              child: SlideTransition(position: slide, child: child),
            );
          },
        );
}

enum SlideDirection { right, left, up, down }
