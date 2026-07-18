import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_limits.dart';
import '../../services/gub_service.dart';
import '../../widgets/gub_home_background.dart';
import '../../widgets/user_header.dart';
import 'gub_screen.dart';

class JoinGubScreen extends StatefulWidget {
  const JoinGubScreen({super.key});

  @override
  State<JoinGubScreen> createState() => _JoinGubScreenState();
}

class _JoinGubScreenState extends State<JoinGubScreen> {
  final TextEditingController _controller = TextEditingController();

  bool _loading = false;

  Future<void> _joinHub() async {
    final inviteCode = _controller.text.trim();

    if (inviteCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a Gub invite code."),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final gubId = await GubService().joinHub(inviteCode: inviteCode);

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => GubScreen(gubId: gubId),
        ),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
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
                  "Join a Gub",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  "Enter the invitation code shared with you.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 30),

                TextField(
                  controller: _controller,
                  maxLength: AppLimits.inviteCodeLength,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _joinHub(),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[A-Za-z0-9-]'),
                    ),
                  ],
                  decoration: const InputDecoration(
                    labelText: "Invitation Code",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.vpn_key),
                  ),
                ),

                const Spacer(),

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
                        : const Text(
                            "Join Gub",
                            style: TextStyle(fontSize: 17),
                          ),
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