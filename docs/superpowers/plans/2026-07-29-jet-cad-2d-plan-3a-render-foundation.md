# jet_cad_2d Plan 3a — Render Path Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the uncached render path for `jet_cad_2d` — camera, `Float64` coordinate rebasing, style resolution, an instance-descending painter — and measure it with five repeatable rigs, so Plan 3b's caches are designed against numbers instead of assumptions.

**Architecture:** Style resolution lands in the pure `jet_cad_2d` package (DXF semantics, no `dart:ui`). A new `packages/jet_cad_2d_flutter` holds the camera, a thin `DrawSink` paint seam with production/recording/null implementations, and `DraftPainter`, which merges two ascending-handle query streams into global handle order and recurses into definitions through `ContainerIndex`. Correctness is established by a differential oracle comparing the painter's operation recording against an index-free reference walk, not by pixel goldens.

**Tech Stack:** Dart 3.5+, Flutter (stable, ≥3.24), `vector_math_64`, `package:test` for the pure package, `flutter_test` + `integration_test` for the widget package.

**Spec:** [2026-07-29-jet-cad-2d-plan-3a-design.md](../specs/2026-07-29-jet-cad-2d-plan-3a-design.md)

## Global Constraints

- **Draw order is ascending handle value, globally.** Every query already returns that order; the painter must preserve it across the leaf and instance streams.
- **Zero allocation on the frame path.** The painter's buffers must not grow after warm-up. Proven structurally through capacity getters, in the shape of `SpatialIndex.entityScratchCapacity`.
- **Leaf containment is `EntityRecord.owner`, only.** Never read leaves from a `children` list — `children` holds child nodes.
- **Geometric *decisions* use `Tolerance`; comparisons of *stored values* use exact `==`.**
- **`packages/jet_cad_2d` must never import Flutter.** No `dart:ui`, no `package:flutter`. `dart test` must keep working there.
- **`document.commands.onAfterMutate` belongs to `SpatialIndex`.** It is a single nullable field, claimed in `SpatialIndex`'s constructor. Nothing in this plan may assign it; the painter listens to the async `document.changes` stream instead.
- **`GeometryStore.peek` for frame reads, `read` for anything stored.** `peek` returns the store's own buffers.
- **Every fixture instance carries a distinct non-uniform scale, a rotation and a translation.** No identity transforms in any new fixture. At least one mirrored, one nested two levels deep, one leaf owned by a group node.
- Analyzer and `dart format` clean at every commit. `dart test` in `packages/jet_cad_2d` (599 tests today) stays green throughout.

## Deviations from the spec, recorded here deliberately

1. **`DrawSink` takes `Transform2`, not `Matrix4`.** The spec's sketch used `Matrix4`. `Transform2` is the engine's own affine type with exact `==` semantics for the recording sink, and `CanvasDrawSink` converts to the `Float64List(16)` `Canvas.transform` wants at the single point it is needed. Nothing else in the design depends on the choice.
2. **`StyleResolver.styleFor` takes an entity *slot*, not a `Handle`.** The spec wrote `Handle`. The frame path holds slots — `forEachInRect` yields slots — and a handle-keyed signature would force a map lookup per entity per frame purely to satisfy a signature. The handle is recoverable with `entities.handleAt(slot)`.

## File Structure

**Pure package (`packages/jet_cad_2d`)**

| File | Responsibility |
|---|---|
| `lib/src/document/style_context.dart` (create) | `StyleContext` value type — the 3b cache key |
| `lib/src/document/resolved_style.dart` (create) | `ResolvedStyle` + `aciToRgb` |
| `lib/src/document/style_resolver.dart` (create) | `StyleResolver` interface + `DocumentStyleResolver` |
| `lib/src/testing/generate_document.dart` (move) | shared corpus generator |
| `lib/testing.dart` (create) | testing-only entry point |
| `lib/src/index/query_scratch.dart` (modify) | `Int32List` → `Uint32List` handle truncation fix |

**Flutter package (`packages/jet_cad_2d_flutter`)**

| File | Responsibility |
|---|---|
| `lib/src/viewport_transform.dart` | world↔screen affine in `Float64` |
| `lib/src/camera_controller.dart` | `ValueNotifier<ViewportTransform>`, pan/zoom, rebase origin |
| `lib/src/draw_sink.dart` | the seam + `RecordingDrawSink` + `NullDrawSink` |
| `lib/src/canvas_draw_sink.dart` | `ui.Canvas` implementation, `ResolvedStyle` → `Paint` |
| `lib/src/leaf_owner_map.dart` | definition → leaf slots, incrementally maintained |
| `lib/src/draft_painter.dart` | the frame walk |
| `lib/src/reference_walk.dart` | the index-free oracle |
| `lib/src/draft_canvas.dart` | the widget + `DocChangeNotifier` |

**Rigs**

| File | Responsibility |
|---|---|
| `packages/jet_cad_2d_flutter/test/rig/paint_microbench_test.dart` | R1 + R3 |
| `apps/dev_harness_2d/` | harness app |
| `apps/dev_harness_2d/integration_test/frame_timing_test.dart` | R2, R4a, R4b |

---

## Task 0: Fix `QueryScratch` handle truncation

`QueryScratch` stores handle *values* for `forEachInstanceInRect` in an `Int32List` while `kMaxHandle` is `0xFFFFFFFF`. Above 2³¹ the sort compares negatives and `Handle(...)` throws `HandleRangeError`. Latent today, in the exact path 3a's painter consumes.

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/index/query_scratch.dart:22`
- Test: `packages/jet_cad_2d/test/index/query_scratch_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `QueryScratch` unchanged in API; backing store becomes `Uint32List`.

- [ ] **Step 1: Write the failing test**

```dart
  test('sortByValue orders handle values above 2^31 correctly', () {
    // `forEachInstanceInRect` stores raw handle values here, and kMaxHandle is
    // 0xFFFFFFFF. An Int32List reads 0x90000000 as negative, so it sorts below
    // a small handle and then throws HandleRangeError when the caller rebuilds
    // the Handle. Values chosen to straddle the sign bit.
    final scratch = QueryScratch(4);
    scratch
      ..add(0x90000000)
      ..add(0x00000010)
      ..add(0xFFFFFFFF);
    scratch.sortByValue();

    expect([for (var i = 0; i < scratch.length; i++) scratch[i]],
        [0x00000010, 0x90000000, 0xFFFFFFFF]);
    expect(() => Handle(scratch[2]), returnsNormally);
  });
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `cd packages/jet_cad_2d && dart test test/index/query_scratch_test.dart -n 'above 2^31'`
Expected: FAIL — the stored values come back negative and the order is wrong.

- [ ] **Step 3: Change the backing store**

In `query_scratch.dart`, change both the field and the constructor initialiser:

```dart
  QueryScratch([int initialCapacity = 1024])
      : _slots = Uint32List(initialCapacity < 1 ? 1 : initialCapacity);

  Uint32List _slots;
```

Update `_grow`'s allocation to `Uint32List` as well. Slots are non-negative by construction, so the entity-slot use is unaffected.

- [ ] **Step 4: Run the full index suite**

Run: `cd packages/jet_cad_2d && dart test`
Expected: PASS, 600 tests.

- [ ] **Step 5: Commit**

```bash
git add packages/jet_cad_2d/lib/src/index/query_scratch.dart packages/jet_cad_2d/test/index/query_scratch_test.dart
git commit -m "fix(jet_cad_2d): stop truncating handle values above 2^31 in QueryScratch"
```

---

## Task 1: Move the corpus generator into the package

Both Plan 2's benchmark and 3a's rigs must generate identical documents. `benchmark/` is outside `lib/`, so the Flutter package cannot import it.

**Files:**
- Create: `packages/jet_cad_2d/lib/src/testing/generate_document.dart` (moved content)
- Create: `packages/jet_cad_2d/lib/testing.dart`
- Delete: `packages/jet_cad_2d/benchmark/generate_document.dart`
- Modify: `packages/jet_cad_2d/benchmark/query_throughput.dart` (import line)
- Test: `packages/jet_cad_2d/test/testing/generate_document_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `package:jet_cad_2d/testing.dart` exporting `generateDocument({int entityCount, int definitionCount = 20, int instanceCount = 0, double originX = kDefaultOriginX})`, plus `kDefaultOriginX`, `kOriginY`, `kFloorWidth`, `kFloorHeight`.

- [ ] **Step 1: Move the file, unchanged**

```bash
git mv packages/jet_cad_2d/benchmark/generate_document.dart \
       packages/jet_cad_2d/lib/src/testing/generate_document.dart
```

Fix its relative imports: it now sits two directories deeper, so `import 'package:jet_cad_2d/jet_cad_2d.dart';` replaces any relative engine import.

- [ ] **Step 2: Add the entry point**

Create `packages/jet_cad_2d/lib/testing.dart`:

```dart
/// Test and benchmark fixtures. **Not** part of the package's public surface —
/// `jet_cad_2d.dart` deliberately does not export this. It lives in `lib/` for
/// one reason: the Flutter package's render rigs and this package's query
/// benchmark must generate byte-identical documents, and a file under
/// `benchmark/` cannot be imported across packages.
library;

export 'src/testing/generate_document.dart';
```

- [ ] **Step 3: Repoint the benchmark**

In `benchmark/query_throughput.dart`, replace `import 'generate_document.dart';` with:

```dart
import 'package:jet_cad_2d/testing.dart';
```

- [ ] **Step 4: Write the determinism test**

Create `test/testing/generate_document_test.dart`:

```dart
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d/testing.dart';
import 'package:test/test.dart';

void main() {
  test('generateDocument is deterministic across calls', () {
    // The generator seeds math.Random(0xC0FFEE). Two documents built with the
    // same arguments must agree entity for entity, or Plan 2's numbers and
    // Plan 3a's are not measured on the same drawing and cannot be compared.
    final a = generateDocument(2000, definitionCount: 20);
    final b = generateDocument(2000, definitionCount: 20);

    expect(a.entities.liveSlots.length, b.entities.liveSlots.length);
    for (final slot in a.entities.liveSlots) {
      expect(a.entities.handleAt(slot), b.entities.handleAt(slot));
      expect(a.entities.kindAt(slot), b.entities.kindAt(slot));
      expect(a.geometry.peek(a.entities.geomIndexAt(slot)).coords,
          b.geometry.peek(b.entities.geomIndexAt(slot)).coords);
    }
    expect(a.extents.minX, b.extents.minX);
    expect(a.extents.maxX, b.extents.maxX);
  });
}
```

- [ ] **Step 5: Run the tests and the benchmark**

Run: `cd packages/jet_cad_2d && dart test && dart run benchmark/query_throughput.dart`
Expected: tests PASS; the benchmark prints numbers matching those recorded in `docs/superpowers/notes/2026-07-28-plan-2-gate-results.md` within the machine's ±15% spread. **If any row moved outside that spread, stop — the move changed the corpus.**

- [ ] **Step 6: Commit**

```bash
git add -A packages/jet_cad_2d
git commit -m "refactor(jet_cad_2d): share the corpus generator through package:jet_cad_2d/testing.dart"
```

---

## Task 2: Style resolution in the pure package

**Files:**
- Create: `packages/jet_cad_2d/lib/src/document/style_context.dart`
- Create: `packages/jet_cad_2d/lib/src/document/resolved_style.dart`
- Create: `packages/jet_cad_2d/lib/src/document/style_resolver.dart`
- Modify: `packages/jet_cad_2d/lib/jet_cad_2d.dart` (three exports)
- Test: `packages/jet_cad_2d/test/document/style_resolver_test.dart`

**Interfaces:**
- Consumes: `EntityStore` column accessors, `DocumentTables.layers`, `decodeColor`, `kByLayer`, `kByBlock`, `ReservedHandles`.
- Produces:
  - `StyleContext({int color, Handle linetype, double linetypeScale, int lineweight, int transparency, Handle layer})` with `==`/`hashCode`, and `StyleContext.documentRoot`.
  - `ResolvedStyle({int argb, int lineweightHundredths, Handle linetype, double linetypeScale})`.
  - `int aciToRgb(int aci)`.
  - `abstract class StyleResolver { StyleContext contextFor(Handle instance, StyleContext inherited); ResolvedStyle styleFor(int slot, StyleContext ctx); }`
  - `class DocumentStyleResolver implements StyleResolver { DocumentStyleResolver(this.document); }`

- [ ] **Step 1: Write the failing tests**

Create `test/document/style_resolver_test.dart`:

