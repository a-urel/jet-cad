### Task 9: `InteractionLayer`, and the exports

**Files:**
- Create: `lib/src/interaction_layer.dart`
- Modify: `lib/src/select_tool.dart` (move `kPickRadiusPixels` out)
- Modify: `lib/jet_cad_2d_flutter.dart` (exports)
- Test: `test/interaction_layer_test.dart`; `pumpInteraction` added to `test/support/selection_fixture.dart`

**Interfaces:**

```dart
const double kPickRadiusPixels = 6.0;

class InteractionLayer extends StatefulWidget {
  const InteractionLayer({super.key, required this.tools, required this.child});
  final ToolController tools;   // its context carries camera, selection, index, document
  final Widget child;
}
```

- [ ] **Step 1: The fixture** — `pumpInteraction(tester, {camera, selection, tools, doc, index})`
  pumps `Center(SizedBox(400×300, InteractionLayer(tools, child: Stack([RepaintBoundary(DraftCanvas), Positioned.fill(... SelectionOverlay ...)]))))`
  and asserts `tester.getSize(find.byType(InteractionLayer)) == Size(400, 300)`.

- [ ] **Step 2: Failing tests** (`TestGesture` via `tester.startGesture` /
  `tester.createGesture(kind: PointerDeviceKind.mouse)`; hovers via
  `gesture.moveTo` on a mouse gesture with no button down — use
  `tester.createGesture(kind: PointerDeviceKind.mouse, pointer: 7)` then
  `addPointer` / `moveTo`; keys via `tester.sendKeyDownEvent` /
  `sendKeyUpEvent`):

1. `'a click selects; the layer took focus'`: `FocusManager.instance.primaryFocus` is the layer's node after the click.
2. **M-02g** — `'drag direction selects the mode; a vertical drag is a window'`:
   the M-02a fixture in world; left→right, right→left, and a drag with
   `end.dx == start.dx`.
3. **M-02i** — `'exiting the layer clears hover'`: hover over a line →
   `selection.hover != null`; `moveTo` outside the layer → null.
4. **M-02l** — `'the pick radius is converted by the camera scale'`: camera
   at scale 0.25; click 5 px from a line on screen → selected.
5. **M-02x** — `'one Delete press is one remove'`: `sendKeyDownEvent(delete)`
   then `sendKeyUpEvent(delete)`; the document lost one entity; `canUndo`;
   `undo()` restores it; `canUndo` is then false.
6. **M-02y** — `'a pointer cancel ends the band'`: start a band with a
   `TestGesture`, then `gesture.cancel()`; `tools.active.phase == idle`,
   selection untouched.
7. `'a middle-button drag never reaches the tool'`: `createGesture(buttons:
   kMiddleMouseButton)` down/move/up → phase stays idle, selection empty.
8. `'primary released while middle is still held is an up'`: down primary,
   move, then a move whose `buttons` is middle only (build the
   `PointerMoveEvent` by hand and dispatch through
   `GestureBinding.instance.handlePointerEvent`) → phase idle; a later
   `PointerUpEvent` with `buttons == 0` is ignored without throwing.

- [ ] **Step 3: Implement `interaction_layer.dart`**

```dart
class _InteractionLayerState extends State<InteractionLayer> {
  final FocusNode _focus = FocusNode(debugLabel: 'InteractionLayer');
  int _activePointer = -1;
  int _lastButtons = 0;

  ToolContext get _ctx => widget.tools.context;
  Tool get _tool => widget.tools.active;

  ToolPointerEvent _wrap(PointerEvent e) {
    final cam = _ctx.camera.value;
    final local = e.localPosition;
    final k = HardwareKeyboard.instance;
    return ToolPointerEvent(
      screen: local,
      world: cam.screenToWorld(Vector2(local.dx, local.dy)),
      pointer: e.pointer, buttons: e.buttons,
      shift: k.isShiftPressed, control: k.isControlPressed,
      meta: k.isMetaPressed, alt: k.isAltPressed,
      pickRadiusWorld: kPickRadiusPixels / cam.scale,
    );
  }

  bool _cameraOwned(int buttons) => buttons & kMiddleMouseButton != 0;

  void _onDown(PointerDownEvent e) {
    if (_cameraOwned(e.buttons) || _activePointer != -1) return;
    if (e.buttons & kPrimaryButton == 0) return;
    _focus.requestFocus();
    _activePointer = e.pointer;
    _lastButtons = e.buttons;
    _tool.onPointerDown(_wrap(e), _ctx);
  }

  void _onMove(PointerMoveEvent e) {
    if (_cameraOwned(e.buttons)) return;
    final hadPrimary = _lastButtons & kPrimaryButton != 0;
    final hasPrimary = e.buttons & kPrimaryButton != 0;
    if (e.pointer == _activePointer) {
      _lastButtons = e.buttons;
      if (hadPrimary && !hasPrimary) {
        _activePointer = -1;
        _tool.onPointerUp(_wrap(e), _ctx);
      } else {
        _tool.onPointerMove(_wrap(e), _ctx);
      }
      return;
    }
    if (_activePointer == -1 && hasPrimary) {
      _activePointer = e.pointer;
      _lastButtons = e.buttons;
      _tool.onPointerDown(_wrap(e), _ctx);
    }
  }

  void _onUp(PointerUpEvent e) {
    if (e.pointer != _activePointer) return;
    _activePointer = -1;
    _lastButtons = 0;
    _tool.onPointerUp(_wrap(e), _ctx);
  }

  void _onCancel(PointerCancelEvent e) {
    if (e.pointer != _activePointer) return;
    _activePointer = -1;
    _lastButtons = 0;
    _tool.cancel(_ctx);
  }

  void _onHover(PointerHoverEvent e) {
    if (_activePointer != -1) return;
    _tool.onPointerMove(_wrap(e), _ctx);
  }

  @override
  void dispose() {
    _ctx.selection.setHover(null);
    _tool.cancel(_ctx);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: (_, event) => _tool.onKey(event, _ctx),
        child: MouseRegion(
          onExit: (_) => _tool.onPointerExit(_ctx),
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
}
```

Exports in `jet_cad_2d_flutter.dart`: `selection.dart`, `tool.dart`,
`select_tool.dart`, `selection_style.dart`, `outline_cache.dart`,
`selection_overlay.dart`, `interaction_layer.dart`.

- [ ] **Step 4: Run, the full package gate line, commit**

```sh
git add lib/src/interaction_layer.dart lib/src/select_tool.dart lib/jet_cad_2d_flutter.dart test/interaction_layer_test.dart test/support/selection_fixture.dart
git commit -m "feat(interaction): InteractionLayer routes pointer transitions and keys to the active tool"
```

---

