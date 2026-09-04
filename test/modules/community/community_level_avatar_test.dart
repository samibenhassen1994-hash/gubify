import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/widgets/community_level_avatar.dart';

void main() {
  testWidgets('renders a level badge only when authoritative XP is available', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            CommunityLevelAvatar(
              displayName: 'Alex',
              userId: 'member-1',
              photoUrl: null,
              radius: 20,
              xp: null,
              onTap: () => taps++,
            ),
            const CommunityLevelAvatar(
              displayName: 'Sam',
              userId: 'member-2',
              photoUrl: null,
              radius: 20,
              xp: 640,
            ),
          ],
        ),
      ),
    );

    expect(find.text('Lv 1'), findsNothing);
    expect(find.text('Lv 8'), findsOneWidget);
    await tester.tap(find.byType(CommunityLevelAvatar).first);
    expect(taps, 1);
  });
}
