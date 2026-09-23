### Task 7: The app: palette, shortcuts, the guard, the text field, `_activate`

Package: `apps/floor_planner`.

**Files:**
- Create: `lib/shortcut_guard.dart`, `lib/tool_palette.dart`,
  `lib/text_entry_overlay.dart`
- Modify: `lib/main.dart`, `lib/planner_view.dart`
- Test: `test/planner_draw_test.dart` (A1–A12)

**Interfaces:**
- Consumes: Tasks 3–6, all six tools and `TextTool.pending`,
  `controller`, `commitText` and `cancelText`. It also uses
  `ToolController`, `SelectTool` and `SelectionController.clear()`.
- Produces:
  - `const List<LogicalKeyboardKey> kShellLetterKeys` (V L P R C A T F);
  - `class ShellShortcutGuard extends StatelessWidget { const ShellShortcutGuard({super.key, required Widget child}); }`;
  - `class PaletteEntry` (`keyName`, `label`, `shortcut`, `logicalKey`,
    `tool`, `drawing`);
  - `class ToolPalette extends StatelessWidget` (`entries`, `tools`, `fill`,
    `geometryAllowed`, `onSelect`);
  - `const Size kTextEntrySize = Size(240, 32)`;
  - `class TextEntryOverlay extends StatefulWidget` (`tool`, `tools`,
    `camera`);
  - `PlannerView` gains `required TextTool textTool`.

- [ ] **Step 1: Write the failing tests.** Create
  `test/planner_draw_test.dart`:

