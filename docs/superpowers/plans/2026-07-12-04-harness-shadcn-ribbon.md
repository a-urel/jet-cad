# Harness shadcn Ribbon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle `apps/dev_harness` with the `shadcn_ui` Flutter port and add an Office/Fusion-style tabbed CAD ribbon (mostly decorative) above the live `JetCadViewport`, keeping the four working actions (Add box, Undo, Redo, Fit).

**Architecture:** Split the single-file harness into bounded units — a data model describing the ribbon, a pure presentational `CadRibbon` widget rendered from that model, a `StatusBar`, and a `HarnessPage` that owns the live session (`CadDocument`/`ViewportController`) and wires callbacks into the ribbon. The app is wrapped in `ShadApp` with a dark theme. Decorative tools (model `onPressed == null`) show a "not implemented" toast on tap.

**Tech Stack:** Flutter 3.44 (Dart ^3.5.0), `shadcn_ui` ^0.55.0 (`ShadApp`, `ShadTabs`, `ShadCard`, `ShadButton`, `ShadToaster`, `LucideIcons`), `package:jet_cad` (local path).

## Global Constraints

- Changes are confined to `apps/dev_harness/`. Do NOT modify `packages/jet_cad/`.
- Public-package-API only: the harness imports `package:jet_cad/jet_cad.dart`. Never import `package:jet_cad/src/...`. (If you think you need to, the package surface is wrong — stop and flag it.)
- `shadcn_ui` resolves to **0.55.0**. This version has **no** `ShadApp.material` / `ShadApp.cupertino` factory — only `ShadApp`, `ShadApp.router`, `ShadApp.custom`. Do not reference `ShadApp.material`.
- Live actions preserve today's exact semantics: Box → `doc.makeBox(const Vec3(40, 30, 20))` then `controller.fitAll()`; Undo → `doc.undo`; Redo → `doc.redo`; Fit → `controller.fitAll`.
- Icons come from `LucideIcons` (re-exported by `shadcn_ui`). Only use the names listed in this plan — they are verified present in `lucide_icons_flutter` 3.1.15.
- Dart formatting: run `dart format` on changed files before each commit.
- `ShadApp` auto-injects `ShadToaster` + `ShadSonner`, so `ShadToaster.of(context)` is valid anywhere under the app (including widget tests that wrap the widget in `ShadApp`).

---

## File Structure

