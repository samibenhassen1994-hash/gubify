import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../config/app_limits.dart';
import '../../../widgets/gub_screen_background.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../models/community_ask_answer_model.dart';
import '../models/community_ask_model.dart';
import '../repositories/community_ask_answer_repository.dart';
import '../repositories/community_ask_repository.dart';
import '../services/community_ask_answer_service.dart';
import '../services/community_ask_service.dart';
import '../services/community_user_xp_cache.dart';
import '../widgets/community_ask_card.dart';
import '../widgets/community_level_avatar.dart';
import '../widgets/community_user_xp_scope.dart';

class CommunityAskDetailsScreen extends StatefulWidget {
  const CommunityAskDetailsScreen({
    super.key,
    required this.ask,
    required this.communityName,
    this.askStream,
    this.answersStream,
    this.currentUserId,
    this.onCreateAnswer,
    this.onSelectBestAnswer,
    this.onEditAnswer,
    this.onEditAsk,
    this.onDeleteAnswer,
    this.onDeleteAsk,
    this.onOpenProfile,
    this.membershipXpCache,
    this.answerService,
  });

  final CommunityAskModel ask;
  final String communityName;
  final Stream<CommunityAskModel?>? askStream;
  final Stream<List<CommunityAskAnswerModel>>? answersStream;
  final String? currentUserId;
  final Future<void> Function(String text)? onCreateAnswer;
  final Future<void> Function(CommunityAskAnswerModel answer)?
  onSelectBestAnswer;
  final Future<void> Function(CommunityAskAnswerModel answer, String text)?
  onEditAnswer;
  final Future<void> Function(String text)? onEditAsk;
  final Future<void> Function(CommunityAskAnswerModel answer)? onDeleteAnswer;
  final Future<void> Function()? onDeleteAsk;
  final void Function(String userId)? onOpenProfile;
  final CommunityUserXpCache? membershipXpCache;
  final CommunityAskAnswerService? answerService;

  @override
  State<CommunityAskDetailsScreen> createState() =>
      _CommunityAskDetailsScreenState();
}

class _CommunityAskDetailsScreenState extends State<CommunityAskDetailsScreen> {
  late final Stream<CommunityAskModel?> _askStream;
  late final Stream<List<CommunityAskAnswerModel>> _answersStream;
  CommunityAskAnswerService? _answerService;
  CommunityAskModel? _locallyResolvedAsk;
  String? _selectingBestAnswerId;

  CommunityAskAnswerService get _service => _answerService ??=
      widget.answerService ??
      (widget.membershipXpCache == null
          ? CommunityAskAnswerService.instance
          : CommunityAskAnswerService.withXpCache(widget.membershipXpCache!));

  @override
  void initState() {
    super.initState();
    _askStream =
        widget.askStream ??
        CommunityAskRepository.instance.watchAsk(
          communityId: widget.ask.communityId,
          askId: widget.ask.askId,
        );
    _answersStream =
        widget.answersStream ??
        _service.watchAnswers(
          communityId: widget.ask.communityId,
          askId: widget.ask.askId,
        );
  }

  Future<void> _create(CommunityAskModel ask, String text) async {
    if (widget.onCreateAnswer != null) {
      return widget.onCreateAnswer!(text);
    }
    await _service.createAnswer(
      communityId: ask.communityId,
      askId: ask.askId,
      askAuthorId: ask.authorId,
      text: text,
      askStatus: ask.status,
    );
  }

  Future<void> _select(
    CommunityAskModel ask,
    CommunityAskAnswerModel answer,
  ) async {
    if (_selectingBestAnswerId != null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Select best answer?'),
        content: const Text('This will resolve the ask and close the topic.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Select best'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _selectingBestAnswerId = answer.answerId);
    try {
      CommunityAskResolution? result;
      if (widget.onSelectBestAnswer != null) {
        await widget.onSelectBestAnswer!(answer);
      } else {
        result = await _service.selectBestAnswer(ask: ask, answer: answer);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _locallyResolvedAsk = CommunityAskModel(
          askId: ask.askId,
          communityId: ask.communityId,
          authorId: ask.authorId,
          authorDisplayName: ask.authorDisplayName,
          type: ask.type,
          text: ask.text,
          sourceMessageId: ask.sourceMessageId,
          createdAt: ask.createdAt,
          updatedAt: ask.updatedAt,
          status: CommunityAskStatus.resolved,
          bestAnswerId: result?.bestAnswerId ?? answer.answerId,
          bestAnswerAuthorId: result?.bestAnswerAuthorId ?? answer.authorId,
          resolvedAt: ask.resolvedAt,
          xpAwarded: true,
        );
        _selectingBestAnswerId = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error is CommunityAskWinnerNotMemberException
          ? 'This member is no longer eligible for a Best Answer.'
          : 'Unable to select this Best Answer.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted && _selectingBestAnswerId == answer.answerId) {
        setState(() => _selectingBestAnswerId = null);
      }
    }
  }

  void _openProfile(String userId) {
    if (widget.onOpenProfile != null) {
      widget.onOpenProfile!(userId);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen.community(
          communityId: widget.ask.communityId,
          communityName: widget.communityName,
          userId: userId,
          communityUserXpCache: widget.membershipXpCache,
        ),
      ),
    );
  }

