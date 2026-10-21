// The app pumped with scripted files (spec 12a Testing, ported), and the
// moves the document tests share: reading the host, the controller and the
// session, and editing through the real tools. The one helper set for every
// app test (R-P14): no copies elsewhere.
import 'dart:convert';

import 'package:architecture_demo/document_host.dart';
import 'package:architecture_demo/document_session.dart';
import 'package:architecture_demo/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer, Tool, ViewportTransform;
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'app_fakes.dart';

/// Far from the origin and from the page, where the rig's edit lands: a
/// default of the plan's origin would hide a transform that is dropped.
final Vector2 kFar = Vector2(-43210.5, 31234.75);

/// The app, its host, controller, session and scripted files.
class AppRig {
  AppRig._(this.tester, this.files, this.guard);

  final WidgetTester tester;
  final FakeDocumentFiles files;
  final FakeExitGuard? guard;

  ArchitectureDemoAppState get app =>
      tester.state<ArchitectureDemoAppState>(find.byType(ArchitectureDemoApp));

  DocumentHostState get host =>
      tester.state<DocumentHostState>(find.byType(DocumentHost));

  PlanController get controller => app.controller;

  DocumentSession get session => app.session;

  /// One undoable edit through the controller's command path: a wall drawn
  /// by the Wall tool with pointer events and keys (W, two clicks, Enter,
  /// Escape) under a turned camera centred on [at], then Select again.
  /// `dirty` is true after it and the history has one more step.
  Future<void> editOnce({Vector2? at}) async {
    final c = at ?? kFar;
    await aimCamera(tester, controller, c);
    await drawWall(
        tester, controller, c + Vector2(-1500, 200), c + Vector2(1500, -300));
  }

  /// Taps the widget keyed [key], then one frame.
  Future<void> tapKey(String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pump();
  }
}

/// The app over [files] (and [guard], the platform's no-op when null) at a
/// 1440 x 900 surface; the rig.
Future<AppRig> pumpApp(WidgetTester tester,
    {FakeDocumentFiles? files,
    FakeExitGuard? guard,
    PagePrinter? printer,
    Size size = const Size(1440, 900),
    PlanEditorLayout? layout}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final fakeFiles = files ?? FakeDocumentFiles();
  await tester.pumpWidget(ArchitectureDemoApp(
      files: fakeFiles,
      exitGuard: guard,
      printer: printer ?? const PrintingPagePrinter(),
      layout: layout));
  await tester.pump();
  return AppRig._(tester, fakeFiles, guard);
}

/// The app's title, as `MaterialApp.onGenerateTitle` made it: the app's own
/// `Title`, the first under the `WidgetsApp`.
String titleOf(WidgetTester tester) => tester
    .widget<Title>(find
        .descendant(of: find.byType(WidgetsApp), matching: find.byType(Title))
        .first)
    .title;

/// The name widget's text.
String shownName(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('document-name'))).data!;

/// [c]'s live objects of [typeId] carrying a `T`, ascending by handle.
List<Handle> liveOf<T extends Component>(PlanController c, String typeId) => [
      for (final h in c.document.components.withComponent<T>())
        if (c.typeOf(h)?.id == typeId) h,
    ]..sort((a, b) => a.value.compareTo(b.value));

/// [c]'s walls, ascending.
List<Handle> wallsOf(PlanController c) =>
    liveOf<WallParams>(c, ArchitectureTypes.wall);

Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

Future<void> chord(WidgetTester tester, LogicalKeyboardKey modifier,
    LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(modifier);
  await press(tester, key);
  await tester.sendKeyUpEvent(modifier);
  await tester.pump();
}

/// Presses [key] with [modifier]; whether the key-down was handled (the
/// result of the key event, as the old app's `chordHandled`).
Future<bool> chordHandled(WidgetTester tester, LogicalKeyboardKey modifier,
    LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(modifier);
  final handled = await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(modifier);
  await tester.pump();
  return handled;
}

