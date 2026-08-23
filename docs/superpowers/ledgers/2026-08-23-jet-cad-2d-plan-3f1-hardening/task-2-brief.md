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

