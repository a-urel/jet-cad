// Ported from jet_cad_floor_plan/test/host/keyboard_focus_test.dart (3a Task 26, spec C6); assertions unchanged.
//
// Host embedding API spec C-7 (Slice 4 plan, Task 6; S-16, S-21): the
// view's `shortcuts` and `autofocus` in both modes, and the controller's
// `deleteSelection()` (C-3 as S-16 was ruled). Both modes on the embedding
// fixture under `embeddingCamera()`; the editor's keys and the delete on
// the editor fixture under `editorCamera()`. A host `CallbackShortcuts`
// above the view counts every key that reaches it.
//
// The wall cases: "a gesture's keys stay: the Wall tool chosen by the
// host", DS2, DS5 and R-3 RP5. The host is 2b's (plan_shortcuts_test.dart's
// `mountUnitKeys`, its `CallbackShortcuts` form) over the editor fixture:
// 2b's units on the sample flat (ruling IT-R2); tables are units.
import 'dart:convert' show jsonEncode;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/canvas_rig.dart';
import '../support/editor_fixture.dart';
import '../support/fake_page_printer.dart';
import '../support/units.dart';

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
  final c = PlanController(kits: editorKits(), json: editorPlanJson());
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

/// [encoded] with the entities by handle: slot order is history, not state
/// (06 D11), and a wall's delete regenerates its neighbours, so its undo
/// lands their entities in other slots. Everything else, the children's
/// order included, compares as written.
String entitiesByHandle(PlanController c) {
  final j = DraftDocumentCodec.encode(c.document);
  j['entities'] = List<Map<String, Object?>>.from(j['entities']! as List)
    ..sort((a, b) => ((a['record']! as Map)['handle']! as int)
        .compareTo((b['record']! as Map)['handle']! as int));
  return jsonEncode(j);
}

/// Table `1`'s data, or null.
Map<String, String>? dataOf1(PlanController c) =>
    c.unitDetails.where((d) => d.unit.label == '1').firstOrNull?.data;

