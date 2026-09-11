import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/legal/legal_links.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  test(
    'opens Privacy Policy in the in-app browser at its canonical URL',
    () async {
      final calls = <(Uri, LaunchMode)>[];

      final opened = await LegalLinks.openPrivacyPolicy(
        launcher: (uri, {required mode}) async {
          calls.add((uri, mode));
          return true;
        },
      );

      expect(opened, isTrue);
      expect(calls, [
        (Uri.parse('https://gubify.com/privacy'), LaunchMode.inAppBrowserView),
      ]);
    },
  );

  test('falls back to the external browser for Terms of Service', () async {
    final calls = <(Uri, LaunchMode)>[];

    final opened = await LegalLinks.openTermsOfService(
      launcher: (uri, {required mode}) async {
        calls.add((uri, mode));
        return mode == LaunchMode.externalApplication;
      },
    );

    expect(opened, isTrue);
    expect(calls, [
      (Uri.parse('https://gubify.com/terms'), LaunchMode.inAppBrowserView),
      (Uri.parse('https://gubify.com/terms'), LaunchMode.externalApplication),
    ]);
  });

  test('opens Support in the in-app browser at its canonical URL', () async {
    final calls = <(Uri, LaunchMode)>[];

    final opened = await LegalLinks.openSupport(
      launcher: (uri, {required mode}) async {
        calls.add((uri, mode));
        return true;
      },
    );

    expect(opened, isTrue);
    expect(calls, [
      (Uri.parse('https://gubify.com/support'), LaunchMode.inAppBrowserView),
    ]);
  });

  test('falls back to the external browser for Report a bug', () async {
    final calls = <(Uri, LaunchMode)>[];

    final opened = await LegalLinks.openBugReport(
      launcher: (uri, {required mode}) async {
        calls.add((uri, mode));
        return mode == LaunchMode.externalApplication;
      },
    );

    expect(opened, isTrue);
    expect(calls, [
      (
        Uri.parse('https://gubify.com/feedback?type=bug'),
        LaunchMode.inAppBrowserView,
      ),
      (
        Uri.parse('https://gubify.com/feedback?type=bug'),
        LaunchMode.externalApplication,
      ),
    ]);
  });
}
