import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../../core/formatters/monetary_amount_input_formatter.dart';
import '../../../widgets/gub_screen_background.dart';
import '../services/goal_service.dart';

class CreateGoalScreen extends StatefulWidget {
  final String gubId;

  const CreateGoalScreen({super.key, required this.gubId});

  @override
  State<CreateGoalScreen> createState() => _CreateGoalScreenState();
}

class _CreateGoalScreenState extends State<CreateGoalScreen> {
  static const Color _primaryColor = Color(0xFF2563EB);
  static const Color _textColor = Color(0xFF0F172A);
  static const Color _secondaryTextColor = Color(0xFF64748B);
  static const Color _borderColor = Color(0xFFDCE6F5);
  static const Color _softBlueColor = Color(0xFFEFF6FF);

  final TextEditingController _titleController = TextEditingController();

  final TextEditingController _descriptionController = TextEditingController();

  final TextEditingController _amountController = TextEditingController();

  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _descriptionFocusNode = FocusNode();
  final FocusNode _amountFocusNode = FocusNode();

  final ScrollController _scrollController = ScrollController();

  final GlobalKey _titleFieldKey = GlobalKey();
  final GlobalKey _descriptionFieldKey = GlobalKey();
  final GlobalKey _amountFieldKey = GlobalKey();

  double _largestViewportHeight = 0;
  int _scrollRequestId = 0;

  DateTime? _deadline;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _titleFocusNode.addListener(() {
      if (_titleFocusNode.hasFocus) {
        _scheduleFieldScroll(
          fieldKey: _titleFieldKey,
          focusNode: _titleFocusNode,
          alignment: 0.65,
        );
      }
    });

    _descriptionFocusNode.addListener(() {
      if (_descriptionFocusNode.hasFocus) {
        _scheduleFieldScroll(
          fieldKey: _descriptionFieldKey,
          focusNode: _descriptionFocusNode,
          alignment: 0.28,
        );
      }
    });

