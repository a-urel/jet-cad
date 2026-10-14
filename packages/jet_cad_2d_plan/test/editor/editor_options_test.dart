// 2a spec P2: PlanEditor's options (which panels show, the gallery, the
// canvas's rulers, grid and snapping) and `controller.permissions` read at
// each build (Task 12 sent the widget-level capability cases here).
// Ported, assertions unchanged, from jet_cad_floor_plan/test/host/
// editor_panels_test.dart (T5-g, the focus order, R-2, R-3's editLayers,
// R-4's Page panel alone, V-5's generic parts), editor_tools_test.dart
// (T4-e, T4-j's readOnly half, T4-f's first part, snapping false keeps
// the user's setting, T4-g's first part, K3's design half) and
// editor_tools_review_test.dart (RV8, RV9, O23, R-2's tool part-way). A
// widget flag of today's capabilities is the editor's option here, the
// host rebuilding its editor; an editing flag is `c.permissions`. The
// floor planner's tools and tables are the generic tools and the marks of
// the editor's fixture; screen points come from the camera's forward
// transform.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show
        InteractionLayer,
        RulerFrame,
        SelectionKey,
        ViewportTransform,
        kRulerThickness;
import 'package:jet_cad_2d_plan/src/controller/permissions.dart';
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:jet_cad_2d_plan/src/editor/plan_editor.dart';
import 'package:jet_cad_2d_plan/src/panels/plan_property_panel.dart';
import 'package:jet_cad_2d_plan/src/tools/generic_tools.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/editor_host.dart';
import '../support/mark_kit.dart';

/// The editor's options a host rebuilds it with (today's widget flags).
final class Options {
  const Options({
    this.propertyPanel = true,
    this.layerPanel = true,
    this.pagePanel = true,
    this.rulers = true,
    this.grid = true,
    this.snapping = true,
    this.gallery = true,
  });

  final bool propertyPanel, layerPanel, pagePanel, rulers, grid, snapping;
  final bool gallery;

  Options copyWith(
          {bool? propertyPanel,
          bool? layerPanel,
          bool? pagePanel,
          bool? rulers,
          bool? grid,
          bool? snapping}) =>
      Options(
          propertyPanel: propertyPanel ?? this.propertyPanel,
          layerPanel: layerPanel ?? this.layerPanel,
          pagePanel: pagePanel ?? this.pagePanel,
          rulers: rulers ?? this.rulers,
          grid: grid ?? this.grid,
          snapping: snapping ?? this.snapping,
          gallery: gallery);
}

/// The palette's letters, the host binds each above the editor.
const List<(String, LogicalKeyboardKey)> kLetters = [
  (PlanToolIds.select, LogicalKeyboardKey.keyV),
  (PlanToolIds.line, LogicalKeyboardKey.keyL),
  (PlanToolIds.polyline, LogicalKeyboardKey.keyP),
  (PlanToolIds.rectangle, LogicalKeyboardKey.keyR),
  (PlanToolIds.circle, LogicalKeyboardKey.keyC),
  (PlanToolIds.arc, LogicalKeyboardKey.keyA),
  (PlanToolIds.text, LogicalKeyboardKey.keyT),
];

/// The keys the host binds above the editor, by name.
final Map<String, ShortcutActivator> kHostKeys = {
  for (final (id, key) in kLetters) id: SingleActivator(key),
  'fill': const SingleActivator(LogicalKeyboardKey.keyF),
  'f3': const SingleActivator(LogicalKeyboardKey.f3),
  'ctrl+e': const SingleActivator(LogicalKeyboardKey.keyE, control: true),
  'ctrl+z': const SingleActivator(LogicalKeyboardKey.keyZ, control: true),
};

final class OptionsHost {
  OptionsHost(this.c, Options options) : options = ValueNotifier(options);

  final PlanController c;
  final ValueNotifier<Options> options;

  /// The keys that reached the host's bindings, by name.
  final Map<String, int> reached = {for (final k in kHostKeys.keys) k: 0};

  /// The host's export dialog's calls.
  int dialogs = 0;
}

final GlobalKey shotKey = GlobalKey(debugLabel: 'editor-shot');