```dart
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

Handle addLine(DraftDocument doc, Handle owner,
    {required Handle layer, required DraftColor color, int lineweight = kByLayer}) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: owner,
      kind: EntityKind.line,
      layer: layer,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: color,
      lineweight: lineweight,
      transparency: kByLayer,
      flags: 0,
    ),
    payload: GeometryPayload(
      coords: Float64List.fromList([0, 0, 1, 1]),
      scalars: Float64List(0),
    ),
  ));
  return handle;
}

void main() {
  test('ByLayer resolves against the entity layer, not the context layer', () {
    final doc = DraftDocument.empty();
    const red = Handle(100);
    doc.tables.layers.add(const LayerRecord(
      handle: red,
      name: 'red',
      color: IndexedColor(1),
      linetype: ReservedHandles.continuousLinetype,
      lineweight: 50,
      transparency: 0,
      visible: true,
      locked: false,
    ));
    final h = addLine(doc, doc.rootHandle,
        layer: red, color: const ByLayerColor());
    final slot = doc.entities.slotOf(h)!;

    final resolver = DocumentStyleResolver(doc);
    final style = resolver.styleFor(slot, StyleContext.documentRoot);

    expect(style.argb, 0xFF000000 | aciToRgb(1));
    expect(style.lineweightHundredths, 50);
  });

  test('ByBlock resolves against the context, and layer-0 inherits it', () {
    // A definition's contents authored ByBlock on layer 0 are the whole point
    // of the block model: 500 instances share one geometry and each renders in
    // its own colour. If this resolves against the layer table instead, every
    // instance renders identically and the picture cache in 3b would be keyed
    // on a context that changes nothing.
    final doc = DraftDocument.empty();
    const def = Handle(200);
    doc.tree.addDefinition(Definition(
      handle: def, name: 'sym', basePoint: Vector2.zero(), children: const []));
    final h = addLine(doc, def,
        layer: ReservedHandles.layerZero, color: const ByBlockColor());
    final slot = doc.entities.slotOf(h)!;

    const instance = Handle(201);
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: instance,
      parent: doc.rootHandle,
      transform: Transform2.translation(5, 7),
      definition: def,
      layer: ReservedHandles.layerZero,
      color: const IndexedColor(3),
    )));

    final resolver = DocumentStyleResolver(doc);
    final ctx = resolver.contextFor(instance, StyleContext.documentRoot);
    expect(ctx.color, encodeColor(const IndexedColor(3)));

    final style = resolver.styleFor(slot, ctx);
    expect(style.argb, 0xFF000000 | aciToRgb(3));
  });

  test('two levels of nesting compose contexts outward-in', () {
    // The inner instance is authored ByBlock, so it must take the OUTER
    // instance's concrete colour, not fall back to a default. A fixture with
    // one nesting level cannot tell the two apart.
    final doc = DraftDocument.empty();
    const inner = Handle(300), outer = Handle(301);
    doc.tree.addDefinition(Definition(
      handle: inner, name: 'inner', basePoint: Vector2.zero(), children: const []));
    doc.tree.addDefinition(Definition(
      handle: outer, name: 'outer', basePoint: Vector2.zero(), children: const []));
    final h = addLine(doc, inner,
        layer: ReservedHandles.layerZero, color: const ByBlockColor());
    final slot = doc.entities.slotOf(h)!;

    const innerNode = Handle(302), outerNode = Handle(303);
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: innerNode,
      parent: outer,
      transform: Transform2.translation(1, 2),
      definition: inner,
      layer: ReservedHandles.layerZero,
      color: const ByBlockColor(),
    )));
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: outerNode,
      parent: doc.rootHandle,
      transform: Transform2.translation(3, 4),
      definition: outer,
      layer: ReservedHandles.layerZero,
      color: const IndexedColor(5),
    )));

    final resolver = DocumentStyleResolver(doc);
    final ctxOuter = resolver.contextFor(outerNode, StyleContext.documentRoot);
    final ctxInner = resolver.contextFor(innerNode, ctxOuter);

    expect(resolver.styleFor(slot, ctxInner).argb, 0xFF000000 | aciToRgb(5));
  });

  test('transparency becomes the alpha channel', () {
    final doc = DraftDocument.empty();
    final h = addLine(doc, doc.rootHandle,
        layer: ReservedHandles.layerZero, color: const IndexedColor(2));
    final slot = doc.entities.slotOf(h)!;
    // 0 is opaque in DXF: alpha = 255 - transparency.
    final ctx = StyleContext.documentRoot.copyWith(transparency: 64);
    expect(DocumentStyleResolver(doc).styleFor(slot, ctx).argb >> 24, 255 - 64);
  });
}
```

- [ ] **Step 2: Run and confirm failure**

Run: `cd packages/jet_cad_2d && dart test test/document/style_resolver_test.dart`
Expected: FAIL — `StyleContext` and friends are undefined.

- [ ] **Step 2a: Add `InstanceNode.color` — required, not conditional**

