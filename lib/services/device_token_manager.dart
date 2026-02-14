import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class DeviceTokenManager {
  DeviceTokenManager();

  FirebaseMessaging? _messaging;
  bool _firebaseReady = false;
  bool _permissionRequested = false;
  String? _cachedToken;
  final Set<String> _subscribedTopics = <String>{};

  Future<void> _ensureFirebase() async {
    if (kIsWeb) {
      return;
    }
    if (_firebaseReady) {
      _messaging ??= FirebaseMessaging.instance;
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _firebaseReady = true;
      _messaging = FirebaseMessaging.instance;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Firebase initialization skipped: $error');
      }
    }
  }

  Future<void> _ensurePermission() async {
    if (_permissionRequested || _messaging == null) return;
    _permissionRequested = true;
    try {
      await _messaging!.requestPermission();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Notification permission request failed: $error');
      }
    }
  }

  Future<String?> fetchToken() async {
    await _ensureFirebase();
    if (_messaging == null) return null;

    await _ensurePermission();
    if (_cachedToken != null) return _cachedToken;

    try {
      _cachedToken = await _messaging!.getToken();
      return _cachedToken;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Unable to fetch FCM token: $error');
      }
      return null;
    }
  }

  void invalidateCache() {
    _cachedToken = null;
  }

  Set<String> get subscribedTopics => Set.unmodifiable(_subscribedTopics);

  Future<void> subscribeToTopic(String topic) async {
    final normalized = _normalizeTopic(topic);
    if (normalized == null) return;

    await _ensureFirebase();
    if (_messaging == null) return;
    await _ensurePermission();
    if (_subscribedTopics.contains(normalized)) return;

    try {
      await _messaging!.subscribeToTopic(normalized);
      _subscribedTopics.add(normalized);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Failed to subscribe to $normalized: $error');
      }
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    final normalized = _normalizeTopic(topic);
    if (normalized == null) return;

    await _ensureFirebase();
    if (_messaging == null) return;

    if (!_subscribedTopics.contains(normalized)) return;

    try {
      await _messaging!.unsubscribeFromTopic(normalized);
      _subscribedTopics.remove(normalized);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Failed to unsubscribe from $normalized: $error');
      }
    }
  }

  Future<void> syncTopics(Iterable<String> desiredTopics) async {
    await _ensureFirebase();
    if (_messaging == null) return;
    await _ensurePermission();

    final desired = desiredTopics
        .map(_normalizeTopic)
        .whereType<String>()
        .toSet();

    final toSubscribe = desired.difference(_subscribedTopics);
    final toUnsubscribe = _subscribedTopics.difference(desired);

    for (final topic in toSubscribe) {
      try {
        await _messaging!.subscribeToTopic(topic);
        _subscribedTopics.add(topic);
      } catch (error) {
        if (kDebugMode) {
          debugPrint('Failed to subscribe to $topic: $error');
        }
      }
    }

    for (final topic in toUnsubscribe) {
      try {
        await _messaging!.unsubscribeFromTopic(topic);
        _subscribedTopics.remove(topic);
      } catch (error) {
        if (kDebugMode) {
          debugPrint('Failed to unsubscribe from $topic: $error');
        }
      }
    }
  }

  Future<void> unsubscribeFromAllTopics() async {
    if (_subscribedTopics.isEmpty) return;
    await syncTopics(const <String>{});
  }

  String? _normalizeTopic(String topic) {
    final trimmed = topic.trim();
    if (trimmed.isEmpty) return null;
    final sanitized = trimmed
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return sanitized;
  }
}
