### Task 23: The furniture library (spec C4, C7; Appendix A D-11, D-15, D-17, D-47)

**Files:**
- Create (`packages/jet_cad_2d_kit_architecture/`):
  - `lib/src/furniture/furniture_catalog.dart` (`furnitureCatalog`, pure Dart)
  - `lib/src/furniture/furniture_names.dart` (`furnitureGerman`, `furnitureTurkish`, pure Dart)
  - `lib/src/furniture/furniture_source.dart` (`kFurnitureAsset`, `furnitureReader`, `furnitureSource`)
  - `tool/generate_furniture_library.dart`
  - `assets/library/furniture.jetlib`, `assets/library/furniture.snapshot.json` (generated, committed)
  - `test/support/place_entry.dart` (`placeEntry`; Task 24 and Task 28 use it)
  - `test/furniture/furniture_library_test.dart` (ported, plus FU-keys, FU-tags, FU-plain-tables)
  - `test/furniture/package_assets_test.dart` (ported PA2, PA3, plus FU-asset-key)
- Modify (`packages/jet_cad_2d_kit_architecture/`):
  - `lib/src/words/words.dart` (`architectureNames` gains the furniture words, so `architectureKit.names` stays `identical` to it: Task 9's SC-ids, `test/scaffold/kit_test.dart`, asserts that, and Task 9's notes say the furniture words go into `architectureNames`)
  - `pubspec.yaml` (`flutter: assets:`)
  - Task 9's SC-conformance test, `packages/jet_cad_2d_kit_architecture/test/scaffold/words_test.dart`: it now runs over the real catalog, library and snapshot (D-47)

**Interfaces:**
- Consumes:
  - Task 1 (C1.4), from `package:jet_cad_2d_kit/jet_cad_2d_kit.dart` and `authoring.dart`: `SymbolBox`, `boxOfEntry(SymbolEntry)`, `placementTransform({required Vector2 at, required Vector2 basePoint, int? quarterTurns, (double, double)? rotation, bool mirrored = false})`.
  - The contract's authoring language today (`jet_cad_2d_kit/lib/src/authoring/`): `Catalog({kit, symbols})`, `CatalogSymbol({key, version = 1, name, category, tags, attachTo, family, unit, base, shapes, retired})` (`catalog.dart:67-96`), `CatalogLine`, `CatalogPolyline`, `CatalogCircle`, `CatalogArc` (`catalog.dart:17-49`), `rect`, `inset`, `poly`, `chairSize`, `chairTuck` (`shapes.dart:13-51`), `encodeLibrary` (`builder.dart:114`), `geometrySnapshot`, `parseSnapshot`, `encodeSnapshot`, `updateSnapshot` (`snapshot.dart:13-95`), `conformance` (`conformance.dart:36-46`).
  - The contract today: `KitNames` (`model/kit_names.dart:15-53`, `merge`), `SymbolLibrary.decode`, `SymbolEntry` (`symbol`, `unit`, `definition`, `leaves`; `model/symbol_library.dart:39-58`), `SymbolComponent`, `UnitComponent`, `registerKitComponents` (`model/register.dart:21`), `SymbolLibrarySource` (`kit/symbol_library_source.dart:8`), `bundledLibrary(assetKey, {bundle})` (`kit/bundled_library.dart:11`).
  - Task 9: `architectureKit` (`lib/src/kit.dart`), `architectureNames` (`lib/src/words/words.dart`), the kit's `pubspec.yaml`, the SC-conformance test and its `sameAsEnglish` map.
- Produces:

```dart
// lib/src/furniture/furniture_catalog.dart (internal, pure Dart)
final Catalog furnitureCatalog; // kit 'architecture', 41 symbols in today's order
// lib/src/furniture/furniture_names.dart (internal, pure Dart)
const Map<String, String> furnitureGerman, furnitureTurkish; // every symbol: and category: word
// lib/src/words/words.dart (Task 9's, changed): architectureNames' 'de' and 'tr' spread them in
// lib/src/furniture/furniture_source.dart (Shared interfaces, exact)
const String kFurnitureAsset =
    'packages/jet_cad_2d_kit_architecture/assets/library/furniture.jetlib';
final SymbolLibrarySource furnitureSource;
Future<Uint8List> Function() furnitureReader({AssetBundle? bundle}); // internal
// test/support/place_entry.dart (kit test support; see "New shared name")
CompoundCommand placeEntry(DraftDocument doc, SymbolEntry entry,
    {required Vector2 at, int quarterTurns = 0, bool mirrored = false, Transform2? transform});
```

