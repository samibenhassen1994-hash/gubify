import 'package:flutter/material.dart';

import '../../../services/board_read_service.dart';
import '../board_screen.dart';

class GubBoardButton extends StatefulWidget {
  final String gubId;

  const GubBoardButton({super.key, required this.gubId});

  @override
  State<GubBoardButton> createState() => _GubBoardButtonState();
}

class _GubBoardButtonState extends State<GubBoardButton> {
  late Stream<int> _unreadCountStream;

  @override
  void initState() {
    super.initState();
    _unreadCountStream = BoardReadService.instance.unreadCountStream(
      widget.gubId,
    );
  }

  @override
  void didUpdateWidget(covariant GubBoardButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gubId != widget.gubId) {
      _unreadCountStream = BoardReadService.instance.unreadCountStream(
        widget.gubId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _unreadCountStream,
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;
        final badgeLabel = unreadCount > 99 ? '99+' : '$unreadCount';

        return SizedBox(
          width: 54,
          height: 54,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Semantics(
                button: true,
                label: unreadCount == 0
                    ? 'Open Board'
                    : 'Open Board, $badgeLabel new posts',
                child: Material(
                  color: Colors.white.withValues(alpha: 0.92),
                  shape: const CircleBorder(),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFEA580C).withValues(alpha: 0.45),
                      ),
                    ),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BoardScreen(gubId: widget.gubId),
                          ),
                        );
                      },
                      child: const SizedBox(
                        width: 42,
                        height: 42,
                        child: Icon(
                          Icons.campaign_rounded,
                          color: Color(0xFFEA580C),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: 2,
                  right: 2,
                  child: ExcludeSemantics(
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        border: Border.all(color: Colors.white, width: 1.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badgeLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
