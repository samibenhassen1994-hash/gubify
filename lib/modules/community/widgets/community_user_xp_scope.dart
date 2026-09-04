import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/community_user_xp_cache.dart';

class CommunityUserXpScope extends StatefulWidget {
  const CommunityUserXpScope({
    super.key,
    required this.userIds,
    required this.builder,
    this.cache,
  });

  final Set<String> userIds;
  final Widget Function(BuildContext context, Map<String, int> xpByUserId)
  builder;
  final CommunityUserXpCache? cache;

  @override
  State<CommunityUserXpScope> createState() => _CommunityUserXpScopeState();
}

class _CommunityUserXpScopeState extends State<CommunityUserXpScope> {
  CommunityUserXpLease? _lease;

  @override
  void initState() {
    super.initState();
    _acquire();
  }

  @override
  void didUpdateWidget(CommunityUserXpScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cache != widget.cache ||
        !setEquals(oldWidget.userIds, widget.userIds)) {
      final previous = _lease;
      _acquire();
      previous?.release();
    }
  }

  void _acquire() {
    _lease = (widget.cache ?? CommunityUserXpCache.instance).acquire(
      widget.userIds,
    );
  }

  @override
  void dispose() {
    _lease?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<Map<String, int>>(
    stream: _lease?.stream,
    initialData: const {},
    builder: (context, snapshot) =>
        widget.builder(context, snapshot.data ?? const {}),
  );
}
