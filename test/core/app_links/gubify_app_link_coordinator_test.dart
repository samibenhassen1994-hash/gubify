import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/core/app_links/gubify_app_link_coordinator.dart';

void main() {
  test(
    'cold-start Community link waits through onboarding readiness',
    () async {
      final source = _FakeAppLinkSource();
      final opened = <String>[];
      final coordinator = GubifyAppLinkCoordinator(
        source: source,
        openInvite: (_) async {},
        openCommunity: (slug) async => opened.add(slug),
      )..start();

      source.add(Uri.parse('https://gubify.com/community/commgub'));
      await _flush();
      expect(opened, isEmpty);

      coordinator.markNavigationReady();
      await _flush();
      expect(opened, ['commgub']);

      coordinator.markNavigationReady();
      await _flush();
      expect(opened, ['commgub']);
      await coordinator.dispose();
    },
  );

  test(
    'foreground Private Gub invite keeps its existing visible code',
    () async {
      final source = _FakeAppLinkSource();
      final opened = <String>[];
      final coordinator = GubifyAppLinkCoordinator(
        source: source,
        openInvite: (code) async => opened.add(code),
        openCommunity: (_) async {},
      )..start();
      coordinator.markNavigationReady();

      source.add(Uri.parse('https://gubify.com/join/K7M4P9Q2'));
      await _flush();

      expect(opened, ['K7M4-P9Q2']);
      await coordinator.dispose();
    },
  );

  test('duplicate Community delivery cannot stack the active route', () async {
    final source = _FakeAppLinkSource();
    final routeClosed = Completer<void>();
    var calls = 0;
    final coordinator = GubifyAppLinkCoordinator(
      source: source,
      openInvite: (_) async {},
      openCommunity: (_) {
        calls++;
        return routeClosed.future;
      },
    )..start();
    coordinator.markNavigationReady();

    final uri = Uri.parse('https://gubify.com/community/commgub');
    source.add(uri);
    source.add(uri);
    await _flush();
    expect(calls, 1);

    routeClosed.complete();
    await _flush();
    expect(calls, 1);
    await coordinator.dispose();
  });

  test('a distinct link waits until active navigation completes', () async {
    final source = _FakeAppLinkSource();
    final routeClosed = Completer<void>();
    final opened = <String>[];
    final coordinator = GubifyAppLinkCoordinator(
      source: source,
      openInvite: (code) async => opened.add('join:$code'),
      openCommunity: (slug) {
        opened.add('community:$slug');
        return routeClosed.future;
      },
    )..start();
    coordinator.markNavigationReady();

    source.add(Uri.parse('https://gubify.com/community/commgub'));
    source.add(Uri.parse('https://gubify.com/join/R8T5-W3X6'));
    await _flush();
    expect(opened, ['community:commgub']);

    routeClosed.complete();
    await _flush();
    expect(opened, ['community:commgub', 'join:R8T5-W3X6']);
    await coordinator.dispose();
  });

  test('invalid links and callback errors do not stop later links', () async {
    final source = _FakeAppLinkSource();
    final opened = <String>[];
    final coordinator = GubifyAppLinkCoordinator(
      source: source,
      openInvite: (_) async => throw StateError('route failed'),
      openCommunity: (slug) async => opened.add(slug),
    )..start();
    coordinator.markNavigationReady();

    source.add(Uri.parse('https://example.com/community/commgub'));
    source.add(Uri.parse('https://gubify.com/join/K7M4-P9Q2'));
    await _flush();
    source.add(Uri.parse('https://gubify.com/community/commgub'));
    await _flush();

    expect(opened, ['commgub']);
    await coordinator.dispose();
  });

  test('start and dispose are idempotent', () async {
    final source = _FakeAppLinkSource();
    var calls = 0;
    final coordinator = GubifyAppLinkCoordinator(
      source: source,
      openInvite: (_) async => calls++,
      openCommunity: (_) async => calls++,
    );

    coordinator.start();
    coordinator.start();
    expect(source.listenCount, 1);

    await coordinator.dispose();
    await coordinator.dispose();
    expect(source.hasListener, isFalse);
    source.add(Uri.parse('https://gubify.com/community/commgub'));
    await _flush();
    expect(calls, 0);
  });
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

class _FakeAppLinkSource implements GubifyAppLinkSource {
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
