### Task 15: The opening tools (spec C3.3, C1.5, C1.11, C6, C7)

**Files:**
- Create (`packages/jet_cad_2d_kit_architecture/`):
  - `lib/src/opening/opening_tool.dart` (ported: `OpeningSettings`, `OpeningTool`, `isUsableHost`; new `openingToolIdOf`)
  - `test/opening/opening_tool_test.dart` (ported kit cases; OT1 (preview), moved from OT1 (shell); new OL-tools, OL-settings, OL-frozen)
- Modify (`packages/jet_cad_2d_kit_architecture/`):
  - `lib/src/opening/opening_plan.dart` (`doorPlanTool`, `windowPlanTool`, `gapPlanTool`)
  - `lib/src/kit.dart` (`tools:` gains the three right after `wallPlanTool`)
- Create (`packages/jet_cad_2d_integration/`): `test/opening/opening_tool_test.dart` (ported OT1 (shell), OT1 (rv9-guardDNG))
- Modify (`packages/jet_cad_2d_integration/`): `test/opening/opening_panel_test.dart` (ported OS1 (runtime), OS3), `test/opening/opening_kink_test.dart` (ported KJ3), `test/support/opening_support.dart` (`placementOf`, `settingsText`, `toolSection`, `settingWidth`)

**Interfaces:**
- Consumes:
  - Task 2/2a: `PlanTool(id, icon, letter, needs, settings, create)`, `PlanToolSettings<S>(initial, specs)` and its `fieldsOf(value, store, toolId:)` (words `property:<tool id>.<spec id>`), `LengthProperty`.
  - Task 6: `PlanServices.settingsOf<S>(toolId)`, `PlanServices.shared`, `liveTypeIdOf`; `FakePlanServices({required DraftDocument document, ParametricCatalog? catalog, Set<Handle> frozen, double scale, Map<String, Object> settings, …})`, `dispose()`.
  - Task 9: `ArchitectureTools.{door,window,gap,wall}`, `liveTypesOf`, `architectureKit`; the words `tool:architecture.{door,window,gap}` ('Door', 'Window', 'Gap' in English), `property:architecture.{door,window,gap}.width`.
  - Task 11: `WallBands` (`hostAt(doc, x, y, {accept})`, `generation`, `invalidate()`), `wallBandsOf(PlanServices s)`, `wallsInDocument(doc, host, live, {moved})`.
  - Task 12: `wallPlanTool` (in `architectureKit.tools`).
  - Task 13: the opening's geometry (`layoutOf`, `openingsInDocument(doc, host, live)`, `cutsOf`, `storedCentreOf`, `edgeSnap`, `symbolOf`, `Cut`, `HostLayout`), `OpeningParams`, `OpeningKind`, `HingeEnd`, `SwingSide`, `isOpeningWidth`; kit test support (`liveOf`, `testCatalog`, the oracles).
  - Task 14: `openingWidthOf(OpeningKind kind, double w)`, `openingPlanType`; the integration support `opening_support.dart` and the C6 convention R14-8.
  - Flutter layer: `PlacementTool` (`hoverPoint`, `markerPoint`, `paintRubberBand`, `commit`), `ToolContext`, `SnapSettings`, `SelectionController`, `CameraController`, `ViewportTransform`, `drawingLayer`.
- Produces (Shared interfaces, Task 15):

```dart
// lib/src/opening/opening_plan.dart
final PlanTool doorPlanTool;    // architecture.door, letter D
final PlanTool windowPlanTool;  // architecture.window, letter N
final PlanTool gapPlanTool;     // architecture.gap, letter G
// lib/src/opening/opening_tool.dart (internal)
@immutable final class OpeningSettings { const OpeningSettings({required double width});
  factory OpeningSettings.defaultFor(OpeningKind kind); /* copyWith, ==, hashCode, toString unchanged */ }
String openingToolIdOf(OpeningKind kind);  // ArchitectureTools.door/window/gap
class OpeningTool extends PlacementTool { OpeningTool(OpeningKind kind, PlanServices services); }
bool isUsableHost(DraftDocument doc, Handle wall);
```

