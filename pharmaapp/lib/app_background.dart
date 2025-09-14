// lib/app_background.dart
import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // --- The Background Image ---
        Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/icon/logo.png'),
              // Make the image very transparent so it doesn't distract
              opacity: 0.05,
              // You can experiment with different fits
              fit: BoxFit.contain,
            ),
          ),
        ),
        // --- The Actual Screen Content ---
        child,
      ],
    );
  }
}