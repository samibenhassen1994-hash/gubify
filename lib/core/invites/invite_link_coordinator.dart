import 'dart:async';

import 'package:app_links/app_links.dart';

import 'invite_link_parser.dart';

abstract interface class InviteLinkSource {
  Stream<Uri> get uriLinks;
}

class AppLinksInviteLinkSource implements InviteLinkSource {
  final AppLinks _appLinks;

  AppLinksInviteLinkSource({AppLinks? appLinks})
    : _appLinks = appLinks ?? AppLinks();

  @override
  Stream<Uri> get uriLinks => _appLinks.uriLinkStream;
}

typedef OpenInviteJoin = Future<void> Function(String visibleCode);

class InviteLinkCoordinator {
  final InviteLinkSource source;
  final OpenInviteJoin openJoin;

  StreamSubscription<Uri>? _subscription;
  ParsedInviteLink? _pending;
  bool _navigationReady = false;
  bool _opening = false;
  bool _disposed = false;

  InviteLinkCoordinator({required this.source, required this.openJoin});

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
    final parsed = InviteLinkParser.parse(uri);
    if (parsed == null) return;
    if (_opening || _pending?.canonicalCode == parsed.canonicalCode) return;

    _pending = parsed;
    unawaited(_drain());
  }

  Future<void> _drain() async {
    if (_disposed || !_navigationReady || _opening || _pending == null) return;

    final invite = _pending!;
    _pending = null;
    _opening = true;
    try {
      await openJoin(invite.visibleCode);
    } catch (_) {
      // Link handling is best-effort and must never surface technical errors.
    } finally {
      _opening = false;
      if (!_disposed) unawaited(_drain());
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _pending = null;
    await _subscription?.cancel();
    _subscription = null;
  }
}
