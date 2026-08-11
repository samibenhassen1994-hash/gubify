import 'package:flutter/material.dart';

import '../../modules/chat/widgets/gub_chat_overlay.dart';
import '../../services/gub_deletion_service.dart';
import '../../services/member_service.dart';
import '../../widgets/banned_users_screen.dart';
import '../../widgets/gub_content_card.dart';
import '../../widgets/gub_screen_background.dart';
import 'widgets/delete_gub_dialog.dart';
import 'my_gubs_screen.dart';

class ManageGubScreen extends StatefulWidget {
  final String gubId;

  const ManageGubScreen({super.key, required this.gubId});

  @override
  State<ManageGubScreen> createState() => _ManageGubScreenState();
}

class _ManageGubScreenState extends State<ManageGubScreen> {
  late final Future<GubDeletionAccess> _accessFuture;
  bool _isLeaving = false;

  @override
  void initState() {
    super.initState();
    _accessFuture = GubDeletionService.instance.access(widget.gubId);
  }

  Future<void> _confirmDeletion(GubDeletionAccess access) async {
    await GubChatOverlay.runWithChatOverlayHidden(() async {
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => DeleteGubDialog(
          gubName: access.gubName,
          onDelete: (confirmedName, onProgress) {
            return GubDeletionService.instance.deleteGubCompletely(
              gubId: widget.gubId,
              confirmedName: confirmedName,
              onProgress: onProgress,
            );
          },
        ),
      );
    });
  }

  Future<void> _leaveGub() async {
    final confirmed = await GubChatOverlay.runWithChatOverlayHidden(
      () => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Leave Gub?'),
          content: const Text('You will leave this Gub and lose access to it.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Leave'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || confirmed != true || _isLeaving) return;

    setState(() => _isLeaving = true);
    try {
      await MemberService.instance.leaveGub(gubId: widget.gubId);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MyGubsScreen()),
        (_) => false,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _isLeaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GubScreenBackground(
      variant: GubBackgroundAssignments.tasks,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Manage Gub'),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            FutureBuilder<GubDeletionAccess>(
              future: _accessFuture,
              builder: (context, snapshot) {
                final access = snapshot.data;
                if (access == null) {
                  return const SizedBox.shrink();
                }
                if (access.isOwner) {
                  return _DeleteGubSection(
                    onDelete: () => _confirmDeletion(access),
                    onShowBannedUsers: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BannedUsersScreen(
                          title: 'Banned users',
                          bannedUsersStream: MemberService.instance
                              .bannedUsersStream(widget.gubId),
                          onUnban: (uid) => MemberService.instance.unbanMember(
                            gubId: widget.gubId,
                            uid: uid,
                          ),
                        ),
                      ),
                    ),
                  );
                }
                return _LeaveGubSection(
                  isLeaving: _isLeaving,
                  onLeave: _leaveGub,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaveGubSection extends StatelessWidget {
  final bool isLeaving;
  final VoidCallback onLeave;

  const _LeaveGubSection({required this.isLeaving, required this.onLeave});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 30),
      GubContentCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          leading: const Icon(Icons.logout_rounded, color: Colors.red),
          title: const Text(
            'Leave Gub',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
          subtitle: const Text('Leave this Gub and lose access to it.'),
          trailing: isLeaving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: isLeaving ? null : onLeave,
        ),
      ),
    ],
  );
}

class _DeleteGubSection extends StatelessWidget {
  final VoidCallback onDelete;
  final VoidCallback onShowBannedUsers;

  const _DeleteGubSection({
    required this.onDelete,
    required this.onShowBannedUsers,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 30),
      GubContentCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          leading: const Icon(Icons.block_rounded, color: Colors.red),
          title: const Text('Banned users'),
          subtitle: const Text('View members banned from this Gub.'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: onShowBannedUsers,
        ),
      ),
      const SizedBox(height: 30),
      const Text(
        'Danger Zone',
        style: TextStyle(
          color: Colors.red,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 12),
      GubContentCard(
        padding: EdgeInsets.zero,
        color: const Color(0xFFFFF1F2),
        border: Border.all(color: const Color(0xFFFECACA)),
        child: ListTile(
          leading: const Icon(Icons.delete_forever, color: Colors.red),
          title: const Text(
            'Delete Gub',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
          subtitle: const Text('Permanently delete this Gub.'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: onDelete,
        ),
      ),
    ],
  );
}
