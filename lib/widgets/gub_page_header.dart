import 'package:flutter/material.dart';

import 'user_header.dart';
import '../screens/welcome_screen.dart';

class GubPageHeader extends StatelessWidget {
  final String title;
  final String? gubId;
  final bool personalProfileEnabled;
  final bool userHeaderInCard;

  const GubPageHeader({
    super.key,
    required this.title,
    this.gubId,
    this.personalProfileEnabled = false,
    this.userHeaderInCard = false,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 22,
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WelcomeScreen(),
                        ),
                      );
                    }
                  },
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 20,
                    color: Color(0xFF1E293B),
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            UserHeader(
              gubId: gubId,
              personalProfileEnabled: personalProfileEnabled,
              showCard: userHeaderInCard,
            ),
          ],
        ),
      ),
    );
  }
}
