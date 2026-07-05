import 'package:flutter/material.dart';

import '../../services/hub_service.dart';
import 'hub_screen.dart';

class JoinHubScreen extends StatefulWidget {
  const JoinHubScreen({super.key});

  @override
  State<JoinHubScreen> createState() => _JoinHubScreenState();
}

class _JoinHubScreenState extends State<JoinHubScreen> {
  final TextEditingController _controller = TextEditingController();

  bool _loading = false;

  Future<void> _joinHub() async {
  print(">>> PULSANTE PREMUTO <<<");

  if (_controller.text.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Inserisci un codice."),
      ),
    );
    return;
  }

  print("Codice digitato: ${_controller.text}");

  setState(() => _loading = true);

  try {
    print("Chiamo HubService...");

    final hubId = await HubService().joinHub(
      inviteCode: _controller.text,
    );

    print("Hub trovato: $hubId");

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
    print("ERRORE: $e");

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.toString()),
      ),
    );
  }

  if (mounted) {
    setState(() => _loading = false);
  }
}

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Unisciti ad un Hub"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 30),

            const Icon(
              Icons.group_add,
              size: 80,
            ),

            const SizedBox(height: 25),

            const Text(
              "Hai ricevuto un invito?",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              "Inserisci il codice Hub che ti è stato condiviso.",
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 35),

            TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: "Codice Hub",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.vpn_key),
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: FilledButton(
                onPressed: _loading ? null : _joinHub,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text(
                        "Entra nell'Hub",
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