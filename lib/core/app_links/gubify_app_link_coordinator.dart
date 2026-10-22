import 'dart:async';

import 'package:app_links/app_links.dart';

import 'gubify_app_link.dart';
import 'gubify_app_link_parser.dart';

abstract interface class GubifyAppLinkSource {
  Stream<Uri> get uriLinks;
}

class AppLinksGubifyAppLinkSource implements GubifyAppLinkSource {
  final AppLinks _appLinks;

  AppLinksGubifyAppLinkSource({AppLinks? appLinks})
    : _appLinks = appLinks ?? AppLinks();

  @override
  Stream<Uri> get uriLinks => _appLinks.uriLinkStream;
}

typedef OpenPrivateGubInvite = Future<void> Function(String visibleCode);
typedef OpenCommunityAppLink = Future<void> Function(String slug);

class GubifyAppLinkCoordinator {
  final GubifyAppLinkSource source;
  final OpenPrivateGubInvite openInvite;
  final OpenCommunityAppLink openCommunity;

  StreamSubscription<Uri>? _subscription;
  GubifyAppLink? _pending;
  String? _activeKey;
  bool _navigationReady = false;
  bool _opening = false;
  bool _disposed = false;

  GubifyAppLinkCoordinator({
    required this.source,
    required this.openInvite,
    required this.openCommunity,
  });

  void start() {
    if (_disposed || _subscription != null) return;
    _subscription = source.uriLinks.listen(_receive, onError: (_) {});
  }

  void markNavigationReady() {
    if (_disposed) return;
    _navigationReady = true;
    unawaited(_drain());
  }

  void _receive(Uri uri) {
    if (_disposed) return;
    final parsed = GubifyAppLinkParser.parse(uri);
    if (parsed == null ||
        parsed.deduplicationKey == _activeKey ||
        parsed.deduplicationKey == _pending?.deduplicationKey) {
      return;
    }

    _pending = parsed;
    unawaited(_drain());
  }

  Future<void> _drain() async {
    if (_disposed || !_navigationReady || _opening || _pending == null) return;

    final destination = _pending!;
    _pending = null;
    _opening = true;
    _activeKey = destination.deduplicationKey;
    try {
      switch (destination) {
        case PrivateGubInviteLink(:final visibleCode):
          await openInvite(visibleCode);
        case CommunityAppLink(:final slug):
          await openCommunity(slug);
      }
    } catch (_) {
      // App Links are best-effort and must never break startup/navigation.
    } finally {
      _opening = false;
      _activeKey = null;
      if (!_disposed) unawaited(_drain());
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _pending = null;
    _activeKey = null;
    await _subscription?.cancel();
    _subscription = null;
  }
}
