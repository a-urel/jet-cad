### Task 7: The catalog language and the library builder (K6)

**Files:**
- Create: `lib/src/authoring/catalog.dart`, `lib/src/authoring/builder.dart`
- Modify: `lib/authoring.dart` (two exports)
- Test: `test/authoring/builder_test.dart`

**Interfaces:**
- Consumes: `registerKitComponents`, `LibraryComponent`, `SymbolComponent`, `UnitComponent`, `UnitLabelling`, `UnitKinds`, `SymbolLibrary.decode`, `SymbolLibraryError` (Tasks 2-5); from `jet_cad_2d`: `DraftDocument.empty()`, `DrawingUnits`, `DraftCommand`, `AddDefinitionCommand`, `SetComponentCommand<T>`, `AddEntityCommand`, `CompoundCommand`, `Definition`, `EntityRecord`, `EntityKind`, `ReservedHandles`, `ByBlockColor`, `kByBlock`, `linePayload`, `polylinePayload`, `circlePayload`, `arcPayload`, `GeometryPayload`, `DraftDocumentCodec.encodeToString`; `Vector2` from `vector_math`.
- Produces (exported from `package:jet_cad_2d_kit/authoring.dart`):
  - `typedef CatalogPoint = (double, double);`
  - `sealed class CatalogShape`; `final class CatalogLine(CatalogPoint from, CatalogPoint to)`; `final class CatalogPolyline(List<CatalogPoint> points, {bool closed = false})`; `final class CatalogCircle(CatalogPoint center, double radius)`; `final class CatalogArc(CatalogPoint center, double radius, double start, double sweep)` — all `const` constructors, positional fields as named.
  - `final class CatalogUnit` — `const CatalogUnit({required String kind, required int capacity, UnitLabelling labelling = UnitLabelling.numbered})`.
  - `final class CatalogSymbol` — `const CatalogSymbol({required String key, int version = 1, required String name, required String category, List<String> tags = const [], List<String> attachTo = const [], String? family, CatalogUnit? unit, required CatalogPoint base, required List<CatalogShape> shapes})`; `String get id`.
  - `final class Catalog` — `const Catalog({required String kit, required List<CatalogSymbol> symbols})`.
  - `DraftDocument buildLibraryDocument(Catalog catalog)` (the caller disposes it); `Uint8List encodeLibrary(Catalog catalog)`.

Plan decision: points in the catalog language are records, `typedef CatalogPoint = (double, double)`, matching K6's `base: (0, 0)`; integer literals in them are doubles by context.
Plan decision: `encodeLibrary` decodes its own output with `SymbolLibrary.decode` and lets a `SymbolLibraryError` through, so a generator can never write a library the decoder refuses (a duplicate `key@version`, a unit whose first shape is open, a zero radius). `buildLibraryDocument` does not validate: it is the test seam.

- [ ] **Step 1: Write the failing test.** Create `test/authoring/builder_test.dart`:

