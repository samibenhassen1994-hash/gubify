import 'package:flutter/material.dart';

import '../models/community_ask_model.dart';
import '../repositories/community_profile_ask_history_repository.dart';
import '../screens/community_ask_details_screen.dart';
import '../services/community_profile_ask_history_service.dart';
import '../services/community_user_xp_cache.dart';
import 'community_ask_card.dart';
import 'community_ask_expandable_section.dart';
import 'community_user_xp_scope.dart';

typedef CommunityProfileAsksLoader =
    Future<CommunityProfileAsksPage> Function({
      required CommunityAskStatus status,
      CommunityProfileAsksCursor? after,
    });

class CommunityProfileAsksSection extends StatefulWidget {
  const CommunityProfileAsksSection({
    super.key,
    required this.targetUserId,
    required this.knownCommunities,
    this.pageLoader,
    this.userXpCache,
    this.detailsBuilder,
  });

  final String targetUserId;
  final Map<String, String> knownCommunities;
  final CommunityProfileAsksLoader? pageLoader;
  final CommunityUserXpCache? userXpCache;
  final Widget Function(BuildContext, CommunityAskModel, String)?
  detailsBuilder;

  @override
  State<CommunityProfileAsksSection> createState() =>
      _CommunityProfileAsksSectionState();
}

class _CommunityProfileAsksSectionState
    extends State<CommunityProfileAsksSection> {
  late final CommunityProfileAsksLoader _loader;
  final _active = _ProfileSectionState();
  final _resolved = _ProfileSectionState();
  var _resolvedOpened = false;

  @override
  void initState() {
    super.initState();
    _loader =
        widget.pageLoader ??
        ({required status, after}) =>
            CommunityProfileAskHistoryService.instance.loadPage(
              targetUserId: widget.targetUserId,
              status: status,
              knownCommunities: widget.knownCommunities,
              after: after,
            );
    _load(_active, CommunityAskStatus.active);
  }

  Future<void> _load(
    _ProfileSectionState section,
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
          ..communityNames.addAll(page.communityNames)
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

  void _resolvedExpansion(bool expanded) {
    if (!expanded || _resolvedOpened) return;
    _resolvedOpened = true;
    _load(_resolved, CommunityAskStatus.resolved);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _cardSection('Active Asks', _active, CommunityAskStatus.active),
      const SizedBox(height: 12),
      CommunityAskExpandableSection(
        title: const Text(
          'Resolved Asks',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        onExpansionChanged: _resolvedExpansion,
        children: [_body(_resolved, CommunityAskStatus.resolved)],
      ),
    ],
  );

  Widget _cardSection(
    String title,
    _ProfileSectionState section,
    CommunityAskStatus status,
  ) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          _body(section, status),
        ],
      ),
    ),
  );

  Widget _body(_ProfileSectionState section, CommunityAskStatus status) {
    if (section.loading && section.items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(18),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (section.error && section.items.isEmpty) {
      return TextButton(
        onPressed: () => _load(section, status),
        child: const Text('Try again'),
      );
    }
    if (section.items.isEmpty && !section.hasMore) {
      return Padding(
        padding: const EdgeInsets.all(16),
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
      userIds: {widget.targetUserId},
      builder: (context, xpByUserId) => Column(
        children: [
          for (final ask in section.items) ...[
            SizedBox(
              key: ValueKey('community-context-${ask.askId}'),
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  section.communityNames[ask.communityId] ?? 'Community',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            CommunityAskCard(
              ask: ask,
              communityName:
                  section.communityNames[ask.communityId] ?? 'Community',
              authorXp: xpByUserId[ask.authorId],
              onTap: () => _openAsk(
                ask,
                section.communityNames[ask.communityId] ?? 'Community',
              ),
            ),
          ],
          if (section.hasMore)
            TextButton(
              onPressed: section.loading ? null : () => _load(section, status),
              child: Text(section.loading ? 'Loading…' : 'Load 5 more'),
            ),
        ],
      ),
    );
  }

  void _openAsk(CommunityAskModel ask, String communityName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            widget.detailsBuilder?.call(context, ask, communityName) ??
            CommunityAskDetailsScreen(
              ask: ask,
              communityName: communityName,
              membershipXpCache: widget.userXpCache,
            ),
      ),
    );
  }
}

class _ProfileSectionState {
  final List<CommunityAskModel> items = [];
  final Map<String, String> communityNames = {};
  CommunityProfileAsksCursor? cursor;
  bool loading = false;
  bool error = false;
  bool hasMore = true;
}
