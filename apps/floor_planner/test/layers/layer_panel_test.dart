// Spec 12b D9, D10, D11: the Layers panel. Every control is one command
// through the dispatcher (the undo stack grows by exactly one), makes the
// document dirty, and is undone by one undo, which the rows follow; the
// disabled states of decision 7 and S-6; the inline rename (Enter, Escape,
// focus loss, the reason, no shell shortcut while typing); + and its
// `Layer N`; the row order; read-only dispatches nothing (M-12a); the list
// follows a direct table write, a new document and an Open.
//
// P-6's layers: `A` (ACI 1), `B` (ACI 5, locked), `C` (ACI 3, hidden),
// beside a visible layer 0; no ACI 7 except where ACI 7's foreground is the
// point, and the hidden layer is not layer 0 except in the S-6 file.
import 'dart:convert';

import 'package:floor_planner/document_host.dart';
import 'package:jet_cad_floor_plan/editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/document_rig.dart' as rig;
import '../support/fake_document_files.dart';
import '../support/layer_fixture.dart';

Finder byKey(String k) => find.byKey(Key(k));

/// The shell's shortcuts around the panel, counted: the letters, Undo and
/// Redo, and Escape (what `ShellShortcutGuard` must keep out of a field).
class ShellCounter {
  int fired = 0;
}

/// [doc]'s panel in a 280-wide right column, with a focusable button
/// beside it (`elsewhere`) to take the focus away, under the shell's
/// shortcuts, counted in [shell].
Future<void> pumpPanel(WidgetTester tester, DraftDocument doc,
    {int foreground = 0x000000, ShellCounter? shell}) async {
  final counter = shell ?? ShellCounter();
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          for (final key in kShellLetterKeys)
            SingleActivator(key): () => counter.fired++,
          for (final chord in [...kUndoChords, ...kRedoChords])
            chord: () => counter.fired++,
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              counter.fired++,
        },
        child: Focus(
          autofocus: true,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 280,
              height: 560,
              child: Column(children: [
                LayerPanel(document: doc, foreground: foreground),
                TextButton(
                    key: const Key('elsewhere'),
                    onPressed: () {},
                    child: const Text('Elsewhere')),
              ]),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pump();
}

/// Lets the change stream deliver and the panel rebuild.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

String hx(Handle h) => h.toHex();

LayerRecord rec(DraftDocument doc, Handle h) => doc.tables.layers[h]!;

/// Every field of [r], for a failing full-record `expect` (`LayerRecord`
/// has no `toString`, and the engine is frozen; Task 10 review info 7).
String fieldsOf(LayerRecord r) => '{handle ${r.handle.toHex()}, name '
    '"${r.name}", ${r.color}, linetype ${r.linetype.toHex()}, lineweight '
    '${r.lineweight}, transparency ${r.transparency}, visible ${r.visible}, '
    'locked ${r.locked}}';

/// The `reason:` of a full-record `expect`: the record [actual] against
/// [want], field by field.
String recordReason(LayerRecord actual, LayerRecord want) =>
    'record ${fieldsOf(actual)}, wanted ${fieldsOf(want)}';

/// The record the panel handed row [h]: what the list shows.
LayerRecord shown(WidgetTester tester, Handle h) =>
    tester.widget<LayerRow>(find.byKey(ValueKey<Handle>(h))).record;

bool shownCurrent(WidgetTester tester, Handle h) =>
    tester.widget<LayerRow>(find.byKey(ValueKey<Handle>(h))).current;

bool enabled(WidgetTester tester, String key) =>
    tester.widget<IconButton>(byKey(key)).onPressed != null;

String tooltipOf(WidgetTester tester, String key) {
  // An IconButton's own tooltip sits inside it; delete's wraps it.
  final inside =
      find.descendant(of: byKey(key), matching: find.byType(Tooltip));
  final tip = inside.evaluate().isNotEmpty
      ? inside
      : find.ancestor(of: byKey(key), matching: find.byType(Tooltip));
  return tester.widget<Tooltip>(tip.first).message!;
}

/// The colour row [h]'s swatch is drawn in.
Color swatchOf(WidgetTester tester, Handle h) {
  final box = tester.widget<Container>(find.descendant(
      of: byKey('layer-colour-${hx(h)}'), matching: find.byType(Container)));
  return (box.decoration! as BoxDecoration).color!;
}

/// The top of row [h] on screen.
double topOf(WidgetTester tester, Handle h) =>
    tester.getTopLeft(byKey('layer-row-${hx(h)}')).dy;

