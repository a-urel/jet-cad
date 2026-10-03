import 'dart:convert';

import 'package:floor_planner/document_host.dart';
import 'package:floor_planner/main.dart';
import 'package:jet_cad_floor_plan/editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'fake_document_files.dart';
import 'fake_exit_guard.dart';

// The app pumped with a scripted `DocumentFiles` (spec 12a, Testing), and
// the moves the document host's tests share: reading the host, the session
// and the current shell's view, and editing through the real tools.

/// The app over [files] (and [exitGuard], the platform's no-op when null)
/// at a 1440 x 900 surface; the host's state.
Future<DocumentHostState> pumpApp(WidgetTester tester, FakeDocumentFiles files,
    {FakeExitGuard? exitGuard}) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(FloorPlannerApp(files: files, exitGuard: exitGuard));
  await tester.pump();
  return hostOf(tester);
}

DocumentHostState hostOf(WidgetTester tester) =>
    tester.state<DocumentHostState>(find.byType(DocumentHost));

DocumentSession sessionOf(WidgetTester tester) =>
    tester.widget<DocumentHost>(find.byType(DocumentHost)).session;

/// The current shell's view: a new one after every swap.
PlannerView viewOf(WidgetTester tester) =>
    tester.widget<PlannerView>(find.byType(PlannerView));

/// The app's title, as `MaterialApp.onGenerateTitle` made it.
String titleOf(WidgetTester tester) =>
    tester.widget<Title>(find.byType(Title)).title;

/// The codec's bytes for [doc], computed here (spec 12a D13).
List<int> bytesOf(DraftDocument doc) =>
    utf8.encode(DraftDocumentCodec.encodeToString(doc));

/// [doc]'s walls, ascending.
List<Handle> wallsOf(DraftDocument doc) =>
    doc.components.withComponent<WallParams>().toList()
      ..sort((a, b) => a.value.compareTo(b.value));

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

/// Cmd+Z: the shell's undo binding.
Future<void> undoKey(WidgetTester tester) =>
    chord(tester, LogicalKeyboardKey.meta, LogicalKeyboardKey.keyZ);

/// The global position of world [p] in the current shell.
Offset globalOf(WidgetTester tester, Vector2 p) {
  final s = viewOf(tester).camera.value.worldToScreen(p);
  return tester.getTopLeft(find.byType(InteractionLayer)) + Offset(s.x, s.y);
}

Future<void> clickAt(WidgetTester tester, Vector2 p) async {
  await tester.tapAt(globalOf(tester, p));
  await tester.pump();
}

/// A rotated, non-reflecting camera at 0.1 px/mm centred on world
/// [centre]: the drawing can sit far from the origin and off the page.
Future<void> aimCamera(WidgetTester tester, Vector2 centre) async {
  final view = viewOf(tester);
  final size = tester.getSize(find.byType(InteractionLayer));
  final linear = Transform2.rotation(0.3).multiply(Transform2.scale(0.1, 0.1));
  final mid = linear.transformPoint(centre);
  view.camera.value = ViewportTransform(
      worldToScreenMatrix: Transform2.translation(
              size.width / 2 - mid.x, size.height / 2 - mid.y)
          .multiply(linear));
  await tester.pump();
}

/// One wall from [a] to [b] through the Wall tool (W, two clicks, Enter),
/// then Escape to Select: an edit through a real tool, the shape ended
/// (spec 12a Testing, T-6).
Future<void> drawWall(WidgetTester tester, Vector2 a, Vector2 b) async {
  await press(tester, LogicalKeyboardKey.keyW);
  await clickAt(tester, a);
  await clickAt(tester, b);
  await press(tester, LogicalKeyboardKey.enter);
  await press(tester, LogicalKeyboardKey.escape);
  expect(viewOf(tester).tools.active, isA<SelectTool>(),
      reason: 'premise: the shape is ended');
}

/// Answers the Save / Don't Save / Cancel dialog (spec 12a D10) with the
/// button keyed [key]: `replace-save`, `replace-discard` or
/// `replace-cancel`. The dialog must be up.
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

/// Runs [flow] (New, Open or Open sample) from a dirty document and
/// answers its dialog with Don't Save (spec 12a D10).
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
