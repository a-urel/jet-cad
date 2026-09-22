### Task 5: `SelectTool` — hover, click, shift, band

**Files:**
- Create: `lib/src/select_tool.dart`
- Test: `test/select_tool_test.dart`

**Interfaces:**
- Consumes: Tasks 2–4; `SpatialIndex.pickInto`, `forEachLeafInBand`, `forEachInstanceInBand`; `document.leavesByOwner()`, `tree.childNodesOf`.
- Produces: `class SelectTool extends Tool`, `const double kBandSlopPixels = 4.0`, read-only `BandMode? get bandMode`, `Rect? get bandScreen` (for the overlay test), `Offset? get bandStart`.

Tests are driven with synthetic `ToolPointerEvent`s — no widgets. A helper
in the test file:

```dart
ToolPointerEvent ev(CameraController camera, Offset screen,
        {int buttons = kPrimaryButton, bool shift = false, int pointer = 1}) =>
    ToolPointerEvent(
      screen: screen,
      world: camera.value.screenToWorld(Vector2(screen.dx, screen.dy)),
      pointer: pointer, buttons: buttons, shift: shift, control: false,
      meta: false, alt: false,
      pickRadiusWorld: kPickRadiusPixels / camera.value.scale,
    );
```

(`kPickRadiusPixels` is defined in Task 9's file; until then declare
`const double kPickRadiusPixels = 6.0;` in `select_tool.dart` and move it in
Task 9.)

- [ ] **Step 1: Failing tests**

Camera: `cameraAt(scale: 2.0, translation: Offset(-1500, 900))` over a
document whose lines sit around world `(900..1100, 400..600)`; verify in a
first test that `screenOf(line midpoint)` lands inside a 800×600 surface.

1. `'hover sets the controller's hover and clears on a miss'`.
2. **M-02d** — `'the pick radius is six screen pixels'`: two parallel
   horizontal lines 30 screen px apart (world spacing `30 / scale`); down+up
   3 px from A → selected A; down+up 10 px from A → selection empty.
3. `'click replaces, shift-click toggles'` (**M-02h**): click A, click B →
   {B}; shift-click A → {A, B}; shift-click A → {B}.
4. `'click on empty space clears; shift-click on empty space does nothing'`.
5. **M-02f** — `'a 2 px move keeps the press a click'`: down on empty, move
   2 px → `phase == ToolPhase.pressed`; up → `phase == idle`, selection
   empty (the log records the second half as non-discriminating).
6. `'a 5 px move from empty space starts a band; from a hit it does not'`:
   → `dragging` vs `pressed`.
7. **M-02a at the tool level, both directions** — `'left-to-right encloses, right-to-left touches'`:
   the M-02a fixture in world; drag from left of `inside` to a point
   between `straddling`'s ends (band right edge through it) → {inside};
   the same corners dragged right-to-left → {inside, straddling}.
8. **M-02r** — `'a group is window-selected only when every leaf is enclosed'`:
   group with two leaves, band enclosing one; window → empty; crossing →
   {group}.
9. `'shift-band toggles'`.
10. `'Escape during a band drops it, selection untouched; cancel returns to idle'`
    — via `onKey(KeyDownEvent(...))` built with `KeyDownEvent(physicalKey:
    PhysicalKeyboardKey.escape, logicalKey: LogicalKeyboardKey.escape,
    timeStamp: Duration.zero)`.

- [ ] **Step 2: Implement `select_tool.dart`** (keys and Delete in Task 6;
  `onKey` returns `ignored` for now)

