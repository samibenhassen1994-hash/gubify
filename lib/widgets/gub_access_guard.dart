import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/gub/my_gubs_screen.dart';

class GubAccessGuard extends StatefulWidget {
  final String hubId;
  final Widget child;

  const GubAccessGuard({super.key, required this.hubId, required this.child});

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
        .doc(widget.hubId)
        .collection("members")
        .doc(uid)
        .snapshots()
        .listen(_handleMembershipChange);
  }

  Future<void> _handleMembershipChange(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) async {
    if (snapshot.exists) return;

    if (_dialogShown) return;

    _dialogShown = true;

    final uid = FirebaseAuth.instance.currentUser!.uid;

    // Elimina eventuale riferimento rimasto
    await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("gubs")
        .doc(widget.hubId)
        .delete();

    if (!mounted) return;

    final result =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text("Removed from Hub"),
            content: const Text("An administrator removed you from this Hub."),
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
