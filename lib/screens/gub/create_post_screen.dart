import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../config/app_limits.dart';

import '../../modules/notifications/services/notification_service.dart';
import '../../services/post_service.dart';

class CreatePostScreen extends StatefulWidget {
  final String gubId;

  const CreatePostScreen({super.key, required this.gubId});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _controller = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final message = _controller.text.trim();

    if (message.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Write something.")));
      return;
    }

    if (message.length > AppLimits.postMaxLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Posts cannot exceed ${AppLimits.postMaxLength} characters.",
          ),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final displayName = await PostService().createPost(
        gubId: widget.gubId,
        message: message,
      );
      final user = FirebaseAuth.instance.currentUser!;
      await NotificationService.instance.send(
        gubId: widget.gubId,
        title: "New Board Post",
        body: "$displayName published a new post.",
        type: "board_post",
        senderId: user.uid,
        senderName: displayName,
        data: {"message": message},
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("New Post")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              maxLines: 8,
              maxLength: AppLimits.postMaxLength,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: "What would you like to share with your Hub?",
                border: OutlineInputBorder(),
              ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: FilledButton.icon(
                onPressed: _loading ? null : _publish,
                icon: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send),
                label: const Text("Publish"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
