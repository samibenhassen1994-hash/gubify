import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/gub/my_gubs_screen.dart';
import '../repositories/gub_invite_repository.dart';

class GubAccessGuard extends StatefulWidget {
  final String gubId;
  final Widget child;

  const GubAccessGuard({super.key, required this.gubId, required this.child});

  @override
  State<GubAccessGuard> createState() => _GubAccessGuardState();
}

class _GubAccessGuardState extends State<GubAccessGuard> {
  late final StreamSubscription _subscription;

  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();

    final uid = FirebaseAuth.instance.currentUser!.uid;

    _subscription = FirebaseFirestore.instance
        .collection("gubs")
        .doc(widget.gubId)
        .collection("members")
        .doc(uid)
        .snapshots()
        .listen(_handleMembershipChange);
  }

  Future<void> _handleMembershipChange(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) async {
    if (snapshot.exists) return;

    final uid = FirebaseAuth.instance.currentUser!.uid;

    if (_dialogShown) return;

    final gub = await FirebaseFirestore.instance
        .collection("gubs")
        .doc(widget.gubId)
        .get();
    if (!gub.exists || gub.data()?["deletionStatus"] == "deleting") {
      return;
    }

    final banned = await GubInviteRepository().isUserBanned(
      gubId: widget.gubId,
      userId: uid,
    );
    _dialogShown = true;

    // Elimina eventuale riferimento rimasto
    await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("gubs")
        .doc(widget.gubId)
        .delete();

    if (!mounted) return;

    final result =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text("Removed from Hub"),
            content: Text(
              banned
                  ? 'You were banned from this Gub by an administrator.'
                  : 'An administrator removed you from this Hub.',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(context, true);
                },
                child: const Text("OK"),
              ),
            ],
          ),
        ) ??
        false;

    if (!mounted) return;

    if (result) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MyGubsScreen()),
        (_) => false,
      );
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
