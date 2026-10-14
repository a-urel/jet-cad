// Spec 2a P2, "The keyboard": the generic letters, then the kits' in load
// order, F reserved, a taken letter a diagnostic (A3); the guard built
// from the letters in use; shortcuts: false; Escape; Undo and Redo under
// the permissions; the host's file callbacks; autofocus. Over the drawing
// fixture (a 1:20 page at (7000, 3000), one line, a rotated, zoomed camera)
// with the stamp kits (stamp_kit.dart).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer, SelectionKey;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/shortcuts/plan_shortcut_guard.dart';
import 'package:jet_cad_2d_plan/src/shortcuts/tool_letters.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/canvas_fixture.dart';
import '../support/fake_page_printer.dart';
import '../support/design_harness.dart';
import '../support/stamp_kit.dart';
import '../support/unit_editor_fixture.dart'
    show editorCamera, kEditorSurface, unitEditorPlanJson;
import '../support/unit_fixtures.dart' show entryOf, fxKit, tableSymbol;

/// The host's keys, by name.
const Map<String, SingleActivator> kHostKeys = {
  'l': SingleActivator(LogicalKeyboardKey.keyL),
  'b': SingleActivator(LogicalKeyboardKey.keyB),
  'f': SingleActivator(LogicalKeyboardKey.keyF),
  'f3': SingleActivator(LogicalKeyboardKey.f3),
  'escape': SingleActivator(LogicalKeyboardKey.escape),
  'delete': SingleActivator(LogicalKeyboardKey.delete),
  'ctrl+z': SingleActivator(LogicalKeyboardKey.keyZ, control: true),
  'ctrl+y': SingleActivator(LogicalKeyboardKey.keyY, control: true),
  'ctrl+n': SingleActivator(LogicalKeyboardKey.keyN, control: true),
  'ctrl+s': SingleActivator(LogicalKeyboardKey.keyS, control: true),
  'ctrl+e': SingleActivator(LogicalKeyboardKey.keyE, control: true),
  'ctrl+p': SingleActivator(LogicalKeyboardKey.keyP, control: true),
};

/// One more line on [c]'s plan, off the fixture's, one undo step.
void drawALine(PlanController c) => c.document.commands.execute(addDrafted(
    c.document,
    EntityKind.line,
    linePayload(Vector2(7020.5, 3030.25), Vector2(7080.5, 3061.75)),
    layer: ReservedHandles.layerZero));

// ---- the units-only key cases (2b Task 10 fix round) ----
//
// Ported from jet_cad_floor_plan/test/host/keyboard_focus_test.dart: T6-c
// (:467-493), RP1's tablesOnly variant (:854-885) and RP12 (:886-909),
// `tablesOnly` being `PlanPermissions.unitsOnly` and the view `PlanEditor`
// over the unit editor fixture.

/// An intent the host's own `Shortcuts` maps a key to, by name.
class HostIntent extends Intent {
  const HostIntent(this.name);
  final String name;
}

/// Every letter the shell binds, F3, Escape, Delete, Backspace and the
/// chords (Task 6 review RP1).
final Map<String, SingleActivator> kIntentKeys = {
  for (final l in 'VLPRBWDNGMSICATF'.split(''))
    l: SingleActivator(LogicalKeyboardKey(
        LogicalKeyboardKey.keyA.keyId + l.codeUnitAt(0) - 'A'.codeUnitAt(0))),
  'f3': const SingleActivator(LogicalKeyboardKey.f3),
  'escape': const SingleActivator(LogicalKeyboardKey.escape),
  'delete': const SingleActivator(LogicalKeyboardKey.delete),
  'backspace': const SingleActivator(LogicalKeyboardKey.backspace),
  'ctrl+z': const SingleActivator(LogicalKeyboardKey.keyZ, control: true),
  'cmd+z': const SingleActivator(LogicalKeyboardKey.keyZ, meta: true),
  'ctrl+shift+z': const SingleActivator(LogicalKeyboardKey.keyZ,
      control: true, shift: true),
  'ctrl+y': const SingleActivator(LogicalKeyboardKey.keyY, control: true),
  'ctrl+e': const SingleActivator(LogicalKeyboardKey.keyE, control: true),
  'cmd+e': const SingleActivator(LogicalKeyboardKey.keyE, meta: true),
  'ctrl+p': const SingleActivator(LogicalKeyboardKey.keyP, control: true),
  'cmd+p': const SingleActivator(LogicalKeyboardKey.keyP, meta: true),
};

