### Task 15: `PlanCanvas` and the plan library's paint-allocation invariant (spec P2 "The widgets", P4 "Where `PlanLocked` is caught"; CLAUDE.md)

**Files:**
- Create: `packages/jet_cad_2d_plan/lib/src/canvas/plan_canvas.dart` (new: `PlanCanvas`)
- Create: `packages/jet_cad_2d_plan/lib/src/canvas/plan_canvas_view.dart` (port of `planner_view.dart`)
- Create: `packages/jet_cad_2d_plan/lib/src/canvas/text_entry_overlay.dart` (port)
- Create: `packages/jet_cad_2d_plan/lib/src/shortcuts/chords.dart` (port of `shell_commands.dart:10-61`)
- Create: `packages/jet_cad_2d_plan/lib/src/shortcuts/plan_shortcut_guard.dart` (port of `shortcut_guard.dart`; `PlanShortcutGuard`, `PlanTextKeys`, `planLetterKeys`)
- Modify: `packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart` (`textTool`, Step 5)
- Reuse (no change): `packages/jet_cad_2d_plan/lib/src/controller/camera_bounds.dart` (Task 8's port, `clampCameraScale`, `kPlanMinScale`, `kPlanMaxScale`; controller ruling R-k)
- Modify: `packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart` (export `PlanCanvas`, `kLockHintDuration`)
- Test support: `packages/jet_cad_2d_plan/test/support/canvas_fixture.dart` (port of `palette_fixture.dart` and the drawing fixture of `planner_draw_test.dart`; Tasks 16 and 17 reuse it)
- Test (new): `packages/jet_cad_2d_plan/test/canvas/plan_canvas_test.dart` (CV-1 … CV-7), `packages/jet_cad_2d_plan/test/invariants/canvas_paint_allocation_test.dart` (CV-alloc)
- Test (ported): `packages/jet_cad_2d_plan/test/canvas/canvas_camera_test.dart` (CM5's second half, from Task 8), `packages/jet_cad_2d_plan/test/canvas/canvas_ui_test.dart`, `test/canvas/dark_canvas_test.dart`, `test/canvas/theme_canvas_test.dart`, `test/canvas/canvas_palette_test.dart`, `test/canvas/canvas_draw_test.dart`, `test/canvas/touch_tools_test.dart`, `test/canvas/canvas_layout_test.dart`

(All paths below are under `packages/jet_cad_2d_plan/` unless they start at the repository root. "`floor_plan/`" abbreviates `packages/jet_cad_floor_plan/`.)

**Interfaces:**
- Consumes:
  - The Flutter layer (`package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart`): `DraftCanvas`, `DraftCanvasState`, `InteractionLayer`, `CameraGestureDetector`, `RulerFrame`, `PageChromePainter`, `SelectionOverlayPainter`, `GesturePolicy`, `ChromePalette`, `PaperPalette`, `kSelectionStrokePixels`, `displayPaperFor`, `darkCanvasFor`, `foregroundFor`, `canvasResolverFor`, `fitToPage`, `ViewportTransform`, `TextTool`, `TextPlacement`, `ToolController`, `CameraController`, `PageNotifier`, `OutlineCache`, `GripCache`, `SelectionController`, `SnapSettings`, `VerticesDrawSink` (`debugCapacityVertices`, `debugPaint`, `resetCounters`, `totalFlushCount`, `frameTriangleCount`).
  - The engine: `DraftDocument`, `DraftDocumentCodec`, `StyleResolver`, `PageComponent`, `Tolerance`, `Transform2`; `package:jet_cad_2d/testing.dart`'s `generateDocument`.
  - Task 7: `String ensureManifest(String text)` (`lib/src/file/plan_file.dart`).
  - Task 8, 9, 10, 11, 12: the members listed in "Assumed from earlier tasks" below.
- Produces:
  - Exported from the barrel: `class PlanCanvas extends StatefulWidget` — `const PlanCanvas({Key? key, required PlanController controller, bool rulers = true, bool grid = true, bool snapping = true, bool autofocus = true})`; `const Duration kLockHintDuration` (2 s).
  - Internal (`lib/src/canvas/`): `PlanCanvasView` (`@internal`, today's `PlannerView` renamed, same constructor); `TextEntryOverlay`, `kTextEntrySize`. `clampCameraScale` is Task 8's (`lib/src/controller/camera_bounds.dart`, R-k).
  - Internal (`lib/src/shortcuts/`), used by Tasks 16, 17 and 18:
    - `chords.dart`: `kNewChords`, `kOpenChords`, `kSaveChords`, `kSaveAsChords`, `kExportChords`, `kPrintChords`, `kUndoChords`, `kRedoChords`, `kFileChords` (`List<SingleActivator>`), `kPageCommandIds`.
    - `plan_shortcut_guard.dart` (re-exports `chords.dart`): `class PlanShortcutGuard extends StatelessWidget` — `const PlanShortcutGuard({Key? key, required PlanController controller, required Widget child})`; `class PlanTextKeys extends StatelessWidget` — `const PlanTextKeys({Key? key, required Widget child})`; `List<LogicalKeyboardKey> planLetterKeys(PlanController controller)` (in this task: the generic letters and F; Task 16 adds the kits' letters); `LogicalKeyboardKey letterKey(String letter)`.

Plan decision (**the guard lands here**): the scopes give the shortcut guard to Task 16, but the text entry this task ports already needs it (`text_entry_overlay.dart:135` wraps its field in `ShellShortcutGuard`), and Task 18 assumes `PlanShortcutGuard({required PlanController controller, required Widget child})` in `lib/src/shortcuts/plan_shortcut_guard.dart` with `planLetterKeys(PlanController)`. So the guard file and the chords land here with the generic letters; Task 16 makes `planLetterKeys` return the letters actually in use (spec P2: "The guard is built from the letters actually in use"), and every guarded field follows without a change.

Plan decision (**which tests move**): `floor_plan/test/planner_palette_test.dart` tests the canvas's colour palettes (chrome and paper sets), not the tool palette, so it is ported here; `floor_plan/test/hover_removal_test.dart`'s HR1 removes a hovered canvas beside the property panel that listens to the selection (its named mutant is the panel's relay), so it moves to Task 17, where that panel exists; HR2 (a hovered table) is 2b's. `canvas_ui_test.dart`'s D6a tests the page panel's swatches and moves to Task 18.

Plan decision (**the canvas owns the paper**): the resolver, its key (ACI 7's ink on the display paper, and whether the canvas re-tones) and the canvas colour move from the shell (`floor_plan/lib/src/planner_shell.dart:281-382`) into `PlanCanvas`, so the canvas stands alone with only a controller (spec P2). The table colour layer (`planner_shell.dart:1518-1524`) and the `_fillPaper`/`_fillTheme` notifiers (`:359`, `:380-381`) are 2b's and are not ported.

Plan decision (**one canvas at a time**, spec P2): the rule is checked after the frame, not in `initState`. Flutter inflates a replacing canvas before it disposes the replaced one when a keyed child moves (`RenderObjectElement.updateChildren` inflates the new middle children before it deactivates the old keyed ones), so a check in `initState` would assert on a legitimate swap. Each `_PlanCanvasState` adds itself to a per-controller set in `initState` and removes itself in `dispose`; a post-frame callback asserts that the set holds at most one. Debug only (`assert`).

Plan decision (**the lock hint**): `PlanController.lockHint` (Task 11) is set by the guarded tools and the panels' commit sites when an edit is refused with `PlanLocked`. The canvas shows `PlanStrings.lockedHint` (Task 9's word) near its bottom edge while it is set, ignoring the pointer, and clears it `kLockHintDuration` (2 s) after it was set.

Plan decision (**`snapping`**): the canvas option writes Task 8's `@internal bool PlanController.snappingAllowed` in `initState` and `didUpdateWidget`; the controller's effective object-snap flag (Task 8's `EffectiveSnap`, the one the `ToolContext`'s `SnapSettings` and `PlanServices.objectSnap` read) is `snappingAllowed && snap.objectSnap`, today's `_CapabilitySnap` (`planner_shell.dart:1756-1777`).

- [ ] **Step 1: The fixture.** Create `test/support/canvas_fixture.dart`. It is `floor_plan/test/support/palette_fixture.dart:1-335` copied, with exactly these adaptations, plus the drawing fixture of `floor_plan/test/planner_draw_test.dart:14-87`:
  1. The header comment (`:1-12`) gains a first line: `// Ported from jet_cad_floor_plan/test/support/palette_fixture.dart and planner_draw_test.dart's drawing fixture, over a PlanController.`
  2. Imports (`:13-24`): drop `package:jet_cad_floor_plan/src/new_document.dart` and `package:jet_cad_floor_plan/src/planner_view.dart`; add `dart:async` (`unawaited`), `dart:convert` (`jsonDecode`), `package:jet_cad_2d_plan/jet_cad_2d_plan.dart`, `package:jet_cad_2d_plan/src/canvas/plan_canvas_view.dart` and `package:jet_cad_2d_plan/src/file/plan_file.dart` (`ensureManifest`).
  3. `paletteDoc` (`:74-109`) is replaced by the code below (the page's origin becomes a parameter, `prepareDocument` becomes the engine calls it made that the canvas needs).
  4. `expectPainters` (`:309-335`): `find.byType(PlannerView)` becomes `find.byType(PlanCanvasView)`. Nothing else in `:111-335` changes.
  5. Append the new helpers below (`paletteText`, `paletteController`, `pumpCanvas`, the drawing fixture).

```dart
/// A document with two ACI 7 lines (ByLayer, layer 0) and, unless [paper]
/// is null, a 1:20 page of that background with the grid off, its origin
/// at ([originX], [originY]). Null [paper] is the page-less document a file
/// saved without a page decodes to. Units are millimetres, as
/// `prepareDocument` set them (`floor_plan/lib/src/new_document.dart:18-24`).
({DraftDocument doc, Handle selected, Handle ink}) paletteDoc(
    TextMeasurer measurer,
    {required int? paper,
    double originX = sheetMinX,
    double originY = sheetMinY}) {
  final doc = DraftDocument.empty(measurer: measurer);
  PageComponent.register(doc.components);
  doc.header.units = DrawingUnits.millimeters;
  if (paper != null) {
    doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle,
        PageComponent(
            scaleDenominator: 20,
            originX: originX,
            originY: originY,
            background: paper,
            gridVisible: false,
            snapToGrid: false)));
  }
  Handle line(double y) {
    final add = addDrafted(doc, EntityKind.line,
        linePayload(Vector2(lineX0, y), Vector2(lineX1, y)),
        layer: ReservedHandles.layerZero);
    doc.commands.execute(add);
    return add.record.handle;
  }

  final selected = line(selectedY);
  final ink = line(inkY);
  doc.commands.clearHistory();
  expect(doc.entities.colorAt(doc.entities.slotOf(ink)!), kByLayer);
  expect(doc.tables.layers[ReservedHandles.layerZero]!.color,
      const IndexedColor(7));
  return (doc: doc, selected: selected, ink: ink);
}

/// [paletteDoc] as a plan's text: [extra] draws on it, then it is encoded
/// with the empty manifest an imported drawing gets (Task 7). The two
/// lines' handles survive the encoding.
({String json, Handle selected, Handle ink}) paletteText(
    {required int? paper,
    double originX = sheetMinX,
    double originY = sheetMinY,
    void Function(DraftDocument doc)? extra}) {
  final m = FlutterTextMeasurer();
  final f = paletteDoc(m, paper: paper, originX: originX, originY: originY);
  extra?.call(f.doc);
  f.doc.commands.clearHistory();
  final json = ensureManifest(DraftDocumentCodec.encodeToString(f.doc));
  unawaited(f.doc.dispose());
  m.clear();
  return (json: json, selected: f.selected, ink: f.ink);
}

/// A controller with no kit over [paletteText]. Disposed at the end of the
/// test.
({PlanController c, Handle selected, Handle ink}) paletteController(
    {required int? paper, void Function(DraftDocument doc)? extra}) {
  final t = paletteText(paper: paper, extra: extra);
  final c = PlanController(kits: const [], json: t.json);
  addTearDown(c.dispose);
  return (c: c, selected: t.selected, ink: t.ink);
}

/// Pumps [c]'s canvas alone, in a Scaffold, under the seed's themes in
/// [mode], at 1440 x 900 and device pixel ratio 1.
Future<void> pumpCanvas(WidgetTester tester, PlanController c, ThemeMode mode,
    {bool rulers = true}) async {
  windowAt(tester, const Size(1440, 900));
  await pumpThemed(
      tester, Scaffold(body: PlanCanvas(controller: c, rulers: rulers)), mode);
  await tester.pump();
}

/// `planner_draw_test.dart`'s `drawDoc` (`:16-32`) as a plan: a 1:20 page
/// anchored at (7000, 3000), grid snap off, its background [background],
/// and one line to select.
({PlanController c, Handle line}) drawController({int background = white}) {
  final m = FlutterTextMeasurer();
  final doc = DraftDocument.empty(measurer: m);
  PageComponent.register(doc.components);
  doc.commands.execute(SetComponentCommand<PageComponent>(
      doc.rootHandle,
      PageComponent(
          scaleDenominator: 20,
          originX: 7000,
          originY: 3000,
          background: background,
          snapToGrid: false)));
  final add = addDrafted(doc, EntityKind.line,
      linePayload(Vector2(7137.3, 3161.7), Vector2(7300.9, 3190.1)),
      layer: ReservedHandles.layerZero);
  doc.commands.execute(add);
  doc.commands.clearHistory();
  final json = ensureManifest(DraftDocumentCodec.encodeToString(doc));
  unawaited(doc.dispose());
  m.clear();
  final c = PlanController(kits: const [], json: json);
  addTearDown(c.dispose);
  return (c: c, line: add.record.handle);
}

/// A controller over a document with no page and nothing drawn.
PlanController pagelessController() {
  final m = FlutterTextMeasurer();
  final doc = DraftDocument.empty(measurer: m);
  final json = ensureManifest(DraftDocumentCodec.encodeToString(doc));
  unawaited(doc.dispose());
  m.clear();
  final c = PlanController(kits: const [], json: json);
  addTearDown(c.dispose);
  return c;
}

/// `planner_draw_test.dart`'s `pumpDraw` (`:38-53`): pumps [c]'s canvas
/// (inside [frame] when given: Tasks 16 and 17 put the palette, the panels
/// and the shortcuts around it), then sets a zoomed, rotated,
/// **non-reflecting** camera centred on (7150, 3110).
Future<void> pumpDraw(WidgetTester tester, PlanController c,
    {Widget Function(Widget canvas)? frame}) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final canvas = PlanCanvas(controller: c);
  await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: frame?.call(canvas) ?? canvas)));
  await tester.pump();
  final size = tester.getSize(find.byType(InteractionLayer));
  final linear = Transform2.rotation(0.35).multiply(Transform2.scale(2.0, 2.0));
  final mid = linear.transformPoint(Vector2(7150, 3110));
  c.camera.value = ViewportTransform(
      worldToScreenMatrix: Transform2.translation(
              size.width / 2 - mid.x, size.height / 2 - mid.y)
          .multiply(linear));
  await tester.pump();
}

/// `planner_draw_test.dart`'s `globalOf` (`:55-58`).
Offset globalOf(WidgetTester tester, PlanController c, double x, double y) {
  final s = c.camera.value.worldToScreen(Vector2(x, y));
  return tester.getTopLeft(find.byType(InteractionLayer)) + Offset(s.x, s.y);
}

/// `planner_draw_test.dart`'s `bytes` and `withoutSeed` (`:69-75`).
String bytes(PlanController c) =>
    DraftDocumentCodec.encodeToString(c.document);

Map<String, Object?> withoutSeed(PlanController c) =>
    (jsonDecode(bytes(c)) as Map<String, Object?>)..remove('handleSeed');

/// `planner_draw_test.dart`'s `entryEditable` and `ofKind` (`:79-87`).
final Finder entryEditable = find.descendant(
    of: find.byKey(const Key('text-entry')),
    matching: find.byType(EditableText));

List<Handle> ofKind(DraftDocument doc, EntityKind kind) => [
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.kindAt(slot) == kind) doc.entities.handleAt(slot),
    ];

/// The active tool with Task 11's guarding decorator taken off, for a test
/// that reads a drawing tool's own state.
Tool activeTool(PlanController c) {
  final t = c.toolController.active;
  return t is GuardedTool ? t.inner : t;
}
```

  (`GuardedTool` comes from `package:jet_cad_2d_plan/src/kits/guard.dart`; add that import.)

- [ ] **Step 2: The new tests.** Create `test/canvas/plan_canvas_test.dart`:

```dart
// Spec 2a P2, "The widgets": PlanCanvas alone, with only a controller. It
// fits the plan on its first frame (today's PlannerView), shows a
// controller in one canvas at a time, follows the controller's document
// swap, carries the rulers, grid and snapping options, pushes the app's
// locale into the controller (spec P5) and shows the lock hint (spec P4).
// The palette fixture: a 1:20 page off the origin, two ACI 7 lines.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/controller/camera_bounds.dart';
import 'package:jet_cad_2d_plan/src/canvas/plan_canvas_view.dart';

import '../support/canvas_fixture.dart';

/// The six numbers of [v]'s world-to-screen matrix.
List<double> m(ViewportTransform v) {
  final t = v.worldToScreenMatrix;
  return [t.a, t.b, t.c, t.d, t.e, t.f];
}

Future<void> pumpAlone(WidgetTester tester, Widget body) async {
  windowAt(tester, const Size(1200, 700));
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: body)));
  await tester.pump();
}

/// [c]'s page fitted to the drawing area, clamped as every fit is.
List<double> pageFit(WidgetTester tester, PlanController c) {
  final size = tester.getSize(find.byType(InteractionLayer));
  final page =
      c.document.components.get<PageComponent>(c.document.rootHandle)!;
  return m(clampCameraScale(fitToPage(page, size), size,
      minScale: c.camera.minScale, maxScale: c.camera.maxScale));
}

void main() {
  testWidgets(
      'CV-1 the plan is fitted to the drawing area on the first frame, '
      'inside the zoom bounds (M-CV-1)', (tester) async {
    final c = paletteController(paper: white).c;
    final before = m(c.camera.value);
    await pumpAlone(tester, PlanCanvas(controller: c));
    final want = pageFit(tester, c);
    expect(want, isNot(before),
        reason: 'premise: the controller\'s nominal camera is not the fit');
    expect(m(c.camera.value), want);
  });

  testWidgets(
      'CV-2 one controller in two canvases asserts after the frame; two '
      'controllers, one canvas, and a canvas moved to another parent do not '
      '(M-CV-2a, M-CV-2b)', (tester) async {
    final c = paletteController(paper: white).c;
    final d = paletteController(paper: blueprint).c;
    windowAt(tester, const Size(1200, 700));
    Widget row(List<PlanController> cs) => MaterialApp(
        home: Row(children: [
          for (final x in cs) Expanded(child: PlanCanvas(controller: x)),
        ]));
    await tester.pumpWidget(row([c, d]));
    expect(tester.takeException(), isNull, reason: 'two controllers');
    await tester.pumpWidget(row([c]));
    expect(tester.takeException(), isNull, reason: 'one canvas');
    // A Column in place of the Row: a new canvas for c, the old one
    // disposed in the same frame.
    await tester.pumpWidget(MaterialApp(
        home: Column(
            children: [Expanded(child: PlanCanvas(controller: c))])));
    expect(tester.takeException(), isNull,
        reason: 'a canvas that replaces another is not a second one');
    await tester.pumpWidget(row([c, c]));
    final error = tester.takeException();
    expect(error, isA<FlutterError>());
    expect('$error', contains('one PlanCanvas at a time'));
  });

  testWidgets(
      'CV-3 load: the canvas draws the controller\'s new document and fits '
      'its page (M-CV-3)', (tester) async {
    final c = paletteController(paper: white).c;
    await pumpAlone(tester, PlanCanvas(controller: c));
    final first = c.document;
    c.load(paletteText(paper: blueprint, originX: -5000, originY: 8000).json);
    await tester.pump();
    await tester.pump();
    expect(identical(c.document, first), isFalse,
        reason: 'premise: load made a new document');
    final canvas = tester.state<DraftCanvasState>(find.byType(DraftCanvas));
    expect(identical(canvas.widget.document, c.document), isTrue);
    expect(m(c.camera.value), pageFit(tester, c),
        reason: 'the new plan is fitted on its first frame');
    expect(tester.widget<PlanCanvasView>(find.byType(PlanCanvasView)).paper,
        PaperPalette.dark,
        reason: 'the paper set is the new page\'s (Blueprint)');
  });

  testWidgets(
      'CV-4 the lock hint shows while controller.lockHint is set and clears '
      'after kLockHintDuration (M-CV-4a, M-CV-4b)', (tester) async {
    final c = paletteController(paper: white).c;
    await pumpAlone(tester, PlanCanvas(controller: c));
    final hint = find.byKey(const Key('plan-lock-hint'));
    expect(hint, findsNothing);
    c.lockHint.value = true;
    await tester.pump();
    expect(hint, findsOneWidget);
    expect(find.descendant(of: hint, matching: find.text('This object is locked')),
        findsOneWidget);
    await tester.pump(kLockHintDuration);
    await tester.pump();
    expect(c.lockHint.value, isFalse);
    expect(hint, findsNothing);
  });

  testWidgets(
      'CV-5 rulers: false and grid: false: no ruler frame and a page chrome '
      'without the grid; the defaults draw both (M-CV-5)', (tester) async {
    final c = paletteController(paper: white).c;
    PageChromePainter chrome() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((p) => p.painter)
        .whereType<PageChromePainter>()
        .single;
    await pumpAlone(
        tester, PlanCanvas(controller: c, rulers: false, grid: false));
    expect(find.byType(RulerFrame), findsNothing);
    expect(chrome().grid, isFalse);
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: PlanCanvas(controller: c))));
    await tester.pump();
    expect(find.byType(RulerFrame), findsOneWidget);
    expect(chrome().grid, isTrue);
  });

  testWidgets(
      'CV-6 snapping: false turns object snap off for the tools and keeps '
      'the user\'s F3 setting; snapping: true turns it back (M-CV-6a, '
      'M-CV-6b)', (tester) async {
    final c = paletteController(paper: white).c;
    await pumpAlone(tester, PlanCanvas(controller: c, snapping: false));
    expect(c.snap.objectSnap, isTrue, reason: 'the user\'s setting');
    expect(c.toolController.context.snap!.objectSnap, isFalse,
        reason: 'what the tools read');
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: PlanCanvas(controller: c))));
    expect(c.toolController.context.snap!.objectSnap, isTrue);
  });

  testWidgets(
      'CV-7 the canvas pushes the app\'s locale into controller.locale and '
      'follows a change of language (M-CV-7)', (tester) async {
    final c = paletteController(paper: white).c;
    Future<void> pumpIn(Locale locale) async {
      await tester.pumpWidget(MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('de'), Locale('tr')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(body: PlanCanvas(controller: c))));
      await tester.pump();
    }

    await pumpIn(const Locale('tr'));
    expect(c.locale.value, const Locale('tr'));
    await pumpIn(const Locale('de'));
    expect(c.locale.value, const Locale('de'));
  });
}
```

- [ ] **Step 3: The invariant.** Create `test/invariants/canvas_paint_allocation_test.dart`:

```dart
// What a steady-state frame of the plan library's canvas allocates
// (CLAUDE.md: "The frame path allocates nothing per entity in steady state,
// and O(1) per flush"; spec 2a "Tests": a paint-allocation test for the
// plan library's canvas).
//
// The drawing is the Flutter layer's DraftCanvas, whose own frame path
// jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart measures:
// once a frame has drawn its widest view, the vertices sink never gives
// capacity back, so `debugCapacityVertices` holds still across a later
// frame or it does not, and `flush` reuses one Paint. What the plan library
// adds is the composition around it: PlanCanvas rebuilds (a controller
// notification, a theme, a parent's build) must hand DraftCanvas the same
// resolver, document, index and camera, or DraftCanvas re-attaches
// (`draft_canvas.dart:443-462`): a new DraftPainter, a new sink, every
// cache made again, which is O(entities) per rebuild. So the frames below
// rebuild PlanCanvas every frame and pin: the same DraftCanvasState, the
// same painter, the same sink, a capacity that holds still and the same
// Paint. The plan library paints nothing per entity of its own: the
// overlay, the rulers and the page chrome are the Flutter layer's.
//
// The corpus is the Flutter layer's (4,000 entities, 400 instances nested
// two deep, mirrored and non-uniform placements, groups, eight layers,
// ByBlock and dashed styles), loaded through PlanController from its text,
// with 50 root entities selected so the overlay draws outlines and grips.
// The two cameras differ by one pixel of pan, off the origin.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d/testing.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/file/plan_file.dart' show ensureManifest;

void main() {
  testWidgets(
      'CV-alloc a rebuilt steady-state PlanCanvas frame allocates O(1) per '
      'flush, not O(entities) (M-CV-alloc-1, M-CV-alloc-2)', (tester) async {
    final corpus = generateDocument(
      4000,
      definitionCount: 40,
      instanceCount: 400,
      nestingDepth: 2,
      mirroredFraction: 0.1,
      nonUniformFraction: 0.2,
      groupCount: 10,
      layerCount: 8,
      byBlockFraction: 0.3,
      dashedFraction: 0.35,
    );
    final json = ensureManifest(DraftDocumentCodec.encodeToString(corpus));
    final c = PlanController(kits: const [], json: json);
    addTearDown(c.dispose);
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: PlanCanvas(controller: c))));
    await tester.pump();

    final doc = c.document;
    final roots = [
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.ownerAt(slot) == doc.rootHandle)
          doc.entities.handleAt(slot),
    ].take(50).toList();
    expect(roots, hasLength(50), reason: 'premise: root entities to select');
    c.selection.replace([for (final h in roots) SelectionKey.root(h)]);

    final size = tester.getSize(find.byType(InteractionLayer));
    final a = ViewportTransform.fit(doc.extents, size);
    final b = ViewportTransform(
        worldToScreenMatrix:
            Transform2.translation(1, -1).multiply(a.worldToScreenMatrix));
    Future<void> frames(int n) async {
      for (var i = 0; i < n; i++) {
        c.camera.value = i.isEven ? a : b;
        tester.element(find.byType(PlanCanvas)).markNeedsBuild();
        await tester.pump();
      }
    }

    // Warm up: both views drawn, so the buffers are at their high water.
    await frames(6);
    final state = tester.state<DraftCanvasState>(find.byType(DraftCanvas));
    final painter = state.painter;
    final sink = state.vertices!;
    final capacity = sink.debugCapacityVertices;
    final paint = sink.debugPaint;
    sink.resetCounters();

    await frames(10);

    expect(sink.totalFlushCount, greaterThan(0),
        reason: 'nothing was flushed, so nothing was measured');
    expect(sink.frameTriangleCount, greaterThan(1000),
        reason: 'a degenerate corpus would make the bound meaningless');
    // M-CV-alloc-2: a key that changes per build remounts the canvas.
    expect(
        identical(
            tester.state<DraftCanvasState>(find.byType(DraftCanvas)), state),
        isTrue,
        reason: 'a rebuild remounted DraftCanvas');
    // M-CV-alloc-1: a resolver made per build rebuilds the painter.
    expect(identical(state.painter, painter), isTrue,
        reason: 'a rebuild handed DraftCanvas a new resolver: a new painter '
            'and every cache made again');
    expect(identical(state.vertices, sink), isTrue);
    expect(sink.debugCapacityVertices, capacity,
        reason: 'the buffer grew in a steady-state frame: O(entities)');
    expect(identical(sink.debugPaint, paint), isTrue,
        reason: 'flush() must reuse the one Paint of the sink\'s life');
  });
}
```

- [ ] **Step 4: Run the new tests to see them fail.** Run: `cd packages/jet_cad_2d_plan && flutter test test/canvas/plan_canvas_test.dart test/invariants/canvas_paint_allocation_test.dart`. Expected: compilation errors naming `PlanCanvas`, `PlanCanvasView`, `clampCameraScale` (unless Task 8 has it) and `kLockHintDuration`; no test runs.

- [ ] **Step 5: The controller member the canvas adds.** Every other member of "Assumed from earlier tasks" is Task 8's or Task 12's as listed there. In `plan_controller.dart` add `textTool` (Task 12 builds the generic tools per document in `DocumentSession.generic`, a `GenericToolSet`):

```dart
  /// The current document's TEXT tool, unwrapped: the canvas's inline
  /// field (TextEntryOverlay) drives its pending placement.
  @internal
  TextTool get textTool => _session.generic.byId[PlanToolIds.text]! as TextTool;
```

  The snapping flag is Task 8's `@internal bool snappingAllowed` (default `true`), read by its `EffectiveSnap` (the `ToolContext`'s `SnapSettings` and `PlanServices.objectSnap`); nothing to add for it.

- [ ] **Step 6: `camera_bounds.dart`.** Task 8 ported it to `lib/src/controller/camera_bounds.dart` (controller ruling R-k); it is not ported again. `plan_canvas_view.dart` and `plan_canvas_test.dart` import `../controller/camera_bounds.dart` / `package:jet_cad_2d_plan/src/controller/camera_bounds.dart`.

- [ ] **Step 7: The chords.** Create `lib/src/shortcuts/chords.dart`: `floor_plan/lib/src/shell_commands.dart:1-61` copied, with the header (`:1-3`) replaced by:

```dart
// The chords the plan's keyboard binds (spec 2a P2, "The keyboard"),
// ported from jet_cad_floor_plan/lib/src/shell_commands.dart:10-61: Cmd
// and Ctrl with each key, on every platform. PlanShortcuts binds them
// (Task 16); the guard keeps Undo and Redo out of a focused field.
```

  and the imports `:4-8` reduced to `import 'package:flutter/services.dart' show LogicalKeyboardKey;` and `import 'package:flutter/widgets.dart' show SingleActivator;`. `ShellCommand` and `DerivedFlag` (`:63-169`) are not copied here (Task 20's bar ports them if it needs them).

- [ ] **Step 8: The guard.** Create `lib/src/shortcuts/plan_shortcut_guard.dart`. `PlanTextKeys` and `_TypingActivator` are `floor_plan/lib/src/shortcut_guard.dart:69-138` copied with `PlannerTextKeys` renamed `PlanTextKeys` (`:97-115`, and `debugLabel: 'PlanTextKeys'`); the rest is new:

```dart
// The keys a text field inside the plan keeps (spec 2a P2, "The keyboard":
// text fields keep their keys, and the guard is built from the letters
// actually in use, not from today's fixed list of 16). Ported from
// jet_cad_floor_plan/lib/src/shortcut_guard.dart: ShellShortcutGuard
// becomes PlanShortcutGuard, whose letters come from planLetterKeys;
// PlannerTextKeys becomes PlanTextKeys, unchanged.
import 'package:flutter/services.dart'
    show HardwareKeyboard, KeyEvent, KeyUpEvent, LogicalKeyboardKey;
import 'package:flutter/widgets.dart';

import '../controller/plan_controller.dart';
import '../tools/generic_tools.dart';
import 'chords.dart';

export 'chords.dart';

/// The key of an upper-case Latin [letter] (`'A'`..`'Z'`).
LogicalKeyboardKey letterKey(String letter) => LogicalKeyboardKey(
    LogicalKeyboardKey.keyA.keyId + letter.codeUnitAt(0) - 0x41);

/// The letters [controller]'s keyboard binds, F included (spec 2a P2: F is
/// reserved for Fill). Here the generic tools' (V L P R C A T); Task 16
/// adds the kits' letters in load order.
List<LogicalKeyboardKey> planLetterKeys(PlanController controller) => [
      for (final t in genericTools) letterKey(t.letter),
      LogicalKeyboardKey.keyF,
    ];

/// Spec 05 D9, Ruling 05-8, spec 2a P2. Ported from `ShellShortcutGuard`
/// (`shortcut_guard.dart:27-67`).
///
/// **Why this exists.** A `Shortcuts` or `CallbackShortcuts` above a text
/// field takes the field's keystrokes. PlanShortcuts' tool letters, its
/// Undo and Redo chords and its Escape are such shortcuts.
///
/// **What it does.** It maps each of them, **nearer** the field, to
/// `DoNothingAndStopPropagationTextIntent`. `EditableText` answers that
/// intent with `DoNothingAction(consumesKey: false)`, so the key stops here
/// and reaches the field as text.
///
/// **Elsewhere it is inert.** With focus anywhere other than a text field,
/// no action is found, and the key bubbles up to the shortcuts as before.
class PlanShortcutGuard extends StatelessWidget {
  const PlanShortcutGuard(
      {super.key, required this.controller, required this.child});

  /// Whose letters in use are guarded.
  final PlanController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) => Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          for (final key in planLetterKeys(controller))
            SingleActivator(key): const DoNothingAndStopPropagationTextIntent(),
          // Undo and Redo: in a focused field they never reach the
          // document. A SingleActivator matches its modifiers exactly, so
          // each chord is listed. The file chords are not guarded: Cmd+S in
          // a panel field saves.
          for (final chord in [...kUndoChords, ...kRedoChords])
            chord: const DoNothingAndStopPropagationTextIntent(),
          // PlanShortcuts binds Escape too: in a panel's field it must not
          // drop a pending shape. The text entry's own Escape binding sits
          // nearer, so it still cancels there.
          const SingleActivator(LogicalKeyboardKey.escape):
              const DoNothingAndStopPropagationTextIntent(),
        },
        child: child,
      );
}
```

  followed by the copied `PlanTextKeys` and `_TypingActivator` (`:69-138` with the doc comment's "[ShellShortcutGuard]" read as "[PlanShortcutGuard]").

- [ ] **Step 9: The text entry.** Copy `floor_plan/lib/src/text_entry_overlay.dart:1-185` to `lib/src/canvas/text_entry_overlay.dart`. Adaptations, and nothing else:
  1. `import 'shortcut_guard.dart';` (`:7`) becomes `import '../shortcuts/plan_shortcut_guard.dart';` and the class gains `required this.controller,` as its first named parameter with the field `final PlanController controller;` (import `../controller/plan_controller.dart`), since the guard needs it.
  2. `ShellShortcutGuard(` (`:135`) becomes `PlanShortcutGuard(controller: widget.controller,`.
  3. The doc comment's "the shell's letters" (`:18`, `:77`, `:94`) reads "the plan's letters".

- [ ] **Step 10: The view.** Copy `floor_plan/lib/src/planner_view.dart:1-481` to `lib/src/canvas/plan_canvas_view.dart`. Adaptations, and nothing else:
  1. Rename `PlannerView` to `PlanCanvasView` (`:18`, `:19`, `:173`, `:221`, and the doc references `:260`, `:288`), `_PlannerViewState` to `_PlanCanvasViewState` (`:173`, `:176`).
  2. Add `import 'package:meta/meta.dart' show internal;` and `@internal` on the class; add `import '../controller/plan_controller.dart';`.
  3. The constructor gains `required this.controller,` as its first named parameter, and the class the field `final PlanController controller;` ("The controller, for the text entry's guard."); `TextEntryOverlay(` (`:390`) gains `controller: widget.controller,`.
  4. The doc comments that say "the shell" (`:55`, `:65`, `:69`, `:93`) read "PlanCanvas"; `:169`'s `FloorPlanView.autofocus` reads `PlanCanvas.autofocus`.

- [ ] **Step 11: The canvas.** Create `lib/src/canvas/plan_canvas.dart`:

```dart
// The plan's canvas (spec 2a P2, "The widgets"): the rulers, the camera
// gestures, the interaction layer, the page chrome, the drawing, the
// selection and grip overlay and the text entry, over one PlanController,
// which is all it takes.
//
// Ported from jet_cad_floor_plan: the paper, the ink and the resolver from
// planner_shell.dart (:281-382), the canvas colour (:367-368), the
// fit-on-start latch from host/floor_plan_view.dart (:507, :595-602), and
// the view itself (PlanCanvasView, planner_view.dart). New: the one-canvas
// rule, the controller's document swap, the locale push, the snapping
// option and the lock hint (spec P4, "Where PlanLocked is caught").
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../controller/plan_controller.dart';
import '../l10n/locale_scope.dart';
import '../l10n/strings.dart';
import '../theme/plan_theme.dart' show PlanTheme, planPaperPaletteFor;
import 'plan_canvas_view.dart';

/// How long the canvas shows the lock hint before it clears it.
const Duration kLockHintDuration = Duration(seconds: 2);

/// Draws [controller]'s plan and routes the pointer and the keys to its
/// active tool.
///
/// - The plan is fitted to the drawing area on its first frame, and again
///   on the first frame of each plan `load`, `newPlan` or `import` swaps in.
/// - A controller is shown in one PlanCanvas at a time: a second one
///   asserts in debug, after the frame.
/// - [rulers] and [grid] are the drafting aids; [snapping] lets object snap
///   act (the user's F3 setting is kept either way); [autofocus] lets the
///   canvas take the focus when it is mounted.
class PlanCanvas extends StatefulWidget {
  const PlanCanvas({
    super.key,
    required this.controller,
    this.rulers = true,
    this.grid = true,
    this.snapping = true,
    this.autofocus = true,
  });

  final PlanController controller;
  final bool rulers;
  final bool grid;
  final bool snapping;
  final bool autofocus;

  @override
  State<PlanCanvas> createState() => _PlanCanvasState();
}

/// The canvases each controller is shown in, for the one-canvas rule
/// (debug only).
final Expando<Set<Object>> _canvasesOf = Expando<Set<Object>>('PlanCanvas');

class _PlanCanvasState extends State<PlanCanvas> {
  PlanController get _c => widget.controller;

  /// The document the resolver, the page listener and the fit latch belong
  /// to; [_bind] moves them to the controller's current one.
  DraftDocument? _document;
  PageNotifier? _page;

  /// ACI 7's foreground follows the paper (planner_shell.dart:281-299):
  /// replaced only when its key ([_foreground], [_darkCanvas]) changes, as
  /// DraftCanvas rebuilds its painter whenever it is handed a different
  /// resolver.
  late StyleResolver _resolver;
  int _foreground = -1;
  bool _darkCanvas = false;

  /// The theme's surface (or the theme's `canvasBackground`) and
  /// brightness; set in [didChangeDependencies].
  late int _surfaceArgb;
  late Brightness _brightness;
  PlanTheme? _theme;

  final GesturePolicy _policy = GesturePolicy.forPlatform();

  /// floor_plan_view.dart:507, :595-602: the fit-on-start latch, taken once
  /// per document.
  DraftDocument? _fitFor;
  bool _fit = false;
  bool _fitIsRequest = false;

  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    _enter(_c);
    _c.addListener(_onController);
    _c.lockHint.addListener(_onHint);
    _c.snappingAllowed = widget.snapping;
    _bind();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = Theme.of(context);
    _theme = PlanTheme.of(context);
    _surfaceArgb = _canvasColour(theme.colorScheme).toARGB32();
    _brightness = theme.brightness;
    // A build follows, so no setState: only a key change builds a new
    // resolver (planner_shell.dart:371-382).
    if (_nextResolver() case final next?) _resolver = next;
    PlanLocaleScope.push(context, _c);
  }

  @override
  void didUpdateWidget(PlanCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.controller;
    if (!identical(old, _c)) {
      _leave(old);
      old.removeListener(_onController);
      old.lockHint.removeListener(_onHint);
      _hintTimer?.cancel();
      _enter(_c);
      _c.addListener(_onController);
      _c.lockHint.addListener(_onHint);
      _rebind();
      PlanLocaleScope.push(context, _c);
    }
    _c.snappingAllowed = widget.snapping;
  }

  @override
  void dispose() {
    _leave(_c);
    _c.removeListener(_onController);
    _c.lockHint.removeListener(_onHint);
    _page?.removeListener(_onPage);
    _hintTimer?.cancel();
    super.dispose();
  }

  /// Spec 2a P2: a controller is shown in one PlanCanvas at a time. Checked
  /// after the frame, when a replaced canvas has been disposed (a keyed
  /// swap inflates the new canvas before it deactivates the old one).
  void _enter(PlanController c) {
    assert(() {
      (_canvasesOf[c] ??= <Object>{}).add(this);
      SchedulerBinding.instance.addPostFrameCallback((_) {
        final shown = _canvasesOf[c];
        if (shown != null && shown.length > 1) {
          throw FlutterError(
              'A PlanController is shown in one PlanCanvas at a time '
              '(spec 2a P2): this controller is in ${shown.length}. Dispose '
              'the first canvas before showing the controller in another.');
        }
      });
      return true;
    }());
  }

  void _leave(PlanController c) {
    assert(() {
      _canvasesOf[c]?.remove(this);
      return true;
    }());
  }

  /// Binds the page listener to the controller's current document.
  void _bind() {
    _document = _c.document;
    _page = _c.page..addListener(_onPage);
  }

  /// A new document (load, newPlan, import) or a new controller: the page
  /// listener moves, and the resolver is made again for the new document.
  void _rebind() {
    _page?.removeListener(_onPage);
    _bind();
    _foreground = -1;
    _resolver = _nextResolver()!;
  }

  /// The controller notified: a document swap rebuilds the canvas; any
  /// other notification (permissions, the locale) is not the canvas's.
  void _onController() {
    if (identical(_c.document, _document)) return;
    setState(_rebind);
  }

  /// planner_shell.dart:344-363, less the table fills (2b): a page change
  /// that moves the resolver's key rebuilds with a new resolver.
  void _onPage() {
    final next = _nextResolver();
    if (next == null) return;
    setState(() => _resolver = next);
  }

  /// planner_shell.dart:328-331: the paper the drafting and the overlays
  /// lie on.
  int _paperArgb() => displayPaperFor(
      page: _c.page.value?.background,
      surface: _surfaceArgb,
      brightness: _brightness);

  /// planner_shell.dart:334-343: a new resolver when the key moved, else
  /// null; records the new key.
  StyleResolver? _nextResolver() {
    final paper = _paperArgb();
    final foreground = foregroundFor(paper);
    final dark =
        darkCanvasFor(page: _c.page.value?.background, brightness: _brightness);
    if (foreground == _foreground && dark == _darkCanvas) return null;
    _foreground = foreground;
    _darkCanvas = dark;
    return canvasResolverFor(_c.document, paper: paper, dark: dark);
  }

  /// planner_shell.dart:367-368: the theme's `canvasBackground`, else its
  /// surface.
  Color _canvasColour(ColorScheme scheme) =>
      _theme?.canvasBackground ?? scheme.surface;

  /// floor_plan_view.dart:595-602.
  bool _fitOnStartFor(DraftDocument document) {
    if (!identical(_fitFor, document)) {
      _fitFor = document;
      _fitIsRequest = !_c.owesFirstFit;
      _fit = _c.takeFitOnStart();
    }
    return _fit;
  }

  /// Spec P4: the hint clears [kLockHintDuration] after it was set.
  void _onHint() {
    _hintTimer?.cancel();
    if (!_c.lockHint.value) return;
    final c = _c;
    _hintTimer = Timer(kLockHintDuration, () {
      if (mounted && identical(c, _c)) c.lockHint.value = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final c = _c;
    final document = c.document;
    // A parent rebuild may arrive before the controller's notification.
    if (!identical(document, _document)) _rebind();
    final paper = _paperArgb();
    return ColoredBox(
      color: _canvasColour(scheme),
      child: Stack(
        fit: StackFit.expand,
        children: [
          PlanCanvasView(
            // A new document is a new view: its own first fit, its own
            // listeners (today's PlannerShell keyed by ObjectKey(document)).
            key: ObjectKey(document),
            controller: c,
            document: document,
            index: c.index,
            resolver: _resolver,
            camera: c.camera,
            page: c.page,
            policy: _policy,
            selection: c.selection,
            tools: c.toolController,
            outlines: c.outlines,
            chrome: ChromePalette.of(theme.brightness),
            paper: planPaperPaletteFor(paper, _theme),
            selectionStrokePixels:
                _theme?.selectionWidth ?? kSelectionStrokePixels,
            sheetArgb: _darkCanvas ? paper : null,
            grips: c.grips,
            textTool: c.textTool,
            fitRequests: c.fitRequests,
            fitOnStart: _fitOnStartFor(document),
            startFitIsRequest: _fitIsRequest,
            onFitted: c.fitted,
            framing: c.framingFor,
            cameraEpoch: () => c.cameraEpoch,
            onCanvasPlaced: c.canvasPlaced,
            rulers: widget.rulers,
            grid: widget.grid,
            autofocus: widget.autofocus,
          ),
          ValueListenableBuilder<bool>(
            valueListenable: c.lockHint,
            builder: (context, shown, _) => shown
                ? Align(
                    alignment: const Alignment(0, 0.9),
                    child: IgnorePointer(
                      child: DecoratedBox(
                        key: const Key('plan-lock-hint'),
                        decoration: BoxDecoration(
                            color: scheme.inverseSurface,
                            borderRadius: BorderRadius.circular(4)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          child: Text(PlanStrings.of(context).lockedHint,
                              style:
                                  TextStyle(color: scheme.onInverseSurface)),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

```

- [ ] **Step 12: The barrel.** In `lib/jet_cad_2d_plan.dart`, add (in sorted position) `export 'src/canvas/plan_canvas.dart' show PlanCanvas, kLockHintDuration;`.

- [ ] **Step 13: Run the new tests.** Run: `cd packages/jet_cad_2d_plan && flutter test test/canvas/plan_canvas_test.dart test/invariants/canvas_paint_allocation_test.dart`. Expected: `All tests passed!` (eight tests).

- [ ] **Step 14: Port the canvas tests.** Assertions unchanged in every ported test; only the fixture, the pump and the imports change, as listed. Each file starts with a header line `// Ported from jet_cad_floor_plan/test/<file>; assertions unchanged.` and imports `package:flutter/material.dart`, `package:flutter_test/flutter_test.dart`, `package:jet_cad_2d/jet_cad_2d.dart`, `package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart`, `package:jet_cad_2d_plan/jet_cad_2d_plan.dart`, `package:jet_cad_2d_plan/src/canvas/plan_canvas_view.dart` where `PlanCanvasView` is read, and `../support/canvas_fixture.dart` in place of `support/palette_fixture.dart`.
  1. **`test/canvas/canvas_ui_test.dart`** from `floor_plan/test/canvas_ui_test.dart`: the premise test (`:36-48`) and the two `M-DT-12` tests (`:93-148`). Not ported: `D6a` (`:50-91`, the page panel's swatches: Task 18). Adaptations in `M-DT-12`: `paletteDoc(m, paper: paper)` and its teardown (`:104-109`) become `final f = paletteController(paper: paper);`; `pumpThemed(tester, PlannerShell(document: f.doc), mode)` (`:111`) becomes `pumpThemed(tester, Scaffold(body: PlanCanvas(controller: f.c)), mode)`; the camera (`:113-116`) is `f.c.camera.value = paletteCamera;`; `await tester.tap(find.byKey(const Key('tool-text'))); await tester.pump();` (`:134-135`) becomes `f.c.selectTool('plan.text'); await tester.pump();` (the palette is Task 16's).
  2. **`test/canvas/dark_canvas_test.dart`** from `floor_plan/test/dark_canvas_test.dart`: every test of the design mode (`:83-223`). The `for (final viewMode in FloorPlanMode.values)` loop and its `group` (`:81-82`, `:224-225`) are dropped (the selection mode is 2b's); each test runs once. Adaptations:
     - `controllerOn` (`:32-49`) becomes:

```dart
PlanController controllerOn(int paper) => paletteController(
    paper: paper,
    extra: (doc) {
      for (final (y, rgb) in [(wallY, 0x000000), (finishY, 0xBBBBBB)]) {
        doc.commands.execute(AddEntityCommand(
          record: draftRecord(
              doc.handleSeed.next(), doc.rootHandle, EntityKind.line,
              layer: ReservedHandles.layerZero, color: TrueColor(rgb)),
          payload: linePayload(Vector2(lineX0, y), Vector2(lineX1, y)),
        ));
      }
    }).c;
```

     - `pumpView` (`:51-60`) takes `PlanController c` and loses its `viewMode` parameter and the `c.setMode` call; it pumps `Scaffold(body: PlanCanvas(controller: c))` and sets `c.camera.value = paletteCamera`. The two `pumpThemed(tester, Scaffold(body: FloorPlanView(controller: c)), …)` calls (`:145`, `:153`) pump `Scaffold(body: PlanCanvas(controller: c))`.
     - `PlannerView` becomes `PlanCanvasView`; `c.activeDocument` becomes `c.document`.
  3. **`test/canvas/theme_canvas_test.dart`** from `floor_plan/test/host/theme_canvas_test.dart` (Task 9 hands it to this task): the premise test (`:177-191`), and the design-mode run of `P-6` (`:217-229`), `M-H33(the editor's selection)` (`:231-250`), `selectionOnDark on the dark canvas` (`:252-262`), `only selectionOnLight` (`:264-282`), `selectionWidth: 4` (`:284-307`), `M-H33(canvasBackground)` (`:309-327`), `the guide` (`:329-352`), `T2-d` (`:354-374`), and `T2-a` (`:404-429`), `a bare PlannerShell reads the ambient extension` (`:431-455`), `R-1` (`:457-474`). Not ported: `paperPaletteFor` (`:193-215`, Task 9's TH18 ports it over `planPaperPaletteFor`), `invariant 4` (`:376-402`, the export and `designJson`: Tasks 19 and 20). The `for (final viewMode in FloorPlanMode.values)` loops (`:213`, `:456`) are dropped (the selection mode is 2b's); each test runs once, named without the `($m)` suffix. Adaptations:
     - `FloorPlanTheme` becomes `PlanTheme`; `fullTheme` (`:38-56`, used only by invariant 4) is dropped.
     - `controllerOn(paper)` (`:58-70`) becomes `paletteController(paper: paper)`.
     - `withExtension` and `pumpHome` (`:72-88`) take `PlanTheme? ambient`.
     - `viewOf(c, {theme, onExport})` (`:90-93`) becomes `Widget viewOf(PlanController c, {PlanTheme? theme}) => Scaffold(body: PlanThemeScope(view: theme, child: PlanCanvas(controller: c)));` (Task 9's `PlanThemeScope`, `lib/src/theme/plan_theme.dart`: the view's theme over the ambient one, as `FloorPlanView(theme:)` resolved it; `PlanEditor(theme:)` is Task 20's).
     - `pumpView` (`:95-115`) loses `viewMode` and `onExport`, the `setMode` call and the `ServiceView` expectation; `v.c.cameraController` becomes `v.c.camera`, `v.c.activeSelection` becomes `v.c.selection`.
     - `PlannerView` becomes `PlanCanvasView` (in `overlayOf` and the tests).
     - The bare-shell test: `pumpHome(tester, PlannerShell(document: f.doc), …)` becomes `pumpHome(tester, Scaffold(body: PlanCanvas(controller: f.c)), …)` over `final f = paletteController(paper: null);` (no `PlanThemeScope`: the canvas reads the ambient extension through `PlanTheme.of`); `view.camera` and `view.selection` become `f.c.camera` and `f.c.selection`.
  4. **`test/canvas/canvas_palette_test.dart`** from `floor_plan/test/planner_palette_test.dart`: every test (`:59-241`). Adaptations: `pumpShell` (`:27-37`) becomes `Future<PlanCanvasView> pumpShell(WidgetTester tester, PlanController c, Handle selected, ThemeMode mode)`, which pumps `Scaffold(body: PlanCanvas(controller: c))` through `windowAt` and `pumpThemed`, then sets `c.camera.value = paletteCamera` and `c.selection.replace([SelectionKey.root(selected)])`, and returns `tester.widget<PlanCanvasView>(find.byType(PlanCanvasView))`; `switchTheme` (`:41-45`) pumps the same `Scaffold(body: PlanCanvas(controller: c))`; each test's `final m = FlutterTextMeasurer(); addTearDown(m.clear); final f = paletteDoc(m, paper: …);` becomes `final f = paletteController(paper: …);`, the calls `pumpShell(tester, f.doc, …)` and `switchTheme(tester, f.doc, …)` pass `f.c`, and every other `f.doc` becomes `f.c.document`; `inkArgb(tester, f.doc, f.ink)` reads `f.c.document`; the `paper(argb)` helper (`:163-167`) executes on `f.c.document`.
  5. **`test/canvas/canvas_draw_test.dart`** from `floor_plan/test/planner_draw_test.dart`: `A7` (`:209-236`), `A17` (`:468-505`), `A20` (`:623-662`), `A21` (`:664-687`), `A22` (`:689-698`), and the local helpers they use, `draftLine` and `argbOnCanvas` (`:591-614`). The others move with the palette and the keys (Task 16) or with the page panel (Tasks 18 and 20). Adaptations:
     - `final view = await pumpDraw(tester, drawDoc(FlutterTextMeasurer()).doc);` becomes `final c = drawController().c; await pumpDraw(tester, c);`; `view.document` becomes `c.document`; `view.camera` becomes `c.camera`; `globalOf(tester, view, …)` becomes `globalOf(tester, c, …)`; `draftLine(tester, view)` becomes `draftLine(tester, c)`.
     - A key press that arms a tool becomes the controller's call and a pump (the keyboard is Task 16's): `press(tester, LogicalKeyboardKey.keyT)` (`A7`) becomes `c.selectTool('plan.text'); await tester.pump();`; `press(tester, LogicalKeyboardKey.keyL)` (`:474`, `:594`) becomes `c.selectTool('plan.line'); await tester.pump();`; the Escape that ends the drafted line (`:479`, `:599`) becomes `c.selectTool('plan.select'); await tester.pump();` (arming select cancels the line tool, which keeps its committed segment, as Escape did).
     - `A7`: `view.tools.active as TextTool` (`:217`) becomes `c.textTool`.
     - `A17`: the two `markNeedsBuild` lines (`:499-500`) name `PlanCanvas` and `PlanCanvasView`.
     - `A20`: `await tapSwatch(tester, 3);` (`:636`) and `await tapSwatch(tester, 1);` (`:657`) become the page edit the swatch made, on the controller's document: `doc.commands.execute(SetComponentCommand<PageComponent>(doc.rootHandle, page().copyWith(background: 0xFF1F3A5F))); await tester.pump();` and the same with `0xFFFAF6EC` (Ivory). The page panel is Task 18's.
     - `A21`: `drawDoc(…)` and its Blueprint edit (`:667-673`) become `final c = drawController(background: 0xFF1F3A5F).c; final doc = c.document;` and `pumpDraw(tester, c)`.
     - `A22`: `DraftDocument.empty(…)` (`:693`) becomes `final c = pagelessController(); final doc = c.document;` and `pumpDraw(tester, c)`.
  6. **`test/canvas/touch_tools_test.dart`** from `floor_plan/test/touch_tools_test.dart`: `TD2` (`:94-112`) and the helpers `finger`, `pinch` (`:37-67`). Not ported: `TD1` (the Room tool: sub-project 3). Adaptations: the fixture is `drawController()` in place of `samplePlan()` (no walls are needed for a polyline), pumped with `pumpDraw`; `press(tester, LogicalKeyboardKey.keyP)` becomes `c.selectTool('plan.polyline'); await tester.pump();`; the three points move onto the drawing fixture's sheet: `(17800.5, 9200.25)` → `(7010.5, 3020.25)`, `(19600.5, 10400.25)` → `(7060.5, 3090.25)`, the pinch's `(18600.5, 9600.25)` → `(7035.5, 3055.25)`; `screenOf(tester, view, p)` becomes `globalOf(tester, c, p.x, p.y)`; `view.tools.active` becomes `c.toolController.active` (the identity and `isMidShape` are read through Task 11's decorator, which forwards `isMidShape`).

  7. **`test/canvas/canvas_layout_test.dart`** from `floor_plan/test/planner_shell_test.dart`: the canvas cases `the camera is fitted to the page at the drawing area's size` (`:140-155`), `the page chrome and the rulers are in the tree, under the canvas` (`:157-169`), `a resize after the first layout does not re-fit the camera` (`:202-220`) and `the interaction tree is in place` (`:249-261`). The other cases there are the shell's bar and status line (Task 20) or the sample flat's walls, rooms and dimensions (sub-project 3); its only key case, "cmd+Z undoes a Delete", deletes a wall (sub-project 3; Task 16's ported `A11` keeps the generic Undo). Adaptations: `pumpSample(tester)` becomes `final c = paletteController(paper: white).c; await tester.pumpWidget(MaterialApp(home: Scaffold(body: PlanCanvas(controller: c))));` (the palette fixture's page is off the origin and its extents, the two lines, are not the page, so the page fit and the extents fit differ as the sample's did); `view.document` becomes `c.document`, `view.camera` becomes `c.camera`. The fixture premise `expect(view.document.entities.liveCount, greaterThanOrEqualTo(500))` (`:168`, the sample flat's size) goes with the sample; no behaviour assertion changes.
  8. **`test/canvas/canvas_camera_test.dart`** from `floor_plan/test/host/camera_test.dart`: CM5's second half (`:226-228`), which Task 8 sent here (it needs a mounted view): Task 8's first half (`:218-225`) repeated as its premise (`cameraController` → `camera`, the controller over `slabPlanText()`), then `mount` (`:47-…`) → pumping `PlanCanvas(controller: c)` in a `MaterialApp` at the source's surface size, and `pageFitOf(c)` (`:105-…`) → `fitToPage(<c's page>, <the canvas's size>)` as `plan_canvas_test.dart`'s `pageFit` reads it; the `fitToTables` half (`:230-239`) is 2b's. Assertions unchanged (controller ruling R-m).

- [ ] **Step 15: Run the ported tests.** Run: `cd packages/jet_cad_2d_plan && flutter test test/canvas`. Expected: `All tests passed!`. A ported test that fails on an assertion is a finding (Global Constraints): stop and report it with the failing line; never change the assertion.

- [ ] **Step 16: Format and the gate.** `cd packages/jet_cad_2d_plan && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — each exits 0. `git status --short` lists only this task's files.

- [ ] **Step 17: Commit.**

```bash
git add packages/jet_cad_2d_plan/lib/src/canvas/plan_canvas.dart packages/jet_cad_2d_plan/lib/src/canvas/plan_canvas_view.dart packages/jet_cad_2d_plan/lib/src/canvas/text_entry_overlay.dart packages/jet_cad_2d_plan/lib/src/shortcuts/chords.dart packages/jet_cad_2d_plan/lib/src/shortcuts/plan_shortcut_guard.dart packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart packages/jet_cad_2d_plan/test/support/canvas_fixture.dart packages/jet_cad_2d_plan/test/canvas/plan_canvas_test.dart packages/jet_cad_2d_plan/test/invariants/canvas_paint_allocation_test.dart packages/jet_cad_2d_plan/test/canvas/canvas_ui_test.dart packages/jet_cad_2d_plan/test/canvas/dark_canvas_test.dart packages/jet_cad_2d_plan/test/canvas/theme_canvas_test.dart packages/jet_cad_2d_plan/test/canvas/canvas_palette_test.dart packages/jet_cad_2d_plan/test/canvas/canvas_draw_test.dart packages/jet_cad_2d_plan/test/canvas/touch_tools_test.dart packages/jet_cad_2d_plan/test/canvas/canvas_layout_test.dart packages/jet_cad_2d_plan/test/canvas/canvas_camera_test.dart packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart
git commit -m "$(cat <<'EOF'
feat(plan): PlanCanvas and its paint-allocation invariant (P2)

The canvas takes only a controller: the rulers, the camera gestures,
the interaction layer, the page chrome, the drawing, the selection and
grip overlay and the text entry, ported from the planner's view. It
owns the paper, the ink and the resolver, fits each plan on its first
frame, follows a document swap, shows a controller in one canvas at a
time, pushes the locale, carries the rulers, grid and snapping options
and shows the lock hint. The shortcut guard lands here, over the
letters in use. A rebuilt steady-state frame keeps the painter, the
sink and its capacity.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 18: Mutation check** (on the committed files; after each: run the named test, quote its red line, `git checkout -- <file>`, `git diff --quiet -- <file>` exits 0):
  - M-CV-1 `lib/src/canvas/plan_canvas.dart`: `fitOnStart: _fitOnStartFor(document),` → `fitOnStart: false,` → CV-1 red (the camera stays nominal).
  - M-CV-2a `plan_canvas.dart`: `shown.length > 1` → `shown.length > 2` → CV-2 red (no error for two canvases).
  - M-CV-2b `plan_canvas.dart`: delete `_leave(_c);` from `dispose` → CV-2 red (the Column step asserts).
  - M-CV-3 `plan_canvas.dart`: delete `_c.addListener(_onController);` from `initState` → CV-3 red (the canvas keeps the old document).
  - M-CV-4a `plan_canvas.dart`: `builder: (context, shown, _) => shown` → `builder: (context, shown, _) => false` → CV-4 red.
  - M-CV-4b `plan_canvas.dart`: delete the `_hintTimer = Timer(…);` statement → CV-4 red (`lockHint` stays true).
  - M-CV-5 `plan_canvas.dart`: `rulers: widget.rulers,` → `rulers: true,` → CV-5 red.
  - M-CV-6a `plan_canvas.dart`: delete `_c.snappingAllowed = widget.snapping;` from `initState` → CV-6 red; M-CV-6b: delete it from `didUpdateWidget` → CV-6 red.
  - M-CV-7 `plan_canvas.dart`: delete `PlanLocaleScope.push(context, _c);` from `didChangeDependencies` → CV-7 red.
  - M-CV-alloc-1 `plan_canvas.dart`: `resolver: _resolver,` → `resolver: canvasResolverFor(document, paper: paper, dark: _darkCanvas),` → CV-alloc red ("a new painter").
  - M-CV-alloc-2 `plan_canvas.dart`: `key: ObjectKey(document),` → `key: UniqueKey(),` → CV-alloc red ("remounted").
  - M-DC-3 (the ported dark-canvas mutant) `plan_canvas.dart`: in `_paperArgb`, `displayPaperFor(…)` → `_c.page.value?.background ?? _surfaceArgb` → `dark_canvas_test.dart`'s "dark theme on White" red.
  - M-DT-12 `lib/src/canvas/text_entry_overlay.dart`: delete `filled: true,` → `canvas_ui_test.dart`'s `M-DT-12` red.

#### Assumed from earlier tasks

Each name below is used as written; where the earlier task named it otherwise, the implementer uses that task's name and reports the difference.
- Task 7 (`lib/src/file/plan_file.dart`): `String ensureManifest(String text)`; `PlanController(json:)` accepts its output.
- Task 8 (`lib/src/controller/plan_controller.dart`): `PlanController` is a `ChangeNotifier` that notifies after `load`, `newPlan` and `import` swap the document (with `document`, `page`, `selection`, `toolController`, `grips` and `outlines` already naming the new document's); `void dispose()`; `void load(String json)`; documents are made with a `FlutterTextMeasurer` (`DraftCanvas` requires one, `draft_canvas.dart:267-279`); `DraftDocument get document`; `SpatialIndex get index`; `CameraController get camera` (with `minScale`, `maxScale` from the constructor's bounds); `PageNotifier get page`; `SelectionController get selection`; `OutlineCache get outlines`; `GripCache get grips`; `SnapSettings get snap` (the user's F3 setting); `bool snappingAllowed` (`@internal`, the canvas's `snapping` option, read by Task 8's `EffectiveSnap`); `ValueListenable<Locale> get locale` with `@internal reportLocale(Locale, {PlanStrings? strings})` (Task 9 adds `strings:`); `bool selectTool(String id)`; and today's camera plumbing (`floor_plan/lib/src/host/floor_plan_controller.dart:472-499`, `:812-852`) under today's names, `@internal`: `Listenable get fitRequests`, `int get cameraEpoch`, `bool takeFitOnStart()`, `bool get owesFirstFit`, `void fitted()`, `ViewportTransform? framingFor(Size viewport)`, `void canvasPlaced(Object view, Rect? global)`; `load` and `newPlan` set the fit-on-start latch as today (`floor_plan_controller.dart:815-831`). Step 5 adds `textTool`.
- Task 9: `PlanStrings` (`lib/src/l10n/strings.dart`) with `PlanStrings.of(BuildContext)` (English without a delegate) and the word `lockedHint` ('This object is locked' in English); `PlanLocaleScope.push(BuildContext, PlanController)` (`lib/src/l10n/locale_scope.dart`), which reports `Localizations.maybeLocaleOf(context)` through `controller.reportLocale` after the frame; `PlanTheme.of(BuildContext)` returning `PlanTheme?` (`lib/src/theme/plan_theme.dart`) with nullable `canvasBackground`, `selectionOnLight`, `selectionOnDark`, `selectionWidth`, resolving a `PlanThemeScope` above, else the ambient `ThemeData` extension (today's `FloorPlanThemeScope.of`, `floor_plan/lib/src/host/floor_plan_theme.dart:465-472`); `PlanThemeScope({PlanTheme? view, required Widget child})`; `PaperPalette planPaperPaletteFor(int paperArgb, PlanTheme? theme)`. `flutter_localizations` is a dependency of `jet_cad_2d_plan` (Task 9 adds it).
- Task 11 (`lib/src/kits/guard.dart`): `ValueNotifier<bool> PlanController.lockHint`; `GuardedTool` with `Tool get inner` (the decorated tool) that forwards `isMidShape`.
- Task 12: `ToolController get toolController` (`@internal`), whose `context.snap` is what the tools read; `const List<GenericTool> genericTools` with `String letter` (`lib/src/tools/generic_tools.dart`); `PlanToolIds`; the per-document `GenericToolSet` at `DocumentSession.generic` (read through `_session`) with `byId`.

#### Interface problem

Resolved: 1 by controller ruling R-l (the guard, the chords and `planLetterKeys` land here; Task 16 widens `planLetterKeys`; Task 13's gallery field, which lands earlier, stops typed keys itself and is not re-wrapped); 2 by Task 8's Produces, which lists every `@internal` camera and view member named above under today's names; 3 by Task 8's `@internal bool snappingAllowed` and `EffectiveSnap` (this task writes it, Step 5).

---

