import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityModel {
  static const String publicVisibility = "public";
  static const String defaultType = "General";
  static const String defaultLanguage = "English";

  /// Options available when creating or filtering communities.
  static const List<String> availableTypes = [
    "General",
    "Gaming",
    "Sport",
    "Music",
    "Study",
    "Travel",
    "Show",
    "Work",
    "Social",
    "Events",
    "Hobbies & Interests",
    "Technology",
    "Art & Creativity",
    "Movies & TV",
    "Books & Reading",
    "Food & Cooking",
    "Fitness & Wellness",
    "Other",
  ];

  /// Kept only so existing documents remain readable in the Explorer.
  static const List<String> _legacyTypes = ["Friends", "Local"];

  static const List<String> availableLanguages = [
    "English",
    "Mandarin Chinese",
    "Hindi",
    "Spanish",
    "French",
    "Arabic",
    "Bengali",
    "Portuguese",
    "Russian",
    "Urdu",
    "Indonesian",
    "German",
    "Japanese",
    "Italian",
    "Turkish",
    "Korean",
  ];

  final String communityId;
  final String name;
  final String ownerId;
  final int memberCount;
  final String visibility;
  final Timestamp? createdAt;
  final String type;
  final String language;
  final String description;

  const CommunityModel({
    required this.communityId,
    required this.name,
    required this.ownerId,
    required this.memberCount,
    required this.visibility,
    required this.createdAt,
    required this.type,
    required this.language,
    required this.description,
  });

  factory CommunityModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final storedCommunityId = data["communityId"];

    return CommunityModel(
      communityId:
          storedCommunityId is String && storedCommunityId.trim().isNotEmpty
          ? storedCommunityId.trim()
          : document.id,
      name: data["name"] as String? ?? "",
      ownerId: data["ownerId"] as String? ?? "",
      memberCount: (data["memberCount"] as num?)?.toInt() ?? 0,
      visibility:
          data["visibility"] as String? ?? CommunityModel.publicVisibility,
      createdAt: data["createdAt"] as Timestamp?,
      type: _normalizedStoredType(data["type"]),
      language: _normalizedOption(
        data["language"],
        availableLanguages,
        defaultLanguage,
      ),
      description: (data["description"] as String? ?? "").trim(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      "communityId": communityId,
      "name": name,
      "ownerId": ownerId,
      "memberCount": memberCount,
      "visibility": visibility,
      "createdAt": createdAt,
      "type": type,
      "language": language,
      "description": description,
    };
  }

  CommunityModel copyWith({int? memberCount}) {
    return CommunityModel(
      communityId: communityId,
      name: name,
      ownerId: ownerId,
      memberCount: memberCount ?? this.memberCount,
      visibility: visibility,
      createdAt: createdAt,
      type: type,
      language: language,
      description: description,
    );
  }

  static String normalizeType(String? value) =>
      _normalizedOption(value, availableTypes, defaultType);

  static String normalizeLanguage(String? value) =>
      _normalizedOption(value, availableLanguages, defaultLanguage);

  static String _normalizedStoredType(Object? value) {
    final normalized = value is String ? value.trim() : "";
    return availableTypes.contains(normalized) ||
            _legacyTypes.contains(normalized)
        ? normalized
        : defaultType;
  }

  static String _normalizedOption(
    Object? value,
    List<String> availableValues,
    String fallback,
  ) {
    final normalized = value is String ? value.trim() : "";
    return availableValues.contains(normalized) ? normalized : fallback;
  }
}

class CommunityMembershipModel {
  final CommunityModel community;
  final String role;
  final Timestamp? joinedAt;

  const CommunityMembershipModel({
    required this.community,
    required this.role,
    required this.joinedAt,
  });

  DateTime? get joinedAtDate => joinedAt?.toDate();
}
