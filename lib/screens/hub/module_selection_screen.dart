import 'package:flutter/material.dart';

import '../../services/hub_service.dart';
import '../../widgets/user_header.dart';
import 'hub_screen.dart';

class ModuleSelectionScreen extends StatefulWidget {
  final String hubName;

  const ModuleSelectionScreen({
    super.key,
    required this.hubName,
  });

  @override
  State<ModuleSelectionScreen> createState() =>
      _ModuleSelectionScreenState();
}

class _ModuleSelectionScreenState extends State<ModuleSelectionScreen> {
  bool _loading = false;

  final Map<String, bool> _modules = {
    "tasks": false,
    "calendar": false,
    "chat": false,
    "photos": false,
    "shopping": false,
    "expenses": false,
    "notes": false,
  };

  Future<void> _createHub() async {
    setState(() => _loading = true);

    try {
      final hubId = await HubService().createHub(
        name: widget.hubName,
        modules: _modules,
      );

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => HubScreen(
            hubId: hubId,
          ),
        ),
        (_) => false,
      );
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

  Widget buildTile({
    required String keyName,
    required String title,
    required IconData icon,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: SwitchListTile(
        value: _modules[keyName]!,
        onChanged: (value) {
          setState(() {
            _modules[keyName] = value;
          });
        },
        secondary: Icon(icon),
        title: Text(title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Choose Modules"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const UserHeader(),

            Text(
              widget.hubName,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              "Select the modules you want to enable.\nYou can change them later at any time.",
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 25),

            Expanded(
              child: ListView(
                children: [
                  buildTile(
                    keyName: "tasks",
                    title: "Tasks",
                    icon: Icons.check_circle_outline,
                  ),
                  buildTile(
                    keyName: "calendar",
                    title: "Calendar",
                    icon: Icons.calendar_month,
                  ),
                  buildTile(
                    keyName: "chat",
                    title: "Chat",
                    icon: Icons.chat_bubble_outline,
                  ),
                  buildTile(
                    keyName: "photos",
                    title: "Photos",
                    icon: Icons.photo_library_outlined,
                  ),
                  buildTile(
                    keyName: "shopping",
                    title: "Shopping",
                    icon: Icons.shopping_cart_outlined,
                  ),
                  buildTile(
                    keyName: "expenses",
                    title: "Expenses",
                    icon: Icons.euro,
                  ),
                  buildTile(
                    keyName: "notes",
                    title: "Notes",
                    icon: Icons.note_alt_outlined,
                  ),
                ],
              ),
            ),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: FilledButton(
                onPressed: _loading ? null : _createHub,
                child: _loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        "Create Hub",
                        style: TextStyle(fontSize: 17),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}