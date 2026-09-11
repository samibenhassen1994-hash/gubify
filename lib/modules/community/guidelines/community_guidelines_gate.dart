import 'package:flutter/material.dart';

import 'community_guidelines_screen.dart';
import 'community_guidelines_service.dart';

class CommunityGuidelinesGate extends StatefulWidget {
  const CommunityGuidelinesGate({super.key, required this.child, this.service});

  final Widget child;
  final CommunityGuidelinesService? service;

  @override
  State<CommunityGuidelinesGate> createState() =>
      _CommunityGuidelinesGateState();
}

class _CommunityGuidelinesGateState extends State<CommunityGuidelinesGate> {
  bool? _accepted;
  Object? _error;

  CommunityGuidelinesService get _service =>
      widget.service ?? CommunityGuidelinesService.instance;

  @override
  void initState() {
    super.initState();
    _loadAcceptance();
  }

  @override
  void didUpdateWidget(covariant CommunityGuidelinesGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      _accepted = null;
      _error = null;
      _loadAcceptance();
    }
  }

  Future<void> _loadAcceptance() async {
    try {
      final accepted = await _service.hasCurrentUserAccepted();
      if (!mounted) return;
      setState(() {
        _accepted = accepted;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 42),
            const SizedBox(height: 10),
            const Text('Unable to load the Community Guidelines status.'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                setState(() {
                  _accepted = null;
                  _error = null;
                });
                _loadAcceptance();
              },
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }
    if (_accepted == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_accepted!) return widget.child;

    return CommunityGuidelinesScreen(
      onAccept: _service.acceptForCurrentUser,
      onAccepted: () => setState(() => _accepted = true),
    );
  }
}