void main() {
  group('shortcuts: false in the design mode', () {
    testWidgets(
        "a gesture's keys stay: the Wall tool chosen by the host, idle, lets "
        'Escape reach the host and stays; part-way, its Escape cancels the '
        'wall and the host hears nothing', (tester) async {
      final (c, reached, _) = await mountUnitKeys(tester,
          permissions: PlanPermissions.full, intents: false);
      await focusCanvas(tester);
      expect(c.selectTool(ArchitectureTools.wall), isTrue,
          reason: 'the command stays callable');
      await tester.pump();
      await press(tester, LogicalKeyboardKey.escape);
      expect(reached['escape'], 1, reason: "no shell's Escape");
      expect(c.activeTool.value, ArchitectureTools.wall);
      final at = screenOf(tester, c, editorTextAt) + const Offset(0, 80);
      await click(tester, at);
      expect(status(tester), contains('Wall'));
      // Part-way: undo waits (S-4), and the Escape is the wall's.
      expect(c.setUnitData('1', const {'pos': 'a1'}), isTrue);
      await tester.pump();
      c.undo();
      expect(dataOf1(c), const {'pos': 'a1'}, reason: 'mid-shape: no undo');
      await press(tester, LogicalKeyboardKey.escape);
      expect(reached['escape'], 1, reason: "the gesture's own Escape");
      c.undo();
      await tester.pump();
      expect(dataOf1(c), isEmpty, reason: 'the wall cancelled: undo acts');
      await press(tester, LogicalKeyboardKey.escape);
      expect(reached['escape'], 2, reason: 'idle again: the host');
    });
  });

  group('deleteSelection()', () {
    testWidgets(
        'DS2 the call deletes as the key does: 1, 2 (with data) and a wall '
        'selected, the same document after the call (shortcuts: false) and '
        'after the key (shortcuts)', (tester) async {
      Future<List<String>> deleted(bool viaCall) async {
        final (c, _, _) = await mountUnitKeys(tester,
            permissions: PlanPermissions.full,
            intents: false,
            shortcuts: !viaCall);
        await focusCanvas(tester);
        expect(c.setUnitData('2', const {'pos': 'b2'}), isTrue);
        await tester.pump();
        final d = c.document;
        c.select({'1', '2'});
        c.activeSelection.replace([
          ...c.activeSelection.keys,
          SelectionKey.root(d.components.withComponent<WallParams>().first),
        ]);
        await tester.pump();
        expect(c.activeSelection.length, 3);
        final before = entitiesByHandle(c);
        final depth = d.commands.undoDepth;
        if (viaCall) {
          expect(c.deleteSelection(), isTrue);
        } else {
          await press(tester, LogicalKeyboardKey.delete);
        }
        await tester.pump();
        expect(d.commands.undoDepth, depth + 1, reason: 'one step');
        final json = encodedPlan(c);
        c.undo();
        await tester.pump();
        expect(d.commands.undoDepth, depth);
        final undone = encodedPlan(c);
        expect(entitiesByHandle(c), before,
            reason: 'the plan as it was (spec O-10: the children in their '
                'order), by ${viaCall ? 'call' : 'key'}');
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        return [json, undone];
      }

      final byCall = await deleted(true);
      final byKey = await deleted(false);
      expect(byCall[0], byKey[0], reason: 'the delete');
      expect(byCall[1], byKey[1], reason: 'its undo');
    });

    testWidgets(
        'DS5 false while a wall is part-way, the host\'s selection held; '
        'true once the wall is cancelled', (tester) async {
      final (c, reached, _) = await mountUnitKeys(tester,
          permissions: PlanPermissions.full, intents: false);
      await focusCanvas(tester);
      expect(c.selectTool(ArchitectureTools.wall), isTrue);
      await tester.pump();
      await click(
          tester, screenOf(tester, c, editorTextAt) + const Offset(0, 80));
      c.select({'1'});
      await tester.pump();
      expect(c.selectedUnits.value, {'1'});
      final before = encodedPlan(c);
      expect(c.deleteSelection(), isFalse, reason: 'part-way');
      expect(encodedPlan(c), before);
      await press(tester, LogicalKeyboardKey.escape);
      c.select({'1'});
      await tester.pump();
      expect(c.deleteSelection(), isTrue, reason: 'idle: the selection goes');
      expect(unitsLabelled(c.document, '1'), isEmpty);
    });
  });

  group("the review's killers (Task 6 review R-2, R-3)", () {
    testWidgets(
        'R-3 (RP5) shortcuts: true: delete: false refuses the call; the Wall '
        "tool idle with the host's selection: the key deletes nothing, the "
        'call deletes', (tester) async {
      final (c, _, _) = await mountUnitKeys(tester,
          permissions: PlanPermissions.full.copyWith(delete: false),
          intents: false,
          shortcuts: true);
      await focusCanvas(tester);
      c.select({'1'});
      await tester.pump();
      expect(c.deleteSelection(), isFalse, reason: 'delete: false');
      await tester.pumpWidget(const SizedBox());
      final (c2, _, _) = await mountUnitKeys(tester,
          permissions: PlanPermissions.full, intents: false, shortcuts: true);
      await focusCanvas(tester);
      expect(c2.selectTool(ArchitectureTools.wall), isTrue);
      await tester.pump();
      c2.select({'1'});
      await tester.pump();
      final before = encodedPlan(c2);
      await press(tester, LogicalKeyboardKey.delete);
      expect(encodedPlan(c2), before,
          reason: 'the key: the Wall tool has none');
      expect(c2.deleteSelection(), isTrue, reason: 'the call deletes');
      expect(unitsLabelled(c2.document, '1'), isEmpty);
      expect(c2.activeTool.value, ArchitectureTools.wall);
    });
  });
}
