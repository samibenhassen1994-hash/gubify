import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/models/community_model.dart';
import 'package:gubify/modules/community/widgets/community_membership_card.dart';
import 'package:gubify/modules/profile/models/user_profile_model.dart';
import 'package:gubify/modules/profile/screens/personal_profile_screen.dart';

void main() {
  final memberships = [
    _membership('first', 'First Community'),
    _membership('second', 'Second Community'),
  ];

  testWidgets('Personal Profile Communities uses a four pixel card gap', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PersonalProfileScreen(
          userId: 'user',
          profileFuture: Future.value(
            const UserProfileModel(
              userId: 'user',
              displayName: 'User',
              isCurrentUser: true,
            ),
          ),
          gubsStream: Stream.value(const <PersonalGubModel>[]),
          communitiesStream: Stream.value(memberships),
          accountConnectionSection: const SizedBox(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Communities (2)'));
    await tester.pumpAndSettle();

    final cards = find.byType(CommunityMembershipCard);
    expect(cards, findsNWidgets(2));
    final firstBottom = tester.getBottomLeft(cards.at(0)).dy;
    final secondTop = tester.getTopLeft(cards.at(1)).dy;
    expect(secondTop - firstBottom, closeTo(4, 0.01));
    expect(find.text('Member'), findsNWidgets(2));
    expect(find.textContaining('Member since'), findsNWidgets(2));
  });
}

CommunityMembershipModel _membership(String id, String name) {
  return CommunityMembershipModel(
    community: CommunityModel(
      communityId: id,
      name: name,
      ownerId: 'owner',
      memberCount: 2,
      visibility: CommunityModel.publicVisibility,
      createdAt: null,
      type: CommunityModel.defaultType,
      language: CommunityModel.defaultLanguage,
      description: '',
      accessMode: CommunityModel.openAccessMode,
    ),
    role: 'member',
    joinedAt: Timestamp.fromDate(DateTime(2026, 8, 1)),
  );
}
