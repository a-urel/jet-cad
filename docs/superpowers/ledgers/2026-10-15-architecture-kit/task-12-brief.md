### Task 12: The wall type, grips, tool and settings (spec C3.2, C1.5, C1.8; R-P1, R-P8, R-P9, R-P15)

**Files:**
- Create (`packages/jet_cad_2d_kit_architecture/`): `lib/src/wall/wall_grips.dart` (ported), `lib/src/wall/wall_tool.dart` (ported, with `WallSettings`), `lib/src/wall/wall_plan.dart` (new: `wallPlanType`, `wallPlanTool`), `test/support/wall_shell.dart` (ported), `test/wall/wall_tool_test.dart` (ported: the direct cases), `test/wall/wall_grips_test.dart` (ported: the provider-direct tails EG1-k, EG3-k, EG4-k, EG6-k), `test/wall/wall_joint_kinds_test.dart` (WT3-k, WT9-k: the shell cases' `classify` lines), `test/wall/wall_plan_test.dart` (new: WT-type, WT-settings, WT-bands, WT-frozen, WT-kit)
- Modify (`packages/jet_cad_2d_kit_architecture/`): `lib/src/kit.dart` (the type and the tool), `lib/jet_cad_2d_kit_architecture.dart` (`WallParams`, `Justification`), `CHANGELOG.md`
- Create (`packages/jet_cad_2d_integration/`): `test/support/wall_fixture.dart` (the wall fixture over public libraries), `test/support/wall_shell.dart` (the wall cases' harness over Task 9's rig), `test/wall/wall_tool_test.dart` (WT1-WT9, WT14, RF2, WT19), `test/wall/wall_grips_test.dart` (EG1-EG6, WG-refuse-short), `test/wall/wall_paint_test.dart` (WP5)

**Interfaces:**
- Consumes:
  - Task 11: `WallParams`, `Justification`, `wallJoin`, `isWallThickness`, `kWallMaxThickness`, `WallType` (`lib/src/wall/wall.dart`); `WorldWall`, `classify`, `Tee`, `NodeJoint`, `Free`, `wallsInDocument(doc, host, LiveTypeOf live, {moved})` (`wall_geometry.dart`); `WallBands(LiveTypeOf)`, `wallBandsOf(PlanServices)` (`wall_bands.dart`); the kit's `test/support/wall_fixture.dart` (`wallDoc`, `addWall`, `addSpoke`, `plan`, `polar`, `far`, `ox`, `oy`, `liveOf`, `testCatalog`, `installParametric`, ...).
  - Task 9: `ArchitectureTypes.wall`, `ArchitectureTools.wall`; `LiveTypeOf`, `liveTypesOf` (`lib/src/live.dart`); `architectureKit` (`lib/src/kit.dart`); the words `tool:architecture.wall`, `type:architecture.wall`, `property:architecture.wall.{thickness,justification}`, `property:architecture.wall.justification.{left,centre,right}`; the integration package's `architectureController`, `planEditorApp` and its rig (`test/support/editor_rig.dart`: `pumpEditor(tester, c, {locale, centre, scale, turn})`, `globalOf(tester, c, x, y)`, `status`, `press`, `activeTool`, `kitCatalog`).
  - Task 10: the box in `architectureKit` (`types: [boxPlanType]`, `tools: [boxPlanTool]`), `test/support/catalog.dart`.
  - Task 2 / R-P4, R-P7: `PlanType.fieldsOf(DraftDocument document, Handle group, PlanWords words)`, `commitField(document, group, field, input, words)`; `KitNamesWords` is a `KitWords`, which is a `PlanWords`.
  - Task 6: `package:jet_cad_2d_kit/testing.dart`'s `FakePlanServices` (`catalog`, `frozen`, `settings`, `words`, `shared`, `dispose`); R-P12 (its `settingsOf` reads the given map at each call).
  - Task 7 (C1.8): a grip provider's `drag`/`preview` answering null or empty gives no move; anything else thrown keeps 2a's rule (no grips, one `hookFailed`); the drop executes through `controller.execute`.
  - The plan library's public API: `PlanController.document`, `activeSelection`, `camera`, `diagnostics`, `save()`, and R-P9's `@internal` `grips` (`GripCache.grips`, rows `key`, `grip`, `object`).
- Produces:

```dart
// lib/src/wall/wall_grips.dart (kit-internal)
final class WallGrips implements ObjectGripProvider {
  WallGrips({required LiveTypeOf live});        // no 08 D13 _keptPut/_seated until Task 14
}
// lib/src/wall/wall_tool.dart (kit-internal)
@immutable final class WallSettings { const WallSettings({double thickness = 200,
    Justification justification = Justification.centre}); /* today's */ }
class WallTool extends PlacementTool {
  WallTool(WallSettings Function() settings, WallBands bands);
  // today's debugBandScans, debugBandEnd, name 'Wall'
}
// lib/src/wall/wall_plan.dart (Shared interfaces: "Each type task exports from its *_plan.dart")
final PlanType<WallParams> wallPlanType;   // id ArchitectureTypes.wall; thickness, justification
final PlanTool wallPlanTool;               // id ArchitectureTools.wall, letter 'W'
// lib/jet_cad_2d_kit_architecture.dart gains: export 'src/wall/wall.dart' show Justification, WallParams;
```

**Appendix A rows closed:** D-19's wall part, with Task 11: `wall_tool_test.dart` (21 cases: WT10-WT13, WT15-WT18, WT20 in the kit; WT1-WT9, WT14, RF2, WT19 in the integration package, WT3's and WT9's `classify` lines in the kit's WT3-k and WT9-k), `wall_paint_test.dart` (WP5, integration), `wall_grips_test.dart` EG1-EG6 (integration, their provider-direct tails in the kit). **Moved (R-P8):** EG7, EG8 to Task 17 (they build an opening and a separator: `shadowDoc`, `wall_grips_test.dart:155-218`); EG9, EG10 to Task 21 (they read `RoomInputs`, `OpeningGrips`, the separator's grips, `attachCandidates`, `thickestWall`, `DimensionGrips` and the opening and dimension panel sections, `:611-892`). Review Focus 3's kit half: WG-refuse-short. D-26's wall row (the palette's W) is proven by WT7.

Plan decisions and rulings:
- **R-P8 (no 08 D13 here).** Today's `WallGrips.drag` appends `_keptPut` (`wall_grips.dart:63-66, 69-127`): the openings of a wall whose start moved keep their distance from its end. It names `OpeningParams`, `layoutInDocument`, `placeCut` and `storedCentreOf` (Task 13). This task ports `WallGrips` without `_keptPut`/`_seated` and without their bullet in the class doc (`:27-33`); Task 14 adds them back from these lines with `opening_end_drag_test`. No case of EG1-EG6 builds an opening, so none of them sees the difference.
- **The live rule (C1.5).** `WallGrips` takes `{required LiveTypeOf live}` (Task 13's part, R-P8) and reads the walls through Task 11's `wallsInDocument(d, group, _live)` (`:51`, `:159`); `_endsAt` becomes an instance method for it. A frozen wall offers no grips and does not follow a joined end (WT-frozen).
- **The tool reads its settings per event, over the services.** Today's `WallTool(ValueNotifier<WallSettings> settings, {WallBands? bands})` (`wall_tool.dart:69-75`) read `settings.value` at each commit (`:216`) and paint (`:263-264`); the shell owned the notifier and the panel wrote it. In the kit: `WallTool(WallSettings Function() settings, WallBands bands)`, `wallPlanTool.create` passes `() => services.settingsOf<WallSettings>(ArchitectureTools.wall)` and `wallBandsOf(services)`; the plan's store holds the settings and its property panel writes them while the tool is active (spec C3.2; 2a P3). The band cache is the kit's shared one, so the tool never disposes it (today's `_ownsBands` and `dispose` override, `:70-71, :89, :240-244`, go). The kit's direct cases (WT10-WT20) build the same tool over a local `ValueNotifier<WallSettings>`, so `rig.tool.settings.value = ...` becomes `rig.settings.value = ...` (a name; assertions unchanged).
- **The fields.** `wallPlanType`: `thickness` a `LengthProperty` whose `write` throws `ArgumentError` unless `isWallThickness` (strict at `wallJoin.linear`, at most `kWallMaxThickness`: today's `selection_panel.dart:412-414`; spec C3.2 "strict, in `write`"), `justification` a `ChoiceProperty` over `Justification.values`; both `gate: PlanGate.reshape` (today's `_capable`, `selection_panel.dart:380-389`: an object's own field needs `reshape`). `wallPlanTool.settings`: the same two specs over `WallSettings`, ungated (today a tool's settings are always editable, `:388`), so the tool's word ids are the type's (`property:architecture.wall.*`: "the tool shares the type's id", Shared interfaces). Today's `SegmentedButton` (`selection_panel.dart:1313-1331`) is the panel's dropdown (C7 class 3: finders change, values do not; WS1-WS11 are Task 27's).
- **The palette.** `tools: [boxPlanTool, wallPlanTool]`, `types: [boxPlanType, wallPlanType]`: today's palette order (box, wall, door, ... `planner_shell.dart:547-561`) and registration order (`catalog.dart:28-31`). The icon is `Icons.maximize` (today's palette has no icons). The tool consults no lock and no layer (today's; spec C3.2).
- **R-P1, the integration package imports public libraries only.** The ported shell cases keep every assertion; where one reads a kit internal:
  - `wallTool(tester).isPending` → `activeTool(tester).isMidShape` (the rig's; the guard forwards `isMidShape`, `guard.dart:363-366`, and `PlacementTool.isMidShape` is `isPending`, `placement_tool.dart:76`). The Wall tool is the active tool at each of those lines.
  - `wallTool(tester).settings.value = WallSettings(t, j)` → `await setWallSettings(tester, thickness: '<t>', justification: j)`: the property panel's settings fields (`setting-thickness` typed, Enter; `setting-justification` picked), which store the same `WallSettings` the notifier held. Ruling R12-1: the user's path to the same value (`plan_property_panel.dart:700-745`); the settings section shows while the Wall tool is active.
  - `classify(...)` (WT3: `:303`, `:342-343`, `:365-366` and `expectTee`'s `:142-143`; WT9: `:544-545`) is the kit's geometry: those lines are deleted from the shell cases, each leaving `// classify: WT3-k (the kit).`, and run unchanged in the kit's companions WT3-k and WT9-k, which replay each chain through the Wall tool at the points the shell resolves (a tick's end exactly; the grid point `snapToGrid(p, 10, page)` of a click that no object snap catches, as WT3 itself asserts at `:299-302`) with the case's settings. Ruling R12-2 (R-P1's "split").
  - `WallGrips()` called directly (EG1 `:270-272`, EG3 `:334-371`, EG4 `:411-421`, EG6 `:549-579`) is a kit internal: each tail runs in the kit as EG1-k, EG3-k, EG4-k, EG6-k over its case's fixture, since each shell part ends undone or refused (`canon(doc) == before` is asserted just above), so the tail's document is the fixture's. Ruling R12-3 (R-P1's "split").
  - `WorldWall`, `wallJoin` (fixture reads of world ends and the join tolerance) are reproduced in the integration fixture over the public `WallParams` (`toWorld.transformPoint(p.start)`, bit for bit `wall_geometry.dart:19-62`; `Tolerance(linear: 1e-6, angular: 1e-9)`, `wall.dart:19`): a test-local fixture (R-P1).
  - EG2's shown grips (`view.grips!.grips`) are the controller's `@internal grips` (R-P9: the file starts with `// ignore_for_file: invalid_use_of_internal_member`).
