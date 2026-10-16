### Task 25: The sample flat (spec C3.7, C1.9, C6; Appendix A D-34)

**Files:**
- Create (`packages/jet_cad_2d_kit_architecture/`): `lib/src/sample/sample_flat.dart` (`buildSampleFlat` and today's sample constants), `test/sample/sample_flat_test.dart` (12 ported cases and SF-words)
- Modify (`packages/jet_cad_2d_kit_architecture/`): `lib/jet_cad_2d_kit_architecture.dart` (export `buildSampleFlat`), `test/wall/wall_regen_test.dart` (WR9's sample-plan line, carried from Task 11, ruling R11-1)
- Modify (`packages/jet_cad_2d_integration/`): `lib/jet_cad_2d_integration.dart` (`sampleFlatController`)
- Create (`packages/jet_cad_2d_integration/`): `test/sample/sample_flat_test.dart` (2 ported cases and SF-controller)

**Interfaces:**
- Consumes:
  - Task 3: `KitWords.text(String id, [Map<String, Object> args])`, `KitWords.decimalSeparator`, `KitNamesWords(KitNames, Locale Function(), {String Function()? decimalSeparator})`; the `text:` words of Task 9 (`text:architecture.sample-hall`, `sample-kitchen`, `sample-bath`, `sample-living`, `sample-dining`, `sample-bedroom` with `{n}`).
  - Task 5: `typedef PlanBuild = void Function(DraftDocument document, KitWords words)`; `PlanController({…, PlanBuild? build})`; `PlanKit.prepare`.
  - Task 9: `architectureKit` (its `prepare` is `ensureDashedLinetype`), the kit barrel, the integration library and `architectureController`.
  - Tasks 11-21, today's names: `WallParams(sx, sy, ex, ey, thickness, justification)`, `Justification` (Task 11); `OpeningParams(host, position, width, kind, {hinge, swing})`, `OpeningKind`, `HingeEnd`, `SwingSide` (Task 13); `SeparatorParams(sx, sy, ex, ey)` (Task 16); `RoomParams(seedX, seedY, name)` (Task 18), `Traced`, `pointInRing` (Task 16, `room/room_trace.dart`); `DimensionParams(a, b, kind, offset)`, `DimEnd`, `AttachedEnd(wall, end, side)`, `FixedEnd(x, y)`, `DimKind`, `WallSide`, `DimensionType` (Tasks 20, 21); `BoxParams` (Task 10).
  - Test support: Task 16/18's `test/support/room_fixture.dart` (`anchorOf`, `kids`, `kindOf`, `labelsOf`, `labelStrings`, `payloadOf`, `probeView`, `worldPoints`), Task 20's `test/support/dimension_fixture.dart` (`dimLines`, `dimText`, `dimTextGeometry`).
  - Engine: `PageComponent` (`register`, `effectiveWidthMm`, `effectiveHeightMm`, `scaleDenominator`, `copyWith`), `DecimalSeparator`, `addDraftedRegion` (`jet_cad_2d/lib/src/document/drafting.dart:69`), `sheetWorldRect`; Flutter layer: `FlutterTextMeasurer`, `ViewportTransform`, `kPickRadiusPixels`, `resolveHit`; plan: `kPlanMinScale`, `kPlanMaxScale` (`jet_cad_2d_plan/lib/src/controller/camera_bounds.dart:13-14`, exported).
- Produces (Shared interfaces, exact):

```dart
// packages/jet_cad_2d_kit_architecture/lib/src/sample/sample_flat.dart, exported by the barrel
void buildSampleFlat(DraftDocument document, KitWords words); // a PlanBuild
// internal: today's constants
const double kPlanOriginX = 12000.0, kPlanOriginY = 8000.0, kPlanWidth = 14000.0, kPlanHeight = 9000.0;
// packages/jet_cad_2d_integration/lib/jet_cad_2d_integration.dart
PlanController sampleFlatController(); // build: buildSampleFlat
```

**Appendix A rows closed:**
- **D-34** `jet_cad_floor_plan/test/startup_plan_test.dart` (14): 12 cases in the kit, 2 in the integration package (below). `intersection_snap_test` is Task 26's.
- C3.7 (the sample flat as a `PlanBuild`) and C6's "a controller over the sample flat", which Tasks 26-28 use (D-23, D-24, A1-A4, the paint-allocation invariant).
- D-19's `wall_regen_test` WR9, whole: its sample-plan line (`wall_regen_test.dart:497-501`), carried from Task 11 (R11-1), restored in Step 2b.

**Plan decisions:**
- **The move** (C3.7): today's `startupPlan` (`jet_cad_floor_plan/lib/src/startup_plan.dart:70-255`) without `prepareDocument` (:76), its own system (:82, :252) and `clearHistory` (:253), which the plan library now does (C1.9). Every object is added by command in today's source order (draw order is reading order). The page is set where today sets it (after the separator, before the rooms), with `words.decimalSeparator` (`','` → `DecimalSeparator.comma`, else `point`: today's `documentSeparatorFor`, `l10n/document_separator.dart:14-17`). The rooms are named by `words.text('text:architecture.sample-…')`. The camera clamp constants (`kMinScale`, `kMaxScale`, :50-51) are not moved: they are the plan's `kPlanMinScale`, `kPlanMaxScale`, the same values.
- **The kit test's document** is made as the plan library makes one for `build` (C1.9): the page's, the contract's and the kit's components, millimetres, the kit's `prepare`, a parametric system over the kit's six types, `buildSampleFlat`, then the history cleared. Two differences, neither read by a ported case: the plan's registry also holds the unit components (`plan_controller.dart:374-379`), and `newPlanDocument` attaches the default page (`new_plan.dart:15-18, 29-30`) before the build replaces it; the kit test attaches no page before the build, as today's `prepareDocument` did not (`jet_cad_floor_plan/lib/src/new_document.dart:18-24`). `sampleFlatController()` (Step 3's SF-controller) runs the plan library's own path. Each kit case's `startupPlan(measurer)` becomes that document. SP9's "one undo step" needs the cleared history (a document keeps at most 200 steps, `DraftDocument.empty`'s `undoLimit`, and the build executes more).
- **Placement (C7).** The 12 cases that read only the document go to the kit. "the clamp constants bracket the fitted scale by decades" (the plan's constants) and "the startup plan carries an A4 landscape page at 1:50 … with no history" (the history after a build is the plan library's) go to the integration package over `sampleFlatController()`, assertions unchanged; there the kit's internal constants are written out (public libraries only).
- **Systems.** SP5 asks the installed system for `drift()` and `diagnostics()` (today it made a fresh uninstalled one over the global catalog after the sample's system was disposed); SP9 uses the installed system (today it installed one, which would now throw: `ParametricSystem.install`, `jet_cad_2d/lib/src/parametric/parametric_system.dart:718-722`); SP6 installs its own over the decoded document with the test's catalog.

- [ ] **Step 1: Precondition.** Tasks 1-24 are committed. `cd packages/jet_cad_2d_kit_architecture && flutter analyze` → `No issues found!`. Read the kit's `test/support/room_fixture.dart` and `test/support/dimension_fixture.dart`; if `probeView` (today's `room_fixture.dart:311`) gained a catalog or reader argument in Task 16, pass it as Task 16's tests do.

- [ ] **Step 2: The kit test.** Copy `packages/jet_cad_floor_plan/test/startup_plan_test.dart` to `packages/jet_cad_2d_kit_architecture/test/sample/sample_flat_test.dart` and adapt it. **Assertions unchanged.**
  - Header (new, before the imports):

```dart
// 3a Task 25 (spec C3.7, C1.9; D-34), ported from jet_cad_floor_plan/test/
// startup_plan_test.dart: the sample flat built by buildSampleFlat on a
// document made as the plan library makes one for `build`. The clamp
// constants' case and the page-with-no-history case are the integration
// package's (test/sample/sample_flat_test.dart there).
```

  - Imports (source :1-28) become:

```dart
import 'dart:math' as math;
import 'dart:ui' show Locale, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart'
    show KitNamesWords, KitWords, registerKitComponents;
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_kit_architecture/src/dimension/dimension.dart'
    show DimensionType;
import 'package:jet_cad_2d_kit_architecture/src/room/room_trace.dart'
    show Traced, pointInRing;
import 'package:jet_cad_2d_kit_architecture/src/sample/sample_flat.dart'
    show kPlanHeight, kPlanOriginX, kPlanOriginY, kPlanWidth;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/dimension_fixture.dart' show dimLines, dimText, dimTextGeometry;
import '../support/room_fixture.dart'
    show
        anchorOf,
        kids,
        kindOf,
        labelsOf,
        labelStrings,
        payloadOf,
        probeView,
        worldPoints;
```

  (`architectureKit`, the parameter classes and `buildSampleFlat` come from the barrel; import `DimensionType` from the file Task 20/21 put it in.)
  - After `wallExtents` (source :55-61) add the document the plan library would make:

```dart
/// The sample flat as the plan library builds it for `PlanController(build:)`
/// (spec C1.9): a document over [measurer] with the page's, the contract's
/// and the kit's components and millimetres; the kit's `prepare` (the DASHED
/// record); a parametric system over the kit's six types, installed and
/// disposed at tear-down; [buildSampleFlat] in [words] (English and the
/// point by default); then the history cleared, as the plan library clears
/// it.
({DraftDocument doc, ParametricSystem system, ParametricCatalog catalog})
    sampleFlat(FlutterTextMeasurer measurer, {KitWords? words}) {
  final catalog = ParametricCatalog();
  for (final type in architectureKit.types) {
    type.registerInto(catalog);
  }
  final doc = DraftDocument.empty(measurer: measurer);
  PageComponent.register(doc.components);
  registerKitComponents(doc.components);
  catalog.registerComponents(doc.components);
  doc.header.units = DrawingUnits.millimeters;
  architectureKit.prepare!(doc);
  final system = ParametricSystem(doc, catalog)..install();
  addTearDown(system.dispose);
  buildSampleFlat(
      doc,
      words ??
          KitNamesWords(architectureKit.names, () => const Locale('en')));
  doc.commands.clearHistory();
  return (doc: doc, system: system, catalog: catalog);
}
```

  - `perl -pi -e 's/startupPlan\(measurer\)/sampleFlat(measurer).doc/g' packages/jet_cad_2d_kit_architecture/test/sample/sample_flat_test.dart`, then:
    - SP5 (source :429, :579): its first line becomes `final flat = sampleFlat(measurer);` and `final doc = flat.doc;`; `final system = ParametricSystem(doc, parametricCatalog);` → `final system = flat.system;`.
    - SP9 (source :680-682): `final doc = sampleFlat(measurer).doc; final system = installParametric(doc); addTearDown(system.dispose);` → `final flat = sampleFlat(measurer); final doc = flat.doc; final system = flat.system;`.
    - SP6 (source :732-739): `final doc = sampleFlat(measurer).doc;` → `final flat = sampleFlat(measurer); final doc = flat.doc;`; `parametricCatalog.registerComponents(r);` → `flat.catalog.registerComponents(r);`; `final system = installParametric(loaded);` → `final system = ParametricSystem(loaded, flat.catalog)..install(); addTearDown(system.dispose);`.
  - Delete the two cases the integration package runs: "the clamp constants bracket the fitted scale by decades" (source :119-133) and "the startup plan carries an A4 landscape page at 1:50 centred on the plan, in millimetres, with no history" (:135-158).
  - Ported to the kit (12): "is at the target scale: between 500 and 1,000 entities", "is off-origin and not axis-symmetric", "the outer walls close: …", SP1, SP2, SP3, SP4, SP5, SP8, SP9, SP6, SP7. Check `grep -n "²\|√\|−\|—" packages/jet_cad_2d_kit_architecture/test/sample/sample_flat_test.dart` against the source's lines.
  - Append the new case at the end of `main`:

```dart
  test(
      'SF-words the sample is built in the words it is given: German room '
      'names, and the comma, which the page, the area labels and the '
      'dimension values then print', () {
    final de = KitNamesWords(architectureKit.names, () => const Locale('de'),
        decimalSeparator: () => ',');
    final doc = sampleFlat(measurer, words: de).doc;
    final rooms = doc.components.withComponent<RoomParams>().toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    expect([for (final r in rooms) doc.components.get<RoomParams>(r)!.name], [
      'Flur',
      'Schlafzimmer 1',
      'Schlafzimmer 2',
      'Küche',
      'Bad',
      'Wohnen',
      'Essen',
    ]);
    expect(doc.components.get<PageComponent>(doc.rootHandle)!.decimalSeparator,
        DecimalSeparator.comma);
    expect(labelStrings(doc, rooms.first), ['Flur', '22,00 m²']);
    final dims = doc.components.withComponent<DimensionParams>().toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    expect([for (final d in dims) dimText(doc, d)],
        ['14,00', '9,00', '4,69', '4,38', '3,58']);
  });
```

  The German names are today's `strings_de.dart:426-441`.

- [ ] **Step 2b: WR9's sample-plan line (carried from Task 11, ruling R11-1).** In `packages/jet_cad_2d_kit_architecture/test/wall/wall_regen_test.dart`, replace the two-line comment Task 11 left in WR9 (`// The sample plan's line (wall_regen_test.dart:497-501) returns with` / `// buildSampleFlat in Task 25 (ruling R11-1).`) with today's `:497-501`, **its assertion unchanged** (`expect(diagnosticsOf(sample), isEmpty);`), the sample made as Step 2's `sampleFlat` makes it, over the kit tests' catalog:

```dart
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final sample = DraftDocument.empty(measurer: measurer);
    PageComponent.register(sample.components);
    registerKitComponents(sample.components);
    testCatalog().registerComponents(sample.components);
    sample.header.units = DrawingUnits.millimeters;
    architectureKit.prepare!(sample);
    final system = installParametric(sample);
    addTearDown(system.dispose);
    buildSampleFlat(sample,
        KitNamesWords(architectureKit.names, () => const Locale('en')));
    sample.commands.clearHistory();
    expect(diagnosticsOf(sample), isEmpty);
```

  and add the imports `dart:ui show Locale`, `package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart show FlutterTextMeasurer` (Task 11 removed today's `:11`), `package:jet_cad_2d_kit/jet_cad_2d_kit.dart show KitNamesWords, registerKitComponents` and `package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart show architectureKit, buildSampleFlat` (`testCatalog`, `installParametric` and `diagnosticsOf` are the wall fixture's). Today's lines `:497-501` built `startupPlan(measurer)` and installed the global catalog's system on it; the build above is the plan library's for `build` (C1.9), the change of fixture R11-1 names. Run `flutter test test/wall/wall_regen_test.dart` after Step 5: `All tests passed!`.

- [ ] **Step 3: The integration test.** Create `packages/jet_cad_2d_integration/test/sample/sample_flat_test.dart`. The two ported cases are the source's (`startup_plan_test.dart:119-158`), **assertions unchanged**; adaptations: the document is `sampleFlatController().document`; `kMinScale`, `kMaxScale` → `kPlanMinScale`, `kPlanMaxScale` (the plan's, equal values); the sample's constants written out; `wallExtents` copied unchanged (:53-61).

```dart
// 3a Task 25 (spec C3.7, C1.9, C6; D-34): the sample flat built by the plan
// library over the architecture kit. Ported from jet_cad_floor_plan/test/
// startup_plan_test.dart: the clamp constants' case (now the plan's
// constants) and the page-with-no-history case (the history after a build
// is the plan library's). The kit runs the other twelve.
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show ViewportTransform;
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

// The kit's sample constants the page case reads (its lib/src/sample/
// sample_flat.dart), written out: this package imports public libraries
// only.
const double kPlanOriginX = 12000.0;
const double kPlanWidth = 14000.0;

/// The walls' extents: the union of every wall group's bounds (each at the
/// identity, SP5), so the dimensions' lines outside the plan are not in it.
Aabb2 wallExtents(DraftDocument doc) {
  var box = Aabb2.empty();
  for (final w in doc.components.withComponent<WallParams>()) {
    box = box.union(doc.definitionBounds(w));
  }
  return box;
}

/// Lets the controller's library load finish.
Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

PlanController flat() {
  final c = sampleFlatController();
  addTearDown(c.dispose);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Spec D4's owed check: the constants against the document's own units.
  // At 1440 x 900 the fit scale is 0.95 * min(1440 / 14000, 900 / 9000) --
  // 0.095 px/mm -- so kPlanMinScale allows ~95x further out and
  // kPlanMaxScale ~1000x further in. Both decades are needed by a CAD user;
  // neither is absurd. The numbers are printed so the results note can
  // quote them.
  test('the clamp constants bracket the fitted scale by decades', () {
    final doc = flat().document;
    final fit = ViewportTransform.fit(doc.extents, const Size(1440, 900));
    // ignore: avoid_print
    print('STARTUP fit scale ${fit.scale} px/mm; '
        'min $kPlanMinScale (${fit.scale / kPlanMinScale}x out), '
        'max $kPlanMaxScale (${kPlanMaxScale / fit.scale}x in)');
    expect(fit.scale / kPlanMinScale, greaterThan(10));
    expect(kPlanMaxScale / fit.scale, greaterThan(100));
  });

  test(
      'the startup plan carries an A4 landscape page at 1:50 centred on the '
      'plan, in millimetres, with no history', () {
    final doc = flat().document;
    final page = doc.components.get<PageComponent>(doc.rootHandle)!;
    expect(page.preset, SheetSize.a4);
    expect(page.orientation, PageOrientation.landscape);
    expect(page.scaleDenominator, 50);
    expect(page.displayUnit, DisplayUnit.meters);
    final rect = sheetWorldRect(page);
    // Centred on the plan, the walls' outer rectangle (19,000, 12,500):
    // the page is set before the rooms and dimensions, and spec 11 D17's
    // overall dimensions, outside the walls, do not move it (Ruling 11-14,
    // the controller's ruling).
    final extents = wallExtents(doc);
    expect(extents.center.x, 19000);
    expect(extents.center.y, 12500);
    expect(rect.center.x, closeTo(extents.center.x, 1e-9));
    expect(rect.center.y, closeTo(extents.center.y, 1e-9));
    expect(rect.minX, lessThan(kPlanOriginX));
    expect(rect.maxX, greaterThan(kPlanOriginX + kPlanWidth));
    expect(doc.header.units, DrawingUnits.millimeters);
    expect(doc.commands.canUndo, isFalse, reason: 'Ruling 04-1');
  });

  test(
      'SF-controller sampleFlatController opens the sample flat clean: seven '
      'rooms named in English, 611 entities, nothing to undo, not dirty, no '
      'diagnostic once the library has loaded', () async {
    final c = flat();
    await settle();
    final doc = c.document;
    final rooms = doc.components.withComponent<RoomParams>().toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    expect([for (final r in rooms) doc.components.get<RoomParams>(r)!.name], [
      'Hall',
      'Bedroom 1',
      'Bedroom 2',
      'Kitchen',
      'Bath',
      'Living',
      'Dining',
    ]);
    expect(doc.entities.liveCount, 611);
    expect(c.canUndo.value, isFalse);
    expect(c.dirty.value, isFalse);
    expect(c.diagnostics.value, isEmpty);
  });
}
```

  Task 9's integration pubspec already lists `jet_cad_2d`, `jet_cad_2d_flutter`, `jet_cad_2d_kit` and `vector_math` (R-P6): no pubspec change here. If it does not (a Task 9 finding), stop and report it.

- [ ] **Step 4: Run the tests, see them fail.** `cd packages/jet_cad_2d_kit_architecture && flutter test test/sample/` → compile error: `lib/src/sample/sample_flat.dart` does not exist (`buildSampleFlat` undefined). `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice test/sample/` → compile error: `sampleFlatController` undefined.

- [ ] **Step 5: `sample_flat.dart`.** Create `packages/jet_cad_2d_kit_architecture/lib/src/sample/sample_flat.dart`:
  - Header and imports (new; today's :1-29 comment kept in substance):

```dart
// The sample flat (spec 3a C3.7): today's startupPlan (jet_cad_floor_plan/
// lib/src/startup_plan.dart:70-255) as a PlanBuild (C1.9). The plan library
// makes the document, runs every kit's `prepare` (the DASHED record),
// installs its parametric system, runs this, then clears the history and
// takes the save point: so this function neither prepares the document nor
// installs or disposes a system nor clears the history, as today's did.
//
// A hand-written flat, in millimetres: two bedrooms, a living room, a
// kitchen, a bathroom and a hall, with walls, doors, windows, a few pieces
// of furniture and the floor finishes drawn in -- the finishes are what
// carry the count into the target scale (500-5,000 entities) while every
// line stays something a person can check by eye.
//
// Walls, openings, a separator, rooms and dimensions are parametric objects:
// nine walls and fifteen openings; a 400 mm column, a tenth wall; the
// Living | Dining separator; seven rooms named in the given words; five
// dimensions. Eight furniture pieces are drafted fills, not library symbols.
// Everything is added by command in source order, so draw order (ascending
// handle) is reading order.
//
// Off-origin and not axis-symmetric, by construction: a drawing centred on
// (0, 0) is the degenerate fixture this repository keeps rediscovering.
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show KitWords;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../dimension/dimension.dart';
import '../opening/opening.dart';
import '../room/room.dart';
import '../separator/separator.dart';
import '../wall/wall.dart';
```

  (Import `DimensionParams`, `DimEnd`, `AttachedEnd`, `FixedEnd`, `DimKind`, `WallSide`, `OpeningParams`, `OpeningKind`, `SwingSide`, `SeparatorParams`, `RoomParams`, `WallParams`, `Justification` from the files Tasks 11-21 put them in; drop an import that names nothing this file uses. `dimension_geometry.dart` is not imported: `dimension.dart` re-exports it (today's `dimension.dart:24`, Task 20), and a second import of it is an `unnecessary_import` warning, which fails `flutter analyze`.)
  - Today's constants (:53-63) unchanged, without `kMinScale`/`kMaxScale` (:47-51: the plan's `kPlanMinScale`/`kPlanMaxScale`):

```dart
/// The flat's outer wall corner, and its outer size.
const double kPlanOriginX = 12000.0;
const double kPlanOriginY = 8000.0;
const double kPlanWidth = 14000.0;
const double kPlanHeight = 9000.0;

const double _wall = 250.0; // exterior wall thickness
const double _partition = 120.0; // interior wall thickness

const DraftColor _furnitureColor = TrueColor(0x8A6D3B);
const DraftColor _finishColor = TrueColor(0xBBBBBB);
```

  - The build (today's :65-255):

```dart
/// Builds the sample flat into [document] (spec C3.7), a `PlanBuild`: its
/// rooms named in [words] (`text:architecture.sample-*`), its page printing
/// [words]' decimal separator. [document] has the plan's components and a
/// parametric system over the kit's types (the plan library's, C1.9).
void buildSampleFlat(DraftDocument document, KitWords words) {
  final doc = document;
  final p = _Pen(doc);
```

  then copy today's lines 84-198 unchanged (the walls, doors, windows, finishes, furniture, column and separator, comments included), then:

```dart
  // The page is document data, attached through the log like everything
  // else, before the rooms so they read the real page. Centred on the
  // extents, which the rooms do not change. Its decimal separator is the
  // words' (today's documentSeparatorFor), set before the rooms and the
  // dimensions, so their text is generated with it.
  doc.commands.execute(SetComponentCommand<PageComponent>(
      doc.rootHandle,
      _samplePage(doc.extents,
          decimalSeparator: words.decimalSeparator == ','
              ? DecimalSeparator.comma
              : DecimalSeparator.point)));

  // Seven rooms: the six spaces, and the dining area the separator splits
  // off the living room. Each seed lies in no band.
  String sample(String id, [Map<String, Object> args = const {}]) =>
      words.text('text:architecture.$id', args);
  p.room(14500, 10500, sample('sample-hall'));
  p.room(13300, 15000, sample('sample-bedroom', {'n': 1}));
  p.room(15800, 15000, sample('sample-bedroom', {'n': 2}));
  p.room(19000, 10000, sample('sample-kitchen'));
  p.room(23500, 10000, sample('sample-bath'));
  p.room(24500, 16000, sample('sample-living'));
  p.room(19000, 16000, sample('sample-dining'));
```

  then copy today's lines 222-247 unchanged (the five dimensions), and close the function with `}` (today's :249-254, the system's dispose and `clearHistory`, are not copied).
  - The page (today's `startupPage`, :257-267, private now):

```dart
/// The sample's page: A4 landscape at 1:50 in metres, centred on [extents],
/// printing [decimalSeparator].
PageComponent _samplePage(Aabb2 extents,
    {DecimalSeparator decimalSeparator = DecimalSeparator.point}) {
  final page = PageComponent(decimalSeparator: decimalSeparator);
  final w = page.effectiveWidthMm * page.scaleDenominator;
  final h = page.effectiveHeightMm * page.scaleDenominator;
  return page.copyWith(
      originX: extents.center.x - w / 2, originY: extents.center.y - h / 2);
}
```

  - Copy today's lines 269-422 (`_Pen`) unchanged.
  - `grep -n "x0\|_Pen\|clearHistory\|installParametric\|prepareDocument\|strings\." packages/jet_cad_2d_kit_architecture/lib/src/sample/sample_flat.dart`: no `clearHistory`, `installParametric`, `prepareDocument` or `strings.` line remains.

- [ ] **Step 6: The barrel and the integration library.**
  - `packages/jet_cad_2d_kit_architecture/lib/jet_cad_2d_kit_architecture.dart`: add `export 'src/sample/sample_flat.dart' show buildSampleFlat;` (the barrel's exact list, Shared interfaces).
  - `packages/jet_cad_2d_integration/lib/jet_cad_2d_integration.dart`, beside `architectureController`:

```dart
/// A controller over the architecture kit whose plan is the sample flat
/// (spec C3.7, C1.9): built by the plan library, so it opens clean with
/// nothing to undo, its rooms named in the controller's words (English
/// until a locale is reported).
PlanController sampleFlatController() =>
    PlanController(kits: [architectureKit], build: buildSampleFlat);
```

  If Task 9's `architectureController` passes more than `kits` (a measurer, thumbnails), pass the same here.

- [ ] **Step 7: Run the tests, see them pass.**
  - `cd packages/jet_cad_2d_kit_architecture && flutter test test/sample/` → `All tests passed!` (13 tests); then `flutter test`.
  - `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice test/sample/` → `All tests passed!` (3 tests); quote the `STARTUP fit scale` line; then `flutter test --enable-vmservice`.

- [ ] **Step 8: Format and the gates.**
  - `cd packages/jet_cad_2d_kit_architecture && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .`
  - `cd packages/jet_cad_2d_integration && dart format . && flutter test --enable-vmservice && flutter analyze && dart format --output=none --set-exit-if-changed .`
  - From the root: `dart run tool/ci/check_kit_deps.dart` → exit 0.
  - `git status --short`: only this task's files.

- [ ] **Step 9: Commit.**

```bash
git add packages/jet_cad_2d_kit_architecture/lib/src/sample/sample_flat.dart packages/jet_cad_2d_kit_architecture/lib/jet_cad_2d_kit_architecture.dart packages/jet_cad_2d_kit_architecture/test/sample/sample_flat_test.dart packages/jet_cad_2d_integration/lib/jet_cad_2d_integration.dart packages/jet_cad_2d_integration/test/sample/sample_flat_test.dart packages/jet_cad_2d_kit_architecture/test/wall/wall_regen_test.dart
git commit -m "$(cat <<'EOF'
feat(architecture): the sample flat as a plan build (3a C3.7)

Today's startup plan moves into the kit as buildSampleFlat, a PlanBuild:
the plan library prepares the document, installs its system and clears
the history, so the build only adds today's walls, openings, finishes,
furniture fills, separator, rooms and dimensions in source order, the
rooms named in the given words and the page printing their separator.
The integration package gains sampleFlatController; startup_plan_test
is ported, twelve cases in the kit and two over the controller.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

  (No pubspec changes in this task; the root `pubspec.lock` is not tracked.)

- [ ] **Step 10: Mutation check** (committed files only; after each: run the named test, see it red, quote the red line, then `git checkout -- <file>` and `git diff --quiet -- <file>` must exit 0):
  - M-SF1 `packages/jet_cad_2d_kit_architecture/lib/src/sample/sample_flat.dart`: `words.decimalSeparator == ','` → `false` → SF-words red (the page's point, `22.00 m²`).
  - M-SF2 same file: `sample('sample-hall')` → `'Hall'` → SF-words red.
  - M-SF3 same file: move the separator's line (`p.separator(x0 + 9500, …)`) above the column's (`p.wall(x0 + 11500, …)`) → SP2 red (the column after the furniture, then the separator).
  - M-SF4 same file: delete the statement that sets the sample's page (`doc.commands.execute(SetComponentCommand<PageComponent>(…));`) → in `packages/jet_cad_2d_integration`, `flutter test --enable-vmservice test/sample/`: "the startup plan carries an A4 landscape page at 1:50 centred on the plan …" red (the plan's default page is centred on the world origin, `jet_cad_2d_plan/lib/src/controller/new_plan.dart:15-18`).
  - M-SF5 `packages/jet_cad_2d_integration/lib/jet_cad_2d_integration.dart`: `PlanController(kits: [architectureKit], build: buildSampleFlat)` → `PlanController(kits: [architectureKit])` → SF-controller red.

#### Assumed from earlier tasks

Each name is used as written; where the earlier task named it otherwise, use that task's name and report the difference.
- Task 3: `KitNamesWords(names, locale, {String Function()? decimalSeparator})`, `KitWords.text`, `KitWords.decimalSeparator`; Task 9's English, German and Turkish `text:architecture.sample-*` words are today's (`strings_{en,de,tr}.dart` `sampleHall` … `sampleBedroom(n)`), `sample-bedroom` holding `{n}`.
- Task 5: `PlanKit.prepare` (`void Function(DraftDocument)?`), `PlanController({…, PlanBuild? build})`.
- Task 9: the integration package's library with `architectureController`; its pubspec listing `jet_cad_2d_plan` and `jet_cad_2d_kit_architecture` (Step 3 adds the engine and the Flutter layer if missing).
- Tasks 16, 18, 20: the kit's `test/support/room_fixture.dart` and `test/support/dimension_fixture.dart` with today's helper names and shapes.
- Tasks 20, 21: `DimensionType` constructible as today (`const DimensionType()`); if it now takes the kit's reader, construct it as Task 21's tests do (SP8 reads only `references`).

---

