import 'community_slug.dart';

/// Produces the exact-name registry key for Communities.
///
/// Unlike a slug, spaces and punctuation remain meaningful: this is only used
/// to block the same displayed Community name after basic normalization.
class CommunityNameKey {
  CommunityNameKey._();

  static String fromName(String name) {
    final normalized = CommunitySlug.removeAccents(name.trim().toLowerCase());
    return normalized
        .replaceAll(RegExp(r'\s+'), ' ')
        // A Firestore document ID cannot contain a slash. Keep it distinct
        // from a space or hyphen so this remains a name key, not a slug.
        .replaceAll('/', '∕');
  }
}
