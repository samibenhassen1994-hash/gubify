import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../modules/legal/privacy_policy_screen.dart';
import '../modules/legal/terms_screen.dart';
import '../services/auth_service.dart';
import '../widgets/startup_artwork_background.dart';
import '../screens/welcome_screen.dart';
import 'package:flutter/services.dart';

class NameScreen extends StatefulWidget {
  final VoidCallback? onNavigationReady;

  const NameScreen({super.key, this.onNavigationReady});

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
    return StartupArtworkBackground(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.52),
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _controller,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 17,
                        ),
                        textCapitalization: TextCapitalization.words,
                        maxLength: 22,

                        inputFormatters: [
                          LengthLimitingTextInputFormatter(22),
                          FilteringTextInputFormatter.allow(
                            RegExp(r"[a-zA-ZÀ-ÖØ-öø-ÿ0-9 ]"),
                          ),
                        ],

                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.person_outline_rounded,
                            color: Color(0xFF6B7280),
                          ),
                          counterText: '',
                          hintText: 'Your name',
                          hintStyle: const TextStyle(color: Colors.black45),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 1),

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
                                    color: Colors.black87,
                                    fontSize: 13,
                                    height: 1.45,
                                  ),
                                  children: [
                                    const TextSpan(
                                      text: 'I agree to the ',
                                    ),

                                    TextSpan(
                                      text: 'Terms of Service',
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
                                              builder: (_) =>
                                                  const TermsScreen(),
                                            ),
                                          );
                                        },
                                    ),

                                    const TextSpan(
                                      text: ' and acknowledge the ',
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
                                              builder: (_) =>
                                                  const PrivacyPolicyScreen(),
                                            ),
                                          );
                                        },
                                    ),

                                    const TextSpan(text: '.'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: const Color(0xFF3B82F6),
                            disabledBackgroundColor: const Color(0xFFE5E7EB),
                            foregroundColor: Colors.white,
                            disabledForegroundColor: const Color(0xFF9CA3AF),
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
                                        content: Text(
                                          'Name must contain at least 2 characters',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  if (!RegExp(
                                    r'[A-Za-zÀ-ÖØ-öø-ÿ]',
                                  ).hasMatch(name)) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Name must contain at least one letter',
                                        ),
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

                                  if (reservedNames.contains(
                                    name.toLowerCase(),
                                  )) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'This name cannot be used',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  if (name.contains(RegExp(r'\s{2,}'))) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Multiple consecutive spaces are not allowed',
                                        ),
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
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          widget.onNavigationReady?.call();
                                        });
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
                    ], // children della Column interna
                  ), // Column interna
                ), // Container
              ], // children della Column esterna
            ), // Column esterna
          ), // SingleChildScrollView
        ), // Center
      ), // SafeArea
    ); // StartupArtworkBackground
  }
}
