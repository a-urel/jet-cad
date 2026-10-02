// Spec 09 D6, plan 09a Task 4: the placer. Fixtures avoid the degenerate
// cases (P-4): every base point is off the origin, every `at` is off the
// origin, placements are rotated and mirrored, instance style fields differ
// from the defaults, the target document holds handles the library also uses,
// a foreign definition has the symbol's own name, and an older version lives
// beside a newer one.
import 'dart:convert';
import 'dart:math' as math;

import 'package:floor_planner/parametric/catalog.dart';
import 'package:floor_planner/symbols/symbol_component.dart';
import 'package:floor_planner/symbols/symbol_library.dart';
import 'package:floor_planner/symbols/symbol_placer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/symbol_fixtures.dart';

typedef Leaf = ({EntityRecord record, GeometryPayload payload});

SymbolLibrary library() => SymbolLibrary.decode(bytesOf(buildValidLibrary()));

SymbolEntry entryOf(String key) =>
    library().entries.firstWhere((e) => e.key == key);

SymbolEntry sofa() => entryOf('sofa.three');

/// [e] re-issued at another [version] (same key, same leaves).
SymbolEntry withVersion(SymbolEntry e, int version) => SymbolEntry(
      key: e.key,
      name: e.name,
      category: e.category,
      tags: e.tags,
      version: version,
      definition: e.definition,
      leaves: e.leaves,
    );

DraftDocument target({DraftPermissions permissions = DraftPermissions.all}) {
  final doc = DraftDocument.empty(permissions: permissions);
  registerAppComponents(doc.components);
  doc.header.units = DrawingUnits.millimeters;
  return doc;
}

List<InstanceNode> instances(DraftDocument doc) =>
    doc.tree.nodes.whereType<InstanceNode>().toList();

/// The leaves owned by [def], ascending by handle.
List<Leaf> leavesOf(DraftDocument doc, Handle def) {
  final out = <Leaf>[];
  for (final slot in doc.entities.liveSlots) {
    if (doc.entities.ownerAt(slot) != def) continue;
    final record = doc.entities.read(slot);
    out.add((record: record, payload: doc.geometry.read(record.geomIndex)));
  }
  out.sort((a, b) => a.record.handle.value.compareTo(b.record.handle.value));
  return out;
}

Definition defOf(DraftDocument doc, String key, int version) {
  for (final h in doc.components.withComponent<SymbolComponent>()) {
    final c = doc.components.get<SymbolComponent>(h)!;
    final d = doc.tree.definition(h);
    if (d != null && c.key == key && c.version == version) return d;
  }
  throw StateError('no $key@$version');
}

/// A foreign definition, no component.
AddDefinitionCommand foreign(int handle, String name) =>
    AddDefinitionCommand(Definition(
        handle: Handle(handle),
        name: name,
        basePoint: Vector2(3, 4),
        children: const []));

String encoded(DraftDocument doc) => DraftDocumentCodec.encodeToString(doc);

/// The encoded document without its handle seed, which a refused or undone
/// placement is allowed to have moved (spec F-8).
String encodedNoSeed(DraftDocument doc) {
  final json = DraftDocumentCodec.encode(doc)..remove('handleSeed');
  return jsonEncode(json);
}

DraftDocument reload(DraftDocument doc) =>
    DraftDocumentCodec.decodeString(encoded(doc),
        registerComponents: registerAppComponents);

/// World position of a local point under placement (q, mirrored), written
/// without [Transform2]: mirror the local x, rotate by q quarter turns, move
/// the base point to [at].
Vector2 expectedWorld(
    Vector2 local, Vector2 base, Vector2 at, int q, bool mirrored) {
  var x = local.x - base.x;
  var y = local.y - base.y;
  if (mirrored) x = -x;
  final (rx, ry) = switch (((q % 4) + 4) % 4) {
    0 => (x, y),
    1 => (-y, x),
    2 => (-x, -y),
    _ => (y, -x),
  };
  return Vector2(at.x + rx, at.y + ry);
}

final Vector2 at = Vector2(3333.5, -2222.25);

/// Far from the origin, as the wall fixtures are (plan P-2).
final Vector2 far = Vector2(100000.25, -70000.75);

/// A 30° and a −112.5° rotation vector: (name, cos, sin).
final List<(String, double, double)> rotations = [
  ('30°', math.sqrt(3) / 2, 0.5),
  (
    '−112.5°',
    math.cos(-112.5 * math.pi / 180),
    math.sin(-112.5 * math.pi / 180)
  ),
];
const Tolerance tol = Tolerance.standard;

