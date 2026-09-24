### Task 8: The Selection panel section

**Files:**
- Create: `apps/floor_planner/lib/selection_panel.dart`
- Modify: `apps/floor_planner/lib/main.dart`. The right panel becomes a
  `Column`:
  - `SelectionPanel` first, sized to its content;
  - then `Expanded(PagePanel)`;
  - both inside the one `ShellShortcutGuard`.
- Test: `apps/floor_planner/test/selection_panel_test.dart`

**Interfaces:**
- Consumes: `BoxParams` and `BoxType` (Task 6), `SelectionController`, and
  the rig (Task 7).
- Produces: `SelectionPanel({required DraftDocument document, required
  SelectionController selection})`, with the keys `selection-panel`,
  `box-width` and `box-height`.

- [ ] **Step 1: Write SP1–SP7.** They reuse `box_rig.dart`. Draw two boxes
  as in BX4, then select with `view.selection.replace([...])`: the
  `PlannerView`'s selection controller, via `SelectionKey.root(h)`. Read
  `planner_view.dart` for the field's name.

```dart
// apps/floor_planner/test/selection_panel_test.dart
import 'package:floor_planner/parametric/box.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'support/box_rig.dart';

Finder get width => find.byKey(const Key('box-width'));
Finder get height => find.byKey(const Key('box-height'));

void main() {
  testWidgets('SP1 shown for exactly one selected box', (tester) async {
    final view = await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    await drawTwoBoxes(tester, view); // in box_rig.dart: BX4's four clicks
    final bs = boxes(view.document);
    expect(width, findsNothing);
    view.selection.replace([SelectionKey.root(bs.first)]);
    await tester.pump();
    expect(width, findsOneWidget);
    expect(tester.widget<TextField>(width).controller!.text, '120');
  });

  testWidgets('SP2 hidden for none, two, and a non-box', (tester) async {
    final view = await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    await drawTwoBoxes(tester, view);
    final bs = boxes(view.document);
    view.selection.replace([for (final b in bs) SelectionKey.root(b)]);
    await tester.pump();
    expect(width, findsNothing);
    final line = addDrafted(view.document, EntityKind.line,
        linePayload(Vector2(7300, 3300), Vector2(7400, 3350)));
    view.document.commands.execute(line);
    view.selection.replace([SelectionKey.root(line.record.handle)]);
    await tester.pump();
    expect(width, findsNothing);
  });

  testWidgets('SP3 Enter commits one step and regenerates', (tester) async {
    final view = await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    await drawTwoBoxes(tester, view);
    final b = boxes(view.document).first;
    view.selection.replace([SelectionKey.root(b)]);
    await tester.pump();
    final depth = view.document.commands.undoDepth;
    await tester.enterText(width, '150');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(view.document.components.get<BoxParams>(b)!.width, 150);
    expect(view.document.commands.undoDepth, depth + 1);
    expect(ParametricSystem(view.document, boxCatalog).drift(), isEmpty);
  });

  testWidgets('SP4 an invalid value reverts and commits nothing',
      (tester) async {
    final view = await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    await drawTwoBoxes(tester, view);
    final b = boxes(view.document).first;
    view.selection.replace([SelectionKey.root(b)]);
    await tester.pump();
    final depth = view.document.commands.undoDepth;
    for (final bad in ['0', '-3', 'abc']) {
      await tester.enterText(height, bad);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(tester.widget<TextField>(height).controller!.text, '70');
    }
    expect(view.document.commands.undoDepth, depth);
  });

  testWidgets('SP5 under runtime the fields are read-only', (tester) async {
    final view = await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    await drawTwoBoxes(tester, view);
    view.document.commands.permissions = DraftPermissions.runtime;
    view.selection.replace([SelectionKey.root(boxes(view.document).first)]);
    await tester.pump();
    expect(tester.widget<TextField>(width).readOnly, isTrue);
  });

  testWidgets('SP6 undo after a panel edit shows the old width '
      '(Review Focus 4)', (tester) async {
    final view = await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    await drawTwoBoxes(tester, view);
    final b = boxes(view.document).first;
    view.selection.replace([SelectionKey.root(b)]);
    await tester.pump();
    await tester.enterText(width, '150');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    view.document.commands.undo();
    await tester.pump();
    expect(tester.widget<TextField>(width).controller!.text, '120');
  });

  testWidgets('SP7 typing B in the width field does not switch tools',
      (tester) async {
    final view = await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    await drawTwoBoxes(tester, view);
    await press(tester, LogicalKeyboardKey.keyV);
    view.selection.replace([SelectionKey.root(boxes(view.document).first)]);
    await tester.pump();
    await tester.tap(width);
    await tester.pump();
    await press(tester, LogicalKeyboardKey.keyB);
    expect(status(tester), isNot('Box'));
  });
}
```

  Add `drawTwoBoxes(tester, view)` to `box_rig.dart`: B, then BX4's four
  clicks, then `pump`. Add the `vector_math` import to this test for
  `Vector2`.

