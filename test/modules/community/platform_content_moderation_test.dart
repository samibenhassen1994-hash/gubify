import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/admin/platform_admin_service.dart';
import 'package:gubify/modules/community/admin/platform_content_screen.dart';
import 'package:gubify/modules/community/admin/platform_moderation_model.dart';
import 'package:gubify/modules/community/admin/platform_moderation_repository.dart';
import 'package:gubify/modules/community/admin/platform_moderation_service.dart';

class MemoryContent extends PlatformModerationRepository {
  bool hidden = false;
  final updates = StreamController<List<PlatformModerationItem>>.broadcast();
  List<PlatformModerationItem> get items => [
    PlatformModerationItem(
      id: 'answer',
      text: 'Original answer',
      author: 'Member',
      hidden: hidden,
    ),
  ];
  @override
  Stream<List<PlatformModerationItem>> content(
    String communityId,
    PlatformContentKind kind,
    String? askId,
    int limit,
  ) async* {
    yield items;
    yield* updates.stream;
  }

  @override
  Future<void> setHidden({
    required String communityId,
    required PlatformContentKind kind,
    String? askId,
    required String itemId,
    required bool hidden,
    required String actorId,
  }) async {
    this.hidden = hidden;
    updates.add(items);
  }
}

void main() {
  testWidgets(
    'moderator confirms hide and unhide; revocation blocks subsequent mutation',
    (tester) async {
      final active = StreamController<bool>();
      final identities = StreamController<PlatformAdminIdentity?>();
      final role = PlatformAdminService(
        identities: identities.stream,
        watchActive: (_) => active.stream,
      );
      final repository = MemoryContent();
      final service = PlatformModerationService(
        role: role,
        repository: repository,
      );
      identities.add(
        const PlatformAdminIdentity(uid: 'admin', isAnonymous: false),
      );
      await tester.pump();
      active.add(true);
      await tester.pump();
      await tester.pumpWidget(
        MaterialApp(
          home: PlatformContentScreen(
            communityId: 'c',
            kind: PlatformContentKind.answers,
            askId: 'ask',
            bestAnswerId: 'answer',
            role: role,
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Best Answer'), findsOneWidget);
      await tester.tap(find.text('Hide'));
      await tester.pumpAndSettle();
      expect(repository.hidden, false);
      await tester.tap(find.widgetWithText(FilledButton, 'Hide'));
      await tester.pumpAndSettle();
      expect(repository.hidden, true);
      expect(find.text('Removed by moderation'), findsOneWidget);
      expect(find.text('Original answer'), findsOneWidget);
      await tester.tap(find.text('Unhide'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Unhide'));
      await tester.pumpAndSettle();
      expect(repository.hidden, false);
      active.add(false);
      await tester.pump();
      await expectLater(
        service.setHidden(
          communityId: 'c',
          kind: PlatformContentKind.answers,
          askId: 'ask',
          itemId: 'answer',
          hidden: true,
        ),
        throwsStateError,
      );
      expect(repository.hidden, false);
      await tester.pumpWidget(const SizedBox.shrink());
      role.dispose();
      await active.close();
      await identities.close();
      await repository.updates.close();
    },
  );
}
