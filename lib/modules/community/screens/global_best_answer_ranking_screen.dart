import 'package:flutter/material.dart';

import '../models/community_leaderboard_model.dart';
import '../services/global_best_answer_ranking_service.dart';

typedef GlobalRankingLoader =
    Future<CommunityLeaderboardPage> Function({
      Object? after,
      required int limit,
    });

class GlobalBestAnswerRankingScreen extends StatefulWidget {
  const GlobalBestAnswerRankingScreen({super.key, this.loadPage});

  final GlobalRankingLoader? loadPage;

  @override
  State<GlobalBestAnswerRankingScreen> createState() =>
      _GlobalBestAnswerRankingScreenState();
}

class _GlobalBestAnswerRankingScreenState
    extends State<GlobalBestAnswerRankingScreen> {
  final _members = <CommunityLeaderboardMember>[];
  Object? _cursor;
  var _loading = true;
  var _hasMore = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load(initial: true);
  }

  Future<void> _load({bool initial = false}) async {
    if (!initial &&
        (_loading ||
            !_hasMore ||
            _members.length >= GlobalBestAnswerRankingService.maximumEntries)) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page =
          await (widget.loadPage ??
              GlobalBestAnswerRankingService.instance.loadPage)(
            after: initial ? null : _cursor,
            limit: GlobalBestAnswerRankingService.pageSize,
          );
      if (!mounted) return;
      setState(() {
        if (initial) _members.clear();
        final remaining =
            GlobalBestAnswerRankingService.maximumEntries - _members.length;
        _members.addAll(page.members.take(remaining));
        _cursor = page.nextCursor;
        _hasMore =
            page.hasMore &&
            page.members.length == GlobalBestAnswerRankingService.pageSize &&
            _members.length < GlobalBestAnswerRankingService.maximumEntries;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage(
            'assets/backgrounds/sfondo_cosmico_incantato_viola_e_oro.png',
          ),
          fit: BoxFit.cover,
        ),
      ),
      child: ColoredBox(
        color: Colors.black26,
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                centerTitle: true,
                title: const Text('Best Answer Ranking'),
              ),
              const Text(
                'Top contributors across all communities',
                style: TextStyle(color: Colors.white70),
              ),
              const Padding(
                padding: EdgeInsets.all(12),
                child: Chip(label: Text('Answers')),
              ),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _body() {
    if (_loading && _members.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _members.isEmpty) {
      return Center(
        child: FilledButton(
          onPressed: () => _load(initial: true),
          child: const Text('Retry'),
        ),
      );
    }
    if (_members.isEmpty) {
      return const Center(
        child: Text('No rankings yet.', style: TextStyle(color: Colors.white)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _members.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _members.length) {
          return TextButton(
            onPressed: _loading ? null : () => _load(),
            child: Text(_loading ? 'Loading...' : 'Load 10 more'),
          );
        }
        final member = _members[index];
        final initial = member.displayName.trim().isEmpty
            ? '?'
            : member.displayName.trim()[0].toUpperCase();
        return Card(
          color: Colors.black.withValues(alpha: index < 3 ? .45 : .30),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: member.photoUrl == null
                  ? null
                  : NetworkImage(member.photoUrl!),
              child: member.photoUrl == null ? Text(initial) : null,
            ),
            title: Text(
              member.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              '${member.bestAnswerCount} Best Answers',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            trailing: _rankIndicator(index),
          ),
        );
      },
    );
  }

  Widget _rankIndicator(int index) {
    const medalColors = [
      Color(0xFFFFD700),
      Color(0xFFC0C0C0),
      Color(0xFFCD7F32),
    ];
    if (index < medalColors.length) {
      return Icon(Icons.workspace_premium, color: medalColors[index], size: 26);
    }
    return Text(
      '#${index + 1}',
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    );
  }
}
