### Task 9: The app — the shell owns the caches, F3, `osnap-text`, the test seam, end to end

**Files:**
- Modify: `lib/main.dart`, `lib/planner_view.dart`
- Test: `test/planner_grips_test.dart` (A1–A4)

**Interfaces:**
- Consumes: `OutlineCache`, `GripCache`, `SnapSettings` and `ToolContext`'s
  new fields (Tasks 4–5); everything through the barrel.
- Produces:
  - `PlannerShell({Key? key, DraftDocument? document, ViewportTransform? initialCamera})`
  - `PlannerView({…, required OutlineCache outlines, required GripCache grips})`
  - the top bar's `Text(key: Key('osnap-text'))`, reading `OSNAP` or
    `osnap off`;
  - F3 bound with `includeRepeats: false`.

- [ ] **Step 1: Write the failing test.**

```dart
// test/planner_grips_test.dart
import 'dart:typed_data';

import 'package:floor_planner/main.dart';
import 'package:floor_planner/planner_view.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind, kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

Handle addLine(DraftDocument doc, List<double> coords) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: doc.rootHandle,
      kind: EntityKind.line,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByLayerColor(),
      lineweight: kByLayer,
      transparency: kByLayer,
      flags: 0,
    ),
    payload: GeometryPayload(
        coords: Float64List.fromList(coords), scalars: Float64List(0)),
  ));
  return handle;
}

/// Two lines off the origin on a page whose grid is a fixed 100 mm anchored
/// at (7000, 3000). `other`'s start is off the lattice, so an object snap
/// and a grid snap land in different places.
({DraftDocument doc, Handle line, Handle other}) shellScene(
    FlutterTextMeasurer measurer) {
  final doc = DraftDocument.empty(measurer: measurer);
  PageComponent.register(doc.components);
  doc.commands.execute(SetComponentCommand<PageComponent>(doc.rootHandle,
      PageComponent(originX: 7000, originY: 3000, gridStepMm: 100)));
  final line = addLine(doc, [7010, 3020, 7130, 3060]);
  final other = addLine(doc, [7137.3, 3161.7, 7300.9, 3190.1]);
  doc.commands.clearHistory();
  return (doc: doc, line: line, other: other);
}

GeometryPayload payloadOf(DraftDocument doc, Handle h) =>
    doc.geometry.read(doc.entities.geomIndexAt(doc.entities.slotOf(h)!));

/// Pumps the shell through its test seam on a 1440 × 900 surface, then
/// sets a zoomed, panned, rotated camera.
Future<PlannerView> pumpShell(WidgetTester tester, DraftDocument doc) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: PlannerShell(document: doc)));
  await tester.pump();
  // Set after the first pump: PlannerView fits the camera once, at the end
  // of its first frame (Ruling 04-16), and would overwrite one set before.
  final view = tester.widget<PlannerView>(find.byType(PlannerView));
  final size = tester.getSize(find.byType(InteractionLayer));
  final linear =
      Transform2.rotation(0.35).multiply(Transform2.scale(2.0, -2.0));
  final mid = linear.transformPoint(Vector2(7150, 3110));
  view.camera.value = ViewportTransform(
      worldToScreenMatrix:
          Transform2.translation(size.width / 2 - mid.x, size.height / 2 - mid.y)
              .multiply(linear));
  await tester.pump();
  return view;
}

Offset globalOf(WidgetTester tester, PlannerView view, double x, double y) {
  final s = view.camera.value.worldToScreen(Vector2(x, y));
  return tester.getTopLeft(find.byType(InteractionLayer)) + Offset(s.x, s.y);
}

Future<void> mouseDrag(WidgetTester tester, Offset from, Offset to) async {
  final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
  await gesture.down(from);
  await gesture.moveTo(from + const Offset(12, 0));
  await gesture.moveTo(to);
  await gesture.up();
  await gesture.removePointer();
  await tester.pump();
}

Future<void> cmdZ(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.keyZ);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.keyZ);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pump();
}

String osnapText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('osnap-text'))).data!;

/// Selects the line with a click on its body, a third of the way along.
Future<void> selectLine(WidgetTester tester, PlannerView view) async {
  await tester.tapAt(globalOf(tester, view, 7050, 3020 + 40 / 3));
  await tester.pump();
}

void main() {
  testWidgets('a stretch through the shell lands exactly on an endpoint, and '
      'cmd+Z restores it with == (A1, M-03au)', (tester) async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final s = shellScene(measurer);
    final view = await pumpShell(tester, s.doc);
    final before = payloadOf(s.doc, s.line);
    await selectLine(tester, view);
    expect(view.selection.keys, [SelectionKey.root(s.line)]);

    // Grab vertex 1; drop it 3 px from the other line's start. Object snap
    // is on by default, so it lands there exactly (spec D8).
    await mouseDrag(tester, globalOf(tester, view, 7130, 3060),
        globalOf(tester, view, 7137.3, 3161.7) + const Offset(3, -2));
    final after = payloadOf(s.doc, s.line);
    expect([after.coords[2], after.coords[3]], [7137.3, 3161.7]);
    expect([after.coords[0], after.coords[1]], [7010, 3020]);
    expect(s.doc.commands.undoDepth, 1);

    await cmdZ(tester);
    expect(payloadOf(s.doc, s.line), before,
        reason: 'undo restores the stored payload with == (spec D11)');
    expect(s.doc.commands.undoDepth, 0);
  });

  testWidgets('F3 turns object snap off: osnap-text says so and the drag '
      'lands on the grid (A2, M-03x)', (tester) async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final s = shellScene(measurer);
    final view = await pumpShell(tester, s.doc);
    expect(osnapText(tester), 'OSNAP');
    await tester.sendKeyEvent(LogicalKeyboardKey.f3);
    await tester.pump();
    expect(osnapText(tester), 'osnap off');

    await selectLine(tester, view);
    await mouseDrag(tester, globalOf(tester, view, 7130, 3060),
        globalOf(tester, view, 7137.3, 3161.7) + const Offset(3, -2));
    final after = payloadOf(s.doc, s.line);
    expect([after.coords[2], after.coords[3]], [7100, 3200],
        reason: 'the nearest lattice point of the fixed 100 mm grid');
  });

  testWidgets('F3 held down toggles once (A3, M-03af)', (tester) async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final s = shellScene(measurer);
    await pumpShell(tester, s.doc);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.f3);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.f3);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.f3);
    await tester.pump();
    expect(osnapText(tester), 'osnap off',
        reason: 'includeRepeats: false — a repeat would have toggled it back');
  });

  testWidgets("cmd+Z pressed mid-drag is the drag's, not the shell's (A4, "
      'M-03aa)', (tester) async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final s = shellScene(measurer);
    final view = await pumpShell(tester, s.doc);
    // One finished drag first, so a stray undo would have something to take.
    await selectLine(tester, view);
    await mouseDrag(tester, globalOf(tester, view, 7130, 3060),
        globalOf(tester, view, 7137.3, 3161.7) + const Offset(3, -2));
    expect(s.doc.commands.undoDepth, 1);
    final landed = payloadOf(s.doc, s.line);

    final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
    final from = globalOf(tester, view, 7137.3, 3161.7);
    await gesture.down(from);
    await gesture.moveTo(from + const Offset(20, 10));
    await gesture.moveTo(from + const Offset(35, 18));
    expect(view.tools.active.phase, ToolPhase.dragging);

    await cmdZ(tester);
    expect(s.doc.commands.undoDepth, 1,
        reason: 'the Z never reached the shell (spec D5)');
    expect(payloadOf(s.doc, s.line), landed);
    expect(view.tools.active.phase, ToolPhase.dragging,
        reason: 'the drag is still live');

    await gesture.up();
    await gesture.removePointer();
    await tester.pump();
    expect(s.doc.commands.undoDepth, 2);
  });
}
```

