import 'dart:async';

import 'package:flutter/material.dart';

import '../services/gub_rules_service.dart';

class GubCommunityRulesGate extends StatefulWidget {
  final String gubId;
  final Widget child;

  const GubCommunityRulesGate({
    super.key,
    required this.gubId,
    required this.child,
  });

  @override
  State<GubCommunityRulesGate> createState() => _GubCommunityRulesGateState();
}

class _GubCommunityRulesGateState extends State<GubCommunityRulesGate> {
  bool _checking = true;
  bool _accepted = false;
  bool _dialogOpen = false;
  Object? _checkError;

  @override
  void initState() {
    super.initState();
    unawaited(_checkAcceptance());
  }

  @override
  void didUpdateWidget(covariant GubCommunityRulesGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gubId != widget.gubId) {
      _checking = true;
      _accepted = false;
      _dialogOpen = false;
      _checkError = null;
      unawaited(_checkAcceptance());
    }
  }

  Future<void> _checkAcceptance() async {
    try {
      final accepted = await GubRulesService.instance.hasCurrentUserAccepted(
        widget.gubId,
      );
      if (!mounted) return;
      setState(() {
        _accepted = accepted;
        _checking = false;
        _checkError = null;
      });
      if (!accepted) _scheduleDialog();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _checkError = error;
      });
    }
  }

  void _scheduleDialog() {
    if (_dialogOpen || _accepted || !mounted) return;
    _dialogOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _accepted) {
        _dialogOpen = false;
        return;
      }
      final accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _GubCommunityRulesDialog(
          onAccept: () =>
              GubRulesService.instance.acceptForCurrentUser(widget.gubId),
        ),
      );
      _dialogOpen = false;
      if (!mounted) return;
      if (accepted == true) {
        setState(() => _accepted = true);
      } else if (!_accepted) {
        _scheduleDialog();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_accepted) return widget.child;

    if (!_checking && _checkError != null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Unable to verify the Gub community rules.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        _checking = true;
                        _checkError = null;
                      });
                      unawaited(_checkAcceptance());
                    },
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!_checking) _scheduleDialog();
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _GubCommunityRulesDialog extends StatefulWidget {
  final Future<void> Function() onAccept;

  const _GubCommunityRulesDialog({required this.onAccept});

  @override
  State<_GubCommunityRulesDialog> createState() =>
      _GubCommunityRulesDialogState();
}

class _GubCommunityRulesDialogState extends State<_GubCommunityRulesDialog> {
  bool _agreed = false;
  bool _saving = false;
  String? _error;

  Future<void> _accept() async {
    if (!_agreed || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onAccept();
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _errorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Gub community rules'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'To keep this Gub organized and useful for everyone, '
                'please follow these rules:',
              ),
              const SizedBox(height: 12),
              for (final rule in _rules)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  '),
                      Expanded(child: Text(rule)),
                    ],
                  ),
                ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _agreed,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _agreed = value == true),
                title: const Text(
                  'I have read and understood the rules, and I agree to '
                  'behave appropriately.',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: !_agreed || _saving ? null : _accept,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('I understand and continue'),
          ),
        ],
      ),
    );
  }

  static const _rules = [
    'Create tasks, events and proposals only when they are genuinely useful.',
    'Do not create duplicate, misleading or joke content.',
    'Members can have only one active creation of each limited module at a time.',
    'Deleting an item starts a 12-hour cooldown before another item of the same type can be created in this Gub.',
    'The Gub owner can manage and remove content without creation limits or cooldowns.',
    'If the owner removes a member’s item, the cooldown applies to the original creator.',
    'Repeated misuse may result in content being removed by the Gub owner.',
  ];

  String _errorMessage(Object error) {
    final message = error
        .toString()
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Exception: ', '');
    return message.isEmpty
        ? 'Unable to save your acceptance. Please try again.'
        : message;
  }
}
