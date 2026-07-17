import 'package:cloud_firestore/cloud_firestore.dart';

class GubRepository {
  GubRepository._();

  static final GubRepository instance = GubRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Cache in memoria degli Hub
  final Map<String, Map<String, dynamic>> _hubCache = {};

  /// Restituisce i dati dell'Hub.
  /// Se sono già in memoria, non interroga Firestore.
  Future<Map<String, dynamic>?> getHub(String hubId) async {
    // Cache
    if (_hubCache.containsKey(hubId)) {
      return _hubCache[hubId];
    }

    final doc = await _firestore.collection("hubs").doc(hubId).get();

    if (!doc.exists) return null;

    final data = doc.data();

    if (data != null) {
      _hubCache[hubId] = data;
    }

    return data;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> hubStream(String hubId) {
    return _firestore.collection("hubs").doc(hubId).snapshots();
  }

  /// Aggiorna la cache dopo una modifica
  void updateHub(String hubId, Map<String, dynamic> data) {
    _hubCache[hubId] = data;
  }

  /// Elimina un Hub dalla cache
  void removeHub(String hubId) {
    _hubCache.remove(hubId);
  }

  /// Svuota completamente la cache
  void clearCache() {
    _hubCache.clear();
  }
}