- [ ] **Step 2: Run it to fail.** `cd apps/floor_planner && CI=true flutter
  test test/planner_grips_test.dart` → compile error: `PlannerShell` has no
  named parameter `document`.

- [ ] **Step 3: Implement.** In `lib/main.dart`:

```dart
/// Owns the document, the index, the camera and — since 03 — the outline
/// cache, the grip cache and the snap settings for the window's lifetime.
/// It lays out the chrome slots.
///
/// [document] and [initialCamera] are a test seam (spec 03, Architecture;
/// Ruling 03-18).
/// - [document] replaces the startup plan, and must carry a
///   `FlutterTextMeasurer`.
/// - [initialCamera] replaces the nominal fit.
/// - `PlannerView` still fits once after its first frame, so a test sets a
///   camera of its own after the first pump.
class PlannerShell extends StatefulWidget {
  const PlannerShell({super.key, this.document, this.initialCamera});

  final DraftDocument? document;
  final ViewportTransform? initialCamera;

  @override
  State<PlannerShell> createState() => _PlannerShellState();
}
```

In `_PlannerShellState`:
- `late final DraftDocument _document = widget.document ??
  startupPlan(_measurer);`
- `_camera`'s first argument becomes `widget.initialCamera ??
  _nominalFit()`, with this method:

```dart
  /// Fitted to the nominal window; PlannerView re-fits once at the real
  /// size. A document without a page fits its extents.
  ViewportTransform _nominalFit() {
    final page = _page.value;
    return page != null
        ? fitToPage(page, const Size(1440, 900))
        : ViewportTransform.fit(_document.extents, const Size(1440, 900));
  }
