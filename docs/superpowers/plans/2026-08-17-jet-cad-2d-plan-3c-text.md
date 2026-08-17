# jet_cad_2d Plan 3c — Text Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Store, measure, hit-test and draw single-line text so the product's payload — table numbers and room labels — renders, and measure what it costs.

**Architecture:** Two ordered phases. Phase A puts text in the engine: two string columns, a style handle, a packed attribute word, the four scalars, the codec, one resolution point for geometry, and `HitKind.fill` picking. Phase B draws it: a Flutter measurer, a paragraph cache keyed by `(string, style, colour)`, one new sink op, and the measurement. Layout happens once at a nominal size and every attribute becomes a transform, so the cache key carries no height, angle or width factor.

**Tech Stack:** Dart 3.12, `package:test`, `flutter_test`, `dart:ui` (`ParagraphBuilder`, `Paragraph`, `Canvas.drawParagraph`), `vector_math`.

**Spec:** [docs/superpowers/specs/2026-08-17-jet-cad-2d-plan-3c-design.md](../specs/2026-08-17-jet-cad-2d-plan-3c-design.md) (approved at `169a85f`, revised through three review passes)

## Global Constraints

- **Draw order is ascending handle value**, stable across undo, save, load and purge.
- **The frame path allocates nothing in steady state.** `test/invariants/query_allocation_test.dart` measures it. A `measure()` call that allocates on a cache hit breaks it.
- **Geometric *decisions* use `Tolerance`; *stored value* comparisons are exact `==`.**
- **Leaf containment is `EntityRecord.owner`, and only that.**
- **`kNominalTextPixels = 100.0`** — every paragraph is laid out at this em size, never at the effective size.
- **`kCapHeightRatio = 0.7`** — DXF height is cap height; the em size used for layout is nominal, and the matrix scale is `effectiveHeight / metrics.capHeight`.
- **Paragraph cache key is `(string, textStyle handle, ResolvedStyle.argb)`** — `ui.Paragraph` bakes its colour and `drawParagraph` takes no `Paint`.
- **No MTEXT**, no DXF 72=3/72=5 layout, no text LOD, no fills, no picture cache.
- Language: code, comments and commit messages in English.
- Every task ends green: `dart test` in `packages/jet_cad_2d`, `flutter test` in `packages/jet_cad_2d_flutter`, `dart analyze` and `dart format --output=none --set-exit-if-changed .` clean in both.

## Deviations from the spec, decided while planning

Two, both recorded here because the plan is what the implementer follows:

1. **No second matrix buffer in `CanvasDrawSink`.** The spec called for one. `DrawSink` already carries `beginResidual(Transform2)` / `endResidual()` and every leaf draws in its own residual's local space (`draw_sink.dart:17-30`), so the painter pushes `residual ∘ textLocal` through the existing mechanism and the text op draws at the local origin. The existing `_transformPushed` latch handles it; nothing in `canvas_draw_sink.dart`'s matrix handling changes.
2. **The differential needs no per-field tolerance split.** The spec proposed absolute tolerance on `e`/`f` and relative on the linear terms. Instead a text op flattens to **three screen points** — the local origin and the images of the local unit vectors — so `DrawnItem`'s existing `kScreenTolerance = 1e-6` applies to all three, and scale, rotation and shear are all covered by the machinery already there. `BeginResidualOp` also compares its six terms exactly, so the transform is pinned twice.

## File Structure

**Created:**
- `packages/jet_cad_2d/lib/src/document/text_geometry.dart` — `ResolvedTextAttributes`, `resolveTextAttributes`, `textLocalTransform`, `TextJustifyH`, `TextJustifyV`, and the packing helpers for `_textAttrs`. The single resolution point.
- `packages/jet_cad_2d/lib/src/document/text_metrics.dart` — `TextMetrics`, the `TextMeasurer` interface, `InsertionPointMeasurer`, `MetricModelMeasurer`.
- `packages/jet_cad_2d_flutter/lib/src/flutter_text_measurer.dart` — `FlutterTextMeasurer` and the `(string, style, argb)` LRU holding `Paragraph` + `TextMetrics`.
- `packages/jet_cad_2d/test/document/text_geometry_test.dart`
- `packages/jet_cad_2d/test/document/text_metrics_test.dart`
- `packages/jet_cad_2d/test/codec/schema_v3_fixture_test.dart`
- `packages/jet_cad_2d_flutter/test/flutter_text_measurer_test.dart`
- `packages/jet_cad_2d_flutter/test/text_paint_test.dart`
- `packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart`
- `docs/superpowers/notes/2026-08-1X-plan-3c-results.md` (Task 13 writes it; the date is the day it runs)

**Modified:**
- `packages/jet_cad_2d/lib/src/store/entity_store.dart` — four fields on `EntityRecord`, two `List<String>` columns, `_textStyle`, `_textAttrs`, accessors, `_write`, `read`, `purge`, `remove`, `clear`, `_ensureCapacity`, `toJson`, `fromJson`, `==`, `hashCode`, `copyWith`.
- `packages/jet_cad_2d/lib/src/document/extents.dart` — `entityBounds` takes the record's text fields and a `TextStyleRecord`; text case delegates to `text_geometry.dart`. `TextMeasurer` moves out to `text_metrics.dart` and is re-exported.
- `packages/jet_cad_2d/lib/src/codec/schema_version.dart` — `kSchemaVersion` 3 → 4.
- `packages/jet_cad_2d/lib/src/document/commands.dart` — `SetEntityTextCommand`.
- `packages/jet_cad_2d/lib/src/document/draft_document.dart` — the `entityBounds` call at `:226`.
- `packages/jet_cad_2d/lib/src/index/container_index.dart` — the `entityBounds` call at `:93`.
- `packages/jet_cad_2d/lib/src/index/spatial_index.dart` — the `entityBounds` call at `:2358`, and the pick case at `:765-778`.
- `packages/jet_cad_2d/lib/src/testing/generate_document.dart` — `labelFraction`, `attributedInstanceFraction`.
- `packages/jet_cad_2d/lib/jet_cad_2d.dart` — export the two new files.
- `packages/jet_cad_2d_flutter/lib/src/draw_sink.dart` — `text` on `DrawSink`, `TextOp`, both other sinks.
- `packages/jet_cad_2d_flutter/lib/src/canvas_draw_sink.dart` — implement `text`.
- `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart` — draw text instead of counting it.
- `packages/jet_cad_2d_flutter/lib/src/reference_walk.dart` — the `entityBounds` call at `:108`, and draw text.
- `packages/jet_cad_2d_flutter/test/support/differential.dart` — flatten `TextOp`.
- `packages/jet_cad_2d_flutter/test/rig/rig_support.dart` — `textRigCorpus`, counters.
- Tests that flip: `draft_painter_root_test.dart:287-289`, `generate_document_test.dart:49-52`, and every `entityBounds` test call site (`corpus.dart:632`, `reference_query.dart:210` and `:805`, `extents_test.dart`, `snap_centre_index_test.dart:120` and `:353`).

---

## Task 0: Text columns on the store and the record

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/store/entity_store.dart`
- Test: `packages/jet_cad_2d/test/store/entity_store_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `EntityRecord({..., String text = '', String tag = '', Handle textStyle = ReservedHandles.standardTextStyle, int textAttrs = 0})`; `EntityStore.textAt(int slot) -> String`, `tagAt(int slot) -> String`, `textStyleAt(int slot) -> Handle`, `textAttrsAt(int slot) -> int`.

- [ ] **Step 1: Write the failing test**

```dart
// test/store/entity_store_test.dart
test('text fields round-trip through the store and clear on remove', () {
  final store = EntityStore();
  final slot = store.add(EntityRecord(
    handle: const Handle(1),
    owner: ReservedHandles.root,
    kind: EntityKind.text,
    layer: ReservedHandles.layerZero,
    linetype: ReservedHandles.byLayerLinetype,
    linetypeScale: 1.0,
    geomIndex: 0,
    color: const ByLayerColor(),
    lineweight: kLineweightDefault,
    transparency: kByLayer,
    flags: 0,
    text: 'WC',
    tag: 'ROOM',
    textStyle: const Handle(7),
    textAttrs: 0x0121,
  ));

  expect(store.textAt(slot), 'WC');
  expect(store.tagAt(slot), 'ROOM');
  expect(store.textStyleAt(slot), const Handle(7));
  expect(store.textAttrsAt(slot), 0x0121);
  expect(store.read(slot).text, 'WC');

  store.remove(slot);
  // Strings are heap references: an unreachable slot that still points at a
  // string keeps the whole document's text alive after deletion. The typed
  // columns can afford to keep stale numbers; these cannot.
  expect(store.debugRawTextAt(slot), '');
  expect(store.debugRawTagAt(slot), '');
});

test('purge carries the text columns with the slot', () {
  final store = EntityStore();
  final a = store.add(_textRecord(const Handle(1), text: 'A'));
  final b = store.add(_textRecord(const Handle(2), text: 'B'));
  store.remove(a);
  final remap = store.purge();
  expect(store.textAt(remap[b]), 'B');
});
```

- [ ] **Step 2: Run it and watch it fail**

Run: `cd packages/jet_cad_2d && dart test test/store/entity_store_test.dart`
Expected: FAIL — `EntityRecord` has no named parameter `text`.