/// Cmd+Z: the editor's undo binding.
Future<void> undoKey(WidgetTester tester) =>
    chord(tester, LogicalKeyboardKey.meta, LogicalKeyboardKey.keyZ);

/// The global position of world [p] under [c]'s camera.
Offset globalOf(WidgetTester tester, PlanController c, Vector2 p) {
  final s = c.camera.value.worldToScreen(p);
  return tester.getTopLeft(find.byType(InteractionLayer)) + Offset(s.x, s.y);
}

Future<void> clickAt(WidgetTester tester, PlanController c, Vector2 p) async {
  await tester.tapAt(globalOf(tester, c, p));
  await tester.pump();
}

/// A rotated, non-reflecting camera at 0.1 px/mm centred on world [centre]:
/// the drawing can sit far from the origin and off the page.
Future<void> aimCamera(
    WidgetTester tester, PlanController c, Vector2 centre) async {
  final size = tester.getSize(find.byType(InteractionLayer));
  final linear = Transform2.rotation(0.3).multiply(Transform2.scale(0.1, 0.1));
  final mid = linear.transformPoint(centre);
  c.camera.value = ViewportTransform(
      worldToScreenMatrix: Transform2.translation(
              size.width / 2 - mid.x, size.height / 2 - mid.y)
          .multiply(linear));
  await tester.pump();
}

/// The canvas's active tool, as its interaction layer holds it
/// (`PlanController.toolController` is internal to the library).
Tool activeTool(WidgetTester tester) =>
    tester.widget<InteractionLayer>(find.byType(InteractionLayer)).tools.active;

/// One wall from [a] to [b] through the Wall tool (W, two clicks, Enter),
/// then Escape to Select: an edit through a real tool, the shape ended.
Future<void> drawWall(
    WidgetTester tester, PlanController c, Vector2 a, Vector2 b) async {
  await press(tester, LogicalKeyboardKey.keyW);
  await clickAt(tester, c, a);
  await clickAt(tester, c, b);
  await press(tester, LogicalKeyboardKey.enter);
  await press(tester, LogicalKeyboardKey.escape);
  expect(activeTool(tester).isMidShape, isFalse,
      reason: 'premise: the shape is ended');
}

/// Answers the Save / Don't Save / Cancel dialog with the button keyed
/// [key]: `replace-save`, `replace-discard` or `replace-cancel`. The dialog
/// must be up.
Future<void> answerReplace(WidgetTester tester, String key) async {
  expect(find.byKey(const Key('replace-dialog')), findsOneWidget,
      reason: 'premise: the dialog is up');
  await tester.tap(find.byKey(Key(key)));
  await tester.pump();
  await tester.pump();
}

/// Fails, rather than waits forever, while a flow's dialog is still up:
/// called before awaiting a flow that should have finished.
void noDialog(WidgetTester tester) {
  expect(find.byKey(const Key('replace-dialog')), findsNothing,
      reason: 'no Save / Don\'t Save / Cancel dialog left');
  expect(find.byKey(const Key('document-error')), findsNothing,
      reason: 'no error dialog left');
}

/// Runs [flow] (New, Open or Open sample) from a dirty plan and answers its
/// dialog with Don't Save.
Future<void> discardAndRun(WidgetTester tester, Future<void> flow) async {
  await tester.pump();
  await answerReplace(tester, 'replace-discard');
  noDialog(tester);
  await flow;
  await tester.pump();
}

/// Taps the error dialog's OK.
Future<void> dismissError(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('document-error-ok')));
  await tester.pump();
  await tester.pump();
}

/// The sample flat's text, saved by a controller of its own (disposed at
/// tear-down): what Open sample must produce, computed apart from the app.
String sampleText() {
  final c = PlanController(kits: [architectureKit]);
  addTearDown(c.dispose);
  c.newPlan(build: buildSampleFlat);
  return c.save();
}

