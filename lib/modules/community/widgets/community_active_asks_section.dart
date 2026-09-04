import 'package:flutter/material.dart';

import '../../../widgets/gub_content_card.dart';
import '../models/community_ask_model.dart';
import '../services/community_ask_service.dart';

class CommunityActiveAsksSection extends StatelessWidget {
  const CommunityActiveAsksSection({
    super.key,
    required this.communityId,
    required this.authorId,
    this.asksStream,
  });

  final String communityId;
  final String authorId;
  final Stream<List<CommunityAskModel>>? asksStream;

  @override
  Widget build(BuildContext context) {
    final stream = _asksStream();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StreamBuilder<List<CommunityAskModel>>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _ActiveAsksContainer(
                message: CircularProgressIndicator(),
              );
            }
            if (snapshot.hasError) {
              return const _ActiveAsksContainer(
                message: Text('Unable to load active Asks.'),
              );
            }
            final asks = (snapshot.data ?? const [])
                .where((ask) => ask.status == CommunityAskStatus.active)
                .toList(growable: false);
            if (asks.isEmpty) {
              return const _ActiveAsksContainer(
                message: Text('No active Asks'),
              );
            }
            return Column(
              children: [
                const _ActiveAsksContainer(),
                const SizedBox(height: 12),
                for (final ask in asks) _ActiveAskCard(ask: ask),
              ],
            );
          },
        ),
      ],
    );
  }

  Stream<List<CommunityAskModel>> _asksStream() {
    if (asksStream != null) {
      return asksStream!;
    }
    try {
      return CommunityAskService.instance.activeAsksStream(
        communityId: communityId,
        authorId: authorId,
      );
    } catch (error, stackTrace) {
      return Stream.error(error, stackTrace);
    }
  }
}

class _ActiveAsksContainer extends StatelessWidget {
  const _ActiveAsksContainer({this.message});

  final Widget? message;

  @override
  Widget build(BuildContext context) => GubContentCard(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Text(
            'Active Asks',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 14),
          Center(child: message!),
        ],
      ],
    ),
  );
}

class _ActiveAskCard extends StatelessWidget {
  const _ActiveAskCard({required this.ask});

  final CommunityAskModel ask;

  @override
  Widget build(BuildContext context) {
    final date = ask.createdAt.toDate();
    final dateLabel =
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    ask.type.label,
                    style: const TextStyle(
                      color: Color(0xFF2563EB),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                const Text(
                  'Active',
                  style: TextStyle(
                    color: Color(0xFF059669),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(ask.text, maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Text(
              dateLabel,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}