- [ ] **Step 3: Add the record fields**

In `EntityRecord`: four new final fields with defaults, added to the constructor, to `copyWith`, to `==`, and to `hashCode` — all three, because command inverses and the codec's idempotence tests compare records.

```dart
  /// The displayed string. `''` for every kind but [EntityKind.text] and
  /// [EntityKind.attrib].
  final String text;

  /// A DXF ATTRIB's tag. `''` for a TEXT.
  final String tag;

  final Handle textStyle;

  /// Packed: bits 0-3 horizontal justification (DXF 72), bits 4-7 vertical
  /// justification (DXF 73 for TEXT, **74 for ATTRIB** — for an ATTRIB, group
  /// 73 is field length, not justification), bit 8 `widthFactor` is
  /// overridden, bit 9 `obliqueAngle` is overridden.
  final int textAttrs;
```

- [ ] **Step 4: Add the columns**

```dart
  // Not typed lists, because a string is not a number. This is the one place
  // the all-typed-list shape of this store is broken, and interning into a
  // `Uint32List` index column is the recorded alternative — rejected for now
  // because it puts a refcount on the slot lifetime.
  List<String> _text = List<String>.filled(_initialCapacity, '');
  List<String> _tag = List<String>.filled(_initialCapacity, '');
  Uint32List _textStyle = Uint32List(_initialCapacity);
  Uint16List _textAttrs = Uint16List(_initialCapacity);
```

Extend `_write`, `read`, `_ensureCapacity` (`List<String>.filled(capacity, '')..setAll(0, _text)`), `purge` (copy all four), and `clear` (refill both string lists with `''`). In `remove`, before freeing the slot: `_text[slot] = ''; _tag[slot] = '';`.

Add the accessors, plus two debug-only readers the test above uses:

```dart
  String textAt(int slot) => _text[slot];
  String tagAt(int slot) => _tag[slot];
  Handle textStyleAt(int slot) => Handle(_textStyle[slot]);
  int textAttrsAt(int slot) => _textAttrs[slot];

  /// Reads the column without the live check, so a test can assert that
  /// [remove] released the string reference.
  @visibleForTesting
  String debugRawTextAt(int slot) => _text[slot];
  @visibleForTesting
  String debugRawTagAt(int slot) => _tag[slot];
```

- [ ] **Step 5: Run the store suite**

Run: `cd packages/jet_cad_2d && dart test test/store/`
Expected: PASS.

- [ ] **Step 6: Run the whole engine suite**

Run: `cd packages/jet_cad_2d && dart test`
Expected: PASS — the defaults keep every existing record construction valid. The codec still writes ten keys; that is Task 1.

- [ ] **Step 7: Commit**

```bash
git add packages/jet_cad_2d/lib/src/store/entity_store.dart packages/jet_cad_2d/test/store/entity_store_test.dart
git commit -m "feat(jet_cad_2d): store text content, tag, style and packed attributes"
```

---

## Task 1: Codec, schema 4, and the defensive scalar read

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/store/entity_store.dart` (`toJson`, `fromJson`)
- Modify: `packages/jet_cad_2d/lib/src/codec/schema_version.dart`
- Create: `packages/jet_cad_2d/lib/src/document/text_scalars.dart`
- Create: `packages/jet_cad_2d/test/codec/schema_v3_fixture_test.dart`
- Modify: `packages/jet_cad_2d/test/testing/generate_document_test.dart` (re-baseline the two fingerprints)

**Interfaces:**
- Consumes: Task 0's record fields.
- Produces: `double scalarOr(GeometryPayload payload, int index, double fallback)`; `kSchemaVersion == 4`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/codec/schema_v3_fixture_test.dart
const _v3Document = '''
{"schemaVersion":3,"header":{},"tables":{"layers":[],"linetypes":[],
"textStyles":[],"patterns":[]},"tree":{"nodes":[]},"entities":[
{"record":{"handle":"0x1","owner":"0x0","kind":"text","layer":"0x10",
"linetype":"0x20","linetypeScale":1.0,"color":-1,"lineweight":-3,
"transparency":-1,"flags":0},
"geometry":{"coords":[10.0,20.0],"scalars":[100.0]}}],
"components":{},"rawData":{}}
''';

test('a version-3 document loads under the version-4 build', () {
  final doc = decodeDocument(_v3Document);
  final slot = doc.entities.liveSlots.single;
  expect(doc.entities.textAt(slot), '');
  expect(doc.entities.tagAt(slot), '');
  expect(doc.entities.textStyleAt(slot), ReservedHandles.standardTextStyle);
  expect(doc.entities.textAttrsAt(slot), 0);
  // One scalar, not four. Reading scalars[1] must not throw.
  final payload = doc.geometry.read(doc.entities.geomIndexAt(slot));
  expect(scalarOr(payload, 1, 0.0), 0.0);
  expect(scalarOr(payload, 0, 0.0), 100.0);
});

test('a version-3 document survives a round-trip unpadded', () {
  final once = encodeDocument(decodeDocument(_v3Document));
  final twice = encodeDocument(decodeDocument(once));
  expect(twice, once);
  // The payload is not rewritten on load: padding it would change geometry
  // the file never contained.
  expect(once.contains('"scalars":[100.0]'), isTrue);
});
```

- [ ] **Step 2: Run and watch it fail**

Run: `cd packages/jet_cad_2d && dart test test/codec/schema_v3_fixture_test.dart`
Expected: FAIL — `scalarOr` is undefined.

- [ ] **Step 3: Write the helper**

```dart
// lib/src/document/text_scalars.dart
import '../store/geometry_store.dart';

/// Reads a scalar that a document written before Plan 3c does not carry.
///
/// A text entity written at schema 3 holds exactly one scalar — its height —
/// so `scalars[1..3]` is a `RangeError` on every such document. The payload is
/// **not** padded on load: padding would write geometry the file did not
/// contain and would make `save(load(save(d))) == save(d)` compare a padded
/// payload against an unpadded one.
double scalarOr(GeometryPayload payload, int index, double fallback) =>
    index < payload.scalars.length ? payload.scalars[index] : fallback;
```

- [ ] **Step 4: Extend the codec**

In `EntityRecord.toJson`, after `'flags': flags,`:

```dart
        'text': text,
        'tag': tag,
        'textStyle': textStyle.toJson(),
        'textAttrs': textAttrs,
```

In `fromJson`, absent-key defaults — these four lines *are* the v3→v4 migration, because `json_codec.dart:103` rejects only versions **above** the current one:

```dart
      text: json['text'] as String? ?? '',
      tag: json['tag'] as String? ?? '',
      textStyle: json['textStyle'] == null
          ? ReservedHandles.standardTextStyle
          : Handle.fromJson(json['textStyle']),
      textAttrs: json['textAttrs'] as int? ?? 0,
```

Bump `kSchemaVersion` to `4` and extend its doc comment with one line naming what changed.

- [ ] **Step 5: Re-baseline the corpus fingerprints**

The four new keys move both FNV-1a constants in `generate_document_test.dart:49-52`, and that test's own comment calls them "the whole guard" on corpus extensions. Re-baseline them **here**, in the codec commit, so the guard is voided and restored before Task 7 changes the corpus.

Run: `cd packages/jet_cad_2d && dart test test/testing/generate_document_test.dart`
Read the two actual values out of the failure, replace the constants, and add one line to the comment: `# re-baselined in Plan 3c Task 1: the four text keys changed the serialisation.`

- [ ] **Step 6: Run the suite**

Run: `cd packages/jet_cad_2d && dart test`
Expected: PASS, including the codec determinism, idempotence, round-trip and preserve-unknown tests.

- [ ] **Step 7: Commit**

```bash
git add packages/jet_cad_2d/lib packages/jet_cad_2d/test
git commit -m "feat(jet_cad_2d): carry text fields through the codec at schema 4"
```

---

## Task 2: `TextMetrics`, the measurer seam, and the metric model

**Files:**
- Create: `packages/jet_cad_2d/lib/src/document/text_metrics.dart`
- Modify: `packages/jet_cad_2d/lib/src/document/extents.dart` (drop `TextMeasurer`/`InsertionPointMeasurer`, import them)
- Modify: `packages/jet_cad_2d/lib/jet_cad_2d.dart`
- Test: `packages/jet_cad_2d/test/document/text_metrics_test.dart`

**Interfaces:**
- Consumes: `TextStyleRecord` from `tables.dart`.
- Produces: `TextMetrics({advanceWidth, ascent, descent, capHeight})`, `TextMetrics.zero`; `abstract class TextMeasurer { TextMetrics measure({required String text, required TextStyleRecord style}); }`; `InsertionPointMeasurer`; `MetricModelMeasurer({double advanceRatio = 0.55, double ascentRatio = 0.8, double descentRatio = 0.2, double capRatio = kCapHeightRatio})`; `const double kNominalTextPixels = 100.0`; `const double kCapHeightRatio = 0.7`.

- [ ] **Step 1: Write the failing test**

