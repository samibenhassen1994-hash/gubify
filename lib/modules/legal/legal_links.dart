import 'package:url_launcher/url_launcher.dart';

typedef LegalUrlLauncher =
    Future<bool> Function(Uri uri, {required LaunchMode mode});

abstract final class LegalLinks {
  static final privacyPolicyUri = Uri.parse('https://gubify.com/privacy');
  static final termsOfServiceUri = Uri.parse('https://gubify.com/terms');

  static Future<bool> openPrivacyPolicy({LegalUrlLauncher? launcher}) {
    return _open(privacyPolicyUri, launcher: launcher);
  }

  static Future<bool> openTermsOfService({LegalUrlLauncher? launcher}) {
    return _open(termsOfServiceUri, launcher: launcher);
  }

  static Future<bool> _open(Uri uri, {LegalUrlLauncher? launcher}) async {
    final open = launcher ?? _launchUrl;
    try {
      if (await open(uri, mode: LaunchMode.inAppBrowserView)) return true;
    } catch (_) {}
    try {
      return await open(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _launchUrl(Uri uri, {required LaunchMode mode}) {
    return launchUrl(uri, mode: mode);
  }
}
