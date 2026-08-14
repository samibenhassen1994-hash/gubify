import 'package:flutter/material.dart';

import '../../../repositories/user_repository.dart';

class DeletedUserIdentityBuilder extends StatefulWidget {
  const DeletedUserIdentityBuilder({
    super.key,
    required this.userId,
    required this.currentDisplayName,
    required this.builder,
    this.profileExists,
    this.identity,
    this.resolveCurrentDisplayName = false,
  });

  final String userId;
  final String currentDisplayName;
  final Widget Function(BuildContext context, String displayName, bool deleted)
  builder;
  final Stream<bool>? profileExists;
  final Stream<UserIdentity>? identity;
  final bool resolveCurrentDisplayName;

  @override
  State<DeletedUserIdentityBuilder> createState() =>
      _DeletedUserIdentityBuilderState();
}

class _DeletedUserIdentityBuilderState
    extends State<DeletedUserIdentityBuilder> {
  late Stream<UserIdentity> _identity;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(DeletedUserIdentityBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.profileExists != widget.profileExists ||
        oldWidget.identity != widget.identity ||
        oldWidget.resolveCurrentDisplayName !=
            widget.resolveCurrentDisplayName) {
      _load();
    }
  }

  void _load() {
    if (widget.userId == '__deleted_user__') {
      _identity = Stream.value(const UserIdentity.missing());
      return;
    }

    _identity =
        widget.identity ??
        (widget.resolveCurrentDisplayName
            ? UserRepository.instance.userIdentityStream(widget.userId)
            : (widget.profileExists ??
                      (widget.userId.trim().isEmpty
                          ? Stream<bool>.value(true)
                          : UserRepository.instance.userExistsStream(
                              widget.userId,
                            )))
                  .map(
                    (exists) => exists
                        ? const UserIdentity.existing(null)
                        : const UserIdentity.missing(),
                  ));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserIdentity>(
      stream: _identity,
      builder: (context, snapshot) {
        final identity = snapshot.data;
        final hasTransientError = snapshot.hasError;
        final deleted = !hasTransientError && identity?.exists == false;
        final canonicalDisplayName = identity?.displayName;
        final hasCanonicalDisplayName =
            canonicalDisplayName != null && canonicalDisplayName.isNotEmpty;
        final fallbackDisplayName = widget.currentDisplayName.trim().isEmpty
            ? 'User'
            : widget.currentDisplayName;
        final displayName = deleted
            ? 'Deleted user'
            : widget.resolveCurrentDisplayName
            ? !hasTransientError && hasCanonicalDisplayName
                  ? canonicalDisplayName
                  : fallbackDisplayName
            : identity?.exists == true
            ? fallbackDisplayName
            : 'User';
        return widget.builder(context, displayName, deleted);
      },
    );
  }
}
