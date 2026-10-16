### Task 4: Tool notices (spec C1.2)

**Files:**
- Modify (`packages/jet_cad_2d_kit/`): `lib/src/kit/plan_tool.dart` (`ToolNotice`)
- Create (`packages/jet_cad_2d_kit/`): `test/kit/tool_notice_test.dart`
- Modify (`packages/jet_cad_2d_plan/`): `lib/src/kits/guard.dart` (`GuardedTool.notice`, its guarded listenable), `lib/src/controller/plan_controller.dart` (`toolNotice`, `textOf`), `lib/src/editor/plan_editor.dart` (the status line); test support `test/support/throwing_kit.dart` (`BoomTool` gains a notice, two hooks)
- Create (`packages/jet_cad_2d_plan/`): `test/support/notice_kit.dart`, `test/kits/guarded_notice_test.dart`, `test/controller/tool_notice_controller_test.dart`, `test/editor/editor_notice_test.dart`
- Modify: `docs/superpowers/specs/2026-10-14-plan-library-design-mode-design.md` (one line in Task 2's `## Amendments`), `docs/superpowers/specs/2026-10-13-kit-contract-design.md` (one line in Task 1's section)

**Interfaces:**
- Consumes:
  - Task 3: `KitText` (`==` by value), `fillText`, the `text:` namespace (validate and host words), `KitWords.text`.
  - Contract today: `PlanTool` (`kit/plan_tool.dart:35-66`), `kitOfKey` (`model/kit_ids.dart:31`).
  - Plan library today: `GuardedTool` (`kits/guard.dart:253-479`; `_getterFailed` `:287-290` reports a kit getter's throw after the frame), `ToolController.active` and its forwarding of the active tool's notifications (`jet_cad_2d_flutter/lib/src/tool.dart`, `_forward`), `PlanController._onTools` (`plan_controller.dart:1978-1980`), `_replace` (`:1571-1576`: the old session's tools arm `plan.select` before its listener goes), `_names` (`:483-485`, host words first), `_locale`, `dispose` (`:2575-2615`), `PlanEditor._statusLine` (`editor/plan_editor.dart:514-519`) and its relay (`:350-351`).
  - Today's composition, the oracle: `jet_cad_floor_plan/lib/src/planner_shell.dart:989-1011` (`line`, then ` — ${selectedCount}` with a selection, then ` — $notice`, the room's notice worded at read time with the current strings, `:1007-1010`).
- Produces (Shared interfaces, exact):

```dart
// jet_cad_2d_kit, lib/src/kit/plan_tool.dart
abstract interface class ToolNotice { ValueListenable<KitText?> get notice; }
// jet_cad_2d_plan
// GuardedTool gains: ValueListenable<KitText?>? get notice;   (guarded; a throw → hookFailed, then null)
// PlanController gains:
ValueListenable<KitText?> get toolNotice;   // the active tool's notice
String textOf(KitText text);                // host words first, then the kit named by the id, current locale
// PlanEditor's status line: label, then ' — ' + selectedCount(n) with a selection,
// then ' — ' + textOf(notice) with a notice.
```

**Appendix A rows closed:** D-27's contract part (the status notices' channel, guard, controller listenable and status line; the room's and the dimension's notices are Tasks 19 and 22). Old test files: none (the composed strings `'Room — Already a room: Room 1'` and `'Dimension — 4.69'` are ported in Tasks 19 and 22 over this line).

