import 'dart:convert';
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'clients.dart';

/// A's placement, and everything relational is placed relative to it, so
/// the whole scene is rotated and off the origin.
final Transform2 atA = Transform2.translation(7010, 3020)
    .multiply(Transform2.rotation(math.pi / 6));
Transform2 onA(double x, double y, double turn) => atA
    .multiply(Transform2.translation(x, y))
    .multiply(Transform2.rotation(turn));

/// B pierces A's long top edge from inside: A's top edge splits in two (A
/// has 5 children), B's bottom edge is swallowed (B has 3).
final Transform2 atB = onA(800, 700, 0.3);

/// Far from everything, still rotated.
final Transform2 parked =
    Transform2.translation(19000, 11000).multiply(Transform2.rotation(-0.7));

const Handle hA = Handle(1000);
const Handle hB = Handle(2000);

final ParametricCatalog catalog = testCatalog();

DraftDocument paramDoc() {
  final doc = DraftDocument.empty();
  ParametricSystem(doc, catalog).install();
  return doc;
}

DraftCommand create<T extends Component>(
        DraftDocument doc, Handle h, Transform2 at, T params) =>
    CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: h,
          parent: doc.rootHandle,
          transform: at,
          children: const [])),
      SetComponentCommand<T>(h, params),
    ], label: 'Add object');

void pair(DraftDocument doc, {bool bFirst = false}) {
  final a = create(doc, hA, atA, const ClipRect(2000, 1000));
  final b = create(doc, hB, atB, const ClipRect(400, 900));
  for (final c in bFirst ? [b, a] : [a, b]) {
    doc.commands.execute(c);
  }
}

/// [group]'s children, ascending.
List<Handle> kids(DraftDocument doc, Handle group) => [
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.ownerAt(slot) == group) doc.entities.handleAt(slot),
    ]..sort((a, b) => a.value.compareTo(b.value));

/// Each LINE child of [group], in world coordinates.
List<List<double>> worldSegments(DraftDocument doc, Handle group) {
  final m = doc.tree.accumulatedTransform(group);
  return [
    for (final k in kids(doc, group))
      () {
        final g = doc.geometry
            .read(doc.entities.geomIndexAt(doc.entities.slotOf(k)!))
            .coords;
        final a = m.transformPoint(Vector2(g[0], g[1]));
        final b = m.transformPoint(Vector2(g[2], g[3]));
        return [a.x, a.y, b.x, b.y];
      }(),
  ];
}

String enc(DraftDocument d) => DraftDocumentCodec.encodeToString(d);

/// Entities sorted by handle: slot order is history, not state (spec D11).
String canon(DraftDocument d) {
  final j = DraftDocumentCodec.encode(d);
  j['entities'] = List<Map<String, Object?>>.from(j['entities']! as List)
    ..sort((a, b) => ((a['record']! as Map)['handle']! as int)
        .compareTo((b['record']! as Map)['handle']! as int));
  return jsonEncode(j);
}

/// Decodes with the catalog's factories and installs a system.
DraftDocument reload(String s) {
  final doc = DraftDocumentCodec.decode(jsonDecode(s) as Map<String, Object?>,
      registerComponents: catalog.registerComponents);
  ParametricSystem(doc, catalog).install();
  return doc;
}
