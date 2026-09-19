import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/chat/widgets/chat_user_avatar.dart';
import 'package:gubify/widgets/user_header.dart';

void main() {
  testWidgets('shell callbacks switch Explore and Profile from UserHeader', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    var exploreCalls = 0;
    var profileCalls = 0;
    var learnMoreCalls = 0;
    var supportCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserHeader(
            personalProfileEnabled: true,
            currentUserIdOverride: 'user-1',
            userFutureOverride: Future.value(const {'displayName': 'Alex'}),
            onExploreCommunities: () => exploreCalls += 1,
            onOpenPersonalProfile: () => profileCalls += 1,
            onLearnMore: () => learnMoreCalls += 1,
            onSupport: () => supportCalls += 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Explore communities'));
    await tester.pump();
    expect(exploreCalls, 1);

    await tester.tap(find.byTooltip('Learn More'));
    await tester.pump();
    expect(learnMoreCalls, 1);

    final support = find.byTooltip('Support Us');
    expect(support, findsOneWidget);
    expect(find.bySemanticsLabel('Support Us'), findsOneWidget);
    final supportImage = tester.widget<Image>(
      find.image(const AssetImage('assets/images/supportbotton.png')),
    );
    expect(supportImage.fit, BoxFit.contain);
    expect(
      tester.getCenter(find.byTooltip('Learn More')).dx,
      lessThan(tester.getCenter(support).dx),
    );
    expect(
      tester.getCenter(support).dx,
      lessThan(tester.getCenter(find.byTooltip('Settings')).dx),
    );

    await tester.tap(support);
    await tester.pump();
    expect(supportCalls, 1);

    await tester.tap(find.byType(ChatUserAvatar));
    await tester.pump();
    expect(profileCalls, 1);

    semantics.dispose();
  });

  for (final size in [const Size(320, 426), const Size(390, 844)]) {
    testWidgets('Home header actions fit ${size.width.toInt()} px', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserHeader(
              personalProfileEnabled: true,
              currentUserIdOverride: 'user-1',
              userFutureOverride: Future.value(const {
                'displayName': 'Alexandra',
              }),
              onExploreCommunities: () {},
              onLearnMore: () {},
              onSupport: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        tester.getBottomRight(find.byTooltip('Settings')).dx,
        lessThanOrEqualTo(size.width),
      );
    });
  }
}
