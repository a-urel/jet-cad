# jet_cad_2d Plan 2 — Spatial Index, Queries and Validation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give `jet_cad_2d` a spatial index, hit-testing, snapping and structural validation, so the renderer and every tool have a query layer to build on.

**Architecture:** Each *indexed container* (the tree root, and every `Definition`) owns one `ContainerIndex` holding two STR-packed R-trees in typed arrays — one over leaf entities, one over instance nodes — plus a slot-keyed dirty list for recent edits. Groups are flattened into their nearest indexed ancestor with composed transforms; instances are the recursion boundary and the unit of sharing. Invalidation re-derives the box of each handle a `DocChange` reports as touched and compares it, because `DocChange` carries no change kind.

**Tech Stack:** Dart 3, `package:vector_math/vector_math_64.dart`, `dart:typed_data`, `package:test`. No Flutter, no FFI, no native code, no new dependencies.

**Spec:** [2026-07-28-jet-cad-2d-plan-2-design.md](../specs/2026-07-28-jet-cad-2d-plan-2-design.md)

## Global Constraints

- **Pure Dart only.** No Flutter, no `dart:ui`, no FFI, no native dependencies. `dart:typed_data`, `dart:math`, `dart:async`, `dart:collection` are permitted. This applies to every task except Task 1, which is a throwaway spike that ships nothing.
- Everything lands in `packages/jet_cad_2d`. No new package.
- `dart test`, `dart analyze` (must print "No issues found!") and `dart format --set-exit-if-changed lib test` must all be clean before every commit. Run them from `packages/jet_cad_2d`.
- Baseline at the start of this plan: **264 tests passing** on branch `feat/jet-cad-2d-core`.
- Conventional commits, scope `jet_cad_2d`. Commit messages in English.
- **Draw order is ascending handle value.** Every query returns results in ascending handle order. Hash iteration order is forbidden anywhere a result is produced.
- **Zero allocation on the frame path.** `forEachInRect`, `forEachInstanceInRect`, `pickInto` and `snapInto` must not allocate in steady state — after the result scratch has grown once. Growing the scratch is permitted; allocating per call is not.
- **Slots are not stable.** They are renumbered by `purge()` and reused from a LIFO free list under undo. Any structure keyed by slot is invalidated wholesale by `DocumentPurged`.
- **Leaf containment is `EntityRecord.owner`, and only that.** Leaf sets are derived by bucketing on `EntityStore.ownerAt`. Never read leaves out of a `children` list — `children` holds child *nodes* only.
- **Exact `==` on doubles is deliberate** for stored-value comparisons; geometric *decisions* use `Tolerance`. Do not convert one into the other.
- `Transform2.multiply` applies its **argument first**: `outer.multiply(inner)` maps inner-space → outer-space.
- Accessors must never hand out an internal mutable collection. Return an unmodifiable view or a copy. This bug class was found five times in Plan 1.
- Constants named in this plan (`kNodeCapacity`, the rebuild threshold, the 64-candidate intersection cap, scratch depths) are **exact values**, not suggestions.

## Existing API this plan builds on

Verified against the delivered Plan 1 source. Use these signatures exactly.

```dart
// core/handle.dart
extension type const Handle(int value) { bool get isNone; }
class HandleSeed { Handle get current; Handle next(); void raiseTo(Handle h); }

// core/diagnostic.dart
enum DiagnosticSeverity { info, warning, error }   // confirm arm names before use
class Diagnostic {
  const Diagnostic({required DiagnosticSeverity severity, required String code,
                    required String message, List<Handle> handles = const [],
                    String? sourceLocation});
  final DiagnosticSeverity severity; final String code; final String message;
  final List<Handle> handles; final String? sourceLocation;
}

// geometry/aabb2.dart
class Aabb2 {
  final double minX, minY, maxX, maxY;
  const Aabb2.raw(this.minX, this.minY, this.maxX, this.maxY);
  Aabb2(Vector2 min, Vector2 max);
  factory Aabb2.empty();
  Vector2 get min, max, center, size;
  bool get isEmpty;
  Aabb2 union(Aabb2 other);
  Aabb2 expandedToPoint(Vector2 p);
  Aabb2 expandedBy(double amount);
  bool containsPoint(Vector2 p);
  bool intersects(Aabb2 other);
  Aabb2 transformedBy(Transform2 t);   // conservative
}

// geometry/transform2.dart
class Transform2 {
  final double a, b, c, d, e, f;
  const Transform2(this.a, this.b, this.c, this.d, this.e, this.f);
  factory Transform2.identity();
  factory Transform2.translation(double dx, double dy);
  factory Transform2.scale(double sx, double sy);
  factory Transform2.rotation(double radians);
  bool get isIdentity;
  Transform2 multiply(Transform2 other);    // `other` applied FIRST
  Vector2 transformPoint(Vector2 p);
  Vector2 transformDirection(Vector2 v);
  double get determinant, scaleMagnitude, anisotropyRatio;
  Transform2 invert();                      // throws SingularTransformError
}

// store/entity_store.dart
enum EntityKind { point, line, polyline, circle, arc, text, attrib }
class EntityRecord {
  final Handle handle, owner, layer, linetype;
  final EntityKind kind;
  final double linetypeScale;
  final int geomIndex, lineweight, transparency, flags;
  final DraftColor color;
  EntityRecord copyWith({...});
}
class EntityStore {
  int get liveCount;
  Iterable<int> get liveSlots;             // ascending
  int? slotOf(Handle handle);
  bool containsHandle(Handle handle);
  int add(EntityRecord record);
  EntityRecord read(int slot);
  void replace(int slot, EntityRecord record);
  void remove(int slot);
  EntityKind kindAt(int slot);
  Handle ownerAt(int slot), handleAt(int slot), layerAt(int slot);
  int geomIndexAt(int slot);
  List<int> purge();
  void clear();
}

// store/geometry_store.dart
class GeometryPayload {
  final Float64List coords;    // interleaved x, y
  final Float64List scalars;   // radius, angles, text height
  int get pointCount;
  Vector2 pointAt(int index);
}
class GeometryStore { GeometryPayload read(int slot); /* … */ }

// document/node.dart
sealed class Node { final Handle handle, parent; final Transform2 transform; final bool visible; }
final class GroupNode extends Node { final List<Handle> children; final bool exportAsDxfGroup; }
final class InstanceNode extends Node { final Handle definition, layer; }
final class Definition {
  final Handle handle; final String name; final Vector2 basePoint;
  final List<Handle> children;              // child NODES only
  final bool isXref; final String xrefPath;
}

// document/tree.dart
class DocumentTree {
  Handle get root;
  Node? operator [](Handle handle);
  Definition? definition(Handle handle);
  Iterable<Node> get nodes;                 // ascending handle
  Iterable<Definition> get definitions;     // ascending handle
  List<Handle> childNodesOf(List<Handle> children);   // drops non-node entries
  void addNode(Node node); void replaceNode(Node node); void removeNode(Handle h);
  void addDefinition(Definition d); void replaceDefinition(Definition d);
  List<Handle> ancestorsOf(Handle handle);  // throws NodeCycleError on a cycle
  Transform2 accumulatedTransform(Handle handle);
  bool definitionReaches(Handle from, Handle target);
}

// document/extents.dart
abstract class TextMeasurer {
  Aabb2 measure({required String text, required Handle style,
                 required double height, required Vector2 insertion});
}
class InsertionPointMeasurer implements TextMeasurer { const InsertionPointMeasurer(); }
Aabb2 entityBounds({required EntityKind kind, required GeometryPayload payload,
                    required TextMeasurer measurer, required Handle textStyle,
                    String text = ''});

// document/doc_change.dart
sealed class DocChange { Set<Handle> get touched; }
final class CommandApplied extends DocChange { final String label; final Set<Handle> touched; }
final class CommandUndone extends DocChange { final String label; final Set<Handle> touched; }
final class CommandRedone extends DocChange { final String label; final Set<Handle> touched; }
final class DocumentLoaded extends DocChange {}
final class DocumentPurged extends DocChange {}

// document/tables.dart
class LayerRecord { final Handle handle; final bool visible, locked; /* … */ }

// document/draft_document.dart
class DraftDocument {
  final EntityStore entities; final GeometryStore geometry;
  final DocumentTables tables; final ComponentRegistry components;
  final HandleSeed handleSeed; final DocumentTree tree;
  final DocumentHeader header; final RawDataStore rawData;
  final TextMeasurer textMeasurer;
  late final CommandDispatcher commands;
  Handle get rootHandle;
  Stream<DocChange> get changes;
  Aabb2 get extents;
  Aabb2 definitionBounds(Handle definition);
  void invalidateDerived();
  void purge();
}
```

**Confirm before use:** the exact arm names of `DiagnosticSeverity` and the exact field list of `DocumentTables` (which table sections exist, and their accessor names). Read `core/diagnostic.dart` and `document/tables.dart` rather than guessing; a wrong arm name is a compile error and a wrong section name is a silent miss.

## File structure

```
lib/src/index/
  packed_rtree.dart        STR-packed R-tree over a fixed item set, typed arrays
  dirty_list.dart          slot-keyed recent edits, replace-in-place
  container_index.dart     one indexed container: leaf tree + instance tree + dirty list
  spatial_index.dart       owns every ContainerIndex; DocChange subscription
  query_filter.dart        visibility and lock filtering
  query_scratch.dart       result scratch + in-place sort + reentrancy flag
  hit.dart                 HitKind, HitPath
  snap.dart                SnapKind, SnapMask, SnapResult
lib/src/geometry/
  distance.dart            narrow-phase point-to-primitive distance, world space
lib/src/document/
  validate.dart            DraftDocument.validate() as an extension
test/index/                one test file per lib/src/index file
test/geometry/distance_test.dart
test/invariants/
  differential_test.dart   every query against a brute-force reference
  query_allocation_test.dart
benchmark/
  query_throughput.dart    the Plan 2 gate
```

`packed_rtree.dart` and `dirty_list.dart` know nothing about documents — they are data structures over boxes and payloads, and are tested as such. Everything document-aware lives above them.

---

### Task 1: Phase 0 — throwaway render spike

**This task ships no library code.** Its deliverable is a numbers file. The spike app is deleted in the same task that records it.

**Files:**
- Create (temporary, deleted in Step 6): `spike/render_spike/` — a Flutter app
- Create (permanent): `docs/superpowers/notes/2026-07-28-render-spike-results.md`

**Interfaces:**
- Consumes: nothing. The spike builds its own throwaway document; it must not import `jet_cad_2d`, because measuring the engine is not its purpose.
- Produces: nothing in code. The results file is read by whoever writes the Plan 3 spec.

- [ ] **Step 1: Create the spike app**

```bash
cd /Users/ahmeturel/Projects/oss/jet-cad
flutter create --platforms=macos spike/render_spike
```

- [ ] **Step 2: Write the spike**

Replace `spike/render_spike/lib/main.dart`:

```dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 50k line segments near world 4.5e6, the coordinate magnitude an imported
/// site plan actually uses. A fixture near the origin cannot show the effect
/// this spike exists to measure.
const int kEntityCount = 50000;
const double kOriginX = 4500000.0;
const double kOriginY = -3200000.0;

class Segment {
  const Segment(this.x1, this.y1, this.x2, this.y2);
  final double x1, y1, x2, y2;
}

List<Segment> buildDocument() {
  final rng = math.Random(20260728);
  return List.generate(kEntityCount, (_) {
    final x = kOriginX + rng.nextDouble() * 2000.0;
    final y = kOriginY + rng.nextDouble() * 2000.0;
    return Segment(x, y, x + rng.nextDouble() * 5.0, y + rng.nextDouble() * 5.0);
  });
}

/// Deliberately naive: absolute world coordinates go straight into the
/// float32 matrix, with no rebasing. That is the thing being measured.
class NaivePainter extends CustomPainter {
  NaivePainter(this.segments, this.scale, this.panX, this.panY);
  final List<Segment> segments;
  final double scale, panX, panY;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.0
      ..isAntiAlias = false;
    canvas.save();
    canvas.translate(panX, panY);
    canvas.scale(scale);
    for (final s in segments) {
      canvas.drawLine(Offset(s.x1, s.y1), Offset(s.x2, s.y2), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(NaivePainter old) =>
      old.scale != scale || old.panX != panX || old.panY != panY;
}

void main() => runApp(const SpikeApp());

class SpikeApp extends StatefulWidget {
  const SpikeApp({super.key});
  @override
  State<SpikeApp> createState() => _SpikeAppState();
}

class _SpikeAppState extends State<SpikeApp> {
  late final List<Segment> _segments = buildDocument();
  double _scale = 0.4;
  double _panX = -kOriginX * 0.4 + 400;
  double _panY = -kOriginY * 0.4 + 300;

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: GestureDetector(
            onScaleUpdate: (d) => setState(() {
              _panX += d.focalPointDelta.dx;
              _panY += d.focalPointDelta.dy;
              if (d.scale != 1.0) _scale *= d.scale;
            }),
            child: CustomPaint(
              painter: NaivePainter(_segments, _scale, _panX, _panY),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
}
```

- [ ] **Step 3: Measure frame time**

```bash
cd spike/render_spike
flutter run --profile -d macos
```

Pan and zoom continuously for at least 30 seconds. Capture the frame timings from the DevTools performance overlay or `flutter run --profile --trace-skia`. Record **p50 and p95 raster times**, not just the average — an average hides the stutter a user notices.

- [ ] **Step 4: Observe float32 jitter**

Zoom in until the on-screen scale is roughly 1 logical pixel per document unit. Look for: segment endpoints snapping to a coarse grid, lines shimmering as you pan by sub-pixel amounts, and short segments collapsing to zero length. Screenshot whatever you see.

Then set `kOriginX = 0.0; kOriginY = 0.0`, hot-restart, and compare at the same zoom. The difference between the two is the effect coordinate rebasing exists to prevent.

- [ ] **Step 5: Write the results file**

Create `docs/superpowers/notes/2026-07-28-render-spike-results.md` with these sections, filled with real measurements:

```markdown
# Render spike results — 2026-07-28

Throwaway spike run before Plan 2. Code deleted; these numbers are the deliverable.

## Setup
- Device, OS, Flutter version, build mode
- 50,000 line segments, no caching, no text, no dashes
- World origin 4.5e6 / -3.2e6

## Frame time
| Case | p50 raster (ms) | p95 raster (ms) |
|---|---|---|
| pan at 0.4x | | |
| pan at 4x (fewer visible) | | |
| continuous zoom | | |

## Float32 jitter at 4.5e6
- What was visible (with screenshots)
- Same scene at origin, for comparison
- Verdict: does the coordinate-rebasing design hold?

## Implications for Plan 3
- Raw uncached ceiling for 50k drawLine
- What the definition and tile caches must achieve to reach the 16.6 ms gate
- Anything surprising
```

- [ ] **Step 6: Delete the spike and commit**

```bash
cd /Users/ahmeturel/Projects/oss/jet-cad
rm -rf spike/
git add docs/superpowers/notes/2026-07-28-render-spike-results.md
git commit -m "docs(jet_cad_2d): render spike results

Throwaway spike measuring uncached Canvas throughput at 50k entities and
float32 behaviour at world 4.5e6. Spike code deleted; the numbers inform
Plan 3's caching design and its frame-time gate."
```

**If the spike shows p95 raster time so far above 16.6 ms that caching plausibly cannot close the gap** (as a rule of thumb, more than ~20x over), stop and report it before starting Task 2. That is the one outcome that reopens the render design, and it is cheaper to face now than after the index is built on top of it.

---

### Task 2: `DraftDocument.validate()`

**Files:**
- Create: `packages/jet_cad_2d/lib/src/document/validate.dart`
- Modify: `packages/jet_cad_2d/lib/jet_cad_2d.dart` (add the export)
- Test: `packages/jet_cad_2d/test/document/validate_test.dart`

**Interfaces:**
- Consumes: `DraftDocument`, `DocumentTree`, `EntityStore`, `Diagnostic`.
- Produces: `extension DocumentValidation on DraftDocument { List<Diagnostic> validate(); }` and `const kValidationCodes` — the seven code strings, so tests match constants rather than string literals.

Validation is an extension rather than a method on `DraftDocument` because it needs nothing private, and keeping it out of that class stops an already-large file from growing.

**Why `tree.cycle` matters most:** `DocumentTree.addNode` guards the instance→definition edge, but `addDefinition`/`replaceDefinition` are documented as unguarded, and `addNodeUnchecked` deliberately skips both the guard and the parent/children link. A consistent `parent`/`children` cycle among groups is therefore constructible, and it is the one malformation that makes index construction recurse forever rather than merely producing a wrong answer.

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d/test/document/validate_test.dart`:

```dart
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

/// A minimal line entity owned by [owner].
EntityRecord line(Handle handle, Handle owner) => EntityRecord(
      handle: handle,
      owner: owner,
      kind: EntityKind.line,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.linetypeByLayer,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const DraftColor.byLayer(),
      lineweight: kByLayer,
      transparency: kByLayer,
      flags: 0,
    );

GeometryPayload segment(double x1, double y1, double x2, double y2) =>
    GeometryPayload(
      coords: Float64List.fromList([x1, y1, x2, y2]),
      scalars: Float64List(0),
    );