- [ ] **Step 2: Run; they fail.**
- [ ] **Step 3: Implement `selection_panel.dart`.**

```dart
// apps/floor_planner/lib/selection_panel.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'parametric/box.dart';

/// Spec 06 D13: one selected box's width and height. Each commit is one
/// `SetComponentCommand<BoxParams>`, which the parametric system turns into
/// one undo step with its regeneration. 12 builds the real inspector.
class SelectionPanel extends StatefulWidget {
  const SelectionPanel(
      {super.key, required this.document, required this.selection});

  final DraftDocument document;
  final SelectionController selection;

  @override
  State<SelectionPanel> createState() => _SelectionPanelState();
}

class _SelectionPanelState extends State<SelectionPanel> {
  final TextEditingController _width = TextEditingController();
  final TextEditingController _height = TextEditingController();
  late final StreamSubscription<DocChange> _changes;

  @override
  void initState() {
    super.initState();
    widget.selection.addListener(_sync);
    _changes = widget.document.commands.changes.listen((_) => _sync());
    _load();
  }

  @override
  void dispose() {
    widget.selection.removeListener(_sync);
    _changes.cancel();
    _width.dispose();
    _height.dispose();
    super.dispose();
  }

  /// The one selected box, or null.
  Handle? get _box {
    final keys = widget.selection.keys;
    if (keys.length != 1) return null;
    final h = keys.single.target;
    final node = widget.document.tree[h];
    if (node is! GroupNode || node.parent != widget.document.rootHandle) {
      return null;
    }
    return widget.document.components.get<BoxParams>(h) == null ? null : h;
  }

  static String _number(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();

  /// Copies the model into the fields; no rebuild.
  void _load() {
    final h = _box;
    if (h == null) return;
    final p = widget.document.components.get<BoxParams>(h)!;
    final w = _number(p.width), hh = _number(p.height);
    if (_width.text != w) _width.text = w;
    if (_height.text != hh) _height.text = hh;
  }

  /// A selection or document change: reload and rebuild.
  void _sync() {
    _load();
    if (mounted) setState(() {});
  }

  void _submit(Handle h, String text, {required bool isWidth}) {
    final value = double.tryParse(text.trim());
    final p = widget.document.components.get<BoxParams>(h)!;
    if (value == null || !value.isFinite || value <= 0) {
      _sync();
      return;
    }
    final next = isWidth ? p.copyWith(width: value) : p.copyWith(height: value);
    if (next == p) return;
    widget.document.commands.execute(SetComponentCommand<BoxParams>(h, next));
  }

  @override
  Widget build(BuildContext context) {
    final h = _box;
    if (h == null) return const SizedBox.shrink();
    final editable = widget.document.commands.permissions
        .allows(const BoxType().editCapability);
    Widget field(String label, TextEditingController c, bool isWidth) =>
        TextField(
          key: Key(isWidth ? 'box-width' : 'box-height'),
          controller: c,
          readOnly: !editable,
          decoration: InputDecoration(labelText: label, suffixText: 'mm'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onSubmitted: (t) => _submit(h, t, isWidth: isWidth),
          onTapOutside: (_) => _submit(h, c.text, isWidth: isWidth),
        );
    return Material(
      key: const Key('selection-panel'),
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Box', style: Theme.of(context).textTheme.titleSmall),
            field('Width', _width, true),
            field('Height', _height, false),
          ],
        ),
      ),
    );
  }
}
```

  Focus-out uses `onTapOutside`, which runs on a tap elsewhere. If SP4 or
  SP7 show that `onTapOutside` commits during a test's tap on the field
  itself, keep `onSubmitted` only, and record Ruling 06-14 ("Enter
  commits; focus-out reverts to the model value"). The spec's D13 then
  gets amended in Task 11.

- [ ] **Step 4: Wire the panel.** In `main.dart`, the `chrome-right`
  child becomes:

```dart
                    child: ShellShortcutGuard(
                      child: Column(
                        children: [
                          SelectionPanel(
                              document: _document, selection: _selection),
                          Expanded(
                            child: PagePanel(document: _document, page: _page),
                          ),
                        ],
                      ),
                    ),
```

- [ ] **Step 5: Run the app line.**
- [ ] **Step 6: Commit.**

```bash
git add apps/floor_planner/lib apps/floor_planner/test
git commit -m "$(cat <<'EOF'
feat(floor_planner): the Selection panel edits one box's width and height (spec 06 D13)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

