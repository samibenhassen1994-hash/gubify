/// Produces stable, URL-safe Community slug bases from user-facing names.
class CommunitySlug {
  CommunitySlug._();

  static const int maxLength = 60;

  static String fromName(String name) {
    final normalized = _removeAccents(name.trim().toLowerCase());
    final separated = normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final collapsed = separated
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final base = collapsed.isEmpty ? 'community' : collapsed;
    return base.length <= maxLength ? base : base.substring(0, maxLength);
  }

  static String withSuffix(String base, int sequence) {
    if (sequence <= 1) return base;
    final suffix = '-$sequence';
    final availableLength = maxLength - suffix.length;
    final truncatedBase = base.length <= availableLength
        ? base
        : base.substring(0, availableLength).replaceFirst(RegExp(r'-+$'), '');
    return '${truncatedBase.isEmpty ? 'community' : truncatedBase}$suffix';
  }

  static String _removeAccents(String value) {
    const replacements = {
      'à': 'a',
      'á': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'å': 'a',
      'æ': 'ae',
      'ç': 'c',
      'è': 'e',
      'é': 'e',
      'ê': 'e',
      'ë': 'e',
      'ì': 'i',
      'í': 'i',
      'î': 'i',
      'ï': 'i',
      'ñ': 'n',
      'ò': 'o',
      'ó': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'ø': 'o',
      'œ': 'oe',
      'ß': 'ss',
      'ù': 'u',
      'ú': 'u',
      'û': 'u',
      'ü': 'u',
      'ý': 'y',
      'ÿ': 'y',
    };
    return value
        .split('')
        .map((character) => replacements[character] ?? character)
        .join();
  }
}
