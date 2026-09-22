### Task 10: The app — controllers on the shell, the interaction tree, the status text

**Files:**
- Modify: `lib/main.dart`, `lib/planner_view.dart`
- Test: `test/planner_shell_test.dart`

- [ ] **Step 1: Failing tests** (criterion 13):

1. `'the status text shows the tool name and follows the selection'`:
   `find.byKey(Key('status-text'))` reads `'Select'`; reach the
   controllers through `tester.widget<PlannerView>(...)` (`selection`,
   `tools` become `PlannerView` fields); `selection.replace([...])` with a
   key for one of the startup plan's entities (pick one with
   `SpatialIndex.pickInto` at a known wall's midpoint — `kPlanOriginX +
   100, kPlanOriginY` is on the outer wall; check with a first assertion);
   `await tester.pump()`; text reads `'Select — 1 selected'`.
2. `'the interaction tree is in place'`: `find.byType(InteractionLayer)`,
   `find.byType(SelectionOverlay)` (via `find.byWidgetPredicate((w) => w is
   CustomPaint && w.painter is SelectionOverlay)`), both once; the overlay's
   `RenderCustomPaint.size == DraftCanvas`'s size.
3. `'a click on a wall selects it in the running shell'`: `tester.tapAt`
   the screen position of that midpoint (through `view.camera.value
   .worldToScreen` plus the view's top-left from `tester.getTopLeft`);
   `selection.length == 1`.
4. The four existing tests stay green unedited.

- [ ] **Step 2: Implement**

`_PlannerShellState` gains:

```dart
  late final SelectionController _selection = SelectionController(_document);
  late final ToolContext _context = ToolContext(
      document: _document, index: _index, camera: _camera, selection: _selection);
  late final ToolController _tools =
      ToolController(initial: SelectTool(), context: _context);
  late final Listenable _status = Listenable.merge([_selection, _tools]);
```

disposed in `dispose()` (`_tools.dispose(); _selection.dispose();` before
the camera). `chrome-top` becomes a `Container` with an `Align(alignment:
Alignment.centerLeft, child: Padding(padding: EdgeInsets.symmetric(horizontal:
12), child: ListenableBuilder(listenable: _status, builder: (_, __) => Text(
_statusLine(), key: const Key('status-text')))))` where `_statusLine()` is
`'${_tools.active.name}'` plus `' — ${_selection.length} selected'` when
non-empty. `PlannerView` gains `selection` and `tools` parameters and builds:

```dart
          return CameraGestureDetector(
            camera: widget.camera,
            policy: widget.policy,
            child: InteractionLayer(
              tools: widget.tools,
              child: Stack(
                children: [
                  DraftCanvas(document: widget.document, index: widget.index,
                      camera: widget.camera, tiles: false),   // already inside its own RepaintBoundary
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: SelectionOverlay(
                          selection: widget.selection, tools: widget.tools,
                          camera: widget.camera, outlines: _outlines,
                          repaint: _repaint),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
```

with `_outlines = OutlineCache(widget.document, widget.selection)` and
`_repaint = Listenable.merge([widget.selection, widget.tools, widget.camera])`
as `late final` fields of `_PlannerViewState`, the cache disposed in
`dispose`.

- [ ] **Step 3: Run the app line, including both builds**

```sh
cd apps/floor_planner && CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed . && flutter build macos --debug && flutter build web
git status --short   # restore any analysis_options.yaml pub get rewrote
```

- [ ] **Step 4: Commit**

```sh
git add lib/main.dart lib/planner_view.dart test/planner_shell_test.dart
git commit -m "feat(app): selection, hover and band in the floor planner; tool name and count in the top bar"
```

---