/// The editor over the unit fixture under [permissions], inside a host
/// that counts every [kIntentKeys] key reaching it, through intents
/// ([intents]) or `CallbackShortcuts`; `shortcuts` changeable at runtime.
Future<(PlanController, Map<String, int>, ValueNotifier<bool>)> mountUnitKeys(
    WidgetTester tester,
    {required PlanPermissions permissions,
    bool intents = true,
    bool shortcuts = false}) async {
  final c = PlanController(kits: [fxKit()], json: unitEditorPlanJson());
  addTearDown(c.dispose);
  c.permissions = permissions;
  final keys = ValueNotifier(shortcuts);
  addTearDown(keys.dispose);
  final reached = <String, int>{for (final n in kIntentKeys.keys) n: 0};
  void count(String name) => reached[name] = reached[name]! + 1;
  await tester.binding.setSurfaceSize(kEditorSurface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final editor = ValueListenableBuilder<bool>(
      valueListenable: keys,
      builder: (_, s, __) => PlanEditor(
          controller: c,
          onExport: (_) {},
          onExportDialog: (_, __, ___) async => null,
          printer: FakePagePrinter(),
          shortcuts: s));
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: intents
              ? Shortcuts(
                  shortcuts: {
                      for (final e in kIntentKeys.entries)
                        e.value: HostIntent(e.key),
                    },
                  child: Actions(actions: {
                    HostIntent: CallbackAction<HostIntent>(onInvoke: (x) {
                      count(x.name);
                      return null;
                    }),
                  }, child: Focus(child: editor)))
              : CallbackShortcuts(bindings: {
                  for (final e in kIntentKeys.entries)
                    e.value: () => count(e.key),
                }, child: editor))));
  await tester.pump();
  await tester.pump();
  c.camera.value = editorCamera();
  await tester.pump();
  return (c, reached, keys);
}

bool canvasFocused() {
  final context = FocusManager.instance.primaryFocus?.context;
  return context != null &&
      context.findAncestorWidgetOfExactType<InteractionLayer>() != null;
}

String encodedPlan(PlanController c) =>
    DraftDocumentCodec.encodeToString(c.document);

