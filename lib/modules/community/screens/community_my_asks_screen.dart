import 'package:flutter/material.dart';

import '../../../widgets/gub_screen_background.dart';
import '../models/community_ask_model.dart';
import '../repositories/community_ask_repository.dart';
import '../services/community_ask_service.dart';
import '../services/community_user_xp_cache.dart';
import '../widgets/community_ask_card.dart';
import '../widgets/community_ask_expandable_section.dart';
import '../widgets/community_user_xp_scope.dart';
import 'community_ask_details_screen.dart';

typedef CommunityMyAsksLoader =
    Future<CommunityUserAsksPage> Function({
      required CommunityAskStatus status,
      CommunityUserAsksCursor? after,
    });

class CommunityMyAsksScreen extends StatefulWidget {
  const CommunityMyAsksScreen({
    super.key,
    required this.communityId,
    required this.communityName,
    this.pageLoader,
    this.userXpCache,
  });

  final String communityId;
  final String communityName;
  final CommunityMyAsksLoader? pageLoader;
  final CommunityUserXpCache? userXpCache;

  @override
  State<CommunityMyAsksScreen> createState() => _CommunityMyAsksScreenState();
}

class _CommunityMyAsksScreenState extends State<CommunityMyAsksScreen> {
  late final CommunityMyAsksLoader _loader;
  final _active = _AskSectionState();
  final _resolved = _AskSectionState();
  var _resolvedOpened = false;

  @override
  void initState() {
    super.initState();
    _loader =
        widget.pageLoader ??
        ({required status, after}) =>
            CommunityAskService.instance.loadMyAsksPage(
              communityId: widget.communityId,
              status: status,
              after: after,
            );
    _load(_active, CommunityAskStatus.active);
  }

  Future<void> _load(
    _AskSectionState section,
    CommunityAskStatus status,
  ) async {
    if (section.loading || !section.hasMore) return;
    setState(() {
      section.loading = true;
      section.error = false;
    });
    try {
      final page = await _loader(status: status, after: section.cursor);
      if (!mounted) return;
      setState(() {
        section
          ..items.addAll(page.asks)
          ..cursor = page.nextCursor
          ..hasMore = page.hasMore
          ..loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        section
          ..loading = false
          ..error = true;
      });
    }
  }

  void _openResolved(bool expanded) {
    if (!expanded || _resolvedOpened) return;
    _resolvedOpened = true;
    _load(_resolved, CommunityAskStatus.resolved);
  }

  void _openAsk(CommunityAskModel ask) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityAskDetailsScreen(
          ask: ask,
          communityName: widget.communityName,
          membershipXpCache: widget.userXpCache,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => GubScreenBackground(
    variant: GubBackgroundAssignments.myGubs,
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('My Asks'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _section(
            title: 'Active Asks',
            state: _active,
            status: CommunityAskStatus.active,
          ),
          const SizedBox(height: 12),
          CommunityAskExpandableSection(
            tileKey: const ValueKey('my-resolved-asks-section'),
            title: const Text(
              'Resolved Asks',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            onExpansionChanged: _openResolved,
            children: [_sectionBody(_resolved, CommunityAskStatus.resolved)],
          ),
        ],
      ),
    ),
  );

  Widget _section({
    required String title,
    required _AskSectionState state,
    required CommunityAskStatus status,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 10),
          _sectionBody(state, status),
        ],
      ),
    ),
  );

  Widget _sectionBody(_AskSectionState state, CommunityAskStatus status) {
    if (state.loading && state.items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.error && state.items.isEmpty) {
      return Center(
        child: TextButton(
          onPressed: () => _load(state, status),
          child: const Text('Try again'),
        ),
      );
    }
    if (state.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          status == CommunityAskStatus.active
              ? 'No active Asks'
              : 'No resolved Asks',
          textAlign: TextAlign.center,
        ),
      );
    }
    return CommunityUserXpScope(
      cache: widget.userXpCache,
      userIds: state.items.map((ask) => ask.authorId).toSet(),
      builder: (context, xpByUserId) => Column(
        children: [
          for (final ask in state.items)
            CommunityAskCard(
              ask: ask,
              authorXp: xpByUserId[ask.authorId],
              onTap: () => _openAsk(ask),
            ),
          if (state.hasMore)
            TextButton(
              onPressed: state.loading ? null : () => _load(state, status),
              child: Text(state.loading ? 'Loading…' : 'Load 5 more'),
            ),
        ],
      ),
    );
  }
}

class _AskSectionState {
  final List<CommunityAskModel> items = [];
  CommunityUserAsksCursor? cursor;
  bool loading = false;
  bool error = false;
  bool hasMore = true;
}
