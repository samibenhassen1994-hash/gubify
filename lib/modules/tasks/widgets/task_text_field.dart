import 'package:flutter/material.dart';

class TaskTextField extends StatelessWidget {
  final TextEditingController controller;

  const TaskTextField({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: 2,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        labelText: "What to do?",
        hintText: "What to do?",
        border: OutlineInputBorder(),
      ),
    );
  }
}