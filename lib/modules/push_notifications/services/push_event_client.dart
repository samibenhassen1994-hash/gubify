import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/push_event.dart';

const _pushEventsUrl = String.fromEnvironment('GUBIFY_PUSH_EVENTS_URL');
const _defaultRequestTimeout = Duration(seconds: 10);

typedef PushEventTokenProvider = Future<String?> Function();
typedef PushEventLogger = void Function(String message);

class PushEventClient {
  static final PushEventClient instance = PushEventClient();

  PushEventClient({
    PushEventTokenProvider? getIdToken,
    http.Client? httpClient,
    PushEventLogger? logger,
    Duration requestTimeout = _defaultRequestTimeout,
  }) : this._(
         getIdToken: getIdToken,
         httpClient: httpClient,
         logger: logger,
         endpoint: _pushEventsUrl,
         requestTimeout: requestTimeout,
       );

  @visibleForTesting
  PushEventClient.forTesting({
    required String endpoint,
    PushEventTokenProvider? getIdToken,
    http.Client? httpClient,
    PushEventLogger? logger,
    Duration requestTimeout = _defaultRequestTimeout,
  }) : this._(
         getIdToken: getIdToken,
         httpClient: httpClient,
         logger: logger,
         endpoint: endpoint,
         requestTimeout: requestTimeout,
       );

  PushEventClient._({
    required PushEventTokenProvider? getIdToken,
    required http.Client? httpClient,
    required PushEventLogger? logger,
    required this._endpoint,
    required this._requestTimeout,
  }) : _getIdToken = getIdToken ?? _defaultGetIdToken,
       _httpClient = httpClient ?? http.Client(),
       _logger = logger ?? debugPrint;

  final PushEventTokenProvider _getIdToken;
  final http.Client _httpClient;
  final PushEventLogger _logger;
  final String _endpoint;
  final Duration _requestTimeout;

  Future<void> submit(PushEvent event) async {
    if (_endpoint.isEmpty) return;

    String? idToken;
    try {
      idToken = await _getIdToken();
    } catch (_) {
      _safeLog('Push event delivery failed during authentication.');
      return;
    }

    if (idToken == null || idToken.isEmpty) {
      _safeLog('Push event delivery skipped: no authenticated user.');
      return;
    }

    try {
      final response = await _httpClient
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(event.toJson()),
          )
          .timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _safeLog('Push event delivery failed (HTTP ${response.statusCode}).');
      }
    } on TimeoutException {
      _safeLog('Push event delivery timed out.');
    } catch (_) {
      _safeLog('Push event delivery failed.');
    }
  }

  void _safeLog(String message) {
    try {
      _logger(message);
    } catch (_) {
      // Diagnostics must never change the domain action's outcome.
    }
  }

  static Future<String?> _defaultGetIdToken() =>
      FirebaseAuth.instance.currentUser?.getIdToken(true) ??
      Future<String?>.value();
}
