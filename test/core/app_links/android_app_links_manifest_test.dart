import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android manifest verifies only Private Gub and Community paths', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:name="flutter_deeplinking_enabled"'));
    expect(manifest, contains('android:value="false"'));
    expect(manifest, contains('android:autoVerify="true"'));
    expect(manifest, contains('android:scheme="https"'));
    expect(manifest, contains('android:host="gubify.com"'));
    expect(manifest, contains('android:pathPrefix="/join/"'));
    expect(manifest, contains('android:pathPrefix="/community/"'));
    expect(manifest, isNot(contains('android:pathPrefix="/"')));
  });
}