/// The sample's bytes.
List<int> sampleBytes() => utf8.encode(sampleText());

/// [c]'s plan as the bytes a Save writes.
List<int> bytesOf(PlanController c) => utf8.encode(c.save());

/// Whether the focused node is a panel field (the type is the library's
/// own and not exported).
bool panelFieldFocused() =>
    FocusManager.instance.primaryFocus.runtimeType.toString() ==
    'PanelFieldFocusNode';

/// [group]'s children, ascending.
List<Handle> kidsOf(DraftDocument doc, Handle group) => [
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.ownerAt(slot) == group) doc.entities.handleAt(slot),
    ]..sort((a, b) => a.value.compareTo(b.value));

/// [room]'s TEXT children's strings, ascending: its name label, then its
/// area label.
List<String> roomLabels(DraftDocument doc, Handle room) => [
      for (final k in kidsOf(doc, room))
        if (doc.entities.kindAt(doc.entities.slotOf(k)!) == EntityKind.text)
          doc.entities.textAt(doc.entities.slotOf(k)!),
    ];

/// Dimension [d]'s value string: its one TEXT child's.
String dimensionText(DraftDocument doc, Handle d) => [
      for (final k in kidsOf(doc, d))
        if (doc.entities.kindAt(doc.entities.slotOf(k)!) == EntityKind.text)
          doc.entities.textAt(doc.entities.slotOf(k)!),
    ].single;

/// The middle of wall [h], in the world (through its group's transform).
Vector2 wallMid(PlanController c, Handle h) {
  final w = c.document.components.get<WallParams>(h)!;
  return c.document.tree
      .accumulatedTransform(h)
      .transformPoint(Vector2((w.sx + w.ex) / 2, (w.sy + w.ey) / 2));
}

/// How many live objects of [typeId] the plan holds, whatever their
/// component class.
int liveOfAny(PlanController c, String typeId) => [
      for (final h in c.document.tree.nodes)
        if (c.typeOf(h.handle)?.id == typeId) h,
    ].length;

/// The plan titled and dirty with history, on [rig]: the sample opened from
/// `[name].jetplan` at [location] (the plan must be clean on entry, so the
/// Open asks nothing), then a wall drawn through the Wall tool around [at]
/// (far from the origin by default) under a rotated camera, the shape
/// ended: one more step of history, dirty.
Future<void> titledDirty(AppRig rig,
    {String name = 'plan', Object? location = '/p/plan', Vector2? at}) async {
  final c = rig.controller;
  expect(c.dirty.value, isFalse, reason: 'premise: Open asks nothing');
  rig.files.scriptOpen(
      name: '$name.jetplan', bytes: sampleBytes(), location: location);
  await rig.host.openFlow();
  await rig.tester.pump();
  final depth = c.document.commands.undoDepth;
  final p = at ?? kFar;
  await aimCamera(rig.tester, c, p);
  await drawWall(
      rig.tester, c, p + Vector2(-1600, 250), p + Vector2(1400, -450));
  expect(c.document.commands.undoDepth, depth + 1, reason: 'premise: an edit');
  expect(c.dirty.value, isTrue, reason: 'premise: dirty');
  expect((
    rig.session.name,
    rig.session.fileName,
    rig.session.location
  ), (
    name,
    '$name.jetplan',
    location
  ), reason: 'premise: titled');
}

/// Whether the canvas has the focus: the primary focus is inside the
/// `InteractionLayer` (or, with [exact], is the layer's own node).
bool canvasFocused(WidgetTester tester, {bool exact = false}) {
  final node = FocusManager.instance.primaryFocus;
  if (exact) return node?.debugLabel == 'InteractionLayer';
  if (node?.context == null) return false;
  return find
      .descendant(
          of: find.byType(InteractionLayer),
          matching: find.byElementPredicate((e) => e == node!.context),
          matchRoot: true)
      .evaluate()
      .isNotEmpty;
}
