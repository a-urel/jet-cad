### Task 5: `Tool` and `ToolContext` additions, `SnapSettings`, the cursor rebuild

**Files:**
- Modify: `lib/src/tool.dart`
- Create: `lib/src/snap_settings.dart`
- Modify: `lib/src/interaction_layer.dart` (the `build` method)
- Modify: `lib/jet_cad_2d_flutter.dart`: add `export
  'src/snap_settings.dart';` after `src/selection_style.dart`.
- Test: `test/interaction_cursor_test.dart` (I1)

**Interfaces:**
- Consumes: `GripCache` (Task 4); `PageNotifier`.
- Produces:
  - `ToolContext({required document, required index, required camera, required selection, PageNotifier? page, SnapSettings? snap, GripCache? grips})`
    with fields `page`, `snap` and `grips`. Every 02 call site still
    compiles.
  - `Tool.cursor` → `MouseCursor`, default `MouseCursor.defer`.
  - `Tool.selectionPreviewTransform` → `Transform2?`, default null.
  - `void Tool.paintWorldOverlay(Canvas canvas, Vector2 origin, double scale)`,
    a default no-op (Ruling 03-3).
  - `class SnapSettings extends ChangeNotifier { SnapSettings({bool objectSnap = true}); bool get objectSnap; void toggleObjectSnap(); }`

- [ ] **Step 1: Write the failing test.**

```dart
// test/interaction_cursor_test.dart
import 'dart:ui' show Canvas, Size;

import 'package:flutter/services.dart'
    show KeyEvent, MouseCursor, SystemMouseCursors;
import 'package:flutter/widgets.dart' show KeyEventResult, MouseRegion, Offset;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/flutter_text_measurer.dart';
import 'package:jet_cad_2d_flutter/src/interaction_layer.dart';
import 'package:jet_cad_2d_flutter/src/tool.dart';
import 'package:jet_cad_2d_flutter/src/viewport_transform.dart';

import 'support/selection_fixture.dart';

/// A tool that has only a cursor, and says when it changes.
class _CursorTool extends Tool {
  MouseCursor _cursor = MouseCursor.defer;

  @override
  MouseCursor get cursor => _cursor;

  void show(MouseCursor next) {
    _cursor = next;
    notifyListeners();
  }

  @override
  String get name => 'Cursor';
  @override
  ToolPhase get phase => ToolPhase.idle;
  @override
  void onPointerDown(ToolPointerEvent e, ToolContext ctx) {}
  @override
  void onPointerMove(ToolPointerEvent e, ToolContext ctx) {}
  @override
  void onPointerUp(ToolPointerEvent e, ToolContext ctx) {}
  @override
  void onPointerExit(ToolContext ctx) {}
  @override
  KeyEventResult onKey(KeyEvent event, ToolContext ctx) =>
      KeyEventResult.ignored;
  @override
  void cancel(ToolContext ctx) {}
  @override
  void paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport) {}
}

void main() {
  testWidgets("the MouseRegion follows the active tool's cursor (spec D5, "
      'M-03ab)', (tester) async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final doc = DraftDocument.empty(measurer: measurer);
    final rig = await pumpInteraction(tester,
        document: doc, camera: cameraAt(2.0, const Offset(-1850, 1120)));
    MouseCursor current() => tester
        .widget<MouseRegion>(find
            .descendant(
                of: find.byType(InteractionLayer),
                matching: find.byType(MouseRegion))
            .first)
        .cursor;

    expect(current(), MouseCursor.defer, reason: 'SelectTool, idle');
    final probe = _CursorTool();
    addTearDown(probe.dispose);
    rig.tools.activate(probe);
    probe.show(SystemMouseCursors.move);
    await tester.pump();
    expect(current(), SystemMouseCursors.move,
        reason: 'a notification rebuilds the MouseRegion');
    probe.show(SystemMouseCursors.grabbing);
    await tester.pump();
    expect(current(), SystemMouseCursors.grabbing);
    rig.tools.activate(rig.tool);
    await tester.pump();
    expect(current(), MouseCursor.defer);
  });
}
```

- [ ] **Step 2: Run it to fail.** `CI=true flutter test
  test/interaction_cursor_test.dart` → compile error: `cursor` is not a
  member of `Tool`, so there is nothing to override.

- [ ] **Step 3: Implement.** Create `lib/src/snap_settings.dart`:

