// Cameras, gestures and read-outs for the integration tests (3a Task 26),
// beside Task 9's editor_rig.dart (re-exported: activeTool, globalOf with
// x and y, globalAt with a point, kitCatalog, press, pumpEditor, status),
// over the public widgets: today's PlannerView handles (its camera, its
// selection, its tools) are the controller's camera and selection and the
// InteractionLayer's tool controller (spec C6, ruling IT-R1). The rig's
// helpers are never copied (R-P14): [pumpPlanEditor] and [pressKey] are
// thin delegates under the names today's tests call.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show GripCache, InteractionLayer, ViewportTransform;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'editor_rig.dart' show press, pumpEditor;

export 'editor_rig.dart'
    show activeTool, globalAt, globalOf, kitCatalog, press, pumpEditor, status;

Finder byKey(String k) => find.byKey(Key(k));

/// One field whatever its scope: the object's `property-<id>` or the
/// active tool's `setting-<id>` (today's shell keyed both alike; ruling
/// IT-R7).
Finder field(String id) => find.byWidgetPredicate(
    (w) => w.key == Key('property-$id') || w.key == Key('setting-$id'));

/// The section of [typeId] or the settings of [toolId] (today's
/// `<type>-section`, shown for the object and for its tool).
Finder sectionFinder(String typeId, String toolId) => find.byWidgetPredicate(
    (w) => w.key == Key('section-$typeId') || w.key == Key('settings-$toolId'));

/// Lets [c]'s symbol libraries load (Task 23's furniture): frames and
/// short real waits, at most 400 rounds; returns whether the state is
/// ready. Bounded, it never sleeps on: a library that never loads fails
/// the caller's next expectation.
Future<bool> symbolsReady(WidgetTester tester, PlanController c) async {
  for (var i = 0; i < 400 && c.symbolsState.value != SymbolsState.ready; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  return c.symbolsState.value == SymbolsState.ready;
}

/// [c] in its editor in a [size] window, in [locale], two frames: the rig's
/// [pumpEditor] and one more frame.
Future<void> pumpPlanEditor(WidgetTester tester, PlanController c,
    {Size size = const Size(1440, 900),
    Locale locale = const Locale('en')}) async {
  await pumpEditor(tester, c, locale: locale, window: size);
  await tester.pump();
}

/// The camera on world [centre] at [scale] px/mm, y up, turned [turn]
/// radians on the screen; set after the editor's first fit.
Future<void> frameOn(WidgetTester tester, PlanController c, Vector2 centre,
    {required double scale, double turn = 0}) async {
  final size = tester.getSize(find.byType(InteractionLayer));
  final linear =
      Transform2.rotation(turn).multiply(Transform2.scale(scale, -scale));
  final mid = linear.transformPoint(centre);
  c.camera.value = ViewportTransform(
      worldToScreenMatrix: Transform2.translation(
              size.width / 2 - mid.x, size.height / 2 - mid.y)
          .multiply(linear));
  await tester.pump();
}

/// The selection's grips and box: the cache the plan hands its tools in
/// their context (`InteractionLayer.tools.context.grips`; ruling IT-R12).
GripCache gripsOf(WidgetTester tester) => tester
    .widget<InteractionLayer>(find.byType(InteractionLayer))
    .tools
    .context
    .grips!;

/// The editor's spatial index: the one the plan hands its tools in their
/// context (`InteractionLayer.tools.context.index`; today's `view.index`).
/// A document drives one index (the engine's mutation hook is a single
/// slot), so a test reads the editor's rather than making a second.
SpatialIndex indexOf(WidgetTester tester) => tester
    .widget<InteractionLayer>(find.byType(InteractionLayer))
    .tools
    .context
    .index;

/// A key press and a pump; whether a handler took it: the rig's [press]
/// under today's name.
Future<bool> pressKey(WidgetTester tester, LogicalKeyboardKey key) =>
    press(tester, key);

/// A mouse resting at [at], then a press and a release there.
Future<void> mouseClick(WidgetTester tester, Offset at) async {
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

/// The canvas's own focus node.
FocusNode canvasFocus(WidgetTester tester) => tester
    .widget<Focus>(find
        .descendant(
            of: find.byType(InteractionLayer), matching: find.byType(Focus))
        .first)
    .focusNode!;

/// A click a little inside the canvas's top left: the canvas takes focus.
Future<void> focusCanvas(WidgetTester tester) async {
  await tester.tapAt(
      tester.getTopLeft(find.byType(InteractionLayer)) + const Offset(6, 6));
  await tester.pump();
  expect(FocusManager.instance.primaryFocus, same(canvasFocus(tester)),
      reason: 'premise: the canvas focused');
}

/// Whether the canvas (or a node under it) has the focus.
bool canvasFocused() {
  final context = FocusManager.instance.primaryFocus?.context;
  return context != null &&
      context.findAncestorWidgetOfExactType<InteractionLayer>() != null;
}

/// The menu of the choice [id] opened and its value [segment] tapped (a
/// `ChoiceProperty` is a dropdown; ruling IT-R6). Nothing when the menu
/// does not open (a disabled choice): today's tap on a disabled segment.
Future<void> choose(WidgetTester tester, String id, String segment) async {
  final menu = field(id);
  final key = (tester.widget(menu).key! as ValueKey<String>).value;
  await tester.tap(menu);
  await tester.pumpAndSettle();
  final item = byKey('$key-$segment');
  if (item.evaluate().isEmpty) return;
  await tester.tap(item.last);
  await tester.pumpAndSettle();
}

/// The choice [id]'s dropdown.
DropdownButton<Object?> menuOf(WidgetTester tester, String id) =>
    tester.widget<DropdownButton<Object?>>(field(id));