**Appendix A rows closed:**
- **D-11** `jet_cad_floor_plan/test/symbols/furniture_library_test.dart` (34): ported to the kit with C7's rulings (below); its seating group's two seat-count tests dropped (decision 7); the pre-09c group (4) and "the 14 new symbols … == 27" not ported (C7, umbrella decision 9); "the behaviour tags come last" retired (C7 class 2).
- **D-15** `jet_cad_floor_plan/test/package_assets_test.dart` PA2, PA3 (the kit's asset from a package-key bundle). PA4 stays sub-project 4's (Appendix A.2).
- **D-17** (furniture half): SE11 ("the furniture library's dining tables are v2 and servable") dropped with decision 7; FU-plain-tables pins decision 3 instead. SE8 is Task 8's; SE10, SE10b dropped (decision 7).
- **D-47** A16 conformance over the real catalog, the committed library and snapshot, and the kit's words.

**Plan decisions:**
- **Geometry is today's, leaf for leaf.** Every symbol's shapes are today's (`furniture_catalog.dart:102-675`) in the same order and vertex order: `_rect` is the contract's `rect` (same corner order; `cleanCoordinate` is the identity on these whole numbers), `_inset(w, h, d)` is `inset(0, 0, w, h, d)`, a closed `PolylineShape` is `poly`. The dining sets keep today's private `_chair` (a `rect` and its back line), not the contract's `chairAt`, whose seat starts at another corner and whose back line runs the other way: the leaves, the boxes and every ported literal stay today's.
- **Keys and versions (C4, C7 class 1).** `architecture.` + today's key, at `@1`; `armchair` → `architecture.armchair.single`. The five dining tables were `@2` today; versions restart (umbrella decision 9), so they are `@1` too. The ported "every entry has a category, two tags, its version and leaves" asserts version 1 for every entry (the rewritten line below): a class 1 change, recorded as a ruling in the ledger.
- **Behaviour is fields (C4, C7 class 2).** Tags are today's plain tags; `against-wall` becomes `attachTo: ['wall-face']` on D9's 30 symbols (`furniture_library_test.dart:260-291`), `family:<id>` becomes `family: '<id>'` on the 18 family members. 30 is counted from today's catalog: the four base units, sink, hob, fridge, dishwasher, washer (9), six beds (15), nightstand (16), three wardrobes (19), two sofas (21), TV unit (22), toilet, washbasin, tub, shower (26), three desks (29), bookshelf (30).
- **No unit** (decision 3): the dining tables are plain symbols.
- **Categories** are today's English names (`Dining Room`, `Kitchen`, `Bed Room`, `Living Room`, `Bathroom`, `Office`), so their word ids are `category:architecture/<name>` (`KitNames.categoryWord`).
- **The source joins the kit in Task 24, not here.** `furnitureSource` is written and tested here, but `architectureKit.symbols` gains it in Task 24 together with `attachments: [wallFaceProvider]`: a kit whose library names `wall-face` while no provider offers it makes the plan report one `attachmentKindUnoffered` once the symbols load (`jet_cad_2d_plan/lib/src/controller/plan_controller.dart:2299-2316`), which every integration test of Tasks 10-22 that asserts an empty diagnostics list would then see. The words join the kit here (no runtime effect; the conformance test needs them).
- **`placeEntry`, the test placement.** Today's "every symbol placed" and "plausible size" groups call `placeSymbol`, which is plan-internal and not exported (`jet_cad_2d_plan/lib/jet_cad_2d_plan.dart` exports no placer; `lib/src/symbols/symbol_placer.dart:169`), and a kit's test may not import the plan library (`tool/ci/check_kit_deps.dart`). They place through `test/support/place_entry.dart`, a copy of the placer's no-unit path over the engine's commands and the contract's `placementTransform`; their assertions are unchanged. See "Interface problem".
- **PA2 and PA3** read through `furnitureReader(bundle:)`, today's `readBundledLibrary([AssetBundle? bundle])` shape (`jet_cad_floor_plan/lib/src/symbols/symbol_library_loader.dart:17-26`); `furnitureSource` is that reader over `rootBundle`. The asset under its package key through a real bundle is Task 24's FU-load (integration).

- [ ] **Step 1: Precondition.** Tasks 1-22 are committed. Run `cd packages/jet_cad_2d_kit_architecture && flutter analyze` → `No issues found!`. Read `lib/src/kit.dart`, `lib/src/words/words.dart`, `pubspec.yaml` and the SC-conformance test (`packages/jet_cad_2d_kit_architecture/test/scaffold/words_test.dart`, Task 9's). Check `pubspec.yaml` lists `vector_math: ^2.2.0` (every ported file imports `Vector2`); if it does not, stop and report it (Task 9's).

- [ ] **Step 2: The test support.** Create `packages/jet_cad_2d_kit_architecture/test/support/place_entry.dart`:

```dart
// A library entry placed by the engine's commands (3a Task 23). The plan
// library's placer (jet_cad_2d_plan/lib/src/symbols/symbol_placer.dart:
// 103-219, `definitionForEntry` and `placeSymbol`) is not exported, and a
// kit's tests may not import the plan library (tool/ci/check_kit_deps.dart),
// so the kit's tests place through this copy of its path for a placement
// without a unit label: the definition copied on first use (reused by key and
// version afterwards), then a root-level instance on the drawing layer under
// the contract's `placementTransform`, or under [transform] when given (an
// attachment's). The leaf-equality check of the plan's reuse is not copied:
// a test document holds only copies this helper made.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// The definition of [doc] that copies [entry] (same key and version), or
/// null.
Handle? copyOfEntry(DraftDocument doc, SymbolEntry entry) {
  for (final h in doc.components.withComponent<SymbolComponent>()) {
    final c = doc.components.get<SymbolComponent>(h);
    if (c != null &&
        c.key == entry.symbol.key &&
        c.version == entry.symbol.version &&
        doc.tree.definition(h) != null) {
      return h;
    }
  }
  return null;
}

/// The command that places [entry] in [doc] at [at] ([quarterTurns]
/// counter-clockwise, [mirrored]), or under [transform] when given; one
/// compound labelled `Place <name>`, every handle allocated here, in the
/// placer's order (the definition, its leaves, the instance). [doc] must
/// have the contract's components registered.
CompoundCommand placeEntry(
  DraftDocument doc,
  SymbolEntry entry, {
  required Vector2 at,
  int quarterTurns = 0,
  bool mirrored = false,
  Transform2? transform,
}) {
  final commands = <DraftCommand>[];
  var definition = copyOfEntry(doc, entry);
  if (definition == null) {
    final copy = doc.handleSeed.next();
    commands
      ..add(AddDefinitionCommand(Definition(
        handle: copy,
        name: entry.id,
        basePoint: entry.definition.basePoint,
        children: const [],
      )))
      ..add(SetComponentCommand<SymbolComponent>(copy, entry.symbol));
    final unit = entry.unit;
    if (unit != null) {
      commands.add(SetComponentCommand<UnitComponent>(copy, unit));
    }
    for (final leaf in entry.leaves) {
      commands.add(AddEntityCommand(
        record:
            leaf.record.copyWith(handle: doc.handleSeed.next(), owner: copy),
        payload: leaf.payload,
      ));
    }
    definition = copy;
  }
  commands.add(AddNodeCommand(InstanceNode(
    handle: doc.handleSeed.next(),
    parent: doc.rootHandle,
    definition: definition,
    layer: drawingLayer(doc),
    transform: transform ??
        placementTransform(
          at: at,
          basePoint: entry.definition.basePoint,
          quarterTurns: quarterTurns,
          mirrored: mirrored,
        ),
  )));
  return CompoundCommand(commands, label: 'Place ${entry.symbol.name}');
}
```

- [ ] **Step 3: The ported furniture test.** Copy the source and adapt it:
  - `cp packages/jet_cad_floor_plan/test/symbols/furniture_library_test.dart packages/jet_cad_2d_kit_architecture/test/furniture/furniture_library_test.dart`
  - The keys (C7 class 1), then the entry's fields (the contract's `SymbolEntry` holds them on `symbol`), one command each:
    - `perl -pi -e "s/'(dining|kitchen|bed|sofa|table|tv|bath|office)\./'architecture.\$1./g; s/'armchair'/'architecture.armchair.single'/g" packages/jet_cad_2d_kit_architecture/test/furniture/furniture_library_test.dart`
    - `perl -pi -e 's/\be\.(key|tags|category|version)\b/e.symbol.$1/g' packages/jet_cad_2d_kit_architecture/test/furniture/furniture_library_test.dart`
    - Check: `grep -n "'dining\.\|'kitchen\.\|'bed\.\|'sofa\.\|'tv\.\|'bath\.\|'office\.\|'table\.\|'armchair'" packages/jet_cad_2d_kit_architecture/test/furniture/furniture_library_test.dart` prints nothing.
  - The header (source lines 1-4) becomes:

```dart
// 3a Task 23 (spec C4, C7), ported from jet_cad_floor_plan/test/symbols/
// furniture_library_test.dart (spec 09 D2, D7, plan 09a Task 5): the
// committed asset must equal what the catalog builds, every symbol must
// load, sit off the origin, place cleanly at an off-origin point and quarter
// turn, and be a plausible size in millimetres. C7's rulings: keys and
// versions are C4's (class 1); the against-wall and family tags are the
// `attachTo` and `family` fields (class 2); "the behaviour tags come last"
// is retired (class 2); the pre-09c group and "the 14 new symbols … == 27"
// are not ported (umbrella decision 9); the seating group's two seat-count
// tests are dropped (decision 7). Placement goes through the test support's
// `placeEntry` (the plan's placer is not exported).
```

  - The imports (source lines 5-20) become:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/authoring.dart' show encodeLibrary;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_kit_architecture/src/furniture/furniture_catalog.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/place_entry.dart';
