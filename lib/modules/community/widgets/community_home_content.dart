import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../widgets/gub_content_card.dart';
import '../models/community_ask_model.dart';
import '../models/community_model.dart';
import '../images/community_image_view.dart';
import '../services/community_ask_service.dart';
import '../services/community_service.dart';
import '../screens/community_asks_screen.dart';
import '../screens/community_resolved_asks_screen.dart';
import '../screens/community_my_asks_screen.dart';
import '../screens/community_leaderboard_screen.dart';
import 'community_chat_view.dart';
import 'community_create_ask_card.dart';

enum _CommunityHomePanel { none, community, asks, createAsk }

class CommunityHomeContent extends StatefulWidget {
  final CommunityModel community;
  final bool isKeyboardOpen;
  final bool? isOwner;
  final Widget? chatView;
  final VoidCallback? onOpenAsks;
  final VoidCallback? onOpenResolvedAsks;
  final VoidCallback? onOpenMyAsks;
  final VoidCallback? onOpenLeaderboard;
  final CommunityDirectAskSubmit? onCreateDirectAsk;

  const CommunityHomeContent({
    super.key,
    required this.community,
    required this.isKeyboardOpen,
    this.isOwner,
    this.chatView,
    this.onOpenAsks,
    this.onOpenResolvedAsks,
    this.onOpenMyAsks,
    this.onOpenLeaderboard,
    this.onCreateDirectAsk,
  });

  @override
  State<CommunityHomeContent> createState() => _CommunityHomeContentState();
}

class _CommunityHomeContentState extends State<CommunityHomeContent> {
  _CommunityHomePanel _panel = _CommunityHomePanel.none;

  @override
  void didUpdateWidget(CommunityHomeContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isKeyboardOpen &&
        !oldWidget.isKeyboardOpen &&
        _panel != _CommunityHomePanel.createAsk) {
      _panel = _CommunityHomePanel.none;
    }
  }

  void _toggleCommunity() {
    setState(() {
      _panel = _panel == _CommunityHomePanel.community
          ? _CommunityHomePanel.none
          : _CommunityHomePanel.community;
    });
  }

  void _handleAsks() {
    if (_panel == _CommunityHomePanel.asks) {
      setState(() => _panel = _CommunityHomePanel.none);
      return;
    }
    setState(() => _panel = _CommunityHomePanel.asks);
  }

  void _openActiveAsks() {
    final callback = widget.onOpenAsks;
    if (callback != null) {
      callback();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityAsksScreen(
          communityId: widget.community.communityId,
          communityName: widget.community.name,
          currentUserId: FirebaseAuth.instance.currentUser?.uid,
        ),
      ),
    );
  }

  void _openResolvedAsks() {
    final callback = widget.onOpenResolvedAsks;
    if (callback != null) {
      callback();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityResolvedAsksScreen(
          communityId: widget.community.communityId,
          communityName: widget.community.name,
        ),
      ),
    );
  }

  void _openMyAsks() {
    final callback = widget.onOpenMyAsks;
    if (callback != null) {
      callback();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityMyAsksScreen(
          communityId: widget.community.communityId,
          communityName: widget.community.name,
        ),
      ),
    );
  }

  void _openLeaderboard() {
    final callback = widget.onOpenLeaderboard;
    if (callback != null) {
      callback();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityLeaderboardScreen(
          communityId: widget.community.communityId,
          communityName: widget.community.name,
        ),
      ),
    );
  }

  void _toggleCreateAsk() {
    setState(() {
      _panel = _panel == _CommunityHomePanel.createAsk
          ? _CommunityHomePanel.none
          : _CommunityHomePanel.createAsk;
    });
  }

  Future<void> _createDirectAsk({
    required String text,
    required CommunityAskType type,
  }) async {
    final callback = widget.onCreateDirectAsk;
    if (callback != null) {
      await callback(text: text, type: type);
      return;
    }
    await CommunityAskService.instance.createDirectAsk(
      communityId: widget.community.communityId,
      text: text,
      type: type,
    );
  }

  void _onDirectAskCreated() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _panel = _CommunityHomePanel.none);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Ask created.')));
  }

  @override
  Widget build(BuildContext context) {
    final community = widget.community;
    final memberLabel = community.memberCount == 1 ? 'member' : 'members';
    final isOwner =
        widget.isOwner ??
        CommunityService.instance.isCurrentUserOwner(community);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            widget.isKeyboardOpen ? 8 : 72,
            24,
            6,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _HomeHeaderAction(
                  key: const ValueKey('community-header-action'),
                  label: 'Community',
                  selected: _panel == _CommunityHomePanel.community,
                  onTap: _toggleCommunity,
                  child: CommunityImageView(
                    imageUrl: community.imageUrl,
                    size: 44,
                  ),
                ),
                const SizedBox(width: 10),
                _HomeHeaderAction(
                  key: const ValueKey('asks-header-action'),
                  label: 'Asks',
                  selected: _panel == _CommunityHomePanel.asks,
                  onTap: _handleAsks,
                  child: const Icon(
                    Icons.view_list_rounded,
                    color: Color(0xFF2563EB),
                    size: 25,
                  ),
                ),
                const SizedBox(width: 10),
                _HomeHeaderAction(
                  key: const ValueKey('my-asks-header-action'),
                  label: 'My Asks',
                  selected: false,
                  onTap: _openMyAsks,
                  child: const Icon(
                    Icons.person_search_rounded,
                    color: Color(0xFF2563EB),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 10),
                _HomeHeaderAction(
                  key: const ValueKey('create-ask-header-action'),
                  label: 'Create',
                  selected: _panel == _CommunityHomePanel.createAsk,
                  onTap: _toggleCreateAsk,
                  child: const Icon(
                    Icons.add_rounded,
                    color: Color(0xFF2563EB),
                    size: 27,
                  ),
                ),
                const SizedBox(width: 10),
                _HomeHeaderAction(
                  key: const ValueKey('leaderboard-header-action'),
                  label: 'Leaderboard',
                  selected: false,
                  onTap: _openLeaderboard,
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: Color(0xFF2563EB),
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!widget.isKeyboardOpen && _panel == _CommunityHomePanel.community)
          _CommunityInfoPanel(
            community: community,
            memberLabel: memberLabel,
            isOwner: isOwner,
          ),
        if (!widget.isKeyboardOpen && _panel == _CommunityHomePanel.asks)
          _AsksSummaryPanel(
            onOpenActiveAsks: _openActiveAsks,
            onOpenResolvedAsks: _openResolvedAsks,
          ),
        if (_panel == _CommunityHomePanel.createAsk)
          CommunityCreateAskCard(
            onCreate: _createDirectAsk,
            onCreated: _onDirectAskCreated,
          ),
        Expanded(
          child:
              widget.chatView ??
              CommunityChatView(
                communityId: community.communityId,
                communityName: community.name,
              ),
        ),
      ],
    );
  }
}

