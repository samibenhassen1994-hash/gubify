import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_limits.dart';
import '../../modules/community/models/community_model.dart';
import '../../modules/community/screens/gub_community_home_screen.dart';
import '../../modules/community/services/community_service.dart';
import '../../modules/community/widgets/community_search_picker.dart';
import '../../services/gub_service.dart';
import '../../widgets/gub_content_card.dart';
import '../../widgets/gub_screen_background.dart';
import '../../widgets/user_header.dart';
import 'gub_screen.dart';
import 'widgets/gub_type_selector.dart';

class CreateGubScreen extends StatefulWidget {
  const CreateGubScreen({super.key});

  @override
  State<CreateGubScreen> createState() => _CreateGubScreenState();
}

class _CreateGubScreenState extends State<CreateGubScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _nameFieldKey = GlobalKey();
  final GlobalKey _formCardKey = GlobalKey();

  double _largestViewportHeight = 0;
  bool _scrollScheduled = false;
  bool _typeScrollScheduled = false;
  bool _typeScrollPending = false;
  bool _loading = false;
  bool _checkingCommunityOwnership = false;
  bool _typeImagesPrecached = false;
  int _typeSelectionRequest = 0;
  GubType _selectedType = GubType.private;
  String _selectedCommunityType = CommunityModel.defaultType;
  String _selectedCommunityLanguage = CommunityModel.defaultLanguage;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _positionFormForInitialView();
    });

    _nameFocusNode.addListener(() {
      if (_nameFocusNode.hasFocus) {
        _scheduleBringFieldIntoView();
      }
    });
  }

  void _positionFormForInitialView() {
    if (!mounted || !_scrollController.hasClients) return;

    final formContext = _formCardKey.currentContext;
    if (formContext == null || !formContext.mounted) return;

    Scrollable.ensureVisible(
      formContext,
      alignment: 0.02,
      duration: Duration.zero,
    );
  }

  Future<void> _selectCommunityType() async {
    final type = await showCommunitySearchPicker(
      context: context,
      title: 'Select Community type',
      options: CommunityModel.availableTypes,
      selectedValue: _selectedCommunityType,
    );
    if (!mounted || type == null) return;
    setState(() => _selectedCommunityType = type);
  }

  Future<void> _selectCommunityLanguage() async {
    final language = await showCommunitySearchPicker(
      context: context,
      title: 'Select Community language',
      options: CommunityModel.availableLanguages,
      selectedValue: _selectedCommunityLanguage,
    );
    if (!mounted || language == null) return;
    setState(() => _selectedCommunityLanguage = language);
  }

  Future<void> _changeType(GubType type) async {
    if (_loading ||
        type == _selectedType && !_checkingCommunityOwnership ||
        type == GubType.community && _checkingCommunityOwnership) {
      return;
    }

    final request = ++_typeSelectionRequest;
    if (type == GubType.private) {
      setState(() {
        _selectedType = GubType.private;
        _checkingCommunityOwnership = false;
      });
      _scheduleScrollToUpdatedFormBottom();
      return;
    }

    setState(() => _checkingCommunityOwnership = true);
    try {
      final ownsCommunity = await CommunityService.instance
          .currentUserOwnsCommunity();
      if (!mounted || request != _typeSelectionRequest) return;

      if (ownsCommunity) {
        setState(() {
          _selectedType = GubType.private;
          _checkingCommunityOwnership = false;
        });
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Community limit reached'),
            content: const Text(
              'You can create only one Community. You can still join other Communities.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Got it'),
              ),
            ],
          ),
        );
        if (!mounted || request != _typeSelectionRequest) return;
        _scheduleScrollToUpdatedFormBottom();
        return;
      }

      setState(() {
        _selectedType = GubType.community;
        _checkingCommunityOwnership = false;
      });
      _scheduleScrollToUpdatedFormBottom();
    } catch (_) {
      if (!mounted || request != _typeSelectionRequest) return;
      setState(() {
        _selectedType = GubType.private;
        _checkingCommunityOwnership = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to verify Community ownership. Please try again.',
          ),
        ),
      );
    }
  }

  void _scheduleScrollToUpdatedFormBottom() {
    if (_typeScrollScheduled) {
      _typeScrollPending = true;
      return;
    }
    _typeScrollScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_scrollController.hasClients) {
        _typeScrollScheduled = false;
        return;
      }

      try {
        await _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      } catch (_) {
        // The controller can detach if the route closes during the animation.
      }
      _typeScrollScheduled = false;
      if (_typeScrollPending && mounted) {
        _typeScrollPending = false;
        _scheduleScrollToUpdatedFormBottom();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_typeImagesPrecached) return;

    _typeImagesPrecached = true;
    precacheImage(const AssetImage(GubTypeSelector.privateAssetPath), context);
    precacheImage(
      const AssetImage(GubTypeSelector.communityAssetPath),
      context,
    );
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
    _descriptionController.dispose();
    _nameFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_loading || _checkingCommunityOwnership) return;

    final gubName = _nameController.text.trim();

    final nameLabel = _selectedType == GubType.private
        ? "Gub name"
        : "Community name";

    if (gubName.length < AppLimits.gubNameMinLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "$nameLabel must be at least "
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
            "$nameLabel cannot exceed "
            "${AppLimits.gubNameMaxLength} characters.",
          ),
        ),
      );
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _loading = true);

    try {
      if (_selectedType == GubType.community) {
        final community = await CommunityService.instance.createCommunity(
          name: gubName,
          description: _descriptionController.text,
          type: _selectedCommunityType,
          language: _selectedCommunityLanguage,
        );

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => GubCommunityHomeScreen(
              communityId: community.communityId,
              initialCommunity: community,
            ),
          ),
        );
        return;
      }

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
    final isPrivate = _selectedType == GubType.private;
    final fieldLabel = isPrivate ? "Gub name" : "Community name";
    final fieldHint = isPrivate
        ? "For example: My family"
        : "For example: Photography lovers";
    final buttonLabel = isPrivate ? "Create private Gub" : "Create community";

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

                        const SizedBox(height: 18),

                        GubContentCard(
                          key: _formCardKey,
                          child: Column(
                            children: [
                              GubTypeSelector(
                                selectedType: _selectedType,
                                enabled: !_loading,
                                onChanged: _changeType,
                              ),

                              if (_checkingCommunityOwnership) ...[
                                const SizedBox(height: 12),
                                const LinearProgressIndicator(),
                              ],

                              const SizedBox(height: 24),

                              const Text(
                                "Create your Gub",
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 24),

                              Container(
                                key: _nameFieldKey,
                                child: TextField(
                                  controller: _nameController,
                                  focusNode: _nameFocusNode,
                                  enabled: !_loading,
                                  maxLength: AppLimits.gubNameMaxLength,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _continue(),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r"[a-zA-Z0-9À-ÿ '\-_]"),
                                    ),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: fieldLabel,
                                    hintText: fieldHint,
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),

                              if (_selectedType == GubType.community) ...[
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _descriptionController,
                                  enabled: !_loading,
                                  minLines: 2,
                                  maxLines: 4,
                                  maxLength: 280,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  decoration: const InputDecoration(
                                    labelText: "Description (optional)",
                                    alignLabelWithHint: true,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                CommunityPickerField(
                                  label: 'Type',
                                  value: _selectedCommunityType,
                                  enabled: !_loading,
                                  onTap: _selectCommunityType,
                                ),
                                const SizedBox(height: 16),
                                CommunityPickerField(
                                  label: 'Language',
                                  value: _selectedCommunityLanguage,
                                  enabled: !_loading,
                                  onTap: _selectCommunityLanguage,
                                ),
                              ],

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
                                  onPressed:
                                      _loading || _checkingCommunityOwnership
                                      ? null
                                      : _continue,
                                  child: _loading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 3,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(buttonLabel),
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
