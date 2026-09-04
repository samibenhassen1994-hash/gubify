import 'package:flutter/material.dart';

import '../../../widgets/gub_screen_background.dart';
import '../models/community_model.dart';
import '../repositories/community_repository.dart';
import '../restrictions/services/community_restriction_service.dart';
import '../services/community_service.dart';
import '../widgets/community_explorer_card.dart';
import '../widgets/community_filters_sheet.dart';
import '../widgets/community_linked_account_gate.dart';
import 'community_public_details_screen.dart';
import 'gub_community_home_screen.dart';

typedef CommunityExplorerPageLoader =
    Future<CommunityExplorerPage> Function(CommunityExplorerCursor? after);
typedef CommunityDiscoveryFilter =
    Future<List<CommunityModel>> Function(List<CommunityModel> communities);
typedef CommunityOpenHandler =
    Future<void> Function(CommunityModel community, bool isJoined);

class CommunityExplorerScreen extends StatefulWidget {
  final CommunityExplorerPageLoader? pageLoader;
  final CommunityDiscoveryFilter? discoveryFilter;
  final Stream<Set<String>>? joinedCommunityIdsStream;
  final bool Function()? isAnonymous;
  final bool Function(CommunityModel community)? isOwner;
  final CommunityLinkedAccountGate? linkedAccountGate;
  final CommunityOpenHandler? onCommunityOpen;

  const CommunityExplorerScreen({
    super.key,
    this.pageLoader,
    this.discoveryFilter,
    this.joinedCommunityIdsStream,
    this.isAnonymous,
    this.isOwner,
    this.linkedAccountGate,
    this.onCommunityOpen,
  });

  @override
  State<CommunityExplorerScreen> createState() =>
      _CommunityExplorerScreenState();
}

class _CommunityExplorerScreenState extends State<CommunityExplorerScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<CommunityModel> _communities = [];
  final Set<String> _seenCommunityIds = {};

  late Stream<Set<String>> _joinedCommunityIdsStream;
  late final bool Function() _isAnonymous;
  late final bool Function(CommunityModel community) _isOwner;
  CommunityExplorerFilters _filters = const CommunityExplorerFilters();
  CommunityExplorerCursor? _cursor;
  Object? _loadError;
  bool _loadingInitial = true;
  bool _loadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _isAnonymous =
        widget.isAnonymous ??
        () =>
            widget.joinedCommunityIdsStream == null &&
            CommunityService.instance.isCurrentUserAnonymous;
    _isOwner =
        widget.isOwner ?? CommunityService.instance.isCurrentUserOwner;
    _joinedCommunityIdsStream = _createJoinedCommunityIdsStream();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _loadNextPage();
  }

  Stream<Set<String>> _createJoinedCommunityIdsStream() {
    if (_isAnonymous()) return Stream.value(const <String>{});
    return widget.joinedCommunityIdsStream ??
        CommunityService.instance.joinedCommunityIdsStream();
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 320) {
      return;
    }
    _loadNextPage();
  }

  Future<void> _loadNextPage() async {
    if (_loadingMore || !_hasMore) return;
    setState(() {
      _loadingMore = true;
      _loadError = null;
    });
    try {
      final page =
          await (widget.pageLoader?.call(_cursor) ??
              CommunityService.instance.loadPublicCommunitiesPage(
                after: _cursor,
              ));
      final discoverableCommunities =
          await (widget.discoveryFilter?.call(page.communities) ??
              CommunityRestrictionService.instance
                  .filterDiscoverableCommunities(page.communities));
      if (!mounted) return;
      setState(() {
        for (final community in discoverableCommunities) {
          if (_seenCommunityIds.add(community.communityId)) {
            _communities.add(community);
          }
        }
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _loadingInitial = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loadingInitial = false;
      });
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _retryInitialLoad() {
    setState(() {
      _communities.clear();
      _seenCommunityIds.clear();
      _cursor = null;
      _hasMore = true;
      _loadError = null;
      _loadingInitial = true;
      _joinedCommunityIdsStream = _createJoinedCommunityIdsStream();
    });
    _loadNextPage();
  }

  List<CommunityModel> get _filteredCommunities {
    final query = _searchController.text.trim().toLowerCase();
    return _communities
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

  Future<void> _openCommunity(CommunityModel community, bool isJoined) async {
    final canContinue =
        await (widget.linkedAccountGate?.call(context) ??
            showCommunityLinkedAccountGate(context));
    if (!mounted || !canContinue) return;
    setState(() {
      _joinedCommunityIdsStream = _createJoinedCommunityIdsStream();
    });
    if (widget.onCommunityOpen != null) {
      await widget.onCommunityOpen!(community, isJoined);
      if (mounted) _retryInitialLoad();
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => isJoined
            ? GubCommunityHomeScreen(communityId: community.communityId)
            : CommunityPublicDetailsScreen(communityId: community.communityId),
      ),
    );
    if (mounted) _retryInitialLoad();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
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
                        hintText: "Search loaded communities",
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
              Expanded(child: _buildResults()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_loadingInitial) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null && _communities.isEmpty) {
      return _ExplorerErrorState(onRetry: _retryInitialLoad);
    }

    return StreamBuilder<Set<String>>(
      stream: _joinedCommunityIdsStream,
      builder: (context, joinedSnapshot) {
        if (joinedSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (joinedSnapshot.hasError) {
          return _ExplorerErrorState(onRetry: _retryInitialLoad);
        }
        final filtered = _filteredCommunities;
        if (filtered.isEmpty && !_hasMore) {
          return _ExplorerEmptyState(
            isSearching:
                _searchController.text.trim().isNotEmpty ||
                _filters.hasActiveFilters,
          );
        }
        final joinedIds = joinedSnapshot.data ?? const <String>{};
        return ListView.separated(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          itemCount: filtered.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == filtered.length) {
              if (_loadingMore) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (_loadError != null) {
                return Center(
                  child: OutlinedButton.icon(
                    onPressed: _loadNextPage,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text("Retry loading more"),
                  ),
                );
              }
              if (_hasMore) {
                return Center(
                  child: OutlinedButton.icon(
                    onPressed: _loadNextPage,
                    icon: const Icon(Icons.expand_more_rounded),
                    label: const Text("Load more communities"),
                  ),
                );
              }
              return const SizedBox.shrink();
            }
            final community = filtered[index];
            final isJoined = joinedIds.contains(community.communityId);
            return CommunityExplorerCard(
              community: community,
              isJoined: isJoined,
              isOwner: _isOwner(community),
              onOpen: () => _openCommunity(community, isJoined),
            );
          },
        );
      },
    );
  }
}

class _ExplorerEmptyState extends StatelessWidget {
  final bool isSearching;

  const _ExplorerEmptyState({required this.isSearching});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        isSearching
            ? "No communities match the loaded results."
            : "No public communities yet.",
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16, color: Color(0xFF475569)),
      ),
    ),
  );
}

class _ExplorerErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ExplorerErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
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
