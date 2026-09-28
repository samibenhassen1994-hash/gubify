import 'package:cloud_firestore/cloud_firestore.dart';

class PushDeviceRepository {
  PushDeviceRepository._();
  static final instance = PushDeviceRepository._();

  DocumentReference<Map<String, dynamic>> _device(String uid, String deviceId) =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection('devices').doc(deviceId);

  Future<void> save({required String uid, required String deviceId, required String token, required String platform}) =>
      _device(uid, deviceId).set({
        'deviceId': deviceId,
        'token': token,
        'platform': platform,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> delete({required String uid, required String deviceId}) => _device(uid, deviceId).delete();
}
