import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/models/community_chat_message_model.dart';
import 'package:gubify/modules/community/services/community_chat_service.dart';
import 'package:gubify/modules/moderation/blocking/models/user_block_model.dart';

void main() {
  test(
    'Community chat reapplies visibility when the block list changes',
    () async {
      final messages = _MessageListStream([_before, _atCutoff, _other]);
      final blocks = _BlockListStream();
      final service = CommunityChatService.forTesting(
        membershipBoundary: (_) async => Timestamp(0, 0),
        messages: (_, _) => messages.stream,
        blockedUsers: blocks.stream,
      );
      final iterator = StreamIterator(service.messagesStream('community'));
      addTearDown(() async {
        await iterator.cancel();
        await messages.close();
        await blocks.close();
      });

      expect(await iterator.moveNext(), isTrue);
      expect(iterator.current.map((message) => message.messageId), [
        'before',
        'at',
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
    },
  );
}

final _before = _message('before', 'blocked', Timestamp(9, 999999999));
final _atCutoff = _message('at', 'blocked', Timestamp(10, 0));
final _other = _message('other', 'other', Timestamp(11, 0));

CommunityChatMessageModel _message(
  String id,
  String senderId,
  Timestamp createdAt,
) => CommunityChatMessageModel(
  messageId: id,
  communityId: 'community',
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
  _MessageListStream(List<CommunityChatMessageModel> initialMessages)
    : _current = List.unmodifiable(initialMessages);

  List<CommunityChatMessageModel> _current;
  final _updates =
      StreamController<List<CommunityChatMessageModel>>.broadcast();

  Stream<List<CommunityChatMessageModel>> get stream =>
      Stream.multi((listener) {
        listener.add(_current);
        final subscription = _updates.stream.listen(
          listener.add,
          onError: listener.addError,
          onDone: listener.close,
        );
        listener.onCancel = subscription.cancel;
      }, isBroadcast: true);

  void emit(List<CommunityChatMessageModel> messages) {
    _current = List.unmodifiable(messages);
    _updates.add(_current);
  }

  Future<void> close() => _updates.close();
}