```dart
// test/document/text_metrics_test.dart
test('the metric model is deterministic and its ascent differs from its descent',
    () {
  const m = MetricModelMeasurer();
  final metrics = m.measure(text: 'WC', style: _style);

  expect(metrics.advanceWidth, closeTo(2 * 0.55 * kNominalTextPixels, 1e-9));
  expect(metrics.ascent, closeTo(0.8 * kNominalTextPixels, 1e-9));
  expect(metrics.descent, closeTo(0.2 * kNominalTextPixels, 1e-9));
  expect(metrics.capHeight, closeTo(0.7 * kNominalTextPixels, 1e-9));
  // A model whose ascent equals its descent hides every vertical
  // justification defect, so this inequality is load-bearing.
  expect(metrics.ascent, isNot(closeTo(metrics.descent, 1e-9)));
});

test('measure returns the identical instance on a repeat call', () {
  const m = MetricModelMeasurer();
  final a = m.measure(text: 'T-0001', style: _style);
  final b = m.measure(text: 'T-0001', style: _style);
  // The pick path measures per candidate. A fresh object per call breaks
  // query_allocation_test.
  expect(identical(a, b), isTrue);
});

test('the insertion-point measurer is a declared lower bound', () {
  expect(const InsertionPointMeasurer().measure(text: 'WC', style: _style),
      same(TextMetrics.zero));
});
```

- [ ] **Step 2: Run and watch it fail**

Run: `cd packages/jet_cad_2d && dart test test/document/text_metrics_test.dart`
Expected: FAIL — `MetricModelMeasurer` is undefined.

- [ ] **Step 3: Write `text_metrics.dart`**

```dart
/// The em size every paragraph is laid out at.
///
/// Layout is size-independent here on purpose: height, rotation, width factor
/// and oblique angle are all transforms, so one laid-out paragraph serves the
/// same string at every size. Laying out at the *effective* size instead
/// renders correctly and silently destroys the cache.
const double kNominalTextPixels = 100.0;

/// Cap height as a fraction of the em size.
///
/// DXF's text height is the height of a capital letter; a font's `fontSize` is
/// the em size. `dart:ui` exposes no cap height — `computeLineMetrics` gives
/// ascent and descent only — so this constant stands in for it and the
/// deviation is declared rather than hidden.
const double kCapHeightRatio = 0.7;

@immutable
class TextMetrics {
  const TextMetrics({
    required this.advanceWidth,
    required this.ascent,
    required this.descent,
    required this.capHeight,
  });

  final double advanceWidth;
  final double ascent;
  final double descent;
  final double capHeight;

  static const TextMetrics zero =
      TextMetrics(advanceWidth: 0, ascent: 0, descent: 0, capHeight: 0);
}

/// Supplies font metrics at [kNominalTextPixels].
///
/// Takes the [TextStyleRecord], not a handle: `fontFamily`, `widthFactor` and
/// `obliqueAngle` live on the record, and a measurer is constructed before the
/// document that owns the table, so it cannot look one up.
abstract class TextMeasurer {
  TextMetrics measure({required String text, required TextStyleRecord style});
}

class InsertionPointMeasurer implements TextMeasurer {
  const InsertionPointMeasurer();

  @override
  TextMetrics measure({required String text, required TextStyleRecord style}) =>
      TextMetrics.zero;
}

/// Deterministic, font-free metrics for engine tests.
class MetricModelMeasurer implements TextMeasurer {
  const MetricModelMeasurer({
    this.advanceRatio = 0.55,
    this.ascentRatio = 0.8,
    this.descentRatio = 0.2,
    this.capRatio = kCapHeightRatio,
  });

  final double advanceRatio;
  final double ascentRatio;
  final double descentRatio;
  final double capRatio;

  // One entry per string length, since that is all this model depends on.
  // Memoised because the pick path measures per candidate and the allocation
  // harness forbids a fresh object there.
  static final Map<int, TextMetrics> _byLength = {};

  @override
  TextMetrics measure({required String text, required TextStyleRecord style}) =>
      _byLength.putIfAbsent(
          text.length,
          () => TextMetrics(
                advanceWidth: text.length * advanceRatio * kNominalTextPixels,
                ascent: ascentRatio * kNominalTextPixels,
                descent: descentRatio * kNominalTextPixels,
                capHeight: capRatio * kNominalTextPixels,
              ));
}
```

Note for the implementer: the static cache is keyed by length only because the
ratios are `const` defaults in practice. If a test constructs a model with
different ratios, key the map by `(length, advanceRatio, ascentRatio,
descentRatio, capRatio)` — Task 4's measurer-dependence test constructs a second
model, so do this now, not later.

- [ ] **Step 4: Move the seam and re-export**

Delete `TextMeasurer` and `InsertionPointMeasurer` from `extents.dart`, import them there instead, and add `export 'src/document/text_metrics.dart';` plus `export 'src/document/text_scalars.dart';` to `lib/jet_cad_2d.dart`.

- [ ] **Step 5: Run the suite — it will not compile yet**

Run: `cd packages/jet_cad_2d && dart analyze`
Expected: errors at `entityBounds`' text case (it still calls the old four-argument `measure`) and at every `DraftDocument` construction site that passes a measurer. Task 3 and Task 4 close them. **Do not commit a red tree**: finish Step 6 first.

- [ ] **Step 6: Stub the text case so the tree is green**

Temporarily, in `entityBounds`' text case: `return Aabb2(payload.pointAt(0), payload.pointAt(0));` with a `// Task 4 replaces this.` comment. Everything else compiles.

Run: `cd packages/jet_cad_2d && dart test`
Expected: PASS — the old text boxes were degenerate points anyway, so no existing expectation moves.

- [ ] **Step 7: Commit**

```bash
git add packages/jet_cad_2d/lib packages/jet_cad_2d/test
git commit -m "feat(jet_cad_2d): add the TextMetrics seam and a deterministic metric model"
```

---

## Task 3: `text_geometry.dart` — one resolution point

**Files:**
- Create: `packages/jet_cad_2d/lib/src/document/text_geometry.dart`
- Modify: `packages/jet_cad_2d/lib/jet_cad_2d.dart`
- Test: `packages/jet_cad_2d/test/document/text_geometry_test.dart`

**Interfaces:**
- Consumes: `TextMetrics`, `TextStyleRecord`, `GeometryPayload`, `scalarOr`.
- Produces: `enum TextJustifyH { left, centre, right, aligned, middle, fit }`, `enum TextJustifyV { baseline, bottom, middle, top }`, `int packTextAttrs({TextJustifyH h, TextJustifyV v, bool overrideWidthFactor, bool overrideOblique})`, `class ResolvedTextAttributes { double height, rotation, widthFactor, obliqueAngle; TextJustifyH h; TextJustifyV v; bool fellBackFromAlignedOrFit; }`, `ResolvedTextAttributes resolveTextAttributes(GeometryPayload payload, int textAttrs, TextStyleRecord style)`, `Transform2 textLocalTransform(ResolvedTextAttributes attrs, TextMetrics metrics, Vector2 anchor)`, `Aabb2 textLocalBounds(ResolvedTextAttributes attrs, TextMetrics metrics)`.

- [ ] **Step 1: Write the failing tests — one arithmetic expectation per attribute**

