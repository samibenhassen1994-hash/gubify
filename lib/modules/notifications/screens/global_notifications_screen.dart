import 'package:flutter/material.dart';

import '../../../widgets/gub_screen_background.dart';

class GlobalNotificationsScreen extends StatelessWidget {
  const GlobalNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GubScreenBackground(
      variant: GubBackgroundAssignments.profiles,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Notifications'),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: const SafeArea(
          top: false,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 52,
                    color: Color(0xFF64748B),
                  ),
                  SizedBox(height: 14),
                  Text(
                    'Your notifications will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Color(0xFF475569)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
