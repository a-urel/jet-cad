# Plan 3f.1 — Hardening Before the Picture Cache: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the two model defects that would otherwise become Plan 3g's cache key, turn the machine-independent rig counters into always-on assertions, and either give the Flutter package a working allocation meter or prove it cannot have one.

**Architecture:** Three independent sections. Section 1 (Tasks 1–4) adds four style fields to `InstanceNode`, resolves them in `DocumentStyleResolver.contextFor`, connects `StyleContext.linetypeScale` to `styleFor`, and bumps the on-disk schema to 6 with a defaults-when-absent migration. Section 2 (Tasks 5–6) adds two always-on invariant test files under `test/invariants/` in the Flutter package, sized by the bound under test rather than by realism, and leaves the rig untouched. Section 3 (Task 7) moves `AllocationMeter` into `lib/src/testing/` and probes it under `flutter test`, with a pre-committed stop clause. Task 8 is the exit gate.

**Tech Stack:** Dart 3.13 / Flutter 3.47.x, `package:test`, `flutter_test`, `package:vm_service`. Pure-Dart engine in `packages/jet_cad_2d`, render layer in `packages/jet_cad_2d_flutter`.

**Spec:** [docs/superpowers/specs/2026-08-23-jet-cad-2d-plan-3f1-hardening-design.md](../specs/2026-08-23-jet-cad-2d-plan-3f1-hardening-design.md)

**Working arrangement:** directly on `main` in `/Users/ahmeturel/Projects/oss/jet-cad`, **no worktree** — the same arrangement Plans 3e and 3f used, on the human's explicit consent. The SDD ledger lives at `.superpowers/sdd/2026-08-23-jet-cad-2d-plan-3f1-hardening/` and is archived to `docs/superpowers/ledgers/` when the plan completes.

## Global Constraints

- **The frame path allocates nothing per entity in steady state, and O(1) per flush.** `packages/jet_cad_2d/test/invariants/query_allocation_test.dart` and `packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart` measure it.
- **Draw order is ascending handle value**, stable across undo, save, load and purge.
- **Geometric *decisions* use `Tolerance`; *stored value* comparisons are exact `==`.**
- **Never commit `analysis_options.yaml`** — `flutter pub get` rewrites three of them in this workspace.
- **Never synthesize test output.** Reviewers verify claims independently; a fabricated transcript invalidates the task.
- **Never `git checkout` a file to revert a mutation.** Copy the file aside, mutate, then restore from the copy. The single sanctioned exception is `apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj`, which `flutter drive` rewrites.
- Code, comments and commit messages in English.
- **This plan may not amend `CLAUDE.md`.** A gate passable by editing the rule it is measured against is not a gate.
- **`unused_import` is an error** in `packages/jet_cad_2d_flutter/analysis_options.yaml`. An unused import is a hard failure, not a lint.
- **Prefix every test command with `CI=true`.** Without it, Dart's analytics phone-home can block `dart test` / `flutter test` for minutes at ~0% CPU.

### The anti-degenerate rule — binding, with the force of a criterion

- **No test written by this plan uses `linetypeScale: 1.0`.** Fifty-four lines in this repository already do, and none of them could see that `StyleContext.linetypeScale` was read by nothing.
- **No instance fixture written by this plan leaves all four new fields at their defaults.** Decision 5 of the spec makes the defaults bit-identical to today's behaviour, so a fixture at the defaults proves nothing.
- **Every Section 1 criterion is exercised by a fixture where the property under test differs between the instance, the layer record, layer 0's record, and `StyleContext.documentRoot`** — so a resolution that reads the wrong one of the four lands on a different number.

### Every task ends green

```sh
cd packages/jet_cad_2d            && CI=true dart test    && dart analyze    && dart format --output=none --set-exit-if-changed .
cd packages/jet_cad_2d_flutter    && CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

---

## File Structure

**Engine — `packages/jet_cad_2d`**

| file | responsibility | task |
|---|---|---|
| `lib/src/document/node.dart` | `InstanceNode` gains four style fields, JSON, `==`, `hashCode` | 1 |
| `lib/src/codec/schema_version.dart` | `kSchemaVersion` 5 → 6, v6 entry, stale `:103` cite fixed | 1 |
| `lib/src/document/style_resolver.dart` | `contextFor` resolves the three sentinel fields (Task 2); `linetypeScale` multiplies on both sides (Task 3) | 2, 3 |
| `test/document/instance_style_test.dart` | **new** — criteria 1–8 | 2, 3 |
| `test/codec/instance_style_codec_test.dart` | **new** — criteria 9, 10 | 1, 4 |
| `lib/src/testing/allocation_meter.dart` | **moved** from `test/invariants/vm_allocation_meter.dart` | 7 |
| `lib/testing.dart` | exports the meter | 7 |
| `pubspec.yaml` | `vm_service` dev_dependency → dependency | 7 |

**Render layer — `packages/jet_cad_2d_flutter`**

| file | responsibility | task |
|---|---|---|
| `test/support/text_key_sink.dart` | **new** — `TextKeySink`, moved out of the rig | 5 |
| `test/rig/rig_support.dart` | imports `TextKeySink` instead of declaring it | 5 |
| `test/invariants/text_cache_invariants_test.dart` | **new** — criteria 12, 13 | 5 |
| `test/invariants/frame_accounting_test.dart` | **new** — criteria 14, 15, 16 | 6 |
| `test/invariants/allocation_meter_probe_test.dart` | **new** — criterion 17 | 7 |

**Notes**

| file | responsibility | task |
|---|---|---|
| `docs/superpowers/notes/2026-08-23-plan-3f1-results.md` | the seventeen criteria, scored | 8 |
| `docs/superpowers/notes/plan-3f1-mutation-log.md` | the seventeen mutants, with transcripts | 8 |
| `STATUS.md` | 3f.1 recorded, 3g's inheritance updated | 8 |

---

## Task 1: `InstanceNode` gains four style fields, and the schema bumps to 6

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/document/node.dart:152-241`
- Modify: `packages/jet_cad_2d/lib/src/codec/schema_version.dart`
- Create: `packages/jet_cad_2d/test/codec/instance_style_codec_test.dart`

**Interfaces:**
- Produces: `InstanceNode({..., int lineweight = kByBlock, int transparency = kByBlock, Handle linetype = ReservedHandles.byBlockLinetype, double linetypeScale = 1.0})`, the same four names on `copyWith`, and the JSON keys `'lineweight'`, `'transparency'`, `'linetype'`, `'linetypeScale'`. Tasks 2, 3 and 4 read these fields; Task 4 reads the JSON shape.
- Consumes: nothing.

**Why the defaults are what they are.** `kByBlock` and `ReservedHandles.byBlockLinetype` mean "inherit from whatever places me", which reproduces today's pass-through exactly; `1.0` is the multiplicative identity. Together they make this task a behavioural no-op, which is why it can land before Task 2 without moving a single existing test.

- [ ] **Step 1: Write the failing round-trip test**

Create `packages/jet_cad_2d/test/codec/instance_style_codec_test.dart`:

```dart
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

/// A placement whose four style fields are all non-default.
///
/// Every value is chosen to differ from the field's own default, from
/// `StyleContext.documentRoot`'s value, and from every other field's value —
/// so a round-trip that transposes two keys, or drops one to its default,
/// lands on a number no assertion here expects. `linetypeScale` is 4.0 and
/// not 1.0: this plan's anti-degenerate rule forbids the identity, because
/// the identity is what hid the severed channel for fifty-four fixtures.
InstanceNode styledInstance() => InstanceNode(
      handle: const Handle(300),
      parent: const Handle(1),
      transform: Transform2.translation(17, 23),
      definition: const Handle(200),
      layer: const Handle(100),
      color: const IndexedColor(3),
      lineweight: 211,
      transparency: 137,
      linetype: const Handle(42),
      linetypeScale: 4.0,
    );

void main() {
  test('an instance round-trips all four style fields at non-default values',
      () {
    final node = styledInstance();
    final back = InstanceNode.fromJson(node.toJson());

    expect(back.lineweight, 211);
    expect(back.transparency, 137);
    expect(back.linetype, const Handle(42));
    // A stored value, so the comparison is exact. `Tolerance` is for
    // geometric decisions, never for a number read back off disk.
    expect(back.linetypeScale, 4.0);
    expect(back, node);
  });

  test('the four fields are absent-tolerant and default to the no-op values',
      () {
    // A v5 document's instance node, verbatim: the four keys do not exist.
    final v5 = <String, Object?>{
      'type': 'instance',
      'handle': const Handle(300).toJson(),
      'parent': const Handle(1).toJson(),
      'transform': Transform2.identity().toJson(),
      'visible': true,
      'definition': const Handle(200).toJson(),
      'layer': const Handle(100).toJson(),
      'color': encodeColor(const IndexedColor(3)),
    };
    final back = InstanceNode.fromJson(v5);

    // BYBLOCK, BYBLOCK, BYBLOCK-linetype and the multiplicative identity: the
    // four values that make `contextFor` reproduce its pre-3f.1 behaviour
    // exactly. Any other default silently changes how every existing document
    // renders.
    expect(back.lineweight, kByBlock);
    expect(back.transparency, kByBlock);
    expect(back.linetype, ReservedHandles.byBlockLinetype);
    expect(back.linetypeScale, 1.0);
  });

  test('two instances differing only in linetypeScale are not equal', () {
    // `==` and `hashCode` are the picture cache key's foundation in Plan 3g.
    // A field left out of either makes two different placements collide.
    final a = styledInstance();
    final b = a.copyWith(linetypeScale: 8.0);
    expect(a == b, isFalse);
    expect(a.hashCode == b.hashCode, isFalse);
  });

  test('the schema this build writes is 6', () {
    expect(kSchemaVersion, 6);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```sh
