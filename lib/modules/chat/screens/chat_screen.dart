import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/chat_message_model.dart';
import '../services/chat_service.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/chat_message_composer.dart';

class ChatScreen extends StatefulWidget {
  final String gubId;
  final VoidCallback? onMessagesVisible;

  const ChatScreen({super.key, required this.gubId, this.onMessagesVisible});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();

  late Stream<List<ChatMessageModel>> _messagesStream;

  bool _isSending = false;
  bool _hasPositionedInitialMessages = false;
  String? _lastMessageId;
  String? _lastVisibleMessageId;
  final Set<String> _knownMessageIds = <String>{};
  int _pendingReceivedMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _messagesStream = ChatService.instance.messagesStream(widget.gubId);
    _messageController.addListener(_onMessageChanged);
    _messageFocusNode.addListener(_onFocusChanged);
    _scrollController.addListener(_onScroll);
  }

  void _onMessageChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onFocusChanged() {
    if (!_messageFocusNode.hasFocus || !_isNearBottom()) return;
    _scheduleScrollToBottom(animate: true);
  }

  void _onScroll() {
    final newestMessageId = _lastMessageId;

    if (newestMessageId != null && _isAtBottom()) {
      if (_pendingReceivedMessageCount > 0 && mounted) {
        setState(() => _pendingReceivedMessageCount = 0);
      }
      _notifyMessagesVisible(newestMessageId);
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

  void _handleMessages(List<ChatMessageModel> messages, String? currentUserId) {
    if (messages.isEmpty) {
      _lastMessageId = null;
      _hasPositionedInitialMessages = false;
      _knownMessageIds.clear();
      _pendingReceivedMessageCount = 0;
      return;
    }

    final newestMessageId = messages.last.messageId;

    if (!_hasPositionedInitialMessages) {
      _hasPositionedInitialMessages = true;
      _lastMessageId = newestMessageId;
      _pendingReceivedMessageCount = 0;
      _knownMessageIds.addAll(messages.map((message) => message.messageId));
      _scheduleScrollToBottom(
        animate: false,
        visibleMessageId: newestMessageId,
      );
      return;
    }

    final newReceivedMessageCount = messages.where((message) {
      return !_knownMessageIds.contains(message.messageId) &&
          currentUserId != null &&
          message.senderId != currentUserId;
    }).length;
    _knownMessageIds.addAll(messages.map((message) => message.messageId));

    final shouldFollowNewestMessage = _isNearBottom();
    final newestMessageChanged = _lastMessageId != newestMessageId;
    _lastMessageId = newestMessageId;

    if (!newestMessageChanged) return;

    if (shouldFollowNewestMessage) {
      _scheduleScrollToBottom(animate: true, visibleMessageId: newestMessageId);
    } else if (newReceivedMessageCount > 0) {
      _pendingReceivedMessageCount += newReceivedMessageCount;
    }
  }

  void _notifyMessagesVisible(String newestMessageId) {
    if (_lastVisibleMessageId == newestMessageId) return;
    _lastVisibleMessageId = newestMessageId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onMessagesVisible?.call();
      }
    });
  }

  void _scheduleScrollToBottom({
    required bool animate,
    String? visibleMessageId,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      final target = _scrollController.position.maxScrollExtent;

      if (animate) {
        unawaited(
          _scrollController
              .animateTo(
                target,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
              )
              .then((_) {
                if (!mounted || !_isAtBottom()) return;

                if (_pendingReceivedMessageCount > 0) {
                  setState(() => _pendingReceivedMessageCount = 0);
                }
                if (visibleMessageId != null) {
                  _notifyMessagesVisible(visibleMessageId);
                }
              }),
        );
      } else {
        _scrollController.jumpTo(target);
        if (visibleMessageId != null && _isAtBottom()) {
          _notifyMessagesVisible(visibleMessageId);
        }
      }
    });
  }

  void _scrollToPendingMessages() {
    final newestMessageId = _lastMessageId;
    if (newestMessageId == null) return;

    _scheduleScrollToBottom(animate: true, visibleMessageId: newestMessageId);
  }

  Future<void> _sendMessage() async {
    if (_isSending || _messageController.text.trim().isEmpty) return;

    setState(() => _isSending = true);

    try {
      await ChatService.instance.sendMessage(
        gubId: widget.gubId,
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
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _retryMessages() {
    setState(() {
      _hasPositionedInitialMessages = false;
      _lastMessageId = null;
      _lastVisibleMessageId = null;
      _knownMessageIds.clear();
      _pendingReceivedMessageCount = 0;
      _messagesStream = ChatService.instance.messagesStream(widget.gubId);
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

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF5F8FD),
      appBar: AppBar(
        leading: IconButton(
          tooltip: "Close chat",
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.close_rounded),
        ),
        title: const Text("Chat"),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<ChatMessageModel>>(
                stream: _messagesStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return _ChatErrorState(onRetry: _retryMessages);
                  }

                  final messages = snapshot.data ?? const [];

                  if (messages.isEmpty) {
                    return const _EmptyChatState();
                  }

                  _handleMessages(messages, currentUserId);

                  return Stack(
                    children: [
                      ListView.builder(
                        controller: _scrollController,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(
                          16,
                          16,
                          16,
                          _pendingReceivedMessageCount > 0 ? 72 : 12,
                        ),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];

                          return ChatMessageBubble(
                            message: message,
                            isCurrentUser:
                                currentUserId != null &&
                                message.senderId == currentUserId,
                          );
                        },
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
                                onPressed: _scrollToPendingMessages,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                ),
                                label: Text(
                                  "$_pendingReceivedMessageCount new "
                                  "${_pendingReceivedMessageCount == 1 ? 'message' : 'messages'}",
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
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
            ChatMessageComposer(
              controller: _messageController,
              focusNode: _messageFocusNode,
              isSending: _isSending,
              canSend: canSend,
              maxLength: ChatService.maxMessageLength,
              onSend: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState();

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

class _ChatErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ChatErrorState({required this.onRetry});

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
