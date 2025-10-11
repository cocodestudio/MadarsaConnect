import 'package:flutter/material.dart';

class CircularRevealRoute extends PageRouteBuilder {
  final Widget page;
  final Offset center;
  final Duration duration;
  final Duration reverseDuration;

  CircularRevealRoute({
    required this.page,
    required this.center,
    this.duration = const Duration(milliseconds: 350),
    this.reverseDuration = const Duration(milliseconds: 200),
  }) : super(
    transitionDuration: duration,
    reverseTransitionDuration: reverseDuration,
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          double radius = MediaQuery.of(context).size.longestSide * 1.2;
          double animValue = animation.value;
          return ClipPath(
            clipper: _CircularRevealClipper(
              center: center,
              radius: radius * animValue,
            ),
            child: child,
          );
        },
      );
    },
  );
}

class _CircularRevealClipper extends CustomClipper<Path> {
  final Offset center;
  final double radius;

  _CircularRevealClipper({required this.center, required this.radius});

  @override
  Path getClip(Size size) {
    return Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  @override
  bool shouldReclip(_CircularRevealClipper oldClipper) {
    return radius != oldClipper.radius || center != oldClipper.center;
  }
}
