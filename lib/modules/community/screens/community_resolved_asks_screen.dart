import 'package:flutter/material.dart';

import '../../../widgets/gub_screen_background.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../models/community_ask_model.dart';
import '../repositories/community_ask_repository.dart';
import '../services/community_ask_service.dart';
import '../services/community_user_xp_cache.dart';
import '../widgets/community_ask_card.dart';
import '../widgets/community_user_xp_scope.dart';
import 'community_ask_details_screen.dart';

class CommunityResolvedAsksScreen extends StatefulWidget {
  const CommunityResolvedAsksScreen({
    super.key,
    required this.communityId,
    required this.communityName,
    this.pageLoader,
    this.detailsBuilder,
    this.membershipXpCache,
  });

  final String communityId;
  final String communityName;
  final Future<CommunityResolvedAsksPage> Function(
    CommunityResolvedAsksCursor? after,
  )?
  pageLoader;
  final Widget Function(BuildContext context, CommunityAskModel ask)?
  detailsBuilder;
  final CommunityUserXpCache? membershipXpCache;

  @override
  State<CommunityResolvedAsksScreen> createState() =>
      _CommunityResolvedAsksScreenState();
}

class _CommunityResolvedAsksScreenState
    extends State<CommunityResolvedAsksScreen> {
  final List<CommunityAskModel> _asks = [];
  CommunityResolvedAsksCursor? _cursor;
  Object? _loadError;
  var _loading = true;
  var _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadNextPage();
  }

  Future<void> _loadNextPage() async {
    if ((_loading && _asks.isNotEmpty) || !_hasMore) {
      return;
    }
    setState(() => _loading = true);
    try {
      final page =
          await (widget.pageLoader?.call(_cursor) ??
              CommunityAskService.instance.loadResolvedAsksPage(
                communityId: widget.communityId,
                after: _cursor,
              ));
      if (!mounted) {
        return;
      }
      setState(() {
        _asks.addAll(page.asks);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _loadError = error);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => GubScreenBackground(
    variant: GubBackgroundAssignments.board,
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Resolved Asks'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: _loading && _asks.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null && _asks.isEmpty
            ? Center(
                child: FilledButton(
                  onPressed: _loadNextPage,
                  child: const Text('Try again'),
                ),
              )
            : _asks.isEmpty
            ? const _ResolvedAsksEmptyState()
            : CommunityUserXpScope(
                userIds: _asks.map((ask) => ask.authorId).toSet(),
                cache: widget.membershipXpCache,
                builder: (context, xpByUserId) => ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: _asks.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _asks.length) {
                      if (!_hasMore) {
                        return const SizedBox.shrink();
                      }
                      return Center(
                        child: OutlinedButton(
                          onPressed: _loading ? null : _loadNextPage,
                          child: Text(_loading ? 'Loading…' : 'Load 5 more'),
                        ),
                      );
                    }
                    final ask = _asks[index];
                    return CommunityAskCard(
                      key: ValueKey('resolved-ask-card-${ask.askId}'),
                      ask: ask,
                      communityName: widget.communityName,
                      authorXp: xpByUserId[ask.authorId],
                      onOpenAuthor: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => UserProfileScreen.community(
                            communityId: widget.communityId,
                            communityName: widget.communityName,
                            userId: ask.authorId,
                            communityUserXpCache: widget.membershipXpCache,
                          ),
                        ),
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (routeContext) =>
                              widget.detailsBuilder?.call(routeContext, ask) ??
                              CommunityAskDetailsScreen(
                                ask: ask,
                                communityName: widget.communityName,
                                membershipXpCache: widget.membershipXpCache,
                              ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    ),
  );
}

class _ResolvedAsksEmptyState extends StatelessWidget {
  const _ResolvedAsksEmptyState();

  @override
  Widget build(BuildContext context) => const Center(
    child: Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('No resolved Asks yet'),
      ),
    ),
  );
}