```

  - `builtBytes` (source :22-23) becomes `Uint8List builtBytes() => encodeLibrary(furnitureCatalog);`
  - "the built library decodes through the loader" (:39): `furnitureCatalog.length` → `furnitureCatalog.symbols.length`.
  - "lists every catalog key once, in catalog order" (:74): `for (final s in furnitureCatalog) s.key` → `for (final s in furnitureCatalog.symbols) s.key`.
  - "every base point is off the origin" (:91-92): `furnitureCatalog.firstWhere(` → `furnitureCatalog.symbols.firstWhere(`; `Vector2(s.baseX, s.baseY)` → `Vector2(s.base.$1, s.base.$2)`.
  - "every entry has a category, two tags, its version and leaves" (:96-116, **C7 class 1**): delete the `version2` set and its comment (:96-104); the line `expect(e.symbol.version, version2.contains(e.symbol.key) ? 2 : 1, reason: e.symbol.key);` becomes
    `expect(e.symbol.version, 1, reason: e.symbol.key);` preceded by the comment `// C4: versions restart at 1 (umbrella decision 9), the dining tables' 2 included.`
  - "the against-wall set is D9's list exactly" (:352-358, **C7 class 2**): its set expression becomes

```dart
      expect({
        for (final e in assetLibrary().entries)
          if (e.symbol.attachTo.contains('wall-face')) e.symbol.key,
      }, againstWall);
```

  - "the families are D9's table exactly, one family at most each" (:360-370, **C7 class 2**: one family is now the field's type, so the per-entry `lessThanOrEqualTo(1)` line has nothing left to count and goes with the tags): its body becomes

```dart
      final found = <String, List<String>>{};
      for (final e in assetLibrary().entries) {
        final family = e.symbol.family;
        if (family != null) (found[family] ??= []).add(e.symbol.key);
      }
      expect(found, families);
```

  - Delete (not ported): the `newNames` map (:331-347), "the behaviour tags come last" (:372-388), "the 14 new symbols carry their names; the old keys stay" (:421-430), the whole group "the 27 symbols shipped before 09c" (:433-508), and the seating group's first two tests, "the decoded library carries each servable symbol's seats" and "the catalog says the same thing the file does" (:605-628). Move "the round table draws its four chairs around its top" (:630-666, geometry only, outside decision 7's lines) to the end of the group "the dining tables draw their chairs" and delete the emptied `group('seating (spec 14 S1-S3)', …)` wrapper (:605, :667). Its assertions are unchanged.
  - "every symbol placed" (:669-688): `for (final s in furnitureCatalog)` → `for (final s in furnitureCatalog.symbols)`; `final doc = prepareDocument(const InsertionPointMeasurer());` → `final doc = placementDocument();`; `placeSymbol(` → `placeEntry(`.
  - "plausible size" (:690-704): `for (final s in furnitureCatalog)` → `for (final s in furnitureCatalog.symbols)`; `registerAppComponents(doc.components);` → `registerKitComponents(doc.components);`; `placeSymbol(` → `placeEntry(`.
  - Add, after `assetLibrary()` (source :28):

```dart
/// A document a symbol is placed in: the contract's components and
/// millimetres (today's `prepareDocument` less the planner's own types,
/// which no furniture leaf uses).
DraftDocument placementDocument() {
  final doc = DraftDocument.empty();
  registerKitComponents(doc.components);
  doc.header.units = DrawingUnits.millimeters;
  return doc;
}
```

  - Every other line and every other assertion is the source's. Ported, by group: the asset (5: committed bytes, decodes, building twice, the pubspec, 41 symbols in six categories); the decoded library (5); the outline and the category (4); families and the wall tag (5: the against-wall set, the families, W-16, D9 W x D, base on the box's centre x); the dining tables draw their chairs (5, the round table moved in); every symbol placed (1 generator, 82 cases); plausible size (1 generator, 41 cases). Check the non-ASCII lines of the file against the source with `grep -n "×\|—\|Ø" packages/jet_cad_2d_kit_architecture/test/furniture/furniture_library_test.dart`.
  - Append the new group at the end of `main`:

```dart
  group('C4: keys, fields and plain tables (3a Task 23)', () {
    // Written out by hand: today's 41 keys in today's catalog order
    // (jet_cad_floor_plan/lib/src/symbols/furniture_catalog.dart:300-675).
    const today = [
      'dining.table.square.two',
      'dining.table.square.four',
      'dining.table.rect.four',
      'dining.table.rect.six',
      'dining.table.round',
      'dining.chair',
      'dining.bench',
      'kitchen.base.300',
      'kitchen.base.400',
      'kitchen.base.600',
      'kitchen.base.800',
      'kitchen.sink',
      'kitchen.hob',
      'kitchen.fridge',
      'kitchen.dishwasher',
      'kitchen.washer',
      'kitchen.island',
      'bed.double.1400',
      'bed.double',
      'bed.double.1800',
      'bed.single.800',
      'bed.single',
      'bed.single.1000',
      'bed.nightstand',
      'bed.wardrobe.1200',
      'bed.wardrobe',
      'bed.wardrobe.2400',
      'sofa.two',
      'sofa.three',
      'armchair',
      'table.coffee',
      'tv.unit',
      'bath.toilet',
      'bath.washbasin',
      'bath.tub',
      'bath.shower',
      'office.desk.1200',
      'office.desk',
      'office.desk.1600',
      'office.chair',
      'office.bookshelf',
    ];

    test(
        'FU-keys every id is `architecture.` and today\'s key at version 1, '
        'in today\'s order; armchair, one segment today, is '
        'architecture.armchair.single', () {
      expect(today, hasLength(41));
      expect([for (final e in assetLibrary().entries) e.symbol.id], [
        for (final k in today)
          k == 'armchair'
              ? 'architecture.armchair.single@1'
              : 'architecture.$k@1',
      ]);
    });

    test(
        'FU-tags tags are search words only: no against-wall tag, no family: '
        'tag; every attachTo is empty or exactly [wall-face]', () {
      for (final e in assetLibrary().entries) {
        final why = e.symbol.key;
        expect(e.symbol.tags, isNot(contains('against-wall')), reason: why);
        expect(e.symbol.tags.where((t) => t.startsWith('family:')), isEmpty,
            reason: why);
        expect(e.symbol.attachTo, anyOf(isEmpty, equals(const ['wall-face'])),
            reason: why);
      }
    });

    test(
        'FU-plain-tables no symbol carries a unit, in the catalog or the '
        'file; the five dining tables are plain symbols at version 1 '
        '(decision 3)', () {
      final lib = assetLibrary();
      expect([
        for (final e in lib.entries)
          if (e.unit != null) e.symbol.key,
      ], isEmpty);
      expect([
        for (final s in furnitureCatalog.symbols)
          if (s.unit != null) s.key,
      ], isEmpty);
      for (final key in const [
        'architecture.dining.table.square.two',
        'architecture.dining.table.square.four',
        'architecture.dining.table.rect.four',
        'architecture.dining.table.rect.six',
        'architecture.dining.table.round',
      ]) {
        final e = lib.entries.firstWhere((e) => e.symbol.key == key);
        expect((e.symbol.version, e.unit), (1, null), reason: key);
      }
    });
  });
```

- [ ] **Step 4: The ported asset test.** Create `packages/jet_cad_2d_kit_architecture/test/furniture/package_assets_test.dart`. PA2 and PA3 are the source's (`jet_cad_floor_plan/test/package_assets_test.dart:47-63`), **assertions unchanged**; adaptations: the key written out is the kit's, `readBundledLibrary(bundle)` → `furnitureReader(bundle: bundle)()`, the decode is the contract's. `_MapBundle` and `_file` are copied unchanged (:14-29).

```dart
// 3a Task 23 (spec C4; D-15), ported from jet_cad_floor_plan/test/
// package_assets_test.dart PA2, PA3 (spec 14 V-10): the kit's library is read
// under its package key, so a host app finds it; an app key fails. PA1's
// counterpart for the kit's key is FU-asset-key. PA4 (the export font) is
// sub-project 4's.
import 'dart:io';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show SymbolLibrary;
import 'package:jet_cad_2d_kit_architecture/src/furniture/furniture_source.dart';

/// A bundle that serves fixed bytes under the keys it holds, and nothing
/// else.
class _MapBundle extends CachingAssetBundle {
  _MapBundle(this.assets);

  final Map<String, Uint8List> assets;

  @override
  Future<ByteData> load(String key) async {
    final bytes = assets[key];
    if (bytes == null) throw FlutterError('no asset $key');
    return ByteData.sublistView(bytes);
  }
}

Uint8List _file(String path) => File(path).readAsBytesSync();

void main() {
  group('V-10 the asset key is the package\'s', () {
    // Written out, not read from the constant: a key that drifted to an
    // app's `assets/...` must turn these red.
    const libraryKey =
        'packages/jet_cad_2d_kit_architecture/assets/library/furniture.jetlib';

    test('FU-asset-key the constant names the package key', () {
      expect(kFurnitureAsset, libraryKey);
    });

    test(
        'PA2 the furniture library loads from a bundle holding only the '
        'package key', () async {
      final bytes = _file('assets/library/furniture.jetlib');
      final read =
          await furnitureReader(bundle: _MapBundle({libraryKey: bytes}))();
      expect(read, orderedEquals(bytes));
      expect(SymbolLibrary.decode(read).entries, isNotEmpty);
    });

    test('PA3 a bundle holding only the app\'s old key fails the read',
        () async {
      final bytes = _file('assets/library/furniture.jetlib');
      await expectLater(
          furnitureReader(
              bundle: _MapBundle({'assets/library/furniture.jetlib': bytes}))(),
          throwsA(isA<FlutterError>()));
    });
  });
}
```

- [ ] **Step 5: Run the tests, see them fail.** `cd packages/jet_cad_2d_kit_architecture && flutter test test/furniture/`. Expected: compile errors — `furniture_catalog.dart` and `furniture_source.dart` do not exist (`Error when reading 'lib/src/furniture/furniture_catalog.dart'`).

- [ ] **Step 6: The catalog.** Create `packages/jet_cad_2d_kit_architecture/lib/src/furniture/furniture_catalog.dart` (new code; the geometry is `jet_cad_floor_plan/lib/src/symbols/furniture_catalog.dart:102-675`, each shape mapped as the plan decision says):

```dart
// The architecture kit's furniture (spec 3a C4): today's 41 symbols
// (jet_cad_floor_plan/lib/src/symbols/furniture_catalog.dart), rewritten in
// the authoring language, each in millimetres in a corner-origin local frame
// (x to the right, y up the plan, the front of the piece on y = 0), its base
// point off the origin.
//
// - Keys: `architecture.` and today's key, at version 1 (umbrella decision
//   9: no plan of jet_cad_floor_plan is read, so versions restart);
//   `armchair`, one segment, is `architecture.armchair.single`.
// - Behaviour is fields (umbrella A5): the 30 symbols of 09c D9's
//   against-the-wall set attach to `wall-face`; the six size families are
//   `family` fields; tags are search words only.
// - The dining tables are plain symbols (decision 3): no unit.
// - Every symbol's leaves are today's, in today's order and vertex order: a
//   chair is today's `_chair` (a `rect` and its back line), not `chairAt`.
//
// Pure Dart: no Flutter, no dart:io (the generator runs it under `dart run`).
import 'dart:math' as math;

import 'package:jet_cad_2d_kit/authoring.dart';

const double _pi = math.pi;

const String _dining = 'Dining Room';
const String _kitchen = 'Kitchen';
const String _bedRoom = 'Bed Room';
const String _livingRoom = 'Living Room';
const String _bathroom = 'Bathroom';
const String _office = 'Office';

/// The one attachment kind the kit's symbols name (spec C5).
const List<String> _wallFace = ['wall-face'];

/// Which side of the table a chair sits on; the chair's back is on the far
/// side from the table.
enum _Side { bottom, top, left, right }

/// Today's seat depth beyond the table edge: 450 − 100 = 350.
const double _chairReach = chairSize - chairTuck;

CatalogLine _line(double x1, double y1, double x2, double y2) =>
    CatalogLine((x1, y1), (x2, y2));

/// One chair: a closed 450 x 450 seat outline from (x, y) and a thin back
/// line 60 mm in from the outer edge, on the side away from the table.
List<CatalogShape> _chair(double x, double y, _Side back) => [
      rect(x, y, chairSize, chairSize),
      switch (back) {
        _Side.bottom => _line(x, y + 60, x + chairSize, y + 60),
        _Side.top => _line(
            x, y + chairSize - 60, x + chairSize, y + chairSize - 60),
        _Side.left => _line(x + 60, y, x + 60, y + chairSize),
        _Side.right => _line(
            x + chairSize - 60, y, x + chairSize - 60, y + chairSize),
      },
    ];

/// A [tw] x [th] table with its chairs, its lower-left corner at ([ox],
/// [oy]); [chairs] are (side, centre along that side) pairs. The base point
/// is the table centre. Leaves: table outline, table inset, then each chair
/// (outline, back line). A plain symbol (decision 3).
CatalogSymbol _diningSet(String key, String name, double tw, double th,
    double ox, double oy, List<String> tags, List<(_Side, double)> chairs) {
  final shapes = <CatalogShape>[
    rect(ox, oy, tw, th),
    rect(ox + 50, oy + 50, tw - 100, th - 100),
  ];
  for (final (side, c) in chairs) {
    const h = chairSize / 2;
    switch (side) {
      case _Side.bottom:
        shapes.addAll(_chair(ox + c - h, oy - _chairReach, side));
      case _Side.top:
        shapes.addAll(_chair(ox + c - h, oy + th - chairTuck, side));
      case _Side.left:
        shapes.addAll(_chair(ox - _chairReach, oy + c - h, side));
      case _Side.right:
        shapes.addAll(_chair(ox + tw - chairTuck, oy + c - h, side));
    }
  }
  return CatalogSymbol(
    key: key,
    name: name,
    category: _dining,
    tags: tags,
    base: (ox + tw / 2, oy + th / 2),
    shapes: shapes,
  );
}

// The size families (spec 09c D9): each member is its family's drawing at
// another width, the depth, the front (y = 0) and the back the same, the
// base point on the box's centre x.

/// A double bed [w] x 2000: outline, two pillows 240 deep with 100 mm
/// margins and gap, the fold line at 1300. Base point: the centre.
CatalogSymbol _doubleBed(String key, String name, double w) {
  final pillow = (w - 300) / 2;
  return CatalogSymbol(
    key: key,
    name: name,
    category: _bedRoom,
    tags: const ['bed', 'double', 'sleeping'],
    attachTo: _wallFace,
    family: 'bed-double',
    base: (w / 2, 1000),
    shapes: [
      rect(0, 0, w, 2000),
      rect(100, 1680, pillow, 240),
      rect(200 + pillow, 1680, pillow, 240),
      _line(0, 1300, w, 1300),
    ],
  );
}

/// A single bed [w] x 2000: outline, one pillow 240 deep with 120 mm
/// margins, the fold line at 1300. Base point: the centre.
CatalogSymbol _singleBed(String key, String name, double w) => CatalogSymbol(
      key: key,
      name: name,
      category: _bedRoom,
      tags: const ['bed', 'single', 'sleeping'],
      attachTo: _wallFace,
      family: 'bed-single',
      base: (w / 2, 1000),
      shapes: [
        rect(0, 0, w, 2000),
        rect(120, 1680, w - 240, 240),
        _line(0, 1300, w, 1300),
      ],
    );

/// A wardrobe [w] x 600 of 600 mm doors: outline, the door line at y = 40,
/// a line between each pair of doors, the handles either side of the first.
/// Base point: the front centre.
CatalogSymbol _wardrobe(String key, String name, double w) => CatalogSymbol(
      key: key,
      name: name,
      category: _bedRoom,
      tags: const ['wardrobe', 'storage', 'closet'],
      attachTo: _wallFace,
      family: 'wardrobe',
      base: (w / 2, 0),
      shapes: [
        rect(0, 0, w, 600),
        _line(0, 40, w, 40),
        for (var x = 600.0; x < w; x += 600) _line(x, 40, x, 600),
        _line(560, 40, 560, 160),
        _line(640, 40, 640, 160),
      ],
    );

/// A kitchen base unit [w] x 600: outline, the front line at y = 40, the
/// knob at the front centre. Base point: the front centre.
CatalogSymbol _baseUnit(String key, String name, double w) => CatalogSymbol(
      key: key,
      name: name,
      category: _kitchen,
      tags: const ['base unit', 'cabinet', 'cupboard'],
      attachTo: _wallFace,
      family: 'kitchen-base',
      base: (w / 2, 0),
      shapes: [
        rect(0, 0, w, 600),
        _line(0, 40, w, 40),
        CatalogCircle((w / 2, 20), 10),
      ],
    );

/// A desk [w] x 700: outline, a 400 mm drawer block at the right with two
/// drawer lines. Base point: the front centre.
CatalogSymbol _desk(String key, String name, double w) => CatalogSymbol(
      key: key,
      name: name,
      category: _office,
      tags: const ['desk', 'office', 'table'],
      attachTo: _wallFace,
      family: 'desk',
      base: (w / 2, 0),
      shapes: [
        rect(0, 0, w, 700),
        _line(w - 400, 0, w - 400, 700),
        _line(w - 400, 230, w, 230),
        _line(w - 400, 460, w, 460),
      ],
    );

/// The catalog, in the order the library stores it: definition handles and
/// leaf handles ascend in this order (today's order).
final Catalog furnitureCatalog = Catalog(kit: 'architecture', symbols: [
  // Dining Room
  _diningSet(
      'architecture.dining.table.square.two',
      'Square dining table, 2 seats',
      800,
      800,
      0,
      350,
      const ['table', 'dining', 'square', 'two'],
      const [(_Side.bottom, 400), (_Side.top, 400)]),
  _diningSet(
      'architecture.dining.table.square.four',
      'Square dining table, 4 seats',
      900,
      900,
      350,
      350,
      const ['table', 'dining', 'square', 'four'],
      const [
        (_Side.bottom, 450),
        (_Side.top, 450),
        (_Side.left, 450),
        (_Side.right, 450),
      ]),
  _diningSet(
      'architecture.dining.table.rect.four',
      'Rectangular dining table, 4 seats',
      1400,
      800,
      0,
      350,
      const ['table', 'dining', 'rectangular', 'four'],
      const [
        (_Side.bottom, 350),
        (_Side.bottom, 1050),
        (_Side.top, 350),
        (_Side.top, 1050),
      ]),
  _diningSet(
      'architecture.dining.table.rect.six',
      'Rectangular dining table, 6 seats',
      1800,
      900,
      350,
      350,
      const ['table', 'dining', 'rectangular', 'six'],
      const [
        (_Side.bottom, 450),
        (_Side.bottom, 1350),
        (_Side.top, 450),
        (_Side.top, 1350),
        (_Side.left, 450),
        (_Side.right, 450),
      ]),
  // A Ø 1100 top with four chairs, centred far enough from the origin that
  // every chair has non-negative coordinates.
  CatalogSymbol(
    key: 'architecture.dining.table.round',
    name: 'Round dining table, 4 seats',
    category: _dining,
    tags: const ['table', 'dining', 'round', 'four'],
    base: (900, 900),
    shapes: [
      const CatalogCircle((900, 900), 550),
      const CatalogCircle((900, 900), 500),
      ..._chair(900 - chairSize / 2, 900 - 550 - _chairReach, _Side.bottom),
      ..._chair(900 - chairSize / 2, 900 + 550 - chairTuck, _Side.top),
      ..._chair(900 - 550 - _chairReach, 900 - chairSize / 2, _Side.left),
      ..._chair(900 + 550 - chairTuck, 900 - chairSize / 2, _Side.right),
    ],
  ),
  CatalogSymbol(
    key: 'architecture.dining.chair',
    name: 'Dining chair',
    category: _dining,
    tags: const ['chair', 'seating', 'dining'],
    base: (225, 225),
    shapes: [
      rect(0, 0, 450, 450),
      _line(0, 380, 450, 380),
      rect(40, 40, 370, 300),
    ],
  ),
  CatalogSymbol(
    key: 'architecture.dining.bench',
    name: 'Bench',
    category: _dining,
    tags: const ['bench', 'seating', 'dining'],
    base: (600, 175),
    shapes: [rect(0, 0, 1200, 350), inset(0, 0, 1200, 350, 30)],
  ),

  // Kitchen
  _baseUnit('architecture.kitchen.base.300', 'Base unit 300', 300),
  _baseUnit('architecture.kitchen.base.400', 'Base unit 400', 400),
  _baseUnit('architecture.kitchen.base.600', 'Base unit 600', 600),
  _baseUnit('architecture.kitchen.base.800', 'Base unit 800', 800),
  CatalogSymbol(
    key: 'architecture.kitchen.sink',
    name: 'Sink unit',
    category: _kitchen,
    tags: const ['sink', 'basin', 'cabinet'],
    attachTo: _wallFace,
    base: (600, 0),
    shapes: [
      rect(0, 0, 1200, 600),
      rect(60, 60, 500, 480),
      const CatalogCircle((310, 300), 35),
      _line(640, 100, 1140, 100),
      _line(640, 200, 1140, 200),
      _line(640, 300, 1140, 300),
      _line(640, 400, 1140, 400),
      const CatalogCircle((600, 570), 25),
    ],
  ),
  CatalogSymbol(
    key: 'architecture.kitchen.hob',
    name: 'Hob',
    category: _kitchen,
    tags: const ['hob', 'cooker', 'stove'],
    attachTo: _wallFace,
    base: (300, 0),
    shapes: [
      poly(const [(0, 0), (600, 0), (600, 520), (0, 520)]),
      const CatalogCircle((150, 140), 90),
      const CatalogCircle((150, 140), 40),
      const CatalogCircle((450, 140), 70),
      const CatalogCircle((450, 140), 30),
      const CatalogCircle((150, 390), 70),
      const CatalogCircle((150, 390), 30),
      const CatalogCircle((450, 390), 90),
      const CatalogCircle((450, 390), 40),
    ],
  ),
  CatalogSymbol(
    key: 'architecture.kitchen.fridge',
    name: 'Fridge',
    category: _kitchen,
    tags: const ['fridge', 'refrigerator', 'appliance'],
    attachTo: _wallFace,
    base: (300, 0),
    shapes: [
      rect(0, 0, 600, 650),
      _line(0, 40, 600, 40),
      _line(60, 40, 60, 160),
      _line(540, 40, 540, 160),
    ],
  ),
  CatalogSymbol(
    key: 'architecture.kitchen.dishwasher',
    name: 'Dishwasher',
    category: _kitchen,
    tags: const ['dishwasher', 'dishes', 'appliance'],
    attachTo: _wallFace,
    base: (300, 0),
    shapes: [
      rect(0, 0, 600, 600),
      _line(0, 40, 600, 40),
      _line(200, 20, 400, 20),
    ],
  ),
  CatalogSymbol(
    key: 'architecture.kitchen.washer',
    name: 'Washing machine',
    category: _kitchen,
    tags: const ['washer', 'laundry', 'appliance'],
    attachTo: _wallFace,
    base: (300, 0),
    shapes: [
      rect(0, 0, 600, 600),
      _line(0, 40, 600, 40),
      const CatalogCircle((300, 330), 220),
    ],
  ),
  CatalogSymbol(
    key: 'architecture.kitchen.island',
    name: 'Kitchen island',
    category: _kitchen,
    tags: const ['island', 'counter', 'worktop'],
    base: (900, 450),
    shapes: [
      rect(0, 0, 1800, 900),
      inset(0, 0, 1800, 900, 60),
      _line(600, 60, 600, 840),
      _line(1200, 60, 1200, 840),
    ],
  ),

  // Bed Room
  _doubleBed('architecture.bed.double.1400', 'Double bed 1400', 1400),
  _doubleBed('architecture.bed.double', 'Double bed', 1600),
  _doubleBed('architecture.bed.double.1800', 'Double bed 1800', 1800),
  _singleBed('architecture.bed.single.800', 'Single bed 800', 800),
  _singleBed('architecture.bed.single', 'Single bed', 900),
  _singleBed('architecture.bed.single.1000', 'Single bed 1000', 1000),
  CatalogSymbol(
    key: 'architecture.bed.nightstand',
    name: 'Nightstand',
    category: _bedRoom,
    tags: const ['nightstand', 'bedside', 'table'],
    attachTo: _wallFace,
    base: (225, 0),
    shapes: [
      rect(0, 0, 450, 400),
      inset(0, 0, 450, 400, 40),
      const CatalogCircle((225, 60), 12),
    ],
  ),
  _wardrobe('architecture.bed.wardrobe.1200', 'Wardrobe 1200', 1200),
  _wardrobe('architecture.bed.wardrobe', 'Wardrobe', 1800),
  _wardrobe('architecture.bed.wardrobe.2400', 'Wardrobe 2400', 2400),

  // Living Room
  CatalogSymbol(
    key: 'architecture.sofa.two',
    name: 'Two-seat sofa',
    category: _livingRoom,
    tags: const ['sofa', 'seating', 'couch'],
    attachTo: _wallFace,
    family: 'sofa',
    base: (750, 0),
    shapes: [
      rect(0, 0, 1500, 900),
      _line(0, 700, 1500, 700),
      _line(200, 0, 200, 700),
      _line(1300, 0, 1300, 700),
      _line(750, 0, 750, 700),
    ],
  ),
  CatalogSymbol(
    key: 'architecture.sofa.three',
    name: 'Three-seat sofa',
    category: _livingRoom,
    tags: const ['sofa', 'seating', 'couch'],
    attachTo: _wallFace,
    family: 'sofa',
    base: (1000, 0),
    shapes: [
      rect(0, 0, 2000, 900),
      _line(0, 700, 2000, 700),
      _line(200, 0, 200, 700),
      _line(1800, 0, 1800, 700),
      _line(733, 0, 733, 700),
      _line(1267, 0, 1267, 700),
    ],
  ),
  CatalogSymbol(
    key: 'architecture.armchair.single',
    name: 'Armchair',
    category: _livingRoom,
    tags: const ['armchair', 'seating', 'chair'],
    base: (425, 0),
    shapes: [
      rect(0, 0, 850, 850),
      _line(0, 650, 850, 650),
      _line(150, 0, 150, 650),
      _line(700, 0, 700, 650),
    ],
  ),
  CatalogSymbol(
    key: 'architecture.table.coffee',
    name: 'Coffee table',
    category: _livingRoom,
    tags: const ['table', 'coffee', 'low'],
    base: (550, 300),
    shapes: [rect(0, 0, 1100, 600), inset(0, 0, 1100, 600, 40)],
  ),
  CatalogSymbol(
    key: 'architecture.tv.unit',
    name: 'TV unit',
    category: _livingRoom,
    tags: const ['tv', 'media', 'unit', 'storage'],
    attachTo: _wallFace,
    base: (800, 0),
    shapes: [
      rect(0, 0, 1600, 450),
      _line(533, 0, 533, 450),
      _line(1066, 0, 1066, 450),
      _line(0, 40, 1600, 40),
    ],
  ),

  // Bathroom
  CatalogSymbol(
    key: 'architecture.bath.toilet',
    name: 'Toilet',
    category: _bathroom,
    tags: const ['toilet', 'wc', 'sanitary'],
    attachTo: _wallFace,
    base: (200, 0),
    shapes: [
      poly(const [(0, 500), (400, 500), (400, 700), (0, 700)]),
      _line(0, 500, 0, 200),
      _line(400, 500, 400, 200),
      const CatalogArc((200, 200), 200, _pi, _pi),
      _line(50, 500, 50, 200),
      _line(350, 500, 350, 200),
      const CatalogArc((200, 200), 150, _pi, _pi),
    ],
  ),
  CatalogSymbol(
    key: 'architecture.bath.washbasin',
    name: 'Washbasin',
    category: _bathroom,
    tags: const ['washbasin', 'sink', 'sanitary'],
    attachTo: _wallFace,
    base: (300, 0),
    shapes: [
      poly(const [(0, 0), (600, 0), (600, 450), (0, 450)]),
      const CatalogCircle((300, 210), 170),
      const CatalogCircle((300, 210), 20),
      const CatalogCircle((300, 410), 18),
    ],
  ),
  CatalogSymbol(
    key: 'architecture.bath.tub',
    name: 'Bathtub',
    category: _bathroom,
    tags: const ['bathtub', 'bath', 'sanitary'],
    attachTo: _wallFace,
    base: (850, 375),
    shapes: [
      rect(0, 0, 1700, 750),
      inset(0, 0, 1700, 750, 70),
      const CatalogCircle((170, 375), 25),
      const CatalogCircle((1620, 375), 15),
    ],
  ),
  CatalogSymbol(
    key: 'architecture.bath.shower',
    name: 'Shower tray',
    category: _bathroom,
    tags: const ['shower', 'tray', 'sanitary'],
    attachTo: _wallFace,
    base: (450, 450),
    shapes: [
      rect(0, 0, 900, 900),
      inset(0, 0, 900, 900, 50),
      const CatalogCircle((450, 450), 40),
    ],
  ),

  // Office
  _desk('architecture.office.desk.1200', 'Desk 1200', 1200),
  _desk('architecture.office.desk', 'Desk', 1400),
  _desk('architecture.office.desk.1600', 'Desk 1600', 1600),
  CatalogSymbol(
    key: 'architecture.office.chair',
    name: 'Office chair',
    category: _office,
    tags: const ['chair', 'office', 'seating'],
    base: (300, 300),
    shapes: [
      const CatalogCircle((300, 300), 300),
      const CatalogCircle((300, 300), 230),
      const CatalogArc((300, 300), 280, _pi / 4, _pi / 2),
    ],
  ),
  CatalogSymbol(
    key: 'architecture.office.bookshelf',
    name: 'Bookshelf',
    category: _office,
    tags: const ['bookshelf', 'shelf', 'storage'],
    attachTo: _wallFace,
    base: (450, 0),
    shapes: [
      rect(0, 0, 900, 300),
      _line(0, 30, 900, 30),
      _line(300, 30, 300, 300),
      _line(600, 30, 600, 300),
    ],
  ),
]);
```

  Check the mapping against the source symbol by symbol before generating: each symbol's shapes are the source's, in order. `grep -c "attachTo: _wallFace" packages/jet_cad_2d_kit_architecture/lib/src/furniture/furniture_catalog.dart` prints `19`: 14 single symbols (sink, hob, fridge, dishwasher, washer, nightstand, the two sofas, TV unit, toilet, washbasin, tub, shower, bookshelf) and the five family helpers, whose 16 calls make 30 in all; the ported "the against-wall set is D9's list exactly" is the oracle.

- [ ] **Step 7: The names.** Create `packages/jet_cad_2d_kit_architecture/lib/src/furniture/furniture_names.dart` (today's `furniture_names.dart:6-113`, each key under `symbol:architecture.<key>` and each category under `category:architecture/<category>`; English is the library's stored text):

```dart
// The furniture library's names in German and Turkish (spec 3a C4; today's
// jet_cad_floor_plan/lib/src/symbols/furniture_names.dart), under the kit's
// word ids: `symbol:<key>` and `category:architecture/<English category>`.
// English is the library's own stored text.
//
// Pure Dart: no Flutter, no dart:io.
/// The German words (`words.dart` spreads them into `architectureNames`).
const Map<String, String> furnitureGerman = {
    'symbol:architecture.dining.table.square.two':
        'Quadratischer Esstisch, 2 Plätze',
    'symbol:architecture.dining.table.square.four':
        'Quadratischer Esstisch, 4 Plätze',
    'symbol:architecture.dining.table.rect.four':
        'Rechteckiger Esstisch, 4 Plätze',
    'symbol:architecture.dining.table.rect.six':
        'Rechteckiger Esstisch, 6 Plätze',
    'symbol:architecture.dining.table.round': 'Runder Esstisch, 4 Plätze',
    'symbol:architecture.dining.chair': 'Esszimmerstuhl',
    'symbol:architecture.dining.bench': 'Sitzbank',
    'symbol:architecture.kitchen.base.300': 'Unterschrank 300',
    'symbol:architecture.kitchen.base.400': 'Unterschrank 400',
    'symbol:architecture.kitchen.base.600': 'Unterschrank 600',
    'symbol:architecture.kitchen.base.800': 'Unterschrank 800',
    'symbol:architecture.kitchen.sink': 'Spülenschrank',
    'symbol:architecture.kitchen.hob': 'Kochfeld',
    'symbol:architecture.kitchen.fridge': 'Kühlschrank',
    'symbol:architecture.kitchen.dishwasher': 'Geschirrspüler',
    'symbol:architecture.kitchen.washer': 'Waschmaschine',
    'symbol:architecture.kitchen.island': 'Kücheninsel',
    'symbol:architecture.bed.double.1400': 'Doppelbett 1400',
    'symbol:architecture.bed.double': 'Doppelbett',
    'symbol:architecture.bed.double.1800': 'Doppelbett 1800',
    'symbol:architecture.bed.single.800': 'Einzelbett 800',
    'symbol:architecture.bed.single': 'Einzelbett',
    'symbol:architecture.bed.single.1000': 'Einzelbett 1000',
    'symbol:architecture.bed.nightstand': 'Nachttisch',
    'symbol:architecture.bed.wardrobe.1200': 'Kleiderschrank 1200',
    'symbol:architecture.bed.wardrobe': 'Kleiderschrank',
    'symbol:architecture.bed.wardrobe.2400': 'Kleiderschrank 2400',
    'symbol:architecture.sofa.two': 'Zweisitzer-Sofa',
    'symbol:architecture.sofa.three': 'Dreisitzer-Sofa',
    'symbol:architecture.armchair.single': 'Sessel',
    'symbol:architecture.table.coffee': 'Couchtisch',
    'symbol:architecture.tv.unit': 'TV-Möbel',
    'symbol:architecture.bath.toilet': 'WC',
    'symbol:architecture.bath.washbasin': 'Waschbecken',
    'symbol:architecture.bath.tub': 'Badewanne',
    'symbol:architecture.bath.shower': 'Duschtasse',
    'symbol:architecture.office.desk.1200': 'Schreibtisch 1200',
    'symbol:architecture.office.desk': 'Schreibtisch',
    'symbol:architecture.office.desk.1600': 'Schreibtisch 1600',
    'symbol:architecture.office.chair': 'Bürostuhl',
    'symbol:architecture.office.bookshelf': 'Bücherregal',
    'category:architecture/Dining Room': 'Esszimmer',
    'category:architecture/Kitchen': 'Küche',
    'category:architecture/Bed Room': 'Schlafzimmer',
    'category:architecture/Living Room': 'Wohnzimmer',
    'category:architecture/Bathroom': 'Badezimmer',
    'category:architecture/Office': 'Büro',
};

/// The Turkish words.
const Map<String, String> furnitureTurkish = {
    'symbol:architecture.dining.table.square.two':
        'Kare yemek masası, 2 kişilik',
    'symbol:architecture.dining.table.square.four':
        'Kare yemek masası, 4 kişilik',
    'symbol:architecture.dining.table.rect.four':
        'Dikdörtgen yemek masası, 4 kişilik',
    'symbol:architecture.dining.table.rect.six':
        'Dikdörtgen yemek masası, 6 kişilik',
    'symbol:architecture.dining.table.round':
        'Yuvarlak yemek masası, 4 kişilik',
    'symbol:architecture.dining.chair': 'Yemek sandalyesi',
    'symbol:architecture.dining.bench': 'Bank',
    'symbol:architecture.kitchen.base.300': 'Alt dolap 300',
    'symbol:architecture.kitchen.base.400': 'Alt dolap 400',
    'symbol:architecture.kitchen.base.600': 'Alt dolap 600',
    'symbol:architecture.kitchen.base.800': 'Alt dolap 800',
    'symbol:architecture.kitchen.sink': 'Eviye dolabı',
    'symbol:architecture.kitchen.hob': 'Ocak',
    'symbol:architecture.kitchen.fridge': 'Buzdolabı',
    'symbol:architecture.kitchen.dishwasher': 'Bulaşık makinesi',
    'symbol:architecture.kitchen.washer': 'Çamaşır makinesi',
    'symbol:architecture.kitchen.island': 'Mutfak adası',
    'symbol:architecture.bed.double.1400': 'Çift kişilik yatak 1400',
    'symbol:architecture.bed.double': 'Çift kişilik yatak',
    'symbol:architecture.bed.double.1800': 'Çift kişilik yatak 1800',
    'symbol:architecture.bed.single.800': 'Tek kişilik yatak 800',
    'symbol:architecture.bed.single': 'Tek kişilik yatak',
    'symbol:architecture.bed.single.1000': 'Tek kişilik yatak 1000',
    'symbol:architecture.bed.nightstand': 'Komodin',
    'symbol:architecture.bed.wardrobe.1200': 'Gardırop 1200',
    'symbol:architecture.bed.wardrobe': 'Gardırop',
    'symbol:architecture.bed.wardrobe.2400': 'Gardırop 2400',
    'symbol:architecture.sofa.two': 'İkili kanepe',
    'symbol:architecture.sofa.three': 'Üçlü kanepe',
    'symbol:architecture.armchair.single': 'Koltuk',
    'symbol:architecture.table.coffee': 'Sehpa',
    'symbol:architecture.tv.unit': 'TV ünitesi',
    'symbol:architecture.bath.toilet': 'Klozet',
    'symbol:architecture.bath.washbasin': 'Lavabo',
    'symbol:architecture.bath.tub': 'Küvet',
    'symbol:architecture.bath.shower': 'Duş teknesi',
    'symbol:architecture.office.desk.1200': 'Çalışma masası 1200',
    'symbol:architecture.office.desk': 'Çalışma masası',
    'symbol:architecture.office.desk.1600': 'Çalışma masası 1600',
    'symbol:architecture.office.chair': 'Ofis sandalyesi',
    'symbol:architecture.office.bookshelf': 'Kitaplık',
    'category:architecture/Dining Room': 'Yemek odası',
    'category:architecture/Kitchen': 'Mutfak',
    'category:architecture/Bed Room': 'Yatak odası',
    'category:architecture/Living Room': 'Oturma odası',
    'category:architecture/Bathroom': 'Banyo',
    'category:architecture/Office': 'Ofis',
};
```

  (`dart format .` in Step 13 re-indents the two maps; the file imports nothing.)

  Check every non-ASCII word against the source byte for byte (2b's lesson): `grep -n "ü\|ö\|ä\|ı\|ş\|ç\|ğ\|İ\|Ü\|Ç" packages/jet_cad_2d_kit_architecture/lib/src/furniture/furniture_names.dart` and compare each line with `packages/jet_cad_floor_plan/lib/src/symbols/furniture_names.dart`. Today's `de` category word for `Kitchen` is `Küche` and the sample's kitchen word (Task 9) is also `Küche`: they are different ids, no clash.

- [ ] **Step 8: The source.** Create `packages/jet_cad_2d_kit_architecture/lib/src/furniture/furniture_source.dart`:

```dart
// The furniture library as the kit's symbol source (spec 3a C4, contract
// K5): the package's asset, read under its `packages/` key so a host app
// finds it (today's kFurnitureLibraryAsset and readBundledLibrary,
// jet_cad_floor_plan/lib/src/symbols/symbol_library_loader.dart:17-26).
import 'dart:typed_data';

import 'package:flutter/services.dart' show AssetBundle;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart'
    show SymbolLibrarySource, bundledLibrary;

/// The library's asset key: the package's, never an app's.
const String kFurnitureAsset =
    'packages/jet_cad_2d_kit_architecture/assets/library/furniture.jetlib';

/// The reader of [kFurnitureAsset] in [bundle] (`rootBundle` when null),
/// resolved each time it runs.
Future<Uint8List> Function() furnitureReader({AssetBundle? bundle}) =>
    bundledLibrary(kFurnitureAsset, bundle: bundle);

/// The kit's one symbol source: [furnitureReader] over `rootBundle`.
final SymbolLibrarySource furnitureSource =
    SymbolLibrarySource(label: 'furniture', read: furnitureReader());
```

- [ ] **Step 9: The generator.** Create `packages/jet_cad_2d_kit_architecture/tool/generate_furniture_library.dart`:

```dart
// Writes the architecture kit's furniture library from its catalog and adds
// the geometry snapshot's entries of new key@Ns, never rewriting one (spec
// 3a C4, contract K7).
//
// Run from the package directory, under plain Dart (no Flutter):
//   dart run tool/generate_furniture_library.dart
import 'dart:io';

import 'package:jet_cad_2d_kit/authoring.dart';
import 'package:jet_cad_2d_kit_architecture/src/furniture/furniture_catalog.dart';

void main() {
  final library = File('assets/library/furniture.jetlib');
  final bytes = encodeLibrary(furnitureCatalog);
  library.parent.createSync(recursive: true);
  library.writeAsBytesSync(bytes);
  final snapshot = File('assets/library/furniture.snapshot.json');
  final committed = snapshot.existsSync()
      ? parseSnapshot(snapshot.readAsStringSync())
      : <String, String>{};
  snapshot.writeAsStringSync(encodeSnapshot(
      updateSnapshot(committed, geometrySnapshot(furnitureCatalog))));
  stdout.writeln('wrote ${library.path}: ${bytes.length} bytes, '
      '${furnitureCatalog.symbols.length} symbols');
}
```

  Run it: `cd packages/jet_cad_2d_kit_architecture && dart run tool/generate_furniture_library.dart`. Expected: `wrote assets/library/furniture.jetlib: <n> bytes, 41 symbols` (quote `<n>`). If `dart run` asks for a resolution, run `flutter pub get` from the repository root, then `git status --short` and `git checkout --` any `analysis_options.yaml` it rewrote, and run the generator again. Run it a second time: `git status --short packages/jet_cad_2d_kit_architecture/assets` must show the same two new files and `git diff --stat` nothing more (the generator is deterministic and the snapshot only grows).

- [ ] **Step 10: The pubspec and the kit.**
  - `packages/jet_cad_2d_kit_architecture/pubspec.yaml`: the `flutter:` section (create it at the end of the file when Task 9 wrote none) holds

```yaml
flutter:
  assets:
    - assets/library/furniture.jetlib
```

  - `packages/jet_cad_2d_kit_architecture/lib/src/words/words.dart`: add `import '../furniture/furniture_names.dart';` and make `architectureNames` `const KitNames({'en': englishWords, 'de': {...germanWords, ...furnitureGerman}, 'tr': {...turkishWords, ...furnitureTurkish}})` (a const map may spread const maps; no id is in both, the furniture's are `symbol:`/`category:`). `lib/src/kit.dart` is unchanged: its `names:` stays `architectureNames` (Task 9's SC-ids, `identical(architectureKit.names, architectureNames)`), and `symbols:` stays empty until Task 24 (plan decision). Task 9's SC-words ignores `symbol:`/`category:` ids (its `codeWords`), so it stays green.

- [ ] **Step 11: SC-conformance over the real library (D-47).** In Task 9's SC-conformance test (`packages/jet_cad_2d_kit_architecture/test/scaffold/words_test.dart`), the `conformance(...)` call takes the real catalog, the committed library and snapshot (the empty catalog would now report every furniture word as `wordOrphan`, `conformance.dart:235-243`). Add `import 'dart:io';` and `import 'package:jet_cad_2d_kit_architecture/src/furniture/furniture_catalog.dart';` and make the call:

```dart
    final problems = conformance(
      catalog: furnitureCatalog,
      committedLibrary: File('assets/library/furniture.jetlib').readAsBytesSync(),
      committedSnapshot:
          File('assets/library/furniture.snapshot.json').readAsStringSync(),
      names: architectureKit.names,
      locales: const ['de', 'tr'],
      sameAsEnglish: architectureSameAsEnglish,
      typeIds: {...ids('type'), for (final t in architectureKit.types) t.id},
      toolIds: {...ids('tool'), for (final t in architectureKit.tools) t.id},
      propertyIds: {...ids('property'), ...architectureKit.propertyIds},
    );
    expect(problems, isEmpty, reason: problems.join('\n'));
```

  and its title gains `, over the furniture catalog, its committed library and snapshot (D-47)`. Task 9's `english` and `ids` stay (the id arguments are Task 9's, unchanged); delete its `const catalog = Catalog(...)` line, and its `package:jet_cad_2d_kit/authoring.dart` import's `show` list becomes `show conformance` (`Catalog`, `encodeLibrary`, `encodeSnapshot`, `geometrySnapshot` are then unused, which fails `flutter analyze`).

- [ ] **Step 12: Run the tests, see them pass.** `cd packages/jet_cad_2d_kit_architecture && flutter test test/furniture/` → `All tests passed!` (quote the count). Then the SC-conformance file, then the whole package: `flutter test` → `All tests passed!`.

- [ ] **Step 13: Format and the gates.**
  - `cd packages/jet_cad_2d_kit_architecture && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` → `All tests passed!`, `No issues found!`, exit 0.
  - From the repository root: `dart run tool/ci/check_kit_deps.dart` → exit 0 (the kit and its pubspec changed).
  - `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice` → `All tests passed!` (the kit's words changed; nothing else reaches the plan yet).
  - From the root, `git status --short`: only this task's files (restore any rewritten `analysis_options.yaml` with `git checkout --`).

- [ ] **Step 14: Commit.**

```bash
git add packages/jet_cad_2d_kit_architecture/lib/src/furniture/furniture_catalog.dart packages/jet_cad_2d_kit_architecture/lib/src/furniture/furniture_names.dart packages/jet_cad_2d_kit_architecture/lib/src/furniture/furniture_source.dart packages/jet_cad_2d_kit_architecture/tool/generate_furniture_library.dart packages/jet_cad_2d_kit_architecture/assets/library/furniture.jetlib packages/jet_cad_2d_kit_architecture/assets/library/furniture.snapshot.json packages/jet_cad_2d_kit_architecture/lib/src/words/words.dart packages/jet_cad_2d_kit_architecture/pubspec.yaml packages/jet_cad_2d_kit_architecture/test/support/place_entry.dart packages/jet_cad_2d_kit_architecture/test/furniture/furniture_library_test.dart packages/jet_cad_2d_kit_architecture/test/furniture/package_assets_test.dart packages/jet_cad_2d_kit_architecture/test/scaffold/words_test.dart
git commit -m "$(cat <<'EOF'
feat(architecture): the furniture library (3a C4)

Today's 41 furniture symbols in the authoring language, leaf for leaf,
under architecture.<key>@1 (armchair is architecture.armchair.single);
the 30 against-the-wall symbols attach to wall-face and the six size
families are fields; the dining tables are plain symbols. The generator
writes the library and its geometry snapshot; the German and Turkish
names join the kit's words; the source reads the package's asset key.
The furniture test, PA2 and PA3 are ported, and the conformance test
runs over the real library.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 15: Mutation check** (committed files only; after each: run the named test, see it red, quote the red line, then `git checkout -- <files>` and `git diff --quiet -- <files>` must exit 0; paths under `packages/jet_cad_2d_kit_architecture/`):
  - M-FU1 `lib/src/furniture/furniture_catalog.dart`: delete `attachTo: _wallFace,` from `architecture.kitchen.hob`, then run the generator → "the against-wall set is D9's list exactly" red. Revert the catalog, `assets/library/furniture.jetlib` and `assets/library/furniture.snapshot.json`.
  - M-FU2 same file: `_baseUnit`'s tags gain `'against-wall'` (`const ['base unit', 'cabinet', 'cupboard', 'against-wall']`), then run the generator → FU-tags red. Revert the three files.
  - M-FU3 same file: `architecture.dining.table.round` (an inline `CatalogSymbol`; the square tables go through `_diningSet`, which takes no unit) gains `unit: const CatalogUnit(kind: UnitKinds.table, capacity: 4),` (no generator: the catalog half of the test reads it) → FU-plain-tables red.
  - M-FU4 same file: `_chair`'s `_Side.bottom` back line `y + 60` → `y + 50` in both points, no generator → "the committed bytes equal the built library" red and SC-conformance red (`builtDiffers`, `snapshotChanged`).
  - M-FU5 same file: `'architecture.armchair.single'` → `'architecture.armchair.one'`, then run the generator → FU-keys red. Revert the three files.
  - M-FU6 `lib/src/furniture/furniture_source.dart`: `kFurnitureAsset`'s value → `'assets/library/furniture.jetlib'` → FU-asset-key and PA2 red.
  - M-FU7 `lib/src/furniture/furniture_names.dart`: the `de` word of `symbol:architecture.bed.double` → `'Double bed'` → SC-conformance red (`wordUntranslated`).
  - M-FU8 `lib/src/words/words.dart`: `{...germanWords, ...furnitureGerman}` → `germanWords` (and the import of `furniture_names.dart` removed) → SC-conformance red (`wordMissing` for every furniture word in `de`).
  - M-FU9 `pubspec.yaml`: delete the line `    - assets/library/furniture.jetlib` → "is declared in the pubspec" red.

#### Assumed from earlier tasks

Each name is used as written; where the earlier task named it otherwise, use that task's name and report the difference.
- Task 1: `SymbolBox`, `boxOfEntry`, `placementTransform` exported by `package:jet_cad_2d_kit/jet_cad_2d_kit.dart` (and `authoring.dart`), unchanged from `jet_cad_2d_plan/lib/src/symbols/{symbol_box,symbol_placer}.dart`.
- Task 9: `final PlanKit architectureKit` in `lib/src/kit.dart` with a `names:` argument of `architectureNames` (`lib/src/words/words.dart`); a kit `pubspec.yaml` with `vector_math` among its dependencies; an SC-conformance test calling `conformance(...)` with a `sameAsEnglish` map.

#### Interface problem

**(Resolved by rulings R-P1 and R-P3: such a case runs in the kit over `test/support/place_entry.dart`.)** `placeSymbol` cannot be called where spec C7 puts the cases that use it. C7 sends a case naming `placeSymbol` to `jet_cad_2d_integration`, but that package may import the public libraries only (`implementation_imports`, Global Constraints), and the plan library exports no placer (`packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart`: no `symbols/symbol_placer.dart` export; `placeSymbol` is `lib/src/symbols/symbol_placer.dart:169`). The cases affected: this task's "every symbol placed" and "plausible size" groups; D-13 (`symbol_box_test.dart:321-339, 391-410`); and D-01's `wall_attach_test` and `wall_attach_property_test`, which also name the kit's internals (`attachToWall`, `FaceRun`, `WallBands`, `WallFaces`: `jet_cad_floor_plan/test/symbols/wall_attach_test.dart:13-19, 119, 358-374`), unreachable from the integration package too. Proposed fix (taken here for this task's cases): such a case runs **in the kit** and places through `test/support/place_entry.dart` (the placer's no-unit path over the engine's commands and the contract's `placementTransform`), its assertions unchanged; Task 28 ports D-01's two files and D-13's three cases the same way. The alternative (exporting `placeSymbol` from the plan library) widens the plan's public surface, which spec 2a fixed; it is the human's call, not a task's.

#### New shared name

- `packages/jet_cad_2d_kit_architecture/test/support/place_entry.dart`: `CompoundCommand placeEntry(DraftDocument doc, SymbolEntry entry, {required Vector2 at, int quarterTurns = 0, bool mirrored = false, Transform2? transform})` and `Handle? copyOfEntry(DraftDocument doc, SymbolEntry entry)`. Used by Task 24's provider tests and, by the problem above, Task 28's D-01 and D-13 ports.

---