    _amountFocusNode.addListener(() {
      if (_amountFocusNode.hasFocus) {
        _scheduleFieldScroll(
          fieldKey: _amountFieldKey,
          focusNode: _amountFocusNode,
          alignment: 0.48,
        );
      }
    });
  }

  Future<void> _scheduleFieldScroll({
    required GlobalKey fieldKey,
    required FocusNode focusNode,
    required double alignment,
  }) async {
    final requestId = ++_scrollRequestId;

    // Aspetta che Android abbia aperto la tastiera
    // e ridimensionato la viewport.
    await Future<void>.delayed(const Duration(milliseconds: 300));

    if (!mounted || requestId != _scrollRequestId || !focusNode.hasFocus) {
      return;
    }

    await WidgetsBinding.instance.endOfFrame;

    if (!mounted || requestId != _scrollRequestId || !focusNode.hasFocus) {
      return;
    }

    final fieldContext = fieldKey.currentContext;
    final renderObject = fieldContext?.findRenderObject();

    if (renderObject == null || !_scrollController.hasClients) {
      return;
    }

    final viewport = RenderAbstractViewport.maybeOf(renderObject);

    if (viewport == null) return;

    final revealedOffset = viewport
        .getOffsetToReveal(renderObject, alignment)
        .offset;

    final position = _scrollController.position;

    final targetOffset = revealedOffset
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();

    await _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    String? prefixText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefixText,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
      labelStyle: const TextStyle(
        color: _secondaryTextColor,
        fontWeight: FontWeight.w500,
      ),
      floatingLabelStyle: const TextStyle(
        color: _primaryColor,
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Icon(icon, color: _primaryColor),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _borderColor, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.045),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _softBlueColor,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: _primaryColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _secondaryTextColor,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickDeadline() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (!mounted || picked == null) return;

    setState(() {
      _deadline = picked;
    });
  }

  Future<void> _createGoal() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    final normalizedAmount = _amountController.text.trim().replaceAll(',', '.');

    final amount = double.tryParse(normalizedAmount);

    if (title.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid title and amount.")),
      );
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      await GoalService.instance.createGoal(
        gubId: widget.gubId,
        title: title,
        description: description,
        targetAmount: amount,
        deadline: _deadline,
      );

      if (!mounted) return;

      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  void dispose() {
    _scrollRequestId++;

    _titleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();

    _titleFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _amountFocusNode.dispose();

    _scrollController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GubScreenBackground(
      variant: GubBackgroundAssignments.sharedBudget,
      whiteOverlayOpacity: GubBackgroundAssignments.economicWhiteOverlayOpacity,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const Text(
            "New Shared Budget",
            style: TextStyle(color: _textColor, fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxHeight > _largestViewportHeight) {
                _largestViewportHeight = constraints.maxHeight;
              }

              final keyboardOccupiedHeight =
                  (_largestViewportHeight - constraints.maxHeight)
                      .clamp(0.0, double.infinity)
                      .toDouble();

              return ListView(
                controller: _scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.manual,
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  36 + keyboardOccupiedHeight,
                ),
                children: [
                  Center(
                    child: Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        color: _softBlueColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: const Icon(
                        Icons.flag_rounded,
                        size: 38,
                        color: _primaryColor,
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    "Create a Shared Budget",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _textColor,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),

                  const SizedBox(height: 7),

                  const Text(
                    "Set a shared target and reach it together.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _secondaryTextColor,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 28),

                  _sectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _sectionHeader(
                          icon: Icons.edit_note_rounded,
                          title: "Shared Budget details",
                          subtitle: "Give your group a clear objective.",
                        ),

                        const SizedBox(height: 20),

                        Container(
                          key: _titleFieldKey,
                          child: TextField(
                            controller: _titleController,
                            focusNode: _titleFocusNode,
                            maxLength: 100,
                            maxLengthEnforcement: MaxLengthEnforcement.enforced,
                            textInputAction: TextInputAction.next,
                            onSubmitted: (_) {
                              _descriptionFocusNode.requestFocus();
                            },
                            decoration: _inputDecoration(
                              label: "Title",
                              hint: "Example: Summer holiday fund",
                              icon: Icons.title_rounded,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        Container(
                          key: _descriptionFieldKey,
                          child: TextField(
                            controller: _descriptionController,
                            focusNode: _descriptionFocusNode,
                            keyboardType: TextInputType.multiline,
                            minLines: 3,
                            maxLines: 5,
                            maxLength: 500,
                            maxLengthEnforcement: MaxLengthEnforcement.enforced,
                            decoration: _inputDecoration(
                              label: "Description",
                              hint: "Explain what the Shared Budget is for",
                              icon: Icons.subject_rounded,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        Container(
                          key: _amountFieldKey,
                          child: TextField(
                            controller: _amountController,
                            focusNode: _amountFocusNode,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: const [
                              MonetaryAmountInputFormatter(),
                            ],
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) {
                              if (!_isLoading) {
                                _createGoal();
                              }
                            },
                            decoration: _inputDecoration(
                              label: "Target amount",
                              hint: "0.00",
                              icon: Icons.euro_rounded,
                              prefixText: "€ ",
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  _sectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _sectionHeader(
                          icon: Icons.calendar_month_rounded,
                          title: "Shared Budget deadline",
                          subtitle: "The deadline is optional.",
                        ),

                        const SizedBox(height: 16),

                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _pickDeadline,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: _softBlueColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFBFDBFE),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    child: const Icon(
                                      Icons.event_available_rounded,
                                      color: _primaryColor,
                                    ),
                                  ),
                                  const SizedBox(width: 13),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Deadline",
                                          style: TextStyle(
                                            color: _secondaryTextColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          _deadline == null
                                              ? "No deadline selected"
                                              : "${_deadline!.day.toString().padLeft(2, '0')}/"
                                                    "${_deadline!.month.toString().padLeft(2, '0')}/"
                                                    "${_deadline!.year}",
                                          style: const TextStyle(
                                            color: _textColor,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        if (_deadline != null) ...[
                          const SizedBox(height: 10),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _deadline = null;
                              });
                            },
                            icon: const Icon(Icons.close_rounded, size: 18),
                            label: const Text("Remove deadline"),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 26),

                  SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: _isLoading ? null : _createGoal,
                      style: FilledButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _primaryColor.withValues(
                          alpha: 0.55,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      icon: _isLoading
                          ? const SizedBox(
                              width: 21,
                              height: 21,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.flag_rounded),
                      label: Text(
                        _isLoading ? "Creating..." : "Create Shared Budget",
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
