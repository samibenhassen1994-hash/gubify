class DeletionContext {
  final bool canDelete;
  final bool currentUserIsOwner;
  final String? creatorId;
  final String ownerId;

  const DeletionContext({
    required this.canDelete,
    required this.currentUserIsOwner,
    required this.creatorId,
    required this.ownerId,
  });

  bool get hasKnownCreator => creatorId?.isNotEmpty == true;
  bool get creatorIsOwner => hasKnownCreator && creatorId == ownerId;
  bool get startsCooldown => hasKnownCreator && !creatorIsOwner;
  bool get cooldownAppliesToOriginalCreator =>
      startsCooldown && currentUserIsOwner;
}
