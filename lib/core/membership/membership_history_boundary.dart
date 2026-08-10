import 'package:cloud_firestore/cloud_firestore.dart';

/// Identifies the authoritative start of a user's current membership period.
///
/// A missing timestamp is deliberately represented as [null]. Consumers that
/// filter historical data must treat it as "no historical access" rather than
/// falling back to an unbounded date for legacy memberships.
enum MembershipSpaceType { privateGub, community }

class MembershipHistoryBoundary {
  final String spaceId;
  final MembershipSpaceType spaceType;
  final String userId;
  final Timestamp? membershipStartedAt;

  const MembershipHistoryBoundary({
    required this.spaceId,
    required this.spaceType,
    required this.userId,
    required this.membershipStartedAt,
  });

  bool get hasKnownStart => membershipStartedAt != null;

  /// Prevents a persisted read marker from widening the current membership
  /// history window after a member leaves and later rejoins.
  Timestamp effectiveReadStart(Timestamp? lastReadAt) {
    final start = membershipStartedAt;
    if (start == null) {
      throw StateError('A membership history boundary is required.');
    }
    if (lastReadAt == null || _isAfter(start, lastReadAt)) return start;
    return lastReadAt;
  }

  factory MembershipHistoryBoundary.fromAuthoritativeMembership({
    required String spaceId,
    required MembershipSpaceType spaceType,
    required String userId,
    required Map<String, dynamic> membership,
  }) {
    return MembershipHistoryBoundary(
      spaceId: spaceId,
      spaceType: spaceType,
      userId: userId,
      membershipStartedAt:
          _timestamp(membership['membershipStartedAt']) ??
          _timestamp(membership['joinedAt']) ??
          _timestamp(membership['createdAt']),
    );
  }

  static Timestamp? _timestamp(Object? value) =>
      value is Timestamp ? value : null;

  static bool _isAfter(Timestamp first, Timestamp second) =>
      first.seconds > second.seconds ||
      (first.seconds == second.seconds &&
          first.nanoseconds > second.nanoseconds);
}

/// Keeps a public Community that exists distinct from a Community membership.
/// This prevents callers from treating a non-member as if the Community itself
/// had disappeared.
class CommunityMembershipBoundaryLookup {
  final bool communityExists;
  final MembershipHistoryBoundary? boundary;

  const CommunityMembershipBoundaryLookup._({
    required this.communityExists,
    required this.boundary,
  });

  const CommunityMembershipBoundaryLookup.notFound()
    : this._(communityExists: false, boundary: null);

  const CommunityMembershipBoundaryLookup.notMember()
    : this._(communityExists: true, boundary: null);

  const CommunityMembershipBoundaryLookup.member(
    MembershipHistoryBoundary boundary,
  ) : this._(communityExists: true, boundary: boundary);

  bool get isCurrentMember => boundary != null;
}