`InstanceNode` today carries `definition`, `layer` and the inherited `Node` fields, and **no colour** ([`node.dart:152-163`](../../../packages/jet_cad_2d/lib/src/document/node.dart#L152-L163)). Without it `contextFor` has nothing to read, every instance resolves identically, and 3b's cache key is degenerate by construction. Add:

```dart
final class InstanceNode extends Node {
  final Handle definition;
  final Handle layer;

  /// This instance's own colour, imposed on its definition's BYBLOCK contents.
  ///
  /// `ByBlockColor` — the default — means "inherit from whatever places me",
  /// which for a root-level instance is the document context. This field is how
  /// 500 tables share one geometry and render in 500 colours, and it
  /// round-trips to DXF losslessly.
  final DraftColor color;

  const InstanceNode({
    required super.handle,
    required super.parent,
    required super.transform,
    required this.definition,
    required this.layer,
    this.color = const ByBlockColor(),
    super.visible = true,
  });
```

Carry it through `copyWith`, `toJson` (`'color': encodeColor(color)`), `fromJson` (absent key → `ByBlockColor`, so existing documents load unchanged), `==` and `hashCode`. Add a codec round-trip test asserting an instance with `IndexedColor(3)` survives `save → load`, and one asserting a document written before this field loads with `ByBlockColor`.

- [ ] **Step 3: Implement `StyleContext`**

```dart
/// Everything a definition's BYBLOCK / layer-0 contents resolve against.
///
/// Value equality and a stable hashCode are required: Plan 3b keys the
/// definition picture cache on this, and a context that compares by identity
/// would give every instance its own cache entry.
@immutable
final class StyleContext {
  const StyleContext({
    required this.color,
    required this.linetype,
    required this.linetypeScale,
    required this.lineweight,
    required this.transparency,
    required this.layer,
  });

  /// Encoded and **concrete** — never [kByLayer] or [kByBlock].
  final int color;
  final Handle linetype;
  final double linetypeScale;

  /// 1/100 mm, concrete.
  final int lineweight;

  /// 0..255, concrete.
  final int transparency;

  /// The layer a layer-0 entity inherits.
  final Handle layer;

  static const StyleContext documentRoot = StyleContext(
    color: 7, // ACI 7: the DXF default foreground
    linetype: ReservedHandles.continuousLinetype,
    linetypeScale: 1.0,
    lineweight: 25, // 0.25 mm
    transparency: 0,
    layer: ReservedHandles.layerZero,
  );

  StyleContext copyWith({
    int? color,
    Handle? linetype,
    double? linetypeScale,
    int? lineweight,
    int? transparency,
    Handle? layer,
  }) =>
      StyleContext(
        color: color ?? this.color,
        linetype: linetype ?? this.linetype,
        linetypeScale: linetypeScale ?? this.linetypeScale,
        lineweight: lineweight ?? this.lineweight,
        transparency: transparency ?? this.transparency,
        layer: layer ?? this.layer,
      );

  @override
  bool operator ==(Object other) =>
      other is StyleContext &&
      other.color == color &&
      other.linetype == linetype &&
      other.linetypeScale == linetypeScale &&
      other.lineweight == lineweight &&
      other.transparency == transparency &&
      other.layer == layer;

  @override
  int get hashCode => Object.hash(
      color, linetype, linetypeScale, lineweight, transparency, layer);
}
```

- [ ] **Step 4: Implement `ResolvedStyle` and `aciToRgb`**

```dart
/// One entity's concrete paint under a [StyleContext].
@immutable
final class ResolvedStyle {
  const ResolvedStyle({
    required this.argb,
    required this.lineweightHundredths,
    required this.linetype,
    required this.linetypeScale,
  });

  /// 0xAARRGGBB. Alpha is `255 - transparency`.
  final int argb;

  /// Paper-space width in 1/100 mm. **Not** a world quantity.
  final int lineweightHundredths;

  final Handle linetype;
  final double linetypeScale;

  @override
  bool operator ==(Object other) =>
      other is ResolvedStyle &&
      other.argb == argb &&
      other.lineweightHundredths == lineweightHundredths &&
      other.linetype == linetype &&
      other.linetypeScale == linetypeScale;

  @override
  int get hashCode =>
      Object.hash(argb, lineweightHundredths, linetype, linetypeScale);
}

/// AutoCAD Color Index to RGB.
///
/// The first nine entries are the standard fixed colours and are exact. Beyond
/// them this is a **declared approximation** over the 240-colour cube; the full
/// table is a DXF-plan concern, where it can be checked against real files
/// rather than transcribed from memory. Callers that need exactness above 9
/// should use [TrueColor].
int aciToRgb(int aci) {
  const fixed = <int>[
    0x000000, // 0 — ByBlock placeholder, never resolved to
    0xFF0000, // 1 red
    0xFFFF00, // 2 yellow
    0x00FF00, // 3 green
    0x00FFFF, // 4 cyan
    0x0000FF, // 5 blue
    0xFF00FF, // 6 magenta
    0xFFFFFF, // 7 white/black-on-light
    0x808080, // 8 dark grey
    0xC0C0C0, // 9 light grey
  ];
  if (aci >= 0 && aci < fixed.length) return fixed[aci];
  if (aci >= 250 && aci <= 255) {
    final v = 0x33 + (aci - 250) * 0x22;
    return (v << 16) | (v << 8) | v;
  }
  final i = (aci - 10) % 240;
  final r = 0x33 * (1 + (i ~/ 80));
  final g = 0x33 * (1 + ((i ~/ 16) % 5));
  final b = 0x33 * (1 + (i % 16) ~/ 3);
  return (r.clamp(0, 255) << 16) | (g.clamp(0, 255) << 8) | b.clamp(0, 255);
}
```

- [ ] **Step 5: Implement the resolver**

```dart
abstract class StyleResolver {
  /// The context an instance imposes on its definition's contents.
  StyleContext contextFor(Handle instance, StyleContext inherited);

  /// Concrete paint for one entity slot under a context.
  ///
  /// Takes a slot rather than a handle because the frame path holds slots:
  /// `forEachInRect` yields them, and a handle-keyed signature would add a map
  /// lookup per entity per frame to satisfy the signature alone.
  ResolvedStyle styleFor(int slot, StyleContext ctx);
}

class DocumentStyleResolver implements StyleResolver {
  DocumentStyleResolver(this.document);

  final DraftDocument document;

  @override
  StyleContext contextFor(Handle instance, StyleContext inherited) {
    final node = document.tree[instance];
    if (node is! InstanceNode) return inherited;
    final encoded = encodeColor(node.color);
    final color = switch (encoded) {
      kByBlock => inherited.color,
      kByLayer => _layerColorOf(node.layer, inherited),
      _ => encoded,
    };
    return StyleContext(
      color: color,
      linetype: inherited.linetype,
      linetypeScale: inherited.linetypeScale,
      lineweight: inherited.lineweight,
      transparency: inherited.transparency,
      layer: node.layer == ReservedHandles.layerZero
          ? inherited.layer
          : node.layer,
    );
  }

  @override
  ResolvedStyle styleFor(int slot, StyleContext ctx) {
    final entityLayer = document.entities.layerAt(slot);
    // The layer-0 rule: an entity on layer 0 takes the layer it is placed
    // through, which is what the context carries.
    final layer =
        entityLayer == ReservedHandles.layerZero ? ctx.layer : entityLayer;
    final record = document.tables.layers[layer];

    final encoded = document.entities.colorAt(slot);
    final color = switch (encoded) {
      kByBlock => ctx.color,
      kByLayer => _concreteLayerColor(record, ctx),
      _ => encoded,
    };

    final lw = document.entities.lineweightAt(slot);
    final lineweight = switch (lw) {
      kByBlock => ctx.lineweight,
      kByLayer => record?.lineweight ?? ctx.lineweight,
      kLineweightDefault => ctx.lineweight,
      _ => lw,
    };

    final tr = document.entities.transparencyAt(slot);
    final transparency = switch (tr) {
      kByBlock => ctx.transparency,
      kByLayer => record?.transparency ?? ctx.transparency,
      _ => tr,
    };

    final lt = document.entities.linetypeAt(slot);
    final linetype = lt == ReservedHandles.byBlockLinetype
        ? ctx.linetype
        : lt == ReservedHandles.byLayerLinetype
            ? (record?.linetype ?? ctx.linetype)
            : lt;

    return ResolvedStyle(
      argb: ((255 - transparency.clamp(0, 255)) << 24) | _rgbOf(color),
      lineweightHundredths:
          lineweight == kLineweightDefault ? ctx.lineweight : lineweight,
      linetype: linetype,
      linetypeScale: document.entities.linetypeScaleAt(slot),
    );
  }

  int _layerColorOf(Handle layer, StyleContext inherited) =>
      _concreteLayerColor(document.tables.layers[layer], inherited);

  int _concreteLayerColor(LayerRecord? record, StyleContext ctx) {
    if (record == null) return ctx.color;
    final encoded = encodeColor(record.color);
    // A layer whose own colour is BYLAYER or BYBLOCK is malformed; the context
    // is the only defined answer left.
    return (encoded == kByLayer || encoded == kByBlock) ? ctx.color : encoded;
  }

  int _rgbOf(int encoded) => switch (decodeColor(encoded)) {
        IndexedColor(:final aci) => aciToRgb(aci),
        TrueColor(:final rgb) => rgb,
        // Unreachable: both branches resolve to a concrete value above.
        _ => aciToRgb(7),
      };
}
```

- [ ] **Step 6: Export and run**

Add to `lib/jet_cad_2d.dart`:

```dart
export 'src/document/resolved_style.dart';
export 'src/document/style_context.dart';
export 'src/document/style_resolver.dart';
```

Run: `cd packages/jet_cad_2d && dart test && dart analyze && dart format --set-exit-if-changed .`
Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
git add -A packages/jet_cad_2d
git commit -m "feat(jet_cad_2d): resolve style through StyleContext, BYBLOCK and the layer-0 rule"
```

---

## Task 3: Scaffold the Flutter package and `ViewportTransform`

**Files:**
- Create: `packages/jet_cad_2d_flutter/pubspec.yaml`, `analysis_options.yaml`, `lib/jet_cad_2d_flutter.dart`
- Create: `packages/jet_cad_2d_flutter/lib/src/viewport_transform.dart`
- Modify: `pubspec.yaml` (workspace list)
- Test: `packages/jet_cad_2d_flutter/test/viewport_transform_test.dart`

**Interfaces:**
- Consumes: `Transform2`, `Vector2`, `Aabb2`.
- Produces: `ViewportTransform({required Transform2 worldToScreenMatrix})` with `Vector2 worldToScreen(Vector2)`, `Vector2 screenToWorld(Vector2)`, `Aabb2 visibleWorld(Size)`, `double get scale`; and `ViewportTransform.fit(Aabb2 world, Size viewport)`.

- [ ] **Step 1: Create the package**

`packages/jet_cad_2d_flutter/pubspec.yaml`:

```yaml
name: jet_cad_2d_flutter
description: >-
  Flutter rendering layer for the pure-Dart jet_cad_2d engine. Owns the camera,
  coordinate rebasing, the paint seam and the viewport widget. The engine
  package stays free of dart:ui.
version: 0.1.0
repository: https://github.com/ahmeturel/jet-cad
publish_to: none
resolution: workspace

environment:
  sdk: ^3.5.0
  flutter: ">=3.24.0"

dependencies:
  flutter:
    sdk: flutter
  jet_cad_2d:
    path: ../jet_cad_2d
  meta: ^1.18.0
  vector_math: ^2.2.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  lints: ^6.1.0
```

Copy `packages/jet_cad_2d/analysis_options.yaml` verbatim into the new package. Add both new paths to the root `pubspec.yaml` `workspace:` list:

```yaml
workspace:
  - packages/jet_cad
  - packages/jet_cad_2d
  - packages/jet_cad_2d_flutter
  - apps/dev_harness
  - apps/dev_harness_2d
```

Create `apps/dev_harness_2d` in Task 15; until then leave it out of the list to keep `flutter pub get` working, and add it there.

- [ ] **Step 2: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

void main() {
  test('round-trips a point at site-plan magnitude in Float64', () {
    // 4.5e6 is ordinary in DXF and is where float32 spacing reaches ~0.5
    // units. The transform itself must never lose that; only the residual
    // handed to Canvas is allowed to be float32.
    final vt = ViewportTransform(
      worldToScreenMatrix: Transform2.translation(-4.5e6, -4.5e6)
          .multiply(Transform2.scale(2.0, 2.0)),
    );
    final world = Vector2(4500000.125, 4500000.375);
    final back = vt.screenToWorld(vt.worldToScreen(world));

    expect(back.x, closeTo(world.x, 1e-6));
    expect(back.y, closeTo(world.y, 1e-6));
  });

  test('visibleWorld covers the viewport corners under rotation', () {
    final vt = ViewportTransform(
      worldToScreenMatrix: Transform2.rotation(0.4).multiply(
          Transform2.scale(3.0, 3.0)),
    );
    final box = vt.visibleWorld(const Size(800, 600));
    for (final corner in [
      const Offset(0, 0),
      const Offset(800, 0),
      const Offset(0, 600),
      const Offset(800, 600),
    ]) {
      final w = vt.screenToWorld(Vector2(corner.dx, corner.dy));
      expect(box.containsPoint(w), isTrue,
          reason: 'a corner outside the culling rect is geometry never drawn');
    }
  });
}
```

- [ ] **Step 3: Run and confirm failure**

Run: `cd packages/jet_cad_2d_flutter && flutter test test/viewport_transform_test.dart`
Expected: FAIL — `ViewportTransform` undefined.

- [ ] **Step 4: Implement**

```dart
/// The world→screen affine, held in `Float64` for its whole life.
///
/// Screen coordinates are logical pixels with y down; world coordinates are
/// document units with y up, which the fitting constructor flips. Nothing here
/// ever hands an absolute world coordinate to `dart:ui` — see `CameraController`
/// and the rebase origin for why that matters at 4.5e6.
@immutable
class ViewportTransform {
  ViewportTransform({required this.worldToScreenMatrix})
      : _inverse = worldToScreenMatrix.invert();

  final Transform2 worldToScreenMatrix;
  final Transform2 _inverse;

  /// Geometric mean of the axis scales — the number stroke widths divide by.
  double get scale => worldToScreenMatrix.scaleMagnitude;

  Vector2 worldToScreen(Vector2 world) =>
      worldToScreenMatrix.transformPoint(world);

  Vector2 screenToWorld(Vector2 screen) => _inverse.transformPoint(screen);

  /// The world-space AABB of the viewport rectangle.
  ///
  /// All four corners are transformed, not two: under rotation the axis-aligned
  /// box of two opposite corners omits geometry that is genuinely on screen.
  Aabb2 visibleWorld(Size viewport) {
    var box = Aabb2.empty();
    for (final p in [
      Vector2(0, 0),
      Vector2(viewport.width, 0),
      Vector2(0, viewport.height),
      Vector2(viewport.width, viewport.height),
    ]) {
      box = box.expandedToPoint(screenToWorld(p));
    }
    return box;
  }

  /// Fits [world] into [viewport] with a 5% margin, y flipped.
  factory ViewportTransform.fit(Aabb2 world, Size viewport) {
    final w = (world.maxX - world.minX).abs();
    final h = (world.maxY - world.minY).abs();
    final s = w == 0 || h == 0
        ? 1.0
        : 0.95 * math.min(viewport.width / w, viewport.height / h);
    final cx = (world.minX + world.maxX) / 2;
    final cy = (world.minY + world.maxY) / 2;
    return ViewportTransform(
      worldToScreenMatrix: Transform2(
        s, 0, 0, -s,
        viewport.width / 2 - s * cx,
        viewport.height / 2 + s * cy,
      ),
    );
  }
}
```

- [ ] **Step 5: Run, analyze, format, commit**

Run: `cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --set-exit-if-changed .`

```bash
git add -A packages/jet_cad_2d_flutter pubspec.yaml
git commit -m "feat(jet_cad_2d_flutter): scaffold the package with a Float64 ViewportTransform"
```

---

## Task 4: `CameraController` and the rebase origin

**Files:**
- Create: `packages/jet_cad_2d_flutter/lib/src/camera_controller.dart`
- Test: `packages/jet_cad_2d_flutter/test/camera_controller_test.dart`

**Interfaces:**
- Consumes: `ViewportTransform`.
- Produces: `class CameraController extends ValueNotifier<ViewportTransform>` with `void panBy(Offset screenDelta)`, `void zoomAt(Offset screenFocus, double factor)`; and the free function `Vector2 rebaseOriginFor(Aabb2 visibleWorld)`.

- [ ] **Step 1: Write the failing tests**

```dart
  test('the rebase origin is stable while the camera moves within one step', () {
    // A per-frame origin that tracks the camera continuously changes the
    // float32 residual on every frame, so a straight pan makes geometry
    // shimmer. Snapping to a power-of-two grid means the origin only moves in
    // discrete jumps, and the residual stays bounded and reproducible.
    final a = rebaseOriginFor(Aabb2(Vector2(4500000, 4500000), Vector2(4500100, 4500100)));
    final b = rebaseOriginFor(Aabb2(Vector2(4500001, 4500001), Vector2(4500101, 4500101)));
    expect(a.x, b.x);
    expect(a.y, b.y);
  });

  test('the origin is within one grid step of the view and lands on the grid', () {
    final box = Aabb2(Vector2(4500000, 4500000), Vector2(4500100, 4500100));
    final o = rebaseOriginFor(box);
    final span = 100.0;
    expect((o.x - 4500000).abs(), lessThanOrEqualTo(2 * span));
    // The residual any point in view produces stays small enough for float32
    // to carry it without visible error.
    expect((4500100 - o.x).abs(), lessThan(1 << 20));
  });

  test('zoomAt keeps the world point under the cursor fixed', () {
    final camera = CameraController(ViewportTransform.fit(
        Aabb2(Vector2(0, 0), Vector2(100, 100)), const Size(800, 600)));
    const focus = Offset(320, 210);
    final before = camera.value.screenToWorld(Vector2(focus.dx, focus.dy));
    camera.zoomAt(focus, 2.5);
    final after = camera.value.screenToWorld(Vector2(focus.dx, focus.dy));
    expect(after.x, closeTo(before.x, 1e-9));
    expect(after.y, closeTo(before.y, 1e-9));
  });
```

- [ ] **Step 2: Run and confirm failure**

Run: `cd packages/jet_cad_2d_flutter && flutter test test/camera_controller_test.dart`
Expected: FAIL — undefined.

- [ ] **Step 3: Implement**

```dart
/// The rebase origin for one frame: the view's centre snapped to a
/// power-of-two world grid whose step is derived from the view span.
///
/// Two properties matter and both come from the snapping. The origin is
/// **stable** across small camera movements, so a pan does not re-quantise
/// every coordinate on every frame; and it is **near** the geometry, so the
/// residual reaching float32 is small. Deriving the step from the span rather
/// than fixing it keeps both true at every zoom level.
Vector2 rebaseOriginFor(Aabb2 visibleWorld) {
  final span = math.max(
    (visibleWorld.maxX - visibleWorld.minX).abs(),
    (visibleWorld.maxY - visibleWorld.minY).abs(),
  );
  if (span == 0 || !span.isFinite) return Vector2.zero();
  final exponent = (math.log(span) / math.ln2).floor();
  final step = math.pow(2.0, exponent).toDouble();
  final cx = (visibleWorld.minX + visibleWorld.maxX) / 2;
  final cy = (visibleWorld.minY + visibleWorld.maxY) / 2;
  return Vector2((cx / step).floorToDouble() * step,
      (cy / step).floorToDouble() * step);
}

/// The camera. A `ValueNotifier` so a change repaints inside a
/// `RepaintBoundary` without rebuilding the widget tree.
class CameraController extends ValueNotifier<ViewportTransform> {
  CameraController(super.initial);

  void panBy(Offset screenDelta) {
    final m = value.worldToScreenMatrix;
    value = ViewportTransform(
      worldToScreenMatrix:
          Transform2(m.a, m.b, m.c, m.d, m.e + screenDelta.dx, m.f + screenDelta.dy),
    );
  }

  /// Scales about a screen point, keeping the world point under it fixed.
  void zoomAt(Offset screenFocus, double factor) {
    final m = value.worldToScreenMatrix;
    final about = Transform2.translation(screenFocus.dx, screenFocus.dy)
        .multiply(Transform2.scale(factor, factor))
        .multiply(Transform2.translation(-screenFocus.dx, -screenFocus.dy));
    value = ViewportTransform(worldToScreenMatrix: about.multiply(m));
  }
}
```

> Composition order is the trap here: `about.multiply(m)` applies the camera first and then scales in screen space. Reversing it scales in world space and the focus point drifts — which the third test is written to catch.

- [ ] **Step 4: Run, then commit**

Run: `cd packages/jet_cad_2d_flutter && flutter test`

```bash
git add -A packages/jet_cad_2d_flutter
git commit -m "feat(jet_cad_2d_flutter): add CameraController and the grid-snapped rebase origin"
```

---

## Task 5: The `DrawSink` seam

**Files:**
- Create: `packages/jet_cad_2d_flutter/lib/src/draw_sink.dart`
- Create: `packages/jet_cad_2d_flutter/lib/src/canvas_draw_sink.dart`
- Test: `packages/jet_cad_2d_flutter/test/draw_sink_test.dart`

**Interfaces:**
- Consumes: `ResolvedStyle`, `Transform2`.
- Produces:
  - `abstract class DrawSink` with `beginResidual(Transform2)`, `endResidual()`, `point(double x, double y, ResolvedStyle)`, `polyline(Float64List pts, int count, ResolvedStyle, {required bool closed})`, `circle(double cx, double cy, double r, ResolvedStyle)`, `arc(double cx, double cy, double r, double start, double sweep, ResolvedStyle)`.
  - `class RecordingDrawSink implements DrawSink { List<DrawOp> get ops; }` and `sealed class DrawOp` with `BeginResidualOp`, `EndResidualOp`, `PointOp`, `PolylineOp`, `CircleOp`, `ArcOp`, each with value equality.
  - `class NullDrawSink implements DrawSink { int opCount; }`
  - `class CanvasDrawSink implements DrawSink { CanvasDrawSink(this.canvas, {required this.pixelsPerPaperMm}); }`

- [ ] **Step 1: Write the failing test**

```dart
  test('the recording sink captures ops in order with residual-local points', () {
    final sink = RecordingDrawSink();
    const style = ResolvedStyle(
      argb: 0xFFFF0000,
      lineweightHundredths: 25,
      linetype: ReservedHandles.continuousLinetype,
      linetypeScale: 1.0,
    );
    final residual = Transform2.translation(3, 4);

    sink
      ..beginResidual(residual)
      ..polyline(Float64List.fromList([0, 0, 1, 1]), 2, style, closed: false)
      ..endResidual();

    expect(sink.ops, [
      BeginResidualOp(residual),
      PolylineOp(const [0.0, 0.0, 1.0, 1.0], style, closed: false),
      const EndResidualOp(),
    ]);
  });

  test('polyline copies the caller buffer', () {
    // The painter reuses one scratch buffer per depth, so a sink that retained
    // the caller's list would record the same (last) geometry for every entity
    // and the differential oracle would compare two identical wrong answers.
    final sink = RecordingDrawSink();
    final buffer = Float64List.fromList([0, 0, 1, 1]);
    sink.polyline(buffer, 2, _anyStyle, closed: false);
    buffer[0] = 99;
    expect((sink.ops.single as PolylineOp).points.first, 0.0);
  });
```

- [ ] **Step 2: Run and confirm failure**

Run: `cd packages/jet_cad_2d_flutter && flutter test test/draw_sink_test.dart`
Expected: FAIL — undefined.

- [ ] **Step 3: Implement the seam and the recording sink**

```dart
/// Where the painter writes.
///
/// **Every coordinate passed between [beginResidual] and [endResidual] is in
/// that residual's local space** — already rebased, never a world coordinate,
/// never rebased twice. The rule is on the interface because
/// [RecordingDrawSink] equality is the project's primary correctness
/// mechanism, and an ambiguous coordinate space lets two correct
/// implementations disagree.
abstract class DrawSink {
  void beginResidual(Transform2 residual);
  void endResidual();
  void point(double x, double y, ResolvedStyle style);
  void polyline(Float64List points, int count, ResolvedStyle style,
      {required bool closed});
  void circle(double cx, double cy, double r, ResolvedStyle style);
  void arc(double cx, double cy, double r, double start, double sweep,
      ResolvedStyle style);
}
```

`DrawOp` variants: each a `@immutable final class` with `==`/`hashCode`; `PolylineOp` holds a `List<double>` compared with `listEquals`. `RecordingDrawSink` appends one op per call and **copies** the first `count * 2` doubles out of the caller's buffer. `NullDrawSink` increments a counter per call and stores nothing.

- [ ] **Step 4: Implement `CanvasDrawSink`**

```dart
/// Writes to `dart:ui`.
///
/// Stroke width is the one place paper space meets device space:
/// `lineweightHundredths` is 1/100 mm on paper and must not grow with zoom, so
/// it is converted to pixels and then divided by the residual's representative
/// scale — because `Paint.strokeWidth` is measured in the *current* canvas
/// units, which the residual has already scaled.
class CanvasDrawSink implements DrawSink {
  CanvasDrawSink(this.canvas, {required this.pixelsPerPaperMm});

  final Canvas canvas;
  final double pixelsPerPaperMm;

  final Paint _paint = Paint()..style = PaintingStyle.stroke;
  double _residualScale = 1.0;

  @override
  void beginResidual(Transform2 residual) {
    canvas.save();
    canvas.transform(Float64List.fromList(<double>[
      residual.a, residual.b, 0, 0, //
      residual.c, residual.d, 0, 0, //
      0, 0, 1, 0, //
      residual.e, residual.f, 0, 1, //
    ]));
    _residualScale = residual.scaleMagnitude;
  }

  @override
  void endResidual() {
    canvas.restore();
    _residualScale = 1.0;
  }

  Paint _paintFor(ResolvedStyle style) {
    _paint
      ..color = Color(style.argb)
      ..strokeWidth = _strokeWidth(style);
    return _paint;
  }

  double _strokeWidth(ResolvedStyle style) {
    final devicePx = style.lineweightHundredths / 100.0 * pixelsPerPaperMm;
    final w = _residualScale == 0 ? devicePx : devicePx / _residualScale;
    // 0 means "hairline" to Skia — one device pixel regardless of transform,
    // which is the right floor for a lineweight that has scaled away.
    return w.isFinite && w > 0 ? w : 0.0;
  }
  // point/polyline/circle/arc build a Path (or drawPoints) and call
  // canvas.drawPath(path, _paintFor(style)).
}
```

- [ ] **Step 5: Run, then commit**

Run: `cd packages/jet_cad_2d_flutter && flutter test`

```bash
git add -A packages/jet_cad_2d_flutter
git commit -m "feat(jet_cad_2d_flutter): add the DrawSink seam with recording, null and canvas sinks"
```

---

## Task 6: `DraftPainter` — root leaves with `leafTransform` and rebasing

**Files:**
- Create: `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart`
- Test: `packages/jet_cad_2d_flutter/test/draft_painter_root_test.dart`

**Interfaces:**
- Consumes: `SpatialIndex.forEachInRect`, `ContainerIndex.transformOfLeaf`, `GeometryStore.peek`, `DocumentStyleResolver`, `DrawSink`, `rebaseOriginFor`.
- Produces: `class DraftPainter { DraftPainter({required this.document, required this.index, required this.resolver}); void paint(DrawSink sink, ViewportTransform camera, Size viewport); int get leafBufferCapacity; }`

- [ ] **Step 1: Write the failing test**

```dart
  test('a group-owned leaf is drawn through its folded transform', () {
    // Group nodes are flattened into the enclosing container and the leaf's
    // composed transform is kept in ContainerIndex._leafTransforms. A painter
    // that reads coordinates straight out of GeometryStore and skips
    // transformOfLeaf draws every group-owned leaf at its unplaced position —
    // and a fixture whose group transform is the identity cannot tell.
    final doc = DraftDocument.empty();
    const group = Handle(400);
    doc.commands.execute(AddNodeCommand(GroupNode(
      handle: group,
      parent: doc.rootHandle,
      transform: Transform2.translation(1000, 2000)
          .multiply(Transform2.rotation(0.7))
          .multiply(Transform2.scale(2.0, 3.0)),
      children: const [],
    )));
    addLine(doc, group, 0, 0, 1, 0);

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final painter = DraftPainter(
        document: doc, index: index, resolver: DocumentStyleResolver(doc));
    final sink = RecordingDrawSink();
    painter.paint(sink, ViewportTransform.fit(doc.extents, const Size(800, 600)),
        const Size(800, 600));

    final begin = sink.ops.whereType<BeginResidualOp>().single;
    final line = sink.ops.whereType<PolylineOp>().single;
    // Reconstruct the world position from what actually reached the sink.
    final p = begin.residual.transformPoint(Vector2(line.points[2], line.points[3]));
    final expected = ViewportTransform.fit(doc.extents, const Size(800, 600))
        .worldToScreen(Vector2(1000 + 2 * math.cos(0.7), 2000 + 2 * math.sin(0.7)));
    expect(p.x, closeTo(expected.x, 1e-6));
    expect(p.y, closeTo(expected.y, 1e-6));
  });

  test('the leaf buffer does not grow after warm-up', () {
    final doc = generateDocument(5000, definitionCount: 10);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final painter = DraftPainter(
        document: doc, index: index, resolver: DocumentStyleResolver(doc));
    final camera = ViewportTransform.fit(doc.extents, const Size(800, 600));

    painter.paint(NullDrawSink(), camera, const Size(800, 600));
    final warm = painter.leafBufferCapacity;
    for (var i = 0; i < 20; i++) {
      painter.paint(NullDrawSink(), camera, const Size(800, 600));
    }
    expect(painter.leafBufferCapacity, warm);
  });
```

- [ ] **Step 2: Run and confirm failure**

Run: `cd packages/jet_cad_2d_flutter && flutter test test/draft_painter_root_test.dart`
Expected: FAIL — `DraftPainter` undefined.

- [ ] **Step 3: Implement the root-leaf pass**

```dart
class DraftPainter {
  DraftPainter({
    required this.document,
    required this.index,
    required this.resolver,
  });

  final DraftDocument document;
  final SpatialIndex index;
  final StyleResolver resolver;

  /// Reused across frames; the frame path must not allocate once warm.
  Float64List _points = Float64List(256);
  int get leafBufferCapacity => _points.length;

  void paint(DrawSink sink, ViewportTransform camera, Size viewport) {
    final world = camera.visibleWorld(viewport);
    final origin = rebaseOriginFor(world);
    final rootIndex = index.rootIndex;

    index.forEachInRect(world, const QueryFilter.rendering(), (slot) {
      _drawLeaf(sink, camera, origin, rootIndex.transformOfLeaf(slot), slot,
          StyleContext.documentRoot);
    });
  }

  void _drawLeaf(DrawSink sink, ViewportTransform camera, Vector2 origin,
      Transform2? leafTransform, int slot, StyleContext ctx) {
    // camera ∘ leafTransform ∘ rebase, composed in Float64. The rebase
    // translation is applied on the *inside*, so the residual pushed to
    // Canvas carries only small numbers even at 4.5e6.
    final rebase = Transform2.translation(origin.x, origin.y);
    final chain = camera.worldToScreenMatrix
        .multiply(leafTransform ?? Transform2.identity())
        .multiply(rebase);
    final toLocal = (leafTransform ?? Transform2.identity()).invert();
    final localOrigin = toLocal.transformPoint(origin);

    final payload = document.geometry.peek(document.entities.geomIndexAt(slot));
    final style = resolver.styleFor(slot, ctx);
    sink.beginResidual(chain);
    _emit(sink, document.entities.kindAt(slot), payload, localOrigin, style);
    sink.endResidual();
  }
  // _emit switches on EntityKind, subtracting localOrigin from every point in
  // Float64 into _points before calling the sink. _ensurePoints(n) doubles
  // _points when needed — the one allocation, and only before warm-up.
}
```

> The rebase subtraction happens in the leaf's own space, because that is the space the stored coordinates are in. Subtracting the world-space origin from local coordinates would be a category error that a fixture with an identity `leafTransform` cannot detect — which is why the first test's group carries scale, rotation and translation at once.

- [ ] **Step 4: Count and skip text, rather than silently dropping it**

`EntityKind.text` and `EntityKind.attrib` carry no string — `EntityRecord` has no text content at all, so there is nothing to draw. Skipping is correct; skipping *silently* is not, because it makes every frame number optimistic by an unrecorded amount.

```dart
  int _skippedText = 0;
  /// Text entities not drawn in the last frame.
  ///
  /// Text has no content in the model yet (Plan 3b adds it), so it cannot be
  /// drawn — and text is the product's payload, which makes every measurement
  /// here optimistic by exactly this many entities. Recorded rather than
  /// assumed away.
  int get skippedTextCount => _skippedText;
```

In `_emit`, the `text`/`attrib` cases increment the counter and return. Add the test:

```dart
  test('text entities are counted, not silently dropped', () {
    // The corpus generates ~300 text entities per 30k. If they vanished with
    // no counter, the results note would read as a complete measurement.
    final doc = generateDocument(30000, definitionCount: 100);
    final painter = paintAll(doc);
    expect(painter.skippedTextCount, greaterThan(0));
  });
```

- [ ] **Step 5: Run and confirm the tests pass**

Run: `cd packages/jet_cad_2d_flutter && flutter test`

- [ ] **Step 6: Commit**

```bash
git add -A packages/jet_cad_2d_flutter
git commit -m "feat(jet_cad_2d_flutter): paint root leaves through leafTransform and a rebased residual"
```

---

## Task 7: Merge instances into global handle order

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart`
- Test: `packages/jet_cad_2d_flutter/test/draft_painter_order_test.dart`

**Interfaces:**
- Consumes: `SpatialIndex.forEachInstanceInRect`.
- Produces: `DraftPainter.instanceBufferCapacity`; ops now interleave leaves and instances by ascending handle.

- [ ] **Step 1: Write the failing test**

```dart
  test('leaves and instances interleave by ascending handle', () {
    // Draw order is ascending handle, globally. Running the two queries back to
    // back gives "all leaves, then all instances", which is a different order.
    // It is invisible in 3a — nothing is filled — and decides what covers what
    // as soon as 3b adds fills, by which time the painter would need rewriting.
    final doc = DraftDocument.empty();
    const def = Handle(500);
    doc.tree.addDefinition(Definition(
        handle: def, name: 'sym', basePoint: Vector2.zero(), children: const []));
    addLine(doc, def, 0, 0, 1, 0);                       // definition content

    final lowLeaf = addLineAt(doc, doc.rootHandle, Handle(600), 0, 0);
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: const Handle(601),
      parent: doc.rootHandle,
      transform: Transform2.translation(5, 5)
          .multiply(Transform2.scale(1.0, -2.0)),   // mirrored, non-uniform
      definition: def,
      layer: ReservedHandles.layerZero,
    )));
    final highLeaf = addLineAt(doc, doc.rootHandle, Handle(602), 10, 10);

    final ops = paintToRecording(doc);
    expect(handleOrderOf(ops), [lowLeaf, const Handle(601), highLeaf]);
  });
