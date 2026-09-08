import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/chat/models/chat_message_model.dart';
import 'package:gubify/modules/chat/services/chat_service.dart';
import 'package:gubify/modules/moderation/blocking/models/user_block_model.dart';

void main() {
  test(
    'private chat filters only blocked user messages from the cutoff live',
    () async {
      final messages = _MessageListStream([
        _beforeBlockMessage,
        _afterBlockMessage,
        _otherMessage,
      ]);
      final blocks = _BlockListStream();
      final service = _service(
        messages,
        blocks.stream,
        message: _afterBlockMessage,
      );
      final iterator = StreamIterator(service.messagesStream('gub'));
      addTearDown(() async {
        await iterator.cancel();
        await messages.close();
        await blocks.close();
      });

      expect(await iterator.moveNext(), isTrue);
      expect(iterator.current.map((message) => message.messageId), [
        'before',
        'after',
        'other',
      ]);

      blocks.emit([
        UserBlockModel(blockedUserId: 'blocked', blockedAt: Timestamp(10, 0)),
      ]);
      expect(await iterator.moveNext(), isTrue);
      expect(iterator.current.map((message) => message.messageId), [
        'before',
        'other',
      ]);

      blocks.emit(const []);
      expect(await iterator.moveNext(), isTrue);
      expect(iterator.current.map((message) => message.messageId), [
        'before',
        'after',
        'other',
      ]);
    },
  );

  test('private getMessage respects the same exact block cutoff', () async {
    final messages = _MessageListStream(const <ChatMessageModel>[]);
    final blocks = _BlockListStream();
    final service = _service(
      messages,
      blocks.stream,
      message: _afterBlockMessage,
    );
    addTearDown(() async {
      await messages.close();
      await blocks.close();
    });

    expect(
      await service.getMessage(gubId: 'gub', messageId: 'after'),
      _afterBlockMessage,
    );
    blocks.emit([
      UserBlockModel(blockedUserId: 'blocked', blockedAt: Timestamp(10, 0)),
    ]);
    expect(await service.getMessage(gubId: 'gub', messageId: 'after'), isNull);
  });
}

ChatService _service(
  _MessageListStream messages,
  Stream<List<UserBlockModel>> Function() blocks, {
  required ChatMessageModel message,
}) => ChatService.forTesting(
  membershipBoundary: (_) async => Timestamp(0, 0),
  messages: (_, _) => messages.stream,
  getMessage: (_, _, _) async => message,
  blockedUsers: blocks,
);

final _beforeBlockMessage = _message(
  'before',
  'blocked',
  Timestamp(9, 999999999),
);
final _afterBlockMessage = _message('after', 'blocked', Timestamp(10, 0));
final _otherMessage = _message('other', 'other', Timestamp(11, 0));

ChatMessageModel _message(String id, String senderId, Timestamp createdAt) =>
    ChatMessageModel(
      messageId: id,
      gubId: 'gub',
      senderId: senderId,
      senderName: senderId,
      text: id,
      createdAt: createdAt,
    );

class _BlockListStream {
  var _current = const <UserBlockModel>[];
  final _updates = StreamController<List<UserBlockModel>>.broadcast();

  Stream<List<UserBlockModel>> stream() => Stream.multi((listener) {
    listener.add(_current);
    final subscription = _updates.stream.listen(
      listener.add,
      onError: listener.addError,
      onDone: listener.close,
    );
    listener.onCancel = subscription.cancel;
  }, isBroadcast: true);

  void emit(List<UserBlockModel> blocks) {
    _current = List.unmodifiable(blocks);
    _updates.add(_current);
  }

  Future<void> close() => _updates.close();
}

class _MessageListStream {
  _MessageListStream(List<ChatMessageModel> initialMessages)
    : _current = List.unmodifiable(initialMessages);

  List<ChatMessageModel> _current;
  final _updates = StreamController<List<ChatMessageModel>>.broadcast();

  Stream<List<ChatMessageModel>> get stream => Stream.multi((listener) {
    listener.add(_current);
    final subscription = _updates.stream.listen(
      listener.add,
      onError: listener.addError,
      onDone: listener.close,
    );
    listener.onCancel = subscription.cancel;
  }, isBroadcast: true);

  void emit(List<ChatMessageModel> messages) {
    _current = List.unmodifiable(messages);
    _updates.add(_current);
  }

  Future<void> close() => _updates.close();
}