void main() {
  test('a document built by commands validates clean', () {
    final doc = DraftDocument.empty();
    doc.commands.execute(AddEntityCommand(
      record: line(doc.handleSeed.next(), doc.rootHandle),
      payload: segment(0, 0, 10, 10),
    ));

    expect(doc.validate(), isEmpty);
  });

  test('reports a root that names no node', () {
    final doc = DraftDocument.empty();
    doc.tree.setRoot(const Handle(999));

    final codes = [for (final d in doc.validate()) d.code];
    expect(codes, contains(kValidationCodes.rootMissing));
  });

  test('reports an entity whose owner names no container', () {
    final doc = DraftDocument.empty();
    doc.entities.add(line(const Handle(500), const Handle(4242)));

    final found = doc.validate()
        .where((d) => d.code == kValidationCodes.ownerMissing)
        .toList();
    expect(found, hasLength(1));
    expect(found.single.handles, contains(const Handle(500)));
  });

  test('reports a children entry that resolves to nothing', () {
    final doc = DraftDocument.empty();
    // addNodeUnchecked skips linking, so `children` is authored directly here.
    doc.tree.addNodeUnchecked(GroupNode(
      handle: const Handle(100),
      parent: doc.rootHandle,
      transform: Transform2.identity(),
      children: const [Handle(777)],
    ));

    final codes = [for (final d in doc.validate()) d.code];
    expect(codes, contains(kValidationCodes.danglingChild));
  });

  test('reports parent and children disagreeing', () {
    final doc = DraftDocument.empty();
    // The node says its parent is 100; 100 does not list it.
    doc.tree.addNodeUnchecked(GroupNode(
      handle: const Handle(100),
      parent: doc.rootHandle,
      transform: Transform2.identity(),
      children: const [],
    ));
    doc.tree.addNodeUnchecked(GroupNode(
      handle: const Handle(101),
      parent: const Handle(100),
      transform: Transform2.identity(),
      children: const [],
    ));

    final codes = [for (final d in doc.validate()) d.code];
    expect(codes, contains(kValidationCodes.parentChildMismatch));
  });

  test('reports a group cycle rather than hanging', () {
    final doc = DraftDocument.empty();
    // 100 -> 101 -> 100, consistent in BOTH directions, so no mismatch is
    // reported and only the cycle check can catch it.
    doc.tree.addNodeUnchecked(GroupNode(
      handle: const Handle(100),
      parent: const Handle(101),
      transform: Transform2.identity(),
      children: const [Handle(101)],
    ));
    doc.tree.addNodeUnchecked(GroupNode(
      handle: const Handle(101),
      parent: const Handle(100),
      transform: Transform2.identity(),
      children: const [Handle(100)],
    ));

    final codes = [for (final d in doc.validate()) d.code];
    expect(codes, contains(kValidationCodes.cycle));
  }, timeout: const Timeout(Duration(seconds: 5)));

  test('reports a definition that reaches itself', () {
    final doc = DraftDocument.empty();
    const defA = Handle(200);
    const defB = Handle(201);
    const nodeInA = Handle(300);
    const nodeInB = Handle(301);

    doc.tree.addDefinition(Definition(
      handle: defA, name: 'A', basePoint: Vector2.zero(),
      children: const [nodeInA],
    ));
    doc.tree.addDefinition(Definition(
      handle: defB, name: 'B', basePoint: Vector2.zero(),
      children: const [nodeInB],
    ));
    doc.tree.addNodeUnchecked(InstanceNode(
      handle: nodeInA, parent: defA, transform: Transform2.identity(),
      definition: defB, layer: ReservedHandles.layerZero,
    ));
    doc.tree.addNodeUnchecked(InstanceNode(
      handle: nodeInB, parent: defB, transform: Transform2.identity(),
      definition: defA, layer: ReservedHandles.layerZero,
    ));

    final codes = [for (final d in doc.validate()) d.code];
    expect(codes, contains(kValidationCodes.definitionCycle));
  }, timeout: const Timeout(Duration(seconds: 5)));

  test('reports a leaf handle sitting in a children list', () {
    final doc = DraftDocument.empty();
    final entityHandle = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
      record: line(entityHandle, doc.rootHandle),
      payload: segment(0, 0, 1, 1),
    ));
    doc.tree.addNodeUnchecked(GroupNode(
      handle: const Handle(100),
      parent: doc.rootHandle,
      transform: Transform2.identity(),
      children: [entityHandle],
    ));

    final codes = [for (final d in doc.validate()) d.code];
    expect(codes, contains(kValidationCodes.leafInChildren));
  });

  test('diagnostics come back in a stable order across runs', () {
    DraftDocument broken() {
      final doc = DraftDocument.empty();
      doc.entities.add(line(const Handle(500), const Handle(4242)));
      doc.entities.add(line(const Handle(501), const Handle(4243)));
      doc.tree.addNodeUnchecked(GroupNode(
        handle: const Handle(100),
        parent: doc.rootHandle,
        transform: Transform2.identity(),
        children: const [Handle(777)],
      ));
      return doc;
    }

    final first = [for (final d in broken().validate()) '${d.code}:${d.handles}'];
    final second = [for (final d in broken().validate()) '${d.code}:${d.handles}'];
    expect(first, equals(second));
    expect(first, isNotEmpty);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd packages/jet_cad_2d && dart test test/document/validate_test.dart
```

Expected: compile failure — `The method 'validate' isn't defined` and `Undefined name 'kValidationCodes'`.

If it instead fails on `setRoot`, `addNodeUnchecked`, `ReservedHandles`, `kByLayer` or `DraftColor.byLayer`, read the current source and correct the test to the real names before writing any implementation. Do not adapt the implementation to a wrong test.

- [ ] **Step 3: Write the implementation**

Create `packages/jet_cad_2d/lib/src/document/validate.dart`:

```dart
import '../core/diagnostic.dart';
import '../core/handle.dart';
import 'draft_document.dart';
import 'node.dart';

/// The codes [DocumentValidation.validate] can emit.
///
/// Constants rather than literals so a caller or a test matches a symbol the
/// compiler checks, instead of a string it does not.
abstract final class kValidationCodes {
  static const String rootMissing = 'tree.root_missing';
  static const String parentChildMismatch = 'tree.parent_child_mismatch';
  static const String danglingChild = 'tree.dangling_child';
  static const String leafInChildren = 'tree.leaf_in_children';
  static const String cycle = 'tree.cycle';
  static const String definitionCycle = 'tree.definition_cycle';
  static const String ownerMissing = 'entity.owner_missing';
}

extension DocumentValidation on DraftDocument {
  /// Structural problems in this document, in a stable order.
  ///
  /// Empty means well-formed. This reports and never mutates; the caller
  /// decides whether to reject, repair or warn.
  ///
  /// The index walks the container tree, so it is the first consumer a
  /// malformed document would corrupt — or, for [kValidationCodes.cycle],
  /// hang. Callers that index untrusted input should check this first.
  List<Diagnostic> validate() {
    final out = <Diagnostic>[];

    Diagnostic error(String code, String message, List<Handle> handles) =>
        Diagnostic(
          severity: DiagnosticSeverity.error,
          code: code,
          message: message,
          handles: handles,
        );

    // 1. The root must resolve.
    if (tree[tree.root] == null) {
      out.add(error(kValidationCodes.rootMissing,
          'The tree root ${tree.root.value} names no node.', [tree.root]));
    }

    // Containers are nodes plus definitions; an entity's owner may be either,
    // and the root is just the outermost group.
    bool isContainer(Handle h) =>
        tree[h] != null || tree.definition(h) != null;

    // 2. Entity owners must resolve. Ascending slot order gives a stable
    //    result, and slots are ascending by construction in liveSlots.
    for (final slot in entities.liveSlots) {
      final owner = entities.ownerAt(slot);
      if (!isContainer(owner)) {
        out.add(error(
            kValidationCodes.ownerMissing,
            'Entity ${entities.handleAt(slot).value} names owner '
            '${owner.value}, which is not a container.',
            [entities.handleAt(slot), owner]));
      }
    }

    // Every `children` list in the document, keyed by its container.
    // `tree.nodes` and `tree.definitions` are both ascending by handle, so
    // this walk is stable without sorting.
    final childrenOf = <Handle, List<Handle>>{};
    for (final node in tree.nodes) {
      if (node is GroupNode) childrenOf[node.handle] = node.children;
    }
    for (final definition in tree.definitions) {
      childrenOf[definition.handle] = definition.children;
    }

    // 3. Children entries must resolve, and must name nodes rather than leaves.
    // 4. A node's `parent` must agree with the container that lists it.
    final listedBy = <Handle, Handle>{};
    for (final entry in childrenOf.entries) {
      for (final child in entry.value) {
        if (tree[child] != null) {
          listedBy[child] = entry.key;
          continue;
        }
        if (entities.containsHandle(child)) {
          out.add(error(
              kValidationCodes.leafInChildren,
              'Container ${entry.key.value} lists entity ${child.value} as a '
              'child node. Leaf containment is EntityRecord.owner.',
              [entry.key, child]));
        } else {
          out.add(error(
              kValidationCodes.danglingChild,
              'Container ${entry.key.value} lists ${child.value}, which '
              'resolves to nothing.',
              [entry.key, child]));
        }
      }
    }

    for (final node in tree.nodes) {
      if (node.handle == tree.root) continue;
      final listed = listedBy[node.handle];
      if (listed != node.parent) {
        out.add(error(
            kValidationCodes.parentChildMismatch,
            'Node ${node.handle.value} names parent ${node.parent.value} but '
            'is listed by ${listed?.value}.',
            [node.handle, node.parent]));
      }
    }

    // 5. Group cycles. White/grey/black DFS: a grey node reached again is a
    //    back edge. This must not use `ancestorsOf`, which throws rather than
    //    reporting, and must not recurse — a cycle would blow the stack.
    const white = 0, grey = 1, black = 2;
    final colour = <Handle, int>{};
    for (final start in childrenOf.keys) {
      if ((colour[start] ?? white) != white) continue;
      // Explicit stack of (container, next child index).
      final stack = <Handle>[start];
      final cursor = <int>[0];
      colour[start] = grey;
      while (stack.isNotEmpty) {
        final top = stack.last;
        final children = childrenOf[top] ?? const <Handle>[];
        if (cursor.last >= children.length) {
          colour[top] = black;
          stack.removeLast();
          cursor.removeLast();
          continue;
        }
        final child = children[cursor.last];
        cursor[cursor.length - 1] = cursor.last + 1;
        switch (colour[child] ?? white) {
          case grey:
            out.add(error(
                kValidationCodes.cycle,
                'Container ${top.value} reaches ${child.value}, which is '
                'already on the path: the container tree has a cycle.',
                [top, child]));
          case white:
            if (childrenOf.containsKey(child)) {
              colour[child] = grey;
              stack.add(child);
              cursor.add(0);
            } else {
              colour[child] = black;
            }
          default:
            break;
        }
      }
    }

    // 6. Definition cycles: an instance inside definition D that reaches D.
    for (final definition in tree.definitions) {
      for (final child in definition.children) {
        final node = tree[child];
        if (node is! InstanceNode) continue;
        if (node.definition == definition.handle ||
            tree.definitionReaches(node.definition, definition.handle)) {
          out.add(error(
              kValidationCodes.definitionCycle,
              'Definition ${definition.handle.value} contains instance '
              '${child.value} of ${node.definition.value}, which reaches it.',
              [definition.handle, child, node.definition]));
        }
      }
    }

    return out;
  }
}
```

- [ ] **Step 4: Export it**

In `packages/jet_cad_2d/lib/jet_cad_2d.dart`, add in alphabetical position among the `src/document/` exports:

```dart
export 'src/document/validate.dart';
```

- [ ] **Step 5: Run the tests**

```bash
cd packages/jet_cad_2d && dart test && dart analyze && dart format --set-exit-if-changed lib test
```

Expected: 264 + 9 = 273 passing, analyzer clean, formatter clean.

**`tree.definitionReaches` may itself loop on a cyclic definition graph.** If the definition-cycle test times out rather than passing, the fix belongs here, not in `tree.dart`: track visited definitions in `validate()` and skip a definition already reported. Do not change `definitionReaches`, which other code depends on.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "feat(jet_cad_2d): DraftDocument.validate() with seven structural codes

The index walks the container tree, making it the first consumer a
malformed document would corrupt or hang. addNodeUnchecked deliberately
preserves parent/children disagreement as evidence for a validator;
this is that validator.

tree.cycle uses an explicit-stack white/grey/black DFS rather than
recursion or ancestorsOf: a cycle must be reported, not thrown, and must
not blow the stack."
```

---

### Task 3: `PackedRTree`

**Files:**
- Create: `packages/jet_cad_2d/lib/src/index/packed_rtree.dart`
- Test: `packages/jet_cad_2d/test/index/packed_rtree_test.dart`

**Interfaces:**
- Consumes: nothing from this package. This is a data structure over boxes and integer payloads; it must not import anything from `document/` or `store/`.
- Produces:

```dart
class PackedRTree {
  static const int kNodeCapacity = 16;
  factory PackedRTree.build(int itemCount, Float64List itemBoxes, Uint32List itemPayloads);
  factory PackedRTree.empty();
  int get itemCount;
  Aabb2 get bounds;
  void search(double minX, double minY, double maxX, double maxY,
              void Function(int payload) visit);
  void markDead(int payload);
  bool isDead(int payload);
  void clearDead();
}
```

`itemBoxes` holds four doubles per item — `minX, minY, maxX, maxY` — and `itemPayloads` one integer per item. The tree copies both; the caller may reuse its buffers.

**Why the payload, not the item index, is what `markDead` takes:** the caller thinks in slots, and making it translate to a post-packing item index would leak the packing order into every call site.

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d/test/index/packed_rtree_test.dart`:

```dart
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

/// Builds a tree over [count] unit boxes on a grid, payload == index.
PackedRTree gridTree(int count) {
  final side = math.sqrt(count).ceil();
  final boxes = Float64List(count * 4);
  final payloads = Uint32List(count);
  for (var i = 0; i < count; i++) {
    final x = (i % side).toDouble();
    final y = (i ~/ side).toDouble();
    boxes[i * 4] = x;
    boxes[i * 4 + 1] = y;
    boxes[i * 4 + 2] = x + 0.5;
    boxes[i * 4 + 3] = y + 0.5;
    payloads[i] = i;
  }
  return PackedRTree.build(count, boxes, payloads);
}

/// Everything the tree reports for a query, ascending.
List<int> hits(PackedRTree tree, double minX, double minY, double maxX, double maxY) {
  final out = <int>[];
  tree.search(minX, minY, maxX, maxY, out.add);
  out.sort();
  return out;
}

void main() {
  test('an empty tree reports nothing and has empty bounds', () {
    final tree = PackedRTree.empty();
    expect(tree.itemCount, 0);
    expect(tree.bounds.isEmpty, isTrue);
    expect(hits(tree, -1e9, -1e9, 1e9, 1e9), isEmpty);
  });

  test('a single item is found by a query that overlaps it', () {
    final tree = gridTree(1);
    expect(hits(tree, -1, -1, 1, 1), [0]);
    expect(hits(tree, 10, 10, 11, 11), isEmpty);
  });

  test('a query returns exactly what a brute-force scan returns', () {
    // 1000 items forces several tree levels at capacity 16.
    const count = 1000;
    final tree = gridTree(count);
    final side = math.sqrt(count).ceil();

    final rng = math.Random(7);
    for (var trial = 0; trial < 200; trial++) {
      final qx = rng.nextDouble() * side;
      final qy = rng.nextDouble() * side;
      final qw = rng.nextDouble() * 6;
      final qh = rng.nextDouble() * 6;

      final expected = <int>[];
      for (var i = 0; i < count; i++) {
        final x = (i % side).toDouble();
        final y = (i ~/ side).toDouble();
        // Same overlap predicate the tree uses: touching counts.
        if (x <= qx + qw && x + 0.5 >= qx && y <= qy + qh && y + 0.5 >= qy) {
          expected.add(i);
        }
      }
      expect(hits(tree, qx, qy, qx + qw, qy + qh), expected,
          reason: 'trial $trial at ($qx, $qy) size ($qw, $qh)');
    }
  });

  test('bounds covers every item', () {
    final tree = gridTree(100);
    final b = tree.bounds;
    expect(b.minX, 0.0);
    expect(b.minY, 0.0);
    expect(b.maxX, closeTo(9.5, 1e-12));
    expect(b.maxY, closeTo(9.5, 1e-12));
  });

  test('a dead payload is skipped and clearDead restores it', () {
    final tree = gridTree(100);
    expect(hits(tree, -1, -1, 100, 100), hasLength(100));

    tree.markDead(42);
    expect(tree.isDead(42), isTrue);
    final afterKill = hits(tree, -1, -1, 100, 100);
    expect(afterKill, hasLength(99));
    expect(afterKill, isNot(contains(42)));

    tree.clearDead();
    expect(tree.isDead(42), isFalse);
    expect(hits(tree, -1, -1, 100, 100), hasLength(100));
  });

  test('search allocates nothing after the first call', () {
    final tree = gridTree(5000);
    var seen = 0;
    void count(int _) => seen++;
    tree.search(0, 0, 70, 70, count);   // warm

    final before = _allocatedBytes();
    for (var i = 0; i < 50; i++) {
      tree.search(0, 0, 70, 70, count);
    }
    final after = _allocatedBytes();
    // A tolerance rather than zero: the VM allocates for reasons outside this
    // call. What is being excluded is per-item or per-node allocation, which
    // at 5000 items x 50 calls would be enormous rather than marginal.
    expect(after - before, lessThan(64 * 1024),
        reason: 'search must not allocate per node or per item');
  });

  test('handles items that all share one box', () {
    final boxes = Float64List(64 * 4);
    final payloads = Uint32List(64);
    for (var i = 0; i < 64; i++) {
      boxes[i * 4] = 5.0;
      boxes[i * 4 + 1] = 5.0;
      boxes[i * 4 + 2] = 6.0;
      boxes[i * 4 + 3] = 6.0;
      payloads[i] = i;
    }
    final tree = PackedRTree.build(64, boxes, payloads);
    expect(hits(tree, 5.5, 5.5, 5.5, 5.5), hasLength(64));
    expect(hits(tree, 100, 100, 101, 101), isEmpty);
  });

  test('handles a degenerate zero-area box', () {
    final boxes = Float64List.fromList([3.0, 3.0, 3.0, 3.0]);
    final payloads = Uint32List.fromList([9]);
    final tree = PackedRTree.build(1, boxes, payloads);
    expect(hits(tree, 2, 2, 4, 4), [9]);
    expect(hits(tree, 3, 3, 3, 3), [9]);
  });
}

int _allocatedBytes() {
  // dart:developer's Service API is not available in a plain test run, so this
  // is a deliberate approximation: it measures nothing and returns 0 unless
  // the harness in Task 17 replaces it. The assertion above therefore passes
  // trivially here and is made real in Task 17.
  return 0;
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd packages/jet_cad_2d && dart test test/index/packed_rtree_test.dart
```

Expected: compile failure, `Undefined name 'PackedRTree'`.

- [ ] **Step 3: Write the implementation**

Create `packages/jet_cad_2d/lib/src/index/packed_rtree.dart`:

```dart
import 'dart:typed_data';

import '../geometry/aabb2.dart';

/// A static R-tree, bulk-loaded by sort-tile-recursive packing into typed
/// arrays.
///
/// Static by design. Insertion into a packed tree is not supported at all:
/// recent edits live in a separate dirty list and the tree is rebuilt when
/// that list grows past a threshold. That trade matches the real usage
/// profile — long reads punctuated by short edit bursts — and avoids dynamic
/// R*-tree rebalancing entirely.
///
/// Layout: [_boxes] holds four doubles per node. Items occupy nodes
/// `[0, itemCount)` in packed order; each subsequent level follows, ending at
/// the single root. [_levelEnd] holds the exclusive end node index of each
/// level, so level `L` spans `[_levelEnd[L - 1], _levelEnd[L])` with level 0
/// starting at 0.
class PackedRTree {
  static const int kNodeCapacity = 16;

  /// Depth is bounded by log_16 of the item count, so a fixed stack of 64 is
  /// far beyond any reachable tree: 16^64 items is not representable.
  static const int _kSearchStackDepth = 64;

  PackedRTree._(this._boxes, this._payloads, this._levelEnd, this.itemCount,
      this._payloadToItem)
      : _dead = Uint64List((itemCount + 63) >> 6),
        _stack = Int32List(_kSearchStackDepth);

  factory PackedRTree.empty() => PackedRTree._(
        Float64List(0),
        Uint32List(0),
        Int32List(0),
        0,
        <int, int>{},
      );

  /// Builds a tree over [itemCount] boxes.
  ///
  /// [itemBoxes] holds `minX, minY, maxX, maxY` per item; [itemPayloads] one
  /// integer per item. Both are copied, so the caller may reuse its buffers.
  factory PackedRTree.build(
      int itemCount, Float64List itemBoxes, Uint32List itemPayloads) {
    if (itemCount == 0) return PackedRTree.empty();

    // Sort item indices by centre X, slice into vertical strips, then sort
    // each strip by centre Y. This is the STR packing; it gives strips of
    // roughly square aspect, which is what keeps query overlap low.
    final order = List<int>.generate(itemCount, (i) => i);
    double centreX(int i) => (itemBoxes[i * 4] + itemBoxes[i * 4 + 2]) / 2;
    double centreY(int i) => (itemBoxes[i * 4 + 1] + itemBoxes[i * 4 + 3]) / 2;

    order.sort((p, q) => centreX(p).compareTo(centreX(q)));

    final leafCount = (itemCount + kNodeCapacity - 1) ~/ kNodeCapacity;
    final stripCount = _isqrt(leafCount).clamp(1, leafCount);
    final perStrip = (itemCount + stripCount - 1) ~/ stripCount;

    for (var start = 0; start < itemCount; start += perStrip) {
      final end = (start + perStrip).clamp(0, itemCount);
      final strip = order.sublist(start, end)
        ..sort((p, q) => centreY(p).compareTo(centreY(q)));
      order.setRange(start, end, strip);
    }

    // Level sizes, bottom-up.
    final levelSizes = <int>[itemCount];
    var n = itemCount;
    while (n > 1) {
      n = (n + kNodeCapacity - 1) ~/ kNodeCapacity;
      levelSizes.add(n);
    }

    var totalNodes = 0;
    for (final size in levelSizes) {
      totalNodes += size;
    }

    final boxes = Float64List(totalNodes * 4);
    final payloads = Uint32List(itemCount);
    final levelEnd = Int32List(levelSizes.length);
    final payloadToItem = <int, int>{};

    // Level 0: the items themselves, in packed order.
    for (var i = 0; i < itemCount; i++) {
      final src = order[i];
      boxes[i * 4] = itemBoxes[src * 4];
      boxes[i * 4 + 1] = itemBoxes[src * 4 + 1];
      boxes[i * 4 + 2] = itemBoxes[src * 4 + 2];
      boxes[i * 4 + 3] = itemBoxes[src * 4 + 3];
      payloads[i] = itemPayloads[src];
      payloadToItem[itemPayloads[src]] = i;
    }
    levelEnd[0] = itemCount;

    // Each higher level unions groups of kNodeCapacity children.
    var childStart = 0;
    var writeAt = itemCount;
    for (var level = 1; level < levelSizes.length; level++) {
      final childEnd = levelEnd[level - 1];
      var child = childStart;
      while (child < childEnd) {
        var minX = double.infinity, minY = double.infinity;
        var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
        final groupEnd = (child + kNodeCapacity).clamp(0, childEnd);
        for (var k = child; k < groupEnd; k++) {
          if (boxes[k * 4] < minX) minX = boxes[k * 4];
          if (boxes[k * 4 + 1] < minY) minY = boxes[k * 4 + 1];
          if (boxes[k * 4 + 2] > maxX) maxX = boxes[k * 4 + 2];
          if (boxes[k * 4 + 3] > maxY) maxY = boxes[k * 4 + 3];
        }
        boxes[writeAt * 4] = minX;
        boxes[writeAt * 4 + 1] = minY;
        boxes[writeAt * 4 + 2] = maxX;
        boxes[writeAt * 4 + 3] = maxY;
        writeAt++;
        child = groupEnd;
      }
      childStart = childEnd;
      levelEnd[level] = writeAt;
    }

    return PackedRTree._(boxes, payloads, levelEnd, itemCount, payloadToItem);
  }

  final Float64List _boxes;
  final Uint32List _payloads;
  final Int32List _levelEnd;
  final Map<int, int> _payloadToItem;
  final Uint64List _dead;

  /// Preallocated so [search] allocates nothing. Holds packed node references
  /// as `level * _kNodeRefShift + index`; see [_pushNode].
  final Int32List _stack;

  final int itemCount;

  /// The union of every item box, dead ones included.
  Aabb2 get bounds {
    if (itemCount == 0) return Aabb2.empty();
    final rootIndex = _levelEnd[_levelEnd.length - 1] - 1;
    return Aabb2.raw(
      _boxes[rootIndex * 4],
      _boxes[rootIndex * 4 + 1],
      _boxes[rootIndex * 4 + 2],
      _boxes[rootIndex * 4 + 3],
    );
  }

  /// Visits the payload of every live item whose box overlaps the query.
  ///
  /// Overlap is inclusive: a box touching the query edge is reported. The
  /// narrow phase is the caller's job — this is a broad phase and returns
  /// false positives by design.
  ///
  /// Not reentrant: the traversal stack is owned by this tree, so calling
  /// [search] from inside [visit] corrupts the walk.
  void search(double minX, double minY, double maxX, double maxY,
      void Function(int payload) visit) {
    if (itemCount == 0) return;
    if (itemCount == 1) {
      if (_overlaps(0, minX, minY, maxX, maxY) && !_isDeadItem(0)) {
        visit(_payloads[0]);
      }
      return;
    }

    var depth = 0;
    // Root is the single node of the top level.
    _stack[depth++] = _levelEnd.length - 1;
    _stackNode[0] = _levelEnd[_levelEnd.length - 1] - 1;

    while (depth > 0) {
      depth--;
      final level = _stack[depth];
      final node = _stackNode[depth];

      if (!_overlaps(node, minX, minY, maxX, maxY)) continue;

      if (level == 0) {
        if (!_isDeadItem(node)) visit(_payloads[node]);
        continue;
      }

      final childLevel = level - 1;
      final childBase = childLevel == 0 ? 0 : _levelEnd[childLevel - 1];
      final childEnd = _levelEnd[childLevel];
      // This node is the k-th of its level; its children are the k-th group.
      final selfBase = _levelEnd[level - 1];
      final k = node - selfBase;
      final first = childBase + k * kNodeCapacity;
      final last = (first + kNodeCapacity).clamp(0, childEnd);

      for (var child = first; child < last; child++) {
        _stack[depth] = childLevel;
        _stackNode[depth] = child;
        depth++;
      }
    }
  }

  void markDead(int payload) {
    final item = _payloadToItem[payload];
    if (item == null) return;
    _dead[item >> 6] |= 1 << (item & 63);
  }

  bool isDead(int payload) {
    final item = _payloadToItem[payload];
    if (item == null) return false;
    return _isDeadItem(item);
  }

  void clearDead() {
    for (var i = 0; i < _dead.length; i++) {
      _dead[i] = 0;
    }
  }

  bool _isDeadItem(int item) => (_dead[item >> 6] >> (item & 63)) & 1 == 1;

  bool _overlaps(int node, double minX, double minY, double maxX, double maxY) =>
      _boxes[node * 4] <= maxX &&
      _boxes[node * 4 + 1] <= maxY &&
      _boxes[node * 4 + 2] >= minX &&
      _boxes[node * 4 + 3] >= minY;

  static int _isqrt(int value) {
    var r = 0;
    while ((r + 1) * (r + 1) <= value) {
      r++;
    }
    return r;
  }
}
```

**The stack above is wrong as written and must be fixed while implementing.** It references `_stackNode`, which is never declared, and the capacity is a depth bound rather than a breadth bound — a node pushes up to `kNodeCapacity` children, so the stack must hold `depth * kNodeCapacity` entries, not `depth`. Declare two parallel `Int32List`s of length `_kSearchStackDepth * kNodeCapacity` — one for levels, one for node indices — and size the depth constant to 16, which is far beyond any reachable tree. This is left visible rather than silently corrected because it is exactly the kind of defect a plan's reference code introduces; write the fix, then prove it with the 1000-item differential test, which will overflow the stack if the sizing is wrong.

- [ ] **Step 4: Export it**

In `packages/jet_cad_2d/lib/jet_cad_2d.dart`:

```dart
export 'src/index/packed_rtree.dart';
```

- [ ] **Step 5: Run the tests**

```bash
cd packages/jet_cad_2d && dart test && dart analyze && dart format --set-exit-if-changed lib test
```

Expected: 273 + 7 = 280 passing.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "feat(jet_cad_2d): STR-packed R-tree in typed arrays

Static by design: a packed tree takes no insertions, so recent edits go
to a separate dirty list and the tree is rebuilt past a threshold. That
matches long reads punctuated by short edit bursts and avoids dynamic
R*-tree rebalancing.

Boxes, payloads and the traversal stack are all typed arrays, so search
allocates nothing per node or per item."
```

---

### Task 4: `DirtyList`

**Files:**
- Create: `packages/jet_cad_2d/lib/src/index/dirty_list.dart`
- Test: `packages/jet_cad_2d/test/index/dirty_list_test.dart`

**Interfaces:**
- Consumes: `Aabb2`.
- Produces:

```dart
class DirtyList {
  int get length;
  bool get isEmpty;
  void put(int slot, Aabb2 box);      // insert or replace in place
  void remove(int slot);
  bool contains(int slot);
  void search(double minX, double minY, double maxX, double maxY,
              void Function(int slot) visit);
  void clear();
}
```

**Replace-in-place is the whole point.** A drag emits one edit per pointer-move. Appending would put 200 entries in the list for one entity, trip the rebuild threshold mid-drag, and rebuild during exactly the burst this structure exists to avoid.

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d/test/index/dirty_list_test.dart`:

```dart
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

Aabb2 box(double x, double y, double w, double h) =>
    Aabb2(Vector2(x, y), Vector2(x + w, y + h));

List<int> hits(DirtyList list, Aabb2 q) {
  final out = <int>[];
  list.search(q.minX, q.minY, q.maxX, q.maxY, out.add);
  out.sort();
  return out;
}

void main() {
  test('starts empty', () {
    final list = DirtyList();
    expect(list.length, 0);
    expect(list.isEmpty, isTrue);
    expect(hits(list, box(-1e9, -1e9, 2e9, 2e9)), isEmpty);
  });

  test('finds an entry whose box overlaps', () {
    final list = DirtyList()..put(7, box(0, 0, 1, 1));
    expect(hits(list, box(0.5, 0.5, 1, 1)), [7]);
    expect(hits(list, box(10, 10, 1, 1)), isEmpty);
  });

  test('repeated put on one slot replaces in place and does not grow', () {
    final list = DirtyList();
    for (var i = 0; i < 200; i++) {
      list.put(7, box(i.toDouble(), 0, 1, 1));
    }
    expect(list.length, 1,
        reason: 'a 200-move drag must leave one entry, not 200');

    // The surviving box is the last one written, not the first.
    expect(hits(list, box(199, 0, 1, 1)), [7]);
    expect(hits(list, box(0, 0, 0.5, 1)), isEmpty);
  });

  test('remove drops an entry and keeps the rest findable', () {
    final list = DirtyList()
      ..put(1, box(0, 0, 1, 1))
      ..put(2, box(2, 0, 1, 1))
      ..put(3, box(4, 0, 1, 1));

    list.remove(2);

    expect(list.length, 2);
    expect(list.contains(2), isFalse);
    expect(hits(list, box(-1, -1, 100, 100)), [1, 3]);
  });

  test('remove of the last entry, and of an absent slot, are both safe', () {
    final list = DirtyList()..put(1, box(0, 0, 1, 1));
    list.remove(99);
    expect(list.length, 1);
    list.remove(1);
    expect(list.isEmpty, isTrue);
    expect(hits(list, box(-1, -1, 100, 100)), isEmpty);
  });

  test('removal by swap keeps every remaining slot findable', () {
    // Swap-remove moves the last entry into the hole. If the slot->position
    // map is not updated for the moved entry, that entry becomes unfindable
    // and unremovable. This is the defect the test exists for.
    final list = DirtyList();
    for (var i = 0; i < 10; i++) {
      list.put(i, box(i.toDouble(), 0, 0.5, 1));
    }
    list.remove(0);   // moves slot 9 into position 0

    expect(hits(list, box(9, 0, 0.5, 1)), [9]);
    list.remove(9);
    expect(list.contains(9), isFalse);
    expect(hits(list, box(-1, -1, 100, 100)), [1, 2, 3, 4, 5, 6, 7, 8]);
  });

  test('clear empties everything', () {
    final list = DirtyList()
      ..put(1, box(0, 0, 1, 1))
      ..put(2, box(2, 0, 1, 1));
    list.clear();
    expect(list.isEmpty, isTrue);
    expect(list.contains(1), isFalse);
    expect(hits(list, box(-1, -1, 100, 100)), isEmpty);
  });

  test('an empty box is stored and never matches', () {
    final list = DirtyList()..put(5, Aabb2.empty());
    expect(list.length, 1);
    expect(hits(list, box(-1e9, -1e9, 2e9, 2e9)), isEmpty,
        reason: 'an empty box has minX > maxX and overlaps nothing');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd packages/jet_cad_2d && dart test test/index/dirty_list_test.dart
```

Expected: `Undefined name 'DirtyList'`.

- [ ] **Step 3: Write the implementation**

Create `packages/jet_cad_2d/lib/src/index/dirty_list.dart`:

```dart
import 'dart:typed_data';

import '../geometry/aabb2.dart';

/// Entities edited since the last index rebuild, scanned linearly.
///
/// Keyed by slot with replace-in-place, never append. A drag emits one edit
/// per pointer-move; appending would put 200 entries in this list for one
/// entity, trip the rebuild threshold mid-drag, and rebuild during exactly the
/// burst this structure exists to avoid.
///
/// Removal is by swap with the last entry, which is O(1) and reorders the
/// list. Order here is irrelevant: [search] visits everything and callers sort
/// results by handle.
class DirtyList {
  final Map<int, int> _positionOf = <int, int>{};
  Int32List _slots = Int32List(16);
  Float64List _boxes = Float64List(16 * 4);
  int _length = 0;

  int get length => _length;
  bool get isEmpty => _length == 0;
  bool contains(int slot) => _positionOf.containsKey(slot);

  /// Records [box] for [slot], replacing any box already recorded for it.
  void put(int slot, Aabb2 box) {
    final existing = _positionOf[slot];
    final at = existing ?? _length;
    if (existing == null) {
      if (_length == _slots.length) _grow();
      _slots[at] = slot;
      _positionOf[slot] = at;
      _length++;
    }
    _boxes[at * 4] = box.minX;
    _boxes[at * 4 + 1] = box.minY;
    _boxes[at * 4 + 2] = box.maxX;
    _boxes[at * 4 + 3] = box.maxY;
  }

  void remove(int slot) {
    final at = _positionOf.remove(slot);
    if (at == null) return;
    final last = _length - 1;
    if (at != last) {
      // Swap the last entry into the hole, and — the part that is easy to
      // forget — repoint that entry's map entry at its new position.
      final movedSlot = _slots[last];
      _slots[at] = movedSlot;
      _boxes[at * 4] = _boxes[last * 4];
      _boxes[at * 4 + 1] = _boxes[last * 4 + 1];
      _boxes[at * 4 + 2] = _boxes[last * 4 + 2];
      _boxes[at * 4 + 3] = _boxes[last * 4 + 3];
      _positionOf[movedSlot] = at;
    }
    _length = last;
  }

  /// Visits the slot of every entry whose box overlaps the query.
  ///
  /// Allocates nothing: a plain index loop over typed arrays.
  void search(double minX, double minY, double maxX, double maxY,
      void Function(int slot) visit) {
    for (var i = 0; i < _length; i++) {
      if (_boxes[i * 4] <= maxX &&
          _boxes[i * 4 + 1] <= maxY &&
          _boxes[i * 4 + 2] >= minX &&
          _boxes[i * 4 + 3] >= minY) {
        visit(_slots[i]);
      }
    }
  }

  void clear() {
    _positionOf.clear();
    _length = 0;
  }

  void _grow() {
    final slots = Int32List(_slots.length * 2);
    slots.setRange(0, _length, _slots);
    _slots = slots;
    final boxes = Float64List(_boxes.length * 2);
    boxes.setRange(0, _length * 4, _boxes);
    _boxes = boxes;
  }
}
```

- [ ] **Step 4: Export it**

```dart
export 'src/index/dirty_list.dart';
```

- [ ] **Step 5: Run the tests**

```bash
cd packages/jet_cad_2d && dart test && dart analyze && dart format --set-exit-if-changed lib test
```

Expected: 280 + 8 = 288 passing.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "feat(jet_cad_2d): slot-keyed dirty list with replace-in-place

A drag emits one edit per pointer-move. Appending would put 200 entries
in the list for one entity and trigger a rebuild during the exact burst
the dirty list exists to absorb.

Removal swaps with the last entry and repoints the moved entry's map
position, which is the step whose omission makes an entry silently
unfindable."
```

---

### Task 5: `ContainerIndex` — build, with groups flattened

**Files:**
- Create: `packages/jet_cad_2d/lib/src/index/container_index.dart`
- Test: `packages/jet_cad_2d/test/index/container_index_test.dart`

**Interfaces:**
- Consumes: `PackedRTree`, `DirtyList`, `DraftDocument`, `EntityStore`, `DocumentTree`, `entityBounds`, `Transform2`, `Aabb2`.
- Produces:

```dart
class ContainerIndex {
  ContainerIndex.build(DraftDocument doc, Handle container,
                       Map<Handle, List<int>> leavesByOwner);
  final Handle container;
  int get leafCount;
  int get instanceCount;
  Aabb2 get bounds;                         // in the container's own space
  final DirtyList dirty;
  int get rebuildThreshold;                 // max(64, 0.05 * leafCount)
  bool get needsRebuild;                    // dirty.length > rebuildThreshold
  void searchLeaves(Aabb2 local, void Function(int slot) visit);
  void searchInstances(Aabb2 local, void Function(Handle node) visit);
  Transform2 transformOfInstance(Handle node);
  static Map<Handle, List<int>> leavesByOwner(DraftDocument doc);
}
```

**The build algorithm, stated once because it is the heart of the plan.**

An indexed container is the tree root or a `Definition`. Starting from it with
the identity transform:

- every leaf whose `owner` is the current container contributes
  `entityBounds(...)` transformed by the accumulated transform;
- every child `GroupNode` is **flattened**: recurse into it with
  `acc.multiply(group.transform)`, so its leaves land in this same index;
- every child `InstanceNode` contributes one instance entry, with box
  `doc.definitionBounds(node.definition).transformedBy(acc.multiply(node.transform))`,
  and is **not** recursed into — it is the sharing boundary.

`Transform2.multiply` applies its argument first, so `acc.multiply(child)` maps
child-space to container-space. Getting this backwards produces a plausible
index that is wrong only under rotation and non-uniform scale, which is why the
test below uses both.

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d/test/index/container_index_test.dart`:

```dart
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

EntityRecord line(Handle handle, Handle owner) => EntityRecord(
      handle: handle,
      owner: owner,
      kind: EntityKind.line,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.linetypeByLayer,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const DraftColor.byLayer(),
      lineweight: kByLayer,
      transparency: kByLayer,
      flags: 0,
    );

GeometryPayload segment(double x1, double y1, double x2, double y2) =>
    GeometryPayload(
      coords: Float64List.fromList([x1, y1, x2, y2]),
      scalars: Float64List(0),
    );

/// Adds a line entity owned by [owner] and returns its handle.
Handle addLine(DraftDocument doc, Handle owner, double x1, double y1,
    double x2, double y2) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: line(handle, owner),
    payload: segment(x1, y1, x2, y2),
  ));
  return handle;
}

List<int> leafHits(ContainerIndex index, Aabb2 q) {
  final out = <int>[];
  index.searchLeaves(q, out.add);
  out.sort();
  return out;
}

Aabb2 box(double minX, double minY, double maxX, double maxY) =>
    Aabb2(Vector2(minX, minY), Vector2(maxX, maxY));

void main() {
  test('indexes leaves owned directly by the container', () {
    final doc = DraftDocument.empty();
    addLine(doc, doc.rootHandle, 0, 0, 1, 1);
    addLine(doc, doc.rootHandle, 10, 10, 11, 11);

    final index = ContainerIndex.build(
        doc, doc.rootHandle, ContainerIndex.leavesByOwner(doc));

    expect(index.leafCount, 2);
    expect(leafHits(index, box(-1, -1, 2, 2)), hasLength(1));
    expect(leafHits(index, box(-1, -1, 20, 20)), hasLength(2));
  });

  test('flattens a group: its leaves land in the enclosing index', () {
    final doc = DraftDocument.empty();
    const group = Handle(100);
    doc.commands.execute(AddNodeCommand(
      node: GroupNode(
        handle: group,
        parent: doc.rootHandle,
        transform: Transform2.translation(100, 0),
        children: const [],
      ),
    ));
    addLine(doc, group, 0, 0, 1, 1);

    final index = ContainerIndex.build(
        doc, doc.rootHandle, ContainerIndex.leavesByOwner(doc));

    expect(index.leafCount, 1,
        reason: 'a group is flattened into its nearest indexed ancestor');
    expect(index.instanceCount, 0, reason: 'a group is not an instance');

    // The group transform must be composed in: the leaf lives at x=100.
    expect(leafHits(index, box(-1, -1, 2, 2)), isEmpty);
    expect(leafHits(index, box(99, -1, 102, 2)), hasLength(1));
  });

  test('composes nested group transforms in the right order', () {
    // Two groups: outer rotates 90 degrees, inner translates +10 in x.
    // A point at inner-local (0,0) is at outer-local (10,0), and after the
    // outer rotation it is at container (0,10). Reversing the composition
    // order puts it at (10,0) instead, which is what this pins.
    final doc = DraftDocument.empty();
    const outer = Handle(100);
    const inner = Handle(101);

    doc.commands.execute(AddNodeCommand(
      node: GroupNode(
        handle: outer,
        parent: doc.rootHandle,
        transform: Transform2.rotation(math.pi / 2),
        children: const [],
      ),
    ));
    doc.commands.execute(AddNodeCommand(
      node: GroupNode(
        handle: inner,
        parent: outer,
        transform: Transform2.translation(10, 0),
        children: const [],
      ),
    ));
    addLine(doc, inner, 0, 0, 0, 0);   // a degenerate point at inner origin

    final index = ContainerIndex.build(
        doc, doc.rootHandle, ContainerIndex.leavesByOwner(doc));

    expect(leafHits(index, box(-1, 9, 1, 11)), hasLength(1),
        reason: 'expected the leaf near (0, 10)');
    expect(leafHits(index, box(9, -1, 11, 1)), isEmpty,
        reason: 'a leaf near (10, 0) means the composition order is reversed');
  });

  test('an instance is an entry, not a recursion', () {
    final doc = DraftDocument.empty();
    const def = Handle(200);
    const inDef = Handle(300);
    const instance = Handle(400);

    doc.tree.addDefinition(Definition(
      handle: def, name: 'Table', basePoint: Vector2.zero(),
      children: const [],
    ));
    addLine(doc, def, 0, 0, 2, 2);
    doc.commands.execute(AddNodeCommand(
      node: InstanceNode(
        handle: instance,
        parent: doc.rootHandle,
        transform: Transform2.translation(50, 50),
        definition: def,
        layer: ReservedHandles.layerZero,
      ),
    ));

    final byOwner = ContainerIndex.leavesByOwner(doc);
    final rootIndex = ContainerIndex.build(doc, doc.rootHandle, byOwner);

    expect(rootIndex.leafCount, 0,
        reason: 'the definition body must NOT be flattened into the root');
    expect(rootIndex.instanceCount, 1);

    final defIndex = ContainerIndex.build(doc, def, byOwner);
    expect(defIndex.leafCount, 1);

    // The instance box is the definition box moved to (50,50)..(52,52).
    final found = <Handle>[];
    rootIndex.searchInstances(box(49, 49, 53, 53), found.add);
    expect(found, [instance]);

    found.clear();
    rootIndex.searchInstances(box(0, 0, 10, 10), found.add);
    expect(found, isEmpty);

    // Unused reference kept so the linter does not flag it.
    expect(inDef.value, 300);
  });

  test('an instance nested inside a group is flattened up, with its transform',
      () {
    final doc = DraftDocument.empty();
    const def = Handle(200);
    const group = Handle(100);
    const instance = Handle(400);

    doc.tree.addDefinition(Definition(
      handle: def, name: 'Chair', basePoint: Vector2.zero(),
      children: const [],
    ));
    addLine(doc, def, 0, 0, 1, 1);
    doc.commands.execute(AddNodeCommand(
      node: GroupNode(
        handle: group,
        parent: doc.rootHandle,
        transform: Transform2.translation(0, 200),
        children: const [],
      ),
    ));
    doc.commands.execute(AddNodeCommand(
      node: InstanceNode(
        handle: instance,
        parent: group,
        transform: Transform2.translation(5, 0),
        definition: def,
        layer: ReservedHandles.layerZero,
      ),
    ));

    final index = ContainerIndex.build(
        doc, doc.rootHandle, ContainerIndex.leavesByOwner(doc));

    expect(index.instanceCount, 1);
    final found = <Handle>[];
    index.searchInstances(box(4, 199, 7, 202), found.add);
    expect(found, [instance],
        reason: 'group translate (0,200) then instance translate (5,0)');
  });

  test('transformOfInstance returns the composed container-space transform', () {
    final doc = DraftDocument.empty();
    const def = Handle(200);
    const group = Handle(100);
    const instance = Handle(400);

    doc.tree.addDefinition(Definition(
      handle: def, name: 'Chair', basePoint: Vector2.zero(),
      children: const [],
    ));
    addLine(doc, def, 0, 0, 1, 1);
    doc.commands.execute(AddNodeCommand(
      node: GroupNode(
        handle: group,
        parent: doc.rootHandle,
        transform: Transform2.translation(0, 200),
        children: const [],
      ),
    ));
    doc.commands.execute(AddNodeCommand(
      node: InstanceNode(
        handle: instance,
        parent: group,
        transform: Transform2.translation(5, 0),
        definition: def,
        layer: ReservedHandles.layerZero,
      ),
    ));

    final index = ContainerIndex.build(
        doc, doc.rootHandle, ContainerIndex.leavesByOwner(doc));
    final t = index.transformOfInstance(instance);
    final mapped = t.transformPoint(Vector2.zero());
    expect(mapped.x, closeTo(5, 1e-12));
    expect(mapped.y, closeTo(200, 1e-12));
  });

  test('rebuild threshold is max(64, 5 percent of leaves)', () {
    final doc = DraftDocument.empty();
    for (var i = 0; i < 4000; i++) {
      addLine(doc, doc.rootHandle, i.toDouble(), 0, i + 0.5, 1);
    }
    final index = ContainerIndex.build(
        doc, doc.rootHandle, ContainerIndex.leavesByOwner(doc));

    expect(index.rebuildThreshold, 200);
    expect(index.needsRebuild, isFalse);

    for (var slot = 0; slot <= 200; slot++) {
      index.dirty.put(slot, box(0, 0, 1, 1));
    }
    expect(index.needsRebuild, isFalse, reason: 'threshold is exclusive');
    index.dirty.put(201, box(0, 0, 1, 1));
    expect(index.needsRebuild, isTrue);
  });

  test('a small index still gets a floor of 64', () {
    final doc = DraftDocument.empty();
    addLine(doc, doc.rootHandle, 0, 0, 1, 1);
    final index = ContainerIndex.build(
        doc, doc.rootHandle, ContainerIndex.leavesByOwner(doc));
    expect(index.rebuildThreshold, 64);
  });

  test('an empty container builds and searches without error', () {
    final doc = DraftDocument.empty();
    final index = ContainerIndex.build(
        doc, doc.rootHandle, ContainerIndex.leavesByOwner(doc));
    expect(index.leafCount, 0);
    expect(index.instanceCount, 0);
    expect(index.bounds.isEmpty, isTrue);
    expect(leafHits(index, box(-1e9, -1e9, 1e9, 1e9)), isEmpty);
  });

  test('leavesByOwner buckets every live entity exactly once, ascending', () {
    final doc = DraftDocument.empty();
    const group = Handle(100);
    doc.commands.execute(AddNodeCommand(
      node: GroupNode(
        handle: group,
        parent: doc.rootHandle,
        transform: Transform2.identity(),
        children: const [],
      ),
    ));
    addLine(doc, doc.rootHandle, 0, 0, 1, 1);
    addLine(doc, group, 0, 0, 1, 1);
    addLine(doc, group, 2, 2, 3, 3);

    final byOwner = ContainerIndex.leavesByOwner(doc);
    expect(byOwner[doc.rootHandle], hasLength(1));
    expect(byOwner[group], hasLength(2));

    final all = [for (final bucket in byOwner.values) ...bucket]..sort();
    expect(all, doc.entities.liveSlots.toList());
    for (final bucket in byOwner.values) {
      final sorted = [...bucket]..sort();
      expect(bucket, sorted, reason: 'each bucket must be ascending by slot');
    }
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd packages/jet_cad_2d && dart test test/index/container_index_test.dart
```

Expected: `Undefined name 'ContainerIndex'`.

If `AddNodeCommand`'s parameter is not named `node:`, read `lib/src/document/commands.dart` and correct the test.

- [ ] **Step 3: Write the implementation**

Create `packages/jet_cad_2d/lib/src/index/container_index.dart`:

```dart
import 'dart:math' as math;
import 'dart:typed_data';

import '../core/handle.dart';
import '../document/draft_document.dart';
import '../document/extents.dart';
import '../document/node.dart';
import '../geometry/aabb2.dart';
import '../geometry/transform2.dart';
import 'dirty_list.dart';
import 'packed_rtree.dart';

/// The spatial index of one indexed container — the document root, or a
/// definition.
///
/// Holds two trees, not one: leaves keyed by entity slot, and instances keyed
/// by node handle. Two trees rather than one tagged tree because the callers
/// differ — culling wants leaves and instances separately, and a tagged tree
/// would make every visitor branch on the tag.
///
/// **Groups are flattened.** A group is a one-off: it is not shared, so a
/// per-group index buys no reuse while costing a recursion level on every
/// query. Its leaves are folded into the nearest indexed ancestor with the
/// group transform composed in. An instance is *not* flattened — it is the
/// sharing boundary, and folding it in would defeat the entire design.
class ContainerIndex {
  ContainerIndex._(
    this.container,
    this._leaves,
    this._instances,
    this._instanceHandles,
    this._instanceTransforms,
    this.bounds,
  ) : dirty = DirtyList();

  /// Builds the index for [container].
  ///
  /// [leavesByOwner] is shared across every container built in one pass; see
  /// [ContainerIndex.leavesByOwner]. Passing it in rather than recomputing it
  /// per container is what keeps a whole-document build linear in entities
  /// rather than O(containers x entities).
  factory ContainerIndex.build(
    DraftDocument doc,
    Handle container,
    Map<Handle, List<int>> leavesByOwner,
  ) {
    final leafSlots = <int>[];
    final leafBoxes = <double>[];
    final instanceHandles = <Handle>[];
    final instanceBoxes = <double>[];
    final instanceTransforms = <Transform2>[];
    var bounds = Aabb2.empty();

    void addBox(List<double> into, Aabb2 b) {
      into..add(b.minX)..add(b.minY)..add(b.maxX)..add(b.maxY);
    }

    List<Handle> childNodesOf(Handle c) {
      final node = doc.tree[c];
      if (node is GroupNode) return doc.tree.childNodesOf(node.children);
      final definition = doc.tree.definition(c);
      if (definition != null) {
        return doc.tree.childNodesOf(definition.children);
      }
      return const [];
    }

    // Explicit stack rather than recursion: a malformed tree must not blow
    // the Dart stack, and `validate()` reports tree.cycle for exactly that.
    // Depth is bounded here as a second line of defence.
    const maxDepth = 256;
    final stack = <(Handle, Transform2)>[(container, Transform2.identity())];
    final seen = <Handle>{container};

    while (stack.isNotEmpty) {
      final (current, acc) = stack.removeLast();

      for (final slot in leavesByOwner[current] ?? const <int>[]) {
        final record = doc.entities.read(slot);
        final local = entityBounds(
          kind: record.kind,
          payload: doc.geometry.read(record.geomIndex),
          measurer: doc.textMeasurer,
          textStyle: ReservedHandles.standardTextStyle,
        ).transformedBy(acc);
        leafSlots.add(slot);
        addBox(leafBoxes, local);
        bounds = bounds.union(local);
      }

      for (final child in childNodesOf(current)) {
        final node = doc.tree[child];
        switch (node) {
          case GroupNode(:final transform):
            // Flattened: recurse with the composed transform. `acc` is applied
            // second, so acc.multiply(transform) maps child space to container
            // space.
            if (seen.add(child) && stack.length < maxDepth) {
              stack.add((child, acc.multiply(transform)));
            }
          case InstanceNode(:final definition, :final transform):
            final composed = acc.multiply(transform);
            final box =
                doc.definitionBounds(definition).transformedBy(composed);
            instanceHandles.add(child);
            instanceTransforms.add(composed);
            addBox(instanceBoxes, box);
            bounds = bounds.union(box);
          case null:
            break;
        }
      }
    }

    return ContainerIndex._(
      container,
      _treeOf(leafSlots.length, leafBoxes,
          Uint32List.fromList(leafSlots)),
      _treeOf(instanceHandles.length, instanceBoxes,
          Uint32List.fromList([for (final h in instanceHandles) h.value])),
      instanceHandles,
      instanceTransforms,
      bounds,
    );
  }

  static PackedRTree _treeOf(int count, List<double> boxes, Uint32List payloads) =>
      count == 0
          ? PackedRTree.empty()
          : PackedRTree.build(count, Float64List.fromList(boxes), payloads);

  /// Every live entity slot bucketed by its owner, ascending within a bucket.
  ///
  /// Leaf containment is stated exactly once, by `EntityRecord.owner`, and
  /// that statement is authoritative. Never read leaves out of a `children`
  /// list — `children` holds child nodes only.
  static Map<Handle, List<int>> leavesByOwner(DraftDocument doc) {
    final byOwner = <Handle, List<int>>{};
    // liveSlots yields ascending slots, so each bucket is ascending too.
    for (final slot in doc.entities.liveSlots) {
      (byOwner[doc.entities.ownerAt(slot)] ??= <int>[]).add(slot);
    }
    return byOwner;
  }

  final Handle container;
  final PackedRTree _leaves;
  final PackedRTree _instances;
  final List<Handle> _instanceHandles;
  final List<Transform2> _instanceTransforms;

  /// The union of everything this container holds, in its own space.
  final Aabb2 bounds;

  final DirtyList dirty;

  int get leafCount => _leaves.itemCount;
  int get instanceCount => _instances.itemCount;

  /// Above this many dirty entries the tree is rebuilt.
  ///
  /// The floor of 64 keeps a small document from rebuilding on every second
  /// edit; the 5% term keeps a large one from linearly scanning a meaningful
  /// fraction of itself on every query.
  int get rebuildThreshold => math.max(64, (leafCount * 0.05).floor());

  bool get needsRebuild => dirty.length > rebuildThreshold;

  /// Visits the slot of every leaf whose box overlaps [local], which is
  /// expressed in this container's own space.
  ///
  /// Dirty entries are visited too, so a caller sees recent edits. A slot may
  /// be visited twice if it is both in the tree and dirty; the tree marks
  /// superseded entries dead to prevent that, and the invalidation path is
  /// responsible for doing so.
  void searchLeaves(Aabb2 local, void Function(int slot) visit) {
    if (local.isEmpty) return;
    _leaves.search(local.minX, local.minY, local.maxX, local.maxY, visit);
    dirty.search(local.minX, local.minY, local.maxX, local.maxY, visit);
  }

  void searchInstances(Aabb2 local, void Function(Handle node) visit) {
    if (local.isEmpty) return;
    _instances.search(local.minX, local.minY, local.maxX, local.maxY,
        (payload) => visit(Handle(payload)));
  }

  /// The composed container-space transform of [node], including every group
  /// transform between it and this container.
  Transform2 transformOfInstance(Handle node) {
    final at = _instanceHandles.indexOf(node);
    if (at < 0) return Transform2.identity();
    return _instanceTransforms[at];
  }

  /// Marks a leaf slot as superseded by a dirty entry.
  void markLeafDead(int slot) => _leaves.markDead(slot);
}
```

- [ ] **Step 4: Export it**

```dart
export 'src/index/container_index.dart';
```

- [ ] **Step 5: Run the tests**

```bash
cd packages/jet_cad_2d && dart test && dart analyze && dart format --set-exit-if-changed lib test
```

Expected: 288 + 10 = 298 passing.

**Two things to check while making this pass.** `transformOfInstance` uses `indexOf`, which is O(instances) — acceptable for now because it is not on the frame path, but note it in the report if any later task calls it per frame. And `ContainerIndex.build` calls `doc.definitionBounds(...)` per instance, which recomputes a bucket map each call; if the build is slow on the benchmark document, that is where the time is.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "feat(jet_cad_2d): ContainerIndex with groups flattened

An indexed container is the root or a definition. Groups are folded into
their nearest indexed ancestor with composed transforms, because a group
is a one-off and a per-group index buys no reuse. Instances are entries
rather than recursions: they are the sharing boundary and the reason the
two-kind split pays.

Leaves come from owner-bucketing, never from a children list."
```

---

### Task 6: `SpatialIndex` — one index per container, built together

**Files:**
- Create: `packages/jet_cad_2d/lib/src/index/spatial_index.dart`
- Test: `packages/jet_cad_2d/test/index/spatial_index_test.dart`

**Interfaces:**
- Consumes: `ContainerIndex`, `DraftDocument`.
- Produces:

```dart
class SpatialIndex {
  SpatialIndex(DraftDocument document);
  final DraftDocument document;
  ContainerIndex? indexFor(Handle container);
  ContainerIndex get rootIndex;
  int get containerCount;
  void rebuildAll();
  void rebuildContainer(Handle container);
  void dispose();
}
```

`SpatialIndex` owns one `ContainerIndex` per indexed container: the tree root,
plus every `Definition` — including definitions with no instances, because one
may be placed at any moment and building on demand would put an unbounded
build inside a query.

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d/test/index/spatial_index_test.dart`:

```dart
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

EntityRecord line(Handle handle, Handle owner) => EntityRecord(
      handle: handle,
      owner: owner,
      kind: EntityKind.line,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.linetypeByLayer,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const DraftColor.byLayer(),
      lineweight: kByLayer,
      transparency: kByLayer,
      flags: 0,
    );

Handle addLine(DraftDocument doc, Handle owner, double x1, double y1,
    double x2, double y2) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: line(handle, owner),
    payload: GeometryPayload(
      coords: Float64List.fromList([x1, y1, x2, y2]),
      scalars: Float64List(0),
    ),
  ));
  return handle;
}

void main() {
  test('builds an index for the root and for every definition', () {
    final doc = DraftDocument.empty();
    doc.tree.addDefinition(Definition(
      handle: const Handle(200), name: 'A', basePoint: Vector2.zero(),
      children: const [],
    ));
    doc.tree.addDefinition(Definition(
      handle: const Handle(201), name: 'B', basePoint: Vector2.zero(),
      children: const [],
    ));
    addLine(doc, doc.rootHandle, 0, 0, 1, 1);

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    expect(index.containerCount, 3, reason: 'root plus two definitions');
    expect(index.rootIndex.leafCount, 1);
    expect(index.indexFor(const Handle(200)), isNotNull);
    expect(index.indexFor(const Handle(201)), isNotNull);
    expect(index.indexFor(const Handle(999)), isNull);
  });

  test('builds an index for a definition with no instances', () {
    final doc = DraftDocument.empty();
    doc.tree.addDefinition(Definition(
      handle: const Handle(200), name: 'Unused', basePoint: Vector2.zero(),
      children: const [],
    ));
    addLine(doc, const Handle(200), 0, 0, 5, 5);

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    expect(index.indexFor(const Handle(200))!.leafCount, 1,
        reason: 'an unplaced definition may be placed at any moment; '
            'building on demand would put an unbounded build in a query');
  });

  test('rebuildAll picks up entities added since construction', () {
    final doc = DraftDocument.empty();
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    expect(index.rootIndex.leafCount, 0);

    addLine(doc, doc.rootHandle, 0, 0, 1, 1);
    index.rebuildAll();

    expect(index.rootIndex.leafCount, 1);
  });

  test('rebuildContainer rebuilds only the one named', () {
    final doc = DraftDocument.empty();
    doc.tree.addDefinition(Definition(
      handle: const Handle(200), name: 'A', basePoint: Vector2.zero(),
      children: const [],
    ));
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    addLine(doc, doc.rootHandle, 0, 0, 1, 1);
    addLine(doc, const Handle(200), 0, 0, 1, 1);

    index.rebuildContainer(const Handle(200));

    expect(index.indexFor(const Handle(200))!.leafCount, 1);
    expect(index.rootIndex.leafCount, 0,
        reason: 'the root was not named and must be untouched');
  });

  test('a definition added after construction gets an index on rebuildAll', () {
    final doc = DraftDocument.empty();
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    expect(index.containerCount, 1);

    doc.tree.addDefinition(Definition(
      handle: const Handle(200), name: 'Late', basePoint: Vector2.zero(),
      children: const [],
    ));
    index.rebuildAll();

    expect(index.containerCount, 2);
    expect(index.indexFor(const Handle(200)), isNotNull);
  });

  test('a definition removed after construction loses its index', () {
    final doc = DraftDocument.empty();
    doc.tree.addDefinition(Definition(
      handle: const Handle(200), name: 'Doomed', basePoint: Vector2.zero(),
      children: const [],
    ));
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    expect(index.containerCount, 2);

    doc.tree.removeDefinition(const Handle(200));
    index.rebuildAll();

    expect(index.containerCount, 1);
    expect(index.indexFor(const Handle(200)), isNull);
  });

  test('dispose is idempotent', () {
    final doc = DraftDocument.empty();
    final index = SpatialIndex(doc)..dispose();
    expect(index.dispose, returnsNormally);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd packages/jet_cad_2d && dart test test/index/spatial_index_test.dart
```

Expected: `Undefined name 'SpatialIndex'`.

- [ ] **Step 3: Write the implementation**

Create `packages/jet_cad_2d/lib/src/index/spatial_index.dart`:

```dart
import 'dart:async';

import '../core/handle.dart';
import '../document/doc_change.dart';
import '../document/draft_document.dart';
import 'container_index.dart';

/// Every [ContainerIndex] in a document, kept current against its changes.
///
/// One index per indexed container: the tree root, plus every definition —
/// including definitions with no instances, since one may be placed at any
/// moment and building on demand would put an unbounded build inside a query.
class SpatialIndex {
  SpatialIndex(this.document) {
    rebuildAll();
    _subscription = document.changes.listen(_onChange);
  }

  final DraftDocument document;
  final Map<Handle, ContainerIndex> _byContainer = <Handle, ContainerIndex>{};
  StreamSubscription<DocChange>? _subscription;

  ContainerIndex? indexFor(Handle container) => _byContainer[container];

  ContainerIndex get rootIndex => _byContainer[document.rootHandle]!;

  int get containerCount => _byContainer.length;

  /// Discards every index and rebuilds from scratch.
  ///
  /// One [ContainerIndex.leavesByOwner] pass is shared across every container,
  /// which is what keeps a whole-document build linear in entities rather than
  /// O(containers x entities).
  void rebuildAll() {
    final byOwner = ContainerIndex.leavesByOwner(document);
    _byContainer
      ..clear()
      ..[document.rootHandle] =
          ContainerIndex.build(document, document.rootHandle, byOwner);
    for (final definition in document.tree.definitions) {
      _byContainer[definition.handle] =
          ContainerIndex.build(document, definition.handle, byOwner);
    }
  }

  /// Rebuilds one container, leaving the rest alone.
  void rebuildContainer(Handle container) {
    final byOwner = ContainerIndex.leavesByOwner(document);
    _byContainer[container] =
        ContainerIndex.build(document, container, byOwner);
  }

  void _onChange(DocChange change) {
    // Task 7 replaces this with re-derive-and-compare. Until then the
    // conservative answer is correct but slow, and it is deliberately not the
    // shipped behaviour of this plan.
    switch (change) {
      case DocumentLoaded():
      case DocumentPurged():
        rebuildAll();
      default:
        break;
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _byContainer.clear();
  }
}
```

- [ ] **Step 4: Export it**

```dart
export 'src/index/spatial_index.dart';
```

- [ ] **Step 5: Run the tests**

```bash
cd packages/jet_cad_2d && dart test && dart analyze && dart format --set-exit-if-changed lib test
```

Expected: 298 + 7 = 305 passing.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "feat(jet_cad_2d): SpatialIndex owning one index per container

Root plus every definition, including unplaced ones: a definition may be
instanced at any moment, and building on demand would put an unbounded
build inside a query.

One leavesByOwner pass is shared across the whole build, keeping it
linear in entities rather than O(containers x entities)."
```

---

### Task 7: Invalidation — re-derive and compare

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/index/spatial_index.dart` (replace `_onChange`)
- Modify: `packages/jet_cad_2d/lib/src/index/container_index.dart` (add `boxOfLeaf`, `containsLeaf`)
- Test: `packages/jet_cad_2d/test/index/invalidation_test.dart`

**Interfaces:**
- Consumes: `DocChange`, `ContainerIndex`, `DirtyList`.
- Produces: on `SpatialIndex`, `int get rebuildCount` and `int get dirtyCount` — both test-visible counters, because "did this dirty anything?" is otherwise unobservable and the load-bearing guarantee is *that nothing happened*.

**Why re-derive rather than typed change kinds.** `DocChange` as shipped is
`(label, Set<Handle> touched)` with no kind, and `SetComponentCommand` emits
`touched: {entityHandle}` — indistinguishable from a geometry edit. So the
index is told *which* handles changed and must work out *whether* anything
moved: recompute each touched handle's box and compare against what is indexed.
A component edit finds the box unchanged and dirties nothing. The
appearance-edits-do-not-touch-the-index guarantee is preserved by measurement
rather than by a kind the stream cannot carry — and it keeps working when a
later plan adds the geometry-editing command Plan 1 never shipped.

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d/test/index/invalidation_test.dart`:

```dart
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

EntityRecord line(Handle handle, Handle owner) => EntityRecord(
      handle: handle,
      owner: owner,
      kind: EntityKind.line,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.linetypeByLayer,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const DraftColor.byLayer(),
      lineweight: kByLayer,
      transparency: kByLayer,
      flags: 0,
    );

Handle addLine(DraftDocument doc, Handle owner, double x1, double y1,
    double x2, double y2) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: line(handle, owner),
    payload: GeometryPayload(
      coords: Float64List.fromList([x1, y1, x2, y2]),
      scalars: Float64List(0),
    ),
  ));
  return handle;
}

