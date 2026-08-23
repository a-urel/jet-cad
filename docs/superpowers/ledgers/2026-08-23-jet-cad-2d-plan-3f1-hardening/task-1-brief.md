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

