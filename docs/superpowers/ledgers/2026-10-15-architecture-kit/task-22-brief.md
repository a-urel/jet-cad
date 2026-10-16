### Task 22: The dimension tool and its notice (spec C3.6, C1.2, C1.5, C7)

**Files** (paths under `packages/jet_cad_2d_kit_architecture/` unless they say otherwise):
- Create: `lib/src/dimension/dimension_tool.dart` (ported, adapted)
- Modify: `lib/src/dimension/dimension_plan.dart` (`dimensionPlanTool`), `lib/src/kit.dart` (`dimensionPlanTool` in `tools`)
- Test (ported, kit): `test/dimension/dimension_tool_test.dart`
- Test (new, kit): `test/dimension/dimension_notice_test.dart` (DT-notice, DT-plan-tool)
- Modify (integration): `packages/jet_cad_2d_integration/test/dimension/dimension_plans.dart` (the sample walls and the tool helpers)
- Test (ported, integration): `packages/jet_cad_2d_integration/test/dimension/dimension_tool_test.dart`

**Interfaces:**
- Consumes:
  - Task 20: `attachCandidates(..., {required LiveTypeOf live, ...})`, `thickestWall(doc, live)`, `decideEnd`, `WallPoints`, `debugLineTestPasses`; `DimensionParams`, `DimKind`, `DimEnd`, `AttachedEnd`, `FixedEnd`, `WallSide`, `offsetFor`, `layoutDimension`, `wallEndPoints` (`dimension.dart`); the fixture's `liveOf`.
  - Task 21: `dimensionPlanType`, `dimension_plan.dart`; the integration support `dimension_plans.dart` (`W`, `S`, `O`, `Placement`, `origin`, `corpusGroups`, `buildPlanIn`, `planOf`, `setPage`, `addDimension`, `kids`, `kindOf`, `dimText`, `kitCatalog`, `pumpPlan`, `select`, `byKey`).
  - Task 9: `ArchitectureTools.dimension`, `ArchitectureTypes.dimension`, `LiveTypeOf`, `liveTypesOf`, `architectureKit` (`tools:`), `architectureNames`; the words `tool:architecture.dimension` (`Dimension` / `Bemaßung` / `Ölçü`) and `text:architecture.dimension-value` = `{value}` in every locale (the value is a number in the page's unit and separator, Q0, so no language adds to it).
  - Task 4 (C1.2): `abstract interface class ToolNotice { ValueListenable<KitText?> get notice; }`; `PlanController.toolNotice`, `PlanController.textOf(KitText)`; `PlanEditor`'s status line `label — n selected — notice` (key `status-text`, `plan_editor.dart:593-595`).
  - Task 3 (C1.6): `KitText(id, args)` with `==` by value; `KitWords.text`.
  - Task 6: `FakePlanServices` (`package:jet_cad_2d_kit/testing.dart`).
  - Flutter layer: `PlacementTool` (`jet_cad_2d_flutter/lib/src/draw/placement_tool.dart`: `points`, `hoverPoint`, `hoverKind`, `onKey` Esc → `cancel`, Enter → `finish`, `:177-210`), `ToolContext`, `CameraController`, `SelectionController`, `SnapSettings`, `PageNotifier`, `InteractionLayer`, `kPreviewStrokePixels`, `PaperPalette`; engine `kSnapAperturePixels`, `dragGridStepMm` (`jet_cad_2d/lib/src/index/drag_snap.dart:14, :98`).
  - Plan library (public): `PlanController.activeTool` (`ValueListenable<String>`), `selectTool`, `camera`, `document`; the palette's row keys `tool-<tool id>` (`plan_tool_palette.dart:108`).
- Produces:
  - `final PlanTool dimensionPlanTool` (`lib/src/dimension/dimension_plan.dart`, Shared interfaces): id `ArchitectureTools.dimension`, letter `I`, no settings, `needs` the commit's `{structure, components, geometry}`.
  - Kit-internal: `class DimensionTool extends PlacementTool implements ToolNotice` with `DimensionTool({required LiveTypeOf live})`, `@override ValueListenable<KitText?> get notice`, `@visibleForTesting String? get debugValue`, and today's `kAttachRingPixels`, `kindFor`, `debugAttachSearches`, `debugPreviewBuilds`, `debugPreview`, `debugPreviewKind` unchanged.
  - `architectureKit.tools` gains `dimensionPlanTool`, last (today's palette order box, wall, door, window, gap, room, separator, dimension: `planner_shell.dart:547-601`).

**Appendix A rows closed:** D-19's dimension part: `dimension_tool_test` (11: TL1, TL2, TL3, TL5 ×2, TL6, TL8, M-DT-8 to the kit; TL4, TL5's status-line case, TL7 to integration, TL4 and TL5's status-line case each with a kit twin, ruling DT-R1). D-27's dimension half (the Dimension tool's status notice: the tool's `ToolNotice` here, the status line `Dimension — 4.69` through `PlanEditor` in TL5). `dimension_shell_test` (3: SL1, SL2, TL9) runs on the sample flat and is carried to Task 26 (ruling R-P5; `#### Interface problem` 1, with its port; Task 26's Step 9 item 11). After this task and Task 25's carried ports, every one of the fourteen dimension files is closed.

**C7 placement, per case** (source `packages/jet_cad_floor_plan/test/dimension_tool_test.dart`):
- kit: TL1 (`:250`), TL2 (`:423`), TL3 (`:532`), TL6 (`:717`), TL5 "the preview's five lines…" (`:882`), TL5 "on a 1:100 ft-in page…" (`:1147`), TL8 (`:1420`), M-DT-8 (`:1607`): each drives a `DimensionTool` over a `ToolContext` built from the Flutter layer (`dimRig`, `:50-80`) and asserts its state.
- integration: TL4 (`:572`), TL5 "the status line reads Dimension — 4.69…" (`:1357`), TL7 (`:843`): each pumps `PlannerShell` and reads its status line, keys or palette; they map to `PlanEditor` over a `PlanController` with the kit.
- `dimension_shell_test.dart`: SL1, SL2, TL9 → integration, carried to Task 26 (ruling R-P5).

**R-P1 check:** TL4 and TL5's status-line case need both a plan widget (`PlanEditor`'s status line, keys, palette) and kit internals (the tool's state, `attachCandidates`), so they are split per R-P1 (DT-R1): the integration halves use public libraries only (`PlanController.activeTool`, `toolNotice`, `textOf`, `activeSelection`, `camera`, the kit's barrel); the kit twins TL4k and TL5k hold the internal reads. TL7 needs no kit internal and runs whole in integration. No plan-internal helper is needed, so no `place_entry.dart` fixture is used.

**Plan rulings (this task; the controller confirms them before execution):**
- **DT-R1 (TL4 and TL5's status-line case are split).** Both read the kit tool's own state through `view.tools.active as DimensionTool` (`tool.points`, `tool.hoverKind`, `tool.hoverPoint`, `tool.notice`) and kit internals (`attachCandidates`, `thickestWall`, `SpatialIndex` premises, `:686-708`). The integration package sees neither: the plan holds the tool behind `GuardedTool` and `toolController` is `@internal` (`plan_controller.dart:2099-2100`), and the tool class is under the kit's `src/` (C6: public libraries only). So each case runs twice, every assertion kept once: in integration (TL4, TL5) every line that reads the plan's public surface (the status line, the keys, the palette, the document, the undo depth, `c.toolNotice` put into words, `c.activeTool`); in the kit (TL4k, TL5k, below) the same clicks over a `dimRig` with every line that reads the tool's state or a kit internal, the Esc and Enter keys sent to the tool's `onKey` (what the shell's focus routed to it). Lines that read only the shell (the second Esc back to Select, the status text) have no kit twin; lines that read only the tool have no integration twin.
- **DT-R2 (TL7, TL4).** `expect(view.tools.active, isA<DimensionTool>())` and its negation read the active tool through the plan's public id: `expect(c.activeTool.value, ArchitectureTools.dimension)` (a name change, C7 1).
- **DT-R3 (TL5's status-line case, one premise line).** `expect(tester.getSize(find.byType(InteractionLayer)).width, 896)` (`:1371`) pins the shell's canvas width in a 1440 px window; `PlanEditor`'s columns differ. The premise it stands for ("the pair spans 4,690 × 0.12 = 563 px, inside the canvas", `:1368-1370`) is asserted instead: `greaterThan(4690 * 0.12)`.
- **DT-R4 (every kit case reading the notice).** Today's notice is a `ValueListenable<String?>` holding the TEXT's string (`dimension_tool.dart:136, :165-167`); under C1.2 it is a `ValueListenable<KitText?>` (`text:architecture.dimension-value` with `{value}`). The ported kit lines `rig.tool.notice.value` / `tool.notice.value` read the same string through `debugValue` (`:948, :968, :1180, :1211, :1216, :1237, :1253, :1256, :1570`): the asserted strings (`'4.69'`, `'6.63'`, `'6633'`, `'3.00'`, `isNull`, `isNotNull`) are unchanged. DT-notice (new) pins the `KitText` itself. In integration the plan reads it: `noticeText(c)` is `c.textOf(c.toolNotice.value!)`.
- **Fixture change (TL4, TL5 in integration).** Today's TL4 document has no page, so the tool has no grid (`:579-585`); the plan's new plan always has one (2a `newPlanDocument`), so the build sets `PageComponent(snapToGrid: false)`, the same for the tool (`placement_tool.dart:130`: no grid step without `snapToGrid`). TL5 already set exactly that page (`:1366`). TL7's `startupPlan` becomes the sample's walls, column, separator and openings at the origin (`room_fixture.dart:360-417`, the startup plan's own, spec 08 D18) with one room named `Hall` at its seed (`:405-406`): TL7 reads only the status line, the palette and the Hall's name field.

#### Assumed from earlier tasks

Each name below is used as written; where the earlier task named it otherwise, use that task's name and report the difference.
- Task 4: `PlanController.toolNotice` reflects the active **guarded** tool's notice (`GuardedTool.notice` forwarding the inner `ToolNotice`), and `textOf` reads host words first, then the kit named by the id (`text:architecture.…` → `architecture`).
- Task 18: the room's name field is `TextProperty` id `name` (`Key('property-name')`) and a room is `RoomParams(seedX, seedY, name)` (public through the barrel).
- Task 9's palette keys: `tool-plan.select` for Select and the letter `V` for it (2a's generic letters, `tool_letters.dart:1-7`), `tool-architecture.dimension` for the kit's row.

- [ ] **Step 1: Precondition.** Task 21 is committed. `cd packages/jet_cad_2d_kit_architecture && flutter test && flutter analyze` and `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice && flutter analyze`: all green. Read `packages/jet_cad_2d_kit/lib/src/kit/plan_tool.dart` (Task 4's `ToolNotice`) and `packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart` (`toolNotice`, `textOf`).

- [ ] **Step 2: The failing kit tests (new).** Create `test/dimension/dimension_notice_test.dart`:

```dart
// 3a Task 22, spec C1.2, C1.5, C3.6: the Dimension tool's notice is a word
// id and its argument (text:architecture.dimension-value, {value}), the
// value exactly the TEXT the commit draws, put into words by the plan; and
// the plan tool's declaration, whose tool reads the plan's live types (a
// frozen wall attaches nothing). Fixture: C2's L at the corpus far origin,
// every wall in its own turned group, on a 1:50 page in metres, grid snap
// off.
import 'dart:ui' show Locale, Offset;

import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_kit/testing.dart';
import 'package:jet_cad_2d_kit_architecture/src/dimension/dimension.dart';
import 'package:jet_cad_2d_kit_architecture/src/dimension/dimension_plan.dart';
import 'package:jet_cad_2d_kit_architecture/src/dimension/dimension_tool.dart';
import 'package:jet_cad_2d_kit_architecture/src/ids.dart';
import 'package:jet_cad_2d_kit_architecture/src/words/words.dart'
    show architectureNames;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/dimension_fixture.dart';

const l = WallSide.left;

/// A ToolContext over [doc] at 0.3 px/mm (aperture 33.3 mm), F3 on, the
/// document's page (TL's `dimRig`, dimension_tool_test.dart:50-80).
ToolContext contextOf(DraftDocument doc) {
  final index = SpatialIndex(doc);
  final camera = CameraController(
      ViewportTransform(worldToScreenMatrix: Transform2.scale(0.3, 0.3)));
  final selection = SelectionController(doc);
  final snap = SnapSettings();
  final page = PageNotifier(doc);
  addTearDown(() {
    page.dispose();
    snap.dispose();
    selection.dispose();
    camera.dispose();
    index.dispose();
  });
  return ToolContext(
      document: doc,
      index: index,
      camera: camera,
      selection: selection,
      page: page,
      snap: snap);
}

ToolPointerEvent eventAt(Vector2 world, {int buttons = 0}) =>
    ToolPointerEvent(
        screen: Offset.zero,
        world: world,
        pointer: 1,
        buttons: buttons,
        shift: false,
        control: false,
        meta: false,
        alt: false,
        pickRadiusWorld: 1);

void hover(Tool tool, ToolContext ctx, Vector2 w) =>
    tool.onPointerMove(eventAt(w), ctx);

void click(Tool tool, ToolContext ctx, Vector2 w) {
  hover(tool, ctx, w);
  tool.onPointerDown(eventAt(w, buttons: kPrimaryButton), ctx);
}

/// C2's L at the corpus far origin in own groups; a 1:50 page in metres,
/// no grid snap.
Plan lPlan() {
  final plan = buildPlan(c2Walls, place: corpusGroups);
  attachPage(plan.doc, PageComponent(snapToGrid: false));
  return plan;
}

List<Handle> dimsOf(DraftDocument doc) =>
    doc.components.withComponent<DimensionParams>().toList();

void main() {
  test(
      'DT-notice the notice is text:architecture.dimension-value with the '
      'value the commit draws; every language words it alike; null after '
      'the commit (M-DT1, M-DT2)', () {
    final plan = lPlan();
    final doc = plan.doc;
    final tool = DimensionTool(live: liveOf(doc));
    addTearDown(tool.dispose);
    final ctx = contextOf(doc);
    expect(tool, isA<ToolNotice>());
    // Two free points 4,690 mm apart along the placement's x, clear of
    // both walls (B's faces at x 3,900-4,100 in the plan), and a third
    // 900.25 above them: aligned, 4,690 mm, 4.69 in metres.
    click(tool, ctx, plan.at(1000.25, 1500.5));
    click(tool, ctx, plan.at(5690.25, 1500.5));
    hover(tool, ctx, plan.at(3000.5, 2400.75));
    expect(tool.notice.value,
        const KitText('text:architecture.dimension-value', {'value': '4.69'}));
    final notice = tool.notice.value!;
    for (final language in const ['en', 'de', 'tr']) {
      expect(
          KitNamesWords(architectureNames, () => Locale(language))
              .text(notice.id, notice.args),
          '4.69',
          reason: language);
    }
    click(tool, ctx, plan.at(3000.5, 2400.75));
    expect(dimText(doc, dimsOf(doc).single), '4.69', reason: 'the commit');
    expect(tool.notice.value, isNull, reason: 'after the commit');
  });

  test(
      'DT-plan-tool letter I, the commit\'s needs, no settings; the tool it '
      'makes reads the services\' live types: a frozen wall fixes the end '
      '(M-DT3, M-DT4)', () {
    expect(dimensionPlanTool.id, ArchitectureTools.dimension);
    expect(dimensionPlanTool.letter, 'I');
    expect(dimensionPlanTool.needs,
        {Capability.structure, Capability.components, Capability.geometry});
    expect(dimensionPlanTool.settings, isNull);

    final plan = lPlan();
    final doc = plan.doc;
    final [a, _] = plan.walls;
    // The first click on A's free start's left corner (0, 100), A/0/left
    // alone (GE3's premise); the others free.
    DimEnd firstEnd(Set<Handle> frozen) {
      final s = FakePlanServices(
          document: doc, catalog: testCatalog(), frozen: frozen);
      addTearDown(s.dispose);
      final tool = dimensionPlanTool.create(s);
      addTearDown(tool.dispose);
      final ctx = contextOf(doc);
      final before = dimsOf(doc).toSet();
      click(tool, ctx, plan.at(0, 100));
      click(tool, ctx, plan.at(2500.75, 1800.25));
      click(tool, ctx, plan.at(1200.5, 2600.25));
      final d = dimsOf(doc).singleWhere((h) => !before.contains(h));
      return doc.components.get<DimensionParams>(d)!.a;
    }

    expect(firstEnd(const {}), AttachedEnd(a, 0, l), reason: 'control');
    expect(firstEnd({a}), isA<FixedEnd>(), reason: 'A frozen');
  });
}
```

  Run: `cd packages/jet_cad_2d_kit_architecture && flutter test test/dimension/dimension_notice_test.dart`. Expected: compile failure (`dimension_tool.dart` does not exist; `dimensionPlanTool` undefined).

- [ ] **Step 3: Port the tool.** Create `lib/src/dimension/dimension_tool.dart` from `packages/jet_cad_floor_plan/lib/src/parametric/dimension_tool.dart`:
  - lines 1-18 (imports) become:
    ```dart
    // The Dimension tool (spec 11 D12), moved from jet_cad_floor_plan (3a
    // spec C3.6): the live walls are the plan's (C1.5), and the would-be
    // value is a ToolNotice (C1.2) the plan's status line puts into words.
    import 'dart:async' show StreamSubscription, unawaited;
    import 'dart:math' as math;
    import 'dart:typed_data' show Float64List;
    import 'dart:ui' show Canvas, Offset, Paint, PaintingStyle, Size;

    import 'package:flutter/foundation.dart'
        show ValueListenable, ValueNotifier, visibleForTesting;
    import 'package:flutter/services.dart'
        show KeyDownEvent, KeyEvent, KeyRepeatEvent, LogicalKeyboardKey;
    import 'package:flutter/widgets.dart' show KeyEventResult;
    import 'package:jet_cad_2d/jet_cad_2d.dart';
    import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
    import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show KitText, ToolNotice;
    import 'package:vector_math/vector_math_64.dart' show Vector2;

    import '../live.dart';
    import '../wall/wall.dart' show wallJoin;
    import '../wall/wall_geometry.dart' show wallsInDocument;
    import 'dimension.dart';
    import 'dimension_attach.dart';
    ```
  - copy lines 19-29 unchanged, then add:
    ```dart
    /// The notice's word (spec 3a C1.2, C1.6): its one argument, `value`, is
    /// the would-be TEXT's string.
    const String _kValueText = 'text:architecture.dimension-value';
    ```
  - copy lines 30-72 unchanged; lines 73-76 (the notice paragraph) become:
    ```dart
    /// **The notice** ([notice], spec 3a C1.2): while two points are placed,
    /// `text:architecture.dimension-value` with `value` exactly the TEXT's
    /// string in the page's unit and separator (`4.69`); the plan's status
    /// line appends it in words (`Dimension — 4.69`, S-8). Null otherwise:
    /// after the commit, on Esc and on deactivation.
    ```
  - copy lines 77-87 unchanged; lines 88-89 become:
    ```dart
    class DimensionTool extends PlacementTool implements ToolNotice {
      DimensionTool({required this.live});

      /// The plan's live types (spec 3a C1.5): which walls an end attaches
      /// to and reads its point from.
      final LiveTypeOf live;
    ```
  - copy lines 90-135 unchanged; line 136 becomes `  final ValueNotifier<KitText?> _notice = ValueNotifier<KitText?>(null);`
  - copy lines 137-164 unchanged; lines 165-167 become:
    ```dart
      /// The would-be value while two points are placed (spec 11 D12, S-8;
      /// spec 3a C1.2), as a word id and its argument; null otherwise. The
      /// plan's status line appends it in words.
      @override
      ValueListenable<KitText?> get notice => _notice;

      /// The notice's `value`, or null without a notice: today's
      /// `notice.value` string, which the ported tests read (ruling DT-R4).
      @visibleForTesting
      String? get debugValue => _notice.value?.args['value'] as String?;
    ```
  - copy lines 168-243 unchanged; lines 244-246 become:
    ```dart
        debugAttachSearches++;
        return attachCandidates(ctx.document, ctx.index, p,
            live: live, objectSnap: _objectSnap(ctx), thickest: thickest);
    ```
  - line 254 → `    final t = thickestWall(ctx.document, live);`; line 286 → `    final t = thickestWall(doc, live);`; line 369 → `    _thickest = thickestWall(ctx.document, live);`; lines 383-384 → `    return _memo[key] = attachCandidates(ctx.document, ctx.index, p,\n        live: live, objectSnap: true, thickest: _thickest, points: _wallPoints);`; line 463 → `    if (!_disposed) _notice.value = KitText(_kValueText, {'value': l.text});`; line 482 → `      final ws = wallsInDocument(ctx.document, end.wall, live);`;
  - every other line of 247-574 unchanged (the commit's `ObjectLayer(drawingLayer(doc))`, the refusals caught at `:316-322`, `name` `'Dimension'`).

- [ ] **Step 4: The plan tool.** In `lib/src/dimension/dimension_plan.dart` add the imports `import 'package:flutter/material.dart' show Icons;` and `import 'dimension_tool.dart';`, and after `dimensionPlanType`:

```dart
/// The Dimension tool (Shared interfaces, spec C3.6): letter I (today's,
/// `planner_shell.dart:595-601`), no settings, three clicks per dimension
/// (spec 11 D12). Its commit adds a group, its parameters and its layer:
/// `structure`, `components`, `geometry` (`dimension_tool.dart:311-315`).
final PlanTool dimensionPlanTool = PlanTool(
  id: ArchitectureTools.dimension,
  icon: Icons.straighten,
  letter: 'I',
  needs: const {
    Capability.structure,
    Capability.components,
    Capability.geometry,
  },
  create: (s) => DimensionTool(live: liveTypesOf(s)),
);
```

  In `lib/src/kit.dart`: `dimensionPlanTool` appended to `tools` (last, after `separatorPlanTool`; the import of `dimension/dimension_plan.dart` is Task 21's).

- [ ] **Step 5: Port the kit's tool tests.** Create `test/dimension/dimension_tool_test.dart` from `packages/jet_cad_floor_plan/test/dimension_tool_test.dart`, the kit cases (TL1, TL2, TL3, TL6, TL5 `:882`, TL5 `:1147`, TL8, M-DT-8), **assertions unchanged** but for DT-R4, plus the twins TL4k and TL5k (DT-R1):
  - header (`:1-18`): keep, then `// Ported to jet_cad_2d_kit_architecture (3a Task 22): the tool's own\n// cases; TL4, TL7 and TL5's status line run in jet_cad_2d_integration,\n// TL4k and TL5k here carry their tool halves (ruling DT-R1).`
  - imports (`:19-42`): drop `planner_shell.dart`, `planner_view.dart`, `startup_plan.dart`, `room.dart`, `live_objects.dart`, `package:flutter/gestures.dart`'s `PointerDeviceKind` (keep `kPrimaryButton`); `parametric/dimension.dart`, `dimension_attach.dart`, `dimension_tool.dart` → the kit's `src/dimension/`; `opening.dart show OpeningParams` → `src/opening/opening.dart`; `wall.dart` → `src/wall/wall.dart`; add `package:jet_cad_2d_kit_architecture/src/ids.dart` (`testCatalog()` and `liveOf` reach the file through `dimension_fixture.dart`, which exports `room_fixture.dart` and its re-export of `wall_fixture.dart`'s: a second import of them is an `unnecessary_import`, which fails `flutter analyze`); `'support/dimension_fixture.dart'` → `'../support/dimension_fixture.dart'`. `package:flutter/material.dart` and `package:flutter/services.dart` (`KeyDownEvent, KeyUpEvent, LogicalKeyboardKey, PhysicalKeyboardKey`) stay.
  - `dimRig` (`:58`): `final tool = DimensionTool();` → `final tool = DimensionTool(live: liveOf(doc));`.
  - `dims` (`:112`) becomes:
    ```dart
    /// Every live dimension, ascending (today's `liveObjectsOf`, asked of the
    /// kit's test catalog).
    List<Handle> dims(DraftDocument doc) => [
          for (final h in doc.components.withComponent<DimensionParams>())
            if (testCatalog().typeIdOf(doc, h) == ArchitectureTypes.dimension) h,
        ];
    ```
  - delete the shell helpers `status`, `press`, `pumpShell`, `centreOn`, `tapWorld` (`:141-178`) and the shell cases TL4 (`:572-715`), TL7 (`:843-880`), TL5's status-line case (`:1357-1418`).
  - `attachCandidates(...)` (`:350-351, :389-390, :1064-1065, :1121-1122, :1284-1285, :1330-1331`) gain `live: liveOf(<the call's document>),`; `thickestWall(x)` → `thickestWall(x, liveOf(x))`.
  - DT-R4: `rig.tool.notice.value` / `tool.notice.value` → `rig.tool.debugValue` / `tool.debugValue` (`:948, :968, :1180, :1211, :1216, :1237, :1253, :1256, :1570`).
  - the twins, appended to `main()` (TL4k is TL4 `:572-715`, TL5k is TL5 `:1357-1418`, each with the shell's lines dropped and the tool's kept):

```dart
  test(
      'TL4k (TL4\'s tool half, ruling DT-R1) Esc drops one or two pending '
      'points and places nothing; a second click on the first point, or on '
      'the same wall end point 5 µm away, is ignored; Enter with points '
      'pending does nothing', () async {
    for (final place in const [origin, corpusGroups]) {
      final plan = buildPlan([...sampleWalls(), sampleColumn],
          seps: const [sampleSeparator],
          openings: sampleOpenings,
          place: place);
      plan.doc.commands.clearHistory();
      final doc = plan.doc;
      // The camera at 0.3 px/mm: the aperture is 10 / 0.3 = 33.3 mm.
      final rig = dimRig(doc, pxPerMm: 0.3);
      final tool = rig.tool;
      void key(LogicalKeyboardKey logical, PhysicalKeyboardKey physical) =>
          tool.onKey(
              KeyDownEvent(
                  physicalKey: physical,
                  logicalKey: logical,
                  timeStamp: Duration.zero),
              rig.ctx);
      void escape() =>
          key(LogicalKeyboardKey.escape, PhysicalKeyboardKey.escape);
      void enter() => key(LogicalKeyboardKey.enter, PhysicalKeyboardKey.enter);
      // The Hall's inner corner E1/0/left, (12,250, 8,250).
      final corner = plan.at(12250, 8250);
      final near = plan.at(12253, 8254); // 5 mm off
      final free = plan.at(12900.25, 8900.5);
      final free2 = plan.at(13300.75, 9150.25);
      final depth = doc.commands.undoDepth;

      // Esc with one point, then with two: nothing is placed.
      clickAt(rig, near);
      expect(tool.points, hasLength(1));
      expect((tool.points.first - corner).length, lessThan(dimAttach.linear),
          reason: 'premise: the click snaps onto the corner');
      escape();
      expect(tool.points, isEmpty);
      clickAt(rig, near);
      clickAt(rig, free);
      expect(tool.points, hasLength(2));
      expect(tool.hoverKind, isNull, reason: 'premise: a free point');
      escape();
      expect(tool.points, isEmpty);
      expect(dims(doc), isEmpty);
      expect(doc.commands.undoDepth, depth);

      // A second click on the first point leaves one point pending.
      clickAt(rig, near);
      clickAt(rig, near);
      expect([tool.hoverPoint.x, tool.hoverPoint.y],
          [tool.points.first.x, tool.points.first.y],
          reason: 'premise: the same point');
      expect(tool.points, hasLength(1), reason: 'the corner twice');
      escape();
      clickAt(rig, free);
      clickAt(rig, free);
      expect(tool.hoverKind, isNull, reason: 'premise: a free point');
      expect([tool.hoverPoint.x, tool.hoverPoint.y],
          [tool.points.first.x, tool.points.first.y],
          reason: 'premise: the same point');
      expect(tool.points, hasLength(1), reason: 'a free point twice');

      // Enter with one point pending, then with two: nothing changes.
      final one = Vector2.copy(tool.points.first);
      enter();
      expect(tool.points, [one]);
      clickAt(rig, free2);
      expect(tool.points, hasLength(2));
      final two = Vector2.copy(tool.points[1]);
      enter();
      expect(tool.points, [one, two]);
      expect(dims(doc), isEmpty);
      expect(doc.commands.undoDepth, depth);
      escape();

      // The same wall end point 5 µm away (TL4's hand values, :657-680).
      final outer = plan.at(12000, 8000);
      final node = outer + Vector2(5e-6, 0);
      final page = PageComponent(
          originX: node.x, originY: node.y, gridStepMm: 500, snapToGrid: true);
      attachPage(doc, page);
      await Future<void>.delayed(Duration.zero); // the change reaches the page
      expect(rig.ctx.page!.value, page, reason: 'premise: the tool reads it');
      const pxPerMm = 0.052;
      expect(kSnapAperturePixels / pxPerMm, closeTo(192.3, 0.05));
      expect(dragGridStepMm(page, pxPerMm), 500);
      rig.ctx.camera.value = ViewportTransform(
          worldToScreenMatrix: Transform2.scale(pxPerMm, pxPerMm));
      clickAt(rig, outer + turnedBy(place, -3, -4));
      expect(tool.hoverKind, isNotNull, reason: 'premise: the corner snaps');
      final p0 = Vector2.copy(tool.points.single);
      expect((p0 - outer).length, lessThan(1e-7),
          reason: 'premise: onto the corner');
      final raw1 = outer + turnedBy(place, -170, -170);
      expect((raw1 - outer).length, closeTo(240.4, 0.05));
      clickAt(rig, raw1);
      expect(tool.hoverKind, isNull, reason: 'premise: no object snap');
      final p1 = Vector2.copy(tool.hoverPoint);
      expect([p1.x, p1.y], [node.x, node.y], reason: 'premise: the grid node');
      expect((p1 - p0).length, greaterThan(wallJoin.linear),
          reason: 'premise: not the same point');
      final index = SpatialIndex(doc);
      final t = thickestWall(doc, liveOf(doc));
      final at0 = attachCandidates(doc, index, p0,
          live: liveOf(doc), objectSnap: true, thickest: t);
      final at1 = attachCandidates(doc, index, p1,
          live: liveOf(doc), objectSnap: true, thickest: t);
      index.dispose();
      final e1 = plan.walls[0];
      expect(at0, contains(AttachedEnd(e1, 0, r)), reason: 'premise');
      expect(at1, contains(AttachedEnd(e1, 0, r)), reason: 'premise');
      expect(tool.points, [p0], reason: 'the same wall end point: ignored');

      // Esc drops it.
      escape();
      expect(tool.points, isEmpty);
      expect(dims(doc), isEmpty);
      expect(doc.commands.undoDepth, depth + 1, reason: 'the page alone');
    }
  });

  test(
      'TL5k (TL5\'s tool half over the sample walls, ruling DT-R1) two '
      'clicks on the Hall\'s corners place two points; a free hover reads '
      '4.69; the commit and a cancel clear it', () {
    for (final place in const [origin, corpusGroups]) {
      final plan = buildPlan([...sampleWalls(), sampleColumn],
          seps: const [sampleSeparator],
          openings: sampleOpenings,
          place: place);
      attachPage(plan.doc, PageComponent(snapToGrid: false)); // 1:50 m
      final doc = plan.doc;
      // 0.12 px/mm: the aperture is 10 / 0.12 = 83.3 mm.
      final rig = dimRig(doc, pxPerMm: 0.12);
      final tool = rig.tool;
      for (final commit in [true, false]) {
        final why = '${commit ? 'commit' : 'switch'}, $place';
        clickAt(rig, plan.at(12253, 8254));
        clickAt(rig, plan.at(16937, 8254));
        expect(tool.points, hasLength(2), reason: why);
        final q = plan.at(14600.5, commit ? 9150.25 : 9650.25);
        hoverTo(rig, q);
        expect(tool.hoverKind, isNull, reason: '$why: premise: free');
        expect(tool.debugValue, '4.69', reason: why);
        if (commit) {
          clickAt(rig, q);
          expect(dims(doc), hasLength(1), reason: why);
          expect(dimText(doc, dims(doc).single), '4.69', reason: why);
          expect(tool.debugValue, isNull, reason: '$why: after the commit');
        } else {
          tool.cancel(rig.ctx);
          expect(tool.debugValue, isNull, reason: '$why: deactivated');
        }
      }
    }
  });
```

  (`r`, `turnedBy`, `clickAt`, `hoverTo`, `dimRig` are the file's own, `:44, :119-124, :96-100, :92-93, :51-80`.) Before porting, `grep -rn "TL1 \|TL8 \|M-DT-8" packages/jet_cad_2d_plan/test packages/jet_cad_2d_kit/test`: expected none.

- [ ] **Step 6: Run the kit's tests.** `cd packages/jet_cad_2d_kit_architecture && flutter test`. Expected: `All tests passed!` (TL8 prints its timing). If TL4k's first `expect(tool.points, hasLength(1))` fails because a hover without a press already counts, or a twin line reads differently through the rig than through the shell, stop and report: the twin is a port, its lines are TL4's.

- [ ] **Step 7: The integration support.** In `packages/jet_cad_2d_integration/test/dimension/dimension_plans.dart` add (the `jet_cad_2d_flutter` import's `show` gains `InteractionLayer, ViewportTransform`; `status` and `press` are the rig's, which the file re-exports since Task 21, R-P14):

```dart
/// The sample plan's nine walls, in its order E1-E4, P1-P5, the flat's outer
/// corner at (12000, 8000) (room_fixture.dart:360-376).
List<W> sampleWalls() { /* copy room_fixture.dart:361-373 (the consts and the return) unchanged */ }

/// The sample's fifteen openings, indexing [sampleWalls]
/// (room_fixture.dart:378-394).
const List<O> sampleOpenings = [ /* copy :379-393 unchanged */ ];

/// The Living | Dining separator (room_fixture.dart:398).
const S sampleSeparator = (21500.0, 11560.0, 21500.0, 16750.0);

/// The column, the sample's tenth wall (room_fixture.dart:402).
const W sampleColumn = W(23500, 14000, 23900, 14000, 400);

/// The sample's room seeds, plan coordinates (room_fixture.dart:405-413).
const Map<String, (double, double)> sampleSeeds = { /* copy :406-412 unchanged */ };

/// A room at world [seed] named [name], a root group at the identity and
/// its parameters, one command (room_fixture.dart:567-580, without a label
/// offset or a group transform).
Handle addRoom(DraftDocument doc, Vector2 seed, String name) {
  final h = doc.handleSeed.next();
  doc.commands.execute(CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: h,
        parent: doc.rootHandle,
        transform: Transform2.identity(),
        children: const [])),
    SetComponentCommand<RoomParams>(h, RoomParams(seed.x, seed.y, name)),
  ], label: 'Add room'));
  return h;
}

/// Every live dimension of [doc], ascending (today's `liveObjectsOf`,
/// asked of the kit's types).
List<Handle> dims(DraftDocument doc) => [
      for (final h in doc.components.withComponent<DimensionParams>())
        if (kitCatalog().typeIdOf(doc, h) == ArchitectureTypes.dimension) h,
    ];

/// The active tool's notice in words, or null (spec C1.2).
String? noticeText(PlanController c) {
  final notice = c.toolNotice.value;
  return notice == null ? null : c.textOf(notice);
}

/// [c]'s camera at [pxPerMm], centred on world [at] (y down, as today's
/// `centreOn`, dimension_tool_test.dart:162-171).
Future<void> centreOn(
    WidgetTester tester, PlanController c, Vector2 at, double pxPerMm) async {
  final size = tester.getSize(find.byType(InteractionLayer));
  c.camera.value = ViewportTransform(
      worldToScreenMatrix: Transform2.translation(
              size.width / 2 - pxPerMm * at.x, size.height / 2 - pxPerMm * at.y)
          .multiply(Transform2.scale(pxPerMm, pxPerMm)));
  await tester.pump();
}

/// A primary tap at world [p] on [c]'s canvas.
Future<void> tapWorld(WidgetTester tester, PlanController c, Vector2 p) async {
  final s = c.camera.value.worldToScreen(p);
  await tester.tapAt(
      tester.getTopLeft(find.byType(InteractionLayer)) + Offset(s.x, s.y));
  await tester.pump();
}

/// Plan vector ([x], [y]) turned by [place]'s rotation
/// (dimension_tool_test.dart:119-124).
Vector2 turnedBy(Placement place, double x, double y) {
  final rad = place.deg * math.pi / 180;
  return Vector2(x * math.cos(rad) - y * math.sin(rad),
      x * math.sin(rad) + y * math.cos(rad));
}
```

  (The three `/* copy … */` bodies are copied from the named lines byte for byte; the comments are instructions, not code.)

- [ ] **Step 8: Port the shell cases (integration).** Create `packages/jet_cad_2d_integration/test/dimension/dimension_tool_test.dart`:

```dart
// Spec 11 D12 through PlanEditor (3a Task 22, spec C1.2, C6): the Dimension
// tool's letter, palette row and Esc, Enter and status line, and its
// notice on the status line. Ported from jet_cad_floor_plan's
// test/dimension_tool_test.dart (TL4 :572, TL5 :1357, TL7 :843): the
// lines that read the plan's public surface; the tool's own state is
// TL4k and TL5k in the kit (ruling DT-R1).
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer;
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'dimension_plans.dart';

/// The sample's walls, column, separator and openings at [place] on a plan
/// whose page snaps to no grid (the fixture change: today's document had
/// no page).
Built sampleIn(DraftDocument doc, Placement place) {
  setPage(doc, PageComponent(snapToGrid: false));
  return buildPlanIn(doc, [...sampleWalls(), sampleColumn],
      seps: const [sampleSeparator], openings: sampleOpenings, place: place);
}

void main() {
  testWidgets(
      'TL4 Esc with points pending stays in the tool and places nothing, and '
      'Esc again returns to Select; a second click on the first point, or on '
      'the same wall end point 5 µm away, places nothing; Enter with points '
      'pending does nothing', (tester) async {
    for (final place in const [origin, corpusGroups]) {
      final c = planOf((doc) => sampleIn(doc, place));
      final doc = c.document;
      await pumpPlan(tester, c);
      // The Hall's inner corner E1/0/left, (12,250, 8,250); the camera at
      // 0.3 px/mm on it: the aperture is 10 / 0.3 = 33.3 mm.
      final corner = place.at(12250, 8250);
      await centreOn(tester, c, corner, 0.3);
      await press(tester, LogicalKeyboardKey.keyI);
      expect(status(tester), 'Dimension', reason: '$place');
      expect(c.activeTool.value, ArchitectureTools.dimension); // DT-R2
      final near = place.at(12253, 8254); // 5 mm off
      final free = place.at(12900.25, 8900.5);
      final free2 = place.at(13300.75, 9150.25);
      final depth = doc.commands.undoDepth;

      // Esc with one point, then with two: nothing is placed.
      await tapWorld(tester, c, near);
      await press(tester, LogicalKeyboardKey.escape);
      expect(status(tester), 'Dimension', reason: 'still the tool');
      await tapWorld(tester, c, near);
      await tapWorld(tester, c, free);
      await press(tester, LogicalKeyboardKey.escape);
      expect(dims(doc), isEmpty);
      expect(doc.commands.undoDepth, depth);

      // A second click on the first point, on the corner and at a free
      // point (TL4k asserts the one pending point).
      await tapWorld(tester, c, near);
      await tapWorld(tester, c, near);
      await press(tester, LogicalKeyboardKey.escape);
      await tapWorld(tester, c, free);
      await tapWorld(tester, c, free);

      // Enter with one point pending, then with two: nothing is placed.
      await press(tester, LogicalKeyboardKey.enter);
      await tapWorld(tester, c, free2);
      await press(tester, LogicalKeyboardKey.enter);
      expect(dims(doc), isEmpty);
      expect(doc.commands.undoDepth, depth);
      await press(tester, LogicalKeyboardKey.escape);

      // The same wall end point 5 µm away, at a legal zoom (0.052 px/mm:
      // the aperture is 10 / 0.052 = 192.3 mm), a fixed 500 mm grid whose
      // origin is a node 5e-6 mm east of the outer corner (12,000, 8,000).
      final outer = place.at(12000, 8000);
      final node = outer + Vector2(5e-6, 0);
      final page = PageComponent(
          originX: node.x, originY: node.y, gridStepMm: 500, snapToGrid: true);
      setPage(doc, page);
      await tester.pump();
      await tester.pump();
      const pxPerMm = 0.052;
      expect(kSnapAperturePixels / pxPerMm, closeTo(192.3, 0.05));
      expect(dragGridStepMm(page, pxPerMm), 500);
      await centreOn(tester, c, outer, pxPerMm);
      await tapWorld(tester, c, outer + turnedBy(place, -3, -4));
      final raw1 = outer + turnedBy(place, -170, -170);
      expect((raw1 - outer).length, closeTo(240.4, 0.05));
      await tapWorld(tester, c, raw1);

      // Esc drops it; Esc again returns to Select.
      await press(tester, LogicalKeyboardKey.escape);
      expect(status(tester), 'Dimension');
      await press(tester, LogicalKeyboardKey.escape);
      expect(status(tester), 'Select');
      expect(dims(doc), isEmpty);
      expect(doc.commands.undoDepth, depth + 1, reason: 'the page alone');
    }
  });

  testWidgets(
      'TL5 the status line reads Dimension — 4.69 over the Hall\'s corners, '
      'and clears after the commit and on a switch to Select', (tester) async {
    for (final place in const [origin, corpusGroups]) {
      final c = planOf((doc) => sampleIn(doc, place)); // 1:50 m
      final doc = c.document;
      await pumpPlan(tester, c);
      // E1/0/left (12,250, 8,250) and P1/0/left (16,940, 8,250); the
      // camera at 0.12 px/mm centred between them (the aperture is 10 /
      // 0.12 = 83.3 mm; the pair spans 4,690 × 0.12 = 563 px, inside the
      // canvas: DT-R3).
      expect(tester.getSize(find.byType(InteractionLayer)).width,
          greaterThan(4690 * 0.12));
      await centreOn(tester, c, place.at(14595, 8250), 0.12);
      await press(tester, LogicalKeyboardKey.keyI);
      expect(c.activeTool.value, ArchitectureTools.dimension); // DT-R2
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      final layer = tester.getTopLeft(find.byType(InteractionLayer));
      Future<void> hover(Vector2 w) async {
        final s = c.camera.value.worldToScreen(w);
        await mouse.moveTo(layer + Offset(s.x, s.y));
        await tester.pump();
      }

      for (final commit in [true, false]) {
        final why = '${commit ? 'commit' : 'switch'}, $place';
        await tapWorld(tester, c, place.at(12253, 8254));
        await tapWorld(tester, c, place.at(16937, 8254));
        // A hover in the Hall, 900.25 above the pair (1,400.25 the second
        // time), no Shift: aligned, 16,940 − 12,250 = 4,690 mm, 4.69 in
        // metres.
        final q = place.at(14600.5, commit ? 9150.25 : 9650.25);
        await hover(q);
        expect(noticeText(c), '4.69', reason: why); // DT-R4
        expect(status(tester), 'Dimension — 4.69', reason: why);
        if (commit) {
          await tapWorld(tester, c, q);
          expect(dims(doc), hasLength(1), reason: why);
          expect(dimText(doc, dims(doc).single), '4.69', reason: why);
          expect(noticeText(c), isNull, reason: '$why: after the commit');
          expect(status(tester), 'Dimension', reason: why);
          await tester.pump();
          expect(status(tester), 'Dimension', reason: '$why: change heard');
        } else {
          await tester.tap(byKey('tool-plan.select'));
          await tester.pump();
          expect(noticeText(c), isNull, reason: '$why: deactivated');
          expect(status(tester), 'Select', reason: why);
        }
      }
      await mouse.removePointer();
    }
  });

  testWidgets(
      'TL7 I activates the Dimension tool from the canvas and the palette; '
      'typing I into a panel text field switches nothing', (tester) async {
    final c = planOf((doc) {
      buildPlanIn(doc, [...sampleWalls(), sampleColumn],
          seps: const [sampleSeparator], openings: sampleOpenings);
      final (x, y) = sampleSeeds['Hall']!;
      addRoom(doc, Vector2(x, y), 'Hall');
    });
    final doc = c.document;
    await pumpPlan(tester, c);
    expect(status(tester), 'Select');
    await press(tester, LogicalKeyboardKey.keyI);
    expect(status(tester), 'Dimension', reason: 'I on the canvas');
    expect(c.activeTool.value, ArchitectureTools.dimension); // DT-R2
    await press(tester, LogicalKeyboardKey.keyV);
    expect(status(tester), 'Select');
    await tester.tap(byKey('tool-architecture.dimension'));
    await tester.pump();
    expect(status(tester), 'Dimension', reason: 'the palette entry');
    await press(tester, LogicalKeyboardKey.keyV);

    // The Hall's Name field, focused: I types into it.
    final hall = doc.components
        .withComponent<RoomParams>()
        .firstWhere((h) => doc.components.get<RoomParams>(h)!.name == 'Hall');
    await select(tester, c, [hall]);
    final status0 = status(tester);
    expect(status0, startsWith('Select'));
    final name = byKey('property-name');
    await tester.tap(name);
    await tester.pump();
    tester.testTextInput.enterText('');
    await tester.pump();
    expect(await tester.sendKeyEvent(LogicalKeyboardKey.keyI), isFalse,
        reason: 'I reaches the platform as text');
    tester.testTextInput.enterText('I');
    await tester.pump();
    expect(tester.widget<TextField>(name).controller!.text, 'I');
    expect(status(tester), status0, reason: 'I switched no tool');
    expect(c.activeTool.value, isNot(ArchitectureTools.dimension)); // DT-R2
  });
}
```

  Run: `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice test/dimension/`. Expected: `All tests passed!`. If a tap on `property-name` misses because the field is off-screen in `PlanEditor`'s column, add `await tester.ensureVisible(name);` before it (a finder change, C7 3) and say so in the report; any other failure is a finding.

- [ ] **Step 9: Format and the gates.** `cd packages/jet_cad_2d_kit_architecture && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .`; `cd packages/jet_cad_2d_integration && dart format . && flutter test --enable-vmservice && flutter analyze && dart format --output=none --set-exit-if-changed .`; from the root `dart run tool/ci/check_kit_deps.dart`. All green; `git status --short`: only this task's files. Non-ASCII check (Global Constraints): `perl -ne 'print "$.: $_" if /[^\x00-\x7f]/' <file>` over the source and both destinations: every line it lists in the source outside the deleted spans (`:141-178`, `:572-715`, `:843-880`, `:1357-1418`) appears in the kit file unchanged (the header's `÷` included), and the integration file carries today's characters where its lines are today's: `µ` (`:575`), `—` (U+2014, `:1358`, and `'Dimension — 4.69'`), `×` (`:1373`), `−` (U+2212, `:1395`).

- [ ] **Step 10: Commit.**

```bash
git add packages/jet_cad_2d_kit_architecture/lib/src/dimension/dimension_tool.dart packages/jet_cad_2d_kit_architecture/lib/src/dimension/dimension_plan.dart packages/jet_cad_2d_kit_architecture/lib/src/kit.dart packages/jet_cad_2d_kit_architecture/test/dimension/dimension_tool_test.dart packages/jet_cad_2d_kit_architecture/test/dimension/dimension_notice_test.dart packages/jet_cad_2d_integration/test/dimension/dimension_plans.dart packages/jet_cad_2d_integration/test/dimension/dimension_tool_test.dart
git commit -m "$(cat <<'EOF'
feat(kit-architecture): the dimension tool and its notice (3a C3.6, C1.2)

The Dimension tool (I) moves from jet_cad_floor_plan: its attach search
asks the plan's live types, and its would-be value is a ToolNotice the
plan's status line puts into words ('Dimension — 4.69'). Eight kit cases
and three PlanEditor cases ported; TL4 and TL5's tool halves run as kit
twins (DT-R1); DT-notice and DT-plan-tool are new.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 11: Mutation check** (committed files only; after each: run the named test, see it red, quote the red line, then `git checkout -- <file>` and `git diff --quiet -- <file>` must exit 0). `T = packages/jet_cad_2d_kit_architecture/lib/src/dimension/dimension_tool.dart`, `P = .../dimension_plan.dart`; kit tests from `packages/jet_cad_2d_kit_architecture`, integration tests from `packages/jet_cad_2d_integration` with `--enable-vmservice`.
  - M-DT1 `T`: `if (!_disposed) _notice.value = KitText(_kValueText, {'value': l.text});` → `if (!_disposed) _notice.value = null;` → DT-notice red; TL5 (integration, `Dimension — 4.69`) red; the kit TL5 cases red (`debugValue`).
  - M-DT2 `T`: `_kValueText = 'text:architecture.dimension-value'` → `'text:architecture.dimension'` → DT-notice red (the `KitText` and the words); TL5 (integration) red (`textOf` shows the id).
  - M-DT3 `P`: `create: (s) => DimensionTool(live: liveTypesOf(s))` → `create: (s) => DimensionTool(live: (h) => s.document.components.get<WallParams>(h) != null ? ArchitectureTypes.wall : null)` (add `import '../wall/wall.dart' show WallParams;`) → DT-plan-tool red (`A frozen`).
  - M-DT4 `P`: `letter: 'I'` → `letter: 'D'` → DT-plan-tool red; TL7 (integration, `I on the canvas`) red.
  - M-DT5 `T`: delete the `orthoBase` override (`@override Vector2? get orthoBase => points.length >= 2 ? null : super.orthoBase;`), today's M-11ortho3 → TL2 red (a port check).
  - M-DT6 `T`: in `kindFor`, delete `if (!shift) return DimKind.aligned;` → TL1 red (a port check).

#### Interface problem

1. **(Resolved by ruling R-P5: Task 26 ports it, its Step 9 item 11, with IT-R12 and IT-R13.)** **`dimension_shell_test` needs the sample flat, which lands in Task 25** (as `dimension_paint_test`, Task 21's `#### Interface problem` 2). Its three cases (SL1, SL2, TL9) open `startupPlan(FlutterTextMeasurer())` (`dimension_shell_test.dart:48-60`) and work on the sample's five dimensions (`sampleValues = ['14.00', '9.00', '4.69', '4.38', '3.58']`, `:73`) and ten walls; `sampleFlatController()` and `buildSampleFlat` are Task 25's, and the sample's five dimensions need Task 21's `dimensionPlanType`, so the order cannot be swapped. (The palette order, `dimensionPlanTool` last, is pinned by Task 26's D-26 test, not here.) **Proposed fix (settled by ruling R-P5: Task 26):** port it in Task 26 as `packages/jet_cad_2d_integration/test/dimension/dimension_shell_test.dart`, every case, with:
   - `samplePlan({gridSnap})` (`:48-60`) → a `sampleFlatController()` whose page, for `gridSnap: false`, is changed by one command on `c.document` and the history cleared (`c.document.commands.clearHistory()`); `expect(driftOf(c.document), isEmpty)` and `undoDepth == 0` kept;
   - `pumpShell` → `pumpPlan`; `view.camera` → `c.camera`; `view.selection.keys` / `.replace` → `c.activeSelection.keys` / `.replace`; `view.index.pickInto(...)` and `view.index.snapInto(...)` (`:179, :577`) → the same calls on a `SpatialIndex(c.document)` the test builds and disposes (the engine's own index over the same document gives the same answers: a fixture change); `view.document` → `c.document`;
   - **open, ruled by Task 26 (IT-R12, IT-R13):** SL1's `view.grips!.rotatable` and `view.grips!.pivot` (`:369-371`, "alone it shows a rotation grip") and TL9's `view.tools.active` hover state (`:561-575`, the Line tool's `hoverKind`, `hoverPoint`) read the plan's `@internal` `grips` and `toolController` (`plan_controller.dart:2099-2116`); the integration package cannot. Options: a DT-R1-style split (TL9's hover through a `LineTool` over a `ToolContext` in the kit, on a document `buildSampleFlat` built; the rotation grip through `GripCache` over `dimensionPlanType.gripsFor` in the kit), or a public read on `PlanController` (a 2a amendment). The startup camera ("Clicks use the shell's startup camera", `:18-20`) is the plan's own fit, which may differ from the shell's: SL1's clicks at `globalOf` points are camera-independent, so this changes no assertion; if a hand-computed pick radius printed at `:222` is asserted somewhere, it is a finding.
#### New shared name

- None beyond Task 20's.

---