Plan decisions:
- **The guard owns one wrapper.** `GuardedTool.notice` reads the inner's `notice` once, the first time it is asked, and keeps a `ValueListenable` wrapper over it (the same object every time, so the controller can tell a change of tool from a re-read). The wrapper reads `value`, `addListener` and `removeListener` under the guard: a throw is reported through the tool's own `_getterFailed` (after the frame, as every getter's), and from then on the wrapper answers null and adds no listener ("a throw is one `hookFailed` diagnostic, then null", spec C1.2). A throwing `notice` getter gives no wrapper: `notice` is null for that tool's life. A generic tool is never a `ToolNotice`; `_getterFailed` keeps rethrowing a generic tool's own error, as today.
- **The controller's listenable.** `toolNotice` is the controller's own `ValueNotifier<KitText?>`, a copy of the active tool's notice: `_onTools` (which runs on every activation, and on the tool controller's forwarded notifications) rebinds it to the active tool's wrapper when the tool changes and copies its value; the wrapper's listener copies each later change. A document swap needs nothing more: `_replace` arms `plan.select` on the old session while `_onTools` still listens (`:1574-1575`), which unbinds the old tool before its products are disposed; `_open` rebinds once at its end. Rebinding allocates nothing when the tool is unchanged.
- **Worded at read time.** `toolNotice` carries the `KitText`, never a string; `PlanEditor` calls `textOf` when it builds the line, and its relay listens to `toolNotice` and `locale`, so a language switch re-words a shown notice at once (Review Focus 2, today's `planner_shell.dart:1007-1010`). `textOf` reads `_names[kit]` (the host's words first, `:483-485`), else the host's words alone for an id of no loaded kit, else the id; it fills the placeholders with `fillText`.
- **No re-export.** `KitText` and `ToolNotice` are the contract's; the plan library does not re-export them (its barrel's export list is pinned by `test/barrel_test.dart`, and a host reads `toolNotice` without naming the type).
- **The test kit.** A new kit `note` (`test/support/notice_kit.dart`): one tool, `note.mark` (letter `N`), a `Tool` that implements `ToolNotice` over its own `ValueNotifier<KitText?>`, which a test sets through `controller.toolFor`; English and Turkish words for its label and its one text. The throwing kit's `BoomTool` gains a notice whose getter checks `notice` and whose `value` checks `noticeValue` (spec C2: the every-hook-throws kit covers the notices); its notice is null unless a test sets it, so no existing status line changes.
- **CHANGELOG:** Task 29.

- [ ] **Step 1: Precondition.** Task 3 is committed. Run `cd packages/jet_cad_2d_plan && flutter test test/kits/guarded_tool_test.dart test/editor/plan_editor_test.dart`. Expected: `All tests passed!`.

- [ ] **Step 2: The contract.** `packages/jet_cad_2d_kit/lib/src/kit/plan_tool.dart`: the imports gain `import 'package:flutter/foundation.dart' show ValueListenable;` (first) and `import '../model/kit_text.dart';` (after the package imports); after `PlanToolSettings`, before `PlanTool`:

```dart
/// A kit's tool that has something to say on the status line (spec 3a
/// C1.2): a word id and its arguments, put into words when the line is read,
/// so a change of language re-words it at once. Null says nothing. The
/// plan library reads it through its guard; a tool that does not implement
/// this has no notice.
abstract interface class ToolNotice {
  ValueListenable<KitText?> get notice;
}
```

  Create `packages/jet_cad_2d_kit/test/kit/tool_notice_test.dart`:

