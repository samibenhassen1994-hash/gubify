import 'package:flutter/material.dart';

import 'gub_content_card.dart';

enum MembershipWindow { privateGubs, communities }

class MembershipWindowSelector extends StatelessWidget {
  final MembershipWindow selectedWindow;
  final int? privateCount;
  final int? communityCount;
  final ValueChanged<MembershipWindow> onSelected;

  const MembershipWindowSelector({
    super.key,
    required this.selectedWindow,
    required this.privateCount,
    required this.communityCount,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GubContentCard(
      padding: const EdgeInsets.all(5),
      child: Row(
        children: [
          Expanded(
            child: _MembershipWindowButton(
              label: privateCount == null
                  ? 'Private Gubs'
                  : 'Private Gubs ($privateCount)',
              selected: selectedWindow == MembershipWindow.privateGubs,
              onTap: () => onSelected(MembershipWindow.privateGubs),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _MembershipWindowButton(
              label: communityCount == null
                  ? 'Communities'
                  : 'Communities ($communityCount)',
              selected: selectedWindow == MembershipWindow.communities,
              onTap: () => onSelected(MembershipWindow.communities),
            ),
          ),
        ],
      ),
    );
  }
}

class _MembershipWindowButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MembershipWindowButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF2563EB) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF334155),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
