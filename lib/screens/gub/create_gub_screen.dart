import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_limits.dart';
import '../../widgets/gub_home_background.dart';
import '../../widgets/user_header.dart';
import 'module_selection_screen.dart';

class CreateGubScreen extends StatefulWidget {
  const CreateGubScreen({super.key});

  @override
  State<CreateGubScreen> createState() => _CreateGubScreenState();
}

class _CreateGubScreenState extends State<CreateGubScreen> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _continue() {
    final gubName = _nameController.text.trim();

    if (gubName.length < AppLimits.gubNameMinLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Gub name must be at least ${AppLimits.gubNameMinLength} characters.",
          ),
        ),
      );
      return;
    }

    if (gubName.length > AppLimits.gubNameMaxLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Gub name cannot exceed ${AppLimits.gubNameMaxLength} characters.",
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ModuleSelectionScreen(gubName: gubName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GubHomeBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),

                const UserHeader(),

                const SizedBox(height: 30),

                const Icon(
                  Icons.hub_outlined,
                  size: 82,
                  color: Color(0xFF2563EB),
                ),

                const SizedBox(height: 30),

                const Text(
                  "Create your Gub",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  "Start by choosing a name for your Gub.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 30),

                TextField(
                  controller: _nameController,
                  maxLength: AppLimits.gubNameMaxLength,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _continue(),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r"[a-zA-Z0-9À-ÿ '\-_]"),
                    ),
                  ],
                  decoration: const InputDecoration(
                    labelText: "Choose a name",
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
        ),
      ),
    );
  }
}