class _HomeHeaderAction extends StatelessWidget {
  const _HomeHeaderAction({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF475569),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? const Color(0xFF2563EB)
                      : const Color(0xFFDBEAFE),
                  width: selected ? 2 : 1,
                ),
              ),
              alignment: Alignment.center,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityInfoPanel extends StatelessWidget {
  const _CommunityInfoPanel({
    required this.community,
    required this.memberLabel,
    required this.isOwner,
  });

  final CommunityModel community;
  final String memberLabel;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: SizedBox(
        height: 84,
        child: GubContentCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              CommunityImageView(imageUrl: community.imageUrl, size: 56),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 28,
                      child: FittedBox(
                        alignment: Alignment.centerLeft,
                        fit: BoxFit.scaleDown,
                        child: Text(
                          community.name,
                          maxLines: 1,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontSize: 25,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      alignment: Alignment.centerLeft,
                      fit: BoxFit.scaleDown,
                      child: Row(
                        children: [
                          _CommunityChip(
                            icon: Icons.people_outline,
                            label: '${community.memberCount} $memberLabel',
                          ),
                          const SizedBox(width: 4),
                          _CommunityChip(
                            icon: Icons.workspace_premium_outlined,
                            label: isOwner ? 'Owner' : 'Member',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AsksSummaryPanel extends StatelessWidget {
  const _AsksSummaryPanel({
    required this.onOpenActiveAsks,
    required this.onOpenResolvedAsks,
  });

  final VoidCallback onOpenActiveAsks;
  final VoidCallback onOpenResolvedAsks;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Column(
        children: [
          _AskMenuCard(
            key: const ValueKey('active-asks-summary-card'),
            label: 'Active Asks',
            onTap: onOpenActiveAsks,
          ),
          const SizedBox(height: 8),
          _AskMenuCard(
            key: const ValueKey('resolved-asks-summary-card'),
            label: 'Resolved Asks',
            onTap: onOpenResolvedAsks,
          ),
        ],
      ),
    );
  }
}

class _AskMenuCard extends StatelessWidget {
  const _AskMenuCard({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Open $label',
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: GubContentCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const Text(
              'Tap to view',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
            const SizedBox(width: 3),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Color(0xFF64748B),
            ),
          ],
        ),
      ),
    ),
  );
}

class CommunityStateMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? details;

  const CommunityStateMessage({
    super.key,
    required this.icon,
    required this.message,
    this.details,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GubContentCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44, color: const Color(0xFF2563EB)),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              if (details != null) ...[
                const SizedBox(height: 8),
                Text(
                  details!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CommunityChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CommunityChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF2563EB)),
          const SizedBox(width: 3),
          Text(
            label,
            maxLines: 1,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
