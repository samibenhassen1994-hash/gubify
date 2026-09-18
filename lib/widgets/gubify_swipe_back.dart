import 'package:flutter/material.dart';

class GubifySwipeBack extends StatefulWidget {
  const GubifySwipeBack({super.key, required this.child, this.onBack});

  static const double edgeWidth = 24;
  static const double horizontalThreshold = 72;
  static const double verticalTolerance = 48;

  final Widget child;
  final VoidCallback? onBack;

  @override
  State<GubifySwipeBack> createState() => _GubifySwipeBackState();
}

class _GubifySwipeBackState extends State<GubifySwipeBack> {
  int? _pointer;
  Offset? _startPosition;
  Offset? _lastPosition;
  bool _startedInWrongDirection = false;

  void _handlePointerDown(PointerDownEvent event) {
    if (_pointer != null || event.position.dx > GubifySwipeBack.edgeWidth) {
      return;
    }
    _pointer = event.pointer;
    _startPosition = event.position;
    _lastPosition = event.position;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    _lastPosition = event.position;
    final start = _startPosition;
    if (start != null && event.position.dx < start.dx - 4) {
      _startedInWrongDirection = true;
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    _lastPosition = event.position;
    final start = _startPosition;
    final end = _lastPosition;
    final startedInWrongDirection = _startedInWrongDirection;
    _resetGesture();
    if (start == null || end == null || startedInWrongDirection) return;

    final delta = end - start;
    final verticalDistance = delta.dy.abs();
    final isValidBackGesture =
        delta.dx >= GubifySwipeBack.horizontalThreshold &&
        verticalDistance <= GubifySwipeBack.verticalTolerance &&
        delta.dx >= verticalDistance * 1.5;
    if (!isValidBackGesture) return;

    final onBack = widget.onBack;
    if (onBack != null) {
      onBack();
    } else {
      Navigator.maybePop(context);
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer == _pointer) _resetGesture();
  }

  void _resetGesture() {
    _pointer = null;
    _startPosition = null;
    _lastPosition = null;
    _startedInWrongDirection = false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: widget.child,
    );
  }
}