```

`handleOrderOf` is a helper in the test file that maps each top-level `BeginResidualOp` to the handle the painter recorded alongside it; add a `Handle? debugHandle` field to `BeginResidualOp` for that purpose, set by the painter and ignored by `==`.

- [ ] **Step 2: Run and confirm failure**

Expected: FAIL — order comes back `[lowLeaf, highLeaf, 601]`.

- [ ] **Step 3: Implement the merge**

```dart
  Uint32List _instances = Uint32List(64);
  int _instanceCount = 0;
  int get instanceBufferCapacity => _instances.length;

  /// This frame's culling rectangle in world space. A field, not a parameter,
  /// because `_drawInstance` is reached from inside a query visitor and
  /// threading it through would put a closure on the frame path.
  Aabb2 _worldRect = Aabb2.empty();

  void paint(DrawSink sink, ViewportTransform camera, Size viewport) {
    final world = camera.visibleWorld(viewport);
    _worldRect = world;
    final origin = rebaseOriginFor(world);

    // Step 1: drain the instance query completely. Holding its results across
    // the leaf query is only safe because they are copied out here — both rect
    // queries share SpatialIndex's scratch buffers.
    _instanceCount = 0;
    index.forEachInstanceInRect(world, const QueryFilter.rendering(), (h) {
      if (_instanceCount == _instances.length) _growInstances();
      _instances[_instanceCount++] = h.value;
    });

    // Step 2: stream the leaves, flushing lower-handled instances first.
    var next = 0;
    index.forEachInRect(world, const QueryFilter.rendering(), (slot) {
      final leafHandle = document.entities.handleAt(slot).value;
      while (next < _instanceCount && _instances[next] < leafHandle) {
        _drawInstance(sink, camera, origin, Handle(_instances[next++]));
      }
      _drawLeaf(sink, camera, origin, index.rootIndex.transformOfLeaf(slot),
          slot, StyleContext.documentRoot);
    });

    // Step 3: whatever is left sorts after every visible leaf.
    while (next < _instanceCount) {
      _drawInstance(sink, camera, origin, Handle(_instances[next++]));
    }
  }
