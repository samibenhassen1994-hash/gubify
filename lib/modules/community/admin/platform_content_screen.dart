import 'package:flutter/material.dart';

import 'platform_admin_gate.dart';
import 'platform_admin_service.dart';
import 'platform_moderation_model.dart';
import 'platform_moderation_service.dart';

class PlatformContentScreen extends StatefulWidget {
  const PlatformContentScreen({
    super.key,
    required this.communityId,
    required this.kind,
    required this.role,
    this.askId,
    this.bestAnswerId,
    this.service,
  });
  final PlatformModerationService? service;
  final String communityId;
  final PlatformContentKind kind;
  final PlatformAdminService role;
  final String? askId;
  final String? bestAnswerId;
  @override
  State<PlatformContentScreen> createState() => _PlatformContentScreenState();
}

class _PlatformContentScreenState extends State<PlatformContentScreen> {
  late final service =
      widget.service ?? PlatformModerationService(role: widget.role);
  int _limit = 50;
  final _busy = <String>{};
  late Stream<List<PlatformModerationItem>> _items = _load();
  Stream<List<PlatformModerationItem>> _load() =>
      service.content(widget.communityId, widget.kind, widget.askId, _limit);
  Future<void> _moderate(PlatformModerationItem item) async {
    if (_busy.contains(item.id)) return;
    final action = item.hidden ? 'Unhide' : 'Hide';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$action content?'),
        content: Text(
          item.hidden ? 'Restore this content in the Community?' : 'Replace this content with “Removed by moderation”? The original content and rewards are preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy.add(item.id));
    try {
      await service.setHidden(
        communityId: widget.communityId,
        kind: widget.kind,
        askId: widget.askId,
        itemId: item.id,
        hidden: !item.hidden,
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              item.hidden ? 'Content restored.' : 'Content hidden.',
            ),
          ),
        );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to moderate content. Check your access and try again.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy.remove(item.id));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(switch (widget.kind) {
        PlatformContentKind.messages => 'Chat moderation',
        PlatformContentKind.asks => 'Ask moderation',
        PlatformContentKind.answers => 'Answer moderation',
      }),
    ),
    body: StreamBuilder<List<PlatformModerationItem>>(
      stream: _items,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Center(child: Text('Unable to load content.'));
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final items = snapshot.data!;
        if (items.isEmpty) return const Center(child: Text('No content.'));
        return ListView(
          children: [
            for (final item in items)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.author,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (item.id == widget.bestAnswerId)
                        const Text('Best Answer'),
                      if (item.status.isNotEmpty) Text(item.status),
                      if (item.hidden) const Text('Removed by moderation'),
                      Text(item.text),
                      Wrap(
                        spacing: 12,
                        children: [
                          TextButton(
                            onPressed: _busy.contains(item.id)
                                ? null
                                : () => _moderate(item),
                            child: Text(item.hidden ? 'Unhide' : 'Hide'),
                          ),
                          if (widget.kind == PlatformContentKind.asks)
                            TextButton(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => PlatformAdminGate(
                                    service: widget.role,
                                    builder: (_) => PlatformContentScreen(
                                      communityId: widget.communityId,
                                      kind: PlatformContentKind.answers,
                                      role: widget.role,
                                      askId: item.id,
                                      bestAnswerId: item.bestAnswerId,
                                    ),
                                  ),
                                ),
                              ),
                              child: const Text('Answers'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (items.length == _limit)
              TextButton(
                onPressed: () => setState(() {
                  _limit += 50;
                  _items = _load();
                }),
                child: const Text('Load more'),
              ),
          ],
        );
      },
    ),
  );
}