void main() {
  testWidgets(
      'KB-1 the generic letters, then the kits\' in load order; a taken '
      'letter, F and a later kit\'s B go to no tool, each a letterTaken '
      'diagnostic at construction (M-KB-1a, M-KB-1b, M-KB-1c)', (tester) async {
    final c = PlanController(kits: [stampKit, lateKit]);
    addTearDown(c.dispose);
    // Before any widget is built.
    expect({
      for (final d in c.diagnostics.value)
        if (d.code == KitDiagnosticCode.letterTaken) d.subject
    }, {
      'stamp.clash',
      'stamp.fill',
      'late.star'
    });
    final entries = planToolEntries(c);
    expect([
      for (final e in entries) e.id
    ], [
      'plan.select',
      'plan.line',
      'plan.polyline',
      'plan.rectangle',
      'plan.circle',
      'plan.arc',
      'plan.text',
      'stamp.star',
      'stamp.clash',
      'stamp.fill',
      'stamp.none',
      'late.star',
    ]);
    expect([for (final e in entries) e.letter],
        ['V', 'L', 'P', 'R', 'C', 'A', 'T', 'B', null, null, null, null]);
    expect(planLetterKeys(c), [
      for (final l in 'VLPRCATB'.split('')) letterKey(l),
      LogicalKeyboardKey.keyF,
    ]);
    expect(identical(planToolEntries(c), entries), isTrue,
        reason: 'once per controller');
  });

  testWidgets(
      'KB-2 a kit\'s letter typed into a guarded field reaches the text input '
      'and arms nothing; on the canvas it arms the kit\'s tool (M-KB-2)',
      (tester) async {
    final c = PlanController(kits: [stampKit]);
    addTearDown(c.dispose);
    await pumpDesign(tester, c, hostField: true);
    await tester.tap(find.byKey(const Key('host-field')));
    await tester.pump();
    expect(await press(tester, LogicalKeyboardKey.keyB), isFalse,
        reason: 'B goes to the platform as text');
    expect(c.activeTool.value, 'plan.select');
    await focusCanvas(tester);
    expect(await press(tester, LogicalKeyboardKey.keyB), isTrue);
    expect(c.activeTool.value, 'stamp.star');
    expect(status(tester), 'Star');
  });

  testWidgets(
      'KB-3 shortcuts: false, the canvas focused: a letter, F3, F, Escape, '
      'Delete, Undo and the file chords reach the host; the tool, OSNAP, '
      'Fill, the selection and the history are kept. With shortcuts the '
      'plan takes each (M-KB-3a, M-KB-3b)', (tester) async {
    final f = drawController();
    final c = f.c;
    final d =
        await pumpDesign(tester, c, shortcuts: false, hostKeys: kHostKeys);
    await focusCanvas(tester);
    drawALine(c);
    c.selection.replace([SelectionKey.root(f.line)]);
    await tester.pump();
    final before = bytes(c);
    final osnap = c.snap.objectSnap;
    final fill = c.fill.value;
    const sent = ['l', 'f3', 'f', 'escape', 'delete', 'ctrl+z', 'ctrl+s'];
    for (final k in sent) {
      await sendActivator(tester, kHostKeys[k]!);
      expect(d.reached[k], 1, reason: k);
    }
    expect(bytes(c), before, reason: 'nothing deleted, nothing undone');
    expect(c.activeTool.value, 'plan.select');
    expect(c.snap.objectSnap, osnap);
    expect(c.fill.value, fill);
    expect(c.selection.keys, [SelectionKey.root(f.line)],
        reason: 'the idle Escape bubbled');
    expect(d.saves, 0);

    // The control: the plan binds them all.
    d.shortcuts.value = true;
    await tester.pump();
    await sendActivator(tester, kHostKeys['f3']!);
    expect(c.snap.objectSnap, isNot(osnap));
    await sendActivator(tester, kHostKeys['f']!);
    expect(c.fill.value, isNot(fill));
    await sendActivator(tester, kHostKeys['ctrl+z']!);
    expect(bytes(c), isNot(before), reason: 'undone');
    await sendActivator(tester, kHostKeys['ctrl+s']!);
    expect(d.saves, 1);
    await sendActivator(tester, kHostKeys['l']!);
    expect(c.activeTool.value, 'plan.line');
    await sendActivator(tester, kHostKeys['escape']!);
    expect(c.activeTool.value, 'plan.select');
    for (final k in sent) {
      expect(d.reached[k], 1, reason: '$k: the host heard nothing more');
    }
  });

  testWidgets(
      'KB-4 an idle drawing tool\'s Escape arms plan.select; part-way, the '
      'Escape is the tool\'s and a host\'s undo() waits (M-KB-4)',
      (tester) async {
    final c = drawController().c;
    await pumpDesign(tester, c);
    await focusCanvas(tester);
    drawALine(c);
    final depth = c.document.commands.undoDepth;
    await press(tester, LogicalKeyboardKey.keyP);
    await tester.tapAt(globalOf(tester, c, 7010, 3020));
    await tester.tapAt(globalOf(tester, c, 7060, 3090));
    await tester.pump();
    expect(activeTool(c).isMidShape, isTrue, reason: 'premise: part-way');
    c.undo();
    expect(c.document.commands.undoDepth, depth, reason: 'mid-shape: no undo');
    await press(tester, LogicalKeyboardKey.escape);
    expect(activeTool(c).isMidShape, isFalse, reason: 'the shape dropped');
    expect(c.activeTool.value, 'plan.polyline', reason: 'the tool stays');
    await press(tester, LogicalKeyboardKey.escape);
    expect(c.activeTool.value, 'plan.select');
    c.undo();
    expect(c.document.commands.undoDepth, depth - 1, reason: 'idle: undo acts');
  });

  testWidgets(
      'KB-5 undo: false unbinds Undo and Redo: the chord reaches the host and '
      'the step stays; a host\'s undo() still undoes; undo: true binds them '
      'again (M-KB-5)', (tester) async {
    final c = drawController().c;
    final d = await pumpDesign(tester, c, hostKeys: kHostKeys);
    await focusCanvas(tester);
    drawALine(c);
    final depth = c.document.commands.undoDepth;
    c.permissions = PlanPermissions.full.copyWith(undo: false);
    await tester.pump();
    await sendActivator(tester, kHostKeys['ctrl+z']!);
    expect(d.reached['ctrl+z'], 1);
    expect(c.document.commands.undoDepth, depth);
    c.undo();
    expect(c.document.commands.undoDepth, depth - 1,
        reason: 'host calls are not gated (spec P2)');
    c.redo();
    c.permissions = PlanPermissions.full;
    await tester.pump();
    await sendActivator(tester, kHostKeys['ctrl+z']!);
    expect(c.document.commands.undoDepth, depth - 1);
    await sendActivator(tester, kHostKeys['ctrl+y']!);
    expect(c.document.commands.undoDepth, depth);
    expect(d.reached['ctrl+z'], 1);
    expect(d.reached['ctrl+y'], 0);
  });

  testWidgets(
      'KB-6 the file chords call the host\'s callbacks; Export and Print are '
      'refused with no page but keep their key; export: false lets Ctrl+E '
      'reach the host (M-KB-6a, M-KB-6b)', (tester) async {
    final c = drawController().c;
    final d = await pumpDesign(tester, c, hostKeys: kHostKeys);
    await focusCanvas(tester);
    for (final k in ['ctrl+n', 'ctrl+s', 'ctrl+e', 'ctrl+p']) {
      await sendActivator(tester, kHostKeys[k]!);
    }
    await sendActivator(
        tester, const SingleActivator(LogicalKeyboardKey.keyO, control: true));
    await sendActivator(
        tester,
        const SingleActivator(LogicalKeyboardKey.keyS,
            control: true, shift: true));
    expect([d.news, d.opens, d.saves, d.saveAses, d.exports, d.prints],
        [1, 1, 1, 1, 1, 1]);
    expect(d.reached['ctrl+e'], 0);

    // No page: the commands cannot act, their keys stay the plan's (S-26).
    c.document.commands.execute(
        SetComponentCommand<PageComponent>(c.document.rootHandle, null));
    await tester.pump();
    expect(c.page.value, isNull, reason: 'premise: no page');
    await sendActivator(tester, kHostKeys['ctrl+e']!);
    await sendActivator(tester, kHostKeys['ctrl+p']!);
    expect([d.exports, d.prints], [1, 1]);
    expect([d.reached['ctrl+e'], d.reached['ctrl+p']], [0, 0]);

    c.permissions = PlanPermissions.full.copyWith(export: false);
    await tester.pump();
    await sendActivator(tester, kHostKeys['ctrl+e']!);
    expect(d.reached['ctrl+e'], 1);
    expect(d.reached['ctrl+p'], 0);
  });

  testWidgets(
      'KB-10 autofocus: with it the canvas takes the focus from a host field '
      'mounted in the same frame; without it the field keeps it and a click '
      'on the canvas takes it (T6-a) (M-KB-10)', (tester) async {
    final c = drawController().c;
    Future<FocusNode> sameFrame({required bool autofocus}) async {
      final field = FocusNode(debugLabel: 'host-field');
      addTearDown(field.dispose);
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Column(children: [
        Expanded(child: PlanCanvas(controller: c, autofocus: autofocus)),
        SizedBox(
            height: 48,
            child: TextField(
                key: const Key('host-field'),
                onTapOutside: (_) {},
                focusNode: field,
                autofocus: true)),
      ]))));
      await tester.pump();
      await tester.pump();
      return field;
    }

    final control = await sameFrame(autofocus: true);
    expect(FocusManager.instance.primaryFocus, isNot(same(control)),
        reason: 'the control: the canvas');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    final field = await sameFrame(autofocus: false);
    expect(FocusManager.instance.primaryFocus, same(field));
    await focusCanvas(tester);
  });

  testWidgets(
      'KB-12 PlanShortcuts alone pushes the app\'s locale into its '
      'controller, as every widget of the plan library does (M-KB-12)',
      (tester) async {
    final c = PlanController(kits: [stampKit]);
    addTearDown(c.dispose);
    expect(c.locale.value, const Locale('en'), reason: 'premise');
    await tester.pumpWidget(MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: const [Locale('en'), Locale('tr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: PlanShortcuts(controller: c, child: const SizedBox())));
    await tester.pump();
    await tester.pump();
    expect(c.locale.value, const Locale('tr'));
  });

  testWidgets(
      'KB-13 under PlanCanvas(snapping: false) F3 reaches the host and the '
      'user\'s snap setting is kept; snapping: true at runtime binds F3 '
      'again (S-14) (M-KB-13a, M-KB-13b, M-KB-13c)', (tester) async {
    final c = drawController().c;
    final d = await pumpDesign(tester, c, snapping: false, hostKeys: kHostKeys);
    await focusCanvas(tester);
    final osnap = c.snap.objectSnap;
    expect(c.snappingAllowed, isFalse, reason: 'premise: the canvas wrote it');
    await sendActivator(tester, kHostKeys['f3']!);
    expect(d.reached['f3'], 1);
    expect(c.snap.objectSnap, osnap, reason: 'the hidden setting kept');

    // The control: snapping allowed again, the plan takes F3.
    d.snapping.value = true;
    await tester.pump();
    await tester.pump();
    await sendActivator(tester, kHostKeys['f3']!);
    expect(c.snap.objectSnap, isNot(osnap));
    expect(d.reached['f3'], 1, reason: 'the host heard nothing more');
  });

  testWidgets(
      'KB-14 (final review) shortcuts: false closes the select tool\'s idle '
      'keys only while it speaks for the controller: a swapped-out '
      'controller and a removed PlanShortcuts get them back', (tester) async {
    final one = PlanController(kits: const []);
    addTearDown(one.dispose);
    final two = PlanController(kits: const []);
    addTearDown(two.dispose);
    Widget keys(PlanController c) => MaterialApp(
        home: PlanShortcuts(
            controller: c, shortcuts: false, child: const SizedBox()));
    await tester.pumpWidget(keys(one));
    expect(one.selectGates.idleKeys, isFalse, reason: 'premise');
    await tester.pumpWidget(keys(two));
    // M-KB-14a: didUpdateWidget not giving the old controller its keys
    // back.
    expect(one.selectGates.idleKeys, isTrue);
    expect(two.selectGates.idleKeys, isFalse);
    await tester.pumpWidget(const SizedBox());
    // M-KB-14b: dispose not giving them back: Delete and Escape stay dead
    // in the canvas.
    expect(two.selectGates.idleKeys, isTrue);
  });

  testWidgets(
      'T6-c unitsOnly, 1 selected: Delete and Backspace remove nothing '
      "and reach the host's bindings; with shortcuts: Delete removes 1",
      (tester) async {
    final (c, reached, keys) = await mountUnitKeys(tester,
        permissions: PlanPermissions.unitsOnly, intents: false);
    await focusCanvas(tester);
    c.select({'1'});
    await tester.pump();
    final before = encodedPlan(c);
    await press(tester, LogicalKeyboardKey.delete);
    await press(tester, LogicalKeyboardKey.backspace);
    expect(encodedPlan(c), before);
    expect(reached['delete'], 1);
    expect(reached['backspace'], 1);
    keys.value = true;
    await tester.pump();
    await press(tester, LogicalKeyboardKey.delete);
    expect(c.unitIndex.withLabel('1'), isEmpty);
    expect(reached['delete'], 1);
  });

  testWidgets(
      'RP1 design, unitsOnly, shortcuts: false: every letter, F3, Escape, '
      'Delete, Backspace and every chord reach an intent-based host; '
      'nothing in the plan changes. With shortcuts the plan takes the file '
      'chords', (tester) async {
    final (c, reached, keys) =
        await mountUnitKeys(tester, permissions: PlanPermissions.unitsOnly);
    await focusCanvas(tester);
    c.select({'1'});
    await tester.pump();
    final before = encodedPlan(c);
    for (final e in kIntentKeys.entries) {
      await sendActivator(tester, e.value);
      await tester.pump();
      expect(reached[e.key], 1, reason: e.key);
      expect(canvasFocused(), isTrue, reason: '${e.key}: focus kept');
    }
    await tester.pump(const Duration(seconds: 1));
    expect(encodedPlan(c), before);
    expect(c.activeTool.value, 'plan.select');
    expect(c.editorSelectedUnits.value, {'1'});
    // The control: with the shortcuts the plan takes the chords.
    keys.value = true;
    await tester.pump();
    await sendActivator(tester, kIntentKeys['ctrl+e']!);
    await sendActivator(tester, kIntentKeys['ctrl+p']!);
    expect(reached['ctrl+e'], 1, reason: 'the editor took Ctrl+E');
    expect(reached['ctrl+p'], 1, reason: 'the editor took Ctrl+P');
  });

  testWidgets(
      "RP12 shortcuts: false, unitsOnly, a table armed: R is the symbol "
      "tool's, M (mirror refused) bubbles; W and Escape reach the host; "
      'the tool stays symbol', (tester) async {
    final (c, reached, _) =
        await mountUnitKeys(tester, permissions: PlanPermissions.unitsOnly);
    await focusCanvas(tester);
    expect(
        c.armSymbol(PlanSymbol(
            kitId: 'fx',
            names: const KitNames({}),
            entry: entryOf(tableSymbol()))),
        isTrue);
    await tester.pump();
    expect(c.activeTool.value, 'plan.symbol');
    await focusCanvas(tester);
    expect(canvasFocused(), isTrue, reason: 'premise: the canvas focused');
    await sendActivator(tester, kIntentKeys['R']!);
    await sendActivator(tester, kIntentKeys['M']!);
    expect(reached['R'], 0, reason: "R is the armed tool's");
    expect(reached['M'], 1, reason: 'unitsOnly refuses mirror: M bubbles');
    await sendActivator(tester, kIntentKeys['W']!);
    await sendActivator(tester, kIntentKeys['escape']!);
    expect(reached['W'], 1);
    expect(reached['escape'], 1);
    expect(c.activeTool.value, 'plan.symbol');
  });
}
