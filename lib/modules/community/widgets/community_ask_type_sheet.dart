import 'package:flutter/material.dart';

import '../models/community_ask_model.dart';

Future<CommunityAskType?> showCommunityAskTypeSheet(BuildContext context) =>
    showModalBottomSheet<CommunityAskType>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => const _CommunityAskTypeSheet(),
    );

class _CommunityAskTypeSheet extends StatelessWidget {
  const _CommunityAskTypeSheet();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Create ask',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text('What kind of ask is this?'),
            const SizedBox(height: 14),
            for (final type in CommunityAskType.values)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: () => Navigator.pop(context, type),
                  title: Text(
                    type.label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(type.description),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