- `apps/dev_harness/pubspec.yaml` — add `shadcn_ui` dependency + `flutter_test` dev dependency. (Modify)
- `apps/dev_harness/lib/ribbon/ribbon_model.dart` — `RibbonTool` / `RibbonGroup` / `RibbonTab` data types. (Create)
- `apps/dev_harness/lib/ribbon/cad_ribbon.dart` — `CadRibbon` presentational widget. (Create)
- `apps/dev_harness/lib/status_bar.dart` — `StatusBar` bottom bar. (Create)
- `apps/dev_harness/lib/harness_page.dart` — `HarnessPage`: owns session lifecycle + builds the ribbon model with live callbacks. (Create; logic moved from today's `main.dart`)
- `apps/dev_harness/lib/main.dart` — `runApp(ShadApp(...))` dark shell + boot. (Rewrite)
- `apps/dev_harness/test/ribbon_model_test.dart` — model unit test. (Create)
- `apps/dev_harness/test/cad_ribbon_test.dart` — ribbon widget test. (Create)
- `apps/dev_harness/test/status_bar_test.dart` — status bar widget test. (Create)

---

## Task 1: Dependencies

**Files:**
- Modify: `apps/dev_harness/pubspec.yaml`

**Interfaces:**
- Consumes: nothing.
- Produces: `package:shadcn_ui/shadcn_ui.dart` and `package:flutter_test/flutter_test.dart` available to all later tasks.

- [ ] **Step 1: Add the runtime dependency**

Run (resolves the latest 0.55.x compatible with Flutter 3.44):

```bash
flutter pub add shadcn_ui -C apps/dev_harness
```

- [ ] **Step 2: Add the test dev-dependency**

Run:

```bash
flutter pub add dev:flutter_test -C apps/dev_harness
```

- [ ] **Step 3: Verify the resolved pubspec**

Run:

```bash
grep -E 'shadcn_ui|flutter_test' apps/dev_harness/pubspec.yaml
```

Expected: a `shadcn_ui: ^0.55.0` line under `dependencies:` and a `flutter_test:` line (with `sdk: flutter`) under `dev_dependencies:`.

- [ ] **Step 4: Sanity-resolve**

Run:

```bash
flutter pub get -C apps/dev_harness
```

Expected: `Got dependencies!` with no version-solve error.

- [ ] **Step 5: Commit**

```bash
git add apps/dev_harness/pubspec.yaml
git commit -m "chore(harness): add shadcn_ui and flutter_test deps"
```

Note: `pubspec.lock` is gitignored in this workspace — do not attempt to add it.

---

## Task 2: Ribbon data model

**Files:**
- Create: `apps/dev_harness/lib/ribbon/ribbon_model.dart`
- Test: `apps/dev_harness/test/ribbon_model_test.dart`

**Interfaces:**
- Consumes: `IconData` from `package:flutter/widgets.dart`.
- Produces:
  - `typedef RibbonAction = void Function();`
  - `class RibbonTool { const RibbonTool(this.label, this.icon, {this.onPressed}); final String label; final IconData icon; final RibbonAction? onPressed; bool get isDecorative => onPressed == null; }`
  - `class RibbonGroup { const RibbonGroup(this.title, this.tools); final String title; final List<RibbonTool> tools; }`
  - `class RibbonTab { const RibbonTab(this.title, this.groups); final String title; final List<RibbonGroup> groups; }`

- [ ] **Step 1: Write the failing test**

Create `apps/dev_harness/test/ribbon_model_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_dev_harness/ribbon/ribbon_model.dart';

void main() {
  test('a tool with no callback is decorative', () {
    const decorative = RibbonTool('Extrude', IconData(0xe000));
    expect(decorative.isDecorative, isTrue);
    expect(decorative.onPressed, isNull);
  });

  test('a tool with a callback is live', () {
    var fired = false;
    final live = RibbonTool('Box', const IconData(0xe001), onPressed: () => fired = true);
    expect(live.isDecorative, isFalse);
    live.onPressed!();
    expect(fired, isTrue);
  });

  test('tabs nest groups and tools', () {
    const tab = RibbonTab('Model', [
      RibbonGroup('Primitives', [RibbonTool('Box', IconData(0xe001))]),
    ]);
    expect(tab.title, 'Model');
    expect(tab.groups.single.title, 'Primitives');
    expect(tab.groups.single.tools.single.label, 'Box');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ribbon_model_test.dart -C apps/dev_harness`
Expected: FAIL — `Target of URI doesn't exist: 'package:jet_cad_dev_harness/ribbon/ribbon_model.dart'`.

- [ ] **Step 3: Write minimal implementation**

Create `apps/dev_harness/lib/ribbon/ribbon_model.dart`:

```dart
import 'package:flutter/widgets.dart' show IconData;

/// A no-argument action bound to a ribbon tool.
typedef RibbonAction = void Function();

/// One button in the ribbon. A tool with a null [onPressed] is decorative
/// (not implemented yet) — the ribbon shows a toast when it is tapped.
class RibbonTool {
  const RibbonTool(this.label, this.icon, {this.onPressed});

  final String label;
  final IconData icon;
  final RibbonAction? onPressed;

  bool get isDecorative => onPressed == null;
}

/// A titled cluster of related tools within a tab.
class RibbonGroup {
  const RibbonGroup(this.title, this.tools);

  final String title;
  final List<RibbonTool> tools;
}

/// A top-level ribbon tab (File, Sketch, Model, …).
class RibbonTab {
  const RibbonTab(this.title, this.groups);

  final String title;
  final List<RibbonGroup> groups;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ribbon_model_test.dart -C apps/dev_harness`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
dart format apps/dev_harness/lib/ribbon/ribbon_model.dart apps/dev_harness/test/ribbon_model_test.dart
git add apps/dev_harness/lib/ribbon/ribbon_model.dart apps/dev_harness/test/ribbon_model_test.dart
git commit -m "feat(harness): ribbon data model"
```

---

## Task 3: CadRibbon widget

**Files:**
- Create: `apps/dev_harness/lib/ribbon/cad_ribbon.dart`
- Test: `apps/dev_harness/test/cad_ribbon_test.dart`

**Interfaces:**
- Consumes: `RibbonTab`, `RibbonTool` from `ribbon_model.dart`; `ShadApp`, `ShadTabs`, `ShadTab`, `ShadCard`, `ShadButton`, `ShadToaster`, `ShadToast`, `LucideIcons` from `shadcn_ui`.
- Produces:
  - `class CadRibbon extends StatefulWidget` with constructor
    `const CadRibbon({super.key, required this.tabs, this.quickActions = const [], this.onDecorative});`
    where `final List<RibbonTab> tabs; final List<RibbonTool> quickActions; final void Function(String toolLabel)? onDecorative;`
  - When a decorative tool is tapped: if `onDecorative` is non-null it is called with the tool's label; otherwise a toast is shown. (The injectable callback keeps the widget test free of toast-overlay timing.)

- [ ] **Step 1: Write the failing test**

Create `apps/dev_harness/test/cad_ribbon_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:jet_cad_dev_harness/ribbon/ribbon_model.dart';
import 'package:jet_cad_dev_harness/ribbon/cad_ribbon.dart';

void main() {
  Widget host(Widget child) => ShadApp(
        theme: ShadThemeData(
          colorScheme: const ShadZincColorScheme.dark(),
          brightness: Brightness.dark,
        ),
        home: child,
      );

  testWidgets('renders tab titles and quick actions', (tester) async {
    await tester.pumpWidget(host(const CadRibbon(
      tabs: [
        RibbonTab('Model', [
          RibbonGroup('Primitives', [RibbonTool('Box', LucideIcons.box)]),
        ]),
        RibbonTab('View', []),
      ],
      quickActions: [RibbonTool('Undo', LucideIcons.undo2)],
    )));
    await tester.pumpAndSettle();

    expect(find.text('Model'), findsOneWidget);
    expect(find.text('View'), findsOneWidget);
    expect(find.text('Primitives'), findsOneWidget);
    expect(find.text('Box'), findsWidgets); // label in the tool button
  });

  testWidgets('tapping a live tool fires its callback', (tester) async {
    var boxTaps = 0;
    await tester.pumpWidget(host(CadRibbon(
      tabs: [
        RibbonTab('Model', [
          RibbonGroup('Primitives', [
            RibbonTool('Box', LucideIcons.box, onPressed: () => boxTaps++),
          ]),
        ]),
      ],
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Box'));
    await tester.pump();
    expect(boxTaps, 1);
  });

  testWidgets('tapping a decorative tool routes to onDecorative', (tester) async {
    String? decorative;
    await tester.pumpWidget(host(CadRibbon(
      tabs: [
        RibbonTab('Model', [
          RibbonGroup('Features', [const RibbonTool('Extrude', LucideIcons.layers)]),
        ]),
      ],
      onDecorative: (label) => decorative = label,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Extrude'));
    await tester.pump();
    expect(decorative, 'Extrude');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/cad_ribbon_test.dart -C apps/dev_harness`
Expected: FAIL — `Target of URI doesn't exist: '.../cad_ribbon.dart'`.

- [ ] **Step 3: Write minimal implementation**

Create `apps/dev_harness/lib/ribbon/cad_ribbon.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'ribbon_model.dart';

/// Presentational CAD ribbon: a persistent quick-access strip (live actions)
/// above a [ShadTabs] bar whose selected tab shows titled groups of tools.
///
/// Live tools carry a [RibbonTool.onPressed]; decorative tools do not — tapping
/// one calls [onDecorative] if provided, else shows a "not implemented" toast.
class CadRibbon extends StatefulWidget {
  const CadRibbon({
    super.key,
    required this.tabs,
    this.quickActions = const [],
    this.onDecorative,
  });

  final List<RibbonTab> tabs;
  final List<RibbonTool> quickActions;
  final void Function(String toolLabel)? onDecorative;

  @override
  State<CadRibbon> createState() => _CadRibbonState();
}

class _CadRibbonState extends State<CadRibbon> {
  late String _selected = widget.tabs.isEmpty ? '' : widget.tabs.first.title;

  void _handle(BuildContext context, RibbonTool tool) {
    final onPressed = tool.onPressed;
    if (onPressed != null) {
      onPressed();
      return;
    }
    final onDecorative = widget.onDecorative;
    if (onDecorative != null) {
      onDecorative(tool.label);
      return;
    }
    ShadToaster.of(context).show(
      ShadToast(
        title: Text('🚧 ${tool.label}'),
        description: const Text('Not implemented yet'),
      ),
    );
  }

  Widget _toolButton(BuildContext context, RibbonTool tool) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: ShadButton.ghost(
        onPressed: () => _handle(context, tool),
        child: SizedBox(
          width: 56,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(tool.icon, size: 18),
              const SizedBox(height: 4),
              Text(
                tool.label,
                style: const TextStyle(fontSize: 11),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _group(BuildContext context, RibbonGroup group) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ShadCard(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [for (final t in group.tools) _toolButton(context, t)],
            ),
            const SizedBox(height: 4),
            Text(group.title, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _tabContent(BuildContext context, RibbonTab tab) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [for (final g in tab.groups) _group(context, g)],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.quickActions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final a in widget.quickActions)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ShadButton.ghost(
                      onPressed: () => _handle(context, a),
                      leading: Icon(a.icon, size: 16),
                      child: Text(a.label),
                    ),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: ShadTabs<String>(
            value: _selected,
            onChanged: (v) => setState(() => _selected = v),
            tabs: [
              for (final tab in widget.tabs)
                ShadTab<String>(
                  value: tab.title,
                  content: _tabContent(context, tab),
                  child: Text(tab.title),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/cad_ribbon_test.dart -C apps/dev_harness`
Expected: PASS (3 tests). If a `ShadTabs` assertion complains that both `value` and `controller` are set, ensure only `value` is passed (as above).

- [ ] **Step 5: Commit**

```bash
dart format apps/dev_harness/lib/ribbon/cad_ribbon.dart apps/dev_harness/test/cad_ribbon_test.dart
git add apps/dev_harness/lib/ribbon/cad_ribbon.dart apps/dev_harness/test/cad_ribbon_test.dart
git commit -m "feat(harness): CadRibbon tabbed toolbar widget"
```

---

## Task 4: StatusBar widget

**Files:**
- Create: `apps/dev_harness/lib/status_bar.dart`
- Test: `apps/dev_harness/test/status_bar_test.dart`

**Interfaces:**
- Consumes: `ShadApp`, `ShadThemeData`, `ShadZincColorScheme`, `ShadBadge`, `ShadTheme` from `shadcn_ui`.
- Produces:
  - `class StatusBar extends StatelessWidget` with constructor
    `const StatusBar({super.key, required this.status, required this.selection});`
    where `final String status; final List<int> selection;`
  - Renders the status string on the left and a selection summary on the right (`—` when empty, else comma-joined ids).

- [ ] **Step 1: Write the failing test**

Create `apps/dev_harness/test/status_bar_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:jet_cad_dev_harness/status_bar.dart';

void main() {
  Widget host(Widget child) => ShadApp(
        theme: ShadThemeData(
          colorScheme: const ShadZincColorScheme.dark(),
          brightness: Brightness.dark,
        ),
        home: child,
      );

  testWidgets('shows status and empty-selection placeholder', (tester) async {
    await tester.pumpWidget(host(const StatusBar(status: 'ready', selection: [])));
    await tester.pumpAndSettle();
    expect(find.text('ready'), findsOneWidget);
    expect(find.textContaining('—'), findsOneWidget);
  });

  testWidgets('joins selection ids', (tester) async {
    await tester.pumpWidget(host(const StatusBar(status: 'ready', selection: [12, 13])));
    await tester.pumpAndSettle();
    expect(find.textContaining('12, 13'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/status_bar_test.dart -C apps/dev_harness`
Expected: FAIL — `Target of URI doesn't exist: '.../status_bar.dart'`.

- [ ] **Step 3: Write minimal implementation**

Create `apps/dev_harness/lib/status_bar.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Bottom status strip: current harness status on the left, current selection
/// summary on the right.
class StatusBar extends StatelessWidget {
  const StatusBar({super.key, required this.status, required this.selection});

  final String status;
  final List<int> selection;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final ids = selection.isEmpty ? '—' : selection.join(', ');
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        border: Border(top: BorderSide(color: theme.colorScheme.border)),
      ),
      child: Row(
        children: [
          Text(status, style: theme.textTheme.small),
          const Spacer(),
          Text('selection: $ids', style: theme.textTheme.muted),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/status_bar_test.dart -C apps/dev_harness`
Expected: PASS (2 tests). If `theme.textTheme.small`/`muted` or `colorScheme.card`/`border` are not valid members in 0.55.0, replace with `const TextStyle(fontSize: 12)` and `theme.colorScheme.background` respectively (confirm names against `ShadTextTheme` / `ShadColorScheme` in the resolved package).

- [ ] **Step 5: Commit**

```bash
dart format apps/dev_harness/lib/status_bar.dart apps/dev_harness/test/status_bar_test.dart
git add apps/dev_harness/lib/status_bar.dart apps/dev_harness/test/status_bar_test.dart
git commit -m "feat(harness): status bar widget"
```

---

## Task 5: HarnessPage + main.dart integration

This task wires the live session into the ribbon and status bar and swaps `MaterialApp` for `ShadApp`. It has no unit test (booting requires the native `.dylib`); it is verified by `flutter analyze`, a compile via `flutter build macos --debug`, and a manual run.

**Files:**
- Create: `apps/dev_harness/lib/harness_page.dart`
- Rewrite: `apps/dev_harness/lib/main.dart`

**Interfaces:**
- Consumes: `CadRibbon`, `RibbonTab`/`RibbonGroup`/`RibbonTool` (Tasks 2–3); `StatusBar` (Task 4); `CadDocument`, `ViewportController`, `FfiKernelBridge`, `TextureTarget`, `JetCadViewport`, `Vec3`, `EntityId` from `package:jet_cad/jet_cad.dart`; `ShadApp`, `ShadThemeData`, `ShadZincColorScheme`, `ShadCard`, `ShadTheme`, `LucideIcons` from `shadcn_ui`.
- Produces: `class HarnessPage extends StatefulWidget`; `void main()`.

- [ ] **Step 1: Create `HarnessPage`**

Create `apps/dev_harness/lib/harness_page.dart`. The session lifecycle (`_start`, `dispose`, `_guard`) is moved verbatim from today's `main.dart`; only the `build` UI changes.

```dart
import 'package:flutter/widgets.dart';
import 'package:jet_cad/jet_cad.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'ribbon/cad_ribbon.dart';
import 'ribbon/ribbon_model.dart';
import 'status_bar.dart';

/// Dev harness page: owns the live [CadDocument] / [ViewportController] session
/// and renders the shadcn ribbon + viewport + status bar.
///
/// Public package API only — if something here needs an import from
/// package:jet_cad/src/..., the package surface is wrong.
class HarnessPage extends StatefulWidget {
  const HarnessPage({super.key});

  @override
  State<HarnessPage> createState() => _HarnessPageState();
}

class _HarnessPageState extends State<HarnessPage> {
  CadDocument? _doc;
  ViewportController? _controller;
  String _status = 'starting…';
  Set<EntityId> _selection = const {};

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final libPath = FfiKernelBridge.locateLibrary();
      if (libPath == null) {
        setState(() => _status =
            'native lib not found — run packages/jet_cad/tool/run_harness.sh');
        return;
      }
      final bridge = FfiKernelBridge(libPath);
      final doc =
          await CadDocument.create(bridge, target: const TextureTarget());
      final controller = ViewportController(document: doc);
      controller.selectionChanges
          .listen((event) => setState(() => _selection = event.selection));
      setState(() {
        _doc = doc;
        _controller = controller;
        _status = 'ready';
      });
    } catch (e) {
      setState(() => _status = 'FAILED: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _doc?.dispose();
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
      setState(() => _status = 'ready');
    } catch (e) {
      setState(() => _status = '$e');
    }
  }

  List<RibbonTool> _quickActions(CadDocument doc, ViewportController controller) {
    return [
      RibbonTool('Undo', LucideIcons.undo2, onPressed: () => _guard(doc.undo)),
      RibbonTool('Redo', LucideIcons.redo2, onPressed: () => _guard(doc.redo)),
      RibbonTool('Fit', LucideIcons.maximize,
          onPressed: () => _guard(controller.fitAll)),
    ];
  }

  List<RibbonTab> _tabs(CadDocument doc, ViewportController controller) {
    void addBox() => _guard(() async {
          await doc.makeBox(const Vec3(40, 30, 20));
          await controller.fitAll();
        });
    return [
      const RibbonTab('File', [
        RibbonGroup('Document', [
          RibbonTool('New', LucideIcons.file),
          RibbonTool('Open', LucideIcons.folderOpen),
          RibbonTool('Save', LucideIcons.save),
          RibbonTool('Export', LucideIcons.fileOutput),
        ]),
      ]),
      const RibbonTab('Sketch', [
        RibbonGroup('Draw', [
          RibbonTool('Line', LucideIcons.minus),
          RibbonTool('Rect', LucideIcons.square),
          RibbonTool('Circle', LucideIcons.circle),
          RibbonTool('Arc', LucideIcons.spline),
          RibbonTool('Polygon', LucideIcons.triangle),
        ]),
      ]),
      RibbonTab('Model', [
        RibbonGroup('Primitives', [
          RibbonTool('Box', LucideIcons.box, onPressed: addBox),
          const RibbonTool('Cylinder', LucideIcons.cylinder),
          const RibbonTool('Sphere', LucideIcons.circle),
          const RibbonTool('Cone', LucideIcons.cone),
        ]),
        const RibbonGroup('Features', [
          RibbonTool('Extrude', LucideIcons.layers),
          RibbonTool('Revolve', LucideIcons.rotate3d),
          RibbonTool('Fillet', LucideIcons.spline),
          RibbonTool('Chamfer', LucideIcons.triangle),
          RibbonTool('Shell', LucideIcons.copy),
        ]),
        const RibbonGroup('Boolean', [
          RibbonTool('Union', LucideIcons.plus),
          RibbonTool('Subtract', LucideIcons.minus),
          RibbonTool('Intersect', LucideIcons.copy),
        ]),
      ]),
      const RibbonTab('Modify', [
        RibbonGroup('Transform', [
          RibbonTool('Move', LucideIcons.move),
          RibbonTool('Rotate', LucideIcons.rotate3d),
          RibbonTool('Scale', LucideIcons.scale3d),
          RibbonTool('Mirror', LucideIcons.copy),
        ]),
      ]),
      RibbonTab('View', [
        RibbonGroup('Camera', [
          RibbonTool('Fit', LucideIcons.maximize,
              onPressed: () => _guard(controller.fitAll)),
          const RibbonTool('Isometric', LucideIcons.box),
          const RibbonTool('Front', LucideIcons.square),
          const RibbonTool('Top', LucideIcons.grid3x3),
          const RibbonTool('Wireframe', LucideIcons.grid3x3),
        ]),
      ]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final doc = _doc;
    final controller = _controller;

    final Widget body;
    if (doc == null || controller == null) {
      body = Center(
        child: ShadCard(
          width: 360,
          padding: const EdgeInsets.all(16),
          child: Text(_status, textAlign: TextAlign.center),
        ),
      );
    } else {
      body = Column(
        children: [
          CadRibbon(
            tabs: _tabs(doc, controller),
            quickActions: _quickActions(doc, controller),
          ),
          Expanded(child: JetCadViewport(controller: controller)),
          StatusBar(
            status: _status,
            selection: _selection.map((e) => e.value).toList(),
          ),
        ],
      );
    }

    return ColoredBox(
      color: theme.colorScheme.background,
      child: SafeArea(child: body),
    );
  }
}
```

Note on `EntityId`: `_selection` is a `Set<EntityId>`; the `.value` accessor mirrors today's `main.dart` (`e.value`). If `EntityId.value` is not an `int`, adjust `StatusBar.selection` to the correct element type and the `.map` accordingly — but today's harness already treats `e.value` as printable, so `List<int>` via `e.value` matches existing behavior.

- [ ] **Step 2: Rewrite `main.dart`**

Replace the entire contents of `apps/dev_harness/lib/main.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'harness_page.dart';

void main() {
  runApp(
    ShadApp(
      theme: ShadThemeData(
        colorScheme: const ShadZincColorScheme.dark(),
        brightness: Brightness.dark,
      ),
      home: const HarnessPage(),
    ),
  );
}
```

- [ ] **Step 3: Analyze**

Run: `flutter analyze` (from repo root, or `flutter analyze -C apps/dev_harness`).
Expected: `No issues found!`. Fix any analyzer errors — most likely candidates and their fixes:
  - `ShadZincColorScheme.dark` / member typos → confirm against `~/.pub-cache/hosted/pub.dev/shadcn_ui-0.55.0/lib/src/theme/color_scheme/zinc.dart`.
  - `ShadCard`/`ShadTheme` member mismatches → confirm against the resolved package source.

- [ ] **Step 4: Compile check**

Run: `flutter build macos --debug -C apps/dev_harness`
Expected: build succeeds (the native `.dylib` is `dlopen`ed at runtime, not linked at build time, so this compiles the Dart + runner without it).

- [ ] **Step 5: Run the full test suite**

Run: `flutter test -C apps/dev_harness`
Expected: all tests from Tasks 2–4 PASS.

- [ ] **Step 6: Manual verification**

Run: `bash packages/jet_cad/tool/run_harness.sh`
Confirm by observation:
  - Dark shadcn-styled window with the tabbed ribbon at the top (File / Sketch / Model / View / Modify), Model tab selected.
  - Quick-access Undo / Redo / Fit strip above the tabs.
  - Clicking **Box** (Model → Primitives) adds a box and fits it in the live viewport; status bar reads `ready`.
  - Undo / Redo / Fit work; selecting geometry updates the status bar's `selection:` field.
  - Clicking any decorative tool (e.g. Extrude) shows a `🚧 … Not implemented yet` toast.

- [ ] **Step 7: Commit**

```bash
dart format apps/dev_harness/lib/harness_page.dart apps/dev_harness/lib/main.dart
git add apps/dev_harness/lib/harness_page.dart apps/dev_harness/lib/main.dart
git commit -m "feat(harness): shadcn ShadApp shell + ribbon-wired HarnessPage"
```

---

## Self-Review

**Spec coverage** (against `docs/superpowers/specs/2026-07-12-harness-shadcn-ribbon-design.md`):
- Architecture split (main/harness_page/ribbon_model/cad_ribbon/status_bar) → Tasks 2–5. ✔
- Ribbon data model with null-callback = decorative → Task 2. ✔
- Tabbed ribbon layout, quick-access strip, group boxes, tab inventory → Tasks 3, 5. ✔
- Live wiring (Box/Undo/Redo/Fit + selection stream) preserved → Task 5. ✔
- Booting/failed state ShadCard → Task 5. ✔
- Decorative-tap toast → Task 3. ✔
- ShadApp dark (Zinc) theming → Tasks 3–5. ✔
- shadcn_ui dependency + testing → Tasks 1–4. ✔
- Non-goals (no real ops, no package API change) → enforced by Global Constraints. ✔

**Spec deviation (intentional):** The spec's fallback "switch to `ShadApp.material`" is invalid in the resolved 0.55.0 (no such factory). The plan documents this in Global Constraints; if a Material ancestor is ever needed, wrap the specific subtree in a `Material` widget instead. No Material widgets are used, so this is not expected to arise.

**Placeholder scan:** No TBD/TODO; every code step contains complete code; every command has an expected result.

**Type consistency:** `RibbonTool`/`RibbonGroup`/`RibbonTab` signatures identical across Tasks 2, 3, 5. `CadRibbon` constructor identical in Task 3 impl and Task 5 usage (`tabs:`, `quickActions:`, `onDecorative:` optional). `StatusBar(status:, selection:)` identical in Task 4 and Task 5. `ShadTabs<String>` uses `value` + `onChanged` (not `controller`) consistently.
