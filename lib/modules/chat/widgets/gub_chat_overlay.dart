import 'dart:async';

import 'package:flutter/material.dart';

import '../../profile/screens/user_profile_screen.dart';
import '../../tasks/screens/create_task_screen.dart';
import '../models/chat_message_model.dart';
import '../screens/chat_screen.dart';
import '../services/chat_read_service.dart';
import 'chat_floating_button.dart';

class GubChatNavigatorObserver extends NavigatorObserver {
  GubChatNavigatorObserver._();

  static final GubChatNavigatorObserver instance = GubChatNavigatorObserver._();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);

    if (route is PageRoute<dynamic>) {
      _GubChatOverlayController.instance.bringToFront();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);

    if (route is PageRoute<dynamic>) {
      _GubChatOverlayController.instance.bringToFront();
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);

    if (newRoute is PageRoute<dynamic> || oldRoute is PageRoute<dynamic>) {
      _GubChatOverlayController.instance.bringToFront();
    }
  }
}

class GubChatOverlay extends StatefulWidget {
  final String gubId;
  final Widget child;

  const GubChatOverlay({super.key, required this.gubId, required this.child});

  static Future<bool> openChat({
    required String gubId,
    String? initialMessageId,
  }) {
    return _GubChatOverlayController.instance.openChat(
      gubId: gubId,
      initialMessageId: initialMessageId,
    );
  }

  static Future<T> runWithChatOverlayHidden<T>(
    Future<T> Function() action,
  ) async {
    final controller = _GubChatOverlayController.instance;
    controller.suspend();
    try {
      return await action();
    } finally {
      controller.resume();
    }
  }

  @override
  State<GubChatOverlay> createState() => _GubChatOverlayState();
}

class _GubChatOverlayState extends State<GubChatOverlay> {
  OverlayState? _rootOverlay;
  OverlayEntry? _overlayEntry;
  StreamSubscription<int>? _unreadCountSubscription;

  bool _isChatOpen = false;
  bool _isTaskConversionOpen = false;
  bool _isUserProfileOpen = false;
  bool _bringToFrontScheduled = false;
  int? _unreadCount;
  int _unreadStreamGeneration = 0;

  Future<void>? _readUpdateFuture;
  String? _pendingReadGubId;

  @override
  void initState() {
    super.initState();
    unawaited(_subscribeToUnreadCount());
    _scheduleOverlaySync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleOverlaySync();
  }