Future<void> doubleTapName(WidgetTester tester, Handle h) async {
  final name = byKey('layer-name-${hx(h)}');
  await tester.tap(name);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tap(name);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

Finder fieldOf(Handle h) => byKey('layer-name-field-${hx(h)}');

Future<void> pressEnter(WidgetTester tester) async {
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await settle(tester);
}

Future<void> chooseColour(WidgetTester tester, Handle h, int aci) async {
  await tester.tap(byKey('layer-colour-${hx(h)}'));
  await tester.pumpAndSettle();
  await tester.tap(byKey('layer-colour-item-$aci'));
  await tester.pumpAndSettle();
}

/// A session over [doc], clean now: its `dirty` follows the dispatcher.
DocumentSession sessionOver(DraftDocument doc) =>
    DocumentSession(doc, FlutterTextMeasurer());

void main() {
  testWidgets(
      'rows: layer 0 first, then by name under toLowerCase, not by creation '
      'order nor by code unit (D10)', (tester) async {
    final fx = layerDoc();
    final doc = fx.doc;
    final zero = rec(doc, ReservedHandles.layerZero);
    Handle add(String name) {
      final h = doc.handleSeed.next();
      doc.commands.execute(AddLayerCommand(LayerRecord(
          handle: h,
          name: name,
          color: const IndexedColor(2),
          linetype: zero.linetype,
          lineweight: zero.lineweight,
          transparency: zero.transparency)));
      return h;
    }

    final zed = add('Zed'), alpha = add('alpha'), beta = add('Beta');
    await pumpPanel(tester, doc);
    final expected = [
      ReservedHandles.layerZero,
      fx.a,
      alpha,
      fx.b,
      beta,
      fx.c,
      zed,
    ];
    final tops = [for (final h in expected) topOf(tester, h)];
    for (var i = 1; i < tops.length; i++) {
      expect(tops[i], greaterThan(tops[i - 1]),
          reason: '${rec(doc, expected[i]).name} below '
              '${rec(doc, expected[i - 1]).name}');
    }
    expect(layersInPanelOrder(doc.tables.layers.records).map((r) => r.handle),
        expected);
    // More than six rows: the list scrolls within its cap.
    expect(tester.getSize(byKey('layers-list')).height,
        lessThanOrEqualTo(kLayerListVisibleRows * kLayerRowHeight));
  });

  testWidgets(
      'the current mark, the eye, the lock and the colour: each one command, '
      'dirty, undone by one undo, which the row follows', (tester) async {
    final fx = layerDoc();
    final doc = fx.doc;
    final session = sessionOver(doc);
    await pumpPanel(tester, doc);
    final a = fx.a, b = fx.b;

    Future<void> step(String what, Future<void> Function() act,
        void Function(bool done) check) async {
      final depth = doc.commands.undoDepth;
      expect(session.dirty.value, isFalse, reason: 'premise: clean');
      check(false);
      await act();
      await settle(tester);
      expect(doc.commands.undoDepth, depth + 1, reason: '$what: one command');
      expect(session.dirty.value, isTrue, reason: '$what: dirty');
      check(true);
      doc.commands.undo();
      await settle(tester);
      expect(doc.commands.undoDepth, depth, reason: '$what: undone');
      expect(session.dirty.value, isFalse, reason: '$what: clean again');
      check(false);
    }

    await step(
        'make A current', () => tester.tap(byKey('layer-current-${hx(a)}')),
        (done) {
      expect(doc.header.currentLayer, done ? a : ReservedHandles.layerZero);
      expect(shownCurrent(tester, a), done);
      expect(shownCurrent(tester, ReservedHandles.layerZero), !done);
    });
    // Each control changes its one field: the whole record is compared, so
    // a control that also touched another field (O1, O2) is caught.
    final beforeA = rec(doc, a),
        beforeB = rec(doc, b),
        beforeC = rec(doc, fx.c);
    await step('hide A', () => tester.tap(byKey('layer-eye-${hx(a)}')), (done) {
      final want = done ? beforeA.copyWith(visible: false) : beforeA;
      expect(rec(doc, a), want, reason: recordReason(rec(doc, a), want));
      expect(shown(tester, a), rec(doc, a));
    });
    await step('show C', () => tester.tap(byKey('layer-eye-${hx(fx.c)}')),
        (done) {
      final want = done ? beforeC.copyWith(visible: true) : beforeC;
      expect(rec(doc, fx.c), want, reason: recordReason(rec(doc, fx.c), want));
      expect(shown(tester, fx.c), rec(doc, fx.c));
    });
    await step('lock A', () => tester.tap(byKey('layer-lock-${hx(a)}')),
        (done) {
      final want = done ? beforeA.copyWith(locked: true) : beforeA;
      expect(rec(doc, a), want, reason: recordReason(rec(doc, a), want));
      expect(shown(tester, a), rec(doc, a));
    });
    await step('unlock B', () => tester.tap(byKey('layer-lock-${hx(b)}')),
        (done) {
      final want = done ? beforeB.copyWith(locked: false) : beforeB;
      expect(rec(doc, b), want, reason: recordReason(rec(doc, b), want));
      expect(shown(tester, b), rec(doc, b));
    });
    await step('recolour B to cyan', () => chooseColour(tester, b, 4), (done) {
      final want = IndexedColor(done ? 4 : 5);
      expect(rec(doc, b), beforeB.copyWith(color: want),
          reason: recordReason(rec(doc, b), beforeB.copyWith(color: want)));
      expect(shown(tester, b), rec(doc, b));
      expect(swatchOf(tester, b), Color(0xFF000000 | aciToRgb(want.aci)));
    });
  });

  testWidgets(
      'choosing a layer\'s own colour, or tapping the current mark '
      'of the current layer, dispatches nothing', (tester) async {
    final fx = layerDoc();
    final doc = fx.doc;
    await pumpPanel(tester, doc);
    await chooseColour(tester, fx.a, 1);
    expect(doc.commands.undoDepth, 0);
    expect(enabled(tester, 'layer-current-${hx(ReservedHandles.layerZero)}'),
        isFalse);
  });

  testWidgets(
      'swatches: ACI 7 in the paper\'s foreground, as the resolver draws it; '
      'the menu offers ACI 1-9', (tester) async {
    final fx = layerDoc();
    final doc = fx.doc;
    for (final foreground in [0x000000, 0xFFFFFF]) {
      await pumpPanel(tester, doc, foreground: foreground);
      expect(rec(doc, ReservedHandles.layerZero).color, const IndexedColor(7),
          reason: 'premise: layer 0 is ACI 7');
      expect(swatchOf(tester, ReservedHandles.layerZero),
          Color(0xFF000000 | foreground));
      expect(swatchOf(tester, fx.b), Color(0xFF000000 | aciToRgb(5)));
      await tester.tap(byKey('layer-colour-${hx(fx.a)}'));
      await tester.pumpAndSettle();
      for (var aci = 1; aci <= 9; aci++) {
        expect(byKey('layer-colour-item-$aci'), findsOneWidget);
      }
      expect(byKey('layer-colour-item-10'), findsNothing);
      await tester.tapAt(const Offset(700, 580));
      await tester.pumpAndSettle();
    }
  });

  testWidgets(
      'disabled: hiding the effective current layer (with the reason), '
      'making a hidden layer current; delete on layer 0, on the current '
      'layer and on a layer in use, each with its reason', (tester) async {
    final fx = layerFixture(room: false, dimension: false);
    final doc = fx.doc;
    doc.commands.execute(SetCurrentLayerCommand(fx.a));
    doc.commands.clearHistory();
    await pumpPanel(tester, doc);
    final a = hx(fx.a), c = hx(fx.c);
    expect(enabled(tester, 'layer-eye-$a'), isFalse);
    expect(tooltipOf(tester, 'layer-eye-$a'),
        'The current layer cannot be hidden');
    expect(enabled(tester, 'layer-eye-$c'), isTrue,
        reason: 'showing is always enabled');
    expect(
        enabled(tester, 'layer-eye-${hx(ReservedHandles.layerZero)}'), isTrue,
        reason: 'layer 0 is not current now: it can be hidden');
    expect(enabled(tester, 'layer-current-$c'), isFalse);
    expect(tooltipOf(tester, 'layer-current-$c'),
        'A hidden layer cannot be current');
    expect(enabled(tester, 'layer-current-${hx(fx.b)}'), isTrue,
        reason: 'a locked layer can be current');

    expect(enabled(tester, 'layers-delete'), isFalse);
    expect(tooltipOf(tester, 'layers-delete'), 'Select a layer to delete it');
    Future<void> select(Handle h) async {
      await tester.tap(byKey('layer-row-${hx(h)}'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 400));
      expect(
          tester.state<LayerPanelState>(find.byType(LayerPanel)).selected, h);
    }

    for (final (h, why) in [
      (ReservedHandles.layerZero, 'Layer 0 cannot be deleted'),
      (fx.a, 'The current layer cannot be deleted'),
      (fx.b, 'This layer is in use'),
    ]) {
      await select(h);
      expect(enabled(tester, 'layers-delete'), isFalse,
          reason: rec(doc, h).name);
      expect(tooltipOf(tester, 'layers-delete'), why);
    }
    await select(fx.c);
    expect(layerIsEmpty(doc, fx.c), isTrue, reason: 'premise');
    expect(enabled(tester, 'layers-delete'), isTrue);
    expect(doc.commands.undoDepth, 0, reason: 'selecting is not a command');
  });

  testWidgets(
      'delete: a stored current layer that is hidden and empty is not the '
      'effective current layer; delete is enabled and one tap removes it '
      '(D3, O3)', (tester) async {
    final fx = layerFixture(room: false, dimension: false);
    final doc = fx.doc;
    doc.commands.execute(SetCurrentLayerCommand.restore(fx.c));
    doc.commands.clearHistory();
    expect(doc.header.currentLayer, fx.c, reason: 'premise: stored');
    expect(drawingLayer(doc), ReservedHandles.layerZero,
        reason: 'premise: C is hidden, so layer 0 draws');
    expect(layerIsEmpty(doc, fx.c), isTrue, reason: 'premise');
    await pumpPanel(tester, doc);
    await tester.tap(byKey('layer-row-${hx(fx.c)}'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 400));
    expect(enabled(tester, 'layers-delete'), isTrue);
    expect(tooltipOf(tester, 'layers-delete'), 'Delete layer');
    await tester.tap(byKey('layers-delete'));
    await settle(tester);
    expect(doc.commands.undoDepth, 1);
    expect(doc.tables.layers[fx.c], isNull);
  });

  testWidgets(
      'delete: one command, dirty, the row goes; undo brings it back with '
      'its record', (tester) async {
    final fx = layerFixture(room: false, dimension: false);
    final doc = fx.doc;
    final session = sessionOver(doc);
    final before = rec(doc, fx.c);
    await pumpPanel(tester, doc);
    await tester.tap(byKey('layer-row-${hx(fx.c)}'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(byKey('layers-delete'));
    await settle(tester);
    expect(doc.commands.undoDepth, 1);
    expect(session.dirty.value, isTrue);
    expect(doc.tables.layers[fx.c], isNull);
    expect(byKey('layer-row-${hx(fx.c)}'), findsNothing);
    expect(enabled(tester, 'layers-delete'), isFalse,
        reason: 'the selection went with the row');
    doc.commands.undo();
    await settle(tester);
    expect(session.dirty.value, isFalse);
    expect(shown(tester, fx.c).name, before.name);
    expect(shown(tester, fx.c).color, before.color);
    expect(shown(tester, fx.c).visible, before.visible);
  });

  testWidgets(
      'S-6: a file with hidden layer 0 and an unusable stored current layer: '
      'layer 0 is the effective current layer, and showing it is enabled '
      '(M-LP-26)', (tester) async {
    final fx = layerDoc();
    final src = fx.doc;
    // Written by the restore forms, as only a file can be: the stored
    // current layer names no layer, and layer 0 is hidden.
    src.commands.execute(SetCurrentLayerCommand.restore(const Handle(0x7A7A)));
    src.commands.execute(SetLayerCommand.restore(
        rec(src, ReservedHandles.layerZero).copyWith(visible: false)));
    final doc = DraftDocumentCodec.decodeString(
        DraftDocumentCodec.encodeToString(src),
        registerComponents: registerAppComponents);
    expect(doc.header.currentLayer, const Handle(0x7A7A), reason: 'premise');
    expect(drawingLayer(doc), ReservedHandles.layerZero, reason: 'premise');
    expect(rec(doc, ReservedHandles.layerZero).visible, isFalse,
        reason: 'premise');
    final session = sessionOver(doc);
    await pumpPanel(tester, doc);
    final zero = hx(ReservedHandles.layerZero);
    expect(shownCurrent(tester, ReservedHandles.layerZero), isTrue);
    expect(enabled(tester, 'layer-eye-$zero'), isTrue,
        reason: 'showing the effective current layer is enabled');
    expect(tooltipOf(tester, 'layer-eye-$zero'), 'Show layer');
    expect(enabled(tester, 'layer-current-$zero'), isFalse,
        reason: 'a hidden layer cannot be made current');
    await tester.tap(byKey('layer-eye-$zero'));
    await settle(tester);
    expect(doc.commands.undoDepth, 1);
    expect(session.dirty.value, isTrue);
    expect(rec(doc, ReservedHandles.layerZero).visible, isTrue);
    expect(enabled(tester, 'layer-eye-$zero'), isFalse,
        reason: 'now visible and current: hiding it is refused');
  });

  testWidgets(
      'S-5: showing a hidden stored current layer makes it current again, and '
      'the mark follows', (tester) async {
    final fx = layerDoc();
    final doc = fx.doc;
    doc.commands.execute(SetCurrentLayerCommand.restore(fx.c));
    doc.commands.clearHistory();
    await pumpPanel(tester, doc);
    expect(shownCurrent(tester, fx.c), isFalse);
    expect(shownCurrent(tester, ReservedHandles.layerZero), isTrue);
    await tester.tap(byKey('layer-eye-${hx(fx.c)}'));
    await settle(tester);
    expect(shownCurrent(tester, fx.c), isTrue);
    expect(shownCurrent(tester, ReservedHandles.layerZero), isFalse);
  });

  group('rename', () {
    testWidgets(
        'a double-click opens the field; typing dispatches nothing; Enter '
        'commits the trimmed name in one command (M-LP-18)', (tester) async {
      final fx = layerDoc();
      final doc = fx.doc;
      final session = sessionOver(doc);
      await pumpPanel(tester, doc);
      await doubleTapName(tester, fx.a);
      expect(fieldOf(fx.a), findsOneWidget);
      for (final partial in ['K', 'Ki', 'Kit', 'Kitch', '  Kitchen  ']) {
        await tester.enterText(fieldOf(fx.a), partial);
        await settle(tester);
      }
      expect(doc.commands.undoDepth, 0, reason: 'nothing per keystroke');
      expect(rec(doc, fx.a).name, 'A');
      await pressEnter(tester);
      expect(doc.commands.undoDepth, 1);
      expect(session.dirty.value, isTrue);
      expect(rec(doc, fx.a).name, 'Kitchen', reason: 'trimmed by the UI');
      expect(fieldOf(fx.a), findsNothing);
      expect(shown(tester, fx.a).name, 'Kitchen');
      doc.commands.undo();
      await settle(tester);
      expect(shown(tester, fx.a).name, 'A');
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets(
        'Enter on B (ACI 5, locked) changes the name only: the whole record '
        'is the old one with the new name (O1, O2)', (tester) async {
      final fx = layerDoc();
      final doc = fx.doc;
      final before = rec(doc, fx.b);
      expect(before.locked, isTrue, reason: 'premise');
      expect(before.color, const IndexedColor(5), reason: 'premise');
      await pumpPanel(tester, doc);
      await doubleTapName(tester, fx.b);
      await tester.enterText(fieldOf(fx.b), 'Kitchen');
      await pressEnter(tester);
      expect(doc.commands.undoDepth, 1);
      final want = before.copyWith(name: 'Kitchen');
      expect(rec(doc, fx.b), want, reason: recordReason(rec(doc, fx.b), want));
    });

    testWidgets(
        'a blur-rename then a tap on the same row\'s lock with no frame '
        'between down and up keeps the name: the lock reads the live record '
        '(Task 9 review finding 1)', (tester) async {
      final fx = layerDoc();
      final doc = fx.doc;
      final before = rec(doc, fx.a);
      await pumpPanel(tester, doc);
      await doubleTapName(tester, fx.a);
      await tester.enterText(fieldOf(fx.a), 'Hall');
      await tester.pump();
      // Pointer-down blurs the field (the rename commits); pointer-up, in
      // the same frame, toggles the lock.
      await tester.tap(byKey('layer-lock-${hx(fx.a)}'));
      await settle(tester);
      expect(doc.commands.undoDepth, 2);
      final want = before.copyWith(name: 'Hall', locked: true);
      expect(rec(doc, fx.a), want, reason: recordReason(rec(doc, fx.a), want));
    });

    testWidgets(
        'an invalid name on Enter keeps the field open with the reason; '
        'Escape then reverts and dispatches nothing', (tester) async {
      final fx = layerDoc();
      final doc = fx.doc;
      await pumpPanel(tester, doc);
      await doubleTapName(tester, fx.a);
      await tester.enterText(fieldOf(fx.a), 'b');
      await pressEnter(tester);
      final why = layerNameError(doc, 'b', self: fx.a)!;
      expect(why, contains('B'), reason: 'premise: a case-folded duplicate');
      expect(fieldOf(fx.a), findsOneWidget, reason: 'the field stays open');
      expect(find.text(why), findsOneWidget);
      expect(doc.commands.undoDepth, 0);
      await tester.enterText(fieldOf(fx.a), 'a:b');
      await pressEnter(tester);
      expect(
          find.text(layerNameError(doc, 'a:b', self: fx.a)!), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(fieldOf(fx.a), findsNothing);
      expect(doc.commands.undoDepth, 0);
      expect(rec(doc, fx.a).name, 'A');
    });

    testWidgets(
        'a case-only rename is valid (the record itself is no '
        'duplicate)', (tester) async {
      final fx = layerDoc();
      final doc = fx.doc;
      await pumpPanel(tester, doc);
      await doubleTapName(tester, fx.a);
      await tester.enterText(fieldOf(fx.a), 'a');
      await pressEnter(tester);
      expect(rec(doc, fx.a).name, 'a');
      expect(doc.commands.undoDepth, 1);
    });

    testWidgets('Escape with a valid new name reverts and dispatches nothing',
        (tester) async {
      final fx = layerDoc();
      final doc = fx.doc;
      final shell = ShellCounter();
      await pumpPanel(tester, doc, shell: shell);
      await doubleTapName(tester, fx.a);
      await tester.enterText(fieldOf(fx.a), 'Kitchen');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(fieldOf(fx.a), findsNothing);
      expect(doc.commands.undoDepth, 0);
      expect(rec(doc, fx.a).name, 'A');
      expect(shell.fired, 0, reason: 'the field\'s Escape, not the shell\'s');
    });

    testWidgets(
        'focus loss: an invalid name reverts and dispatches nothing; a valid '
        'one commits once', (tester) async {
      final fx = layerDoc();
      final doc = fx.doc;
      await pumpPanel(tester, doc);
      await doubleTapName(tester, fx.a);
      await tester.enterText(fieldOf(fx.a), 'C');
      await tester.tap(byKey('elsewhere'));
      await settle(tester);
      expect(fieldOf(fx.a), findsNothing);
      expect(doc.commands.undoDepth, 0);
      expect(rec(doc, fx.a).name, 'A');

      await doubleTapName(tester, fx.a);
      await tester.enterText(fieldOf(fx.a), 'Hall');
      await tester.tap(byKey('elsewhere'));
      await settle(tester);
      expect(fieldOf(fx.a), findsNothing);
      expect(doc.commands.undoDepth, 1);
      expect(rec(doc, fx.a).name, 'Hall');
    });

    testWidgets('layer 0 cannot be renamed: a double-click opens no field',
        (tester) async {
      final fx = layerDoc();
      await pumpPanel(tester, fx.doc);
      await doubleTapName(tester, ReservedHandles.layerZero);
      expect(fieldOf(ReservedHandles.layerZero), findsNothing);
    });

    testWidgets(
        'no shell shortcut fires while typing: letters, Undo, Redo and Escape '
        'stop at the field', (tester) async {
      final fx = layerDoc();
      final doc = fx.doc;
      final shell = ShellCounter();
      await pumpPanel(tester, doc, shell: shell);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
      await tester.pump();
      expect(shell.fired, 1, reason: 'premise: the shell hears W elsewhere');
      shell.fired = 0;
      await doubleTapName(tester, fx.a);
      expect(fieldOf(fx.a), findsOneWidget);
      for (final key in kShellLetterKeys) {
        await tester.sendKeyEvent(key);
      }
      for (final chord in [...kUndoChords, ...kRedoChords]) {
        final mods = [
          if (chord.meta) LogicalKeyboardKey.meta,
          if (chord.control) LogicalKeyboardKey.control,
          if (chord.shift) LogicalKeyboardKey.shift,
        ];
        for (final m in mods) {
          await tester.sendKeyDownEvent(m);
        }
        await tester.sendKeyEvent(chord.trigger);
        for (final m in mods.reversed) {
          await tester.sendKeyUpEvent(m);
        }
      }
      await tester.pump();
      expect(shell.fired, 0);
      expect(fieldOf(fx.a), findsOneWidget, reason: 'still typing');
      expect(doc.commands.undoDepth, 0);
    });
  });

  testWidgets(
      '+ adds `Layer N`, the smallest N not taken under toLowerCase, ACI 7, '
      'layer 0\'s linetype, lineweight and transparency, from the handle '
      'seed; selects it and opens its name field', (tester) async {
    final fx = layerDoc();
    final doc = fx.doc;
    final zero0 = rec(doc, ReservedHandles.layerZero);
    // Layer 0 with attributes of its own, so copying them is observable.
    doc.commands.execute(SetLayerCommand.restore(
        zero0.copyWith(lineweight: 35, transparency: 40)));
    final zero = rec(doc, ReservedHandles.layerZero);
    for (final (name, aci) in [('Layer 1', 2), ('layer 3', 6)]) {
      doc.commands.execute(AddLayerCommand(LayerRecord(
          handle: doc.handleSeed.next(),
          name: name,
          color: IndexedColor(aci),
          linetype: zero.linetype,
          lineweight: 13,
          transparency: 0)));
    }
    doc.commands.clearHistory();
    final session = sessionOver(doc);
    await pumpPanel(tester, doc);
    final known = {for (final r in doc.tables.layers.records) r.handle};

    Future<LayerRecord> plus(String want) async {
      final depth = doc.commands.undoDepth;
      final seed = doc.handleSeed.current.value + 1;
      await tester.tap(byKey('layers-add'));
      await settle(tester);
      expect(doc.commands.undoDepth, depth + 1, reason: '$want: one command');
      final added = doc.tables.layers.records
          .where((r) => !known.contains(r.handle))
          .single;
      known.add(added.handle);
      expect(added.handle.value, seed, reason: 'the next handle of the seed');
      expect(added.name, want);
      expect(added.color, const IndexedColor(7));
      expect(added.linetype, zero.linetype);
      expect(added.lineweight, 35);
      expect(added.transparency, 40);
      expect(added.visible, isTrue);
      expect(added.locked, isFalse);
      expect(tester.state<LayerPanelState>(find.byType(LayerPanel)).selected,
          added.handle);
      expect(fieldOf(added.handle), findsOneWidget, reason: 'its name field');
      expect(
          tester.widget<TextField>(fieldOf(added.handle)).focusNode!.hasFocus,
          isTrue);
      return added;
    }

    final two = await plus('Layer 2');
    expect(session.dirty.value, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(fieldOf(two.handle), findsNothing);
    expect(doc.commands.undoDepth, 1, reason: 'Escape dispatched nothing');
    final four = await plus('Layer 4');
    // Its field takes a name at once.
    await tester.enterText(fieldOf(four.handle), 'Furniture');
    await pressEnter(tester);
    expect(rec(doc, four.handle).name, 'Furniture');
    expect(doc.commands.undoDepth, 3);
    doc.commands.undo();
    doc.commands.undo();
    await settle(tester);
    expect(byKey('layer-row-${hx(four.handle)}'), findsNothing,
        reason: 'the list follows the undo of +');
  });

  testWidgets(
      'read-only: every control is disabled and nothing is dispatched; no '
      'PermissionDeniedError is raised (D11, M-12a)', (tester) async {
    for (final permissions in [
      DraftPermissions.readOnly,
      DraftPermissions.runtime,
    ]) {
      final fx = layerDoc();
      final doc = fx.doc;
      doc.commands.permissions = permissions;
      expect(permissions.allows(Capability.structure), isFalse,
          reason: 'premise');
      final bytes = DraftDocumentCodec.encodeToString(doc);
      final state = doc.commands.stateId;
      await pumpPanel(tester, doc);
      final a = hx(fx.a), c = hx(fx.c);
      for (final key in [
        'layer-current-$a',
        'layer-eye-$a',
        'layer-eye-$c',
        'layer-lock-$a',
        'layers-add',
        'layers-delete',
      ]) {
        expect(enabled(tester, key), isFalse, reason: key);
      }
      expect(
          tester.widget<PopupMenuButton<int>>(byKey('layer-colour-$a')).enabled,
          isFalse);
      // Neutral wording: under runtime the picker still moves things
      // (Task 10 review info 6).
      expect(tooltipOf(tester, 'layers-delete'),
          'Layers cannot be changed in this document');
      // Tap them all anyway.
      await tester.tap(byKey('layer-row-$c'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 400));
      for (final key in [
        'layer-current-$a',
        'layer-eye-$a',
        'layer-eye-$c',
        'layer-lock-$a',
        'layer-colour-$a',
        'layers-add',
        'layers-delete',
      ]) {
        await tester.tap(byKey(key), warnIfMissed: false);
        await tester.pumpAndSettle();
      }
      expect(find.byKey(const Key('layer-colour-item-4')), findsNothing,
          reason: 'no colour menu');
      await doubleTapName(tester, fx.a);
      expect(fieldOf(fx.a), findsNothing, reason: 'no rename field');
      expect(tester.takeException(), isNull,
          reason: 'no PermissionDeniedError: nothing reached the dispatcher');
      expect(doc.commands.undoDepth, 0);
      expect(doc.commands.stateId, state);
      expect(DraftDocumentCodec.encodeToString(doc), bytes);
      // The list is still shown.
      expect(byKey('layer-row-$a'), findsOneWidget);
    }
  });

  testWidgets(
      'the list follows a direct table write (tables.changes) and a header '
      'change (commands.changes)', (tester) async {
    final fx = layerDoc();
    final doc = fx.doc;
    await pumpPanel(tester, doc);
    final a = rec(doc, fx.a);
    doc.tables.layers
      ..remove(fx.a)
      ..add(a.copyWith(locked: true, color: const IndexedColor(6)));
    await tester.pump();
    expect(shown(tester, fx.a).locked, isTrue);
    expect(swatchOf(tester, fx.a), Color(0xFF000000 | aciToRgb(6)));
    // A header-only command fires no table change.
    final revision = doc.tables.mutationRevision;
    doc.commands.execute(SetCurrentLayerCommand(fx.b));
    expect(doc.tables.mutationRevision, revision, reason: 'premise');
    await settle(tester);
    expect(shownCurrent(tester, fx.b), isTrue);
  });

  testWidgets('the header collapses and reopens the list; open by default',
      (tester) async {
    final fx = layerDoc();
    await pumpPanel(tester, fx.doc);
    expect(byKey('layer-row-${hx(fx.a)}'), findsOneWidget);
    await tester.tap(byKey('layers-header'));
    await tester.pump();
    expect(byKey('layer-row-${hx(fx.a)}'), findsNothing);
    expect(byKey('layers-add'), findsNothing);
    await tester.tap(byKey('layers-header'));
    await tester.pump();
    expect(byKey('layer-row-${hx(fx.a)}'), findsOneWidget);
  });

  testWidgets(
      'another document: the panel moves its subscriptions and shows the new '
      'layers; dispose removes them', (tester) async {
    final one = layerDoc().doc;
    final two = layerFixture(room: false, dimension: false);
    final baseOne = one.tables.debugListenerCount;
    final baseTwo = two.doc.tables.debugListenerCount;
    await pumpPanel(tester, one);
    expect(one.tables.debugListenerCount, baseOne + 1);
    await pumpPanel(tester, two.doc);
    expect(one.tables.debugListenerCount, baseOne);
    expect(two.doc.tables.debugListenerCount, baseTwo + 1);
    two.doc.commands.execute(SetCurrentLayerCommand(two.a));
    await settle(tester);
    expect(shownCurrent(tester, two.a), isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(two.doc.tables.debugListenerCount, baseTwo);
  });

  testWidgets(
      'in the app: the panel sits between the Selection and Page panels; Open '
      'shows the opened file\'s layers and current layer; a control makes '
      'the session dirty', (tester) async {
    final fx = layerDoc();
    fx.doc.commands.execute(SetCurrentLayerCommand(fx.b));
    final file = utf8.encode(DraftDocumentCodec.encodeToString(fx.doc));

    final files = FakeDocumentFiles();
    final host = await rig.pumpApp(tester, files);
    final right = find.byKey(const Key('chrome-right'));
    expect(find.descendant(of: right, matching: byKey('layers-panel')),
        findsOneWidget);
    expect(byKey('layer-row-${hx(fx.a)}'), findsNothing,
        reason: 'premise: a new document has layer 0 only');
    files.scriptOpen(name: 'layers.jetplan', bytes: file);
    await host.openFlow();
    await tester.pump();
    await tester.pump();
    final opened = rig.sessionOf(tester).document;
    expect(opened.tables.layers[fx.b], isNotNull, reason: 'premise: opened');
    for (final h in [ReservedHandles.layerZero, fx.a, fx.b, fx.c]) {
      expect(byKey('layer-row-${hx(h)}'), findsOneWidget);
    }
    expect(shownCurrent(tester, fx.b), isTrue);
    expect(shown(tester, fx.c).visible, isFalse);
    expect(rig.sessionOf(tester).dirty.value, isFalse);
    await tester.tap(byKey('layer-lock-${hx(fx.a)}'));
    await settle(tester);
    expect(opened.tables.layers[fx.a]!.locked, isTrue);
    expect(opened.commands.undoDepth, 1);
    expect(rig.sessionOf(tester).dirty.value, isTrue);
    // Placement: below the Selection panel's slot, above the Page panel.
    final layersTop = tester.getTopLeft(byKey('layers-panel')).dy;
    final pageTop = tester
        .getTopLeft(
            find.descendant(of: right, matching: find.byType(PagePanel)))
        .dy;
    expect(layersTop, lessThan(pageTop));
  });

  testWidgets(
      'a loaded layer whose stored name fails D4: its eye hides it, one '
      'command (final review finding 1)', (tester) async {
    final fx = layerDoc();
    final zero = rec(fx.doc, ReservedHandles.layerZero);
    final h = fx.doc.handleSeed.next();
    // A direct table write: the user form would refuse the colon.
    fx.doc.tables.layers.add(LayerRecord(
        handle: h,
        name: 'Walls:Ext',
        color: const IndexedColor(4),
        linetype: zero.linetype,
        lineweight: zero.lineweight,
        transparency: zero.transparency));
    final doc = fx.doc;
    await pumpPanel(tester, doc);
    expect(enabled(tester, 'layer-eye-${hx(h)}'), isTrue);
    final depth = doc.commands.undoDepth;
    await tester.tap(byKey('layer-eye-${hx(h)}'));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(rec(doc, h).visible, isFalse);
    expect(rec(doc, h).name, 'Walls:Ext');
    expect(doc.commands.undoDepth, depth + 1);
    expect(shown(tester, h).visible, isFalse);
  });

  testWidgets(
      'a command the document refuses is caught: nothing changes and the '
      'press raises nothing (final review finding 1)', (tester) async {
    final fx = layerDoc();
    final doc = fx.doc;
    await pumpPanel(tester, doc);
    expect(enabled(tester, 'layer-eye-${hx(fx.a)}'), isTrue,
        reason: 'premise: A is not current, so its eye is enabled');
    // A direct header write the panel does not listen to: A becomes the
    // effective current layer behind the built row, whose eye stays enabled
    // until the next rebuild. The press dispatches a hide of the current
    // layer, which the user form refuses (decision 7).
    doc.header.currentLayer = fx.a;
    final before = DraftDocumentCodec.encodeToString(doc);
    final depth = doc.commands.undoDepth;
    final record = rec(doc, fx.a);
    await tester.tap(byKey('layer-eye-${hx(fx.a)}'));
    await settle(tester);
    expect(tester.takeException(), isNull, reason: 'the refusal is caught');
    expect(DraftDocumentCodec.encodeToString(doc), before);
    expect(doc.commands.undoDepth, depth);
    expect(rec(doc, fx.a), record,
        reason: recordReason(rec(doc, fx.a), record));
  });
}
