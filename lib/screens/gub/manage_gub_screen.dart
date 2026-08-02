import 'package:flutter/material.dart';

import '../../modules/chat/widgets/gub_chat_overlay.dart';
import '../../services/gub_deletion_service.dart';
import '../../widgets/gub_content_card.dart';
import '../../widgets/gub_screen_background.dart';
import 'widgets/delete_gub_dialog.dart';

class ManageGubScreen extends StatefulWidget {
  final String gubId;

  const ManageGubScreen({super.key, required this.gubId});

  @override
  State<ManageGubScreen> createState() => _ManageGubScreenState();
}

class _ManageGubScreenState extends State<ManageGubScreen> {
  late final Future<GubDeletionAccess> _accessFuture;

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
            const Text(
              'General',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GubContentCard(
              padding: EdgeInsets.zero,
              child: const ListTile(
                leading: Icon(Icons.edit),
                title: Text('Rename Gub'),
                subtitle: Text('Coming soon'),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
              ),
            ),
            FutureBuilder<GubDeletionAccess>(
              future: _accessFuture,
              builder: (context, snapshot) {
                final access = snapshot.data;
                if (access?.isOwner != true) {
                  return const SizedBox.shrink();
                }
                return _DeleteGubSection(
                  onDelete: () => _confirmDeletion(access!),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteGubSection extends StatelessWidget {
  final VoidCallback onDelete;

  const _DeleteGubSection({required this.onDelete});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
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