```dart
// Spec 3a C1.2: a kit's Tool may implement ToolNotice, against the barrel
// alone. A premise of the export (exempt from the mutation rule beyond
// M-TN-export: without it this file does not compile); the behaviour is
// the plan library's (its guard, controller and status line).
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

final class Speaking extends Tool implements ToolNotice {
  final ValueNotifier<KitText?> said = ValueNotifier(null);

  @override
  ValueListenable<KitText?> get notice => said;

  @override
  String get name => 'speaking';
  @override
  ToolPhase get phase => ToolPhase.idle;
  @override
  void onPointerDown(ToolPointerEvent e, ToolContext ctx) {}
  @override
  void onPointerMove(ToolPointerEvent e, ToolContext ctx) {}
  @override
  void onPointerUp(ToolPointerEvent e, ToolContext ctx) {}
  @override
  void onPointerExit(ToolContext ctx) {}
  @override
  KeyEventResult onKey(KeyEvent event, ToolContext ctx) =>
      KeyEventResult.ignored;
  @override
  void cancel(ToolContext ctx) {}
  @override
  void paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport,
      PaperPalette paper) {}
}

void main() {
  test('TN-iface a Tool implements ToolNotice with a KitText listenable', () {
    final t = Speaking();
    addTearDown(t.said.dispose);
    final ToolNotice n = t;
    expect(n.notice.value, isNull);
    t.said.value = const KitText('text:test.busy', {'name': 'Slab 1'});
    expect(n.notice.value, const KitText('text:test.busy', {'name': 'Slab 1'}));
  });
}
```

  Run `cd packages/jet_cad_2d_kit && dart format . && flutter test test/kit/tool_notice_test.dart && flutter analyze`. Expected: `All tests passed!`, `No issues found!`. (`KeyEvent`, `KeyEventResult`, `Canvas` and `Size` come with `package:flutter/widgets.dart` (its `keyboard_listener.dart` exports `KeyEvent`), so no `package:flutter/services.dart` import: a second one would be `unnecessary_import`, which fails `flutter analyze`; `ValueListenable` is `package:flutter/foundation.dart`'s alone, as `plan_editor.dart:12-13` imports it.)

- [ ] **Step 3: The plan's test kits.**
  1. Create `packages/jet_cad_2d_plan/test/support/notice_kit.dart`:

```dart
// The notice kit (3a Task 4, spec C1.2): kit "note", one tool, note.mark
// (letter N), that implements ToolNotice over its own notifier, which a
// test sets through controller.toolFor('note.mark'). English and Turkish
// words for its label and its one text.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

const String noteToolId = 'note.mark';

/// "Already marked: {name}".
KitText busy(String name) => KitText('text:note.busy', {'name': name});

final class NoteTool extends Tool implements ToolNotice {
  final ValueNotifier<KitText?> said = ValueNotifier(null);

  @override
  ValueListenable<KitText?> get notice => said;

  @override
  String get name => 'Note';
  @override
  ToolPhase get phase => ToolPhase.idle;
  @override
  void onPointerDown(ToolPointerEvent e, ToolContext ctx) {}
  @override
  void onPointerMove(ToolPointerEvent e, ToolContext ctx) {}
  @override
  void onPointerUp(ToolPointerEvent e, ToolContext ctx) {}
  @override
  void onPointerExit(ToolContext ctx) {}
  @override
  KeyEventResult onKey(KeyEvent event, ToolContext ctx) =>
      KeyEventResult.ignored;
  @override
  void cancel(ToolContext ctx) {}
  @override
  void paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport,
      PaperPalette paper) {}

  @override
  void dispose() {
    said.dispose();
    super.dispose();
  }
}

final PlanKit noteKit = PlanKit(
  id: 'note',
  version: '1.0.0',
  tools: [
    PlanTool(
        id: noteToolId,
        icon: Icons.sticky_note_2,
        letter: 'N',
        create: (_) => NoteTool()),
  ],
  names: const KitNames({
    'en': {
      'tool:note.mark': 'Mark',
      'text:note.busy': 'Already marked: {name}',
    },
    'tr': {
      'tool:note.mark': 'İşaret',
      'text:note.busy': 'Zaten işaretli: {name}',
    },
  }),
);
```

  2. `test/support/throwing_kit.dart`: `boomHooks` gains, after the tool's line `'toolCancel', 'toolPaint', 'toolMidShape', 'toolDispose',`: `// Spec 3a C1.2: the tool's notice getter, then its value.` and `'notice', 'noticeValue',`. `BoomTool` becomes `final class BoomTool extends Tool implements ToolNotice` and gains:

```dart
  /// The notice a test sets; null by default, so no status line changes.
  final ValueNotifier<KitText?> said = ValueNotifier(null);
  late final BoomNotice _notice = BoomNotice(kit, said);

  @override
  ValueListenable<KitText?> get notice {
    kit.check('notice');
    return _notice;
  }
```

     its `dispose` becomes `{ said.dispose(); kit.check('toolDispose'); super.dispose(); }`; the file's imports gain `import 'package:flutter/foundation.dart' show ValueListenable;` before `package:flutter/gestures.dart` (`material.dart` does not export `ValueListenable`); and after the class:

```dart
/// The boom tool's notice: its value checks `noticeValue`.
final class BoomNotice implements ValueListenable<KitText?> {
  BoomNotice(this.kit, this._said);

  final ThrowingKit kit;
  final ValueNotifier<KitText?> _said;

  @override
  KitText? get value {
    kit.check('noticeValue');
    return _said.value;
  }

  @override
  void addListener(VoidCallback listener) => _said.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _said.removeListener(listener);
}
```

     The kit's words gain `'text:boom.alert': 'Alert {n}',`.

- [ ] **Step 4: The failing plan tests.**
  1. Create `packages/jet_cad_2d_plan/test/kits/guarded_notice_test.dart`:

```dart
// Spec 3a C1.2, P4 "The failure boundary": the guard forwards a kit tool's
// notice. A tool that is no ToolNotice has none; a notice getter or value
// that throws is one diagnostic, then null for the tool's life.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/src/kits/guard.dart';

import '../support/notice_kit.dart';
import '../support/throwing_kit.dart';

/// [inner] in the plan's guard, as kit [kitId]'s tool [toolId].
({GuardedTool tool, DiagnosticsLog log}) guarded(Tool inner,
    {String kitId = 'note', String toolId = noteToolId}) {
  final log = DiagnosticsLog();
  final hint = ValueNotifier(false);
  final tool = GuardedTool(
      inner: inner,
      kitId: kitId,
      toolId: toolId,
      log: log,
      lockHint: hint,
      onFailed: () {});
  addTearDown(() {
    tool.dispose();
    hint.dispose();
    log.dispose();
  });
  return (tool: tool, log: log);
}

void main() {
  testWidgets(
      'TN-forward the inner\'s notice, one listenable for the tool\'s life, '
      'telling its listeners; none for a tool that has none (M-TN-forward)',
      (tester) async {
    final note = NoteTool();
    final g = guarded(note);
    // M-TN-forward: `notice` answers null for every tool.
    final notice = g.tool.notice!;
    expect(identical(g.tool.notice, notice), isTrue);
    expect(notice.value, isNull);
    var heard = 0;
    void hear() => heard++;
    notice.addListener(hear);
    note.said.value = busy('Mark 1');
    expect(heard, 1);
    expect(notice.value, busy('Mark 1'));
    notice.removeListener(hear);
    note.said.value = busy('Mark 2');
    expect(heard, 1);
    final plain =
        guarded(BoomTool(ThrowingKit()), kitId: 'boom', toolId: 'boom.tool');
    expect(plain.tool.notice, isNotNull, reason: 'premise: BoomTool speaks');
    final silent = guarded(_Silent(), kitId: 'box', toolId: 'box.stamp');
    expect(silent.tool.notice, isNull);
    await tester.pump();
    expect(g.log.entries.value, isEmpty);
  });

  testWidgets(
      'TN-guard a notice getter that throws: one diagnostic after the frame, '
      'no notice (M-TN-guard-getter)', (tester) async {
    final g = guarded(BoomTool(ThrowingKit(failing: ['notice'])),
        kitId: 'boom', toolId: 'boom.tool');
    expect(g.tool.notice, isNull);
    expect(g.tool.notice, isNull);
    await tester.pump();
    expect([for (final d in g.log.entries.value) (d.subject, d.code)],
        [('boom.tool', KitDiagnosticCode.hookFailed)]);
  });

  testWidgets(
      'TN-guard-value a notice value that throws: one diagnostic, then null '
      'even once it heals (M-TN-guard-value, M-TN-then-null)',
      (tester) async {
    final boom = ThrowingKit(failing: ['noticeValue']);
    final inner = BoomTool(boom);
    final g = guarded(inner, kitId: 'boom', toolId: 'boom.tool');
    final notice = g.tool.notice!;
    inner.said.value = const KitText('text:boom.alert', {'n': 1});
    expect(notice.value, isNull);
    boom.failing.clear();
    // M-TN-then-null: the wrapper reads the healed value again.
    expect(notice.value, isNull);
    await tester.pump();
    expect([for (final d in g.log.entries.value) (d.subject, d.code)],
        [('boom.tool', KitDiagnosticCode.hookFailed)]);
  });
}
```

     `_Silent` is file-local, at the end of the file: `final class _Silent extends Tool` with `NoteTool`'s members (`notice`, `said` and `dispose` left out), and no `implements ToolNotice`. `BoomTool(kit)` is the throwing kit's public constructor (`throwing_kit.dart:441-442`): no services needed.
  2. Create `packages/jet_cad_2d_plan/test/controller/tool_notice_controller_test.dart`:

```dart
// Spec 3a C1.2: PlanController.toolNotice is the active tool's notice, for
// a host composing PlanCanvas and the panels itself; textOf puts a KitText
// into words, the host's first, in the current locale.
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/mark_kit.dart';
import '../support/notice_kit.dart';
import '../support/throwing_kit.dart';

PlanController controller({KitNames words = KitNames.empty}) {
  final c = PlanController(kits: [markKit(), noteKit], words: words);
  addTearDown(c.dispose);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'TN-controller the active tool\'s notice: set, followed, cleared when '
      'another tool is armed, read again when it comes back, gone with a '
      'new plan (M-TN-active, M-TN-copy)', () {
    final c = controller();
    expect(c.toolNotice.value, isNull);
    var heard = 0;
    c.toolNotice.addListener(() => heard++);
    expect(c.selectTool(noteToolId), isTrue);
    final note = c.toolFor(noteToolId)! as NoteTool;
    // M-TN-copy: the wrapper's listener never added.
    note.said.value = busy('Mark 1');
    expect(c.toolNotice.value, busy('Mark 1'));
    expect(heard, 1);
    note.said.value = busy('Mark 2');
    expect(c.toolNotice.value, busy('Mark 2'));
    // M-TN-active: `_onTools` does not rebind.
    expect(c.selectTool('plan.select'), isTrue);
    expect(c.toolNotice.value, isNull);
    note.said.value = busy('Mark 3');
    expect(c.toolNotice.value, isNull, reason: 'not the active tool');
    expect(c.selectTool(noteToolId), isTrue);
    expect(c.toolNotice.value, busy('Mark 3'));
    c.newPlan();
    expect(c.toolNotice.value, isNull);
    expect(c.activeTool.value, 'plan.select');
  });

  test(
      'TN-textOf the host\'s word first, then the kit\'s, in the current '
      'locale, its placeholders filled; an id no one words is itself '
      '(M-TN-textOf-host, M-TN-textOf-locale)', () {
    final c = controller(
        words: const KitNames({
          'tr': {'text:note.busy': 'İşaretli: {name}'},
          'de': {'text:acme.hint': 'Hinweis {n}'},
        }));
    expect(c.textOf(busy('Mark 1')), 'Already marked: Mark 1');
    c.reportLocale(const Locale('tr'));
    // M-TN-textOf-host: the kit's own names only ('Zaten işaretli: Mark 1').
    expect(c.textOf(busy('Mark 1')), 'İşaretli: Mark 1');
    c.reportLocale(const Locale('de'));
    // M-TN-textOf-locale: English always.
    expect(c.textOf(const KitText('text:acme.hint', {'n': 4})), 'Hinweis 4');
    expect(c.textOf(busy('Mark 1')), 'Already marked: Mark 1',
        reason: 'no German: English');
    expect(c.textOf(const KitText('text:acme.none', {'n': 4})),
        'text:acme.none');
    expect(c.textOf(const KitText('text:note.busy')), 'Already marked: {name}');
  });

  testWidgets(
      'TN-boundary a boom tool whose notice getter throws, armed: no notice, '
      'one diagnostic, the plan goes on (M-TN-guard-getter)', (tester) async {
    final boom = ThrowingKit(failing: ['notice']);
    final c = PlanController(kits: [boom.kit]);
    addTearDown(c.dispose);
    expect(c.selectTool('boom.tool'), isTrue);
    expect(c.toolNotice.value, isNull);
    await tester.pump();
    expect([
      for (final d in c.diagnostics.value)
        if (d.code == KitDiagnosticCode.hookFailed) d.subject
    ], ['boom.tool']);
    expect(c.selectTool('plan.select'), isTrue);
  });
}
```

  3. Create `packages/jet_cad_2d_plan/test/editor/editor_notice_test.dart`:

```dart
// Spec 3a C1.2, Review Focus 2 (the plan half): PlanEditor's status line
// keeps today's composition (planner_shell.dart:989-1011): the tool's
// label, then " — n selected" with a selection, then " — <notice>", the
// notice worded when the line is read, so a language switch re-words it at
// once, with no stale English.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/editor_host.dart' show editorPlanJson;
import '../support/mark_kit.dart';
import '../support/notice_kit.dart';