void main() {
  test('adding an entity dirties it without a full rebuild', () {
    final doc = DraftDocument.empty();
    addLine(doc, doc.rootHandle, 0, 0, 1, 1);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final rebuildsBefore = index.rebuildCount;
    addLine(doc, doc.rootHandle, 10, 10, 11, 11);

    expect(index.rebuildCount, rebuildsBefore,
        reason: 'one add must not rebuild the whole index');
    expect(index.rootIndex.dirty.length, 1);
  });

  test('a newly added entity is immediately findable', () {
    final doc = DraftDocument.empty();
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    addLine(doc, doc.rootHandle, 50, 50, 51, 51);

    final found = <int>[];
    index.rootIndex.searchLeaves(
        Aabb2(Vector2(49, 49), Vector2(52, 52)), found.add);
    expect(found, hasLength(1),
        reason: 'the dirty list is searched alongside the tree');
  });

  test('a component edit dirties nothing — the load-bearing guarantee', () {
    final doc = DraftDocument.empty();
    final handle = addLine(doc, doc.rootHandle, 0, 0, 1, 1);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final dirtyBefore = index.dirtyCount;
    final rebuildsBefore = index.rebuildCount;

    doc.commands.execute(SetComponentCommand(
      handle: handle,
      component: const OriginComponent(),
    ));

    expect(index.dirtyCount, dirtyBefore,
        reason: 'SetComponentCommand touches the entity handle exactly as a '
            'geometry edit does; re-derivation must find the box unchanged');
    expect(index.rebuildCount, rebuildsBefore);
    expect(index.rootIndex.dirty.isEmpty, isTrue);
  });

  test('removing an entity marks its tree entry dead', () {
    final doc = DraftDocument.empty();
    final keep = addLine(doc, doc.rootHandle, 0, 0, 1, 1);
    final drop = addLine(doc, doc.rootHandle, 10, 10, 11, 11);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    doc.commands.execute(RemoveEntityCommand(handle: drop));

    final found = <int>[];
    index.rootIndex
        .searchLeaves(Aabb2(Vector2(-1, -1), Vector2(100, 100)), found.add);
    expect(found, hasLength(1));
    expect(doc.entities.handleAt(found.single), keep);
  });

  test('undo restores findability', () {
    final doc = DraftDocument.empty();
    final handle = addLine(doc, doc.rootHandle, 10, 10, 11, 11);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    doc.commands.execute(RemoveEntityCommand(handle: handle));
    doc.commands.undo();

    final found = <int>[];
    index.rootIndex
        .searchLeaves(Aabb2(Vector2(9, 9), Vector2(12, 12)), found.add);
    expect(found, hasLength(1));
  });

  test('moving a node re-derives and dirties the instance', () {
    final doc = DraftDocument.empty();
    const def = Handle(200);
    const instance = Handle(400);
    doc.tree.addDefinition(Definition(
      handle: def, name: 'T', basePoint: Vector2.zero(), children: const [],
    ));
    addLine(doc, def, 0, 0, 1, 1);
    doc.commands.execute(AddNodeCommand(
      node: InstanceNode(
        handle: instance,
        parent: doc.rootHandle,
        transform: Transform2.identity(),
        definition: def,
        layer: ReservedHandles.layerZero,
      ),
    ));

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    doc.commands.execute(TransformNodeCommand(
      handle: instance,
      transform: Transform2.translation(500, 500),
    ));

    final found = <Handle>[];
    index.rootIndex.searchInstances(
        Aabb2(Vector2(499, 499), Vector2(502, 502)), found.add);
    expect(found, [instance],
        reason: 'the instance must be findable at its new position');
  });

  test('DocumentPurged forces a full rebuild', () {
    final doc = DraftDocument.empty();
    addLine(doc, doc.rootHandle, 0, 0, 1, 1);
    final drop = addLine(doc, doc.rootHandle, 10, 10, 11, 11);
    doc.commands.execute(RemoveEntityCommand(handle: drop));

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final before = index.rebuildCount;

    doc.purge();

    expect(index.rebuildCount, greaterThan(before),
        reason: 'purge renumbers slots, so every slot-keyed structure dies');
    expect(index.rootIndex.dirty.isEmpty, isTrue);
  });

  test('crossing the rebuild threshold rebuilds and clears the dirty list', () {
    final doc = DraftDocument.empty();
    for (var i = 0; i < 2000; i++) {
      addLine(doc, doc.rootHandle, i.toDouble(), 0, i + 0.5, 1);
    }
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final threshold = index.rootIndex.rebuildThreshold;
    final before = index.rebuildCount;

    // Each add dirties one entity.
    for (var i = 0; i <= threshold; i++) {
      addLine(doc, doc.rootHandle, 5000.0 + i, 0, 5000.5 + i, 1);
    }

    expect(index.rebuildCount, greaterThan(before));
    expect(index.rootIndex.dirty.length, lessThanOrEqualTo(threshold),
        reason: 'a rebuild folds the dirty list into the tree');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd packages/jet_cad_2d && dart test test/index/invalidation_test.dart
```

Expected: `The getter 'rebuildCount' isn't defined`, and several tests failing because `_onChange` currently ignores command events.

- [ ] **Step 3: Add the lookups `ContainerIndex` needs**

In `packages/jet_cad_2d/lib/src/index/container_index.dart`, add:

```dart
  /// The indexed box of [slot], or null if this container does not hold it.
  ///
  /// Reads the tree's stored box rather than recomputing from geometry: the
  /// point of the comparison is "does what is indexed still match the
  /// document", so recomputing both sides would compare a value to itself.
  Aabb2? boxOfLeaf(int slot) => _leaves.boxOfPayload(slot);

  bool containsLeaf(int slot) => _leaves.boxOfPayload(slot) != null;
```

and in `packed_rtree.dart`:

```dart
  /// The stored box of [payload], or null if this tree has no such item.
  Aabb2? boxOfPayload(int payload) {
    final item = _payloadToItem[payload];
    if (item == null) return null;
    return Aabb2.raw(_boxes[item * 4], _boxes[item * 4 + 1],
        _boxes[item * 4 + 2], _boxes[item * 4 + 3]);
  }
```

- [ ] **Step 4: Replace `_onChange`**

In `spatial_index.dart`, add the counters and the real handler:

```dart
  int _rebuildCount = 0;
  int _dirtyCount = 0;

  /// How many full container rebuilds have happened. Test-visible because the
  /// load-bearing guarantee is that certain edits cause *none*.
  int get rebuildCount => _rebuildCount;

  /// How many entries have been written to a dirty list. Same reasoning.
  int get dirtyCount => _dirtyCount;

  void _onChange(DocChange change) {
    switch (change) {
      case DocumentLoaded():
      case DocumentPurged():
        // Slots were renumbered or the document replaced. Every slot-keyed
        // structure — the trees, the dirty lists, the dead bitmasks — is
        // invalid, and there is no incremental path back.
        rebuildAll();
      case CommandApplied(:final touched):
      case CommandUndone(:final touched):
      case CommandRedone(:final touched):
        _reconcile(touched);
    }
  }

  /// Re-derives the box of every touched handle and dirties what moved.
  void _reconcile(Set<Handle> touched) {
    if (touched.isEmpty) {
      rebuildAll();
      return;
    }

    // A touched handle may be an entity, a node, or a definition. Ascending
    // order keeps the work deterministic, which matters because a rebuild
    // decision depends on how many entries land in a dirty list.
    final ordered = touched.toList()..sort((a, b) => a.value.compareTo(b.value));

    var structural = false;
    for (final handle in ordered) {
      if (document.tree.definition(handle) != null) {
        structural = true;
        continue;
      }
      if (document.tree[handle] != null) {
        structural = true;
        continue;
      }
      _reconcileEntity(handle);
    }

    if (structural) {
      // A node or definition changed: which container holds what, and where,
      // may have moved wholesale. Re-deriving one box is not enough, and
      // working out the minimal set is a Plan 3 optimisation if the benchmark
      // asks for it.
      rebuildAll();
      return;
    }

    for (final index in _byContainer.values) {
      if (index.needsRebuild) {
        rebuildContainer(index.container);
      }
    }
  }

  void _reconcileEntity(Handle handle) {
    final slot = document.entities.slotOf(handle);
    if (slot == null) {
      // Removed. Mark it dead everywhere it might be indexed, and drop any
      // dirty entry for it.
      for (final index in _byContainer.values) {
        index.markLeafDead(_lastKnownSlot[handle] ?? -1);
        index.dirty.remove(_lastKnownSlot[handle] ?? -1);
      }
      _lastKnownSlot.remove(handle);
      return;
    }

    _lastKnownSlot[handle] = slot;
    final owner = document.entities.ownerAt(slot);
    final index = _containerHolding(owner);
    if (index == null) {
      rebuildAll();
      return;
    }

    final record = document.entities.read(slot);
    final current = entityBounds(
      kind: record.kind,
      payload: document.geometry.read(record.geomIndex),
      measurer: document.textMeasurer,
      textStyle: ReservedHandles.standardTextStyle,
    );
    // The indexed box is in container space; if this entity sits under a
    // flattened group, the two differ by that group's transform. Comparing
    // against the group-composed box is what makes an unchanged entity
    // register as unchanged.
    final composed = _groupTransformOf(owner, index.container);
    final expected = current.transformedBy(composed);

    final indexed = index.boxOfLeaf(slot);
    if (indexed != null && _sameBox(indexed, expected)) return;

    index.markLeafDead(slot);
    index.dirty.put(slot, expected);
    _dirtyCount++;
  }

  /// The transform from [owner]'s space up to [container]'s space, composing
  /// every flattened group between them.
  Transform2 _groupTransformOf(Handle owner, Handle container) {
    var acc = Transform2.identity();
    var current = owner;
    var guard = 0;
    while (current != container && guard++ < 256) {
      final node = document.tree[current];
      if (node is! GroupNode) break;
      acc = node.transform.multiply(acc);
      current = node.parent;
    }
    return acc;
  }

  /// The index of the container that holds [owner] — itself if it is indexed,
  /// otherwise the nearest indexed ancestor, since groups are flattened.
  ContainerIndex? _containerHolding(Handle owner) {
    var current = owner;
    var guard = 0;
    while (guard++ < 256) {
      final direct = _byContainer[current];
      if (direct != null) return direct;
      final node = document.tree[current];
      if (node == null) return null;
      current = node.parent;
    }
    return null;
  }

  static bool _sameBox(Aabb2 a, Aabb2 b) =>
      a.minX == b.minX &&
      a.minY == b.minY &&
      a.maxX == b.maxX &&
      a.maxY == b.maxY;

  final Map<Handle, int> _lastKnownSlot = <Handle, int>{};
```

Also increment `_rebuildCount` inside `rebuildAll` and `rebuildContainer`, and
populate `_lastKnownSlot` for every live entity inside `rebuildAll`.

**`_sameBox` uses exact `==` deliberately.** This is a stored-value comparison —
"is the indexed box byte-identical to the freshly derived one" — not a
geometric decision. A tolerance here would let a real move slip through as
unchanged.

- [ ] **Step 5: Run the tests**

```bash
cd packages/jet_cad_2d && dart test && dart analyze && dart format --set-exit-if-changed lib test
```

Expected: 305 + 8 = 313 passing.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "feat(jet_cad_2d): re-derive-and-compare index invalidation

DocChange carries no change kind, and SetComponentCommand touches the
entity handle indistinguishably from a geometry edit. So the index
recomputes each touched handle's box and compares: an appearance edit
finds it unchanged and dirties nothing.

That preserves the appearance-edits-do-not-dirty guarantee by
measurement rather than by a kind the stream cannot carry, and it keeps
working when a later plan adds the geometry-editing command Plan 1 never
shipped.

DocumentLoaded and DocumentPurged force a full rebuild: slots were
renumbered, so every slot-keyed structure is invalid at once."
```

---

### Task 8: `QueryFilter` — visibility and locking

**Files:**
- Create: `packages/jet_cad_2d/lib/src/index/query_filter.dart`
- Test: `packages/jet_cad_2d/test/index/query_filter_test.dart`

**Interfaces:**
- Consumes: `LayerRecord`, `Node`, `EntityStore`, `DocumentTables`.
- Produces:

```dart
final class QueryFilter {
  const QueryFilter({required this.visibleOnly, required this.excludeLocked});
  const QueryFilter.all();          // visibleOnly: false, excludeLocked: false
  const QueryFilter.rendering();    // visibleOnly: true,  excludeLocked: false
  const QueryFilter.picking();      // visibleOnly: true,  excludeLocked: true
  final bool visibleOnly, excludeLocked;
  bool get isPassthrough;
}

class FilterEvaluator {
  FilterEvaluator(DraftDocument document);
  bool acceptsEntity(int slot, QueryFilter filter);
  bool acceptsNode(Handle node, QueryFilter filter);
  void invalidate();
}
```

The filter is a query parameter rather than something the caller applies
afterwards. Applying it afterwards would mean the index returns work the caller
throws away, at frame rate — and the three callers want three different answers:
"select all on this layer" wants everything, rendering wants visible, picking
wants visible and unlocked.

`FilterEvaluator` caches per-layer answers, because a layer lookup per entity
per frame is a map hit per entity per frame.

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d/test/index/query_filter_test.dart`:

```dart
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

EntityRecord lineOn(Handle handle, Handle owner, Handle layer) => EntityRecord(
      handle: handle,
      owner: owner,
      kind: EntityKind.line,
      layer: layer,
      linetype: ReservedHandles.linetypeByLayer,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const DraftColor.byLayer(),
      lineweight: kByLayer,
      transparency: kByLayer,
      flags: 0,
    );

int addOn(DraftDocument doc, Handle owner, Handle layer) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: lineOn(handle, owner, layer),
    payload: GeometryPayload(
      coords: Float64List.fromList([0, 0, 1, 1]),
      scalars: Float64List(0),
    ),
  ));
  return doc.entities.slotOf(handle)!;
}

void main() {
  test('the three presets differ in exactly the documented way', () {
    const all = QueryFilter.all();
    const rendering = QueryFilter.rendering();
    const picking = QueryFilter.picking();

    expect(all.visibleOnly, isFalse);
    expect(all.excludeLocked, isFalse);
    expect(all.isPassthrough, isTrue);

    expect(rendering.visibleOnly, isTrue);
    expect(rendering.excludeLocked, isFalse);
    expect(rendering.isPassthrough, isFalse);

    expect(picking.visibleOnly, isTrue);
    expect(picking.excludeLocked, isTrue);
  });

  test('an entity on a hidden layer fails visibleOnly but passes all', () {
    final doc = DraftDocument.empty();
    const hidden = Handle(50);
    doc.tables.layers.add(LayerRecord(
      handle: hidden, name: 'Hidden', color: const DraftColor.index(7),
      linetype: ReservedHandles.linetypeContinuous,
      lineweight: kLineweightDefault, transparency: 0,
      visible: false, locked: false,
    ));
    final slot = addOn(doc, doc.rootHandle, hidden);
    final evaluator = FilterEvaluator(doc);

    expect(evaluator.acceptsEntity(slot, const QueryFilter.all()), isTrue);
    expect(
        evaluator.acceptsEntity(slot, const QueryFilter.rendering()), isFalse);
    expect(evaluator.acceptsEntity(slot, const QueryFilter.picking()), isFalse);
  });

  test('an entity on a locked layer is visible but not pickable', () {
    final doc = DraftDocument.empty();
    const locked = Handle(51);
    doc.tables.layers.add(LayerRecord(
      handle: locked, name: 'Locked', color: const DraftColor.index(7),
      linetype: ReservedHandles.linetypeContinuous,
      lineweight: kLineweightDefault, transparency: 0,
      visible: true, locked: true,
    ));
    final slot = addOn(doc, doc.rootHandle, locked);
    final evaluator = FilterEvaluator(doc);

    expect(
        evaluator.acceptsEntity(slot, const QueryFilter.rendering()), isTrue,
        reason: 'a locked layer still draws');
    expect(evaluator.acceptsEntity(slot, const QueryFilter.picking()), isFalse,
        reason: 'a locked layer is not selectable');
  });

  test('an entity under a hidden ancestor group is hidden', () {
    final doc = DraftDocument.empty();
    const group = Handle(100);
    doc.commands.execute(AddNodeCommand(
      node: GroupNode(
        handle: group,
        parent: doc.rootHandle,
        transform: Transform2.identity(),
        children: const [],
        visible: false,
      ),
    ));
    final slot = addOn(doc, group, ReservedHandles.layerZero);
    final evaluator = FilterEvaluator(doc);

    expect(
        evaluator.acceptsEntity(slot, const QueryFilter.rendering()), isFalse,
        reason: 'visibility is inherited down the container chain');
    expect(evaluator.acceptsEntity(slot, const QueryFilter.all()), isTrue);
  });

  test('an entity two hidden levels up is still hidden', () {
    final doc = DraftDocument.empty();
    const outer = Handle(100);
    const inner = Handle(101);
    doc.commands.execute(AddNodeCommand(
      node: GroupNode(
        handle: outer, parent: doc.rootHandle,
        transform: Transform2.identity(), children: const [], visible: false,
      ),
    ));
    doc.commands.execute(AddNodeCommand(
      node: GroupNode(
        handle: inner, parent: outer,
        transform: Transform2.identity(), children: const [], visible: true,
      ),
    ));
    final slot = addOn(doc, inner, ReservedHandles.layerZero);
    final evaluator = FilterEvaluator(doc);

    expect(
        evaluator.acceptsEntity(slot, const QueryFilter.rendering()), isFalse);
  });

  test('acceptsNode applies the same rules to an instance', () {
    final doc = DraftDocument.empty();
    const def = Handle(200);
    const instance = Handle(400);
    doc.tree.addDefinition(Definition(
      handle: def, name: 'T', basePoint: Vector2.zero(), children: const [],
    ));
    doc.commands.execute(AddNodeCommand(
      node: InstanceNode(
        handle: instance, parent: doc.rootHandle,
        transform: Transform2.identity(), definition: def,
        layer: ReservedHandles.layerZero, visible: false,
      ),
    ));
    final evaluator = FilterEvaluator(doc);

    expect(evaluator.acceptsNode(instance, const QueryFilter.all()), isTrue);
    expect(evaluator.acceptsNode(instance, const QueryFilter.rendering()),
        isFalse);
  });

  test('invalidate picks up a layer flipped after the first query', () {
    final doc = DraftDocument.empty();
    const layer = Handle(52);
    doc.tables.layers.add(LayerRecord(
      handle: layer, name: 'L', color: const DraftColor.index(7),
      linetype: ReservedHandles.linetypeContinuous,
      lineweight: kLineweightDefault, transparency: 0,
      visible: true, locked: false,
    ));
    final slot = addOn(doc, doc.rootHandle, layer);
    final evaluator = FilterEvaluator(doc);

    expect(
        evaluator.acceptsEntity(slot, const QueryFilter.rendering()), isTrue);

    doc.tables.layers.replace(LayerRecord(
      handle: layer, name: 'L', color: const DraftColor.index(7),
      linetype: ReservedHandles.linetypeContinuous,
      lineweight: kLineweightDefault, transparency: 0,
      visible: false, locked: false,
    ));
    evaluator.invalidate();

    expect(
        evaluator.acceptsEntity(slot, const QueryFilter.rendering()), isFalse,
        reason: 'a cached answer must not outlive an invalidate()');
  });

  test('an entity on a layer that does not exist is accepted', () {
    final doc = DraftDocument.empty();
    final slot = addOn(doc, doc.rootHandle, const Handle(9999));
    final evaluator = FilterEvaluator(doc);

    expect(evaluator.acceptsEntity(slot, const QueryFilter.picking()), isTrue,
        reason: 'a missing layer is validate()s problem, not a reason to make '
            'geometry silently unselectable');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd packages/jet_cad_2d && dart test test/index/query_filter_test.dart
```

Expected: `Undefined name 'QueryFilter'`.

**Read `lib/src/document/tables.dart` before fixing the test's `LayerRecord`
constructor call and the `doc.tables.layers` accessor name.** The plan's names
here are the most likely place for a mismatch, and a wrong one is a compile
error rather than a silent defect.

- [ ] **Step 3: Write the implementation**

Create `packages/jet_cad_2d/lib/src/index/query_filter.dart`:

```dart
import '../core/handle.dart';
import '../document/draft_document.dart';
import '../document/node.dart';

/// What a query should skip.
///
/// A filter is a query parameter rather than something the caller applies to
/// the results, because applying it afterwards means the index returns work the
/// caller throws away — at frame rate. Three callers want three answers:
/// "select all on this layer" wants everything, rendering wants visible,
/// picking wants visible and unlocked.
final class QueryFilter {
  const QueryFilter({required this.visibleOnly, required this.excludeLocked});

  /// Everything, hidden and locked included.
  const QueryFilter.all() : visibleOnly = false, excludeLocked = false;

  /// What the renderer draws. A locked layer still draws.
  const QueryFilter.rendering() : visibleOnly = true, excludeLocked = false;

  /// What a pointer can select.
  const QueryFilter.picking() : visibleOnly = true, excludeLocked = true;

  final bool visibleOnly;
  final bool excludeLocked;

  /// True when this filter rejects nothing, so callers can skip evaluation.
  bool get isPassthrough => !visibleOnly && !excludeLocked;
}

/// Applies a [QueryFilter], caching what it can.
///
/// A layer lookup per entity per frame is a map hit per entity per frame, so
/// per-layer answers are memoised. The cache must be dropped whenever a layer
/// record or a node's visibility changes; [invalidate] is that hook.
class FilterEvaluator {
  FilterEvaluator(this.document);

  final DraftDocument document;
  final Map<Handle, bool> _layerVisible = <Handle, bool>{};
  final Map<Handle, bool> _layerLocked = <Handle, bool>{};
  final Map<Handle, bool> _containerVisible = <Handle, bool>{};

  void invalidate() {
    _layerVisible.clear();
    _layerLocked.clear();
    _containerVisible.clear();
  }

  bool acceptsEntity(int slot, QueryFilter filter) {
    if (filter.isPassthrough) return true;
    final layer = document.entities.layerAt(slot);
    if (filter.visibleOnly) {
      if (!_visibleLayer(layer)) return false;
      if (!_visibleContainer(document.entities.ownerAt(slot))) return false;
    }
    if (filter.excludeLocked && _lockedLayer(layer)) return false;
    return true;
  }

  bool acceptsNode(Handle node, QueryFilter filter) {
    if (filter.isPassthrough) return true;
    final resolved = document.tree[node];
    if (resolved == null) return true;
    if (filter.visibleOnly) {
      if (!resolved.visible) return false;
      if (!_visibleContainer(resolved.parent)) return false;
      if (resolved is InstanceNode && !_visibleLayer(resolved.layer)) {
        return false;
      }
    }
    if (filter.excludeLocked &&
        resolved is InstanceNode &&
        _lockedLayer(resolved.layer)) {
      return false;
    }
    return true;
  }

  /// A layer this document does not have is treated as visible and unlocked.
  ///
  /// A missing layer is `validate()`'s problem. Making the geometry silently
  /// unselectable instead would turn a reportable inconsistency into a user
  /// staring at something they cannot click.
  bool _visibleLayer(Handle layer) =>
      _layerVisible[layer] ??= document.tables.layers[layer]?.visible ?? true;

  bool _lockedLayer(Handle layer) =>
      _layerLocked[layer] ??= document.tables.layers[layer]?.locked ?? false;

  /// Visibility is inherited: a leaf under a hidden group is hidden, however
  /// many visible levels sit between them.
  bool _visibleContainer(Handle container) {
    final cached = _containerVisible[container];
    if (cached != null) return cached;

    var current = container;
    var guard = 0;
    var visible = true;
    while (guard++ < 256) {
      final node = document.tree[current];
      if (node == null) break;              // a definition, or the root
      if (!node.visible) {
        visible = false;
        break;
      }
      if (node.parent == current) break;    // malformed; validate() reports it
      current = node.parent;
    }
    return _containerVisible[container] = visible;
  }
}
```

- [ ] **Step 4: Export it**

```dart
export 'src/index/query_filter.dart';
```

- [ ] **Step 5: Run the tests**

```bash
cd packages/jet_cad_2d && dart test && dart analyze && dart format --set-exit-if-changed lib test
```

Expected: 313 + 8 = 321 passing.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "feat(jet_cad_2d): QueryFilter for visibility and locking

A filter is a query parameter, not caller policy: applying it after the
fact means the index returns work the caller throws away at frame rate.
Rendering wants visible, picking wants visible and unlocked, select-all
wants everything.

Per-layer answers are memoised because a layer lookup per entity per
frame is a map hit per entity per frame. A missing layer is treated as
visible and unlocked — that is validate()'s problem, and hiding the
geometry would leave a user unable to click something they can see."
```

---

### Task 9: Query scratch, in-place sort, and the rect queries

**Files:**
- Create: `packages/jet_cad_2d/lib/src/index/query_scratch.dart`
- Modify: `packages/jet_cad_2d/lib/src/index/spatial_index.dart` (add the queries)
- Test: `packages/jet_cad_2d/test/index/query_scratch_test.dart`
- Test: `packages/jet_cad_2d/test/index/rect_query_test.dart`

**Interfaces:**
- Consumes: `SpatialIndex`, `QueryFilter`, `FilterEvaluator`, `EntityStore`.
- Produces:

```dart
class QueryScratch {
  int get length; int get capacity;
  void reset();
  void add(int slot);
  void sortByHandle(EntityStore entities);
  int operator [](int i);
}

// on SpatialIndex:
void forEachInRect(Aabb2 world, QueryFilter filter, void Function(int slot) visit);
void forEachInstanceInRect(Aabb2 world, QueryFilter filter,
                           void Function(Handle instance) visit);
```

**Two rect queries, not one.** The parent spec named a single `forEachInRect`
and did not say whether it descends into instances. It must not: descending
would visit a shared definition's entities once per instance, so a document
with 500 tables would report the same slot 500 times with no way to tell the
instances apart. The renderer does not want that either — it replays one cached
picture per instance. So root-level leaves and instances are two separate
traversals, and pick and snap (which do descend) are separate methods again.

**Ordering requires buffering, which is why it is specified.** Slots are
collected into a preallocated scratch, sorted by handle, then visited. The
sort is hand-written over the live prefix: `List.sort` needs a sublist view,
which allocates.

- [ ] **Step 1: Write the failing tests**

Create `packages/jet_cad_2d/test/index/query_scratch_test.dart`:

```dart
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

void main() {
  test('starts empty and reset makes it empty again', () {
    final scratch = QueryScratch()..add(1)..add(2);
    expect(scratch.length, 2);
    scratch.reset();
    expect(scratch.length, 0);
  });

  test('grows past its initial capacity without losing entries', () {
    final scratch = QueryScratch();
    final initial = scratch.capacity;
    for (var i = 0; i < initial * 4; i++) {
      scratch.add(i);
    }
    expect(scratch.length, initial * 4);
    expect(scratch.capacity, greaterThanOrEqualTo(initial * 4));
    for (var i = 0; i < initial * 4; i++) {
      expect(scratch[i], i);
    }
  });

  test('capacity is retained across reset, which is what warming means', () {
    final scratch = QueryScratch();
    for (var i = 0; i < 5000; i++) {
      scratch.add(i);
    }
    final grown = scratch.capacity;
    scratch.reset();
    expect(scratch.capacity, grown,
        reason: 'reset must not shrink, or every query would regrow');
  });

  test('sortByHandle orders slots by their entity handle, not by slot', () {
    final doc = DraftDocument.empty();
    // Deliberately add so that slot order and handle order disagree: remove
    // the middle entity, then add a new one, which reuses the freed slot while
    // taking a larger handle.
    final a = _add(doc);   // slot 0
    final b = _add(doc);   // slot 1
    final c = _add(doc);   // slot 2
    doc.commands.execute(RemoveEntityCommand(handle: b));
    final d = _add(doc);   // reuses slot 1, handle > c

    final slotA = doc.entities.slotOf(a)!;
    final slotC = doc.entities.slotOf(c)!;
    final slotD = doc.entities.slotOf(d)!;
    expect(slotD, lessThan(slotC),
        reason: 'the fixture is only meaningful if slot order disagrees');

    final scratch = QueryScratch()
      ..add(slotC)
      ..add(slotD)
      ..add(slotA);
    scratch.sortByHandle(doc.entities);

    expect([scratch[0], scratch[1], scratch[2]], [slotA, slotC, slotD]);
  });

  test('sorting is stable enough to be deterministic across runs', () {
    final doc = DraftDocument.empty();
    final handles = [for (var i = 0; i < 50; i++) _add(doc)];
    final slots = [for (final h in handles) doc.entities.slotOf(h)!];

    List<int> sortOnce() {
      final scratch = QueryScratch();
      for (final s in slots.reversed) {
        scratch.add(s);
      }
      scratch.sortByHandle(doc.entities);
      return [for (var i = 0; i < scratch.length; i++) scratch[i]];
    }

    expect(sortOnce(), sortOnce());
    expect(sortOnce(), slots);
  });

  test('sorting an empty and a single-element scratch is safe', () {
    final doc = DraftDocument.empty();
    final scratch = QueryScratch()..sortByHandle(doc.entities);
    expect(scratch.length, 0);

    final h = _add(doc);
    scratch.add(doc.entities.slotOf(h)!);
    scratch.sortByHandle(doc.entities);
    expect(scratch.length, 1);
  });
}

Handle _add(DraftDocument doc) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: doc.rootHandle,
      kind: EntityKind.point,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.linetypeByLayer,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const DraftColor.byLayer(),
      lineweight: kByLayer,
      transparency: kByLayer,
      flags: 0,
    ),
    payload: GeometryPayload(
      coords: Float64List.fromList([0, 0]),
      scalars: Float64List(0),
    ),
  ));
  return handle;
}
```

Add `import 'dart:typed_data';` at the top of that file.

Create `packages/jet_cad_2d/test/index/rect_query_test.dart`:

```dart
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

