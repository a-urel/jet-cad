### Task 9: The app — register, place, fit to page, the tree, the zoom text

**Files:**
- Modify: `lib/startup_plan.dart`, `lib/planner_view.dart`, `lib/main.dart`
- Test: `test/startup_plan_test.dart`, `test/planner_shell_test.dart`

- [ ] **Step 1: Write the failing tests.** In `startup_plan_test.dart`:

```dart
  test('the startup plan carries an A4 landscape page at 1:50 centred on the '
      'plan, in millimetres, with no history', () {
    final doc = startupPlan(FlutterTextMeasurer());
    final page = doc.components.get<PageComponent>(doc.rootHandle)!;
    expect(page.preset, SheetSize.a4);
    expect(page.orientation, PageOrientation.landscape);
    expect(page.scaleDenominator, 50);
    expect(page.displayUnit, DisplayUnit.meters);
    final rect = sheetWorldRect(page);
    final extents = doc.extents;
    expect(rect.center.x, closeTo(extents.center.x, 1e-9));
    expect(rect.center.y, closeTo(extents.center.y, 1e-9));
    expect(rect.minX, lessThan(kPlanOriginX));
    expect(rect.maxX, greaterThan(kPlanOriginX + kPlanWidth));
    expect(doc.header.units, DrawingUnits.millimeters);
    expect(doc.commands.canUndo, isFalse, reason: 'Ruling 04-1');
  });
```

In `planner_shell_test.dart`, replace the fit test's expectation and add:

```dart
  testWidgets('the camera is fitted to the page at the drawing area\'s size',
      (tester) async {
    // M-04k. The drawing area is the RulerFrame's child, not the view.
    await tester.pumpWidget(const FloorPlannerApp());
    await tester.pump();
    final view = tester.widget<PlannerView>(find.byType(PlannerView));
    final size = tester.getSize(find.byType(DraftCanvas));
    final page = view.document.components.get<PageComponent>(view.document.rootHandle)!;
    final expected = fitToPage(page, size);
    expect(view.camera.value.scale, closeTo(expected.scale, 1e-9));
    expect(view.camera.value.worldToScreenMatrix.e,
        closeTo(expected.worldToScreenMatrix.e, 1e-6));
    final extentsFit = ViewportTransform.fit(view.document.extents, size);
    expect(view.camera.value.scale, isNot(closeTo(extentsFit.scale, 1e-9)));
  });

  testWidgets('the page chrome and the rulers are in the tree, under the canvas',
      (tester) async {
    await tester.pumpWidget(const FloorPlannerApp());
    await tester.pump();
    expect(find.byType(RulerFrame), findsOneWidget);
    final chrome = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is PageChromePainter);
    expect(chrome, findsOneWidget);
    expect(tester.getSize(chrome), tester.getSize(find.byType(DraftCanvas)));
    final view = tester.widget<PlannerView>(find.byType(PlannerView));
    expect(view.document.entities.liveCount, greaterThanOrEqualTo(500));
  });

  testWidgets('the zoom text reads the scale and the fitted zoom', (tester) async {
    await tester.pumpWidget(const FloorPlannerApp());
    await tester.pump();
    final view = tester.widget<PlannerView>(find.byType(PlannerView));
    final page = view.document.components.get<PageComponent>(view.document.rootHandle)!;
    final zoom = zoomOf(view.camera.value.scale, page, kLogicalPixelsPerMm);
    final text = tester.widget<Text>(find.byKey(const Key('zoom-text'))).data;
    expect(text, '1:50 · ${(zoom * 100).round()}%');
    view.camera.zoomAt(const Offset(100, 100), 2.0);
    await tester.pump();
    final after = tester.widget<Text>(find.byKey(const Key('zoom-text'))).data;
    expect(after, '1:50 · ${(zoom * 2 * 100).round()}%');
  });
```

Update the existing `the camera is fitted to the real viewport on first
layout` test: its expected transform becomes `fitToPage(page, size)`.

- [ ] **Step 2: Run to fail.**

- [ ] **Step 3: Implement.** `startup_plan.dart`, at the end of
  `startupPlan` before `return doc;`:

```dart
  // Spec 04 D12 and Ruling 04-1: the page is document data, attached
  // through the log like everything else, and then the history is cleared
  // so a fresh document has none — as a loaded one has none.
  PageComponent.register(doc.components);
  doc.header.units = DrawingUnits.millimeters;
  doc.commands.execute(
      SetComponentCommand<PageComponent>(doc.rootHandle, startupPage(doc.extents)));
  doc.commands.clearHistory();
  return doc;
```

and a top-level function:

```dart
/// A4 landscape at 1:50 in metres, centred on [extents] (spec D4).
PageComponent startupPage(Aabb2 extents) {
  final page = PageComponent();
  final w = page.effectiveWidthMm * page.scaleDenominator;
  final h = page.effectiveHeightMm * page.scaleDenominator;
  return page.copyWith(
      originX: extents.center.x - w / 2, originY: extents.center.y - h / 2);
}
```

`main.dart`: after `_document`, `late final PageNotifier _page =
PageNotifier(_document);`; the initial camera becomes
`fitToPage(_document.components.get<PageComponent>(_document.rootHandle)!,
const Size(1440, 900))`; dispose `_page` after `_selection`; pass `page:
_page` to `PlannerView`; in the top bar, after the status text, a second
`ListenableBuilder(listenable: Listenable.merge([_camera, _page]), builder:
(_, __) => Text(_zoomLine(), key: const Key('zoom-text')))` with:

```dart
  String _zoomLine() {
    final page = _page.value;
    if (page == null) return '';
    final zoom = zoomOf(_camera.value.scale, page, kLogicalPixelsPerMm);
    return '1:${_trimNumber(page.scaleDenominator)} · ${(zoom * 100).round()}%';
  }

  static String _trimNumber(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();
```

`planner_view.dart`: a `page` constructor parameter (`PageNotifier`), and
the build becomes:

```dart
  @override
  Widget build(BuildContext context) => RulerFrame(
        camera: widget.camera,
        page: widget.page,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (!_fitted &&
                constraints.biggest.width > 0 &&
                constraints.biggest.height > 0) {
              _fitted = true;
              final page = widget.page.value;
              // Spec D4/D11: the page when there is one, at the drawing
              // area's size — inside the frame, so the bars are excluded.
              widget.camera.value = page != null
                  ? fitToPage(page, constraints.biggest)
                  : ViewportTransform.fit(widget.document.extents, constraints.biggest);
            }
            return CameraGestureDetector(
              camera: widget.camera,
              policy: widget.policy,
              child: InteractionLayer(
                tools: widget.tools,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: PageChromePainter(
                            camera: widget.camera,
                            page: widget.page,
                            repaint: _chromeRepaint,
                          ),
                        ),
                      ),
                    ),
                    DraftCanvas(
                      document: widget.document,
                      index: widget.index,
                      camera: widget.camera,
                      tiles: false,
                    ),
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: SelectionOverlayPainter(
                            selection: widget.selection,
                            tools: widget.tools,
                            camera: widget.camera,
                            outlines: _outlines,
                            repaint: _repaint,
                          ),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
```

with `late final Listenable _chromeRepaint = Listenable.merge([widget.camera,
widget.page]);`. The `Stack`'s size comes from `DraftCanvas`, its one
non-positioned child, exactly as before.

- [ ] **Step 4: Run to pass**: both app test files, then the full
  `floor_planner` line including both builds.
- [ ] **Step 5: Commit** — `feat(app): the page under the plan — startup
  page, fit to page, rulers and chrome in the tree, zoom text`.

---