```dart
// Spec K6: the builder. Deterministic, handles in catalog order, every shape
// kind round-trips through decode, a unit's components, and the format's
// refusals reach the generator. Off the origin, an arc with a negative
// sweep, a seat unit with assigned labels (umbrella A6).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/authoring.dart';

const CatalogSymbol table = CatalogSymbol(
  key: 'sample.table.round-two',
  version: 2,
  name: 'Round table, 2 seats',
  category: 'Tables',
  tags: ['table', 'round', 'two'],
  unit: CatalogUnit(kind: UnitKinds.table, capacity: 2),
  base: (1800, 950),
  shapes: [
    CatalogCircle((1800, 950), 400),
    CatalogPolyline([(1575, 325), (2025, 325), (2025, 775), (1575, 775)],
        closed: true),
    CatalogLine((1575, 385), (2025, 385)),
  ],
);

const CatalogSymbol lamp = CatalogSymbol(
  key: 'sample.lamp.wall',
  name: 'Wall lamp',
  category: 'Lighting',
  tags: ['lamp', 'light'],
  attachTo: ['wall-face'],
  family: 'lamp-wall',
  base: (640, 220),
  shapes: [
    CatalogArc((640, 220), 180, 0.25, -2.75),
    CatalogPolyline([(460, 220), (820, 220), (700, 90)]),
  ],
);

const CatalogSymbol seat = CatalogSymbol(
  key: 'sample.seat.row-end',
  name: 'Row-end seat',
  category: 'Seats',
  tags: ['seat'],
  unit: CatalogUnit(
      kind: UnitKinds.seat, capacity: 1, labelling: UnitLabelling.assigned),
  base: (300, 260),
  shapes: [
    CatalogPolyline([(80, 60), (520, 60), (520, 480), (80, 480)],
        closed: true),
    CatalogLine((80, 120), (520, 120)),
  ],
);

const Catalog catalog = Catalog(kit: 'sample', symbols: [table, lamp, seat]);

void main() {
  test('B1 deterministic: two builds give the same bytes', () {
    // M-B1: allocate handles from a random start.
    expect(encodeLibrary(catalog), encodeLibrary(catalog));
    const again = Catalog(kit: 'sample', symbols: [table, lamp, seat]);
    expect(encodeLibrary(again), encodeLibrary(catalog));
  });

  test('B2 handles ascend: a definition, its leaves, the next definition',
      () {
    final doc = buildLibraryDocument(catalog);
    addTearDown(doc.dispose);
    final defs = [for (final d in doc.tree.definitions) d.handle.value];
    expect(defs, hasLength(3));
    // M-B2: allocate every definition first, then the leaves.
    expect(defs[1], defs[0] + table.shapes.length + 1);
    expect(defs[2], defs[1] + lamp.shapes.length + 1);
    final names = [for (final d in doc.tree.definitions) d.name];
    expect(names, [
      'sample.table.round-two@2',
      'sample.lamp.wall@1',
      'sample.seat.row-end@1',
    ]);
    final leaves = [
      for (final slot in doc.entities.liveSlots) doc.entities.read(slot),
    ];
    expect([for (final r in leaves) r.handle.value], [
      for (var i = 0; i < 3; i++) defs[0] + 1 + i,
      for (var i = 0; i < 2; i++) defs[1] + 1 + i,
      for (var i = 0; i < 2; i++) defs[2] + 1 + i,
    ]);
    expect([for (final r in leaves) r.owner.value], [
      defs[0], defs[0], defs[0], defs[1], defs[1], defs[2], defs[2], //
    ]);
  });

  test('B3 every shape kind and every field round-trips through decode', () {
    final library = SymbolLibrary.decode(encodeLibrary(catalog));
    expect(library.kits, ['sample']);
    final byId = {for (final e in library.entries) e.id: e};
    expect(byId.keys.toList(), [
      'sample.table.round-two@2',
      'sample.lamp.wall@1',
      'sample.seat.row-end@1',
    ]);
    // M-B3a: drop attachTo or family when building the component.
    expect(
        byId['sample.lamp.wall@1']!.symbol,
        SymbolComponent(
          key: 'sample.lamp.wall',
          version: 1,
          name: 'Wall lamp',
          category: 'Lighting',
          tags: const ['lamp', 'light'],
          attachTo: const ['wall-face'],
          family: 'lamp-wall',
        ));
    expect(byId['sample.lamp.wall@1']!.unit, isNull);
    // M-B3b: drop the labelling when building the unit.
    expect(
        byId['sample.seat.row-end@1']!.unit,
        UnitComponent(
            kind: UnitKinds.seat,
            capacity: 1,
            labelling: UnitLabelling.assigned));
    expect(byId['sample.table.round-two@2']!.unit,
        UnitComponent(kind: UnitKinds.table, capacity: 2));
    final t = byId['sample.table.round-two@2']!;
    expect(t.definition.basePoint.x, 1800);
    expect(t.definition.basePoint.y, 950);
    expect([for (final l in t.leaves) l.record.kind],
        [EntityKind.circle, EntityKind.polyline, EntityKind.line]);
    expect(t.leaves[0].payload.coords, [1800, 950]);
    expect(t.leaves[0].payload.scalars, [400]);
    // A closed polyline repeats its first point.
    expect(t.leaves[1].payload.coords,
        [1575, 325, 2025, 325, 2025, 775, 1575, 775, 1575, 325]);
    expect(t.leaves[2].payload.coords, [1575, 385, 2025, 385]);
    final l = byId['sample.lamp.wall@1']!;
    // M-B3c: write the arc's start and sweep swapped.
    expect(l.leaves[0].payload.coords, [640, 220]);
    expect(l.leaves[0].payload.scalars, [180, 0.25, -2.75]);
    expect(l.leaves[1].payload.coords, [460, 220, 820, 220, 700, 90]);
  });

  test('B4 the root carries the library component, in millimetres', () {
    final doc = buildLibraryDocument(catalog);
    addTearDown(doc.dispose);
    expect(doc.header.units, DrawingUnits.millimeters);
    final text = utf8.decode(encodeLibrary(catalog));
    expect(
        text,
        contains('"jetcad.library":{"${doc.rootHandle.value}":'
            '{"format":1,"kit":"sample"}}'));
  });

  test("B5 the format's refusals reach the generator", () {
    // M-B5: return the bytes without decoding them.
    expect(
        () => encodeLibrary(
            const Catalog(kit: 'sample', symbols: [table, lamp, table])),
        throwsA(isA<SymbolLibraryError>().having((e) => e.rule, 'rule', 6)));
    const openUnit = CatalogSymbol(
      key: 'sample.table.open',
      name: 'Open table',
      category: 'Tables',
      unit: CatalogUnit(kind: UnitKinds.table, capacity: 4),
      base: (500, 500),
      shapes: [CatalogLine((100, 100), (900, 900))],
    );
    expect(
        () => encodeLibrary(const Catalog(kit: 'sample', symbols: [openUnit])),
        throwsA(isA<SymbolLibraryError>().having((e) => e.rule, 'rule', 11)));
    const dot = CatalogSymbol(
      key: 'sample.dot.zero',
      name: 'Dot',
      category: 'Tests',
      base: (500, 500),
      shapes: [CatalogCircle((500, 500), 0)],
    );
    expect(() => encodeLibrary(const Catalog(kit: 'sample', symbols: [dot])),
        throwsA(isA<SymbolLibraryError>().having((e) => e.rule, 'rule', 15)));
  });

  test("B6 a component's refusal is the constructor's ArgumentError", () {
    const upper = CatalogSymbol(
      key: 'sample.Table.round',
      name: 'Table',
      category: 'Tables',
      base: (500, 500),
      shapes: [CatalogCircle((500, 500), 300)],
    );
    expect(() => encodeLibrary(const Catalog(kit: 'sample', symbols: [upper])),
        throwsArgumentError);
    expect(() => encodeLibrary(const Catalog(kit: 'Sample', symbols: [])),
        throwsArgumentError);
  });

  test('B7 an empty catalog is a valid, empty library', () {
    // Review Focus 4.
    final library =
        SymbolLibrary.decode(encodeLibrary(const Catalog(kit: 'sample', symbols: [])));
    expect(library.kits, ['sample']);
    expect(library.entries, isEmpty);
  });
}
```

