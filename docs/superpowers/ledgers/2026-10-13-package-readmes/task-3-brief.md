### Task 3: The planner's scenes P1–P6 (D5, A1)

**Files:**
- Create: `tool/screenshots/test/planner_scenes_test.dart`
- Create: `packages/jet_cad_floor_plan/doc/screenshots/{design_light,design_dark,service_status,service_dark_focus,service_band,service_colors}.png` (generated)

**Interfaces:**
- Consumes: Task 2's harness; Task 1's `SymbolLibraryReady` on the barrel.

- [ ] **Step 1: The scenes**, one `testWidgets` each, sharing:

```dart
import 'dart:io';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_floor_plan/jet_cad_floor_plan.dart';
import 'package:jet_cad_restaurant_symbols/jet_cad_restaurant_symbols.dart';

import 'support/shots.dart';

const _package = 'jet_cad_floor_plan';

/// The restaurant demo's Salon (apps/restaurant_demo/assets/plans), read
/// from the repository: one source for the demo and the pictures.
final String _salon =
    File('../../apps/restaurant_demo/assets/plans/salon.json')
        .readAsStringSync();

/// The demo's statuses (DemoHomeState.kStatuses), by table number.
final Map<String, TableStatus> _statuses = {
  '1': TableStatus(color: const Color(0x99FFB300)),
  '2': TableStatus(color: const Color(0x9943A047)),
  '4': TableStatus(color: const Color(0x99E53935), caption: 'Bill'),
  '8': TableStatus(color: const Color(0x9943A047)),
  '10': TableStatus(color: const Color(0x99FFB300)),
};

/// A POS-like look from public fields (the demo's own theme is app code).
const FloorPlanTheme _pos = FloorPlanTheme(
  groupChipRadius: 6,
  selectionWidth: 3,
  focusVeilOpacity: 0.75,
  serviceBarHeight: 52,
);

Future<FloorPlanController> _controller(WidgetTester tester) async {
  final symbols = SymbolLibraryLoader(
      sources: const [furnitureSymbolSource, restaurantSymbolSource]);
  final controller = FloorPlanController(symbols: symbols, json: _salon);
  addTearDown(controller.dispose);
  return controller;
}

Widget _app(FloorPlanController controller,
        {Brightness brightness = Brightness.light,
        FloorPlanTheme? theme,
        FloorPlanFloorDrag floorDrag = FloorPlanFloorDrag.pan}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: brightness),
      supportedLocales: floorPlanSupportedLocales,
      localizationsDelegates: floorPlanLocalizationsDelegates,
      home: Scaffold(
          body: FloorPlanView(
              controller: controller, theme: theme, floorDrag: floorDrag)),
    );

Future<void> _ready(WidgetTester tester, SymbolLibraryLoader symbols) =>
    settle(tester, until: () => symbols.state is SymbolLibraryReady);
```

`setUpAll(() async { await loadManifestFonts(); await ensureFloorPlanFonts(); })`. If `FloorPlanController` does not expose its loader, keep the `SymbolLibraryLoader` in a local and pass it to `_ready`. Scenes:
- **P1** `design_light.png`: `_app(c)`, design mode (the default), `_ready`, `shoot`.
- **P2** `design_dark.png`: as P1 with `brightness: Brightness.dark`.
- **P3** `service_status.png`: `c.setMode(FloorPlanMode.selection)`, `c.setTableStatus(_statuses)`, `c.setTableGroups({'party': TableGroup(members: {'6', '7'}, label: 'Party of 8')})`.
- **P4** `service_dark_focus.png`: dark, `theme: _pos`, selection mode, `_statuses`, `c.setTableFocus({'8', '9', '10', '11'})`.
- **P5** `service_band.png`: light, selection mode, `floorDrag: FloorPlanFloorDrag.band`; a mouse gesture from a floor point right of tables 3–5 to a point left of them (right to left: a crossing band): `final g = await tester.startGesture(from, kind: PointerDeviceKind.mouse); await g.moveTo(to); await tester.pump();` then `shoot`, then `await g.up()`. Take `from`/`to` from `c.worldToGlobal` of world points read off the plan, or from fractions of `c.canvasRect.value`, so the band crosses three tables and starts on the floor.
- **P6** `service_colors.png`: light, selection mode, `c.setTablesColor({'1': FloorPlanColor.blue, '2': FloorPlanColor.blue, '3': FloorPlanColor.teal, '6': FloorPlanColor.purple, '7': FloorPlanColor.purple, '9': FloorPlanColor.orange})`.

Table numbers 1–11 are the Salon's (`kDemoZones` in `apps/restaurant_demo/lib/main.dart`); if a number is not on the plan, `setTableStatus` ignores it — check with `c.tables`/`tableAt` and pick numbers that are.

- [ ] **Step 2: Run without writing.** `cd tool/screenshots && flutter test test/planner_scenes_test.dart`: six passed, `git status --short` shows nothing new.

- [ ] **Step 3: Generate and look.** `UPDATE_SCREENSHOTS=1 flutter test test/planner_scenes_test.dart`. Open each PNG (Read tool) and check: real text and icons (no grey boxes), the plan fitted and fully visible, statuses/captions/group chip/veil/band/colours as the scene names. Adjust scenes until each reads at a glance; never edit a PNG.

- [ ] **Step 4: Measure.** `ls -l packages/jet_cad_floor_plan/doc/screenshots/`. If any file exceeds 1 MB or the six exceed 4 MB, set `kRatio = 1.0`, regenerate, re-measure. Record the ratio and the six sizes for the results note.

- [ ] **Step 5: Commit** the test and the six PNGs: `git commit -m "feat(tool): the planner's six scenes and their screenshots"`.

---

