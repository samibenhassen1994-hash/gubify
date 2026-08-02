import 'package:flutter/material.dart';

import '../../../modules/chat/widgets/gub_chat_overlay.dart';
import '../invite_members_screen.dart';

typedef OpenInviteMembersAction =
    Future<void> Function(BuildContext context, String gubId);

class InviteMembersButton extends StatefulWidget {
  final String gubId;
  final OpenInviteMembersAction? openAction;

  const InviteMembersButton({super.key, required this.gubId, this.openAction});

  @override
  State<InviteMembersButton> createState() => _InviteMembersButtonState();
}

class _InviteMembersButtonState extends State<InviteMembersButton> {
  bool _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final action = widget.openAction ?? _openScreen;
      await action(context, widget.gubId);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  static Future<void> _openScreen(BuildContext context, String gubId) {
    return GubChatOverlay.runWithChatOverlayHidden(
      () => Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => InviteMembersScreen(gubId: gubId)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: FilledButton.icon(
        icon: const Icon(Icons.person_add),
        label: const Text("Invite Members"),
        onPressed: _opening ? null : _open,
      ),
    );
  }
}