- **The integration plans.** Today's fixtures built a `DraftDocument` and pumped `PlannerShell(document: doc)`. Here `wallPlanJson(page, build)` makes `architectureController()`, gives its document the case's page, runs `build` (the kit's system regenerates the walls), and returns `c.save()`; the case opens it with `architectureController(json: ...)`, so it has no undo history (today's `clearHistory`) and its manifest names the kit. A case that wrote stray components straight into the store before pumping (EG6: `:503-506`) does the same on `ctrl.document` before `pumpEditor`, today's order. Task 9's `pagePlanJson` builds a page-only plan without the kit's system; walls need the kit's, so this helper is the wall support's own (not a copy of a rig helper, R-P14).
- **R-P15 (WG-refuse-short).** Today, a wall-end grip on a point where the wall would be no longer than `wallJoin.linear` has an empty preview (`wall_grips.dart:137-138`) and, released there, no command (`grip_drag.dart:303-313` asks `drag` at the drop point; `wall_grips.dart:198` answers null); nothing is reported (no throw reaches the guard) and the grips stay usable. WG-refuse-short asserts exactly what a host sees: a drag through the refused point to an accepted one commits that point in one undo step; a drop on the refused point commits nothing; no diagnostic at any time; a later drag commits. The preview half is pinned by EG1-k (`preview(...)` at the refused point `isEmpty`), see "Interface problem".

- [ ] **Step 1: Precondition.** Tasks 1-11 are committed. Run, from the repository root:
  - `grep -n "wallsInDocument\|wallsInView" packages/jet_cad_2d_kit_architecture/lib/src/wall/wall_geometry.dart` and `grep -n "WallBands wallBandsOf\|WallBands(this._live)" packages/jet_cad_2d_kit_architecture/lib/src/wall/wall_bands.dart` — Task 11's names.
  - `grep -n "fieldsOf\|commitField" packages/jet_cad_2d_kit/lib/src/kit/plan_type.dart` — the R-P4 signatures with `words`.
  - `grep -n "Tool activeTool\|Future<void> pumpEditor\|Offset globalOf\|ParametricCatalog kitCatalog" packages/jet_cad_2d_integration/test/support/editor_rig.dart` — four hits (Task 9).
  - `grep -n "types:\|tools:" packages/jet_cad_2d_kit_architecture/lib/src/kit.dart` — `[boxPlanType]` and `[boxPlanTool]` (Task 10).
  Any miss is a finding: stop and report it.

- [ ] **Step 2: The kit's test support.** Create `test/support/wall_shell.dart`: **copy `packages/jet_cad_floor_plan/test/support/wall_shell.dart:1-51`**, with the header line `// Ported from jet_cad_floor_plan/test/support/wall_shell.dart (3a Task 12), unchanged but for its imports.` first and its imports `:1-4` as:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;
```

- [ ] **Step 3: The kit's ported tests.**
  1. `test/wall/wall_tool_test.dart` ← `wall_tool_test.dart`: the header below, the helpers `:191-210` (`pointerAt`, `hoverTo`, `pressAt`, `median`; `({WallTool tool, ToolContext ctx}) rig` → `Rig rig` in `hoverTo` and `pressAt`), then `void main() {`, **WT10-WT13 (`:548-664`) and WT15-WT18, WT20 (`:733-859`) copied, assertions unchanged**, with `rig.tool.settings.value` → `rig.settings.value` (WT18 `:809, :821`; WT20 `:841, :853`), and `}`:

```dart
// Ported from jet_cad_floor_plan/test/wall_tool_test.dart (3a Task 12):
// the cases that drive the Wall tool directly (WT10-WT13, WT15-WT18,
// WT20), assertions unchanged. The shell cases (WT1-WT9, WT14, RF2, WT19)
// run in jet_cad_2d_integration. The rig reads the tool's settings through
// a function, as the plan's services give them, and builds the band cache
// over the kit tests' catalog.
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall_bands.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall_tool.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/wall_fixture.dart';
import '../support/wall_shell.dart';

typedef Rig = ({
  WallTool tool,
  ToolContext ctx,
  ValueNotifier<WallSettings> settings
});

