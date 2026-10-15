### Task 15: Painting, theme, the design canvas's colours and the export fills (spec S4 "Painting", "Theme"; S2 "Locked units"; CLAUDE.md's frame-path rule)

**Files:**
- Modify: `packages/jet_cad_2d_plan/lib/src/theme/plan_theme.dart` (the thirteen fields; copyWith, merge, lerp, `==`, `hashCode`, `toString`, `validatePlanTheme`)
- Create: `packages/jet_cad_2d_plan/lib/src/service/paint/unit_status_painter.dart` (port of `floor_plan/lib/src/service/table_status_painter.dart`)
- Create: `packages/jet_cad_2d_plan/lib/src/service/paint/unit_group_painter.dart` (port of `floor_plan/lib/src/service/table_group_painter.dart`)
- Create: `packages/jet_cad_2d_plan/lib/src/service/paint/unit_focus_painter.dart` (port of `floor_plan/lib/src/service/table_focus_painter.dart`)
- Create: `packages/jet_cad_2d_plan/lib/src/export/unit_colour_underlay.dart` (port of `floor_plan/lib/src/colors/table_color_underlay.dart`, plus `checkedUnitColourOpacity` and the built-ins' fills)
- Modify: `packages/jet_cad_2d_plan/lib/src/export/registries.dart` (`PlanExportRequest.unitColourOpacity`), `export/builtin_exporters.dart` (the fills), `export/page_flows.dart` (the opacity, the fills), `export/editor_page_flows.dart` (the view's opacity)
- Modify: `packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart` (`export`/`print` take `unitColourOpacity`; the flows read the active unit index; `documentUnits`)
- Modify: `packages/jet_cad_2d_plan/lib/src/canvas/plan_canvas.dart` (the design colour underlay), `canvas/plan_canvas_view.dart` (`tableOverlays` → `unitOverlays`), `editor/plan_editor.dart` (the flows' opacity)
- Test support (new): `test/support/service_paint.dart` (`ServicePaintLayers`: the four painters over one session as today's view mounted them, `floor_plan/lib/src/host/service_view.dart:282-351`, `:558-599`; Task 16's `PlanServiceView` mounts its own), `test/support/unit_zone_fixture.dart` (port of `floor_plan/test/host/zone_fixture.dart`)
- Test (new): `test/service/paint/unit_paint_test.dart` (SP-seat-fill, SP-group-mixed, SP-locked-status, SP-dup-label), `test/export/unit_colour_opacity_test.dart` (SP-export-seat, SP-opacity-arg, SP-request), in `test/invariants/canvas_paint_allocation_test.dart`: CV-alloc-colour, CV-alloc-service
- Test (ported): `test/service/paint/unit_status_painter_test.dart`, `unit_group_painter_test.dart`, `unit_focus_painter_test.dart`, `unit_theme_painter_test.dart`, `unit_fill_test.dart`, `test/export/unit_colour_export_test.dart`; `test/theme/plan_theme_test.dart` gains the source's seventeen-field cases

(Paths below are under `packages/jet_cad_2d_plan/` unless they start at the repository root. `floor_plan/` abbreviates `packages/jet_cad_floor_plan/`.)

**Interfaces:**
- Consumes:
  - Flutter layer: `PaperPalette.forPaper`, `foregroundFor`, `darkCanvasTone`, `kStatusCaptionOnLight`, `kStatusCaptionOnDark`, `displayPaperFor`, `darkCanvasFor`, `kDarkCanvasPaper`, `ViewportTransform`, `PageUnderlayFill`, `PageUnderlayPolygon`, `PageUnderlayCircle`, `exportPagePdf`/`exportPagePng`'s `underlay:` (`jet_cad_2d_flutter/lib/src/export/page_export.dart:37-42`, `:113-118`), `triangulateSimplePolygon`.
  - Task 6: `UnitInfo` (`instance`, `definition`, `owner`, `label`, `text`, `visible`, `locked`, `generated`, `toWorld`), `UnitIndex` (`units`), `UnitIndexCache` (`current`), `UnitColour` (`swatch`), `registerUnitComponents`.
  - Task 8 (`lib/src/service/unit_picker.dart`): `UnitPicker.candidatesOf(DraftDocument document, UnitIndex index, {required Map<Handle, Aabb2> boxes, required Map<Handle, List<int>> Function() leaves})` → `List<UnitCandidate>` (`unit`, `transform`, `box`, `corners`, `locked`), `UnitPicker.tolerance`, `unitTopOf`, `PolygonTop`, `CircleTop`; test support `test/support/unit_fixtures.dart` (`fxKit`, `unitPlan`, `placeUnit`, `placeAt`, `placeTurned`, `addLayer`, `addUnitLabel`, `unitsOf`, `entryOf`, `tableUnit`, the symbols `tableSymbol`, `trapezoidTable`, `stoolSymbol`, `openTable`, `kDeg37`); `embeddingTable` from Task 8's `test/support/unit_editor_fixture.dart` (re-exported by Task 9's `unit_embedding_fixture.dart`).
  - Task 9: `@internal UnitIndex get unitIndex` (the active document's since Task 11), `setUnitColour`, `unitDetails`, `editorSelectedUnits`; test support `test/support/unit_embedding_fixture.dart`.
  - Task 11: `ServiceSession` (`document`, `units`), `PlanController.serviceSession`, `PlanMode`.
  - Task 12: `UnitStatus`, `UnitGroup`, `GroupUnit`, `groupIdsByLabel`, `inLeadOrder` (Assumed from earlier tasks); `PlanController.unitStatuses`, `unitGroups`, `groupStatuses`, `unitFocus` and their setters.
  - Task 14: test support `numberedRowOfTables`, `copyForService` (`unit_fixtures.dart`), `parts` (`service_rig.dart`).
  - Task 5: `unitKit()`, `tableSymbolId` (`test/support/test_kit.dart`); `serviceFixture()`, `testEntry`, `unitLabelsOf` (`test/support/service_fixture.dart`); 2a's `planText`.
  - 2a: `PlanTheme`, `PlanThemeScope`, `validatePlanTheme`, `PlanCanvas`, `PlanCanvasView`, `PlanPageFlows`, `EditorPageFlows`, `PlanExportRequest`, the built-in exporters, `PlanEditor`; `test/support/canvas_fixture.dart`, `recording_exporters.dart`, `fake_page_printer.dart`.
- Produces:
  - `const double kUnitColourOpacity = 0.35` in `lib/src/theme/plan_theme.dart` (today's `kTableColorOpacity`, `floor_plan_theme.dart:14`; the Shared interfaces list it; controller ruling R-22).
  - `PlanTheme` (exported already) gains, in today's declaration order (`floor_plan/lib/src/host/floor_plan_theme.dart:29-47`): `TextStyle? statusCaptionStyle`, `double? statusFillOpacity`, `double? unitColourOpacity`, `Color? groupFrameColor`, `double? groupFrameWidth`, `double? groupFrameMargin`, `Color? groupChipColor`, `TextStyle? groupChipTextStyle`, `double? groupChipRadius`, `EdgeInsets? groupChipPadding`, then the four 2a fields with `focusVeilColor` and `focusVeilOpacity` before `canvasBackground`, and `double? serviceBarHeight` last.
  - `PlanExportRequest.unitColourOpacity` (`double`, constructor parameter `this.unitColourOpacity = kUnitColourOpacity`); `PlanController.export(String exporterId, PlanExportChoice choice, {String? name, double? unitColourOpacity})` and `print(PlanExportChoice choice, {PagePrinter? printer, String? name, double? unitColourOpacity})`: null is 0.35; a value not finite or outside [0, 1] is an `ArgumentError` named `unitColourOpacity`, thrown at the call.
  - Internal (`lib/src/service/paint/`):
    - `unit_status_painter.dart`: `class UnitStatusPainter extends CustomPainter` — `UnitStatusPainter({required DraftDocument document, required UnitIndexCache units, required ValueListenable<ViewportTransform> camera, required ValueListenable<Map<String, UnitStatus>> statuses, required ValueListenable<Map<String, UnitGroup>> unitGroups, required ValueListenable<Map<String, UnitStatus>> groupStatuses, required ValueListenable<int> paper, ValueListenable<PlanTheme?>? theme, bool Function()? darkCanvas, required Listenable repaint})`, `debugAllocations`, `debugRebuilds`, `debugCached`; `const double kStatusCaptionSize = 11`, `kStatusCaptionGap = 2`; `int over(Color colour, int paper)`; `Color statusCaptionInk(Color colour, int paper)`; `TextStyle paintedTextStyle(TextStyle style, Color ink)`.
    - `unit_group_painter.dart`: `enum UnitGroupLayer { frames, chips }`; `class UnitGroupPainter extends CustomPainter` — `UnitGroupPainter({required UnitGroupLayer layer, required DraftDocument document, required UnitIndexCache units, required ValueListenable<ViewportTransform> camera, required ValueListenable<Map<String, UnitGroup>> groups, required ValueListenable<int> paper, ValueListenable<Set<String>?>? unitFocus, ValueListenable<PlanTheme?>? theme, required Listenable repaint})`, `debugAllocations`, `debugRebuilds`, `debugChipTexts`; `String groupLabel(UnitGroup group, Iterable<GroupUnit> members)`; `convexHull`, `offsetHull` (`@visibleForTesting`); `kGroupFrameMarginMm`, `kGroupFrameStrokePixels`, `kGroupChipPaddingX`, `kGroupChipPaddingY`, `kGroupChipRadius`.
    - `unit_focus_painter.dart`: `class UnitFocusPainter extends CustomPainter` — `UnitFocusPainter({required DraftDocument document, required UnitIndexCache units, required ValueListenable<ViewportTransform> camera, required ValueListenable<Set<String>?> focus, required ValueListenable<int> paper, ValueListenable<PlanTheme?>? theme, required Listenable repaint})`, `debugAllocations`, `debugRebuilds`, `debugRecolours`; `const double kUnitFocusVeilAlpha = 0.6`; `Color focusVeilColour(int paper, PlanTheme? theme)`.
    These are the constructors Task 16's view calls (its "Assumed from earlier tasks", Task 15 row, and "Interface problem" 4).
  - Test support (`test/support/service_paint.dart`): `final class ServicePaintLayers` — `ServicePaintLayers({required PlanController controller, required ServiceSession session, required bool Function() darkCanvas})`; `ValueNotifier<int> paper`, `ValueNotifier<PlanTheme?> theme`; the four painters (`statuses`, `frames`, `chips`, `focus`); `Widget get underlay` (the frames, then the statuses: keys `unit-group-layer`, `unit-status-layer`); `Widget get overlay` (the veil, then the chips: keys `unit-focus-layer`, `unit-group-chips`); `void dispose()`. Today's mount, for the painter and invariant tests until Task 16's view exists.
  - Internal (`lib/src/export/unit_colour_underlay.dart`): `List<PageUnderlayFill> unitColourUnderlay(UnitIndex index, DraftDocument document, double opacity, {Set<Handle> omitted = const {}})`; `double checkedUnitColourOpacity(double? given)`; `final Expando<List<PageUnderlayFill>> unitFillsOf`.
  - Internal: `PlanCanvasView.unitOverlays` (renamed from `tableOverlays`); `PlanCanvas` paints the unit colours under the drafting (key `unit-colour-layer`); `@internal UnitIndexCache get documentUnits` on `PlanController` (the design session's cache; it never switches with the mode); `EditorPageFlows({…, double Function() unitColourOpacity})`.

Plan decision (**what moves to Task 16**): `floor_plan/test/host/theme_service_test.dart`, `test/host/status_caption_test.dart` and `test/host/table_groups_look_test.dart` pump `FloorPlanView` in the selection mode (`theme_service_test.dart:147-154`, `status_caption_test.dart:68-81`, `table_groups_look_test.dart:141-142`), and so do `table_fill_test.dart`'s TF6 (`:650-673`) and the selection-mode tail of TF7 (`:735-755`), and `floor_plan_theme_test.dart`'s "resolution (T-2, S-11), in both modes" selection runs (`:673-783`) and its tests that read `ServiceView` or the service layout (`:832-1020`). They need `PlanServiceView`, so they are ported in Task 16 (controller ruling R-15, its Step B2b), assertions unchanged; TF7's tail moves as `TF7b` ("may move, never weaken", 2a's ruling). This task ports every painter-level, design-mode and export test; its service scene is mounted by the test harness `ServicePaintLayers`, today's mount (`service_view.dart:282-351`, `:558-599`), which Task 16's view repeats in `lib`.

Plan decision (**the room rows go to sub-project 3**): TF1 and TF7 assert a coloured table inside a teal room and the room's tint (`table_fill_test.dart:529-546`, `:688-713`), and EX5 compares against a room fill; rooms are sub-project 3's. As 2a moved its room rows (2a results note, "Moved assertions"), these lines move to sub-project 3: the fixture has no room and no `R`, and only the lines naming `R`, `tintSample` or `tintAlpha` are dropped; every other assertion of TF1, TF7 and EX5 is ported unchanged. Accepted by controller ruling R-16 (an execution ruling the ledger records).

Plan decision (**a unit's world transform is the index's**): today's painters read `node.transform` per frame (`table_status_painter.dart:392-394`), right for a root-level table. A seat's world transform is its row's group × its instance (spec S2), which `UnitInfo.toWorld` holds. The fills capture it at rebuild; the rebuild key is the unit index object (`UnitIndexCache.current`, rebuilt on the state id, the layers' revision and `locked`), which subsumes today's state id and tables revision (`:363-385`). A frame still allocates nothing.

Plan decision (**the export fills**): an exporter receives a codec copy of the plan (`page_flows.dart:137-158`) and no catalog, so it cannot tell a row's seats from a plain group's instances. The flows compute the fills from the live active document's `UnitIndex` (the copy has the same handles and geometry), skipping the units of omitted objects, and hand them to the built-ins through the internal `unitFillsOf` expando on the request; a host's exporter receives `request.unitColourOpacity` (spec S4) and the copy. The shape of `PlanExportRequest` stays the Shared interfaces' plus that one field.

Plan decision (**the editor's opacity**): today's view read the ambient extension with its own theme over it at each export (`floor_plan/lib/src/host/floor_plan_view.dart:533-546`); `PlanEditor` does the same through `EditorPageFlows.unitColourOpacity`, and a host's direct `export`/`print` call takes the argument or 0.35 (`floor_plan_controller.dart:1338-1384`).

- [ ] **Step 1: The failing tests.** Create `test/service/paint/unit_paint_test.dart`:

```dart
// 2b spec S4 "Painting"; S2 "Locked units", "Unlabelled, duplicate and bad
// labels": the status, group and focus painters over placed and generated
// units, on the controller's service copy. The fixture is Task 5's
// serviceFixture(): the table turned and mirrored off the origin, row A
// turned, row B curved. Painters are built over the session and recorded
// on a spy canvas; the expected matrices are the camera times the unit's
// world transform computed here from the row's group and the seat's
// instance, never read from the painter.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter/rendering.dart' show CustomPainter;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show PlanKit, kUnitLabelTag;
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:jet_cad_2d_plan/src/symbols/symbol_placer.dart' show placeSymbol;
import 'package:jet_cad_2d_plan/src/service/service_session.dart' show PlanMode;
import 'package:jet_cad_2d_plan/src/service/service_state.dart'
    show UnitGroup, UnitStatus;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../../support/harness.dart' show planText;
import '../../support/service_fixture.dart';
import '../../support/service_paint.dart';
import '../../support/service_rig.dart' show parts;
import '../../support/test_kit.dart';

/// Records the matrices and paths a painter hands the canvas.
class Spy implements ui.Canvas {
  final List<Float64List> matrices = [];
  final List<ui.Path> paths = [];
  final List<Color> colours = [];
  final List<ui.Paragraph> paragraphs = [];

  @override
  void save() {}
  @override
  void restore() {}
  @override
  void translate(double dx, double dy) {}
  @override
  void transform(Float64List m) => matrices.add(Float64List.fromList(m));
  @override
  void drawPath(ui.Path path, ui.Paint paint) {
    paths.add(path);
    colours.add(paint.color);
  }

  @override
  void drawRRect(ui.RRect rrect, ui.Paint paint) {}
  @override
  void drawParagraph(ui.Paragraph p, ui.Offset offset) => paragraphs.add(p);
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnsupportedError('${i.memberName}');
}

const Color red = Color(0xFFE53935), blue = Color(0xFF3949AB);

/// 0.1 px/mm, y up, panned.
const Transform2 cam = Transform2(0.1, 0, 0, -0.1, -3900, -2600);

({PlanController c, ServicePaintLayers layers}) service(String json,
    {List<PlanKit>? kits}) {
  final c = PlanController(kits: kits ?? [unitKit()], json: json);
  addTearDown(c.dispose);
  c.setMode(PlanMode.service);
  c.camera.value = ViewportTransform(worldToScreenMatrix: cam);
  final layers = ServicePaintLayers(
      controller: c, session: c.serviceSession!, darkCanvas: () => false);
  addTearDown(layers.dispose);
  return (c: c, layers: layers);
}

Spy frame(CustomPainter p) {
  final spy = Spy();
  p.paint(spy, const ui.Size(1600, 1200));
  return spy;
}

/// camera · [t] as the 4x4 the painter writes (a, b, c, d, e, f placed).
List<double> matrixOf(Transform2 t) {
  final a = cam.a * t.a + cam.c * t.b, b = cam.b * t.a + cam.d * t.b;
  final c = cam.a * t.c + cam.c * t.d, d = cam.b * t.c + cam.d * t.d;
  final e = cam.a * t.e + cam.c * t.f + cam.e;
  final f = cam.b * t.e + cam.d * t.f + cam.f;
  return [a, b, c, d, e, f];
}

List<double> abcdef(Float64List m) => [m[0], m[1], m[4], m[5], m[12], m[13]];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'SP-seat-fill a status on a seat fills at the row\'s group times the '
      'seat\'s instance, not the instance alone (M-SP-seat)', () {
    final f = serviceFixture();
    final s = service(f.json);
    final doc = s.c.serviceSession!.document;
    final seat = doc.tree[f.seatsA[1]]! as InstanceNode;
    final row = doc.tree[seat.parent]! as GroupNode;
    final world = row.transform.multiply(seat.transform);
    expect(parts(world), isNot(parts(seat.transform)),
        reason: 'premise: the row is placed off the origin and turned');
    s.c.setUnitStatus({'A2': UnitStatus(color: red, caption: 'Bill')});

    final spy = frame(s.layers.statuses);
    expect(spy.paths, hasLength(1));
    final got = abcdef(spy.matrices.single);
    final want = matrixOf(world);
    for (var i = 0; i < 6; i++) {
      expect(got[i], closeTo(want[i], 1e-9), reason: 'coefficient $i');
    }
  });

  test(
      'SP-group-mixed a group of the table and two seats with a group '
      'status: three fills in its colour, one caption, under the lead; a '
      'frame round all three, and one chip (M-SP-frame)', () {
    final f = serviceFixture();
    final s = service(f.json);
    final table = s.c.unitIndex[f.table]!.text!;
    expect(table.compareTo('A1'), lessThan(0),
        reason: 'premise: the table\'s number leads the plain label order');
    s.c.setUnitGroups({
      'g': UnitGroup(members: {table, 'A1', 'A2'})
    });
    s.c.setGroupStatus({'g': UnitStatus(color: blue, caption: 'Gr')});

    final fills = frame(s.layers.statuses);
    expect(fills.colours, [blue, blue, blue]);
    expect(fills.paragraphs, hasLength(1), reason: 'one caption');
    final frames = frame(s.layers.frames);
    expect(frames.paths, hasLength(1), reason: 'one frame');
    expect(s.layers.chips.debugChipTexts, isEmpty,
        reason: 'premise: no chip before a chips frame');
    frame(s.layers.chips);
    expect(s.layers.chips.debugChipTexts, ['$table+A1+A2']);
  });

  test(
      'SP-locked-status Review Focus 4: the rows\' kit missing, a group '
      'status paints on the locked seats (M-SP-locked)', () {
    final f = serviceFixture();
    final s = service(f.json, kits: const <PlanKit>[]);
    expect(s.c.unitIndex[f.seatsA[0]]!.locked, isTrue, reason: 'premise');
    s.c.setUnitGroups({
      'g': UnitGroup(members: {'A1', 'A2'})
    });
    s.c.setGroupStatus({'g': UnitStatus(color: blue)});
    expect(frame(s.layers.statuses).colours, [blue, blue]);
  });

  test(
      'SP-dup-label a label two placed units share (a loaded file): a status '
      'on it fills both (M-SP-dup)', () {
    // Two tables, the second's label rewritten to the first's in the file
    // (a host cannot write a used label: setUnitLabel refuses it, Task 9).
    final json = planText([unitKit()], (d) {
      final entry = testEntry(tableSymbolId);
      final a = placeSymbol(d, entry,
          at: Vector2(-2400.5, 3100.25), quarterTurns: 1, mirrored: true);
      d.commands.execute(a);
      final b = placeSymbol(d, entry, at: Vector2(3600.25, -2900.5));
      d.commands.execute(b);
      Handle instanceOf(CompoundCommand c) =>
          c.children.whereType<AddNodeCommand>().last.node.handle;
      final first = instanceOf(a), second = instanceOf(b);
      // A label each: the numbering placer's (Task 7), or the fixture's.
      for (final (h, text) in [(first, '12'), (second, '13')]) {
        if (unitLabelsOf(d, h).isEmpty) {
          labelPlacedUnit(d, h, entry, text);
        }
      }
      d.commands.execute(SetEntityTextCommand(unitLabelsOf(d, second).first.$1,
          unitLabelsOf(d, first).first.$2, kUnitLabelTag));
    });
    final s = service(json);
    final shared = s.c.unitIndex.units.first.text!;
    expect(s.c.unitIndex.withLabel(shared), hasLength(2), reason: 'premise');
    s.c.setUnitStatus({shared: UnitStatus(color: red)});
    expect(frame(s.layers.statuses).colours, [red, red]);
  });
}
```

  `placeSymbol` is 2a's (`lib/src/symbols/symbol_placer.dart`); `testEntry`, `tableSymbolId`, `unitLabelsOf` and `labelPlacedUnit` are Task 5's; the test imports `package:jet_cad_2d_kit/jet_cad_2d_kit.dart show PlanKit, kUnitLabelTag` and `package:jet_cad_2d_plan/src/symbols/symbol_placer.dart show placeSymbol`.

  Create `test/export/unit_colour_opacity_test.dart`:

```dart
// 2b spec S4 "Painting": PlanExportRequest.unitColourOpacity, the
// controller's export and print argument (today's tableColorOpacity,
// floor_plan_controller.dart:1338-1384), and a seat's fill in the export's
// underlay placed by its row's group times its instance.
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show PageUnderlayFill;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show PlanSwatch;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/export/unit_colour_underlay.dart';

import '../support/fake_page_printer.dart';
import '../support/recording_exporters.dart';
import '../support/service_fixture.dart';
import '../support/service_rig.dart' show parts;
import '../support/test_kit.dart' show unitKit;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'SP-export-seat a coloured seat\'s fill is placed by its row\'s group '
      'times its instance (M-SP-export)', () {
    final f = serviceFixture();
    final c = PlanController(kits: [unitKit()], json: f.json);
    addTearDown(c.dispose);
    expect(c.setUnitColour('A2', PlanSwatch.teal), isTrue, reason: 'premise');
    final doc = c.document;
    final seat = doc.tree[f.seatsA[1]]! as InstanceNode;
    final row = doc.tree[seat.parent]! as GroupNode;
    final fills = unitColourUnderlay(c.unitIndex, doc, 0.35);
    expect(fills, hasLength(1));
    final PageUnderlayFill fill = fills.single;
    expect(parts(fill.placement), parts(row.transform.multiply(seat.transform)));
    expect(fill.argb, (89 << 24) | PlanSwatch.teal.rgb);
  });

  testWidgets(
      'SP-opacity-arg export and print refuse an opacity outside [0, 1] at '
      'the call, naming unitColourOpacity; null is 0.35 (M-SP-check)',
      (tester) async {
    final rec = RecordingExporter('acme.text', 'txt', 'text/plain');
    final c = PlanController(
        kits: [unitKit()], json: serviceFixture().json, exporters: [rec]);
    addTearDown(c.dispose);
    for (final bad in [-0.01, 1.01, double.nan, double.infinity]) {
      expect(
          () => c.export(rec.id, PlanExportChoice.initial,
              unitColourOpacity: bad),
          throwsA(isA<ArgumentError>()
              .having((e) => e.name, 'name', 'unitColourOpacity')));
      expect(
          () => c.print(PlanExportChoice.initial,
              printer: FakePagePrinter(), unitColourOpacity: bad),
          throwsA(isA<ArgumentError>()
              .having((e) => e.name, 'name', 'unitColourOpacity')));
    }
    await tester.runAsync(() => c.export(rec.id, PlanExportChoice.initial));
    expect(rec.requests.single.unitColourOpacity, 0.35);
  });

  testWidgets(
      'SP-request a host\'s exporter receives the given opacity '
      '(M-SP-request)', (tester) async {
    final rec = RecordingExporter('acme.text', 'txt', 'text/plain');
    final c = PlanController(
        kits: [unitKit()], json: serviceFixture().json, exporters: [rec]);
    addTearDown(c.dispose);
    await tester.runAsync(() => c.export(rec.id, PlanExportChoice.initial,
        unitColourOpacity: 0.6));
    expect(rec.requests.single.unitColourOpacity, 0.6);
  });
}
```

  `RecordingExporter` is 2a's (`test/support/recording_exporters.dart:11-48`): it keeps every request it was handed (`requests`); a request's `unitColourOpacity` is a plain field, readable after the copy is disposed.

- [ ] **Step 2: Run them, expecting failure.** Run: `cd packages/jet_cad_2d_plan && flutter test test/service/paint/unit_paint_test.dart test/export/unit_colour_opacity_test.dart`. Expected: compile errors naming `../../support/service_paint.dart` (not found until Step 5), `package:jet_cad_2d_plan/src/service/paint/unit_status_painter.dart` and `package:jet_cad_2d_plan/src/export/unit_colour_underlay.dart` (not found).

- [ ] **Step 3: The theme.** In `lib/src/theme/plan_theme.dart`:
  1. The header's last sentence (`:5-6`) becomes `2b adds the statuses, groups, focus veil, unit colours and service bar.`
  2. The constructor, the fields, `copyWith`, `merge`, `lerp`, `==`, `hashCode` and `_fields` follow `floor_plan/lib/src/host/floor_plan_theme.dart:29-352` field by field, with exactly these changes: `FloorPlanTheme` → `PlanTheme`; `tableColorOpacity` → `unitColourOpacity` (doc: "Both modes' unit colour fills: the hue's alpha, in the range 0 to 1. Null: 0.35."); every doc's "selection mode" → "service", "table" → "unit"; `lerp` keeps 2a's covariant signature (`plan_theme.dart:102-104`). The helpers `_mergeStyle`, `_lerpInsets` and `_lerpStyle` are copied from `floor_plan_theme.dart:195-196`, `:268-289` unchanged. The fields' doc comments are today's, renamed.
  2b. Before `PlanTheme`, today's constant (`floor_plan/lib/src/host/floor_plan_theme.dart:14`), renamed; no earlier task declares it (controller ruling R-22):

```dart
/// The unit colour fill's default alpha (spec 2b S4 "Painting"): both
/// modes, and every exporter's `PlanExportRequest.unitColourOpacity`.
const double kUnitColourOpacity = 0.35;
```

  3. `validatePlanTheme` (`plan_theme.dart:156-165`) becomes today's `validateFloorPlanTheme` (`floor_plan_theme.dart:363-420`) with `tableColorOpacity` → `unitColourOpacity` (the argument name included) and the doc's "view" → "scope".

- [ ] **Step 4: The painters.** Create the three files under `lib/src/service/paint/` as ports, each starting `// Ported from jet_cad_floor_plan/lib/src/service/<file> (2b spec S4 "Painting"): over units, placed and generated.`, followed by the source's header comment renamed (table → unit, number → label, selection mode → service).
  1. **`unit_status_painter.dart`** from `table_status_painter.dart:1-441`. Adaptations:
     - Imports (`:16-21`): `'../../theme/plan_theme.dart' show PlanTheme, kUnitColourOpacity;`, `'../../units/unit_index.dart' show UnitIndex, UnitIndexCache, UnitInfo;`, `'../../units/unit_components.dart' show UnitColour;`, `'../service_state.dart' show GroupUnit, UnitGroup, UnitStatus, groupIdsByLabel, inLeadOrder;`, `'../unit_picker.dart' show CircleTop, PolygonTop, unitTopOf;`.
     - `_Fill` (`:25-40`) gains `final Transform2 toWorld;` after `instance` (constructor `_Fill(this.instance, this.toWorld, this.path, …)`), doc: "Definition space to world: the unit's, captured at rebuild (a seat's is its row's group × its instance)."
     - The class (`:123-198`): `TableStatusPainter` → `UnitStatusPainter`; the constructor gains `required this.units,` after `required this.document,`, and `tableGroups` → `unitGroups`; field types `ValueListenable<Map<String, UnitStatus>>`, `ValueListenable<Map<String, UnitGroup>>`, `ValueListenable<PlanTheme?>?`; new field `/// The document's units, as the session's cache holds them. final UnitIndexCache units;`. The build state `int? _state; int? _tablesRevision;` (`:161-162`) becomes `UnitIndex? _indexBuilt;`; `_themeBuilt` is a `PlanTheme?`.
     - `_rebuild(PlanTheme? look)` (`:200-301`): from `final fills = <_Fill>[];` (`:208`) to the end of the first loop (`:258`) becomes the code below; from `// The lead of each statused group` (`:259`) on, unchanged but `(t, path, drawn, status, id)` → `(u, path, drawn, status, id)`, `t.instance` → `u.instance`, `_labelOf(t.label)` → `_labelOf(u.label)`, and `_Fill(t.instance,` → `_Fill(u.instance, u.toWorld,`.

```dart
    final fills = <_Fill>[];
    // Every unit of the index, placed or generated; the colours live in
    // the document (PC-5).
    final index = units.current;
    final groupOf = groupMap.isEmpty
        ? const <String, String>{}
        : groupIdsByLabel(unitGroups.value);
    final tone = darkCanvas?.call() ?? false;
    final colourAlpha =
        (255 * (look?.unitColourOpacity ?? kUnitColourOpacity)).round();
    // Each visible unit with a top and a fill, in draw order (the index is
    // ascending by handle): its drawn colour, and its status when the fill
    // is one (a status's group id when it is the group's); per statused
    // group its members that may lead.
    final filled = <(UnitInfo, Path, Color, UnitStatus?, String?)>[];
    final candidates = <String, List<GroupUnit>>{};
    for (final u in index.units) {
      // The status rungs key by label; the colour rung needs none.
      final label = u.text;
      final id = label == null ? null : groupOf[label];
      final groupStatus = id == null ? null : groupMap[id];
      final status = label == null ? null : (groupStatus ?? map[label]);
      final colour = status == null
          ? document.components.get<UnitColour>(u.instance)?.swatch
          : null;
      if (status == null && colour == null) continue;
      // A hidden layer's unit is not filled; a locked one is (S2).
      if (!u.visible) continue;
      final path = _paths.putIfAbsent(u.definition, () => _pathOf(u));
      if (path == null) continue;
      final Color drawn;
      if (status != null) {
        drawn = opacity == null
            ? status.color
            : status.color.withValues(alpha: status.color.a * opacity);
      } else {
        final rgb = tone
            ? darkCanvasTone(colour!.rgb, paperArgb & 0xFFFFFF)
            : colour!.rgb;
        drawn = Color((colourAlpha << 24) | rgb);
      }
      filled.add((u, path, drawn, status, groupStatus == null ? null : id));
      if (groupStatus != null) {
        (candidates[id!] ??= []).add(GroupUnit(
            handle: u.instance, label: label!, visible: true, locked: false));
      }
    }
```

     - `_pathOf` (`:319-335`): `Path? _pathOf(UnitInfo u)`, `tableTopOf(document, t.definition)` → `unitTopOf(document, u.definition)`.
     - `paint` (`:361-431`): the head becomes the code below; the loop body from `final t = node.transform;` (`:394`) on is unchanged, its two preceding lines (`:392-393`) replaced by `final t = f.toWorld;`.

```dart
  @override
  void paint(Canvas canvas, Size size) {
    final index = units.current;
    final map = statuses.value;
    final groups = unitGroups.value;
    final groupMap = groupStatuses.value;
    final paperArgb = paper.value;
    final look = theme?.value;
    if (!identical(_indexBuilt, index) ||
        !identical(_builtFor, map) ||
        !identical(_groupsBuilt, groups) ||
        !identical(_groupStatusesBuilt, groupMap) ||
        _paperBuilt != paperArgb ||
        !identical(_themeBuilt, look)) {
      _rebuild(look);
      _indexBuilt = index;
      _builtFor = map;
      _groupsBuilt = groups;
      _groupStatusesBuilt = groupMap;
      _paperBuilt = paperArgb;
      _themeBuilt = look;
    }
    final fills = _fills;
    if (fills.isEmpty) return;
    final cam = camera.value.worldToScreenMatrix;
    final m = _matrix;
    for (var i = 0; i < fills.length; i++) {
      final f = fills[i];
      final t = f.toWorld;
```

     - `shouldRepaint` (`:433-440`): `tableGroups` → `unitGroups`, and `|| !identical(oldDelegate.units, units)`.
     - Doc words: "table" → "unit", "number" → "label", "unnumbered" → "unlabelled", `FloorPlanTableColor` → `UnitColour`, "selection mode" → "service", `kTableColorOpacity` → `kUnitColourOpacity`, `tableColorOpacity` → `unitColourOpacity`.
  2. **`unit_focus_painter.dart`** from `table_focus_painter.dart:1-200`. Adaptations:
     - Imports (`:13-14`): `'../../theme/plan_theme.dart' show PlanTheme;`, `'../../units/unit_index.dart' show UnitIndex, UnitIndexCache;`, `'../unit_picker.dart' show UnitCandidate, UnitPicker;`.
     - `kTableFocusVeilAlpha` → `kUnitFocusVeilAlpha`; `focusVeilColour(int paper, PlanTheme? theme)`.
     - The class: `TableFocusPainter` → `UnitFocusPainter`, constructor gains `required this.units,` after `document`; `theme` is `ValueListenable<PlanTheme?>?`; the `_boxes` map (`:85-87`) stays (Task 8's `candidatesOf` caches into it); `int? _state; int? _tablesRevision;` → `UnitIndex? _indexBuilt;`; `_themeBuilt` a `PlanTheme?`.
     - `_rebuild` (`:110-130`): the loop becomes `for (final c in UnitPicker.candidatesOf(document, units.current, boxes: _boxes, leaves: document.leavesByOwner)) { final label = c.unit.text; if (label != null && focused.contains(label)) { _addQuad(kept, c); } else { _addQuad(faded, c); any = true; } }` (Task 8's Z0 candidates: a seat's quad through its world transform). `_addQuad(Path path, UnitCandidate c)` unchanged in body.
     - `paint` (`:150-162`): `final index = units.current;` and the key `!identical(_indexBuilt, index) || !identical(_builtFor, focused)`, storing `_indexBuilt = index`.
     - `shouldRepaint`: `|| !identical(oldDelegate.units, units)`.
  3. **`unit_group_painter.dart`** from `table_group_painter.dart:1-540`. Adaptations:
     - Imports (`:13-19`): `'../../theme/plan_theme.dart' show PlanTheme;`, `'../service_state.dart' show GroupUnit, UnitGroup, UnitGroupLookup, inLeadOrder;`, `'../../units/unit_index.dart' show UnitIndex, UnitIndexCache;`, `'../unit_picker.dart' show UnitCandidate, UnitPicker;`, `'unit_focus_painter.dart' show focusVeilColour, kUnitFocusVeilAlpha;`, `'unit_status_painter.dart' show kStatusCaptionSize, paintedTextStyle, statusCaptionInk;`.
     - `TableGroupLayer` → `UnitGroupLayer`; `groupLabel(UnitGroup group, Iterable<GroupUnit> members)`, `t.number!` → `t.label!` (two places).
     - The class: `TableGroupPainter` → `UnitGroupPainter`; the field and parameter `picker` (`:237`, `:251-253`) → `/// The session's units: the candidates (Z0) and their boxes. final UnitIndexCache units;` (as Task 16's view calls it), plus `final Map<Handle, Aabb2> _boxes = {};` (the definitions' boxes for the painter's life, as the focus painter's); `tableFocus` → `unitFocus`; `theme` a `ValueListenable<PlanTheme?>?`; `kTableFocusVeilAlpha` → `kUnitFocusVeilAlpha`. `int? _state; int? _tablesRevision;` (`:286-287`) → `UnitIndex? _indexBuilt;`.
     - `_rebuild` (`:353-386`): `final candidates = picker.candidates;` → `final candidates = UnitPicker.candidatesOf(document, units.current, boxes: _boxes, leaves: document.leavesByOwner);`; `final byHandle = {for (final c in candidates) c.unit.instance: c};`; the lookup's units `GroupUnit(handle: c.unit.instance, label: c.unit.text, visible: true, locked: c.unit.locked)`; the member loop's `final node = document.tree[m.handle]; if (node is! InstanceNode) continue; final t = node.transform; final b = byHandle[m.handle]!.box;` → `final c = byHandle[m.handle]!; final t = c.transform; final b = c.box;` (`c.transform` is the unit's world transform); `TablePicker.tolerance` → `UnitPicker.tolerance`; the focus test `focus.contains(m.number)` → `focus.contains(m.label)`.
     - `paint` (`:458-479`): `final index = units.current;` replaces the state id and revision reads, the key `!identical(_indexBuilt, index)` replaces their two comparisons, storing `_indexBuilt = index`; `tableFocus` → `unitFocus`.
     - `shouldRepaint`: `!identical(oldDelegate.picker, picker)` → `!identical(oldDelegate.units, units)`; `tableFocus` → `unitFocus`.
     - Doc words renamed as in 1.

- [ ] **Step 5: The service paint harness.** Create `test/support/service_paint.dart` (test support: Task 16's `PlanServiceView` mounts the same painters in `lib`, its Step A9):

```dart
// The service canvas's painted layers over one session, for the painter
// and invariant tests (2b Task 15): today's mounting in jet_cad_floor_plan's
// ServiceView (host/service_view.dart:282-351, :558-599), which Task 16's
// PlanServiceView repeats. The underlay is the group frames, then the unit
// colours and statuses (under the drafting); the overlay is the focus veil,
// then the group chips (above the drafting, under the selection outlines).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:jet_cad_2d_plan/src/service/paint/unit_focus_painter.dart';
import 'package:jet_cad_2d_plan/src/service/paint/unit_group_painter.dart';
import 'package:jet_cad_2d_plan/src/service/paint/unit_status_painter.dart';
import 'package:jet_cad_2d_plan/src/service/service_session.dart';
import 'package:jet_cad_2d_plan/src/theme/plan_theme.dart' show PlanTheme;

/// The four painters of one service session and what they repaint on.
final class ServicePaintLayers {
  ServicePaintLayers(
      {required PlanController controller,
      required ServiceSession session,
      required bool Function() darkCanvas})
      : _c = controller,
        _session = session,
        _darkCanvas = darkCanvas {
    _changes = session.document.changes.listen((_) => _changed.bump());
  }

  final PlanController _c;
  final ServiceSession _session;
  final bool Function() _darkCanvas;

  /// The paper under the statuses, ARGB (dark theme spec D6c): the view
  /// sets it where today's did (`service_view.dart:429-451`).
  final ValueNotifier<int> paper = ValueNotifier<int>(0xFFFFFFFF);

  /// The resolved look: the view sets it from `PlanTheme.of` in
  /// `didChangeDependencies`.
  final ValueNotifier<PlanTheme?> theme = ValueNotifier<PlanTheme?>(null);

  final _Bump _changed = _Bump();
  StreamSubscription<DocChange>? _changes;

  /// The unit colours and statuses (today's TableStatusPainter mount).
  late final UnitStatusPainter statuses = UnitStatusPainter(
    document: _session.document,
    units: _session.units,
    camera: _c.camera,
    statuses: _c.unitStatuses,
    unitGroups: _c.unitGroups,
    groupStatuses: _c.groupStatuses,
    paper: paper,
    theme: theme,
    darkCanvas: _darkCanvas,
    repaint: Listenable.merge([
      _c.camera,
      _c.unitStatuses,
      _c.unitGroups,
      _c.groupStatuses,
      _changed,
      paper,
      theme
    ]),
  );

  late final Listenable _groupRepaint = Listenable.merge(
      [_c.camera, _c.unitGroups, _c.unitFocus, _changed, paper, theme]);

  /// The group frames, under the status fills.
  late final UnitGroupPainter frames = _groupPainter(UnitGroupLayer.frames);

  /// The group label chips, above the drafting.
  late final UnitGroupPainter chips = _groupPainter(UnitGroupLayer.chips);

  UnitGroupPainter _groupPainter(UnitGroupLayer layer) => UnitGroupPainter(
        layer: layer,
        document: _session.document,
        units: _session.units,
        camera: _c.camera,
        groups: _c.unitGroups,
        paper: paper,
        unitFocus: _c.unitFocus,
        theme: theme,
        repaint: _groupRepaint,
      );

  /// The veil over the units outside the host's focus.
  late final UnitFocusPainter focus = UnitFocusPainter(
    document: _session.document,
    units: _session.units,
    camera: _c.camera,
    focus: _c.unitFocus,
    paper: paper,
    theme: theme,
    repaint: Listenable.merge(
        [_c.camera, _c.unitFocus, _changed, paper, theme]),
  );

  static Widget _layer(String key, CustomPainter painter) => RepaintBoundary(
        child: CustomPaint(
            key: Key(key), painter: painter, size: Size.infinite),
      );

  /// The frames under the status fills (G3), for `PlanCanvasView.underlay`.
  Widget get underlay => Stack(fit: StackFit.expand, children: [
        _layer('unit-group-layer', frames),
        _layer('unit-status-layer', statuses),
      ]);

  /// The focus's veil (Z13), then the label chips (G3, F-11), for
  /// `PlanCanvasView.overlay`.
  Widget get overlay => Stack(fit: StackFit.expand, children: [
        _layer('unit-focus-layer', focus),
        _layer('unit-group-chips', chips),
      ]);

  void dispose() {
    _changes?.cancel();
    _changed.dispose();
    paper.dispose();
    theme.dispose();
  }
}

/// A notifier whose every [bump] is one notification.
final class _Bump extends ChangeNotifier {
  void bump() => notifyListeners();
}
```

- [ ] **Step 6: The design canvas's colours.**
  1. `lib/src/canvas/plan_canvas_view.dart`: the field and parameter `tableOverlays` (`:47`, `:136-140`, `:454`) → `unitOverlays`; its doc's "the host's widgets on the tables" → "the host's widgets on the units (`PlanServiceView.unitOverlayBuilder`, Task 16)"; the `underlay` doc (`:127-129`) → "Painted between the page chrome and the drafting: the unit colours in design, the group frames and the statuses in service (2b S4)"; the `overlay` doc (`:131-134`) → "Painted above the drafting and below the selection overlay: the focus veil and the group chips in service (2b S4)".
  2. `lib/src/controller/plan_controller.dart` (no earlier task exposes the design session's cache: Task 6's `unitIndex` reads the active document's since Task 11, and its cache is private), add

```dart
  /// The design session's unit index cache (Task 6): the design canvas's
  /// colours read it, whatever the mode.
  @internal
  UnitIndexCache get documentUnits => _session.units;
```

     where `_session.units` is the name Task 6 gave `DocumentSession`'s cache.
  3. `lib/src/canvas/plan_canvas.dart` (today's design mount, `floor_plan/lib/src/planner_shell.dart:356-381`, `:745-766`, `:1518-1524`): the header gains `// 2b: the unit colours under the drafting (plan colours spec PC-5).`; imports `dart:async` (kept), `'../service/paint/unit_status_painter.dart' show UnitStatusPainter;`, `'../service/service_state.dart' show UnitGroup, UnitStatus;`. State fields after `_hintTimer`:

```dart
  /// Plan colours spec PC-5 (planner_shell.dart:745-766): the unit colour
  /// fills, under the drafting, in design: no status and no group; they
  /// repaint on the camera, every document change, the paper and the
  /// theme. Built per document in [_bind].
  final ValueNotifier<int> _fillPaper = ValueNotifier<int>(0xFFFFFFFF);
  final ValueNotifier<PlanTheme?> _fillTheme = ValueNotifier<PlanTheme?>(null);
  final _Bump _documentChanged = _Bump();
  StreamSubscription<DocChange>? _documentChanges;
  late UnitStatusPainter _colourPainter;

  static final ValueNotifier<Map<String, UnitStatus>> _noStatuses =
      ValueNotifier(const <String, UnitStatus>{});
  static final ValueNotifier<Map<String, UnitGroup>> _noGroups =
      ValueNotifier(const <String, UnitGroup>{});
```

     `_bind()` becomes:

```dart
  /// Binds the page listener, the document's change bump and the colour
  /// painter to the controller's current document.
  void _bind() {
    final document = _document = _c.document;
    _page = _c.page..addListener(_onPage);
    _documentChanges?.cancel();
    _documentChanges =
        document.changes.listen((_) => _documentChanged.bump());
    _colourPainter = UnitStatusPainter(
      document: document,
      units: _c.documentUnits,
      camera: _c.camera,
      statuses: _noStatuses,
      unitGroups: _noGroups,
      groupStatuses: _noStatuses,
      paper: _fillPaper,
      theme: _fillTheme,
      darkCanvas: () => _darkCanvas,
      repaint: Listenable.merge(
          [_c.camera, _documentChanged, _fillPaper, _fillTheme]),
    );
  }
```

     `_onPage()` gains `_fillPaper.value = _paperArgb();` as its first statement (planner_shell.dart:356-359: a page change that keeps the resolver's key still changes the paper). `didChangeDependencies()` gains, after its resolver line, `_fillTheme.value = _theme; _fillPaper.value = _paperArgb();` (planner_shell.dart:380-381). `dispose()` gains `_documentChanges?.cancel(); _documentChanged.dispose(); _fillPaper.dispose(); _fillTheme.dispose();` before `super.dispose()`. In `build`, `PlanCanvasView(…)` gains, after `sheetArgb:`,

```dart
            // Plan colours spec PC-5: the unit colours, under the drafting
            // and the selection.
            underlay: RepaintBoundary(
              child: CustomPaint(
                key: const Key('unit-colour-layer'),
                painter: _colourPainter,
                size: Size.infinite,
              ),
            ),
```

     and at the end of the file:

```dart
/// A notifier whose every [bump] is one notification.
final class _Bump extends ChangeNotifier {
  void bump() => notifyListeners();
}
```

- [ ] **Step 7: The export fills and the opacity.**
  1. Create `lib/src/export/unit_colour_underlay.dart` (port of `floor_plan/lib/src/colors/table_color_underlay.dart:1-75`):

```dart
// A page export's underlay of the plan's coloured units (plan colours spec
// PC-7; 2b spec S4 "Painting"): each unit's colour as a fill of its top
// under the drawing, in the export and in the print. The paper is white,
// so no tone is applied. Ported from jet_cad_floor_plan/lib/src/colors/
// table_color_underlay.dart over units, placed and generated.
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show PageUnderlayCircle, PageUnderlayFill, PageUnderlayPolygon;
import 'package:meta/meta.dart' show internal;

import '../service/unit_picker.dart' show CircleTop, PolygonTop, unitTopOf;
import '../units/unit_components.dart' show UnitColour;
import '../units/unit_index.dart' show UnitIndex;
import '../theme/plan_theme.dart' show kUnitColourOpacity;

/// The underlay of [document]'s coloured units, as [index] reads them:
/// every unit on a visible layer whose colour this release knows, not of
/// an object in [omitted] (a type with `exported: false`), its top in its
/// definition's space (a polygon closed and triangulated, skipped when it
/// does not triangulate; or a circle), placed by the unit's world
/// transform (a seat's: its row's group × its instance), its hue at alpha
/// `round(255 * opacity)`. Ascending by instance handle. White paper: no
/// tone.
///
/// A unit with no top, a colour of an unknown name and a unit on a hidden
/// layer have no fill, as on the canvas. A self-intersecting polygon top
/// is skipped here while the canvas fills it (today's known difference).
///
/// Throws an [ArgumentError] when [opacity] is not finite or lies outside
/// `[0, 1]`.
@internal
List<PageUnderlayFill> unitColourUnderlay(
    UnitIndex index, DraftDocument document, double opacity,
    {Set<Handle> omitted = const {}}) {
  if (!opacity.isFinite || opacity < 0 || opacity > 1) {
    throw ArgumentError.value(opacity, 'opacity', 'must be in [0, 1]');
  }
  final alpha = (255 * opacity).round();
  final out = <PageUnderlayFill>[];
  for (final u in index.units) {
    final colour = document.components.get<UnitColour>(u.instance)?.swatch;
    if (colour == null || !u.visible) continue;
    if (u.owner case final owner? when omitted.contains(owner)) continue;
    final argb = (alpha << 24) | colour.rgb;
    switch (unitTopOf(document, u.definition)) {
      case PolygonTop(:final xy):
        final n = xy.length ~/ 2;
        final closed = Float64List(2 * (n + 1))
          ..setRange(0, 2 * n, xy)
          ..[2 * n] = xy[0]
          ..[2 * n + 1] = xy[1];
        final triangles = triangulateSimplePolygon(closed, n + 1);
        if (triangles.isEmpty) continue;
        out.add(PageUnderlayPolygon(
            placement: u.toWorld,
            argb: argb,
            xy: closed,
            count: n + 1,
            triangles: triangles));
      case CircleTop(:final cx, :final cy, :final r):
        out.add(PageUnderlayCircle(
            placement: u.toWorld, argb: argb, cx: cx, cy: cy, r: r));
      case null:
        break;
    }
  }
  return out;
}

/// [given], or [kUnitColourOpacity] when null; an [ArgumentError] named
/// `unitColourOpacity` when it is not finite or lies outside `[0, 1]`
/// (today's `_checkedOpacity`, floor_plan_controller.dart:1374-1383).
@internal
double checkedUnitColourOpacity(double? given) {
  if (given == null) return kUnitColourOpacity;
  if (!given.isFinite || given < 0 || given > 1) {
    throw ArgumentError.value(given, 'unitColourOpacity', 'must be in [0, 1]');
  }
  return given;
}

/// The unit fills a request's built-in exporter draws, set by the flows
/// before they call it: an exporter is handed a codec copy and no catalog,
/// so the fills are made from the live document's unit index.
@internal
final Expando<List<PageUnderlayFill>> unitFillsOf =
    Expando<List<PageUnderlayFill>>('unit fills');
```

  2. `lib/src/export/registries.dart`, `PlanExportRequest` (`:120-146`): the constructor gains `this.unitColourOpacity = kUnitColourOpacity,` after `required this.fonts,`, and the class gains

```dart
  /// The alpha the units' colours are filled at under the drawing (2b spec
  /// S4): the exporting editor's theme, or the host's argument, or 0.35.
  final double unitColourOpacity;
```

     (import `'../theme/plan_theme.dart' show kUnitColourOpacity`, Step 3).
  3. `lib/src/export/builtin_exporters.dart`: the header's "without the table colours (2b): an empty underlay writes today's bytes" → "with the unit colours the flows made (2b; `unitFillsOf`): no fill writes today's bytes"; `PlanPdfExporter.export` and `PlanPngExporter.export` each pass `underlay: unitFillsOf[request] ?? const [],` to `exportPagePdf` / `exportPagePng` (import `unit_colour_underlay.dart show unitFillsOf`).
  4. `lib/src/export/page_flows.dart`:
     - the constructor gains `UnitIndex Function()? units,` (the field `final UnitIndex Function()? _units;`, doc: "The live document's unit index, for the built-ins' fills; null makes none.");
     - `exportOnce` and `printOnce` each gain `double unitColourOpacity = kUnitColourOpacity`; `export` and `print` each gain `double unitColourOpacity = kUnitColourOpacity` (optional: 2a's tests call the flows without it) and pass it on;
     - in `exportOnce`, between `final copy = _copyOf(live);` and the `try`, and in `printOnce` the same, the request is built first:

```dart
    final omitted = omittedOf(copy.document);
    final request = PlanExportRequest(
        document: copy.document,
        page: exportPageOf(copy.document),
        choice: choice,
        omitted: omitted,
        fonts: fonts,
        unitColourOpacity: unitColourOpacity);
    final units = _units;
    unitFillsOf[request] = units == null
        ? const []
        : unitColourUnderlay(units(), live, unitColourOpacity,
            omitted: omitted);
```

       and the `try` hands `request` to `exporter.export(request)` (`const PlanPdfExporter().export(request)` in `printOnce`).
  5. `lib/src/export/editor_page_flows.dart`: `EditorPageFlows` gains `this.unitColourOpacity = _defaultOpacity` (`static double _defaultOpacity() => kUnitColourOpacity;`), the field `final double Function() unitColourOpacity;` (doc: "The opacity the units' colours are filled at: the view's theme as it is at the call, else 0.35 (floor_plan/lib/src/host/page_flows.dart:153-158)."); its `exportOnce` and `printOnce` calls pass `unitColourOpacity: unitColourOpacity()`.
  6. `lib/src/editor/plan_editor.dart`: `_flowsFor` passes `unitColourOpacity: _unitColourOpacity`, with

```dart
  /// The opacity an export or a print fills the units' colours at: the
  /// ambient extension with the editor's `theme` over it, else the
  /// editor's, else 0.35 (floor_plan_view.dart:540-546). A state gone
  /// meanwhile reads its own theme.
  double _unitColourOpacity() {
    final theme = mounted
        ? (Theme.of(context).extension<PlanTheme>()?.merge(widget.theme) ??
            widget.theme)
        : widget.theme;
    return theme?.unitColourOpacity ?? kUnitColourOpacity;
  }
```

  7. `lib/src/controller/plan_controller.dart`: `PlanPageFlows(…)` gains `units: () => unitIndex,` (Task 9's active index; the flows' `document` is the active document since Task 11); `export` and `print` become

```dart
  Future<PlanExport?> export(String exporterId, PlanExportChoice choice,
      {String? name, double? unitColourOpacity}) {
    final opacity = checkedUnitColourOpacity(unitColourOpacity);
    return pageFlows.export(exporterId, choice,
        name: name ?? 'plan', unitColourOpacity: opacity);
  }

  Future<bool> print(PlanExportChoice choice,
      {PagePrinter? printer, String? name, double? unitColourOpacity}) {
    final opacity = checkedUnitColourOpacity(unitColourOpacity);
    return pageFlows.print(choice,
        printer: printer ?? const PrintingPagePrinter(),
        name: name ?? 'plan',
        unitColourOpacity: opacity);
  }
```

     each doc gaining "The coloured units are filled under the drawing at [unitColourOpacity] when given, else at 0.35: with no view there is no theme to read. A given opacity not finite or outside `[0, 1]` throws an [ArgumentError] at once, before any flow runs."
  8. Check that the export copy registers the unit components: `PlanPageFlows._copyOf` (`page_flows.dart:140-158`) must call `registerUnitComponents(r)` beside `registerKitComponents(r)` (Task 6 registers them "wherever 2a registers kit components"); add it if it is missing, and report.

- [ ] **Step 8: Run them, expecting pass.** After Steps 3-7: `cd packages/jet_cad_2d_plan && flutter test test/service/paint/unit_paint_test.dart test/export/unit_colour_opacity_test.dart`. Expected: `All tests passed!` (7 tests).

- [ ] **Step 9: The allocation invariant's scenes.** In `test/invariants/canvas_paint_allocation_test.dart` add (imports: `package:jet_cad_2d_kit/jet_cad_2d_kit.dart show PlanSwatch`, `package:jet_cad_2d_plan/src/controller/plan_controller.dart`, `package:jet_cad_2d_plan/src/service/service_session.dart show PlanMode`, `package:jet_cad_2d_plan/src/service/paint/unit_status_painter.dart`, `package:jet_cad_2d_plan/src/service/service_state.dart show UnitGroup, UnitStatus`, `'../support/service_fixture.dart'`, `'../support/service_paint.dart'`, `'../support/test_kit.dart' show unitKit`):

```dart
  testWidgets(
      'CV-alloc-colour the design canvas\'s unit colours: ten rebuilt '
      'frames, the camera moving, keep the painter and build and rebuild '
      'nothing (M-CV-colour-a, M-CV-colour-b)', (tester) async {
    final f = serviceFixture();
    final c = PlanController(kits: [unitKit()], json: f.json);
    addTearDown(c.dispose);
    final table = c.unitIndex[f.table]!.text!;
    expect(c.setUnitColour(table, PlanSwatch.teal), isTrue);
    expect(c.setUnitColour('A1', PlanSwatch.purple), isTrue);
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: PlanCanvas(controller: c))));
    await tester.pump();
    await tester.pump();
    UnitStatusPainter painter() => tester
        .widget<CustomPaint>(find.byKey(const Key('unit-colour-layer')))
        .painter! as UnitStatusPainter;
    final p = painter();
    final made = p.debugAllocations;
    final rebuilds = p.debugRebuilds;
    expect(made, greaterThanOrEqualTo(3),
        reason: 'premise: two paths and a paint at least');
    final size = tester.getSize(find.byType(InteractionLayer));
    final a = ViewportTransform.fit(c.document.extents, size);
    for (var i = 0; i < 10; i++) {
      c.camera.value = ViewportTransform(
          worldToScreenMatrix: Transform2.translation(1.0 + i, -1.0 - i)
              .multiply(a.worldToScreenMatrix));
      tester.element(find.byType(PlanCanvas)).markNeedsBuild();
      await tester.pump();
    }
    expect(identical(painter(), p), isTrue, reason: 'the painter is kept');
    expect(p.debugAllocations, made, reason: 'nothing per frame');
    expect(p.debugRebuilds, rebuilds, reason: 'no rebuild per frame');
  });

  testWidgets(
      'CV-alloc-service the service scene: statuses, a group, a group '
      'status and a focus over the table and the seats; ten frames, the '
      'camera moving, build and rebuild nothing in any painter '
      '(M-CV-service)', (tester) async {
    final f = serviceFixture();
    final c = PlanController(kits: [unitKit()], json: f.json);
    addTearDown(c.dispose);
    final table = c.unitIndex[f.table]!.text!;
    c.setMode(PlanMode.service);
    c.setUnitStatus({
      table: UnitStatus(color: const Color(0xFFE53935), caption: 'Bill'),
      'A1': UnitStatus(color: const Color(0xFF43A047)),
    });
    c.setUnitGroups({
      'g': UnitGroup(members: {'A2', 'A3'})
    });
    c.setGroupStatus({'g': UnitStatus(color: const Color(0xFF3949AB))});
    c.setUnitFocus({'A1', 'B1'});
    final layers = ServicePaintLayers(
        controller: c, session: c.serviceSession!, darkCanvas: () => false);
    addTearDown(layers.dispose);
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(fit: StackFit.expand, children: [
          Positioned.fill(child: layers.underlay),
          Positioned.fill(child: layers.overlay),
        ])));
    final base = ViewportTransform.fit(
        c.serviceSession!.document.extents, const Size(1440, 900));
    Future<void> frames(int n) async {
      for (var i = 0; i < n; i++) {
        c.camera.value = ViewportTransform(
            worldToScreenMatrix: Transform2.translation(1.0 + i, -1.0 - i)
                .multiply(base.worldToScreenMatrix));
        await tester.pump();
      }
    }

    await frames(3);
    List<int> made() => [
          layers.statuses.debugAllocations,
          layers.frames.debugAllocations,
          layers.chips.debugAllocations,
          layers.focus.debugAllocations,
        ];
    List<int> rebuilt() => [
          layers.statuses.debugRebuilds,
          layers.frames.debugRebuilds,
          layers.chips.debugRebuilds,
          layers.focus.debugRebuilds,
        ];
    final made0 = made(), rebuilt0 = rebuilt();
    expect(layers.statuses.debugAllocations, greaterThan(0),
        reason: 'premise: the fills built');
    // Each group painter counts its two paints and its matrix at birth.
    expect(layers.frames.debugAllocations, greaterThan(3),
        reason: 'premise: the frame built');
    expect(layers.chips.debugAllocations, greaterThan(3),
        reason: 'premise: the chip built');
    expect(layers.focus.debugAllocations, greaterThan(2),
        reason: 'premise: the veil built');
    await frames(10);
    expect(made(), made0, reason: 'nothing per frame');
    expect(rebuilt(), rebuilt0, reason: 'no rebuild per frame');
  });
```

- [ ] **Step 10: Port the painter, fill, export and theme tests.** Assertions unchanged in every ported test; only fixtures, names and imports change, as listed. Each file starts with `// Ported from jet_cad_floor_plan/test/<path>; assertions unchanged.` None of them was ported by 2a (2a results note, "Ported tests": 2a ported `floor_plan_theme_test.dart`'s four generic fields only, as `test/theme/plan_theme_test.dart` and `test/editor/editor_theme_test.dart`). Common adaptations:
  - names: `TableStatus` → `UnitStatus`, `TableGroup` → `UnitGroup`, `validateTableGroups` → `validateUnitGroups`, `GroupTable` → `GroupUnit` (`number:` → `label:`), `TableStatusPainter` → `UnitStatusPainter` (`tableGroups:` → `unitGroups:`, and `units: unitsOf(doc)` after `document:`), `TableGroupPainter` → `UnitGroupPainter` (`picker: TablePicker(doc)` → `units: unitsOf(doc)`, `tableFocus:` → `unitFocus:`), `TableGroupLayer` → `UnitGroupLayer`, `TableFocusPainter` → `UnitFocusPainter` (and `units: unitsOf(doc)`), `TablePicker.tolerance` → `UnitPicker.tolerance`, `kTableFocusVeilAlpha` → `kUnitFocusVeilAlpha`, `FloorPlanTheme` → `PlanTheme`, `tableColorOpacity` → `unitColourOpacity`, `kTableColorOpacity` → `kUnitColourOpacity`, `kTableLabelTag` → `kUnitLabelTag`, `FloorPlanColor.<hue>` → `PlanSwatch.<hue>`, `FloorPlanTableColor(c)` → `UnitColour(PlanSwatch.<hue>)` (Task 6's), `floorPlanColorNamed` → `planSwatchNamed`;
  - the survey: `TableSurvey.of(doc)` → `unitsOf(doc).current` (one cache per document, kept in a variable where a test re-surveys), `.withNumber(n)` → `.withLabel(n)`, `.tables` → `.units`, `t.number` → `t.text`;
  - the fixtures: `../../support/unit_fixtures.dart` (Task 8's, with Task 14's `numberedRowOfTables` and `copyForService`): `plan()` → `unitPlan()`; `placeSymbol(doc, entryOf(s), at: a, quarterTurns: q, mirrored: m)` → `placeAt(doc, s, a, quarterTurns: q, mirrored: m)` **followed by** `addUnitLabel(doc, h, '<n>')`, `<n>` today's placer's number (1, 2, … in placement order; a planter none); `rowOfTables(n)` → `numberedRowOfTables(n)`; the embedding fixture is Task 9's `../../support/unit_embedding_fixture.dart`; the zone fixture is `../../support/unit_zone_fixture.dart` (below); the palette helpers (`Shot`, `shoot`, `pixelOf`, `channelDistance`, `hex`, `lightTheme`, `darkTheme`, `shotKey`, `windowAt`) are 2a's `../../support/canvas_fixture.dart`;
  - a plan text that a controller loads is written by `encodePlan(doc, validateKitSet([fxKit()]))` (2a's) and loaded with `PlanController(kits: [fxKit()], json: …)`, so the fixture kit's symbols are never locked; `registerAppComponents` → `(r) => registerPlanComponents(r, ParametricCatalog())`.
  - **`test/support/unit_zone_fixture.dart`** (no other task ports `floor_plan/test/host/zone_fixture.dart`: Task 12 replaced `zonePlanJson` by its own `servicePlanText`): the port of `zone_fixture.dart:1-322` over `fxKit()`, with the adaptations above. `zoneSymbolBoxes` keyed by the fixture kit's keys; `placeZoneTable` places with `placeUnit(doc, s, transform: …, layer: layer)` and labels with `addUnitLabel` (an unlabelled table when `label` is null); `zonePlanJson` (`:82-120`) starts from `unitPlan()` in place of the walled room (`:83-89`, the room named `7`: sub-project 3, as 2a's room rows) and keeps the TEXT `7` (`:105-115`, its record and payload through Task 3's `kUnitLabelTextAttrs` and `unitLabelPayload`, `tag: ''`, kind `text`), returned through `encodePlan(doc, validateKitSet([fxKit()]))`; `quadsOf(DraftDocument doc, bool Function(UnitInfo u) which)`; `quadsNumbered` reads labels. `addZoneLayer` is the fixture's `addLayer` under its old name.
  1. **`test/service/paint/unit_status_painter_test.dart`** from `floor_plan/test/service/table_status_painter_test.dart`: SP1 … SP12. `SpyCanvas` and `cameraOn` stay in this file; `cameraOn` reads `unitsOf(doc).current.withLabel('1')`; `painterFor` (`:87-101`) builds `UnitStatusPainter(document: doc, units: unitsOf(doc), camera: camera, statuses: statuses, unitGroups: ValueNotifier(const {}), groupStatuses: ValueNotifier(const {}), paper: p, repaint: …)`. SP4 relabels with `SetEntityTextCommand(label, '<n>', kUnitLabelTag)`. The symbols `FurnitureSymbol`/`PolylineShape` used locally (SP2's asymmetric top) become `CatalogSymbol`s keyed under `fx`.
  2. **`test/service/paint/unit_group_painter_test.dart`** from `table_group_painter_test.dart`: every test (TG-L1 … TG-L11, TG-Z1, TG-Z2, RX1 and the lead-order premise). `openTable()` (`:91-106`) is the fixture's `openTable` (Task 8: an open first leaf, placed through a hand-built entry); `skewTable` (`:108-124`) a `CatalogSymbol` keyed `fx.skew.three`; `addLayer` (`:126-…`) the fixture's; `GroupSpy` stays; `rgbDistance` and `veilOver` from `unit_zone_fixture.dart`; `SpyCanvas` from `unit_status_painter_test.dart`.
  3. **`test/service/paint/unit_focus_painter_test.dart`** from `table_focus_painter_test.dart`: FP1 … FP7, FX1. `zoneDoc()` (`:39-40`) → `PlanController(kits: [fxKit()], json: zonePlanJson())`'s document decoded the same way: `DraftDocumentCodec.decodeString(zonePlanJson(), registerComponents: (r) => registerPlanComponents(r, ParametricCatalog()))`; `addCluster` (`:43-47`) through `placeZoneTable`; `painterOn` builds `UnitFocusPainter(document: doc, units: unitsOf(doc), …)`; `rowOfTables` → `numberedRowOfTables`.
  4. **`test/service/paint/unit_theme_painter_test.dart`** from `table_theme_painter_test.dart`: every test (invariant 7 with a theme, the status, groups and veil groups). `fullTheme` (`:3-…`) as a `PlanTheme`; `themedStatus`, `themedGroups` (its `TablePicker? picker` parameter → `UnitIndexCache? units`, default `unitsOf(doc)`), the focus builder take `units:` and the renames; `quadsNumbered`, `quadsOf`, `TestQuad` from `unit_zone_fixture.dart`.
  5. **`test/service/paint/unit_fill_test.dart`** from `table_fill_test.dart`: the fixture test, TF1 (its `R` and tint lines to sub-project 3, plan decision), TF2, TF3, TF4, TF5, TF7 up to and excluding the selection-mode tail (`:735-755`, to Task 16 as TF7b) and with its room-tint lines to sub-project 3, TF8, TF8b, TF9, TF10. Not here: TF6 (Task 16). Adaptations:
     - the fixture (`:63-438`): `roundTable` (`:65-…`) a `CatalogSymbol` keyed `fx.round.off` (its circle off the definition's origin, as today), the embedding top Task 8's `embeddingTable` (`unit_editor_fixture.dart`); the four walls and the room (`:211-256`) and spec `R` dropped (sub-project 3); `fillDoc` builds on `unitPlan()`, places each spec with `placeUnit(doc, s, transform: placementOf(spec), layer: …)`, labels it with `addUnitLabel` (U unlabelled) and colours it with `SetComponentCommand<UnitColour>(instance, UnitColour(PlanSwatch.<hue>))` (M's unknown name `magenta` through `UnitColour.fromJson({'colour': 'magenta'})`, Task 6's lenient decode, whatever key its `toJson` writes); `fillJson` returns `encodePlan(fillDoc(…), validateKitSet([fxKit()]))`;
     - `controllerOver()` (`:453-457`) → `PlanController(kits: [fxKit()], json: fillJson())`, disposed at tear-down;
     - `pumpApp` (`:461-472`): `FloorPlanView(controller: c, theme: theme)` → `PlanEditor(controller: c, theme: theme)`; `pumpPlan` (`:475-484`): `c.cameraController.value` → `c.camera.value`;
     - `designPainter` (`:503-505`): the key `table-colour-layer` → `unit-colour-layer`, the cast to `UnitStatusPainter`;
     - `painterOver` builds the status painter over `unitsOf(doc)`; `c.activeDocument` → `c.document`; `c.setTableColor('N', FloorPlanColor.teal)` → `c.setUnitColour('N', PlanSwatch.teal)`; `c.tableDetails` → `c.unitDetails`, `d.table.number` → `d.unit.label`, `.color` → `.colour`; `c.select({'C'})` stays, `c.selectedTables` → `c.editorSelectedUnits` (Task 9's design feed, today's `selectedTables` in design); the Delete key of TF8b reaches 2a's `PlanShortcuts` through `PlanEditor`.
  6. **`test/export/unit_colour_export_test.dart`** from `floor_plan/test/colors/table_color_export_test.dart`: the premises, EX1, EX2, EX3, EX3b, EX3c, EX4, EX5 (its room line to sub-project 3). Adaptations:
     - imports (`:20-60`): the fill test's names from `'../service/paint/unit_fill_test.dart'`; `FakePagePrinter` from 2a's `'../support/fake_page_printer.dart'`; `canvas_fixture.dart` for `channelDistance`, `hex`, `pixelOf`, `shoot`;
     - `tableColorUnderlay(doc, x)` → `unitColourUnderlay(unitsOf(doc).current, doc, x)`;
     - `exportBytes(doc, page, png96, fontBytes: …, tableColorOpacity: o)` (EX2) → a controller over `fillJson()`: `c.pageFlows.exportOnce('plan.png', const PlanExportChoice(dpi: PlanExportDpi.d96), 'plan', unitColourOpacity: o)`'s bytes; the PDF branch (EX3c) → `'plan.pdf'` the same way;
     - `c.exportPlan(apiPng96, tableColorOpacity: o)` → `c.export('plan.png', const PlanExportChoice(dpi: PlanExportDpi.d96), unitColourOpacity: o)`; `c.printPlan(printer: p, tableColorOpacity: o)` → `c.print(PlanExportChoice.initial, printer: p, unitColourOpacity: o)`; `c.pageFlowReady` → `c.pageFlows.ready`;
     - EX4 (`:356-476`): `FloorPlanView(controller: c, theme: theme, onExport: got.add, printer: printer, onExportDialog: dialog)` → `PlanEditor(controller: c, theme: theme, onExport: got.add, printer: printer, onExportDialog: dialog)`, the dialog answering `const PlanExportAnswer(exporter: 'plan.png', choice: PlanExportChoice(dpi: PlanExportDpi.d96))` (2a's `PlanExportDialog` signature); `FloorPlanExport` → `PlanExport`.
  7. **`test/theme/plan_theme_test.dart`** (2a's port of `floor_plan/test/host/floor_plan_theme_test.dart`): `fullA`, `fullB` and `fields` become the source's seventeen-field versions (`floor_plan_theme_test.dart:29-…`, its field table), renamed (`tableColorOpacity` → `unitColourOpacity`); TH0 takes back the source's "the field table names the seventeen fields of a full theme" (`:335-344`). Added, from the source: T1-a (`:374-400`), R-3 (`:486-505`), the insets' lerp within "two full themes …" (`:402-419`, each field its type's lerp), "each field changed alone" (`:534-557`) and `toString` (`:558-572`) over the seventeen, and the validation of the thirteen fields through the scope, as 2a's TH11 does for the width (`:574-672`: the opacities, the frame width, the bar, the margin, the radius, the padding and the font sizes, each refused naming its field). Not here: the selection-mode resolution and the `ServiceView` tests (Task 16).

- [ ] **Step 11: Run the ported tests.** Run, one by one:
  - `cd packages/jet_cad_2d_plan && flutter test test/service/paint`. Expected: `All tests passed!`.
  - `cd packages/jet_cad_2d_plan && flutter test test/export test/theme test/canvas test/editor test/invariants/canvas_paint_allocation_test.dart`. Expected: `All tests passed!` (2a's canvas and editor tests stay green with the colour layer and the renamed slot).

  A ported test that fails on an assertion is a finding (Global Constraints): stop and report it with the failing line; never change the assertion.

- [ ] **Step 12: Format and the gate.** `cd packages/jet_cad_2d_plan && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — each exits 0. `git status --short` lists only this task's files.

- [ ] **Step 13: Commit.**

```bash
git add packages/jet_cad_2d_plan/lib/src/theme/plan_theme.dart packages/jet_cad_2d_plan/lib/src/service/paint/unit_status_painter.dart packages/jet_cad_2d_plan/lib/src/service/paint/unit_group_painter.dart packages/jet_cad_2d_plan/lib/src/service/paint/unit_focus_painter.dart packages/jet_cad_2d_plan/lib/src/export/unit_colour_underlay.dart packages/jet_cad_2d_plan/lib/src/export/registries.dart packages/jet_cad_2d_plan/lib/src/export/builtin_exporters.dart packages/jet_cad_2d_plan/lib/src/export/page_flows.dart packages/jet_cad_2d_plan/lib/src/export/editor_page_flows.dart packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart packages/jet_cad_2d_plan/lib/src/canvas/plan_canvas.dart packages/jet_cad_2d_plan/lib/src/canvas/plan_canvas_view.dart packages/jet_cad_2d_plan/lib/src/editor/plan_editor.dart packages/jet_cad_2d_plan/test/service/paint/unit_paint_test.dart packages/jet_cad_2d_plan/test/service/paint/unit_status_painter_test.dart packages/jet_cad_2d_plan/test/service/paint/unit_group_painter_test.dart packages/jet_cad_2d_plan/test/service/paint/unit_focus_painter_test.dart packages/jet_cad_2d_plan/test/service/paint/unit_theme_painter_test.dart packages/jet_cad_2d_plan/test/service/paint/unit_fill_test.dart packages/jet_cad_2d_plan/test/export/unit_colour_opacity_test.dart packages/jet_cad_2d_plan/test/export/unit_colour_export_test.dart packages/jet_cad_2d_plan/test/theme/plan_theme_test.dart packages/jet_cad_2d_plan/test/invariants/canvas_paint_allocation_test.dart packages/jet_cad_2d_plan/test/support/service_paint.dart packages/jet_cad_2d_plan/test/support/unit_zone_fixture.dart
```

  Then:

```bash
git commit -m "$(cat <<'EOF'
feat(plan): unit painting, the service theme and export fills (2b S4)

The status, group and focus painters ported over units, placed and
generated: a seat fills at its row's group times its instance, a
locked unit is painted, a shared label paints on each unit. The
design canvas fills unit colours; PlanTheme gains today's thirteen
service and colour fields; export and print take unitColourOpacity,
every exporter receives it, and the built-in PDF and PNG fill the
colours. The paint invariant gains the design colours and the
service scene.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 14: Mutation check** (on the committed files; after each: run the named test, quote its red line, `git checkout -- <file>`, then `git diff --quiet -- <file>` exits 0):
  - M-SP-seat `lib/src/service/paint/unit_status_painter.dart`, in `paint`: `final t = f.toWorld;` → `final t = (document.tree[f.instance]! as InstanceNode).transform;` → SP-seat-fill red (the matrix lacks the row's group).
  - M-SP-frame `lib/src/service/paint/unit_group_painter.dart`, in `_rebuild`: `if (members.length < 2) continue;` → `if (members.length < 4) continue;` → SP-group-mixed red (no frame).
  - M-SP-locked `unit_status_painter.dart`, in `_rebuild`: after `if (!u.visible) continue;` insert `if (u.locked) continue;` → SP-locked-status red (no fill).
  - M-SP-dup `unit_status_painter.dart`, in `_rebuild`: `final status = label == null ? null : (groupStatus ?? map[label]);` → `final status = label == null || index.withLabel(label).first.instance != u.instance ? null : (groupStatus ?? map[label]);` → SP-dup-label red (one fill).
  - M-SP-export `lib/src/export/unit_colour_underlay.dart`: both `placement: u.toWorld,` → `placement: (document.tree[u.instance]! as InstanceNode).transform,` → SP-export-seat red.
  - M-SP-check `unit_colour_underlay.dart`, in `checkedUnitColourOpacity`: delete the `if (!given.isFinite …) throw …;` statement → SP-opacity-arg red.
  - M-SP-request `lib/src/export/page_flows.dart`, in `exportOnce`: `unitColourOpacity: unitColourOpacity);` (the request's) → `unitColourOpacity: kUnitColourOpacity);` → SP-request red (0.35, not 0.6).
  - M-CV-colour-a `lib/src/canvas/plan_canvas.dart`, in `build`: `painter: _colourPainter,` → `painter: UnitStatusPainter(document: document, units: c.documentUnits, camera: c.camera, statuses: _noStatuses, unitGroups: _noGroups, groupStatuses: _noStatuses, paper: _fillPaper, theme: _fillTheme, repaint: c.camera),` (a painter per build) → CV-alloc-colour red ("the painter is kept").
  - M-CV-colour-b `unit_status_painter.dart`, in `paint`: `if (!identical(_indexBuilt, index) ||` → `if (true ||` → CV-alloc-colour red ("no rebuild per frame").
  - M-CV-service `unit_group_painter.dart`, in `paint`: `!identical(_builtFor, map) ||` → `true ||` → CV-alloc-service red.
  - M-H31 (the ported themed allocation mutant) `lib/src/service/paint/unit_focus_painter.dart`, in `paint`: the recolour guard `if (_paperBuilt != paperArgb || !identical(_themeBuilt, look))` → `if (true)` → `unit_theme_painter_test.dart`'s "FP3 themed" red (`debugRecolours` moves per frame).
  - M-14c2-8 (SP1's) `unit_status_painter.dart`, in `paint`: `..drawPath(f.path, f.paint)` → `..drawPath(f.path, Paint()..color = f.paint.color)` → `unit_status_painter_test.dart`'s SP1 red (a frame passes a new Paint).
  - M-TH-merge `lib/src/theme/plan_theme.dart`, in `merge`: `unitColourOpacity: other.unitColourOpacity ?? unitColourOpacity,` → `unitColourOpacity: unitColourOpacity,` → `plan_theme_test.dart`'s merge case (a view setting one field over an ambient full theme) red.
  - M-TH-valid `plan_theme.dart`, in `validatePlanTheme`: delete `opacity(theme.unitColourOpacity, 'unitColourOpacity');` → `plan_theme_test.dart`'s validation case red.
  - M-C8 (the ported export mutant) `lib/src/export/builtin_exporters.dart`, `PlanPngExporter.export`: delete `underlay: unitFillsOf[request] ?? const [],` → `unit_colour_export_test.dart`'s EX2 red.
  - M-C23 `lib/src/editor/plan_editor.dart`: `unitColourOpacity: _unitColourOpacity,` deleted from `_flowsFor` → `unit_colour_export_test.dart`'s EX4 red (0.35 in place of the theme's 0.6).

#### Assumed from earlier tasks

Each name below is used as written; where the earlier task named it otherwise, the implementer uses that task's name and reports the difference.
- Task 5: `unitKit()`, `tableSymbolId` (`test/support/test_kit.dart`); `serviceFixture()` (`json`, `table`, `seatsA`, `seatsB`), `testEntry`, `unitLabelsOf`, `labelPlacedUnit` (`test/support/service_fixture.dart`).
- Task 6: `UnitInfo` (with `visible`, `label`, `owner`), `UnitIndex.units` / `withLabel`, `UnitIndexCache.current`; `UnitColour(PlanSwatch)`, `swatch`, and its lenient `fromJson` keeping an unknown name; `registerUnitComponents` (Task 6 already adds it to `PlanPageFlows._copyOf`; Step 7.8 only checks); `DocumentSession.units`.
- Task 8: `UnitPicker.candidatesOf`, `UnitCandidate`, `UnitPicker.tolerance`, `unitTopOf`, `PolygonTop`, `CircleTop`; the test support of "Consumes".
- Task 9: `PlanController.unitIndex` (`@internal`), `setUnitColour`, `setUnitLabel`, `unitDetails` (`PlanUnitDetail.unit.label`, `.colour`), `select`, `editorSelectedUnits`; `test/support/unit_embedding_fixture.dart`.
- Task 11: `PlanMode`, `setMode`, `serviceSession` (`document`, `units`); the page flows' `document` closure returns the active document.
- Task 12 (`lib/src/service/service_state.dart`): `UnitStatus({required Color color, String? caption})`, `UnitGroup({required Set<String> members, String? label})`, `validateUnitGroups`, `GroupUnit`, `groupIdsByLabel`, `inLeadOrder`, `UnitGroupLookup` (`visibleMembers`); on `PlanController`: `unitStatuses`, `setUnitStatus`, `unitGroups`, `setUnitGroups`, `groupStatuses`, `setGroupStatus`, `unitFocus`, `setUnitFocus`.
- Task 14: `numberedRowOfTables`, `copyForService` (`test/support/unit_fixtures.dart`), `parts` (`test/support/service_rig.dart`).
- 2a: `RecordingExporter` (`test/support/recording_exporters.dart`), `FakePagePrinter`, `PlanEditor(controller:, theme:, onExport:, printer:, onExportDialog:)`, `PlanExportAnswer`, `PlanExportDpi`, `encodePlan`, `validateKitSet`, `planText`, `registerPlanComponents`, `placeSymbol`.

#### Interface problem

None of this task's own. It answers Task 16's "Interface problem" 4 in its Produces: the three painters' constructors (today's, renamed, each with `units: UnitIndexCache`; `UnitGroupPainter` takes `units`, not a picker, as Task 16's view calls it) and `PlanPageFlows.exportOnce`/`printOnce({double unitColourOpacity})`. `PlanExportRequest` gains only `unitColourOpacity`, as the Shared interfaces name it; the built-ins' fills travel through the internal `unitFillsOf` expando, so no other member is added to that public class. The picker's members it reads are Task 8's (controller ruling R-12).

The scope gap (the view-level tests) is resolved by R-15: Task 16's Step B2b ports `host/theme_service_test.dart`, `host/status_caption_test.dart`, `host/table_groups_look_test.dart`, `table_fill_test.dart`'s TF6 and TF7b, and `host/floor_plan_theme_test.dart`'s selection-mode resolution and `ServiceView` tests.

---

