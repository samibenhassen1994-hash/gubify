import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppSound {
  messageSent,
  chatOpen,
  notification,
  created,
  completed,
  joined,
}

class AppSoundService {
  AppSoundService._() {
    _loadFuture = _loadPreference();
  }

  static final AppSoundService instance = AppSoundService._();

  static const String _enabledPreferenceKey = 'appSoundsEnabled';

  static const Map<AppSound, String> _assetPaths = {
    AppSound.messageSent: 'sounds/message_sent.wav',
    AppSound.chatOpen: 'sounds/chat_open.wav',
    AppSound.notification: 'sounds/notification.wav',
    AppSound.created: 'sounds/created.wav',
    AppSound.completed: 'sounds/completed.wav',
    AppSound.joined: 'sounds/joined.wav',
  };

  final ValueNotifier<bool> _enabled = ValueNotifier<bool>(true);
  final Map<AppSound, AudioPlayer> _players = {
    for (final sound in AppSound.values) sound: AudioPlayer(),
  };
  final Map<String, Set<String>> _knownUnreadNotificationIdsByGub = {};

  late final Future<void> _loadFuture;

  ValueListenable<bool> get enabledListenable => _enabled;

  bool get isEnabled => _enabled.value;

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled.value = prefs.getBool(_enabledPreferenceKey) ?? true;
    } catch (error) {
      debugPrint('Unable to load app sound preference: $error');
    }
  }

  Future<void> setEnabled(bool enabled) async {
    await _loadFuture;

    if (_enabled.value == enabled) return;
    _enabled.value = enabled;

    if (!enabled) {
      await Future.wait(
        _players.values.map((player) async {
          try {
            await player.stop();
          } catch (_) {
            // Sound preferences must never interrupt the user's action.
          }
        }),
      );
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledPreferenceKey, enabled);
    } catch (error) {
      debugPrint('Unable to save app sound preference: $error');
    }
  }

  void handleUnreadNotifications({
    required String gubId,
    required Iterable<String> unreadIds,
  }) {
    final normalizedGubId = gubId.trim();
    if (normalizedGubId.isEmpty) return;

    final currentIds = unreadIds.toSet();
    final previousIds = _knownUnreadNotificationIdsByGub[normalizedGubId];
    _knownUnreadNotificationIdsByGub[normalizedGubId] = currentIds;

    // The first snapshot establishes a baseline. Existing notifications must
    // not all make a sound when a Gub screen is opened.
    if (previousIds == null) return;

    if (currentIds.difference(previousIds).isNotEmpty) {
      unawaited(playNotification());
    }
  }

  Future<void> playMessageSent() => _play(AppSound.messageSent);

  Future<void> playChatOpen() => _play(AppSound.chatOpen);

  Future<void> playNotification() => _play(AppSound.notification);

  Future<void> playCreated() => _play(AppSound.created);

  Future<void> playCompleted() => _play(AppSound.completed);

  Future<void> playJoined() => _play(AppSound.joined);

  Future<void> _play(AppSound sound) async {
    await _loadFuture;
    if (!_enabled.value) return;

    final player = _players[sound];
    final assetPath = _assetPaths[sound];
    if (player == null || assetPath == null) return;

    try {
      await player.stop();
      await player.play(AssetSource(assetPath));
    } catch (error) {
      debugPrint('Unable to play app sound ${sound.name}: $error');
    }
  }
}
