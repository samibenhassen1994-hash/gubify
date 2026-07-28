import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../chat/widgets/chat_message_composer.dart';
import '../models/community_chat_message_model.dart';
import '../services/community_chat_service.dart';
import 'community_chat_message_bubble.dart';

class CommunityChatView extends StatefulWidget {
  final String communityId;

  const CommunityChatView({super.key, required this.communityId});

  @override
  State<CommunityChatView> createState() => _CommunityChatViewState();
}

class _CommunityChatViewState extends State<CommunityChatView> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final Set<String> _knownMessageIds = <String>{};

  late Stream<List<CommunityChatMessageModel>> _messagesStream;

  bool _isSending = false;
  bool _hasPositionedInitialMessages = false;
  bool _isScrollingToPendingMessages = false;
  int _pendingReceivedMessageCount = 0;
  int _pendingScrollGeneration = 0;
  String? _lastMessageId;

  @override
  void initState() {
    super.initState();
    _messagesStream = CommunityChatService.instance.messagesStream(
      widget.communityId,
    );
    _messageController.addListener(_onMessageChanged);
    _messageFocusNode.addListener(_onFocusChanged);
    _scrollController.addListener(_onScroll);
  }

  void _onMessageChanged() {
    if (mounted) setState(() {});
  }

  void _onFocusChanged() {
    if (_messageFocusNode.hasFocus && _isNearBottom()) {
      _scheduleScrollToBottom(animate: true);
    }
  }

  void _onScroll() {
    if (_isScrollingToPendingMessages || !_isAtBottom()) return;

    if (_pendingReceivedMessageCount > 0 && mounted) {
      setState(() => _pendingReceivedMessageCount = 0);
    }
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;

    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels <= 96;
  }

  bool _isAtBottom() {
    if (!_scrollController.hasClients) return false;

    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels <= 8;
  }

  void _handleMessages(
    List<CommunityChatMessageModel> messages,
    String? currentUserId,
  ) {
    if (messages.isEmpty) {
      _hasPositionedInitialMessages = false;
      _knownMessageIds.clear();
      _pendingReceivedMessageCount = 0;
      _isScrollingToPendingMessages = false;
      _pendingScrollGeneration++;
      _lastMessageId = null;
      return;
    }

    final newestMessageId = messages.last.messageId;
    if (!_hasPositionedInitialMessages) {
      _hasPositionedInitialMessages = true;
      _lastMessageId = newestMessageId;
      _knownMessageIds.addAll(messages.map((message) => message.messageId));
      _scheduleScrollToBottom(animate: false);
      return;
    }

    final receivedMessageCount = messages.where((message) {
      return !_knownMessageIds.contains(message.messageId) &&
          currentUserId != null &&
          message.senderId != currentUserId;
    }).length;
    _knownMessageIds.addAll(messages.map((message) => message.messageId));

    final newestMessageChanged = _lastMessageId != newestMessageId;
    final shouldFollowNewestMessage = _isNearBottom();
    _lastMessageId = newestMessageId;

    if (!newestMessageChanged) return;

    if (_isScrollingToPendingMessages) {
      _pendingReceivedMessageCount += receivedMessageCount;
      return;
    }

    if (shouldFollowNewestMessage) {
      _scheduleScrollToBottom(animate: true);
    } else if (receivedMessageCount > 0) {
      _pendingReceivedMessageCount += receivedMessageCount;
    }
  }

  void _scheduleScrollToBottom({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      final target = _scrollController.position.maxScrollExtent;
      if (!animate) {
        _scrollController.jumpTo(target);
        return;
      }

      unawaited(
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        ),
      );
    });
  }

  void _scrollToPendingMessages() {
    if (_isScrollingToPendingMessages || !_scrollController.hasClients) {
      return;
    }

    final generation = ++_pendingScrollGeneration;
    setState(() => _isScrollingToPendingMessages = true);
    _schedulePendingScrollAttempt(generation);
  }

  void _schedulePendingScrollAttempt(int generation) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != _pendingScrollGeneration ||
          !_isScrollingToPendingMessages) {
        return;
      }
      if (!_scrollController.hasClients) {
        setState(() => _isScrollingToPendingMessages = false);
        return;
      }

      final target = _scrollController.position.maxScrollExtent;
      unawaited(
        _scrollController
            .animateTo(
              target,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
            )
            .then((_) => _verifyPendingScroll(generation))
            .onError<Object>((_, _) => _verifyPendingScroll(generation)),
      );
    });
  }

  void _verifyPendingScroll(int generation) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != _pendingScrollGeneration ||
          !_isScrollingToPendingMessages) {
        return;
      }
      if (!_scrollController.hasClients) {
        setState(() => _isScrollingToPendingMessages = false);
        return;
      }
      if (!_isAtBottom()) {
        _schedulePendingScrollAttempt(generation);
        return;
      }

      setState(() {
        _isScrollingToPendingMessages = false;
        _pendingReceivedMessageCount = 0;
      });
    });
  }

  Future<void> _sendMessage() async {
    if (_isSending || _messageController.text.trim().isEmpty) return;

    setState(() => _isSending = true);
    try {
      await CommunityChatService.instance.sendMessage(
        communityId: widget.communityId,
        text: _messageController.text,
      );
      if (!mounted) return;

      _messageController.clear();
      _messageFocusNode.requestFocus();
      _scheduleScrollToBottom(animate: true);
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Unable to send the message. Please try again."),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _retryMessages() {
    setState(() {
      _hasPositionedInitialMessages = false;
      _knownMessageIds.clear();
      _pendingReceivedMessageCount = 0;
      _isScrollingToPendingMessages = false;
      _pendingScrollGeneration++;
      _lastMessageId = null;
      _messagesStream = CommunityChatService.instance.messagesStream(
        widget.communityId,
      );
    });
  }

  @override
  void dispose() {
    _messageController
      ..removeListener(_onMessageChanged)
      ..dispose();
    _messageFocusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final canSend = !_isSending && _messageController.text.trim().isNotEmpty;

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<CommunityChatMessageModel>>(
            stream: _messagesStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _CommunityChatErrorState(onRetry: _retryMessages);
              }

              final messages = snapshot.data ?? const [];
              if (messages.isEmpty) return const _CommunityChatEmptyState();

              _handleMessages(messages, currentUserId);

              return Stack(
                children: [
                  SingleChildScrollView(
                    controller: _scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.manual,
                    padding: EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      _pendingReceivedMessageCount > 0 ? 72 : 12,
                    ),
                    child: Column(
                      children: [
                        for (final message in messages)
                          CommunityChatMessageBubble(
                            key: ValueKey(message.messageId),
                            message: message,
                            isCurrentUser:
                                currentUserId != null &&
                                message.senderId == currentUserId,
                          ),
                      ],
                    ),
                  ),
                  if (_pendingReceivedMessageCount > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 12,
                      child: Center(
                        child: Semantics(
                          button: true,
                          excludeSemantics: true,
                          label:
                              "$_pendingReceivedMessageCount new "
                              "${_pendingReceivedMessageCount == 1 ? 'message' : 'messages'}. "
                              "Scroll to the latest messages.",
                          child: FilledButton.icon(
                            onPressed: _isScrollingToPendingMessages
                                ? null
                                : _scrollToPendingMessages,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            label: Text(
                              "$_pendingReceivedMessageCount new "
                              "${_pendingReceivedMessageCount == 1 ? 'message' : 'messages'}",
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFF2563EB),
                              disabledForegroundColor: Colors.white,
                              elevation: 4,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        Container(
          color: Colors.white,
          child: SafeArea(
            top: false,
            child: ChatMessageComposer(
              controller: _messageController,
              focusNode: _messageFocusNode,
              isSending: _isSending,
              canSend: canSend,
              maxLength: CommunityChatService.maxMessageLength,
              onSend: _sendMessage,
            ),
          ),
        ),
      ],
    );
  }
}

class _CommunityChatEmptyState extends StatelessWidget {
  const _CommunityChatEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 48,
              color: Color(0xFF2563EB),
            ),
            SizedBox(height: 14),
            Text(
              "No messages yet. Start the conversation!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityChatErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _CommunityChatErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 44,
              color: Color(0xFF64748B),
            ),
            const SizedBox(height: 12),
            const Text("Unable to load the chat.", textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text("Try again"),
            ),
          ],
        ),
      ),
    );
  }
}