- [ ] **Step 2: Run it to see it fail.** Run: `cd packages/jet_cad_2d_kit && flutter test test/authoring/builder_test.dart`. Expected: compilation errors (`Undefined class 'CatalogSymbol'`).

- [ ] **Step 3: The catalog language.** Create `lib/src/authoring/catalog.dart`:

```dart
// The catalog language (spec K6): a kit's symbols as plain data, in
// millimetres, each in its own frame. Geometry only: lines, polylines,
// circles and arcs. Replaces jet_cad_floor_plan's FurnitureSymbol and
// FurnitureShape.
//
// Pure Dart: no Flutter, no dart:io.
import '../model/unit_component.dart';

/// A point, (x, y) in millimetres.
typedef CatalogPoint = (double, double);

/// One drawn shape of a symbol.
sealed class CatalogShape {
  const CatalogShape();
}

final class CatalogLine extends CatalogShape {
  const CatalogLine(this.from, this.to);

  final CatalogPoint from;
  final CatalogPoint to;
}

/// A polyline through [points]; [closed] repeats the first point.
final class CatalogPolyline extends CatalogShape {
  const CatalogPolyline(this.points, {this.closed = false});

  final List<CatalogPoint> points;
  final bool closed;
}

final class CatalogCircle extends CatalogShape {
  const CatalogCircle(this.center, this.radius);

  final CatalogPoint center;
  final double radius;
}

/// A counter-clockwise arc from [start] through [sweep], both in radians.
final class CatalogArc extends CatalogShape {
  const CatalogArc(this.center, this.radius, this.start, this.sweep);

  final CatalogPoint center;
  final double radius;
  final double start;
  final double sweep;
}

/// A symbol's service unit (umbrella A6).
final class CatalogUnit {
  const CatalogUnit({
    required this.kind,
    required this.capacity,
    this.labelling = UnitLabelling.numbered,
  });

  final String kind;
  final int capacity;
  final UnitLabelling labelling;
}

/// One symbol of a kit's library. A unit draws its outline first (K3 rule
/// 11): a closed polyline or a circle.
final class CatalogSymbol {
  const CatalogSymbol({
    required this.key,
    this.version = 1,
    required this.name,
    required this.category,
    this.tags = const [],
    this.attachTo = const [],
    this.family,
    this.unit,
    required this.base,
    required this.shapes,
  });

  final String key;
  final int version;
  final String name;
  final String category;
  final List<String> tags;
  final List<String> attachTo;
  final String? family;
  final CatalogUnit? unit;
  final CatalogPoint base;
  final List<CatalogShape> shapes;

  /// `key@version`.
  String get id => '$key@$version';
}

/// A kit's symbols, in library order.
final class Catalog {
  const Catalog({required this.kit, required this.symbols});

  final String kit;
  final List<CatalogSymbol> symbols;
}
```

