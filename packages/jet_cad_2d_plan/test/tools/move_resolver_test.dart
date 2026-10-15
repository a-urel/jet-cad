// Spec P3 "Attachment" (Task 14): plan.select's move resolver asks the
// registry for a root-level symbol instance whose jetcad.symbol attaches
// somewhere; the query is the plain-moved transform, anchored on the moved
// footprint's back-centre, the node excluded. A turned, mirrored placement
// far from the origin; a camera at 0.1 px/mm.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/authoring.dart' show Catalog, encodeLibrary;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/src/attach/attachment_registry.dart';
import 'package:jet_cad_2d_plan/src/symbols/symbol_placer.dart';
import 'package:jet_cad_2d_plan/src/tools/move_resolver.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/attach_fixtures.dart';
import '../support/symbol_fixtures.dart';

final class _ServicesStub implements PlanServices {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('a provider factory read the services');
}

final SymbolLibrary lib =
    SymbolLibrary.decode(encodeLibrary(Catalog(kit: 'demo', symbols: [
  box('demo.shelf.wall', 'Wall shelf', 'Storage', ['shelf'],
      attachTo: ['test-edge'], base: (950, 410)),
  box('demo.table.free', 'Table', 'Dining', ['table'], base: (950, 410)),
])));

SymbolEntry entry(String key) =>
    lib.entries.singleWhere((e) => e.symbol.key == key);

final class Scene {
  Scene({String key = 'demo.shelf.wall', bool objectSnap = true}) {
    doc = DraftDocument.empty();
    registerKitComponents(doc.components);
    doc.header.units = DrawingUnits.millimeters;
    doc.commands.execute(placeSymbol(doc, entry(key),
        at: Vector2(100000.25, -70000.75), quarterTurns: 1, mirrored: true));
    instance = doc.tree.nodes.whereType<InstanceNode>().single.handle;
    index = SpatialIndex(doc);
    selection = SelectionController(doc);
    camera = CameraController(ViewportTransform(
        worldToScreenMatrix: Transform2(0.1, 0, 0, -0.1, -9600, -6600)));
    snap = SnapSettings(objectSnap: objectSnap);
    ctx = ToolContext(
        document: doc,
        index: index,
        camera: camera,
        selection: selection,
        snap: snap);
    registry = PlanAttachmentRegistry(report: reported.add);
    edge = RecordingProvider('test-edge', (q) => answer?.call(q));
    registry.add('demo', (_) => edge, _ServicesStub());
    resolver = PlanMoveResolver(
        attachments: () {
          asked++;
          return registry;
        },
        canRotate: () => rotate);
    addTearDown(() {
      registry.dispose();
      snap.dispose();
      selection.dispose();
      index.dispose();
      camera.dispose();
    });
  }

  late final DraftDocument doc;
  late final Handle instance;
  late final SpatialIndex index;
  late final SelectionController selection;
  late final CameraController camera;
  late final SnapSettings snap;
  late final ToolContext ctx;
  late final PlanAttachmentRegistry registry;
  late final RecordingProvider edge;
  late final PlanMoveResolver resolver;
  final List<KitDiagnostic> reported = [];
  Attachment? Function(AttachmentQuery q)? answer;
  bool rotate = true;

  /// How many times the resolver read the registry to ask it.
  int asked = 0;

  Transform2 get transform => (doc.tree[instance]! as InstanceNode).transform;
}

List<double> partsOf(Transform2 t) => [t.a, t.b, t.c, t.d, t.e, t.f];

final Transform2 delta = Transform2.translation(310.5, -125.25);

