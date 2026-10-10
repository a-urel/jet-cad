// Host embedding API spec C-5's panels (Slice 4 plan, Task 5; S-9 d e,
// S-10, S-11, C-8, V-5): every Selection panel field and button by its
// flag, the layer picker, the Layer and Page panels shown and edited by
// theirs, a hidden panel kept offstage with its state, `readOnly` letting
// nothing edit through the UI while the host's own calls still work, and
// `tablesOnly` hiding the Material menus. Through `FloorPlanView` on the
// editor fixture under `editorCamera()`, with `editor_tools_test.dart`'s
// host and helpers; screen points come from the camera's forward
// transform.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_floor_plan/editor.dart'
    show
        DimKind,
        DimensionParams,
        Justification,
        OpeningKind,
        OpeningParams,
        RoomParams,
        WallParams,
        liveObjectsOf;
import 'package:jet_cad_floor_plan/jet_cad_floor_plan.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_library_state.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_placer.dart';
import 'package:jet_cad_floor_plan/src/tables/table_index.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'editor_fixture.dart';
import 'editor_select_test.dart' as s;
import 'editor_tools_test.dart' as t;

typedef Caps = FloorPlanEditorCapabilities;

/// The selection made by hand (a door is not on the screen).
Future<void> select(
    WidgetTester tester, FloorPlanController c, Handle h) async {
  c.activeSelection.replace([SelectionKey.root(h)]);
  await tester.pump();
}

/// The panel field [key]'s widget.
TextField fieldOf(WidgetTester tester, String key) =>
    tester.widget<TextField>(t.byKey(key));

/// Types [text] into the read-only field [key] the only way a test can --
/// into its controller, the field focused -- and leaves it: its focus-loss
/// commit runs.
Future<void> typeIntoReadOnly(
    WidgetTester tester, String key, String text) async {
  await tester.tap(t.byKey(key));
  await tester.pump();
  fieldOf(tester, key).controller!.text = text;
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
}

