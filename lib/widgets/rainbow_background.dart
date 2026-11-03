import 'package:flutter/material.dart';

import '../main.dart';

class RainbowBackground extends StatelessWidget {
  final Widget child;

  const RainbowBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.cream,
            AppColors.butterLight,
            Color(0xFFFCE8E8),
            Color(0xFFF0E9FC),
            Color(0xFFE6F3FA),
            AppColors.background,
          ],
        ),
      ),
      child: child,
    );
  }
}
