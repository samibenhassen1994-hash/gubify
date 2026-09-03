import 'package:flutter/material.dart';

import '../../profile/screens/user_profile_screen.dart';
import '../leveling/community_level.dart';
import '../models/community_leaderboard_model.dart';
import '../services/community_leaderboard_service.dart';
import '../services/community_user_xp_cache.dart';
import '../widgets/community_leaderboard_trophy.dart';
import '../widgets/community_level_avatar.dart';
import '../widgets/community_user_xp_scope.dart';

typedef CommunityLeaderboardLoader = Future<CommunityLeaderboardPage> Function({
  Object? after,
  required int limit,
});

class CommunityLeaderboardScreen extends StatefulWidget {
  const CommunityLeaderboardScreen({
    super.key,
    required this.communityId,
    required this.communityName,
    this.loadTopLevel,
    this.loadTopAnswers,
    this.profileBuilder,
    this.userXpCache,
  });

  final String communityId;
  final String communityName;
  final CommunityLeaderboardLoader? loadTopLevel;
  final CommunityLeaderboardLoader? loadTopAnswers;
  final Widget Function(BuildContext, CommunityLeaderboardMember)? profileBuilder;
  final CommunityUserXpCache? userXpCache;

  @override
  State<CommunityLeaderboardScreen> createState() =>
      _CommunityLeaderboardScreenState();
}

class _CommunityLeaderboardScreenState
    extends State<CommunityLeaderboardScreen> {
  final Set<int> _openedTabs = {0};
  late final _level = _LeaderboardTabState(
    loader: widget.loadTopLevel ??
        ({after, required limit}) => CommunityLeaderboardService.instance
            .loadTopLevel(
              communityId: widget.communityId,
              after: after,
              limit: limit,
            ),
  );
  late final _answers = _LeaderboardTabState(
    loader: widget.loadTopAnswers ??
        ({after, required limit}) => CommunityLeaderboardService.instance
            .loadTopAnswers(
              communityId: widget.communityId,
              after: after,
              limit: limit,
            ),
  );

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/backgrounds/background_leaderboard.png',
              fit: BoxFit.cover,
            ),
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: const Text('Leaderboard'),
              bottom: TabBar(
                onTap: (index) => setState(() => _openedTabs.add(index)),
                tabs: const [Tab(text: 'Top Level'), Tab(text: 'Top Answers')],
              ),
            ),
            body: TabBarView(
              children: [
                _LeaderboardList(
                  state: _level,
                  userXpCache: widget.userXpCache,
                  valueBuilder: (member, xp) {
                    final level = CommunityLevel.fromXp(xp);
                    return 'Lv ${level.level} · $xp XP';
                  },
                  onOpen: _openProfile,
                ),
                if (_openedTabs.contains(1))
                  _LeaderboardList(
                    state: _answers,
                    userXpCache: widget.userXpCache,
                    valueBuilder: (member, _) => member.bestAnswerCount == 1
                        ? '1 Best Answer'
                        : '${member.bestAnswerCount} Best Answers',
                    onOpen: _openProfile,
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openProfile(CommunityLeaderboardMember member) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => widget.profileBuilder?.call(context, member) ??
            UserProfileScreen.community(
              communityId: widget.communityId,
              communityName: widget.communityName,
              userId: member.userId,
            ),
      ),
    );
  }
}

class _LeaderboardTabState {
  _LeaderboardTabState({required this.loader});
  final CommunityLeaderboardLoader loader;
}

class _LeaderboardList extends StatefulWidget {
  const _LeaderboardList({
    required this.state,
    required this.valueBuilder,
    required this.onOpen,
    required this.userXpCache,
  });
  final _LeaderboardTabState state;
  final String Function(CommunityLeaderboardMember, int) valueBuilder;
  final ValueChanged<CommunityLeaderboardMember> onOpen;
  final CommunityUserXpCache? userXpCache;

  @override
  State<_LeaderboardList> createState() => _LeaderboardListState();
}

class _LeaderboardListState extends State<_LeaderboardList> {
  final _members = <CommunityLeaderboardMember>[];
  Object? _cursor;
  var _loading = false;
  var _hasMore = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading || !_hasMore || _members.length >= 10) return;
    setState(() { _loading = true; _error = null; });
    try {
      final page = await widget.state.loader(after: _cursor, limit: 5);
      if (!mounted) return;
      setState(() {
        _members.addAll(page.members.take(10 - _members.length));
        _cursor = page.nextCursor;
        _hasMore = page.hasMore && _members.length < 10;
      });
      (widget.userXpCache ?? CommunityUserXpCache.instance).cacheLoaded({
        for (final member in page.members) member.userId: member.xp,
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _members.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _members.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("Couldn't load leaderboard."),
          const SizedBox(height: 8),
          FilledButton(onPressed: _load, child: const Text('Try again')),
        ]),
      );
    }
    if (_members.isEmpty) return const Center(child: Text('No ranked members yet.'));
    return CommunityUserXpScope(
      userIds: _members.map((member) => member.userId).toSet(),
      cache: widget.userXpCache,
      builder: (context, xpByUserId) => _buildList(xpByUserId),
    );
  }

  Widget _buildList(Map<String, int> xpByUserId) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _members.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _members.length) {
          return Center(
            child: TextButton(
              onPressed: _loading ? null : _load,
              child: Text(_loading ? 'Loading...' : 'Load 5 more'),
            ),
          );
        }
        final member = _members[index];
        final xp = xpByUserId[member.userId] ?? member.xp;
        final rank = index + 1;
        return Card(
          child: ListTile(
            onTap: () => widget.onOpen(member),
            leading: Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 28, child: Text('#$rank')),
              CommunityLeaderboardTrophy(rank: rank),
              const SizedBox(width: 6),
              CommunityLevelAvatar(
                displayName: member.displayName,
                userId: member.userId,
                photoUrl: member.photoUrl,
                xp: xp,
              ),
            ]),
            title: Text(member.displayName),
            subtitle: Text(widget.valueBuilder(member, xp)),
          ),
        );
      },
    );
  }
}
