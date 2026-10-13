// A walk through the engine: draw, query, undo and save a document.
//
// Run with `dart run example/jet_cad_2d_example.dart`.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

Future<void> main() async {
  final doc = DraftDocument.empty();

  // Every edit is a command: executed through the dispatcher, it can be
  // undone and redone.
  final line = addDrafted(
      doc, EntityKind.line, linePayload(Vector2(100, 100), Vector2(500, 100)),
      layer: ReservedHandles.layerZero);
  final circle = addDrafted(
      doc, EntityKind.circle, circlePayload(Vector2(300, 250), 50),
      layer: ReservedHandles.layerZero);
  doc.commands
    ..execute(line)
    ..execute(circle);
  print('entities: ${doc.entities.liveCount}');
  print('extents: ${doc.extents}');

  // The spatial index follows the document's edits synchronously. A pick
  // finds the topmost entity within a radius of a world point and writes
  // into a caller-owned HitPath: nothing per entity is allocated, only a
  // few objects per level of instance nesting. The point is 1 unit outside
  // the circle's top, within the radius of 2.
  final index = SpatialIndex(doc);
  final hit = HitPath();
  void pick() {
    final found =
        index.pickInto(Vector2(300, 301), 2, const QueryFilter.picking(), hit);
    final what = !found
        ? 'nothing'
        : hit.entity == circle.record.handle
            ? 'the circle (${hit.kind.name})'
            : 'another entity';
    print('pick (300, 301): $what');
  }

  pick();
  doc.commands.undo();
  print('after undo, entities: ${doc.entities.liveCount}');
  pick();
  doc.commands.redo();
  print('after redo, entities: ${doc.entities.liveCount}');
  pick();

  // The document format is deterministic: a decoded copy writes the same
  // bytes back, and holds the same geometry.
  final saved = DraftDocumentCodec.encodeToString(doc);
  final copy = DraftDocumentCodec.decodeString(saved);
  print('decoded copy: entities ${copy.entities.liveCount}, encodes '
      'identically: ${DraftDocumentCodec.encodeToString(copy) == saved}');
  final copyIndex = SpatialIndex(copy);
  final onCopy = copyIndex.pickInto(
          Vector2(300, 301), 2, const QueryFilter.picking(), hit) &&
      copy.entities.kindAt(copy.entities.slotOf(hit.entity)!) ==
          EntityKind.circle;
  print('pick on the copy (300, 301): '
      '${onCopy ? 'a circle (${hit.kind.name})' : 'no circle'}');

  copyIndex.dispose();
  index.dispose();
  await copy.dispose();
  await doc.dispose();
}
