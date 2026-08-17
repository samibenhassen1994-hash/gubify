import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../modules/chat/widgets/chat_user_avatar.dart';
import '../modules/chat/widgets/gub_chat_overlay.dart';
import '../modules/notifications/models/notification_model.dart';
import '../modules/notifications/screens/notifications_screen.dart';
import '../modules/notifications/services/notification_service.dart';
import '../modules/profile/screens/personal_profile_screen.dart';
import '../modules/profile/screens/account_screen.dart';
import '../modules/profile/screens/user_profile_screen.dart';
import '../modules/profile/widgets/account_session_section.dart';
import '../modules/profile/widgets/google_account_connection_section.dart';
import '../pages/startup_screen.dart';
import '../repositories/user_repository.dart';
import '../services/app_sound_service.dart';
import '../services/auth_service.dart';
import 'gub_content_card.dart';

class UserHeader extends StatefulWidget {
  final String? gubId;
  final bool darkMode;
  final bool personalProfileEnabled;
  final bool showCard;
  final bool darkCard;
  final double? bottomPadding;
  final VoidCallback? onExploreCommunities;

  const UserHeader({
    super.key,
    this.gubId,
    this.darkMode = false,
    this.personalProfileEnabled = false,
    this.showCard = false,
    this.darkCard = false,
    this.bottomPadding,
    this.onExploreCommunities,
  }) : assert(!darkCard || showCard, "darkCard requires showCard.");

  @override
  State<UserHeader> createState() => _UserHeaderState();
}

