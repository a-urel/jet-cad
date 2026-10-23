// The chrome parts (spec "The component mapping": Fields, Choices, Menus,
// Semantics): each part mounted under a bare `MaterialApp` in a
// `PlanShadScope`, and the behaviours the panels used to get from Material
// widgets that shadcn's do not give for free.
import 'dart:ui' show Tristate;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/src/chrome/host_slot.dart';
import 'package:jet_cad_2d_plan/src/chrome/icon_button.dart';
import 'package:jet_cad_2d_plan/src/chrome/menu_button.dart';
import 'package:jet_cad_2d_plan/src/chrome/rows.dart';
import 'package:jet_cad_2d_plan/src/chrome/segmented.dart';
import 'package:jet_cad_2d_plan/src/chrome/select.dart';
import 'package:jet_cad_2d_plan/src/chrome/shad_scope.dart';
import 'package:jet_cad_2d_plan/src/chrome/text_field.dart';
import 'package:jet_cad_2d_plan/src/chrome/words_carrier.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Widget _host(Widget child, {ThemeData? theme}) => MaterialApp(
      theme: theme,
      home: Scaffold(
        body: PlanShadScope(
          child: PlanHostSlot(
              child: Align(alignment: Alignment.topLeft, child: child)),
        ),
      ),
    );

Widget _box(Widget child) => SizedBox(width: 280, child: child);