void main() {
  group('placementTransform', () {
    test(
        'P1 the base point lands on at, and a leaf endpoint where the '
        'independent formula says, for every quarter turn, mirrored or not',
        () {
      final e = sofa();
      final base = e.definition.basePoint;
      expect(base.x, isNot(0));
      expect(base.y, isNot(0));
      final line =
          e.leaves.firstWhere((l) => l.record.handle.value == sofaLine);
      final p0 = line.payload.pointAt(0);
      final p1 = line.payload.pointAt(1);
      for (final mirrored in [false, true]) {
        for (var q = 0; q < 4; q++) {
          final t = placementTransform(
              at: at, basePoint: base, quarterTurns: q, mirrored: mirrored);
          expect(tol.eqPoint(t.transformPoint(base), at), isTrue,
              reason: 'q=$q mirrored=$mirrored base point');
          for (final p in [p0, p1]) {
            final want = expectedWorld(p, base, at, q, mirrored);
            expect(tol.eqPoint(t.transformPoint(p), want), isTrue,
                reason: 'q=$q mirrored=$mirrored $p -> '
                    '${t.transformPoint(p)}, want $want');
          }
        }
      }
    });

    test('P2 quarter turns are taken modulo 4, negative allowed', () {
      final base = Vector2(900, 400);
      List<double> t(int q) => placementTransform(
              at: at, basePoint: base, quarterTurns: q, mirrored: true)
          .toJson()
          .cast<double>();
      expect(t(-1), t(3));
      expect(t(4), t(0));
      expect(t(5), t(1));
      expect(t(-6), t(2));
      expect(t(1), isNot(t(3)));
    });

    test(
        'P3 the matrix is exactly 0 and ±1 in its linear part and never '
        '-0.0, for every quarter turn, mirrored or not', () {
      final base = Vector2(900, 400);
      for (final mirrored in [false, true]) {
        for (var q = -2; q < 6; q++) {
          final t = placementTransform(
              at: at, basePoint: base, quarterTurns: q, mirrored: mirrored);
          for (final v in [t.a, t.b, t.c, t.d]) {
            expect([0.0, 1.0, -1.0], contains(v),
                reason: 'q=$q mirrored=$mirrored ${t.toJson()}');
          }
          for (final v in [t.a, t.b, t.c, t.d, t.e, t.f]) {
            expect(v == 0 && v.isNegative, isFalse,
                reason: 'q=$q mirrored=$mirrored has -0.0: ${t.toJson()}');
          }
        }
      }
    });

    test(
        'P4 a mirror flips the local x axis whatever the turns (det < 0), '
        'and the turn order is rotate after mirror', () {
      final base = Vector2(900, 400);
      for (var q = 0; q < 4; q++) {
        expect(
            placementTransform(
                    at: at, basePoint: base, quarterTurns: q, mirrored: true)
                .determinant,
            -1.0);
        expect(
            placementTransform(at: at, basePoint: base, quarterTurns: q)
                .determinant,
            1.0);
      }
      // Local +x under q=1 mirrored: mirrored to -x, rotated to -y.
      final t = placementTransform(
          at: at, basePoint: base, quarterTurns: 1, mirrored: true);
      final d = t.transformDirection(Vector2(1, 0));
      expect(d.x, 0.0);
      expect(d.y, -1.0);
    });

    // Plan 09c-1 Task 5 (spec D5): the rotation as a unit vector. The
    // fixtures: a 30° and a −112.5° vector (no 0 or ±1 in either), `far` and
    // the sofa's base point off the origin and off each other.

    test(
        'P20 a rotation vector gives translate(at) · R · S · '
        'translate(−base), written out by hand, mirrored or not', () {
      final e = sofa();
      final base = e.definition.basePoint;
      final line =
          e.leaves.firstWhere((l) => l.record.handle.value == sofaLine);
      for (final (name, cos, sin) in rotations) {
        for (final mirrored in [false, true]) {
          final why = '$name mirrored=$mirrored';
          final s = mirrored ? -1.0 : 1.0;
          final t = placementTransform(
              at: far,
              basePoint: base,
              rotation: (cos, sin),
              mirrored: mirrored);
          // The local x is mirrored first, then turned: (s·cos, s·sin);
          // the local y turns alone: (−sin, cos). Exact doubles.
          expect(
              t.toJson(),
              [
                s * cos,
                s * sin,
                -sin,
                cos,
                far.x - (s * cos * base.x - sin * base.y),
                far.y - (s * sin * base.x + cos * base.y),
              ],
              reason: why);
          expect(tol.eqPoint(t.transformPoint(base), far), isTrue,
              reason: '$why base point');
          for (final p in [line.payload.pointAt(0), line.payload.pointAt(1)]) {
            final u = (p.x - base.x) * s, v = p.y - base.y;
            final want =
                Vector2(far.x + cos * u - sin * v, far.y + sin * u + cos * v);
            expect(tol.eqPoint(t.transformPoint(p), want), isTrue,
                reason: '$why $p -> ${t.transformPoint(p)}, want $want');
          }
          expect(t.determinant, closeTo(s, 1e-12), reason: why);
        }
      }
    });

    test(
        'P21 quarterTurns and rotation together are refused (an '
        'ArgumentError, not only an assert)', () {
      for (final q in [0, 1]) {
        expect(
            () => placementTransform(
                at: far,
                basePoint: Vector2(900, 400),
                quarterTurns: q,
                rotation: (rotations.first.$2, rotations.first.$3)),
            throwsArgumentError,
            reason: 'quarterTurns: $q');
      }
      // Neither: no turn.
      expect(
          placementTransform(at: far, basePoint: Vector2(900, 400)).toJson(),
          placementTransform(
              at: far,
              basePoint: Vector2(900, 400),
              rotation: (1.0, 0.0)).toJson());
    });

    test(
        'P22 the quarter-turn form is the rotation form at the exact table: '
        'the same bytes for every turn, mirrored or not', () {
      const table = [(1.0, 0.0), (0.0, 1.0), (-1.0, 0.0), (0.0, -1.0)];
      final base = Vector2(900, 400);
      for (final mirrored in [false, true]) {
        for (var q = -2; q < 6; q++) {
          expect(
              placementTransform(
                      at: far,
                      basePoint: base,
                      quarterTurns: q,
                      mirrored: mirrored)
                  .toJson(),
              placementTransform(
                      at: far,
                      basePoint: base,
                      rotation: table[((q % 4) + 4) % 4],
                      mirrored: mirrored)
                  .toJson(),
              reason: 'q=$q mirrored=$mirrored');
        }
      }
    });

    test(
        'P23 an axis-aligned rotation vector (cos or sin −0.0, as a face '
        'normal gives it) stores no −0.0, mirrored or not (M-09c-n: the '
        'named axis-aligned exception)', () {
      final base = Vector2(900, 400);
      for (final r in [
        (-0.0, 1.0),
        (0.0, 1.0),
        (-0.0, -1.0),
        (1.0, -0.0),
        (-1.0, -0.0),
      ]) {
        for (final mirrored in [false, true]) {
          final t = placementTransform(
              at: far, basePoint: base, rotation: r, mirrored: mirrored);
          for (final v in t.toJson()) {
            expect(v == 0 && v.isNegative, isFalse,
                reason: '$r mirrored=$mirrored has -0.0: ${t.toJson()}');
          }
        }
      }
    });
  });

  group('placeSymbol', () {
    test(
        'P5 is labelled, does not execute, allocates handles at '
        'construction and writes no table record', () {
      final doc = target();
      final e = sofa();
      final tablesBefore = DraftDocumentCodec.encode(doc)['tables'];
      final seedBefore = doc.handleSeed.current;
      final cmd = placeSymbol(doc, e, at: at);
      expect(cmd.label, 'Place Three-seat sofa');
      expect(doc.tree.definitions, isEmpty);
      expect(instances(doc), isEmpty);
      expect(doc.entities.liveCount, 0);
      // definition + 4 leaves + instance.
      expect(doc.handleSeed.current.value, seedBefore.value + 6);
      final seedAfterBuild = doc.handleSeed.current;
      doc.commands.execute(cmd);
      doc.commands.undo();
      doc.commands.redo();
      expect(doc.handleSeed.current, seedAfterBuild,
          reason: 'execute, undo and redo allocate nothing');
      expect(DraftDocumentCodec.encode(doc)['tables'], tablesBefore);
      expect(cmd.capabilities, {
        Capability.structure,
        Capability.geometry,
        Capability.components,
      });
    });

    test('P6 the placed instance: definition, parent, layer, transform', () {
      final doc = target();
      final e = sofa();
      doc.commands.execute(
          placeSymbol(doc, e, at: at, quarterTurns: 1, mirrored: true));
      final inst = instances(doc).single;
      final def = defOf(doc, 'sofa.three', 3);
      expect(inst.definition, def.handle);
      expect(inst.parent, doc.rootHandle);
      expect(inst.layer, ReservedHandles.layerZero);
      expect(inst.visible, isTrue);
      expect(
          inst.transform.toJson(),
          placementTransform(
                  at: at,
                  basePoint: e.definition.basePoint,
                  quarterTurns: 1,
                  mirrored: true)
              .toJson());
      expect(def.name, 'sofa.three@3');
      expect(def.basePoint, e.definition.basePoint);
      expect(def.children, isEmpty);
      expect(doc.components.get<SymbolComponent>(def.handle), sofaSymbol());
      // The copied leaves are the library's, field for field but the handle,
      // owner and geomIndex.
      final got = leavesOf(doc, def.handle);
      expect(got.length, e.leaves.length);
      for (var i = 0; i < got.length; i++) {
        final want = e.leaves[i];
        expect(got[i].payload, want.payload);
        expect(got[i].record.kind, want.record.kind);
        expect(got[i].record.owner, def.handle);
        expect(got[i].record.layer, want.record.layer);
        expect(got[i].record.linetype, want.record.linetype);
        expect(got[i].record.color, want.record.color);
        expect(got[i].record.lineweight, want.record.lineweight);
        expect(got[i].record.transparency, want.record.transparency);
        expect(got[i].record.flags, want.record.flags);
      }
    });

    test(
        'P7 two placements of one symbol: one definition, two instances '
        'with distinct handles, each at its own transform', () {
      final doc = target();
      final e = sofa();
      doc.commands.execute(placeSymbol(doc, e, at: at));
      final leafCount = doc.entities.liveCount;
      doc.commands.execute(
          placeSymbol(doc, e, at: Vector2(-77.5, 910.25), quarterTurns: 3));
      expect(doc.tree.definitions.length, 1);
      expect(doc.entities.liveCount, leafCount, reason: 'no second copy');
      expect(doc.components.withComponent<SymbolComponent>().length, 1);
      final is_ = instances(doc);
      expect(is_.length, 2);
      expect(is_[0].handle, isNot(is_[1].handle));
      expect(is_[0].definition, is_[1].definition);
      expect(is_[0].transform, isNot(is_[1].transform));
      expect(doc.commands.undoDepth, 2);
      // Undoing the second placement leaves the first, definition included.
      doc.commands.undo();
      expect(instances(doc).length, 1);
      expect(doc.tree.definitions.length, 1);
      expect(doc.entities.liveCount, leafCount);
      expect(doc.validate(), isEmpty);
    });

    group('style', () {
      const colour = TrueColor(0x33aa77);
      final styles = <String, InstanceStyle>{
        'color': const InstanceStyle(color: colour),
        'lineweight': const InstanceStyle(lineweight: 70),
        'transparency': const InstanceStyle(transparency: 96),
        'linetype':
            const InstanceStyle(linetype: ReservedHandles.continuousLinetype),
        'linetypeScale': const InstanceStyle(linetypeScale: 2.5),
      };
      const defaults = InstanceNode(
          handle: Handle(1),
          parent: Handle(1),
          transform: Transform2(1, 0, 0, 1, 0, 0),
          definition: Handle(1),
          layer: Handle(1));
      for (final f in styles.entries) {
        test('P8 ${f.key} reaches the instance, and only it', () {
          final doc = target();
          doc.commands.execute(placeSymbol(doc, sofa(),
              at: at, quarterTurns: 2, mirrored: true, style: f.value));
          final i = instances(doc).single;
          expect(i.color, f.key == 'color' ? colour : defaults.color);
          expect(
              i.lineweight, f.key == 'lineweight' ? 70 : defaults.lineweight);
          expect(i.transparency,
              f.key == 'transparency' ? 96 : defaults.transparency);
          expect(
              i.linetype,
              f.key == 'linetype'
                  ? ReservedHandles.continuousLinetype
                  : defaults.linetype);
          expect(i.linetypeScale,
              f.key == 'linetypeScale' ? 2.5 : defaults.linetypeScale);
        });
      }

      test('P8b the default style is InstanceNode\'s own defaults', () {
        const s = InstanceStyle();
        expect(s.color, defaults.color);
        expect(s.lineweight, defaults.lineweight);
        expect(s.transparency, defaults.transparency);
        expect(s.linetype, defaults.linetype);
        expect(s.linetypeScale, defaults.linetypeScale);
        final doc = target();
        doc.commands.execute(placeSymbol(doc, sofa(), at: at));
        final i = instances(doc).single;
        expect(i.color, const ByBlockColor());
        expect(i.lineweight, kByBlock);
        expect(i.transparency, kByBlock);
        expect(i.linetype, ReservedHandles.byBlockLinetype);
        expect(i.linetypeScale, 1.0);
      });

      test('P8c a reused definition still takes the new placement\'s style',
          () {
        final doc = target();
        doc.commands.execute(placeSymbol(doc, sofa(), at: at));
        doc.commands.execute(placeSymbol(doc, sofa(),
            at: at,
            style: const InstanceStyle(
                color: colour,
                lineweight: 70,
                transparency: 96,
                linetype: ReservedHandles.continuousLinetype,
                linetypeScale: 2.5)));
        final styled =
            instances(doc).firstWhere((i) => i.color != const ByBlockColor());
        expect(styled.color, colour);
        expect(styled.lineweight, 70);
        expect(styled.transparency, 96);
        expect(styled.linetype, ReservedHandles.continuousLinetype);
        expect(styled.linetypeScale, 2.5);
        expect(doc.tree.definitions.length, 1);
      });
    });

    test(
        'P9 undo is one step removing instance, leaves, component and '
        'definition; redo restores the same handles; dirty follows stateId',
        () {
      final doc = target();
      final e = sofa();
      final s0 = doc.commands.stateId;
      final depth0 = doc.commands.undoDepth;
      final cmd = placeSymbol(doc, e, at: at, quarterTurns: 3, mirrored: true);
      doc.commands.execute(cmd);
      final s1 = doc.commands.stateId;
      expect(s1, isNot(s0));
      expect(doc.commands.undoDepth, depth0 + 1);
      final def = defOf(doc, 'sofa.three', 3);
      final inst = instances(doc).single;
      final leafHandles = [
        for (final l in leavesOf(doc, def.handle)) l.record.handle
      ];
      expect(leafHandles.length, 4);
      final bytes1 = encoded(doc);

      doc.commands.undo();
      expect(doc.commands.stateId, s0);
      expect(doc.commands.undoDepth, depth0);
      expect(instances(doc), isEmpty);
      expect(doc.tree.definitions, isEmpty);
      expect(doc.entities.liveCount, 0);
      expect(doc.components.withComponent<SymbolComponent>(), isEmpty);
      expect(doc.tree[doc.rootHandle], isNotNull);
      expect(doc.validate(), isEmpty);

      doc.commands.redo();
      expect(doc.commands.stateId, s1);
      expect(doc.commands.undoDepth, depth0 + 1);
      expect(instances(doc).single.handle, inst.handle);
      expect(defOf(doc, 'sofa.three', 3).handle, def.handle);
      expect([for (final l in leavesOf(doc, def.handle)) l.record.handle],
          leafHandles);
      expect(encoded(doc), bytes1, reason: 'redo is byte-identical');
      expect(doc.validate(), isEmpty);

      // Undo again and place afresh: the compound's undo left nothing behind
      // that would make a second placement reuse an orphan.
      doc.commands.undo();
      doc.commands.execute(placeSymbol(doc, e, at: at));
      expect(doc.tree.definitions.length, 1);
      expect(doc.entities.liveCount, 4);
      expect(doc.components.withComponent<SymbolComponent>().length, 1);
    });

    test(
        'P10 handles of another document: the target already holds '
        'entities, a node and a definition at the handles the library uses',
        () {
      final doc = target();
      final e = sofa();
      // Library handles 4200 (definition), 4210-4213 (leaves) in the target,
      // as a different kind of thing each.
      doc.commands.execute(CompoundCommand([
        foreign(sofaDef.value, 'mine'),
        AddEntityCommand(
            record: leafRecord(sofaLine, doc.rootHandle, EntityKind.line),
            payload: linePayload(Vector2(1, 2), Vector2(301, 402))),
        AddNodeCommand(GroupNode(
            handle: const Handle(sofaPolyline),
            parent: doc.rootHandle,
            transform: Transform2.translation(5, 6),
            children: const [])),
        AddEntityCommand(
            record: leafRecord(sofaArc, doc.rootHandle, EntityKind.circle),
            payload: circlePayload(Vector2(9, 8), 7)),
        AddEntityCommand(
            record: leafRecord(sofaCircle, doc.rootHandle, EntityKind.circle),
            payload: circlePayload(Vector2(19, 18), 17)),
      ], label: 'Mine'));
      final before = encodedNoSeed(doc);
      expect(doc.handleSeed.current.value, greaterThanOrEqualTo(sofaCircle));

      doc.commands.execute(placeSymbol(doc, e, at: at, quarterTurns: 1));
      final def = defOf(doc, 'sofa.three', 3);
      expect(def.handle.value, greaterThan(sofaCircle));
      for (final l in leavesOf(doc, def.handle)) {
        expect(l.record.handle.value, greaterThan(sofaCircle));
      }
      // The target's own things are untouched.
      expect(doc.tree.definition(sofaDef)!.name, 'mine');
      expect(doc.entities.containsHandle(const Handle(sofaLine)), isTrue);
      expect(doc.tree[const Handle(sofaPolyline)], isA<GroupNode>());
      expect(leavesOf(doc, doc.rootHandle).map((l) => l.record.handle.value),
          [sofaLine, sofaArc, sofaCircle]);
      expect(
          leavesOf(doc, doc.rootHandle)
              .firstWhere((l) => l.record.handle.value == sofaLine)
              .payload,
          linePayload(Vector2(1, 2), Vector2(301, 402)));
      expect(doc.validate(), isEmpty);

      doc.commands.undo();
      expect(encodedNoSeed(doc), before,
          reason: 'undo restores the target exactly');
    });

    test(
        'P11 an older version beside a newer one: each copied, names '
        'distinct, each instance on its own definition', () {
      final doc = target();
      final v3 = sofa();
      final v4 = withVersion(v3, 4);
      final v2 = withVersion(v3, 2);
      doc.commands.execute(placeSymbol(doc, v3, at: at));
      final d3 = defOf(doc, 'sofa.three', 3);
      final d3Leaves = leavesOf(doc, d3.handle);

      doc.commands.execute(placeSymbol(doc, v4, at: at, mirrored: true));
      doc.commands.execute(placeSymbol(doc, v2, at: at, quarterTurns: 2));
      expect(doc.tree.definitions.length, 3);
      final d4 = defOf(doc, 'sofa.three', 4);
      final d2 = defOf(doc, 'sofa.three', 2);
      expect({d3.name, d4.name, d2.name},
          {'sofa.three@3', 'sofa.three@4', 'sofa.three@2'});
      expect({d3.handle, d4.handle, d2.handle}.length, 3);
      // v3's definition and leaves are untouched.
      expect(doc.tree.definition(d3.handle), d3);
      expect(leavesOf(doc, d3.handle).map((l) => l.payload).toList(),
          d3Leaves.map((l) => l.payload).toList());
      expect(doc.components.get<SymbolComponent>(d3.handle)!.version, 3);
      expect(doc.components.get<SymbolComponent>(d4.handle)!.version, 4);
      expect(doc.components.get<SymbolComponent>(d2.handle)!.version, 2);
      // Each instance names its own version's definition.
      final defs = instances(doc).map((i) => i.definition).toList();
      expect(defs, [d3.handle, d4.handle, d2.handle]);
      // Placing v4 again reuses v4, not v3 and not a third copy.
      doc.commands.execute(placeSymbol(doc, v4, at: at));
      expect(doc.tree.definitions.length, 3);
      expect(instances(doc).last.definition, d4.handle);
      expect(doc.validate(), isEmpty);
    });

    test(
        'P12 a foreign definition named like the symbol pushes the copy to '
        '#2, and a second foreign name to #3; the foreign ones are not reused',
        () {
      final doc = target();
      doc.commands.execute(foreign(901, 'sofa.three@3'));
      doc.commands.execute(placeSymbol(doc, sofa(), at: at));
      final copy = defOf(doc, 'sofa.three', 3);
      expect(copy.name, 'sofa.three@3#2');
      expect(copy.handle.value, isNot(901));
      expect(doc.tree.definition(const Handle(901))!.name, 'sofa.three@3');
      expect(doc.components.get<SymbolComponent>(const Handle(901)), isNull);
      expect(doc.tree.definitions.length, 2);
      expect(instances(doc).single.definition, copy.handle);

      final doc2 = target();
      doc2.commands.execute(foreign(901, 'sofa.three@3'));
      doc2.commands.execute(foreign(902, 'sofa.three@3#2'));
      doc2.commands.execute(placeSymbol(doc2, sofa(), at: at));
      expect(defOf(doc2, 'sofa.three', 3).name, 'sofa.three@3#3');
      expect({for (final d in doc2.tree.definitions) d.name}.length, 3);
    });

    test('P13 a component whose definition is gone is not reused', () {
      final doc = target();
      // Since spec 09c D11 a removed definition takes its component, so the
      // orphan is written after the removal: the kind a file saved before
      // 09c may still carry (D11 leaves those alone).
      doc.commands.execute(foreign(905, 'x'));
      doc.commands.execute(RemoveDefinitionCommand(const Handle(905)));
      doc.commands.execute(SetComponentCommand<SymbolComponent>(
          const Handle(905), sofaSymbol()));
      expect(doc.components.withComponent<SymbolComponent>().length, 1,
          reason: 'the orphan component is still there');
      doc.commands.execute(placeSymbol(doc, sofa(), at: at));
      final def = defOf(doc, 'sofa.three', 3);
      expect(def.handle.value, isNot(905));
      expect(instances(doc).single.definition, def.handle);
      expect(doc.validate(), isEmpty);
    });

    test(
        'P14 quarter-turn matrices in the file are exactly 0/±1 with no '
        '-0.0 in the encoded text', () {
      for (final mirrored in [false, true]) {
        for (var q = 0; q < 4; q++) {
          final doc = target();
          doc.commands.execute(placeSymbol(doc, sofa(),
              at: at, quarterTurns: q, mirrored: mirrored));
          final text = encoded(doc);
          expect(text.contains('-0.0'), isFalse,
              reason: 'q=$q mirrored=$mirrored');
          final json = jsonDecode(text) as Map;
          final node = (json['nodes'] as List)
              .cast<Map>()
              .firstWhere((n) => n['type'] == 'instance');
          final m = (node['transform'] as List).cast<num>();
          for (final v in m.take(4)) {
            expect([0, 1, -1], contains(v), reason: 'q=$q $m');
          }
        }
      }
    });

    test(
        'P15 save and load: byte-identical with instances and definitions, '
        'validate() empty', () {
      final doc = target();
      doc.commands.execute(placeSymbol(doc, sofa(),
          at: at,
          quarterTurns: 1,
          mirrored: true,
          style:
              const InstanceStyle(color: TrueColor(0x33aa77), lineweight: 70)));
      doc.commands.execute(placeSymbol(doc, entryOf('nightstand.single'),
          at: Vector2(-410.5, 77.75), quarterTurns: 3));
      doc.commands.execute(placeSymbol(doc, sofa(), at: Vector2(1, 2)));
      final diagnostics = doc.validate();
      // ignore: avoid_print
      print('P-6 item 3: validate() on the saved plan -> '
          '${diagnostics.length} diagnostics $diagnostics');
      expect(diagnostics, isEmpty);
      final bytes = encoded(doc);
      final loaded = reload(doc);
      expect(encoded(loaded), bytes);
      expect(loaded.validate(), isEmpty);
      expect(loaded.tree.definitions.length, 2);
      expect(instances(loaded).length, 3);
      expect(loaded.components.withComponent<SymbolComponent>().length, 2);
      expect(defOf(loaded, 'sofa.three', 3).name, 'sofa.three@3');
      // A placement after load reuses the loaded definition.
      loaded.commands.execute(placeSymbol(loaded, sofa(), at: at));
      expect(loaded.tree.definitions.length, 2);
      expect(instances(loaded).length, 4);
    });

    test(
        'P16 draw order: the copied leaves ascend with the library\'s '
        'order, and still do after undo, redo and save/load', () {
      final doc = target();
      final e = sofa();
      // Fixture: the file order of the leaves is not their handle order.
      expect(e.leaves.map((l) => l.record.handle.value).toList(),
          [sofaLine, sofaPolyline, sofaArc, sofaCircle]);
      doc.commands.execute(placeSymbol(doc, e, at: at));
      final def = defOf(doc, 'sofa.three', 3);

      void check(DraftDocument d, String when) {
        final got = leavesOf(d, defOf(d, 'sofa.three', 3).handle);
        expect(got.length, e.leaves.length, reason: when);
        for (var i = 0; i < got.length; i++) {
          expect(got[i].payload, e.leaves[i].payload,
              reason: '$when: leaf $i is the library\'s leaf $i');
          expect(got[i].record.kind, e.leaves[i].record.kind, reason: when);
          if (i > 0) {
            expect(got[i].record.handle.value,
                greaterThan(got[i - 1].record.handle.value),
                reason: when);
          }
        }
      }

      check(doc, 'placed');
      final handles = leavesOf(doc, def.handle).map((l) => l.record.handle);
      doc.commands.undo();
      doc.commands.redo();
      check(doc, 'redo');
      expect(leavesOf(doc, def.handle).map((l) => l.record.handle), handles);
      check(reload(doc), 'reloaded');
    });

    test(
        'P17 a denied components capability refuses the whole placement '
        'and leaves the document unchanged', () {
      const noComponents = DraftPermissions(
          transform: true, components: false, geometry: true, structure: true);
      final doc = target(permissions: noComponents);
      final before = encodedNoSeed(doc);
      final state = doc.commands.stateId;
      final depth = doc.commands.undoDepth;
      expect(() => doc.commands.execute(placeSymbol(doc, sofa(), at: at)),
          throwsA(isA<PermissionDeniedError>()));
      expect(encodedNoSeed(doc), before);
      expect(doc.commands.stateId, state);
      expect(doc.commands.undoDepth, depth);
      expect(doc.tree.definitions, isEmpty);
      expect(doc.entities.liveCount, 0);
      expect(instances(doc), isEmpty);
      expect(doc.components.withComponent<SymbolComponent>(), isEmpty);
    });

    test(
        'P24 a given transform is stored verbatim: its six doubles, through '
        'execute, undo, redo and save/load; at, the turns and the mirror '
        'are not used', () {
      final doc = target();
      final e = sofa();
      final (_, cos, sin) = rotations.first;
      final given = placementTransform(
          at: far,
          basePoint: Vector2(37.5, -912.25),
          rotation: (cos, sin)).multiply(Transform2.scale(-1, 1));
      final bytes = given.toJson();
      // Not what at, the turns or the mirror passed alongside would give.
      expect(
          placementTransform(
                  at: at,
                  basePoint: e.definition.basePoint,
                  quarterTurns: 1,
                  mirrored: true)
              .toJson(),
          isNot(bytes));
      final cmd = placeSymbol(doc, e,
          at: at, quarterTurns: 1, mirrored: true, transform: given);
      doc.commands.execute(cmd);
      expect(instances(doc).single.transform.toJson(), bytes);
      doc.commands.undo();
      expect(instances(doc), isEmpty);
      doc.commands.redo();
      expect(instances(doc).single.transform.toJson(), bytes);
      expect(instances(reload(doc)).single.transform.toJson(), bytes);
      expect(doc.tree.definitions.single.basePoint, e.definition.basePoint);
      expect(doc.validate(), isEmpty);
    });

    test('P18 a read-only document refuses too', () {
      final doc = target(permissions: DraftPermissions.readOnly);
      expect(() => doc.commands.execute(placeSymbol(doc, sofa(), at: at)),
          throwsA(isA<PermissionDeniedError>()));
      expect(doc.tree.definitions, isEmpty);
    });
  });

  group('the library entry is read-only to a placement', () {
    /// Every field of every leaf record and payload, and the entry's own
    /// fields, as text: a record has no `==`, a payload compares by identity.
    List<String> snapshot(SymbolEntry e) => [
          '${e.key}|${e.name}|${e.category}|${e.tags}|${e.version}',
          '${e.definition.handle.value}|${e.definition.name}|'
              '${e.definition.basePoint.x},${e.definition.basePoint.y}|'
              '${e.definition.children}',
          for (final l in e.leaves)
            [
              l.record.handle.value,
              l.record.owner.value,
              l.record.kind,
              l.record.layer.value,
              l.record.linetype.value,
              l.record.linetypeScale,
              l.record.geomIndex,
              encodeColor(l.record.color),
              l.record.lineweight,
              l.record.transparency,
              l.record.flags,
              l.record.text,
              l.record.tag,
              l.record.textStyle.value,
              l.record.textAttrs,
              'coords ${l.payload.coords.toList()}',
              'scalars ${l.payload.scalars.toList()}',
            ].join('|'),
        ];

    test('P19 placing rotated and mirrored, twice, leaves the entry byte-equal',
        () {
      final entry = sofa();
      final before = snapshot(entry);
      expect(entry.leaves, isNotEmpty);
      // A fresh document each (a copy) and a second placement into the first
      // (a reuse), both rotated and mirrored, off the origin.
      final a = target();
      a.commands.execute(placeSymbol(a, entry,
          at: Vector2(9000, -7000), quarterTurns: 1, mirrored: true));
      a.commands.execute(placeSymbol(a, entry,
          at: Vector2(-4000, 8000), quarterTurns: 3, mirrored: true));
      final b = target();
      b.commands.execute(placeSymbol(b, entry,
          at: Vector2(123, 456), quarterTurns: 2, mirrored: true));
      expect(instances(a), hasLength(2));
      expect(a.tree.definitions, hasLength(1));
      expect(snapshot(entry), before);
      // The copies are the entry's values, and they are not the entry's
      // buffers: changing a copy in the document cannot reach the library.
      final placedLeaves = leavesOf(a, a.tree.definitions.single.handle);
      expect(placedLeaves.length, entry.leaves.length);
      for (var i = 0; i < entry.leaves.length; i++) {
        expect(placedLeaves[i].payload.coords.toList(),
            entry.leaves[i].payload.coords.toList());
        expect(
            identical(
                placedLeaves[i].payload.coords, entry.leaves[i].payload.coords),
            isFalse);
      }
    });
  });
}
