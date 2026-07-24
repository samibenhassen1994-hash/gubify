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
  final ValueChanged<ChatMessageModel>? onConvertToTask;
  final String? initialMessageId;

  const ChatScreen({
    super.key,
    required this.gubId,
    this.onMessagesVisible,
    this.onConvertToTask,
    this.initialMessageId,
  });

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
  bool _isScrollingToPendingMessages = false;
  int _pendingScrollGeneration = 0;
  bool _messageActionOpen = false;
  final GlobalKey _targetMessageKey = GlobalKey();
  ChatMessageModel? _loadedTargetMessage;
  bool _targetLookupStarted = false;
  bool _targetFoundInStream = false;
  bool _targetScrollScheduled = false;
  bool _targetScrollCompleted = false;
  int _targetScrollAttempts = 0;
  bool _isTargetHighlighted = false;
  Timer? _highlightTimer;

  @override
  void initState() {
    super.initState();
    _messagesStream = ChatService.instance.messagesStream(widget.gubId);
    _messageController.addListener(_onMessageChanged);
    _messageFocusNode.addListener(_onFocusChanged);
    _scrollController.addListener(_onScroll);
  }

  void _ensureTargetMessageAvailable(List<ChatMessageModel> messages) {
    final messageId = widget.initialMessageId;
    if (messageId == null) return;

    if (messages.any((message) => message.messageId == messageId)) {
      _targetFoundInStream = true;
      return;
    }

    if (_targetLookupStarted || _loadedTargetMessage != null) return;
    _targetLookupStarted = true;
    unawaited(_loadInitialMessage());
  }

  Future<void> _loadInitialMessage() async {
    final messageId = widget.initialMessageId;
    if (messageId == null) return;

    try {
      final message = await ChatService.instance.getMessage(
        gubId: widget.gubId,
        messageId: messageId,
      );
      if (!mounted || _targetFoundInStream) return;

      if (message == null) {
        _showMissingOriginalMessage();
        _scheduleScrollToBottom(animate: false);
        return;
      }

      _knownMessageIds.add(message.messageId);
      setState(() => _loadedTargetMessage = message);
    } catch (_) {
      if (!mounted || _targetFoundInStream) return;
      _showMissingOriginalMessage();
      _scheduleScrollToBottom(animate: false);
    }
  }

  void _showMissingOriginalMessage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unable to find the original message.")),
      );
    });
  }

  List<ChatMessageModel> _withLoadedTarget(List<ChatMessageModel> messages) {
    final target = _loadedTargetMessage;
    if (target == null ||
        messages.any((message) => message.messageId == target.messageId)) {
      return messages;
    }

    final combined = <ChatMessageModel>[...messages, target]
      ..sort((first, second) => first.createdAt.compareTo(second.createdAt));
    return combined;
  }

  void _scheduleTargetMessageScroll(List<ChatMessageModel> messages) {
    final targetMessageId = widget.initialMessageId;
    if (targetMessageId == null ||
        _targetScrollCompleted ||
        _targetScrollScheduled) {
      return;
    }

    final containsTarget = messages.any(
      (message) => message.messageId == targetMessageId,
    );
    if (!containsTarget) return;

    _targetFoundInStream = true;
    _targetScrollScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _targetScrollScheduled = false;
      if (!mounted || _targetScrollCompleted) return;

      final targetContext = _targetMessageKey.currentContext;
      if (targetContext == null) {
        if (_targetScrollAttempts++ < 2) {
          _scheduleTargetMessageScroll(messages);
        }
        return;
      }

      _targetScrollCompleted = true;
      unawaited(
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
          alignment: 0.35,
        ).then((_) {
          if (!mounted) return;

          setState(() => _isTargetHighlighted = true);
          _highlightTimer?.cancel();
          _highlightTimer = Timer(const Duration(milliseconds: 1800), () {
            if (mounted) {
              setState(() => _isTargetHighlighted = false);
            }
          });
        }),
      );
    });
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
      if (_isScrollingToPendingMessages) return;

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
      _isScrollingToPendingMessages = false;
      _pendingScrollGeneration++;
      return;
    }

    final newestMessageId = messages.last.messageId;

    if (!_hasPositionedInitialMessages) {
      _hasPositionedInitialMessages = true;
      _lastMessageId = newestMessageId;
      _pendingReceivedMessageCount = 0;
      _knownMessageIds.addAll(messages.map((message) => message.messageId));
      if (widget.initialMessageId == null) {
        _scheduleScrollToBottom(
          animate: false,
          visibleMessageId: newestMessageId,
        );
      }
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
    if (_isScrollingToPendingMessages) {
      _pendingReceivedMessageCount += newReceivedMessageCount;
      return;
    }

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
    if (_isScrollingToPendingMessages || _lastMessageId == null) return;
    if (!_scrollController.hasClients) return;

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

      final newestMessageId = _lastMessageId;
      setState(() {
        _isScrollingToPendingMessages = false;
        _pendingReceivedMessageCount = 0;
      });

      if (newestMessageId != null) {
        _notifyMessagesVisible(newestMessageId);
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

  Future<void> _showMessageActions(ChatMessageModel message) async {
    if (_messageActionOpen || widget.onConvertToTask == null) return;
    _messageActionOpen = true;

    final shouldConvert = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ListTile(
              leading: const Icon(
                Icons.task_alt_rounded,
                color: Color(0xFF2563EB),
              ),
              title: const Text("Convert to task"),
              onTap: () => Navigator.pop(sheetContext, true),
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    if (shouldConvert != true) {
      _messageActionOpen = false;
      return;
    }

    widget.onConvertToTask?.call(message);
  }

  void _retryMessages() {
    setState(() {
      _hasPositionedInitialMessages = false;
      _lastMessageId = null;
      _lastVisibleMessageId = null;
      _knownMessageIds.clear();
      _pendingReceivedMessageCount = 0;
      _isScrollingToPendingMessages = false;
      _pendingScrollGeneration++;
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
    _highlightTimer?.cancel();
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

                  final streamedMessages = snapshot.data ?? const [];
                  _ensureTargetMessageAvailable(streamedMessages);
                  final messages = _withLoadedTarget(streamedMessages);

                  if (messages.isEmpty) {
                    return const _EmptyChatState();
                  }

                  _handleMessages(messages, currentUserId);
                  _scheduleTargetMessageScroll(messages);

                  return Stack(
                    children: [
                      SingleChildScrollView(
                        controller: _scrollController,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(
                          16,
                          16,
                          16,
                          _pendingReceivedMessageCount > 0 ? 72 : 12,
                        ),
                        child: Column(
                          children: [
                            for (final message in messages)
                              KeyedSubtree(
                                key:
                                    message.messageId == widget.initialMessageId
                                    ? _targetMessageKey
                                    : ValueKey(message.messageId),
                                child: ChatMessageBubble(
                                  message: message,
                                  isCurrentUser:
                                      currentUserId != null &&
                                      message.senderId == currentUserId,
                                  isHighlighted:
                                      _isTargetHighlighted &&
                                      message.messageId ==
                                          widget.initialMessageId,
                                  onLongPress: () =>
                                      _showMessageActions(message),
                                ),
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
                                  disabledBackgroundColor: const Color(
                                    0xFF2563EB,
                                  ),
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
