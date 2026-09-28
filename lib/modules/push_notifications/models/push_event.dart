sealed class PushEvent {
  const PushEvent();

  const factory PushEvent.taskAssigned({
    required String gubId,
    required String taskId,
  }) = _TaskAssignedPushEvent;

  const factory PushEvent.proposalCreated({
    required String gubId,
    required String proposalId,
  }) = _ProposalCreatedPushEvent;

  const factory PushEvent.communityAnswerCreated({
    required String communityId,
    required String askId,
    required String answerId,
  }) = _CommunityAnswerCreatedPushEvent;

  const factory PushEvent.communityBestAnswerSelected({
    required String communityId,
    required String askId,
    required String answerId,
  }) = _CommunityBestAnswerSelectedPushEvent;

  const factory PushEvent.communityJoinRequestCreated({
    required String communityId,
    required String requesterUid,
  }) = _CommunityJoinRequestCreatedPushEvent;

  const factory PushEvent.communityJoinRequestResolved({
    required String communityId,
    required String requesterUid,
  }) = _CommunityJoinRequestResolvedPushEvent;

  Map<String, String> toJson();
}

final class _TaskAssignedPushEvent extends PushEvent {
  const _TaskAssignedPushEvent({required this.gubId, required this.taskId});

  final String gubId;
  final String taskId;

  @override
  Map<String, String> toJson() => {
    'type': 'task_assigned',
    'gubId': gubId,
    'taskId': taskId,
  };
}

final class _ProposalCreatedPushEvent extends PushEvent {
  const _ProposalCreatedPushEvent({
    required this.gubId,
    required this.proposalId,
  });

  final String gubId;
  final String proposalId;

  @override
  Map<String, String> toJson() => {
    'type': 'proposal_created',
    'gubId': gubId,
    'proposalId': proposalId,
  };
}

final class _CommunityAnswerCreatedPushEvent extends PushEvent {
  const _CommunityAnswerCreatedPushEvent({
    required this.communityId,
    required this.askId,
    required this.answerId,
  });

  final String communityId;
  final String askId;
  final String answerId;

  @override
  Map<String, String> toJson() => {
    'type': 'community_answer_created',
    'communityId': communityId,
    'askId': askId,
    'answerId': answerId,
  };
}

final class _CommunityBestAnswerSelectedPushEvent extends PushEvent {
  const _CommunityBestAnswerSelectedPushEvent({
    required this.communityId,
    required this.askId,
    required this.answerId,
  });

  final String communityId;
  final String askId;
  final String answerId;

  @override
  Map<String, String> toJson() => {
    'type': 'community_best_answer_selected',
    'communityId': communityId,
    'askId': askId,
    'answerId': answerId,
  };
}

final class _CommunityJoinRequestCreatedPushEvent extends PushEvent {
  const _CommunityJoinRequestCreatedPushEvent({
    required this.communityId,
    required this.requesterUid,
  });

  final String communityId;
  final String requesterUid;

  @override
  Map<String, String> toJson() => {
    'type': 'community_join_request_created',
    'communityId': communityId,
    'requesterUid': requesterUid,
  };
}

final class _CommunityJoinRequestResolvedPushEvent extends PushEvent {
  const _CommunityJoinRequestResolvedPushEvent({
    required this.communityId,
    required this.requesterUid,
  });

  final String communityId;
  final String requesterUid;

  @override
  Map<String, String> toJson() => {
    'type': 'community_join_request_resolved',
    'communityId': communityId,
    'requesterUid': requesterUid,
  };
}
