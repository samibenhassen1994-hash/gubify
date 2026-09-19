import 'package:flutter/material.dart';

import '../models/community_leaderboard_model.dart';
import '../screens/global_best_answer_ranking_screen.dart';
import '../services/global_best_answer_ranking_service.dart';

class GlobalBestAnswerRankingPreview extends StatefulWidget {
  const GlobalBestAnswerRankingPreview({
    super.key,
    this.loadPage,
    this.onTap,
    this.compact = false,
  });

  final GlobalRankingLoader? loadPage;
  final VoidCallback? onTap;
  final bool compact;

  @override
  State<GlobalBestAnswerRankingPreview> createState() =>
      _GlobalBestAnswerRankingPreviewState();
}

class _GlobalBestAnswerRankingPreviewState
    extends State<GlobalBestAnswerRankingPreview> {
  late final Future<CommunityLeaderboardPage> _page =
      (widget.loadPage ?? GlobalBestAnswerRankingService.instance.loadPage)(
        after: null,
        limit: 5,
      );

  @override
  Widget build(BuildContext context) => InkWell(
    key: const Key('global-best-answer-ranking-preview'),
    onTap:
        widget.onTap ??
        () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => const GlobalBestAnswerRankingScreen(),
          ),
        ),
    borderRadius: BorderRadius.circular(18),
    child: Container(
      height: widget.compact ? 136 : 178,
      padding: EdgeInsets.all(widget.compact ? 4 : 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        image: const DecorationImage(
          image: AssetImage(
            'assets/backgrounds/sfondo_cosmico_tra_nuvole_e_stelle.png',
          ),
          fit: BoxFit.cover,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .25),
          borderRadius: BorderRadius.circular(14),
        ),
        child: FutureBuilder<CommunityLeaderboardPage>(
          future: _page,
          builder: (context, snapshot) {
            final items =
                snapshot.data?.members.take(5).toList() ??
                const <CommunityLeaderboardMember>[];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      'Best Answer Ranking',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: widget.compact ? 12 : 16,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      'Top 5 across all communities',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: widget.compact ? 8 : 11,
                      ),
                    ),
                  ),
                  Expanded(child: _buildContent(snapshot, items)),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );

  Widget _buildContent(
    AsyncSnapshot<CommunityLeaderboardPage> snapshot,
    List<CommunityLeaderboardMember> items,
  ) {
    Widget content;
    if (snapshot.connectionState != ConnectionState.done) {
      content = const Center(child: CircularProgressIndicator(strokeWidth: 2));
    } else if (snapshot.hasError) {
      content = const Center(
        child: Text(
          'Ranking unavailable',
          style: TextStyle(color: Colors.white70, fontSize: 10),
        ),
      );
    } else if (items.isEmpty) {
      content = const Center(
        child: Text(
          'No rankings yet.',
          style: TextStyle(color: Colors.white70, fontSize: 10),
        ),
      );
    } else {
      content = Align(
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < items.length; index++)
              SizedBox(
                height: widget.compact ? 17 : 18,
                child: _RankingPreviewRow(index: index, member: items[index]),
              ),
          ],
        ),
      );
    }
    return Stack(
      children: [
        content,
        Align(
          alignment: Alignment.bottomRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'View Top 100',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: widget.compact ? 8 : 10,
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.white70,
                size: widget.compact ? 12 : 14,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RankingPreviewRow extends StatelessWidget {
  const _RankingPreviewRow({required this.index, required this.member});

  final int index;
  final CommunityLeaderboardMember member;

  @override
  Widget build(BuildContext context) {
    final initial = member.displayName.trim().isEmpty
        ? '?'
        : member.displayName.trim()[0].toUpperCase();
    return Stack(
      key: Key('global-ranking-row-$index'),
      alignment: Alignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 33),
          child: Row(
            key: Key('global-ranking-main-group-$index'),
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 18, child: _rankIndicator(index)),
              CircleAvatar(
                radius: 6,
                backgroundImage: member.photoUrl == null
                    ? null
                    : NetworkImage(member.photoUrl!),
                child: member.photoUrl == null
                    ? Text(initial, style: const TextStyle(fontSize: 7))
                    : null,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  member.displayName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 0,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${member.bestAnswerCount}',
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _rankIndicator(int index) {
    const medalColors = [
      Color(0xFFFFD700),
      Color(0xFFC0C0C0),
      Color(0xFFCD7F32),
    ];
    if (index < medalColors.length) {
      return Icon(Icons.workspace_premium, color: medalColors[index], size: 13);
    }
    return Text(
      '#${index + 1}',
      style: const TextStyle(color: Colors.white, fontSize: 10),
    );
  }
}
