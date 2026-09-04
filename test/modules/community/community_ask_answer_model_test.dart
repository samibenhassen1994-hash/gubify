import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/models/community_ask_answer_model.dart';

void main() {
  test('Answer round-trips its closed immutable payload', () {
    final answer = CommunityAskAnswerModel(
      answerId: 'answer-1',
      authorId: 'member',
      authorDisplayName: 'Member',
      text: 'Try this.',
      createdAt: Timestamp.fromMillisecondsSinceEpoch(1000),
    );

    expect(
      CommunityAskAnswerModel.fromFirestore(
        answer.toFirestore(),
        answerId: 'answer-1',
      ),
      answer,
    );
  });
}