```dart
class SelectTool extends Tool {
  SelectTool();

  @override
  String get name => 'Select';
  ToolPhase _phase = ToolPhase.idle;
  @override
  ToolPhase get phase => _phase;

  final HitPath _hit = HitPath();
  Offset _start = Offset.zero;
  Vector2 _startWorld = Vector2.zero();
  SelectionKey? _downKey;
  bool _downHit = false;
  Offset _end = Offset.zero;
  BandMode? _bandMode;
  int _pointer = -1;

  BandMode? get bandMode => _phase == ToolPhase.dragging ? _bandMode : null;
  Rect? get bandScreen =>
      _phase == ToolPhase.dragging ? Rect.fromPoints(_start, _end) : null;

  SelectionKey? _pick(ToolPointerEvent e, ToolContext ctx) {
    if (!ctx.index.pickInto(e.world, e.pickRadiusWorld,
        const QueryFilter.picking(), _hit)) {
      return null;
    }
    return resolveHit(_hit, ctx.document);
  }

  @override
  void onPointerDown(ToolPointerEvent e, ToolContext ctx) {
    if (_phase != ToolPhase.idle) return;
    _phase = ToolPhase.pressed;
    _pointer = e.pointer;
    _start = e.screen;
    _startWorld.setFrom(e.world);
    _downKey = _pick(e, ctx);
    _downHit = _downKey != null;
    notifyListeners();
  }

  @override
  void onPointerMove(ToolPointerEvent e, ToolContext ctx) {
    switch (_phase) {
      case ToolPhase.idle:
        if (e.buttons != 0) return;
        ctx.selection.setHover(_pick(e, ctx));
      case ToolPhase.pressed:
        if (e.pointer != _pointer) return;
        if ((e.screen - _start).distance < kBandSlopPixels) return;
        if (_downHit) return;
        _phase = ToolPhase.dragging;
        ctx.selection.setHover(null);
        _end = e.screen;
        _bandMode = _end.dx >= _start.dx ? BandMode.window : BandMode.crossing;
        notifyListeners();
      case ToolPhase.dragging:
        if (e.pointer != _pointer) return;
        _end = e.screen;
        _bandMode = _end.dx >= _start.dx ? BandMode.window : BandMode.crossing;
        notifyListeners();
    }
  }

  @override
  void onPointerUp(ToolPointerEvent e, ToolContext ctx) {
    if (e.pointer != _pointer) return;
    switch (_phase) {
      case ToolPhase.idle:
        return;
      case ToolPhase.pressed:
        final key = _downKey;
        if (key != null) {
          e.shift ? ctx.selection.toggle([key]) : ctx.selection.replace([key]);
        } else if (!e.shift) {
          ctx.selection.clear();
        }
      case ToolPhase.dragging:
        final keys = _bandKeys(ctx, e);
        e.shift ? ctx.selection.toggle(keys) : ctx.selection.replace(keys);
    }
    _reset();
    notifyListeners();
  }

  List<SelectionKey> _bandKeys(ToolContext ctx, ToolPointerEvent e) {
    final mode = _bandMode!;
    final a = _startWorld, b = e.world;
    final band = Aabb2.raw(math.min(a.x, b.x), math.min(a.y, b.y),
        math.max(a.x, b.x), math.max(a.y, b.y));
    final passing = <int>{};
    ctx.index.forEachLeafInBand(band, mode, const QueryFilter.picking(), passing.add);
    final keys = <SelectionKey>[];
    final seenGroups = <Handle>{};
    final doc = ctx.document;
    Map<Handle, List<int>>? byOwner;
    for (final slot in passing) {
      final owner = doc.entities.ownerAt(slot);
      if (owner == doc.rootHandle) {
        keys.add(SelectionKey.root(doc.entities.handleAt(slot)));
        continue;
      }
      final top = _topmostGroup(doc, owner);
      if (top == null || !seenGroups.add(top)) continue;
      byOwner ??= doc.leavesByOwner();
      if (mode == BandMode.crossing || _everyLeafIn(doc, top, byOwner, passing)) {
        keys.add(SelectionKey.root(top));
      }
    }
    ctx.index.forEachInstanceInBand(band, mode, const QueryFilter.picking(),
        (h) => keys.add(SelectionKey.root(h)));
    return keys;
  }

  /// Every leaf owned by [group] or a group nested in it is in [passing],
  /// and there is at least one.
  bool _everyLeafIn(DraftDocument doc, Handle group,
      Map<Handle, List<int>> byOwner, Set<int> passing) {
    var any = false;
    final stack = <Handle>[group];
    while (stack.isNotEmpty) {
      final g = stack.removeLast();
      for (final slot in byOwner[g] ?? const <int>[]) {
        if (doc.entities.kindAt(slot) == EntityKind.fill) continue;
        any = true;
        if (!passing.contains(slot)) return false;
      }
      final node = doc.tree[g];
      if (node is GroupNode) {
        for (final child in doc.tree.childNodesOf(node.children)) {
          if (doc.tree[child] is GroupNode) stack.add(child);
        }
      }
    }
    return any;
  }

  static Handle? _topmostGroup(DraftDocument doc, Handle owner) {
    final List<Handle> ancestors;
    try {
      ancestors = doc.tree.ancestorsOf(owner);
    } on NodeCycleError {
      return null;
    }
    return topmostGroupOf(doc, owner, ancestors);   // selection.dart
  }

  void _reset() {
    _phase = ToolPhase.idle;
    _pointer = -1;
    _downKey = null;
    _downHit = false;
    _bandMode = null;
  }

  @override
  void onPointerExit(ToolContext ctx) {
    ctx.selection.setHover(null);
    if (_phase == ToolPhase.dragging) cancel(ctx);
  }

  @override
  void cancel(ToolContext ctx) {
    if (_phase == ToolPhase.idle) return;
    _reset();
    notifyListeners();
  }

  @override
  KeyEventResult onKey(KeyEvent event, ToolContext ctx) => KeyEventResult.ignored;

  @override
  void paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport) {
    final rect = bandScreen;
    if (rect == null) return;
    final crossing = _bandMode == BandMode.crossing;
    final color = crossing ? kCrossingBandColor : kWindowBandColor;
    canvas.drawRect(rect, Paint()..color = color.withAlpha(kBandFillAlpha));
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    if (!crossing) {
      canvas.drawRect(rect, stroke);
      return;
    }
    _drawDashedRect(canvas, rect, stroke);   // 6 on / 4 off, screen pixels
  }
}
```

The band-paint `Paint`s allocate per frame **while dragging only**; that is
the tool's preview, not the overlay's steady state, and the log records it
as accepted. `_drawDashedRect` walks the four edges with `Path.moveTo/lineTo`
in 6/4 steps. `selection_style.dart` is Task 7's; for Task 5 define
the two band colours and `kBandFillAlpha` there now (create the file with
just those three) so this compiles.

- [ ] **Step 3: Run, gate line, commit**

```sh
git add lib/src/select_tool.dart lib/src/selection_style.dart lib/src/selection.dart test/select_tool_test.dart
git commit -m "feat(tools): SelectTool hover, click, shift and band"
```

---

