import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../modules/chat/widgets/gub_chat_overlay.dart';
import '../../models/board_post_model.dart';
import '../../models/board_comment_model.dart';
import '../../services/board_read_service.dart';
import '../../services/post_service.dart';
import '../../widgets/gub_screen_background.dart';
import 'create_post_screen.dart';
import 'widgets/board_post_author.dart';
import 'widgets/board_comment_tile.dart';

class BoardScreen extends StatefulWidget {
  final String gubId;

  const BoardScreen({super.key, required this.gubId});

  @visibleForTesting
  static List<BoardPostModel> orderPosts(
    List<BoardPostModel> posts,
    String? pinnedPostId,
  ) => [...posts]
    ..sort((a, b) {
      if (a.postId == pinnedPostId) return -1;
      if (b.postId == pinnedPostId) return 1;
      return 0;
    });

  @visibleForTesting
  static String formatPostDate(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} · '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  static const _topReadThreshold = 24.0;

  final ScrollController _scrollController = ScrollController();
  String? _latestPostId;
  String? _lastMarkedPostId;
  bool _hasLoadedPosts = false;
  bool _hasInitializedRead = false;
  bool _markScheduled = false;
  final PostService _postService = PostService();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _latestPostId == null) return;

    if (_scrollController.position.pixels <= _topReadThreshold) {
      _scheduleMarkAsRead(_latestPostId!);
    }
  }

  void _scheduleMarkAsRead(String postId, {bool force = false}) {
    if (_markScheduled || _lastMarkedPostId == postId) return;
    if (!force &&
        _scrollController.hasClients &&
        _scrollController.position.pixels > _topReadThreshold) {
      return;
    }

    _markScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markScheduled = false;
      if (!mounted) return;

      _lastMarkedPostId = postId;
      unawaited(_markAsRead());
    });
  }

  Future<void> _markAsRead() async {
    try {
      await BoardReadService.instance.markAsRead(widget.gubId);
    } catch (_) {
      // A failed read receipt must not prevent the Board from being usable.
    }
  }

  void _scheduleInitialRead() {
    if (_hasInitializedRead) {
      return;
    }
    _hasInitializedRead = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_markAsRead());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChatFloatingActionButtonRouteScope(
      additionalBottomOffset: kFloatingActionButtonMargin,
      child: GubScreenBackground(
        variant: GubBackgroundAssignments.board,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: const Text('Board')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreatePostScreen(gubId: widget.gubId),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Create post'),
            tooltip: 'Create post',
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Board',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 6),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Share updates with your Gub.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: StreamBuilder<Map<String, dynamic>?>(
                    stream: _postService.boardStateStream(widget.gubId),
                    builder: (context, boardSnapshot) {
                      final board = boardSnapshot.data;
                      final pinnedId = board?['pinnedBoardPostId'] as String?;
                      final isOwner =
                          board?['ownerId'] ==
                          FirebaseAuth.instance.currentUser?.uid;
                      return StreamBuilder<List<BoardPostModel>>(
                        stream: _postService.postsStream(widget.gubId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          if (snapshot.hasError) {
                            return const Center(
                              child: Text('Unable to load Board posts.'),
                            );
                          }

                          final sourcePosts =
                              snapshot.data ?? const <BoardPostModel>[];
                          final posts = BoardScreen.orderPosts(
                            sourcePosts,
                            pinnedId,
                          );
                          if (posts.isEmpty) {
                            _scheduleInitialRead();
                            return Center(
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.campaign_outlined, size: 50),
                                      SizedBox(height: 12),
                                      Text(
                                        'No posts yet',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        "Select 'Create post' to publish the first update.",
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          _latestPostId = posts.first.postId;
                          _scheduleMarkAsRead(
                            _latestPostId!,
                            force: !_hasLoadedPosts,
                          );
                          _hasLoadedPosts = true;

                          return ListView.builder(
                            controller: _scrollController,
                            itemCount: posts.length,
                            itemBuilder: (context, index) {
                              final post = posts[index];

                              return _BoardPostCard(
                                gubId: widget.gubId,
                                post: post,
                                pinned: post.postId == pinnedId,
                                canPin: isOwner,
                                postService: _postService,
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BoardPostCard extends StatelessWidget {
  const _BoardPostCard({
    required this.gubId,
    required this.post,
    required this.pinned,
    required this.canPin,
    required this.postService,
  });

  final String gubId;
  final BoardPostModel post;
  final bool pinned;
  final bool canPin;
  final PostService postService;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: pinned
            ? const BorderSide(color: Color(0xFF2563EB), width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pinned) ...[
              const Row(
                children: [
                  Icon(
                    Icons.push_pin_rounded,
                    size: 17,
                    color: Color(0xFF2563EB),
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Pinned',
                    style: TextStyle(
                      color: Color(0xFF2563EB),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: BoardPostAuthor(post: post, gubId: gubId),
                ),
                if (canPin)
                  IconButton(
                    tooltip: pinned ? 'Unpin post' : 'Pin post',
                    onPressed: () => postService.setPinnedPost(
                      gubId: gubId,
                      postId: pinned ? null : post.postId,
                    ),
                    icon: Icon(
                      pinned ? Icons.push_pin : Icons.push_pin_outlined,
                    ),
                  ),
              ],
            ),
            if (post.createdAt != null) ...[
              const SizedBox(height: 4),
              Text(
                BoardScreen.formatPostDate(post.createdAt!.toDate()),
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
            ],
            const SizedBox(height: 14),
            Text(post.message, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 14),
            Row(
              children: [
                StreamBuilder<bool>(
                  stream: postService.isLikedStream(
                    gubId: gubId,
                    postId: post.postId,
                  ),
                  builder: (context, snapshot) => TextButton.icon(
                    onPressed: () => postService.toggleLike(
                      gubId: gubId,
                      postId: post.postId,
                    ),
                    icon: Icon(
                      snapshot.data == true
                          ? Icons.favorite
                          : Icons.favorite_border,
                      size: 20,
                    ),
                    label: Text('${post.likes}'),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => _BoardCommentsSheet(
                      gubId: gubId,
                      post: post,
                      postService: postService,
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline, size: 20),
                  label: Text('${post.comments}'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BoardCommentsSheet extends StatefulWidget {
  const _BoardCommentsSheet({
    required this.gubId,
    required this.post,
    required this.postService,
  });
  final String gubId;
  final BoardPostModel post;
  final PostService postService;
  @override
  State<_BoardCommentsSheet> createState() => _BoardCommentsSheetState();
}

class _BoardCommentsSheetState extends State<_BoardCommentsSheet> {
  final _controller = TextEditingController();
  bool _sending = false;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) {
      return;
    }
    setState(() => _sending = true);
    try {
      await widget.postService.addComment(
        gubId: widget.gubId,
        postId: widget.post.postId,
        text: text,
      );
      _controller.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Unable to add comment.')));
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Comments',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<BoardCommentModel>>(
                stream: widget.postService.commentsStream(
                  gubId: widget.gubId,
                  postId: widget.post.postId,
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Unable to load comments.'),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final comments = snapshot.data!;
                  if (comments.isEmpty) {
                    return const Center(child: Text('No comments yet.'));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: comments.length,
                    itemBuilder: (context, index) => BoardCommentTile(
                      comment: comments[index],
                      formattedDate: comments[index].createdAt == null
                          ? null
                          : BoardScreen.formatPostDate(
                              comments[index].createdAt!.toDate(),
                            ),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: 'Write a comment…',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _sending ? null : _send,
                      tooltip: 'Send comment',
                      icon: _sending
                          ? const CircularProgressIndicator()
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
