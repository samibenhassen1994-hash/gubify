import 'package:flutter/material.dart';

import '../modules/community/screens/community_explorer_screen.dart';
import '../modules/community/screens/gub_community_home_screen.dart';
import '../modules/community/models/community_model.dart';
import '../modules/notifications/screens/global_notifications_screen.dart';
import '../modules/profile/models/user_profile_model.dart';
import '../modules/profile/screens/personal_profile_screen.dart';
import '../modules/profile/services/user_profile_service.dart';
import '../widgets/gubify_bottom_navigation_bar.dart';
import 'gub/create_gub_screen.dart';
import 'gub/gub_screen.dart';
import 'gub/join_gub_screen.dart';
import 'gub/my_gubs_screen.dart';
import 'welcome_screen.dart';

typedef MainHomeBuilder =
    Widget Function(
      BuildContext context,
      VoidCallback onExplore,
      VoidCallback onProfile,
      VoidCallback onCreateGub,
      VoidCallback onMyGubs,
      VoidCallback onJoinGub,
    );

typedef MainCreateGubBuilder =
    Widget Function(
      BuildContext context,
      ValueChanged<String> onCreated,
      ValueChanged<CommunityModel> onCommunityCreated,
    );

typedef MainCreatedCommunityBuilder =
    Widget Function(
      BuildContext context,
      CommunityModel community,
      VoidCallback onExitToMyGubs,
    );

typedef MainMyGubsBuilder =
    Widget Function(BuildContext context, VoidCallback onBack);
typedef MainProfileBuilder =
    Widget Function(BuildContext context, VoidCallback onExitToMyGubs);
typedef MainJoinGubBuilder =
    Widget Function(
      BuildContext context,
      VoidCallback onBack,
      ValueChanged<String> onJoined,
    );
typedef JoinedGubBuilder =
    Widget Function(
      BuildContext context,
      String gubId,
      VoidCallback onExitToMyGubs,
    );