- [ ] **Step 4: The builder.** Create `lib/src/authoring/builder.dart`:

```dart
// The library builder (spec K6): a catalog in, a library document out, one
// definition per symbol named key@version, in one compound command. Ported
// from jet_cad_floor_plan's build_library.dart.
//
// The document is DraftDocument.empty, the kit components and millimetre
// units, nothing else (not prepareDocument: its DASHED linetype is not in
// K3's list).
//
// Pure Dart: no Flutter, no dart:io.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../model/library_component.dart';
import '../model/register.dart';
import '../model/symbol_component.dart';
import '../model/symbol_library.dart';
import '../model/unit_component.dart';
import 'catalog.dart';

/// The library document of [catalog]. Deterministic: handles ascend in
/// catalog order (a definition, its leaves, the next definition). Every leaf
/// is on layer 0 with BYBLOCK linetype, colour, lineweight and transparency
/// and no flag (K3 rule 14). The caller disposes the document.
///
/// Throws a component's [ArgumentError] for a value spec K2 refuses.
DraftDocument buildLibraryDocument(Catalog catalog) {
  // Every component is constructed, and so validated, before the document
  // exists: a value K2 refuses throws here and leaves nothing to dispose.
  final library = LibraryComponent(kit: catalog.kit);
  final symbols = [
    for (final s in catalog.symbols)
      SymbolComponent(
        key: s.key,
        version: s.version,
        name: s.name,
        category: s.category,
        tags: s.tags,
        attachTo: s.attachTo,
        family: s.family,
      ),
  ];
  final units = [
    for (final s in catalog.symbols)
      if (s.unit case final unit?)
        UnitComponent(
            kind: unit.kind,
            capacity: unit.capacity,
            labelling: unit.labelling)
      else
        null,
  ];
  final doc = DraftDocument.empty();
  registerKitComponents(doc.components);
  doc.header.units = DrawingUnits.millimeters;
  final commands = <DraftCommand>[
    SetComponentCommand<LibraryComponent>(doc.rootHandle, library),
  ];
  for (var i = 0; i < catalog.symbols.length; i++) {
    final s = catalog.symbols[i];
    final def = doc.handleSeed.next();
    commands
      ..add(AddDefinitionCommand(Definition(
        handle: def,
        name: s.id,
        basePoint: Vector2(s.base.$1, s.base.$2),
        children: const [],
      )))
      ..add(SetComponentCommand<SymbolComponent>(def, symbols[i]));
    final unit = units[i];
    if (unit != null) {
      commands.add(SetComponentCommand<UnitComponent>(def, unit));
    }
    for (final shape in s.shapes) {
      commands.add(AddEntityCommand(
        record: EntityRecord(
          handle: doc.handleSeed.next(),
          owner: def,
          kind: _kindOf(shape),
          layer: ReservedHandles.layerZero,
          linetype: ReservedHandles.byBlockLinetype,
          linetypeScale: 1.0,
          geomIndex: 0,
          color: const ByBlockColor(),
          lineweight: kByBlock,
          transparency: kByBlock,
          flags: 0,
        ),
        payload: _payloadOf(shape),
      ));
    }
  }
  doc.commands.execute(CompoundCommand(commands, label: 'Symbol library'));
  doc.commands.clearHistory();
  return doc;
}

/// The `.jetlib` bytes of [catalog]: the codec's JSON of
/// [buildLibraryDocument], UTF-8. The same catalog gives the same bytes.
///
/// Decodes its own output: throws the [SymbolLibraryError] of a catalog the
/// format refuses, so a generator never writes such a library.
Uint8List encodeLibrary(Catalog catalog) {
  final doc = buildLibraryDocument(catalog);
  try {
    final bytes =
        Uint8List.fromList(utf8.encode(DraftDocumentCodec.encodeToString(doc)));
    SymbolLibrary.decode(bytes);
    return bytes;
  } finally {
    unawaited(doc.dispose());
  }
}

EntityKind _kindOf(CatalogShape shape) => switch (shape) {
      CatalogLine() => EntityKind.line,
      CatalogPolyline() => EntityKind.polyline,
      CatalogCircle() => EntityKind.circle,
      CatalogArc() => EntityKind.arc,
    };

Vector2 _v(CatalogPoint p) => Vector2(p.$1, p.$2);

GeometryPayload _payloadOf(CatalogShape shape) => switch (shape) {
      CatalogLine(:final from, :final to) => linePayload(_v(from), _v(to)),
      CatalogPolyline(:final points, :final closed) =>
        polylinePayload([for (final p in points) _v(p)], closed: closed),
      CatalogCircle(:final center, :final radius) =>
        circlePayload(_v(center), radius),
      CatalogArc(:final center, :final radius, :final start, :final sweep) =>
        arcPayload(_v(center), radius, start, sweep),
    };
```