/// The surface of today's editor tests (`kEditorSurface`).
const Size kSurface = Size(2400, 1500);

/// A camera that frames the fixture's marks and line: 0.2 px/mm, y flipped,
/// the world point 4,500 mm left of and 3,200 mm above the sheet's centre at
/// the canvas's top left.
ViewportTransform workCamera(PlanController c) {
  final sheet = sheetWorldRect(c.page.value!);
  final cx = (sheet.minX + sheet.maxX) / 2, cy = (sheet.minY + sheet.maxY) / 2;
  return ViewportTransform(
      worldToScreenMatrix:
          Transform2(0.2, 0, 0, -0.2, -0.2 * (cx - 4500), 0.2 * (cy + 3200)));
}

Future<OptionsHost> mountOptions(WidgetTester tester,
    {Options options = const Options(),
    PlanPermissions permissions = PlanPermissions.full,
    String? json}) async {
  final c = editorController(json: json);
  c.permissions = permissions;
  final h = OptionsHost(c, options);
  addTearDown(h.options.dispose);
  await tester.binding.setSurfaceSize(kSurface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: CallbackShortcuts(
    bindings: {
      for (final MapEntry(:key, :value) in kHostKeys.entries)
        value: () => h.reached[key] = h.reached[key]! + 1,
    },
    child: RepaintBoundary(
      key: shotKey,
      child: ValueListenableBuilder<Options>(
          valueListenable: h.options,
          builder: (_, o, __) => PlanEditor(
              controller: c,
              propertyPanel: o.propertyPanel,
              layerPanel: o.layerPanel,
              pagePanel: o.pagePanel,
              rulers: o.rulers,
              grid: o.grid,
              snapping: o.snapping,
              gallery: o.gallery,
              onExport: (_) {},
              onExportDialog: (_, __, ___) async {
                h.dialogs++;
                return null;
              })),
    ),
  ))));
  await tester.pump();
  await tester.pump();
  c.camera.value = workCamera(c);
  await tester.pump();
  return h;
}

/// The host sets new permissions, as `setCaps` set new capabilities.
Future<void> setPermissions(
    WidgetTester tester, OptionsHost h, PlanPermissions p) async {
  h.c.permissions = p;
  await tester.pump();
  await tester.pump();
}

/// The host rebuilds its editor with [o].
Future<void> setOptions(WidgetTester tester, OptionsHost h, Options o) async {
  h.options.value = o;
  await tester.pump();
  await tester.pump();
}

String encoded(PlanController c) =>
    DraftDocumentCodec.encodeToString(c.document);

/// The shown canvas's top left, global.
Offset canvasOrigin(WidgetTester tester) =>
    tester.getTopLeft(find.byType(InteractionLayer));

/// World [w] on the screen, by the camera's forward transform.
Offset screenOf(WidgetTester tester, PlanController c, Vector2 w) {
  final p = c.camera.value.worldToScreen(w);
  return canvasOrigin(tester) + Offset(p.x, p.y);
}

/// Whether the primary focus is the canvas's (inside its interaction
/// layer).
bool canvasFocused() {
  final context = FocusManager.instance.primaryFocus?.context;
  return context != null &&
      context.findAncestorWidgetOfExactType<InteractionLayer>() != null;
}

Future<bool> press(WidgetTester tester, LogicalKeyboardKey key) async {
  final handled = await tester.sendKeyEvent(key);
  await tester.pump();
  return handled;
}

/// Ctrl+[key], pressed and released.
Future<void> ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

/// A mouse click at [at], with a hover first (the placement tools read it).
Future<void> click(WidgetTester tester, Offset at) async {
  final g = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
  await g.addPointer(location: at - const Offset(3, 3));
  await g.moveTo(at);
  await tester.pump();
  await g.down(at);
  await tester.pump();
  await g.up();
  await tester.pump();
  await g.removePointer();
  await tester.pump();
}

