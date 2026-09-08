import 'package:flutter/material.dart';

import '../../../../repositories/user_repository.dart';
import '../models/user_block_model.dart';
import '../services/user_block_service.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key, this.service, this.loadUser});

  final UserBlockService? service;
  final Future<Map<String, dynamic>?> Function(String userId)? loadUser;

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final Map<String, Future<String>> _names = {};

  UserBlockService get _service => widget.service ?? UserBlockService.instance;

  Future<String> _displayName(String userId) =>
      _names.putIfAbsent(userId, () async {
        final data = await (widget.loadUser ?? UserRepository.instance.getUser)(
          userId,
        );
        final displayName = data?['displayName'];
        return displayName is String && displayName.trim().isNotEmpty
            ? displayName.trim()
            : 'User';
      });

  Future<void> _unblock(String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unblock user?'),
        content: const Text(
          'This user will be removed from your blocked users list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    try {
      await _service.unblockUser(userId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User unblocked.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to unblock user.')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Blocked users')),
    body: StreamBuilder<List<UserBlockModel>>(
      stream: _service.blockedUsersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Unable to load blocked users.'));
        }
        final blocks = snapshot.data ?? const <UserBlockModel>[];
        if (blocks.isEmpty) {
          return const Center(child: Text('No blocked users.'));
        }
        return ListView.builder(
          itemCount: blocks.length,
          itemBuilder: (context, index) {
            final block = blocks[index];
            return FutureBuilder<String>(
              future: _displayName(block.blockedUserId),
              builder: (context, nameSnapshot) => ListTile(
                title: Text(nameSnapshot.data ?? 'User'),
                subtitle: block.blockedAt == null
                    ? null
                    : Text(
                        'Blocked ${MaterialLocalizations.of(context).formatMediumDate(block.blockedAt!.toDate())}',
                      ),
                trailing: TextButton(
                  onPressed: () => _unblock(block.blockedUserId),
                  child: const Text('Unblock'),
                ),
              ),
            );
          },
        );
      },
    ),
  );
}