cd packages/jet_cad_2d && CI=true dart test test/codec/instance_style_codec_test.dart
```

Expected: compile failure — `InstanceNode` has no named parameter `lineweight`.

- [ ] **Step 3: Add the four fields to `InstanceNode`**

In `lib/src/document/node.dart`, after the `color` field (currently line 163), add:

```dart
  /// This instance's own lineweight, imposed on its definition's BYBLOCK
  /// contents.
  ///
  /// Encoded exactly as `EntityRecord.lineweight` is — `kByBlock` (the
  /// default), `kByLayer`, `kLineweightDefault`, or a concrete value in
  /// 1/100 mm. A second encoding for the same concept would be a second thing
  /// to keep in step, and `DocumentStyleResolver` would need two switches
  /// where it now needs one shape.
  final int lineweight;

  /// 0..255, or `kByBlock` (the default) or `kByLayer`. Same encoding as
  /// `EntityRecord.transparency`.
  final int transparency;

  /// `ReservedHandles.byBlockLinetype` (the default),
  /// `ReservedHandles.byLayerLinetype`, or a concrete linetype handle. Same
  /// encoding as `EntityRecord.linetype`.
  final Handle linetype;

  /// **Multiplies; it does not substitute.**
  ///
  /// DXF's rule for a nested entity's effective linetype scale is a product,
  /// not an override, so an entity inside two INSERTs is scaled by both and by
  /// the header's global scale. The other three fields above answer "which
  /// value wins"; this one answers "by how much", and there is no sentinel
  /// because there is nothing to defer to — `1.0` already means "impose
  /// nothing".
  final double linetypeScale;
```

Extend the constructor:

```dart
  const InstanceNode({
    required super.handle,
    required super.parent,
    required super.transform,
    required this.definition,
    required this.layer,
    this.color = const ByBlockColor(),
    this.lineweight = kByBlock,
    this.transparency = kByBlock,
    this.linetype = ReservedHandles.byBlockLinetype,
    this.linetypeScale = 1.0,
    super.visible = true,
  });
```

Extend `copyWith`:

```dart
  InstanceNode copyWith({
    Handle? handle,
    Handle? parent,
    Transform2? transform,
    bool? visible,
    Handle? definition,
    Handle? layer,
    DraftColor? color,
    int? lineweight,
    int? transparency,
    Handle? linetype,
    double? linetypeScale,
  }) =>
      InstanceNode(
        handle: handle ?? this.handle,
        parent: parent ?? this.parent,
        transform: transform ?? this.transform,
        visible: visible ?? this.visible,
        definition: definition ?? this.definition,
        layer: layer ?? this.layer,
        color: color ?? this.color,
        lineweight: lineweight ?? this.lineweight,
        transparency: transparency ?? this.transparency,
        linetype: linetype ?? this.linetype,
        linetypeScale: linetypeScale ?? this.linetypeScale,
      );
```

- [ ] **Step 4: Extend the JSON on both sides**

In the same file, `toJson` gains four keys:

```dart
  @override
  Map<String, Object?> toJson() => {
        'type': 'instance',
        'handle': handle.toJson(),
        'parent': parent.toJson(),
        'transform': transform.toJson(),
        'visible': visible,
        'definition': definition.toJson(),
        'layer': layer.toJson(),
        'color': encodeColor(color),
        'lineweight': lineweight,
        'transparency': transparency,
        'linetype': linetype.toJson(),
        'linetypeScale': linetypeScale,
      };
```

`fromJson` defaults all four when absent, with the same argument the `color`
field's existing comment makes:

```dart
        color: json['color'] == null
            ? const ByBlockColor()
            : decodeColor(json['color']! as int),
        // Absent in v5 and earlier. BYBLOCK for the three sentinel fields and
        // 1.0 for the scale are the correct defaults for the same reason
        // BYBLOCK was correct for `color`: they are no-ops. `contextFor`
        // reduces to the pass-through it performed before this field existed,
        // so a v5 document resolves bit-identically under a v6 build.
        //
        // BYLAYER would not be a no-op. It would make every pre-3f.1 INSERT
        // start imposing its layer's linetype on its definition's BYBLOCK
        // contents, silently changing how existing drawings render.
        lineweight: json['lineweight'] == null
            ? kByBlock
            : json['lineweight']! as int,
        transparency: json['transparency'] == null
            ? kByBlock
            : json['transparency']! as int,
        linetype: json['linetype'] == null
            ? ReservedHandles.byBlockLinetype
            : Handle.fromJson(json['linetype']),
        linetypeScale: json['linetypeScale'] == null
            ? 1.0
            : (json['linetypeScale']! as num).toDouble(),
```

Extend `operator ==` and `hashCode`:

```dart
  @override
  bool operator ==(Object other) =>
      other is InstanceNode &&
      other.handle == handle &&
      other.parent == parent &&
      other.transform
          .equals(transform, const Tolerance(linear: 0, angular: 0)) &&
      other.visible == visible &&
      other.definition == definition &&
      other.layer == layer &&
      other.color == color &&
      other.lineweight == lineweight &&
      other.transparency == transparency &&
      other.linetype == linetype &&
      // Exact, not tolerant: a stored value, and Plan 3g will key a picture
      // cache on it.
      other.linetypeScale == linetypeScale;

  @override
  int get hashCode => Object.hash(handle, parent, visible, definition, layer,
      color, lineweight, transparency, linetype, linetypeScale);
```

- [ ] **Step 5: Bump the schema and fix the stale citation**

In `lib/src/codec/schema_version.dart`, add the v6 entry above the constant and
change the constant:

```dart
/// 6: `InstanceNode.toJson` gained `lineweight`, `transparency`, `linetype`
/// and `linetypeScale`; `fromJson` defaults all four to their no-op values
/// (BYBLOCK, BYBLOCK, BYBLOCK-linetype, 1.0) when absent, which is the whole
/// of the v5->v6 migration. The bump exists for the **reader**: without it a
/// v5 build would load a v6 file, silently drop four fields, and render a
/// different drawing. With it, that build refuses the file and says why.
const int kSchemaVersion = 6;
```

In the same file, line 14 cites the version guard at `json_codec.dart:103`; it
is at `:104`. Fix the citation while the file is open.

- [ ] **Step 6: Run the new test and the full engine suite**

```sh
cd packages/jet_cad_2d && CI=true dart test test/codec/instance_style_codec_test.dart
CI=true dart test && dart analyze && dart format --output=none --set-exit-if-changed .
```

Expected: the four new tests PASS; the pre-existing suite is unchanged and
green. **If any pre-existing test moves, stop** — the defaults are supposed to
be a no-op, and a moved test means one of them is not.

- [ ] **Step 7: Fire mutants M10 and M11**

Copy the file aside first — `cp lib/src/document/node.dart /tmp/node.dart.bak`
— and restore from the copy, never with `git checkout`.

**M11:** delete the `'linetypeScale': linetypeScale,` line from `toJson`.
Expected: `an instance round-trips all four style fields at non-default values`
goes red on `expect(back.linetypeScale, 4.0)`.

**M10:** change `fromJson`'s absent-`linetype` default from
`ReservedHandles.byBlockLinetype` to `ReservedHandles.byLayerLinetype`.
Expected: `the four fields are absent-tolerant and default to the no-op values`
goes red. (M10's *resolution* consequence is criterion 9, proved in Task 4.)

Record both transcripts verbatim in the task report.

- [ ] **Step 8: Commit**

```bash
git add packages/jet_cad_2d/lib/src/document/node.dart \
        packages/jet_cad_2d/lib/src/codec/schema_version.dart \
        packages/jet_cad_2d/test/codec/instance_style_codec_test.dart
git commit -m "feat: InstanceNode carries the four style fields StyleContext needs

StyleContext has six fields and InstanceNode carried two of them, so a
BYBLOCK entity inside a definition had no INSERT lineweight, transparency
or linetype to inherit -- the information did not exist in the model.
Adds all four with the entity store's own encoding and sentinels.

Every default is a no-op: kByBlock reproduces the pass-through contextFor
already performs, and 1.0 is the multiplicative identity. So this commit
changes no drawing, which is what lets it land before the resolver does.

Schema 5 -> 6. The bump is for the reader: without it a v5 build loads a
v6 file, drops four fields and renders something else."
```

---

## Task 2: `contextFor` resolves the three sentinel fields

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/document/style_resolver.dart:27-52`, and delete the now-unused `_layerColorOf` helper at `:106-107`
- Create: `packages/jet_cad_2d/test/document/instance_style_test.dart`

**Interfaces:**
- Consumes: `InstanceNode.lineweight`, `.transparency`, `.linetype` from Task 1.
- Produces: `contextFor` now returns a `StyleContext` whose `lineweight`, `transparency` and `linetype` are derived from the instance. Task 3 edits the same method's `linetypeScale` line; Task 4 compares whole `ResolvedStyle`s across schema versions.

**The single layer-record fetch.** Today `_layerColorOf(layer, inherited)` looks
the record up for `color` alone. Four fields asking the same table four times
would be four map lookups per instance per frame, on a path the global
constraints bound. Fetch once, pass the record to `_concreteLayerColor`, and
delete `_layerColorOf` — an unused private method is an analyzer error.

**The fourth arm.** `kLineweightDefault` (`-3`) is a third valid sentinel in
this encoding and it is present in the repository today —
`test/document/tables_test.dart:13` builds a `LayerRecord` with it, and
`test/codec/schema_v3_fixture_test.dart:17,47` carries it in stored JSON. A
three-arm switch would write `-3` into `StyleContext.lineweight`, a field whose
own doc comment declares it concrete. The entity-side guard does not rescue it:
`style_resolver.dart:100` maps a `-3` entity lineweight to `ctx.lineweight`,
which under such an INSERT is itself `-3`, and `-3` would reach the painter as
a stroke width.

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d/test/document/instance_style_test.dart`:

```dart
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

// ---------------------------------------------------------------------------
// Fixture helpers.
//
// Four distinct sources for every property under test — the instance, the
// substituted layer's record, layer 0's record, and `StyleContext.documentRoot`
// — so a resolution that reads the wrong one of the four lands on a number no
// assertion here expects. A fixture where two of the four agree cannot tell a
// correct resolver from the mutant that reads the other one.
// ---------------------------------------------------------------------------

Handle addLayer(
  DraftDocument doc,
  Handle handle,
  String name, {
  required int lineweight,
  required int transparency,
  required Handle linetype,
}) {
  doc.tables.layers.add(LayerRecord(
    handle: handle,
    name: name,
    color: const IndexedColor(5),
    linetype: linetype,
    lineweight: lineweight,
    transparency: transparency,
    visible: true,
    locked: false,
  ));
  return handle;
}

Handle addDefinition(DraftDocument doc, Handle handle, String name) {
  doc.tree.addDefinition(Definition(
      handle: handle,
      name: name,
      basePoint: Vector2.zero(),
      children: const []));
  return handle;
}

