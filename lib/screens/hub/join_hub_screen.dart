import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_limits.dart';
import '../../services/hub_service.dart';
import '../../widgets/user_header.dart';
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
    final inviteCode = _controller.text.trim();

    if (inviteCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter an invite code.")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final hubId = await HubService().joinHub(inviteCode: inviteCode);

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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Join a Hub")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const UserHeader(),

            const SizedBox(height: 20),

            const Icon(Icons.group_add, size: 80),

            const SizedBox(height: 25),

            const Text(
              "Got an invitation?",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            const Text(
              "Enter the Hub invite code that was shared with you.",
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 35),

            TextField(
              controller: _controller,
              maxLength: AppLimits.inviteCodeLength,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _joinHub(),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
              ],
              decoration: const InputDecoration(
                labelText: "Hub Code",
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
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      )
                    : const Text("Join Hub", style: TextStyle(fontSize: 17)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