/// The Wall tool driven directly, wired as the plan wires it, over [doc]:
/// its settings read through [Rig.settings], its own band cache over the
/// kit tests' catalog, a unit camera (a 10 mm aperture), object snap on, no
/// page (no grid). Today's `directRig` (wall_tool_test.dart:168-189).
Rig directRig(DraftDocument doc) {
  final index = SpatialIndex(doc);
  final camera = CameraController(
      ViewportTransform(worldToScreenMatrix: Transform2.identity()));
  final selection = SelectionController(doc);
  final settings = ValueNotifier<WallSettings>(const WallSettings());
  final bands = WallBands(liveOf(doc));
  final tool = WallTool(() => settings.value, bands);
  addTearDown(() {
    tool.dispose();
    bands.dispose();
    settings.dispose();
    selection.dispose();
    camera.dispose();
    index.dispose();
  });
  return (
    tool: tool,
    ctx: ToolContext(
        document: doc, index: index, camera: camera, selection: selection),
    settings: settings,
  );
}
```

  2. `test/wall/wall_grips_test.dart` (EG1-k, EG3-k, EG4-k, EG6-k; ruling R12-3): the head below, then today's constants and `addL` (`wall_grips_test.dart:134-153`) copied unchanged, then `void main() {` and the four cases, each a `test(` built from today's lines with `WallGrips()` → `WallGrips(live: liveOf(doc))` everywhere and **every assertion unchanged**:
     - EG1-k: `test('EG1-k a degenerate drop is refused by the provider: no command, no preview', () {`, `final doc = gripDoc((doc) { doc.commands.execute(addWall(doc, wa, plan(0, 0), plan(3000, 400), 200, Justification.centre)); });` (`:225-228`'s build), then `:270-272`.
     - EG3-k: `test("EG3-k an L's shared end, the provider directly: the command's members ascend by handle, the preview is both moved centrelines in world, another grip moves A's free start alone, a degenerate wall on the corner joins nothing", () {`, `final doc = gripDoc((doc) => addL(doc));`, `final q = gridOf(plan(3500, -400));` (`:313`), then `:334-371`.
     - EG4-k: `test("EG4-k a three-way node's end, the provider directly: one command per wall, ascending by handle, whichever end is dragged", () {`, `:377-388` with `gripDoc(FlutterTextMeasurer(), (doc) {` → `gripDoc((doc) {`, `final q = gridOf(polar(hub, 23 + 80, 500));` (`:397`), then `:411-421`.
     - EG6-k: `test("EG6-k an L's corner and a file's strays, the provider directly: a stray offers no grips; a live wall offers its two ends, bitwise; the command and the preview name A and B only", () {`, `:456-520` (the strays and their premises) with `gripDoc(FlutterTextMeasurer(), (doc) {` → `gripDoc((doc) {`, `final q = gridOf(plan(3500, -400));` (`:528`), then `:549-579`.

```dart
// Ported from jet_cad_floor_plan/test/wall_grips_test.dart (3a Task 12,
// R-P1): the provider-direct tails of EG1, EG3, EG4 and EG6, whose
// WallGrips is a kit internal, assertions unchanged, each over its case's
// fixture as the shell case leaves it there (the shell part ends undone or
// refused, so the document is the fixture's). The shell parts run in
// jet_cad_2d_integration. Every wall sits at the far origin in its own
// rotated group (`groupAt`, or a spoke's group at its hub).
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall_grips.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/wall_fixture.dart';

/// The walls [build] adds to an empty document with the kit tests' system,
/// with no undo history (wall_grips_test.dart:36-56's `gripDoc`, without
/// the page, which only the shell's snap reads).
DraftDocument gripDoc(void Function(DraftDocument doc) build) {
  final doc = wallDoc();
  build(doc);
  doc.commands.clearHistory();
  return doc;
}

/// The shell case's grid point nearest [p]: its 1:20 page near the far
/// origin, grid at 10 mm (wall_grips_test.dart:42-49, 119-121).
Vector2 gridOf(Vector2 p) => snapToGrid(
    p,
    10,
    PageComponent(
        scaleDenominator: 20,
        originX: ox - 2000,
        originY: oy - 2000,
        gridStepMm: 10));

/// Wall [h]'s end [k] in world.
Vector2 endOf(DraftDocument doc, Handle h, int k) =>
    worldWallOf(doc, h).endpoint(k);

```

  3. `test/wall/wall_joint_kinds_test.dart` (WT3-k, WT9-k; ruling R12-2; new code, its assertions the source's `classify` lines):

```dart
// 3a Task 12, R-P1: the joint-kind assertions of today's shell cases WT3
// and WT9 (jet_cad_floor_plan/test/wall_tool_test.dart:273-386, :499-524),
// whose `classify` is a kit internal the integration package cannot import.
// Each companion replays its case's chains through the Wall tool, at the
// points the shell resolves them to (a tick's end, exactly; a grid point of
// the case's 1:20 page, `snapToGrid`), with the case's settings; its
// assertions are the case's `classify` lines, unchanged. The shell halves
// (WT3, WT9) run in jet_cad_2d_integration with every other assertion.
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/services.dart'
    show KeyDownEvent, LogicalKeyboardKey, PhysicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall_bands.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall_geometry.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall_tool.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/wall_fixture.dart';
import '../support/wall_shell.dart';

// The room of WR12, turned 23° about the far origin (wall_tool_test.dart:
// 20-27).
final Vector2 c0 = plan(0, 0), c1 = plan(4000, 300);
final Vector2 c2 = plan(3600, 3100), c3 = plan(-200, 2700);
final Vector2 s0 = plan(1300, 1900);

/// The shell cases' page: 1:20 near the far origin, grid at 10 mm.
final PageComponent page = PageComponent(
    scaleDenominator: 20,
    originX: ox - 2000,
    originY: oy - 2000,
    gridStepMm: 10);

/// The grid point the shell's click at [p] resolves to.
Vector2 grid(Vector2 p) => snapToGrid(p, 10, page);

/// The unit left normal of the line from [a] to [b].
Vector2 leftOf(Vector2 a, Vector2 b) {
  final d = (b - a).normalized();
  return Vector2(-d.y, d.x);
}

/// The Wall tool over [doc] with [settings], its own band cache, a unit
/// camera and [snap] (null: object snap on); one chain per [draw].
final class Chains {
  Chains(this.doc, {SnapSettings? snap}) {
    tool = WallTool(() => settings, bands);
    ctx = ToolContext(
        document: doc,
        index: index,
        camera: camera,
        selection: selection,
        snap: snap);
    addTearDown(() {
      tool.dispose();
      bands.dispose();
      selection.dispose();
      camera.dispose();
      index.dispose();
    });
  }

  final DraftDocument doc;
  WallSettings settings = const WallSettings();
  late final WallBands bands = WallBands(liveOf(doc));
  late final SpatialIndex index = SpatialIndex(doc);
  late final CameraController camera = CameraController(
      ViewportTransform(worldToScreenMatrix: Transform2.identity()));
  late final SelectionController selection = SelectionController(doc);
  late final WallTool tool;
  late final ToolContext ctx;

  void _press(Vector2 world) => tool.onPointerDown(
      ToolPointerEvent(
          screen: Offset.zero,
          world: world,
          pointer: 1,
          buttons: kPrimaryButton,
          shift: false,
          control: false,
          meta: false,
          alt: false,
          pickRadiusWorld: 1),
      ctx);

  /// One wall from [a] to [b], then Enter: the new wall.
  Handle draw(Vector2 a, Vector2 b) {
    _press(a);
    _press(b);
    tool.onKey(
        const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.enter,
            logicalKey: LogicalKeyboardKey.enter,
            timeStamp: Duration.zero),
        ctx);
    return walls(doc).last;
  }
}

void main() {
  test(
      "WT3-k WT3's joint kinds: a click on a centreline body makes a T, one "
      'within a thickness of its end a node, one outside the band nothing',
      () {
    final doc = wallDoc();
    final k = Chains(doc);
    final h = k.draw(c0, c1);
    k.settings =
        const WallSettings(thickness: 115, justification: Justification.left);
    final foot = c0 + (c1 - c0) * 0.35;
    final side = (s0 - project(s0, c0, c1)).normalized();
    final s = k.draw(s0, grid(foot + side * 20));
    expect(classify(worldWallOf(doc, s), 1, [worldWallOf(doc, h)]), isA<Tee>());

    k.settings = const WallSettings();
    final nH = leftOf(c0, c1);
    final inSign = nH.dot(s0 - c0) > 0 ? 1.0 : -1.0;
    final t1 = k.draw(grid(plan(2300, 1000)),
        grid(c0 + (c1 - c0) * 0.6 + nH * (90 * inSign)));
    expect(classify(worldWallOf(doc, t1), 1, [worldWallOf(doc, h)]),
        isA<Tee>(),
        reason: t1.toHex());
    final t2 = k.draw(grid(plan(3100, -1300)),
        grid(c0 + (c1 - c0) * 0.8 - nH * (60 * inSign)));
    expect(classify(worldWallOf(doc, t2), 1, [worldWallOf(doc, h)]),
        isA<Tee>(),
        reason: t2.toHex());
    final len = c0.distanceTo(c1);
    final n = k.draw(
        grid(c0 + (c1 - c0) * ((len - 120) / len) + nH * (70 * inSign)),
        grid(plan(5200, 1100)));
    expect(classify(worldWallOf(doc, n), 0, [worldWallOf(doc, h)]),
        isA<NodeJoint>());

    k.settings =
        const WallSettings(thickness: 240, justification: Justification.left);
    final h2 = k.draw(c3, c2);
    final nH2 = leftOf(c3, c2);
    k.settings = const WallSettings();
    final t3 = k.draw(
        grid(plan(1500, 2200)), grid(c3 + (c2 - c3) * 0.4 + nH2 * 180));
    expect(classify(worldWallOf(doc, t3), 1, [worldWallOf(doc, h2)]),
        isA<Tee>(),
        reason: t3.toHex());
    final t4 = k.draw(
        grid(plan(2500, 2100)), grid(c3 + (c2 - c3) * 0.7 - nH2 * 150));
    expect(
        classify(worldWallOf(doc, t4), 1, [worldWallOf(doc, h2)]), isA<Free>());
  });

  test(
      "WT9-k WT9's joint kind: with object snap off, a click in a wall's "
      'band joins nothing', () {
    final doc = wallDoc();
    final h = Chains(doc).draw(c0, c1);
    final k = Chains(doc, snap: SnapSettings(objectSnap: false));
    final nH = leftOf(c0, c1);
    final inSign = nH.dot(s0 - c0) > 0 ? 1.0 : -1.0;
    final t = k.draw(grid(plan(2300, 1000)),
        grid(c0 + (c1 - c0) * 0.6 + nH * (90 * inSign)));
    expect(classify(worldWallOf(doc, t), 1, [worldWallOf(doc, h)]),
        isNot(isA<Tee>()));
  });
}
```

  Check the `°` of the copied lines with `grep -n "°" test/wall/*.dart` against the sources (Global Constraints).

- [ ] **Step 4: The kit's new tests.** Create `test/wall/wall_plan_test.dart`:

```dart
// 3a Task 12 (spec C3.2, C1.5, C2): the wall as the kit declares it -- its
// plan type's fields, its tool's settings and letter, the tool made over a
// plan's services (its settings read there, the shared band cache), the
// grips over the services' live walls, and the kit carrying both. Walls at
// the far origin in their own turned groups, or spokes of a node at a
// turned hub.
import 'dart:ui' show Locale;

import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_kit/testing.dart';
import 'package:jet_cad_2d_kit_architecture/src/ids.dart';
import 'package:jet_cad_2d_kit_architecture/src/kit.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall_bands.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall_plan.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall_tool.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/wall_fixture.dart';
import '../support/wall_shell.dart';

/// A primary press at [world], as the canvas hands one to a tool.
ToolPointerEvent pressEvent(Vector2 world) => ToolPointerEvent(
    screen: Offset.zero,
    world: world,
    pointer: 1,
    buttons: kPrimaryButton,
    shift: false,
    control: false,
    meta: false,
    alt: false,
    pickRadiusWorld: 1);

/// [doc]'s tool context: a unit camera, object snap on, no page.
ToolContext contextOf(DraftDocument doc) {
  final index = SpatialIndex(doc);
  final camera = CameraController(
      ViewportTransform(worldToScreenMatrix: Transform2.identity()));
  final selection = SelectionController(doc);
  addTearDown(() {
    selection.dispose();
    camera.dispose();
    index.dispose();
  });
  return ToolContext(
      document: doc, index: index, camera: camera, selection: selection);
}

/// [command]'s members' handles: a grip drag's walls, in order.
List<Handle> handlesOf(DraftCommand command) => [
      for (final m in (command as CompoundCommand).children)
        (m as SetComponentCommand<WallParams>).handle,
    ];

/// The panel's words (English, no kit words: the fields need none).
final KitWords words = KitNamesWords(KitNames.empty, () => const Locale('en'));

void main() {
  test(
      'WT-type the wall type: thickness, strict as isWallThickness in its '
      'write, and justification of left, centre and right, each needing '
      'reshape, under property:architecture.wall.*', () {
    final doc = wallDoc();
    const h = Handle(1300);
    doc.commands.execute(addWall(
        doc, h, plan(-1200, 300), plan(1800, 900), 115, Justification.left));
    final p = doc.components.get<WallParams>(h)!;
    final [thickness, justification] = wallPlanType.fieldsOf(doc, h, words);
    expect([thickness.wordId, justification.wordId], [
      'property:architecture.wall.thickness',
      'property:architecture.wall.justification',
    ]);
    expect([thickness.spec.gate, justification.spec.gate],
        [PlanGate.reshape, PlanGate.reshape]);
    expect([thickness.value, justification.value], [115, Justification.left]);
    expect(
        switch (justification.spec) {
          ChoiceProperty(:final values) => values,
          _ => null,
        },
        Justification.values);
    for (final t in [wallJoin.linear, 0.0, -115.0, nextUp(kWallMaxThickness)]) {
      expect(() => thickness.commit!(t), throwsArgumentError, reason: '$t');
      expect(() => wallPlanType.commitField(doc, h, thickness, t, words),
          throwsArgumentError,
          reason: '$t');
    }
    for (final t in [nextUp(wallJoin.linear), kWallMaxThickness, 240.5]) {
      expect(thickness.commit!(t), p.copyWith(thickness: t), reason: '$t');
    }
    expect(justification.commit!(Justification.right),
        p.copyWith(justification: Justification.right));
    expect(wallPlanType.id, ArchitectureTypes.wall);
    expect(wallPlanType.parametric, isA<WallType>());
  });

  test(
      "WT-settings the Wall tool: W, the commits' needs, settings from 200 "
      'centre, the same strict thickness and the three justifications, '
      'ungated, under property:architecture.wall.*; the tool made over a '
      "plan's services draws with the settings it reads there", () {
    expect(wallPlanTool.id, ArchitectureTools.wall);
    expect(wallPlanTool.letter, 'W');
    expect(wallPlanTool.needs, {
      Capability.structure,
      Capability.components,
      Capability.geometry,
    });
    final settings = wallPlanTool.settings!;
    expect(settings.initial, const WallSettings());
    Object? stored;
    final [thickness, justification] = settings.fieldsOf(
        const WallSettings(thickness: 150, justification: Justification.right),
        (v) => stored = v,
        toolId: ArchitectureTools.wall);
    expect([thickness.wordId, justification.wordId], [
      'property:architecture.wall.thickness',
      'property:architecture.wall.justification',
    ]);
    expect([thickness.spec.gate, justification.spec.gate], [null, null]);
    expect([thickness.value, justification.value], [150, Justification.right]);
    expect(() => thickness.commit!(wallJoin.linear), throwsArgumentError);
    expect(() => thickness.commit!(nextUp(kWallMaxThickness)),
        throwsArgumentError);
    expect(stored, isNull);
    thickness.commit!(kWallMaxThickness);
    expect(
        stored,
        const WallSettings(
            thickness: kWallMaxThickness, justification: Justification.right));
    justification.commit!(Justification.left);
    expect(stored,
        const WallSettings(thickness: 150, justification: Justification.left));

    final doc = wallDoc();
    final services = FakePlanServices(
        document: doc,
        catalog: testCatalog(),
        settings: {
          ArchitectureTools.wall: const WallSettings(
              thickness: 115, justification: Justification.left),
        });
    addTearDown(services.dispose);
    final tool = wallPlanTool.create(services);
    addTearDown(tool.dispose);
    final ctx = contextOf(doc);
    tool.onPointerDown(pressEvent(plan(0, 0)), ctx);
    tool.onPointerDown(pressEvent(plan(3000, 400)), ctx);
    final h = walls(doc).single;
    final p = doc.components.get<WallParams>(h)!;
    expect([p.thickness, p.justification], [115, Justification.left]);
    expect(doc.tree[h]!.transform, Transform2.identity());
  });

  test(
      "WT-bands the tool made over a plan's services scans the kit's shared "
      'band cache: its commit invalidates wallBandsOf(services), and a new '
      "chain's first click in the new wall's band right after joins it", () {
    final doc = wallDoc();
    final services = FakePlanServices(
        document: doc,
        catalog: testCatalog(),
        settings: {ArchitectureTools.wall: const WallSettings()});
    addTearDown(services.dispose);
    final bands = wallBandsOf(services);
    final tool = wallPlanTool.create(services);
    addTearDown(tool.dispose);
    final ctx = contextOf(doc);
    final g = bands.generation;
    tool.onPointerDown(pressEvent(plan(0, 0)), ctx);
    tool.onPointerDown(pressEvent(plan(3000, 0)), ctx);
    expect(bands.generation, greaterThan(g));
    final a = worldWallOf(doc, walls(doc).single);
    // End the chain, so the next wall does not run from A's end along A
    // itself; then a new chain whose first click lies in A's band, 70 mm
    // off its centreline, and a second click well away from A.
    tool.cancel(ctx);
    tool.onPointerDown(pressEvent(plan(1500, 70)), ctx);
    tool.onPointerDown(pressEvent(plan(1500, 1500)), ctx);
    expect(walls(doc), hasLength(2), reason: 'premise: the stem landed');
    final start = doc.components.get<WallParams>(walls(doc).last)!.start;
    expect(distToLine(start, a.s, a.e), lessThan(wallJoin.linear));
  });

  test(
      "WT-frozen the wall's grips over a plan's services: a frozen wall "
      'offers no grips and does not follow a joined end; with nothing '
      'frozen it does (spec 3a C1.5)', () {
    final hub = plan(1500, 1500);
    const wa = Handle(1300), wb = Handle(2600), wf = Handle(3900);
    final doc = wallDoc();
    for (final (h, deg, t, j, fromHub) in [
      (wa, 20.0, 200.0, Justification.centre, true),
      (wb, 140.0, 115.0, Justification.left, false),
      (wf, 255.0, 150.0, Justification.right, true),
    ]) {
      doc.commands.execute(
          addSpoke(doc, h, hub, deg + 23, 2000, t, j, fromHub: fromHub));
    }
    final q = polar(hub, 23 + 80, 500);
    final frozen =
        FakePlanServices(document: doc, catalog: testCatalog(), frozen: {wf});
    addTearDown(frozen.dispose);
    final grips = wallPlanType.gripsFor(frozen)!;
    expect(grips.gripsOf(doc, wf), isEmpty);
    final g = grips.gripsOf(doc, wa)[0];
    expect(handlesOf(grips.drag(doc, wa, g, q)!), [wa, wb]);
    expect(grips.preview(doc, wa, g, q), hasLength(2));

    final all = FakePlanServices(document: doc, catalog: testCatalog());
    addTearDown(all.dispose);
    final control = wallPlanType.gripsFor(all)!;
    expect(control.gripsOf(doc, wf), hasLength(2));
    expect(handlesOf(control.drag(doc, wa, control.gripsOf(doc, wa)[0], q)!),
        [wa, wb, wf]);
  });

  test(
      'WT-kit the kit carries the wall type after the box and the Wall tool '
      'after the Box tool, and it validates', () {
    expect([for (final t in architectureKit.types.take(2)) t.id],
        [ArchitectureTypes.box, ArchitectureTypes.wall]);
    expect(identical(architectureKit.types[1], wallPlanType), isTrue);
    expect([for (final t in architectureKit.tools.take(2)) t.id],
        [ArchitectureTools.box, ArchitectureTools.wall]);
    expect(identical(architectureKit.tools[1], wallPlanTool), isTrue);
    expect(architectureKit.validate(), isEmpty);
  });
}
```

- [ ] **Step 5: Run the kit's tests, see them fail.** `cd packages/jet_cad_2d_kit_architecture && flutter test test/wall/`. Expected: `wall_tool_test.dart`, `wall_grips_test.dart`, `wall_joint_kinds_test.dart` and `wall_plan_test.dart` fail to load (`Error when reading 'lib/src/wall/wall_tool.dart'`, `wall_grips.dart`, `wall_plan.dart`: no such file); Task 11's files pass.

- [ ] **Step 6: `lib/src/wall/wall_grips.dart`.** **Copy `packages/jet_cad_floor_plan/lib/src/parametric/wall_grips.dart:1-203`**, then:
  1. Lines 5-9 (the relative imports) become `import '../live.dart';`, `import 'wall.dart';`, `import 'wall_geometry.dart';`.
  2. The class doc's bullet `:27-33` ("**Openings stay put** ...") becomes:

```dart
/// - **Openings stay put** (spec 08 D13): joins with the opening type, in
///   3a's Task 14.
```

  3. After `final class WallGrips implements ObjectGripProvider {` (`:41`) insert:

```dart
  /// [live] names the live walls ([wallsInDocument]): a frozen wall offers
  /// no grips and does not follow a joined end (spec 3a C1.5).
  WallGrips({required LiveTypeOf live}) : _live = live;

  final LiveTypeOf _live;

```

  4. `:51` `wallsInDocument(d, group)?.host` → `wallsInDocument(d, group, _live)?.host`.
  5. In `drag` delete `:65` (`..._keptPut(d, moved),`); delete `:69-128` (`_keptPut`, `_seated` and their docs). Task 14 restores both from these lines (R-P8).
  6. `_endsAt`'s doc `:151-152` "by the engine's / object rule (`live_objects.dart`)." → "by the engine's / object rule through [_live]."; `:158` `static List<(Handle, int)> _endsAt(` → `List<(Handle, int)> _endsAt(` (an instance method: it reads `_live`); `:159` `wallsInDocument(d, group)` → `wallsInDocument(d, group, _live)`.
  Everything else (`gripsOf`, `drag`'s compound and label, `preview` and its cache, `movable`, `_moved`) is unchanged.

- [ ] **Step 7: `lib/src/wall/wall_tool.dart`.** **Copy `packages/jet_cad_floor_plan/lib/src/parametric/wall_tool.dart:1-278`**, then:
  1. `:4-5` → `import 'package:flutter/foundation.dart' show immutable, visibleForTesting;`
  2. `WallSettings`' doc `:13-15` → `/// The Wall tool's settings (spec 07 D11): what the next wall is drawn` / `/// with. The plan keeps them (\`PlanToolSettings\`); its property panel edits` / `/// them while the tool is active.` (`WallSettings` itself, `:16-41`, unchanged.)
  3. `:67-75` (the constructor, its doc, and the `settings` notifier with its doc) become:

```dart
  /// [_settings] reads the tool's settings (`PlanServices.settingsOf`) at
  /// each commit and each paint; [_bands] is the band cache the kit shares
  /// with the opening tools (spec 08 D14, Ruling 08-11; [wallBandsOf]).
  WallTool(this._settings, this._bands);

  final WallSettings Function() _settings;
```

  4. `:86-89`: the band cache's doc gains "Shared: the tool never disposes it." and `final bool _ownsBands;` goes.
  5. `_addWall`'s doc `:212-213` "the panel never writes one, but the settings are a public notifier." → "the panel never writes one, but a host's store may hold one."; `:216` `final w = settings.value;` → `final w = _settings();`.
  6. Delete `:240-245` (the `dispose` override and the blank line after it).
  7. `paintRubberBand` `:263-264`: `final t = settings.value.thickness;` / `final (l, r) = switch (settings.value.justification) {` → `final settings = _settings();` / `final t = settings.thickness;` / `final (l, r) = switch (settings.justification) {`.

- [ ] **Step 8: `lib/src/wall/wall_plan.dart`** (new):

```dart
// The wall as the kit declares it (spec 3a C3.2): its plan type (the
// engine type, its grips, its thickness and justification fields) and its
// tool (letter W, the settings the panel edits while the tool is active).
import 'package:flutter/material.dart' show Icons;
import 'package:jet_cad_2d/jet_cad_2d.dart' show Capability;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import '../ids.dart';
import '../live.dart';
import 'wall.dart';
import 'wall_bands.dart';
import 'wall_grips.dart';
import 'wall_tool.dart';

/// [t], when a wall may have it ([isWallThickness]: strict above
/// `wallJoin.linear`, at most [kWallMaxThickness]); else an
/// [ArgumentError], which the panel takes as a refusal (today's
/// `selection_panel.dart:412-414`).
double _thickness(double t) => isWallThickness(t)
    ? t
    : throw ArgumentError.value(t, 'thickness', 'is not a wall thickness');

/// The wall's plan type: thickness and justification, each needing the
/// `reshape` permission (today's `_capable`, `selection_panel.dart:380-389`).
final PlanType<WallParams> wallPlanType = PlanType<WallParams>(
  id: ArchitectureTypes.wall,
  fromJson: WallParams.fromJson,
  parametric: const WallType(),
  grips: (services) => WallGrips(live: liveTypesOf(services)),
  properties: [
    LengthProperty<WallParams>(
        id: 'thickness',
        read: (p) => p.thickness,
        write: (p, t) => p.copyWith(thickness: _thickness(t)),
        gate: PlanGate.reshape),
    ChoiceProperty<WallParams, Justification>(
        id: 'justification',
        values: Justification.values,
        read: (p) => p.justification,
        write: (p, j) => p.copyWith(justification: j),
        gate: PlanGate.reshape),
  ],
);

/// The Wall tool, W: a chain of walls drawn with its settings, which the
/// panel edits while it is active (no gate: a tool's settings are always
/// editable, today's `_capable`). It consults no lock and no layer rule
/// (today's).
final PlanTool wallPlanTool = PlanTool(
  id: ArchitectureTools.wall,
  icon: Icons.maximize,
  letter: 'W',
  needs: const {
    Capability.structure,
    Capability.components,
    Capability.geometry,
  },
  settings: PlanToolSettings<WallSettings>(
    initial: const WallSettings(),
    specs: [
      LengthProperty<WallSettings>(
          id: 'thickness',
          read: (s) => s.thickness,
          write: (s, t) => s.copyWith(thickness: _thickness(t))),
      ChoiceProperty<WallSettings, Justification>(
          id: 'justification',
          values: Justification.values,
          read: (s) => s.justification,
          write: (s, j) => s.copyWith(justification: j)),
    ],
  ),
  create: (services) => WallTool(
      () => services.settingsOf<WallSettings>(ArchitectureTools.wall),
      wallBandsOf(services)),
);
```

- [ ] **Step 9: The kit wires it.**
  1. `lib/src/kit.dart`: add `import 'wall/wall_plan.dart';`; `types: [boxPlanType]` → `types: [boxPlanType, wallPlanType]`; `tools: [boxPlanTool]` → `tools: [boxPlanTool, wallPlanTool]`.
  2. `lib/jet_cad_2d_kit_architecture.dart`: add `export 'src/wall/wall.dart' show Justification, WallParams;` after the box's export (the barrel's list, Shared interfaces).
  3. `CHANGELOG.md`: append the bullet `- The wall (\`architecture.wall\`, \`WallParams\`, \`Justification\`): mitred joints, Ts and nodes; its two end grips, which move joined ends too; its thickness and justification in the property panel; the Wall tool (W), whose settings the panel edits while it is active.`

- [ ] **Step 10: Run the kit's tests, see them pass.** `cd packages/jet_cad_2d_kit_architecture && dart format . && flutter test`. Expected: `All tests passed!` — `test/wall/` holds 64 tests (Task 11's 44; WT10-WT13, WT15-WT18, WT20; EG1-k, EG3-k, EG4-k, EG6-k; WT3-k, WT9-k; WT-type, WT-settings, WT-bands, WT-frozen, WT-kit); Task 9's SC-conformance and SC-example now see the wall's ids and W.

- [ ] **Step 11: The integration package's support.**
  1. Create `packages/jet_cad_2d_integration/test/support/wall_fixture.dart`: **copy `packages/jet_cad_floor_plan/test/support/wall_fixture.dart:1-301` and `wall_shell.dart:8-51`** (the latter appended after a line `// test/support/wall_shell.dart, unchanged.`), with these adaptations (public libraries only, R-P1):
     - The header below replaces the source's whole import block `:1-9` (its three `dart:` imports are in it); `kitCatalog` is the rig's (R-P14). The appended `wall_shell.dart:8-51` part brings no import of its own (its `:1-6` are not copied).
     - **Not copied** (they need the kit's geometry, which only the kit's copy has): `worldWall` (`:45-55`), `spoke` (`:57-72`), `ringOf` (`:74-84`), `triangulates` (`:157-162`), `wallDoc` (`:171-176`), `reload` (`:295-301`).
     - `:276-282` (`driftOf`, `diagnosticsOf`): `parametricCatalog` → `kitCatalog()`, the doc comments "the floor planner's catalog" → "the kit's types".
     - Every other helper (`ox`, `oy`, `far`, `plan`, `nextUp`, `polar`, `groupAt`, `oracleMeet`, `face`, `distToLine`, `project`, `insideRing`, `diskSamples`, `overlapCensus`, `sharedBitwise`, `nearestIn`, `addWallLocal`, `addWall`, `addSpoke`, `kids`, `kindOf`, `payloadOf`, `pointsOf`, `worldWallOf`, `worldOutline`, `sharedNear`, `isRectNear`, `enc`, `canon`; `walls`, `xy`, `facesOf`, `expectMitre`, `expectSquare`) unchanged.

```dart
// The wall fixture of jet_cad_floor_plan/test/support/wall_fixture.dart and
// wall_shell.dart (3a Task 12), for the integration package's wall tests:
// public libraries only (R-P1), so `WorldWall` and `wallJoin` are
// reproduced over the public `WallParams`, the catalog is the rig's
// `kitCatalog` (R-P14), and the helpers that need the kit's geometry
// (`ringOf`, `worldWall`, `spoke`, `triangulates`, `wallDoc`, `reload`)
// stay in the kit's own copy.
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'editor_rig.dart' show kitCatalog;

/// Every "do these join" decision for walls, as the kit's `wallJoin`
/// (jet_cad_floor_plan/lib/src/parametric/wall.dart:19), reproduced: the
/// kit does not export it (R-P1).
const Tolerance wallJoin = Tolerance(linear: 1e-6, angular: 1e-9);

/// A wall in world space, as the kit's `WorldWall` builds one
/// (wall_geometry.dart:19-62), reproduced over the public [WallParams]
/// (R-P1): its world ends are the stored ends through the group's
/// transform, bit for bit.
final class WorldWall {
  WorldWall(this.handle, WallParams p, this.toWorld)
      : params = p,
        s = toWorld.transformPoint(p.start),
        e = toWorld.transformPoint(p.end),
        t = p.thickness,
        j = p.justification;

  final Handle handle;
  final WallParams params;
  final Transform2 toWorld;
  final Vector2 s, e;
  final double t;
  final Justification j;

  /// The unit direction from start to end.
  late final Vector2 d = (e - s).normalized();

  /// The left and right face offsets along the left normal.
  (double, double) get offsets => switch (j) {
        Justification.centre => (t / 2, -t / 2),
        Justification.left => (t, 0),
        Justification.right => (0, -t),
      };

  /// The start for `k == 0`, the end otherwise.
  Vector2 endpoint(int k) => k == 0 ? s : e;
}
```

  2. Create `packages/jet_cad_2d_integration/test/support/wall_shell.dart` (new; its gestures are today's, `wall_tool_test.dart:84-110` and `wall_grips_test.dart:84-125`):

```dart
// The wall cases' shell harness (jet_cad_floor_plan/test/wall_tool_test.dart
// :37-118 and wall_grips_test.dart:36-121), over the editor rig (R-P14:
// pumpEditor, globalOf, globalAt, status, press are the rig's): a plan of the
// architecture kit built in a new plan's document and saved, so the
// controller opens it as a file with no undo history; the pointer and key
// gestures of today's cases; the Wall tool's settings set through the
// property panel's settings fields. Public libraries only (R-P1).
import 'package:flutter/gestures.dart' show PointerDeviceKind, kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'editor_rig.dart';
import 'wall_fixture.dart';

/// The pages' fixed grid step (wall_tool_test.dart:34,
/// wall_grips_test.dart:35).
const double gridStep = 10;

/// Today's 1:20 page near the far origin, grid snap on at [gridStep].
PageComponent wallPage() => PageComponent(
    scaleDenominator: 20,
    originX: ox - 2000,
    originY: oy - 2000,
    gridStepMm: gridStep);

/// A plan of the architecture kit as a file: a new plan's document given
/// [page], then [build] run on it (the kit's system regenerates what it
/// adds), saved through the controller (its manifest names the kit).
/// Opened, it has no undo history (today's fixtures' `clearHistory`).
String wallPlanJson(
    PageComponent page, void Function(DraftDocument doc) build) {
  final c = architectureController();
  try {
    c.document.commands.execute(
        SetComponentCommand<PageComponent>(c.document.rootHandle, page));
    build(c.document);
    return c.save();
  } finally {
    c.dispose();
  }
}

/// A controller over [plan], disposed at tear-down.
PlanController wallController(String plan) {
  final c = architectureController(json: plan);
  addTearDown(c.dispose);
  return c;
}

/// A primary click at world [p] plus the raw offset `(dx, dy)` in mm.
Future<void> clickAt(WidgetTester tester, PlanController c, Vector2 p,
    [double dx = 0, double dy = 0]) async {
  await tester.tapAt(globalAt(tester, c, Vector2(p.x + dx, p.y + dy)));
  await tester.pump();
}

/// A click near [p]: 12 mm and -9 mm off, well inside the aperture.
Future<void> clickNear(WidgetTester tester, PlanController c, Vector2 p) =>
    clickAt(tester, c, p, 12, -9);

Future<void> undoKey(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
  await press(tester, LogicalKeyboardKey.keyZ);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
  await tester.pump();
}

/// The page grid's point nearest [p], as the drag chain computes it.
Vector2 gridOf(DraftDocument doc, Vector2 p) => snapToGrid(
    p, gridStep, doc.components.get<PageComponent>(doc.rootHandle)!);

/// Sets the active Wall tool's settings through the property panel's
/// settings fields, as today's cases set the tool's notifier
/// (`wallTool(tester).settings.value = ...`, ruling R12-1): [thickness]
/// typed and committed with Enter (which hands the focus back to the
/// canvas), then [justification] picked from its menu.
Future<void> setWallSettings(WidgetTester tester,
    {required String thickness, required Justification justification}) async {
  await tester.enterText(find.byKey(const Key('setting-thickness')), thickness);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
  await tester.tap(find.byKey(const Key('setting-justification')));
  await tester.pumpAndSettle();
  await tester.tap(
      find.byKey(Key('setting-justification-${justification.name}')).last);
  await tester.pumpAndSettle();
}

/// Selects wall [h] with a click in the middle of its band, 40% along it,
/// away from both of its grips (wall_grips_test.dart:84-93).
Future<void> selectWall(
    WidgetTester tester, PlanController c, Handle h) async {
  final w = worldWallOf(c.document, h);
  final n = Vector2(-w.d.y, w.d.x);
  final (l, r) = facesOf(c.document.components.get<WallParams>(h)!);
  await tester.tapAt(
      globalAt(tester, c, w.s + (w.e - w.s) * 0.4 + n * ((l + r) / 2)));
  await tester.pump();
  expect(c.activeSelection.keys, [SelectionKey.root(h)]);
}

/// A mouse drag from world [from] to world [to], past the slop at once.
Future<void> dragWorld(WidgetTester tester, PlanController c, Vector2 from,
    Vector2 to) async {
  final a = globalAt(tester, c, from), b = globalAt(tester, c, to);
  final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
  await gesture.down(a);
  await gesture.moveTo(a + const Offset(12, 0));
  await gesture.moveTo(b);
  await gesture.up();
  await gesture.removePointer();
  await tester.pump();
}

/// Wall [h]'s end [k] in world.
Vector2 endOf(DraftDocument doc, Handle h, int k) =>
    worldWallOf(doc, h).endpoint(k);
```

- [ ] **Step 12: The integration package's ported tests.** Each file is its source's cases with the listed adaptations; **assertions unchanged** but as rulings R12-1 to R12-3 say. The adaptation common to the three files (**A12-shell**):
  - Imports: the source's `jet_cad_floor_plan` imports, `PlannerShell`, `PlannerView` and `tool_palette.dart` go; add `package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart`, `package:jet_cad_2d_plan/jet_cad_2d_plan.dart`, `'../support/editor_rig.dart'`, `'../support/wall_shell.dart'`, `'../support/wall_fixture.dart'` (and nothing under `src/`).
  - A case's controller variable is `ctrl` in `wall_grips_test.dart` (its cases use `c` and `pc` as locals) and `pc` in `wall_tool_test.dart` (WT4 loops over `c`): `PlannerView view` → `PlanController pc` / `ctrl`; `view.document` → `<ctrl>.document`; `tester, view,` → `tester, <ctrl>,`; `view.camera` → `<ctrl>.camera`; `view.selection` → `<ctrl>.activeSelection`.
  - The fixture's document is opened from `wallPlanJson(<page>, <build>)` with `wallController(...)`, then `await pumpEditor(tester, <ctrl>, centre: <centre>, scale: <scale>)` (the rig's; today's cameras are turned 0.35 rad, the rig's default `turn`).
  - `find.byKey(const Key('tool-wall'))` → `find.byKey(const Key('tool-architecture.wall'))` (C7 class 1).
  1. `test/wall/wall_tool_test.dart` ← `wall_tool_test.dart` WT1-WT9 (`:213-546`), WT14 and RF2 (`:666-731`), WT19 (`:861-917`), with today's room points `:20-29` (`c0`..`c3`, `s0`, `_centre`) and helpers `leftOf`, `expectTee`, `drawWall` (`:124-166`) copied. Header:

```dart
// Ported from jet_cad_floor_plan/test/wall_tool_test.dart (3a Task 12):
// the cases that pump the shell (WT1-WT9, WT14, RF2, WT19), over a
// PlanController of the architecture kit in PlanEditor, assertions
// unchanged but for R-P1's: public libraries only, so the tool's settings
// are set through the property panel's settings fields (R12-1),
// `isPending` is read as the guard's `isMidShape` (the rig's activeTool;
// PlacementTool's isMidShape is its isPending, placement_tool.dart:76),
// and the joint kinds (`classify`, a kit internal) are asserted by the
// kit's companions WT3-k and WT9-k (R12-2). The direct cases (WT10-WT13,
// WT15-WT18, WT20) run in the kit.
```

     Imports, exactly (A12-shell's, less what only the source's harness and `directRig` used, so `unused_import`, an error in `analysis_options.yaml`, cannot fire): `dart:math as math` (WT14), `package:flutter/material.dart`, `package:flutter/services.dart show LogicalKeyboardKey`, `package:flutter_test/flutter_test.dart`, `package:jet_cad_2d/jet_cad_2d.dart`, `package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart`, `package:jet_cad_2d_plan/jet_cad_2d_plan.dart`, `package:vector_math/vector_math_64.dart show Vector2`, `'../support/editor_rig.dart'`, `'../support/wall_fixture.dart'`, `'../support/wall_shell.dart'`. The source's `package:flutter/gestures.dart` and `package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart` are **not** imported: every name they gave the shell cases (`FlutterTextMeasurer`, `InteractionLayer`, `ViewportTransform`) goes with the harness, and `kPrimaryButton`, `ToolContext` and the rest were `directRig`'s (the kit's). Of the source's top-level helpers only `c0`-`c3`, `s0`, `_centre` (`:20-29`) and `leftOf`, `expectTee`, `drawWall` (`:124-166`) are copied: `_scale`, `gridStep`, `clickAt`, `clickNear`, `press`, `undoKey`, `status`, `wallTool`, `gridOf` are the rig's or `wall_shell.dart`'s (R-P14), and `directRig`, `pointerAt`, `hoverTo`, `pressAt`, `median` the kit's.
     Then, besides A12-shell:
     - `wallShellDoc(m, {ticks})` (`:37-62`) becomes `String wallShellPlan({bool ticks = true}) => wallPlanJson(wallPage(), (doc) { <the tick loop :51-59, unchanged> });` and `pumpWalls` (`:64-82`) becomes `Future<PlanController> pumpWalls(WidgetTester tester, String plan) async { final pc = wallController(plan); await pumpEditor(tester, pc, centre: _centre, scale: 0.15); return pc; }`; so `final view = await pumpWalls(tester, wallShellDoc(FlutterTextMeasurer()));` → `final pc = await pumpWalls(tester, wallShellPlan());`.
     - `wallTool(tester).isPending` → `activeTool(tester).isMidShape` (R-P1; `:236, :254, :400, :434, :441, :444, :452, :469, :471, :513, :522`, their `reason:` kept).
     - `wallTool(tester).settings.value = const WallSettings(thickness: T, justification: Justification.J);` → `await setWallSettings(tester, thickness: 'T', justification: Justification.J);` (`:250-251`, `:285-286`, `:350-351`); `= const WallSettings();` (`:324`, `:355`) → `thickness: '200', justification: Justification.centre`; WT19's `= const WallSettings(thickness: 50);` (`:904`) → `thickness: '50', justification: Justification.centre` (R12-1).
     - The `classify` expectations (`:142-143` in `expectTee`, `:303`, `:342-343`, `:365-366`, `:544-545`) → `// classify: WT3-k / WT9-k (the kit).` (R12-2); WT9's `final h = await drawWall(...)` (`:532`) → `await drawWall(...)` with the comment `// H, whose joint kind with T WT9-k asserts in the kit.` (its only other reader was the `classify` line).
     - WT14 (`:666-702`): `:669`'s `final doc = wallShellDoc(..., ticks: false);` goes; the clutter loop `:681-687` becomes `final plan = wallPlanJson(wallPage(), (doc) { <the loop :681-687> });`, and `:688-689` (`clearHistory`, the pump) become `final pc = await pumpWalls(tester, plan); final doc = pc.document;` (the `g`, `u`, `n` declarations stay before the loop; the opened plan has no history).
     - WT19 (`:861-917`): the document `:873-887` becomes `final plan = wallPlanJson(PageComponent(scaleDenominator: 20, originX: s.x - 2000, originY: s.y - 2000, gridStepMm: gridStep), (doc) { <the comment and tick loop :882-886> });`, `final pc = wallController(plan); final doc = pc.document;`, and the pump and camera `:888-902` become `await pumpEditor(tester, pc, centre: (s + e) / 2, scale: 100);` (the comment `// 100 px per mm, turned: ...` kept above it).
  2. `test/wall/wall_grips_test.dart` ← `wall_grips_test.dart` EG1-EG6 (`:221-580`) and today's constants and `addL` (`:134-153`), with the new WG-refuse-short appended. Header and helpers:

```dart
// Ported from jet_cad_floor_plan/test/wall_grips_test.dart (3a Task 12):
// EG1-EG6, over a PlanController of the architecture kit in PlanEditor,
// assertions unchanged; the provider-direct tails of EG1, EG3, EG4 and EG6
// use the kit's WallGrips and run in the kit as EG1-k, EG3-k, EG4-k and
// EG6-k (R-P1, R12-3); the shown grips are the controller's grip cache
// (R-P9). EG7, EG8 move to Task 17 and EG9, EG10 to Task 21 (R-P8).
// WG-refuse-short is new (Review Focus 3's kit half, R-P15).
// ignore_for_file: invalid_use_of_internal_member

/// A 1:20 page near the far origin with grid snap on at [gridStep], and
/// the walls [build] adds, as a plan with no undo history
/// (wall_grips_test.dart:36-56's `gripDoc`).
String gripPlan(void Function(DraftDocument doc) build) =>
    wallPlanJson(wallPage(), build);

/// The shown grips of wall [h], as (index, x, y): the controller's grip
/// cache (wall_grips_test.dart:127-131's `gripsOf(view, h)`).
List<(int, double, double)> gripsOf(PlanController c, Handle h) => [
      for (final r in c.grips.grips)
        if (r.key == SelectionKey.root(h)) (r.grip.index, r.grip.x, r.grip.y),
    ];
```

     (imports: A12-shell's, `package:flutter/gestures.dart show PointerDeviceKind, kPrimaryButton`, `package:flutter_test/flutter_test.dart`, `package:jet_cad_2d/jet_cad_2d.dart`, `package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart show SelectionKey`, `package:vector_math/vector_math_64.dart show Vector2`). Then, besides A12-shell:
     - `final doc = gripDoc(FlutterTextMeasurer(), (doc) { ... });` → `final ctrl = wallController(gripPlan((doc) { ... })); final doc = ctrl.document;` (EG1, EG4, EG6; the one-line forms of EG2, EG3, EG5 likewise); `final view = await pumpGrips(tester, doc, X);` → `await pumpEditor(tester, ctrl, centre: X, scale: 0.15);`. EG6's strays (`:487-506`) and their premises (`:507-520`) stay where they are: written into `ctrl.document`'s store before the pump, today's order.
     - `gripsOf(view, h)` → `gripsOf(ctrl, h)`; `view.grips!.grips` → `ctrl.grips.grips` (EG2 `:285`, R-P9).
     - `globalOf(tester, view, <a Vector2>)` (today's file-local Vector2 form, `:84-87`, called in EG1 at `:257` and `:262`) → `globalAt(tester, ctrl, <the same Vector2>)`: the rig's `globalOf` takes `(x, y)` doubles, its `globalAt` a `Vector2` (R-P14).
     - EG1's `:270-272`, EG3's `:334-371`, EG4's `:411-421`, EG6's `:549-579` → one comment each, `// The provider directly: EG<n>-k (the kit).` (R12-3); EG3's local `c` (`:338`) goes with its tail; its local `pc` (`:311`) stays (asserted at `:325`).
     - Append WG-refuse-short:

```dart
  testWidgets(
      'WG-refuse-short (Review Focus 3, spec 3a C1.8) a wall-end grip dragged '
      "onto the wall's other end, where the wall would be no longer than the "
      'join tolerance: a drop there commits nothing and reports nothing; a '
      'drag that passes it and ends on an accepted point commits that point '
      'in one undo step; the grips stay usable', (tester) async {
    final ctrl = wallController(gripPlan((doc) {
      doc.commands.execute(addWall(
          doc, wa, plan(0, 0), plan(3000, 400), 200, Justification.left));
    }));
    final doc = ctrl.document;
    await pumpEditor(tester, ctrl, centre: plan(1500, 400), scale: 0.15);
    final before = canon(doc);
    final reports = ctrl.diagnostics.value.length;
    await selectWall(tester, ctrl, wa);

    // Through the start (object snap puts the pointer on it: the wall
    // would be degenerate there) to an accepted grid point: one step.
    final q = gridOf(doc, plan(3400, 1300));
    final from = globalAt(tester, ctrl, endOf(doc, wa, 1));
    final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
    await gesture.down(from);
    await gesture.moveTo(from + const Offset(12, 0));
    await gesture
        .moveTo(globalAt(tester, ctrl, endOf(doc, wa, 0) + Vector2(4, -3)));
    await tester.pump();
    await gesture.moveTo(globalAt(tester, ctrl, q));
    await gesture.up();
    await gesture.removePointer();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(doc.commands.undoDepth, 1);
    expect((endOf(doc, wa, 1) - q).length, lessThan(1e-6));
    expect(ctrl.diagnostics.value, hasLength(reports));

    // Dropped on the start: refused; nothing committed, nothing reported.
    final moved = canon(doc);
    await dragWorld(
        tester, ctrl, endOf(doc, wa, 1), endOf(doc, wa, 0) + Vector2(4, -3));
    expect(tester.takeException(), isNull);
    expect(doc.commands.undoDepth, 1);
    expect(canon(doc), moved);
    expect(ctrl.diagnostics.value, hasLength(reports));

    // The grips stay usable: the next drag lands, one more step.
    final r = gridOf(doc, plan(2600, -700));
    await dragWorld(tester, ctrl, endOf(doc, wa, 1), r);
    expect(doc.commands.undoDepth, 2);
    expect((endOf(doc, wa, 1) - r).length, lessThan(1e-6));
    expect(ctrl.diagnostics.value, hasLength(reports));
    await undoKey(tester);
    await undoKey(tester);
    expect(canon(doc), before);
  });
```

  3. `test/wall/wall_paint_test.dart` ← `wall_paint_test.dart:1-115`, WP5. Header `// Ported from jet_cad_floor_plan/test/wall_paint_test.dart (3a Task 12): WP5 over a PlanController of the architecture kit in PlanEditor, assertions unchanged.`; imports as A12-shell, **less** `package:jet_cad_2d_plan/jet_cad_2d_plan.dart` (WP5 writes no plan-library name: its controller comes from `wallController`, so the import would be unused, an error), plus `dart:typed_data`, `dart:ui as ui`, `package:flutter/material.dart`, `package:flutter/rendering.dart`, `package:flutter/services.dart show LogicalKeyboardKey`, `package:flutter_test/flutter_test.dart`, `package:jet_cad_2d/jet_cad_2d.dart`, `package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart show InteractionLayer`, `package:vector_math/vector_math_64.dart show Vector2`. Besides A12-shell:
     - The document `:32-45` (the measurer, the page, `clearHistory`) becomes `final ctrl = wallController(wallPlanJson(PageComponent(scaleDenominator: 20, originX: ox - 2900, originY: oy - 2000, snapToGrid: false), (_) {})); final doc = ctrl.document;` followed by the background premise `:43-44` unchanged.
     - The surface, the capture key, the pump and the camera `:47-63` become `// Rotated, 0.2 px per mm: the band is 40 px wide.` and `await pumpEditor(tester, ctrl, centre: far(0, 0), scale: 0.2);`; the local `globalOf(Vector2 p)` (`:65-69`) reads `ctrl.camera`.
     - The capture `:85-86` (today a `RepaintBoundary` keyed around the whole app; the rig pumps the app itself) becomes the outermost repaint boundary around the canvas and its origin, so each global point reads its own pixel:

```dart
    final boundary = tester.renderObject<RenderRepaintBoundary>(find
        .ancestor(
            of: find.byType(InteractionLayer),
            matching: find.byType(RepaintBoundary))
        .last);
    final origin = boundary.localToGlobal(Offset.zero);
```

       and `lumAt`'s `final o = globalOf(p);` (`:95`) → `final o = globalOf(p) - origin;`. The luminance thresholds and sample points are unchanged.
  Check the `°` and `—` (RF2's `'Select — 1 selected'`) literals with `grep -n "°\|—" test/wall/*.dart` against the sources.

- [ ] **Step 13: Run the integration tests.** `cd packages/jet_cad_2d_integration && dart format . && flutter test --enable-vmservice test/wall/`. Expected: `All tests passed!` — 20 tests (WT1-WT9, WT14, RF2, WT19; EG1-EG6, WG-refuse-short; WP5). Then the whole package: `flutter test --enable-vmservice`, `All tests passed!`.

- [ ] **Step 14: The gates.** From the repository root:
  - `cd packages/jet_cad_2d_kit_architecture && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — `All tests passed!`, `No issues found!`, exit 0.
  - `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice && flutter analyze && dart format --output=none --set-exit-if-changed .` — the same. `grep -rn "/src/" packages/jet_cad_2d_integration/test packages/jet_cad_2d_integration/lib | grep import` prints nothing (R-P1).
  - `dart run tool/ci/check_kit_deps.dart` — exit 0.
  - `git status --short`: only this task's files (no `analysis_options.yaml`).

- [ ] **Step 15: Commit.**

```bash
git add packages/jet_cad_2d_kit_architecture/lib/src/wall/wall_grips.dart packages/jet_cad_2d_kit_architecture/lib/src/wall/wall_tool.dart packages/jet_cad_2d_kit_architecture/lib/src/wall/wall_plan.dart packages/jet_cad_2d_kit_architecture/lib/src/kit.dart packages/jet_cad_2d_kit_architecture/lib/jet_cad_2d_kit_architecture.dart packages/jet_cad_2d_kit_architecture/CHANGELOG.md packages/jet_cad_2d_kit_architecture/test/support/wall_shell.dart packages/jet_cad_2d_kit_architecture/test/wall/wall_tool_test.dart packages/jet_cad_2d_kit_architecture/test/wall/wall_grips_test.dart packages/jet_cad_2d_kit_architecture/test/wall/wall_joint_kinds_test.dart packages/jet_cad_2d_kit_architecture/test/wall/wall_plan_test.dart packages/jet_cad_2d_integration/test/support/wall_fixture.dart packages/jet_cad_2d_integration/test/support/wall_shell.dart packages/jet_cad_2d_integration/test/wall/wall_tool_test.dart packages/jet_cad_2d_integration/test/wall/wall_grips_test.dart packages/jet_cad_2d_integration/test/wall/wall_paint_test.dart
git commit -m "$(cat <<'EOF'
feat(architecture): the wall's type, grips, tool and settings (3a C3.2)

wallPlanType (thickness, strict as today, and justification, both behind
reshape; the end grips over the services' live walls) and wallPlanTool
(W, its settings read from the plan per event, the kit's shared band
cache) join the kit. The tool and grip tests are split by C7 and R-P1:
the direct cases, the provider tails and the joint kinds in the kit, the
shell cases in the integration package over the plan editor.
WG-refuse-short pins a grip drop on a refused point: nothing committed,
nothing reported, the grips still usable.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 16: Mutation check** (committed files only; after each: run the named test, see it red, quote the red line, then `git checkout -- <file>` and `git diff --quiet -- <file>` must exit 0). Kit tests run with `cd packages/jet_cad_2d_kit_architecture && flutter test <file>`, integration tests with `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice <file>`.
  - M-WT-1 `lib/src/wall/wall_plan.dart`: `_thickness`'s body → `t` (`double _thickness(double t) => t;`) → `test/wall/wall_plan_test.dart` WT-type and WT-settings red (`wallJoin.linear` accepted).
  - M-WT-2 `wall_plan.dart`: delete the type's thickness `gate: PlanGate.reshape` → WT-type red.
  - M-WT-3 `wall_plan.dart`: in `create`, `() => services.settingsOf<WallSettings>(ArchitectureTools.wall)` → `() => const WallSettings()` → WT-settings red (200 centre drawn).
  - M-WT-4 `wall_plan.dart`: in `create`, `wallBandsOf(services)` → `WallBands(liveTypesOf(services))` → WT-bands red (the shared cache's generation does not move).
  - M-WT-5 `lib/src/wall/wall_grips.dart`: in `_endsAt`, `wallsInDocument(d, group, _live)` → `wallsInDocument(d, group, (_) => ArchitectureTypes.wall)` (with `import '../ids.dart';`) → WT-frozen red (the frozen wall follows).
  - M-WT-6 `wall_grips.dart`: in `gripsOf`, the same substitution → WT-frozen red (the frozen wall offers grips).
  - M-WT-7 `wall_plan.dart`: delete `grips: (services) => WallGrips(live: liveTypesOf(services)),` → WT-frozen red (`gripsFor` null).
  - M-WT-8 `lib/src/kit.dart`: `tools: [boxPlanTool, wallPlanTool]` → `tools: [boxPlanTool]` → WT-kit red; integration `test/wall/wall_tool_test.dart` WT7 red (no `tool-architecture.wall`, W does nothing).
  - M-WT-9 `wall_plan.dart`: `letter: 'W'` → `letter: 'Q'` → WT-settings red; integration WT1 red (`status` stays `Select`).
  - M-WT-10 `wall_plan.dart`: the tool's justification `write: (s, j) => s.copyWith(justification: j)` → `write: (s, j) => s` → WT-settings red; integration WT2 red (B drawn centre, not left).
  - M-WT-11 `lib/src/wall/wall_tool.dart`: `_joinBandInto`'s `return _bands.joinInto(ctx.document, px, py, out);` → `return false;` → `test/wall/wall_joint_kinds_test.dart` WT3-k red (no Tee), and `test/wall/wall_tool_test.dart` WT10 red.
  - M-WT-12 `wall_tool.dart`: `if (!(ctx.snap?.objectSnap ?? true)) return false;` → `if (false) return false;` → WT9-k red (the band joins with object snap off).
  - M-WG-1 `wall_grips.dart`: in `_moved`, `if (!((w.e - w.s).length > wallJoin.linear)) return null;` → `if (!((w.e - w.s).length > wallJoin.linear)) throw StateError('short');` → integration `test/wall/wall_grips_test.dart` WG-refuse-short red (a `hookFailed` diagnostic; the grips blacked out, so the drop at `q` commits nothing), and kit EG1-k red.
  - M-WG-2 `wall_grips.dart`: delete that line → WG-refuse-short red (the drop on the start commits a degenerate wall: `undoDepth` 2), and EG1-k red.
  (Under Task 7's C1.8 an `ArgumentError` from `_moved` would be another lawful refusal — no move, no diagnostic — so `throw ArgumentError(...)` is an equivalent mutant of `return null`, not listed.)

#### Assumed from earlier tasks

- Task 11: the names in Consumes, as its part gives them; `test/support/wall_fixture.dart` re-exports `testCatalog` and `installParametric` and gives `liveOf(doc, {frozen})`.
- Task 9: `architectureKit` with `names` holding every wall word of the plan's table in English, German and Turkish (WT-kit's `validate()` and Task 9's SC-conformance hold them); the rig's `pumpEditor(tester, c, {Locale locale, Vector2? centre, double scale = 2, double turn = 0.35})`, `globalOf(tester, c, double x, double y)`, `activeTool(tester)`, `kitCatalog()`; the integration pubspec lists `jet_cad_2d`, `jet_cad_2d_flutter`, `jet_cad_2d_kit` and `vector_math` (R-P6).
- Task 2 (R-P4, R-P7): `fieldsOf(document, group, words)` and `commitField(document, group, field, input, words)`; `KitNamesWords(KitNames, Locale Function())` is a `PlanWords`.
- Task 6: `FakePlanServices(document:, catalog:, frozen:, settings:)`, `dispose()`; `settingsOf` reads the given map (R-P12).
- Task 7: C1.8 as in Consumes; it does not change what a provider's `null` means.
- The plan library: its property panel shows the active tool's settings with keys `setting-<spec id>` and a choice's items `setting-<spec id>-<value>` (`plan_property_panel.dart:700-745`), and Enter in a field hands the focus back to the canvas (`:683-685`).

#### New shared name

- `WallGrips({required LiveTypeOf live})` (`lib/src/wall/wall_grips.dart`); Task 14 adds `_keptPut`/`_seated` back into `drag` (`wall_grips.dart:63-66, 69-127` today) and their class-doc bullet; Tasks 17 and 21 build it for EG7-EG10's provider halves.
- `WallTool(WallSettings Function() settings, WallBands bands)`, `WallSettings` (`lib/src/wall/wall_tool.dart`): Task 26's and Task 27's wall rows (the Wall-tool settings case, WS cases) reach the settings through the panel's `setting-thickness`/`setting-justification` fields.
- Integration `test/support/wall_fixture.dart` (the public-only wall fixture: `WorldWall` and `wallJoin` reproduced, `worldWallOf`, `worldOutline`, `addWall`, `addSpoke`, `canon`, `driftOf`, `diagnosticsOf`, `expectMitre`, `expectSquare`, ...) and `test/support/wall_shell.dart` (`wallPlanJson`, `wallController`, `wallPage`, `gridStep`, `clickAt`, `clickNear`, `undoKey`, `gridOf`, `setWallSettings`, `selectWall`, `dragWorld`, `endOf`): every later integration task that builds walls (14, 15, 17, 19, 21, 26-28) imports them rather than a second copy (R-P14).

#### Carried to later tasks (R-P8)

- **Task 14:** `_keptPut` and `_seated` into `WallGrips.drag` (with their tests, `opening_end_drag_test`).
- **Task 17:** `wall_grips_test.dart` EG7, EG8 (`:582-653`): `shadowDoc` (`:155-218`) builds a door on C and a separator. The shell halves in the integration package over this task's `wall_shell.dart`; the provider-direct halves (`WallGrips(live: ...)`'s command and preview, EG8 `:626-639`) in the kit (Task 17's Step 7b).
- **Task 21:** EG9, EG10 (`:655-892`): they read `wallsInDocument`, `openingsInDocument`, `WallBands`, `attachCandidates`, `thickestWall`, `RoomInputs`, `ObjectGrips`' successors (the opening's, the separator's and the dimension's grips) and the opening and dimension panel sections; split by R-P1 the same way.

#### Interface problem

- **(Resolved by ruling R-P17: the preview at a refused point is empty, today's.)** **R-P15's preview clause is not today's.** R-P15 says "the preview keeps the last accepted state". Today the preview is **empty** while the pointer is on a refused point: `WallGrips.preview` returns `const []` when `_moved` refuses (`jet_cad_floor_plan/lib/src/parametric/wall_grips.dart:137-138`), and the plan's `GripDrag.moveTo` stores that list as the preview (`jet_cad_2d_flutter/lib/src/grip_drag.dart:262-263`); EG1 asserts it (`wall_grips_test.dart:272`: `preview(...)` at the refused point `isEmpty`), ported unchanged as EG1-k. The preview is not public, so WG-refuse-short asserts the rest of R-P15 (no commit at a refused drop, no diagnostic, grips usable, a later drag in one step). Proposed fix: Review Focus 3 reads "the preview is empty while the pointer is on the refused point (today's), a drop there commits nothing, nothing is reported, the grips stay usable and a later drag commits in one undo step"; keeping the last accepted state would be a behaviour change needing the human's word.
- **(Resolved by ruling R-P17: positional `live`; R-P6's named form struck.)** **R-P6 against R-P8 on `wallsInDocument`.** R-P6 gives `{required LiveTypeOf live}`, R-P8 and Task 13's part the positional `wallsInDocument(doc, host, LiveTypeOf live, {moved})`. Tasks 11 and 12 use the positional form; Task 15's part (`wallsInDocument(doc, host, _live)`) and Task 14's agree. Proposed: strike R-P6's form.

---

