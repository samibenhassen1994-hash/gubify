import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/models/community_model.dart';
import 'package:gubify/modules/community/services/community_user_xp_cache.dart';
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

  testWidgets('Profile keeps navbar clearance inside its scroll content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PersonalProfileScreen(
          userId: 'user',
          additionalBottomScrollPadding: 88,
          profileFuture: Future.value(
            const UserProfileModel(
              userId: 'user',
              displayName: 'User',
              isCurrentUser: true,
            ),
          ),
          gubsStream: Stream.value(const <PersonalGubModel>[]),
          communitiesStream: Stream.value(const <CommunityMembershipModel>[]),
          accountConnectionSection: const SizedBox(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final list = tester.widget<ListView>(find.byType(ListView));
    expect((list.padding! as EdgeInsets).bottom, 120);
  });

  testWidgets(
    'Personal Profile renders Community progress from shared XP cache',
    (tester) async {
      var loads = 0;
      final cache = CommunityUserXpCache(
        loadXp: (userIds) async {
          loads += 1;
          return const {'user': 60};
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PersonalProfileScreen(
            userId: 'user',
            showCommunityProgress: true,
            communityUserXpCache: cache,
            profileFuture: Future.value(
              const UserProfileModel(
                userId: 'user',
                displayName: 'User',
                isCurrentUser: true,
              ),
            ),
            gubsStream: Stream.value(const <PersonalGubModel>[]),
            communitiesStream: Stream.value(const <CommunityMembershipModel>[]),
            accountConnectionSection: const SizedBox(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Community progress'), findsOneWidget);
      expect(find.text('Level 3'), findsOneWidget);
      expect(find.text('60 XP total'), findsOneWidget);
      expect(find.text('0 / 60 XP'), findsOneWidget);
      expect(loads, 1);
    },
  );

  testWidgets('anonymous Personal Profile does not acquire Community XP', (
    tester,
  ) async {
    var loads = 0;
    final cache = CommunityUserXpCache(
      loadXp: (_) async {
        loads += 1;
        return const {'user': 60};
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PersonalProfileScreen(
          userId: 'user',
          showCommunityProgress: false,
          communityUserXpCache: cache,
          profileFuture: Future.value(
            const UserProfileModel(
              userId: 'user',
              displayName: 'User',
              isCurrentUser: true,
            ),
          ),
          gubsStream: Stream.value(const <PersonalGubModel>[]),
          communitiesStream: Stream.value(const <CommunityMembershipModel>[]),
          accountConnectionSection: const SizedBox(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Community progress'), findsNothing);
    expect(loads, 0);
  });

  testWidgets(
    'Community opened from Profile receives the shell exit callback',
    (tester) async {
      var exits = 0;
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
            communitiesStream: Stream.value([memberships.first]),
            accountConnectionSection: const SizedBox(),
            communityLinkedAccountGate: (_) async => true,
            onExitToMyGubs: () => exits += 1,
            communityHomeBuilder: (_, communityId, onExitToMyGubs) => Scaffold(
              body: FilledButton(
                onPressed: onExitToMyGubs,
                child: Text('Exit $communityId'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Communities (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('First Community'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Exit first'));
      await tester.pump();

      expect(exits, 1);
    },
  );
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
