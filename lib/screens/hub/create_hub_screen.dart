import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_limits.dart';
import '../../widgets/user_header.dart';
import 'module_selection_screen.dart';

class CreateHubScreen extends StatefulWidget {
  const CreateHubScreen({super.key});

  @override
  State<CreateHubScreen> createState() => _CreateHubScreenState();
}

class _CreateHubScreenState extends State<CreateHubScreen> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _continue() {
    final hubName = _nameController.text.trim();

    if (hubName.length < AppLimits.hubNameMinLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Hub name must be at least ${AppLimits.hubNameMinLength} characters.",
          ),
        ),
      );
      return;
    }

    if (hubName.length > AppLimits.hubNameMaxLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Hub name cannot exceed ${AppLimits.hubNameMaxLength} characters.",
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ModuleSelectionScreen(hubName: hubName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Hub")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const UserHeader(),

            const SizedBox(height: 20),

            const Icon(Icons.groups, size: 80),

            const SizedBox(height: 30),

            const Text(
              "Create your Hub",
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: _nameController,
              maxLength: AppLimits.hubNameMaxLength,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _continue(),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r"[a-zA-Z0-9À-ÿ '\-_]"),
                ),
              ],
              decoration: const InputDecoration(
                labelText: "Hub Name",
                border: OutlineInputBorder(),
              ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: FilledButton(
                onPressed: _continue,
                child: const Text("Continue"),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
