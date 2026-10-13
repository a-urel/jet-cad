### Task 4: The library format: `SymbolLibrary.decode` and its fifteen rules (K3)

**Files:**
- Create: `lib/src/model/symbol_library.dart`
- Modify: `lib/src/model/model.dart` (add `export 'symbol_library.dart';`)
- Create: `test/support/library_fixtures.dart`
- Test: `test/model/symbol_library_test.dart`

**Interfaces:**
- Consumes: `registerKitComponentsWrapped`, `ComponentRead` (Task 3, imported from `register.dart` directly), the four components, `kitOfKey` (Tasks 2-3); from `jet_cad_2d`: `DraftDocumentCodec.decodeString(source, diagnostics:, registerComponents:)`, `Diagnostic.message`, `DraftDocument` (`header.units`, `rootHandle`, `tree.nodes`, `tree.definitions`, `components.get<T>/withComponent<T>`, `entities.liveSlots/read/geomIndexAt`, `geometry.read`, `dispose()`), `InstanceNode`, `GroupNode`, `Definition` (`handle`, `name`, `basePoint`, `children`, `isXref`), `EntityRecord` (`layer`, `linetype`, `linetypeScale`, `color`, `lineweight`, `transparency`, `flags`, `textStyle`, `text`, `tag`, `textAttrs`), `EntityKind`, `GeometryPayload` (`coords`, `scalars`, `pointCount`, `pointAt`), `ReservedHandles`, `ByBlockColor`, `kByBlock`, `isClosedPolyline`, `isDegenerateSegment`, `Tolerance.standard`, `DrawingUnits`, `Handle.toHex()`.
- Produces (exported):
  - `typedef SymbolLeaf = ({EntityRecord record, GeometryPayload payload});`
  - `final class SymbolLibraryError implements Exception` — `const SymbolLibraryError(int rule, String message)`; `final int rule` (K3's rule number, 1-15); `final String message`.
  - `final class SymbolEntry` — `SymbolComponent symbol`, `UnitComponent? unit`, `Definition definition`, `List<SymbolLeaf> leaves` (ascending by handle, unmodifiable), `String get id`.
  - `final class SymbolLibrary` — `static const double maxCoordinate = 1e6`; `static const int format = 1`; `List<String> kits`; `List<SymbolEntry> entries` (definition-handle order); `List<String> get categories`; `static SymbolLibrary decode(Uint8List bytes)`. Task 5 adds `static SymbolLibrary merge(List<SymbolLibrary> libraries)`.
- Test support (Tasks 5, 6 reuse it): `test/support/library_fixtures.dart` — `sofaDef`, `tableDef`, `armchairDef`, the leaf handle constants, `sofaSymbol()`, `tableSymbol()`, `tableUnit()`, `armchairSymbol()`, `fixtureLeaves()`, `buildValidLibrary()`, `bytesOf(DraftDocument)`, `validLibraryJson()`, `bytesOfJson(json, {text})`, `entityJson`, `recordJson`, `geometryJson`, `definitionJson`, `componentsJson(lib, typeId)`, `componentJson(lib, typeId, handle)`, `instanceNodeJson(...)`.

Plan decision: `SymbolLibraryError` carries the K3 rule number (`rule`), so each one-fault test pins the rule that refused it, not only words of a message.
Plan decision: `decode` registers the kit components through guarded factories (`registerKitComponentsWrapped`, same types and ids) that turn a constructor's refusal into the K3 rule it belongs to — `key` → 5; `tags`, `attachTo`, `family` and a unit's `kind` → 8; anything in `jetcad.library` → 2; any other field → 1 — because K2's constructors refuse a bad pattern while the codec decodes, before any validator code runs.
Plan decision: a unit kind off K2's pattern is refused under rule 8, the rule of every other K2 pattern.
Rule 2 as amended (1525dfe) refuses units other than millimetres and a `LibraryComponent` on any handle but the root; rule 9 as amended is a unit definition whose `SymbolComponent` has a `family`; rule 14 as amended refuses today's accepted BYLAYER and CONTINUOUS values (the old L5, inverted in V14).
Plan decision: an external-reference definition, a definition with no leaf (it would draw nothing), and a `SymbolComponent` on a handle that is not a definition are refused under rule 4.
Plan decision: rule 14 as amended (1525dfe) lists layer 0, by-block linetype, colour, lineweight and transparency, linetype scale 1 and flags 0; text style STANDARD and empty text, tag and text attributes are also exactly what the builder writes, so they are checked too.

Rule map, old → new (the old IDs are `jet_cad_floor_plan/test/symbols/symbol_library_test.dart` and `seating_test.dart`): R00, R08 → V1a, V1b; R06, R07 → V3a, V3b; R01, R04 → V4a, V4b; R03, R03b → V5b, V5c; R02, R02b → V6a, V6b; R03c → V8a; R03d (family tags) → replaced by the structured `family` (V8f, V9a); SE6 → V1d; SE7 → V10a; R05 → V12a; R09, R10, R11 → V13a, V13c; R12-R19 → V14; R20-R27e → V15; L1-L4, L6 → V0a-V0d, V0f; L5 → inverted in V14. New: rules 2, 5, 7, 8, 9, 11 and the plan decisions above.

- [ ] **Step 1: The fixtures.** Create `test/support/library_fixtures.dart`:

```dart
// Fixtures for the library validator (spec K3): a small valid library of the
// kit "sample", its bytes, and the codec-JSON helpers that break it one rule
// at a time (the breaker pattern of jet_cad_floor_plan's symbol_fixtures).
//
// Not degenerate: every base point and leaf is off the origin, the versions
// are 3, 2 and 1, the definition handles are far apart, the leaves are
// inserted out of handle order and interleaved across symbols, one symbol is
// a unit, one carries attachment kinds and a family.
import 'dart:convert';
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

const Handle sofaDef = Handle(4200);
const Handle tableDef = Handle(4300);
const Handle armchairDef = Handle(4400);

/// Leaves, by handle; the fixture inserts them in another order.
const int sofaLine = 4210,
    sofaPolyline = 4211,
    sofaArc = 4212,
    sofaCircle = 4213;
const int tableTop = 4310, tableStool = 4311;
const int armchairSeat = 4410, armchairArc = 4411;

SymbolComponent sofaSymbol() => SymbolComponent(
      key: 'sample.sofa.three',
      version: 3,
      name: 'Three-seat sofa',
      category: 'Living Room',
      tags: const ['sofa', 'seating', 'couch'],
      attachTo: const ['wall-face'],
      family: 'sofa-long',
    );

SymbolComponent tableSymbol() => SymbolComponent(
      key: 'sample.table.high-top',
      version: 2,
      name: 'High-top table',
      category: 'Bar',
      tags: const ['table', 'bar', 'high'],
    );

UnitComponent tableUnit() => UnitComponent(kind: UnitKinds.table, capacity: 4);

SymbolComponent armchairSymbol() => SymbolComponent(
      key: 'sample.chair.arm',
      version: 1,
      name: 'Armchair',
      category: 'Living Room',
      tags: const ['armchair', 'seating', 'chair'],
    );

EntityRecord leafRecord(int handle, Handle owner, EntityKind kind) =>
    EntityRecord(
      handle: Handle(handle),
      owner: owner,
      kind: kind,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byBlockLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByBlockColor(),
      lineweight: kByBlock,
      transparency: kByBlock,
      flags: 0,
    );

/// The leaves in their **insertion** (file) order: not ascending by handle,
/// and the symbols interleaved. The table's first leaf by handle is its
/// closed top; the armchair's is a circle.
List<SymbolLeaf> fixtureLeaves() => [
      (
        record: leafRecord(sofaCircle, sofaDef, EntityKind.circle),
        payload: circlePayload(Vector2(1500, 620), 45),
      ),
      (
        record: leafRecord(tableTop, tableDef, EntityKind.polyline),
        payload: polylinePayload([
          Vector2(950, 560),
          Vector2(1550, 560),
          Vector2(1550, 1160),
          Vector2(950, 1160),
        ], closed: true),
      ),
      (
        record: leafRecord(sofaLine, sofaDef, EntityKind.line),
        payload: linePayload(Vector2(120, 340), Vector2(1680, 340)),
      ),
      (
        record: leafRecord(armchairArc, armchairDef, EntityKind.arc),
        payload: arcPayload(Vector2(500, 500), 300, 0.25, 2.5),
      ),
      (
        record: leafRecord(sofaArc, sofaDef, EntityKind.arc),
        payload: arcPayload(Vector2(900, 900), 250, 0.5, 1.75),
      ),
      (
        record: leafRecord(tableStool, tableDef, EntityKind.circle),
        payload: circlePayload(Vector2(1250, 400), 190),
      ),
      (
        record: leafRecord(sofaPolyline, sofaDef, EntityKind.polyline),
        payload: polylinePayload(
            [Vector2(120, 340), Vector2(120, 900), Vector2(400, 950)]),
      ),
      (
        record: leafRecord(armchairSeat, armchairDef, EntityKind.circle),
        payload: circlePayload(Vector2(510, 480), 120),
      ),
    ];

/// The valid library: kit "sample", three symbols in two categories, the
/// table a unit.
DraftDocument buildValidLibrary() {
  final doc = DraftDocument.empty();
  registerKitComponents(doc.components);
  doc.header.units = DrawingUnits.millimeters;
  Definition def(Handle h, String name, double x, double y) =>
      Definition(handle: h, name: name, basePoint: Vector2(x, y), children: []);
  doc.commands.execute(CompoundCommand([
    SetComponentCommand<LibraryComponent>(
        doc.rootHandle, LibraryComponent(kit: 'sample')),
    AddDefinitionCommand(def(armchairDef, 'sample.chair.arm@1', 510, 35)),
    AddDefinitionCommand(def(sofaDef, 'sample.sofa.three@3', 900, 400)),
    AddDefinitionCommand(def(tableDef, 'sample.table.high-top@2', 1250, 860)),
    SetComponentCommand<SymbolComponent>(sofaDef, sofaSymbol()),
    SetComponentCommand<SymbolComponent>(tableDef, tableSymbol()),
    SetComponentCommand<UnitComponent>(tableDef, tableUnit()),
    SetComponentCommand<SymbolComponent>(armchairDef, armchairSymbol()),
    for (final l in fixtureLeaves())
      AddEntityCommand(record: l.record, payload: l.payload),
  ], label: 'Fixture library'));
  doc.commands.clearHistory();
  return doc;
}

Uint8List bytesOf(DraftDocument doc) =>
    Uint8List.fromList(utf8.encode(DraftDocumentCodec.encodeToString(doc)));

/// The valid library as mutable JSON (a deep copy through text).
Map<String, Object?> validLibraryJson() =>
    (jsonDecode(DraftDocumentCodec.encodeToString(buildValidLibrary())) as Map)
        .cast<String, Object?>();

/// [json] as bytes, after replacing each key of [text] by its value in the
/// encoded text (how a non-finite number reaches the file: `1e999`).
Uint8List bytesOfJson(Map<String, Object?> json, {Map<String, String>? text}) {
  var s = jsonEncode(json);
  text?.forEach((from, to) => s = s.replaceAll(from, to));
  return Uint8List.fromList(utf8.encode(s));
}

/// The `entities` entry (`{record, geometry}`) of the leaf [handle].
Map<String, Object?> entityJson(Map<String, Object?> lib, int handle) {
  for (final e in lib['entities']! as List) {
    final m = (e as Map).cast<String, Object?>();
    if ((m['record']! as Map)['handle'] == handle) return m;
  }
  throw StateError('no leaf $handle');
}

Map<String, Object?> recordJson(Map<String, Object?> lib, int handle) =>
    (entityJson(lib, handle)['record']! as Map).cast<String, Object?>();

Map<String, Object?> geometryJson(Map<String, Object?> lib, int handle) =>
    (entityJson(lib, handle)['geometry']! as Map).cast<String, Object?>();

Map<String, Object?> definitionJson(Map<String, Object?> lib, int handle) {
  for (final d in lib['definitions']! as List) {
    final m = (d as Map).cast<String, Object?>();
    if (m['handle'] == handle) return m;
  }
  throw StateError('no definition $handle');
}

/// The per-handle map of component type [typeId], created when absent.
Map<String, Object?> componentsJson(Map<String, Object?> lib, String typeId) {
  final all = (lib['components']! as Map).cast<String, Object?>();
  return (all.putIfAbsent(typeId, () => <String, Object?>{})! as Map)
      .cast<String, Object?>();
}

/// The component [typeId] on [handle].
Map<String, Object?> componentJson(
        Map<String, Object?> lib, String typeId, int handle) =>
    (componentsJson(lib, typeId)['$handle']! as Map).cast<String, Object?>();

/// An instance node of [definition], parented to [parent].
Map<String, Object?> instanceNodeJson(
        {required int handle, required int parent, required int definition}) =>
    {
      'type': 'instance',
      'handle': handle,
      'parent': parent,
      'transform': [1.0, 0.0, 0.0, 1.0, 0.0, 0.0],
      'visible': true,
      'definition': definition,
      'layer': ReservedHandles.layerZero.value,
      'color': encodeColor(const ByBlockColor()),
      'lineweight': kByBlock,
      'transparency': kByBlock,
      'linetype': ReservedHandles.byBlockLinetype.value,
      'linetypeScale': 1.0,
    };
```

- [ ] **Step 2: Write the failing test.** Create `test/model/symbol_library_test.dart`:

```dart
// Spec K3: the library validator. Every rule has one-fault cases, each a
// single edit of a valid library's codec JSON (so a case can only go red
// through its own rule), and positive controls proving no rule is
// over-strict. Each refusal pins its rule number.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import '../support/library_fixtures.dart';

/// Stands for a non-finite number: JSON has none, but `jsonDecode` reads
/// `1e999` as infinity, so the sentinel is replaced in the text.
const double kSentinel = 7777.125;
const Map<String, String> kInfinity = {'7777.125': '1e999'};
const Map<String, String> kNegInfinity = {'7777.125': '-1e999'};

String hex(int handle) => Handle(handle).toHex();

/// Decoding [bytes] throws a [SymbolLibraryError] of [rule] whose message
/// holds every one of [parts].
void expectRefused(Uint8List bytes, int rule, List<String> parts) {
  try {
    SymbolLibrary.decode(bytes);
  } on SymbolLibraryError catch (e) {
    expect(e.rule, rule, reason: 'message: ${e.message}');
    for (final p in parts) {
      expect(e.message, contains(p), reason: 'message: ${e.message}');
    }
    return;
  }
  fail('the library was accepted; expected rule $rule naming $parts');
}

int ownerOf(Object? entity) =>
    ((entity! as Map)['record']! as Map)['owner']! as int;

int handleOf(Object? entity) =>
    ((entity! as Map)['record']! as Map)['handle']! as int;

void main() {
  group('a valid library', () {
    test('V0a every entry equals what was built, in definition order', () {
      final lib = SymbolLibrary.decode(bytesOf(buildValidLibrary()));
      expect(lib.kits, ['sample']);
      // M-V0a: sort the entries by key instead of definition order. (Entries
      // in component order would survive: withComponent ascends by handle,
      // the same order as the definitions.)
      expect([for (final e in lib.entries) e.id], [
        'sample.sofa.three@3',
        'sample.table.high-top@2',
        'sample.chair.arm@1',
      ]);
      final built = buildValidLibrary();
      addTearDown(built.dispose);
      final want = {
        sofaDef: (sofaSymbol(), null, 900.0, 400.0),
        tableDef: (tableSymbol(), tableUnit(), 1250.0, 860.0),
        armchairDef: (armchairSymbol(), null, 510.0, 35.0),
      };
      for (final e in lib.entries) {
        final (symbol, unit, bx, by) = want[e.definition.handle]!;
        expect(e.symbol, symbol);
        // M-V0a2: an entry without its unit.
        expect(e.unit, unit);
        expect(e.definition.name, symbol.id);
        expect(e.definition.basePoint.x, bx);
        expect(e.definition.basePoint.y, by);
        expect(e.definition, built.tree.definition(e.definition.handle));
        final expected = fixtureLeaves()
            .where((l) => l.record.owner == e.definition.handle)
            .toList()
          ..sort(
              (a, b) => a.record.handle.value.compareTo(b.record.handle.value));
        expect(e.leaves.length, expected.length);
        for (var i = 0; i < expected.length; i++) {
          expect(e.leaves[i].record.copyWith(geomIndex: 0),
              expected[i].record.copyWith(geomIndex: 0));
          expect(e.leaves[i].payload.coords, expected[i].payload.coords);
          expect(e.leaves[i].payload.scalars, expected[i].payload.scalars);
        }
      }
      expect([for (final e in lib.entries) e.leaves.length], [4, 2, 2]);
    });

    test('V0b leaves ascend by handle although the file order does not', () {
      final fileOrder = [
        for (final e in validLibraryJson()['entities']! as List)
          if (ownerOf(e) == sofaDef.value) handleOf(e),
      ];
      expect(fileOrder, [sofaCircle, sofaLine, sofaArc, sofaPolyline],
          reason: 'premise: the file order is not the handle order');
      final lib = SymbolLibrary.decode(bytesOf(buildValidLibrary()));
      // M-V0b: drop the sort of each entry's leaves.
      expect(
          [for (final l in lib.entries.first.leaves) l.record.handle.value],
          [sofaLine, sofaPolyline, sofaArc, sofaCircle]);
    });

    test('V0c categories in first-appearance order, each once', () {
      final lib = SymbolLibrary.decode(bytesOf(buildValidLibrary()));
      expect(lib.categories, ['Living Room', 'Bar']);
    });

    test('V0d the lists are unmodifiable', () {
      final lib = SymbolLibrary.decode(bytesOf(buildValidLibrary()));
      expect(() => lib.entries.removeLast(), throwsUnsupportedError);
      expect(() => lib.kits.add('x'), throwsUnsupportedError);
      expect(() => lib.entries.first.leaves.clear(), throwsUnsupportedError);
    });

    test('V0f a coordinate at the bound and a small radius are allowed', () {
      final j = validLibraryJson();
      (geometryJson(j, sofaLine)['coords']! as List)
        ..[0] = 1e6
        ..[1] = -1e6;
      (geometryJson(j, sofaCircle)['scalars']! as List)[0] = 1e-3;
      expect(SymbolLibrary.decode(bytesOfJson(j)).entries, hasLength(3));
    });

    test('V0g a unit whose first leaf is a circle is valid', () {
      // The unit moves from the table (a closed polyline first) to the
      // armchair (a circle first). M-V11: accept only polylines as closed.
      final j = validLibraryJson();
      final units = componentsJson(j, UnitComponent.componentTypeId);
      units['${armchairDef.value}'] = units.remove('${tableDef.value}');
      final lib = SymbolLibrary.decode(bytesOfJson(j));
      expect(lib.entries.last.unit, tableUnit());
      expect(lib.entries[1].unit, isNull);
    });
  });

  group('rule 1: not a readable document', () {
    test('V1a bytes the codec cannot read are refused, not thrown through',
        () {
      expectRefused(Uint8List.fromList([0xff, 0xfe, 0x00]), 1,
          ['not a readable library']);
      expectRefused(Uint8List.fromList(utf8.encode('{"schemaVersion":1}')), 1,
          ['not a readable library']);
      expectRefused(Uint8List.fromList(utf8.encode('[1, 2]')), 1,
          ['not a readable library']);
    });

    test('V1b a definition cycle the codec repaired is refused', () {
      final j = validLibraryJson();
      (j['nodes']! as List).add(instanceNodeJson(
          handle: 5000, parent: sofaDef.value, definition: sofaDef.value));
      definitionJson(j, sofaDef.value)['children'] = [5000];
      // M-V1b: skip the diagnostics check.
      expectRefused(bytesOfJson(j), 1, ['codec repaired']);
    });

    test('V1c a symbol version of 0', () {
      final j = validLibraryJson();
      componentJson(j, SymbolComponent.componentTypeId, sofaDef.value)
          ['version'] = 0;
      expectRefused(bytesOfJson(j), 1, ['jetcad.symbol', 'sample.sofa.three']);
    });

    test('V1d a unit capacity of 0 (ported SE6)', () {
      final j = validLibraryJson();
      componentJson(j, UnitComponent.componentTypeId, tableDef.value)
          ['capacity'] = 0;
      expectRefused(bytesOfJson(j), 1, ['jetcad.unit', 'capacity']);
    });

    test('V1e an unknown labelling', () {
      final j = validLibraryJson();
      componentJson(j, UnitComponent.componentTypeId, tableDef.value)
          ['labelling'] = 'random';
      expectRefused(bytesOfJson(j), 1, ['jetcad.unit', 'random']);
    });

    test('V1f a symbol component without its family field', () {
      final j = validLibraryJson();
      componentJson(j, SymbolComponent.componentTypeId, tableDef.value)
          .remove('family');
      expectRefused(bytesOfJson(j), 1, ['"family"']);
    });

    test('V1g structurally broken documents are rule 1, never a TypeError',
        () {
      // Review Focus 1. M-V1g: catch only FormatException around the codec.
      final noEntities = validLibraryJson()..remove('entities');
      expectRefused(bytesOfJson(noEntities), 1, ['not a readable library']);
      final listComponents = validLibraryJson()..['components'] = [1, 2];
      expectRefused(bytesOfJson(listComponents), 1, ['not a readable']);
      final j = validLibraryJson();
      componentsJson(j, SymbolComponent.componentTypeId)['${sofaDef.value}'] =
          'not a map';
      expectRefused(bytesOfJson(j), 1, ['not a readable']);
    });
  });

  group('rule 2: the library component and the units', () {
    test('V2a a root without the library component', () {
      final j = validLibraryJson();
      (j['components']! as Map).remove(LibraryComponent.componentTypeId);
      expectRefused(bytesOfJson(j), 2, ['no library component']);
    });

    test('V2b a format other than 1', () {
      final j = validLibraryJson();
      componentJson(j, LibraryComponent.componentTypeId, j['root']! as int)
          ['format'] = 2;
      // M-V2b: check `format >= 1` only.
      expectRefused(bytesOfJson(j), 2, ['format 2']);
    });

    test('V2c a library kit that is not a kit id', () {
      final j = validLibraryJson();
      componentJson(j, LibraryComponent.componentTypeId, j['root']! as int)
          ['kit'] = 'Sample';
      expectRefused(bytesOfJson(j), 2, ['jetcad.library', 'Sample']);
    });

    test('V2d units other than millimetres', () {
      final j = validLibraryJson();
      (j['header']! as Map)['units'] = 'inches';
      expectRefused(bytesOfJson(j), 2, ['inches']);
    });

    test('V2e a library component on a definition as well', () {
      final j = validLibraryJson();
      componentsJson(j, LibraryComponent.componentTypeId)['${sofaDef.value}'] =
          {'format': 1, 'kit': 'sample'};
      expectRefused(bytesOfJson(j), 2, [hex(sofaDef.value), 'not the root']);
    });
  });

  group('rule 3: nodes', () {
    test('V3a an instance (ported R06)', () {
      final j = validLibraryJson();
      (j['nodes']! as List).add(instanceNodeJson(
          handle: 5000, parent: j['root']! as int, definition: sofaDef.value));
      expectRefused(bytesOfJson(j), 3, ['instance ${hex(5000)}']);
    });

    test('V3b a group (ported R07)', () {
      final j = validLibraryJson();
      (j['nodes']! as List).add({
        'type': 'group',
        'handle': 5001,
        'parent': j['root'],
        'transform': [1.0, 0.0, 0.0, 1.0, 0.0, 0.0],
        'visible': true,
        'children': <int>[],
        'exportAsDxfGroup': false,
      });
      expectRefused(bytesOfJson(j), 3, ['group ${hex(5001)}']);
    });
  });

  group('rule 4: definitions', () {
    test('V4a a definition without a symbol component (ported R01)', () {
      final j = validLibraryJson();
      componentsJson(j, SymbolComponent.componentTypeId)
          .remove('${armchairDef.value}');
      expectRefused(
          bytesOfJson(j), 4, [hex(armchairDef.value), 'no symbol component']);
    });

    test('V4b a leaf handle in children (ported R04)', () {
      final j = validLibraryJson();
      definitionJson(j, sofaDef.value)['children'] = [sofaLine];
      expectRefused(bytesOfJson(j), 4,
          ['sample.sofa.three@3', 'lists children', hex(sofaLine)]);
    });

    test('V4c an external reference', () {
      final j = validLibraryJson();
      definitionJson(j, sofaDef.value)['isXref'] = true;
      expectRefused(bytesOfJson(j), 4, ['sample.sofa.three@3', 'external']);
    });

    test('V4d a definition with no leaf', () {
      final j = validLibraryJson();
      (j['entities']! as List)
          .removeWhere((e) => ownerOf(e) == armchairDef.value);
      // M-V4d: drop the empty-leaves check.
      expectRefused(bytesOfJson(j), 4, ['sample.chair.arm@1', 'no leaf']);
    });

    test('V4e a symbol component on the root', () {
      final j = validLibraryJson();
      final symbols = componentsJson(j, SymbolComponent.componentTypeId);
      symbols['${j['root']}'] = symbols['${sofaDef.value}'];
      expectRefused(bytesOfJson(j), 4, ['not a definition']);
    });
  });

  group('rule 5: the key', () {
    test("V5a a key under another kit than the library's", () {
      final j = validLibraryJson();
      componentJson(j, SymbolComponent.componentTypeId, sofaDef.value)['key'] =
          'other.sofa.three';
      // M-V5a: drop the kit check (rule 7 would then refuse it instead).
      expectRefused(bytesOfJson(j), 5, ['other.sofa.three', '"sample"']);
    });

    for (final (name, key) in [
      ('V5b an upper-case key (ported R03)', 'sample.Sofa.three'),
      ('V5c a key with white space (ported R03b)', 'sample.sofa three.x'),
      ('V5d a key of two segments', 'sample.sofa'),
      ('V5e a key with a double hyphen', 'sample.sofa--x.three'),
    ]) {
      test(name, () {
        final j = validLibraryJson();
        componentJson(j, SymbolComponent.componentTypeId, sofaDef.value)
            ['key'] = key;
        // M-V5b: map the constructor's "key" refusal to rule 1.
        expectRefused(bytesOfJson(j), 5, [key]);
      });
    }
  });

  group('rule 6: a repeated key@version', () {
    test('V6a the same key and version twice (ported R02)', () {
      final j = validLibraryJson();
      componentJson(j, SymbolComponent.componentTypeId, tableDef.value)
        ..['key'] = 'sample.sofa.three'
        ..['version'] = 3;
      expectRefused(bytesOfJson(j), 6, [
        hex(tableDef.value),
        'sample.sofa.three@3',
        'repeats',
      ]);
    });

    test('V6b the same key at another version is another symbol (ported R02b)',
        () {
      final j = validLibraryJson();
      componentJson(j, SymbolComponent.componentTypeId, tableDef.value)
        ..['key'] = 'sample.sofa.three'
        ..['version'] = 4;
      definitionJson(j, tableDef.value)['name'] = 'sample.sofa.three@4';
      expect(SymbolLibrary.decode(bytesOfJson(j)).entries, hasLength(3));
    });
  });

  group('rule 7: the definition name', () {
    for (final (name, value) in [
      ('V7a another version in the name', 'sample.sofa.three@2'),
      ('V7b a name without its version', 'sample.sofa.three'),
    ]) {
      test(name, () {
        final j = validLibraryJson();
        definitionJson(j, sofaDef.value)['name'] = value;
        // M-V7: drop the name check.
        expectRefused(bytesOfJson(j), 7, ['"$value"', 'sample.sofa.three@3']);
      });
    }
  });

  group('rule 8: tags, target kinds, families, unit kinds', () {
    void symbolCase(String name, String field, Object value, String part) {
      test(name, () {
        final j = validLibraryJson();
        componentJson(j, SymbolComponent.componentTypeId, sofaDef.value)
            [field] = value;
        // M-V8: map "tags", "attachTo" or "family" to rule 1.
        expectRefused(bytesOfJson(j), 8, ['sample.sofa.three', part]);
      });
    }

    symbolCase('V8a an upper-case tag (ported R03c)', 'tags',
        ['sofa', 'Seating', 'couch'], 'Seating');
    symbolCase('V8b a repeated tag', 'tags', ['sofa', 'couch', 'sofa'],
        'repeated');
    symbolCase('V8c an empty tag', 'tags', ['sofa', ''], 'tags');
    symbolCase('V8d an upper-case target kind', 'attachTo', ['Wall-Face'],
        'Wall-Face');
    symbolCase('V8e a repeated target kind', 'attachTo',
        ['wall-face', 'wall-face'], 'repeated');
    symbolCase('V8f a family with a space', 'family', 'sofa long', 'sofa long');

    test('V8g a unit kind off the pattern', () {
      final j = validLibraryJson();
      componentJson(j, UnitComponent.componentTypeId, tableDef.value)['kind'] =
          'Table';
      expectRefused(bytesOfJson(j), 8, ['jetcad.unit', 'Table']);
    });
  });

  group('rule 9: a unit in a family', () {
    test('V9a a unit whose symbol names a family', () {
      final j = validLibraryJson();
      componentJson(j, SymbolComponent.componentTypeId, tableDef.value)
          ['family'] = 'table-high';
      // M-V9: drop the check; the sofa's own family (V0a) shows a family is
      // fine on a symbol that is not a unit.
      expectRefused(
          bytesOfJson(j), 9, ['sample.table.high-top@2', 'table-high']);
    });
  });

  group('rule 10: a unit component off a symbol definition', () {
    test('V10a on the root (ported SE7)', () {
      final j = validLibraryJson();
      final units = componentsJson(j, UnitComponent.componentTypeId);
      units['${j['root']}'] = units['${tableDef.value}'];
      expectRefused(bytesOfJson(j), 10, ['not a symbol']);
    });

    test('V10b on a leaf', () {
      final j = validLibraryJson();
      final units = componentsJson(j, UnitComponent.componentTypeId);
      units['$sofaLine'] = units['${tableDef.value}'];
      // M-V10: drop the check.
      expectRefused(bytesOfJson(j), 10, [hex(sofaLine)]);
    });
  });

  group('rule 11: a unit outline', () {
    test('V11a a unit whose first leaf is an open polyline', () {
      final j = validLibraryJson();
      final coords = geometryJson(j, tableTop)['coords']! as List;
      coords[coords.length - 1] = 1170.0;
      // M-V11a: drop the check.
      expectRefused(bytesOfJson(j), 11,
          ['sample.table.high-top@2', hex(tableTop), 'not a closed']);
    });

    test('V11b a unit whose first leaf is a line', () {
      final j = validLibraryJson();
      final units = componentsJson(j, UnitComponent.componentTypeId);
      units['${sofaDef.value}'] = units.remove('${tableDef.value}');
      componentJson(j, SymbolComponent.componentTypeId, sofaDef.value)
          ['family'] = null;
      // Two edits: the sofa's family would be rule 9. M-V11b: take the last
      // leaf instead of the first.
      expectRefused(bytesOfJson(j), 11, ['sample.sofa.three@3', hex(sofaLine)]);
    });
  });

  group('rule 12: the base point', () {
    test('V12a a non-finite base point (ported R05)', () {
      final j = validLibraryJson();
      definitionJson(j, tableDef.value)['basePoint'] = [kSentinel, 860.0];
      expectRefused(bytesOfJson(j, text: kInfinity), 12,
          ['sample.table.high-top@2', 'non-finite base point']);
    });
  });

  group('rule 13: leaves', () {
    test('V13a owned by the root (ported R09)', () {
      final j = validLibraryJson();
      recordJson(j, sofaLine)['owner'] = j['root'];
      expectRefused(bytesOfJson(j), 13, [hex(sofaLine), 'not a definition']);
    });

    test('V13b owned by a handle that names nothing', () {
      final j = validLibraryJson();
      recordJson(j, sofaLine)['owner'] = 9999;
      expectRefused(bytesOfJson(j), 13, [hex(sofaLine), hex(9999)]);
    });

    for (final kind in ['text', 'fill', 'attrib', 'point']) {
      test('V13c a leaf of kind $kind (ported R10, R11)', () {
        final j = validLibraryJson();
        recordJson(j, sofaCircle)['kind'] = kind;
        // M-V13c: let `point` through as the old allow-list did not.
        expectRefused(bytesOfJson(j), 13, [hex(sofaCircle), 'is a $kind']);
      });
    }
  });

  group('rule 14: leaf style (ported R12-R19, L5 inverted)', () {
    void style(String name, String field, Object? value, List<String> parts,
        {Map<String, String>? text}) {
      test(name, () {
        final j = validLibraryJson();
        recordJson(j, sofaLine)[field] = value;
        // M-V14: drop the check the case names.
        expectRefused(
            bytesOfJson(j, text: text), 14, [hex(sofaLine), ...parts]);
      });
    }

    style('V14a layer', 'layer', 20, ['not layer 0']);
    style('V14b linetype BYLAYER (allowed before, L5)', 'linetype',
        ReservedHandles.byLayerLinetype.value, ['not BYBLOCK']);
    style('V14c linetype CONTINUOUS (allowed before, L5)', 'linetype',
        ReservedHandles.continuousLinetype.value, ['not BYBLOCK']);
    style('V14d linetype DASHED', 'linetype',
        ReservedHandles.dashedLinetype.value, ['linetype ${hex(6)}']);
    style('V14e linetype scale 2', 'linetypeScale', 2.0, ['scale 2.0']);
    style('V14f linetype scale non-finite', 'linetypeScale', kSentinel,
        ['scale Infinity'],
        text: kInfinity);
    style('V14g a concrete colour', 'color', 1, ['colour']);
    style('V14h colour BYLAYER (allowed before, L5)', 'color',
        encodeColor(const ByLayerColor()), ['colour']);
    style('V14i lineweight 25', 'lineweight', 25, ['lineweight 25']);
    style('V14j lineweight BYLAYER (allowed before, L5)', 'lineweight',
        kByLayer, ['lineweight $kByLayer']);
    style('V14k transparency 50', 'transparency', 50, ['transparency 50']);
    style('V14l transparency BYLAYER (allowed before, L5)', 'transparency',
        kByLayer, ['transparency $kByLayer']);
    style('V14m flag invisible', 'flags', EntityFlags.invisible, ['flags 1']);
    style('V14n flag unpickable', 'flags', EntityFlags.unpickable,
        ['flags 2']);
    style('V14o text style', 'textStyle', 20, ['not STANDARD']);
    style('V14p text', 'text', 'x', ['text']);
    style('V14q tag', 'tag', 'x', ['tag']);
    style('V14r text attributes', 'textAttrs', 1, ['text attributes 1']);
  });

  group('rule 15: leaf geometry (ported R20-R27e)', () {
    void geometry(String name, int leaf,
        void Function(Map<String, Object?> g) edit, List<String> parts,
        {Map<String, String>? text}) {
      test(name, () {
        final j = validLibraryJson();
        edit(geometryJson(j, leaf));
        expectRefused(bytesOfJson(j, text: text), 15, [hex(leaf), ...parts]);
      });
    }

    geometry('V15a a line with six coordinates', sofaLine,
        (g) => g['coords'] = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0], ['malformed line']);
    geometry('V15b a polyline with an odd coordinate count', sofaPolyline,
        (g) => g['coords'] = [1.0, 2.0, 3.0, 4.0, 5.0], ['malformed polyline']);
    geometry('V15c a polyline with a scalar', sofaPolyline,
        (g) => g['scalars'] = [0.5], ['malformed polyline']);
    geometry('V15d a circle with no radius', sofaCircle,
        (g) => g['scalars'] = <double>[], ['malformed circle']);
    geometry('V15e a non-finite coordinate', sofaPolyline,
        (g) => (g['coords']! as List)[4] = kSentinel, ['not finite'],
        text: kInfinity);
    geometry('V15f a negative infinite coordinate', sofaPolyline,
        (g) => (g['coords']! as List)[4] = kSentinel, ['not finite'],
        text: kNegInfinity);
    geometry('V15g a coordinate beyond 1e6', sofaPolyline,
        (g) => (g['coords']! as List)[5] = 1000000.5, ['beyond']);
    geometry('V15h a coordinate below -1e6', sofaPolyline,
        (g) => (g['coords']! as List)[0] = -1000000.5, ['beyond']);
    geometry('V15i a non-finite scalar', sofaArc,
        (g) => (g['scalars']! as List)[1] = kSentinel, ['non-finite scalar'],
        text: kInfinity);
    geometry('V15j a zero-length line', sofaLine,
        (g) => g['coords'] = [100.0, 100.0, 100.0, 100.0], ['zero-length']);
    geometry('V15k a polyline of one vertex', sofaPolyline,
        (g) => g['coords'] = [120.0, 340.0], ['polyline of 1 vertices']);
    geometry('V15l a circle of radius 0', sofaCircle,
        (g) => g['scalars'] = [0.0], ['radius 0.0']);
    geometry('V15m a circle of negative radius', sofaCircle,
        (g) => g['scalars'] = [-5.0], ['radius -5.0']);
    geometry('V15n an arc of radius 0', sofaArc,
        (g) => g['scalars'] = [0.0, 0.5, 1.75], ['radius 0.0']);
    geometry('V15o an arc of zero sweep', sofaArc,
        (g) => g['scalars'] = [250.0, 0.5, 0.0], ['zero sweep']);
    // The decision is Tolerance.standard.angular (1e-9), not `== 0`: a sweep
    // the tolerance cannot tell from zero is refused, either sign, and the
    // bound itself. M-V15: `sweep == 0` turns V15p-V15r green-to-red.
    final below = Tolerance.standard.angular / 2;
    geometry('V15p a tiny positive sweep', sofaArc,
        (g) => g['scalars'] = [250.0, 0.5, below], ['zero sweep']);
    geometry('V15q a tiny negative sweep', sofaArc,
        (g) => g['scalars'] = [250.0, 0.5, -below], ['zero sweep']);
    geometry('V15r a sweep at the tolerance', sofaArc,
        (g) => g['scalars'] = [250.0, 0.5, Tolerance.standard.angular],
        ['zero sweep']);
    for (final sweep in [2 * Tolerance.standard.angular, -2e-9]) {
      test('V15s a sweep of $sweep, just above the tolerance, loads', () {
        final j = validLibraryJson();
        geometryJson(j, sofaArc)['scalars'] = [250.0, 0.5, sweep];
        final lib = SymbolLibrary.decode(bytesOfJson(j));
        final arc = lib.entries.first.leaves
            .firstWhere((l) => l.record.kind == EntityKind.arc);
        expect(arc.payload.scalars[2], sweep);
      });
    }
  });
}
```

- [ ] **Step 3: Run it to see it fail.** Run: `cd packages/jet_cad_2d_kit && flutter test test/model/symbol_library_test.dart`. Expected: compilation errors (`Undefined name 'SymbolLibrary'`, `Undefined class 'SymbolLeaf'`).

- [ ] **Step 4: The validator.** Create `lib/src/model/symbol_library.dart`:

```dart
// The library format (spec K3): bytes in, typed and validated entries out.
// A decoded library is not trusted: every rule is checked here, none is left
// to the tree or the codec. Ported from jet_cad_floor_plan's
// symbol_library.dart, with the contract's components and K3's fifteen
// rules, each refusal carrying its rule number.
//
// Pure Dart: no Flutter, no dart:io.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';

import 'kit_ids.dart';
import 'library_component.dart';
import 'register.dart';
import 'symbol_component.dart';
import 'unit_component.dart';

/// A leaf of a symbol: its record (the library's handles and `geomIndex`)
/// and its geometry.
typedef SymbolLeaf = ({EntityRecord record, GeometryPayload payload});

/// A library the decoder refuses: [rule] is the spec's K3 rule (1-15),
/// [message] names the offending key or handle.
final class SymbolLibraryError implements Exception {
  const SymbolLibraryError(this.rule, this.message);

  final int rule;
  final String message;

  @override
  String toString() => 'SymbolLibraryError (rule $rule): $message';
}

/// One symbol of a library: its identity, its unit or null, its definition
/// and its leaves, ascending by handle (draw order).
final class SymbolEntry {
  SymbolEntry({
    required this.symbol,
    required this.unit,
    required this.definition,
    required List<SymbolLeaf> leaves,
  }) : leaves = List.unmodifiable(leaves);

  final SymbolComponent symbol;
  final UnitComponent? unit;
  final Definition definition;
  final List<SymbolLeaf> leaves;

  /// `key@version`.
  String get id => symbol.id;

  @override
  String toString() => 'SymbolEntry($id, ${leaves.length} leaves)';
}

/// A validated library: its kit and its entries in definition-handle order.
final class SymbolLibrary {
  SymbolLibrary._(List<String> kits, List<SymbolEntry> entries)
      : kits = List.unmodifiable(kits),
        entries = List.unmodifiable(entries);

  /// A coordinate beyond this (mm) is refused: no symbol is a kilometre
  /// wide, and a huge coordinate poisons every bound computed from it.
  static const double maxCoordinate = 1e6;

  /// The library format this build reads.
  static const int format = 1;

  /// The kits whose symbols this holds: one for a decoded library, several
  /// for a merged one, in first-appearance order.
  final List<String> kits;

  final List<SymbolEntry> entries;

  /// Category names in first-appearance order over [entries].
  List<String> get categories {
    final seen = <String>{};
    return [
      for (final e in entries)
        if (seen.add(e.symbol.category)) e.symbol.category,
    ];
  }

  /// Decodes [bytes] (UTF-8 of the codec's JSON), registering only the kit
  /// components, and validates the result. Throws [SymbolLibraryError] on
  /// every fault of spec K3; nothing else escapes.
  static SymbolLibrary decode(Uint8List bytes) {
    final diagnostics = <Diagnostic>[];
    final DraftDocument doc;
    try {
      doc = DraftDocumentCodec.decodeString(
        utf8.decode(bytes),
        diagnostics: diagnostics,
        registerComponents: (registry) =>
            registerKitComponentsWrapped(registry, _guarded),
      );
    } on SymbolLibraryError {
      rethrow;
    } catch (e) {
      // FormatException, SchemaVersionError, a TypeError from a mistyped
      // field, a DuplicateHandleError: all mean "not a readable library".
      throw SymbolLibraryError(1, 'not a readable library: $e');
    }
    try {
      return _validate(doc, diagnostics);
    } finally {
      unawaited(doc.dispose());
    }
  }

  /// Reads a component, turning its constructor's refusal into the K3 rule
  /// the field belongs to.
  static T _guarded<T extends Component>(String typeId,
      Map<String, Object?> json, T Function(Map<String, Object?> json) read) {
    final named = switch (json['key'] ?? json['kit']) {
      final String s => '"$s"',
      _ => '',
    };
    try {
      return read(json);
    } on ArgumentError catch (e) {
      throw SymbolLibraryError(_ruleOf(typeId, e.name), '$typeId $named: $e');
    } on FormatException catch (e) {
      final rule = typeId == LibraryComponent.componentTypeId ? 2 : 1;
      throw SymbolLibraryError(rule, '$typeId $named: ${e.message}');
    }
  }

  static int _ruleOf(String typeId, String? field) => switch ((typeId, field)) {
        (LibraryComponent.componentTypeId, _) => 2,
        (SymbolComponent.componentTypeId, 'key') => 5,
        (SymbolComponent.componentTypeId, 'tags' || 'attachTo' || 'family') =>
          8,
        (UnitComponent.componentTypeId, 'kind') => 8,
        _ => 1,
      };

  static SymbolLibrary _validate(
      DraftDocument doc, List<Diagnostic> diagnostics) {
    // Rule 1: the codec repairs a definition cycle by dropping the instance
    // that closes it; its report is the only trace. Any repair is a refusal.
    if (diagnostics.isNotEmpty) {
      throw SymbolLibraryError(
          1, 'the codec repaired the library: ${diagnostics.first.message}');
    }

    // Rule 2: the root's library component, the format, the units.
    if (doc.header.units != DrawingUnits.millimeters) {
      throw SymbolLibraryError(2,
          'the library is in ${doc.header.units.name}, not in millimeters');
    }
    final library = doc.components.get<LibraryComponent>(doc.rootHandle);
    if (library == null) {
      throw const SymbolLibraryError(
          2, 'the root carries no library component');
    }
    if (library.format != format) {
      throw SymbolLibraryError(2,
          'the library is of format ${library.format}; this build reads $format');
    }
    for (final h in doc.components.withComponent<LibraryComponent>()) {
      if (h != doc.rootHandle) {
        throw SymbolLibraryError(
            2, 'a library component on ${h.toHex()}, which is not the root');
      }
    }

    // Rule 3: the root is the only node.
    for (final node in doc.tree.nodes) {
      if (node.handle == doc.rootHandle) continue;
      final what = switch (node) {
        InstanceNode() => 'instance',
        GroupNode() => 'group',
      };
      throw SymbolLibraryError(3,
          '$what ${node.handle.toHex()} in the library: it holds definitions only');
    }

    // Rules 4-9 and 12: definitions, ascending by handle.
    final leavesOf = <Handle, List<SymbolLeaf>>{};
    final seen = <String>{};
    final drafts = <(Definition, SymbolComponent, UnitComponent?)>[];
    for (final definition in doc.tree.definitions) {
      final at = 'definition ${definition.handle.toHex()}';
      final symbol = doc.components.get<SymbolComponent>(definition.handle);
      if (symbol == null) {
        throw SymbolLibraryError(4, '$at has no symbol component');
      }
      final who = '$at (${symbol.id})';
      if (definition.isXref) {
        throw SymbolLibraryError(4, '$who is an external reference');
      }
      if (definition.children.isNotEmpty) {
        throw SymbolLibraryError(
            4,
            '$who lists children '
            '(${definition.children.map((h) => h.toHex()).join(', ')}): a '
            "symbol's leaves are found by owner");
      }
      if (kitOfKey(symbol.key) != library.kit) {
        throw SymbolLibraryError(
            5, '$who is not under the library\'s kit "${library.kit}"');
      }
      if (!seen.add(symbol.id)) {
        throw SymbolLibraryError(
            6, '$who repeats the key and version of an earlier definition');
      }
      if (definition.name != symbol.id) {
        throw SymbolLibraryError(
            7, '$who is named "${definition.name}", not "${symbol.id}"');
      }
      final unit = doc.components.get<UnitComponent>(definition.handle);
      if (unit != null && symbol.family != null) {
        throw SymbolLibraryError(9,
            '$who is a unit in the size family "${symbol.family}": a unit is in no family');
      }
      final base = definition.basePoint;
      if (!base.x.isFinite || !base.y.isFinite) {
        throw SymbolLibraryError(12, '$who has a non-finite base point');
      }
      drafts.add((definition, symbol, unit));
      leavesOf[definition.handle] = [];
    }

    // Rules 4 and 10: a symbol or a unit component off a definition.
    for (final h in doc.components.withComponent<SymbolComponent>()) {
      if (!leavesOf.containsKey(h)) {
        throw SymbolLibraryError(
            4, 'a symbol component on ${h.toHex()}, which is not a definition');
      }
    }
    for (final h in doc.components.withComponent<UnitComponent>()) {
      if (!leavesOf.containsKey(h)) {
        throw SymbolLibraryError(10,
            "a unit component on ${h.toHex()}, which is not a symbol's definition");
      }
    }

    // Rules 13-15: leaves.
    final entities = doc.entities;
    for (final slot in entities.liveSlots) {
      final record = entities.read(slot);
      final at = 'leaf ${record.handle.toHex()}';
      final owned = leavesOf[record.owner];
      if (owned == null) {
        throw SymbolLibraryError(13,
            '$at is owned by ${record.owner.toHex()}, which is not a definition');
      }
      final who = '$at of ${record.owner.toHex()}';
      switch (record.kind) {
        case EntityKind.line:
        case EntityKind.polyline:
        case EntityKind.circle:
        case EntityKind.arc:
          break;
        case EntityKind.point:
        case EntityKind.text:
        case EntityKind.attrib:
        case EntityKind.fill:
          throw SymbolLibraryError(
              13,
              '$who is a ${record.kind.name}: a symbol holds lines, '
              'polylines, circles and arcs only');
      }
      _checkStyle(record, who);
      final payload = doc.geometry.read(entities.geomIndexAt(slot));
      _checkGeometry(record.kind, payload, who);
      owned.add((record: record, payload: payload));
    }

    // Rules 4 and 11, per definition: at least one leaf, a unit's outline.
    final entries = <SymbolEntry>[];
    for (final (definition, symbol, unit) in drafts) {
      final who = 'definition ${definition.handle.toHex()} (${symbol.id})';
      final leaves = leavesOf[definition.handle]!
        ..sort(
            (a, b) => a.record.handle.value.compareTo(b.record.handle.value));
      if (leaves.isEmpty) {
        throw SymbolLibraryError(4, '$who has no leaf');
      }
      if (unit != null) {
        final first = leaves.first;
        final closed = first.record.kind == EntityKind.circle ||
            (first.record.kind == EntityKind.polyline &&
                isClosedPolyline(first.payload));
        if (!closed) {
          throw SymbolLibraryError(
              11,
              '$who is a unit whose first leaf, '
              '${first.record.handle.toHex()}, is not a closed polyline or a '
              'circle');
        }
      }
      entries.add(SymbolEntry(
          symbol: symbol, unit: unit, definition: definition, leaves: leaves));
    }
    return SymbolLibrary._([library.kit], entries);
  }

  /// Rule 14: exactly the style the builder writes.
  static void _checkStyle(EntityRecord r, String who) {
    Never refuse(String what) => throw SymbolLibraryError(14, '$who $what');
    if (r.layer != ReservedHandles.layerZero) {
      refuse('is on layer ${r.layer.toHex()}, not layer 0');
    }
    if (r.linetype != ReservedHandles.byBlockLinetype) {
      refuse('has linetype ${r.linetype.toHex()}, not BYBLOCK');
    }
    if (r.linetypeScale != 1.0) {
      refuse('has linetype scale ${r.linetypeScale}, not 1');
    }
    if (r.color is! ByBlockColor) {
      refuse('has a colour other than BYBLOCK');
    }
    if (r.lineweight != kByBlock) {
      refuse('has lineweight ${r.lineweight}, not BYBLOCK');
    }
    if (r.transparency != kByBlock) {
      refuse('has transparency ${r.transparency}, not BYBLOCK');
    }
    if (r.flags != 0) {
      refuse('has flags ${r.flags}: a symbol is drawn and picked');
    }
    if (r.textStyle != ReservedHandles.standardTextStyle) {
      refuse('has text style ${r.textStyle.toHex()}, not STANDARD');
    }
    if (r.text.isNotEmpty) refuse('carries text');
    if (r.tag.isNotEmpty) refuse('carries a tag');
    if (r.textAttrs != 0) refuse('has text attributes ${r.textAttrs}');
  }

  /// Rule 15: counts, finiteness, bounds, degeneracy against [Tolerance].
  static void _checkGeometry(EntityKind kind, GeometryPayload p, String who) {
    final (int? coords, int scalars) = switch (kind) {
      EntityKind.line => (4, 0),
      EntityKind.circle => (2, 1),
      EntityKind.arc => (2, 3),
      _ => (null, 0), // a polyline: any even count, no scalar
    };
    if (p.coords.length.isOdd ||
        (coords != null && p.coords.length != coords) ||
        p.scalars.length != scalars) {
      throw SymbolLibraryError(
          15,
          '$who has a malformed ${kind.name} payload '
          '(${p.coords.length} coordinates, ${p.scalars.length} scalars)');
    }
    for (final c in p.coords) {
      if (!c.isFinite || c.abs() > maxCoordinate) {
        throw SymbolLibraryError(
            15,
            '$who has a coordinate ($c) that is not finite or is beyond '
            '±${maxCoordinate.toInt()}');
      }
    }
    for (final s in p.scalars) {
      if (!s.isFinite) {
        throw SymbolLibraryError(15, '$who has a non-finite scalar');
      }
    }
    switch (kind) {
      case EntityKind.line:
        if (isDegenerateSegment(p.pointAt(0), p.pointAt(1))) {
          throw SymbolLibraryError(15, '$who is a zero-length line');
        }
      case EntityKind.polyline:
        if (p.pointCount < 2) {
          throw SymbolLibraryError(
              15, '$who is a polyline of ${p.pointCount} vertices');
        }
      case EntityKind.circle:
      case EntityKind.arc:
        if (p.scalars[0] <= Tolerance.standard.linear) {
          throw SymbolLibraryError(15, '$who has radius ${p.scalars[0]}');
        }
        if (kind == EntityKind.arc &&
            p.scalars[2].abs() <= Tolerance.standard.angular) {
          throw SymbolLibraryError(15, '$who has a zero sweep');
        }
      default:
        break;
    }
  }
}
```

Add `export 'symbol_library.dart';` to `lib/src/model/model.dart` (keep the list alphabetical: after `export 'register.dart' show registerKitComponents;`).

- [ ] **Step 5: Run the tests.** Run: `cd packages/jet_cad_2d_kit && flutter test test/model test/invariants`. Expected: `All tests passed!`. If a one-fault case is refused under another rule than it names, the fixture edit has a second fault: fix the edit, never the expected rule.

- [ ] **Step 6: Mutation check** (on committed files; revert each with `git checkout -- <file>` and check `git diff --quiet`; quote each red line):
  - M-V0a: sort `drafts` by the symbol key before building entries → V0a red.
  - M-V0a2: build each entry without its unit (`unit: null`) → V0a red.
  - M-V0b: drop the `..sort(...)` of `leaves` → V0b red.
  - M-V1b: delete the `diagnostics.isNotEmpty` check → V1b red.
  - M-V1g: change `catch (e)` to `on FormatException catch (e)` → V1g red.
  - M-V2b: `library.format < 1` in place of `!= format` → V2b red.
  - M-V4d: delete the `leaves.isEmpty` check → V4d red.
  - M-V5a: delete the `kitOfKey(...) != library.kit` check → V5a red (rule 7 instead of 5).
  - M-V5b: delete the `(SymbolComponent.componentTypeId, 'key') => 5,` arm → V5b-V5e red (rule 1).
  - M-V7: delete the name check → V7a, V7b red.
  - M-V8: delete the `'tags' || 'attachTo' || 'family'` arm → V8a-V8f red.
  - M-V9: delete the unit-and-family check → V9a red.
  - M-V10: delete the unit loop → V10a, V10b red.
  - M-V11a: delete the rule-11 check → V11a, V11b red; M-V11: replace `first.record.kind == EntityKind.circle ||` with `false ||` → V0g red.
  - M-V13c: move `case EntityKind.point:` to the accepted cases → V13c point red.
  - M-V14: delete the `linetype` check → V14b-V14d red; delete the `text` check → V14p red.
  - M-V15: `p.scalars[2] == 0` in place of the tolerance test → V15p-V15r red.

- [ ] **Step 7: The gate.** `cd packages/jet_cad_2d_kit && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — all exit 0.

- [ ] **Step 8: Commit.**

```bash
git add packages/jet_cad_2d_kit/lib/src/model/symbol_library.dart packages/jet_cad_2d_kit/lib/src/model/model.dart packages/jet_cad_2d_kit/test/support/library_fixtures.dart packages/jet_cad_2d_kit/test/model/symbol_library_test.dart
git commit -m "$(cat <<'EOF'
feat(kit): the .jetlib validator, K3's fifteen rules (K3)

SymbolLibrary.decode registers only the kit components, through guarded
factories that report a constructor's refusal under its rule, and refuses
every fault of K3 with a SymbolLibraryError carrying the rule number.
The floor plan's L and R cases are ported one fault at a time; the leaf
style is now exactly the builder's (BYBLOCK), and rules 2, 5, 7, 8, 9 and
11 are new.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---
