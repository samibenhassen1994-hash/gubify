import 'dart:ui';

import 'package:flutter/material.dart';

class GubifyBottomNavigationBar extends StatelessWidget {
  const GubifyBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.compact = false,
    this.profileDisplayName,
    this.profilePhotoUrl,
    this.hasUnreadNotifications = false,
  });

  static const double regularHeight = 64;
  static const double compactHeight = 48;
  static const double overlayScrollClearance = regularHeight + 24;

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool compact;
  final String? profileDisplayName;
  final String? profilePhotoUrl;
  final bool hasUnreadNotifications;

  static const _destinations = <_BottomDestination>[
    _BottomDestination(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    _BottomDestination(
      label: 'Explore',
      icon: Icons.search_rounded,
      selectedIcon: Icons.search_rounded,
    ),
    _BottomDestination(
      label: 'Notifications',
      icon: Icons.notifications_none_rounded,
      selectedIcon: Icons.notifications_rounded,
    ),
    _BottomDestination(label: 'Profile', isProfile: true),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? compactHeight : regularHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x140F172A),
              blurRadius: 18,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: DecoratedBox(
              key: const Key('gubify-bottom-navigation-glass'),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
                  width: 1,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: Row(
                  children: [
                    for (
                      var index = 0;
                      index < _destinations.length;
                      index++
                    ) ...[
                      if (index > 0)
                        Container(
                          width: 1,
                          height: 26,
                          color: const Color(0x1F334155),
                        ),
                      Expanded(
                        child: _BottomNavigationItem(
                          destination: _destinations[index],
                          selected: selectedIndex == index,
                          onTap: () => onDestinationSelected(index),
                          compact: compact,
                          profileDisplayName: profileDisplayName,
                          profilePhotoUrl: profilePhotoUrl,
                          hasUnread: index == 2 && hasUnreadNotifications,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavigationItem extends StatelessWidget {
  const _BottomNavigationItem({
    required this.destination,
    required this.selected,
    required this.onTap,
    required this.compact,
    this.profileDisplayName,
    this.profilePhotoUrl,
    required this.hasUnread,
  });

  final _BottomDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;
  final String? profileDisplayName;
  final String? profilePhotoUrl;
  final bool hasUnread;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: Tooltip(
        message: destination.label,
        child: InkResponse(
          onTap: onTap,
          radius: 28,
          containedInkWell: true,
          highlightShape: BoxShape.circle,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: compact ? 40 : 44,
              height: compact ? 40 : 44,
              decoration: BoxDecoration(
                color: selected ? const Color(0x14334155) : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: destination.isProfile
                  ? _ProfileNavigationAvatar(
                      displayName: profileDisplayName,
                      photoUrl: profilePhotoUrl,
                      selected: selected,
                    )
                  : Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          selected ? destination.selectedIcon : destination.icon,
                          color: selected ? const Color(0xFF0F172A) : const Color(0xFF475569),
                          size: selected ? 27 : 25,
                        ),
                        if (hasUnread)
                          const Positioned(
                            right: -2,
                            top: -2,
                            child: DecoratedBox(
                              key: Key('global-notification-unread-dot'),
                              decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                              child: SizedBox(width: 8, height: 8),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomDestination {
  const _BottomDestination({
    required this.label,
    this.icon,
    this.selectedIcon,
    this.isProfile = false,
  });

  final String label;
  final IconData? icon;
  final IconData? selectedIcon;
  final bool isProfile;
}

class _ProfileNavigationAvatar extends StatelessWidget {
  const _ProfileNavigationAvatar({
    required this.displayName,
    required this.photoUrl,
    required this.selected,
  });

  final String? displayName;
  final String? photoUrl;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final trimmedName = displayName?.trim() ?? '';
    final initial = trimmedName.isEmpty
        ? '?'
        : String.fromCharCode(trimmedName.runes.first).toUpperCase();
    final trimmedPhotoUrl = photoUrl?.trim() ?? '';
    final photoUri = Uri.tryParse(trimmedPhotoUrl);
    final usablePhotoUrl =
        photoUri != null &&
        (photoUri.scheme == 'http' || photoUri.scheme == 'https');

    return Center(
      child: AnimatedContainer(
        key: Key(
          selected
              ? 'bottom-navigation-profile-selection'
              : 'bottom-navigation-profile-avatar',
        ),
        duration: const Duration(milliseconds: 180),
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF334155),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.35),
            width: selected ? 2 : 1,
          ),
          image: usablePhotoUrl
              ? DecorationImage(
                  image: NetworkImage(trimmedPhotoUrl),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        alignment: Alignment.center,
        child: usablePhotoUrl
            ? null
            : Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
