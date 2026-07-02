import 'package:flutter/material.dart';

class HubfyBackground extends StatelessWidget {
  final Widget child;

  const HubfyBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [

          // ===============================
          // IMMAGINE DI SFONDO
          // ===============================

          Positioned.fill(
            child: Image.asset(
              'assets/backgrounds/welcome_background.png',
              fit: BoxFit.cover,
            ),
          ),

          // ===============================
          // CERCHIO ESTERNO
          // ===============================

          Positioned.fill(
            child: Center(
              child: Container(
                width: 520,
                height: 520,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .05),
                  ),
                ),
              ),
            ),
          ),

          // ===============================
          // CERCHIO INTERNO
          // ===============================

          Positioned.fill(
            child: Center(
              child: Container(
                width: 360,
                height: 360,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .03),
                  ),
                ),
              ),
            ),
          ),

          // ===============================
          // GLOW DIETRO IL LOGO
          // ===============================

          Positioned.fill(
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -140),
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB)
                            .withValues(alpha: .45),
                        blurRadius: 120,
                        spreadRadius: 35,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ===============================
          // CONTENUTO
          // ===============================

          child,
        ],
      ),
    );
  }
}