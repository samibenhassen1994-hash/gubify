import '../invites/invite_link_parser.dart';
import 'gubify_app_link.dart';

class GubifyAppLinkParser {
  const GubifyAppLinkParser._();

  static final RegExp _communitySlugPattern = RegExp(
    r'^[a-z0-9]+(?:-[a-z0-9]+)*$',
  );

  static GubifyAppLink? parse(Uri uri) {
    final invite = InviteLinkParser.parse(uri);
    if (invite != null) {
      return PrivateGubInviteLink(
        canonicalCode: invite.canonicalCode,
        visibleCode: invite.visibleCode,
      );
    }

    if (uri.scheme != 'https' ||
        uri.host != 'gubify.com' ||
        uri.hasPort ||
        uri.userInfo.isNotEmpty ||
        uri.pathSegments.length != 2 ||
        uri.pathSegments.first != 'community') {
      return null;
    }

    final slug = uri.pathSegments.last;
    if (slug.length > 60 || !_communitySlugPattern.hasMatch(slug)) return null;

    return CommunityAppLink(slug: slug);
  }
}
