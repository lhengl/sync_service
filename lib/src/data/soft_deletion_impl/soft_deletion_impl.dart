import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:collection/collection.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:sembast/sembast.dart' as sb;
import 'package:sync_service/src/application/application.dart';
import 'package:sync_service/src/data/data.dart';

import '../../domain/domain.dart';
import '../../domain/entities/sync_entity.dart';
import '../../helpers/helpers.dart';

part 'disposal_registry.dart';
part 'firestore_soft_remote_repo.dart';
part 'firestore_soft_sync_delegate.dart';
part 'firestore_soft_sync_service.dart';
part 'firestore_soft_synced_repo.dart';
part 'garbage_collector.dart';
part 'soft_deletion_impl.mapper.dart';
