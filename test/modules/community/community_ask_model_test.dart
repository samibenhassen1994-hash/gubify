import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/models/community_ask_model.dart';

void main() {
  test('ask types keep stable lowercase Firestore values', () {
    expect(CommunityAskType.help.value, 'help');
    expect(CommunityAskType.information.value, 'information');
    expect(CommunityAskType.advice.value, 'advice');
  });

  test('Chat ask round-trips canonical text and source message id', () {
    final createdAt = Timestamp.fromMillisecondsSinceEpoch(1234);
    final ask = CommunityAskModel(
      askId: 'message-1',
      communityId: 'community-1',
      authorId: 'author-1',
      authorDisplayName: 'Sami',
      type: CommunityAskType.help,
      sourceMessageId: 'message-1',
      text: 'Can someone help?',
      createdAt: createdAt,
      status: CommunityAskStatus.active,
    );

    final decoded = CommunityAskModel.fromFirestore(
      ask.toFirestore(),
      askId: ask.askId,
    );

    expect(decoded.askId, 'message-1');
    expect(decoded.type, CommunityAskType.help);
    expect(decoded.status, CommunityAskStatus.active);
    expect(decoded.text, 'Can someone help?');
    expect(decoded.sourceMessageId, 'message-1');
    expect(decoded.createdAt, createdAt);
  });

  test('Direct ask omits sourceMessageId from Firestore', () {
    final ask = CommunityAskModel(
      askId: 'generated-id',
      communityId: 'community-1',
      authorId: 'author-1',
      authorDisplayName: 'Sami',
      type: CommunityAskType.advice,
      sourceMessageId: null,
      text: 'Which approach would you recommend?',
      createdAt: Timestamp.fromMillisecondsSinceEpoch(1234),
      status: CommunityAskStatus.active,
    );

    final data = ask.toFirestore();
    expect(data['text'], 'Which approach would you recommend?');
    expect(data.containsKey('sourceMessageId'), isFalse);

    final decoded = CommunityAskModel.fromFirestore(data, askId: ask.askId);
    expect(decoded.sourceMessageId, isNull);
    expect(decoded.text, 'Which approach would you recommend?');
  });
}
