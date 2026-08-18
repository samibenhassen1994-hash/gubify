import 'community_slug.dart';

/// Produces the duplicate-detection registry key for Communities.
///
/// This key is intentionally different from the visible Community name and
/// from the URL slug. Whitespace is ignored only for duplicate detection, so
/// names such as "Test Prova" and "Te st Pro va" reserve the same key while
/// punctuation remains meaningful.
class CommunityNameKey {
  CommunityNameKey._();

  static String fromName(String name) {
    final normalized = CommunitySlug.removeAccents(name.trim().toLowerCase());
    return normalized
        .replaceAll(RegExp(r'\s+'), '')
        // A Firestore document ID cannot contain a slash. Keep it distinct
        // from punctuation such as a hyphen so this remains a name key.
        .replaceAll('/', '∕');
  }
}
