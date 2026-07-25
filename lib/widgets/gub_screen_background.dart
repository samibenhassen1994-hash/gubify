import 'package:flutter/material.dart';

enum GubBackgroundVariant { blue, lilac, mint, sunset }

abstract final class GubBackgroundAssignments {
  static const double economicWhiteOverlayOpacity = 0.40;

  static const profiles = GubBackgroundVariant.lilac;
  static const tasks = GubBackgroundVariant.blue;
  static const proposals = GubBackgroundVariant.lilac;
  static const events = GubBackgroundVariant.mint;
  static const groupGoals = GubBackgroundVariant.mint;
  static const sharedBudget = GubBackgroundVariant.sunset;
}

extension GubBackgroundVariantAsset on GubBackgroundVariant {
  String get assetPath => switch (this) {
    GubBackgroundVariant.blue =>
      "assets/images/backgrounds/gub_background_blue.jpeg",
    GubBackgroundVariant.lilac =>
      "assets/images/backgrounds/gub_background_lilac.jpeg",
    GubBackgroundVariant.mint =>
      "assets/images/backgrounds/gub_background_mint.jpeg",
    GubBackgroundVariant.sunset =>
      "assets/images/backgrounds/gub_background_sunset.jpeg",
  };
}

class GubScreenBackground extends StatelessWidget {
  static const double defaultWhiteOverlayOpacity = 0.35;

  final GubBackgroundVariant variant;
  final Widget child;
  final double whiteOverlayOpacity;

  const GubScreenBackground({
    super.key,
    required this.variant,
    required this.child,
    this.whiteOverlayOpacity = defaultWhiteOverlayOpacity,
  }) : assert(
         whiteOverlayOpacity >= 0 && whiteOverlayOpacity <= 1,
         "whiteOverlayOpacity must be between 0 and 1.",
       );

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: Image.asset(
            variant.assetPath,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
        ),
        if (whiteOverlayOpacity > 0)
          IgnorePointer(
            child: ColoredBox(
              color: Colors.white.withValues(alpha: whiteOverlayOpacity),
            ),
          ),
        child,
      ],
    );
  }
}
