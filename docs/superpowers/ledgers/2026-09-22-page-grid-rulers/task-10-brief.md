### Task 10: `PagePanel`

**Files:**
- Create: `lib/page_panel.dart`
- Modify: `lib/main.dart` (the right slot)
- Test: `test/page_panel_test.dart`

- [ ] **Step 1: Write the failing tests.**

```dart
// test/page_panel_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:floor_planner/page_panel.dart';

void main() {
  (DraftDocument, PageNotifier) docWithPage() {
    final doc = DraftDocument.empty();
    PageComponent.register(doc.components);
    doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle, PageComponent(originX: 7350, originY: -1230)));
    doc.commands.clearHistory();
    return (doc, PageNotifier(doc));
  }

  Future<void> pump(WidgetTester tester, DraftDocument doc, PageNotifier page) =>
      tester.pumpWidget(MaterialApp(
          home: Scaffold(body: SizedBox(width: 280, child: PagePanel(document: doc, page: page)))));

  PageComponent pageOf(DraftDocument doc) =>
      doc.components.get<PageComponent>(doc.rootHandle)!;

  testWidgets('each toggle is exactly one command, and undo reverts the control',
      (tester) async {
    // M-04o.
    final (doc, page) = docWithPage();
    addTearDown(page.dispose);
    await pump(tester, doc, page);
    for (final (key, read) in [
      ('page-grid', (PageComponent p) => p.gridVisible),
      ('page-snap', (PageComponent p) => p.snapToGrid),
      ('page-breaks', (PageComponent p) => p.pageBreaks),
    ]) {
      final before = read(pageOf(doc));
      final depth = doc.commands.undoDepth;
      await tester.tap(find.byKey(Key(key)));
      await tester.pump();
      expect(read(pageOf(doc)), !before, reason: key);
      expect(doc.commands.undoDepth, depth + 1, reason: key);
      doc.commands.undo();
      await tester.pump();
      expect(read(pageOf(doc)), before);
      expect(tester.widget<CheckboxListTile>(find.byKey(Key(key))).value, before);
    }
  });

  testWidgets('preset, orientation, unit and swatch each issue one command',
      (tester) async {
    final (doc, page) = docWithPage();
    addTearDown(page.dispose);
    await pump(tester, doc, page);

    await tester.tap(find.byKey(const Key('page-preset')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Letter').last);
    await tester.pumpAndSettle();
    expect(pageOf(doc).preset, SheetSize.letter);
    expect(doc.commands.undoDepth, 1);

    await tester.tap(find.byKey(const Key('page-orientation-portrait')));
    await tester.pump();
    expect(pageOf(doc).orientation, PageOrientation.portrait);
    expect(doc.commands.undoDepth, 2);

    await tester.tap(find.byKey(const Key('page-unit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ft-in').last);
    await tester.pumpAndSettle();
    expect(pageOf(doc).displayUnit, DisplayUnit.feetInches);
    expect(doc.commands.undoDepth, 3);

    await tester.tap(find.byKey(const Key('page-swatch-3')));
    await tester.pump();
    expect(pageOf(doc).background, 0xFF1F3A5F);
    expect(doc.commands.undoDepth, 4);
  });

  testWidgets('the scale field commits on submit, refuses junk', (tester) async {
    final (doc, page) = docWithPage();
    addTearDown(page.dispose);
    await pump(tester, doc, page);
    await tester.enterText(find.byKey(const Key('page-scale')), '100');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(pageOf(doc).scaleDenominator, 100);
    expect(doc.commands.undoDepth, 1);
    await tester.enterText(find.byKey(const Key('page-scale')), '-3');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(pageOf(doc).scaleDenominator, 100);
    expect(doc.commands.undoDepth, 1);
  });

  testWidgets('a custom size shows Custom', (tester) async {
    final (doc, page) = docWithPage();
    addTearDown(page.dispose);
    doc.commands.execute(SetComponentCommand<PageComponent>(doc.rootHandle,
        PageComponent(widthMm: 200, heightMm: 300)));
    await tester.pump();
    await pump(tester, doc, page);
    expect(find.text('Custom'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to fail.**

- [ ] **Step 3: Implement.**

```dart
// lib/page_panel.dart
import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

/// The smallest panel that lets a human change the page (spec D12). Every
/// control executes one `SetComponentCommand`; the panel rebuilds from the
/// notifier, so undo moves the controls back. 12 replaces this.
class PagePanel extends StatefulWidget {
  const PagePanel({super.key, required this.document, required this.page});

  final DraftDocument document;
  final PageNotifier page;

  @override
  State<PagePanel> createState() => _PagePanelState();
}

class _PagePanelState extends State<PagePanel> {
  final TextEditingController _scale = TextEditingController();

