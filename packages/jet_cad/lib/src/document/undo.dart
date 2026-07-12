import 'dart:typed_data';

import 'entity.dart';

/// Everything needed to walk one operation backward or forward again.
///
/// Uniform algorithm (transform ops skip snapshots and use their inverse
/// matrix instead):
///   undo: delete postBodies, restore preSnapshot, swap entity maps back
///   redo: delete preBodies,  restore postSnapshot, swap entity maps forward
/// Snapshots are id-preserving, which is what makes redo safe: restored
/// bodies keep the ids that later operations reference.
class UndoRecord {
  final Uint8List? preSnapshot;
  final List<BodyId> preBodies;
  final Uint8List? postSnapshot;
  final List<BodyId> postBodies;
  final Map<EntityId, Entity> entitiesBefore;
  final Map<EntityId, Entity> entitiesAfter;

  const UndoRecord({
    this.preSnapshot,
    this.preBodies = const [],
    this.postSnapshot,
    this.postBodies = const [],
    this.entitiesBefore = const {},
    this.entitiesAfter = const {},
  });
}