Widget app(PlanController c, Locale locale) => MaterialApp(
    locale: locale,
    supportedLocales: planSupportedLocales,
    localizationsDelegates: planLocalizationsDelegates,
    home: Scaffold(body: PlanEditor(controller: c)));

String status(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('status-text'))).data!;

Future<PlanController> pump(WidgetTester tester) async {
  final c = PlanController(kits: [markKit(), noteKit], json: editorPlanJson());
  addTearDown(c.dispose);
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(app(c, const Locale('en')));
  await tester.pump();
  return c;
}

void main() {
  testWidgets(
      'TN-status the label, the selection, then the notice; no notice, no '
      'dash (M-TN-order)', (tester) async {
    final c = await pump(tester);
    expect(c.selectTool(noteToolId), isTrue);
    await tester.pump();
    expect(status(tester), 'Mark');
    final note = c.toolFor(noteToolId)! as NoteTool;
    note.said.value = busy('Mark 1');
    await tester.pump();
    expect(status(tester), 'Mark — Already marked: Mark 1');
    final marks = c.catalog.objectsOf<MarkCross>(c.document);
    expect(marks, hasLength(2), reason: 'premise: the fixture\'s marks');
    c.selection.replace([for (final h in marks) SelectionKey.root(h)]);
    await tester.pump();
    // M-TN-order: the notice before the selection.
    expect(status(tester), 'Mark — 2 selected — Already marked: Mark 1');
    note.said.value = null;
    await tester.pump();
    expect(status(tester), 'Mark — 2 selected');
  });

  testWidgets(
      'TN-relocale (Review Focus 2) a language switch re-words a shown '
      'notice at once, in the new language, with its name; and back '
      '(M-TN-relocale)', (tester) async {
    final c = await pump(tester);
    expect(c.selectTool(noteToolId), isTrue);
    (c.toolFor(noteToolId)! as NoteTool).said.value = busy('Mark 1');
    await tester.pump();
    expect(status(tester), 'Mark — Already marked: Mark 1');
    await tester.pumpWidget(app(c, const Locale('tr')));
    await tester.pump();
    // M-TN-relocale: the editor words the notice once and keeps the text.
    expect(status(tester), 'İşaret — Zaten işaretli: Mark 1');
    await tester.pumpWidget(app(c, const Locale('en')));
    await tester.pump();
    expect(status(tester), 'Mark — Already marked: Mark 1');
  });
}
```

  `c.selection` and `c.toolFor` are `@internal`, used by tests of the same package; `c.catalog` is public. If `PlanEditor` needs a host callback for its default bar in this test, pass the ones `editor_words_test.dart:40` passes (`onExport: (_) {}`).

  Run `cd packages/jet_cad_2d_plan && flutter test test/kits/guarded_notice_test.dart test/controller/tool_notice_controller_test.dart test/editor/editor_notice_test.dart`. Expected: compilation fails (`The getter 'notice' isn't defined for the type 'GuardedTool'`, `toolNotice`, `textOf`).