/// A line that defers every property to whatever places it.
Handle addByBlockLine(
  DraftDocument doc,
  Handle owner,
  Handle handle, {
  double linetypeScale = 2.0,
}) {
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: owner,
      kind: EntityKind.line,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byBlockLinetype,
      linetypeScale: linetypeScale,
      geomIndex: 0,
      color: const ByBlockColor(),
      lineweight: kByBlock,
      transparency: kByBlock,
      flags: 0,
    ),
    payload: GeometryPayload(
      coords: Float64List.fromList([0, 0, 1, 1]),
      scalars: Float64List(0),
    ),
  ));
  return handle;
}

Handle addInstance(
  DraftDocument doc,
  Handle handle,
  Handle definition, {
  Handle? parent,
  Handle layer = ReservedHandles.layerZero,
  int lineweight = kByBlock,
  int transparency = kByBlock,
  Handle linetype = ReservedHandles.byBlockLinetype,
  double linetypeScale = 1.0,
}) {
  doc.commands.execute(AddNodeCommand(InstanceNode(
    handle: handle,
    parent: parent ?? doc.rootHandle,
    // Never the identity: an identity transform commutes and hides ordering,
    // which is the defect four fixtures missed in Plan 2.
    transform: Transform2.translation(31, 17),
    definition: definition,
    layer: layer,
    lineweight: lineweight,
    transparency: transparency,
    linetype: linetype,
    linetypeScale: linetypeScale,
  )));
  return handle;
}

/// Resolves [child] as if drawn through [instance], directly rather than by
/// walking. The claim under test is what `contextFor` computes, not how a
/// traversal reaches it; the traversal is covered by the differential and
/// golden suites in the Flutter package.
ResolvedStyle resolveThrough(
    DraftDocument doc, List<Handle> instances, Handle child) {
  final resolver = DocumentStyleResolver(doc);
  var ctx = StyleContext.documentRoot;
  for (final i in instances) {
    ctx = resolver.contextFor(i, ctx);
  }
  return resolver.styleFor(doc.entities.slotOf(child)!, ctx);
}

