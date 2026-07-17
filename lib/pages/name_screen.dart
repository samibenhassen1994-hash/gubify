import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../modules/legal/privacy_policy_screen.dart';
import '../modules/legal/terms_screen.dart';
import '../services/auth_service.dart';
import '../widgets/gubify_background.dart';
import '../widgets/gubify_logo.dart';
import '../screens/welcome_screen.dart';
import 'package:flutter/services.dart';

class NameScreen extends StatefulWidget {
  const NameScreen({super.key});

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  final TextEditingController _controller = TextEditingController();

  bool _isLoading = false;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GubifyBackground(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              children: [
                GubifyLogo(width: MediaQuery.of(context).size.width * 0.7),
                const SizedBox(height: 35),
                const Text(
                  'Welcome!',
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .4,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Before creating or joining a Gub,\nlet's get to know you.",
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
                  maxLength: 22,

                  inputFormatters: [
                  LengthLimitingTextInputFormatter(22),
                   FilteringTextInputFormatter.allow(
                   RegExp(r"[a-zA-ZÀ-ÖØ-öø-ÿ0-9 ]"),
                       ),
                     ],
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Your name',
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
                const SizedBox(height: 28),

Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Transform.scale(
      scale: 0.95,
      child: Checkbox(
        value: _acceptedTerms,
        activeColor: const Color(0xFF3B82F6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
        onChanged: (value) {
          setState(() {
            _acceptedTerms = value ?? false;
          });
        },
      ),
    ),

    const SizedBox(width: 4),

    Expanded(
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: RichText(
          text: TextSpan(
            style: TextStyle(
              color: Colors.white.withValues(alpha: .75),
              fontSize: 13,
              height: 1.45,
            ),
            children: [
              const TextSpan(
                text: 'I have read and accept the ',
              ),

              TextSpan(
                text: 'Terms & Conditions',
                style: const TextStyle(
                  color: Color(0xFF4DA3FF),
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TermsScreen(),
                      ),
                    );
                  },
              ),

              const TextSpan(
                text: ' and ',
              ),

              TextSpan(
                text: 'Privacy Policy',
                style: const TextStyle(
                  color: Color(0xFF4DA3FF),
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyScreen(),
                      ),
                    );
                  },
              ),

              const TextSpan(
                text: '.',
              ),
            ],
          ),
        ),
      ),
    ),
  ],
),

const SizedBox(height: 30),
               SizedBox(
  width: double.infinity,
  height: 56,
  child: ElevatedButton(
    style: ElevatedButton.styleFrom(
      elevation: 0,
      backgroundColor: const Color(0xFF3B82F6),
      disabledBackgroundColor: Colors.white.withValues(alpha: .15),
      foregroundColor: Colors.white,
      disabledForegroundColor: Colors.white.withValues(alpha: .45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    onPressed: (_isLoading || !_acceptedTerms)
        ? null
        : () async {
            final name = _controller.text.trim();

if (name.length < 2) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Name must contain at least 2 characters'),
    ),
  );
  return;
}

if (!RegExp(r'[A-Za-zÀ-ÖØ-öø-ÿ]').hasMatch(name)) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Name must contain at least one letter'),
    ),
  );
  return;
}

const reservedNames = {
  'admin',
  'administrator',
  'support',
  'gubify',
  'system',
};

if (reservedNames.contains(name.toLowerCase())) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('This name cannot be used'),
    ),
  );
  return;
}
          

if (name.contains(RegExp(r'\s{2,}'))) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Multiple consecutive spaces are not allowed'),
    ),
  );
  return;
}

          
            setState(() => _isLoading = true);

            try {
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
                SnackBar(content: Text('Error: $e')),
              );
            }

            if (context.mounted) {
              setState(() => _isLoading = false);
            }
          },
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: _isLoading
          ? const SizedBox(
              key: ValueKey('loading'),
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : const Text(
              'Continue',
              key: ValueKey('text'),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
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
