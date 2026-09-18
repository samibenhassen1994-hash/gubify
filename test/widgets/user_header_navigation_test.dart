import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/chat/widgets/chat_user_avatar.dart';
import 'package:gubify/widgets/user_header.dart';

void main() {
  testWidgets('shell callbacks switch Explore and Profile from UserHeader', (
    tester,
  ) async {
    var exploreCalls = 0;
    var profileCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserHeader(
            personalProfileEnabled: true,
            currentUserIdOverride: 'user-1',
            userFutureOverride: Future.value(const {'displayName': 'Alex'}),
            onExploreCommunities: () => exploreCalls += 1,
            onOpenPersonalProfile: () => profileCalls += 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Explore communities'));
    await tester.pump();
    expect(exploreCalls, 1);

    await tester.tap(find.byType(ChatUserAvatar));
    await tester.pump();
    expect(profileCalls, 1);
  });
}
