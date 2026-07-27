import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_limits.dart';
import '../../services/gub_service.dart';
import '../../widgets/gub_content_card.dart';
import '../../widgets/gub_screen_background.dart';
import '../../widgets/user_header.dart';
import 'gub_screen.dart';

class CreateGubScreen extends StatefulWidget {
  const CreateGubScreen({super.key});

  @override
  State<CreateGubScreen> createState() => _CreateGubScreenState();
}

class _CreateGubScreenState extends State<CreateGubScreen> {
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _nameFieldKey = GlobalKey();

  double _largestViewportHeight = 0;
  bool _scrollScheduled = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();

    _nameFocusNode.addListener(() {
      if (_nameFocusNode.hasFocus) {
        _scheduleBringFieldIntoView();
      }
    });
  }

  void _scheduleBringFieldIntoView() {
    if (_scrollScheduled) return;

    _scrollScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Aspetta che Android abbia ridimensionato la schermata
      // dopo l'apertura della tastiera.
      await Future<void>.delayed(const Duration(milliseconds: 250));

      if (!mounted || !_nameFocusNode.hasFocus) {
        _scrollScheduled = false;
        return;
      }

      final fieldContext = _nameFieldKey.currentContext;

      if (fieldContext != null && fieldContext.mounted) {
        await Scrollable.ensureVisible(
          fieldContext,
          alignment: 0.65,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }

      _scrollScheduled = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_loading) return;

    final gubName = _nameController.text.trim();

    if (gubName.length < AppLimits.gubNameMinLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Gub name must be at least "
            "${AppLimits.gubNameMinLength} characters.",
          ),
        ),
      );
      return;
    }

    if (gubName.length > AppLimits.gubNameMaxLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Gub name cannot exceed "
            "${AppLimits.gubNameMaxLength} characters.",
          ),
        ),
      );
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _loading = true);

    try {
      final gubId = await GubService().createHub(name: gubName);

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => GubScreen(gubId: gubId)),
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
        variant: GubBackgroundAssignments.createGub,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Memorizza l'altezza maggiore, normalmente quella
              // disponibile quando la tastiera è chiusa.
              if (constraints.maxHeight > _largestViewportHeight) {
                _largestViewportHeight = constraints.maxHeight;
              }

              // Sul Huawei viewInsets.bottom rimane 0.
              // Calcoliamo quindi lo spazio occupato dalla tastiera
              // confrontando l'altezza normale con quella attuale.
              final keyboardOccupiedHeight =
                  (_largestViewportHeight - constraints.maxHeight)
                      .clamp(0.0, double.infinity)
                      .toDouble();

              final keyboardIsOpen = keyboardOccupiedHeight > 40;

              final minimumContentHeight = (constraints.maxHeight - 48)
                  .clamp(0.0, double.infinity)
                  .toDouble();

              if (_nameFocusNode.hasFocus && keyboardIsOpen) {
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
                                "Create your Gub",
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 10),

                              const Text(
                                "Start by choosing a name for your Gub.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                  height: 1.5,
                                ),
                              ),

                              const SizedBox(height: 30),

                              Container(
                                key: _nameFieldKey,
                                child: TextField(
                                  controller: _nameController,
                                  focusNode: _nameFocusNode,
                                  maxLength: AppLimits.gubNameMaxLength,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _continue(),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r"[a-zA-Z0-9À-ÿ '\-_]"),
                                    ),
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: "Choose a name",
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),

                              // Riduce la distanza quando la tastiera
                              // restringe la viewport.
                              if (keyboardIsOpen)
                                const SizedBox(height: 16)
                              else
                                const SizedBox(height: 30),

                              SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: FilledButton(
                                  onPressed: _loading ? null : _continue,
                                  child: _loading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 3,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text("Create Gub"),
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