```

> `_drawInstance` is called from **inside** `forEachInRect`'s visitor. That is legal only because it uses `ContainerIndex` queries, never a `SpatialIndex`-level one: `_beginQuery` is called by `SpatialIndex` methods alone, and calling one from here throws `QueryReentrancyError`. Task 8 implements `_drawInstance` under that constraint.

- [ ] **Step 4: Add the reentrancy regression test**

```dart
  test('painting never issues a SpatialIndex-level query from inside a visit', () {
    // The merge exists to stay on the legal side of Plan 2's non-reentrancy.
    // A future edit that reaches for forEachInstanceInRect inside the leaf
    // stream fails here rather than in a rig, where it would look like a
    // rendering bug.
    final doc = generateDocument(2000, definitionCount: 10);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    expect(
      () => DraftPainter(
              document: doc, index: index, resolver: DocumentStyleResolver(doc))
          .paint(NullDrawSink(),
              ViewportTransform.fit(doc.extents, const Size(800, 600)),
              const Size(800, 600)),
      returnsNormally,
    );
  });
```

- [ ] **Step 5: Run, then commit**

Run: `cd packages/jet_cad_2d_flutter && flutter test`

```bash
git add -A packages/jet_cad_2d_flutter
git commit -m "feat(jet_cad_2d_flutter): merge leaf and instance streams into global handle order"
```

---

## Task 8: Recurse into definitions

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart`
- Test: `packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart`

**Interfaces:**
- Consumes: `SpatialIndex.indexFor`, `ContainerIndex.searchLeaves`, `instanceHandleAt`, `instanceTransformAt`, `instanceCount`, `Transform2.invert`.
- Produces: `DraftPainter.depthBufferCapacities` → `List<int>`, one entry per recursion depth reached.

- [ ] **Step 1: Write the failing tests**

```dart
  test('a slot in both the tree and the dirty overlay is drawn once', () {
    // ContainerIndex.searchLeaves visits the packed tree and then the dirty
    // overlay, and documents that a slot in both is visited twice. SpatialIndex
    // deduplicates for its own callers; a ContainerIndex caller gets nothing
    // for free, and a doubled draw is invisible on opaque strokes and wrong the
    // moment 3b adds transparency.
    final doc = documentWithDirtiedDefinitionLeaf();
    final ops = paintToRecording(doc);
    expect(ops.whereType<PolylineOp>().length,
        ops.whereType<PolylineOp>().toSet().length);
  });

  test('definition contents are drawn in ascending handle order', () {
    final doc = documentWithThreeDefinitionLeaves(); // handles 700, 701, 702
    final ops = paintToRecording(doc);
    expect(handleOrderOf(ops).where((h) => h.value >= 700).toList(),
        [const Handle(700), const Handle(701), const Handle(702)]);
  });

  test('two levels of nesting compose ancestors in the right order', () {
    // The outer instance scales 2x and the inner translates by 10. Composed
    // outward-in the point lands at 20; inward-out it lands at 10 + 2*x. Every
    // transform in the fixture is non-identity, so the two cannot coincide.
    final doc = nestedFixture();
    final ops = paintToRecording(doc);
    expect(worldPointOf(ops.last), closeTo(20.0, 1e-9));
  });
```

- [ ] **Step 2: Run and confirm failure**

Run: `cd packages/jet_cad_2d_flutter && flutter test test/draft_painter_recursion_test.dart`

- [ ] **Step 3: Implement recursion**

```dart
  final List<_DepthScratch> _depths = <_DepthScratch>[];

  List<int> get depthBufferCapacities =>
      [for (final d in _depths) d.slots.length];

  _DepthScratch _scratchAt(int depth) {
    while (_depths.length <= depth) {
      _depths.add(_DepthScratch());
    }
    return _depths[depth];
  }

  void _drawInstance(DrawSink sink, ViewportTransform camera, Vector2 origin,
      Handle instance) {
    final node = document.tree[instance];
    if (node is! InstanceNode) return;
    _drawContainer(
      sink: sink,
      camera: camera,
      origin: origin,
      container: node.definition,
      // camera ∘ ancestors ∘ instance, still in Float64 and not yet rebased.
      accumulated: node.transform,
      ctx: resolver.contextFor(instance, StyleContext.documentRoot),
      depth: 0,
      worldRect: _worldRect,
    );
  }

  void _drawContainer({
    required DrawSink sink,
    required ViewportTransform camera,
    required Vector2 origin,
    required Handle container,
    required Transform2 accumulated,
    required StyleContext ctx,
    required int depth,
    required Aabb2 worldRect,
  }) {
    final ci = index.indexFor(container);
    if (ci == null) return;
    final scratch = _scratchAt(depth);

    // The query rectangle must be expressed in the container's own space.
    final toLocal = accumulated.invert();
    final localRect = _transformedBox(worldRect, toLocal);

    // searchLeaves is neither ordered nor deduplicated. Both are this
    // caller's job — see the tests in this task.
    scratch.reset();
    ci.searchLeaves(localRect, scratch.add);
    scratch.sortAndDedupeByHandle(document.entities);

    // Instances are walked by index: transformOfInstance(handle) is an
    // indexOf over a List<Handle>, which is linear, and calling it once per
    // visible instance per frame is quadratic.
    var next = 0;
    final placed = _placedInstances(ci, localRect, depth);
    for (var i = 0; i < scratch.length; i++) {
      final slot = scratch[i];
      final leafHandle = document.entities.handleAt(slot).value;
      while (next < placed.length && placed.handleAt(next) < leafHandle) {
        _descend(sink, camera, origin, ci, placed, next++, accumulated, ctx,
            depth, worldRect);
      }
      final leafT = ci.transformOfLeaf(slot);
      _drawLeafComposed(sink, camera, origin,
          accumulated.multiply(leafT ?? Transform2.identity()), slot, ctx);
    }
    while (next < placed.length) {
      _descend(sink, camera, origin, ci, placed, next++, accumulated, ctx,
          depth, worldRect);
    }
  }
```

`_descend` reads `ci.instanceHandleAt(i)` / `ci.instanceTransformAt(i)`, composes `accumulated.multiply(instanceTransform)`, calls `resolver.contextFor` with the current `ctx` as the inherited context, and recurses at `depth + 1`.

- [ ] **Step 4: Run and confirm the tests pass**

Run: `cd packages/jet_cad_2d_flutter && flutter test`

- [ ] **Step 5: Extend the allocation test to every depth**

```dart
  test('no depth buffer grows after warm-up', () {
    final doc = generateDocument(20000, definitionCount: 200);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final painter = DraftPainter(
        document: doc, index: index, resolver: DocumentStyleResolver(doc));
    final camera = ViewportTransform.fit(doc.extents, const Size(800, 600));
    painter.paint(NullDrawSink(), camera, const Size(800, 600));
    final warm = List<int>.from(painter.depthBufferCapacities);
    for (var i = 0; i < 20; i++) {
      painter.paint(NullDrawSink(), camera, const Size(800, 600));
    }
    expect(painter.depthBufferCapacities, warm);
  });
```

- [ ] **Step 6: Commit**

```bash
git add -A packages/jet_cad_2d_flutter
git commit -m "feat(jet_cad_2d_flutter): descend into definitions with per-depth scratch and ordered dedupe"
```

---

## Task 9: Lineweight and the anisotropy bypass

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart`, `lib/src/canvas_draw_sink.dart`
- Test: `packages/jet_cad_2d_flutter/test/lineweight_test.dart`

**Interfaces:**
- Consumes: `Transform2.scaleMagnitude`, `Transform2.anisotropyRatio`.
- Produces: `const double kAnisotropyThreshold = 2.0;` and `DraftPainter.bypassCount` (instances drawn through the exact per-axis path in the last frame).

- [ ] **Step 1: Write the failing tests**

```dart
  test('paper-space width survives a 0.1x and a 10x instance identically', () {
    // A lineweight is 1/100 mm on paper. If it is treated as a world quantity,
    // the same wall renders 100x thicker under one instance than the other.
    final thin = strokeWidthUnderUniformScale(0.1);
    final thick = strokeWidthUnderUniformScale(10.0);
    expect(thin, closeTo(thick, 1e-9));
  });

  test('an instance past the anisotropy threshold takes the bypass', () {
    // Under scale(1, 8) no single stroke width is correct. The parent spec's
    // answer is to bypass — transform the points in Float64, push a
    // translation-only residual, and use the exact width.
    final painter = paintFixture(Transform2.scale(1.0, 8.0));
    expect(painter.bypassCount, 1);
    final begin = lastBeginResidual(painter);
    expect(begin.residual.a, closeTo(1.0, 1e-12));
    expect(begin.residual.d, closeTo(1.0, 1e-12));
  });

  test('a mirrored but conformal instance does not take the bypass', () {
    // scale(-2, 2) has determinant -4 and anisotropyRatio 1: mirroring alone
    // is conformal, and sqrt(|det|) is exactly right. Bypassing it would cost
    // the cache path in 3b for nothing.
    expect(paintFixture(Transform2.scale(-2.0, 2.0)).bypassCount, 0);
  });
