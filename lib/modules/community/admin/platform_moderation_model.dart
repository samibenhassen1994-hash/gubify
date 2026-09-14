enum PlatformContentKind { messages, asks, answers }

class PlatformModerationItem {
  const PlatformModerationItem({
    required this.id,
    required this.text,
    required this.author,
    required this.hidden,
    this.status = '',
    this.bestAnswerId,
  });
  final String id;
  final String text;
  final String author;
  final bool hidden;
  final String status;
  final String? bestAnswerId;
  factory PlatformModerationItem.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) => PlatformModerationItem(
    id: id,
    text: data['text'] as String? ?? '',
    author:
        (data['senderName'] ?? data['authorDisplayName']) as String? ?? 'User',
    hidden: data['moderationHidden'] == true,
    status: data['status'] as String? ?? '',
    bestAnswerId: data['bestAnswerId'] as String?,
  );
}
