import 'package:flutter/material.dart';

import '../../../widgets/gub_content_card.dart';
import '../../../widgets/gub_screen_background.dart';
import '../models/community_access_request_model.dart';
import '../models/community_model.dart';
import '../services/community_service.dart';

class CommunityJoinRequestsScreen extends StatefulWidget {
  final CommunityModel community;
  final Future<List<CommunityAccessRequestModel>> Function(String communityId)?
  pendingRequestsLoader;

  const CommunityJoinRequestsScreen({
    super.key,
    required this.community,
    this.pendingRequestsLoader,
  });

  @override
  State<CommunityJoinRequestsScreen> createState() =>
      _CommunityJoinRequestsScreenState();
}

class _CommunityJoinRequestsScreenState
    extends State<CommunityJoinRequestsScreen> {
  final Set<String> _processingUserIds = {};
  late Future<List<CommunityAccessRequestModel>> _requestsFuture;

  bool get _usesJoinRequests => widget.community.usesJoinRequests;

  @override
  void initState() {
    super.initState();
    if (_usesJoinRequests) {
      _reload();
    }
  }

  void _reload() {
    _requestsFuture =
        widget.pendingRequestsLoader?.call(widget.community.communityId) ??
        CommunityService.instance.pendingJoinRequests(
          widget.community.communityId,
        );
  }

  Future<void> _resolve(
    CommunityAccessRequestModel request, {
    required bool approve,
  }) async {
    if (!_processingUserIds.add(request.userId)) return;
    setState(() {});
    try {
      if (approve) {
        await CommunityService.instance.approveJoinRequest(
          communityId: widget.community.communityId,
          userId: request.userId,
        );
      } else {
        await CommunityService.instance.rejectJoinRequest(
          communityId: widget.community.communityId,
          userId: request.userId,
        );
      }
      if (!mounted) return;
      setState(_reload);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
      setState(_reload);
    } finally {
      _processingUserIds.remove(request.userId);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return GubScreenBackground(
      variant: GubBackgroundAssignments.profiles,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text("Join requests"),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: SafeArea(
          top: false,
          child: !_usesJoinRequests
              ? const _RequestsState(
                  message: 'This Community accepts members directly.',
                )
              : FutureBuilder<List<CommunityAccessRequestModel>>(
                  future: _requestsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return _RequestsState(
                        message: "Unable to load join requests.",
                        onRetry: () => setState(_reload),
                      );
                    }
                    final requests = snapshot.data ?? const [];
                    if (requests.isEmpty) {
                      return const _RequestsState(
                        message: "There are no pending requests.",
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                      itemCount: requests.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final request = requests[index];
                        final processing = _processingUserIds.contains(
                          request.userId,
                        );
                        return GubContentCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                request.displayName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: processing
                                          ? null
                                          : () => _resolve(
                                              request,
                                              approve: false,
                                            ),
                                      child: const Text("Reject"),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: processing
                                          ? null
                                          : () => _resolve(
                                              request,
                                              approve: true,
                                            ),
                                      child: processing
                                          ? const SizedBox.square(
                                              dimension: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text("Approve"),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _RequestsState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _RequestsState({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text("Try again"),
            ),
          ],
        ],
      ),
    ),
  );
}
