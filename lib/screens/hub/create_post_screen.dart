import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../config/app_limits.dart';

import '../../repositories/user_repository.dart';

class CreatePostScreen extends StatefulWidget {
  final String hubId;

  const CreatePostScreen({
    super.key,
    required this.hubId,
  });

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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Write something."),
      ),
    );
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
      final user = FirebaseAuth.instance.currentUser!;

      final userData =
          await UserRepository.instance.getUser(user.uid);

      final displayName =
          userData?["displayName"] ?? "User";

      await FirebaseFirestore.instance
          .collection("hubs")
          .doc(widget.hubId)
          .collection("posts")
          .add({
        "authorId": user.uid,
        "authorName": displayName,
        "authorPhoto": user.photoURL,
        "message": message,
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
        "likes": 0,
        "comments": 0,
      });

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("New Post"),
      ),
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