void main() {
  // `StyleContext.documentRoot` is lineweight 25, transparency 0, linetype
  // `continuousLinetype`. Every expected value below differs from all three.

  test('an INSERT imposes its concrete lineweight on a BYBLOCK child', () {
    final doc = DraftDocument.empty();
    final def = addDefinition(doc, const Handle(200), 'BOLT');
    final child = addByBlockLine(doc, def, const Handle(201));
    addInstance(doc, const Handle(300), def, lineweight: 211);

    expect(resolveThrough(doc, [const Handle(300)], child).lineweightHundredths,
        211);
  });

  test('an INSERT imposes its concrete transparency on a BYBLOCK child', () {
    final doc = DraftDocument.empty();
    final def = addDefinition(doc, const Handle(200), 'BOLT');
    final child = addByBlockLine(doc, def, const Handle(201));
    addInstance(doc, const Handle(300), def, transparency: 137);

    // Transparency reaches the drawing as the alpha byte: 255 - 137 = 118.
    // Asserted through `argb` rather than through a transparency getter
    // because `ResolvedStyle` has no separate transparency field, and the
    // byte is what a painter actually consumes.
    expect(resolveThrough(doc, [const Handle(300)], child).argb >> 24, 118);
  });

  test('an INSERT imposes its concrete linetype on a BYBLOCK child', () {
    final doc = DraftDocument.empty();
    final def = addDefinition(doc, const Handle(200), 'BOLT');
    final child = addByBlockLine(doc, def, const Handle(201));
    addInstance(doc, const Handle(300), def, linetype: const Handle(42));

    expect(resolveThrough(doc, [const Handle(300)], child).linetype,
        const Handle(42));
  });

  group('BYLAYER on an INSTANCE reads the substituted layer, not node.layer',
      () {
    /// Layer 0 and layer `L` carry different values for every property, and
    /// the instance sits on layer 0 so substitution has to happen for the
    /// right one to be read. A mutant reading `node.layer` gets layer 0's
    /// numbers; the correct resolver gets `L`'s.
    DraftDocument fixture() {
      final doc = DraftDocument.empty();
      addLayer(doc, ReservedHandles.layerZero, '0',
          lineweight: 13, transparency: 9, linetype: const Handle(70));
      addLayer(doc, const Handle(100), 'STRUCT',
          lineweight: 191, transparency: 88, linetype: const Handle(71));
      final def = addDefinition(doc, const Handle(200), 'BOLT');
      addByBlockLine(doc, def, const Handle(201));
      // The outer placement puts layer STRUCT into the context; the inner
      // instance is on layer 0, so it inherits STRUCT and must read STRUCT's
      // record for its own BYLAYER properties.
      addInstance(doc, const Handle(300), const Handle(210),
          layer: const Handle(100));
      return doc;
    }

    test('lineweight', () {
      final doc = fixture();
      addInstance(doc, const Handle(310), const Handle(200),
          parent: const Handle(210), lineweight: kByLayer);
      expect(
          resolveThrough(doc, [const Handle(300), const Handle(310)],
                  const Handle(201))
              .lineweightHundredths,
          191);
    });

    test('transparency', () {
      final doc = fixture();
      addInstance(doc, const Handle(310), const Handle(200),
          parent: const Handle(210), transparency: kByLayer);
      expect(
          resolveThrough(doc, [const Handle(300), const Handle(310)],
                      const Handle(201))
                  .argb >>
              24,
          255 - 88);
    });

    test('linetype', () {
      final doc = fixture();
      addInstance(doc, const Handle(310), const Handle(200),
          parent: const Handle(210), linetype: ReservedHandles.byLayerLinetype);
      expect(
          resolveThrough(doc, [const Handle(300), const Handle(310)],
                  const Handle(201))
              .linetype,
          const Handle(71));
    });
  });

  group('kLineweightDefault never reaches a ResolvedStyle', () {
    // `-3` is a third sentinel in this encoding, not a width. A three-arm
    // switch sends it down "otherwise" and into StyleContext.lineweight,
    // whose doc comment declares that field concrete -- and the entity-side
    // guard cannot rescue it, because that guard maps a -3 entity lineweight
    // to ctx.lineweight, which here would itself be -3.
    test('carried directly by the INSERT', () {
      final doc = DraftDocument.empty();
      final def = addDefinition(doc, const Handle(200), 'BOLT');
      final child = addByBlockLine(doc, def, const Handle(201));
      addInstance(doc, const Handle(300), def,
          lineweight: kLineweightDefault);

      // documentRoot's 25 -- the inherited value, which is what "default"
      // means here.
      expect(
          resolveThrough(doc, [const Handle(300)], child).lineweightHundredths,
          25);
    });

    test('reached through the INSERT\'s BYLAYER lookup', () {
      final doc = DraftDocument.empty();
      addLayer(doc, const Handle(100), 'DEFAULTED',
          lineweight: kLineweightDefault,
          transparency: 0,
          linetype: ReservedHandles.continuousLinetype);
      final def = addDefinition(doc, const Handle(200), 'BOLT');
      final child = addByBlockLine(doc, def, const Handle(201));
      addInstance(doc, const Handle(300), def,
          layer: const Handle(100), lineweight: kByLayer);

      expect(
          resolveThrough(doc, [const Handle(300)], child).lineweightHundredths,
          25);
    });
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```sh
cd packages/jet_cad_2d && CI=true dart test test/document/instance_style_test.dart
```

Expected: eight tests, all FAIL. The three "imposes its concrete X" tests read
`documentRoot`'s values (25, alpha 255, `continuousLinetype`); the BYLAYER
tests read the same; the two `kLineweightDefault` tests read `-3` and `25`
respectively.

- [ ] **Step 3: Rewrite `contextFor`**

Replace `lib/src/document/style_resolver.dart:27-52` with:

```dart
  @override
  StyleContext contextFor(Handle instance, StyleContext inherited) {
    final node = document.tree[instance];
    if (node is! InstanceNode) return inherited;
    // An instance on layer 0 is substituted onto the layer it is placed
    // through, exactly as an entity is in [styleFor]. That one effective layer
    // answers every question this method asks — which layer supplies this
    // instance's BYLAYER properties, and which layer it passes down — so it is
    // computed once. Reading `node.layer` for a property while passing the
    // substituted layer down would make one node report two effective layers.
    final layer =
        node.layer == ReservedHandles.layerZero ? inherited.layer : node.layer;
    // One lookup, not four. Before Plan 3f.1 only `color` consulted the record;
    // four properties asking the same table four times would be four map
    // lookups per instance per frame, on a path the non-negotiables bound.
    final record = document.tables.layers[layer];

    final encoded = encodeColor(node.color);
    final color = switch (encoded) {
      kByBlock => inherited.color,
      kByLayer => _concreteLayerColor(record, inherited),
      _ => encoded,
    };

    // `kLineweightDefault` is a *third* sentinel, not a width, and it must not
    // survive into `StyleContext.lineweight` — a field whose own doc comment
    // declares it concrete. It can arrive by either route: written on the
    // INSERT itself, or read off a layer record, which
    // `test/document/tables_test.dart:13` already does.
    int concrete(int value) =>
        value == kLineweightDefault ? inherited.lineweight : value;
    final lineweight = switch (node.lineweight) {
      kByBlock => inherited.lineweight,
      kByLayer => concrete(record?.lineweight ?? inherited.lineweight),
      _ => concrete(node.lineweight),
    };

    final transparency = switch (node.transparency) {
      kByBlock => inherited.transparency,
      kByLayer => record?.transparency ?? inherited.transparency,
      _ => node.transparency,
    };

    // Spelled as nested conditionals rather than a switch because
    // `ReservedHandles.byBlockLinetype` is a `Handle`, not an `int` constant
    // pattern — the same shape `styleFor` uses for the entity-side read.
    //
    // Absence is checked; malformedness is not. A layer whose *colour* is
    // itself BYLAYER or BYBLOCK is rejected by `_concreteLayerColor`, and a
    // layer whose *linetype* is one of those sentinels is not — an asymmetry
    // this method inherits from `styleFor` rather than introducing. An INSERT
    // and an entity resolving the same malformed layer differently would be a
    // new defect; fixing the entity side is a separate change.
    final linetype = node.linetype == ReservedHandles.byBlockLinetype
        ? inherited.linetype
        : node.linetype == ReservedHandles.byLayerLinetype
            ? (record?.linetype ?? inherited.linetype)
            : node.linetype;

    return StyleContext(
      color: color,
      linetype: linetype,
      linetypeScale: inherited.linetypeScale,
      lineweight: lineweight,
      transparency: transparency,
      layer: layer,
    );
  }
```

Then delete the now-unused helper:

```dart
  int _layerColorOf(Handle layer, StyleContext inherited) =>
      _concreteLayerColor(document.tables.layers[layer], inherited);
```

- [ ] **Step 4: Run the test and the full engine suite**

```sh
cd packages/jet_cad_2d && CI=true dart test test/document/instance_style_test.dart
CI=true dart test && dart analyze && dart format --output=none --set-exit-if-changed .
```

Expected: eight PASS, whole suite green, `dart analyze` clean (which is what
proves `_layerColorOf` was actually removed rather than left dangling).

- [ ] **Step 5: Fire mutants M1, M2, M3, M6, M7, M8, M9**

`cp lib/src/document/style_resolver.dart /tmp/style_resolver.dart.bak` first;
restore from the copy after each.

| mutant | edit | must redden |
|---|---|---|
| M1 | `lineweight:` → `inherited.lineweight` | `imposes its concrete lineweight`, `BYLAYER ... lineweight` |
| M2 | `transparency:` → `inherited.transparency` | `imposes its concrete transparency`, `BYLAYER ... transparency` |
| M3 | `linetype:` → `inherited.linetype` | `imposes its concrete linetype`, `BYLAYER ... linetype` |
| M6 | `final record = document.tables.layers[node.layer];` | all three BYLAYER tests |
| M7 | transparency's `kByLayer` arm → `node.transparency` | `BYLAYER ... transparency` |
| M8 | linetype's `byLayerLinetype` branch → `node.linetype` | `BYLAYER ... linetype` |
| M9 | delete `concrete(...)`, use the raw values | both `kLineweightDefault` tests |

Record each transcript verbatim.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d/lib/src/document/style_resolver.dart \
        packages/jet_cad_2d/test/document/instance_style_test.dart
git commit -m "feat: an INSERT imposes lineweight, transparency and linetype

contextFor computed two of StyleContext's six fields from the instance and
passed the other four straight through, so an entity that asked for its
placer's lineweight got whatever enclosed the outermost block -- for a
root-level INSERT, documentRoot's hardcoded 25.

Resolves all three sentinel-carrying fields the way color is already
resolved, through the substituted layer, off a single layer-record fetch
rather than one per field.

kLineweightDefault gets a fourth arm. It is a sentinel, not a width, and
it can arrive on the INSERT or off a layer record. styleFor's own guard
cannot rescue it -- that guard maps a -3 entity lineweight to
ctx.lineweight, which under such an INSERT is itself -3."
```

---

## Task 3: `linetypeScale` composes multiplicatively

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/document/style_resolver.dart` — the `linetypeScale:` line in `contextFor`, and the `linetypeScale:` line in `styleFor` (currently `:102`)
- Modify: `packages/jet_cad_2d/test/document/instance_style_test.dart` — add one group

**Interfaces:**
- Consumes: `InstanceNode.linetypeScale` from Task 1; `resolveThrough` from Task 2.
- Produces: `ResolvedStyle.linetypeScale` is now the product of the entity's own scale and every enclosing INSERT's. `DraftPainter` already multiplies that by `document.header.globalLinetypeScale` at `draft_painter.dart:615,769,803`, so the full DXF chain closes.

**Why this is a separate task from Task 2.** The other three fields answer
"which value wins" and substitute. This one answers "by how much" and
multiplies — a different rule, taken from DXF, and the only one of the four
that also changes `styleFor`. A reviewer can reject the multiplication without
rejecting the substitutions.

**The chosen numbers, and why these.** Entity `2.0` × inner INSERT `4.0` ×
outer INSERT `8.0` = **`64.0`**. Every factor is exact in binary, so the
assertion is `==` and not a tolerance. And `64.0` differs from every factor
(2, 4, 8), every pairwise product (8, 16, 32), the sum (14) and the maximum
(8) — so a mutant that drops one multiplication, replaces it with addition, or
takes a maximum lands on a different number in every case.

- [ ] **Step 1: Write the failing test**

Append to `packages/jet_cad_2d/test/document/instance_style_test.dart`, inside
`main()`:

```dart
  group('linetypeScale multiplies down the tree', () {
    test('entity 2.0 x inner 4.0 x outer 8.0 resolves to exactly 64.0', () {
      final doc = DraftDocument.empty();
      final inner = addDefinition(doc, const Handle(200), 'BOLT');
      final outer = addDefinition(doc, const Handle(210), 'PLATE');
      final child = addByBlockLine(doc, inner, const Handle(201),
          linetypeScale: 2.0);
      addInstance(doc, const Handle(300), outer, linetypeScale: 8.0);
      addInstance(doc, const Handle(310), inner,
          parent: const Handle(210), linetypeScale: 4.0);

      // Exact. Every factor is a power of two, so the product is
      // representable and `Tolerance` would only hide a wrong answer.
      expect(
          resolveThrough(doc, [const Handle(300), const Handle(310)], child)
              .linetypeScale,
          64.0);
    });

    test('an INSERT at 1.0 leaves its child alone', () {
      // The default's no-op property, asserted rather than assumed: this is
      // what makes every pre-3f.1 document resolve unchanged. The entity's own
      // scale is still 2.0, never 1.0 -- the identity on both sides would
      // prove nothing.
      final doc = DraftDocument.empty();
      final def = addDefinition(doc, const Handle(200), 'BOLT');
      final child =
          addByBlockLine(doc, def, const Handle(201), linetypeScale: 2.0);
      addInstance(doc, const Handle(300), def);

      expect(resolveThrough(doc, [const Handle(300)], child).linetypeScale,
          2.0);
    });
  });
```

- [ ] **Step 2: Run it and watch it fail**

```sh
cd packages/jet_cad_2d && CI=true dart test test/document/instance_style_test.dart --plain-name "linetypeScale multiplies"
```

Expected: the first test FAILS reading `2.0` instead of `64.0` — `styleFor`
returns the entity's own scale and ignores the context entirely. The second
test passes already, and that is the point: it cannot distinguish a connected
channel from a severed one, which is exactly how fifty-four fixtures at `1.0`
missed this defect. It is kept as the no-op guard, not as the proof.

- [ ] **Step 3: Connect both ends**

In `contextFor`, change the pass-through to a product:

```dart
      // Multiplies, never substitutes. DXF's rule for a nested entity's
      // effective linetype scale is a product, so nesting composes without a
      // special case for depth: entity x every enclosing INSERT x the header's
      // global scale, which `DraftPainter` applies at the far end.
      linetypeScale: inherited.linetypeScale * node.linetypeScale,
```

In `styleFor`, change the line that ignores the context:

```dart
      // Before Plan 3f.1 this read `document.entities.linetypeScaleAt(slot)`
      // alone. `StyleContext.linetypeScale` was constructed, copied, compared
      // and hashed, and no code path read it to produce a drawing — and no
      // test could tell, because every linetypeScale literal in the repository
      // was 1.0, the multiplicative identity.
      linetypeScale:
          ctx.linetypeScale * document.entities.linetypeScaleAt(slot),
```

- [ ] **Step 4: Run the test and the full engine suite**

```sh
cd packages/jet_cad_2d && CI=true dart test && dart analyze && dart format --output=none --set-exit-if-changed .
```

Expected: ten tests in `instance_style_test.dart` PASS, whole suite green. No
pre-existing test moves — `documentRoot.linetypeScale` is `1.0` and every
existing instance now defaults to `1.0`, so every existing product is the
identity.

- [ ] **Step 5: Fire mutants M4 and M5**

| mutant | edit | must redden |
|---|---|---|
| M4 | `styleFor` → `linetypeScale: document.entities.linetypeScaleAt(slot)` | `entity 2.0 x inner 4.0 x outer 8.0` (reads 2.0) |
| M5 | `contextFor` → `linetypeScale: node.linetypeScale` | same test (reads 8.0) |

Both must also leave `an INSERT at 1.0 leaves its child alone` green — that
test is the no-op guard and is expected to survive, which is why it is not
listed as any mutant's killer.

- [ ] **Step 6: Run the Flutter suite too**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test
```

This is the first task whose change can move a *drawing*: dash spacing reads
`ResolvedStyle.linetypeScale`. Expected: green, including all 35 goldens, with
no PNG regenerated. **If a golden moves, stop** — the defaults are supposed to
make this a no-op, and a moved golden means a fixture somewhere carries a
non-identity instance scale that was previously being ignored.

- [ ] **Step 7: Commit**

```bash
git add packages/jet_cad_2d/lib/src/document/style_resolver.dart \
        packages/jet_cad_2d/test/document/instance_style_test.dart
git commit -m "fix: StyleContext.linetypeScale reaches the drawing

The field was constructed, copied by copyWith, compared by ==, hashed, and
threaded through contextFor -- and styleFor built its ResolvedStyle from
the entity's own scale alone, so no code path read the context's to produce
a drawing. Dash spacing consumes it at three sites in DraftPainter.

No test could see it. Every linetypeScale literal in the repository is 1.0
except one storage round-trip, and 1.0 is the multiplicative identity: a
severed channel and a connected one produce the same output when every
value flowing through is the identity.

Composes multiplicatively, per DXF: entity x every enclosing INSERT x the
header's global scale. Substitution would have been the wrong rule and
would have made nesting need a special case for depth."
```

---

## Task 4: a v5 document resolves bit-identically under a v6 build

**Files:**
- Modify: `packages/jet_cad_2d/test/codec/instance_style_codec_test.dart` — add one group

**Interfaces:**
- Consumes: everything from Tasks 1–3.
- Produces: nothing. This task is proof, not mechanism.

**Why the fixture shape is named rather than left to judgement.** M10 changes
`fromJson`'s absent-`linetype` default from `byBlockLinetype` to
`byLayerLinetype`. That changes a *resolved style* only when the document
contains a BYBLOCK-linetype entity, inside a definition, placed through an
INSERT whose effective layer's linetype differs from the inherited context's.
Relying on the golden suite to catch it assumes some existing golden happens to
contain that shape, which nobody has verified. The fixture below contains it
explicitly, so M10 is killed by design rather than by luck.

- [ ] **Step 1: Write the failing test**

Append to `packages/jet_cad_2d/test/codec/instance_style_codec_test.dart`:

```dart
  group('a v5 document resolves bit-identically under a v6 build', () {
    /// A v5 document: a v6 encoding with the four new instance keys stripped
    /// and the version declared back down.
    ///
    /// **Derived, not hand-written.** Hand-writing the whole document shape
    /// would put a second, drifting copy of the codec's JSON contract in a
    /// test file, and a fixture that silently fails to parse into anything
    /// proves less than nothing about migration. Encoding a real document and
    /// removing exactly the four keys a pre-3f.1 writer never wrote produces
    /// precisely what that writer produced, and stays correct when the rest of
    /// the shape changes.
    ///
    /// The document's shape is chosen so M10 has somewhere to land: entity 201
    /// is BYBLOCK-linetype, it lives inside definition 200, and instance 300
    /// sits on layer 100 whose linetype (71) differs from documentRoot's
    /// `continuousLinetype`. Under the correct BYBLOCK default the entity
    /// resolves to `continuousLinetype`; under M10's BYLAYER default it
    /// resolves to `Handle(71)`.
    Map<String, Object?> v5Document() {
      final doc = DraftDocument.empty();
      doc.tables.layers.add(const LayerRecord(
        handle: Handle(100),
        name: 'STRUCT',
        color: IndexedColor(5),
        linetype: Handle(71),
        lineweight: 191,
        transparency: 88,
        visible: true,
        locked: false,
      ));
      doc.tree.addDefinition(Definition(
          handle: const Handle(200),
          name: 'BOLT',
          basePoint: Vector2.zero(),
          children: const []));
      doc.commands.execute(AddEntityCommand(
        record: const EntityRecord(
          handle: Handle(201),
          owner: Handle(200),
          kind: EntityKind.line,
          layer: ReservedHandles.layerZero,
          linetype: ReservedHandles.byBlockLinetype,
          linetypeScale: 2.0,
          geomIndex: 0,
          color: ByBlockColor(),
          lineweight: kByBlock,
          transparency: kByBlock,
          flags: 0,
        ),
        payload: GeometryPayload(
          coords: Float64List.fromList([0, 0, 1, 1]),
          scalars: Float64List(0),
        ),
      ));
      doc.commands.execute(AddNodeCommand(InstanceNode(
        handle: const Handle(300),
        parent: doc.rootHandle,
        transform: Transform2.translation(31, 17),
        definition: const Handle(200),
        layer: const Handle(100),
      )));

      final json = DraftDocumentCodec.encode(doc);
      // Exactly the four keys a v5 writer did not write.
      for (final node in json['nodes']! as List<Object?>) {
        final map = node! as Map<String, Object?>;
        if (map['type'] != 'instance') continue;
        map.remove('lineweight');
        map.remove('transparency');
        map.remove('linetype');
        map.remove('linetypeScale');
      }
      json['schemaVersion'] = 5;
      return json;
    }

    test('every field of the resolved style matches the pre-3f.1 answer', () {
      final doc = DraftDocumentCodec.decode(v5Document());
      final resolver = DocumentStyleResolver(doc);
      final ctx = resolver.contextFor(const Handle(300),
          StyleContext.documentRoot);
      final style =
          resolver.styleFor(doc.entities.slotOf(const Handle(201))!, ctx);

      // The four answers a pre-3f.1 build produced for this document, written
      // as literals. Recomputing them from the current resolver would be a
      // tautology -- the code under test on both sides of the comparison.
      //
      // lineweight: the INSERT defaults to BYBLOCK, so the entity's BYBLOCK
      // reaches documentRoot's 25 -- NOT layer STRUCT's 191.
      expect(style.lineweightHundredths, 25);
      // transparency: same route to documentRoot's 0, so alpha is 255 --
      // NOT 255 - 88.
      expect(style.argb >> 24, 255);
      // linetype: BYBLOCK all the way to documentRoot's continuousLinetype.
      // This is the assertion M10 breaks.
      expect(style.linetype, ReservedHandles.continuousLinetype);
      // linetypeScale: the entity's own 2.0 times an INSERT that defaults to
      // the identity.
      expect(style.linetypeScale, 2.0);
    });

    test('a v6 build refuses nothing it wrote and everything from the future',
        () {
      // The bump's whole purpose is the reader. A v5 payload loads; a v7 one
      // is refused by version rather than by a FormatException deep inside a
      // field parse.
      expect(() => DraftDocumentCodec.decode(v5Document()), returnsNormally);
      final future = v5Document()..['schemaVersion'] = 7;
      expect(() => DraftDocumentCodec.decode(future),
          throwsA(isA<SchemaVersionError>()));
    });
  });
```

- [ ] **Step 2: Run it**

```sh
cd packages/jet_cad_2d && CI=true dart test test/codec/instance_style_codec_test.dart
```

Expected: both new tests PASS on the first run. **This is a regression guard,
not a red-green cycle** — Tasks 1–3 were built so that this is already true,
and a failure here means one of their defaults is not the no-op it claims to
be. If it fails, the defect is in Task 1's `fromJson` or Task 2's `contextFor`,
not in this test.

- [ ] **Step 3: Fire M10 again, this time for its resolution consequence**

`cp lib/src/document/node.dart /tmp/node.dart.bak`, change `fromJson`'s absent-
`linetype` default to `ReservedHandles.byLayerLinetype`, and run:

```sh
CI=true dart test test/codec/instance_style_codec_test.dart
```

Expected: `every field of the resolved style matches the pre-3f.1 answer` goes
red on `expect(style.linetype, ReservedHandles.continuousLinetype)`, reading
`Handle(71)`. Restore from the copy.

- [ ] **Step 4: Confirm criterion 11 — no golden moved**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test
git status --short packages/jet_cad_2d_flutter/test/golden
```

Expected: the suite green, and `git status` reports **nothing** under
`test/golden` — no PNG regenerated, none modified. Paste both outputs into the
task report.

- [ ] **Step 5: Commit**

```bash
git add packages/jet_cad_2d/test/codec/instance_style_codec_test.dart
git commit -m "test: a v5 document resolves bit-identically under v6

The migration's whole claim is that the four new defaults are no-ops. This
pins it against a v5 payload written as JSON rather than built through the
API -- built through the API it would carry v6 defaults and prove nothing.

The fixture shape is deliberate: a BYBLOCK-linetype entity inside a
definition, placed through an INSERT whose layer's linetype differs from
documentRoot's. Without that shape the mutant that defaults absent
linetypes to BYLAYER changes no resolved style and survives."
```

---

## Task 5: `TextKeySink` moves, and the text-cache invariants become assertions

**Files:**
- Create: `packages/jet_cad_2d_flutter/test/support/text_key_sink.dart`
- Modify: `packages/jet_cad_2d_flutter/test/rig/rig_support.dart` — delete the class, import it
- Create: `packages/jet_cad_2d_flutter/test/invariants/text_cache_invariants_test.dart`

**Interfaces:**
- Consumes: `FlutterTextMeasurer()` bare, `CanvasDrawSink`, `DraftPainter`, `referenceWalk`.
- Produces: `test/support/text_key_sink.dart` exporting `TextKeySink` — the rig, `flutter_text_measurer_test.dart` and this new file all import it from there.

**Why the sink matters, and why the obvious helper is wrong.** The two caches
fill on two different paths. `measure()` fills the metrics map and
`DraftPainter._drawText` calls it directly at `draft_painter.dart:873`, so any
sink reaches it. `paragraphFor` fills the paragraph map and has exactly **one**
production caller — `CanvasDrawSink.text` at `canvas_draw_sink.dart:207`.
`paintToRecording` (`test/support/fixtures.dart:167`) drives a
`RecordingDrawSink`, and `TextKeySink` records only keys: either would report
`textOpCount == 600` with `liveParagraphCount` sitting at **zero**.

**Why the camera is built by hand.** `ViewportTransform.fit` applies a 0.95
margin, and deriving an expected on-screen cap height through it cost Plan 3f
two tasks. This fixture builds `ViewportTransform` directly at scale `1.0`, so
world units are screen pixels and the threshold arithmetic is `8.0 >= 3.0` with
nothing to get wrong.

- [ ] **Step 1: Move `TextKeySink` without changing it**

Create `packages/jet_cad_2d_flutter/test/support/text_key_sink.dart` holding
the class exactly as it stands at `test/rig/rig_support.dart:111-167`,
including its full doc comment and the `isAttributeTag` static. Add the imports
it needs:

```dart
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
```

Then in `test/rig/rig_support.dart`, delete the class and add:

```dart
import '../support/text_key_sink.dart';
export '../support/text_key_sink.dart';
```

The `export` keeps `paint_microbench_test.dart` and
`flutter_text_measurer_test.dart` compiling unchanged — they import
`rig_support.dart` and reference `TextKeySink` through it. One definition, four
readers.

- [ ] **Step 2: Verify the move changed nothing**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test test/flutter_text_measurer_test.dart
flutter analyze
```

Expected: green, and analyze clean — which is what proves no import went stale.
`unused_import` is an error in this package, so a leftover import fails here
rather than at review.

- [ ] **Step 3: Write the failing invariant test**

Create `packages/jet_cad_2d_flutter/test/invariants/text_cache_invariants_test.dart`:

```dart
// The structural half of what `test/rig/paint_microbench_test.dart` prints.
//
// The rig measures at realistic scale and prints; those numbers depend on
// machine load and a rig that fails the build on a slow machine teaches people
// to ignore it. **These numbers do not.** Cache occupancy, eviction counts and
// op counts are a function of the document, the camera and the code — the same
// integers on every machine — so they can be a gate, and they are sized by the
// bound under test rather than by realism.
//
// Plan 3f's mutant 7 (`metricsLimit` defaulting to `kParagraphCacheLimit`)
// passed all 297 tests in the suite it shipped with. Nine of the twelve
// constructions in `flutter_text_measurer_test.dart` are already bare, so bare
// construction was never the missing half: **no test in that file ever pushed
// past 512 distinct metrics keys**, so nothing it asserted was sensitive to
// `metricsLimit` at any value. This file supplies the other half.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import '../support/fixtures.dart';

/// More distinct keys than `kParagraphCacheLimit` (512) and fewer than
/// `kMetricsCacheLimit` (8192). 600 sits between the two bounds, which is the
/// only property that matters: at 512 or below no value of either limit
/// changes an answer.
const int kDistinctLabels = 600;

/// Cap height in world units. At the camera below, world units are screen
/// pixels, so this is 8 px against a `kMinTextCapPixels` of 3.0 — a 2.67x
/// margin, and `culledTextCount == 0` is asserted rather than assumed.
const double kLabelHeight = 8.0;

/// World == screen, y flipped, no margin.
///
/// **Not `ViewportTransform.fit`.** `fit` applies a 0.95 margin, and deriving
/// an expected on-screen cap height through it is what cost Plan 3f two tasks.
/// At scale 1.0 the level-of-detail arithmetic is `8.0 >= 3.0` and there is
/// nothing to get wrong.
ViewportTransform unitCamera() => ViewportTransform(
    worldToScreenMatrix: Transform2(1, 0, 0, -1, 0, kViewport.height));

/// 600 labels, every string distinct, laid out on a grid that fits inside
/// [kViewport] so none of them culls by bounds.
///
/// 25 columns x 24 rows on a 30 x 24 pixel cell: a four-character label at 8 px
/// cap height is roughly 18 px wide, so nothing leaves its cell and nothing
/// leaves the viewport.
DraftDocument sixHundredLabels(FlutterTextMeasurer measurer) {
  final doc = DraftDocument.empty(measurer: measurer);
  for (var i = 0; i < kDistinctLabels; i++) {
    final column = i % 25;
    final row = i ~/ 25;
    addText(
      doc,
      doc.rootHandle,
      Handle(1000 + i),
      // Distinct by construction: 600 strings, 600 keys.
      'L${i.toString().padLeft(3, '0')}',
      column * 30.0 + 4,
      row * 24.0 + 8,
      kLabelHeight,
    );
  }
  return doc;
}

void main() {
  test('the default cache bounds hold 600 distinct keys the way they claim',
      () {
    // Bare. Both limits are what is under test, so neither may be supplied.
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);

    final doc = sixHundredLabels(measurer);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    // The baseline, stated rather than assumed: `doc.extents` measures text
    // through `entityBounds`, so building the document and the index has
    // already warmed the *metrics* map with all 600 keys. That is harmless for
    // the four counters below — the same 600 keys, still no evictions — but it
    // is why `layoutCount` is deliberately not asserted here. Plan 3f's Task 5
    // lost a round to exactly this warm-up.
    expect(doc.extents.isEmpty, isFalse,
        reason: 'the fixture must have measurable text');

    // `CanvasDrawSink` over a real `Canvas`, and nothing else will do:
    // `paragraphFor` has one production caller and this is it. A
    // `RecordingDrawSink` or a `TextKeySink` would leave `liveParagraphCount`
    // at zero while reporting `textOpCount == 600`.
    final recorder = PictureRecorder();
    final sink = CanvasDrawSink(
      canvas: Canvas(recorder),
      pixelsPerPaperMm: kLogicalPixelsPerMm,
      measurer: measurer,
      textStyleOf: doc.textStyleOf,
    );
    final painter = DraftPainter(
      document: doc,
      index: index,
      resolver: DocumentStyleResolver(doc),
    );

    painter.paint(sink, unitCamera(), kViewport);
    // A `Picture` holds native memory past the Dart object. Leaving one alive
    // is the "moved the leak" shape Plan 3f's own rule was written against.
    recorder.endRecording().dispose();

    // The fixture proves it drew what it claims before any cache number is
    // read: a level-of-detail cull would produce a smaller, self-consistent,
    // wrong set of counts.
    expect(painter.textOpCount, kDistinctLabels);
    expect(painter.culledTextCount, 0);
    expect(painter.skippedTextCount, 0);

    // The metrics map is bounded at 8192 and holds all 600.
    expect(measurer.liveMetricsCount, kDistinctLabels);
    expect(measurer.metricsEvictionCount, 0);

    // The paragraph map is bounded at 512, so 600 inserts leave 512 live and
    // evict 88. Eviction is one-per-insert once full.
    expect(measurer.liveParagraphCount, kParagraphCacheLimit);
    expect(measurer.paragraphEvictionCount,
        kDistinctLabels - kParagraphCacheLimit);
  });

  test('referenceWalk culls sub-threshold text at its own default', () {
    // The third of Plan 3f's three named untested defaults, and the one still
    // open. Two callers exist and neither closes it:
    // `test/support/fixtures.dart:184` re-declares its own
    // `minTextCapPixels = kMinTextCapPixels` and always passes it on, so the
    // parameter is shadowed for anything routed through `referenceToRecording`
    // — which is why this calls `referenceWalk` directly.
    // `test/differential_test.dart:63` does call it bare, but asserts only
    // `expect(sink.ops, isNotEmpty)`, which stays true at any threshold.
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);

    final doc = DraftDocument.empty(measurer: measurer);
    // 1.0 world unit at the unit camera is 1.0 px of cap height, a third of
    // `kMinTextCapPixels`. Drawn beside a label that clears the threshold, so
    // the walk is proved to be culling rather than simply drawing nothing.
    addText(doc, doc.rootHandle, const Handle(1001), 'TINY', 40, 40, 1.0);
    addText(doc, doc.rootHandle, const Handle(1002), 'BIG', 40, 200, 30.0);

    final sink = RecordingDrawSink();
    referenceWalk(doc, sink, unitCamera(), kViewport,
        DocumentStyleResolver(doc));

    final drawn = sink.ops.whereType<TextOp>().map((op) => op.text).toList();
    expect(drawn, ['BIG'],
        reason: 'TINY is 1 px of cap height against a 3.0 px default');
  });
}
```

**Where the names come from.** `RecordingDrawSink` and `TextOp` are production
types in `lib/src/draw_sink.dart:289` and `:267`, both exported from the
package barrel, and `TextOp` carries its string in a field named `text`.
`kLogicalPixelsPerMm` is exported from `draft_canvas.dart:19`. The only import
this file needs beyond the barrel is `../support/fixtures.dart`, for `addText`
and `kViewport`.

- [ ] **Step 4: Run it**

```sh
CI=true flutter test test/invariants/text_cache_invariants_test.dart
```

Expected: both PASS. If the first fails on `painter.culledTextCount`, the grid
arithmetic is wrong and the fixture is not drawing what it claims — fix the
fixture, never the expectation.

- [ ] **Step 5: Fire mutants M12, M13, M14**

`cp lib/src/flutter_text_measurer.dart /tmp/ftm.dart.bak` and
`cp lib/src/reference_walk.dart /tmp/rw.dart.bak`; restore from the copies.

| mutant | edit | must redden |
|---|---|---|
| M12 | `this.metricsLimit = kParagraphCacheLimit` | `liveMetricsCount` reads 512, `metricsEvictionCount` reads 88 |
| M13 | `this.paragraphLimit = kMetricsCacheLimit` | `liveParagraphCount` reads 600, `paragraphEvictionCount` reads 0 |
| M14 | `reference_walk.dart:36` default → `0.0` | `drawn` reads `['TINY', 'BIG']` |

M12 is Plan 3f's survivor: run the **whole** Flutter suite under it, not just
this file, and record that the only red is here. That is the evidence the hole
is closed rather than moved.

- [ ] **Step 6: Full suite, then commit**

```sh
CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

```bash
git add packages/jet_cad_2d_flutter/test/support/text_key_sink.dart \
        packages/jet_cad_2d_flutter/test/rig/rig_support.dart \
        packages/jet_cad_2d_flutter/test/invariants/text_cache_invariants_test.dart
git commit -m "test: the text cache's default bounds become an always-on gate

Plan 3f's mutant 7 passed all 297 tests. The recorded reason was that every
test in flutter_text_measurer_test.dart supplied both bounds explicitly;
nine of its twelve constructions are in fact bare. The real reason is
single: no test ever pushed past 512 distinct metrics keys, so nothing it
asserted was sensitive to metricsLimit at any value.

600 distinct labels sit between the two bounds, painted through a
CanvasDrawSink over a PictureRecorder -- paragraphFor has exactly one
production caller and a RecordingDrawSink never reaches it. The camera is
built by hand at scale 1.0 rather than through ViewportTransform.fit,
whose 0.95 margin cost Plan 3f two tasks.

Also closes reference_walk's minTextCapPixels default, the third of Plan
3f's three named untested defaults. Its two callers shadow it: one
re-declares the same default, the other asserts only that ops are
non-empty."
```

---

## Task 6: the frame accounting invariants

**Files:**
- Create: `packages/jet_cad_2d_flutter/test/invariants/frame_accounting_test.dart`

**Interfaces:**
- Consumes: `unitCamera()` and `addText` — `unitCamera` is duplicated into this file rather than shared, because the two invariant files are meant to be readable alone and a four-line camera helper is not worth a third support file.
- Produces: nothing.

**Three identities, no magic constants.** Each is true at any corpus size,
which is what lets the fixture stay small.

**Why item 3 is what it is.** An earlier draft asserted that five counters
agree across the two backends. All five are `DraftPainter` fields
(`draft_painter.dart:147,167,177,199,210`), `DrawSink` is write-only, and the
painter never branches on which sink it holds — `DraftCanvas` builds one
painter and swaps only the sink. Two paints could not have disagreed, and
dropping a text op inside `VerticesDrawSink` would have moved no painter
counter, so that claim's own mutant could not have reddened it. What replaces
it compares a number the **sink** owns against a number the **painter** owns.

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d_flutter/test/invariants/frame_accounting_test.dart`:

```dart
// Identities the rig prints and does not assert. None of them carries a magic
// constant: each is true at any corpus size, which is why this fixture is tiny
// and always runs while the rig stays tagged `rig` and skipped.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import '../support/fixtures.dart';

/// World == screen, y flipped, no margin. See
/// `text_cache_invariants_test.dart` for why this is not
/// `ViewportTransform.fit`.
ViewportTransform unitCamera() => ViewportTransform(
    worldToScreenMatrix: Transform2(1, 0, 0, -1, 0, kViewport.height));

/// Text in all three accounting states at once.
///
/// A fixture where any of the three counters is zero cannot tell a correct
/// accounting identity from one that drops a term.
DraftDocument threeWayTextDocument(FlutterTextMeasurer measurer) {
  final doc = DraftDocument.empty(measurer: measurer);
  // Drawn: 30 px of cap height against a 3.0 threshold.
  addText(doc, doc.rootHandle, const Handle(1001), 'ALPHA', 40, 500, 30.0);
  addText(doc, doc.rootHandle, const Handle(1002), 'BETA', 40, 440, 30.0);
  // Culled: 1 px, a third of the threshold.
  addText(doc, doc.rootHandle, const Handle(1003), 'GAMMA', 40, 380, 1.0);
  // Skipped: the empty string is nothing to lay out, and the painter counts it
  // separately from a cull because the two mean different things.
  addText(doc, doc.rootHandle, const Handle(1004), '', 40, 320, 30.0);
  return doc;
}

/// Every text leaf in [doc], counted from the document rather than from the
/// painter.
///
/// Plan 3c's Ruling 28 in miniature: an identity whose two sides come from the
/// same source is not an identity. Reading the expected total back off the
/// painter would make this assertion compare a number with itself.
int textLeafCount(DraftDocument doc) {
  var n = 0;
  // `leavesByOwner()` is the same enumeration `referenceWalk` uses to find
  // leaves, and it is the document's own answer rather than the painter's.
  for (final slots in doc.leavesByOwner().values) {
    for (final slot in slots) {
      final kind = doc.entities.kindAt(slot);
      if (kind == EntityKind.text || kind == EntityKind.attrib) n++;
    }
  }
  return n;
}

/// Paints [doc] once through a `CanvasDrawSink` over a throwaway recorder and
/// returns the painter, counters intact.
({DraftPainter painter, CanvasDrawSink sink}) paintOnce(
  DraftDocument doc,
  SpatialIndex index,
  FlutterTextMeasurer measurer, {
  bool vertices = false,
}) {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  final sink = CanvasDrawSink(
    canvas: canvas,
    pixelsPerPaperMm: kLogicalPixelsPerMm,
    measurer: measurer,
    textStyleOf: doc.textStyleOf,
  );
  final painter = DraftPainter(
    document: doc,
    index: index,
    resolver: DocumentStyleResolver(doc),
  );
  if (vertices) {
    // `devicePixelRatio` defaults to 1.0 and is left there: the widget rebinds
    // it from `MediaQuery` per frame, and a widgetless test has no display to
    // ask. Nothing this test asserts is in device pixels.
    final batching = VerticesDrawSink(
      pixelsPerPaperMm: kLogicalPixelsPerMm,
      fallback: sink,
      canvas: canvas,
    );
    painter.paint(batching, unitCamera(), kViewport);
    batching.flush();
  } else {
    painter.paint(sink, unitCamera(), kViewport);
  }
  recorder.endRecording().dispose();
  return (painter: painter, sink: sink);
}

void main() {
  test('text accounting closes: drawn + culled + skipped is every text leaf',
      () {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final doc = threeWayTextDocument(measurer);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final p = paintOnce(doc, index, measurer).painter;

    // All three non-zero, so no term can be dropped without changing the sum.
    expect(p.textOpCount, greaterThan(0));
    expect(p.culledTextCount, greaterThan(0));
    expect(p.skippedTextCount, greaterThan(0));
    expect(p.textOpCount + p.culledTextCount + p.skippedTextCount,
        textLeafCount(doc));
  });

  test('a repeated frame is a repeated frame', () {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final doc = threeWayTextDocument(measurer);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final first = paintOnce(doc, index, measurer).painter;
    final before = (
      first.textOpCount,
      first.culledTextCount,
      first.skippedTextCount,
      first.screenSpaceLeafCount,
    );

    // The same painter, painted again: every counter resets at the top of
    // `paint()`, so a second identical frame must read identically. A counter
    // that accumulates instead of resetting reads double here.
    first.paint(
      CanvasDrawSink(
        canvas: Canvas(PictureRecorder()),
        pixelsPerPaperMm: kLogicalPixelsPerMm,
        measurer: measurer,
        textStyleOf: doc.textStyleOf,
      ),
      unitCamera(),
      kViewport,
    );

    expect(
        (
          first.textOpCount,
          first.culledTextCount,
          first.skippedTextCount,
          first.screenSpaceLeafCount,
        ),
        before);
  });

  test('the vertices backend loses no text on the way through its fallback',
      () {
    // `VerticesDrawSink` delegates exactly three calls to its fallback --
    // beginResidual, endResidual and text (vertices_draw_sink.dart:300,307,721)
    // -- and of the seven `_canvasCalls++` sites in CanvasDrawSink, none is in
    // the two residual methods. So under this backend that counter counts
    // paragraphs and nothing else, and the equality below is a real comparison
    // between a sink-owned number and a painter-owned one.
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final doc = threeWayTextDocument(measurer);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final r = paintOnce(doc, index, measurer, vertices: true);

    expect(r.painter.textOpCount, greaterThan(0),
        reason: 'a fixture drawing no text cannot test a text seam');
    expect(r.sink.canvasCallCount, r.painter.textOpCount);
  });
}
```

**Where the names come from.** `leavesByOwner()` is the enumeration
`reference_walk.dart:41` already uses; `VerticesDrawSink`'s constructor takes
`canvas` directly (`vertices_draw_sink.dart:105-111`) and defaults
`devicePixelRatio` to `1.0`; `RecordingDrawSink` and `TextOp` are production
types exported from the package barrel.

- [ ] **Step 2: Run it**

```sh
CI=true flutter test test/invariants/frame_accounting_test.dart
```

Expected: three PASS.

- [ ] **Step 3: Fire mutants M15, M16, M17**

`cp lib/src/draft_painter.dart /tmp/dp.dart.bak` and
`cp lib/src/vertices_draw_sink.dart /tmp/vds.dart.bak`.

| mutant | edit | must redden |
|---|---|---|
| M15 | in `_drawText`, keep `_culledText++` but delete the `return` after it | `text accounting closes` — the sum exceeds the leaf count |
| M16 | delete `_textOps = 0;` from the top of `paint()` | `a repeated frame is a repeated frame` |
| M17 | in `VerticesDrawSink.text`, guard the delegation so one op is dropped (`if (_frameTextOps++ != 0) _fallback?.text(...)`) | `the vertices backend loses no text` |

M17 needs a counter field to drop exactly one op; add it as part of the
mutation and remove it with the restore. Record all three transcripts.

- [ ] **Step 4: Full suite, then commit**

```sh
CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

```bash
git add packages/jet_cad_2d_flutter/test/invariants/frame_accounting_test.dart
git commit -m "test: three frame-accounting identities the rig only printed

Text accounting closes, a repeated frame reads identically, and the
vertices backend loses no text through its fallback. No magic constants:
each holds at any corpus size, which is why the fixture is tiny and always
runs while the rig stays skipped.

The third identity replaces one that could not fail. Asserting that five
counters agree across backends is guaranteed by construction -- all five
are DraftPainter fields, DrawSink is write-only, and the painter never
branches on its sink. Comparing a sink-owned count against a painter-owned
one is a real comparison; the rig's version has teeth only because it
compares two processes.

The expected leaf count is derived from the document, never read back off
the painter: an identity whose two sides share a source is not one."
```

---

## Task 7: `AllocationMeter` moves, and the probe decides whether it works

**Files:**
- Move: `packages/jet_cad_2d/test/invariants/vm_allocation_meter.dart` → `packages/jet_cad_2d/lib/src/testing/allocation_meter.dart`
- Modify: `packages/jet_cad_2d/lib/testing.dart`
- Modify: `packages/jet_cad_2d/pubspec.yaml`
- Modify: `packages/jet_cad_2d/test/invariants/query_allocation_test.dart:97`, `packages/jet_cad_2d/test/invariants/text_paint_allocation_test.dart:19`, `packages/jet_cad_2d/test/index/packed_rtree_test.dart:7`
- Create: `packages/jet_cad_2d_flutter/test/invariants/allocation_meter_probe_test.dart`

**Interfaces:**
- Consumes: nothing from earlier tasks. This task is independent of Sections 1 and 2 and could run first.
- Produces: `package:jet_cad_2d/testing.dart` exports `AllocationMeter`.

**The order is forced.** Dart cannot import another package's `test/`
directory, so the probe cannot run until the meter has moved. Move, re-point,
prove the engine suite still green, *then* probe — so a red probe is
unambiguously about `flutter test` and not about the move.

**The stop clause is pre-committed and binding.** If `connect()` returns null,
or the positive control reads below 90%, then **revert the file move, the three
import re-points, and the `pubspec.yaml` promotion of `vm_service` from
`dev_dependencies` to `dependencies`**, record the finding with its transcript,
and drop Section 3. Sections 1 and 2 do not depend on the meter. Do not
negotiate with a red probe; do not weaken the threshold to make it pass.

- [ ] **Step 1: Move the file, unchanged**

```sh
cd packages/jet_cad_2d
git mv test/invariants/vm_allocation_meter.dart lib/src/testing/allocation_meter.dart
```

The contents travel verbatim, including the long header on the three failure
modes it designs around. While the file is open, its header says "Two separate
failure modes found and designed around" and then enumerates three; correct the
count.

- [ ] **Step 2: Export it and promote the dependency**

In `lib/testing.dart`, add below the existing export:

```dart
export 'src/testing/allocation_meter.dart';
```

In `pubspec.yaml`, move `vm_service: ^15.2.0` from `dev_dependencies` into
`dependencies`. **State the cost in the task report rather than glossing it:** a
Dart dependency resolves at package level, not library level, so every consumer
of `jet_cad_2d` now resolves `vm_service` even though `jet_cad_2d.dart` does
not export `testing.dart`. Tree shaking removes the unused code from a built
application; what is paid is dependency-tree weight.

- [ ] **Step 3: Re-point the three call sites**

Replace the relative import in each with the package import:

```dart
import 'package:jet_cad_2d/testing.dart';
```

- `test/invariants/query_allocation_test.dart:97` (was `import 'vm_allocation_meter.dart';`)
- `test/invariants/text_paint_allocation_test.dart:19` (was `import 'vm_allocation_meter.dart';`)
- `test/index/packed_rtree_test.dart:7` (was `import '../invariants/vm_allocation_meter.dart';`)

If a file already imports `package:jet_cad_2d/jet_cad_2d.dart` and now has two
package imports, that is fine — `testing.dart` is deliberately not exported
from the main library.

- [ ] **Step 4: Prove the move changed nothing**

```sh
cd packages/jet_cad_2d && CI=true dart pub get
CI=true dart test && dart analyze && dart format --output=none --set-exit-if-changed .
```

Expected: the whole engine suite green, including the allocation tests that use
the meter. **This gate exists so a red probe in Step 6 cannot be blamed on the
move.** If anything here is red, fix it before going near the probe.

- [ ] **Step 5: Write the probe**

Create `packages/jet_cad_2d_flutter/test/invariants/allocation_meter_probe_test.dart`:

```dart
// Does the VM allocation profiler work under `flutter test`?
//
// `AllocationMeter` relies on `dart:developer`'s
// `Service.controlWebServer(enable: true)` to start the VM service at runtime,
// from inside the isolate under test, with no launch flag. That was verified
// under plain `dart test` when the meter was written. It has never been
// verified under `flutter test`, whose tests run inside the `flutter_tester`
// engine binary — and Plan 3f recorded the Flutter side's allocation question
// as unmeasurable on exactly that assumption.
//
// Connecting is not the bar. A meter that connects and reports zero is worse
// than no meter, because it reports green. So this asks two questions.

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/testing.dart';

/// Allocated only by this file, so nothing else on the heap can be attributed
/// to it. The meter's own guidance is to watch classes the path under test does
/// not build in bulk; here the path under test *is* the allocation.
class ProbeWitness {
  ProbeWitness(this.serial);
  final int serial;
}

const int kProbeAllocations = 100000;

void main() {
  test('the allocation profiler connects and counts under flutter test',
      () async {
    final meter = await AllocationMeter.connect();
    if (meter == null) {
      fail('AllocationMeter.connect() returned null under flutter test. '
          'The stop clause fires: revert the file move, the three import '
          're-points, and the vm_service promotion in '
          'packages/jet_cad_2d/pubspec.yaml, record this transcript, and drop '
          'Section 3 of the plan.');
    }

    await meter.reset();

    // The allocations must ESCAPE. An allocation the JIT can prove dead may
    // never happen, and a healthy meter would then read zero and be blamed
    // for it. Retaining every instance in a list the compiler cannot see
    // through is what makes this a positive control rather than a coin flip.
    final retained = <ProbeWitness>[];
    for (var i = 0; i < kProbeAllocations; i++) {
      retained.add(ProbeWitness(i));
    }
    expect(retained.length, kProbeAllocations);

    // At most one call per reset -- see the meter's failure mode 3.
    final counts = await meter.accumulatedInstances({'ProbeWitness'});
    final seen = counts['ProbeWitness'] ?? 0;

    expect(seen, greaterThanOrEqualTo((kProbeAllocations * 0.9).round()),
        reason: 'the meter connected but under-counted a known allocation: '
            'saw $seen of $kProbeAllocations. The stop clause fires.');
  }, timeout: const Timeout(Duration(seconds: 60)));
}
```

- [ ] **Step 6: Run the probe and read the result honestly**

```sh
cd packages/jet_cad_2d_flutter && CI=true dart pub get
CI=true flutter test test/invariants/allocation_meter_probe_test.dart
```

Paste the **verbatim** output into the task report, green or red. This is the
one result in the plan whose value does not depend on which way it goes.

- [ ] **Step 7a: If GREEN — commit and report**

```bash
git add packages/jet_cad_2d/lib/src/testing/allocation_meter.dart \
        packages/jet_cad_2d/lib/testing.dart \
        packages/jet_cad_2d/pubspec.yaml \
        packages/jet_cad_2d/test/invariants/query_allocation_test.dart \
        packages/jet_cad_2d/test/invariants/text_paint_allocation_test.dart \
        packages/jet_cad_2d/test/index/packed_rtree_test.dart \
        packages/jet_cad_2d_flutter/test/invariants/allocation_meter_probe_test.dart
git commit -m "test: the allocation meter is reachable from the Flutter package

Dart cannot import another package's test/ directory, so
jet_cad_2d_flutter had no allocation instrument except
VerticesDrawSink.debugCapacityVertices -- which Plan 3e proved blind to a
lazily populated cache, exactly the shape of Plan 3g's picture cache.

Moves the meter to lib/src/testing/ behind the existing lib/testing.dart,
whose own doc comment already argues this case for generate_document.dart.
vm_service is promoted from a dev dependency to a real one: dependency
resolution is package-level, so every consumer now resolves it.

The probe asks two questions, because a meter that connects and reports
zero is worse than none: it connects, and it counts an escaping known
allocation to within 10%."
```

Report explicitly that Plan 3g may now write its own trap-5 gate against its
own cache, on an instrument proven to count. **Do not write that gate here** —
there is no lazy cache-miss path in this repository to instrument; the fill
path is explicitly eager and says so at `draft_painter.dart:686-690`.

- [ ] **Step 7b: If RED — revert in full and report**

```sh
cd /Users/ahmeturel/Projects/oss/jet-cad
git checkout -- packages/jet_cad_2d/pubspec.yaml
git mv packages/jet_cad_2d/lib/src/testing/allocation_meter.dart \
       packages/jet_cad_2d/test/invariants/vm_allocation_meter.dart
```

Then restore the three relative imports, remove the `testing.dart` export line,
delete the probe file, and re-run both suites to confirm the tree is back where
it started. (`git checkout` on `pubspec.yaml` is reverting a whole file to its
committed state, not reverting a mutation — the mutation rule does not apply.)

Record in the task report, and later in the results note: the verbatim probe
output, the exact `flutter test` invocation, and the conclusion that Plan 3g's
central risk must be gated by a command-time assertion rather than a frame-path
allocation gate — which is what actually proved fills eager in Plan 3e, after
the allocation gate stayed green through the mutation that should have broken
it.

---

## Task 8: the exit gate

**Files:**
- Create: `docs/superpowers/notes/2026-08-23-plan-3f1-results.md`
- Create: `docs/superpowers/notes/plan-3f1-mutation-log.md`
- Modify: `STATUS.md`

**Interfaces:**
- Consumes: every task's report and every mutation transcript.
- Produces: the results of record.

- [ ] **Step 1: Run the whole gate, both packages, from a clean tree**

```sh
cd /Users/ahmeturel/Projects/oss/jet-cad
git status --short
cd packages/jet_cad_2d         && CI=true dart test    && dart analyze    && dart format --output=none --set-exit-if-changed .
cd ../jet_cad_2d_flutter       && CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
cd .. && git status --short jet_cad_2d_flutter/test/golden
```

Record the test counts verbatim. The golden `git status` must be empty.

- [ ] **Step 2: Score all seventeen criteria**

Write `docs/superpowers/notes/2026-08-23-plan-3f1-results.md` with one row per
criterion: number, claim, the command that proves it, the observed result, and
PASS / MISS / UNEVALUABLE. Criterion 17 is scored by whichever branch of Task 7
ran. **Never synthesize a transcript**; if a criterion was not run, mark it
UNEVALUABLE and say why.

The note must also carry, in its own section, anything this plan did **not**
close — at minimum:

- **Permitted divergence 5** — overlapping translucent strokes on a triangle
  soup. Untouched by this plan, still unexercised by any fixture.
- **The malformed-layer asymmetry**, mirrored rather than fixed (spec accepted
  gap 2).
- **Ruling 4's `kParagraphCacheLimit` raise**, still unspent, still carrying its
  measured 3,876.
- **Whatever Task 7's probe decided**, in full.

- [ ] **Step 3: Write the mutation log**

Write `docs/superpowers/notes/plan-3f1-mutation-log.md` with one section per
mutant M1–M17: the exact edit, the exact command, the verbatim output, and
whether it was killed. A mutant that no criterion reddened is recorded as a
**survivor with its reason** — never quietly dropped. Plan 3f's log carries
three such entries and they are the most useful rows in it.

- [ ] **Step 4: Update `STATUS.md`**

- A "Plan 3f.1 — hardening" section under the roadmap, before the 3g section:
  what landed, the criteria score, the commit range, links to both notes.
- Amend the **Plan 3g** section: trap 4 (`InstanceNode` carries 2 of 6 fields)
  is **closed** — say so rather than deleting the trap, so a reader of the
  older notes can follow the thread.
- Add to 3g's inheritance the cache-key cardinality consequence: `StyleContext`
  compares `linetypeScale` with `==` and hashes it, so once the four fields
  carry real values, instances that used to share a definition picture no
  longer do — and because the scale is a product accumulated down the tree, two
  chains whose scales are mathematically equal but reached by different factors
  are different doubles and therefore different keys. A reason 3g may want a
  quantised scale band in its key rather than the raw double.
- Record whether the Flutter package now has a working allocation meter.

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/notes/2026-08-23-plan-3f1-results.md \
        docs/superpowers/notes/plan-3f1-mutation-log.md \
        STATUS.md
git commit -m "docs: Plan 3f.1 results, mutation log, and STATUS update"
```

---

## Self-review

**Spec coverage.** Decisions 1–4 → Tasks 1–4. Decision 5's hazard → the
anti-degenerate rule in Global Constraints, enforced in every Section 1 fixture
and in Task 3's explicit note that the `1.0` guard test is not the proof.
Decision 6 → Tasks 5 and 6, with the rig and `dart_test.yaml` untouched.
Decisions 7–9 → Task 7, including the full-revert stop clause and the explicit
refusal to write a trap-5 gate here. Criteria 1–17 map to Tasks 2, 3, 2, 3, 2,
2, 2, 2, 4, 1, 4, 5, 5, 6, 6, 6, 7. Mutants M1–M17 map to Tasks 2, 2, 2, 3, 3,
2, 2, 2, 2, 1+4, 1, 5, 5, 5, 6, 6, 6.

**Every identifier in this plan was read from the tree while writing it**, not
recalled: `DraftDocumentCodec.encode`/`.decode` and the `'nodes'` key
(`json_codec.dart:36,56,92`), `RecordingDrawSink` and `TextOp.text`
(`draw_sink.dart:289,267,270`), `VerticesDrawSink`'s constructor
(`vertices_draw_sink.dart:105-111`), `leavesByOwner()` (`reference_walk.dart:41`),
`liveMetricsCount`/`liveParagraphCount` (`flutter_text_measurer.dart:109,112`),
`kByBlock = -2` / `kLineweightDefault = -3` / `byBlockLinetype = Handle(3)`
(`style.dart:6,9,12,107`), and the seven `_canvasCalls++` sites
(`canvas_draw_sink.dart:137,152,159,168,189,200,226`). The first draft of this
plan sent the implementer to re-derive four of those; a plan that outsources
its own signatures sends someone to debug a fabricated one.

**One thing is deliberately left to the implementer:** Task 4's `v5Document()`
derives its fixture by encoding a real document and removing four keys, rather
than hand-writing the codec's JSON shape. That is not a gap — a hand-written
shape would be a second, drifting copy of the contract, and one that silently
fails to parse proves less than nothing about a migration.

**Task independence.** Section 3 (Task 7) depends on nothing and can run first
if its probe result is wanted early. Tasks 5 and 6 depend on nothing in
Section 1. Within Section 1 the order is forced: 1 → 2 → 3 → 4.
