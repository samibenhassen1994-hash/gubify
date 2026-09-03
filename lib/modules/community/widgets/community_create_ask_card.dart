import 'package:flutter/material.dart';

import '../../../config/app_limits.dart';
import '../../../widgets/gub_content_card.dart';
import '../models/community_ask_model.dart';
import '../services/community_ask_service.dart';

typedef CommunityDirectAskSubmit =
    Future<void> Function({
      required String text,
      required CommunityAskType type,
    });

class CommunityCreateAskCard extends StatefulWidget {
  const CommunityCreateAskCard({
    super.key,
    required this.onCreate,
    required this.onCreated,
  });

  final CommunityDirectAskSubmit onCreate;
  final VoidCallback onCreated;

  @override
  State<CommunityCreateAskCard> createState() => _CommunityCreateAskCardState();
}

class _CommunityCreateAskCardState extends State<CommunityCreateAskCard> {
  final TextEditingController _controller = TextEditingController();
  CommunityAskType? _selectedType;
  bool _submitting = false;
  String? _errorMessage;

  bool get _canSubmit =>
      !_submitting &&
      _controller.text.trim().isNotEmpty &&
      _selectedType != null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final text = _controller.text.trim();
    final type = _selectedType!;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await widget.onCreate(text: text, type: type);
      if (!mounted) return;
      _controller.clear();
      setState(() {
        _selectedType = null;
        _submitting = false;
      });
      widget.onCreated();
    } on CommunityActiveAskExistsException {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = 'You already have an active Ask in this Community.';
      });
    } on CommunityAskCooldownException catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = error.userMessage;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = 'Unable to create this ask. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: GubContentCard(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(
              alignment: Alignment.center,
              child: Text(
                'Create ask',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 7),
            TextField(
              key: const ValueKey('create-ask-text'),
              controller: _controller,
              minLines: 2,
              maxLines: 4,
              maxLength: AppLimits.communityMessageMaxLength,
              enabled: !_submitting,
              decoration: const InputDecoration(
                hintText: 'What do you want to ask?',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() => _errorMessage = null),
            ),
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final type in CommunityAskType.values)
                  ChoiceChip(
                    key: ValueKey('create-ask-type-${type.value}'),
                    label: Text(type.label),
                    selected: _selectedType == type,
                    onSelected: _submitting
                        ? null
                        : (_) => setState(() {
                            _selectedType = type;
                            _errorMessage = null;
                          }),
                  ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 5),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],
            const SizedBox(height: 7),
            Align(
              alignment: Alignment.center,
              child: FilledButton(
                key: const ValueKey('create-ask-submit'),
                onPressed: _canSubmit ? _submit : null,
                child: _submitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create ask'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