**Appendix A rows closed:** D-19's last opening rows: `opening_tool_test` (18: 16 in the kit — OT1 (stored centre), OT1 (ffw-noFitRaw), OT2, OT2 (rv9-hingeRaw), OT2 (rv9-swingResolved), OT1 (rv9-selfFirst), OT1 (liveness), OT3 (pure), OT3 (X10-gate), OT3 (rv10-storedCuts), OT3 (t11-apertureDir), OT5, OT4 (X9-cache), OT4 (t10-scanMemo), OT4 (cost), HF7; 2 in C6 — OT1 (shell), OT1 (rv9-guardDNG)), `opening_kink_test` KJ3 (C6), `opening_panel_test` OS1 (runtime) and OS3 (C6). 21 cases; with Tasks 13 (32) and 14 (32) every one of the opening's 85 cases is ported. Contributes to D-26 (the D, N, G rows; Task 26 closes it) and D-48 (the palette entries and per-tool strings from the kit's `PlanTool`s; Task 26).

**Plan rulings (this task):**
- **R15-1 (the tool over the services).** Today's `OpeningTool(kind, ValueNotifier<OpeningSettings> settings, {WallBands? bands})` (`opening_tool.dart:88-101`) owned its settings in the shell and shared the shell's band cache. In the kit: `OpeningTool(kind, services)`; the width is `services.settingsOf<OpeningSettings>(openingToolIdOf(kind)).width`, read at each hover and click as today's tool read `settings.value` (spec C1.5: the tools read their settings per event; no listenable, D-40); the band cache is the kit's shared `wallBandsOf(services)` (disposed with the document by the plan, so `dispose` no longer disposes it); the document adapters take `liveTypesOf(services)`. The tool still reads object snap from its `ToolContext` (`ctx.snap?.objectSnap ?? true`, `:192`), still consults the layer record for its host (`isUsableHost`, `:447-450`), and has no keys (today's: only the dimension tool has keys, spec Facts). Everything else is today's code.
- **R15-2 (OT1 (shell)'s preview line).** OT1 (shell) reads the hovered tool's preview (`door.debugPreview`, `opening_tool_test.dart:263-264`), an `OpeningTool` member; under R-P1 the integration package cannot name `OpeningTool`. The line moves to the kit as the case "OT1 (preview)", the same hover (the Door tool at 750, 1,300 along A and 37 off it) and the same assertion; the rest of OT1 (shell) stays one C6 case. The assertion is kept, in another file.
- **R15-3 (a tool's settings in C6).** OS3 asserts each tool's settings keystroke by keystroke (`door.settings.value.width`). In C6 the settings are the plan's (`PlanController.servicesOf('architecture').settingsOf`, `@internal`, R14-8) and their type, `OpeningSettings`, is the kit's internal one (C2's narrow surface, R-P1). `settingsText(c, toolId)` reads them through `toString`, which is today's `'OpeningSettings($width)'` ported unchanged: `expect(door.settings.value.width, want)` becomes `expect(settingsText(c, ArchitectureTools.door), 'OpeningSettings($want)')` with `want` the same `double`. The asserted width is unchanged. OT1 (shell)'s `door.settings.value = const OpeningSettings(width: 750)` (a fixture write) becomes typing `750` into the tool's settings field with the tool active, as a user does.
- **R15-4 (finders, C7 class 3, as R14-10).** The palette's `tool-door`, `tool-window`, `tool-gap`, `tool-select` → `tool-architecture.door`, `tool-architecture.window`, `tool-architecture.gap`, `tool-plan.select`; in tool mode the panel shows the tool's settings section, `Key('settings-architecture.door')` (titled with `tool:architecture.door`, 'Door'), and its width field `Key('setting-width')`, where today's one Opening section showed `opening-section` and `opening-width` in both modes. `tool.name` in OT1's status check → the tool's word (`'Door'`, `'Window'`, `'Gap'`, today's names). Values unchanged.
- **R15-5 (C7 placement, R-P1).** Kit: every `test(` case of `opening_tool_test` (they drive the tool directly, `directRig`, over kit internals). C6: OT1 (shell), OT1 (rv9-guardDNG), KJ3, OS1 (runtime), OS3: they pump today's `PlannerShell` and name no kit internal once R15-2 and R15-3 apply.

- [ ] **Step 1: Precondition.** Tasks 6, 9-14 are committed; the kit's and the integration package's tests pass (`flutter test`; `flutter test --enable-vmservice`). `grep -n "OpeningTool\|doorPlanTool" packages/jet_cad_2d_kit_architecture/lib/src/kit.dart`: no match. Any other result is a finding: stop and report it.

- [ ] **Step 2: The failing kit tests.** Create `packages/jet_cad_2d_kit_architecture/test/opening/opening_tool_test.dart` from `jet_cad_floor_plan/test/opening_tool_test.dart`, cases' names, order and assertions unchanged (A12), with a first line `// Ported from jet_cad_floor_plan/test/opening_tool_test.dart (spec 3a C3.3, C7, R15-5).`:
  - Header comment `:1-9` kept. Imports: `dart:math`, `package:flutter/gestures.dart show kPrimaryButton`, `package:flutter/material.dart` (for `Canvas`, `Rect`, `Paint`, `Offset` in `MarkerSpy` and the events), `flutter_test`, `jet_cad_2d`, `jet_cad_2d_flutter`, `vector_math`, then `package:jet_cad_2d_kit/testing.dart`, `package:jet_cad_2d_kit_architecture/src/ids.dart`, `…/src/kit.dart`, `…/src/opening/opening.dart`, `…/src/opening/opening_geometry.dart`, `…/src/opening/opening_plan.dart`, `…/src/opening/opening_tool.dart`, `…/src/wall/wall.dart`, and `'../support/opening_fixture.dart'`, `'../support/wall_fixture.dart'`, `'../support/wall_shell.dart'`. Not imported: `planner_shell.dart`, `planner_view.dart`, `tool_palette.dart`, `package:flutter/services.dart` (the shell's).
  - Copy `:31-33` (`centre`, `left`, `right`) and `:119-130` (`openings`, `addWallFromSeed`); the shell section `:34-117` (`_scale`, `gridStep`, `_centre`, `toolShellDoc`, `pumpTools`, `clickAt`, `press`, `undoKey`, `status`, `openingTool`, `gridOf`) is C6's and is not copied.
  - The rig `:132-164` becomes (R15-1):

```dart
// ---------------------------------------------------------------------------
// The tool driven directly, as `wall_tool_test.dart` drives the Wall tool,
// over the kit's test double of the plan's services (spec 3a C1.11).

typedef Rig = ({
  OpeningTool tool,
  ToolContext ctx,
  Map<String, Object> settings,
});

/// An opening tool of [kind] over [doc]: a camera at [scale] pixels per mm
/// (the default, 1, gives a 10 mm aperture), object snap as [snap] says
/// (none: on), no page (no grid), the tool's settings at today's default
/// in [Rig.settings], which the services read at each event ([setWidth]),
/// and [frozen] objects the services call not live (spec 2a E2).
Rig directRig(DraftDocument doc, OpeningKind kind,
    {double scale = 1, SnapSettings? snap, Set<Handle> frozen = const {}}) {
  final settings = <String, Object>{
    openingToolIdOf(kind): OpeningSettings.defaultFor(kind),
  };
  final services = FakePlanServices(
      document: doc,
      catalog: testCatalog(),
      frozen: frozen,
      scale: scale,
      settings: settings);
  final index = SpatialIndex(doc);
  final camera = CameraController(
      ViewportTransform(worldToScreenMatrix: Transform2.scale(scale, scale)));
  final selection = SelectionController(doc);
  final tool = OpeningTool(kind, services);
  addTearDown(() {
    tool.dispose();
    services.dispose();
    selection.dispose();
    camera.dispose();
    index.dispose();
  });
  return (
    tool: tool,
    ctx: ToolContext(
        document: doc,
        index: index,
        camera: camera,
        selection: selection,
        snap: snap),
    settings: settings,
  );
}

/// The tool's settings now hold [width] (today's `tool.settings.value =
/// OpeningSettings(width: width)`).
void setWidth(Rig rig, double width) =>
    rig.settings[openingToolIdOf(rig.tool.kind)] =
        OpeningSettings(width: width);
```

  - Copy `:166-203` unchanged (`pointerAt`, `hoverTo`, `pressAt`, `median`, `added`, `numbersOf`, `MarkerSpy`).
  - Cases, in today's order: OT1 (stored centre) `:346`, OT1 (ffw-noFitRaw) `:407`, OT2 `:442`, OT2 (rv9-hingeRaw) `:489`, OT2 (rv9-swingResolved) `:518`, OT1 (rv9-selfFirst) `:545`, OT1 (liveness) `:590`, OT3 (pure) `:668`, OT3 (X10-gate) `:700`, OT3 (rv10-storedCuts) `:795`, OT3 (t11-apertureDir) `:851`, OT5 `:892`, OT4 (X9-cache) `:933`, OT4 (t10-scanMemo) `:1031`, OT4 (cost) `:1054`, HF7 `:1111`. Adaptations: `rig.tool.settings.value = const OpeningSettings(width: w)` → `setWidth(rig, w)` (`:559`, `:759`, `:824`, `:879`; `:771`'s `on.tool.settings.value = …` → `setWidth(on, 600)`); Task 13's A13-live at `:721`, `:1127`, `:1129`. Assertions unchanged: OT1 (liveness)'s strays (a node-less handle, a nested group) answer null from the services' `liveTypeIdOf` over `testCatalog`, so they host nothing, as today.
  - Then, after HF7, the moved line (R15-2):

```dart
  test(
      'OT1 (preview) the hover of OT1 (shell), in the kit (R15-2): with the '
      'Door tool at 750, a hover 1,300 along A and 37 off it builds the '
      'leaf, the arc and the two jambs, and commits nothing', () {
    final doc = wallDoc();
    final a = addWallFromSeed(doc, plan(0, 0), plan(5000, 0), 200, centre);
    addWallFromSeed(doc, plan(5000, 0), plan(5000, 3000), 115, left);
    doc.commands.clearHistory();
    final fa = oracleFrameOf(doc, a);
    final rig = directRig(doc, OpeningKind.door);
    setWidth(rig, 750);
    hoverTo(rig, oracleAt(fa, 1300, 37));
    expect([for (final (k, _) in rig.tool.debugPreview) k],
        [EntityKind.line, EntityKind.arc, EntityKind.line, EntityKind.line]);
    expect(openings(doc), isEmpty);
  });
```

  - Then the new cases:

```dart
  test(
      'OL-tools (spec 3a C3.3) D, N and G: ids, letters, needs; each '
      'tool\'s settings start at today\'s defaults (900, 1,200, 900) and '
      'refuse a width its kind may not take; the kit carries them right '
      'after the Wall tool, and validates', () {
    final tools = [doorPlanTool, windowPlanTool, gapPlanTool];
    expect([for (final t in tools) (t.id, t.letter)], [
      (ArchitectureTools.door, 'D'),
      (ArchitectureTools.window, 'N'),
      (ArchitectureTools.gap, 'G'),
    ]);
    for (final t in tools) {
      expect(t.needs,
          {Capability.structure, Capability.components, Capability.geometry},
          reason: t.id);
    }
    expect([for (final t in tools) (t.settings!.initial as OpeningSettings).width],
        [900, 1200, 900]);

    Object? kept;
    final gap = gapPlanTool.settings!
        .fieldsOf(const OpeningSettings(width: 900), (v) => kept = v,
            toolId: ArchitectureTools.gap)
        .single;
    expect(gap.wordId, 'property:architecture.gap.width');
    expect(() => gap.commit!(0.000004), throwsArgumentError);
    expect(kept, isNull, reason: 'not above 4 × wallJoin.linear');
    gap.commit!(0.000005);
    expect(kept, const OpeningSettings(width: 0.000005));
    final door = doorPlanTool.settings!
        .fieldsOf(const OpeningSettings(width: 900), (v) => kept = v,
            toolId: ArchitectureTools.door)
        .single;
    expect(() => door.commit!(0.000001), throwsArgumentError);
    door.commit!(0.000004);
    expect(kept, const OpeningSettings(width: 0.000004));

    final ids = [for (final t in architectureKit.tools) t.id];
    final w = ids.indexOf(ArchitectureTools.wall);
    expect(ids.sublist(w, w + 4), [
      ArchitectureTools.wall,
      ArchitectureTools.door,
      ArchitectureTools.window,
      ArchitectureTools.gap,
    ]);
    expect(architectureKit.validate(), isEmpty);
  });

  test(
      'OL-settings (spec 3a C3.3, R15-1) the tool reads its width from the '
      'plan\'s settings at each click: a change between two clicks gives '
      'the second door the new width', () {
    final doc = wallDoc();
    final a = addWallFromSeed(doc, plan(0, 0), plan(5000, 0), 200, centre);
    final f = oracleFrameOf(doc, a);
    doc.commands.clearHistory();
    final rig = directRig(doc, OpeningKind.door);
    final none = openings(doc);
    pressAt(rig, oracleAt(f, 1200, 40));
    final first = added(doc, none);
    setWidth(rig, 750);
    final one = openings(doc);
    pressAt(rig, oracleAt(f, 3600, 40));
    final second = added(doc, one);
    expect([
      for (final h in [first, second])
        doc.components.get<OpeningParams>(h)!.width
    ], [900, 750]);
  });

  test(
      'OL-frozen (spec 3a C1.5) a wall the plan has frozen is no host and '
      'no obstacle for the opening tools: a click on it places nothing; a '
      'door clicked on a live wall where the frozen one crosses it is '
      'stored at the click, unclamped', () {
    final doc = wallDoc();
    final a = addWallFromSeed(
        doc, plan(0, 0), plan(4000, 0), 200, Justification.left);
    final fa = oracleFrameOf(doc, a);
    final x = addWallFromSeed(doc, oracleAt(fa, 1800, -900),
        oracleAt(fa, 1950, 900), 150, centre);
    final fx = oracleFrameOf(doc, x);
    doc.commands.clearHistory();
    expect(OpeningOracle(doc).obstacles(a), hasLength(1),
        reason: 'premise: X crosses A');
    final rig = directRig(doc, OpeningKind.door,
        frozen: {x}, snap: SnapSettings(objectSnap: false));
    // On X, away from A.
    pressAt(rig, oracleAt(fx, 1500, 30));
    expect(openings(doc), isEmpty, reason: 'a frozen wall hosts nothing');
    expect(doc.commands.undoDepth, 0);
    // On A, where X crosses it: no obstacle, so no clamp.
    pressAt(rig, oracleAt(fa, 1875, 60));
    final o = doc.components.get<OpeningParams>(openings(doc).single)!;
    expect(o.host, a);
    expect(o.position, closeTo(1875, 1e-6));
  });
```

  Check every non-ASCII literal against the source with `grep -n` after writing.

- [ ] **Step 3: The C6 ports (R15-5).** In `packages/jet_cad_2d_integration/`:
  1. `test/support/opening_support.dart` gains:

```dart
/// The unwrapped tool [toolId] of [c]'s document (today's palette entry's
/// tool), as the Flutter layer's placement tool: its resolved hover point.
PlacementTool placementOf(PlanController c, String toolId) =>
    c.toolFor(toolId)! as PlacementTool;

/// The tool [toolId]'s settings as the plan holds them, through their
/// `toString`, today's `'OpeningSettings($width)'` (R15-3).
String settingsText(PlanController c, String toolId) =>
    '${c.servicesOf('architecture').settingsOf<Object>(toolId)}';

/// A tool's settings section (R15-4) and its width field.
Finder toolSection(String toolId) => find.byKey(Key('settings-$toolId'));
Finder get settingWidth => find.byKey(const Key('setting-width'));

/// Every opening, ascending (today's `openings`).
List<Handle> openings(DraftDocument doc) =>
    doc.components.withComponent<OpeningParams>().toList();

/// The one opening [doc] gained over [before] (today's `added`).
Handle added(DraftDocument doc, List<Handle> before) =>
    openings(doc).where((o) => !before.contains(o)).single;

/// Adds a wall with a handle from the seed, as a tool would (today's
/// `addWallFromSeed`).
Handle addWallFromSeed(
    DraftDocument doc, Vector2 s, Vector2 e, double t, Justification j) {
  final h = doc.handleSeed.next();
  doc.commands.execute(addWall(doc, h, s, e, t, j));
  return h;
}
```

  2. Create `test/opening/opening_tool_test.dart` (`// Ported from jet_cad_floor_plan/test/opening_tool_test.dart (spec 3a C6, C7, R15-2..R15-5).` and `// ignore_for_file: invalid_use_of_internal_member`), with OT1 (shell) (`:206-344`) and OT1 (rv9-guardDNG) (`:633-666`):
     - `pumpTools(tester, toolShellDoc(FlutterTextMeasurer()))` → `final c = openingController(openingPlanText(shellPage, (_) {}));` then `await pumpEditor(tester, c, centre: plan(2500, 1500), scale: 0.15);` and `final doc = c.document;` (the walls are then added on the controller's document from the seed, as today, regenerated by its system).
     - The palette loop (`:222-231`): keys per R15-4; names unchanged.
     - `place(OpeningTool tool, Vector2 raw)` → `place(String toolId, String word, Vector2 raw)`: `tool.hoverPoint` → `placementOf(c, toolId).hoverPoint`; `expect(status(tester), tool.name, …)` → `expect(status(tester), word, …)`; `clickAt(tester, view, raw)` → `tapWorld(tester, c, raw)`.
     - `door.settings.value = const OpeningSettings(width: 750); await press(tester, keyD);` → `await press(tester, keyD); await enterAndSubmit(tester, settingWidth, '750');` (R15-3); the same for N (1000) and G (640). `final door = openingTool(tester, 'tool-door')` and its siblings are dropped.
     - The hover (`:258-265`): the mouse `moveTo` stays, with `view.camera` → `cameraOf(c)`; the `door.debugPreview` assertion moves to the kit (R15-2); `expect(openings(doc), isEmpty)` stays.
     - `undoKey`, `press`, `status`, `gridOf`, `diagnosticsOf`, `driftOf`, `OpeningOracle`, `oracleFrameOf`, `oracleAt`, `oracleU`, `xy` from the support.
     - OT1 (rv9-guardDNG): `pumpTools` as above; `clickAt` → `tapWorld`; `Key('page-scale')` is the plan's page panel's (`plan_page_panel.dart:262`). Assertions unchanged.
  3. `test/opening/opening_panel_test.dart` gains OS1 (runtime) (`:299-349`) after OS1, and OS3 (`:404-496`) after OS2, in today's order, adapted as Task 14's Step 5.2 plus: `openingTool(tester, 'tool-door')` and its siblings dropped; `door.settings.value.width` → `settingsText(c, ArchitectureTools.door)` compared with `'OpeningSettings($want)'` (and `window`, `gap` alike; `expect(window.settings.value.width, 1200, …)` → `expect(settingsText(c, ArchitectureTools.window), 'OpeningSettings(1200.0)', …)`, `gap` `'OpeningSettings(900.0)'`, `door` `'OpeningSettings(720.0)'`); in tool mode `tester.widget<Text>(section).data` → `tester.widget<Text>(toolSection(ArchitectureTools.door)).data` (and `.window`, `.gap` after N and G), and `width` → `settingWidth` (R15-4); `position` and `flipHinge` stay the object's finders (asserted absent in tool mode, as today); after `press(keyV)`, `width` and `position` are the object's again. Assertions unchanged.
  4. `test/opening/opening_kink_test.dart` gains KJ3 (`:288-311`) before KJ4: `shellDoc((d) => addKink(d, 2))` → `openingController(openingPlanText(shellPage, (d) => addKink(d, 2)))`; `pumpShell` → `pumpEditor`; `tapWorld(tester, view, …)` → `tapWorld(tester, c, …)`; `hostFrameInDocument(doc, hA)!.uE` → `OpeningOracle(c.document).span(hA).$2` (R14-9). Assertions unchanged.

- [ ] **Step 4: Run them: they fail.** `cd packages/jet_cad_2d_kit_architecture && flutter test test/opening/opening_tool_test.dart`: compilation errors (`opening_tool.dart` missing; `doorPlanTool` undefined). `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice test/opening/`: OT1 (shell), OT1 (rv9-guardDNG), KJ3, OS1 (runtime), OS3 red (no `tool-architecture.door` in the palette; `toolFor` returns null); Task 14's cases still green. Quote the first failure of each.

- [ ] **Step 5: Port `opening_tool.dart`.** Create `lib/src/opening/opening_tool.dart` from `jet_cad_floor_plan/lib/src/parametric/opening_tool.dart`:
  - Lines 1-12 become:

```dart
import 'dart:ui' show Canvas, Offset, Rect;

import 'package:flutter/foundation.dart' show immutable, visibleForTesting;
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show PlanServices;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../ids.dart';
import '../live.dart';
import '../wall/wall_bands.dart';
import '../wall/wall_geometry.dart' show wallsInDocument;
import 'opening.dart';
import 'opening_geometry.dart';
```

  - Lines 14-16 (the settings' doc) become `/// An opening tool's settings (spec 08 D14, Ruling 08-17): the width of the` / `/// next opening, in mm. The plan holds one per tool (spec 2a P3); the` / `/// property panel edits the active tool's (spec 3a C3.3).`; lines 17-39 unchanged. Then add:

```dart
/// The tool id of the opening tool of [kind] (spec 3a C2).
String openingToolIdOf(OpeningKind kind) => switch (kind) {
      OpeningKind.door => ArchitectureTools.door,
      OpeningKind.window => ArchitectureTools.window,
      OpeningKind.gap => ArchitectureTools.gap,
    };
```

  - Copy lines 41-87 unchanged, adding to the class doc after `:87`: `///` / `/// Ported from jet_cad_floor_plan's lib/src/parametric/opening_tool.dart` / `/// (spec 3a C3.3, R15-1): the width, the band cache and the live walls` / `/// come from the plan's services.`
  - Lines 88-101 become:

```dart
class OpeningTool extends PlacementTool {
  /// An opening tool of [kind] over [services]: the width is the plan's
  /// settings of [openingToolIdOf] `(kind)`, read at each hover and click;
  /// the band cache is the kit's shared one ([wallBandsOf]); the walls and
  /// openings it sees are the services' live ones (spec 3a C1.5).
  OpeningTool(this.kind, this.services)
      : _bands = wallBandsOf(services),
        _live = liveTypesOf(services);

  final OpeningKind kind;

  /// The plan's services: read, never kept beyond the document.
  final PlanServices services;

  final WallBands _bands;
  final LiveTypeOf _live;

  /// The width of the next opening: the tool's settings now.
  double get _width =>
      services.settingsOf<OpeningSettings>(openingToolIdOf(kind)).width;
```

  - Lines 103-406 unchanged except: `settings.value.width` → `_width` at `:203`, `:333`, `:341`; `wallsInDocument(doc, host)` → `wallsInDocument(doc, host, _live)` at `:308`; `openingsInDocument(doc, host)` → `openingsInDocument(doc, host, _live)` at `:316`.
  - Lines 407-411 become:

```dart
  @override
  void dispose() {
    // The band cache is the kit's shared one: the plan disposes it with its
    // document (spec 3a C2).
    super.dispose();
  }
```

  - Copy lines 412-450 unchanged (`paintRubberBand`, `isUsableHost`).

- [ ] **Step 6: The three plan tools.** In `lib/src/opening/opening_plan.dart`: the header's last sentence becomes `// The three opening tools close the file (Task 15).`; add `import 'package:flutter/material.dart' show IconData, Icons;` and `import 'opening_tool.dart';`; append:

```dart
/// One opening tool (spec 3a C3.3): today's palette entry
/// (`planner_shell.dart:560-580`) and its settings (today's one
/// `OpeningSettings` per kind, `:469`), the width field writing through
/// [openingWidthOf]. No keys: the letter is the plan's palette shortcut.
PlanTool _openingPlanTool(OpeningKind kind, String letter, IconData icon) =>
    PlanTool(
      id: openingToolIdOf(kind),
      icon: icon,
      letter: letter,
      needs: const {
        Capability.structure,
        Capability.components,
        Capability.geometry,
      },
      settings: PlanToolSettings<OpeningSettings>(
          initial: OpeningSettings.defaultFor(kind),
          specs: [
            LengthProperty<OpeningSettings>(
                id: 'width',
                read: (s) => s.width,
                write: (s, w) => s.copyWith(width: openingWidthOf(kind, w))),
          ]),
      create: (services) => OpeningTool(kind, services),
    );

final PlanTool doorPlanTool = _openingPlanTool(
    OpeningKind.door, 'D', Icons.door_front_door_outlined);
final PlanTool windowPlanTool =
    _openingPlanTool(OpeningKind.window, 'N', Icons.window_outlined);
final PlanTool gapPlanTool =
    _openingPlanTool(OpeningKind.gap, 'G', Icons.space_bar);
```

  In `lib/src/kit.dart`, `tools:` gains `doorPlanTool, windowPlanTool, gapPlanTool` right after `wallPlanTool` (today's palette order W, D, N, G, D-26).

- [ ] **Step 7: Run them: they pass.** `cd packages/jet_cad_2d_kit_architecture && dart format . && flutter test`: `All tests passed!` (OT4 (cost) prints). `cd packages/jet_cad_2d_integration && dart format . && flutter test --enable-vmservice`: `All tests passed!`.

- [ ] **Step 8: The gates.**
  - `cd packages/jet_cad_2d_kit_architecture && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .`
  - `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice && flutter analyze && dart format --output=none --set-exit-if-changed .`
  - `dart run tool/ci/check_kit_deps.dart`: exit 0.
  - `git status --short`: only this task's files.

- [ ] **Step 9: Commit.**

```bash
git add packages/jet_cad_2d_kit_architecture/lib/src/opening/opening_tool.dart packages/jet_cad_2d_kit_architecture/lib/src/opening/opening_plan.dart packages/jet_cad_2d_kit_architecture/lib/src/kit.dart packages/jet_cad_2d_kit_architecture/test/opening/opening_tool_test.dart packages/jet_cad_2d_integration/test/support/opening_support.dart packages/jet_cad_2d_integration/test/opening/opening_tool_test.dart packages/jet_cad_2d_integration/test/opening/opening_panel_test.dart packages/jet_cad_2d_integration/test/opening/opening_kink_test.dart
git commit -m "$(cat <<'EOF'
feat(architecture): the Door, Window and Gap tools (spec 3a C3.3)

The three opening tools join the kit after the Wall tool, letters D, N
and G, each with its width setting, strict by kind. The tool reads its
width from the plan's settings at each event, shares the kit's band
cache and sees only live walls (C1.5). The tool tests run in the kit
over FakePlanServices; the canvas, panel and kinked-joint cases run in
PlanEditor. The opening's 85 cases are all ported.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 10: Mutation check** (committed files only; after each: run the named test, see it red, then `git checkout -- <file>` and `git diff --quiet -- <file>` must exit 0). Kit: `cd packages/jet_cad_2d_kit_architecture && flutter test test/opening/opening_tool_test.dart`; integration: `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice <file>`. Quote each red line.
  - M-OL-1 `lib/src/opening/opening_plan.dart`: the door's letter `'D'` → `'X'` → OL-tools red.
  - M-OL-2 `lib/src/opening/opening_tool.dart`: in `OpeningSettings.defaultFor`, `kind == OpeningKind.window ? 1200 : 900` → `900` → OL-tools red; OS3 red (`OpeningSettings(1200.0)` expected for N).
  - M-OL-3 `opening_plan.dart`: in `_openingPlanTool`'s width spec, `openingWidthOf(kind, w)` → `openingWidthOf(OpeningKind.door, w)` → OL-tools red (a gap's 0.000004 kept); OS3 red.
  - M-OL-4 `opening_tool.dart`: read the width once: add the field `late final double _first = services.settingsOf<OpeningSettings>(openingToolIdOf(kind)).width;` and make `_width => _first` → OL-settings red (the second door is 900).
  - M-OL-5 `opening_tool.dart`: in `_frameFor`, `wallsInDocument(doc, host, _live)` → `wallsInDocument(doc, host, (h) => h == host ? _live(h) : ArchitectureTypes.wall)` → OL-frozen red (the frozen X is an obstacle: the door is not stored at 1,875).
  - M-OL-6 (a pair, both edits applied before the run, both reverted after: the first click is refused twice over, by the band cache and by the frame, so neither edit alone turns it red) `lib/src/wall/wall_bands.dart` (Task 11): in the cache's rebuild, drop the live filter so every `WallParams` holder gets a band; and `lib/src/opening/opening_tool.dart`: in `_frameFor`, `wallsInDocument(doc, host, _live)` → `wallsInDocument(doc, host, (h) => ArchitectureTypes.wall)` → OL-frozen red at `'a frozen wall hosts nothing'` (a door placed on the frozen X). Revert with `git checkout -- packages/jet_cad_2d_kit_architecture/lib/src/wall/wall_bands.dart packages/jet_cad_2d_kit_architecture/lib/src/opening/opening_tool.dart`, then `git diff --quiet` on both.
  - M-OL-7 `lib/src/kit.dart`: remove `doorPlanTool` from `tools:` → OL-tools red; OT1 (shell) red (`test/opening/opening_tool_test.dart` of the integration package: no `tool-architecture.door`).
  - M-OL-8 `opening_tool.dart`: in `_place`, `swing: side >= 0 ? SwingSide.left : SwingSide.right` → `swing: side >= 0 ? SwingSide.right : SwingSide.left` → OT2 red.

  (`isUsableHost`'s layer rule is pinned by `opening_host_layer_test`, Task 26, D-29; its mutation is that task's.)

#### Assumed from earlier tasks

- Task 6: `FakePlanServices` keeps the `settings` map it is given (no copy) and answers `settingsOf(toolId)` with `settings[toolId]` at each call, so a test changes a tool's settings by writing to that map (`setWidth`); `frozen` drives `liveTypeIdOf`; its `shared` caches one `WallBands` per document and disposes it in `dispose()`.
- Tasks 10, 12: `architectureKit.tools` is `[boxPlanTool, wallPlanTool]` before this task (today's palette order box, wall, door, window, gap, room, separator, dimension, `planner_shell.dart:547-601`; Task 12's "The palette"); this task's three go right after `wallPlanTool`. Task 9: the words of the three tools and their `width` settings exist in all three locales.
- Task 11: `wallBandsOf(PlanServices s)` returns the kit's shared `WallBands`, whose rebuild keeps only walls `s.liveTypeIdOf` names `ArchitectureTypes.wall`; `hostAt`, `generation` and `invalidate` are today's.
- Task 14: the integration support and R14-8, R14-9, R14-10; `openingWidthOf`.
- The plan library (2a P3): while a tool with settings is active, the property panel shows that tool's settings section (`settings-<tool id>`, fields `setting-<spec id>`) instead of the selected object's section, and writes a settings field as it is typed (today's tool mode, `selection_panel.dart:1060-1066`). If it shows both sections, OS3's `expect(position, findsNothing, …)` fails: that is a finding (stop and report it), not a test to change.

#### Interface problem

None beyond Task 13's and Task 14's.

---

