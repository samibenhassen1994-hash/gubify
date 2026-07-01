import 'package:flutter/material.dart';

class JoinHomeScreen extends StatelessWidget {
  const JoinHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ho un invito"),
      ),
      body: const Center(
        child: Text(
          "Qui entrerai in una casa tramite invito",
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}