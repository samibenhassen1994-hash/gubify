import 'package:flutter/material.dart';

class GubifyLogo extends StatelessWidget {
  final double width;

  const GubifyLogo({
    super.key,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      width: width,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}