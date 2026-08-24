class PlatformRestriction {
  final bool communityChatRestricted;

  const PlatformRestriction({required this.communityChatRestricted});

  static const unrestricted = PlatformRestriction(
    communityChatRestricted: false,
  );

  factory PlatformRestriction.fromFirestore(Map<String, dynamic>? data) {
    return PlatformRestriction(
      communityChatRestricted: data?['communityChatRestricted'] == true,
    );
  }
}

class CommunityRestriction {
  final bool hiddenFromDiscovery;
  final bool joiningRestricted;

  const CommunityRestriction({
    required this.hiddenFromDiscovery,
    required this.joiningRestricted,
  });

  static const unrestricted = CommunityRestriction(
    hiddenFromDiscovery: false,
    joiningRestricted: false,
  );

  factory CommunityRestriction.fromFirestore(Map<String, dynamic>? data) {
    return CommunityRestriction(
      hiddenFromDiscovery: data?['hiddenFromDiscovery'] == true,
      joiningRestricted: data?['joiningRestricted'] == true,
    );
  }
}
