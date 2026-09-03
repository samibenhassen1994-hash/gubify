import 'package:flutter/material.dart';

class CommunityAskExpandableSection extends StatelessWidget {
  const CommunityAskExpandableSection({
    super.key,
    this.tileKey,
    required this.title,
    required this.children,
    this.onExpansionChanged,
  });

  final Key? tileKey;
  final Widget title;
  final List<Widget> children;
  final ValueChanged<bool>? onExpansionChanged;

  static const _borderlessShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    side: BorderSide.none,
  );

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      key: tileKey,
      shape: _borderlessShape,
      collapsedShape: _borderlessShape,
      minTileHeight: 48,
      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 2),
      title: title,
      onExpansionChanged: onExpansionChanged,
      children: children,
    ),
  );
}
