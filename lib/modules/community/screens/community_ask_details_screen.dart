import 'package:flutter/material.dart';

import '../../../widgets/gub_screen_background.dart';
import '../../chat/widgets/chat_user_avatar.dart';
import '../models/community_ask_model.dart';
import '../widgets/community_ask_card.dart';

class CommunityAskDetailsScreen extends StatelessWidget {
  const CommunityAskDetailsScreen({
    super.key,
    required this.ask,
    required this.communityName,
  });

  final CommunityAskModel ask;
  final String communityName;

  @override
  Widget build(BuildContext context) {
    return GubScreenBackground(
      variant: GubBackgroundAssignments.board,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Ask'),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CommunityAskTypeBadge(type: ask.type),
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
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          ChatUserAvatar(
                            displayName: ask.authorDisplayName,
                            userId: ask.authorId,
                            radius: 21,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              ask.authorDisplayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        ask.text,
                        style: const TextStyle(fontSize: 16, height: 1.45),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        formatCommunityAskDate(ask.createdAt.toDate()),
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
