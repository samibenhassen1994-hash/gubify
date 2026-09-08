import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/screens/gub/members_screen.dart';

void main() {
  testWidgets('tapping a private Gub member avatar opens that profile', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GubMemberAvatar(
            gubId: 'gub-1',
            userId: 'member-1',
            profileScreenBuilder: (gubId, userId) =>
                _ProfileDestination(gubId: gubId, userId: userId),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('gub-member-avatar-member-1')));
    await tester.pumpAndSettle();

    expect(find.text('gub-1/member-1'), findsOneWidget);
  });
}

class _ProfileDestination extends StatelessWidget {
  const _ProfileDestination({required this.gubId, required this.userId});

  final String gubId;
  final String userId;

  @override
  Widget build(BuildContext context) => Scaffold(body: Text('$gubId/$userId'));
}
