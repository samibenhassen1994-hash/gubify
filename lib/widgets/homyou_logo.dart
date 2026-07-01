import 'package:flutter/material.dart';

class HomyouLogo extends StatelessWidget {
  final double width;

  const HomyouLogo({
    super.key,
    this.width = 220,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      width: width,
      fit: BoxFit.contain,
    );
  }
}