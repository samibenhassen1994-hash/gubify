import 'package:flutter/material.dart';

import '../../services/gub_deletion_service.dart';
import '../../widgets/gub_content_card.dart';
import '../../widgets/gub_screen_background.dart';

class ManageGubScreen extends StatefulWidget {
  final String gubId;

  const ManageGubScreen({super.key, required this.gubId});

  @override
  State<ManageGubScreen> createState() => _ManageGubScreenState();
}

class _ManageGubScreenState extends State<ManageGubScreen> {
  late Future<bool> _isOwnerFuture;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _isOwnerFuture = GubDeletionService.instance.isCurrentUserOwner(widget.gubId);
  }

  Future<void> _confirmDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Gub?'),
        content: const Text(
          'This permanently removes the Gub and its shared data for all members.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _isDeleting) return;

    setState(() => _isDeleting = true);
    try {
      await GubDeletionService.instance.deleteGub(widget.gubId);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Unsupported operation: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
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
            FutureBuilder<bool>(
              future: _isOwnerFuture,
              builder: (context, snapshot) {
                if (snapshot.data != true) return const SizedBox.shrink();
                return _DeleteGubSection(
                  isDeleting: _isDeleting,
                  onDelete: _confirmDeletion,
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
  final bool isDeleting;
  final VoidCallback onDelete;

  const _DeleteGubSection({required this.isDeleting, required this.onDelete});

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
          trailing: isDeleting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: isDeleting ? null : onDelete,
        ),
      ),
    ],
  );
}
