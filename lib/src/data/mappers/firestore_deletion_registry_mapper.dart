import '../../domain/entities/deletion_registry.dart';
import 'json_mapper.dart';

class FirestoreDeletionRegistryMapper extends JsonMapper<DeletionRegistry> {
  @override
  DeletionRegistry fromMap(Map<String, dynamic> map) {
    return DeletionRegistry.fromMap(map);
  }

  @override
  Map<String, dynamic> toMap(DeletionRegistry value) {
    return value.toMap();
  }
}