- [ ] **Step 5: The guard.** `packages/jet_cad_2d_plan/lib/src/kits/guard.dart`, in `GuardedTool` (`:253-479`) after `selectionPreviewTransform` (`:382-390`, the last guarded getter):

```dart
  bool _noticeRead = false;
  _GuardedNotice? _notice;

  /// The inner tool's notice when it is a [ToolNotice] (spec 3a C1.2),
  /// through the guard: read once, then the same listenable for the tool's
  /// life. A throwing `notice` getter is one diagnostic and no notice; a
  /// throwing value or listener is one diagnostic, then null.
  ValueListenable<KitText?>? get notice {
    if (!_noticeRead) {
      _noticeRead = true;
      final inner = this.inner;
      if (inner is ToolNotice) {
        try {
          _notice = _GuardedNotice(this, (inner as ToolNotice).notice);
        } catch (e, s) {
          _getterFailed(e, s);
        }
      }
    }
    return _notice;
  }
```

  and after the `GuardedTool` class (after `:479`, before `GuardedGrips`):

```dart
/// A kit tool's notice read at the boundary (spec 3a C1.2): what it throws
/// is its tool's getter failure (one diagnostic after the frame), and from
/// then on it answers null and holds no listener.
final class _GuardedNotice implements ValueListenable<KitText?> {
  _GuardedNotice(this._tool, this._inner);

  final GuardedTool _tool;
  final ValueListenable<KitText?> _inner;
  bool _failed = false;

  void _fail(Object error, StackTrace stack) {
    _failed = true;
    _tool._getterFailed(error, stack);
  }

  @override
  KitText? get value {
    if (_failed) return null;
    try {
      return _inner.value;
    } catch (e, s) {
      _fail(e, s);
      return null;
    }
  }

  @override
  void addListener(VoidCallback listener) {
    if (_failed) return;
    try {
      _inner.addListener(listener);
    } catch (e, s) {
      _fail(e, s);
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    try {
      _inner.removeListener(listener);
    } catch (e, s) {
      _fail(e, s);
    }
  }
}
```

  The imports gain `import 'package:flutter/foundation.dart' show ValueListenable;` before `package:flutter/scheduler.dart` (`:9`): `package:flutter/widgets.dart` exports `VoidCallback` and `ValueNotifier` but not `ValueListenable`. (`ToolNotice` and `KitText` come with the kit barrel. `inner is ToolNotice` on a local: the field is public, so it does not promote; the cast is the promotion.)