```dart
import 'package:floor_planner/main.dart';
import 'package:floor_planner/planner_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// A 1:20 page anchored at (7000, 3000), grid snap off, and one line to
/// select. `DraftCanvas` needs a `FlutterTextMeasurer`.
({DraftDocument doc, Handle line}) drawDoc(FlutterTextMeasurer m) {
  final doc = DraftDocument.empty(measurer: m);
  PageComponent.register(doc.components);
  doc.commands.execute(SetComponentCommand<PageComponent>(
      doc.rootHandle,
      PageComponent(
          scaleDenominator: 20,
          originX: 7000,
          originY: 3000,
          snapToGrid: false)));
  final add = addDrafted(doc, EntityKind.line,
      linePayload(Vector2(7137.3, 3161.7), Vector2(7300.9, 3190.1)));
  doc.commands.execute(add);
  doc.commands.clearHistory();
  return (doc: doc, line: add.record.handle);
}

/// Pumps the shell, then sets a zoomed, rotated, **non-reflecting** camera:
/// the app camera in `planner_grips_test.dart` is a reflection, whose
/// `b == c` hides a transposition.
Future<PlannerView> pumpDraw(WidgetTester tester, DraftDocument doc) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: PlannerShell(document: doc)));
  await tester.pump();
  final view = tester.widget<PlannerView>(find.byType(PlannerView));
  final size = tester.getSize(find.byType(InteractionLayer));
  final linear =
      Transform2.rotation(0.35).multiply(Transform2.scale(2.0, 2.0));
  final mid = linear.transformPoint(Vector2(7150, 3110));
  view.camera.value = ViewportTransform(
      worldToScreenMatrix: Transform2.translation(
              size.width / 2 - mid.x, size.height / 2 - mid.y)
          .multiply(linear));
  await tester.pump();
  return view;
}

Offset globalOf(WidgetTester tester, PlannerView view, double x, double y) {
  final s = view.camera.value.worldToScreen(Vector2(x, y));
  return tester.getTopLeft(find.byType(InteractionLayer)) + Offset(s.x, s.y);
}

String status(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('status-text'))).data!;

Future<bool> press(WidgetTester tester, LogicalKeyboardKey key) async {
  final handled = await tester.sendKeyEvent(key);
  await tester.pump();
  return handled;
}

String bytes(PlannerView view) =>
    DraftDocumentCodec.encodeToString(view.document);

List<Handle> ofKind(DraftDocument doc, EntityKind kind) => [
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.kindAt(slot) == kind) doc.entities.handleAt(slot),
    ];

void main() {
  testWidgets('A1 each palette entry activates its tool', (tester) async {
    await pumpDraw(tester, drawDoc(FlutterTextMeasurer()).doc);
    for (final (key, name) in const [
      ('tool-line', 'Line'),
      ('tool-polyline', 'Polyline'),
      ('tool-rectangle', 'Rectangle'),
      ('tool-circle', 'Circle'),
      ('tool-arc', 'Arc'),
      ('tool-text', 'Text'),
      ('tool-select', 'Select'),
    ]) {
      await tester.tap(find.byKey(Key(key)));
      await tester.pump();
      expect(status(tester), name, reason: key);
    }
  });

  testWidgets('A2 each shortcut activates its tool, and F toggles Fill',
      (tester) async {
    await pumpDraw(tester, drawDoc(FlutterTextMeasurer()).doc);
    for (final (key, name) in const [
      (LogicalKeyboardKey.keyL, 'Line'),
      (LogicalKeyboardKey.keyP, 'Polyline'),
      (LogicalKeyboardKey.keyR, 'Rectangle'),
      (LogicalKeyboardKey.keyC, 'Circle'),
      (LogicalKeyboardKey.keyA, 'Arc'),
      (LogicalKeyboardKey.keyT, 'Text'),
      (LogicalKeyboardKey.keyV, 'Select'),
    ]) {
      await press(tester, key);
      expect(status(tester), name);
    }
    bool fill() => tester
        .widget<CheckboxListTile>(find.byKey(const Key('tool-fill')))
        .value!;
    expect(fill(), isFalse);
    await press(tester, LogicalKeyboardKey.keyF);
    expect(fill(), isTrue);
    await tester.tap(find.byKey(const Key('tool-fill')));
    await tester.pump();
    expect(fill(), isFalse);
  });

  testWidgets('A3 activating a drawing tool clears the selection',
      (tester) async {
    final d = drawDoc(FlutterTextMeasurer());
    final view = await pumpDraw(tester, d.doc);
    view.selection.replace([SelectionKey.root(d.line)]);
    await tester.pump();
    expect(view.selection.isEmpty, isFalse);
    await press(tester, LogicalKeyboardKey.keyL);
    expect(view.selection.isEmpty, isTrue);
  });

  testWidgets('A4 an idle Escape returns to Select (M-05m)', (tester) async {
    await pumpDraw(tester, drawDoc(FlutterTextMeasurer()).doc);
    await press(tester, LogicalKeyboardKey.keyL);
    await press(tester, LogicalKeyboardKey.escape);
    expect(status(tester), 'Select');
  });

  testWidgets('A5 text end to end: T, click, type, Enter; then focus is back '
      'on the canvas', (tester) async {
    final view = await pumpDraw(tester, drawDoc(FlutterTextMeasurer()).doc);
    await press(tester, LogicalKeyboardKey.keyT);
    await tester.tapAt(globalOf(tester, view, 7100.5, 3050.25));
    await tester.pump();
    expect(find.byKey(const Key('text-entry')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('text-entry')), 'Kitchen');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    final text = ofKind(view.document, EntityKind.text).single;
    final slot = view.document.entities.slotOf(text)!;
    expect(view.document.entities.read(slot).text, 'Kitchen');
    expect(
        view.document.geometry
            .read(view.document.entities.geomIndexAt(slot))
            .scalars[0],
        50.0);
    expect(find.byKey(const Key('text-entry')), findsNothing);
    await press(tester, LogicalKeyboardKey.keyL);
    expect(status(tester), 'Line', reason: 'Ruling 05-7: focus came back');
  });

  testWidgets('A6 text: Escape and a palette click cancel byte-identically; a '
      'canvas click commits', (tester) async {
    final view = await pumpDraw(tester, drawDoc(FlutterTextMeasurer()).doc);
    final before = bytes(view);
    await press(tester, LogicalKeyboardKey.keyT);
    await tester.tapAt(globalOf(tester, view, 7100, 3050));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('text-entry')), 'x');
    await press(tester, LogicalKeyboardKey.escape);
    expect(bytes(view), before);
    expect(find.byKey(const Key('text-entry')), findsNothing);

    await tester.tapAt(globalOf(tester, view, 7100, 3050));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('text-entry')), 'y');
    await tester.tap(find.byKey(const Key('tool-select')));
    await tester.pump();
    expect(bytes(view), before);

    await press(tester, LogicalKeyboardKey.keyT);
    await tester.tapAt(globalOf(tester, view, 7100, 3050));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('text-entry')), 'Hall');
    await tester.tapAt(globalOf(tester, view, 7180, 3020));
    await tester.pump();
    expect(ofKind(view.document, EntityKind.text), hasLength(1));
  });

  testWidgets('A7 the field sits at the camera\'s point and survives a pan '
      'with its state (M-05n, M-05u)', (tester) async {
    final view = await pumpDraw(tester, drawDoc(FlutterTextMeasurer()).doc);
    await press(tester, LogicalKeyboardKey.keyT);
    await tester.tapAt(globalOf(tester, view, 7100.5, 3050.25));
    await tester.pump();
    final field = find.byKey(const Key('text-entry'));
    final placed = view.tools.active as TextTool;
    final at = placed.pending.value!.point;
    Offset corner() =>
        tester.getBottomLeft(find.byKey(const Key('text-entry-box')));
    final want = globalOf(tester, view, at.x, at.y);
    expect((corner() - want).distance, lessThan(0.5));
    await tester.enterText(field, 'abc');
    final state = tester.state<EditableTextState>(find.byType(EditableText));
    view.camera.value = ViewportTransform(
        worldToScreenMatrix: Transform2.translation(40, -25)
            .multiply(view.camera.value.worldToScreenMatrix));
    await tester.pump();
    expect((corner() - globalOf(tester, view, at.x, at.y)).distance,
        lessThan(0.5));
    expect(identical(tester.state<EditableTextState>(find.byType(EditableText)),
        state), isTrue, reason: 'Ruling 05-10: never rebuilt by the camera');
    expect(state.widget.focusNode.hasFocus, isTrue);
    expect(placed.controller.text, 'abc');
  });

  testWidgets('A8 shell letters typed into the field are not consumed and do '
      'not switch tools (M-05v)', (tester) async {
    final view = await pumpDraw(tester, drawDoc(FlutterTextMeasurer()).doc);
    await press(tester, LogicalKeyboardKey.keyT);
    await tester.tapAt(globalOf(tester, view, 7100, 3050));
    await tester.pump();
    for (final key in const [
      LogicalKeyboardKey.keyL,
      LogicalKeyboardKey.keyA,
      LogicalKeyboardKey.keyT,
      LogicalKeyboardKey.keyF,
      LogicalKeyboardKey.keyV,
    ]) {
      expect(await press(tester, key), isFalse,
          reason: '$key reaches the platform as text (Ruling 05-9)');
      expect(status(tester), 'Text');
    }
  });

  testWidgets('A9 letters and cmd+Z in the page panel\'s scale field neither '
      'switch tools nor undo the document (Review Focus 1)', (tester) async {
    final view = await pumpDraw(tester, drawDoc(FlutterTextMeasurer()).doc);
    await press(tester, LogicalKeyboardKey.keyR);
    await tester.tapAt(globalOf(tester, view, 7010, 3020));
    await tester.tapAt(globalOf(tester, view, 7090, 3070));
    await tester.pump();
    expect(view.document.commands.undoDepth, 1);
    await tester.tap(find.byKey(const Key('page-scale')));
    await tester.pump();
    expect(await press(tester, LogicalKeyboardKey.keyL), isFalse);
    expect(status(tester), 'Rectangle');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(view.document.commands.undoDepth, 1, reason: 'not undone');
  });

  testWidgets('A10 a tool shortcut mid-polyline cancels it byte-identically '
      '(Review Focus 2)', (tester) async {
    final view = await pumpDraw(tester, drawDoc(FlutterTextMeasurer()).doc);
    final before = bytes(view);
    await press(tester, LogicalKeyboardKey.keyP);
    await tester.tapAt(globalOf(tester, view, 7010, 3020));
    await tester.tapAt(globalOf(tester, view, 7060, 3090));
    await tester.pump();
    await press(tester, LogicalKeyboardKey.keyL);
    expect(status(tester), 'Line');
    expect(bytes(view), before);
  });

  testWidgets('A11 cmd+Z after a commit, with the tool armed and idle, removes '
      'exactly that shape (Review Focus 5)', (tester) async {
    final view = await pumpDraw(tester, drawDoc(FlutterTextMeasurer()).doc);
    final before = bytes(view);
    await press(tester, LogicalKeyboardKey.keyR);
    await tester.tapAt(globalOf(tester, view, 7010, 3020));
    await tester.tapAt(globalOf(tester, view, 7090, 3070));
    await tester.pump();
    expect(ofKind(view.document, EntityKind.polyline), hasLength(1));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(bytes(view), before);
    expect(status(tester), 'Rectangle', reason: 'still armed');
  });

  testWidgets('A12 under runtime permissions the drawing tools are disabled',
      (tester) async {
    final d = drawDoc(FlutterTextMeasurer());
    d.doc.commands.permissions = DraftPermissions.runtime;
    await pumpDraw(tester, d.doc);
    expect(tester.widget<ListTile>(find.byKey(const Key('tool-line'))).enabled,
        isFalse);
    expect(tester.widget<ListTile>(find.byKey(const Key('tool-select'))).enabled,
        isTrue);
    await press(tester, LogicalKeyboardKey.keyL);
    expect(status(tester), 'Select');
  });
}
```

  A7 takes the field's corner from the keyed `SizedBox`
  (`text-entry-box`) that Task 7 Step 5 wraps it in.