```

- [ ] **Step 2: Run and confirm failure**

Run: `cd packages/jet_cad_2d_flutter && flutter test test/lineweight_test.dart`

- [ ] **Step 3: Implement**

In `_drawLeafComposed`, before pushing the residual:

```dart
    // `sqrt(|det|)` is the representative scale; `anisotropyRatio` is how far
    // the transform is from conformal. Within the threshold one width is close
    // enough. Beyond it, no single width is right, so the points are
    // transformed here in Float64 and the residual carries translation only —
    // the same bypass the parent spec specifies for cached pictures, which is
    // why it is built now rather than invented twice.
    if (composed.anisotropyRatio > kAnisotropyThreshold) {
      _bypassCount++;
      _emitBypassed(sink, composed, origin, slot, style);
      return;
    }
```

`_emitBypassed` transforms each stored point by `composed`, subtracts the *screen-space* rebase (the origin already mapped through the camera), writes into `_points`, and pushes `Transform2.translation(rebasedX, rebasedY)`.

- [ ] **Step 4: Run, then commit**

Run: `cd packages/jet_cad_2d_flutter && flutter test`

```bash
git add -A packages/jet_cad_2d_flutter
git commit -m "feat(jet_cad_2d_flutter): keep lineweight in paper space with a declared anisotropy bypass"
```

---

## Task 10: The leaf-owner map, maintained incrementally

**Files:**
- Create: `packages/jet_cad_2d_flutter/lib/src/leaf_owner_map.dart`
- Test: `packages/jet_cad_2d_flutter/test/leaf_owner_map_test.dart`

**Interfaces:**
- Consumes: `DraftDocument.leavesByOwner`, `EntityStore.slotOf`, `DocChange` variants.
- Produces: `class LeafOwnerMap { LeafOwnerMap(this.document); List<int> slotsOf(Handle owner); void applyChange(DocChange change); int rebuildCount; }`

- [ ] **Step 1: Write the failing tests**

```dart
  test('a node transform costs no rebuild', () {
    // leavesByOwner() is a full live-slot scan that allocates a fresh map. R4b
    // issues one TransformNodeCommand per frame at 500k entities; rebuilding
    // here would turn that rig into a measurement of this scan.
    final doc = generateDocument(5000, definitionCount: 20);
    final map = LeafOwnerMap(doc);
    final before = map.rebuildCount;
    doc.commands.execute(
        TransformNodeCommand(firstInstanceOf(doc), Transform2.translation(1, 1)));
    map.applyChange(lastChangeOf(doc));
    expect(map.rebuildCount, before);
  });

  test('an added entity lands in its owner bucket without a full rebuild', () {
    final doc = generateDocument(1000, definitionCount: 5);
    final map = LeafOwnerMap(doc);
    final def = firstDefinitionOf(doc);
    final before = map.slotsOf(def).length;
    final rebuilds = map.rebuildCount;

    final handle = addLine(doc, def, 0, 0, 1, 1);
    map.applyChange(lastChangeOf(doc));

    expect(map.slotsOf(def), hasLength(before + 1));
    expect(map.slotsOf(def), contains(doc.entities.slotOf(handle)));
    expect(map.rebuildCount, rebuilds);
  });

  test('a purge forces a full rebuild', () {
    // DocumentPurged renumbers slots, so every slot-keyed structure is invalid
    // and there is no incremental path back — the same answer SpatialIndex
    // gives.
    final doc = generateDocument(1000, definitionCount: 5);
    final map = LeafOwnerMap(doc);
    final rebuilds = map.rebuildCount;
    map.applyChange(const DocumentPurged());
    expect(map.rebuildCount, rebuilds + 1);
  });

  test('buckets stay ascending by slot after an incremental add', () {
    final doc = generateDocument(1000, definitionCount: 5);
    final map = LeafOwnerMap(doc);
    final def = firstDefinitionOf(doc);
    addLine(doc, def, 0, 0, 1, 1);
    map.applyChange(lastChangeOf(doc));
    final slots = map.slotsOf(def);
    expect(slots, orderedEquals(List<int>.from(slots)..sort()));
  });
```

- [ ] **Step 2: Run and confirm failure**

Run: `cd packages/jet_cad_2d_flutter && flutter test test/leaf_owner_map_test.dart`

- [ ] **Step 3: Implement**

```dart
/// Definition (or root) → its leaf slots, ascending.
///
/// **Re-derive and compare, not a typed change kind.** `DocChange` carries only
/// a label and a `touched` set — `SetComponentCommand` touches an entity handle
/// exactly as a geometry edit does — so this cannot be told what changed. It
/// looks each touched handle up and re-derives that one slot's bucket, which is
/// the same doctrine `SpatialIndex._onChange` follows and for the same reason.
class LeafOwnerMap {
  LeafOwnerMap(this.document) {
    rebuild();
  }

  final DraftDocument document;
  final Map<Handle, List<int>> _byOwner = <Handle, List<int>>{};
  final Map<int, Handle> _ownerOfSlot = <int, Handle>{};
  int rebuildCount = 0;

  List<int> slotsOf(Handle owner) => _byOwner[owner] ?? const <int>[];

  void rebuild() {
    rebuildCount++;
    _byOwner
      ..clear()
      ..addAll(document.leavesByOwner());
    _ownerOfSlot.clear();
    for (final entry in _byOwner.entries) {
      for (final slot in entry.value) {
        _ownerOfSlot[slot] = entry.key;
      }
    }
  }

  void applyChange(DocChange change) {
    switch (change) {
      case DocumentLoaded():
      case DocumentPurged():
        rebuild();
      case CommandApplied(:final touched):
      case CommandUndone(:final touched):
      case CommandRedone(:final touched):
        if (touched.isEmpty) {
          rebuild();
          return;
        }
        for (final handle in touched) {
          _reconcile(handle);
        }
    }
  }

  void _reconcile(Handle handle) {
    final slot = document.entities.slotOf(handle);
    if (slot == null) {
      // Either a node — which changes no leaf's owner and costs nothing — or a
      // removed entity, whose slot is found through the reverse map.
      if (document.tree[handle] != null ||
          document.tree.definition(handle) != null) {
        return;
      }
      _forgetRemoved(handle);
      return;
    }
    final owner = document.entities.ownerAt(slot);
    final previous = _ownerOfSlot[slot];
    if (previous == owner) return;
    if (previous != null) _byOwner[previous]?.remove(slot);
    final bucket = _byOwner[owner] ??= <int>[];
    // Buckets stay ascending: callers sort by handle, but an unsorted bucket
    // would make the painter's own dedupe pass order-dependent.
    final at = _lowerBound(bucket, slot);
    bucket.insert(at, slot);
    _ownerOfSlot[slot] = owner;
  }
}
```

`_forgetRemoved` scans `_ownerOfSlot` for slots no longer live and drops them; it is the conservative branch and is expected to be rare.

- [ ] **Step 4: Wire it into `DraftPainter`**

`DraftPainter` takes a `LeafOwnerMap` and uses `slotsOf(definition)` where Task 8 called `ContainerIndex.searchLeaves` on a definition whose contents are small enough that culling costs more than drawing — decided by `ci.leafCount <= kCullFloor` with `kCullFloor = 32`, recorded as a constant with a comment explaining it is a measured guess to be revisited from R1's numbers.

- [ ] **Step 5: Run and commit**

Run: `cd packages/jet_cad_2d_flutter && flutter test`

```bash
git add -A packages/jet_cad_2d_flutter
git commit -m "feat(jet_cad_2d_flutter): maintain the leaf-owner map by re-deriving touched handles"
```

---

## Task 11: The differential oracle

**Files:**
- Create: `packages/jet_cad_2d_flutter/lib/src/reference_walk.dart`
- Create: `packages/jet_cad_2d_flutter/test/support/fixtures.dart`
- Test: `packages/jet_cad_2d_flutter/test/differential_test.dart`

**Interfaces:**
- Consumes: `DocumentTree`, `DraftDocument.leavesByOwner`, `DrawSink`, `entityBounds`.
- Produces: `void referenceWalk(DraftDocument doc, DrawSink sink, ViewportTransform camera, Size viewport, StyleResolver resolver)`; `void expectPainterSupersetOfReference(List<DrawOp> painter, List<DrawOp> reference, Aabb2 viewWorld)`.

- [ ] **Step 1: Build the fixture, with the rule enforced**

```dart
/// The corpus every differential test runs on.
///
/// **No identity transform anywhere.** Plan 2's post-mortem records a
/// composition-order defect that four separate fixtures failed to catch because
/// their transforms were the identity, which commutes and hides ordering. Every
/// instance here carries a distinct non-uniform scale, a rotation and a
/// translation; one is mirrored; one is nested two levels deep; one leaf is
/// owned by a group node so `transformOfLeaf` is exercised.
DraftDocument differentialFixture({double originX = 0}) { /* ... */ }

/// A guard so the rule cannot rot.
void assertNoIdentityTransforms(DraftDocument doc) {
  for (final node in doc.tree.nodes) {
    if (node.handle == doc.rootHandle) continue; // the root is the identity
    expect(node.transform.isIdentity, isFalse,
        reason: 'fixture rule: an identity transform hides ordering defects');
  }
}

/// The one spelling every test in this package uses, so a signature change
/// lands in one place.
List<DrawOp> paintToRecording(DraftDocument doc, [ViewportTransform? camera]) {
  final index = SpatialIndex(doc);
  final view = camera ?? ViewportTransform.fit(doc.extents, const Size(800, 600));
  final sink = RecordingDrawSink();
  DraftPainter(document: doc, index: index, resolver: DocumentStyleResolver(doc))
      .paint(sink, view, const Size(800, 600));
  index.dispose();
  return sink.ops;
}
```

- [ ] **Step 2: Write the failing differential test**

```dart
  test('the painter draws a superset of the reference walk, in order', () {
    // The reference traverses the tree directly with no index and no culling,
    // accumulating transforms by a different route than the painter. One
    // comparison therefore covers wrong culling, wrong merge order and wrong
    // transform composition at once.
    //
    // Superset, not equality: the painter culls against index boxes carrying
    // narrow-phase slack, in container space; the reference culls against
    // entity bounds in root space. Demanding equality would fail on every
    // rotated instance whose box is looser than its geometry.
    final doc = differentialFixture();
    assertNoIdentityTransforms(doc);
    final camera = ViewportTransform.fit(doc.extents, const Size(800, 600));

    final painted = paintToRecording(doc, camera);
    final reference = RecordingDrawSink();
    referenceWalk(doc, reference, camera, const Size(800, 600),
        DocumentStyleResolver(doc));

    expectPainterSupersetOfReference(
        painted, reference.ops, camera.visibleWorld(const Size(800, 600)));
  });

  test('the same holds at 4.5e6 with the view over one nested instance', () {
    final doc = differentialFixture(originX: 4.5e6);
    final camera = cameraOverNestedInstance(doc);
    final painted = paintToRecording(doc, camera);
    final reference = RecordingDrawSink();
    referenceWalk(doc, reference, camera, const Size(800, 600),
        DocumentStyleResolver(doc));
    expectPainterSupersetOfReference(
        painted, reference.ops, camera.visibleWorld(const Size(800, 600)));
  });
