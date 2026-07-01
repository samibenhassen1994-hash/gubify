import 'package:flutter/material.dart';

class CreateHomeScreen extends StatelessWidget {
  const CreateHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Crea una casa"),
      ),
      body: const Center(
        child: Text(
          "Qui creerai una nuova casa",
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}