import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/chat/widgets/chat_user_avatar.dart';
import 'package:gubify/modules/community/models/community_ask_model.dart';
import 'package:gubify/modules/community/models/community_model.dart';
import 'package:gubify/modules/community/screens/community_settings_screen.dart';
import 'package:gubify/modules/community/services/community_user_xp_cache.dart';
import 'package:gubify/modules/profile/models/user_profile_model.dart';
import 'package:gubify/modules/profile/screens/user_profile_screen.dart';

void main() {
  testWidgets(
    'keeps Community details and opens the current user Community profile',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CommunitySettingsScreen(
            community: _community,
            isOwner: false,
            currentUserId: 'current-user',
            currentUserRoleFuture: Future.value('owner'),
            currentUserProfileFuture: Future.value(
              const UserProfileModel(
                userId: 'current-user',
                displayName: 'Sami',
                photoUrl: null,
                isCurrentUser: true,
              ),
            ),
            communityUserXpCache: CommunityUserXpCache(
              loadXp: (_) async => const <String, int>{},
            ),
            selfProfileActiveAsksStream: Stream.value(
              const <CommunityAskModel>[],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Study Circle'), findsOneWidget);
      expect(find.text('Community role: Owner'), findsOneWidget);
      expect(find.byType(ChatUserAvatar), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('community-settings-current-user-profile')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(UserProfileScreen), findsOneWidget);
      expect(find.text('Block User'), findsNothing);
    },
  );
}

final _community = CommunityModel(
  communityId: 'community',
  name: 'Study Circle',
  ownerId: 'owner',
  memberCount: 2,
  visibility: CommunityModel.publicVisibility,
  createdAt: Timestamp(1, 0),
  type: CommunityModel.defaultType,
  language: CommunityModel.defaultLanguage,
  description: 'A study Community.',
  accessMode: CommunityModel.openAccessMode,
);
