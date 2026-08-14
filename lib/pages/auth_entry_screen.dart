import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../modules/legal/privacy_policy_screen.dart';
import '../modules/legal/terms_screen.dart';
import '../services/auth_service.dart';

class AuthEntryScreen extends StatefulWidget {
  static const backgroundAsset = 'assets/images/auth/auth_entry_background.png';
  static const logoAsset = 'assets/images/auth/auth_entry_logo.png';

  const AuthEntryScreen({
    super.key,
    required this.authService,
    required this.onAuthenticated,
    required this.onContinueAnonymously,
  });

  final AuthService authService;
  final Future<void> Function() onAuthenticated;
  final Future<void> Function() onContinueAnonymously;

  @override
  State<AuthEntryScreen> createState() => _AuthEntryScreenState();
}

class _AuthEntryScreenState extends State<AuthEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isRegistering = false;
  bool _acceptedTerms = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const TermsScreen()));
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  Future<void> _runGoogle() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    final result = await widget.authService.signInWithGoogle();
    if (!mounted) return;
    if (result.isSuccess) {
      await _completeAuthenticatedRouting();
      return;
    }
    setState(() => _isLoading = false);
    if (result.status != AccountAuthStatus.cancelled) {
      _showError(_messageFor(result.status));
    }
  }

  Future<void> _runEmail() async {
    if (_isLoading ||
        (_isRegistering && !_acceptedTerms) ||
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _isLoading = true);
    final result = _isRegistering
        ? await widget.authService.registerWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          )
        : await widget.authService.signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
    if (!mounted) return;
    if (result.isSuccess) {
      await _completeAuthenticatedRouting();
      return;
    }
    setState(() => _isLoading = false);
    _showError(_messageFor(result.status));
  }

  Future<void> _completeAuthenticatedRouting() async {
    try {
      await widget.onAuthenticated();
    } on Object {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Unable to open your account. Please try again.');
      return;
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _continueAnonymously() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await widget.onContinueAnonymously();
    } on Object {
      if (mounted) _showError('Unable to continue without an account.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _messageFor(AccountAuthStatus status) {
    return switch (status) {
      AccountAuthStatus.invalidEmail => 'Enter a valid email address.',
      AccountAuthStatus.invalidCredential => 'Incorrect email or password.',
      AccountAuthStatus.emailAlreadyInUse =>
        'This email is already linked to an account.',
      AccountAuthStatus.weakPassword => 'Choose a stronger password.',
      AccountAuthStatus.userDisabled => 'This account has been disabled.',
      AccountAuthStatus.networkRequestFailed =>
        'Check your internet connection and try again.',
      AccountAuthStatus.tooManyRequests =>
        'Too many attempts. Please try again later.',
      AccountAuthStatus.operationNotAllowed =>
        'This sign-in method is not available right now.',
      _ => 'Unable to continue. Please try again.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: Image.asset(
              AuthEntryScreen.backgroundAsset,
              key: const ValueKey('auth-entry-background'),
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final logoSize = (constraints.maxWidth * 0.4)
                    .clamp(128.0, 190.0)
                    .toDouble();
                final topSpacing = (constraints.maxHeight * 0.035)
                    .clamp(12.0, 30.0)
                    .toDouble();

                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (constraints.maxHeight - 18)
                          .clamp(0.0, double.infinity)
                          .toDouble(),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(height: topSpacing),
                        Semantics(
                          image: true,
                          label: 'Gubify',
                          child: Image.asset(
                            AuthEntryScreen.logoAsset,
                            key: const ValueKey('auth-entry-logo'),
                            width: logoSize,
                            height: logoSize,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: Card(
                            child: Padding(
                              padding: _isRegistering
                                  ? const EdgeInsets.fromLTRB(16, 12, 16, 10)
                                  : const EdgeInsets.fromLTRB(20, 18, 20, 16),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (_isRegistering) ...[
                                      const Text(
                                        'Create your account',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                    TextFormField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      autofillHints: const [
                                        AutofillHints.email,
                                      ],
                                      decoration: InputDecoration(
                                        labelText: 'Email',
                                        isDense: _isRegistering ? true : null,
                                        contentPadding: _isRegistering
                                            ? const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 12,
                                              )
                                            : null,
                                      ),
                                      validator: (value) =>
                                          (value?.trim().contains('@') ?? false)
                                          ? null
                                          : 'Enter a valid email address.',
                                    ),
                                    SizedBox(height: _isRegistering ? 8 : 10),
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      autofillHints: [
                                        _isRegistering
                                            ? AutofillHints.newPassword
                                            : AutofillHints.password,
                                      ],
                                      decoration: InputDecoration(
                                        labelText: 'Password',
                                        isDense: _isRegistering ? true : null,
                                        contentPadding: _isRegistering
                                            ? const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 12,
                                              )
                                            : null,
                                        suffixIcon: IconButton(
                                          tooltip: _obscurePassword
                                              ? 'Show password'
                                              : 'Hide password',
                                          onPressed: () => setState(
                                            () => _obscurePassword =
                                                !_obscurePassword,
                                          ),
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                          ),
                                        ),
                                      ),
                                      validator: (value) =>
                                          value?.isNotEmpty == true
                                          ? null
                                          : 'Enter a password.',
                                    ),
                                    if (_isRegistering) ...[
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        controller: _confirmPasswordController,
                                        obscureText: _obscurePassword,
                                        autofillHints: const [
                                          AutofillHints.newPassword,
                                        ],
                                        decoration: const InputDecoration(
                                          labelText: 'Confirm password',
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12,
                                          ),
                                        ),
                                        validator: (value) =>
                                            value == _passwordController.text
                                            ? null
                                            : 'Passwords do not match.',
                                      ),
                                      _TermsAcceptance(
                                        value: _acceptedTerms,
                                        onChanged: _isLoading
                                            ? null
                                            : (value) => setState(
                                                () => _acceptedTerms =
                                                    value ?? false,
                                              ),
                                        termsRecognizer: _termsRecognizer,
                                        privacyRecognizer: _privacyRecognizer,
                                      ),
                                    ],
                                    SizedBox(height: _isRegistering ? 10 : 16),
                                    FilledButton(
                                      style: _isRegistering
                                          ? FilledButton.styleFrom(
                                              minimumSize:
                                                  const Size.fromHeight(46),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 10,
                                                  ),
                                            )
                                          : null,
                                      onPressed:
                                          _isLoading ||
                                              (_isRegistering &&
                                                  !_acceptedTerms)
                                          ? null
                                          : _runEmail,
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Text(
                                              _isRegistering
                                                  ? 'Create account'
                                                  : 'Sign in',
                                            ),
                                    ),
                                    TextButton(
                                      style: _isRegistering
                                          ? TextButton.styleFrom(
                                              minimumSize:
                                                  const Size.fromHeight(42),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 6,
                                                  ),
                                            )
                                          : null,
                                      onPressed: _isLoading
                                          ? null
                                          : () => setState(() {
                                              _isRegistering = !_isRegistering;
                                              _acceptedTerms = false;
                                            }),
                                      child: Text(
                                        _isRegistering
                                            ? 'Already have an account? Sign in'
                                            : 'Create account',
                                      ),
                                    ),
                                    if (!_isRegistering) ...[
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(child: Divider()),
                                            Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 12,
                                              ),
                                              child: Text('or'),
                                            ),
                                            Expanded(child: Divider()),
                                          ],
                                        ),
                                      ),
                                      FilledButton.icon(
                                        onPressed: _isLoading
                                            ? null
                                            : _runGoogle,
                                        icon: _isLoading
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.g_mobiledata_rounded,
                                              ),
                                        label: const Text(
                                          'Continue with Google',
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 2),
                                    TextButton(
                                      style: _isRegistering
                                          ? TextButton.styleFrom(
                                              minimumSize:
                                                  const Size.fromHeight(42),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 6,
                                                  ),
                                            )
                                          : null,
                                      onPressed: _isLoading
                                          ? null
                                          : _continueAnonymously,
                                      child: const Text(
                                        'Continue without an account',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsAcceptance extends StatelessWidget {
  const _TermsAcceptance({
    required this.value,
    required this.onChanged,
    required this.termsRecognizer,
    required this.privacyRecognizer,
  });

  final bool value;
  final ValueChanged<bool?>? onChanged;
  final TapGestureRecognizer termsRecognizer;
  final TapGestureRecognizer privacyRecognizer;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Transform.scale(
          scale: 0.86,
          child: Checkbox(
            value: value,
            activeColor: const Color(0xFF3B82F6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 2),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 13,
                  height: 1.25,
                ),
                children: [
                  const TextSpan(text: 'I agree to the '),
                  TextSpan(
                    text: 'Terms of Service',
                    style: const TextStyle(
                      color: Color(0xFF4DA3FF),
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: termsRecognizer,
                  ),
                  const TextSpan(text: ' and acknowledge the '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: const TextStyle(
                      color: Color(0xFF4DA3FF),
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: privacyRecognizer,
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
