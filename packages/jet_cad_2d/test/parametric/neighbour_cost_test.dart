import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/clients.dart';

/// Spec 07 D10: the far origin, rotated, so no fixture sits at the identity.
final Transform2 far = Transform2.translation(4500000, 1200000)
    .multiply(Transform2.rotation(math.pi / 6));

const int columns = 20;

/// Object [i]'s placement: a grid of thin segments, 800 apart along a row
/// (1000 long, so a row's neighbours overlap end to end) and 400 apart
/// across rows (so the row above and below overlap too), each with a small
/// turn of its own. An interior object has a handful of neighbours.
Transform2 cell(int i) => far
    .multiply(Transform2.translation(
        800.0 * (i % columns), 400.0 * (i ~/ columns) + 7.0 * (i % 2)))
    .multiply(Transform2.rotation(0.01 * (i % 3)));

const ClipRect segment = ClipRect(1000, 20);

/// [n] objects created in one edit; returns their handles, ascending.
List<Handle> grid(DraftDocument doc, int n) {
  final handles = [for (var i = 0; i < n; i++) doc.handleSeed.next()];
  doc.commands.execute(CompoundCommand([
    for (var i = 0; i < n; i++) ...[
      AddNodeCommand(GroupNode(
          handle: handles[i],
          parent: doc.rootHandle,
          transform: cell(i),
          children: const [])),
      SetComponentCommand<ClipRect>(handles[i], segment),
    ],
  ], label: 'Grid'));
  return handles;
}

DraftDocument gridDoc(ParametricCatalog catalog) {
  final doc = DraftDocument.empty();
  ParametricSystem(doc, catalog).install();
  return doc;
}

/// A root LINE among the objects, touching none of them.
DraftCommand line(DraftDocument doc, int k) => AddEntityCommand(
    record: draftRecord(doc.handleSeed.next(), doc.rootHandle, EntityKind.line),
    payload: linePayload(
        Vector2(4500000.0 + 3 * k, 1190000), Vector2(4500500.0, 1190300)));

/// Records the neighbour list every `generate` call sees (NC3).
final class RecordingType extends ParametricType<ClipRect> {
  RecordingType();
  final Map<Handle, List<Handle>> seen = {};

  /// The list `view.neighbours` itself returned, not a copy.
  final Map<Handle, List<Handle>> returned = {};
  @override
  Capability get editCapability => Capability.geometry;
  @override
  Aabb2 reach(ClipRect params, Transform2 toWorld) =>
      rectReach(params, toWorld);
  @override
  List<Generated> generate(ParametricView view, Handle self) {
    seen[self] = List.of(returned[self] = view.neighbours(self));
    return clippedRect(view, self);
  }
}

/// The O(n²) oracle: spec 06 D3's neighbour relation, from each object's
/// world reach, computed here independently of the engine.
Map<Handle, List<Handle>> oracle(DraftDocument doc, List<Handle> objects) {
  const tol = Tolerance.standard;
  final reach = {
    for (final h in objects)
      h: rectReach(
          doc.components.get<ClipRect>(h)!, doc.tree.accumulatedTransform(h)),
  };
  bool overlap(Aabb2 a, Aabb2 b) =>
      a.maxX - b.minX > tol.linear &&
      b.maxX - a.minX > tol.linear &&
      a.maxY - b.minY > tol.linear &&
      b.maxY - a.minY > tol.linear;
  return {
    for (final a in objects)
      a: [
        for (final b in objects)
          if (a != b && overlap(reach[a]!, reach[b]!)) b,
      ],
  };
}

double median(List<double> xs) => (xs.toList()..sort())[xs.length ~/ 2];