/// Types [text] into the field [key] and submits it.
Future<void> typeAndSubmit(WidgetTester tester, String key, String text) async {
  await tester.enterText(t.byKey(key), text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

/// Whether [finder]'s `IconButton` is enabled.
bool iconEnabled(WidgetTester tester, Finder finder) =>
    tester.widget<IconButton>(finder).onPressed != null;

/// The Material menus under the view (C-8): a dropdown, a popup menu
/// button or a menu anchor, on the stage.
Finder menusUnder() => find.descendant(
    of: find.byType(FloorPlanView),
    matching: find.byWidgetPredicate(
        (w) => w is DropdownButton || w is PopupMenuButton || w is MenuAnchor));

/// The first wall, room, dimension and door of the design.
Handle firstOf<T extends Component>(DraftDocument d) =>
    liveObjectsOf<T>(d).first;

Handle doorOf(DraftDocument d) => liveObjectsOf<OpeningParams>(d).firstWhere(
    (o) => d.components.get<OpeningParams>(o)!.kind == OpeningKind.door);

void main() {
  group('the Selection panel by its flags (S-10, S-11)', () {
    testWidgets(
        'M-H43 1 selected: no Mirror under tablesOnly; Mirror under full. '
        'M-H43b no layer picker under tablesOnly or readOnly; the picker '
        'under full', (tester) async {
      final h = await t.mountEditor(tester);
      final c = h.c;
      await select(tester, c, s.tableOf(c, '1'));
      expect(t.byKey('symbol-mirror'), findsOneWidget);
      expect(t.byKey('layer-picker'), findsOneWidget);
      await s.setCaps(tester, h, Caps.tablesOnly);
      expect(t.byKey('table-section'), findsOneWidget);
      expect(t.byKey('symbol-mirror'), findsNothing);
      expect(t.byKey('layer-picker'), findsNothing);
      await s.setCaps(tester, h, Caps.readOnly);
      expect(t.byKey('table-section'), findsOneWidget);
      expect(t.byKey('layer-picker'), findsNothing);
      await s.setCaps(tester, h, Caps.full);
      expect(t.byKey('symbol-mirror'), findsOneWidget);
      expect(t.byKey('layer-picker'), findsOneWidget);
    });

    testWidgets(
        'tablesOnly, 1 selected: the number editable, ±90 shown and turning '
        'it, the Rotation field editable; T5-e readOnly: the number '
        'read-only and a typed 12 not committed; tablesOnly: committed',
        (tester) async {
      final h = await t.mountEditor(tester, caps: Caps.readOnly);
      final c = h.c;
      await select(tester, c, s.tableOf(c, '1'));
      expect(fieldOf(tester, 'table-number').readOnly, isTrue);
      final before = s.encoded(c);
      await typeIntoReadOnly(tester, 'table-number', '12');
      expect(s.encoded(c), before);
      expect(fieldOf(tester, 'table-number').controller!.text, '1');
      await s.setCaps(tester, h, Caps.tablesOnly);
      expect(fieldOf(tester, 'table-number').readOnly, isFalse);
      expect(fieldOf(tester, 'symbol-rotation').readOnly, isFalse);
      await typeAndSubmit(tester, 'table-number', '12');
      expect(TableSurvey.of(c.activeDocument).withNumber('12'), hasLength(1));
      final turn = s.degreesOf(s.transformOf(c, '12'));
      await tester.tap(t.byKey('table-rotate-left'));
      await tester.pump();
      expect(s.degreesOf(s.transformOf(c, '12')), closeTo(turn + 90, 1e-6));
      await typeAndSubmit(tester, 'symbol-rotation', '45');
      expect(s.degreesOf(s.transformOf(c, '12')), closeTo(45, 1e-6));
    });

    testWidgets(
        'T5-f full.copyWith(reshape: false): a wall\'s thickness read-only '
        '(a typed value not committed) and its justification disabled; a '
        'door\'s flips absent and its width read-only; a room\'s name '
        'read-only; the dimension kind disabled; the Size menu absent while '
        'Mirror stays; under full each edits', (tester) async {
      final h =
          await t.mountEditor(tester, caps: Caps.full.copyWith(reshape: false));
      final c = h.c;
      final d = c.activeDocument;
      final before = s.encoded(c);
      // The wall.
      final wall = firstOf<WallParams>(d);
      await select(tester, c, wall);
      expect(fieldOf(tester, 'wall-thickness').readOnly, isTrue);
      await typeIntoReadOnly(tester, 'wall-thickness', '300');
      expect(s.encoded(c), before);
      expect(
          tester
              .widget<SegmentedButton<Justification>>(
                  t.byKey('wall-justification'))
              .onSelectionChanged,
          isNull);
      // The door.
      final door = doorOf(d);
      await select(tester, c, door);
      expect(t.byKey('opening-section'), findsOneWidget);
      expect(t.byKey('opening-flip-hinge'), findsNothing);
      expect(t.byKey('opening-flip-swing'), findsNothing);
      expect(fieldOf(tester, 'opening-width').readOnly, isTrue);
      expect(fieldOf(tester, 'opening-position').readOnly, isTrue);
      // The room.
      await select(tester, c, firstOf<RoomParams>(d));
      expect(fieldOf(tester, 'room-name').readOnly, isTrue);
      // The dimension.
      final dim = firstOf<DimensionParams>(d);
      await select(tester, c, dim);
      expect(
          tester
              .widget<SegmentedButton<DimKind>>(t.byKey('dimension-kind'))
              .onSelectionChanged,
          isNull);
      // A symbol with a family: the Size menu.
      await t.librarySettled(tester, c);
      final library = (c.symbols.state as SymbolLibraryReady).library;
      final sofa = library.entries.firstWhere((e) => e.key == 'sofa.two');
      d.commands.execute(placeSymbol(d, sofa,
          at: Vector2(24600, 13600),
          transform: const Transform2(1, 0, 0, 1, 24600, 13600),
          numbered: false));
      final placed = d.tree.nodes.whereType<InstanceNode>().last.handle;
      await select(tester, c, placed);
      expect(t.byKey('symbol-section'), findsOneWidget);
      expect(t.byKey('symbol-size-menu'), findsNothing);
      expect(t.byKey('symbol-mirror'), findsOneWidget);
      final placedState = s.encoded(c);
      // Under full each edits.
      await s.setCaps(tester, h, Caps.full);
      expect(t.byKey('symbol-size-menu'), findsOneWidget);
      await select(tester, c, wall);
      expect(fieldOf(tester, 'wall-thickness').readOnly, isFalse);
      await typeAndSubmit(tester, 'wall-thickness', '300');
      expect(d.components.get<WallParams>(wall)!.thickness, 300);
      expect(
          tester
              .widget<SegmentedButton<Justification>>(
                  t.byKey('wall-justification'))
              .onSelectionChanged,
          isNotNull);
      await select(tester, c, door);
      final hinge = d.components.get<OpeningParams>(door)!.hinge;
      await tester.tap(t.byKey('opening-flip-hinge'));
      await tester.pump();
      expect(d.components.get<OpeningParams>(door)!.hinge, isNot(hinge));
      await select(tester, c, dim);
      await tester.tap(t.byKey('dimension-vertical'));
      await tester.pump();
      expect(d.components.get<DimensionParams>(dim)!.kind, DimKind.vertical);
      expect(s.encoded(c), isNot(placedState));
    });

    testWidgets(
        'a tool\'s settings are no edit of the document: with the Wall tool '
        'active under full.copyWith(reshape: false), its thickness edits',
        (tester) async {
      final h =
          await t.mountEditor(tester, caps: Caps.full.copyWith(reshape: false));
      await t.press(tester, LogicalKeyboardKey.keyW);
      expect(h.c.activeTool.value, FloorPlanTool.wall);
      expect(fieldOf(tester, 'wall-thickness').readOnly, isFalse);
      expect(
          tester
              .widget<SegmentedButton<Justification>>(
                  t.byKey('wall-justification'))
              .onSelectionChanged,
          isNotNull);
    });
  });

  group('readOnly (V-5)', () {
    testWidgets(
        'a table, a wall, a room and a dimension are each selectable by a '
        'click, their sections read-only: no ±90, Mirror, flips or layer '
        'picker', (tester) async {
      final h = await t.mountEditor(tester, caps: Caps.readOnly);
      final c = h.c;
      Future<void> clickAt(Vector2 w) =>
          t.click(tester, t.screenOf(tester, c, w));
      await clickAt(s.edgeOf(c, '1'));
      expect(t.byKey('table-section'), findsOneWidget);
      expect(fieldOf(tester, 'table-number').readOnly, isTrue);
      expect(fieldOf(tester, 'symbol-rotation').readOnly, isTrue);
      for (final k in [
        'table-rotate-left',
        'table-rotate-right',
        'symbol-mirror',
        'layer-picker'
      ]) {
        expect(t.byKey(k), findsNothing, reason: k);
      }
      // The north wall, beyond its inner face.
      await clickAt(Vector2(25500, 16850));
      expect(t.byKey('wall-section'), findsOneWidget);
      expect(fieldOf(tester, 'wall-thickness').readOnly, isTrue);
      expect(
          tester
              .widget<SegmentedButton<Justification>>(
                  t.byKey('wall-justification'))
              .onSelectionChanged,
          isNull);
      // The living room, by its name label.
      await clickAt(Vector2(22857, 15478));
      expect(t.byKey('room-section'), findsOneWidget);
      expect(fieldOf(tester, 'room-name').readOnly, isTrue);
      // The overall depth, by its dimension line.
      await clickAt(Vector2(26300, 15000));
      expect(t.byKey('dimension-section'), findsOneWidget);
      expect(
          tester
              .widget<SegmentedButton<DimKind>>(t.byKey('dimension-kind'))
              .onSelectionChanged,
          isNull);
      // The east wall's window.
      await clickAt(Vector2(25875, 14200));
      expect(t.byKey('opening-section'), findsOneWidget);
      expect(fieldOf(tester, 'opening-width').readOnly, isTrue);
      expect(t.byKey('layer-picker'), findsNothing);
    });

    testWidgets(
        'no command reaches the document from a pointer path or a key: a '
        'body drag, the line\'s and the column\'s end grips, the rotation '
        'grip\'s place, Delete and Backspace, the letters and Ctrl+Z leave '
        'the design byte-identical', (tester) async {
      final h = await t.mountEditor(tester, caps: Caps.readOnly);
      final c = h.c;
      final d = c.activeDocument;
      final before = s.encoded(c);
      Offset at(Vector2 w) => t.screenOf(tester, c, w);
      // 1: clicked, dragged, its rotation grip's place dragged, deleted.
      await t.click(tester, at(s.edgeOf(c, '1')));
      expect(s.selected(c), {s.keyOf(c, '1')});
      await s.drag(tester, at(s.edgeOf(c, '1')),
          at(s.edgeOf(c, '1')) + const Offset(90, 45));
      await t.click(tester, at(s.edgeOf(c, '1')));
      final grip = s.rotationGripOf(tester, c, '1');
      await s.drag(tester, grip, grip + const Offset(120, 60));
      await t.click(tester, at(s.edgeOf(c, '1')));
      await t.press(tester, LogicalKeyboardKey.delete);
      await t.press(tester, LogicalKeyboardKey.backspace);
      // The free line: its body and both ends.
      final (a, b) = t.newestLine(d);
      await t.click(tester, at((a + b) / 2));
      expect(s.selected(c), hasLength(1));
      for (final end in [a, b, (a + b) / 2]) {
        await s.drag(tester, at(end), at(end) + const Offset(50, -30));
      }
      await t.press(tester, LogicalKeyboardKey.delete);
      // The column's end grip.
      final column = Vector2(23500, 14000);
      await t.click(tester, at(column));
      expect(s.selected(c), hasLength(1));
      await s.drag(tester, at(column), at(column) + const Offset(-60, 0));
      await t.press(tester, LogicalKeyboardKey.backspace);
      // The letters and the history's chords.
      for (final k in [
        LogicalKeyboardKey.keyW,
        LogicalKeyboardKey.keyL,
        LogicalKeyboardKey.keyF,
      ]) {
        await t.press(tester, k);
      }
      await t.ctrl(tester, LogicalKeyboardKey.keyZ);
      expect(c.activeTool.value, FloorPlanTool.select);
      expect(s.encoded(c), before);
      expect(c.canUndo.value, isFalse);
    });

    testWidgets(
        'the host\'s own calls still work under readOnly: setTableData, '
        'undo() and load', (tester) async {
      final h = await t.mountEditor(tester, caps: Caps.readOnly);
      final c = h.c;
      final before = s.encoded(c);
      expect(c.setTableData('2', const {'pos': 'b2'}), isTrue);
      expect(s.encoded(c), isNot(before));
      expect(c.canUndo.value, isTrue);
      c.undo();
      await tester.pump();
      expect(s.encoded(c), before);
      // A load replaces the plan, under readOnly too: 2's data, set again,
      // is gone with the plan it was set on.
      expect(c.setTableData('2', const {'pos': 'b2'}), isTrue);
      final dataOf2 =
          c.tableDetails.where((x) => x.table.number == '2').single.data;
      expect(dataOf2, const {'pos': 'b2'});
      c.load(editorPlanJson());
      await tester.pump();
      await tester.pump();
      expect(c.tableDetails.where((x) => x.table.number == '2').single.data,
          isEmpty);
      expect(c.canUndo.value, isFalse);
    });
  });

  group('the Layer and Page panels, the right column (S-9 e, S-11)', () {
    testWidgets(
        'T5-g layerPanel false: no Layers section; pagePanel false: no page '
        'controls; selectionPanel false: no Selection panel; all three '
        'false: no right column. The Layers section\'s open state is kept '
        'across hide and show', (tester) async {
      final h = await t.mountEditor(tester);
      final c = h.c;
      await select(tester, c, s.tableOf(c, '1'));
      expect(t.byKey('selection-panel'), findsOneWidget);
      expect(t.byKey('layers-panel'), findsOneWidget);
      expect(t.byKey('page-preset'), findsOneWidget);
      // Closed by the user.
      await tester.tap(t.byKey('layers-header'));
      await tester.pump();
      expect(t.byKey('layers-list'), findsNothing);
      await s.setCaps(tester, h, Caps.full.copyWith(layerPanel: false));
      expect(t.byKey('layers-panel'), findsNothing);
      expect(t.byKey('page-preset'), findsOneWidget);
      await s.setCaps(tester, h, Caps.full.copyWith(pagePanel: false));
      expect(t.byKey('layers-panel'), findsOneWidget);
      expect(t.byKey('layers-list'), findsNothing, reason: 'still closed');
      expect(t.byKey('page-preset'), findsNothing);
      await s.setCaps(tester, h, Caps.full.copyWith(selectionPanel: false));
      expect(t.byKey('selection-panel'), findsNothing);
      expect(t.byKey('table-section'), findsNothing);
      expect(t.byKey('chrome-right'), findsOneWidget);
      await s.setCaps(
          tester,
          h,
          Caps.full.copyWith(
              selectionPanel: false, layerPanel: false, pagePanel: false));
      expect(t.byKey('chrome-right'), findsNothing);
      await s.setCaps(tester, h, Caps.full);
      expect(t.byKey('selection-panel'), findsOneWidget);
      expect(t.byKey('chrome-right'), findsOneWidget);
    });

    testWidgets(
        'a hidden panel is out of the focus order: the page scale focused, '
        'then pagePanel false, it has the focus no more; shown again, its '
        'value is the page\'s', (tester) async {
      final h = await t.mountEditor(tester);
      await tester.tap(t.byKey('page-scale'));
      await tester.pump();
      final node = fieldOf(tester, 'page-scale').focusNode!;
      expect(node.hasFocus, isTrue);
      await s.setCaps(tester, h, Caps.full.copyWith(pagePanel: false));
      expect(node.hasFocus, isFalse);
      await s.setCaps(tester, h, Caps.full);
      expect(fieldOf(tester, 'page-scale').focusNode, same(node),
          reason: 'the same field, kept');
    });

    testWidgets(
        'T5-g editLayers false: + and a row\'s every control disabled, the '
        'list shown; editPage false: every page control disabled, the '
        'values shown; true again: enabled', (tester) async {
      final h = await t.mountEditor(tester,
          caps: Caps.full.copyWith(editLayers: false, editPage: false));
      final c = h.c;
      final d = c.activeDocument;
      // The locked layer: visible and not current, so each of its controls
      // is enabled under full.
      final locked = d.tables.layers.records
          .firstWhere((r) => r.name == kEmbeddingLocked)
          .handle
          .toHex();
      expect(t.byKey('layers-list'), findsOneWidget);
      expect(iconEnabled(tester, t.byKey('layers-add')), isFalse);
      for (final k in ['layer-eye-', 'layer-lock-', 'layer-current-']) {
        expect(iconEnabled(tester, t.byKey('$k$locked')), isFalse, reason: k);
      }
      expect(
          tester
              .widget<PopupMenuButton<int>>(t.byKey('layer-colour-$locked'))
              .enabled,
          isFalse);
      void pageControls(bool enabled) {
        expect(
            tester
                    .widget<DropdownButton<SheetSize?>>(t.byKey('page-preset'))
                    .onChanged !=
                null,
            enabled,
            reason: 'preset');
        expect(
            tester
                    .widget<SegmentedButton<PageOrientation>>(find.ancestor(
                        of: t.byKey('page-orientation-portrait'),
                        matching:
                            find.byType(SegmentedButton<PageOrientation>)))
                    .onSelectionChanged !=
                null,
            enabled,
            reason: 'orientation');
        expect(fieldOf(tester, 'page-scale').enabled ?? true, enabled,
            reason: 'scale');
        expect(
            tester
                    .widget<DropdownButton<DisplayUnit>>(t.byKey('page-unit'))
                    .onChanged !=
                null,
            enabled,
            reason: 'unit');
        expect(
            tester
                    .widget<SegmentedButton<DecimalSeparator>>(
                        t.byKey('page-decimal-separator'))
                    .onSelectionChanged !=
                null,
            enabled,
            reason: 'separator');
        for (final k in ['page-grid', 'page-snap', 'page-breaks']) {
          expect(tester.widget<CheckboxListTile>(t.byKey(k)).onChanged != null,
              enabled,
              reason: k);
        }
        for (var i = 0; i < 4; i++) {
          expect(
              tester.widget<InkWell>(t.byKey('page-swatch-$i')).onTap != null,
              enabled,
              reason: 'swatch $i');
        }
      }

      pageControls(false);
      final before = s.encoded(c);
      await tester.tap(t.byKey('page-swatch-3'));
      await tester.tap(t.byKey('page-grid'));
      await tester.tap(t.byKey('layer-eye-$locked'));
      await tester.pump();
      expect(s.encoded(c), before);
      await s.setCaps(tester, h, Caps.full);
      pageControls(true);
      expect(iconEnabled(tester, t.byKey('layers-add')), isTrue);
      expect(iconEnabled(tester, t.byKey('layer-eye-$locked')), isTrue);
    });
  });

  group('C-8', () {
    testWidgets(
        'T5-h tablesOnly, 1 selected: no dropdown, popup menu or menu '
        'anchor under the editor; under full there are', (tester) async {
      final h = await t.mountEditor(tester);
      final c = h.c;
      await select(tester, c, s.tableOf(c, '1'));
      expect(menusUnder(), findsWidgets, reason: 'under full');
      await s.setCaps(tester, h, Caps.tablesOnly);
      expect(t.byKey('table-rotate-left'), findsOneWidget);
      expect(menusUnder(), findsNothing);
    });

    testWidgets(
        'T5-h under a local Theme with a hand-built ColorScheme, tablesOnly, '
        '1 selected: the ±90 buttons\' foreground is that scheme\'s primary',
        (tester) async {
      // A host's own scheme, every role a colour no default has.
      const scheme = ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFF6A1B4D),
        onPrimary: Color(0xFFFDF2F8),
        secondary: Color(0xFF1B6A5A),
        onSecondary: Color(0xFFF2FDF9),
        error: Color(0xFFB3261F),
        onError: Color(0xFFFFFBF9),
        surface: Color(0xFFF7F3EA),
        onSurface: Color(0xFF221E14),
      );
      final c = FloorPlanController(json: editorPlanJson());
      addTearDown(c.dispose);
      await tester.binding.setSurfaceSize(kEditorSurface);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Theme(
                  data: ThemeData.from(colorScheme: scheme),
                  child: FloorPlanView(
                      controller: c,
                      onExport: (_) {},
                      editorCapabilities: Caps.tablesOnly)))));
      await tester.pump();
      await tester.pump();
      await select(tester, c, s.tableOf(c, '1'));
      for (final k in ['table-rotate-left', 'table-rotate-right']) {
        final icon =
            find.descendant(of: t.byKey(k), matching: find.byType(Icon));
        expect(IconTheme.of(tester.element(icon)).color, scheme.primary,
            reason: k);
      }
      expect(menusUnder(), findsNothing);
    });
  });

  group("the review's killers (Task 5 review R-2, R-3, R-4)", () {
    /// The locked layer's hex: visible and not current, so each of its
    /// controls is enabled under full.
    String lockedLayer(FloorPlanController c) =>
        c.activeDocument.tables.layers.records
            .firstWhere((r) => r.name == kEmbeddingLocked)
            .handle
            .toHex();

    for (final (name, target) in [
      ('readOnly', Caps.readOnly),
      ('tablesOnly', Caps.tablesOnly),
      ('no switch (the control)', null),
    ]) {
      testWidgets(
          'R-2 a layer\'s colour menu opened under full, then $name, a '
          'colour chosen: ${target == null ? 'it recolours' : 'nothing'}',
          (tester) async {
        final h = await t.mountEditor(tester);
        final c = h.c;
        final locked = lockedLayer(c);
        await tester.tap(t.byKey('layer-colour-$locked'));
        await tester.pumpAndSettle();
        final before = s.encoded(c);
        if (target != null) await s.setCaps(tester, h, target);
        await tester.pump();
        final item = t.byKey('layer-colour-item-1');
        expect(item, findsWidgets, reason: 'the menu is still open');
        await tester.tap(item.last);
        await tester.pumpAndSettle();
        if (target == null) {
          expect(s.encoded(c), isNot(before));
        } else {
          expect(s.encoded(c), before);
          expect(c.canUndo.value, isFalse);
        }
      });
    }

    testWidgets(
        'R-3 tablesOnly.copyWith(renumber: false), 1 selected: the number '
        'read-only and a typed 12 not committed, while ±90 turns 1 and the '
        'Rotation field commits', (tester) async {
      final h = await t.mountEditor(tester,
          caps: Caps.tablesOnly.copyWith(renumber: false));
      final c = h.c;
      await select(tester, c, s.tableOf(c, '1'));
      expect(fieldOf(tester, 'table-number').readOnly, isTrue);
      final before = s.encoded(c);
      await typeIntoReadOnly(tester, 'table-number', '12');
      expect(s.encoded(c), before);
      expect(TableSurvey.of(c.activeDocument).withNumber('12'), isEmpty);
      final turn = s.degreesOf(s.transformOf(c, '1'));
      expect(t.byKey('table-rotate-left'), findsOneWidget);
      await tester.tap(t.byKey('table-rotate-left'));
      await tester.pump();
      expect(s.degreesOf(s.transformOf(c, '1')), closeTo(turn + 90, 1e-6));
      expect(fieldOf(tester, 'symbol-rotation').readOnly, isFalse);
      await typeAndSubmit(tester, 'symbol-rotation', '45');
      expect(s.degreesOf(s.transformOf(c, '1')), closeTo(45, 1e-6));
    });

    testWidgets(
        'R-3 tablesOnly.copyWith(rotate: false), 1 selected: the number '
        'commits, while ±90 is absent and the Rotation field read-only (a '
        'typed value not committed)', (tester) async {
      final h = await t.mountEditor(tester,
          caps: Caps.tablesOnly.copyWith(rotate: false));
      final c = h.c;
      await select(tester, c, s.tableOf(c, '1'));
      expect(t.byKey('table-rotate-left'), findsNothing);
      expect(t.byKey('table-rotate-right'), findsNothing);
      expect(fieldOf(tester, 'symbol-rotation').readOnly, isTrue);
      final turn = s.degreesOf(s.transformOf(c, '1'));
      await typeIntoReadOnly(tester, 'symbol-rotation', '75');
      expect(s.degreesOf(s.transformOf(c, '1')), closeTo(turn, 1e-6));
      expect(fieldOf(tester, 'table-number').readOnly, isFalse);
      await typeAndSubmit(tester, 'table-number', '12');
      expect(TableSurvey.of(c.activeDocument).withNumber('12'), hasLength(1));
    });

    testWidgets(
        'R-3 full.copyWith(changeLayer: false): no layer picker for 1, while '
        'the wall\'s thickness edits; full.copyWith(reshape: false): the '
        'picker for 1, while the thickness is read-only', (tester) async {
      final h = await t.mountEditor(tester,
          caps: Caps.full.copyWith(changeLayer: false));
      final c = h.c;
      final d = c.activeDocument;
      await select(tester, c, s.tableOf(c, '1'));
      expect(t.byKey('layer-picker'), findsNothing);
      final wall = firstOf<WallParams>(d);
      await select(tester, c, wall);
      expect(fieldOf(tester, 'wall-thickness').readOnly, isFalse);
      await typeAndSubmit(tester, 'wall-thickness', '300');
      expect(d.components.get<WallParams>(wall)!.thickness, 300);
      await s.setCaps(tester, h, Caps.full.copyWith(reshape: false));
      await select(tester, c, s.tableOf(c, '1'));
      expect(t.byKey('layer-picker'), findsOneWidget);
      await select(tester, c, wall);
      expect(fieldOf(tester, 'wall-thickness').readOnly, isTrue);
    });

    testWidgets(
        'R-3 editLayers false alone: the Layer panel disabled, the Page '
        'panel enabled; editPage false alone: the reverse', (tester) async {
      final h = await t.mountEditor(tester,
          caps: Caps.full.copyWith(editLayers: false));
      final c = h.c;
      final locked = lockedLayer(c);
      bool pageEnabled() =>
          tester
              .widget<DropdownButton<SheetSize?>>(t.byKey('page-preset'))
              .onChanged !=
          null;
      bool layersEnabled() =>
          iconEnabled(tester, t.byKey('layers-add')) &&
          iconEnabled(tester, t.byKey('layer-eye-$locked'));
      expect(layersEnabled(), isFalse);
      expect(pageEnabled(), isTrue);
      await s.setCaps(tester, h, Caps.full.copyWith(editPage: false));
      expect(layersEnabled(), isTrue);
      expect(pageEnabled(), isFalse);
    });

    testWidgets(
        'R-4 a tool\'s settings are no edit: with the Door tool active under '
        'full.copyWith(reshape: false), its width edits the tool, not the '
        'design', (tester) async {
      final h =
          await t.mountEditor(tester, caps: Caps.full.copyWith(reshape: false));
      final c = h.c;
      await t.press(tester, LogicalKeyboardKey.keyD);
      expect(c.activeTool.value, FloorPlanTool.door);
      expect(fieldOf(tester, 'opening-width').readOnly, isFalse);
      final before = s.encoded(c);
      await typeAndSubmit(tester, 'opening-width', '1000');
      expect(fieldOf(tester, 'opening-width').controller!.text, '1000');
      expect(s.encoded(c), before);
    });

    testWidgets(
        'R-4 the Page panel alone: with selectionPanel and layerPanel false, '
        'the right column holds the page controls', (tester) async {
      await t.mountEditor(tester,
          caps: Caps.full.copyWith(selectionPanel: false, layerPanel: false));
      expect(t.byKey('chrome-right'), findsOneWidget);
      expect(t.byKey('page-preset'), findsOneWidget);
      expect(t.byKey('selection-panel'), findsNothing);
      expect(t.byKey('layers-panel'), findsNothing);
    });
  });
}