```dart
// test/document/text_geometry_test.dart
const _model = MetricModelMeasurer();
final _plain = TextStyleRecord(
    handle: const Handle(7), name: 'STANDARD', fontFamily: 'Roboto');

ResolvedTextAttributes _resolve(
        {double height = 200.0,
        double rotation = 0.0,
        int attrs = 0,
        double? widthFactor,
        double? oblique,
        TextStyleRecord? style}) =>
    resolveTextAttributes(
        GeometryPayload(
            coords: Float64List.fromList([0, 0]),
            scalars: Float64List.fromList(
                [height, rotation, widthFactor ?? 0, oblique ?? 0])),
        attrs,
        style ?? _plain);

test('an unset override bit reads the style, not the scalar', () {
  final style = TextStyleRecord(
      handle: const Handle(7),
      name: 'WIDE',
      fontFamily: 'Roboto',
      widthFactor: 2.0);
  // Bit 8 clear: the 0.25 sitting in scalars[2] must be ignored.
  final a = _resolve(attrs: 0, widthFactor: 0.25, style: style);
  expect(a.widthFactor, 2.0);

  final b = _resolve(
      attrs: packTextAttrs(overrideWidthFactor: true),
      widthFactor: 0.25,
      style: style);
  expect(b.widthFactor, 0.25);
});

test('a style fixed height overrides the entity height', () {
  final style = TextStyleRecord(
      handle: const Handle(7),
      name: 'FIXED',
      fontFamily: 'Roboto',
      fixedHeight: 50.0);
  expect(_resolve(height: 200.0, style: style).height, 50.0);
  expect(_resolve(height: 200.0).height, 200.0);
});

test('height scales by cap height, not by the em size', () {
  final attrs = _resolve(height: 210.0);
  final m = _model.measure(text: 'WC', style: _plain);
  final t = textLocalTransform(attrs, m, Vector2.zero());
  // 210 / (0.7 * 100) = 3.0
  expect(t.a, closeTo(3.0, 1e-9));
  expect(t.d, closeTo(3.0, 1e-9));
});

test('centre justification offsets by half the advance width', () {
  final m = _model.measure(text: 'WC', style: _plain); // 110 nominal units
  final left = textLocalTransform(
      _resolve(attrs: packTextAttrs(h: TextJustifyH.left)), m, Vector2.zero());
  final centre = textLocalTransform(
      _resolve(attrs: packTextAttrs(h: TextJustifyH.centre)), m,
      Vector2.zero());
  // Scale is 200 / 70; half the advance is 55 nominal units.
  expect(centre.e - left.e, closeTo(-55.0 * (200.0 / 70.0), 1e-9));
});

test('top justification offsets by the ascent and bottom by the descent', () {
  final m = _model.measure(text: 'WC', style: _plain);
  final scale = 200.0 / 70.0;
  final top = textLocalTransform(
      _resolve(attrs: packTextAttrs(v: TextJustifyV.top)), m, Vector2.zero());
  final bottom = textLocalTransform(
      _resolve(attrs: packTextAttrs(v: TextJustifyV.bottom)), m,
      Vector2.zero());
  expect(top.f, closeTo(-m.ascent * scale, 1e-9));
  expect(bottom.f, closeTo(m.descent * scale, 1e-9));
});

test('72=4 (middle) ignores the vertical code', () {
  final m = _model.measure(text: 'WC', style: _plain);
  final a = textLocalTransform(
      _resolve(
          attrs: packTextAttrs(h: TextJustifyH.middle, v: TextJustifyV.top)),
      m,
      Vector2.zero());
  final b = textLocalTransform(
      _resolve(
          attrs:
              packTextAttrs(h: TextJustifyH.middle, v: TextJustifyV.baseline)),
      m,
      Vector2.zero());
  expect(a.f, closeTo(b.f, 1e-9));
});

test('rotation is not symmetric about its sign', () {
  final m = _model.measure(text: 'WC', style: _plain);
  // 0 and pi are degenerate for a sign flip; 0.4 rad is not.
  final plus = textLocalTransform(_resolve(rotation: 0.4), m, Vector2.zero());
  final minus = textLocalTransform(_resolve(rotation: -0.4), m, Vector2.zero());
  expect(plus.b, closeTo(-minus.b, 1e-9));
  expect(plus.b, isNot(closeTo(0.0, 1e-6)));
});

test('the width factor scales the already-sheared glyph, not the other way', () {
  final style = TextStyleRecord(
      handle: const Handle(7),
      name: 'SLANT',
      fontFamily: 'Roboto',
      widthFactor: 2.0,
      obliqueAngle: 0.3);
  final m = _model.measure(text: 'WC', style: _plain);
  final t = textLocalTransform(_resolve(style: style), m, Vector2.zero());
  final scale = 200.0 / 70.0;
  // Shear first, then the x-scale: c = widthFactor * tan(oblique) * scale.
  expect(t.c, closeTo(2.0 * math.tan(0.3) * scale, 1e-9));
  // The other order would give tan(0.3) * scale, which this pins against.
  expect(t.c, isNot(closeTo(math.tan(0.3) * scale, 1e-6)));
});

test('aligned and fit fall back to left, in the resolver', () {
  final a = _resolve(attrs: packTextAttrs(h: TextJustifyH.aligned));
  expect(a.h, TextJustifyH.left);
  expect(a.fellBackFromAlignedOrFit, isTrue);
});

test('a v3 payload with one scalar resolves to defaults', () {
  final attrs = resolveTextAttributes(
      GeometryPayload(
          coords: Float64List.fromList([0, 0]),
          scalars: Float64List.fromList([120.0])),
      0,
      _plain);
  expect(attrs.height, 120.0);
  expect(attrs.rotation, 0.0);
  expect(attrs.widthFactor, 1.0);
  expect(attrs.obliqueAngle, 0.0);
});
```

- [ ] **Step 2: Run and watch it fail**

Run: `cd packages/jet_cad_2d && dart test test/document/text_geometry_test.dart`
Expected: FAIL — `resolveTextAttributes` is undefined.

- [ ] **Step 3: Implement the resolver**

```dart
const int _kOverrideWidthFactor = 1 << 8;
const int _kOverrideOblique = 1 << 9;

int packTextAttrs({
  TextJustifyH h = TextJustifyH.left,
  TextJustifyV v = TextJustifyV.baseline,
  bool overrideWidthFactor = false,
  bool overrideOblique = false,
}) =>
    (h.index & 0xF) |
    ((v.index & 0xF) << 4) |
    (overrideWidthFactor ? _kOverrideWidthFactor : 0) |
    (overrideOblique ? _kOverrideOblique : 0);

ResolvedTextAttributes resolveTextAttributes(
    GeometryPayload payload, int textAttrs, TextStyleRecord style) {
  var h = TextJustifyH.values[textAttrs & 0xF];
  var fellBack = false;
  if (h == TextJustifyH.aligned || h == TextJustifyH.fit) {
    // Both need a second point the payload does not carry. The fallback lives
    // here, not in the painter, so the box and the glyphs agree.
    h = TextJustifyH.left;
    fellBack = true;
  }
  final v = h == TextJustifyH.middle
      // DXF ignores the vertical code when 72 = 4.
      ? TextJustifyV.baseline
      : TextJustifyV.values[(textAttrs >> 4) & 0xF];

  return ResolvedTextAttributes(
    height: style.fixedHeight != 0 ? style.fixedHeight : scalarOr(payload, 0, 0),
    rotation: scalarOr(payload, 1, 0),
    widthFactor: (textAttrs & _kOverrideWidthFactor) != 0
        ? scalarOr(payload, 2, style.widthFactor)
        : style.widthFactor,
    obliqueAngle: (textAttrs & _kOverrideOblique) != 0
        ? scalarOr(payload, 3, style.obliqueAngle)
        : style.obliqueAngle,
    h: h,
    v: h == TextJustifyH.middle ? TextJustifyV.middle : v,
    fellBackFromAlignedOrFit: fellBack,
  );
}
```

- [ ] **Step 4: Implement the transform and the local box**

```dart
/// Composed innermost-first:
///   oblique shear -> width-factor x-scale -> height scale
///   -> justification offset -> rotation -> translation to [anchor]
///
/// Shear before the x-scale, deliberately: `w * (x + k*y)` is not
/// `w*x + k*y`, and scaling the already-slanted glyph is the DXF reading. The
/// text ladder golden is the evidence, and a mutant that swaps the two is
/// killed by `text_geometry_test`'s width-factor-and-oblique case.
Transform2 textLocalTransform(
    ResolvedTextAttributes attrs, TextMetrics metrics, Vector2 anchor) {
  final scale = metrics.capHeight == 0
      ? 0.0
      // Cap height, not the em size: DXF's height is the capital-letter height.
      : attrs.height / metrics.capHeight;
  final k = math.tan(attrs.obliqueAngle);

  // Glyph space -> shear -> width factor -> uniform height scale.
  final a = attrs.widthFactor * scale;
  final c = attrs.widthFactor * k * scale;
  final d = scale;

  final dx = switch (attrs.h) {
        TextJustifyH.left || TextJustifyH.aligned || TextJustifyH.fit => 0.0,
        TextJustifyH.centre || TextJustifyH.middle => -metrics.advanceWidth / 2,
        TextJustifyH.right => -metrics.advanceWidth,
      } *
      attrs.widthFactor *
      scale;
  final dy = switch (attrs.v) {
        TextJustifyV.baseline => 0.0,
        TextJustifyV.bottom => metrics.descent,
        TextJustifyV.middle => (metrics.descent - metrics.ascent) / 2,
        TextJustifyV.top => -metrics.ascent,
      } *
      scale;

  final cos = math.cos(attrs.rotation), sin = math.sin(attrs.rotation);
  // rotation ∘ (linear part), then the rotated offset plus the anchor.
  return Transform2(
    cos * a - sin * 0.0,
    sin * a + cos * 0.0,
    cos * c - sin * d,
    sin * c + cos * d,
    anchor.x + cos * dx - sin * dy,
    anchor.y + sin * dx + cos * dy,
  );
}

/// The glyph box in the text's own space, before [textLocalTransform].
Aabb2 textLocalBounds(ResolvedTextAttributes attrs, TextMetrics metrics) =>
    Aabb2(Vector2(0, -metrics.descent), Vector2(metrics.advanceWidth, metrics.ascent));
```

- [ ] **Step 5: Run the tests**

Run: `cd packages/jet_cad_2d && dart test test/document/text_geometry_test.dart`
Expected: PASS, all eleven.

- [ ] **Step 6: Export and commit**

Add `export 'src/document/text_geometry.dart';` to `lib/jet_cad_2d.dart`.

```bash
git add packages/jet_cad_2d/lib packages/jet_cad_2d/test
git commit -m "feat(jet_cad_2d): resolve text attributes and compose the local transform in one place"
```

---