- [ ] **Step 2: Run them and see them fail.**
  Run: `cd apps/floor_planner && CI=true flutter test test/planner_draw_test.dart`
  Expected: compile errors or missing keys (`tool-line` and so on).

- [ ] **Step 3: `lib/shortcut_guard.dart`.**

```dart
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';

/// The shell's single-letter tool shortcuts (spec 05 D5).
const List<LogicalKeyboardKey> kShellLetterKeys = [
  LogicalKeyboardKey.keyV,
  LogicalKeyboardKey.keyL,
  LogicalKeyboardKey.keyP,
  LogicalKeyboardKey.keyR,
  LogicalKeyboardKey.keyC,
  LogicalKeyboardKey.keyA,
  LogicalKeyboardKey.keyT,
  LogicalKeyboardKey.keyF,
];

/// Spec 05 D9 and Ruling 05-8.
///
/// **Why this exists.** A `Shortcuts` or `CallbackShortcuts` above a text
/// field takes the field's keystrokes ("Shortcuts prevent text input fields
/// from receiving their keystrokes as text input", Flutter's
/// `editable_text.dart`). The shell's tool letters and its cmd/ctrl+Z are
/// such shortcuts.
///
/// **What it does.** It maps each of them, **nearer** the field, to
/// `DoNothingAndStopPropagationTextIntent`. `EditableText` answers that
/// intent with `DoNothingAction(consumesKey: false)`, so the key stops here
/// and reaches the field as text.
///
/// **Elsewhere it is inert.** With focus anywhere other than a text field,
/// no action is found, and the key bubbles up to the shell as before.
class ShellShortcutGuard extends StatelessWidget {
  const ShellShortcutGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          for (final key in kShellLetterKeys)
            SingleActivator(key): const DoNothingAndStopPropagationTextIntent(),
          const SingleActivator(LogicalKeyboardKey.keyZ, meta: true):
              const DoNothingAndStopPropagationTextIntent(),
          const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
              const DoNothingAndStopPropagationTextIntent(),
        },
        child: child,
      );
}
```

