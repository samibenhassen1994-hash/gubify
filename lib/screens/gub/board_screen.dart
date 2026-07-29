import 'dart:async';

import 'package:flutter/material.dart';

import '../../modules/chat/widgets/gub_chat_overlay.dart';
import '../../models/board_post_model.dart';
import '../../services/board_read_service.dart';
import '../../services/post_service.dart';
import '../../widgets/gub_screen_background.dart';
import 'create_post_screen.dart';

class BoardScreen extends StatefulWidget {
  final String gubId;

  const BoardScreen({super.key, required this.gubId});

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
                  child: StreamBuilder<List<BoardPostModel>>(
                    stream: PostService().postsStream(widget.gubId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return const Center(
                          child: Text('Unable to load Board posts.'),
                        );
                      }

                      final posts = snapshot.data ?? const <BoardPostModel>[];
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

                          return Card(
                            margin: const EdgeInsets.only(bottom: 14),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const CircleAvatar(
                                        child: Icon(Icons.person),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          post.authorName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    post.message,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(height: 18),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.favorite_border,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 6),
                                      Text('${post.likes}'),
                                      const SizedBox(width: 20),
                                      const Icon(
                                        Icons.chat_bubble_outline,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 6),
                                      Text('${post.comments}'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
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
