import 'dart:async';

import 'package:flutter/material.dart';

import '../../../widgets/gub_screen_background.dart';
import '../../../widgets/gubify_swipe_back.dart';
import '../models/community_model.dart';
import '../repositories/community_repository.dart';
import '../restrictions/services/community_restriction_service.dart';
import '../services/community_service.dart';
import '../utils/community_name_key.dart';
import '../widgets/community_explorer_card.dart';
import '../widgets/community_filters_sheet.dart';
import '../widgets/community_linked_account_gate.dart';
import 'community_public_details_screen.dart';
import 'gub_community_home_screen.dart';

typedef CommunityExplorerPageLoader =
    Future<CommunityExplorerPage> Function(CommunityExplorerCursor? after);
typedef CommunityExplorerSearchPageLoader =
    Future<CommunityExplorerPage> Function(
      CommunityExplorerCursor? after,
      String searchKey,
    );
typedef CommunityDiscoveryFilter =
    Future<List<CommunityModel>> Function(List<CommunityModel> communities);
typedef CommunityOpenHandler =
    Future<void> Function(CommunityModel community, bool isJoined);

class CommunityExplorerScreen extends StatefulWidget {
  final CommunityExplorerPageLoader? pageLoader;
  final CommunityExplorerSearchPageLoader? searchPageLoader;
  final CommunityDiscoveryFilter? discoveryFilter;
  final Stream<Set<String>>? joinedCommunityIdsStream;
  final bool Function()? isAnonymous;
  final bool Function(CommunityModel community)? isOwner;
  final CommunityLinkedAccountGate? linkedAccountGate;
  final CommunityOpenHandler? onCommunityOpen;
  final bool showBackButton;
  final double additionalBottomScrollPadding;
  final VoidCallback? onExitToMyGubs;

  const CommunityExplorerScreen({
    super.key,
    this.pageLoader,
    this.searchPageLoader,
    this.discoveryFilter,
    this.joinedCommunityIdsStream,
    this.isAnonymous,
    this.isOwner,
    this.linkedAccountGate,
    this.onCommunityOpen,
    this.showBackButton = true,
    this.additionalBottomScrollPadding = 0,
    this.onExitToMyGubs,
  });

  @override
  State<CommunityExplorerScreen> createState() =>
      _CommunityExplorerScreenState();
}

class _CommunityExplorerScreenState extends State<CommunityExplorerScreen> {
  static const _pageSize = 10;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<CommunityModel> _communities = [];
  final Set<String> _seenCommunityIds = {};
  final List<CommunityExplorerCursor?> _pageStarts = [null];

