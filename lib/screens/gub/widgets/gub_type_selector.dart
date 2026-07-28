import 'package:flutter/material.dart';

enum GubType { private, community }

class GubTypeSelector extends StatelessWidget {
  static const String privateAssetPath =
      "assets/images/private_gub_explanation.png";
  static const String communityAssetPath =
      "assets/images/community_gub_explanation.png";

  final GubType selectedType;
  final ValueChanged<GubType> onChanged;
  final bool enabled;

  const GubTypeSelector({
    super.key,
    required this.selectedType,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isPrivate = selectedType == GubType.private;
    final assetPath = isPrivate ? privateAssetPath : communityAssetPath;
    final semanticLabel = isPrivate
        ? "Private Gub: a private space for invited members."
        : "Community: a shared space designed for a wider community.";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: Semantics(
            key: ValueKey(selectedType),
            image: true,
            label: semanticLabel,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 1.2,
                child: Image.asset(
                  assetPath,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.high,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        SegmentedButton<GubType>(
          segments: const [
            ButtonSegment(
              value: GubType.private,
              icon: Icon(Icons.lock_outline, size: 20),
              label: Text("Private", style: TextStyle(fontSize: 13)),
            ),
            ButtonSegment(
              value: GubType.community,
              icon: Icon(Icons.groups_outlined, size: 20),
              label: Text("Community", style: TextStyle(fontSize: 13)),
            ),
          ],
          selected: {selectedType},
          onSelectionChanged: enabled
              ? (selection) => onChanged(selection.first)
              : null,
          showSelectedIcon: false,
          expandedInsets: EdgeInsets.zero,
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? Colors.white
                  : const Color(0xFF2563EB),
            ),
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? const Color(0xFF2563EB)
                  : Colors.white,
            ),
            side: const WidgetStatePropertyAll(
              BorderSide(color: Color(0xFF93C5FD)),
            ),
          ),
        ),
      ],
    );
  }
}
