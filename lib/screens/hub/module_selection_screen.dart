import 'package:flutter/material.dart';

import '../../services/hub_service.dart';
import '../../widgets/user_header.dart';
import 'hub_screen.dart';

class ModuleSelectionScreen extends StatefulWidget {
  final String hubName;

  const ModuleSelectionScreen({super.key, required this.hubName});

  @override
  State<ModuleSelectionScreen> createState() => _ModuleSelectionScreenState();
}

class _ModuleSelectionScreenState extends State<ModuleSelectionScreen> {
  bool _loading = false;

  final Map<String, bool> _modules = {
    "goals": true,
    "proposals": true,
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
        MaterialPageRoute(builder: (_) => HubScreen(hubId: hubId)),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showModuleInfo({required String title, required String description}) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(title),
          content: Text(description),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  Widget buildTile({
    required String keyName,
    required String title,
    required IconData icon,
    required String description,
    bool enabled = true,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SwitchListTile(
        value: _modules[keyName]!,
        onChanged: enabled
            ? (value) {
                setState(() {
                  _modules[keyName] = value;
                });
              }
            : null,
        secondary: Icon(icon),
        title: Row(
          children: [
            Text(title),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                _showModuleInfo(title: title, description: description);
              },
              child: const Icon(
                Icons.info_outline,
                size: 20,
                color: Colors.blue,
              ),
            ),
          ],
        ),
        subtitle: enabled ? null : const Text("Core module"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Choose Modules")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const UserHeader(),

            Text(
              widget.hubName,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            const Text(
              "Core modules are always enabled.\nChoose any additional modules.",
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 25),

            Expanded(
              child: ListView(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      "Core Modules",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  buildTile(
                    keyName: "goals",
                    title: "Shared Budget",
                    icon: Icons.account_balance_wallet_outlined,
                    description:
                        "Create shared money goals for your Hub.\n\n"
                        "Useful for trips, group gifts and common purchases.",
                  ),
                  buildTile(
                    keyName: "proposals",
                    title: "Proposals",
                    icon: Icons.how_to_vote_outlined,
                    description:
                        "Create proposals, let members vote and automatically approve decisions when the majority is reached.",
                    enabled: false,
                  ),

                  const SizedBox(height: 20),

                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      "Optional Modules",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  buildTile(
                    keyName: "tasks",
                    title: "Tasks",
                    icon: Icons.check_circle_outline,
                    description:
                        "Create and manage shared tasks with Hub members.",
                  ),

                  buildTile(
                    keyName: "calendar",
                    title: "Calendar",
                    icon: Icons.calendar_month,
                    description:
                        "Organize events and important dates together.",
                  ),

                  buildTile(
                    keyName: "chat",
                    title: "Chat",
                    icon: Icons.chat_bubble_outline,
                    description: "Communicate with all Hub members.",
                  ),

                  buildTile(
                    keyName: "photos",
                    title: "Photos",
                    icon: Icons.photo_library_outlined,
                    description: "Save and share photos inside your Hub.",
                  ),

                  buildTile(
                    keyName: "shopping",
                    title: "Shopping",
                    icon: Icons.shopping_cart_outlined,
                    description: "Create shared shopping lists.",
                  ),

                  buildTile(
                    keyName: "expenses",
                    title: "Expenses",
                    icon: Icons.euro,
                    description: "Track shared expenses between members.",
                  ),

                  buildTile(
                    keyName: "notes",
                    title: "Notes",
                    icon: Icons.note_alt_outlined,
                    description: "Create shared notes for your Hub.",
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
                    : const Text("Create Hub", style: TextStyle(fontSize: 17)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
