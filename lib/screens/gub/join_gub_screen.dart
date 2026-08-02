import 'package:flutter/material.dart';

import '../../core/invites/invite_code.dart';
import '../../core/invites/invite_code_input_formatter.dart';
import '../../services/gub_service.dart';
import '../../widgets/gub_content_card.dart';
import '../../widgets/gub_screen_background.dart';
import '../../widgets/user_header.dart';
import 'gub_screen.dart';

class JoinGubScreen extends StatefulWidget {
  final Future<String> Function({required String inviteCode})? joinAction;
  final bool showUserHeader;
  final String? initialCode;

  const JoinGubScreen({
    super.key,
    this.joinAction,
    this.showUserHeader = true,
    this.initialCode,
  });

  @override
  State<JoinGubScreen> createState() => _JoinGubScreenState();
}

class _JoinGubScreenState extends State<JoinGubScreen> {
  late final TextEditingController _controller;
  final FocusNode _inviteCodeFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _inviteCodeFieldKey = GlobalKey();

  double _largestViewportHeight = 0;
  bool _scrollScheduled = false;

  bool _loading = false;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(text: _formattedInitialCode());

    _inviteCodeFocusNode.addListener(() {
      if (_inviteCodeFocusNode.hasFocus) {
        _scheduleBringFieldIntoView();
      }
    });
  }

  String _formattedInitialCode() {
    final initialCode = widget.initialCode;
    if (initialCode == null) return '';

    try {
      return InviteCode.format(InviteCode.normalize(initialCode));
    } on InvalidInviteCodeException {
      return '';
    }
  }

  void _scheduleBringFieldIntoView() {
    if (_scrollScheduled) return;

    _scrollScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 250));

      if (!mounted || !_inviteCodeFocusNode.hasFocus) {
        _scrollScheduled = false;
        return;
      }

      final fieldContext = _inviteCodeFieldKey.currentContext;

      if (fieldContext == null || !fieldContext.mounted) {
        _scrollScheduled = false;
        return;
      }

      await Scrollable.ensureVisible(
        fieldContext,
        alignment: 0.65,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );

      _scrollScheduled = false;
    });
  }

  Future<void> _joinHub() async {
    if (_loading) return;
    final visibleInviteCode = _controller.text;

    if (visibleInviteCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a Gub invite code.")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final inviteCode = InviteCode.normalize(visibleInviteCode);
      final gubId = await (widget.joinAction ?? GubService().joinHub)(
        inviteCode: inviteCode,
      );

      if (!mounted) return;

      FocusManager.instance.primaryFocus?.unfocus();

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => GubScreen(gubId: gubId)),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;

      final message = e
          .toString()
          .replaceFirst('Exception: ', '')
          .replaceFirst('Bad state: ', '');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _inviteCodeFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _goBack() {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: GubScreenBackground(
        variant: GubBackgroundAssignments.joinGub,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxHeight > _largestViewportHeight) {
                _largestViewportHeight = constraints.maxHeight;
              }

              final keyboardOccupiedHeight =
                  (_largestViewportHeight - constraints.maxHeight)
                      .clamp(0.0, double.infinity)
                      .toDouble();

              final keyboardIsOpen = keyboardOccupiedHeight > 40;

              final minimumContentHeight = (constraints.maxHeight - 48)
                  .clamp(0.0, double.infinity)
                  .toDouble();

              if (_inviteCodeFocusNode.hasFocus && keyboardIsOpen) {
                _scheduleBringFieldIntoView();
              }

              return SingleChildScrollView(
                controller: _scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.manual,
                padding: EdgeInsets.fromLTRB(
                  24,
                  24,
                  24,
                  24 + keyboardOccupiedHeight,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minimumContentHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: _goBack,
                          ),
                        ),

                        if (widget.showUserHeader)
                          const UserHeader(showCard: true),

                        const SizedBox(height: 10),

                        GubContentCard(
                          child: Column(
                            children: [
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

                              Container(
                                key: _inviteCodeFieldKey,
                                child: TextField(
                                  controller: _controller,
                                  focusNode: _inviteCodeFocusNode,
                                  maxLength: InviteCode.formattedLength,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _joinHub(),
                                  inputFormatters: const [
                                    InviteCodeInputFormatter(),
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: "Invitation Code",
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.vpn_key),
                                  ),
                                ),
                              ),

                              if (keyboardIsOpen)
                                const SizedBox(height: 16)
                              else
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
                                      : const Text(
                                          "Join Gub",
                                          style: TextStyle(fontSize: 17),
                                        ),
                                ),
                              ),

                              const SizedBox(height: 2),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
