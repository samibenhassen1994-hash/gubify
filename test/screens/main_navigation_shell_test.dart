import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/models/community_model.dart';
import 'package:gubify/modules/community/models/community_leaderboard_model.dart';
import 'package:gubify/modules/profile/models/user_profile_model.dart';
import 'package:gubify/screens/main_navigation_shell.dart';
import 'package:gubify/screens/welcome_screen.dart';
import 'package:gubify/widgets/gubify_bottom_navigation_bar.dart';
import 'package:gubify/widgets/gubify_swipe_back.dart';

Future<CommunityLeaderboardPage> _emptyRanking({
  Object? after,
  required int limit,
}) async => const CommunityLeaderboardPage(members: []);

void main() {
  Widget buildShell({
    Size size = const Size(390, 844),
    String displayName = 'Sami',
  }) {
    return MaterialApp(
      home: MainNavigationShell(
        userId: 'user-1',
        isAnonymous: false,
        currentUserProfile: Future.value(
          UserProfileModel(
            userId: 'user-1',
            displayName: displayName,
            isCurrentUser: true,
          ),
        ),
        homeBuilder:
            (context, onExplore, onProfile, onCreateGub, onMyGubs, onJoinGub) =>
                _HomeProbe(
                  onExplore: onExplore,
                  onProfile: onProfile,
                  onCreateGub: onCreateGub,
                  onMyGubs: onMyGubs,
                  onJoinGub: onJoinGub,
                ),
        createGubBuilder: (context, onCreated, onCommunityCreated) =>
            _CreateGubProbe(
              onCreated: onCreated,
              onCommunityCreated: onCommunityCreated,
            ),
        createdCommunityBuilder: (_, community, onExitToMyGubs) => Scaffold(
          body: Column(
            children: [
              Text('Created Community ${community.communityId}'),
              TextButton(
                onPressed: onExitToMyGubs,
                child: const Text('Exit created Community'),
              ),
            ],
          ),
        ),
        myGubsBuilder: (context, onBack) => _MyGubsProbe(onBack: onBack),
        joinGubBuilder: (context, onBack, onJoined) =>
            _JoinGubProbe(onBack: onBack, onJoined: onJoined),
        joinedGubBuilder: (_, gubId, onExitToMyGubs) => Scaffold(
          body: Column(
            children: [
              Text('Joined Gub $gubId'),
              TextButton(
                onPressed: onExitToMyGubs,
                child: const Text('Exit specific Gub'),
              ),
            ],
          ),
        ),
        exploreBuilder: (_) => const _StatefulExploreProbe(),
        notificationsBuilder: (_) =>
            const Center(child: Text('Global notifications placeholder')),
        profileBuilder: (_, onExitToMyGubs) =>
            _ProfileCommunityProbe(onExitToMyGubs: onExitToMyGubs),
      ),
    );
  }

  testWidgets('shows exactly four destinations in the approved order', (
    tester,
  ) async {
    await tester.pumpWidget(buildShell());

    expect(find.byType(GubifyBottomNavigationBar), findsOneWidget);
    expect(find.byTooltip('Home'), findsOneWidget);
    expect(find.byTooltip('Explore'), findsOneWidget);
    expect(find.byTooltip('Notifications'), findsOneWidget);
    expect(find.byTooltip('Profile'), findsOneWidget);
    expect(
      tester
          .widgetList<Tooltip>(
            find.descendant(
              of: find.byType(GubifyBottomNavigationBar),
              matching: find.byType(Tooltip),
            ),
          )
          .map((tooltip) => tooltip.message),
      ['Home', 'Explore', 'Notifications', 'Profile'],
    );
    expect(find.text('Home root'), findsOneWidget);
  });

  testWidgets('Profile destination uses the current user initial', (
    tester,
  ) async {
    await tester.pumpWidget(buildShell());
    await tester.pump();

    final bar = find.byType(GubifyBottomNavigationBar);
    expect(find.descendant(of: bar, matching: find.text('S')), findsOneWidget);
    expect(
      find.descendant(
        of: bar,
        matching: find.byIcon(Icons.person_outline_rounded),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: bar, matching: find.byIcon(Icons.person_rounded)),
      findsNothing,
    );
  });

  testWidgets('Profile destination safely falls back when name is empty', (
    tester,
  ) async {
    await tester.pumpWidget(buildShell(displayName: '   '));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(GubifyBottomNavigationBar),
        matching: find.text('?'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping and selecting Profile keeps the avatar visible', (
    tester,
  ) async {
    await tester.pumpWidget(buildShell());
    await tester.pump();

    await tester.tap(find.byTooltip('Profile'));
    await tester.pump();

    expect(find.text('Profile root'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(GubifyBottomNavigationBar),
        matching: find.text('S'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('bottom-navigation-profile-selection')),
      findsOneWidget,
    );
  });

  testWidgets('floating bar is a translucent blurred overlay', (tester) async {
    await tester.pumpWidget(buildShell());
    await tester.pump();

    final glassFinder = find.byKey(const Key('gubify-bottom-navigation-glass'));
    final glass = tester.widget<DecoratedBox>(glassFinder);
    final decoration = glass.decoration as BoxDecoration;

    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(decoration.color!.a, lessThanOrEqualTo(0.16));
    expect(
      find.ancestor(of: glassFinder, matching: find.byType(Positioned)),
      findsOneWidget,
    );
    expect(
      find.ancestor(of: glassFinder, matching: find.byType(Stack)),
      findsWidgets,
    );
  });

  testWidgets('root content keeps the original full-screen MediaQuery', (
    tester,
  ) async {
    double? rootBottomPadding;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MainNavigationShell(
          userId: 'user-1',
          isAnonymous: false,
          currentUserProfile: Future.value(
            const UserProfileModel(
              userId: 'user-1',
              displayName: 'Sami',
              isCurrentUser: true,
            ),
          ),
          homeBuilder:
              (
                context,
                onExplore,
                onProfile,
                onCreateGub,
                onMyGubs,
                onJoinGub,
              ) => Builder(
                builder: (context) {
                  rootBottomPadding = MediaQuery.paddingOf(context).bottom;
                  return const SizedBox.expand(
                    key: Key('full-screen-root-content'),
                    child: ColoredBox(color: Colors.blue),
                  );
                },
              ),
          exploreBuilder: (_) => const SizedBox(),
          notificationsBuilder: (_) => const SizedBox(),
          profileBuilder: (_, _) => const SizedBox(),
        ),
      ),
    );
    await tester.pump();

    expect(rootBottomPadding, 0);
    expect(
      tester
          .getBottomRight(find.byKey(const Key('full-screen-root-content')))
          .dy,
      844,
    );
    expect(
      find.ancestor(
        of: find.byType(GubifyBottomNavigationBar),
        matching: find.byType(Stack),
      ),
      findsWidgets,
    );
  });

  testWidgets('switches all tabs and Home callbacks without pushing routes', (
    tester,
  ) async {
    await tester.pumpWidget(buildShell());

    await tester.tap(find.text('Open Explore from Home'));
    await tester.pump();
    expect(find.text('Explore root'), findsOneWidget);
    expect(find.byType(GubifyBottomNavigationBar), findsOneWidget);

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pump();
    expect(find.text('Global notifications placeholder'), findsOneWidget);

    await tester.tap(find.byTooltip('Home'));
    await tester.pump();
    await tester.tap(find.text('Open Profile from Home'));
    await tester.pump();
    expect(find.text('Profile root'), findsOneWidget);

    await tester.tap(find.byTooltip('Home'));
    await tester.pump();
    expect(find.text('Home root'), findsOneWidget);
  });

  for (final subsection in ['My Gubs', 'Join a Gub']) {
    testWidgets(
      '$subsection stays inside the shell and system Back returns Home',
      (tester) async {
        await tester.pumpWidget(buildShell());

        await tester.tap(find.text('Open $subsection'));
        await tester.pump();
        expect(find.text('$subsection subsection'), findsOneWidget);
        expect(find.byType(GubifyBottomNavigationBar), findsOneWidget);

        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.text('Home root'), findsOneWidget);
        expect(find.byType(GubifyBottomNavigationBar), findsOneWidget);
      },
    );

    testWidgets('$subsection left-edge swipe returns Home', (tester) async {
      await tester.pumpWidget(buildShell());
      await tester.tap(find.text('Open $subsection'));
      await tester.pump();

      final gesture = await tester.startGesture(const Offset(10, 220));
      await gesture.moveBy(const Offset(90, 0));
      await gesture.up();
      await tester.pump();

      expect(find.text('Home root'), findsOneWidget);
      expect(find.byType(GubifyBottomNavigationBar), findsOneWidget);
    });
  }

  testWidgets('specific Gub covers My Gubs and Back restores it with navbar', (
    tester,
  ) async {
    await tester.pumpWidget(buildShell());
    await tester.tap(find.text('Open My Gubs'));
    await tester.pump();

    await tester.tap(find.text('Open specific Gub'));
    await tester.pumpAndSettle();
    expect(find.text('Specific Gub'), findsOneWidget);
    expect(find.byType(GubifyBottomNavigationBar), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('My Gubs subsection'), findsOneWidget);
    expect(find.byType(GubifyBottomNavigationBar), findsOneWidget);
  });

  testWidgets('specific Gub edge swipe restores My Gubs with navbar', (
    tester,
  ) async {
    await tester.pumpWidget(buildShell());
    await tester.tap(find.text('Open My Gubs'));
    await tester.pump();
    await tester.tap(find.text('Open specific Gub'));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(const Offset(10, 220));
    await gesture.moveBy(const Offset(90, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('My Gubs subsection'), findsOneWidget);
    expect(find.byType(GubifyBottomNavigationBar), findsOneWidget);
  });

  testWidgets('successful join leaves My Gubs underneath the joined Gub', (
    tester,
  ) async {
    await tester.pumpWidget(buildShell());
    await tester.tap(find.text('Open Join a Gub'));
    await tester.pump();

    await tester.tap(find.text('Complete join'));
    await tester.pumpAndSettle();
    expect(find.text('Joined Gub joined-1'), findsOneWidget);
    expect(find.byType(GubifyBottomNavigationBar), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('My Gubs subsection'), findsOneWidget);
    expect(find.byType(GubifyBottomNavigationBar), findsOneWidget);
  });

  testWidgets('successful create leaves My Gubs underneath the created Gub', (
    tester,
  ) async {
    await tester.pumpWidget(buildShell());
    await tester.tap(find.text('Open Create Gub'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Complete creation'));
    await tester.pumpAndSettle();

    expect(find.text('Joined Gub created-1'), findsOneWidget);
    expect(find.byType(GubifyBottomNavigationBar), findsNothing);
    expect(
      find.byType(MainNavigationShell, skipOffstage: false),
      findsOneWidget,
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('My Gubs subsection'), findsOneWidget);
    expect(find.byType(GubifyBottomNavigationBar), findsOneWidget);
    expect(
      find.byType(MainNavigationShell, skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets(
    'successful Community creation leaves My Gubs underneath the Community',
    (tester) async {
      await tester.pumpWidget(buildShell());
      await tester.tap(find.text('Open Create Gub'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Complete Community creation'));
      await tester.pumpAndSettle();

      expect(find.text('Created Community community-1'), findsOneWidget);
      expect(find.byType(GubifyBottomNavigationBar), findsNothing);
      expect(
        find.byType(MainNavigationShell, skipOffstage: false),
        findsOneWidget,
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('My Gubs subsection'), findsOneWidget);
      expect(find.byType(GubifyBottomNavigationBar), findsOneWidget);
      expect(
        find.byType(MainNavigationShell, skipOffstage: false),
        findsOneWidget,
      );
    },
  );

  testWidgets('specific Gub exit returns to the existing shell My Gubs', (
    tester,
  ) async {
    await tester.pumpWidget(buildShell());
    await tester.tap(find.text('Open Join a Gub'));
    await tester.pump();
    await tester.tap(find.text('Complete join'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Exit specific Gub'));
    await tester.pumpAndSettle();

    expect(find.text('My Gubs subsection'), findsOneWidget);
    expect(find.byType(GubifyBottomNavigationBar), findsOneWidget);
    expect(
      find.byType(MainNavigationShell, skipOffstage: false),
      findsOneWidget,
    );
  });

  for (final action in ['Leave', 'Delete', 'Access loss']) {
    testWidgets(
      'Profile Community $action returns to the same shell and keeps Explore state',
      (tester) async {
        await tester.pumpWidget(buildShell());
        await tester.tap(find.byTooltip('Explore'));
        await tester.pump();
        await tester.enterText(find.byType(TextField), 'cached gardening');

        await tester.tap(find.byTooltip('Profile'));
        await tester.pump();
        await tester.tap(find.text('Open Profile Community'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();

        expect(find.text('My Gubs subsection'), findsOneWidget);
        expect(find.byType(GubifyBottomNavigationBar), findsOneWidget);
        expect(
          find.byType(MainNavigationShell, skipOffstage: false),
          findsOneWidget,
        );

        await tester.tap(find.byTooltip('Explore'));
        await tester.pump();
        expect(find.text('cached gardening'), findsOneWidget);
      },
    );
  }

  for (final subsection in ['My Gubs', 'Join a Gub']) {
    testWidgets('re-tapping Home returns $subsection to Welcome', (
      tester,
    ) async {
      await tester.pumpWidget(buildShell());
      await tester.tap(find.text('Open $subsection'));
      await tester.pump();

      await tester.tap(find.byTooltip('Home'));
      await tester.pump();

      expect(find.text('Home root'), findsOneWidget);
    });
  }

  testWidgets('re-tapping Home on Welcome is a no-op', (tester) async {
    var homeBuilds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MainNavigationShell(
          userId: 'user-1',
          isAnonymous: false,
          currentUserProfile: Future.value(
            const UserProfileModel(
              userId: 'user-1',
              displayName: 'Sami',
              isCurrentUser: true,
            ),
          ),
          homeBuilder:
              (
                context,
                onExplore,
                onProfile,
                onCreateGub,
                onMyGubs,
                onJoinGub,
              ) {
                homeBuilds += 1;
                return const Scaffold(body: Text('Welcome probe'));
              },
          exploreBuilder: (_) => const SizedBox(),
          notificationsBuilder: (_) => const SizedBox(),
          profileBuilder: (_, _) => const SizedBox(),
        ),
      ),
    );
    await tester.pump();
    final buildsBeforeRetap = homeBuilds;

    await tester.tap(find.byTooltip('Home'));
    await tester.pump();

    expect(homeBuilds, buildsBeforeRetap);
    expect(find.text('Welcome probe'), findsOneWidget);
  });

  testWidgets('global root tabs do not expose edge swipe back', (tester) async {
    await tester.pumpWidget(buildShell());
    expect(find.byType(GubifySwipeBack), findsNothing);

    await tester.tap(find.byTooltip('Explore'));
    await tester.pump();
    expect(find.byType(GubifySwipeBack), findsNothing);
  });

  testWidgets('preserves Explore state across tab switches', (tester) async {
    await tester.pumpWidget(buildShell());
    await tester.tap(find.byTooltip('Explore'));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'gardening');
    await tester.tap(find.byTooltip('Profile'));
    await tester.pump();
    await tester.tap(find.byTooltip('Explore'));
    await tester.pump();

    expect(find.text('gardening'), findsOneWidget);
  });

  testWidgets('a pushed detail covers the shell and returns to Explore', (
    tester,
  ) async {
    await tester.pumpWidget(buildShell());
    await tester.tap(find.byTooltip('Explore'));
    await tester.pump();

    await tester.tap(find.text('Open detail'));
    await tester.pumpAndSettle();
    expect(find.text('Pushed detail'), findsOneWidget);
    expect(find.byType(GubifyBottomNavigationBar), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Explore root'), findsOneWidget);
    expect(find.byType(GubifyBottomNavigationBar), findsOneWidget);
  });

  for (final destination in ['Explore', 'Notifications', 'Profile']) {
    testWidgets('system Back from $destination switches to Home', (
      tester,
    ) async {
      await tester.pumpWidget(buildShell());
      await tester.tap(find.byTooltip(destination));
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(find.text('Home root'), findsOneWidget);
      expect(find.byType(GubifyBottomNavigationBar), findsOneWidget);
    });
  }

  testWidgets('floating bar does not overflow a 320x426 viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 426));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildShell(size: const Size(320, 426)));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      tester.getBottomRight(find.byType(GubifyBottomNavigationBar)).dy,
      lessThanOrEqualTo(426),
    );
  });

  testWidgets('real non-scrollable Home and bar fit 320x426', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 426));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MainNavigationShell(
          userId: 'user-1',
          isAnonymous: false,
          currentUserProfile: Future.value(
            const UserProfileModel(
              userId: 'user-1',
              displayName: 'Test',
              isCurrentUser: true,
            ),
          ),
          homeBuilder:
              (
                context,
                onExplore,
                onProfile,
                onCreateGub,
                onMyGubs,
                onJoinGub,
              ) => WelcomeScreen(
                headerOverride: const SizedBox(height: 52),
                greetingOverride: const SizedBox(
                  height: 31,
                  child: Center(child: Text('Hi, Test')),
                ),
                onExploreCommunities: onExplore,
                onOpenPersonalProfile: onProfile,
                onCreateGub: onCreateGub,
                onOpenMyGubs: onMyGubs,
                onOpenJoinGub: onJoinGub,
                globalRankingLoader: _emptyRanking,
                compactForBottomNavigation: true,
              ),
          exploreBuilder: (_) => const SizedBox(),
          notificationsBuilder: (_) => const SizedBox(),
          profileBuilder: (_, _) => const SizedBox(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.byTooltip('Create Gub'), findsOneWidget);
    expect(find.byType(GubifyBottomNavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _HomeProbe extends StatelessWidget {
  const _HomeProbe({
    required this.onExplore,
    required this.onProfile,
    required this.onCreateGub,
    required this.onMyGubs,
    required this.onJoinGub,
  });

  final VoidCallback onExplore;
  final VoidCallback onProfile;
  final VoidCallback onCreateGub;
  final VoidCallback onMyGubs;
  final VoidCallback onJoinGub;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        const Text('Home root'),
        TextButton(
          onPressed: onExplore,
          child: const Text('Open Explore from Home'),
        ),
        TextButton(
          onPressed: onProfile,
          child: const Text('Open Profile from Home'),
        ),
        TextButton(
          onPressed: onCreateGub,
          child: const Text('Open Create Gub'),
        ),
        TextButton(onPressed: onMyGubs, child: const Text('Open My Gubs')),
        TextButton(onPressed: onJoinGub, child: const Text('Open Join a Gub')),
      ],
    ),
  );
}

class _CreateGubProbe extends StatelessWidget {
  const _CreateGubProbe({
    required this.onCreated,
    required this.onCommunityCreated,
  });

  final ValueChanged<String> onCreated;
  final ValueChanged<CommunityModel> onCommunityCreated;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        TextButton(
          onPressed: () => onCreated('created-1'),
          child: const Text('Complete creation'),
        ),
        TextButton(
          onPressed: () => onCommunityCreated(
            const CommunityModel(
              communityId: 'community-1',
              name: 'Created Community',
              ownerId: 'user-1',
              memberCount: 1,
              visibility: CommunityModel.publicVisibility,
              createdAt: null,
              type: CommunityModel.defaultType,
              language: CommunityModel.defaultLanguage,
              description: '',
              accessMode: CommunityModel.openAccessMode,
            ),
          ),
          child: const Text('Complete Community creation'),
        ),
      ],
    ),
  );
}

class _MyGubsProbe extends StatelessWidget {
  const _MyGubsProbe({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => GubifySwipeBack(
    onBack: onBack,
    child: Scaffold(
      body: Column(
        children: [
          const Text('My Gubs subsection'),
          TextButton(onPressed: onBack, child: const Text('Back to Home')),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const GubifySwipeBack(
                  child: Scaffold(body: Text('Specific Gub')),
                ),
              ),
            ),
            child: const Text('Open specific Gub'),
          ),
        ],
      ),
    ),
  );
}

class _JoinGubProbe extends StatelessWidget {
  const _JoinGubProbe({required this.onBack, required this.onJoined});

  final VoidCallback onBack;
  final ValueChanged<String> onJoined;

  @override
  Widget build(BuildContext context) => GubifySwipeBack(
    onBack: onBack,
    child: Scaffold(
      body: Column(
        children: [
          const Text('Join a Gub subsection'),
          TextButton(onPressed: onBack, child: const Text('Back to Home')),
          TextButton(
            onPressed: () => onJoined('joined-1'),
            child: const Text('Complete join'),
          ),
        ],
      ),
    ),
  );
}

class _StatefulExploreProbe extends StatefulWidget {
  const _StatefulExploreProbe();

  @override
  State<_StatefulExploreProbe> createState() => _StatefulExploreProbeState();
}

class _StatefulExploreProbeState extends State<_StatefulExploreProbe> {
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        const Text('Explore root'),
        const TextField(),
        TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Pushed detail')),
            ),
          ),
          child: const Text('Open detail'),
        ),
      ],
    ),
  );
}

class _ProfileCommunityProbe extends StatelessWidget {
  const _ProfileCommunityProbe({required this.onExitToMyGubs});

  final VoidCallback onExitToMyGubs;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        const Text('Profile root'),
        FilledButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                body: Column(
                  children: [
                    for (final action in ['Leave', 'Delete', 'Access loss'])
                      FilledButton(
                        onPressed: onExitToMyGubs,
                        child: Text(action),
                      ),
                  ],
                ),
              ),
            ),
          ),
          child: const Text('Open Profile Community'),
        ),
      ],
    ),
  );
}
