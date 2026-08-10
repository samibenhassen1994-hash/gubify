import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/core/membership/membership_history_boundary.dart';

void main() {
  final joinedAt = Timestamp.fromDate(DateTime.utc(2026, 8, 10, 9));
  final newerStart = Timestamp.fromDate(DateTime.utc(2026, 8, 10, 10));

  test('Private Gub boundary comes from the authoritative membership', () {
    final boundary = MembershipHistoryBoundary.fromAuthoritativeMembership(
      spaceId: 'gub-1',
      spaceType: MembershipSpaceType.privateGub,
      userId: 'user-1',
      membership: {'joinedAt': joinedAt},
    );

    expect(boundary.membershipStartedAt, joinedAt);
    expect(boundary.hasKnownStart, isTrue);
  });

  test('Community rejoin uses the current membership start', () {
    final firstMembership =
        MembershipHistoryBoundary.fromAuthoritativeMembership(
          spaceId: 'community-1',
          spaceType: MembershipSpaceType.community,
          userId: 'user-1',
          membership: {'joinedAt': joinedAt},
        );
    final rejoinedMembership =
        MembershipHistoryBoundary.fromAuthoritativeMembership(
          spaceId: 'community-1',
          spaceType: MembershipSpaceType.community,
          userId: 'user-1',
          membership: {'joinedAt': newerStart},
        );

    expect(firstMembership.membershipStartedAt, joinedAt);
    expect(rejoinedMembership.membershipStartedAt, newerStart);
  });

  test('a user copy cannot create a boundary without membership', () {
    const lookup = CommunityMembershipBoundaryLookup.notMember();

    expect(lookup.communityExists, isTrue);
    expect(lookup.isCurrentMember, isFalse);
    expect(lookup.boundary, isNull);
  });

  test('an existing Community non-member differs from a missing Community', () {
    const nonMember = CommunityMembershipBoundaryLookup.notMember();
    const missing = CommunityMembershipBoundaryLookup.notFound();

    expect(nonMember.communityExists, isTrue);
    expect(missing.communityExists, isFalse);
  });

  test('legacy membership without timestamps has no historical boundary', () {
    final boundary = MembershipHistoryBoundary.fromAuthoritativeMembership(
      spaceId: 'gub-1',
      spaceType: MembershipSpaceType.privateGub,
      userId: 'user-1',
      membership: const {'role': 'member'},
    );

    expect(boundary.membershipStartedAt, isNull);
    expect(boundary.hasKnownStart, isFalse);
  });

  test('a current membership boundary dominates an older read marker', () {
    final boundary = MembershipHistoryBoundary.fromAuthoritativeMembership(
      spaceId: 'gub-1',
      spaceType: MembershipSpaceType.privateGub,
      userId: 'user-1',
      membership: {'joinedAt': newerStart},
    );
    final olderRead = Timestamp.fromDate(DateTime.utc(2026, 8, 10, 8));
    final newerRead = Timestamp.fromDate(DateTime.utc(2026, 8, 10, 11));

    expect(boundary.effectiveReadStart(olderRead), newerStart);
    expect(boundary.effectiveReadStart(newerRead), newerRead);
  });
}