  @override
  void didUpdateWidget(covariant GubChatOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.gubId != widget.gubId) {
      unawaited(_subscribeToUnreadCount());
      _scheduleOverlaySync(bringToFront: true);
    }
  }

  void _scheduleOverlaySync({bool bringToFront = false}) {
    if (bringToFront && _overlayEntry?.mounted == true) {
      _removeOverlay();
    }
    if (_bringToFrontScheduled) return;

    _bringToFrontScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bringToFrontScheduled = false;
      if (!mounted) return;

      final currentRootOverlay = Overlay.maybeOf(context, rootOverlay: true);
      if (currentRootOverlay == null || !currentRootOverlay.mounted) return;

      final entry = _overlayEntry;
      final overlayChanged =
          _rootOverlay != null && !identical(_rootOverlay, currentRootOverlay);

      if (entry != null && (!entry.mounted || overlayChanged)) {
        if (entry.mounted) {
          entry.remove();
        }
        _overlayEntry = null;
      }

      _rootOverlay = currentRootOverlay;
      _GubChatOverlayController.instance.attach(this);

      if (_isOverlaySuppressed) {
        _removeOverlay();
      } else {
        _insertOverlay();
      }
    });
  }

  Future<void> _subscribeToUnreadCount() async {
    final generation = ++_unreadStreamGeneration;
    await _unreadCountSubscription?.cancel();

    if (!mounted || generation != _unreadStreamGeneration) return;

    _unreadCount = null;

    _unreadCountSubscription = ChatReadService.instance
        .unreadCountStream(widget.gubId)
        .listen(
          (count) {
            if (!mounted || generation != _unreadStreamGeneration) return;

            _unreadCount = count;
            _overlayEntry?.markNeedsBuild();
          },
          onError: (Object _) {
            if (!mounted || generation != _unreadStreamGeneration) return;

            _unreadCount = null;
            _overlayEntry?.markNeedsBuild();
          },
        );
  }

  void _insertOverlay() {
    if (!mounted || _isOverlaySuppressed) return;

    final currentEntry = _overlayEntry;
    if (currentEntry != null) {
      if (currentEntry.mounted) return;
      _overlayEntry = null;
    }

    final overlay = _rootOverlay;
    if (overlay == null || !overlay.mounted) return;

    final entry = OverlayEntry(builder: _buildOverlay);
    _overlayEntry = entry;
    overlay.insert(entry);
  }

  Widget _buildOverlay(BuildContext context) {
    final keyboardIsOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    if (_isOverlaySuppressed || keyboardIsOpen) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: SafeArea(
        minimum: const EdgeInsets.only(right: 20, bottom: 88),
        child: Align(
          alignment: Alignment.bottomRight,
          child: ChatFloatingButton(
            onPressed: () => _openChat(),
            unreadCount: _unreadCount,
          ),
        ),
      ),
    );
  }

  void _removeOverlay() {
    final entry = _overlayEntry;
    if (entry?.mounted == true) {
      entry!.remove();
    }
    _overlayEntry = null;
  }

  void bringToFront() {
    if (!mounted || _isOverlaySuppressed) return;
    _scheduleOverlaySync(bringToFront: true);
  }

  bool get _isOverlaySuppressed =>
      _isChatOpen ||
      _isTaskConversionOpen ||
      _isUserProfileOpen ||
      _GubChatOverlayController.instance.isSuspended;

  Future<void> _openChat({String? initialMessageId}) async {
    if (_isChatOpen || !mounted) return;

    final chatGubId = widget.gubId;
    ChatMessageModel? taskSourceMessage;
    String? profileUserId;
    _isChatOpen = true;
    _unreadCount = 0;
    _removeOverlay();

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.94,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: ChatScreen(
              gubId: chatGubId,
              initialMessageId: initialMessageId,
              onMessagesVisible: () => _handleVisibleMessages(chatGubId),
              onConvertToTask: (message) {
                taskSourceMessage = message;
                Navigator.pop(sheetContext);
              },
              onOpenUserProfile: (userId) {
                profileUserId = userId;
                Navigator.pop(sheetContext);
              },
            ),
          ),
        );
      },
    );

    if (!mounted) return;

    _unreadCount = 0;
    unawaited(_markChatAsRead(chatGubId));
    _isChatOpen = false;

    final selectedProfileUserId = profileUserId;
    if (selectedProfileUserId != null) {
      _isUserProfileOpen = true;

      try {
        await Navigator.of(context, rootNavigator: true).push<void>(
          MaterialPageRoute(
            builder: (_) => UserProfileScreen(
              gubId: chatGubId,
              userId: selectedProfileUserId,
            ),
          ),
        );
      } finally {
        if (mounted) {
          _isUserProfileOpen = false;
          _insertOverlay();
        }
      }
      return;
    }

    final sourceMessage = taskSourceMessage;
    if (sourceMessage != null) {
      _isTaskConversionOpen = true;

      try {
        await Navigator.of(context, rootNavigator: true).push<void>(
          MaterialPageRoute(
            builder: (_) => CreateTaskScreen(
              gubId: chatGubId,
              sourceType: "chat",
              sourceId: sourceMessage.messageId,
              sourcePreview: sourceMessage.text,
              originUserId: sourceMessage.senderId,
              sourceAuthorName: sourceMessage.senderName,
            ),
          ),
        );
      } finally {
        if (mounted) {
          _isTaskConversionOpen = false;
          _insertOverlay();
        }
      }
      return;
    }

    _insertOverlay();
  }

  void _handleVisibleMessages(String gubId) {
    if (_isChatOpen) {
      unawaited(_markChatAsRead(gubId));
    }
  }

  Future<void> _markChatAsRead(String gubId) {
    _pendingReadGubId = gubId;
    return _readUpdateFuture ??= _drainReadUpdates();
  }

  Future<void> _drainReadUpdates() async {
    try {
      while (_pendingReadGubId != null) {
        final gubId = _pendingReadGubId!;
        _pendingReadGubId = null;

        try {
          await ChatReadService.instance.markAsRead(gubId);
        } catch (_) {}
      }
    } finally {
      _readUpdateFuture = null;
    }
  }

  @override
  void dispose() {
    _unreadStreamGeneration++;
    unawaited(_unreadCountSubscription?.cancel());
    _GubChatOverlayController.instance.detach(this);
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _GubChatOverlayController {
  _GubChatOverlayController._();

  static final _GubChatOverlayController instance =
      _GubChatOverlayController._();

  _GubChatOverlayState? _activeOverlay;
  int _suspensionCount = 0;

  bool get isSuspended => _suspensionCount > 0;

  void attach(_GubChatOverlayState overlay) {
    _activeOverlay = overlay;
  }

  void detach(_GubChatOverlayState overlay) {
    if (identical(_activeOverlay, overlay)) {
      _activeOverlay = null;
    }
  }

  void bringToFront() {
    _activeOverlay?.bringToFront();
  }

  void suspend() {
    _suspensionCount++;
    _activeOverlay?._removeOverlay();
  }

  void resume() {
    if (_suspensionCount == 0) return;

    _suspensionCount--;
    if (_suspensionCount == 0) {
      _activeOverlay?._scheduleOverlaySync(bringToFront: true);
    }
  }

  Future<bool> openChat({
    required String gubId,
    String? initialMessageId,
  }) async {
    final overlay = _activeOverlay;
    if (overlay == null ||
        !overlay.mounted ||
        overlay.widget.gubId != gubId ||
        overlay._isOverlaySuppressed) {
      return false;
    }

    await overlay._openChat(initialMessageId: initialMessageId);
    return true;
  }
}
