import 'package:flutter/material.dart';

import '../screens/chat_screen.dart';
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

  bool _isChatOpen = false;
  bool _bringToFrontScheduled = false;

  @override
  void initState() {
    super.initState();

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
      _overlayEntry?.markNeedsBuild();
    }
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
          child: ChatFloatingButton(onPressed: _openChat),
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

    _isChatOpen = true;
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
            child: ChatScreen(gubId: widget.gubId),
          ),
        );
      },
    );

    if (!mounted) return;

    _isChatOpen = false;
    _insertOverlay();
  }

  @override
  void dispose() {
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
