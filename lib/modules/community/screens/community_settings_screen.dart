import 'package:flutter/material.dart';

import '../../../widgets/gub_content_card.dart';
import '../../../widgets/gub_screen_background.dart';
import '../../../screens/welcome_screen.dart';
import '../models/community_model.dart';
import '../services/community_service.dart';

class CommunitySettingsScreen extends StatefulWidget {
  final CommunityModel community;

  const CommunitySettingsScreen({super.key, required this.community});

  @override
  State<CommunitySettingsScreen> createState() =>
      _CommunitySettingsScreenState();
}

class _CommunitySettingsScreenState extends State<CommunitySettingsScreen> {
  late final Future<String> _roleFuture;

  @override
  void initState() {
    super.initState();
    _roleFuture = CommunityService.instance.currentUserRole(
      widget.community.communityId,
    );
  }

  Future<void> _showDeleteDialog() async {
    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DeleteCommunityDialog(community: widget.community),
    );
    if (!mounted || deleted != true) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Community deleted.')));
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = CommunityService.instance.isCurrentUserOwner(
      widget.community,
    );

    return GubScreenBackground(
      variant: GubBackgroundAssignments.createGub,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Community Settings'),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              GubContentCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.community.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<String>(
                      future: _roleFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const LinearProgressIndicator();
                        }
                        if (snapshot.hasError) {
                          return const Text(
                            'Your role is currently unavailable.',
                            style: TextStyle(color: Color(0xFF475569)),
                          );
                        }
                        return Text(
                          'Your role: ${snapshot.data ?? 'Member'}',
                          style: const TextStyle(color: Color(0xFF475569)),
                        );
                      },
                    ),
                  ],
                ),
              ),
              if (isOwner) ...[
                const SizedBox(height: 28),
                const Text(
                  'Danger Zone',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                GubContentCard(
                  padding: EdgeInsets.zero,
                  color: const Color(0xFFFFF1F2),
                  border: Border.all(color: const Color(0xFFFECACA)),
                  child: ListTile(
                    leading: const Icon(
                      Icons.delete_forever_rounded,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Delete Community',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: const Text(
                      'Permanently remove this Community and its data.',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _showDeleteDialog,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DeleteCommunityDialog extends StatefulWidget {
  final CommunityModel community;

  const _DeleteCommunityDialog({required this.community});

  @override
  State<_DeleteCommunityDialog> createState() => _DeleteCommunityDialogState();
}

class _DeleteCommunityDialogState extends State<_DeleteCommunityDialog> {
  final TextEditingController _confirmationController = TextEditingController();
  bool _isDeleting = false;
  bool _nameMatches = false;

  @override
  void initState() {
    super.initState();
    _confirmationController.addListener(_updateMatch);
  }

  void _updateMatch() {
    final matches = _confirmationController.text == widget.community.name;
    if (matches != _nameMatches) setState(() => _nameMatches = matches);
  }

  Future<void> _delete() async {
    if (_isDeleting || !_nameMatches) return;
    setState(() => _isDeleting = true);
    try {
      await CommunityService.instance.deleteCommunity(
        communityId: widget.community.communityId,
        confirmationName: _confirmationController.text,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
      setState(() => _isDeleting = false);
    }
  }

  @override
  void dispose() {
    _confirmationController
      ..removeListener(_updateMatch)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deletionEnabled = _nameMatches;

    return PopScope(
      canPop: !_isDeleting,
      child: AlertDialog(
        title: const Text('Delete Community?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This permanently removes the Community, its messages and membership data for everyone.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmationController,
                enabled: !_isDeleting,
                decoration: InputDecoration(
                  labelText: 'Type “${widget.community.name}” to confirm',
                  border: const OutlineInputBorder(),
                ),
              ),
              if (_isDeleting) ...[
                const SizedBox(height: 16),
                const Text(
                  'Deleting Community… Keep the app open until the process is complete.',
                  style: TextStyle(
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isDeleting ? null : () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: deletionEnabled && !_isDeleting ? _delete : null,
            child: _isDeleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Delete Community'),
          ),
        ],
      ),
    );
  }
}
