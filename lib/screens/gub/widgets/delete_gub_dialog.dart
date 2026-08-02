import 'package:flutter/material.dart';

typedef DeleteGubCallback =
    Future<void> Function(
      String confirmedName,
      ValueChanged<String> onProgress,
    );

class DeleteGubDialog extends StatefulWidget {
  final String gubName;
  final DeleteGubCallback onDelete;

  const DeleteGubDialog({
    super.key,
    required this.gubName,
    required this.onDelete,
  });

  @override
  State<DeleteGubDialog> createState() => _DeleteGubDialogState();
}

class _DeleteGubDialogState extends State<DeleteGubDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _isDeleting = false;
  String? _progress;
  String? _error;

  bool get _matchesName =>
      widget.gubName.isNotEmpty && _controller.text == widget.gubName;

  Future<void> _delete() async {
    if (_isDeleting || !_matchesName) return;

    setState(() {
      _isDeleting = true;
      _progress = 'Preparing deletion…';
      _error = null;
    });

    try {
      await widget.onDelete(_controller.text, (message) {
        if (mounted) setState(() => _progress = message);
      });
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isDeleting = false;
        _progress = null;
        _error = error
            .toString()
            .replaceFirst('GubDeletionException: ', '')
            .replaceFirst('Bad state: ', '')
            .replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_isDeleting,
      child: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.fromLTRB(16, 12, 16, viewInsets.bottom + 12),
          child: LayoutBuilder(
            builder: (context, constraints) => Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 560,
                  maxHeight: constraints.maxHeight,
                ),
                child: Material(
                  color:
                      theme.dialogTheme.backgroundColor ??
                      theme.colorScheme.surface,
                  elevation: 6,
                  shadowColor: theme.colorScheme.shadow.withValues(alpha: .2),
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delete this Gub?',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'This will permanently delete the Gub and all its tasks, '
                          'events, proposals, shared budgets, messages and member data. '
                          'This action cannot be undone.',
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Type this Gub name exactly:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                          ),
                          child: SelectableText(
                            widget.gubName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _controller,
                          enabled: !_isDeleting,
                          autofocus: true,
                          decoration: const InputDecoration(
                            labelText: 'Type the Gub name to confirm',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        if (_progress != null) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(_progress!)),
                            ],
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        OverflowBar(
                          alignment: MainAxisAlignment.end,
                          spacing: 8,
                          overflowSpacing: 8,
                          children: [
                            TextButton(
                              onPressed: _isDeleting
                                  ? null
                                  : () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              onPressed: _matchesName && !_isDeleting
                                  ? _delete
                                  : null,
                              child: const Text('Delete Gub permanently'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