/// A mouse drag from [from] to [to] in eight steps.
Future<void> drag(WidgetTester tester, Offset from, Offset to) async {
  final g = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
  await g.addPointer(location: from - const Offset(2, 2));
  await g.moveTo(from);
  await tester.pump();
  await g.down(from);
  await tester.pump();
  for (var i = 1; i <= 8; i++) {
    await g.moveTo(Offset.lerp(from, to, i / 8)!);
    await tester.pump();
  }
  await g.up();
  await tester.pump();
  await g.removePointer();
  await tester.pump();
}

String statusText(WidgetTester tester) =>
    tester.widget<Text>(byKey('status-text')).data!;

/// The newest root-level line of the plan: its two ends, world.
(Vector2, Vector2) newestLine(DraftDocument d) {
  final e = d.entities;
  final slot = e.liveSlots
      .where(
          (s) => e.kindAt(s) == EntityKind.line && e.ownerAt(s) == d.rootHandle)
      .reduce((a, b) => e.handleAt(a).value > e.handleAt(b).value ? a : b);
  final p = d.geometry.read(e.geomIndexAt(slot)).coords;
  return (Vector2(p[0], p[1]), Vector2(p[2], p[3]));
}

/// The plan's marks, in the order the fixture made them.
List<Handle> marksOf(PlanController c) =>
    c.catalog.objectsOf<MarkCross>(c.document);

/// The world point of mark [h] at its local ([x], [y]).
Vector2 onMark(PlanController c, Handle h, double x, double y) =>
    (c.document.tree[h]! as GroupNode).transform.transformPoint(Vector2(x, y));

/// The first mark's half-size (the fixture's 700.5).
double sizeOf(PlanController c, Handle h) =>
    c.document.components.get<MarkCross>(h)!.size;

/// The panel field [key]'s widget.
TextField fieldOf(WidgetTester tester, String key) =>
    tester.widget<TextField>(byKey(key));

/// Whether [finder]'s `IconButton` is enabled.
bool iconEnabled(WidgetTester tester, Finder finder) =>
    tester.widget<IconButton>(finder).onPressed != null;

/// The plan's page.
PageComponent pageOf(DraftDocument d) =>
    d.components.get<PageComponent>(d.rootHandle)!;

/// Captures the editor.
Future<(ByteData, int)> shoot(WidgetTester tester) async {
  final boundary =
      shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final width = image.width;
    image.dispose();
    return (raw!, width);
  }))!;
}

/// The distinct colours of the global rect [r] of [shot].
Set<int> coloursIn((ByteData, int) shot, Rect r, Offset shotOrigin) {
  final (bytes, width) = shot;
  final colours = <int>{};
  for (var y = (r.top - shotOrigin.dy).ceil();
      y < (r.bottom - shotOrigin.dy).floor();
      y++) {
    for (var x = (r.left - shotOrigin.dx).ceil();
        x < (r.right - shotOrigin.dx).floor();
        x++) {
      colours.add(bytes.getUint32((y * width + x) * 4));
    }
  }
  return colours;
}

/// Draws a line with L, two clicks and two Escapes.
Future<void> drawLine(
    WidgetTester tester, PlanController c, Vector2 from, Vector2 to) async {
  await press(tester, LogicalKeyboardKey.keyL);
  await click(tester, screenOf(tester, c, from));
  await click(tester, screenOf(tester, c, to));
  await press(tester, LogicalKeyboardKey.escape);
  await press(tester, LogicalKeyboardKey.escape);
}

/// A free spot of the sheet, left of the first mark.
Vector2 freeSpot(PlanController c, double dx, double dy) {
  final sheet = sheetWorldRect(c.page.value!);
  final cx = (sheet.minX + sheet.maxX) / 2, cy = (sheet.minY + sheet.maxY) / 2;
  return Vector2(cx - 4000.5 + dx, cy + 2600.25 + dy);
}

bool undoEnabled(WidgetTester tester) =>
    tester.widget<IconButton>(byKey('toolbar-undo')).onPressed != null;

