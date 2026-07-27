import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../services/user_service.dart';
import '../../../widgets/gub_screen_background.dart';
import '../../chat/widgets/gub_chat_overlay.dart';
import '../models/proposal_model.dart';
import '../services/proposal_service.dart';

class CreateProposalScreen extends StatefulWidget {
  final String gubId;
  final int memberCount;

  const CreateProposalScreen({
    super.key,
    required this.gubId,
    required this.memberCount,
  });

  @override
  State<CreateProposalScreen> createState() => _CreateProposalScreenState();
}

class _CreateProposalScreenState extends State<CreateProposalScreen> {
  static const Color _primaryColor = Color(0xFF2563EB);
  static const Color _textColor = Color(0xFF0F172A);
  static const Color _secondaryTextColor = Color(0xFF64748B);
  static const Color _borderColor = Color(0xFFDCE6F5);
  static const Color _softBlueColor = Color(0xFFEFF6FF);

  final TextEditingController _titleController = TextEditingController();

  final TextEditingController _descriptionController = TextEditingController();

  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _descriptionFocusNode = FocusNode();

  final ScrollController _scrollController = ScrollController();

  final GlobalKey _titleFieldKey = GlobalKey();
  final GlobalKey _descriptionFieldKey = GlobalKey();

  double _largestViewportHeight = 0;
  int _scrollRequestId = 0;

  DateTime? eventDate;
  TimeOfDay? eventTime;

  int votingDays = 1;

  @override
  void initState() {
    super.initState();

    _titleFocusNode.addListener(() {
      if (_titleFocusNode.hasFocus) {
        _scheduleFieldScroll(
          fieldKey: _titleFieldKey,
          focusNode: _titleFocusNode,
          alignment: 0.52,
        );
      }
    });

    _descriptionFocusNode.addListener(() {
      if (_descriptionFocusNode.hasFocus) {
        _scheduleFieldScroll(
          fieldKey: _descriptionFieldKey,
          focusNode: _descriptionFocusNode,
          alignment: 0.16,
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

    // Attende l'apertura della tastiera e il resize Android.
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
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
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

  Widget _sectionTitle({
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

  Widget _selectionTile({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _softBlueColor,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: _primaryColor, size: 21),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _secondaryTextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: const TextStyle(
                        color: _textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickEventDate() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final date = await GubChatOverlay.runWithChatOverlayHidden(
      () => showDatePicker(
        context: context,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        initialDate: eventDate ?? DateTime.now(),
      ),
    );

    if (!mounted || date == null) return;

    setState(() {
      eventDate = date;
    });
  }

  Future<void> _pickEventTime() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final time = await GubChatOverlay.runWithChatOverlayHidden(
      () => showTimePicker(
        context: context,
        initialTime: eventTime ?? TimeOfDay.now(),
      ),
    );

    if (!mounted || time == null) return;

    setState(() {
      eventTime = time;
    });
  }

  Future<void> _createProposal() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter a title.")));
      return;
    }

    if (eventDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Choose an event date.")));
      return;
    }

    if (eventTime == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Choose an event time.")));
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    final user = FirebaseAuth.instance.currentUser!;

    final creatorName = await UserService().getDisplayName(user.uid);

    final proposal = ProposalModel(
      gubId: widget.gubId,
      proposalId: FirebaseFirestore.instance.collection("temp").doc().id,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      creatorId: user.uid,
      creatorName: creatorName,
      status: "voting",
      createdAt: Timestamp.now(),
      expiresAt: Timestamp.fromDate(
        DateTime.now().add(Duration(days: votingDays)),
      ),
      eventDate: Timestamp.fromDate(
        DateTime(
          eventDate!.year,
          eventDate!.month,
          eventDate!.day,
          eventTime!.hour,
          eventTime!.minute,
        ),
      ),
      type: "custom",
      yesVotes: 0,
      noVotes: 0,
      memberCount: widget.memberCount,
      resultProcessed: false,
      eventCreated: false,
      tasksCreated: false,
    );

    await ProposalService.instance.createProposal(proposal: proposal);

    if (!mounted) return;

    Navigator.pop(context);
  }

  @override
  void dispose() {
    _scrollRequestId++;

    _titleController.dispose();
    _descriptionController.dispose();

    _titleFocusNode.dispose();
    _descriptionFocusNode.dispose();

    _scrollController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GubScreenBackground(
      variant: GubBackgroundAssignments.proposals,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const Text(
            "New Proposal",
            style: TextStyle(color: _textColor, fontWeight: FontWeight.w700),
          ),
        ),
        body: LayoutBuilder(
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
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
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
                      Icons.how_to_vote_rounded,
                      size: 38,
                      color: _primaryColor,
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                const Text(
                  "Create a Proposal",
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
                  "Turn an idea into a group decision.",
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
                      _sectionTitle(
                        icon: Icons.edit_note_rounded,
                        title: "Proposal details",
                        subtitle: "Explain clearly what members will vote on.",
                      ),

                      const SizedBox(height: 20),

                      Container(
                        key: _titleFieldKey,
                        child: TextField(
                          controller: _titleController,
                          focusNode: _titleFocusNode,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) {
                            _descriptionFocusNode.requestFocus();
                          },
                          decoration: _inputDecoration(
                            label: "Proposal title",
                            hint: "Example: Dinner on Saturday",
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
                          decoration: _inputDecoration(
                            label: "Description",
                            hint: "Add useful details for the group",
                            icon: Icons.subject_rounded,
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
                      _sectionTitle(
                        icon: Icons.event_available_rounded,
                        title: "Event settings",
                        subtitle: "Choose when the approved event will happen.",
                      ),

                      const SizedBox(height: 15),

                      _selectionTile(
                        icon: Icons.calendar_month_rounded,
                        title: "Event date",
                        value: eventDate == null
                            ? "Choose a date"
                            : "${eventDate!.day.toString().padLeft(2, '0')}/"
                                  "${eventDate!.month.toString().padLeft(2, '0')}/"
                                  "${eventDate!.year}",
                        onTap: _pickEventDate,
                      ),

                      const Divider(height: 1, color: Color(0xFFE7EEF8)),

                      _selectionTile(
                        icon: Icons.schedule_rounded,
                        title: "Event time",
                        value: eventTime == null
                            ? "Choose a time"
                            : "${eventTime!.hour.toString().padLeft(2, '0')}:"
                                  "${eventTime!.minute.toString().padLeft(2, '0')}",
                        onTap: _pickEventTime,
                      ),

                      const Divider(height: 25, color: Color(0xFFE7EEF8)),

                      DropdownButtonFormField<int>(
                        initialValue: votingDays,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: _primaryColor,
                        ),
                        decoration: _inputDecoration(
                          label: "Voting duration",
                          hint: "Choose voting duration",
                          icon: Icons.timer_outlined,
                        ),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text("1 day")),
                          DropdownMenuItem(value: 3, child: Text("3 days")),
                          DropdownMenuItem(value: 7, child: Text("7 days")),
                        ],
                        onChanged: (value) {
                          if (value == null) return;

                          setState(() {
                            votingDays = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 26),

                SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _createProposal,
                    style: FilledButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.how_to_vote_rounded),
                    label: const Text(
                      "Create Proposal",
                      style: TextStyle(
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
    );
  }
}