```

- [ ] **Step 3: Run and confirm failure**

Run: `cd packages/jet_cad_2d_flutter && flutter test test/differential_test.dart`

- [ ] **Step 4: Implement the reference and the comparison**

`referenceWalk` recurses `doc.tree` from the root, composing transforms with `Transform2.multiply`, reading leaves through `doc.leavesByOwner()`, resolving style with the same resolver, and emitting ops for every entity whose world-space `entityBounds` intersects the view rectangle. It uses no `SpatialIndex` at all — that is what makes it independent.

`expectPainterSupersetOfReference` asserts, in this order:

1. every reference op appears in the painter's list, matched on op kind, style and geometry to within `Tolerance.defaultTolerance`;
2. matched ops appear in the same relative order;
3. every unmatched painter op lies outside the view rectangle once its residual is applied — conservative culling, never a wrong drawing.

- [ ] **Step 5: Run, then commit**

Run: `cd packages/jet_cad_2d_flutter && flutter test`

```bash
git add -A packages/jet_cad_2d_flutter
git commit -m "test(jet_cad_2d_flutter): compare the painter against an index-free reference walk"
```

---

## Task 12: Large-coordinate assertions

**Files:**
- Test: `packages/jet_cad_2d_flutter/test/large_coordinate_test.dart`
- Modify: `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart` (add `bool debugDisableRebasing`)

**Interfaces:**
- Consumes: the fixture from Task 11.
- Produces: nothing new in the public API; `debugDisableRebasing` is documented as test-only.

- [ ] **Step 1: Write the failing tests**

```dart
  test('every residual reaching Canvas is small at 4.5e6', () {
    // float32 has a 24-bit mantissa: at 4.5e6 the representable spacing is
    // about 0.5 units. The whole chain composes in Float64 and only the
    // residual crosses over, so its translation must stay far below that.
    final doc = differentialFixture(originX: 4.5e6);
    final ops = paintToRecording(doc).whereType<BeginResidualOp>();
    expect(ops, isNotEmpty);
    for (final op in ops) {
      expect(op.residual.e.abs(), lessThan(1 << 20));
      expect(op.residual.f.abs(), lessThan(1 << 20));
    }
  });

  test('recorded points reproduce world coordinates through the residual', () {
    final doc = differentialFixture(originX: 4.5e6);
    final camera = ViewportTransform.fit(doc.extents, const Size(800, 600));
    for (final (op, expectedWorld) in recordedPointsWithExpectedWorld(doc, camera)) {
      final screen = op.residual.transformPoint(op.localPoint);
      final world = camera.screenToWorld(screen);
      expect(world.x, closeTo(expectedWorld.x, 1e-3));
      expect(world.y, closeTo(expectedWorld.y, 1e-3));
    }
  });

  test('with rebasing disabled, float32 rounding is observable', () {
    // Documents what the failure looks like, so the assertions above are
    // measured against something real rather than against an argument. If this
    // ever stops failing, the two above stopped proving anything.
    final doc = differentialFixture(originX: 4.5e6);
    final rounded = paintToRecordingAsFloat32(doc, disableRebasing: true);
    final exact = paintToRecordingAsFloat32(doc, disableRebasing: false);
    expect(maxPointErrorOf(rounded), greaterThan(0.05));
    expect(maxPointErrorOf(exact), lessThan(1e-3));
  });