```

- after `_policy`, add `final SnapSettings _snap = SnapSettings();`
- after `_selection`, add:

```dart
  // Spec 03 D6, moved from PlannerView. The order is load-bearing.
  // - The outline cache is built after the selection controller, so the
  //   controller prunes a dead key before the cache walks it.
  // - The grip cache is built after the outline cache, so on a selection
  //   change its listener runs after the outlines have been rebuilt.
  late final OutlineCache _outlines = OutlineCache(_document, _selection);
  late final GripCache _grips = GripCache(_document, _selection, _outlines);
```

- `_context` becomes `ToolContext(document: _document, index: _index,
  camera: _camera, selection: _selection, page: _page, snap: _snap, grips:
  _grips)`;
- `dispose` becomes:

```dart
  @override
  void dispose() {
    _tools.dispose();
    _grips.dispose();
    _outlines.dispose();
    _selection.dispose();
    _snap.dispose();
    _page.dispose();
    _camera.dispose();
    _index.dispose();
    _measurer.clear();
    super.dispose();
  }
```

- the `CallbackShortcuts` bindings gain F3:

```dart
          const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _undo,
          const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undo,
          // Spec 03 D10: one toggle per press, never per key repeat.
          const SingleActivator(LogicalKeyboardKey.f3, includeRepeats: false):
              _snap.toggleObjectSnap,
```

- in the top bar's `Row`, between `const Spacer(),` and the zoom-text
  `ListenableBuilder`:

```dart
                    ListenableBuilder(
                      listenable: _snap,
                      builder: (_, __) => Text(
                          _snap.objectSnap ? 'OSNAP' : 'osnap off',
                          key: const Key('osnap-text')),
                    ),
                    const SizedBox(width: 16),
```

- `PlannerView(...)` gains `outlines: _outlines, grips: _grips,`.

In `lib/planner_view.dart`:
- add the two fields and constructor parameters:

```dart
    required this.outlines,
    required this.grips,
  ...
  /// Owned by the shell since 03 (spec D6).
  final OutlineCache outlines;

  /// The selection's grips. A member of the overlay's repaint merge.
  final GripCache grips;
```

- delete the state's `_outlines` field and its `dispose` override. The
  state then owns nothing to dispose.
- `_repaint` becomes:

```dart
  // The two caches are in the merge because they are the members that hear
  // a `DocChange`: an edit under a selected instance rebuilds the outline
  // and the grips, and nothing else in here would ask for the frame that
  // draws them.
  late final Listenable _repaint = Listenable.merge([
    widget.selection,
    widget.tools,
    widget.camera,
    widget.outlines,
    widget.grips,
  ]);
```

- the overlay's `outlines: _outlines` becomes `outlines: widget.outlines`.

- [ ] **Step 4: Run it to pass.** `CI=true flutter test
  test/planner_grips_test.dart test/planner_shell_test.dart` → all tests
  pass. The existing shell tests pump `const FloorPlannerApp()`, so they
  are unchanged. Then run the `floor_planner` gate line, including both
  builds.
- [ ] **Step 5: Commit.**

```bash
git add apps/floor_planner/lib/main.dart apps/floor_planner/lib/planner_view.dart apps/floor_planner/test/planner_grips_test.dart
git commit -m "$(cat <<'EOF'
feat(app): grips in the shell -- caches, F3, osnap-text, test seam

Spec 03 D6, D10: the shell owns OutlineCache, GripCache and SnapSettings in
listener order and hands them to PlannerView and ToolContext; F3 toggles
object snap once per press; the top bar reads OSNAP / osnap off; PlannerShell
takes an optional document and camera (Ruling 03-18). End-to-end: stretch,
cmd+Z, F3, and cmd+Z mid-drag.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---