Handle addLine(DraftDocument doc, Handle owner, double x, double y) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle, owner: owner, kind: EntityKind.line,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.linetypeByLayer, linetypeScale: 1.0,
      geomIndex: 0, color: const DraftColor.byLayer(),
      lineweight: kByLayer, transparency: kByLayer, flags: 0,
    ),
    payload: GeometryPayload(
      coords: Float64List.fromList([x, y, x + 1, y + 1]),
      scalars: Float64List(0),
    ),
  ));
  return handle;
}

Aabb2 rect(double minX, double minY, double maxX, double maxY) =>
    Aabb2(Vector2(minX, minY), Vector2(maxX, maxY));

void main() {
  test('returns overlapping root leaves in ascending handle order', () {
    final doc = DraftDocument.empty();
    final handles = [
      for (var i = 0; i < 20; i++) addLine(doc, doc.rootHandle, i * 10.0, 0),
    ];
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final seen = <Handle>[];
    index.forEachInRect(rect(-1, -1, 35, 5), const QueryFilter.all(),
        (slot) => seen.add(doc.entities.handleAt(slot)));

    expect(seen, [handles[0], handles[1], handles[2], handles[3]]);
    expect(seen, orderedEquals(List.of(seen)..sort((a, b) => a.value.compareTo(b.value))));
  });

  test('does NOT descend into instances', () {
    final doc = DraftDocument.empty();
    const def = Handle(200);
    doc.tree.addDefinition(Definition(
      handle: def, name: 'T', basePoint: Vector2.zero(), children: const [],
    ));
    addLine(doc, def, 0, 0);

    for (var i = 0; i < 5; i++) {
      doc.commands.execute(AddNodeCommand(
        node: InstanceNode(
          handle: Handle(400 + i), parent: doc.rootHandle,
          transform: Transform2.translation(i * 2.0, 0),
          definition: def, layer: ReservedHandles.layerZero,
        ),
      ));
    }
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    var leafVisits = 0;
    index.forEachInRect(
        rect(-10, -10, 100, 100), const QueryFilter.all(), (_) => leafVisits++);
    expect(leafVisits, 0,
        reason: 'descending would report the shared slot once per instance, '
            'with no way to tell the instances apart');

    final instances = <Handle>[];
    index.forEachInstanceInRect(
        rect(-10, -10, 100, 100), const QueryFilter.all(), instances.add);
    expect(instances, hasLength(5));
  });

  test('instances come back in ascending handle order', () {
    final doc = DraftDocument.empty();
    const def = Handle(200);
    doc.tree.addDefinition(Definition(
      handle: def, name: 'T', basePoint: Vector2.zero(), children: const [],
    ));
    addLine(doc, def, 0, 0);
    for (final h in [Handle(407), Handle(401), Handle(404)]) {
      doc.commands.execute(AddNodeCommand(
        node: InstanceNode(
          handle: h, parent: doc.rootHandle, transform: Transform2.identity(),
          definition: def, layer: ReservedHandles.layerZero,
        ),
      ));
    }
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final seen = <Handle>[];
    index.forEachInstanceInRect(
        rect(-10, -10, 10, 10), const QueryFilter.all(), seen.add);
    expect(seen, [const Handle(401), const Handle(404), const Handle(407)]);
  });

  test('the filter is applied inside the query, not by the caller', () {
    final doc = DraftDocument.empty();
    const hidden = Handle(50);
    doc.tables.layers.add(LayerRecord(
      handle: hidden, name: 'H', color: const DraftColor.index(7),
      linetype: ReservedHandles.linetypeContinuous,
      lineweight: kLineweightDefault, transparency: 0,
      visible: false, locked: false,
    ));
    addLine(doc, doc.rootHandle, 0, 0);
    final onHidden = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
      record: EntityRecord(
        handle: onHidden, owner: doc.rootHandle, kind: EntityKind.line,
        layer: hidden, linetype: ReservedHandles.linetypeByLayer,
        linetypeScale: 1.0, geomIndex: 0, color: const DraftColor.byLayer(),
        lineweight: kByLayer, transparency: kByLayer, flags: 0,
      ),
      payload: GeometryPayload(
        coords: Float64List.fromList([0, 0, 1, 1]),
        scalars: Float64List(0),
      ),
    ));

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    var all = 0, rendering = 0;
    index.forEachInRect(rect(-1, -1, 5, 5), const QueryFilter.all(), (_) => all++);
    index.forEachInRect(
        rect(-1, -1, 5, 5), const QueryFilter.rendering(), (_) => rendering++);

    expect(all, 2);
    expect(rendering, 1);
  });

  test('an empty query rect returns nothing', () {
    final doc = DraftDocument.empty();
    addLine(doc, doc.rootHandle, 0, 0);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    var visits = 0;
    index.forEachInRect(Aabb2.empty(), const QueryFilter.all(), (_) => visits++);
    expect(visits, 0);
  });

  test('a slot that is both in the tree and dirty is reported once', () {
    final doc = DraftDocument.empty();
    final handle = addLine(doc, doc.rootHandle, 0, 0);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    // Move it: the tree entry is marked dead and a dirty entry is written.
    doc.commands.execute(RemoveEntityCommand(handle: handle));
    doc.commands.undo();

    var visits = 0;
    index.forEachInRect(rect(-10, -10, 10, 10), const QueryFilter.all(),
        (_) => visits++);
    expect(visits, 1, reason: 'the dead bitmask exists to prevent a double report');
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
cd packages/jet_cad_2d && dart test test/index/query_scratch_test.dart test/index/rect_query_test.dart
```

Expected: `Undefined name 'QueryScratch'` and `The method 'forEachInRect' isn't defined`.

- [ ] **Step 3: Write `QueryScratch`**

Create `packages/jet_cad_2d/lib/src/index/query_scratch.dart`:

```dart
import 'dart:typed_data';

import '../store/entity_store.dart';

/// A reusable result buffer for one query.
///
/// Ordering requires buffering, so a query that promises ascending handle
/// order cannot stream straight to its visitor. This is that buffer, owned by
/// the index and reused, so a query allocates nothing in steady state.
///
/// [reset] deliberately does not shrink: capacity is the whole point, and a
/// scratch that shrank would regrow on every query, which is exactly the
/// allocation this exists to avoid. That is also why the allocation harness
/// warms a query before asserting.
class QueryScratch {
  QueryScratch([int initialCapacity = 1024])
      : _slots = Int32List(initialCapacity);

  Int32List _slots;
  int _length = 0;

  int get length => _length;
  int get capacity => _slots.length;

  int operator [](int i) => _slots[i];

  void reset() => _length = 0;

  void add(int slot) {
    if (_length == _slots.length) {
      final grown = Int32List(_slots.length * 2);
      grown.setRange(0, _length, _slots);
      _slots = grown;
    }
    _slots[_length++] = slot;
  }

  /// Sorts the live prefix by entity handle, ascending.
  ///
  /// Hand-written rather than `List.sort`, which would need a sublist view of
  /// the live prefix — and that view allocates, once per query, on the frame
  /// path.
  ///
  /// Insertion sort below a threshold, heapsort above it. Heapsort rather than
  /// quicksort because it is in-place with no recursion and no worst case that
  /// a crafted document could trigger.
  void sortByHandle(EntityStore entities) {
    if (_length < 2) return;
    if (_length <= 32) {
      for (var i = 1; i < _length; i++) {
        final value = _slots[i];
        final key = entities.handleAt(value).value;
        var j = i - 1;
        while (j >= 0 && entities.handleAt(_slots[j]).value > key) {
          _slots[j + 1] = _slots[j];
          j--;
        }
        _slots[j + 1] = value;
      }
      return;
    }

    for (var start = (_length >> 1) - 1; start >= 0; start--) {
      _siftDown(entities, start, _length);
    }
    for (var end = _length - 1; end > 0; end--) {
      final tmp = _slots[0];
      _slots[0] = _slots[end];
      _slots[end] = tmp;
      _siftDown(entities, 0, end);
    }
  }

  void _siftDown(EntityStore entities, int root, int end) {
    var parent = root;
    while (true) {
      final left = parent * 2 + 1;
      if (left >= end) return;
      var swap = parent;
      if (entities.handleAt(_slots[swap]).value <
          entities.handleAt(_slots[left]).value) {
        swap = left;
      }
      final right = left + 1;
      if (right < end &&
          entities.handleAt(_slots[swap]).value <
              entities.handleAt(_slots[right]).value) {
        swap = right;
      }
      if (swap == parent) return;
      final tmp = _slots[parent];
      _slots[parent] = _slots[swap];
      _slots[swap] = tmp;
      parent = swap;
    }
  }
}
```

- [ ] **Step 4: Add the rect queries to `SpatialIndex`**

```dart
  final QueryScratch _scratch = QueryScratch();
  final List<Handle> _instanceScratch = <Handle>[];
  late final FilterEvaluator _filters = FilterEvaluator(document);

  /// Visits the slot of every root-level leaf whose box overlaps [world],
  /// in ascending handle order.
  ///
  /// **Does not descend into instances.** A shared definition's entities would
  /// otherwise be reported once per instance, with no way to tell the
  /// instances apart — and the renderer does not want that, since it replays
  /// one cached picture per instance. Use [forEachInstanceInRect] for those,
  /// and `pickInto` when you need to descend.
  void forEachInRect(
      Aabb2 world, QueryFilter filter, void Function(int slot) visit) {
    if (world.isEmpty) return;
    _scratch.reset();
    rootIndex.searchLeaves(world, (slot) {
      if (_filters.acceptsEntity(slot, filter)) _scratch.add(slot);
    });
    _scratch.sortByHandle(document.entities);
    for (var i = 0; i < _scratch.length; i++) {
      visit(_scratch[i]);
    }
  }

  /// Visits every root-level instance whose box overlaps [world], ascending.
  void forEachInstanceInRect(
      Aabb2 world, QueryFilter filter, void Function(Handle instance) visit) {
    if (world.isEmpty) return;
    _instanceScratch.clear();
    rootIndex.searchInstances(world, (node) {
      if (_filters.acceptsNode(node, filter)) _instanceScratch.add(node);
    });
    _instanceScratch.sort((a, b) => a.value.compareTo(b.value));
    for (final node in _instanceScratch) {
      visit(node);
    }
  }
```

Call `_filters.invalidate()` from `rebuildAll`, so a layer edit that triggers a
rebuild also drops the cached visibility answers.

- [ ] **Step 5: Correct Plan 1's stale draw-order documentation**

Plan 1's `_childrenOf` doc comment in
`packages/jet_cad_2d/lib/src/document/draft_document.dart` states that leaves
come back in ascending **slot** order and that this "is not an explicit
z-order". Ascending handle is now *the* draw order, so that paragraph is wrong
in the one place a reader would look for the rule.

Replace the paragraph beginning "Leaves come back in ascending **slot** order"
with:

```dart
  /// Leaves come back in ascending **slot** order, which is an implementation
  /// detail of this walk and not an ordering anyone may rely on: a slot moves
  /// under `purge()` and under undo. **Draw order is ascending handle value**,
  /// which is stable across undo, save, load and purge, and is what every
  /// query returns and what hit-test ties break on. A caller that needs draw
  /// order must sort by handle — `SpatialIndex` does this for its callers.
  /// Only [GroupNode.children] carries a deliberate order, and it orders child
  /// nodes.
```

Leaving the old text would put a contradicted rule in the most likely place for
someone to read it, which is worse than having no comment at all.

- [ ] **Step 6: Run the tests**

```bash
cd packages/jet_cad_2d && dart test && dart analyze && dart format --set-exit-if-changed lib test
```

Expected: 321 + 11 = 332 passing.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "feat(jet_cad_2d): rect queries with a warmed scratch and in-place sort

Two rect queries rather than one. forEachInRect must not descend into
instances: a shared definition's entities would be reported once per
instance with no way to tell them apart, and the renderer replays one
cached picture per instance anyway.

Ascending handle order requires buffering, so results go through a
reusable scratch that never shrinks on reset. The sort is hand-written
because List.sort needs a sublist view of the live prefix, and that view
allocates once per query on the frame path."
```

---

### Task 10: Reentrancy and in-visitor mutation guards

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/index/spatial_index.dart`
- Modify: `packages/jet_cad_2d/lib/src/document/undo.dart` (dispatcher-side check)
- Test: `packages/jet_cad_2d/test/index/reentrancy_test.dart`

**Interfaces:**
- Produces: `class QueryReentrancyError implements Exception`, and on `CommandDispatcher` a settable `void Function()? onBeforeMutate` hook.

**Why the dispatcher is involved.** The scratch stack is owned by the index, so
a query inside a visitor corrupts the walk — that much is expected. **Mutating
the document inside a visitor is the more likely mistake and the less expected
one**: it changes the very structure being walked, and nothing about the API
suggests it is forbidden. Asserting only on the query side would leave the
worse error undetected.

The hook is a nullable callback rather than a direct dependency because
`undo.dart` must not import the index — the dependency runs the other way.

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d/test/index/reentrancy_test.dart`:

```dart
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

Handle addLine(DraftDocument doc, double x, double y) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle, owner: doc.rootHandle, kind: EntityKind.line,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.linetypeByLayer, linetypeScale: 1.0,
      geomIndex: 0, color: const DraftColor.byLayer(),
      lineweight: kByLayer, transparency: kByLayer, flags: 0,
    ),
    payload: GeometryPayload(
      coords: Float64List.fromList([x, y, x + 1, y + 1]),
      scalars: Float64List(0),
    ),
  ));
  return handle;
}

