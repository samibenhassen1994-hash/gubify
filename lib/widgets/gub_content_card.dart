import 'package:flutter/material.dart';

class GubContentCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Border? border;
  final List<BoxShadow>? boxShadow;

  const GubContentCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color = Colors.white,
    this.border,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border:
            border ?? Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
        boxShadow:
            boxShadow ??
            const [
              BoxShadow(
                color: Color(0x0F0F172A),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}