void main() {
  group('readOnly (V-5)', () {
    testWidgets(
        'no command reaches the document from a pointer path or a key: a '
        'body drag, the line\'s end grips, Delete and Backspace, the '
        'letters and Ctrl+Z leave the plan byte-identical', (tester) async {
      final h =
          await mountOptions(tester, permissions: PlanPermissions.readOnly);
      final c = h.c;
      final d = c.document;
      final before = encoded(c);
      Offset at(Vector2 w) => screenOf(tester, c, w);
      // The first mark: clicked on its body, dragged, deleted.
      final mark = marksOf(c).first;
      final s = sizeOf(c, mark);
      final body = onMark(c, mark, s / 2, s / 2);
      await click(tester, at(body));
      expect({...c.selection.keys}, {SelectionKey.root(mark)});
      await drag(tester, at(body), at(body) + const Offset(90, 45));
      await click(tester, at(body));
      await press(tester, LogicalKeyboardKey.delete);
      await press(tester, LogicalKeyboardKey.backspace);
      // The free line: its body and both ends.
      final (a, b) = newestLine(d);
      await click(tester, at((a + b) / 2));
      expect(c.selection.keys, hasLength(1));
      for (final end in [a, b, (a + b) / 2]) {
        await drag(tester, at(end), at(end) + const Offset(50, -30));
      }
      await press(tester, LogicalKeyboardKey.delete);
      // The letters and the history's chords.
      for (final k in [
        LogicalKeyboardKey.keyP,
        LogicalKeyboardKey.keyL,
        LogicalKeyboardKey.keyF,
      ]) {
        await press(tester, k);
      }
      await ctrl(tester, LogicalKeyboardKey.keyZ);
      expect(c.activeTool.value, PlanToolIds.select);
      expect(encoded(c), before);
      expect(c.canUndo.value, isFalse);
    });
  });

  group('the Layer and Page panels, the right column (S-9 e, S-11)', () {
    testWidgets(
        'T5-g layerPanel false: no Layers section; pagePanel false: no page '
        'controls; propertyPanel false: no property panel; all three '
        'false: no right column. The Layers section\'s open state is kept '
        'across hide and show', (tester) async {
      final h = await mountOptions(tester);
      final c = h.c;
      c.selection.replace([SelectionKey.root(marksOf(c).first)]);
      await tester.pump();
      expect(find.byType(PlanPropertyPanel), findsOneWidget);
      expect(byKey('layers-panel'), findsOneWidget);
      expect(byKey('page-preset'), findsOneWidget);
      // Closed by the user.
      await tester.tap(byKey('layers-header'));
      await tester.pump();
      expect(byKey('layers-list'), findsNothing);
      await setOptions(tester, h, const Options(layerPanel: false));
      expect(byKey('layers-panel'), findsNothing);
      expect(byKey('page-preset'), findsOneWidget);
      await setOptions(tester, h, const Options(pagePanel: false));
      expect(byKey('layers-panel'), findsOneWidget);
      expect(byKey('layers-list'), findsNothing, reason: 'still closed');
      expect(byKey('page-preset'), findsNothing);
      await setOptions(tester, h, const Options(propertyPanel: false));
      expect(find.byType(PlanPropertyPanel), findsNothing);
      expect(find.byType(PlanPropertyPanel), findsNothing);
      expect(byKey('chrome-right'), findsOneWidget);
      await setOptions(
          tester,
          h,
          const Options(
              propertyPanel: false, layerPanel: false, pagePanel: false));
      expect(byKey('chrome-right'), findsNothing);
      await setOptions(tester, h, const Options());
      expect(find.byType(PlanPropertyPanel), findsOneWidget);
      expect(byKey('chrome-right'), findsOneWidget);
    });

    testWidgets(
        'a hidden panel is out of the focus order: the page scale focused, '
        'then pagePanel false, it has the focus no more; shown again, its '
        'value is the page\'s', (tester) async {
      final h = await mountOptions(tester);
      await tester.tap(byKey('page-scale'));
      await tester.pump();
      final node = fieldOf(tester, 'page-scale').focusNode!;
      expect(node.hasFocus, isTrue);
      await setOptions(tester, h, const Options(pagePanel: false));
      expect(node.hasFocus, isFalse);
      await setOptions(tester, h, const Options());
      expect(fieldOf(tester, 'page-scale').focusNode, same(node),
          reason: 'the same field, kept');
    });

    testWidgets(
        'T5-g editLayers false: + and a row\'s every control disabled, the '
        'list shown; editPage false: every page control disabled, the '
        'values shown; true again: enabled', (tester) async {
      final h = await mountOptions(tester,
          json: editorPlanJson(lockedLayer: true),
          permissions: PlanPermissions.full
              .copyWith(editLayers: false, editPage: false));
      final c = h.c;
      final d = c.document;
      // The locked layer: visible and not current, so each of its controls
      // is enabled under full.
      final locked = d.tables.layers.records
          .firstWhere((r) => r.name == kEditorLocked)
          .handle
          .toHex();
      expect(byKey('layers-list'), findsOneWidget);
      expect(iconEnabled(tester, byKey('layers-add')), isFalse);
      for (final k in ['layer-eye-', 'layer-lock-', 'layer-current-']) {
        expect(iconEnabled(tester, byKey('$k$locked')), isFalse, reason: k);
      }
      expect(
          tester
              .widget<PopupMenuButton<int>>(byKey('layer-colour-$locked'))
              .enabled,
          isFalse);
      void pageControls(bool enabled) {
        expect(
            tester
                    .widget<DropdownButton<SheetSize?>>(byKey('page-preset'))
                    .onChanged !=
                null,
            enabled,
            reason: 'preset');
        expect(
            tester
                    .widget<SegmentedButton<PageOrientation>>(find.ancestor(
                        of: byKey('page-orientation-portrait'),
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
                    .widget<DropdownButton<DisplayUnit>>(byKey('page-unit'))
                    .onChanged !=
                null,
            enabled,
            reason: 'unit');
        expect(
            tester
                    .widget<SegmentedButton<DecimalSeparator>>(
                        byKey('page-decimal-separator'))
                    .onSelectionChanged !=
                null,
            enabled,
            reason: 'separator');
        for (final k in ['page-grid', 'page-snap', 'page-breaks']) {
          expect(tester.widget<CheckboxListTile>(byKey(k)).onChanged != null,
              enabled,
              reason: k);
        }
        for (var i = 0; i < 4; i++) {
          expect(tester.widget<InkWell>(byKey('page-swatch-$i')).onTap != null,
              enabled,
              reason: 'swatch $i');
        }
      }

      pageControls(false);
      final before = encoded(c);
      await tester.tap(byKey('page-swatch-3'));
      await tester.tap(byKey('page-grid'));
      await tester.tap(byKey('layer-eye-$locked'));
      await tester.pump();
      expect(encoded(c), before);
      await setPermissions(tester, h, PlanPermissions.full);
      pageControls(true);
      expect(iconEnabled(tester, byKey('layers-add')), isTrue);
      expect(iconEnabled(tester, byKey('layer-eye-$locked')), isTrue);
    });

    String lockedLayer(PlanController c) => c.document.tables.layers.records
        .firstWhere((r) => r.name == kEditorLocked)
        .handle
        .toHex();

    for (final (name, target) in [
      ('readOnly', PlanPermissions.readOnly),
      (
        'full.copyWith(editLayers: false)',
        PlanPermissions.full.copyWith(editLayers: false)
      ),
      ('no switch (the control)', null),
    ]) {
      testWidgets(
          'R-2 a layer\'s colour menu opened under full, then $name, a '
          'colour chosen: ${target == null ? 'it recolours' : 'nothing'}',
          (tester) async {
        final h =
            await mountOptions(tester, json: editorPlanJson(lockedLayer: true));
        final c = h.c;
        final locked = lockedLayer(c);
        await tester.tap(byKey('layer-colour-$locked'));
        await tester.pumpAndSettle();
        final before = encoded(c);
        if (target != null) await setPermissions(tester, h, target);
        await tester.pump();
        final item = byKey('layer-colour-item-1');
        expect(item, findsWidgets, reason: 'the menu is still open');
        await tester.tap(item.last);
        await tester.pumpAndSettle();
        if (target == null) {
          expect(encoded(c), isNot(before));
        } else {
          expect(encoded(c), before);
          expect(c.canUndo.value, isFalse);
        }
      });
    }

    testWidgets(
        'R-3 editLayers false alone: the Layer panel disabled, the Page '
        'panel enabled; editPage false alone: the reverse', (tester) async {
      final h = await mountOptions(tester,
          json: editorPlanJson(lockedLayer: true),
          permissions: PlanPermissions.full.copyWith(editLayers: false));
      final c = h.c;
      final locked = lockedLayer(c);
      bool pageEnabled() =>
          tester
              .widget<DropdownButton<SheetSize?>>(byKey('page-preset'))
              .onChanged !=
          null;
      bool layersEnabled() =>
          iconEnabled(tester, byKey('layers-add')) &&
          iconEnabled(tester, byKey('layer-eye-$locked'));
      expect(layersEnabled(), isFalse);
      expect(pageEnabled(), isTrue);
      await setPermissions(
          tester, h, PlanPermissions.full.copyWith(editPage: false));
      expect(layersEnabled(), isTrue);
      expect(pageEnabled(), isFalse);
    });

    testWidgets(
        'R-4 the Page panel alone: with propertyPanel and layerPanel false, '
        'the right column holds the page controls', (tester) async {
      await mountOptions(tester,
          options: const Options(propertyPanel: false, layerPanel: false));
      expect(byKey('chrome-right'), findsOneWidget);
      expect(byKey('page-preset'), findsOneWidget);
      expect(find.byType(PlanPropertyPanel), findsNothing);
      expect(byKey('layers-panel'), findsNothing);
    });
  });

  group('the bar and the left column', () {
    testWidgets(
        'T4-e full.copyWith(export: false, undo: false): no Export, Undo or '
        'Redo button, Ctrl+E and Ctrl+Z reach the host; full at runtime: '
        'both shown and bound', (tester) async {
      final h = await mountOptions(tester,
          permissions:
              PlanPermissions.full.copyWith(export: false, undo: false));
      for (final k in ['toolbar-export', 'toolbar-undo', 'toolbar-redo']) {
        expect(byKey(k), findsNothing, reason: k);
      }
      expect(byKey('toolbar-print'), findsOneWidget);
      expect(canvasFocused(), isTrue);
      await ctrl(tester, LogicalKeyboardKey.keyE);
      await ctrl(tester, LogicalKeyboardKey.keyZ);
      expect(h.reached['ctrl+e'], 1);
      expect(h.reached['ctrl+z'], 1);
      expect(h.dialogs, 0);

      h.c.permissions = PlanPermissions.full;
      await tester.pump();
      // M-ED-13: the Export command ignores `permissions.export`.
      for (final k in ['toolbar-export', 'toolbar-undo', 'toolbar-redo']) {
        expect(byKey(k), findsOneWidget, reason: k);
      }
      await ctrl(tester, LogicalKeyboardKey.keyE);
      await tester.pump();
      await ctrl(tester, LogicalKeyboardKey.keyZ);
      expect(h.reached['ctrl+e'], 1);
      expect(h.reached['ctrl+z'], 1);
      expect(h.dialogs, 1);
    });

    testWidgets(
        'T4-j readOnly: no left column, and the canvas origin 240 px to the '
        'left; full.copyWith(editLayers: false): the column', (tester) async {
      final h = await mountOptions(tester);
      final full = canvasOrigin(tester);
      await setPermissions(tester, h, PlanPermissions.readOnly);
      // M-ED-12: `_leftShown` answers true.
      expect(byKey('chrome-left'), findsNothing);
      expect(canvasOrigin(tester), full - const Offset(240, 0));
      await setPermissions(
          tester, h, PlanPermissions.full.copyWith(editLayers: false));
      expect(byKey('chrome-left'), findsOneWidget);
      expect(canvasOrigin(tester), full);
    });

    testWidgets('RV8 tools {select, symbol} with gallery false: no left column',
        (tester) async {
      await mountOptions(tester,
          options: const Options(gallery: false),
          permissions: const PlanPermissions(
              tools: {PlanToolIds.select, PlanToolIds.symbol}));
      expect(byKey('chrome-left'), findsNothing);
    });

    testWidgets(
        'RV9 print and undo false: no Print, no Undo or Redo; Ctrl+Z '
        'reaches the host and undoes nothing', (tester) async {
      final h = await mountOptions(tester,
          permissions:
              PlanPermissions.full.copyWith(print: false, undo: false));
      expect(byKey('toolbar-print'), findsNothing);
      expect(byKey('toolbar-export'), findsOneWidget);
      expect(byKey('toolbar-undo'), findsNothing);
      expect(byKey('toolbar-redo'), findsNothing);
      final d = h.c.document;
      final depth = d.commands.undoDepth;
      await drawLine(
          tester, h.c, freeSpot(h.c, 0, 0), freeSpot(h.c, 800.5, -300.25));
      expect(d.commands.undoDepth, depth + 1);
      await ctrl(tester, LogicalKeyboardKey.keyZ);
      expect(d.commands.undoDepth, depth + 1);
      expect(h.reached['ctrl+z'], 1);
    });

    testWidgets(
        'O23 every command refused: no toolbar, and the status line starts '
        'at the bar\'s padding', (tester) async {
      await mountOptions(tester,
          permissions: PlanPermissions.full
              .copyWith(export: false, print: false, undo: false));
      expect(
          find.byWidgetPredicate((w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('toolbar-')),
          findsNothing);
      expect(tester.getTopLeft(byKey('status-text')).dx,
          tester.getTopLeft(byKey('chrome-top')).dx + 12);
    });
  });

  group('snapping, rulers and grid', () {
    testWidgets(
        'T4-f snapping false: no OSNAP, F3 reaches the host, and a line '
        'drawn from within the aperture of the first mark\'s end starts at '
        'the grid point of the raw one; snapping true: it starts at the end',
        (tester) async {
      final h =
          await mountOptions(tester, options: const Options(snapping: false));
      final c = h.c;
      expect(byKey('osnap-text'), findsNothing);
      await press(tester, LogicalKeyboardKey.f3);
      expect(h.reached['f3'], 1);

      // The end of the mark's first generated line, (s, s) in its frame;
      // the raw point a few pixels off it: inside the 10 px aperture.
      final mark = marksOf(c).first;
      final s = sizeOf(c, mark);
      final corner = onMark(c, mark, s, s);
      final raw = Vector2(corner.x - 12, corner.y - 8);
      Future<Vector2> drawFrom() async {
        await press(tester, LogicalKeyboardKey.keyL);
        await click(tester, screenOf(tester, c, raw));
        await click(tester,
            screenOf(tester, c, Vector2(corner.x - 600, corner.y + 1000)));
        await press(tester, LogicalKeyboardKey.escape);
        await press(tester, LogicalKeyboardKey.escape);
        return newestLine(c.document).$1;
      }

      final page = pageOf(c.document);
      final step = dragGridStepMm(page, c.camera.value.scale)!;
      final grid = Vector2(
          page.originX + ((raw.x - page.originX) / step).round() * step,
          page.originY + ((raw.y - page.originY) / step).round() * step);
      final off = await drawFrom();
      expect(off.x, closeTo(grid.x, 1e-6));
      expect(off.y, closeTo(grid.y, 1e-6));
      expect(off.distanceTo(corner), greaterThan(1));

      await setOptions(tester, h, const Options());
      expect(byKey('osnap-text'), findsOneWidget);
      final on = await drawFrom();
      expect(on.x, closeTo(corner.x, 1e-6));
      expect(on.y, closeTo(corner.y, 1e-6));
    });

    testWidgets(
        'snapping false keeps the user\'s setting: F3 off under full, '
        'snapping false and back, still off', (tester) async {
      final h = await mountOptions(tester);
      final on = tester.widget<Text>(byKey('osnap-text')).data;
      await press(tester, LogicalKeyboardKey.f3);
      final off = tester.widget<Text>(byKey('osnap-text')).data;
      expect(off, isNot(on));
      h.options.value = const Options(snapping: false);
      await tester.pump();
      h.options.value = const Options();
      await tester.pump();
      expect(tester.widget<Text>(byKey('osnap-text')).data, off);
    });

    testWidgets(
        'T4-g rulers and grid false: no RulerFrame, no grid pixel on the '
        'sheet; rulers toggled at runtime: the canvas origin moves by the '
        'rulers\' thickness and back', (tester) async {
      final h = await mountOptions(tester);
      final c = h.c;
      // The sheet's top above the drawing (y -27,000 to the page's top,
      // -25,700): the grid, nothing drafted.
      final page = pageOf(c.document);
      expect(c.document.extents.maxY, lessThan(-27000));
      expect(page.originY + page.effectiveHeightMm * page.scaleDenominator,
          greaterThan(-25800));
      c.camera.value = ViewportTransform(
          worldToScreenMatrix:
              Transform2(0.37, 0, 0, -0.37, -0.37 * 39000, 0.37 * -25600));
      await tester.pump();
      Rect sheet() => Rect.fromPoints(
          screenOf(tester, c, Vector2(39500, -25750)),
          screenOf(tester, c, Vector2(41300, -26200)));
      final origin = tester.getTopLeft(find.byKey(shotKey));
      final withGrid = coloursIn(await shoot(tester), sheet(), origin);
      expect(withGrid.length, greaterThan(1));

      h.options.value = const Options(rulers: false, grid: false);
      await tester.pump();
      await tester.pump();
      expect(find.byType(RulerFrame), findsNothing);
      final without = coloursIn(await shoot(tester), sheet(), origin);
      expect(without, hasLength(1));

      h.options.value = const Options();
      await tester.pump();
      await tester.pump();
      final ruled = canvasOrigin(tester);
      h.options.value = const Options(rulers: false);
      await tester.pump();
      await tester.pump();
      expect(canvasOrigin(tester),
          ruled - const Offset(kRulerThickness, kRulerThickness));
      h.options.value = const Options();
      await tester.pump();
      await tester.pump();
      expect(find.byType(RulerFrame), findsOneWidget);
      expect(canvasOrigin(tester), ruled);
    });

    testWidgets(
        'R-2 a polyline part-way: rulers off and on throw nothing; the '
        'polyline is cancelled cleanly and Undo enabled after the frame; the '
        'tool starts afresh', (tester) async {
      final h = await mountOptions(tester);
      final c = h.c;
      final d = c.document;
      await drawLine(tester, c, freeSpot(c, 0, 0), freeSpot(c, 800.5, -300.25));
      await press(tester, LogicalKeyboardKey.keyP);
      final first = freeSpot(c, 200.5, -900.75);
      await click(tester, screenOf(tester, c, first));
      expect(undoEnabled(tester), isFalse, reason: 'premise: mid-shape');
      final depth = d.commands.undoDepth;
      for (final rulers in [false, true]) {
        h.options.value = Options(rulers: rulers);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'rulers $rulers');
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'rulers $rulers');
        expect(undoEnabled(tester), isTrue, reason: 'rulers $rulers');
        expect(c.activeTool.value, PlanToolIds.polyline);
        expect(statusText(tester), 'Polyline');
        // A fresh start: one click is a first point, nothing added.
        await click(tester, screenOf(tester, c, first));
        expect(d.commands.undoDepth, depth, reason: 'rulers $rulers');
        expect(undoEnabled(tester), isFalse);
      }
      await click(tester, screenOf(tester, c, freeSpot(c, 1000.25, -900.75)));
      await press(tester, LogicalKeyboardKey.enter);
      expect(d.commands.undoDepth, depth + 1);
    });
  });

  testWidgets(
      'K3 (final review F-6, mutant S26) after a load, selectTool and '
      'deleteSelection reach the new plan: the old one\'s withdrawal leaves '
      'its registrations', (tester) async {
    final h = await mountOptions(tester);
    final c = h.c;
    c.load(c.save());
    await tester.pump();
    await tester.pump();
    expect(c.selectTool(PlanToolIds.line), isTrue);
    await tester.pump();
    expect(c.activeTool.value, PlanToolIds.line);
    expect(c.selectTool(PlanToolIds.select), isTrue);
    await tester.pump();
    final first = marksOf(c).first;
    c.selection.replace([SelectionKey.root(first)]);
    await tester.pump();
    final n = marksOf(c).length;
    expect(c.deleteSelection(), isTrue);
    await tester.pump();
    expect(marksOf(c).length, n - 1);
    expect(marksOf(c), isNot(contains(first)));
  });
}
