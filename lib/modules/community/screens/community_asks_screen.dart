import 'package:flutter/material.dart';

import '../../../widgets/gub_screen_background.dart';
import '../models/community_ask_model.dart';
import '../services/community_ask_service.dart';
import '../widgets/community_ask_card.dart';
import 'community_ask_details_screen.dart';

class CommunityAsksScreen extends StatefulWidget {
  const CommunityAsksScreen({
    super.key,
    required this.communityId,
    required this.communityName,
    this.asksStream,
  });

  final String communityId;
  final String communityName;
  final Stream<List<CommunityAskModel>>? asksStream;

  @override
  State<CommunityAsksScreen> createState() => _CommunityAsksScreenState();
}

class _CommunityAsksScreenState extends State<CommunityAsksScreen> {
  CommunityAskType? _filter;
  late final Stream<List<CommunityAskModel>> _asksStream;

  @override
  void initState() {
    super.initState();
    _asksStream = widget.asksStream ?? _loadAsks();
  }

  Stream<List<CommunityAskModel>> _loadAsks() {
    try {
      return CommunityAskService.instance.watchActiveAsks(widget.communityId);
    } catch (error, stackTrace) {
      return Stream.error(error, stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GubScreenBackground(
      variant: GubBackgroundAssignments.board,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Asks'),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              _AskFilters(
                selected: _filter,
                onSelected: (filter) => setState(() => _filter = filter),
              ),
              Expanded(
                child: StreamBuilder<List<CommunityAskModel>>(
                  stream: _asksStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const _AsksMessage(title: 'Unable to load asks');
                    }
                    final allAsks = snapshot.data ?? const [];
                    final asks = _filter == null
                        ? allAsks
                        : allAsks
                              .where((ask) => ask.type == _filter)
                              .toList(growable: false);
                    if (asks.isEmpty) {
                      return _filter == null
                          ? const _AsksMessage(
                              title: 'No active asks',
                              subtitle:
                                  'Asks created by community members will appear here.',
                            )
                          : _AsksMessage(title: 'No ${_filter!.label} asks');
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: asks.length,
                      itemBuilder: (context, index) {
                        final ask = asks[index];
                        return CommunityAskCard(
                          key: ValueKey('ask-card-${ask.askId}'),
                          ask: ask,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CommunityAskDetailsScreen(
                                ask: ask,
                                communityName: widget.communityName,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AskFilters extends StatelessWidget {
  const _AskFilters({required this.selected, required this.onSelected});

  final CommunityAskType? selected;
  final ValueChanged<CommunityAskType?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          ChoiceChip(
            key: const ValueKey('ask-filter-all'),
            label: const Text('All'),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
          ),
          for (final type in CommunityAskType.values) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              key: ValueKey('ask-filter-${type.value}'),
              label: Text(type.label),
              selected: selected == type,
              onSelected: (_) => onSelected(type),
            ),
          ],
        ],
      ),
    );
  }
}

class _AsksMessage extends StatelessWidget {
  const _AsksMessage({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.view_list_rounded,
              size: 42,
              color: Color(0xFF2563EB),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
