import 'package:flutter/material.dart';

import '../widgets/hubfy_background.dart';
import '../services/auth_service.dart';
import '../screens/welcome_screen.dart';
import '../widgets/hubfy_logo.dart';

class NameScreen extends StatefulWidget {
  const NameScreen({super.key});

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  final TextEditingController _controller = TextEditingController();
 bool _isLoading = false;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HubfyBackground(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              children: [
                HubfyLogo(
  width: MediaQuery.of(context).size.width * 0.7,
),

                const SizedBox(height: 35),

                const Text(
                  "Welcome!",
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  "Before creating or joining a Hub,\nlet's get to know you.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .75),
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 45),

                TextField(
                  controller: _controller,
                  style: const TextStyle(color: Colors.white),
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: "Your name",
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: .45),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: .05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading
    ? null
    : () async {
        final name = _controller.text.trim();

        if (name.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Please enter your name"),
            ),
          );
          return;
        }

        setState(() {
          _isLoading = true;
        });

        try {
          print("PROFILE UID: ${AuthService().currentUser?.uid}");
          await AuthService().createProfile(name);

          if (!context.mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const WelcomeScreen(),
            ),
          );
        } catch (e) {
          if (!context.mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error: $e"),
            ),
          );
        }

        if (context.mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      },
                  child: _isLoading
    ? const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: Colors.white,
        ),
      )
    : const Text(
        "Continue",
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}