- [ ] **Step 6: The controller.** `packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart` (the line numbers are at `c6bcce3e`; Task 3 adds two lines at `:355-359`, so each place below is two lines lower: find it by the code quoted):
  1. Fields, beside `_activeTool` (`:552`):

```dart
  /// The active tool's notice, copied from its guarded listenable (spec 3a
  /// C1.2), and the listenable it is copied from now.
  final ValueNotifier<KitText?> _toolNotice = ValueNotifier(null);
  ValueListenable<KitText?>? _noticeSource;
```

  2. After `activeTool` (`:1976`):

```dart
  /// The active tool's notice (spec 3a C1.2), null when it has none: a
  /// word id and its arguments, for [textOf] when the line is read.
  ValueListenable<KitText?> get toolNotice => _toolNotice;

  /// [text] in words (spec 3a C1.2, C1.6): the host's word first, then the
  /// kit's the id names, in the current locale, else English; the id itself
  /// when no one words it; its placeholders filled.
  String textOf(KitText text) {
    final id = text.id;
    final names = _names[kitOfKey(id.substring(id.indexOf(':') + 1))] ??
        _hostWords;
    return fillText(
        names.word(_locale.value.languageCode, id) ?? id, text.args);
  }

  /// Follows the active tool's notice: rebinds when the tool changed,
  /// then copies its value.
  void _rebindNotice() {
    final active = _session.tools.active;
    final next = active is GuardedTool ? active.notice : null;
    if (!identical(next, _noticeSource)) {
      _noticeSource?.removeListener(_copyNotice);
      _noticeSource = next;
      next?.addListener(_copyNotice);
    }
    _copyNotice();
  }

  void _copyNotice() => _toolNotice.value = _noticeSource?.value;
```

  3. `_onTools` (`:1978-1980`) gains `_rebindNotice();` after its line. `_open` gains `_rebindNotice();` as its last statement (after `_reportUnofferedKinds();`).
  4. `dispose`: before `session.tools.removeListener(_onTools);` add `_noticeSource?.removeListener(_copyNotice);` and `_noticeSource = null;`; after `_activeTool.dispose();` add `_toolNotice.dispose();`.

  If `KitNames.word` (`model/kit_names.dart:35`) does not fall back to English, `textOf`'s `'Already marked: Mark 1'` under German would fail: check it and report (it does today, `:35-38`).