  static const List<(String, int)> _swatches = [
    ('White', 0xFFFFFFFF),
    ('Ivory', 0xFFFAF6EC),
    ('Grey', 0xFFEDEDED),
    ('Blueprint', 0xFF1F3A5F),
  ];

  @override
  void initState() {
    super.initState();
    _syncScale();
    widget.page.addListener(_syncScale);
  }

  @override
  void dispose() {
    widget.page.removeListener(_syncScale);
    _scale.dispose();
    super.dispose();
  }

  void _syncScale() {
    final page = widget.page.value;
    if (page == null) return;
    final text = _number(page.scaleDenominator);
    if (_scale.text != text) _scale.text = text;
  }

  static String _number(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();

  void _set(PageComponent next) => widget.document.commands.execute(
      SetComponentCommand<PageComponent>(widget.document.rootHandle, next));

  void _submitScale(PageComponent page, String text) {
    final value = double.tryParse(text.trim());
    if (value == null || !value.isFinite || value <= 0) {
      _syncScale();
      return;
    }
    if (value != page.scaleDenominator) _set(page.copyWith(scaleDenominator: value));
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<PageComponent?>(
        valueListenable: widget.page,
        builder: (context, page, _) {
          if (page == null) return const SizedBox.shrink();
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              const Text('Page', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButton<SheetSize?>(
                key: const Key('page-preset'),
                isExpanded: true,
                value: page.preset,
                items: [
                  for (final s in SheetSize.presets)
                    DropdownMenuItem(value: s, child: Text(s.name)),
                  if (page.preset == null)
                    const DropdownMenuItem<SheetSize?>(
                        value: null, enabled: false, child: Text('Custom')),
                ],
                onChanged: (s) {
                  if (s != null) _set(page.copyWith(widthMm: s.widthMm, heightMm: s.heightMm));
                },
              ),
              const SizedBox(height: 8),
              SegmentedButton<PageOrientation>(
                segments: const [
                  ButtonSegment(
                      value: PageOrientation.portrait,
                      label: Text('Portrait', key: Key('page-orientation-portrait'))),
                  ButtonSegment(
                      value: PageOrientation.landscape,
                      label: Text('Landscape', key: Key('page-orientation-landscape'))),
                ],
                selected: {page.orientation},
                onSelectionChanged: (s) => _set(page.copyWith(orientation: s.single)),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('page-scale'),
                controller: _scale,
                decoration: const InputDecoration(prefixText: '1:', labelText: 'Scale'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onSubmitted: (text) => _submitScale(page, text),
              ),
              const SizedBox(height: 8),
              DropdownButton<DisplayUnit>(
                key: const Key('page-unit'),
                isExpanded: true,
                value: page.displayUnit,
                items: const [
                  DropdownMenuItem(value: DisplayUnit.millimeters, child: Text('mm')),
                  DropdownMenuItem(value: DisplayUnit.centimeters, child: Text('cm')),
                  DropdownMenuItem(value: DisplayUnit.meters, child: Text('m')),
                  DropdownMenuItem(value: DisplayUnit.inches, child: Text('in')),
                  DropdownMenuItem(value: DisplayUnit.feetInches, child: Text('ft-in')),
                ],
                onChanged: (u) {
                  if (u != null) _set(page.copyWith(displayUnit: u));
                },
              ),
              CheckboxListTile(
                key: const Key('page-grid'),
                title: const Text('Grid'),
                value: page.gridVisible,
                onChanged: (v) => _set(page.copyWith(gridVisible: v)),
              ),
              CheckboxListTile(
                key: const Key('page-snap'),
                title: const Text('Snap to grid'),
                value: page.snapToGrid,
                onChanged: (v) => _set(page.copyWith(snapToGrid: v)),
              ),
              CheckboxListTile(
                key: const Key('page-breaks'),
                title: const Text('Page breaks'),
                value: page.pageBreaks,
                onChanged: (v) => _set(page.copyWith(pageBreaks: v)),
              ),
              const SizedBox(height: 8),
              const Text('Paper'),
              Row(
                children: [
                  for (var i = 0; i < _swatches.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        key: Key('page-swatch-$i'),
                        onTap: () => _set(page.copyWith(background: _swatches[i].$2)),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Color(_swatches[i].$2),
                            border: Border.all(
                                color: page.background == _swatches[i].$2
                                    ? Colors.blue
                                    : Colors.black26,
                                width: page.background == _swatches[i].$2 ? 2 : 1),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      );
}
```

In `main.dart`, the `chrome-right` container gets `child:
PagePanel(document: _document, page: _page)`.

- [ ] **Step 4: Run to pass**, then the full `floor_planner` line with
  both builds. The `SegmentedButton` label keys: if `find.byKey` cannot tap
  the label, put the key on the `ButtonSegment`'s `icon` instead, or tap
  `find.text('Portrait')`; keep the assertion.
- [ ] **Step 5: Commit** — `feat(app): PagePanel — one command per
  control`.

---