- [ ] **Step 4: `lib/tool_palette.dart`.**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

/// One palette row and its shortcut (spec 05 D5).
final class PaletteEntry {
  const PaletteEntry({
    required this.keyName,
    required this.label,
    required this.shortcut,
    required this.logicalKey,
    required this.tool,
    required this.drawing,
  });

  final String keyName;
  final String label;
  final String shortcut;
  final LogicalKeyboardKey logicalKey;
  final Tool tool;

  /// A drawing tool: disabled while geometry is denied.
  final bool drawing;
}

/// Spec 05 D5, D13: the tools and the Fill toggle, in the left panel.
///
/// **It never takes focus** (`ExcludeFocus`, Ruling 05-6), so the canvas
/// keeps it and the shell's shortcuts keep working after a click here.
class ToolPalette extends StatelessWidget {
  const ToolPalette({
    super.key,
    required this.entries,
    required this.tools,
    required this.fill,
    required this.geometryAllowed,
    required this.onSelect,
  });

  final List<PaletteEntry> entries;
  final ToolController tools;
  final ValueNotifier<bool> fill;
  final bool geometryAllowed;
  final void Function(Tool tool) onSelect;

  @override
  Widget build(BuildContext context) => ExcludeFocus(
        child: ListenableBuilder(
          listenable: Listenable.merge([tools, fill]),
          builder: (context, _) => ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              for (final e in entries)
                ListTile(
                  key: Key(e.keyName),
                  dense: true,
                  selected: identical(tools.active, e.tool),
                  enabled: !e.drawing || geometryAllowed,
                  title: Text(e.label),
                  trailing: Text(e.shortcut),
                  onTap: () => onSelect(e.tool),
                ),
              const Divider(),
              CheckboxListTile(
                key: const Key('tool-fill'),
                dense: true,
                title: const Text('Fill'),
                secondary: const Text('F'),
                value: fill.value,
                onChanged: geometryAllowed
                    ? (v) => fill.value = v ?? false
                    : null,
              ),
            ],
          ),
        ),
      );
}
```

- [ ] **Step 5: `lib/text_entry_overlay.dart`.**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'shortcut_guard.dart';

/// Ruling 05-11: the field's size. Its bottom-left sits at the insertion
/// point's screen position.
const Size kTextEntrySize = Size(240, 32);

/// Spec 05 D9: the inline field for [TextTool].
///
/// **Where it sits.** Outside the `InteractionLayer`, so a click on it is
/// not a canvas click.
///
/// **Keys.** The guard lets the shell's letters through as text, and
/// Escape cancels.
///
/// **Rebuilds.** The field is a stable child of the camera builder, so a pan
/// or zoom moves it and never rebuilds it (Ruling 05-10).
///
/// **Commit and cancel.** Enter commits. Any other loss of focus cancels
/// if the placement is still pending. A canvas click has already committed
/// synchronously in the tool, so its blur finds nothing to cancel.
class TextEntryOverlay extends StatefulWidget {
  const TextEntryOverlay({
    super.key,
    required this.tool,
    required this.tools,
    required this.camera,
  });

  final TextTool tool;
  final ToolController tools;
  final CameraController camera;

  @override
  State<TextEntryOverlay> createState() => _TextEntryOverlayState();
}

class _TextEntryOverlayState extends State<TextEntryOverlay> {
  final FocusNode _focus = FocusNode(debugLabel: 'text-entry');

  @override
  void initState() {
    super.initState();
    widget.tool.pending.addListener(_onPending);
    _focus.addListener(_onFocus);
  }

  /// Ruling 05-7: hand focus back to the canvas, the scope's previous child,
  /// as soon as the placement ends.
  void _onPending() {
    if (widget.tool.pending.value == null && _focus.hasFocus) {
      _focus.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
    }
  }

  void _onFocus() {
    if (!_focus.hasFocus && widget.tool.pending.value != null) {
      widget.tool.cancelText(widget.tools.context);
    }
  }

  void _submit(String s) => widget.tool.commitText(s, widget.tools.context);

  void _cancel() => widget.tool.cancelText(widget.tools.context);

  @override
  void dispose() {
    widget.tool.pending.removeListener(_onPending);
    _focus.removeListener(_onFocus);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextPlacement?>(
        valueListenable: widget.tool.pending,
        builder: (context, placed, _) {
          if (placed == null) return const SizedBox.shrink();
          final field = SizedBox.fromSize(
            key: const Key('text-entry-box'),
            size: kTextEntrySize,
            child: ShellShortcutGuard(
              child: CallbackShortcuts(
                bindings: <ShortcutActivator, VoidCallback>{
                  const SingleActivator(LogicalKeyboardKey.escape): _cancel,
                },
                child: TextField(
                  key: const Key('text-entry'),
                  controller: widget.tool.controller,
                  focusNode: _focus,
                  autofocus: true,
                  maxLines: 1,
                  onSubmitted: _submit,
                  decoration: const InputDecoration(
                      isDense: true, border: OutlineInputBorder()),
                ),
              ),
            ),
          );
          return Stack(
            children: [
              ListenableBuilder(
                listenable: widget.camera,
                builder: (context, child) {
                  final s = widget.camera.value.worldToScreen(placed.point);
                  return Positioned(
                    left: s.x,
                    top: s.y - kTextEntrySize.height,
                    child: child!,
                  );
                },
                child: field,
              ),
            ],
          );
        },
      );
}
```

