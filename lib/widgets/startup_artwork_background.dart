import 'package:flutter/material.dart';

class StartupArtworkBackground extends StatelessWidget {
  final Widget child;

  const StartupArtworkBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/startup_background.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),

          SafeArea(
            child: child,
          ),
        ],
      ),
    );
  }
}