import 'invite_code.dart';

class InviteShareContent {
  final String visibleCode;
  final Uri url;
  final String payload;

  const InviteShareContent._({
    required this.visibleCode,
    required this.url,
    required this.payload,
  });

  factory InviteShareContent.build({
    required String gubName,
    required String canonicalCode,
  }) {
    if (gubName.trim().isEmpty) {
      throw const InvalidInviteCodeException();
    }
    final visibleCode = InviteCode.format(canonicalCode);
    final url = Uri.https('gubify.com', '/join/$visibleCode');
    return InviteShareContent._(
      visibleCode: visibleCode,
      url: url,
      payload:
          'Join my Gub “$gubName” on Gubify.\n\n'
          'Invite code: $visibleCode\n'
          '$url\n\n'
          'Download Gubify on Google Play:\n'
          'https://play.google.com/store/apps/details?id=com.gubify.app',
    );
  }
}
