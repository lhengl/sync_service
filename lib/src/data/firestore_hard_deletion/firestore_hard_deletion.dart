import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:collection/collection.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:duration/duration.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:sembast/sembast.dart' as sb;
import 'package:sync_service/src/application/application.dart';
import 'package:sync_service/src/data/data.dart';

import '../../domain/domain.dart';
import '../../domain/entities/sync_entity.dart';
import '../../helpers/helpers.dart';

part 'deletion_registry.dart';
part 'firestore_hard_deletion.mapper.dart';
part 'firestore_remote_repo.dart';
part 'firestore_sync_repo.dart';
part 'firestore_sync_service.dart';