- [ ] **Step 6: `lib/planner_view.dart`.** Add `required this.textTool`
  and `final TextTool textTool;`. In `build`, the `LayoutBuilder` builder
  now returns:

```dart
            return Stack(
              children: [
                Positioned.fill(
                  child: CameraGestureDetector(
                    // … exactly as before …
                  ),
                ),
                // Spec 05 D9: outside the InteractionLayer, so a click on
                // the field is not a canvas click.
                Positioned.fill(
                  child: TextEntryOverlay(
                    tool: widget.textTool,
                    tools: widget.tools,
                    camera: widget.camera,
                  ),
                ),
              ],
            );
```

  Import `text_entry_overlay.dart`. An empty `Stack` region does not
  absorb hits (`RenderStack` has no `hitTestSelf`), so pointer events still
  reach the canvas beneath.

- [ ] **Step 7: `lib/main.dart`.** In `_PlannerShellState`:

```dart
  // Spec 05 D5, D13: the shell owns the tools and the Fill toggle.
  final ValueNotifier<bool> _fill = ValueNotifier<bool>(false);
  final SelectTool _select = SelectTool();
  final LineTool _line = LineTool();
  late final PolylineTool _polyline = PolylineTool(fill: _fill);
  late final RectangleTool _rectangle = RectangleTool(fill: _fill);
  late final CircleTool _circle = CircleTool(fill: _fill);
  final ArcTool _arc = ArcTool();
  final TextTool _text = TextTool();

  late final List<PaletteEntry> _entries = [
    PaletteEntry(keyName: 'tool-select', label: 'Select', shortcut: 'V', logicalKey: LogicalKeyboardKey.keyV, tool: _select, drawing: false),
    PaletteEntry(keyName: 'tool-line', label: 'Line', shortcut: 'L', logicalKey: LogicalKeyboardKey.keyL, tool: _line, drawing: true),
    PaletteEntry(keyName: 'tool-polyline', label: 'Polyline', shortcut: 'P', logicalKey: LogicalKeyboardKey.keyP, tool: _polyline, drawing: true),
    PaletteEntry(keyName: 'tool-rectangle', label: 'Rectangle', shortcut: 'R', logicalKey: LogicalKeyboardKey.keyR, tool: _rectangle, drawing: true),
    PaletteEntry(keyName: 'tool-circle', label: 'Circle', shortcut: 'C', logicalKey: LogicalKeyboardKey.keyC, tool: _circle, drawing: true),
    PaletteEntry(keyName: 'tool-arc', label: 'Arc', shortcut: 'A', logicalKey: LogicalKeyboardKey.keyA, tool: _arc, drawing: true),
    PaletteEntry(keyName: 'tool-text', label: 'Text', shortcut: 'T', logicalKey: LogicalKeyboardKey.keyT, tool: _text, drawing: true),
  ];

  bool get _geometryAllowed =>
      _document.commands.permissions.allows(Capability.geometry);

  /// Spec 05 D5: the one way a tool becomes active. A drawing tool clears
  /// the selection first, because the overlay paints the selection's
  /// outlines and grips under any active tool. It is refused while geometry
  /// is denied. Focus never leaves the canvas (Ruling 05-6).
  void _activate(Tool tool) {
    final drawing = !identical(tool, _select);
    if (drawing && !_geometryAllowed) return;
    if (drawing) _selection.clear();
    _tools.activate(tool);
  }

  /// An idle drawing tool leaves Escape unhandled; it arrives here.
  void _escape() {
    if (!identical(_tools.active, _select)) _activate(_select);
  }
```

  Then:
  - Change `_tools` to `ToolController(initial: _select, context: _context)`.
  - In `bindings`, add the tool shortcuts, then Fill, then Escape:

    ```dart
    for (final e in _entries) SingleActivator(e.logicalKey, includeRepeats: false): () => _activate(e.tool),
    const SingleActivator(LogicalKeyboardKey.keyF, includeRepeats: false): () { if (_geometryAllowed) _fill.value = !_fill.value; },
    const SingleActivator(LogicalKeyboardKey.escape): _escape,
    ```
  - Fill the `chrome-left` container:

    ```dart
    child: ToolPalette(entries: _entries, tools: _tools, fill: _fill, geometryAllowed: _geometryAllowed, onSelect: _activate)
    ```
  - Wrap the right panel in the guard:

    ```dart
    child: ShellShortcutGuard(child: PagePanel(document: _document, page: _page))
    ```
  - Pass `textTool: _text` to `PlannerView`.
  - In `dispose`, after `_tools.dispose()`, dispose all seven tools and
    `_fill`.

  Import `shortcut_guard.dart` and `tool_palette.dart`. Update the class's
  doc comment: "since 05, the tools and the Fill toggle."