## Task 4: `entityBounds` and all four call sites

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/document/extents.dart`
- Modify: `packages/jet_cad_2d/lib/src/document/draft_document.dart:226`
- Modify: `packages/jet_cad_2d/lib/src/index/container_index.dart:93`
- Modify: `packages/jet_cad_2d/lib/src/index/spatial_index.dart:2358`
- Modify: `packages/jet_cad_2d_flutter/lib/src/reference_walk.dart:108`
- Modify: test call sites — `test/invariants/corpus.dart:632`, `test/invariants/reference_query.dart:210` and `:805`, `test/document/extents_test.dart`, `test/index/snap_centre_index_test.dart:120` and `:353`
- Test: `packages/jet_cad_2d/test/index/text_overlay_test.dart` (create)

**Interfaces:**
- Consumes: Task 3's `resolveTextAttributes`, `textLocalTransform`, `textLocalBounds`.
- Produces: `Aabb2 entityBounds({required EntityKind kind, required GeometryPayload payload, required TextMeasurer measurer, required TextStyleRecord textStyle, String text = ''})` — note the parameter type change from `Handle` to `TextStyleRecord`.

- [ ] **Step 1: Write the failing test — the one that pins the incremental path**

```dart
// test/index/text_overlay_test.dart
test('an edited text has the same box in the overlay as after a rebuild', () {
  final doc = DraftDocument.empty(measurer: const MetricModelMeasurer());
  final style = doc.tables.textStyles.byName('STANDARD')!;
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
      EntityRecord(/* ... a text record at (1000, 2000), height 200 ... */),
      GeometryPayload(
          coords: Float64List.fromList([1000, 2000]),
          scalars: Float64List.fromList([200, 0, 0, 0]))));

  final index = SpatialIndex(doc);
  doc.commands.execute(SetEntityTextCommand(handle, 'A MUCH LONGER LABEL', ''));

  final incremental = index.rootIndex.boxOfLeaf(doc.entities.slotOf(handle)!);
  index.rebuildAll();
  final rebuilt = index.rootIndex.boxOfLeaf(doc.entities.slotOf(handle)!);

  // The dirty-overlay path at spatial_index.dart:2358 must resolve text the
  // same way the full build does. Hard-coding `text: ''` there leaves an
  // edited text in a degenerate box while a rebuilt one is correct — on the
  // path an editing session spends all its time in.
  expect(incremental.minX, closeTo(rebuilt.minX, 1e-9));
  expect(incremental.maxX, closeTo(rebuilt.maxX, 1e-9));
  expect(incremental.minY, closeTo(rebuilt.minY, 1e-9));
  expect(incremental.maxY, closeTo(rebuilt.maxY, 1e-9));
  expect(rebuilt.maxX - rebuilt.minX, greaterThan(0.0));
});
```

This test needs `SetEntityTextCommand`, which is Task 5. Write the test now and mark it `skip: 'Task 5 adds the command'`, then unskip it in Task 5 — or reorder locally and do Task 5 first. **Do not delete the test to make the tree green.**

- [ ] **Step 2: Change `entityBounds`' text case**

```dart
    case EntityKind.text:
    case EntityKind.attrib:
      final attrs = resolveTextAttributes(payload, textAttrs, textStyle);
      final metrics = measurer.measure(text: text, style: textStyle);
      final local = textLocalBounds(attrs, metrics);
      return local
          .transformedBy(textLocalTransform(attrs, metrics, payload.pointAt(0)));
```

Add `required TextStyleRecord textStyle` and `int textAttrs = 0` to the signature, replacing the `Handle textStyle` parameter.

- [ ] **Step 3: Update all four production call sites**

Each already holds the document, so each looks up the record once:

```dart
      final record = doc.entities.read(slot);          // or the existing local
      final leafBox = entityBounds(
        kind: record.kind,
        payload: payload,
        measurer: doc.textMeasurer,
        textStyle: doc.tables.textStyles[record.textStyle] ??
            doc.tables.textStyles[ReservedHandles.standardTextStyle]!,
        textAttrs: record.textAttrs,
        text: record.text,
      );