- [ ] **Step 7: The status line.** `packages/jet_cad_2d_plan/lib/src/editor/plan_editor.dart`:
  1. The relay (`:350-351`): `Listenable.merge([c.selection, c.toolController, c.activeTool])` → `Listenable.merge([c.selection, c.toolController, c.activeTool, c.toolNotice, c.locale])`.
  2. `_statusLine` (`:514-519`):

```dart
  /// The active tool's label, the selection's size when it is not empty,
  /// and the tool's notice when it has one (today's composition,
  /// planner_shell.dart:989-1011; spec 3a C1.2), the notice worded now, in
  /// the current language.
  String _statusLine(PlanStrings strings) {
    final c = widget.controller;
    final base = planToolLabel(context, c, c.activeTool.value);
    final n = c.selection.length;
    final line = n == 0 ? base : '$base — ${strings.selectedCount(n)}';
    final notice = c.toolNotice.value;
    return notice == null ? line : '$line — ${c.textOf(notice)}';
  }
```

  Run `cd packages/jet_cad_2d_plan && dart format . && flutter analyze && flutter test test/kits/ test/controller/ test/editor/`. Expected: `No issues found!`, `All tests passed!`.

- [ ] **Step 8: The amendment lines.**
  1. `docs/superpowers/specs/2026-10-14-plan-library-design-mode-design.md`, the `## Amendments` section Task 2 made, a second bullet:

```markdown
- **P2, the status line and tool notices** (3a C1.2): a kit's `Tool` may
  implement `ToolNotice` (a `ValueListenable<KitText?>`); the guard
  forwards it (`GuardedTool.notice`; a throw is one `hookFailed`, then
  null); `PlanController.toolNotice` is the active tool's notice and
  `textOf` puts a `KitText` into words (the host's first, then the kit's,
  in the current locale). `PlanEditor`'s status line is the tool's label,
  then ` — n selected` with a selection, then ` — <notice>`, worded when
  it is read, so a language switch re-words it at once.
```

  2. `docs/superpowers/specs/2026-10-13-kit-contract-design.md`, Task 1's section, one more bullet:

```markdown
- **Tool notices** (3a C1.2): the surface gains `ToolNotice`, a kit tool's
  `ValueListenable<KitText?> notice`, which the plan library reads through
  its guard and shows on the status line.
```