- [ ] **Step 8: Run the tests and see them pass.**
  Run: `cd apps/floor_planner && CI=true flutter test`
  Expected: all 26 existing tests and A1–A12 pass, for **38**.

  **If A8's `sendKeyEvent` returns `true` with the guard in place**, then
  `flutter_test`'s dispatch treats `skipRemainingHandlers` differently than
  Ruling 05-9 assumed:
  - Stop. Paste the output. Record it in the ledger.
  - Assert instead that `status` stays `Text` and that the field's
    controller text is unchanged.
  - Keep M-05v's kill on the status assertion.

- [ ] **Step 9: Gate and commit.** Run the `floor_planner` line, including
  both builds.

```bash
git add apps/floor_planner/lib/shortcut_guard.dart apps/floor_planner/lib/tool_palette.dart apps/floor_planner/lib/text_entry_overlay.dart apps/floor_planner/lib/main.dart apps/floor_planner/lib/planner_view.dart apps/floor_planner/test/planner_draw_test.dart
git commit -m "$(cat <<'EOF'
feat(app): the tool palette, shortcuts and the inline text field

A palette in the left panel and the V, L, P, R, C, A, T and F shortcuts
reach the seven tools and Fill through one _activate, which clears the
selection. An idle Escape returns to Select. The text field sits outside
the InteractionLayer, follows the camera without rebuilding, and is
guarded, like the page panel, so the shell's letters and cmd+Z reach a
text field as text. Spec 05 D5, D9, D13; Rulings 05-6 to 05-11.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