Aabb2 rect(double a, double b, double c, double d) =>
    Aabb2(Vector2(a, b), Vector2(c, d));

void main() {
  test('a query inside a visitor throws rather than returning nonsense', () {
    final doc = DraftDocument.empty();
    addLine(doc, 0, 0);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    expect(
      () => index.forEachInRect(rect(-1, -1, 10, 10), const QueryFilter.all(),
          (_) {
        index.forEachInRect(
            rect(-1, -1, 10, 10), const QueryFilter.all(), (_) {});
      }),
      throwsA(isA<QueryReentrancyError>()),
    );
  });

  test('mutating the document inside a visitor throws', () {
    final doc = DraftDocument.empty();
    addLine(doc, 0, 0);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    expect(
      () => index.forEachInRect(
          rect(-1, -1, 10, 10), const QueryFilter.all(), (_) {
        addLine(doc, 5, 5);
      }),
      throwsA(isA<QueryReentrancyError>()),
      reason: 'mutation inside a visitor changes the structure being walked, '
          'and is the more likely of the two mistakes',
    );
  });

  test('undo inside a visitor throws too', () {
    final doc = DraftDocument.empty();
    addLine(doc, 0, 0);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    expect(
      () => index.forEachInRect(
          rect(-1, -1, 10, 10), const QueryFilter.all(), (_) {
        doc.commands.undo();
      }),
      throwsA(isA<QueryReentrancyError>()),
    );
  });

  test('the flag clears after a query, including one that threw', () {
    final doc = DraftDocument.empty();
    addLine(doc, 0, 0);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    try {
      index.forEachInRect(rect(-1, -1, 10, 10), const QueryFilter.all(), (_) {
        throw StateError('visitor blew up');
      });
    } on StateError {
      // expected
    }

    // If the flag leaked, this second query would throw QueryReentrancyError.
    var visits = 0;
    index.forEachInRect(
        rect(-1, -1, 10, 10), const QueryFilter.all(), (_) => visits++);
    expect(visits, 1);

    // And mutation is allowed again.
    expect(() => addLine(doc, 9, 9), returnsNormally);
  });

  test('sequential queries are fine — only nesting is forbidden', () {
    final doc = DraftDocument.empty();
    addLine(doc, 0, 0);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    var first = 0, second = 0;
    index.forEachInRect(
        rect(-1, -1, 10, 10), const QueryFilter.all(), (_) => first++);
    index.forEachInRect(
        rect(-1, -1, 10, 10), const QueryFilter.all(), (_) => second++);
    expect(first, 1);
    expect(second, 1);
  });

  test('forEachInstanceInRect is guarded as well', () {
    final doc = DraftDocument.empty();
    const def = Handle(200);
    doc.tree.addDefinition(Definition(
      handle: def, name: 'T', basePoint: Vector2.zero(), children: const [],
    ));
    addLine(doc, 0, 0);
    doc.commands.execute(AddNodeCommand(
      node: InstanceNode(
        handle: const Handle(400), parent: doc.rootHandle,
        transform: Transform2.identity(), definition: def,
        layer: ReservedHandles.layerZero,
      ),
    ));
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    expect(
      () => index.forEachInstanceInRect(
          rect(-10, -10, 10, 10), const QueryFilter.all(), (_) {
        addLine(doc, 5, 5);
      }),
      throwsA(isA<QueryReentrancyError>()),
    );
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd packages/jet_cad_2d && dart test test/index/reentrancy_test.dart
```

Expected: `Undefined name 'QueryReentrancyError'`.

- [ ] **Step 3: Add the dispatcher hook**

In `packages/jet_cad_2d/lib/src/document/undo.dart`, on `CommandDispatcher`:

```dart
  /// Called before `execute`, `undo` and `redo` mutate anything.
  ///
  /// Exists so a derived structure that is mid-walk can refuse the mutation:
  /// changing the document inside a query visitor changes the structure being
  /// walked. Nullable and settable rather than a direct dependency, because
  /// this layer must not import the index — the dependency runs the other way.
  void Function()? onBeforeMutate;
```

Call `onBeforeMutate?.call()` as the very first statement of `execute`, `undo`
and `redo` — before the permission check and before the disposal check, so that
a forbidden mutation is reported as such rather than as whatever the next guard
would have said.

- [ ] **Step 4: Add the guard to `SpatialIndex`**

```dart
/// Thrown when a query runs inside another query's visitor, or when the
/// document is mutated inside one.
///
/// Both corrupt the walk. The index owns a single reusable scratch stack —
/// that is what makes a query allocation-free — so a nested query overwrites
/// the outer one's state, and a mutation changes the structure being walked
/// underneath it.
class QueryReentrancyError implements Exception {
  const QueryReentrancyError(this.what);
  final String what;
  @override
  String toString() =>
      'QueryReentrancyError: $what is not permitted inside a query visitor. '
      'Collect the results first, then act on them.';
}
```

In `SpatialIndex`, add `bool _inQuery = false;`, install the hook in the
constructor, and clear it in `dispose`:

```dart
    document.commands.onBeforeMutate = () {
      if (_inQuery) throw const QueryReentrancyError('mutating the document');
    };
```

Wrap both query bodies:

```dart
  void forEachInRect(
      Aabb2 world, QueryFilter filter, void Function(int slot) visit) {
    if (world.isEmpty) return;
    if (_inQuery) throw const QueryReentrancyError('a nested query');
    _inQuery = true;
    try {
      // ... existing body ...
    } finally {
      // `finally` rather than a trailing assignment: a visitor that throws
      // must not leave the index permanently unqueryable.
      _inQuery = false;
    }
  }
```

- [ ] **Step 5: Run the tests**

```bash
cd packages/jet_cad_2d && dart test && dart analyze && dart format --set-exit-if-changed lib test
```

Expected: 332 + 6 = 338 passing.

**If any pre-existing test now fails**, the likely cause is `onBeforeMutate`
being invoked before a disposal or permission check that a test asserts on.
Check the order: the hook must run first, but it must not swallow the later
checks.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "feat(jet_cad_2d): guard query reentrancy and in-visitor mutation

The scratch stack is what makes a query allocation-free, and it is
single. A nested query overwrites the outer walk's state; a mutation
changes the structure being walked. Both are now errors rather than
wrong answers.

The dispatcher check matters more than the query one: mutating inside a
visitor is the likelier mistake and nothing about the API suggests it is
forbidden. The hook is a nullable callback so undo.dart does not import
the index."
```

---

### Task 11: Narrow-phase distance primitives

**Files:**
- Create: `packages/jet_cad_2d/lib/src/geometry/distance.dart`
- Test: `packages/jet_cad_2d/test/geometry/distance_test.dart`

**Interfaces:**
- Consumes: `Vector2`, `GeometryPayload`, `EntityKind`, `Tolerance`.
- Produces:

```dart
double distanceToSegment(Vector2 p, Vector2 a, Vector2 b);
double distanceToCircle(Vector2 p, Vector2 centre, double radius);
double distanceToArc(Vector2 p, Vector2 centre, double radius,
                     double startAngle, double sweep);
double distanceToPolyline(Vector2 p, GeometryPayload payload);
bool insideClosedPolyline(Vector2 p, GeometryPayload payload);
double? nearestVertexDistance(Vector2 p, GeometryPayload payload, Vector2 out);
```

**Everything here works in world space.** The broad phase inverse-transforms
the query and accepts false positives; the narrow phase transforms the
*candidate* instead. That is exact under any affine — including mirroring and
non-uniform scale — and avoids ellipse math entirely. These functions therefore
take already-transformed geometry and never see a `Transform2`.

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d/test/geometry/distance_test.dart`:

```dart
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

GeometryPayload poly(List<double> coords) => GeometryPayload(
      coords: Float64List.fromList(coords),
      scalars: Float64List(0),
    );

void main() {
  group('distanceToSegment', () {
    test('is zero on the segment and at its endpoints', () {
      final a = Vector2(0, 0), b = Vector2(10, 0);
      expect(distanceToSegment(Vector2(5, 0), a, b), closeTo(0, 1e-12));
      expect(distanceToSegment(a, a, b), closeTo(0, 1e-12));
      expect(distanceToSegment(b, a, b), closeTo(0, 1e-12));
    });

    test('is the perpendicular distance beside the segment', () {
      expect(distanceToSegment(Vector2(5, 3), Vector2(0, 0), Vector2(10, 0)),
          closeTo(3, 1e-12));
    });

    test('clamps to the endpoint beyond the ends', () {
      // Beyond b, the answer is the distance to b, not to the infinite line.
      expect(distanceToSegment(Vector2(20, 0), Vector2(0, 0), Vector2(10, 0)),
          closeTo(10, 1e-12));
      expect(distanceToSegment(Vector2(-3, 4), Vector2(0, 0), Vector2(10, 0)),
          closeTo(5, 1e-12));
    });

    test('handles a degenerate zero-length segment', () {
      final p = Vector2(3, 4);
      expect(distanceToSegment(p, Vector2.zero(), Vector2.zero()),
          closeTo(5, 1e-12));
    });

    test('is exact at large coordinates', () {
      // 4.5e6 is where float32 would fail; Float64 must not.
      const big = 4500000.0;
      final d = distanceToSegment(Vector2(big + 5, big + 3),
          Vector2(big, big), Vector2(big + 10, big));
      expect(d, closeTo(3, 1e-9));
    });
  });

  group('distanceToCircle', () {
    test('is the distance to the rim, inside and out', () {
      final c = Vector2(0, 0);
      expect(distanceToCircle(Vector2(15, 0), c, 10), closeTo(5, 1e-12));
      expect(distanceToCircle(Vector2(5, 0), c, 10), closeTo(5, 1e-12),
          reason: 'a point inside is still 5 from the rim');
      expect(distanceToCircle(c, c, 10), closeTo(10, 1e-12));
      expect(distanceToCircle(Vector2(10, 0), c, 10), closeTo(0, 1e-12));
    });
  });

  group('distanceToArc', () {
    test('is zero on the arc and grows off it', () {
      // Quarter arc from 0 to pi/2, radius 10, centred at origin.
      final c = Vector2.zero();
      expect(distanceToArc(Vector2(10, 0), c, 10, 0, math.pi / 2),
          closeTo(0, 1e-9));
      expect(distanceToArc(Vector2(0, 10), c, 10, 0, math.pi / 2),
          closeTo(0, 1e-9));
      final mid = Vector2(10 * math.cos(math.pi / 4), 10 * math.sin(math.pi / 4));
      expect(distanceToArc(mid, c, 10, 0, math.pi / 2), closeTo(0, 1e-9));
    });

    test('measures to the nearer endpoint outside the sweep', () {
      // A point at angle pi (opposite side) is outside a 0..pi/2 arc, so the
      // answer is the distance to the (10, 0) endpoint, not to the rim.
      final c = Vector2.zero();
      final d = distanceToArc(Vector2(-10, 0), c, 10, 0, math.pi / 2);
      expect(d, closeTo(20, 1e-9),
          reason: 'clamping to the sweep is what separates an arc '
              'from a circle; without it this would be 0');
    });

    test('handles a negative sweep', () {
      final c = Vector2.zero();
      expect(distanceToArc(Vector2(10, 0), c, 10, 0, -math.pi / 2),
          closeTo(0, 1e-9));
      expect(distanceToArc(Vector2(0, -10), c, 10, 0, -math.pi / 2),
          closeTo(0, 1e-9));
    });
  });

  group('distanceToPolyline', () {
    test('is the minimum over every segment', () {
      final p = poly([0, 0, 10, 0, 10, 10]);
      expect(distanceToPolyline(Vector2(5, 2), p), closeTo(2, 1e-12));
      expect(distanceToPolyline(Vector2(12, 5), p), closeTo(2, 1e-12));
    });

    test('handles a single point', () {
      expect(distanceToPolyline(Vector2(3, 4), poly([0, 0])), closeTo(5, 1e-12));
    });

    test('handles an empty payload', () {
      expect(distanceToPolyline(Vector2(0, 0), poly([])), double.infinity);
    });
  });

  group('insideClosedPolyline', () {
    test('separates inside from outside for a square', () {
      final square = poly([0, 0, 10, 0, 10, 10, 0, 10]);
      expect(insideClosedPolyline(Vector2(5, 5), square), isTrue);
      expect(insideClosedPolyline(Vector2(15, 5), square), isFalse);
      expect(insideClosedPolyline(Vector2(-1, 5), square), isFalse);
    });

    test('handles a concave shape, where a bounding box would not', () {
      // An L: the notch at (8,8) is outside the shape but inside its box.
      final l = poly([0, 0, 10, 0, 10, 4, 4, 4, 4, 10, 0, 10]);
      expect(insideClosedPolyline(Vector2(2, 2), l), isTrue);
      expect(insideClosedPolyline(Vector2(8, 8), l), isFalse,
          reason: 'inside the bounding box but outside the shape');
    });

    test('is false for a degenerate polyline', () {
      expect(insideClosedPolyline(Vector2(0, 0), poly([0, 0, 1, 1])), isFalse);
    });
  });

  group('nearestVertexDistance', () {
    test('finds the closest vertex and writes it out', () {
      final p = poly([0, 0, 10, 0, 10, 10]);
      final out = Vector2.zero();
      final d = nearestVertexDistance(Vector2(9, 1), p, out);
      expect(d, closeTo(math.sqrt(2), 1e-12));
      expect(out.x, closeTo(10, 1e-12));
      expect(out.y, closeTo(0, 1e-12));
    });

    test('returns null for an empty payload and leaves out untouched', () {
      final out = Vector2(42, 42);
      expect(nearestVertexDistance(Vector2.zero(), poly([]), out), isNull);
      expect(out.x, 42);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd packages/jet_cad_2d && dart test test/geometry/distance_test.dart
```

Expected: `Undefined name 'distanceToSegment'`.

- [ ] **Step 3: Write the implementation**

Create `packages/jet_cad_2d/lib/src/geometry/distance.dart`:

```dart
import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import '../store/geometry_store.dart';

/// Narrow-phase distance, in world space.
///
/// The broad phase inverse-transforms the query into local space and accepts
/// false positives; the narrow phase transforms the *candidate* into world
/// space instead. That is exact under any affine — mirroring and non-uniform
/// scale included — and avoids ellipse math entirely, which is why nothing
/// here takes a Transform2.

/// Distance from [p] to the segment [a]-[b], clamped at the endpoints.
double distanceToSegment(Vector2 p, Vector2 a, Vector2 b) {
  final abx = b.x - a.x, aby = b.y - a.y;
  final lengthSq = abx * abx + aby * aby;
  // Exact zero, not a tolerance: this is the degenerate-segment branch, and
  // any non-zero length gives a valid projection.
  if (lengthSq == 0.0) {
    final dx = p.x - a.x, dy = p.y - a.y;
    return math.sqrt(dx * dx + dy * dy);
  }
  var t = ((p.x - a.x) * abx + (p.y - a.y) * aby) / lengthSq;
  if (t < 0.0) t = 0.0;
  if (t > 1.0) t = 1.0;
  final dx = p.x - (a.x + t * abx);
  final dy = p.y - (a.y + t * aby);
  return math.sqrt(dx * dx + dy * dy);
}

/// Distance from [p] to the *rim*. A point inside the circle is still its
/// distance from the rim, not zero: a circle entity is a curve, not a disc.
double distanceToCircle(Vector2 p, Vector2 centre, double radius) {
  final dx = p.x - centre.x, dy = p.y - centre.y;
  return (math.sqrt(dx * dx + dy * dy) - radius).abs();
}

/// Distance from [p] to an arc of [sweep] radians starting at [startAngle].
///
/// Outside the sweep the answer is the distance to the nearer endpoint.
/// Without that clamp an arc would behave exactly like a full circle, which
/// is the whole difference between the two.
double distanceToArc(Vector2 p, Vector2 centre, double radius,
    double startAngle, double sweep) {
  final dx = p.x - centre.x, dy = p.y - centre.y;
  final angle = math.atan2(dy, dx);

  final from = sweep >= 0 ? startAngle : startAngle + sweep;
  final span = sweep.abs();

  // Normalise the offset from the sweep start into [0, 2pi).
  var offset = (angle - from) % (2 * math.pi);
  if (offset < 0) offset += 2 * math.pi;

  if (offset <= span) {
    return (math.sqrt(dx * dx + dy * dy) - radius).abs();
  }

  final endA = Vector2(centre.x + radius * math.cos(from),
      centre.y + radius * math.sin(from));
  final endB = Vector2(centre.x + radius * math.cos(from + span),
      centre.y + radius * math.sin(from + span));
  return math.min(p.distanceTo(endA), p.distanceTo(endB));
}

/// Minimum distance from [p] to any segment of the polyline.
///
/// Returns [double.infinity] for an empty payload, so a caller comparing
/// against a pick radius rejects it without a special case.
double distanceToPolyline(Vector2 p, GeometryPayload payload) {
  final count = payload.pointCount;
  if (count == 0) return double.infinity;
  if (count == 1) return p.distanceTo(payload.pointAt(0));

  var best = double.infinity;
  for (var i = 0; i + 1 < count; i++) {
    final d = distanceToSegment(p, payload.pointAt(i), payload.pointAt(i + 1));
    if (d < best) best = d;
  }
  return best;
}

/// Even-odd ray cast: is [p] inside the polygon the payload's points close?
///
/// A bounding-box test is not a substitute — a concave shape has points inside
/// its box and outside itself, which is exactly the fill-hit case that matters
/// for an L-shaped room.
bool insideClosedPolyline(Vector2 p, GeometryPayload payload) {
  final count = payload.pointCount;
  if (count < 3) return false;

  var inside = false;
  for (var i = 0, j = count - 1; i < count; j = i++) {
    final pi = payload.pointAt(i);
    final pj = payload.pointAt(j);
    if ((pi.y > p.y) != (pj.y > p.y) &&
        p.x < (pj.x - pi.x) * (p.y - pi.y) / (pj.y - pi.y) + pi.x) {
      inside = !inside;
    }
  }
  return inside;
}

/// Distance to the nearest vertex, writing that vertex into [out].
///
/// Returns null and leaves [out] untouched when there are no points, so a
/// caller can distinguish "no vertex" from "a vertex at distance zero".
double? nearestVertexDistance(
    Vector2 p, GeometryPayload payload, Vector2 out) {
  final count = payload.pointCount;
  if (count == 0) return null;

  var best = double.infinity;
  var bestX = 0.0, bestY = 0.0;
  for (var i = 0; i < count; i++) {
    final v = payload.pointAt(i);
    final dx = p.x - v.x, dy = p.y - v.y;
    final d = math.sqrt(dx * dx + dy * dy);
    if (d < best) {
      best = d;
      bestX = v.x;
      bestY = v.y;
    }
  }
  out
    ..x = bestX
    ..y = bestY;
  return best;
}
```

- [ ] **Step 4: Export it**

```dart
export 'src/geometry/distance.dart';
```

- [ ] **Step 5: Run the tests**

```bash
cd packages/jet_cad_2d && dart test && dart analyze && dart format --set-exit-if-changed lib test
```

Expected: 338 + 16 = 354 passing.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "feat(jet_cad_2d): narrow-phase distance primitives in world space

The broad phase inverse-transforms the query and accepts false
positives; the narrow phase transforms the candidate instead. Exact
under any affine including mirroring, and no ellipse math — which is why
nothing here takes a Transform2.

distanceToArc clamps to the sweep and falls back to the nearer endpoint:
without that an arc behaves as a full circle, which is the entire
difference between the two."
```

---

### Task 12: `HitPath` and `pickInto`

**Files:**
- Create: `packages/jet_cad_2d/lib/src/index/hit.dart`
- Modify: `packages/jet_cad_2d/lib/src/index/spatial_index.dart` (add `pickInto`)
- Test: `packages/jet_cad_2d/test/index/pick_test.dart`

**Interfaces:**
- Consumes: `distance.dart`, `ContainerIndex`, `QueryFilter`.
- Produces:

```dart
enum HitKind { vertex, edge, fill }

class HitPath {
  HitPath([int chainCapacity = 16]);
  final Uint32List chain;     // root -> ... -> leaf, caller-owned
  int chainLength;
  Handle entity;
  Vector2 worldPoint;
  HitKind kind;
  bool truncated;
  void reset();
}

// on SpatialIndex:
bool pickInto(Vector2 world, double radius, QueryFilter filter, HitPath out);
```

**The engine reports a path, not a decision.** Plan 4's `DraftViewer` will
select `chain[0]` — tapping a chair selects its table — while `DraftDesigner`
descends into a group. Neither policy lives here.

**Tie-break, stated once:** greater root-level ancestor handle wins; if equal,
greater leaf handle wins. The parent spec's "topmost node, then draw order" is
circular now that draw order *is* handle order.

Priority is `vertex` > `edge` > `fill`, checked in that order: a click near a
line's endpoint means the endpoint, even though it is also on the line.

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d/test/index/pick_test.dart`:

```dart
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

Handle addEntity(DraftDocument doc, Handle owner, EntityKind kind,
    List<double> coords, List<double> scalars) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle, owner: owner, kind: kind,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.linetypeByLayer, linetypeScale: 1.0,
      geomIndex: 0, color: const DraftColor.byLayer(),
      lineweight: kByLayer, transparency: kByLayer, flags: 0,
    ),
    payload: GeometryPayload(
      coords: Float64List.fromList(coords),
      scalars: Float64List.fromList(scalars),
    ),
  ));
  return handle;
}

void main() {
  test('picks a line by its edge', () {
    final doc = DraftDocument.empty();
    final handle =
        addEntity(doc, doc.rootHandle, EntityKind.line, [0, 0, 10, 0], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final hit = HitPath();
    expect(index.pickInto(Vector2(5, 0.2), 1.0, const QueryFilter.all(), hit),
        isTrue);
    expect(hit.entity, handle);
    expect(hit.kind, HitKind.edge);
  });

  test('prefers a vertex over the edge it sits on', () {
    final doc = DraftDocument.empty();
    addEntity(doc, doc.rootHandle, EntityKind.line, [0, 0, 10, 0], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final hit = HitPath();
    // (0.1, 0) is on the line AND within radius of the endpoint at (0,0).
    expect(index.pickInto(Vector2(0.1, 0), 1.0, const QueryFilter.all(), hit),
        isTrue);
    expect(hit.kind, HitKind.vertex,
        reason: 'a click near an endpoint means the endpoint');
  });

  test('reports fill inside a closed polyline', () {
    final doc = DraftDocument.empty();
    final handle = addEntity(doc, doc.rootHandle, EntityKind.polyline,
        [0, 0, 10, 0, 10, 10, 0, 10, 0, 0], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final hit = HitPath();
    expect(index.pickInto(Vector2(5, 5), 0.1, const QueryFilter.all(), hit),
        isTrue);
    expect(hit.entity, handle);
    expect(hit.kind, HitKind.fill);
  });

  test('misses cleanly and leaves the path reset', () {
    final doc = DraftDocument.empty();
    addEntity(doc, doc.rootHandle, EntityKind.line, [0, 0, 10, 0], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final hit = HitPath();
    expect(
        index.pickInto(Vector2(500, 500), 1.0, const QueryFilter.all(), hit),
        isFalse);
    expect(hit.chainLength, 0);
  });

  test('descends into an instance and reports the whole chain', () {
    final doc = DraftDocument.empty();
    const def = Handle(200);
    const instance = Handle(400);
    doc.tree.addDefinition(Definition(
      handle: def, name: 'T', basePoint: Vector2.zero(), children: const [],
    ));
    final leaf = addEntity(doc, def, EntityKind.line, [0, 0, 2, 0], []);
    doc.commands.execute(AddNodeCommand(
      node: InstanceNode(
        handle: instance, parent: doc.rootHandle,
        transform: Transform2.translation(100, 100),
        definition: def, layer: ReservedHandles.layerZero,
      ),
    ));
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final hit = HitPath();
    expect(
        index.pickInto(Vector2(101, 100), 0.5, const QueryFilter.all(), hit),
        isTrue,
        reason: 'the definition body lives at 100,100 once instanced');
    expect(hit.entity, leaf);
    expect(hit.chainLength, greaterThanOrEqualTo(1));
    expect(Handle(hit.chain[0]), instance,
        reason: 'chain[0] is the root-level ancestor, which is what a viewer '
            'selects when a chair inside a table is tapped');
  });

  test('picks under a mirrored instance, where an ellipse method would fail',
      () {
    final doc = DraftDocument.empty();
    const def = Handle(200);
    doc.tree.addDefinition(Definition(
      handle: def, name: 'T', basePoint: Vector2.zero(), children: const [],
    ));
    final leaf = addEntity(doc, def, EntityKind.line, [0, 0, 10, 0], []);
    doc.commands.execute(AddNodeCommand(
      node: InstanceNode(
        handle: const Handle(400), parent: doc.rootHandle,
        // Mirror in x and stretch in y: determinant is negative and the
        // scale is non-uniform. The narrow phase measures in world space,
        // so this must still be exact.
        transform: Transform2.scale(-1, 3),
        definition: def, layer: ReservedHandles.layerZero,
      ),
    ));
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final hit = HitPath();
    expect(index.pickInto(Vector2(-5, 0), 0.5, const QueryFilter.all(), hit),
        isTrue);
    expect(hit.entity, leaf);
    expect(index.pickInto(Vector2(5, 0), 0.5, const QueryFilter.all(), hit),
        isFalse, reason: 'the mirrored copy is at negative x only');
  });

  test('breaks a tie by greater root ancestor handle, then greater leaf', () {
    final doc = DraftDocument.empty();
    // Two coincident lines at the root: the greater handle must win.
    final lower =
        addEntity(doc, doc.rootHandle, EntityKind.line, [0, 0, 10, 0], []);
    final upper =
        addEntity(doc, doc.rootHandle, EntityKind.line, [0, 0, 10, 0], []);
    expect(upper.value, greaterThan(lower.value));

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final hit = HitPath();
    expect(index.pickInto(Vector2(5, 0), 0.5, const QueryFilter.all(), hit),
        isTrue);
    expect(hit.entity, upper);
  });

  test('respects the filter', () {
    final doc = DraftDocument.empty();
    const locked = Handle(51);
    doc.tables.layers.add(LayerRecord(
      handle: locked, name: 'L', color: const DraftColor.index(7),
      linetype: ReservedHandles.linetypeContinuous,
      lineweight: kLineweightDefault, transparency: 0,
      visible: true, locked: true,
    ));
    final handle = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
      record: EntityRecord(
        handle: handle, owner: doc.rootHandle, kind: EntityKind.line,
        layer: locked, linetype: ReservedHandles.linetypeByLayer,
        linetypeScale: 1.0, geomIndex: 0, color: const DraftColor.byLayer(),
        lineweight: kByLayer, transparency: kByLayer, flags: 0,
      ),
      payload: GeometryPayload(
        coords: Float64List.fromList([0, 0, 10, 0]),
        scalars: Float64List(0),
      ),
    ));
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final hit = HitPath();
    expect(index.pickInto(Vector2(5, 0), 0.5, const QueryFilter.all(), hit),
        isTrue);
    expect(index.pickInto(Vector2(5, 0), 0.5, const QueryFilter.picking(), hit),
        isFalse);
  });

  test('a chain deeper than the buffer truncates from the root', () {
    final doc = DraftDocument.empty();
    // Nest definitions four deep with a two-slot chain buffer.
    var inner = const Handle(200);
    doc.tree.addDefinition(Definition(
      handle: inner, name: 'L0', basePoint: Vector2.zero(), children: const [],
    ));
    final leaf = addEntity(doc, inner, EntityKind.line, [0, 0, 2, 0], []);

    for (var level = 1; level <= 3; level++) {
      final outer = Handle(200 + level);
      final node = Handle(300 + level);
      doc.tree.addDefinition(Definition(
        handle: outer, name: 'L$level', basePoint: Vector2.zero(),
        children: const [],
      ));
      doc.tree.addNode(InstanceNode(
        handle: node, parent: outer, transform: Transform2.identity(),
        definition: inner, layer: ReservedHandles.layerZero,
      ));
      inner = outer;
    }
    doc.commands.execute(AddNodeCommand(
      node: InstanceNode(
        handle: const Handle(500), parent: doc.rootHandle,
        transform: Transform2.identity(), definition: inner,
        layer: ReservedHandles.layerZero,
      ),
    ));

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final hit = HitPath(2);
    expect(index.pickInto(Vector2(1, 0), 0.5, const QueryFilter.all(), hit),
        isTrue);
    expect(hit.entity, leaf,
        reason: 'truncation must never change which leaf was hit');
    expect(hit.truncated, isTrue);
    expect(hit.chainLength, lessThanOrEqualTo(2));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd packages/jet_cad_2d && dart test test/index/pick_test.dart
```

Expected: `Undefined name 'HitPath'`.

- [ ] **Step 3: Write `hit.dart`**

```dart
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import '../core/handle.dart';

/// What part of an entity a pick landed on.
///
/// Checked in this order: a click near a line's endpoint means the endpoint,
/// even though it is also on the line.
enum HitKind { vertex, edge, fill }

/// The result of a pick: what was hit, and the chain of nodes above it.
///
/// Caller-owned so a pick allocates nothing at pointer-move rate. The engine
/// reports the path; policy lives in the widget layer — a viewer selects
/// `chain[0]`, the root-level ancestor, so tapping a chair selects its table,
/// while a designer descends.
class HitPath {
  HitPath([int chainCapacity = 16]) : chain = Uint32List(chainCapacity);

  /// Root-level ancestor first, leaf's immediate parent last.
  final Uint32List chain;

  int chainLength = 0;
  Handle entity = const Handle(0);
  Vector2 worldPoint = Vector2.zero();
  HitKind kind = HitKind.edge;

  /// The chain was deeper than [chain] and was cut from the root end.
  ///
  /// Truncating from the root rather than the leaf keeps the leaf hit — the
  /// part that identifies what was clicked — always correct. Only deeply
  /// nested instances are affected.
  bool truncated = false;

  void reset() {
    chainLength = 0;
    entity = const Handle(0);
    kind = HitKind.edge;
    truncated = false;
  }
}
```

- [ ] **Step 4: Add `pickInto` to `SpatialIndex`**

The traversal descends instances with composed transforms, measures in world
space, and keeps the best candidate:

```dart
  final HitPath _pickScratch = HitPath(32);

  /// Finds the topmost entity within [radius] of [world].
  ///
  /// Returns false and resets [out] on a miss. Descends into instances, unlike
  /// [forEachInRect] — a pick wants the leaf, and its chain identifies which
  /// instance the leaf was reached through.
  bool pickInto(
      Vector2 world, double radius, QueryFilter filter, HitPath out) {
    if (_inQuery) throw const QueryReentrancyError('a nested query');
    _inQuery = true;
    try {
      out.reset();
      _bestKind = null;
      _bestEntity = const Handle(0);
      _bestRoot = const Handle(0);
      _pickIn(rootIndex, Transform2.identity(), world, radius, filter,
          const Handle(0), 0, out);
      return out.chainLength > 0 || !_bestEntity.isNone;
    } finally {
      _inQuery = false;
    }
  }
```

Implement `_pickIn` to:

1. Build the local query box: inverse-transform a `radius`-expanded world box,
   conservatively, via `Aabb2.transformedBy(composed.invert())`. Catch
   `SingularTransformError` and skip that instance — a degenerate transform
   collapses the geometry to nothing and there is nothing to hit.
2. `searchLeaves` on the local box; for each slot, transform its geometry to
   world with `composed` and measure with the Task 11 primitives. Track the
   best by `(kind priority, then greater root ancestor handle, then greater
   entity handle)`.
3. `searchInstances`; for each, recurse with `composed.multiply(instanceLocal)`
   and the root ancestor set to the instance handle when depth is 0.
4. On a better candidate, write `entity`, `kind`, `worldPoint`, and the chain,
   setting `truncated` when depth exceeds `out.chain.length`.

**Do not call `searchLeaves` and recurse inside the same visitor callback** —
`ContainerIndex.searchLeaves` walks the tree's own stack, and recursing from
inside it corrupts that walk exactly as the reentrancy guard describes. Collect
the instance handles for a level into a scratch list first, close the visitor,
then recurse.

- [ ] **Step 5: Run the tests**

```bash
cd packages/jet_cad_2d && dart test && dart analyze && dart format --set-exit-if-changed lib test
```

Expected: 354 + 9 = 363 passing.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "feat(jet_cad_2d): HitPath and pickInto

The engine reports a path, not a decision: a viewer selects chain[0] so
tapping a chair selects its table, a designer descends. Neither policy
lives in the engine.

Ties break by greater root ancestor handle then greater leaf handle --
the parent spec's 'topmost, then draw order' is circular now that draw
order is handle order. Chains deeper than the buffer truncate from the
root so the leaf hit stays correct."
```

---

### Task 13: Snap types and the cheap snap kinds

**Files:**
- Create: `packages/jet_cad_2d/lib/src/index/snap.dart`
- Modify: `packages/jet_cad_2d/lib/src/index/spatial_index.dart` (add `snapInto`)
- Test: `packages/jet_cad_2d/test/index/snap_test.dart`

**Interfaces:**
- Produces:

```dart
enum SnapKind { endpoint, midpoint, center, quadrant, insertion,
                nearest, perpendicular, tangent, intersection }

extension type const SnapMask(int bits) {
  static const SnapMask none = SnapMask(0);
  static const SnapMask cheap = SnapMask(...);   // endpoint..insertion
  static const SnapMask all = SnapMask(...);
  bool has(SnapKind kind);
  SnapMask with_(SnapKind kind);
}

class SnapResult {
  SnapResult([int chainCapacity = 16]);
  bool found;
  SnapKind kind;
  Vector2 point;
  Handle entity;
  final Uint32List chain;
  int chainLength;
  void reset();
}

// on SpatialIndex:
void snapInto(Vector2 world, double radius, SnapMask mask, SnapResult out);
```

One best candidate, ordered by `(kind priority, distance)`. Kind priority is
declaration order in `SnapKind`: an endpoint beats a midpoint at the same
distance, and both beat `nearest`.

**A snap query allocates nothing.** It runs at pointer-move rate. The caller
owns `SnapResult` including its chain buffer, and the query writes into it.

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d/test/index/snap_test.dart`:

```dart
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

Handle addEntity(DraftDocument doc, Handle owner, EntityKind kind,
    List<double> coords, List<double> scalars) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle, owner: owner, kind: kind,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.linetypeByLayer, linetypeScale: 1.0,
      geomIndex: 0, color: const DraftColor.byLayer(),
      lineweight: kByLayer, transparency: kByLayer, flags: 0,
    ),
    payload: GeometryPayload(
      coords: Float64List.fromList(coords),
      scalars: Float64List.fromList(scalars),
    ),
  ));
  return handle;
}

void main() {
  test('SnapMask reports the kinds it contains', () {
    const mask = SnapMask.cheap;
    expect(mask.has(SnapKind.endpoint), isTrue);
    expect(mask.has(SnapKind.midpoint), isTrue);
    expect(mask.has(SnapKind.nearest), isFalse);
    expect(SnapMask.none.has(SnapKind.endpoint), isFalse);
    expect(SnapMask.all.has(SnapKind.intersection), isTrue);
  });

  test('snaps to an endpoint', () {
    final doc = DraftDocument.empty();
    addEntity(doc, doc.rootHandle, EntityKind.line, [0, 0, 10, 0], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final out = SnapResult();
    index.snapInto(Vector2(0.3, 0.3), 1.0, SnapMask.cheap, out);

    expect(out.found, isTrue);
    expect(out.kind, SnapKind.endpoint);
    expect(out.point.x, closeTo(0, 1e-12));
    expect(out.point.y, closeTo(0, 1e-12));
  });

  test('snaps to a midpoint', () {
    final doc = DraftDocument.empty();
    addEntity(doc, doc.rootHandle, EntityKind.line, [0, 0, 10, 0], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final out = SnapResult();
    index.snapInto(Vector2(5.1, 0.1), 1.0, SnapMask.cheap, out);

    expect(out.found, isTrue);
    expect(out.kind, SnapKind.midpoint);
    expect(out.point.x, closeTo(5, 1e-12));
  });

  test('prefers an endpoint to a midpoint at equal distance', () {
    final doc = DraftDocument.empty();
    // Endpoint at (0,0), midpoint at (5,0); query is equidistant from both.
    addEntity(doc, doc.rootHandle, EntityKind.line, [0, 0, 10, 0], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final out = SnapResult();
    index.snapInto(Vector2(2.5, 0), 3.0, SnapMask.cheap, out);

    expect(out.kind, SnapKind.endpoint,
        reason: 'kind priority beats distance only at equal distance, and '
            'endpoint outranks midpoint');
    expect(out.point.x, closeTo(0, 1e-12));
  });

  test('snaps to a circle centre and to its quadrants', () {
    final doc = DraftDocument.empty();
    addEntity(doc, doc.rootHandle, EntityKind.circle, [0, 0], [10]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final out = SnapResult();
    index.snapInto(Vector2(0.2, 0.2), 1.0, SnapMask.cheap, out);
    expect(out.kind, SnapKind.center);
    expect(out.point.x, closeTo(0, 1e-12));

    index.snapInto(Vector2(10.2, 0.1), 1.0, SnapMask.cheap, out);
    expect(out.kind, SnapKind.quadrant);
    expect(out.point.x, closeTo(10, 1e-12));
    expect(out.point.y, closeTo(0, 1e-12));
  });

  test('finds nothing outside the radius and resets the result', () {
    final doc = DraftDocument.empty();
    addEntity(doc, doc.rootHandle, EntityKind.line, [0, 0, 10, 0], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final out = SnapResult()..found = true;
    index.snapInto(Vector2(500, 500), 1.0, SnapMask.cheap, out);
    expect(out.found, isFalse);
  });

  test('an empty mask finds nothing even on top of geometry', () {
    final doc = DraftDocument.empty();
    addEntity(doc, doc.rootHandle, EntityKind.line, [0, 0, 10, 0], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final out = SnapResult();
    index.snapInto(Vector2(0, 0), 1.0, SnapMask.none, out);
    expect(out.found, isFalse);
  });

  test('snapping crosses an instance boundary', () {
    final doc = DraftDocument.empty();
    const def = Handle(200);
    doc.tree.addDefinition(Definition(
      handle: def, name: 'Chair', basePoint: Vector2.zero(), children: const [],
    ));
    final leaf = addEntity(doc, def, EntityKind.line, [0, 0, 2, 0], []);
    doc.commands.execute(AddNodeCommand(
      node: InstanceNode(
        handle: const Handle(400), parent: doc.rootHandle,
        transform: Transform2.translation(100, 100),
        definition: def, layer: ReservedHandles.layerZero,
      ),
    ));
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final out = SnapResult();
    index.snapInto(Vector2(102.1, 100.1), 1.0, SnapMask.cheap, out);

    expect(out.found, isTrue,
        reason: 'snapping to a chair corner inside a table instance is the '
            'motivating case');
    expect(out.entity, leaf);
    expect(out.point.x, closeTo(102, 1e-9));
    expect(out.point.y, closeTo(100, 1e-9));
  });

  test('snap points are exact under a rotated instance', () {
    final doc = DraftDocument.empty();
    const def = Handle(200);
    doc.tree.addDefinition(Definition(
      handle: def, name: 'R', basePoint: Vector2.zero(), children: const [],
    ));
    addEntity(doc, def, EntityKind.line, [0, 0, 10, 0], []);
    doc.commands.execute(AddNodeCommand(
      node: InstanceNode(
        handle: const Handle(400), parent: doc.rootHandle,
        transform: Transform2.rotation(math.pi / 2),
        definition: def, layer: ReservedHandles.layerZero,
      ),
    ));
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    // The far endpoint rotates from (10,0) to (0,10).
    final out = SnapResult();
    index.snapInto(Vector2(0.1, 9.9), 1.0, SnapMask.cheap, out);
    expect(out.found, isTrue);
    expect(out.kind, SnapKind.endpoint);
    expect(out.point.x, closeTo(0, 1e-9));
    expect(out.point.y, closeTo(10, 1e-9));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd packages/jet_cad_2d && dart test test/index/snap_test.dart
```

Expected: `Undefined name 'SnapMask'`.

- [ ] **Step 3: Write `snap.dart`**

```dart
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import '../core/handle.dart';

/// The snap kinds, in priority order.
///
/// Declaration order *is* priority order: at equal distance an endpoint beats
/// a midpoint, and both beat `nearest`. Reordering this enum changes snapping
/// behaviour, which is why the order is stated rather than incidental.
enum SnapKind {
  endpoint,
  midpoint,
  center,
  quadrant,
  insertion,
  perpendicular,
  tangent,
  intersection,
  nearest,
}

/// Which snap kinds a query should consider.
extension type const SnapMask(int bits) {
  static const SnapMask none = SnapMask(0);

  /// Constant cost per entity.
  static const SnapMask cheap = SnapMask(0x1F);   // endpoint..insertion

  static const SnapMask all = SnapMask(0x1FF);

  bool has(SnapKind kind) => bits & (1 << kind.index) != 0;

  SnapMask with_(SnapKind kind) => SnapMask(bits | (1 << kind.index));
}

/// The single best snap candidate.
///
/// Caller-owned, including [chain], because a snap query runs at pointer-move
/// rate and must allocate nothing. A result that returned a freshly allocated
/// list would violate the budget it is declared under.
class SnapResult {
  SnapResult([int chainCapacity = 16]) : chain = Uint32List(chainCapacity);

  bool found = false;
  SnapKind kind = SnapKind.nearest;
  Vector2 point = Vector2.zero();
  Handle entity = const Handle(0);
  final Uint32List chain;
  int chainLength = 0;

  void reset() {
    found = false;
    chainLength = 0;
    entity = const Handle(0);
  }
}
```

- [ ] **Step 4: Add `snapInto` for the cheap kinds**

Traversal mirrors `pickInto`: descend instances with composed transforms,
generate candidate points **in world space** from each entity, and keep the
best by `(kind index, distance)`.

Candidate generation per `EntityKind`:

| Kind | endpoint | midpoint | center | quadrant | insertion |
|---|---|---|---|---|---|
| `point` | the point | — | — | — | — |
| `line`, `polyline` | every vertex | midpoint of each segment | — | — | — |
| `circle` | — | — | centre | 0°, 90°, 180°, 270° on the rim | — |
| `arc` | both arc ends | point at half sweep | centre | quadrants inside the sweep only | — |
| `text`, `attrib` | — | — | — | — | the insertion point |

Transform each candidate by the composed transform **before** measuring
distance, never after: measuring in local space and transforming the winner
would rank candidates by local distance, which is wrong under any non-uniform
scale.

- [ ] **Step 5: Run the tests**

```bash
cd packages/jet_cad_2d && dart test && dart analyze && dart format --set-exit-if-changed lib test
```

Expected: 363 + 9 = 372 passing.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "feat(jet_cad_2d): snap types and the cheap snap kinds

SnapKind declaration order is priority order: at equal distance an
endpoint beats a midpoint. SnapResult is caller-owned including its
chain buffer, because snapping runs at pointer-move rate under a
zero-allocation budget.

Candidates are transformed to world space before being measured, not
after: ranking by local distance is wrong under any non-uniform scale."
```

---

### Task 14: Moderate and intersection snapping

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/index/spatial_index.dart`
- Modify: `packages/jet_cad_2d/lib/src/geometry/distance.dart` (add projection helpers)
- Test: `packages/jet_cad_2d/test/index/snap_advanced_test.dart`

**Interfaces:**
- Produces: `const int kIntersectionCandidateCap = 64;` and, in `distance.dart`:

```dart
Vector2? projectOntoSegment(Vector2 p, Vector2 a, Vector2 b, Vector2 out);
Vector2? segmentIntersection(Vector2 a1, Vector2 a2, Vector2 b1, Vector2 b2,
                             Vector2 out);
```

**Intersection snapping considers at most 64 candidates**, taken in ascending
handle order from those inside the query rectangle. Pairwise over the
candidates is quadratic, so an uncapped version degrades without bound on a
dense drawing — and 64 candidates is already 2016 pair tests. The number is
declared here rather than invented at the keyboard, so it can be tested and
tuned.

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d/test/index/snap_advanced_test.dart`:

```dart
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

Handle addLine(DraftDocument doc, List<double> coords) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle, owner: doc.rootHandle, kind: EntityKind.line,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.linetypeByLayer, linetypeScale: 1.0,
      geomIndex: 0, color: const DraftColor.byLayer(),
      lineweight: kByLayer, transparency: kByLayer, flags: 0,
    ),
    payload: GeometryPayload(
      coords: Float64List.fromList(coords),
      scalars: Float64List(0),
    ),
  ));
  return handle;
}

void main() {
  test('segmentIntersection finds a crossing and rejects a miss', () {
    final out = Vector2.zero();
    expect(
        segmentIntersection(Vector2(0, 0), Vector2(10, 0), Vector2(5, -5),
            Vector2(5, 5), out),
        isNotNull);
    expect(out.x, closeTo(5, 1e-12));
    expect(out.y, closeTo(0, 1e-12));

    expect(
        segmentIntersection(Vector2(0, 0), Vector2(10, 0), Vector2(0, 5),
            Vector2(10, 5), out),
        isNull,
        reason: 'parallel');

    expect(
        segmentIntersection(Vector2(0, 0), Vector2(1, 0), Vector2(5, -5),
            Vector2(5, 5), out),
        isNull,
        reason: 'the infinite lines cross, but the segments do not');
  });

  test('projectOntoSegment lands on the segment and clamps outside it', () {
    final out = Vector2.zero();
    expect(projectOntoSegment(Vector2(5, 3), Vector2(0, 0), Vector2(10, 0), out),
        isNotNull);
    expect(out.x, closeTo(5, 1e-12));
    expect(out.y, closeTo(0, 1e-12));

    projectOntoSegment(Vector2(20, 3), Vector2(0, 0), Vector2(10, 0), out);
    expect(out.x, closeTo(10, 1e-12), reason: 'clamped to the far endpoint');
  });

  test('nearest snaps to the closest point on a line', () {
    final doc = DraftDocument.empty();
    addLine(doc, [0, 0, 10, 0]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final out = SnapResult();
    index.snapInto(Vector2(3, 0.4), 1.0,
        const SnapMask(0).with_(SnapKind.nearest), out);

    expect(out.found, isTrue);
    expect(out.kind, SnapKind.nearest);
    expect(out.point.x, closeTo(3, 1e-12));
    expect(out.point.y, closeTo(0, 1e-12));
  });

  test('intersection snaps to where two lines cross', () {
    final doc = DraftDocument.empty();
    addLine(doc, [0, 0, 10, 0]);
    addLine(doc, [5, -5, 5, 5]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final out = SnapResult();
    index.snapInto(Vector2(5.2, 0.2), 1.0,
        const SnapMask(0).with_(SnapKind.intersection), out);

    expect(out.found, isTrue);
    expect(out.kind, SnapKind.intersection);
    expect(out.point.x, closeTo(5, 1e-12));
    expect(out.point.y, closeTo(0, 1e-12));
  });

  test('intersection finds nothing where lines do not cross', () {
    final doc = DraftDocument.empty();
    addLine(doc, [0, 0, 10, 0]);
    addLine(doc, [0, 3, 10, 3]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final out = SnapResult();
    index.snapInto(Vector2(5, 1.5), 2.0,
        const SnapMask(0).with_(SnapKind.intersection), out);
    expect(out.found, isFalse);
  });

  test('the intersection candidate cap is declared and enforced', () {
    expect(kIntersectionCandidateCap, 64);

    final doc = DraftDocument.empty();
    // 200 overlapping lines through one small region: far past the cap.
    for (var i = 0; i < 200; i++) {
      addLine(doc, [-10 + i * 0.01, -10, 10 + i * 0.01, 10]);
      addLine(doc, [-10 + i * 0.01, 10, 10 + i * 0.01, -10]);
    }
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final out = SnapResult();
    // The point is not that a particular intersection wins — it is that this
    // terminates promptly rather than doing 400 choose 2 pair tests.
    index.snapInto(Vector2(0, 0), 5.0,
        const SnapMask(0).with_(SnapKind.intersection), out);
    expect(out.found, isTrue);
  }, timeout: const Timeout(Duration(seconds: 5)));

  test('perpendicular snaps to the foot of the perpendicular', () {
    final doc = DraftDocument.empty();
    addLine(doc, [0, 0, 10, 0]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final out = SnapResult();
    index.snapInto(Vector2(7, 0.5), 1.0,
        const SnapMask(0).with_(SnapKind.perpendicular), out);

    expect(out.found, isTrue);
    expect(out.point.x, closeTo(7, 1e-12));
    expect(out.point.y, closeTo(0, 1e-12));
  });

  test('endpoint still outranks nearest when both are in range', () {
    final doc = DraftDocument.empty();
    addLine(doc, [0, 0, 10, 0]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final out = SnapResult();
    index.snapInto(Vector2(0.2, 0.2), 1.0, SnapMask.all, out);
    expect(out.kind, SnapKind.endpoint,
        reason: 'nearest would give (0.2, 0) at a smaller distance; kind '
            'priority is what stops nearest swallowing every other kind');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd packages/jet_cad_2d && dart test test/index/snap_advanced_test.dart
```

Expected: `Undefined name 'segmentIntersection'`.

- [ ] **Step 3: Add the geometry helpers**

In `distance.dart`:

```dart
/// The closest point on segment [a]-[b] to [p], written into [out].
///
/// Returns [out] on success, or null for a degenerate zero-length segment,
/// where "the closest point on the segment" has no useful answer distinct
/// from the endpoint itself.
Vector2? projectOntoSegment(Vector2 p, Vector2 a, Vector2 b, Vector2 out) {
  final abx = b.x - a.x, aby = b.y - a.y;
  final lengthSq = abx * abx + aby * aby;
  if (lengthSq == 0.0) return null;
  var t = ((p.x - a.x) * abx + (p.y - a.y) * aby) / lengthSq;
  if (t < 0.0) t = 0.0;
  if (t > 1.0) t = 1.0;
  out
    ..x = a.x + t * abx
    ..y = a.y + t * aby;
  return out;
}

/// Where segments [a1]-[a2] and [b1]-[b2] cross, written into [out].
///
/// Null when they are parallel, or when the infinite lines cross outside one
/// of the segments. Both cases matter: CAD users expect an intersection snap
/// only where the drawn geometry actually meets.
Vector2? segmentIntersection(
    Vector2 a1, Vector2 a2, Vector2 b1, Vector2 b2, Vector2 out) {
  final rx = a2.x - a1.x, ry = a2.y - a1.y;
  final sx = b2.x - b1.x, sy = b2.y - b1.y;
  final denominator = rx * sy - ry * sx;
  // Exact zero: parallel. A tolerance here would report an intersection
  // point computed by dividing by something near zero, which is worse than
  // reporting none.
  if (denominator == 0.0) return null;

  final t = ((b1.x - a1.x) * sy - (b1.y - a1.y) * sx) / denominator;
  final u = ((b1.x - a1.x) * ry - (b1.y - a1.y) * rx) / denominator;
  if (t < 0.0 || t > 1.0 || u < 0.0 || u > 1.0) return null;

  out
    ..x = a1.x + t * rx
    ..y = a1.y + t * ry;
  return out;
}
```

- [ ] **Step 4: Extend `snapInto`**

Add the moderate kinds — `nearest` via `projectOntoSegment`, `perpendicular`
as the same foot when the query is off the line, `tangent` for circles and arcs
— and then intersection:

```dart
/// The most candidates an intersection snap will consider.
///
/// Pairwise testing is quadratic, so an uncapped version degrades without
/// bound on a dense drawing: 64 candidates is already 2016 pair tests. Taken
/// in ascending handle order so the choice is deterministic rather than
/// whatever the index happened to visit first.
const int kIntersectionCandidateCap = 64;
```

Collect candidate slots inside the query rectangle into the existing scratch,
sort by handle, take the first `kIntersectionCandidateCap`, then test each pair
of segments and keep the crossing nearest to the query point.

- [ ] **Step 5: Run the tests**

```bash
cd packages/jet_cad_2d && dart test && dart analyze && dart format --set-exit-if-changed lib test
```

Expected: 372 + 8 = 380 passing.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "feat(jet_cad_2d): nearest, perpendicular, tangent and intersection snap

Intersection is capped at 64 candidates in ascending handle order:
pairwise testing is quadratic, 64 is already 2016 pair tests, and an
uncapped version degrades without bound on a dense drawing. The cap is
declared as a constant so it is testable rather than invented.

segmentIntersection uses an exact zero test for the parallel case — a
tolerance there would report a point produced by dividing by something
near zero, which is worse than reporting none."
```

---

### Task 15: The `Iterable` convenience queries

**Files:**
- Create: `packages/jet_cad_2d/lib/src/index/convenience_queries.dart`
- Test: `packages/jet_cad_2d/test/index/convenience_queries_test.dart`

**Interfaces:**
- Produces, as an extension on `SpatialIndex`:

```dart
Iterable<Handle> entitiesInRect(Aabb2 world, QueryFilter filter);
Iterable<Handle> instancesOf(Handle definition);
Iterable<Handle> onLayer(Handle layer);
Iterable<Handle> attributesOf(Handle instance);
```

**These are O(n) scans, once per call, with no index behind them** — except
`entitiesInRect`, which wraps `forEachInRect`. The cost is documented at the
declaration so that Plan 3 does not call `onLayer` inside a paint loop and
discover it there. That warning is the main deliverable of this task; the code
is straightforward.

`withComponent<T>` already exists on `ComponentRegistry` from Plan 1 and is not
reimplemented here.

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d/test/index/convenience_queries_test.dart`:

```dart
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

Handle addOn(DraftDocument doc, Handle owner, Handle layer, EntityKind kind) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle, owner: owner, kind: kind, layer: layer,
      linetype: ReservedHandles.linetypeByLayer, linetypeScale: 1.0,
      geomIndex: 0, color: const DraftColor.byLayer(),
      lineweight: kByLayer, transparency: kByLayer, flags: 0,
    ),
    payload: GeometryPayload(
      coords: Float64List.fromList([0, 0, 1, 1]),
      scalars: Float64List.fromList(
          kind == EntityKind.attrib || kind == EntityKind.text ? [1.0] : []),
    ),
  ));
  return handle;
}

void main() {
  test('entitiesInRect matches forEachInRect, ascending', () {
    final doc = DraftDocument.empty();
    final handles = [
      for (var i = 0; i < 5; i++)
        addOn(doc, doc.rootHandle, ReservedHandles.layerZero, EntityKind.line),
    ];
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final rect = Aabb2(Vector2(-1, -1), Vector2(5, 5));
    final viaCallback = <Handle>[];
    index.forEachInRect(rect, const QueryFilter.all(),
        (slot) => viaCallback.add(doc.entities.handleAt(slot)));

    expect(index.entitiesInRect(rect, const QueryFilter.all()).toList(),
        viaCallback);
    expect(viaCallback.toSet(), handles.toSet());
  });

  test('onLayer returns only that layer, ascending', () {
    final doc = DraftDocument.empty();
    const other = Handle(60);
    doc.tables.layers.add(LayerRecord(
      handle: other, name: 'Other', color: const DraftColor.index(3),
      linetype: ReservedHandles.linetypeContinuous,
      lineweight: kLineweightDefault, transparency: 0,
      visible: true, locked: false,
    ));
    final onZero = [
      addOn(doc, doc.rootHandle, ReservedHandles.layerZero, EntityKind.line),
      addOn(doc, doc.rootHandle, ReservedHandles.layerZero, EntityKind.line),
    ];
    addOn(doc, doc.rootHandle, other, EntityKind.line);

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    expect(index.onLayer(ReservedHandles.layerZero).toList(), onZero);
    expect(index.onLayer(other).toList(), hasLength(1));
    expect(index.onLayer(const Handle(9999)).toList(), isEmpty);
  });

  test('instancesOf finds every placement of a definition, ascending', () {
    final doc = DraftDocument.empty();
    const defA = Handle(200);
    const defB = Handle(201);
    for (final d in [defA, defB]) {
      doc.tree.addDefinition(Definition(
        handle: d, name: 'D${d.value}', basePoint: Vector2.zero(),
        children: const [],
      ));
    }
    for (final (handle, definition) in [
      (const Handle(405), defA),
      (const Handle(401), defA),
      (const Handle(403), defB),
    ]) {
      doc.commands.execute(AddNodeCommand(
        node: InstanceNode(
          handle: handle, parent: doc.rootHandle,
          transform: Transform2.identity(), definition: definition,
          layer: ReservedHandles.layerZero,
        ),
      ));
    }
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    expect(index.instancesOf(defA).toList(),
        [const Handle(401), const Handle(405)]);
    expect(index.instancesOf(defB).toList(), [const Handle(403)]);
    expect(index.instancesOf(const Handle(9999)).toList(), isEmpty);
  });

  test('attributesOf returns attrib entities owned by an instance', () {
    final doc = DraftDocument.empty();
    const def = Handle(200);
    const instance = Handle(400);
    doc.tree.addDefinition(Definition(
      handle: def, name: 'T', basePoint: Vector2.zero(), children: const [],
    ));
    doc.commands.execute(AddNodeCommand(
      node: InstanceNode(
        handle: instance, parent: doc.rootHandle,
        transform: Transform2.identity(), definition: def,
        layer: ReservedHandles.layerZero,
      ),
    ));
    final attrib =
        addOn(doc, instance, ReservedHandles.layerZero, EntityKind.attrib);
    addOn(doc, instance, ReservedHandles.layerZero, EntityKind.line);

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    expect(index.attributesOf(instance).toList(), [attrib],
        reason: 'a line owned by the instance is not an attribute');
    expect(index.attributesOf(const Handle(9999)).toList(), isEmpty);
  });

  test('every convenience query is empty on an empty document', () {
    final doc = DraftDocument.empty();
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    expect(
        index
            .entitiesInRect(
                Aabb2(Vector2(-1e9, -1e9), Vector2(1e9, 1e9)),
                const QueryFilter.all())
            .toList(),
        isEmpty);
    expect(index.onLayer(ReservedHandles.layerZero).toList(), isEmpty);
    expect(index.instancesOf(const Handle(200)).toList(), isEmpty);
    expect(index.attributesOf(const Handle(400)).toList(), isEmpty);
  });

  test('results are materialised, so mutating after the call is safe', () {
    final doc = DraftDocument.empty();
    addOn(doc, doc.rootHandle, ReservedHandles.layerZero, EntityKind.line);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final result = index.onLayer(ReservedHandles.layerZero);
    addOn(doc, doc.rootHandle, ReservedHandles.layerZero, EntityKind.line);

    expect(result.toList(), hasLength(1),
        reason: 'a lazy iterable would observe the new entity, and would also '
            'be a query running outside the reentrancy guard');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd packages/jet_cad_2d && dart test test/index/convenience_queries_test.dart
```

Expected: `The method 'entitiesInRect' isn't defined`.

- [ ] **Step 3: Write the implementation**

Create `packages/jet_cad_2d/lib/src/index/convenience_queries.dart`:

```dart
import '../core/handle.dart';
import '../document/node.dart';
import '../geometry/aabb2.dart';
import '../store/entity_store.dart';
import 'query_filter.dart';
import 'spatial_index.dart';

/// Query forms for tools, adapters and tests — everything not on the frame
/// path.
///
/// **These allocate, and most of them are O(n) scans with no index behind
/// them.** They exist so a tool has one obvious place to look, not because
/// they are fast. Do not call them per frame: `onLayer` inside a paint loop is
/// a full entity scan per frame.
extension ConvenienceQueries on SpatialIndex {
  /// Root-level entities overlapping [world], ascending by handle.
  ///
  /// The allocating form of `forEachInRect`, with identical results. O(log n)
  /// plus the result size; the only member of this extension that is not a
  /// full scan.
  Iterable<Handle> entitiesInRect(Aabb2 world, QueryFilter filter) {
    final out = <Handle>[];
    forEachInRect(world, filter, (slot) => out.add(document.entities.handleAt(slot)));
    return out;
  }

  /// Every entity on [layer], ascending by handle. **O(entities).**
  Iterable<Handle> onLayer(Handle layer) {
    final out = <Handle>[];
    for (final slot in document.entities.liveSlots) {
      if (document.entities.layerAt(slot) == layer) {
        out.add(document.entities.handleAt(slot));
      }
    }
    out.sort((a, b) => a.value.compareTo(b.value));
    return out;
  }

  /// Every instance node placing [definition], ascending. **O(nodes).**
  Iterable<Handle> instancesOf(Handle definition) {
    final out = <Handle>[];
    for (final node in document.tree.nodes) {
      if (node is InstanceNode && node.definition == definition) {
        out.add(node.handle);
      }
    }
    out.sort((a, b) => a.value.compareTo(b.value));
    return out;
  }

  /// Attribute entities owned by [instance], ascending. **O(entities).**
  Iterable<Handle> attributesOf(Handle instance) {
    final out = <Handle>[];
    for (final slot in document.entities.liveSlots) {
      if (document.entities.ownerAt(slot) == instance &&
          document.entities.kindAt(slot) == EntityKind.attrib) {
        out.add(document.entities.handleAt(slot));
      }
    }
    out.sort((a, b) => a.value.compareTo(b.value));
    return out;
  }
}
```

**Every one returns a materialised list, not a lazy iterable.** A lazy iterable
would observe later mutations, and — worse — would run its query outside the
reentrancy guard, at whatever moment the caller happened to iterate.

- [ ] **Step 4: Export it**

```dart
export 'src/index/convenience_queries.dart';
```

- [ ] **Step 5: Run the tests**

```bash
cd packages/jet_cad_2d && dart test && dart analyze && dart format --set-exit-if-changed lib test
```

Expected: 380 + 6 = 386 passing.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "feat(jet_cad_2d): Iterable convenience queries, cost documented

O(n) scans with no index behind them, labelled as such at the
declaration so Plan 3 does not call onLayer inside a paint loop and
discover the cost there.

Every one materialises its result: a lazy iterable would observe later
mutations and would run its query outside the reentrancy guard, at
whatever moment the caller happened to iterate."
```

---

### Task 16: Differential testing against a brute-force reference

**Files:**
- Create: `packages/jet_cad_2d/test/invariants/reference_query.dart`
- Create: `packages/jet_cad_2d/test/invariants/corpus.dart`
- Create: `packages/jet_cad_2d/test/invariants/differential_test.dart`

**Interfaces:**
- Consumes: everything.
- Produces: no library code. `corpus.dart` exports `List<CorpusDocument> buildCorpus()`; `reference_query.dart` exports brute-force equivalents of each query.

**This is the load-bearing test of the whole plan.** Every query result must
equal a brute-force linear scan over the same document. That one property kills
most index bugs outright, and unlike hand-picked cases it does not depend on
guessing which cases matter.

**The corpus is fixed here, not left to the implementer.** Plan 1 shipped five
green tests that proved nothing, every one because the *fixture* was degenerate
rather than because the assertion was wrong: one entity made slot 0
indistinguishable from slot 0; LIFO undo made restore-by-value
indistinguishable from restore-by-slot; commutative translations made
composition order invisible.

- [ ] **Step 1: Write the corpus**

Create `packages/jet_cad_2d/test/invariants/corpus.dart` with a builder per
row of the table below. Each returns a `CorpusDocument(name, document)`.

| Fixture | What it exists to catch |
|---|---|
| `empty` | traversal of a tree with no items |
| `single` | off-by-one in the packed tree's one-item path |
| `flatGrid` | the ordinary case, 400 root-level entities |
| `deepInstances` | instances nested **three levels** deep |
| `groupsInDefinitions` | groups **inside definitions**, and groups inside groups — the case the first draft of the design missed entirely |
| `mirrored` | negative-determinant scale, where an ellipse-based narrow phase silently fails |
| `nonUniformScale` | scale (2, 5), where local-space distance ranking is wrong |
| `rotated` | rotation at 0.7 rad — not a multiple of 90°, so an axis-aligned shortcut shows up |
| `largeCoordinates` | everything at 4.5e6, where a fixture near the origin proves nothing |
| `sharedDefinition` | one definition placed 300 times |
| `dirtyUnderThreshold` | edits present, no rebuild triggered |
| `dirtyOverThreshold` | enough edits to force a rebuild mid-test |
| `afterPurge` | slots renumbered under the index |
| `afterUndoReusingSlot` | a freed slot reused by a later add, so slot order and handle order disagree |
| `textDefaultMeasurer` | text entities whose boxes are degenerate points |

- [ ] **Step 2: Write the reference implementation**

Create `packages/jet_cad_2d/test/invariants/reference_query.dart`. It must
compute answers **without touching `SpatialIndex`** — walking the tree and the
entity store directly, composing transforms by hand. If it shares code with the
implementation it is not a reference.

```dart
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

/// Brute-force answers, computed independently of the index.
///
/// Deliberately slow and obvious: it walks every entity, composes transforms
/// by hand, and sorts at the end. It must not call `SpatialIndex`,
/// `ContainerIndex` or `PackedRTree` — sharing code with the implementation
/// would make agreement meaningless. It may use `entityBounds` and
/// `distance.dart`, which are the geometry definitions rather than the index
/// under test.

/// Every root-level leaf whose world box overlaps [world], ascending.
///
/// Mirrors `forEachInRect`: root-level only, no descent into instances,
/// groups flattened.
List<Handle> referenceEntitiesInRect(
    DraftDocument doc, Aabb2 world, QueryFilter filter) {
  if (world.isEmpty) return const [];
  final evaluator = FilterEvaluator(doc);
  final out = <Handle>[];

  for (final slot in doc.entities.liveSlots) {
    final owner = doc.entities.ownerAt(slot);
    final composed = _toRootSpace(doc, owner);
    if (composed == null) continue;   // inside a definition, not root-level
    if (!evaluator.acceptsEntity(slot, filter)) continue;

    final record = doc.entities.read(slot);
    final box = entityBounds(
      kind: record.kind,
      payload: doc.geometry.read(record.geomIndex),
      measurer: doc.textMeasurer,
      textStyle: ReservedHandles.standardTextStyle,
    ).transformedBy(composed);

    if (!box.isEmpty && box.intersects(world)) {
      out.add(doc.entities.handleAt(slot));
    }
  }

  out.sort((a, b) => a.value.compareTo(b.value));
  return out;
}

/// Every root-level instance whose world box overlaps [world], ascending.
List<Handle> referenceInstancesInRect(
    DraftDocument doc, Aabb2 world, QueryFilter filter) {
  if (world.isEmpty) return const [];
  final evaluator = FilterEvaluator(doc);
  final out = <Handle>[];

  for (final node in doc.tree.nodes) {
    if (node is! InstanceNode) continue;
    final parentTransform = _toRootSpace(doc, node.parent);
    if (parentTransform == null) continue;
    if (!evaluator.acceptsNode(node.handle, filter)) continue;

    final box = doc
        .definitionBounds(node.definition)
        .transformedBy(parentTransform.multiply(node.transform));
    if (!box.isEmpty && box.intersects(world)) out.add(node.handle);
  }

  out.sort((a, b) => a.value.compareTo(b.value));
  return out;
}

/// The winning pick, or null. Descends into instances, unlike the rect query.
({Handle entity, HitKind kind})? referencePick(
    DraftDocument doc, Vector2 world, double radius, QueryFilter filter) {
  final evaluator = FilterEvaluator(doc);
  ({Handle entity, HitKind kind, Handle root})? best;

  for (final candidate in _allLeavesInWorld(doc)) {
    if (!evaluator.acceptsEntity(candidate.slot, filter)) continue;

    final kind = _hitKindOf(doc, candidate, world, radius);
    if (kind == null) continue;

    final handle = doc.entities.handleAt(candidate.slot);
    if (best == null ||
        kind.index < best.kind.index ||
        (kind == best.kind &&
            (candidate.root.value > best.root.value ||
                (candidate.root == best.root &&
                    handle.value > best.entity.value)))) {
      best = (entity: handle, kind: kind, root: candidate.root);
    }
  }

  return best == null ? null : (entity: best.entity, kind: best.kind);
}

/// The winning snap candidate, or null.
({SnapKind kind, Vector2 point})? referenceSnap(
    DraftDocument doc, Vector2 world, double radius, SnapMask mask) {
  ({SnapKind kind, Vector2 point, double distance})? best;

  for (final candidate in _allLeavesInWorld(doc)) {
    for (final (kind, point) in _snapCandidates(doc, candidate, mask, world)) {
      final distance = world.distanceTo(point);
      if (distance > radius) continue;
      if (best == null ||
          kind.index < best.kind.index ||
          (kind == best.kind && distance < best.distance)) {
        best = (kind: kind, point: point, distance: distance);
      }
    }
  }

  return best == null ? null : (kind: best.kind, point: best.point);
}
```

Four private helpers carry the walking, and they are where the reference earns
its independence:

- `_toRootSpace(doc, container)` composes group transforms upward from
  `container` to the tree root, returning **null** if the walk reaches a
  definition instead — that is what distinguishes root-level geometry from a
  definition body, and getting it wrong makes the reference agree with a
  broken index for the wrong reason.
- `_allLeavesInWorld(doc)` yields
  `({int slot, Transform2 toWorld, Handle root})` for **every** leaf reachable
  from the root, descending through instances with composed transforms, with
  `root` set to the root-level ancestor. Depth-cap it at 256 so a malformed
  corpus document fails a test rather than hanging the suite.
- `_hitKindOf` measures in world space using `distance.dart`, checking
  `vertex`, then `edge`, then `fill`, and returning the first within `radius`.
- `_snapCandidates` yields `(SnapKind, Vector2)` pairs in world space, using
  the same per-kind table as Task 13 — written out again here rather than
  shared, because a shared table would let one mistake pass both sides.

- [ ] **Step 3: Write the differential test**

```dart
void main() {
  for (final fixture in buildCorpus()) {
    group(fixture.name, () {
      test('entitiesInRect matches brute force over 200 random rects', () {
        final index = SpatialIndex(fixture.document);
        addTearDown(index.dispose);
        final rng = math.Random(20260728);

        for (var trial = 0; trial < 200; trial++) {
          final rect = _randomRect(rng, fixture.document.extents);
          for (final filter in [
            const QueryFilter.all(),
            const QueryFilter.rendering(),
            const QueryFilter.picking(),
          ]) {
            expect(
              index.entitiesInRect(rect, filter).toList(),
              referenceEntitiesInRect(fixture.document, rect, filter),
              reason: '${fixture.name} trial $trial rect $rect',
            );
          }
        }
      });

      test('instancesInRect matches brute force over 200 random rects', () {
        final index = SpatialIndex(fixture.document);
        addTearDown(index.dispose);
        final rng = math.Random(20260729);

        for (var trial = 0; trial < 200; trial++) {
          final rect = _randomRect(rng, fixture.document.extents);
          for (final filter in [
            const QueryFilter.all(),
            const QueryFilter.rendering(),
          ]) {
            final actual = <Handle>[];
            index.forEachInstanceInRect(rect, filter, actual.add);
            expect(
              actual,
              referenceInstancesInRect(fixture.document, rect, filter),
              reason: '${fixture.name} trial $trial rect $rect',
            );
          }
        }
      });

      test('pick matches brute force over 200 random points', () {
        final index = SpatialIndex(fixture.document);
        addTearDown(index.dispose);
        final rng = math.Random(20260730);
        final hit = HitPath(32);

        for (var trial = 0; trial < 200; trial++) {
          final point = _randomPoint(rng, fixture.document.extents);
          // Two radii: one tight enough to miss often, one loose enough that
          // several entities compete and the tie-break rule is exercised.
          for (final radius in [0.01, 5.0]) {
            final found = index.pickInto(
                point, radius, const QueryFilter.picking(), hit);
            final expected = referencePick(
                fixture.document, point, radius, const QueryFilter.picking());

            expect(found, expected != null,
                reason: '${fixture.name} trial $trial at $point r=$radius');
            if (expected != null) {
              expect(hit.entity, expected.entity,
                  reason: '${fixture.name} trial $trial at $point r=$radius');
              expect(hit.kind, expected.kind,
                  reason: '${fixture.name} trial $trial at $point r=$radius');
            }
          }
        }
      });

      test('snap matches brute force over 200 random points', () {
        final index = SpatialIndex(fixture.document);
        addTearDown(index.dispose);
        final rng = math.Random(20260731);
        final out = SnapResult(32);

        for (var trial = 0; trial < 200; trial++) {
          final point = _randomPoint(rng, fixture.document.extents);
          for (final mask in [SnapMask.cheap, SnapMask.all]) {
            index.snapInto(point, 2.0, mask, out);
            final expected =
                referenceSnap(fixture.document, point, 2.0, mask);

            expect(out.found, expected != null,
                reason: '${fixture.name} trial $trial at $point');
            if (expected != null) {
              expect(out.kind, expected.kind,
                  reason: '${fixture.name} trial $trial at $point');
              expect(out.point.x, closeTo(expected.point.x, 1e-9));
              expect(out.point.y, closeTo(expected.point.y, 1e-9));
            }
          }
        }
      });
    });
  }
}
```

`_randomRect` must generate rects that sometimes miss entirely, sometimes cover
everything, and sometimes clip a single entity's edge — a generator that only
produces mid-sized rects in the populated region tests one case 200 times.

- [ ] **Step 4: Run and fix**

```bash
cd packages/jet_cad_2d && dart test test/invariants/differential_test.dart
```

**Expect real failures here, and treat them as findings rather than as test
bugs.** This is the first test that exercises the index against an independent
answer. When one fails, fix the implementation unless you can show the
reference is wrong.

- [ ] **Step 5: Full suite**

```bash
cd packages/jet_cad_2d && dart test && dart analyze && dart format --set-exit-if-changed lib test
```

Expected: 386 + 60 = 446 passing (four tests per fixture across fifteen fixtures).

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "test(jet_cad_2d): differential testing against a brute-force reference

Every query result must equal a brute-force linear scan over the same
document. One property, and unlike hand-picked cases it does not depend
on guessing which cases matter.

The corpus is fixed rather than left to judgement: Plan 1 shipped five
green tests that proved nothing because the fixture was degenerate, not
because the assertion was wrong. Groups inside definitions, mirrored and
non-uniform scale, non-right-angle rotation, coordinates at 4.5e6, both
sides of the rebuild threshold, and a document whose slot order and
handle order disagree are all required rows."
```

---

### Task 17: The allocation harness

**Files:**
- Create: `packages/jet_cad_2d/test/invariants/query_allocation_test.dart`

**Interfaces:**
- Consumes: `dart:developer`'s `Service`, or `VmService` via `package:vm_service` if the former proves insufficient.

**The zero-allocation claim is tested, not asserted in prose.** The assertion is
"no allocation in steady state", not "no allocation ever": the result scratch
grows once, and that growth is permitted. So the harness **warms each query
before measuring**.

- [ ] **Step 1: Write the harness**

Measure with `ProcessInfo.currentRss` deltas across many iterations if the VM
service is unavailable in a plain `dart test` run, and state in a comment which
mechanism was used and why. A harness that silently measures nothing — as the
placeholder in Task 3 does — is worse than none, so if neither mechanism works,
**say so in the task report and mark the test `skip:` with the reason**, rather
than leaving a green test that checks nothing.

```dart
void main() {
  test('forEachInRect does not allocate in steady state', () {
    final doc = largeDocument(50000);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final rect = Aabb2(Vector2(0, 0), Vector2(100, 100));

    var count = 0;
    void visit(int _) => count++;

    // Warm: the result scratch grows here, once, and that growth is allowed.
    for (var i = 0; i < 10; i++) {
      index.forEachInRect(rect, const QueryFilter.rendering(), visit);
    }

    final before = _sampleAllocatedBytes();
    for (var i = 0; i < 1000; i++) {
      index.forEachInRect(rect, const QueryFilter.rendering(), visit);
    }
    final after = _sampleAllocatedBytes();

    final perCall = (after - before) / 1000;
    expect(perCall, lessThan(64),
        reason: 'a per-call allocation would scale with 1000 iterations; '
            'this bound admits VM noise but not a per-query object');
  });

  test('pickInto does not allocate in steady state', () {
    final doc = largeDocument(50000);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final hit = HitPath(32);
    final point = Vector2(50, 50);

    for (var i = 0; i < 10; i++) {
      index.pickInto(point, 1.0, const QueryFilter.picking(), hit);
    }

    final before = _sampleAllocatedBytes();
    for (var i = 0; i < 1000; i++) {
      index.pickInto(point, 1.0, const QueryFilter.picking(), hit);
    }
    final after = _sampleAllocatedBytes();

    expect((after - before) / 1000, lessThan(64),
        reason: 'pickInto runs at pointer-move rate');
  });

  test('snapInto does not allocate in steady state', () {
    final doc = largeDocument(50000);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final out = SnapResult(32);
    final point = Vector2(50, 50);

    for (var i = 0; i < 10; i++) {
      index.snapInto(point, 1.0, SnapMask.all, out);
    }

    final before = _sampleAllocatedBytes();
    for (var i = 0; i < 1000; i++) {
      index.snapInto(point, 1.0, SnapMask.all, out);
    }
    final after = _sampleAllocatedBytes();

    expect((after - before) / 1000, lessThan(64),
        reason: 'snapInto runs at pointer-move rate, with the strictest '
            'budget of the three: SnapMask.all enables the intersection pass');
  });
}

/// A document of [count] line entities on a grid near the origin.
///
/// Near the origin deliberately: this harness measures allocation, not
/// precision, and the differential corpus is where large coordinates are
/// exercised.
DraftDocument largeDocument(int count) {
  final doc = DraftDocument.empty();
  final side = math.sqrt(count).ceil();
  for (var i = 0; i < count; i++) {
    final x = (i % side).toDouble();
    final y = (i ~/ side).toDouble();
    doc.commands.execute(AddEntityCommand(
      record: EntityRecord(
        handle: doc.handleSeed.next(),
        owner: doc.rootHandle,
        kind: EntityKind.line,
        layer: ReservedHandles.layerZero,
        linetype: ReservedHandles.linetypeByLayer,
        linetypeScale: 1.0,
        geomIndex: 0,
        color: const DraftColor.byLayer(),
        lineweight: kByLayer,
        transparency: kByLayer,
        flags: 0,
      ),
      payload: GeometryPayload(
        coords: Float64List.fromList([x, y, x + 0.5, y + 0.5]),
        scalars: Float64List(0),
      ),
    ));
  }
  return doc;
}
```

- [ ] **Step 2: Run it, and act on what it says**

If any query allocates per call, find it and fix it. The likely culprits are:
`Aabb2` construction inside a loop, `Vector2` temporaries in the narrow phase,
a closure captured per call, and `Iterable` methods such as `where` or `map` on
the frame path.

- [ ] **Step 3: Full suite and commit**

```bash
cd packages/jet_cad_2d && dart test && dart analyze && dart format --set-exit-if-changed lib test
git add packages/jet_cad_2d
git commit -m "test(jet_cad_2d): allocation harness for the frame-path queries

The zero-allocation budget is measured, not asserted in prose. Each
query is warmed first, because the result scratch grows once by design
and the claim is 'no allocation in steady state'."
```

---

### Task 18: The query-throughput gate

**Files:**
- Create: `packages/jet_cad_2d/benchmark/query_throughput.dart`
- Create: `packages/jet_cad_2d/benchmark/generate_document.dart`
- Create: `docs/superpowers/notes/2026-07-28-plan-2-gate-results.md`

**Interfaces:**
- Consumes: the whole public query API.

**Every measurement runs twice: on a freshly built index, and with the dirty
list at its rebuild threshold.** At 500k the threshold is 25k linearly scanned
entries on every query, including pick and snap at pointer-move rate. Measuring
only a fresh index would let a threshold pass the gate and fail in use — and a
fresh index is the state a document is in least often.

| Measurement | Threshold | Verdict if missed |
|---|---|---|
| `forEachInRect` returning ~2k visible from 500k | < 2 ms | **fail** — index design returns to Plan 2 |
| `pick` at 500k | < 1 ms | **fail** |
| `snap` at 500k, all kinds | < 1 ms | **fail** |

- [ ] **Step 1: Write the document generator**

`generateDocument(int entityCount, {int definitionCount = 20, int instanceCount = 0, double originX = 4500000.0})`
— entities spread over a plausible floor-plan area, at large world coordinates,
with a realistic mix: mostly lines and polylines, some circles and arcs, a few
hundred text entities, and `definitionCount` definitions each placed many times.

A benchmark document of 500k identical points at the origin would measure
nothing that matters.

- [ ] **Step 2: Write the benchmark**

```dart
/// Runs each measurement twice: fresh, and with the dirty list at threshold.
///
/// A fresh index is the state a document is in least often — every editing
/// session leaves the dirty list populated, and at 500k the threshold is 25k
/// linearly scanned entries on every query.
void main() {
  for (final count in [50000, 500000]) {
    final doc = generateDocument(count);
    final index = SpatialIndex(doc);

    _report('forEachInRect fresh', count,
        () => _timeRectQuery(index, doc));

    _fillDirtyToThreshold(index, doc);
    _report('forEachInRect at dirty threshold', count,
        () => _timeRectQuery(index, doc));

    // …the same pair for pick and snap.
  }
}
```

Report p50 and p95 over at least 100 iterations, discarding the first 20 as
warm-up. Report a mean alone and a stall becomes invisible.

- [ ] **Step 3: Run the gate**

```bash
cd packages/jet_cad_2d && dart run benchmark/query_throughput.dart
```

- [ ] **Step 4: Record the results**

Write `docs/superpowers/notes/2026-07-28-plan-2-gate-results.md` with the
machine, the numbers for every combination, and an explicit **PASS** or
**FAIL** per row against the thresholds above.

**If any row fails, stop and report it.** The gate's verdict is that the index
design returns to Plan 2 — it is not advisory, and it may not be deferred into
Plan 3. The parent spec's reasoning holds: the cost of reversing a design grows
sharply once the next layer is built on it.

- [ ] **Step 5: Commit**

```bash
git add packages/jet_cad_2d docs/superpowers/notes
git commit -m "test(jet_cad_2d): query-throughput gate, fresh and at threshold

Every measurement runs twice. A fresh index is the state a document is
in least often: an editing session leaves the dirty list populated, and
at 500k the rebuild threshold is 25k linearly scanned entries on every
query including pick and snap at pointer-move rate. Measuring only a
fresh index would let a threshold pass the gate and fail in use."
```

---

## Notes for whoever executes this plan

**Where the defects will be.** Plan 1's post-mortem is worth carrying: of the
defects found there, the expensive ones were not wrong logic but *unfed
mechanisms* and *degenerate fixtures*. Two candidates in this plan:

- `ContainerIndex.markLeafDead` is called from the invalidation path only. If
  that path is wrong, the dead bitmask never fires and every moved entity is
  reported twice — by the stale tree entry and by the dirty list. The
  `rect_query_test` case "a slot that is both in the tree and dirty is reported
  once" is the only thing standing between that and a silent double-report.
- `PackedRTree`'s traversal stack sizing (Task 3, Step 3) is deliberately left
  wrong in the plan text, with the fix described. If it is "fixed" by raising
  the depth constant rather than by making the stack breadth-aware, the 1000-item
  differential test will pass and the 500k benchmark will overflow.

**Two constants worth re-reading before tuning:** the rebuild threshold
`max(64, 0.05 * count)` and `kIntersectionCandidateCap = 64`. Both are declared
so they can be tuned against the benchmark — but tune them *with* the benchmark,
and record the before-and-after, rather than adjusting until something passes.