- [ ] **Step 9: The gates.** From the repository root:
  - `cd packages/jet_cad_2d_kit && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — `All tests passed!`, `No issues found!`, exit 0.
  - `cd packages/jet_cad_2d_plan && flutter test --enable-vmservice && flutter analyze && dart format --output=none --set-exit-if-changed .` — the same (the paint-allocation invariant included: `_onTools` now rebinds, which allocates nothing while the tool is unchanged).
  - `dart run tool/ci/check_kit_deps.dart` — exit 0.
  - `grep -n "İşaret\|işaretli\|İşaretli" packages/jet_cad_2d_plan/test/support/notice_kit.dart packages/jet_cad_2d_plan/test/controller/tool_notice_controller_test.dart packages/jet_cad_2d_plan/test/editor/editor_notice_test.dart` and `grep -n " — " packages/jet_cad_2d_plan/lib/src/editor/plan_editor.dart packages/jet_cad_2d_plan/test/editor/editor_notice_test.dart`: the Turkish letters and the em dash are characters, as in today's `planner_shell.dart:1004-1011`.
  - `git status --short`: only this task's files.

- [ ] **Step 10: Commit.**

```bash
git add packages/jet_cad_2d_kit/lib/src/kit/plan_tool.dart packages/jet_cad_2d_kit/test/kit/tool_notice_test.dart packages/jet_cad_2d_plan/lib/src/kits/guard.dart packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart packages/jet_cad_2d_plan/lib/src/editor/plan_editor.dart packages/jet_cad_2d_plan/test/support/notice_kit.dart packages/jet_cad_2d_plan/test/support/throwing_kit.dart packages/jet_cad_2d_plan/test/kits/guarded_notice_test.dart packages/jet_cad_2d_plan/test/controller/tool_notice_controller_test.dart packages/jet_cad_2d_plan/test/editor/editor_notice_test.dart docs/superpowers/specs/2026-10-14-plan-library-design-mode-design.md docs/superpowers/specs/2026-10-13-kit-contract-design.md
git commit -m "$(cat <<'EOF'
feat(plan): tool notices on the status line (spec 3a C1.2)

A kit's tool may implement ToolNotice, a listenable KitText. The guard
forwards it, a throw being one diagnostic and then no notice; the
controller's toolNotice follows the active tool, and textOf words a
KitText with the host's words first. PlanEditor's status line keeps
today's composition, label, selection, then the notice, worded when the
line is read so a language switch re-words it at once.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 11: Mutation check** (committed files only; after each: run the named test, see it red, then `git checkout -- <file>` and `git diff --quiet -- <file>` must exit 0). Plan tests run with `cd packages/jet_cad_2d_plan && flutter test <file>`.
  - M-TN-export `jet_cad_2d_kit/lib/src/kit/plan_tool.dart`: rename `ToolNotice` to `ToolNotices` (the declaration only) → `jet_cad_2d_kit/test/kit/tool_notice_test.dart` fails to compile.
  - M-TN-forward `jet_cad_2d_plan/lib/src/kits/guard.dart`: the `notice` getter's body → `return null;` (keep the fields) → `test/kits/guarded_notice_test.dart` TN-forward red, and `test/controller/tool_notice_controller_test.dart` TN-controller red.
  - M-TN-guard-getter `guard.dart`: in `notice`, replace the `try { ... } catch (e, s) { _getterFailed(e, s); }` by its body alone → TN-guard and TN-boundary red (the `BoomFailure` escapes).
  - M-TN-guard-value `guard.dart`: `_GuardedNotice.value` → `=> _inner.value;` → TN-guard-value red.
  - M-TN-then-null `guard.dart`: delete `if (_failed) return null;` from `value` → TN-guard-value red (the healed value comes back).
  - M-TN-active `jet_cad_2d_plan/lib/src/controller/plan_controller.dart`: delete `_rebindNotice();` from `_onTools` → TN-controller red.
  - M-TN-copy `plan_controller.dart`: in `_rebindNotice`, delete `next?.addListener(_copyNotice);` → TN-controller red (`busy('Mark 1')` set after arming is not seen).
  - M-TN-textOf-host `plan_controller.dart`: in `textOf`, `_names[...] ?? _hostWords` → `kits.kitOf(kitOfKey(id.substring(id.indexOf(':') + 1)))?.names ?? _hostWords` → TN-textOf red.
  - M-TN-textOf-locale `plan_controller.dart`: `_locale.value.languageCode` → `'en'` → TN-textOf red.
  - M-TN-order `jet_cad_2d_plan/lib/src/editor/plan_editor.dart`: compose the notice before the selection (`final head = notice == null ? base : '$base — ${c.textOf(notice)}'; return n == 0 ? head : '$head — ${strings.selectedCount(n)}';`) → `test/editor/editor_notice_test.dart` TN-status red.
  - M-TN-relocale `plan_editor.dart`: add a field `String? _noticeText;` to the state and return `'$line — ${_noticeText ??= c.textOf(notice)}'` → TN-relocale red (the English notice stays after the switch).

  Quote each red line.

---

