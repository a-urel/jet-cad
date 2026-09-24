### Task 7: The Box tool, the key B, and the install in the shell

**Files:**
- Create: `apps/floor_planner/lib/parametric/box_tool.dart`
- Modify: `apps/floor_planner/lib/main.dart`:
  - `initState` and `dispose`;
  - a `_box` field;
  - a `PaletteEntry` after Rectangle.
- Modify: `apps/floor_planner/lib/shortcut_guard.dart`: add
  `LogicalKeyboardKey.keyB` to `kShellLetterKeys`.
- Create: `apps/floor_planner/test/support/box_rig.dart`
- Test: `apps/floor_planner/test/planner_box_test.dart`
- Modify: `apps/floor_planner/test/startup_plan_test.dart`: add SP5.

**Interfaces:**
- Consumes: `installBoxes` and `BoxParams` (Task 6), and
  `commit(…, needs:)` (Task 5).
- Produces: `class BoxTool extends RectangleTool`, whose `name` is
  `'Box'`. The shell field is `_parametric`.

- [ ] **Step 1: Write the rig and BX1–BX6.**
  - **`box_rig.dart`:**
    - copy `pumpDraw`, `globalOf`, `status`, `press` and `bytes` from
      `test/planner_draw_test.dart`. **Copy, never import a test file**;
    - add `boxDoc(FlutterTextMeasurer m)`: a 1:20 page at `(7000, 3000)`,
      `snapToGrid: false`, and **no** entities, with `clearHistory()`;
    - add `boxKids(DraftDocument, Handle)`;
    - add `boxes(DraftDocument)`, the handles carrying `BoxParams`,
      ascending.
  - **The tests:**

```dart
// apps/floor_planner/test/planner_box_test.dart
import 'package:floor_planner/parametric/box.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'support/box_rig.dart';

void main() {
  testWidgets('BX1 B and the palette entry activate the Box tool',
      (tester) async {
    await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    await press(tester, LogicalKeyboardKey.keyB);
    expect(status(tester), 'Box');
    await press(tester, LogicalKeyboardKey.keyV);
    await tester.tap(find.byKey(const Key('tool-box')));
    await tester.pump();
    expect(status(tester), 'Box');
  });

  testWidgets('BX2 two clicks: one box, four lines, one undo step',
      (tester) async {
    final view = await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    final doc = view.document;
    await press(tester, LogicalKeyboardKey.keyB);
    await tester.tapAt(globalOf(tester, view, 7010, 3020));
    await tester.tapAt(globalOf(tester, view, 7130, 3090));
    await tester.pump();
    final b = boxes(doc).single;
    expect(doc.components.get<BoxParams>(b)!.width, closeTo(120, 1e-6));
    expect(doc.components.get<BoxParams>(b)!.height, closeTo(70, 1e-6));
    expect(boxKids(doc, b), hasLength(4));
    expect(doc.commands.undoDepth, 1);
    doc.commands.undo();
    await tester.pump();
    expect(boxes(doc), isEmpty);
    expect(doc.entities.liveSlots, isEmpty);
  });

  testWidgets('BX3 Fill does not apply to a box', (tester) async {
    final view = await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    await press(tester, LogicalKeyboardKey.keyF);
    await press(tester, LogicalKeyboardKey.keyB);
    await tester.tapAt(globalOf(tester, view, 7010, 3020));
    await tester.tapAt(globalOf(tester, view, 7130, 3090));
    await tester.pump();
    for (final s in view.document.entities.liveSlots) {
      expect(view.document.entities.kindAt(s), EntityKind.line);
    }
  });

  testWidgets('BX4 two overlapping boxes read as one outline',
      (tester) async {
    final view = await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    final doc = view.document;
    await press(tester, LogicalKeyboardKey.keyB);
    await tester.tapAt(globalOf(tester, view, 7010, 3020));
    await tester.tapAt(globalOf(tester, view, 7130, 3090));
    await tester.tapAt(globalOf(tester, view, 7100, 3060));
    await tester.tapAt(globalOf(tester, view, 7190, 3120));
    await tester.pump();
    final bs = boxes(doc);
    expect(bs, hasLength(2));
    // Each outline loses two part-edges inside the other: two edges cut.
    expect(boxKids(doc, bs[0]), hasLength(4));
    expect(boxKids(doc, bs[1]), hasLength(4));
    expect(ParametricSystem(doc, boxCatalog).drift(), isEmpty);
    // Every child midpoint lies outside the other box's interior.
  });

  testWidgets('BX5 click a box, Delete: gone with its component; cmd+Z '
      'brings both back (Review Focus 2)', (tester) async {
    final view = await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    final doc = view.document;
    await press(tester, LogicalKeyboardKey.keyB);
    await tester.tapAt(globalOf(tester, view, 7010, 3020));
    await tester.tapAt(globalOf(tester, view, 7130, 3090));
    await tester.tapAt(globalOf(tester, view, 7100, 3060));
    await tester.tapAt(globalOf(tester, view, 7190, 3120));
    await press(tester, LogicalKeyboardKey.keyV);
    final first = boxes(doc).first;
    // The first box's bottom edge, away from the second box.
    await tester.tapAt(globalOf(tester, view, 7040, 3020));
    await tester.pump();
    await press(tester, LogicalKeyboardKey.delete);
    expect(doc.tree[first], isNull);
    expect(doc.components.get<BoxParams>(first), isNull);
    expect(boxKids(doc, boxes(doc).single), hasLength(4));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await press(tester, LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    expect(doc.components.get<BoxParams>(first), isNotNull);
    expect(boxes(doc), hasLength(2));
  });

  testWidgets('BX6 typing B in the page panel field does not switch tools',
      (tester) async {
    await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    final field = find.descendant(
        of: find.byKey(const Key('chrome-right')),
        matching: find.byType(EditableText));
    await tester.tap(field.first);
    await tester.pump();
    await press(tester, LogicalKeyboardKey.keyB);
    expect(status(tester), isNot('Box'));
  });
}
```

  - **BX4's geometry.** `(7010,3020)-(7130,3090)` and
    `(7100,3060)-(7190,3120)` overlap in one corner, so each box loses one
    corner region and two of its edges are shortened. That is 4 children
    each, and different world segments from an isolated box.
    - Add the midpoint check the comment names: each child's world midpoint
      is not strictly inside the other box's world rectangle.
    - If the exact counts differ from what the geometry gives, **derive
      them by hand, write the derivation in the test's comment, and assert
      that.**
  - **BX5's click point.** `(7040, 3020)` lies on the first box's bottom
    edge, outside the second box. A click there selects the group by
    `resolveHit`.
  - **Undo in BX5.** The shell binds cmd+Z. If key simulation of meta+Z
    does not reach the shell in the test binding, call
    `doc.commands.undo()` instead and note it in the report.

  SP5 goes in `startup_plan_test.dart`:

```dart
  test('SP5 the sample plan holds no parametric object (spec 06 D13)', () {
    final doc = startupPlan(FlutterTextMeasurer());
    final system = ParametricSystem(doc, boxCatalog);
    expect(system.drift(), isEmpty);
    expect(system.diagnostics(), isEmpty);
    expect(doc.components.withComponent<BoxParams>(), isEmpty);
  });
```

  Adapt `startupPlan`'s argument to the file's existing calls.

- [ ] **Step 2: Run; they fail** (no `BoxTool`, and no `tool-box` entry).
- [ ] **Step 3: Implement `box_tool.dart`.**

```dart
// apps/floor_planner/lib/parametric/box_tool.dart
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'box.dart';

/// Spec 06 D13: two opposite corners, world-axis aligned, committed as a
/// parametric box — a group at the lower-left corner carrying [BoxParams].
/// The expander generates its lines. Fill does not apply.
class BoxTool extends RectangleTool {
  BoxTool();

  @override
  String get name => 'Box';

  @override
  void accept(Vector2 point, ToolContext ctx) {
    if (points.isEmpty) {
      points.add(point);
      return;
    }
    final c1 = points.first;
    if (isDegenerateRectangle(c1, point)) return;
    commit(ctx, () {
      final doc = ctx.document;
      final h = doc.handleSeed.next();
      final minX = c1.x < point.x ? c1.x : point.x;
      final minY = c1.y < point.y ? c1.y : point.y;
      return CompoundCommand([
        AddNodeCommand(GroupNode(
            handle: h,
            parent: doc.rootHandle,
            transform: Transform2.translation(minX, minY),
            children: const [])),
        SetComponentCommand<BoxParams>(
            h, BoxParams((point.x - c1.x).abs(), (point.y - c1.y).abs())),
      ], label: 'Add box');
    }, needs: const {
      Capability.structure,
      Capability.components,
      Capability.geometry,
    });
    clearShape();
  }
}
```

  If `points`, `clearShape` or `commit` are not visible to a subclass
  outside the package, check `placement_tool.dart`'s annotations
  (`@protected` members are visible to subclasses). Check the package's
  exports too: `RectangleTool` and `isDegenerateRectangle` must be
  exported.

- [ ] **Step 4: Wire the shell.** In `main.dart`:
  1. Add the imports `parametric/box.dart` and `parametric/box_tool.dart`.
  2. Add the fields `late final ParametricSystem _parametric;` and
     `final BoxTool _box = BoxTool();`.
  3. Add or extend `initState` so it runs, **before anything else that
     reads the document**:

     ```dart
     @override
     void initState() {
       super.initState();
       // Spec 06 D13, Ruling 06-12: startupPlan builds its document with no
       // parametric object, so installing after it is safe.
       _parametric = installBoxes(_document);
     }
     ```

  4. In `dispose`, add `_parametric.dispose();` just before
     `_index.dispose();`.
  5. After the Rectangle entry, add
     `PaletteEntry(keyName: 'tool-box', label: 'Box', shortcut: 'B',
     logicalKey: LogicalKeyboardKey.keyB, tool: _box, drawing: true)`.
  6. In `shortcut_guard.dart`, add `LogicalKeyboardKey.keyB` after `keyR`.

  Existing tests that enumerate every palette entry or `kShellLetterKeys`
  (A1, A2 and A9 in `planner_draw_test.dart`) keep passing. If one counts
  entries, update the count and say so in the report.

- [ ] **Step 5: Run the app line.** Paste the output.
- [ ] **Step 6: Commit.**

```bash
git add apps/floor_planner/lib apps/floor_planner/test
git commit -m "$(cat <<'EOF'
feat(floor_planner): the Box tool on B, and the parametric system in the shell (spec 06 D13)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