  Future<void> _deleteAsk(CommunityAskModel ask) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Ask?'),
        content: const Text(
          'This will permanently remove this Ask and its Answers.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      if (widget.onDeleteAsk != null) {
        await widget.onDeleteAsk!();
      } else {
        await CommunityAskService.instance.deleteAsk(ask);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to delete this Ask.')),
        );
      }
    }
  }

  Future<void> _deleteAnswer(
    CommunityAskModel ask,
    CommunityAskAnswerModel answer,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Answer?'),
        content: const Text('This Answer will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      if (widget.onDeleteAnswer != null) {
        await widget.onDeleteAnswer!(answer);
      } else {
        await _service.deleteAnswer(ask: ask, answer: answer);
      }
    } on CommunityBestAnswerProtectedException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The selected Best Answer cannot be deleted.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to delete this Answer.')),
        );
      }
    }
  }

  Future<void> _editAnswer(
    CommunityAskModel ask,
    CommunityAskAnswerModel answer,
  ) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _EditAnswerDialog(initialText: answer.text),
    );
    if (text == null || !mounted) return;
    try {
      if (widget.onEditAnswer != null) {
        await widget.onEditAnswer!(answer, text);
      } else {
        await _service.editAnswer(ask: ask, answer: answer, text: text);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to edit this Answer.')),
        );
      }
    }
  }

  Future<void> _editAsk(CommunityAskModel ask) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _EditAskDialog(initialText: ask.text),
    );
    if (text == null || !mounted) return;
    try {
      if (widget.onEditAsk != null) {
        await widget.onEditAsk!(text);
      } else {
        await CommunityAskService.instance.editAsk(ask: ask, text: text);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to edit this Ask.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => GubScreenBackground(
    variant: GubBackgroundAssignments.board,
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Ask'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<CommunityAskModel?>(
          stream: _askStream,
          initialData: widget.ask,
          builder: (context, askSnapshot) {
            final streamedAsk = askSnapshot.data;
            final localAsk = _locallyResolvedAsk;
            final ask =
                localAsk != null &&
                    (streamedAsk == null ||
                        streamedAsk.status != CommunityAskStatus.resolved ||
                        streamedAsk.bestAnswerId != localAsk.bestAnswerId)
                ? localAsk
                : streamedAsk;
            if (ask == null) {
              return const Center(child: Text('This Ask is unavailable.'));
            }
            return StreamBuilder<List<CommunityAskAnswerModel>>(
              stream: _answersStream,
              initialData: const [],
              builder: (context, answerSnapshot) {
                final answers = answerSnapshot.data ?? const [];
                CommunityAskAnswerModel? best;
                for (final answer in answers) {
                  if (answer.answerId == ask.bestAnswerId) {
                    best = answer;
                  }
                }
                final remaining = answers
                    .where((answer) => answer.answerId != best?.answerId)
                    .toList(growable: false);
                final uid =
                    widget.currentUserId ??
                    FirebaseAuth.instance.currentUser?.uid ??
                    '';
                final currentUserHasAnswer = answers.any(
                  (answer) => answer.authorId == uid,
                );
                final isSelectingBest = _selectingBestAnswerId != null;
                return CommunityUserXpScope(
                  userIds: {
                    ask.authorId,
                    ...answers.map((answer) => answer.authorId),
                  },
                  cache: widget.membershipXpCache,
                  builder: (context, xpByUserId) => ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    children: [
                      _AskThreadCard(
                        ask: ask,
                        authorXp: xpByUserId[ask.authorId],
                        onOpenAuthor: () => _openProfile(ask.authorId),
                        canEdit:
                            ask.status == CommunityAskStatus.active &&
                            uid == ask.authorId &&
                            !isSelectingBest,
                        onEdit: () => _editAsk(ask),
                        canDelete: uid == ask.authorId && !isSelectingBest,
                        onDelete: () => _deleteAsk(ask),
                      ),
                      const SizedBox(height: 18),
                      const Align(
                        alignment: Alignment.center,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.all(Radius.circular(14)),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 9,
                            ),
                            child: Text(
                              'Answers',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (best case final bestAnswer?) ...[
                        _AnswerCard(
                          answer: bestAnswer,
                          authorXp: xpByUserId[bestAnswer.authorId],
                          isBest: true,
                          canSelect: false,
                          onSelect: null,
                          canEdit: false,
                          canDelete: false,
                          onOpenAuthor: () => _openProfile(bestAnswer.authorId),
                          onEdit: null,
                          onDelete: null,
                        ),
                        const SizedBox(height: 10),
                      ],
                      for (final answer in remaining) ...[
                        _AnswerCard(
                          answer: answer,
                          authorXp: xpByUserId[answer.authorId],
                          isBest: false,
                          canSelect:
                              ask.status == CommunityAskStatus.active &&
                              uid == ask.authorId &&
                              answer.authorId != ask.authorId,
                          isSelecting:
                              _selectingBestAnswerId == answer.answerId,
                          selectionLocked: isSelectingBest,
                          onSelect: () => _select(ask, answer),
                          canEdit:
                              ask.status == CommunityAskStatus.active &&
                              uid == answer.authorId &&
                              uid == answer.answerId &&
                              answer.updatedAt == null &&
                              !isSelectingBest,
                          canDelete:
                              !(ask.status == CommunityAskStatus.resolved &&
                                  answer.answerId == ask.bestAnswerId) &&
                              (uid == answer.authorId || uid == ask.authorId) &&
                              !isSelectingBest,
                          onOpenAuthor: () => _openProfile(answer.authorId),
                          onEdit: () => _editAnswer(ask, answer),
                          onDelete: () => _deleteAnswer(ask, answer),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (ask.status == CommunityAskStatus.active &&
                          uid != ask.authorId &&
                          !currentUserHasAnswer)
                        _AnswerComposer(onSubmit: (text) => _create(ask, text))
                      else if (ask.status == CommunityAskStatus.active &&
                          uid != ask.authorId)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Text('You have already answered this Ask.'),
                          ),
                        )
                      else if (ask.status == CommunityAskStatus.active)
                        const SizedBox.shrink()
                      else
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Text(
                              'This ask has been resolved.',
                              style: TextStyle(
                                color: Color(0xFF047857),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    ),
  );
}

class _EditAnswerDialog extends StatefulWidget {
  const _EditAnswerDialog({required this.initialText});

  final String initialText;

  @override
  State<_EditAnswerDialog> createState() => _EditAnswerDialogState();
}

class _EditAnswerDialogState extends State<_EditAnswerDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit Answer'),
    content: TextField(
      controller: _controller,
      minLines: 2,
      maxLines: 4,
      maxLength: AppLimits.communityMessageMaxLength,
      autofocus: true,
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: const Text('Save'),
      ),
    ],
  );
}

class _EditAskDialog extends StatefulWidget {
  const _EditAskDialog({required this.initialText});

  final String initialText;

  @override
  State<_EditAskDialog> createState() => _EditAskDialogState();
}

class _EditAskDialogState extends State<_EditAskDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit Ask'),
    content: TextField(
      controller: _controller,
      minLines: 2,
      maxLines: 4,
      maxLength: AppLimits.communityMessageMaxLength,
      autofocus: true,
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: const Text('Save'),
      ),
    ],
  );
}

class _AskThreadCard extends StatelessWidget {
  const _AskThreadCard({
    required this.ask,
    required this.authorXp,
    required this.onOpenAuthor,
    required this.canEdit,
    required this.onEdit,
    required this.canDelete,
    required this.onDelete,
  });
  final CommunityAskModel ask;
  final int? authorXp;
  final VoidCallback onOpenAuthor;
  final bool canEdit;
  final VoidCallback onEdit;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CommunityAskTypeBadge(type: ask.type),
              const Spacer(),
              Text(
                ask.status == CommunityAskStatus.active ? 'Active' : 'Resolved',
                style: const TextStyle(
                  color: Color(0xFF059669),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          InkWell(
            key: ValueKey('ask-detail-author-${ask.askId}'),
            onTap: onOpenAuthor,
            child: Row(
              children: [
                CommunityLevelAvatar(
                  displayName: ask.authorDisplayName,
                  userId: ask.authorId,
                  photoUrl: null,
                  radius: 17,
                  xp: authorXp,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ask.authorDisplayName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(ask.text, style: const TextStyle(fontSize: 16, height: 1.45)),
          const SizedBox(height: 12),
          Text(
            ask.updatedAt == null
                ? formatCommunityAskDate(ask.createdAt.toDate())
                : 'Edited ${_formatEditedAt(context, ask.updatedAt!.toDate())}',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
          if (canEdit || canDelete)
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                children: [
                  if (canEdit)
                    TextButton(
                      onPressed: onEdit,
                      child: const Text('Edit Ask'),
                    ),
                  if (canDelete)
                    TextButton(
                      onPressed: onDelete,
                      child: const Text('Delete Ask'),
                    ),
                ],
              ),
            ),
        ],
      ),
    ),
  );

  String _formatEditedAt(BuildContext context, DateTime value) {
    final localizations = MaterialLocalizations.of(context);
    return '${localizations.formatMediumDate(value)} · '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(value))}';
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    required this.answer,
    required this.authorXp,
    required this.isBest,
    required this.canSelect,
    this.isSelecting = false,
    this.selectionLocked = false,
    required this.onSelect,
    required this.canEdit,
    required this.canDelete,
    required this.onOpenAuthor,
    required this.onEdit,
    required this.onDelete,
  });
  final CommunityAskAnswerModel answer;
  final int? authorXp;
  final bool isBest;
  final bool canSelect;
  final bool isSelecting;
  final bool selectionLocked;
  final VoidCallback? onSelect;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onOpenAuthor;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => Card(
    color: isBest ? const Color(0xFFECFDF5) : null,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isBest) ...[
            const Text(
              '✓ Best answer',
              style: TextStyle(
                color: Color(0xFF047857),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
          ],
          InkWell(
            key: ValueKey('answer-author-${answer.answerId}'),
            onTap: onOpenAuthor,
            child: Row(
              children: [
                CommunityLevelAvatar(
                  displayName: answer.authorDisplayName,
                  userId: answer.authorId,
                  photoUrl: null,
                  radius: 16,
                  xp: authorXp,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    answer.authorDisplayName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          Text(answer.text),
          if (answer.updatedAt != null)
            const Padding(
              padding: EdgeInsets.only(top: 5),
              child: Text(
                'Edited',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
            ),
          if (canSelect || canEdit || canDelete)
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                children: [
                  if (isSelecting)
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Selecting...'),
                        ],
                      ),
                    )
                  else if (canSelect)
                    TextButton(
                      onPressed: selectionLocked ? null : onSelect,
                      child: const Text('Select best'),
                    ),
                  if (canEdit)
                    TextButton(onPressed: onEdit, child: const Text('Edit')),
                  if (canDelete)
                    TextButton(
                      onPressed: onDelete,
                      child: const Text('Delete'),
                    ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class _AnswerComposer extends StatefulWidget {
  const _AnswerComposer({required this.onSubmit});
  final Future<void> Function(String text) onSubmit;
  @override
  State<_AnswerComposer> createState() => _AnswerComposerState();
}

class _AnswerComposerState extends State<_AnswerComposer> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (_loading || text.isEmpty) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.onSubmit(text);
      if (!mounted) {
        return;
      }
      _controller.clear();
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = 'Unable to send this Answer.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    key: const ValueKey('answer-composer'),
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('answer-input'),
                  controller: _controller,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: AppLimits.communityMessageMaxLength,
                  enabled: !_loading,
                  decoration: const InputDecoration(
                    hintText: 'Write an answer...',
                    counterText: '',
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => setState(() => _error = null),
                ),
              ),
              IconButton(
                key: const ValueKey('answer-send'),
                onPressed: !_loading && _controller.text.trim().isNotEmpty
                    ? _send
                    : null,
                icon: _loading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ],
          ),
          if (_error != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
        ],
      ),
    ),
  );
}
