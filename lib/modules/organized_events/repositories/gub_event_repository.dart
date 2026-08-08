import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/models/creation_availability.dart';
import '../../../core/models/deletion_context.dart';
import '../../../repositories/creation_cooldown_repository.dart';
import '../models/gub_event_model.dart';

class GubEventRepository {
  GubEventRepository._();
  static final instance = GubEventRepository._();
  final _db = FirebaseFirestore.instance;
  final _auth =