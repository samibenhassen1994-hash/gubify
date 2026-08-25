import 'package:flutter/material.dart';

import '../../../widgets/gub_content_card.dart';
import '../../../widgets/banned_users_screen.dart';
import '../../../widgets/gub_screen_background.dart';
import '../../../screens/welcome_screen.dart';
import '../../../screens/gub/my_gubs_screen.dart';
import '../models/community_model.dart';
import '../images/community_image_settings_card.dart';
import '../services/community_service.dart';
import 'community_join_requests_screen.dart';
import 'community_members_screen.dart';

class CommunitySettingsScreen extends StatefulWidget {
  final CommunityModel community;

  const CommunitySettingsScreen({super.key, required this.community});

  @override
  State<CommunitySettingsScreen> createState() =>
      _CommunitySettingsScreenState();
}

class _CommunitySettingsScreenState extends State<CommunitySettingsScreen> {
  late final Future<String> _roleFuture;
  late CommunityModel _community;

  @override
  void initState() {
    super.initState();
    _community = widget.community;
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

  Future<void> _leaveCommunity() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Leave Community?'),
        content: const Text('You will lose access to this Community.'),
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
    );
    if (!mounted || confirmed != true) return;
    try {
      await CommunityService.instance.leaveCommunity(
        widget.community.communityId,
      );
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = CommunityService.instance.isCurrentUserOwner(
      widget.community,
    );
    final canManageJoinRequests = widget.community.canManageJoinRequests(
      isOwner: isOwner,
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
              const SizedBox(height: 16),
              GubContentCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(
                    Icons.people_outline_rounded,
                    color: Color(0xFF2563EB),
                  ),
                  title: const Text(
                    'Members',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${widget.community.memberCount} members'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CommunityMembersScreen(community: widget.community),
                    ),
                  ),
                ),
              ),
              if (canManageJoinRequests) ...[
                const SizedBox(height: 16),
                GubContentCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(
                      Icons.how_to_reg_rounded,
                      color: Color(0xFF2563EB),
                    ),
                    title: const Text(
                      'Join requests',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Approve or reject pending access requests.',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CommunityJoinRequestsScreen(
                          community: widget.community,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              CommunityImageManagementSection(
                isOwner: isOwner,
                community: _community,
                onUpdated: (community) =>
                    setState(() => _community = community),
              ),
              if (isOwner) ...[
                const SizedBox(height: 16),
                GubContentCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.block_rounded, color: Colors.red),
                    title: const Text(
                      'Banned users',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'View members banned from this Community.',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BannedUsersScreen(
                          title: 'Banned users',
                          bannedUsersStream: CommunityService.instance
                              .bannedUsersStream(widget.community.communityId),
                          onUnban: (uid) =>
                              CommunityService.instance.unbanMember(
                                communityId: widget.community.communityId,
                                uid: uid,
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
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
              ] else ...[
                const SizedBox(height: 28),
                const Text(
                  'Membership',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                GubContentCard(
                  padding: EdgeInsets.zero,
                  color: const Color(0xFFFFF1F2),
                  border: Border.all(color: const Color(0xFFFECACA)),
                  child: ListTile(
                    leading: const Icon(
                      Icons.exit_to_app_rounded,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Leave Community',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: const Text(
                      'Remove yourself from this Community.',
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _leaveCommunity,
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