```

- [ ] **Step 2: Run, implement `debugDisableRebasing`, run again**

Run: `cd packages/jet_cad_2d_flutter && flutter test test/large_coordinate_test.dart`
Expected: FAIL, then PASS once the flag exists and the painter honours it by passing `Vector2.zero()` as the origin.

- [ ] **Step 3: Commit**

```bash
git add -A packages/jet_cad_2d_flutter
git commit -m "test(jet_cad_2d_flutter): pin residual magnitudes and float32 jitter at 4.5e6"
```

---

## Task 12b: Mutation testing on the arithmetic and the ordering

The spec names four surfaces where a defect would be invisible to a passing suite: the camera and rebasing arithmetic, the merge ordering, the per-container sort and deduplication, and style resolution. Plan 2's evidence is that these are found by mutation, not by reading.

**Files:**
- Create: `docs/superpowers/notes/plan-3a-mutation-log.md`
- Modify: whichever test files fail to catch a mutant

**Interfaces:**
- Consumes: every test written so far.
- Produces: a log of mutants, each either caught or accompanied by the new test that catches it.

- [ ] **Step 1: Apply each mutant by hand, one at a time, and run the suite**

| # | Mutant | Must be caught by |
|---|---|---|
| 1 | `camera ∘ leafTransform ∘ rebase` → `camera ∘ rebase ∘ leafTransform` | the group-owned-leaf test (Task 6) |
| 2 | `about.multiply(m)` → `m.multiply(about)` in `zoomAt` | the focus-fixed test (Task 4) |
| 3 | `_instances[next] < leafHandle` → `<=` | the interleaving test (Task 7) |
| 4 | drop `scratch.sortAndDedupeByHandle` | the ordering and dedupe tests (Task 8) |
| 5 | `accumulated.multiply(instanceTransform)` → the reverse | the two-level nesting test (Task 8) |
| 6 | `rebaseOriginFor` returns the view centre unsnapped | the stability test (Task 4) |
| 7 | `ByBlock` resolves to the layer instead of the context | the ByBlock test (Task 2) |
| 8 | layer-0 resolves to `layerZero` instead of `ctx.layer` | the nesting test (Task 2) |
| 9 | `anisotropyRatio` threshold comparison flipped | the bypass tests (Task 9) |
| 10 | `_strokeWidth` skips the `/ _residualScale` division | the 0.1×/10× test (Task 9) |

- [ ] **Step 2: For every mutant that survives, write the test that kills it**

A surviving mutant is a fixture that cannot tell right from wrong — the exact defect class Plan 2's post-mortem named. Fix the fixture, not the assertion: the usual cause is a transform that commutes.

- [ ] **Step 3: Record the log**

One row per mutant: caught by which test, or killed by which new test. This is the evidence the suite is load-bearing.

- [ ] **Step 4: Commit**

```bash
git add -A packages/jet_cad_2d_flutter docs/superpowers/notes/plan-3a-mutation-log.md
git commit -m "test(jet_cad_2d_flutter): close the gaps mutation testing found"
```

---

## Task 12c: The two goldens

Only two things in this plan cannot be shown correct by the operation record: whether a stroke *looks* the right width, and whether the anisotropy bypass produces the right shape. Everything else is asserted structurally, which is why this task is two goldens and not a suite of them.

**Files:**
- Create: `packages/jet_cad_2d_flutter/test/golden/stroke_width_golden_test.dart`
- Create: `packages/jet_cad_2d_flutter/test/golden/*.png` (generated)

- [ ] **Step 1: Write the goldens, tagged for macOS**

```dart
@Tags(['golden'])
library;

// Font- and platform-dependent rendering makes goldens fragile, so this file
// holds the two cases the operation record genuinely cannot cover. Everything
// else is asserted on RecordingDrawSink.

void main() {
  testWidgets('paper-space stroke width at three zoom levels', (tester) async {
    await tester.pumpWidget(canvasOver(strokeWidthFixture(), zoom: 0.5));
    await expectLater(find.byType(DraftCanvas),
        matchesGoldenFile('stroke_width_0_5x.png'));
    // …repeated at 1.0x and 8.0x: the three must show the SAME on-screen
    // thickness, which is what "paper space" means.
  });

  testWidgets('an anisotropic instance draws exact per-axis widths',
      (tester) async {
    await tester.pumpWidget(canvasOver(anisotropicFixture(scaleY: 8.0)));
    await expectLater(find.byType(DraftCanvas),
        matchesGoldenFile('anisotropy_bypass.png'));
  });
}
```

- [ ] **Step 2: Generate, inspect by eye, commit**

Run: `cd packages/jet_cad_2d_flutter && flutter test --tags golden --update-goldens`
Then **open the three stroke-width PNGs and confirm the lines are the same thickness.** A golden accepted without looking at it records whatever the code did, including the bug.

```bash
git add -A packages/jet_cad_2d_flutter/test/golden
git commit -m "test(jet_cad_2d_flutter): pin stroke width and the anisotropy bypass with goldens"
```

---

## Task 13: `DraftCanvas` and the damage model

**Files:**
- Create: `packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart`
- Test: `packages/jet_cad_2d_flutter/test/draft_canvas_test.dart`

**Interfaces:**
- Consumes: `CameraController`, `DraftPainter`, `DraftDocument.changes`.
- Produces: `class DraftCanvas extends StatefulWidget { DraftCanvas({required this.document, required this.index, required this.camera}); }` and `class DocChangeNotifier extends ChangeNotifier`.

- [ ] **Step 1: Write the failing tests**

```dart
  testWidgets('repaints on a camera change without rebuilding', (tester) async {
    var builds = 0;
    await tester.pumpWidget(wrap(Builder(builder: (_) {
      builds++;
      return DraftCanvas(document: doc, index: index, camera: camera);
    })));
    final buildsAfterFirst = builds;
    camera.panBy(const Offset(10, 0));
    await tester.pump();
    expect(builds, buildsAfterFirst,
        reason: 'a ValueNotifier passed as CustomPainter.repaint repaints '
            'inside the RepaintBoundary; rebuilding would defeat it');
  });

  testWidgets('does not claim commands.onAfterMutate', (tester) async {
    // That field is a single slot and SpatialIndex takes it in its constructor.
    // A painter that assigns it silently disables the index's invalidation, and
    // every query from then on answers from a stale tree.
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final before = doc.commands.onAfterMutate;
    await tester.pumpWidget(wrap(
        DraftCanvas(document: doc, index: index, camera: camera)));
    expect(identical(doc.commands.onAfterMutate, before), isTrue);
  });

  testWidgets('repaints after a document change', (tester) async {
    await tester.pumpWidget(wrap(
        DraftCanvas(document: doc, index: index, camera: camera)));
    final before = paintCountOf(tester);
    doc.commands.execute(AddEntityCommand(record: someLine, payload: somePayload));
    await tester.pump();          // let the async broadcast deliver
    await tester.pump();
    expect(paintCountOf(tester), greaterThan(before));
  });
```

- [ ] **Step 2: Run and confirm failure**

Run: `cd packages/jet_cad_2d_flutter && flutter test test/draft_canvas_test.dart`

- [ ] **Step 3: Implement**

```dart
/// Bridges the document's async change stream to a `Listenable`.
///
/// Async is correct here and would be wrong for the index. `SpatialIndex` owns
/// the synchronous `commands.onAfterMutate` hook because a query issued in the
/// same turn as an edit must see the edit. A repaint happens on a later frame
/// by construction, so a microtask's delay changes nothing — and taking that
/// single-slot hook would disable the index.
class DocChangeNotifier extends ChangeNotifier {
  DocChangeNotifier(this.document, {this.onChange}) {
    _sub = document.changes.listen((change) {
      onChange?.call(change);
      notifyListeners();
    });
  }

  final DraftDocument document;
  final void Function(DocChange change)? onChange;
  late final StreamSubscription<DocChange> _sub;

  @override
  void dispose() {
    unawaited(_sub.cancel());
    super.dispose();
  }
}
```

`DraftCanvas`'s `State` builds a `RepaintBoundary` around a `CustomPaint` whose painter is a `_DraftCustomPainter` constructed with
`repaint: Listenable.merge([widget.camera, _docChanges])`, holds one `DraftPainter` and one `LeafOwnerMap` for its lifetime, and forwards each `DocChange` to the map through `DocChangeNotifier.onChange`. `shouldRepaint` returns `false` — the `repaint` listenable is the only trigger, which is what "repaint on events, never per vsync" means in Flutter's vocabulary.

- [ ] **Step 4: Run and commit**

Run: `cd packages/jet_cad_2d_flutter && flutter test && flutter analyze`

```bash
git add -A packages/jet_cad_2d_flutter
git commit -m "feat(jet_cad_2d_flutter): add DraftCanvas with event-driven damage"
```

---

## Task 14: Corpus extensions, all off by default

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/testing/generate_document.dart`
- Test: `packages/jet_cad_2d/test/testing/generate_document_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: `generateDocument(..., {int nestingDepth = 0, double mirroredFraction = 0, double nonUniformFraction = 0, int groupCount = 0, int layerCount = 1, double byBlockFraction = 0, double dashedFraction = 0})`.

- [ ] **Step 1: Write the failing tests**

```dart
  test('defaults reproduce the Plan 2 corpus exactly', () {
    // Plan 2's recorded numbers must stay reproducible from this file. Any
    // extension that changes the default document silently invalidates the
    // gate results note.
    final doc = generateDocument(2000, definitionCount: 20);
    expect(doc.tables.layers.all, hasLength(1));
    for (final slot in doc.entities.liveSlots) {
      expect(doc.entities.colorAt(slot), kByLayer);
      expect(doc.entities.layerAt(slot), ReservedHandles.layerZero);
    }
    for (final node in doc.tree.nodes.where((n) => n.handle != doc.rootHandle)) {
      expect(node, isA<InstanceNode>());
      expect(node.parent, doc.rootHandle);
    }
  });

  test('nestingDepth places instances inside definitions', () {
    final doc = generateDocument(5000, definitionCount: 20, nestingDepth: 2);
    expect(
        doc.tree.nodes.where((n) =>
            n.handle != doc.rootHandle && n.parent != doc.rootHandle),
        isNotEmpty);
  });

  test('mirroredFraction produces negative-determinant instances', () {
    final doc = generateDocument(5000, definitionCount: 20, mirroredFraction: 0.25);
    final placed =
        doc.tree.nodes.where((n) => n.handle != doc.rootHandle).toList();
    final mirrored = placed.where((n) => n.transform.determinant < 0);
    expect(mirrored.length / placed.length, closeTo(0.25, 0.05));
  });

  test('byBlockFraction and layerCount create more than one resolution path', () {
    // Without this the memo-versus-unmemoised delta measures a single path and
    // means nothing.
    final doc = generateDocument(5000, definitionCount: 20,
        layerCount: 8, byBlockFraction: 0.3);
    final encodings = {
      for (final slot in doc.entities.liveSlots) doc.entities.colorAt(slot)
    };
    expect(encodings.length, greaterThan(1));
    expect(doc.tables.layers.all, hasLength(8));
  });

  test('dashedFraction is reported and non-zero when asked for', () {
    final doc = generateDocument(5000, definitionCount: 20, dashedFraction: 0.4);
    final dashed = doc.entities.liveSlots.where((s) =>
        doc.entities.linetypeAt(s) != ReservedHandles.byLayerLinetype);
    expect(dashed.length / doc.entities.liveSlots.length, closeTo(0.4, 0.05));
  });
```

- [ ] **Step 2: Run, implement, run**

Every new parameter defaults to the value that reproduces today's document. Run `dart test` and then, critically:

Run: `cd packages/jet_cad_2d && dart run benchmark/query_throughput.dart`
Expected: numbers within ±15% of the gate note's recorded values. **A shift beyond that means a default leaked.**

- [ ] **Step 3: Commit**

```bash
git add -A packages/jet_cad_2d
git commit -m "feat(jet_cad_2d): add off-by-default corpus extensions for nesting, mirroring, layers and dashes"
```

---

## Task 15: Rigs R1 and R3

**Files:**
- Create: `packages/jet_cad_2d_flutter/test/rig/paint_microbench_test.dart`
- Create: `packages/jet_cad_2d_flutter/dart_test.yaml`
- Create: `packages/jet_cad_2d_flutter/README.md`

**Interfaces:**
- Consumes: `DraftPainter`, `NullDrawSink`, `CanvasDrawSink`, `generateDocument`.
- Produces: a rig printing p50/p95 for paint and query-only, tagged `rig` and excluded from the default suite.

- [ ] **Step 1: Exclude rigs from the default suite**

`dart_test.yaml`:

```yaml
tags:
  rig:
    # Rigs measure; they do not assert. Running them in the normal suite would
    # make it slow and make its result depend on machine load.
    skip: "run explicitly: flutter test --tags rig"
```

- [ ] **Step 2: Write the rig**

```dart
@Tags(['rig'])
library;

// R1 — paint microbench, and R3 — query-only.
//
// R1 runs under `flutter test`: debug JIT, and PictureRecorder records without
// rasterising. It is a RELATIVE regression signal only. It is not comparable to
// R2's profile-mode numbers and cannot see raster cost. Do not mix the two in
// the results note.

void main() {
  for (final entityCount in [50000, 500000]) {
    test('paint and query at $entityCount', () {
      final doc = generateDocument(entityCount,
          definitionCount: entityCount ~/ 25,
          nestingDepth: 2,
          mirroredFraction: 0.1,
          nonUniformFraction: 0.2,
          groupCount: 50,
          layerCount: 8,
          byBlockFraction: 0.3,
          dashedFraction: 0.35);
      final index = SpatialIndex(doc);
      final painter = DraftPainter(
          document: doc, index: index, resolver: DocumentStyleResolver(doc));
      final camera = ViewportTransform.fit(doc.extents, const Size(1600, 1200));

      final paintUs = _measure(() {
        final recorder = PictureRecorder();
        painter.paint(
            CanvasDrawSink(Canvas(recorder), pixelsPerPaperMm: 3.78),
            camera, const Size(1600, 1200));
        recorder.endRecording().dispose();
      });
      final queryUs = _measure(() =>
          painter.paint(NullDrawSink(), camera, const Size(1600, 1200)));

      print('R1 $entityCount paint  p50=${paintUs.p50} p95=${paintUs.p95}');
      print('R3 $entityCount query  p50=${queryUs.p50} p95=${queryUs.p95}');
      print('    bypassed instances: ${painter.bypassCount}');
      print('    skipped text entities: ${painter.skippedTextCount}');
      index.dispose();
    });
  }
}
```

`_measure` runs 20 warm-up iterations then 120 measured ones, collecting microseconds into a sorted list and returning p50/p95 — the same shape as `benchmark/query_throughput.dart`, so the two are read the same way.

- [ ] **Step 3: Run both rigs**

Run: `cd packages/jet_cad_2d_flutter && flutter test --tags rig`
Expected: prints eight lines. Record them; they are the first entries in the results note.

- [ ] **Step 3a: Measure the style memo, in that order**

`DocumentStyleResolver` is unmemoised on purpose: the unmemoised cost is measured first so the memo's value is a number rather than an assumption, and so the invalidation debt `FilterEvaluator` already carries is not duplicated before anything needs it.

Add `MemoisedStyleResolver`, wrapping `DocumentStyleResolver` with a `Map<(int slot, StyleContext ctx), ResolvedStyle>`, and re-run the rig with both:

```dart
    final plainUs = _measure(() => painter.paint(NullDrawSink(), camera, size));
    final memoPainter = DraftPainter(
        document: doc,
        index: index,
        resolver: MemoisedStyleResolver(DocumentStyleResolver(doc)));
    final memoUs = _measure(() => memoPainter.paint(NullDrawSink(), camera, size));
    print('style memo delta: p50 ${plainUs.p50} -> ${memoUs.p50}');
```

The corpus must run with `layerCount: 8, byBlockFraction: 0.3` for this to mean anything — with one layer and one colour there is a single resolution path and any memo looks free.

**`MemoisedStyleResolver` carries a documented hazard:** its cache is valid only while no layer record and no instance colour changes. Nothing in today's command set can change either, exactly as `FilterEvaluator` documents for its own caches. It is a rig instrument in 3a, and 3b either gives it an invalidation hook or does not ship it.

- [ ] **Step 4: Document and commit**

`README.md` lists all five rig commands verbatim.

```bash
git add -A packages/jet_cad_2d_flutter
git commit -m "test(jet_cad_2d_flutter): add the paint and query-only rigs"
```

---

## Task 16: Harness app, R2, R4a and R4b

**Files:**
- Create: `apps/dev_harness_2d/` (Flutter app: `pubspec.yaml`, `lib/main.dart`)
- Create: `apps/dev_harness_2d/integration_test/frame_timing_test.dart`
- Modify: root `pubspec.yaml` (add the app to `workspace:`)

**Interfaces:**
- Consumes: `DraftCanvas`, `CameraController`, `generateDocument`.
- Produces: three measurement runs printing p50/p95 build and raster times.

- [ ] **Step 1: Create the app**

`lib/main.dart` builds a `DraftCanvas` over a document chosen by `--dart-define=ENTITIES=50000`, with pointer pan and scroll zoom wired directly to `CameraController` — twenty lines, no tool architecture, because tools are Plan 4.

- [ ] **Step 2: Write the scripted timeline**

```dart
// R2 — frame timing under a scripted camera. R4a — a leaf edit per frame.
// R4b — an instance drag per frame.
//
// Profile mode only:
//   flutter test integration_test/frame_timing_test.dart --profile -d macos
//
// Debug numbers are meaningless here; the harness refuses to record them.

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('R2 pan and zoom', (tester) async {
    assert(() {
      throw StateError('run with --profile; debug frame times mean nothing');
    }());
    final timings = <FrameTiming>[];
    binding.addTimingsCallback(timings.addAll);
    await tester.pumpWidget(harnessApp(entityCount: 50000));

    // 120 frames of pan, then 120 of zoom across three scale bands, so band
    // crossings are inside the measurement rather than either side of it.
    for (var i = 0; i < 120; i++) {
      camera.panBy(const Offset(-7, -3));
      await tester.pump(const Duration(milliseconds: 16));
    }
    for (var i = 0; i < 120; i++) {
      camera.zoomAt(const Offset(800, 600), i.isEven ? 1.03 : 0.97);
      await tester.pump(const Duration(milliseconds: 16));
    }
    _report('R2', timings);
  });

  testWidgets('R4a leaf edit per frame', (tester) async {
    // A drag is remove-then-add today: there is no in-place geometry command.
    // Each step burns a handle and leaves a dead slot, which is itself recorded.
    final handlesBefore = doc.handleSeed.current.value;
    for (var step = 1; step <= 200; step++) {
      doc.commands.execute(RemoveEntityCommand(dragged));
      dragged = addLineAt(doc, owner, x + step * 2.0, y + step * 1.0);
      camera.panBy(const Offset(-3, -1));
      await tester.pump(const Duration(milliseconds: 16));
    }
    _report('R4a', timings);
    print('R4a overlay length: ${index.rootIndex.dirty.length} '
        'threshold: ${index.rootIndex.rebuildThreshold} '
        'rebuilds: ${index.rebuildCount} '
        'handles burned: ${doc.handleSeed.current.value - handlesBefore}');
  });

  testWidgets('R4b instance drag per frame', (tester) async {
    // TransformNodeCommand touches a node handle, which SpatialIndex._reconcile
    // classifies as structural and answers with rebuildAll(). This rig measures
    // that: the cost of the application's defining gesture, once per frame.
    final before = index.rebuildCount;
    for (var step = 1; step <= 200; step++) {
      doc.commands.execute(TransformNodeCommand(
          instance,
          Transform2.translation(step * 2.0, step * 1.0)
              .multiply(Transform2.scale(1.0, -1.5))));
      await tester.pump(const Duration(milliseconds: 16));
    }
    _report('R4b', timings);
    print('R4b rebuilds: ${index.rebuildCount - before} over 200 frames');
  });
}
```

`_report` prints p50/p95/max of `buildDuration` and `rasterDuration` separately, because a build-bound and a raster-bound frame call for opposite fixes in 3b.

- [ ] **Step 3: Run all three at 50k and 500k**

Run: `cd apps/dev_harness_2d && flutter test integration_test/frame_timing_test.dart --profile -d macos`
Record every line.

- [ ] **Step 4: Commit**

```bash
git add -A apps/dev_harness_2d pubspec.yaml
git commit -m "test(dev_harness_2d): add the frame-timing and edit-simulation rigs"
```

---

## Task 17: Web smoke and the results note

**Files:**
- Create: `docs/superpowers/notes/<completion-date>-plan-3a-results.md`

**Interfaces:**
- Consumes: every rig's output.
- Produces: the note Plan 3b is designed from.

- [ ] **Step 1: Run the web smoke**

Run: `cd packages/jet_cad_2d_flutter && flutter test --tags rig --platform chrome`
and the harness app in a release web build. Record both. Informational only — nothing here fails the plan.

- [ ] **Step 2: Write the note**

It must contain, each as a table row with the command that produced it:

1. R1 paint p50/p95 at 50k and 500k, labelled debug-JIT relative.
2. R3 query-only p50/p95 at the same sizes, and the paint-minus-query difference.
3. R2 build and raster p50/p95/max at both sizes, macOS profile.
4. R4a: overlay length reached, rebuild threshold, rebuild count, per-frame cost, handles and slots burned over 200 frames.
5. R4b: rebuilds per frame and the cost of one 500k `rebuildAll()`.
6. The anisotropy bypass fraction and the threshold chosen.
7. The skipped-text count, and the non-continuous-linetype fraction — the two declared optimisms, quantified.
8. Web smoke figures.
9. Style memo delta: resolution cost with and without memoisation.

- [ ] **Step 3: Choose the dirty-overlay option**

State A, B, C or D with the numbers that decide it: the cost of one 500k repack against the overlay scan's share of frame time, and how often R4a crossed the threshold. If the data is genuinely ambiguous, name the one additional measurement that resolves it — a named next step, not a deferral.

- [ ] **Step 4: State what R4b means for Plan 4**

If a per-frame `rebuildAll()` at 500k is unaffordable, say so plainly and record it as a constraint Plan 4 inherits, alongside the missing in-place geometry command.

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/notes/
git commit -m "docs: record Plan 3a's measurements and the dirty-overlay decision"
```

---

## Task 18: Exit gate

- [ ] **Step 1: Run everything**

```bash
cd packages/jet_cad_2d && dart test && dart analyze && dart format --set-exit-if-changed .
cd ../jet_cad_2d_flutter && flutter test && flutter test --tags golden && flutter analyze && dart format --set-exit-if-changed .
cd ../jet_cad_2d && dart run benchmark/query_throughput.dart
```

- [ ] **Step 2: Confirm the two failable criteria**

| Criterion | Where proven |
|---|---|
| The differential oracle's four assertions hold on the large-coordinate, nested, mirrored, group-owning corpus | `test/differential_test.dart`, `test/large_coordinate_test.dart` |
| Per-depth painter buffers do not grow after warm-up | `test/draft_painter_recursion_test.dart` |

Also confirm: every mutant in Task 12b's table is accounted for in the log, and the three stroke-width goldens were looked at by a human rather than accepted blind.

Frame timings are baselines, not thresholds. The 16.6 ms gate belongs to Plan 3b.

- [ ] **Step 3: Confirm the results note is complete**

Every row in Task 17 filled with a real number, and the overlay option chosen with its justification.

- [ ] **Step 4: Merge**

Use `superpowers:finishing-a-development-branch`.