In `lib/authoring.dart`, the exports become:

```dart
export 'src/authoring/builder.dart';
export 'src/authoring/catalog.dart';
export 'src/model/model.dart';
```

- [ ] **Step 5: Run the tests.** Run: `cd packages/jet_cad_2d_kit && flutter test test/authoring test/invariants`. Expected: `All tests passed!` (P1 now walks `builder.dart` and `catalog.dart` and finds them pure).

- [ ] **Step 6: Mutation check** (on committed files; revert each with `git checkout -- <file>` and check `git diff --quiet`): M-B1 (allocate handles from a random start) → B1 red; M-B2 (build every `AddDefinitionCommand` in a first loop, the leaves in a second) → B2 red; M-B3a (omit `attachTo: s.attachTo,`) → B3 red; M-B3b (omit `labelling: unit.labelling`) → B3 red; M-B3c (`arcPayload(_v(center), radius, sweep, start)`) → B3 red; M-B5 (delete `SymbolLibrary.decode(bytes);`) → B5 red; M-P1 (add `import 'package:flutter/foundation.dart';` to `builder.dart`) → P1 red.

- [ ] **Step 7: The gate.** `cd packages/jet_cad_2d_kit && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — all exit 0.

- [ ] **Step 8: Commit.**

```bash
git add packages/jet_cad_2d_kit/lib/authoring.dart packages/jet_cad_2d_kit/lib/src/authoring/catalog.dart packages/jet_cad_2d_kit/lib/src/authoring/builder.dart packages/jet_cad_2d_kit/test/authoring/builder_test.dart
git commit -m "$(cat <<'EOF'
feat(kit): the catalog language and the library builder (K6)

Catalog, CatalogSymbol, CatalogUnit and the sealed CatalogShape family
(line, polyline, circle, arc) describe a kit's symbols as data.
buildLibraryDocument makes one definition per key@version with handles
in catalog order; encodeLibrary writes its bytes and decodes them first,
so a generator never writes a library the decoder refuses.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---
