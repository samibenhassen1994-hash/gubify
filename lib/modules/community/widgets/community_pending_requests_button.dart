import 'package:flutter/material.dart';

class CommunityPendingRequestsButton extends StatelessWidget {
  final Stream<int> countStream;
  final VoidCallback onPressed;
  final bool isVisible;

  const CommunityPendingRequestsButton({
    super.key,
    required this.countStream,
    required this.onPressed,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();
    return StreamBuilder<int>(
      stream: countStream,
      builder: (context, snapshot) {
        final count = snapshot.hasError ? 0 : snapshot.data ?? 0;
        return Semantics(
          button: true,
          label: count > 0 ? 'Join requests, $count pending' : 'Join requests',
          child: Badge(
            isLabelVisible: count > 0,
            label: Text(count > 99 ? '99+' : '$count'),
            child: Material(
              color: Colors.white.withValues(alpha: 0.84),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPressed,
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(
                    Icons.how_to_reg_rounded,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
