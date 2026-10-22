import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/core/app_links/community_app_link_handler.dart';
import 'package:gubify/modules/community/repositories/community_repository.dart';

void main() {
  group('Community App Link projection resolution', () {
    test('returns the Community ID for a matching public projection', () {
      expect(
        CommunityRepository.publicCommunityIdFromData(
          requestedSlug: 'commgub',
          data: const {'slug': 'commgub', 'communityId': 'community-123'},
        ),
        'community-123',
      );
    });

    test('rejects absent and malformed public projections', () {
      expect(
        CommunityRepository.publicCommunityIdFromData(
          requestedSlug: 'commgub',
          data: null,
        ),
        isNull,
      );
      expect(
        CommunityRepository.publicCommunityIdFromData(
          requestedSlug: 'commgub',
          data: const {'slug': 'commgub', 'communityId': ''},
        ),
        isNull,
      );
      expect(
        CommunityRepository.publicCommunityIdFromData(
          requestedSlug: 'commgub',
          data: const {'slug': 'different', 'communityId': 'community-123'},
        ),
        isNull,
      );
    });
  });

  group('CommunityAppLinkHandler', () {
    test('opens exactly the Community ID returned for the slug', () async {
      final opened = <String>[];
      var unavailableCalls = 0;
      final handler = CommunityAppLinkHandler(
        resolveCommunityId: (slug) async {
          expect(slug, 'commgub');
          return 'community-123';
        },
        openCommunity: (communityId) async => opened.add(communityId),
        showUnavailable: () async => unavailableCalls++,
      );

      await handler.open('commgub');

      expect(opened, ['community-123']);
      expect(unavailableCalls, 0);
    });

    test(
      'shows unavailable without opening when projection is absent',
      () async {
        final opened = <String>[];
        var unavailableCalls = 0;
        final handler = CommunityAppLinkHandler(
          resolveCommunityId: (_) async => null,
          openCommunity: (communityId) async => opened.add(communityId),
          showUnavailable: () async => unavailableCalls++,
        );

        await handler.open('missing-community');

        expect(opened, isEmpty);
        expect(unavailableCalls, 1);
      },
    );
  });
}
