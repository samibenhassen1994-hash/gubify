import 'invite_code.dart';

class ParsedInviteLink {
  final String canonicalCode;
  final String visibleCode;

  const ParsedInviteLink({
    required this.canonicalCode,
    required this.visibleCode,
  });
}

class InviteLinkParser {
  const InviteLinkParser._();

  static ParsedInviteLink? parse(Uri uri) {
    if (uri.scheme != 'https' ||
        uri.host != 'gubify.com' ||
        uri.hasPort ||
        uri.userInfo.isNotEmpty ||
        uri.pathSegments.length != 2 ||
        uri.pathSegments.first != 'join') {
      return null;
    }

    final segment = uri.pathSegments.last;
    try {
      final canonical = InviteCode.normalize(segment);
      final visible = InviteCode.format(canonical);
      final upperSegment = segment.toUpperCase();
      if (upperSegment != canonical && upperSegment != visible) return null;

      return ParsedInviteLink(canonicalCode: canonical, visibleCode: visible);
    } on InvalidInviteCodeException {
      return null;
    }
  }

  static ParsedInviteLink? tryParse(String value) {
    final uri = Uri.tryParse(value);
    return uri == null ? null : parse(uri);
  }
}
