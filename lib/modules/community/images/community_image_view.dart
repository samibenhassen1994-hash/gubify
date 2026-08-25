import 'package:flutter/material.dart';

class CommunityImageView extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final BorderRadius borderRadius;

  const CommunityImageView({
    super.key,
    required this.imageUrl,
    required this.size,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
  });

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = imageUrl?.trim();
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: size,
        height: size,
        child: normalizedUrl == null || normalizedUrl.isEmpty
            ? _fallback()
            : Image.network(
                normalizedUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(),
              ),
      ),
    );
  }

  Widget _fallback() => ColoredBox(
    color: const Color(0xFFEFF6FF),
    child: const Center(
      child: Icon(Icons.public_rounded, color: Color(0xFF2563EB), size: 38),
    ),
  );
}
