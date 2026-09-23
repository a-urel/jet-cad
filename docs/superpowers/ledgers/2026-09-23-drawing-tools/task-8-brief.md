### Task 8: The sample plan's furniture becomes filled regions

Package: `apps/floor_planner`.

**Files:**
- Modify: `lib/startup_plan.dart`
- Test: `test/startup_plan_test.dart` (SP1, SP2 added)

**Interfaces:**
- Consumes: Task 1 (`addDraftedRegion`, `rectanglePayload`,
  `polylinePayload`, `circlePayload`).
- Produces: `_Pen.rectRegion`, `_Pen.polygonRegion`, `_Pen.circleRegion`
  (private).

- [ ] **Step 1: Write the failing tests.** Append to
  `test/startup_plan_test.dart`'s `main()`. Add the `jet_cad_2d` import if
  the file lacks it.

```dart
  test('SP1 the furniture is eight filled regions with the furniture '
      'outline', () {
    final doc = startupPlan(FlutterTextMeasurer());
    final boundaries = <Handle>[];
    for (final slot in doc.entities.liveSlots) {
      final h = doc.entities.handleAt(slot);
      if (doc.fills.fillsOf(h).isNotEmpty) boundaries.add(h);
    }
    expect(boundaries, hasLength(8));
    for (final b in boundaries) {
      final r = doc.entities.read(doc.entities.slotOf(b)!);
      expect(r.color, const TrueColor(0x8A6D3B));
      expect(r.lineweight, 25);
      final fill = doc.fills.fillsOf(b).single;
      expect(doc.entities.read(doc.entities.slotOf(fill)!).color,
          kDraftFillColor);
    }
    expect(doc.entities.liveCount, 509, reason: 'Ruling 05-12: 523 − 14');
  });

  test('SP2 every fill draws over every floor-finish line (M-05r)', () {
    final doc = startupPlan(FlutterTextMeasurer());
    var maxFinish = 0, minFill = 1 << 62;
    for (final slot in doc.entities.liveSlots) {
      final r = doc.entities.read(slot);
      if (r.kind == EntityKind.fill && r.handle.value < minFill) {
        minFill = r.handle.value;
      }
      if (r.kind == EntityKind.line &&
          r.color == const TrueColor(0xBBBBBB) &&
          r.handle.value > maxFinish) {
        maxFinish = r.handle.value;
      }
    }
    expect(maxFinish, greaterThan(0));
    expect(minFill, greaterThan(maxFinish));
  });
```

  (`_finishColor` is `TrueColor(0xBBBBBB)`, at `startup_plan.dart:37`.
  Verify that before relying on it.)

- [ ] **Step 2: Run them and see them fail.**
  Run: `cd apps/floor_planner && CI=true flutter test test/startup_plan_test.dart`
  Expected: SP1 finds 0 regions, and SP2's `minFill` is `1 << 62`.

- [ ] **Step 3: Implement.** In `_Pen`, add:

```dart
  /// Spec 05 D14: a furniture piece as one region, the fill under its
  /// boundary, the boundary keeping today's colour and weight.
  void _region(EntityKind kind, GeometryPayload payload) =>
      doc.commands.execute(addDraftedRegion(doc, kind, payload,
          boundaryColor: _furnitureColor, boundaryLineweight: 25)!);

  void rectRegion(double ax, double ay, double bx, double by) => _region(
      EntityKind.polyline, rectanglePayload(Vector2(ax, ay), Vector2(bx, by)));

  void polygonRegion(List<double> xy) => _region(
      EntityKind.polyline,
      polylinePayload([
        for (var i = 0; i < xy.length; i += 2) Vector2(xy[i], xy[i + 1]),
      ], closed: true));

  void circleRegion(double cx, double cy, double r) =>
      _region(EntityKind.circle, circlePayload(Vector2(cx, cy), r));
```

  Import `package:vector_math/vector_math_64.dart show Vector2`, which is
  already an app dependency (`pubspec.yaml:21`).

  Then **delete** the furniture block (`// --- Furniture: rectangles, one
  L. ---` through the basin). Re-add it **after the parquet call**, before
  `PageComponent.register`:

```dart
  // --- Furniture: filled regions (spec 05 D14), after the finishes so
  // their fills draw over the tile and parquet lines. ---
  p.rectRegion(x0 + 400, y0 + 6600, x0 + 2200, y0 + 8600); // bed
  p.rectRegion(x0 + 2900, y0 + 6800, x0 + 4500, y0 + 8600); // bed
  p.rectRegion(x0 + 6000, y0 + 4200, x0 + 9000, y0 + 5100); // sofa
  p.rectRegion(x0 + 6400, y0 + 5600, x0 + 8600, y0 + 6800); // table
  // The kitchen counter: one L, so its fill has no seam.
  p.polygonRegion([
    x0 + 5400, y0 + 400, //
    x0 + 9100, y0 + 400,
    x0 + 9100, y0 + 1000,
    x0 + 6000, y0 + 1000,
    x0 + 6000, y0 + 3100,
    x0 + 5400, y0 + 3100,
  ]);
  p.rectRegion(x0 + 12200, y0 + 400, x0 + 13500, y0 + 2000); // bath
  p.circleRegion(x0 + 7600, y0 + 6200, 350); // lamp, after the table
  p.circleRegion(x0 + 10300, y0 + 1200, 220); // basin
```

  If `_Pen.rect` is now unused, keep it (the walls use it) or delete it;
  `analyze` decides.

- [ ] **Step 4: Run the tests and see them pass.** Run the whole app suite.
  `planner_shell_test`'s `>= 500` and `startup_plan_test`'s `[500, 1000]`
  still hold at 509.

- [ ] **Step 5: Gate and commit.** Run the `floor_planner` line.

```bash
git add apps/floor_planner/lib/startup_plan.dart apps/floor_planner/test/startup_plan_test.dart
git commit -m "$(cat <<'EOF'
feat(app): the sample plan's furniture as filled regions

The beds, the sofa, the table, the bath, the L-shaped counter, the lamp
and the basin are regions in the drafting fill colour with their old
outline, emitted after the floor finishes so the fills cover the tile
and parquet lines. 523 entities become 509. Spec 05 D14.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

