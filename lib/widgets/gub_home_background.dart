import 'package:flutter/material.dart';

class GubHomeBackground extends StatelessWidget {
  final Widget child;

  const GubHomeBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Sfondo
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFF8FAFC),
                  Color(0xFFF2F5FA),
                ],
              ),
            ),
          ),
        ),

        // Glow in alto a destra
        Positioned(
          top: -220,
          right: -220,
          child: Container(
            width: 500,
            height: 500,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2563EB).withValues(alpha: .025),
            ),
          ),
        ),

        // Glow in basso a sinistra
        Positioned(
          bottom: -260,
          left: -260,
          child: Container(
            width: 560,
            height: 560,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2563EB).withValues(alpha: .018),
            ),
          ),
        ),

        // Puntini decorativi
        Positioned(
          top: 170,
          right: 55,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue.withValues(alpha: .06),
            ),
          ),
        ),

        Positioned(
          top: 330,
          left: 35,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue.withValues(alpha: .05),
            ),
          ),
        ),

        Positioned(
          bottom: 220,
          left: 80,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue.withValues(alpha: .05),
            ),
          ),
        ),

        Positioned(
          bottom: 340,
          right: 60,
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue.withValues(alpha: .05),
            ),
          ),
        ),

        child,
      ],
    );
  }
}