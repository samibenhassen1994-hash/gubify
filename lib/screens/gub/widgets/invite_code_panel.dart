import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/invites/invite_code.dart';
import '../../../core/invites/invite_share_content.dart';

typedef InviteShareAction =
    Future<void> Function({
      required String text,
      required Rect sharePositionOrigin,
    });

class InviteCodePanel extends StatefulWidget {
  final String gubName;
  final String canonicalCode;
  final bool inviteAvailable;
  final InviteShareAction? shareAction;

  const InviteCodePanel({
    super.key,
    required this.gubName,
    required this.canonicalCode,
    this.inviteAvailable = true,
    this.shareAction,
  });

  @override
  State<InviteCodePanel> createState() => _InviteCodePanelState();
}

class _InviteCodePanelState extends State<InviteCodePanel> {
  bool _copying = false;
  bool _sharing = false;

  InviteShareContent? get _content {
    if (!widget.inviteAvailable) return null;
    try {
      return InviteShareContent.build(
        gubName: widget.gubName,
        canonicalCode: widget.canonicalCode,
      );
    } on InvalidInviteCodeException {
      return null;
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copyCode(InviteShareContent content) async {
    if (_copying) return;
    setState(() => _copying = true);
    try {
      await Clipboard.setData(ClipboardData(text: content.visibleCode));
      _showMessage('Invite code copied');
    } catch (_) {
      _showMessage('Invite unavailable. Please try again.');
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  Future<void> _shareInvite(
    BuildContext shareContext,
    InviteShareContent content,
  ) async {
    if (_sharing) return;
    final renderObject = shareContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      _showMessage('Invite unavailable. Please try again.');
      return;
    }
    final origin = renderObject.localToGlobal(Offset.zero) & renderObject.size;
    setState(() => _sharing = true);
    try {
      final action = widget.shareAction ?? _shareWithPlugin;
      await action(text: content.payload, sharePositionOrigin: origin);
    } catch (_) {
      _showMessage('Invite unavailable. Please try again.');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  static Future<void> _shareWithPlugin({
    required String text,
    required Rect sharePositionOrigin,
  }) async {
    await SharePlus.instance.share(
      ShareParams(text: text, sharePositionOrigin: sharePositionOrigin),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _content;
    final visibleCode = content?.visibleCode ?? 'Unavailable';
    final available = content != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              const Text('Invite code', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 10),
              Semantics(
                label: available
                    ? 'Invite code $visibleCode'
                    : 'Invite unavailable',
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    visibleCode,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                    ),
                  ),
                ),
              ),
              if (!available) ...[
                const SizedBox(height: 12),
                const Text(
                  'Invite unavailable. Please try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black87),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 55),
          child: FilledButton.icon(
            icon: const Icon(Icons.copy),
            label: Text(_copying ? 'Copying…' : 'Copy code'),
            onPressed: !available || _copying ? null : () => _copyCode(content),
          ),
        ),
        const SizedBox(height: 15),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 55),
          child: Builder(
            builder: (shareContext) => OutlinedButton.icon(
              icon: const Icon(Icons.share),
              label: Text(_sharing ? 'Opening…' : 'Share invite link'),
              onPressed: !available || _sharing
                  ? null
                  : () => _shareInvite(shareContext, content),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Anyone with this invite can join your private Gub.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54, height: 1.4),
        ),
      ],
    );
  }
}
