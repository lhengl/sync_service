import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:flutter_kronos/flutter_kronos.dart';

mixin SembastHelper {
  String generateId() => fs.FirebaseFirestore.instance.collection('collection').doc().id;
  Future<DateTime> get utc async => await FlutterKronos.getNtpDateTime ?? DateTime.now().toUtc();
}
