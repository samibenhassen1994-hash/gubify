import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityModel {
  static const String publicVisibility = "public";
  static const String defaultType = "General";
  static const String defaultLanguage = "Italian";

  static const List<String> availableTypes = [
    "General",
    "Friends",
    "Gaming",
    "Sport",
    "Music",
    "Study",
    "Travel",
    "Local",
    "Other",
  ];
  static const List<String> availableLanguages = [
    "Italian",
    "English",
    "Other",
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
      type: _normalizedOption(data["type"], availableTypes, defaultType),
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

  static String _normalizedOption(
    Object? value,
    List<String> availableValues,
    String fallback,
  ) {
    final normalized = value is String ? value.trim() : "";
    return availableValues.contains(normalized) ? normalized : fallback;
  }
}
