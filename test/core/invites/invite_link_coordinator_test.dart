import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/core/invites/invite_link_coordinator.dart';

void main() {
  test('cold-start link waits for onboarding and opens exactly once', () async {
    final source = _FakeInviteLinkSource();
    final opened = <String>[];
    final coordinator = InviteLinkCoordinator(
      source: source,
      openJoin: (code) async => opened.add(code),
    )..start();

    source.add(Uri.parse('https://gubify.com/join/K7M4P9Q2'));
    await _flush();
    expect(opened, isEmpty);

    coordinator.markNavigationReady();
    await _flush();
    expect(opened, ['K7M4-P9Q2']);

    coordinator.markNavigationReady();
    await _flush();
    expect(opened, ['K7M4-P9Q2']);
    await coordinator.dispose();
  });

  test('foreground link opens after navigation is ready', () async {
    final source = _FakeInviteLinkSource();
    final opened = <String>[];
    final coordinator = InviteLinkCoordinator(
      source: source,
      openJoin: (code) async => opened.add(code),
    )..start();
    coordinator.markNavigationReady();

    source.add(Uri.parse('https://gubify.com/join/R8T5-W3X6'));
    await _flush();

    expect(opened, ['R8T5-W3X6']);
    await coordinator.dispose();
  });

  test('duplicate event while Join is open does not stack a route', () async {
    final source = _FakeInviteLinkSource();
    final routeClosed = Completer<void>();
    var calls = 0;
    final coordinator = InviteLinkCoordinator(
      source: source,
      openJoin: (_) {
        calls++;
        return routeClosed.future;
      },
    )..start();
    coordinator.markNavigationReady();

    final uri = Uri.parse('https://gubify.com/join/K7M4-P9Q2');
    source.add(uri);
    source.add(uri);
    await _flush();
    expect(calls, 1);

    routeClosed.complete();
    await _flush();
    expect(calls, 1);
    await coordinator.dispose();
  });

  test('invalid links are ignored without opening Join', () async {
    final source = _FakeInviteLinkSource();
    var calls = 0;
    final coordinator = InviteLinkCoordinator(
      source: source,
      openJoin: (_) async => calls++,
    )..start();
    coordinator.markNavigationReady();

    source.add(Uri.parse('https://example.com/join/K7M4-P9Q2'));
    await _flush();

    expect(calls, 0);
    await coordinator.dispose();
  });

  test('dispose closes the listener and prevents later callbacks', () async {
    final source = _FakeInviteLinkSource();
    var calls = 0;
    final coordinator = InviteLinkCoordinator(
      source: source,
      openJoin: (_) async => calls++,
    )..start();
    coordinator.markNavigationReady();
    expect(source.hasListener, isTrue);

    await coordinator.dispose();
    expect(source.hasListener, isFalse);
    source.add(Uri.parse('https://gubify.com/join/K7M4-P9Q2'));
    await _flush();

    expect(calls, 0);
  });

  test('an in-flight navigation cannot trigger work after dispose', () async {
    final source = _FakeInviteLinkSource();
    final routeClosed = Completer<void>();
    var calls = 0;
    final coordinator = InviteLinkCoordinator(
      source: source,
      openJoin: (_) {
        calls++;
        return routeClosed.future;
      },
    )..start();
    coordinator.markNavigationReady();

    source.add(Uri.parse('https://gubify.com/join/K7M4-P9Q2'));
    await _flush();
    expect(calls, 1);

    await coordinator.dispose();
    source.add(Uri.parse('https://gubify.com/join/R8T5-W3X6'));
    routeClosed.complete();
    await _flush();
    expect(calls, 1);
  });

  test('start is idempotent and registers one listener', () async {
    final source = _FakeInviteLinkSource();
    final coordinator = InviteLinkCoordinator(
      source: source,
      openJoin: (_) async {},
    );

    coordinator.start();
    coordinator.start();
    expect(source.listenCount, 1);
    await coordinator.dispose();
  });
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

class _FakeInviteLinkSource implements InviteLinkSource {
  final StreamController<Uri> _controller = StreamController<Uri>.broadcast();
  int listenCount = 0;

  @override
  Stream<Uri> get uriLinks {
    listenCount++;
    return _controller.stream;
  }

  bool get hasListener => _controller.hasListener;

  void add(Uri uri) => _controller.add(uri);
}