class _UserHeaderState extends State<UserHeader> {
  String? _userId;
  late Future<Map<String, dynamic>?> _userFuture;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void didUpdateWidget(covariant UserHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != _userId) {
      _loadCurrentUser();
    }
  }

  void _loadCurrentUser() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _userId = currentUserId;
    _userFuture = currentUserId == null
        ? Future.value(null)
        : UserRepository.instance.getUser(currentUserId);
  }

  Future<void> _openSettings() async {
    Future<void> showSettings() {
      return showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (_) => const UserSettingsSheet(),
      );
    }

    if (widget.gubId == null) {
      await showSettings();
      if (mounted) setState(_loadCurrentUser);
      return;
    }

    await GubChatOverlay.runWithChatOverlayHidden(showSettings);
    if (mounted) setState(_loadCurrentUser);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != _userId) {
      return _buildPlaceholder();
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          const placeholder = SizedBox(height: 44);

          return Padding(
            padding: EdgeInsets.only(
              bottom: widget.bottomPadding ?? (widget.showCard ? 20 : 24),
            ),
            child: widget.showCard
                ? _UserHeaderCard(dark: widget.darkCard, child: placeholder)
                : placeholder,
          );
        }

        final data = snapshot.data;
        final storedDisplayName = data?["displayName"];
        final displayName =
            storedDisplayName is String && storedDisplayName.trim().isNotEmpty
            ? storedDisplayName.trim()
            : "User";
        final storedPhotoUrl = data?["photoUrl"] ?? data?["photoURL"];
        final photoUrl = storedPhotoUrl is String ? storedPhotoUrl : null;
        final useLightForeground =
            widget.darkCard || (widget.darkMode && !widget.showCard);

        final headerContent = Row(
          children: [
            _CurrentUserAvatar(
              gubId: widget.gubId,
              userId: user.uid,
              displayName: displayName,
              photoUrl: widget.darkCard ? null : photoUrl,
              personalProfileEnabled: widget.personalProfileEnabled,
              backgroundColor: widget.darkCard ? const Color(0xFF2563EB) : null,
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Text(
                displayName,
                style: TextStyle(
                  color: useLightForeground ? Colors.white : Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            if (widget.gubId != null)
              StreamBuilder<List<NotificationModel>>(
                stream: NotificationService.instance.unreadNotificationsStream(
                  widget.gubId!,
                ),
                builder: (context, snapshot) {
                  final unreadNotifications = snapshot.data ?? const [];

                  AppSoundService.instance.handleUnreadNotifications(
                    gubId: widget.gubId!,
                    unreadIds: unreadNotifications.map(
                      (notification) => notification.notificationId,
                    ),
                  );

                  final count = unreadNotifications.length;

                  return SizedBox(
                    width: 56,
                    height: 56,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(28),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  NotificationsScreen(gubId: widget.gubId!),
                            ),
                          );
                        },
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              Icons.notifications_outlined,
                              size: 26,
                              color: widget.darkCard
                                  ? Colors.white
                                  : useLightForeground
                                  ? Colors.white70
                                  : Colors.black54,
                            ),

                            if (count > 0)
                              Positioned(
                                right: 6,
                                top: 6,
                                child: IgnorePointer(
                                  child: Container(
                                    width: 19,
                                    height: 19,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      count > 9 ? "9+" : "$count",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

            if (widget.onExploreCommunities != null)
              IconButton(
                tooltip: "Explore communities",
                onPressed: widget.onExploreCommunities,
                icon: Icon(
                  Icons.public_rounded,
                  size: 25,
                  color: widget.darkCard
                      ? Colors.white
                      : useLightForeground
                      ? Colors.white70
                      : const Color(0xFF2563EB),
                ),
              ),

            IconButton(
              tooltip: "Settings",
              onPressed: _openSettings,
              icon: Icon(
                Icons.settings_outlined,
                size: 26,
                color: widget.darkCard
                    ? Colors.white
                    : useLightForeground
                    ? Colors.white70
                    : Colors.black54,
              ),
            ),
          ],
        );

        return Padding(
          padding: EdgeInsets.only(bottom: widget.bottomPadding ?? 20),
          child: widget.showCard
              ? _UserHeaderCard(dark: widget.darkCard, child: headerContent)
              : headerContent,
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    const placeholder = SizedBox(height: 44);
    return Padding(
      padding: EdgeInsets.only(
        bottom: widget.bottomPadding ?? (widget.showCard ? 20 : 24),
      ),
      child: widget.showCard
          ? _UserHeaderCard(dark: widget.darkCard, child: placeholder)
          : placeholder,
    );
  }
}

class UserSettingsSheet extends StatefulWidget {
  const UserSettingsSheet({super.key, this.authService, this.onLoggedOut});

  final AuthService? authService;
  final Future<void> Function()? onLoggedOut;

  @override
  State<UserSettingsSheet> createState() => _UserSettingsSheetState();
}

class _UserSettingsSheetState extends State<UserSettingsSheet> {
  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
  }

  Future<void> _openAccountSecurity() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: GoogleAccountConnectionSection(
          authService: _authService,
          onAccountSecured: () => Navigator.of(sheetContext).pop(),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _returnToAuthEntry() async {
    final onLoggedOut = widget.onLoggedOut;
    if (onLoggedOut != null) {
      await onLoggedOut();
      return;
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil<void>(
      MaterialPageRoute(
        builder: (_) => StartupScreen(
          authService: _authService,
          minimumDisplayDuration: Duration.zero,
          onNavigationReady: () {},
        ),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Settings",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.manage_accounts_outlined),
              title: const Text(
                'Account',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AccountScreen(authService: _authService),
                ),
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: AppSoundService.instance.enabledListenable,
              builder: (context, enabled, _) {
                return SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.volume_up_outlined),
                  title: const Text(
                    "App sounds",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    "Play sounds for messages, notifications and actions.",
                  ),
                  value: enabled,
                  onChanged: AppSoundService.instance.setEnabled,
                );
              },
            ),
            const SizedBox(height: 12),
            AccountSessionSection(
              authService: _authService,
              onLoggedOut: _returnToAuthEntry,
              onSecureAccount: () {
                _openAccountSecurity();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _UserHeaderCard extends StatelessWidget {
  final Widget child;
  final bool dark;

  const _UserHeaderCard({required this.child, required this.dark});

  @override
  Widget build(BuildContext context) {
    return GubContentCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      color: dark ? const Color(0xE60B1739) : Colors.white,
      border: dark
          ? Border.all(color: const Color(0x24FFFFFF), width: 0.8)
          : null,
      boxShadow: dark
          ? const [
              BoxShadow(
                color: Color(0x38000000),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ]
          : null,
      child: child,
    );
  }
}

class _CurrentUserAvatar extends StatefulWidget {
  final String? gubId;
  final String userId;
  final String? displayName;
  final String? photoUrl;
  final bool personalProfileEnabled;
  final Color? backgroundColor;

  const _CurrentUserAvatar({
    required this.gubId,
    required this.userId,
    required this.personalProfileEnabled,
    this.displayName,
    this.photoUrl,
    this.backgroundColor,
  });

  @override
  State<_CurrentUserAvatar> createState() => _CurrentUserAvatarState();
}

class _CurrentUserAvatarState extends State<_CurrentUserAvatar> {
  bool _isOpeningProfile = false;

  Future<void> _openProfile() async {
    final gubId = widget.gubId;
    if ((gubId == null && !widget.personalProfileEnabled) ||
        _isOpeningProfile) {
      return;
    }

    setState(() => _isOpeningProfile = true);
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => gubId == null
              ? PersonalProfileScreen(userId: widget.userId)
              : UserProfileScreen(gubId: gubId, userId: widget.userId),
        ),
      );
    } finally {
      if (mounted) setState(() => _isOpeningProfile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChatUserAvatar(
      displayName: widget.displayName,
      userId: widget.userId,
      photoUrl: widget.photoUrl,
      radius: 22,
      backgroundColor: widget.backgroundColor,
      onTap:
          (widget.gubId == null && !widget.personalProfileEnabled) ||
              _isOpeningProfile
          ? null
          : _openProfile,
    );
  }
}
