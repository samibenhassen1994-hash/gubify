import 'package:flutter/material.dart';

import '../../../widgets/gub_screen_background.dart';
import '../models/community_model.dart';
import '../services/community_service.dart';
import '../widgets/community_explorer_card.dart';
import '../widgets/community_filters_sheet.dart';
import 'gub_community_home_screen.dart';

class CommunityExplorerScreen extends StatefulWidget {
  const CommunityExplorerScreen({super.key});

  @override
  State<CommunityExplorerScreen> createState() =>
      _CommunityExplorerScreenState();
}

class _CommunityExplorerScreenState extends State<CommunityExplorerScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _joiningCommunityIds = <String>{};

  late Stream<List<CommunityModel>> _communitiesStream;
  late Stream<Set<String>> _joinedCommunityIdsStream;
  CommunityExplorerFilters _filters = const CommunityExplorerFilters();

  @override
  void initState() {
    super.initState();
    _communitiesStream = CommunityService.instance.publicCommunitiesStream();
    _joinedCommunityIdsStream = CommunityService.instance
        .joinedCommunityIdsStream();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  List<CommunityModel> _filteredCommunities(List<CommunityModel> communities) {
    final query = _searchController.text.trim().toLowerCase();

    return communities
        .where((community) {
          final matchesQuery =
              query.isEmpty || community.name.toLowerCase().contains(query);
          final matchesType =
              _filters.type == null || community.type == _filters.type;
          final matchesLanguage =
              _filters.language == null ||
              community.language == _filters.language;
          return matchesQuery && matchesType && matchesLanguage;
        })
        .toList(growable: false);
  }

  Future<void> _openFilters() async {
    final filters = await showModalBottomSheet<CommunityExplorerFilters>(
      context: context,
      showDragHandle: true,
      builder: (_) => CommunityFiltersSheet(initialFilters: _filters),
    );
    if (!mounted || filters == null) return;

    setState(() => _filters = filters);
  }

  void _retry() {
    setState(() {
      _communitiesStream = CommunityService.instance.publicCommunitiesStream();
      _joinedCommunityIdsStream = CommunityService.instance
          .joinedCommunityIdsStream();
    });
  }

  Future<void> _joinCommunity(CommunityModel community) async {
    if (_joiningCommunityIds.contains(community.communityId)) return;

    setState(() => _joiningCommunityIds.add(community.communityId));
    try {
      final joinedCommunity = await CommunityService.instance.joinCommunity(
        communityId: community.communityId,
      );
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GubCommunityHomeScreen(
            communityId: joinedCommunity.communityId,
            initialCommunity: joinedCommunity,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Unable to join the community. Please try again."),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _joiningCommunityIds.remove(community.communityId));
      }
    }
  }

  void _openCommunity(CommunityModel community) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GubCommunityHomeScreen(
          communityId: community.communityId,
          initialCommunity: community,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GubScreenBackground(
      variant: GubBackgroundAssignments.profiles,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: IconButton(
            tooltip: "Back",
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: const Text("Explore communities"),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: SearchBar(
                        controller: _searchController,
                        hintText: "Search communities",
                        leading: const Icon(Icons.search_rounded),
                        padding: const WidgetStatePropertyAll(
                          EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filledTonal(
                      tooltip: "Filter communities",
                      onPressed: _openFilters,
                      icon: Badge(
                        isLabelVisible: _filters.hasActiveFilters,
                        child: const Icon(Icons.filter_list_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<CommunityModel>>(
                  stream: _communitiesStream,
                  builder: (context, communitiesSnapshot) {
                    if (communitiesSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (communitiesSnapshot.hasError) {
                      return _ExplorerErrorState(onRetry: _retry);
                    }

                    final communities = communitiesSnapshot.data ?? const [];
                    return StreamBuilder<Set<String>>(
                      stream: _joinedCommunityIdsStream,
                      builder: (context, joinedSnapshot) {
                        if (joinedSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (joinedSnapshot.hasError) {
                          return _ExplorerErrorState(onRetry: _retry);
                        }

                        final filtered = _filteredCommunities(communities);
                        if (filtered.isEmpty) {
                          return _ExplorerEmptyState(
                            isSearching:
                                _searchController.text.trim().isNotEmpty ||
                                _filters.hasActiveFilters,
                          );
                        }

                        final joinedIds =
                            joinedSnapshot.data ?? const <String>{};
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final community = filtered[index];
                            return CommunityExplorerCard(
                              community: community,
                              isJoined: joinedIds.contains(
                                community.communityId,
                              ),
                              isJoining: _joiningCommunityIds.contains(
                                community.communityId,
                              ),
                              onJoin: () => _joinCommunity(community),
                              onOpen: () => _openCommunity(community),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExplorerEmptyState extends StatelessWidget {
  final bool isSearching;

  const _ExplorerEmptyState({required this.isSearching});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          isSearching
              ? "No communities match your search."
              : "No public communities yet.",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Color(0xFF475569)),
        ),
      ),
    );
  }
}

class _ExplorerErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ExplorerErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 44,
              color: Color(0xFF64748B),
            ),
            const SizedBox(height: 12),
            const Text("Unable to load communities."),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text("Try again"),
            ),
          ],
        ),
      ),
    );
  }
}
