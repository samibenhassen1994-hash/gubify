import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/chat_message_model.dart';
import '../services/chat_service.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/chat_message_composer.dart';

class ChatScreen extends StatefulWidget {
  final String gubId;

  const ChatScreen({super.key, required this.gubId});

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

  @override
  void initState() {
    super.initState();
    _messagesStream = ChatService.instance.messagesStream(widget.gubId);
    _messageController.addListener(_onMessageChanged);
    _messageFocusNode.addListener(_onFocusChanged);
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

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;

    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels <= 96;
  }

  void _handleMessages(List<ChatMessageModel> messages) {
    if (messages.isEmpty) {
      _lastMessageId = null;
      _hasPositionedInitialMessages = false;
      return;
    }

    final newestMessageId = messages.last.messageId;

    if (!_hasPositionedInitialMessages) {
      _hasPositionedInitialMessages = true;
      _lastMessageId = newestMessageId;
      _scheduleScrollToBottom(animate: false);
      return;
    }

    if (_lastMessageId == newestMessageId) return;

    final shouldFollowNewestMessage = _isNearBottom();
    _lastMessageId = newestMessageId;

    if (shouldFollowNewestMessage) {
      _scheduleScrollToBottom(animate: true);
    }
  }

  void _scheduleScrollToBottom({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      final target = _scrollController.position.maxScrollExtent;

      if (animate) {
        unawaited(
          _scrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          ),
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
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
    _scrollController.dispose();
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

                  _handleMessages(messages);

                  return ListView.builder(
                    controller: _scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