void main() {
  test(
      'MV-1 the query: the plain move, its back-centre, the node excluded, '
      'its mirror, mayRotate; the answer is the move', () {
    final s = Scene();
    final placed = attachment(Transform2.translation(99000.5, -69000.25),
        Vector2(99010.25, -69020.5), 'face');
    s.answer = (_) => placed;
    final r = s.resolver.resolveMove(s.ctx, s.instance, delta)!;
    expect(partsOf(r.transform), partsOf(placed.transform));
    expect(r.marker, placed.marker);
    final q = s.edge.queries.single;
    final moved = delta.multiply(s.transform);
    expect(partsOf(q.current), partsOf(moved));
    final box = boxOfEntry(entry('demo.shelf.wall'))!;
    // M-MV1a: the raw transform's back-centre (no delta).
    expect(q.pointer, moved.transformPoint(box.backCentre));
    // M-MV1b: the node not excluded.
    expect(q.exclude, {s.instance});
    expect(q.mirrored, isTrue, reason: 'placed mirrored');
    expect(q.mayRotate, isTrue);
    expect(q.capture, closeTo(16 / 0.1, 1e-9));
    expect(q.edgeCapture, closeTo(kSnapAperturePixels / 0.1, 1e-9));
    expect([q.footprint.minX, q.footprint.maxY], [box.left, box.back]);
    s.rotate = false;
    s.resolver.resolveMove(s.ctx, s.instance, delta);
    expect(s.edge.queries.last.mayRotate, isFalse);
  });

  test(
      'MV-2 nothing is asked for a symbol that attaches to nothing, a '
      'non-symbol, with object snap off, or for a scaled instance', () {
    final free = Scene(key: 'demo.table.free');
    // M-MV2a: the attachTo test dropped.
    expect(free.resolver.resolveMove(free.ctx, free.instance, delta), isNull);
    expect(free.edge.queries, isEmpty);
    expect(free.asked, 0, reason: 'no attachTo: the registry is not asked');

    final off = Scene(objectSnap: false);
    off.answer = (_) => attachment(Transform2.identity(), Vector2(1, 1), 't');
    // M-MV2b: the object snap test dropped.
    expect(off.resolver.resolveMove(off.ctx, off.instance, delta), isNull);
    expect(off.edge.queries, isEmpty);

    final scaled = Scene();
    scaled.doc.commands.execute(TransformNodeCommand(
        scaled.instance, Transform2.scale(2, 2).multiply(scaled.transform)));
    expect(scaled.resolver.resolveMove(scaled.ctx, scaled.instance, delta),
        isNull);
    expect(scaled.edge.queries, isEmpty);

    final line = addDrafted(scaled.doc, EntityKind.line,
        linePayload(Vector2(100500, -70500), Vector2(101500, -70100)),
        layer: ReservedHandles.layerZero);
    scaled.doc.commands.execute(line);
    expect(scaled.resolver.resolveMove(scaled.ctx, line.record.handle, delta),
        isNull);
  });

  test(
      'MV-3 within one drag a query keeps the last answer; after the '
      'document changes it starts afresh', () {
    final s = Scene();
    final a = attachment(Transform2.translation(99000.5, -69000.25),
        Vector2(99010.25, -69020.5), 'face');
    s.answer = (_) => a;
    s.resolver.resolveMove(s.ctx, s.instance, delta);
    s.resolver.resolveMove(s.ctx, s.instance, delta);
    // M-MV3a: keep always null.
    expect(s.edge.queries.last.keep, same(a));
    s.doc.commands.execute(TransformNodeCommand(s.instance, a.transform));
    s.resolver.resolveMove(s.ctx, s.instance, delta);
    // M-MV3b: the stateId reset dropped.
    expect(s.edge.queries.last.keep, isNull);
  });

  test('MV-4 the footprint is the definition\'s live leaves', () {
    final s = Scene();
    final node = s.doc.tree[s.instance]! as InstanceNode;
    final box = boxOfDefinition(s.doc, node.definition)!;
    s.answer = (_) => null;
    s.resolver.resolveMove(s.ctx, s.instance, delta);
    final f = s.edge.queries.single.footprint;
    expect([f.minX, f.minY, f.maxX, f.maxY],
        [box.left, box.front, box.right, box.back]);
  });
}
