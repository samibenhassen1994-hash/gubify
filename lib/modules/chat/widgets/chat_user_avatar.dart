import 'package:flutter/material.dart';

class ChatUserAvatar extends StatelessWidget {
  final String? displayName;
  final String? userId;
  final String? photoUrl;
  final double radius;

  const ChatUserAvatar({
    super.key,
    this.displayName,
    this.userId,
    this.photoUrl,
    this.radius = 17,
  });

  static const List<Color> _avatarColors = [
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFF0891B2),
    Color(0xFF059669),
    Color(0xFFEA580C),
    Color(0xFFDB2777),
  ];

  @override
  Widget build(BuildContext context) {
    final normalizedPhotoUrl = photoUrl?.trim();
    final colorKey = userId?.trim().isNotEmpty == true
        ? userId!.trim()
        : displayName?.trim() ?? "";
    final colorIndex = (colorKey.hashCode & 0x7fffffff) % _avatarColors.length;

    return CircleAvatar(
      radius: radius,
      backgroundColor: _avatarColors[colorIndex],
      foregroundImage:
          normalizedPhotoUrl != null && normalizedPhotoUrl.isNotEmpty
          ? NetworkImage(normalizedPhotoUrl)
          : null,
      child: normalizedPhotoUrl == null || normalizedPhotoUrl.isEmpty
          ? Text(
              _initialFor(displayName),
              style: TextStyle(
                color: Colors.white,
                fontSize: radius * 0.82,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
    );
  }

  String _initialFor(String? name) {
    final normalizedName = name?.trim() ?? "";
    if (normalizedName.isEmpty) return "?";

    return String.fromCharCode(normalizedName.runes.first).toUpperCase();
  }
}
