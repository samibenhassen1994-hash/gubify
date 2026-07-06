import 'package:flutter/material.dart';

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
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Inserisci il nome dell'Hub"),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ModuleSelectionScreen(
          hubName: _nameController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Crea Hub"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const UserHeader(),

            const SizedBox(height: 20),

            const Icon(
              Icons.groups,
              size: 80,
            ),

            const SizedBox(height: 30),

            const Text(
              "Crea il tuo Hub",
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Nome Hub",
                border: OutlineInputBorder(),
              ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: FilledButton(
                onPressed: _continue,
                child: const Text("Continua"),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}