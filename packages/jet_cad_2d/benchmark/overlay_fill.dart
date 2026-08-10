// The A-vs-C input the frame rigs cannot produce.
//
// R4a drags one entity, and a drag is remove-then-add: the add takes the slot
// the remove just freed, so the overlay never grows past one entry. A real
// editing session touches *different* entities. This fills the overlay from
// distinct edits and measures two things against each other — what the
// overlay's linear scan costs per query as it fills, and what the repack costs
// when it crosses.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d/testing.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

const int kEntities = 500000;

double medianRectQueryMs(SpatialIndex index, DraftDocument doc, Aabb2 rect) {
  final samples = <double>[];
  for (var i = 0; i < 40; i++) {
    final sw = Stopwatch()..start();
    var seen = 0;
    index.forEachInRect(rect, const QueryFilter.rendering(), (_) => seen++);
    sw.stop();
    if (i >= 10) samples.add(sw.elapsedMicroseconds / 1000.0);
  }
  samples.sort();
  return samples[samples.length ~/ 2];
}

void main() {
  final doc = generateDocument(kEntities,
      definitionCount: 200,
      instanceCount: 20000,
      nestingDepth: 2,
      mirroredFraction: 0.1,
      nonUniformFraction: 0.2,
      groupCount: 50,
      layerCount: 8,
      byBlockFraction: 0.3,
      dashedFraction: 0.35);

  // Corpus composition, for the two declared optimisms.
  var text = 0, dashed = 0, total = 0;
  for (final slot in doc.entities.liveSlots) {
    total++;
    final kind = doc.entities.kindAt(slot);
    if (kind == EntityKind.text || kind == EntityKind.attrib) text++;
    if (doc.entities.linetypeAt(slot) != ReservedHandles.byLayerLinetype) {
      dashed++;
    }
  }
  print('corpus entities=$total text=$text '
      '(${(text / total * 100).toStringAsFixed(2)}%) '
      'non-continuous linetype=$dashed '
      '(${(dashed / total * 100).toStringAsFixed(1)}%)');

  final index = SpatialIndex(doc);
  final e = doc.extents;
  final cx = (e.minX + e.maxX) / 2, cy = (e.minY + e.maxY) / 2;
  final rect = Aabb2(Vector2(cx - 1500, cy - 1125), Vector2(cx + 1500, cy + 1125));
  final threshold = index.rootIndex.rebuildThreshold;
  print('rebuildThreshold=$threshold  leafCount=${index.rootIndex.leafCount}');
  print('overlay=0  rectQuery p50=${medianRectQueryMs(index, doc, rect)}ms');

  // Edit distinct entities: a transform of the coordinates in place is not a
  // command the model has, so this is remove-then-add on a *fresh* entity each
  // time, which is what a multi-select nudge would produce.
  final slots = doc.entities.liveSlots.toList();
  final random = math.Random(7);
  final handles = [
    for (var i = 0; i < slots.length; i += math.max(1, slots.length ~/ 40000))
      doc.entities.handleAt(slots[i])
  ];

  var edited = 0;
  for (final target in [threshold ~/ 8, threshold ~/ 2, threshold - 100]) {
    while (edited < target && edited < handles.length) {
      final handle = handles[edited++];
      final slot = doc.entities.slotOf(handle);
      if (slot == null) continue;
      final owner = doc.entities.ownerAt(slot);
      final payload = doc.geometry.peek(doc.entities.geomIndexAt(slot));
      final coords = Float64List.fromList(payload.coords);
      for (var i = 0; i < coords.length; i++) {
        coords[i] += random.nextDouble();
      }
      doc.commands.execute(RemoveEntityCommand(handle));
      doc.commands.execute(AddEntityCommand(
        record: EntityRecord(
          handle: doc.handleSeed.next(),
          owner: owner,
          kind: doc.entities.kindAt(slot),
          layer: ReservedHandles.layerZero,
          linetype: ReservedHandles.byLayerLinetype,
          linetypeScale: 1.0,
          geomIndex: 0,
          color: const ByLayerColor(),
          lineweight: 25,
          transparency: 0,
          flags: 0,
        ),
        payload: GeometryPayload(
            coords: coords, scalars: Float64List.fromList(payload.scalars)),
      ));
    }
    print('overlay=${index.rootIndex.dirty.length}  '
        'rectQuery p50=${medianRectQueryMs(index, doc, rect)}ms  '
        'rebuilds=${index.rebuildCount}');
  }

  // Cross it, and time the repack that lands.
  final before = index.rebuildCount;
  final sw = Stopwatch()..start();
  while (index.rebuildCount == before && edited < handles.length) {
    final handle = handles[edited++];
    final slot = doc.entities.slotOf(handle);
    if (slot == null) continue;
    doc.commands.execute(RemoveEntityCommand(handle));
  }
  sw.stop();
  print('crossing the threshold: ${sw.elapsedMilliseconds}ms for the edits '
      'that triggered it, rebuilds=${index.rebuildCount - before}');

  // One explicit full repack, isolated.
  final repack = Stopwatch()..start();
  final fresh = SpatialIndex(doc);
  repack.stop();
  print('one full 500k index build: ${repack.elapsedMilliseconds}ms');
  fresh.dispose();
  index.dispose();
}