void main() {
  const n = 300;

  test('NC1 a root line drawn among 300 objects performs no overlap test', () {
    final doc = gridDoc(testCatalog());
    final objects = grid(doc, n);
    // The fixture is not degenerate: every object has a handful of
    // neighbours, none has none, none has all.
    final all = oracle(doc, objects);
    expect(all.values.map((l) => l.length).reduce(math.min), greaterThan(0));
    expect(all.values.map((l) => l.length).reduce(math.max), lessThan(9));
    final depth = doc.commands.undoDepth;
    final seed = doc.handleSeed.current.value;
    debugOverlapTests = 0;
    doc.commands.execute(line(doc, 0));
    expect(debugOverlapTests, 0);
    // The line landed at the root, as one undo step.
    final h = Handle(seed + 1);
    expect(doc.entities.ownerAt(doc.entities.slotOf(h)!), doc.rootHandle);
    expect(doc.commands.undoDepth, depth + 1);
  });

  test(
      'NC2 moving one of 300 objects performs fewer than 10 × n tests: '
      'exactly one search per closure member, plus the seed\'s before', () {
    final doc = gridDoc(testCatalog());
    final objects = grid(doc, n);
    final moved = objects[150];
    final before = oracle(doc, objects);
    debugOverlapTests = 0;
    doc.commands.execute(TransformNodeCommand(
        moved, cell(150).multiply(Transform2.translation(50, 0))));
    final tests = debugOverlapTests;
    final after = oracle(doc, objects);
    final closure = {moved, ...before[moved]!, ...after[moved]!};
    // Not degenerate: the seed has neighbours, so the closure members'
    // own searches are part of the exact count below.
    expect(closure.length, greaterThan(2));
    // At least the seed's own search, before and after: it did search.
    expect(tests, greaterThanOrEqualTo(2 * (n - 1)));
    expect(tests, lessThan(10 * n));
    // Each search tests every other object once: the seed before, and each
    // closure member after, the seed's after-search memoised for its own
    // generate.
    expect(tests, (1 + closure.length) * (n - 1));
    expect(ParametricSystem(doc, testCatalog()).drift(), isEmpty);
  });

  test(
      'NC3 every closure member of a move sees the oracle\'s neighbours, and '
      'the closure is the seed plus its neighbours before and after', () {
    final recording = RecordingType();
    final catalog = ParametricCatalog()
      ..register<ClipRect>(ClipRect.id, ClipRect.fromJson, recording);
    final doc = gridDoc(catalog);
    final objects = grid(doc, n);
    final moved = objects[150];
    final before = oracle(doc, objects);
    recording.seen.clear();
    // Half a row up and across: the moved object changes neighbours.
    doc.commands.execute(TransformNodeCommand(
        moved, cell(150).multiply(Transform2.translation(430, 200))));
    final after = oracle(doc, objects);
    expect(before[moved], isNotEmpty);
    expect(after[moved], isNotEmpty);
    expect(after[moved], isNot(before[moved]));
    // Both lost and gained: a closure of `after` alone, or of `before`
    // alone, would miss a member.
    expect(
        before[moved]!.toSet().difference(after[moved]!.toSet()), isNotEmpty);
    expect(
        after[moved]!.toSet().difference(before[moved]!.toSet()), isNotEmpty);
    final closure = {moved, ...before[moved]!, ...after[moved]!}.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    expect(
        recording.seen.keys.toList()
          ..sort((a, b) => a.value.compareTo(b.value)),
        closure);
    for (final h in closure) {
      expect(recording.seen[h], after[h], reason: h.toHex());
      // The memo is handed out, so it must not be writable.
      expect(() => recording.returned[h]!.add(h), throwsUnsupportedError,
          reason: h.toHex());
    }
    expect(ParametricSystem(doc, catalog).drift(), isEmpty);
  });

  test('NC4 timing: a line draw and a move among 100 / 300 / 600 (printed)',
      () {
    for (final n in [100, 300, 600]) {
      final doc = gridDoc(testCatalog());
      final objects = grid(doc, n);
      final moved = objects[n ~/ 2];
      final home = cell(n ~/ 2);
      final away = home.multiply(Transform2.translation(50, 0));
      double time(DraftCommand Function(int) edit, int k) {
        final sw = Stopwatch()..start();
        doc.commands.execute(edit(k));
        sw.stop();
        return sw.elapsedMicroseconds / 1000;
      }

      DraftCommand move(int k) =>
          TransformNodeCommand(moved, k.isEven ? away : home);
      // Untimed warm-ups for the JIT: two of each, so the object moves away
      // and back and every timed move is a real one.
      for (final k in [-2, -1]) {
        time((k) => line(doc, k), k);
        time(move, k);
      }
      final lines = [for (var k = 0; k < 5; k++) time((k) => line(doc, k), k)];
      final moves = [for (var k = 0; k < 5; k++) time(move, k)];
      print('NC4 n=$n line draw median ${median(lines).toStringAsFixed(2)} ms '
          '${lines.map((x) => x.toStringAsFixed(2)).toList()}; '
          'move median ${median(moves).toStringAsFixed(2)} ms '
          '${moves.map((x) => x.toStringAsFixed(2)).toList()}');
    }
  });
}
