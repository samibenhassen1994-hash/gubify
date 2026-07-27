import 'package:flutter/material.dart';

class ChatUserAvatar extends StatelessWidget {
  final String? displayName;
  final String? userId;
  final String? photoUrl;
  final double radius;
  final VoidCallback? onTap;
  final Color? backgroundColor;

  const ChatUserAvatar({
    super.key,
    this.displayName,
    this.userId,
    this.photoUrl,
    this.radius = 17,
    this.onTap,
    this.backgroundColor,
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
    final colorIndex = _stableHash(colorKey) % _avatarColors.length;

    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? _avatarColors[colorIndex],
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

    if (onTap == null) return avatar;

    return Semantics(
      button: true,
      label:
          "Open ${displayName?.trim().isNotEmpty == true ? displayName!.trim() : 'user'} profile",
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(3), child: avatar),
        ),
      ),
    );
  }

  int _stableHash(String value) {
    var hash = 0;
    for (final codeUnit in value.codeUnits) {
      hash = ((hash * 31) + codeUnit) & 0x7fffffff;
    }
    return hash;
  }

  String _initialFor(String? name) {
    final normalizedName = name?.trim() ?? "";
    if (normalizedName.isEmpty) return "?";

    return String.fromCharCode(normalizedName.runes.first).toUpperCase();
  }
}