```

`spatial_index.dart:2358` is the one that matters most: it is the incremental
re-derive. `reference_walk.dart:108` is the differential oracle's own bounds
call and must use the same expression.

- [ ] **Step 4: Update the test call sites**

Run `grep -rn "entityBounds(" packages/*/test` and fix each — six sites across five files. Where a test passed `ReservedHandles.standardTextStyle`, pass the record from the document's table instead.

- [ ] **Step 5: Run everything**

Run: `cd packages/jet_cad_2d && dart test && dart analyze`
Run: `cd packages/jet_cad_2d_flutter && flutter test && flutter analyze`
Expected: PASS. Existing text expectations that asserted a degenerate box move here — that is the point, and each change is deliberate.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d packages/jet_cad_2d_flutter
git commit -m "feat(jet_cad_2d): bound text by its laid-out box at every call site"
```

---

## Task 5: `SetEntityTextCommand`

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/document/commands.dart`
- Test: `packages/jet_cad_2d/test/document/commands_test.dart`, and unskip `test/index/text_overlay_test.dart`

**Interfaces:**
- Consumes: Task 0's columns.
- Produces: `SetEntityTextCommand(Handle handle, String text, String tag)`.

- [ ] **Step 1: Write the failing test**

```dart
test('setting text is undoable and dirties the index', () {
  // ... build a doc with one text entity 'A' ...
  final index = SpatialIndex(doc);
  final before = index.rootIndex.boxOfLeaf(slot).maxX;

  doc.commands.execute(SetEntityTextCommand(handle, 'AAAAAAAA', 'TAG'));
  expect(doc.entities.textAt(slot), 'AAAAAAAA');
  expect(doc.entities.tagAt(slot), 'TAG');
  expect(index.rootIndex.boxOfLeaf(slot).maxX, greaterThan(before));

  doc.commands.undo();
  expect(doc.entities.textAt(slot), 'A');
  expect(doc.entities.tagAt(slot), '');
  expect(index.rootIndex.boxOfLeaf(slot).maxX, closeTo(before, 1e-9));

  doc.commands.redo();
  expect(doc.entities.textAt(slot), 'AAAAAAAA');
});
```

- [ ] **Step 2: Run and watch it fail**

Run: `cd packages/jet_cad_2d && dart test test/document/commands_test.dart`
Expected: FAIL — `SetEntityTextCommand` is undefined.

- [ ] **Step 3: Implement it, following `SetComponentCommand`'s shape**

```dart
/// Rewrites a text entity's content.
///
/// A string change changes the laid-out box, so this emits `touched` exactly as
/// a geometry edit does and the index re-derives the leaf through its
/// incremental path. Writing the column directly would leave a stale box.
class SetEntityTextCommand extends DraftCommand {
  SetEntityTextCommand(this.handle, this.text, this.tag);

  final Handle handle;
  final String text;
  final String tag;

  @override
  Capability get capability => Capability.geometry;

  @override
  String get label => 'Set text';

  @override
  CommandResult apply(CommandTarget target) {
    final slot = target.entities.slotOf(handle);
    if (slot == null) return CommandResult.rejected('no such entity: $handle');
    final previous = target.entities.read(slot);
    if (previous.kind != EntityKind.text && previous.kind != EntityKind.attrib) {
      return CommandResult.rejected('not a text entity: $handle');
    }
    target.entities
        .replace(slot, previous.copyWith(text: text, tag: tag));
    return CommandResult.applied(
      touched: {handle},
      inverse: SetEntityTextCommand(handle, previous.text, previous.tag),
    );
  }
}
```

Match `CommandResult`'s actual factory names and `DraftCommand`'s actual member
set by reading `command.dart` and one existing command before writing this.

- [ ] **Step 4: Run, then unskip the overlay test**

Run: `cd packages/jet_cad_2d && dart test test/document/commands_test.dart test/index/text_overlay_test.dart`
Expected: PASS both, including the overlay-equals-rebuild case.

- [ ] **Step 5: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "feat(jet_cad_2d): add SetEntityTextCommand with an index-dirtying inverse"
```

---

## Task 6: Text picks as `HitKind.fill`

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/index/spatial_index.dart:765-778`
- Modify: `packages/jet_cad_2d/test/invariants/reference_query.dart`
- Test: `packages/jet_cad_2d/test/index/pick_test.dart`

**Interfaces:**
- Consumes: Task 3's `textLocalBounds`/`textLocalTransform`, Task 4's bounds.
- Produces: text and attrib leaves report `HitKind.fill` when the query point is inside the laid-out box; the insertion point remains a `SnapKind.insertion` candidate and is no longer a pick candidate.

- [ ] **Step 1: Write the failing tests**

```dart
test('a pointer inside a text box hits it as a fill', () {
  // A label 'LONG ROOM NAME' at (0,0), height 200, left/baseline.
  final hit = HitPath();
  // Well inside the box and far from the insertion point.
  expect(index.pickInto(Vector2(400, 60), 1.0, const QueryFilter.picking(), hit),
      isTrue);
  expect(hit.kind, HitKind.fill);
  expect(hit.entity, textHandle);
});

test('a pointer near the insertion point is no longer a vertex hit', () {
  final hit = HitPath();
  index.pickInto(Vector2(-5, -5), 10.0, const QueryFilter.picking(), hit);
  expect(hit.kind, isNot(HitKind.vertex));
});

test('a point entity still picks as a vertex', () {
  // The switch case used to be shared; splitting it must not move `point`.
  final hit = HitPath();
  expect(index.pickInto(pointPos, 5.0, const QueryFilter.picking(), hit), isTrue);
  expect(hit.kind, HitKind.vertex);
});

test('the insertion point is still a snap candidate', () {
  final out = SnapResult();
  index.snapInto(Vector2(2, 2), 20.0, SnapMask.only(SnapKind.insertion), out);
  expect(out.found, isTrue);
  expect(out.kind, SnapKind.insertion);
});
```

- [ ] **Step 2: Run and watch them fail**

Run: `cd packages/jet_cad_2d && dart test test/index/pick_test.dart`
Expected: FAIL — the fill case returns nothing and the vertex case still fires.

- [ ] **Step 3: Split the shared case and test the box**

Replace the shared `point`/`text`/`attrib` case with `point` alone (unchanged),
plus a text case that transforms the query point into text-local space and tests
the box:

```dart
      case EntityKind.text:
      case EntityKind.attrib:
        // The laid-out box is the hit geometry (HitKind.fill); the insertion
        // point stays a snap candidate, not a pick candidate. Picking and
        // snapping are different questions.
        final record = document.entities.read(slot);
        final style = document.tables.textStyles[record.textStyle] ??
            document.tables.textStyles[ReservedHandles.standardTextStyle]!;
        final attrs =
            resolveTextAttributes(payload, record.textAttrs, style);
        final metrics =
            document.textMeasurer.measure(text: record.text, style: style);
        final local = textLocalTransform(attrs, metrics, payload.pointAt(0));
        // toLocal already maps world -> owner space; compose the text's own
        // inverse on top of it, then test the axis-aligned glyph box.
        final inv = local.inverted();
        final lx = inv.a * ownerX + inv.c * ownerY + inv.e;
        final ly = inv.b * ownerX + inv.d * ownerY + inv.f;
        final box = textLocalBounds(attrs, metrics);
        if (lx >= box.minX && lx <= box.maxX &&
            ly >= box.minY && ly <= box.maxY) {
          foundKind = HitKind.fill;
          foundX = world.x;
          foundY = world.y;
        }
```

The implementer must read the surrounding `_considerLeaf` to get the actual
local-coordinate variable names and the zero-allocation conventions — the six
raw transform coefficients are already in scope as fields there, and
`Transform2.inverted()` allocates, so cache the inverse per candidate the same
way the file caches other per-candidate state, or invert by hand into six
locals.

- [ ] **Step 4: Teach the brute-force reference the same rule**

`reference_query.dart` computes hits independently. Add the same box test there,
written from the metrics rather than copied from the index, so the differential
compares two implementations rather than one.

- [ ] **Step 5: Run pick, snap, differential and the allocation harness**

Run: `cd packages/jet_cad_2d && dart test`
Expected: PASS, including `test/invariants/differential_test.dart` and
`test/invariants/query_allocation_test.dart`. If the allocation test fails, the
inverse or the metrics are allocating per candidate — fix that, do not relax the
test.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "feat(jet_cad_2d): pick text by its laid-out box as HitKind.fill"
```

---

## Task 7: The corpus grows two text sources

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/testing/generate_document.dart`
- Test: `packages/jet_cad_2d/test/testing/generate_document_test.dart`

**Interfaces:**
- Consumes: Tasks 0-5.
- Produces: `generateDocument(..., double labelFraction = 0, double attributedInstanceFraction = 0)`.

- [ ] **Step 1: Write the failing tests**

```dart
test('both text fractions default to zero and change nothing', () {
  // The two fingerprints from Task 1's re-baseline still hold.
  expect(fingerprint(generateDocument(2000, definitionCount: 20)),
      <the Task 1 value>);
});

test('labelFraction produces repeating strings out of the root budget', () {
  final doc = generateDocument(2000, definitionCount: 20, labelFraction: 0.05);
  final labels = <String>{};
  var count = 0;
  for (final slot in doc.entities.liveSlots) {
    if (doc.entities.kindAt(slot) == EntityKind.text) {
      count++;
      labels.add(doc.entities.textAt(slot));
    }
  }
  expect(count, greaterThan(50));
  // Repeating, not unique: this is the distribution the cache hits.
  expect(labels.length, lessThanOrEqualTo(20));
});

test('attributedInstanceFraction gives each chosen instance a unique attrib',
    () {
  final doc = generateDocument(2000,
      definitionCount: 20, instanceCount: 100, attributedInstanceFraction: 0.5);
  final values = <String>[];
  for (final slot in doc.entities.liveSlots) {
    if (doc.entities.kindAt(slot) == EntityKind.attrib) {
      values.add(doc.entities.textAt(slot));
      // Owned by the instance node, in instance-local coordinates.
      expect(doc.tree[doc.entities.ownerAt(slot)], isA<InstanceNode>());
    }
  }
  expect(values.length, 50);
  expect(values.toSet().length, values.length);
});
```

- [ ] **Step 2: Run and watch them fail**

Run: `cd packages/jet_cad_2d && dart test test/testing/generate_document_test.dart`
Expected: FAIL — no such named parameters.

- [ ] **Step 3: Implement both, drawing from the existing shared stream**

Both extensions draw from `extra` (`generate_document.dart:96`,
`math.Random(0x5EEDED)`) and **draw nothing while they are off**. There is one
such stream, not one per extension, so turning `labelFraction` on shifts every
`attributedInstanceFraction` draw: the two fractions are **not** independently
reproducible, and a fixture names both together or neither. Record that in the
doc comment.

Labels come **out of** the root entity budget (so the total leaf count does not
move); attributes are **additive** leaves owned by their instance node, with
coordinates in instance-local space — DXF stores them already placed, and
`container_index.dart:208-210` transforms them by the instance's composed
transform, so writing world coordinates here would double-apply it.

```dart
const List<String> _kLabelVocabulary = <String>[
  'WC', 'KITCHEN', 'BAR', 'STORE', 'OFFICE', 'ENTRY', 'HALL', 'STAIR',
  'LIFT', 'TERRACE', 'PANTRY', 'CLOAK', 'PLANT', 'RISER', 'LOBBY',
  'CORRIDOR', 'SERVICE', 'DECK', 'GARDEN', 'ROOF',
];
```

- [ ] **Step 4: Run the suite**

Run: `cd packages/jet_cad_2d && dart test`
Expected: PASS, including both fingerprints at defaults and the structural
assertions beside them — one layer, **three linetypes**, every entity `ByLayer`
on layer zero.

- [ ] **Step 5: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "test(jet_cad_2d): add off-by-default label and attribute corpus extensions"
```

---

## Task 8: The sink learns one text op

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/draw_sink.dart`
- Modify: `packages/jet_cad_2d_flutter/lib/src/canvas_draw_sink.dart`
- Modify: `packages/jet_cad_2d_flutter/test/support/differential.dart`
- Test: `packages/jet_cad_2d_flutter/test/draw_sink_test.dart`

**Interfaces:**
- Consumes: nothing from Phase A.
- Produces: `void DrawSink.text(String text, Handle style, ResolvedStyle resolved)`; `TextOp(text, style, resolved)`; `flatten` emits `DrawnItem('text:$text', style, [origin, +x, +y])`.

- [ ] **Step 1: Write the failing test**

```dart
test('a text op records its string, style handle and resolved style', () {
  final sink = RecordingDrawSink()
    ..beginResidual(Transform2.translation(10, 20))
    ..text('WC', const Handle(7), _resolved)
    ..endResidual();
  expect(sink.ops[1], TextOp('WC', const Handle(7), _resolved));
});

test('flatten turns a text op into an origin and two unit images', () {
  final items = flatten(<DrawOp>[
    BeginResidualOp(Transform2(2, 0, 0, 2, 100, 200)),
    TextOp('WC', const Handle(7), _resolved),
    const EndResidualOp(),
  ]);
  expect(items.single.kind, 'text:WC');
  expect(items.single.points[0], _v(100, 200));
  expect(items.single.points[1], _v(102, 200));
  expect(items.single.points[2], _v(100, 202));
});
```

- [ ] **Step 2: Run and watch it fail**

Run: `cd packages/jet_cad_2d_flutter && flutter test test/draw_sink_test.dart`
Expected: FAIL — `text` is not a member of `RecordingDrawSink`.

- [ ] **Step 3: Add the op**

`DrawSink.text(String text, Handle style, ResolvedStyle resolved)`, drawn at the
**local origin** — the painter pushes `residual ∘ textLocal`, so no offset and
no second matrix are needed. `TextOp` with value equality over all three fields;
`RecordingDrawSink` appends it; `NullDrawSink` counts it.

`CanvasDrawSink.text` resolves the paragraph through Task 9's cache and calls
`canvas.drawParagraph(paragraph, Offset.zero)` after the existing
`_pushTransform()`. Until Task 9 lands, implement it as
`throw UnimplementedError('Task 9 supplies the paragraph cache')` and leave the
painter not calling it — the two tasks commit separately and neither leaves the
suite red.

- [ ] **Step 4: Flatten it**

```dart
      case TextOp(:final text, :final style, :final resolved):
        // Three points, not one: the origin plus the images of the local unit
        // vectors, so `kScreenTolerance` covers scale, rotation and shear with
        // the machinery already here. The string rides in `kind`, which
        // compares exactly.
        out.add(DrawnItem('text:$text', resolved, [
          residual.transformPoint(Vector2.zero()),
          residual.transformPoint(Vector2(1, 0)),
          residual.transformPoint(Vector2(0, 1)),
        ]));
```

- [ ] **Step 5: Run and commit**

Run: `cd packages/jet_cad_2d_flutter && flutter test`
Expected: PASS.

```bash
git add packages/jet_cad_2d_flutter
git commit -m "feat(jet_cad_2d_flutter): add a text op to the draw sink and the oracle"
```

---

## Task 9: `FlutterTextMeasurer` and the paragraph cache

**Files:**
- Create: `packages/jet_cad_2d_flutter/lib/src/flutter_text_measurer.dart`
- Modify: `packages/jet_cad_2d_flutter/lib/src/canvas_draw_sink.dart`
- Modify: `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart`
- Test: `packages/jet_cad_2d_flutter/test/flutter_text_measurer_test.dart`

**Interfaces:**
- Consumes: `TextMetrics`, `TextMeasurer`, `kNominalTextPixels`, `kCapHeightRatio`.
- Produces: `FlutterTextMeasurer implements TextMeasurer` with `Paragraph paragraphFor(String text, Handle styleHandle, TextStyleRecord style, int argb)`, `int get layoutCount`, `int get evictionCount`, `int get liveParagraphCount`, `void clear()`; `const int kParagraphCacheLimit = 512`.

- [ ] **Step 1: Write the failing tests**

```dart
test('the same string in two colours is two entries, not one', () {
  final m = FlutterTextMeasurer();
  m.paragraphFor('WC', const Handle(7), _style, 0xFFFF0000);
  m.paragraphFor('WC', const Handle(7), _style, 0xFF00FF00);
  // ui.Paragraph bakes its colour and drawParagraph takes no Paint, so a key
  // without argb would draw one of these in the wrong colour.
  expect(m.layoutCount, 2);
  expect(m.liveParagraphCount, 2);
});

test('a repeat request lays out nothing and allocates no metrics', () {
  final m = FlutterTextMeasurer();
  final a = m.measure(text: 'WC', style: _style);
  final before = m.layoutCount;
  final b = m.measure(text: 'WC', style: _style);
  expect(m.layoutCount, before);
  // The pick path measures per candidate; a fresh object per call breaks
  // query_allocation_test.
  expect(identical(a, b), isTrue);
});

test('eviction disposes the paragraph', () {
  final m = FlutterTextMeasurer(limit: 2);
  m.paragraphFor('A', const Handle(7), _style, 0xFF000000);
  m.paragraphFor('B', const Handle(7), _style, 0xFF000000);
  m.paragraphFor('C', const Handle(7), _style, 0xFF000000);
  expect(m.evictionCount, 1);
  expect(m.liveParagraphCount, 2);
  // A Paragraph holds native glyph memory: a bound on the count is not a
  // bound on the memory unless eviction releases it.
  expect(m.debugLastEvicted!.debugDisposed, isTrue);
});

test('metrics are cap-height based and taken at the nominal size', () {
  final m = FlutterTextMeasurer();
  final metrics = m.measure(text: 'WC', style: _style);
  expect(metrics.capHeight, closeTo(kCapHeightRatio * kNominalTextPixels, 1e-9));
  expect(metrics.ascent, greaterThan(0));
  expect(metrics.advanceWidth, greaterThan(0));
});
```

- [ ] **Step 2: Run and watch it fail**

Run: `cd packages/jet_cad_2d_flutter && flutter test test/flutter_text_measurer_test.dart`
Expected: FAIL — `FlutterTextMeasurer` is undefined.

- [ ] **Step 3: Implement it**

Key: a value class over `(String text, Handle style, int argb)` with `==` and
`hashCode`. Entry: `(Paragraph paragraph, TextMetrics metrics)`. LRU: a
`LinkedHashMap` with remove-and-reinsert on hit, `limit` default
`kParagraphCacheLimit = 512`, and `paragraph.dispose()` on eviction.

Layout is always at `kNominalTextPixels`:

```dart
    final builder = ParagraphBuilder(ParagraphStyle(
      fontFamily: style.fontFamily,
      fontSize: kNominalTextPixels,     // never the effective height
      textAlign: TextAlign.left,
    ))
      ..pushStyle(TextStyle(color: Color(argb), fontFamily: style.fontFamily,
          fontSize: kNominalTextPixels))
      ..addText(text);
    final paragraph = builder.build()
      ..layout(const ParagraphConstraints(width: double.infinity));
    final lines = paragraph.computeLineMetrics();
    final metrics = TextMetrics(
      advanceWidth: paragraph.longestLine,
      ascent: lines.isEmpty ? 0 : lines.first.ascent,
      descent: lines.isEmpty ? 0 : lines.first.descent,
      // dart:ui exposes no cap height; the declared ratio stands in for it and
      // the deviation is recorded in the results note.
      capHeight: kCapHeightRatio * kNominalTextPixels,
    );
```

`measure()` needs an `argb` for the key it shares with drawing. Use a single
declared `kMetricsProbeArgb = 0xFF000000` for metric-only requests and document
why: colour cannot change metrics, so a metrics request reuses the black entry
rather than adding one per colour.

Then implement `CanvasDrawSink.text` properly: `_pushTransform()`, then
`canvas.drawParagraph(measurer.paragraphFor(...), Offset.zero)`. The sink needs
the measurer, so add it as a constructor parameter alongside `pixelsPerPaperMm`
and thread it from `DraftCanvas`.

- [ ] **Step 4: Run and commit**

Run: `cd packages/jet_cad_2d_flutter && flutter test && flutter analyze`

```bash
git add packages/jet_cad_2d_flutter
git commit -m "feat(jet_cad_2d_flutter): lay text out once at nominal size behind an LRU"
```

---

## Task 10: The painter draws text

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart`
- Modify: `packages/jet_cad_2d_flutter/lib/src/reference_walk.dart`
- Modify: `packages/jet_cad_2d_flutter/test/draft_painter_root_test.dart:287-289`
- Test: `packages/jet_cad_2d_flutter/test/text_paint_test.dart` (create)

**Interfaces:**
- Consumes: Tasks 3, 8, 9.
- Produces: `DraftPainter.skippedTextCount` still exists but reaches 0 on a text corpus; text is drawn under `residual ∘ textLocal`.

- [ ] **Step 1: Write the failing tests**

```dart
test('a text leaf draws one text op under its own composed residual', () {
  final run = paintOnce(_docWithOneLabel(), RecordingDrawSink());
  final ops = run.sink.ops;
  expect(ops.whereType<TextOp>().length, 1);
  expect(run.painter.skippedTextCount, 0);
});

test('the reference walk and the painter agree with text on', () {
  // The differential oracle, over a corpus that actually contains text.
  expectSamePicture(
      textRigCorpus(2000), workingSetCamera, wholeDrawingCamera);
});

test('text inside a mirrored instance is drawn mirrored, not corrected', () {
  final run = paintOnce(_docWithMirroredLabel(), RecordingDrawSink());
  final residual = run.sink.ops.whereType<BeginResidualOp>().last.residual;
  // v1 renders text faithfully mirrored: the determinant stays negative.
  expect(residual.a * residual.d - residual.b * residual.c, lessThan(0));
});
```

- [ ] **Step 2: Run and watch them fail**

Run: `cd packages/jet_cad_2d_flutter && flutter test test/text_paint_test.dart`
Expected: FAIL — no `TextOp` is emitted; `skippedTextCount` is 1.

- [ ] **Step 3: Replace the skip with a draw**

```dart
      case EntityKind.text:
      case EntityKind.attrib:
        final style = _styleRecordFor(record.textStyle);
        final attrs = resolveTextAttributes(payload, record.textAttrs, style);
        final metrics =
            document.textMeasurer.measure(text: record.text, style: style);
        if (record.text.isEmpty) {
          _skippedText++;   // nothing to draw; still counted
          break;
        }
        // The sink's contract is local coordinates under a pushed residual,
        // so the text's own transform composes into the residual rather than
        // travelling as an offset.
        sink
          ..beginResidual(chain.residual
              .multiply(textLocalTransform(attrs, metrics, payload.pointAt(0))))
          ..text(record.text, record.textStyle, style_)
          ..endResidual();
```

Read the surrounding code for the actual residual variable and the resolved
style local; the painter already has both. Mirror the same change into
`reference_walk.dart` — independently written, same rule.

- [ ] **Step 4: Fix the two assertions that flip**

`draft_painter_root_test.dart:287` asserts `skippedTextCount > 0` and `:289`
folds it into a count identity. Both change: on the default corpus text now
draws, so the count is 0 and the identity drops the term. Change them
deliberately, in this commit, with a comment naming Plan 3c.

- [ ] **Step 5: Run everything**

Run: `cd packages/jet_cad_2d_flutter && flutter test && flutter analyze`
Expected: PASS, including `differential_test.dart` with text present.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d_flutter
git commit -m "feat(jet_cad_2d_flutter): draw text instead of counting it"
```

---

## Task 11: Goldens — the attribute ladder and the mirror

**Files:**
- Create: `packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart`
- Create: five PNGs under `test/golden/`

**Interfaces:**
- Consumes: Tasks 9 and 10.
- Produces: `text_ladder_1..5.png`.

- [ ] **Step 1: Write the ladder**

Five rungs, each a small document rendered at a fixed viewport:

1. horizontal justification: left, centre, right, middle, all sharing one anchor
2. vertical justification: baseline, bottom, middle, top, all sharing one anchor
3. rotation: 0, 0.4, 1.2, -0.9 radians
4. width factor 0.5/1/2 and oblique 0/0.3 **crossed** — the pair that pins the
   composition order, since either alone commutes
5. one mirrored instance containing a label, next to the same label unmirrored

- [ ] **Step 2: Generate and review**

Run: `cd packages/jet_cad_2d_flutter && flutter test --update-goldens test/golden/text_ladder_golden_test.dart`
Then **look at all five PNGs**. Check: no glyph is clipped, the crossed rung's
slanted-then-widened glyphs are wider at the same slope rather than more slanted,
and rung 5's mirrored label reads backwards. A golden accepted without being
looked at pins whatever bug produced it.

- [ ] **Step 3: Run the golden tag and commit**

Run: `cd packages/jet_cad_2d_flutter && flutter test --tags golden`
Expected: PASS, including the pre-existing stroke-width and dash-ladder
goldens, **with no existing PNG regenerated**.

```bash
git add packages/jet_cad_2d_flutter/test/golden
git commit -m "test(jet_cad_2d_flutter): pin text justification, rotation and mirroring as goldens"
```

---

## Task 12: Rigs, counters, and the number the gate depends on

**Files:**
- Modify: `packages/jet_cad_2d_flutter/test/rig/rig_support.dart`
- Modify: `packages/jet_cad_2d_flutter/test/rig/paint_microbench_test.dart`
- Modify: `apps/dev_harness_2d/integration_test/frame_timing_test.dart`

**Interfaces:**
- Consumes: everything above.
- Produces: `DraftDocument textRigCorpus(int entityCount)`; rig output lines for layout count, eviction count, live paragraphs, text ops, and **distinct visible cache keys at the working-set camera**.

- [ ] **Step 1: Add `textRigCorpus` beside `rigCorpus`**

```dart
/// `rigCorpus` plus text. A separate function, not a flag on `rigCorpus`:
/// `labelFraction` comes out of the root budget, so switching it on inside
/// `rigCorpus` would move the line, polyline, circle and arc counts and retire
/// Plan 3b's dash and canvas-call baselines as a side effect.
DraftDocument textRigCorpus(int entityCount) => generateDocument(
      entityCount,
      definitionCount: kDefinitionCount,
      instanceCount: kInstanceCount,
      nestingDepth: 2,
      mirroredFraction: 0.1,
      nonUniformFraction: 0.2,
      groupCount: 50,
      layerCount: 8,
      byBlockFraction: 0.3,
      dashedFraction: 0.35,
      labelFraction: 0.02,
      attributedInstanceFraction: 0.2,
    );
```

- [ ] **Step 2: Measure the number the gate's feasibility rests on**

Add a rig case that walks the working-set camera once over
`textRigCorpus(50000)` and prints the count of **distinct
`(string, style, argb)` keys** drawn, then the same for the whole-drawing
camera.

Run it. If the working-set count exceeds `kParagraphCacheLimit`, the
zero-new-layouts gate row cannot pass by construction. **Do not relax the row.**
Record the count, then either raise the limit to the measured working-set count
rounded up, or lower `attributedInstanceFraction`, and write down which and why.

- [ ] **Step 3: Report the counters from every rig**

Extend the printed lines with layout count, eviction count, live paragraphs and
text ops per frame, at both cameras, and the same rows with text drawing
disabled so the on/off delta is one flag apart on one corpus.

- [ ] **Step 4: Commit**

```bash
git add packages/jet_cad_2d_flutter apps/dev_harness_2d
git commit -m "test: add textRigCorpus and report the text counters from every rig"
```

---

## Task 13: Mutation testing

**Files:**
- Create: `docs/superpowers/notes/plan-3c-mutation-log.md`

**Interfaces:**
- Consumes: every test above.
- Produces: one log row per mutant, each killed or argued equivalent.

- [ ] **Step 1: Run the mutants from the spec's table, one at a time**

For each: edit the named expression, run the narrowest suite that should catch
it, record which test failed and how, then `git checkout --` the file and
confirm `git status --short` is empty before the next one.

The sixteen mutants are the spec's table. Three deserve care because they are
the ones a green suite most plausibly misses:

- **Lay the paragraph out at the effective em size** instead of nominal. Renders
  correctly. Only the zero-layout row and the cache-entry count can see it — if
  nothing fails, add the assertion that makes it fail before moving on.
- **Allocate a fresh `TextMetrics` on a cache hit.** Must be caught by
  `query_allocation_test`.
- **Drop `argb` from the cache key.** Must be caught by
  `flutter_text_measurer_test` and visibly by a colour golden.

- [ ] **Step 2: Write the log**

Same shape as `plan-3b-mutation-log.md`: mutant, expression, suite, killing
test, and a "Reproducing" section naming the exact commands.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/notes/plan-3c-mutation-log.md
git commit -m "docs: record Plan 3c's mutation log"
```

---

## Task 14: Exit gate and the results note

**Files:**
- Create: `docs/superpowers/notes/2026-08-1X-plan-3c-results.md`

- [ ] **Step 1: Run every check**

| Check | Command | Threshold |
|---|---|---|
| engine suite | `cd packages/jet_cad_2d && dart test` | all pass |
| engine analyze/format | `dart analyze && dart format --output=none --set-exit-if-changed .` | clean |
| widget suite | `cd packages/jet_cad_2d_flutter && flutter test` | all pass |
| goldens | `flutter test --tags golden` | all pass, no existing PNG regenerated |
| widget analyze/format | `flutter analyze && dart format --output=none --set-exit-if-changed .` | clean |
| harness analyze | `cd apps/dev_harness_2d && flutter analyze` | clean |
| allocation harness | `cd packages/jet_cad_2d && dart test test/invariants/query_allocation_test.dart` | zero allocation with text in the corpus |
| query throughput | `dart run benchmark/query_throughput.dart` | unchanged in shape; `snap at dirty threshold` is the **known** carried failure from Plan 2 |
| rigs | `flutter test --tags rig --run-skipped`, then `flutter drive --profile -d macos` for the frame rows | recorded |

- [ ] **Step 2: Check the failable criteria**

| Criterion | Threshold |
|---|---|
| repeat frame at the working-set camera | zero new paragraph layouts |
| evictions per repeat frame at the working-set camera | zero |
| peak live paragraphs | <= the declared limit |
| `skippedTextCount` on `textRigCorpus` | 0 |
| differential and non-vacuity, text on | pass |
| reference-query differential, text picking | pass |
| overlay-equals-rebuild for an edited text | pass |
| mutation log | every mutant killed or argued equivalent |

- [ ] **Step 3: Write the note**

Record, with scope named: text's time cost on `textRigCorpus` at both sizes and
both cameras, the on/off delta, cache hit rate **split by source** (repeating
labels against unique attributes), the whole-drawing thrash numbers as input to
3e's LOD decision, the distinct-visible-key count from Task 12, the
`kCapHeightRatio` deviation, and **whether macOS Low Power Mode was on** —
Plan 3b's numbers were contaminated by it and every `flutter drive` figure needs
the flag stated.

- [ ] **Step 4: If a failable row misses, record it and stop**

3b's Task 4 stop clause is the precedent: a row that fires is a result. Write
the number, say what it implies for 3d and 3e, and stop rather than tuning until
it complies.

- [ ] **Step 5: Finish the branch**

Use **superpowers:finishing-a-development-branch**: verify the suite, detect the
environment, present the integration options, act on the choice.

---

## Self-Review

**Spec coverage.** Two string columns, the style handle and the packed word →
Task 0. Codec, schema 4, defensive scalars, fingerprint re-baseline → Task 1.
`TextMetrics` taking the record, the three measurers, the metrics-allocation rule
→ Task 2. `text_geometry.dart`, cap height, composition order, the aligned/fit
fallback in the resolver, 72=4 → Task 3. All four `entityBounds` call sites and
the overlay-equals-rebuild test → Task 4. `SetEntityTextCommand` with index
dirtying → Task 5. `HitKind.fill`, the split `point` case, the reference query →
Task 6. `labelFraction`, `attributedInstanceFraction`, the shared `Random`
consequence, the structural guard → Task 7. The text op and the three-point
flattening → Task 8. The `(string, style, argb)` LRU with dispose → Task 9. The
painter and the two flipped assertions → Task 10. Goldens → Task 11. Rigs and the
distinct-key measurement → Task 12. Mutants → Task 13. Gate and note → Task 14.

**Deliberately not covered, per the spec's non-goals:** MTEXT, 72=3/72=5 layout
and their second point, text LOD, entity-level unknown-key preservation, fills,
the picture cache.

**Type consistency.** `resolveTextAttributes(GeometryPayload, int, TextStyleRecord)`,
`textLocalTransform(ResolvedTextAttributes, TextMetrics, Vector2)`,
`textLocalBounds(ResolvedTextAttributes, TextMetrics)`,
`measure({required String text, required TextStyleRecord style})`,
`text(String, Handle, ResolvedStyle)` and
`entityBounds({kind, payload, measurer, textStyle: TextStyleRecord, textAttrs, text})`
are spelled the same in every task that uses them.

**Two ordering hazards, called out where they occur.** Task 4's overlay test needs
Task 5's command, so it is written skipped and unskipped in Task 5. Task 8's
`CanvasDrawSink.text` needs Task 9's cache, so it throws `UnimplementedError`
until Task 9 and the painter does not call it until Task 10.