```dart
import 'package:flutter/foundation.dart';

/// F3's object-snap toggle (spec D10). The shell owns it; a drag reads it
/// per event through `ToolContext.snap`.
class SnapSettings extends ChangeNotifier {
  SnapSettings({bool objectSnap = true}) : _objectSnap = objectSnap;

  bool _objectSnap;
  bool get objectSnap => _objectSnap;

  void toggleObjectSnap() {
    _objectSnap = !_objectSnap;
    notifyListeners();
  }
}
```

In `lib/src/tool.dart`:
- change the services import to `import 'package:flutter/services.dart'
  show KeyEvent, MouseCursor;`;
- add `import 'grip_cache.dart';`, `import 'page_notifier.dart';` and
  `import 'snap_settings.dart';`;
- replace `ToolContext` with:

```dart
/// Everything a [Tool] needs to act: the document to mutate, the index to
/// query, the camera to read, the selection to update — and, since 03, the
/// page, the snap settings and the grips, each optional so every 02 call
/// site still compiles (spec D10).
final class ToolContext {
  const ToolContext({
    required this.document,
    required this.index,
    required this.camera,
    required this.selection,
    this.page,
    this.snap,
    this.grips,
  });

  final DraftDocument document;
  final SpatialIndex index;
  final CameraController camera;
  final SelectionController selection;

  /// The page, for the drag's grid snap; null: no grid snap.
  final PageNotifier? page;

  /// F3's toggle; null: object snap is on.
  final SnapSettings? snap;

  /// The selection's grips and box; null: no grip or rotation grip is drawn
  /// or hit.
  final GripCache? grips;

  void execute(DraftCommand command) => document.commands.execute(command);
}
```

Add three members to `abstract class Tool`, after `paintOverlay`:

```dart
  /// The pointer's cursor over the layer (spec 03 D5). `InteractionLayer`
  /// rebuilds its `MouseRegion` when the tool notifies.
  MouseCursor get cursor => MouseCursor.defer;

  /// The world transform a live move or rotate would apply, for the
  /// overlay's preview (spec 03 D7); null otherwise.
  Transform2? get selectionPreviewTransform => null;

  /// Paints under the overlay's rebased world matrix, `worldToScreen ∘
  /// translate(origin)`, so coordinates handed to [canvas] must be `world −
  /// origin` (Ruling 03-3). [scale] is the camera's, for stroke widths.
  void paintWorldOverlay(Canvas canvas, Vector2 origin, double scale) {}
```

In `lib/src/interaction_layer.dart`, replace `build` with:

```dart
  @override
  Widget build(BuildContext context) => Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: (_, event) => _tool.onKey(event, _ctx),
        // Spec 03 D5: a cursor is a widget parameter, so it needs a
        // rebuild. Only the MouseRegion is rebuilt, and only when the tool
        // (or a swap) notifies; the Listener subtree is the cached child.
        child: ListenableBuilder(
          listenable: widget.tools,
          builder: (context, child) => MouseRegion(
            cursor: _tool.cursor,
            onExit: _onExit,
            child: child,
          ),
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _onDown,
            onPointerMove: _onMove,
            onPointerUp: _onUp,
            onPointerCancel: _onCancel,
            onPointerHover: _onHover,
            child: widget.child,
          ),
        ),
      );
```

Add the export to `lib/jet_cad_2d_flutter.dart`, after
`src/selection_style.dart`:

```dart
export 'src/snap_settings.dart';
```

- [ ] **Step 4: Run it to pass.** `CI=true flutter test
  test/interaction_cursor_test.dart test/interaction_layer_test.dart
  test/tool_controller_test.dart` → all tests pass. `_CountingTool` still
  compiles; it overrides nothing new. Then run the `jet_cad_2d_flutter`
  gate line.
- [ ] **Step 5: Commit.**

```bash
git add packages/jet_cad_2d_flutter/lib/src/tool.dart packages/jet_cad_2d_flutter/lib/src/snap_settings.dart packages/jet_cad_2d_flutter/lib/src/interaction_layer.dart packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart packages/jet_cad_2d_flutter/test/interaction_cursor_test.dart
git commit -m "$(cat <<'EOF'
feat(render): Tool cursor and preview hooks, ToolContext page/snap/grips

Spec 03 D5, D7, D10: Tool.cursor, selectionPreviewTransform and
paintWorldOverlay with defaults (Ruling 03-3); three optional ToolContext
fields; SnapSettings; and a ListenableBuilder that rebuilds only the
InteractionLayer's MouseRegion when the tool notifies.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

