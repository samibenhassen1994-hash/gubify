import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_block_model.dart';

Map<String, Timestamp> blockedAtByUser(Iterable<UserBlockModel> blocks) => {
  for (final block in blocks)
    if (block.blockedAt != null) block.blockedUserId: block.blockedAt!,
};

bool isUserBlockMessageVisible({
  required String senderId,
  required Timestamp createdAt,
  required Map<String, Timestamp> blockedAtByUser,
}) {
  final blockedAt = blockedAtByUser[senderId];
  return blockedAt == null || createdAt.compareTo(blockedAt) < 0;
}

Stream<List<T>> filterUserBlockedMessages<T>({
  required Stream<List<T>> messagesStream,
  required Stream<List<UserBlockModel>> blocksStream,
  required String Function(T message) senderId,
  required Timestamp Function(T message) createdAt,
}) {
  late final StreamController<List<T>> controller;
  StreamSubscription<List<T>>? messagesSubscription;
  StreamSubscription<List<UserBlockModel>>? blocksSubscription;
  List<T>? messages;
  Map<String, Timestamp>? blocks;

  void emit() {
    final currentMessages = messages;
    final currentBlocks = blocks;
    if (currentMessages == null ||
        currentBlocks == null ||
        controller.isClosed) {
      return;
    }
    controller.add([
      for (final message in currentMessages)
        if (isUserBlockMessageVisible(
          senderId: senderId(message),
          createdAt: createdAt(message),
          blockedAtByUser: currentBlocks,
        ))
          message,
    ]);
  }

  controller = StreamController<List<T>>(
    onListen: () {
      messagesSubscription = messagesStream.listen((value) {
        messages = value;
        emit();
      }, onError: controller.addError);
      blocksSubscription = blocksStream.listen((value) {
        blocks = blockedAtByUser(value);
        emit();
      }, onError: controller.addError);
    },
    onCancel: () async {
      await Future.wait([
        if (messagesSubscription != null) messagesSubscription!.cancel(),
        if (blocksSubscription != null) blocksSubscription!.cancel(),
      ]);
    },
  );
  return controller.stream;
}
