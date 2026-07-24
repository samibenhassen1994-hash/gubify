import 'dart:async';

import 'package:flutter/material.dart';

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

  @override
  State<GubChatOverlay> createState() => _GubChatOverlayState();
}

class _GubChatOverlayState extends State<GubChatOverlay> {
  OverlayState? _rootOverlay;
  OverlayEntry? _overlayEntry;
  StreamSubscription<int>? _unreadCountSubscription;

  bool _isChatOpen = false;
  bool _bringToFrontScheduled = false;
  int? _unreadCount;
  int _unreadStreamGeneration = 0;

  Future<void>? _readUpdateFuture;
  String? _pendingReadGubId;

  @override
  void initState() {
    super.initState();
    unawaited(_subscribeToUnreadCount());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _rootOverlay = Overlay.of(context, rootOverlay: true);
      _GubChatOverlayController.instance.attach(this);
      _insertOverlay();
    });
  }

  @override
  void didUpdateWidget(covariant GubChatOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.gubId != widget.gubId) {
      unawaited(_subscribeToUnreadCount());
      _overlayEntry?.markNeedsBuild();
    }
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
    if (!mounted || _isChatOpen || _overlayEntry != null) return;

    final overlay = _rootOverlay;
    if (overlay == null) return;

    final entry = OverlayEntry(builder: _buildOverlay);
    _overlayEntry = entry;
    overlay.insert(entry);
  }

  Widget _buildOverlay(BuildContext context) {
    final keyboardIsOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    if (_isChatOpen || keyboardIsOpen) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: SafeArea(
        minimum: const EdgeInsets.only(right: 20, bottom: 88),
        child: Align(
          alignment: Alignment.bottomRight,
          child: ChatFloatingButton(
            onPressed: _openChat,
            unreadCount: _unreadCount,
          ),
        ),
      ),
    );
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void bringToFront() {
    if (!mounted || _isChatOpen || _bringToFrontScheduled) return;

    _bringToFrontScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bringToFrontScheduled = false;

      if (!mounted || _isChatOpen) return;

      _removeOverlay();
      _insertOverlay();
    });
  }

  Future<void> _openChat() async {
    if (_isChatOpen || !mounted) return;

    final chatGubId = widget.gubId;
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
              onMessagesVisible: () => _handleVisibleMessages(chatGubId),
            ),
          ),
        );
      },
    );

    if (!mounted) return;

    _unreadCount = 0;
    unawaited(_markChatAsRead(chatGubId));
    _isChatOpen = false;
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
}