enum _HomeDestination { welcome, myGubs, joinGub }

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({
    super.key,
    required this.userId,
    required this.isAnonymous,
    this.homeBuilder,
    this.exploreBuilder,
    this.notificationsBuilder,
    this.profileBuilder,
    this.createGubBuilder,
    this.createdCommunityBuilder,
    this.myGubsBuilder,
    this.joinGubBuilder,
    this.joinedGubBuilder,
    this.currentUserProfile,
  });

  final String userId;
  final bool isAnonymous;
  final MainHomeBuilder? homeBuilder;
  final WidgetBuilder? exploreBuilder;
  final WidgetBuilder? notificationsBuilder;
  final MainProfileBuilder? profileBuilder;
  final MainCreateGubBuilder? createGubBuilder;
  final MainCreatedCommunityBuilder? createdCommunityBuilder;
  final MainMyGubsBuilder? myGubsBuilder;
  final MainJoinGubBuilder? joinGubBuilder;
  final JoinedGubBuilder? joinedGubBuilder;
  final Future<UserProfileModel>? currentUserProfile;

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  static const _homeIndex = 0;
  static const _exploreIndex = 1;
  static const _profileIndex = 3;
  final List<Widget?> _pages = List<Widget?>.filled(4, null);
  late final Future<UserProfileModel> _currentUserProfile;
  var _selectedIndex = _homeIndex;
  var _homeDestination = _HomeDestination.welcome;

  @override
  void initState() {
    super.initState();
    _currentUserProfile =
        widget.currentUserProfile ??
        UserProfileService.instance.loadPersonalProfile(userId: widget.userId);
  }

  void _select(int index) {
    if (index == _selectedIndex) {
      if (index == _homeIndex && _homeDestination != _HomeDestination.welcome) {
        _showWelcome();
      }
      return;
    }
    setState(() => _selectedIndex = index);
  }

  void _showHomeDestination(_HomeDestination destination) {
    setState(() {
      _selectedIndex = _homeIndex;
      _homeDestination = destination;
    });
  }

  void _showWelcome() => _showHomeDestination(_HomeDestination.welcome);

  void _returnToMyGubs() {
    _showHomeDestination(_HomeDestination.myGubs);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Widget _buildSpecificGub(BuildContext context, String gubId) =>
      widget.joinedGubBuilder?.call(context, gubId, _returnToMyGubs) ??
      GubScreen(gubId: gubId, onExitToMyGubs: _returnToMyGubs);

  void _openCreateGub() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) =>
            widget.createGubBuilder?.call(
              routeContext,
              _openCreatedGub,
              _openCreatedCommunity,
            ) ??
            CreateGubScreen(
              onPrivateGubCreated: _openCreatedGub,
              onCommunityCreated: _openCreatedCommunity,
              onExitToMyGubs: _returnToMyGubs,
            ),
      ),
    );
  }

  void _openCreatedGub(String gubId) {
    _showHomeDestination(_HomeDestination.myGubs);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (context) => _buildSpecificGub(context, gubId),
      ),
    );
  }

  void _openCreatedCommunity(CommunityModel community) {
    _showHomeDestination(_HomeDestination.myGubs);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (context) =>
            widget.createdCommunityBuilder?.call(
              context,
              community,
              _returnToMyGubs,
            ) ??
            GubCommunityHomeScreen(
              communityId: community.communityId,
              initialCommunity: community,
              onExitToMyGubs: _returnToMyGubs,
            ),
      ),
    );
  }

  void _openJoinedGub(String gubId) {
    _showHomeDestination(_HomeDestination.myGubs);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _buildSpecificGub(context, gubId),
      ),
    );
  }

  Widget _buildHome() {
    return switch (_homeDestination) {
      _HomeDestination.welcome =>
        widget.homeBuilder?.call(
              context,
              () => _select(_exploreIndex),
              () => _select(_profileIndex),
              _openCreateGub,
              () => _showHomeDestination(_HomeDestination.myGubs),
              () => _showHomeDestination(_HomeDestination.joinGub),
            ) ??
            WelcomeScreen(
              onExploreCommunities: () => _select(_exploreIndex),
              onOpenPersonalProfile: () => _select(_profileIndex),
              onCreateGub: _openCreateGub,
              onOpenMyGubs: () => _showHomeDestination(_HomeDestination.myGubs),
              onOpenJoinGub: () =>
                  _showHomeDestination(_HomeDestination.joinGub),
              compactForBottomNavigation: true,
            ),
      _HomeDestination.myGubs =>
        widget.myGubsBuilder?.call(context, _showWelcome) ??
            MyGubsScreen(
              onBack: _showWelcome,
              onExitToMyGubs: _returnToMyGubs,
              onExploreCommunities: () => _select(_exploreIndex),
              additionalBottomScrollPadding:
                  GubifyBottomNavigationBar.overlayScrollClearance,
            ),
      _HomeDestination.joinGub =>
        widget.joinGubBuilder?.call(context, _showWelcome, _openJoinedGub) ??
            JoinGubScreen(
              onBack: _showWelcome,
              onJoined: _openJoinedGub,
              additionalBottomScrollPadding:
                  GubifyBottomNavigationBar.overlayScrollClearance,
            ),
    };
  }

  Widget _buildPage(int index) {
    return switch (index) {
      0 => _buildHome(),
      1 =>
        widget.exploreBuilder?.call(context) ??
            CommunityExplorerScreen(
              showBackButton: false,
              additionalBottomScrollPadding:
                  GubifyBottomNavigationBar.overlayScrollClearance,
              onExitToMyGubs: _returnToMyGubs,
            ),
      2 =>
        widget.notificationsBuilder?.call(context) ??
            const GlobalNotificationsScreen(),
      3 =>
        widget.profileBuilder?.call(context, _returnToMyGubs) ??
            PersonalProfileScreen(
              userId: widget.userId,
              onExitToMyGubs: _returnToMyGubs,
              profileFuture: _currentUserProfile,
              showCommunityProgress: !widget.isAnonymous,
              additionalBottomScrollPadding:
                  GubifyBottomNavigationBar.overlayScrollClearance,
              communitiesStream: widget.isAnonymous
                  ? Stream<List<CommunityMembershipModel>>.value(const [])
                  : null,
            ),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _pageAt(int index) {
    if (index == _homeIndex) return _buildPage(index);
    if (index == _selectedIndex) {
      _pages[index] ??= _buildPage(index);
    }
    return _pages[index] ?? const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final compactNavigation = mediaQuery.size.height < 500;

    return PopScope<Object?>(
      canPop:
          _selectedIndex == _homeIndex &&
          _homeDestination == _HomeDestination.welcome,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_selectedIndex != _homeIndex) {
          _select(_homeIndex);
        } else if (_homeDestination != _HomeDestination.welcome) {
          _showWelcome();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  for (var index = 0; index < 4; index++) _pageAt(index),
                ],
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 0,
              child: SafeArea(
                top: false,
                minimum: EdgeInsets.only(bottom: compactNavigation ? 4 : 12),
                child: FutureBuilder<UserProfileModel>(
                  future: _currentUserProfile,
                  builder: (context, snapshot) => GubifyBottomNavigationBar(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: _select,
                    compact: compactNavigation,
                    profileDisplayName: snapshot.data?.displayName,
                    profilePhotoUrl: snapshot.data?.photoUrl,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