Future<void> _mouseClick(WidgetTester tester, Finder finder) async {
  final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await g.addPointer(location: tester.getCenter(finder));
  await g.down(tester.getCenter(finder));
  await tester.pump();
  await g.up();
  await tester.pump();
  await g.removePointer();
}

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  group('PlanTextField', () {
    testWidgets(
        'CP1 two PlanTextFields: tapping the second does not call the '
        "first's onTapOutside", (tester) async {
      var outsideA = 0;
      await tester.pumpWidget(_host(_box(Column(children: [
        PlanTextField(
            key: const Key('a'),
            controller: TextEditingController(text: 'one'),
            onTapOutside: (_) => outsideA++),
        PlanTextField(
            key: const Key('b'),
            controller: TextEditingController(text: 'two')),
      ]))));
      await tester.tap(find.byKey(const Key('a')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('b')));
      await tester.pump();
      expect(outsideA, 0);
    });

    testWidgets('CP2 tapping outside both calls it once', (tester) async {
      var outsideA = 0;
      await tester.pumpWidget(_host(Column(children: [
        _box(PlanTextField(
            key: const Key('a'),
            controller: TextEditingController(text: 'one'),
            onTapOutside: (_) => outsideA++)),
        _box(PlanTextField(
            key: const Key('b'),
            controller: TextEditingController(text: 'two'))),
        const SizedBox(key: Key('elsewhere'), width: 50, height: 50),
      ])));
      await tester.tap(find.byKey(const Key('a')));
      await tester.pump();
      await tester.tapAt(const Offset(700, 500));
      await tester.pump();
      expect(outsideA, 1);
    });

    testWidgets(
        'CP3 a readOnly field: focusable, its text selectable and copyable, '
        'typing changes nothing; readOnly set while focused keeps the focus; '
        'editable again, typing edits', (tester) async {
      final controller = TextEditingController(text: 'hello world');
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      var changes = 0;
      Widget field({required bool readOnly}) => _host(_box(PlanTextField(
          controller: controller,
          focusNode: focus,
          readOnly: readOnly,
          onChanged: (_) => changes++)));

      await tester.pumpWidget(field(readOnly: true));
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      expect(focus.hasFocus, isTrue, reason: 'focusable');

      // Selectable and copyable: the clipboard holds the selection.
      controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 5);
      await tester.pump();
      String? clipboard = 'before';
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String?;
        } else if (call.method == 'Clipboard.getData') {
          return <String, Object?>{'text': clipboard};
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      tester
          .state<EditableTextState>(find.byType(EditableText))
          .copySelection(SelectionChangedCause.keyboard);
      expect(clipboard, 'hello');
      expect(controller.selection,
          const TextSelection(baseOffset: 0, extentOffset: 5));

      // Not editable: typed text, a backspace and a cut change nothing.
      await tester.enterText(find.byType(EditableText), 'typed');
      await tester.pump();
      expect(controller.text, 'hello world');
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(controller.text, 'hello world');
      expect(changes, 0);
      // Its toolbar offers copy and no cut or paste.
      tester.state<EditableTextState>(find.byType(EditableText)).showToolbar();
      await tester.pump();
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Cut'), findsNothing);
      expect(find.text('Paste'), findsNothing);
      tester.state<EditableTextState>(find.byType(EditableText)).hideToolbar();
      await tester.pump();

      // editable -> readOnly while focused keeps the focus ...
      await tester.pumpWidget(field(readOnly: false));
      await tester.pumpWidget(field(readOnly: true));
      expect(focus.hasFocus, isTrue);
      // ... and back to editable: typing edits.
      await tester.pumpWidget(field(readOnly: false));
      expect(focus.hasFocus, isTrue);
      await tester.enterText(find.byType(EditableText), 'edited');
      await tester.pump();
      expect(controller.text, 'edited');
      expect(changes, 1);
    });
  });

  group('PlanSelect', () {
    List<PlanOption<String>> options() =>
        const [PlanOption('a', 'Alpha'), PlanOption('b', 'Beta')];

    testWidgets(
        'CP4 a PlanSelect whose onChanged refuses shows the old option after '
        'the pick', (tester) async {
      await tester.pumpWidget(_host(_box(PlanSelect<String>(
          value: 'a', options: options(), onChanged: (_) {}))));
      expect(find.text('Alpha'), findsOneWidget);
      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beta'));
      await tester.pumpAndSettle();
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsNothing);
    });

    testWidgets(
        'a PlanSelect closed by Escape gives the focus to its focusNode; '
        'expanded, it fills the width it is given', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(_host(_box(PlanSelect<String>(
          value: 'a',
          options: options(),
          expanded: true,
          focusNode: node,
          onChanged: (_) {}))));
      final trigger = find.byType(ShadSelect<String>);
      expect(tester.getSize(trigger).width, 280);
      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      expect(find.text('Beta'), findsOneWidget);
      expect(node.hasFocus, isFalse, reason: 'premise: the popover has it');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Beta'), findsNothing);
      expect(node.hasFocus, isTrue);
    });

    testWidgets('CP5 a PlanSelect rebuilt with a new value shows it',
        (tester) async {
      Widget select(String v) => _host(_box(
          PlanSelect<String>(value: v, options: options(), onChanged: (_) {})));
      await tester.pumpWidget(select('a'));
      expect(find.text('Alpha'), findsOneWidget);
      await tester.pumpWidget(select('b'));
      await tester.pump();
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('Alpha'), findsNothing);
      await tester.pumpWidget(select('a'));
      await tester.pump();
      expect(find.text('Alpha'), findsOneWidget);
    });

    testWidgets('a pick that the model takes shows the new option',
        (tester) async {
      var value = 'a';
      await tester.pumpWidget(StatefulBuilder(
          builder: (context, set) => _host(_box(PlanSelect<String>(
              value: value,
              options: options(),
              onChanged: (v) => set(() => value = v))))));
      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beta'));
      await tester.pumpAndSettle();
      expect(value, 'b');
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('Alpha'), findsNothing);
    });

    testWidgets(
        'CP9 flipping the ancestor ShadTheme to dark with the select open: '
        'no exception, the open popover is the dark one', (tester) async {
      Widget app(Brightness b) => MaterialApp(
            home: ShadTheme(
              data: ShadThemeData(
                  brightness: b,
                  colorScheme: b == Brightness.dark
                      ? const ShadSlateColorScheme.dark()
                      : const ShadSlateColorScheme.light()),
              child: ShadMouseAreaSurface(
                child: ShadMouseCursorProvider(
                  child: Scaffold(
                    body: PlanShadScope(
                      child: PlanHostSlot(
                        child: Align(
                            alignment: Alignment.topLeft,
                            child: _box(PlanSelect<String>(
                                value: 'a',
                                options: options(),
                                onChanged: (_) {}))),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
      await tester.pumpWidget(app(Brightness.light));
      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      expect(find.text('Beta'), findsOneWidget);
      await tester.pumpWidget(app(Brightness.dark));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final popover = find.ancestor(
          of: find.text('Beta'), matching: find.byType(DecoratedBox));
      final fills = tester
          .widgetList<DecoratedBox>(popover)
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.color)
          .whereType<Color>();
      expect(fills, contains(const ShadSlateColorScheme.dark().popover));
      expect(
          fills, isNot(contains(const ShadSlateColorScheme.light().popover)));
    });
  });

  group('PlanMenuButton', () {
    Widget menu({
      List<PlanMenuEntry<String>> Function()? entries,
      ValueChanged<String>? onSelected,
      String? selected,
    }) =>
        _host(_box(Row(children: [
          const PlanIconButton(
              key: Key('before'), icon: LucideIcons.plus, label: 'Before'),
          PlanMenuButton<String>(
            key: const Key('menu'),
            icon: LucideIcons.ellipsis,
            label: 'More',
            selected: selected,
            entries: entries ??
                () => const [
                      PlanMenuEntry('one', 'Item one', key: Key('e-one')),
                      PlanMenuEntry('two', 'Item two'),
                    ],
            onSelected: onSelected ?? (_) {},
          ),
        ])));

    testWidgets(
        'CP6 opens on a primary mouse click on desktop and on a tap on '
        'Android; Enter on the focused trigger opens it; Escape closes it '
        'and the trigger has focus', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      await tester.pumpWidget(menu());
      expect(find.text('Item one'), findsNothing);
      await _mouseClick(tester, find.byKey(const Key('menu')));
      await tester.pumpAndSettle();
      expect(find.text('Item one'), findsOneWidget, reason: 'mouse click');
      // An outside tap closes it.
      await tester.tapAt(const Offset(700, 500));
      await tester.pumpAndSettle();
      expect(find.text('Item one'), findsNothing);

      // Keyboard: focus the trigger by Tab from the button before it.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Item one'), findsOneWidget, reason: 'Enter');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Item one'), findsNothing);
      final focused = FocusManager.instance.primaryFocus;
      expect(
          focused?.context
              ?.findAncestorWidgetOfExactType<PlanMenuButton<String>>(),
          isNotNull,
          reason: 'the trigger has the focus');

      // Space opens it too.
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.text('Item one'), findsOneWidget, reason: 'Space');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.pumpWidget(menu());
      await tester.tap(find.byKey(const Key('menu')));
      await tester.pumpAndSettle();
      expect(find.text('Item one'), findsOneWidget, reason: 'tap on Android');
      // The framework checks this before the tearDown below runs.
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('an entry pick reports its value and closes the menu',
        (tester) async {
      final picked = <String>[];
      await tester.pumpWidget(menu(onSelected: picked.add, selected: 'two'));
      await tester.tap(find.byKey(const Key('menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('e-one')));
      await tester.pumpAndSettle();
      expect(picked, ['one']);
      expect(find.text('Item one'), findsNothing);
    });

    testWidgets('the selected entry is marked', (tester) async {
      await tester.pumpWidget(menu(selected: 'two'));
      await tester.tap(find.byKey(const Key('menu')));
      await tester.pumpAndSettle();
      final check = find.byIcon(LucideIcons.check);
      expect(check, findsOneWidget);
      expect(
          find.descendant(
              of: find.ancestor(of: check, matching: find.byType(Row)).first,
              matching: find.text('Item two')),
          findsOneWidget);
    });

    testWidgets(
        'CP8 an entry disabled by entries() while the menu is open becomes '
        'disabled without reopening', (tester) async {
      final allowed = ValueNotifier(true);
      addTearDown(allowed.dispose);
      final picked = <String>[];
      await tester.pumpWidget(ListenableBuilder(
          listenable: allowed,
          builder: (context, _) => _host(_box(PlanMenuButton<String>(
                key: const Key('menu'),
                icon: LucideIcons.ellipsis,
                label: 'More',
                entries: () => [
                  PlanMenuEntry('one', 'Item one',
                      enabled: allowed.value, key: const Key('e-one')),
                ],
                onSelected: picked.add,
              )))));
      await tester.tap(find.byKey(const Key('menu')));
      await tester.pumpAndSettle();
      ShadContextMenuItem item() =>
          tester.widget<ShadContextMenuItem>(find.byKey(const Key('e-one')));
      expect(item().enabled, isTrue);
      allowed.value = false;
      await tester.pump();
      expect(find.text('Item one'), findsOneWidget, reason: 'still open');
      expect(item().enabled, isFalse);
      await tester.tap(find.byKey(const Key('e-one')), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(picked, isEmpty);
    });
  });

  group('PlanIconButton', () {
    testWidgets(
        'CP7 Tab moves focus across a row of three PlanIconButtons; Space '
        'activates the focused one', (tester) async {
      final pressed = <int>[];
      await tester
          .pumpWidget(_host(Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < 3; i++)
          PlanIconButton(
              key: Key('b$i'),
              icon: LucideIcons.plus,
              label: 'Button $i',
              onPressed: () => pressed.add(i)),
      ])));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(pressed, [1]);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(pressed, [1, 2]);
    });

    testWidgets(
        'CP10 selected: true exposes a selected semantics node labelled '
        'label; selected: false does not', (tester) async {
      final handle = tester.ensureSemantics();
      Widget button(bool? selected) => _host(PlanIconButton(
          key: const Key('btn'),
          icon: LucideIcons.plus,
          label: 'Wall',
          selected: selected,
          onPressed: () {}));
      await tester.pumpWidget(button(true));
      var node = tester.getSemantics(find.bySemanticsLabel('Wall'));
      expect(node.flagsCollection.isSelected, Tristate.isTrue);
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.label, 'Wall');
      await tester.pumpWidget(button(false));
      node = tester.getSemantics(find.bySemanticsLabel('Wall'));
      expect(node.flagsCollection.isSelected, Tristate.isFalse);
      await tester.pumpWidget(button(null));
      node = tester.getSemantics(find.bySemanticsLabel('Wall'));
      expect(node.flagsCollection.isSelected, Tristate.none);
      handle.dispose();
    });

    testWidgets('a button without onPressed is not enabled in semantics',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(const PlanIconButton(
          key: Key('btn'), icon: LucideIcons.plus, label: 'Wall')));
      final node = tester.getSemantics(find.bySemanticsLabel('Wall'));
      expect(node.flagsCollection.isEnabled, Tristate.isFalse);
      handle.dispose();
    });
  });

  group('PlanSegmented and rows', () {
    testWidgets('a segment pick reports its value; the value is the authority',
        (tester) async {
      final picked = <String>[];
      await tester.pumpWidget(_host(PlanSegmented<String>(
          value: 'a',
          segments: const [
            PlanSegment('a', 'Alpha', key: Key('s-a')),
            PlanSegment('b', 'Beta', key: Key('s-b')),
          ],
          onChanged: picked.add)));
      await tester.tap(find.byKey(const Key('s-b')));
      await tester.pump();
      expect(picked, ['b']);
      // Refused: still Alpha selected.
      final handle = tester.ensureSemantics();
      expect(
          tester
              .getSemantics(find.byKey(const Key('s-a')))
              .flagsCollection
              .isSelected,
          Tristate.isTrue);
      expect(
          tester
              .getSemantics(find.byKey(const Key('s-b')))
              .flagsCollection
              .isSelected,
          Tristate.isFalse);
      handle.dispose();
    });

    testWidgets('check, switch and list rows activate from the keyboard',
        (tester) async {
      var checked = false, on = false, taps = 0;
      await tester.pumpWidget(StatefulBuilder(
          builder: (context, set) => _host(_box(Column(children: [
                PlanCheckRow(
                    key: const Key('check'),
                    label: 'Check',
                    value: checked,
                    onChanged: (v) => set(() => checked = v)),
                PlanSwitchRow(
                    key: const Key('switch'),
                    label: 'Switch',
                    value: on,
                    onChanged: (v) => set(() => on = v)),
                PlanListRow(
                    key: const Key('list'),
                    title: const Text('Row'),
                    selected: true,
                    onTap: () => taps++),
              ])))));
      await tester.tap(find.byKey(const Key('check')));
      await tester.tap(find.byKey(const Key('switch')));
      await tester.tap(find.byKey(const Key('list')));
      await tester.pump();
      expect([checked, on, taps], [true, true, 1]);
      final handle = tester.ensureSemantics();
      final list = tester.getSemantics(find.byKey(const Key('list')));
      expect(list.flagsCollection.isButton, isTrue);
      expect(list.flagsCollection.isSelected, Tristate.isTrue);
      // Tab to the list row, Enter and Space both activate.
      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(taps, 3);
      handle.dispose();
    });

    testWidgets('PlanReadOnlyField shows its label and child', (tester) async {
      await tester.pumpWidget(_host(
          _box(const PlanReadOnlyField(label: 'Layer', child: Text('Walls')))));
      expect(find.text('Layer'), findsOneWidget);
      expect(find.text('Walls'), findsOneWidget);
    });
  });

  testWidgets(
      'CP11 every part\'s visibleWords lists its label, tooltip, placeholder, '
      'error and every entry/option label', (tester) async {
    final parts = <PlanWordsCarrier>[
      const PlanIconButton(
          icon: LucideIcons.plus, label: 'Add', tooltip: 'Add a wall'),
      const PlanIconButton(icon: LucideIcons.plus, label: 'Same'),
      PlanTextField(
          controller: TextEditingController(),
          label: 'Width',
          suffix: 'mm',
          placeholder: 'Type',
          errorText: 'Too big'),
      PlanSelect<int>(
          value: 1,
          label: 'Kind',
          placeholder: 'Pick',
          options: const [PlanOption(1, 'One'), PlanOption(2, 'Two')],
          onChanged: (_) {}),
      PlanSegmented<int>(
          value: 1,
          segments: const [PlanSegment(1, 'Left'), PlanSegment(2, 'Right')],
          onChanged: (_) {}),
      PlanMenuButton<int>(
          icon: LucideIcons.ellipsis,
          label: 'More',
          entries: () =>
              const [PlanMenuEntry(1, 'Rename'), PlanMenuEntry(2, 'Delete')],
          onSelected: (_) {}),
      const PlanCheckRow(label: 'Locked', value: false),
      const PlanSwitchRow(label: 'Visible', value: true),
      const PlanReadOnlyField(label: 'Fixed', child: SizedBox()),
    ];
    final words = [for (final p in parts) p.visibleWords.toSet()];
    expect(words[0], {'Add', 'Add a wall'});
    expect(words[1], {'Same'});
    expect(words[2], {'Width', 'mm', 'Type', 'Too big'});
    expect(words[3], {'Kind', 'Pick', 'One', 'Two'});
    expect(words[4], {'Left', 'Right'});
    expect(words[5], {'More', 'Rename', 'Delete'});
    expect(words[6], {'Locked'});
    expect(words[7], {'Visible'});
    expect(words[8], {'Fixed'});
  });
}