  late Stream<Set<String>> _joinedCommunityIdsStream;
  late final bool Function() _isAnonymous;
  late final bool Function(CommunityModel community) _isOwner;
  CommunityExplorerFilters _filters = const CommunityExplorerFilters();
  Timer? _searchDebounce;
  String _searchKey = '';
  CommunityExplorerCursor? _nextCursor;
  Object? _loadError;
  bool _loadingInitial = true;
  bool _loadingPage = false;
  bool _hasMore = true;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _isAnonymous =
        widget.isAnonymous ??
        () =>
            widget.joinedCommunityIdsStream == null &&
            CommunityService.instance.isCurrentUserAnonymous;
    _isOwner = widget.isOwner ?? CommunityService.instance.isCurrentUserOwner;
    _joinedCommunityIdsStream = _createJoinedCommunityIdsStream();
    _searchController.addListener(_onSearchChanged);
    _loadInitialPage();
  }

  Stream<Set<String>> _createJoinedCommunityIdsStream() {
    if (_isAnonymous()) return Stream.value(const <String>{});
    return widget.joinedCommunityIdsStream ??
        CommunityService.instance.joinedCommunityIdsStream();
  }

  void _onSearchChanged() {
    final nextSearchKey = CommunityNameKey.fromName(_searchController.text);
    _searchDebounce?.cancel();
    if (nextSearchKey == _searchKey) return;
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted ||
          nextSearchKey != CommunityNameKey.fromName(_searchController.text) ||
          nextSearchKey == _searchKey) {
        return;
      }
      _searchKey = nextSearchKey;
      _retryInitialLoad();
    });
  }

  Future<void> _loadInitialPage() =>
      _loadPage(after: null, pageIndex: 0, resetPageStarts: true);

  Future<void> _loadPage({
    required CommunityExplorerCursor? after,
    required int pageIndex,
    bool resetPageStarts = false,
  }) async {
    if (_loadingPage) return;
    setState(() {
      _loadingPage = true;
      _loadError = null;
      if (pageIndex == 0) _loadingInitial = true;
    });
    try {
      final page =
          await (widget.searchPageLoader?.call(after, _searchKey) ??
              widget.pageLoader?.call(after) ??
              CommunityService.instance.loadPublicCommunitiesPage(
                after: after,
                limit: _pageSize,
                namePrefix: _searchKey,
              ));
      final discoverableCommunities =
          await (widget.discoveryFilter?.call(page.communities) ??
              CommunityRestrictionService.instance
                  .filterDiscoverableCommunities(page.communities));
      if (!mounted) return;
      setState(() {
        _communities.clear();
        _seenCommunityIds.clear();
        for (final community in discoverableCommunities) {
          if (_seenCommunityIds.add(community.communityId) &&
              _communities.length < _pageSize) {
            _communities.add(community);
          }
        }
        if (resetPageStarts) {
          _pageStarts
            ..clear()
            ..add(null);
        }
        _currentPage = pageIndex;
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore && page.nextCursor != null;
        _loadingInitial = false;
      });
      _scrollToTop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loadingInitial = false;
      });
    } finally {
      if (mounted) setState(() => _loadingPage = false);
    }
  }

  Future<void> _retryInitialLoad() async {
    setState(() {
      _communities.clear();
      _seenCommunityIds.clear();
      _pageStarts
        ..clear()
        ..add(null);
      _currentPage = 0;
      _nextCursor = null;
      _hasMore = true;
      _loadError = null;
      _loadingInitial = true;
      _joinedCommunityIdsStream = _createJoinedCommunityIdsStream();
    });
    await _loadPage(after: null, pageIndex: 0, resetPageStarts: true);
  }

  Future<void> _nextPage() async {
    final nextCursor = _nextCursor;
    if (_loadingPage || !_hasMore || nextCursor == null) return;
    final nextPageIndex = _currentPage + 1;
    if (_pageStarts.length <= nextPageIndex) _pageStarts.add(nextCursor);
    await _loadPage(
      after: _pageStarts[nextPageIndex],
      pageIndex: nextPageIndex,
    );
  }

  Future<void> _previousPage() async {
    if (_loadingPage || _currentPage == 0) return;
    final previousPageIndex = _currentPage - 1;
    await _loadPage(
      after: _pageStarts[previousPageIndex],
      pageIndex: previousPageIndex,
    );
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    });
  }

  List<CommunityModel> get _filteredCommunities {
    return _communities
        .where((community) {
          final matchesType =
              _filters.type == null || community.type == _filters.type;
          final matchesLanguage =
              _filters.language == null ||
              community.language == _filters.language;
          return matchesType && matchesLanguage;
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
            ? GubCommunityHomeScreen(
                communityId: community.communityId,
                onExitToMyGubs: widget.onExitToMyGubs,
              )
            : CommunityPublicDetailsScreen(
                communityId: community.communityId,
                onExitToMyGubs: widget.onExitToMyGubs,
              ),
      ),
    );
    if (mounted) _retryInitialLoad();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = GubScreenBackground(
      variant: GubBackgroundAssignments.profiles,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          automaticallyImplyLeading: widget.showBackButton,
          leading: widget.showBackButton
              ? IconButton(
                  tooltip: "Back",
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                )
              : null,
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
              Expanded(child: _buildResults()),
            ],
          ),
        ),
      ),
    );
    return widget.showBackButton
        ? GubifySwipeBack(child: content)
        : content;
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
        final joinedIds = joinedSnapshot.data ?? const <String>{};
        return RefreshIndicator(
          onRefresh: _retryInitialLoad,
          child: ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              28 + widget.additionalBottomScrollPadding,
            ),
            children: [
              if (filtered.isEmpty)
                _ExplorerEmptyState(
                  isSearching:
                      _searchKey.isNotEmpty || _filters.hasActiveFilters,
                )
              else
                for (final community in filtered) ...[
                  CommunityExplorerCard(
                    community: community,
                    isJoined: joinedIds.contains(community.communityId),
                    isOwner: _isOwner(community),
                    onOpen: () => _openCommunity(
                      community,
                      joinedIds.contains(community.communityId),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              if (_loadError != null)
                Center(
                  child: OutlinedButton.icon(
                    onPressed: () => _loadPage(
                      after: _pageStarts[_currentPage],
                      pageIndex: _currentPage,
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text("Retry loading page"),
                  ),
                ),
              _CommunityExplorerPagination(
                currentPage: _currentPage + 1,
                canGoPrevious: _currentPage > 0 && !_loadingPage,
                canGoNext: _hasMore && !_loadingPage,
                onPrevious: _previousPage,
                onNext: _nextPage,
              ),
            ],
          ),
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

class _CommunityExplorerPagination extends StatelessWidget {
  final int currentPage;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _CommunityExplorerPagination({
    required this.currentPage,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        OutlinedButton(
          key: const Key('community-explorer-previous-page'),
          onPressed: canGoPrevious ? onPrevious : null,
          child: const Text('Previous'),
        ),
        Text('Page $currentPage'),
        OutlinedButton(
          key: const Key('community-explorer-next-page'),
          onPressed: canGoNext ? onNext : null,
          child: const Text('Next'),
        ),
      ],
    ),
  );
}

class _ExplorerErrorState extends StatelessWidget {
  final Future<void> Function() onRetry;

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
