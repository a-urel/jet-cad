// Ported from apps/floor_planner/test/document_open_test.dart (audit
// docs/superpowers/specs/2026-10-16-architecture-demo-test-audit.md, section
// "document_open_test.dart"). DO1, DO2 and DO6 are PORT. DO3, DO4 and DO5
// are COVERED by library tests, each opened and checked:
//   DO3 (a file without the DASHED record opens without one and saves back
//   byte-identical): COVERED, checked: packages/jet_cad_2d_integration/test/
//   scaffold/prepare_test.dart:21 (SC-prepare, `opened.save() == file`) and
//   packages/jet_cad_2d_plan/test/controller/prepare_build_test.dart:105
//   (PB3-prepare-load).
//   DO4 (the page after an Open is live): COVERED, checked: packages/
//   jet_cad_2d_plan/test/panels/layer_page_controller_test.dart:210 (LP-3,
//   a load swaps the document under the Page panel) and packages/
//   jet_cad_2d_plan/test/editor/editor_view_test.dart:64 (the zoom text
//   reads the scale and the fitted zoom).
//   DO5 (the catalog after an Open): COVERED, checked: packages/
//   jet_cad_2d_kit_architecture/test/sample/sample_flat_test.dart:723
//   (SP6, a loaded plan has no drift and no diagnostic), packages/
//   jet_cad_2d_integration/test/wall/wall_grips_test.dart:180 (EG2, a
//   selected wall shows two grips) and packages/jet_cad_2d_kit_architecture/
//   test/wall/wall_live_test.dart:64 (WL1).
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:architecture_demo/document_host.dart';
import 'package:architecture_demo/document_session.dart';
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer, SelectionKey, rotationGripOf;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show KitDiagnosticCode;
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/app_fakes.dart';
import 'support/app_rig.dart';

/// Every parametric object of the plan with its parameters: what a round
/// trip must carry across.
Map<String, Object?> objectsOf(PlanController c) {
  final doc = c.document;
  Map<int, Object?> of<T extends Component>() => {
        for (final h in doc.components.withComponent<T>())
          h.value: doc.components.get<T>(h),
      };
  return {
    'walls': of<WallParams>(),
    'openings': of<OpeningParams>(),
    'rooms': of<RoomParams>(),
    'dimensions': of<DimensionParams>(),
  };
}

/// What the Open flow would throw for [bytes], computed here with a
/// controller of its own: the dialog shows the thrown object's text.
String decodeError(List<int> bytes) {
  final probe = PlanController(kits: [architectureKit]);
  addTearDown(probe.dispose);
  try {
    probe.load(utf8.decode(bytes));
  } catch (e) {
    return e.toString();
  }
  fail('premise: the fixture fails to load');
}

/// The sample's JSON with [edit] applied, as bytes.
List<int> editedSample(void Function(Map<String, Object?> json) edit) {
  final json = jsonDecode(sampleText()) as Map<String, Object?>;
  edit(json);
  return utf8.encode(jsonEncode(json));
}

/// Sets every `scaleDenominator` under [node] to 0: the page's.
int zeroScale(Object? node) {
  var n = 0;
  if (node is Map<String, Object?>) {
    if (node.containsKey('scaleDenominator')) {
      node['scaleDenominator'] = 0;
      n++;
    }
    for (final v in node.values) {
      n += zeroScale(v);
    }
  } else if (node is List) {
    for (final v in node) {
      n += zeroScale(v);
    }
  }
  return n;
}

/// [t]'s six entries, for exact comparison.
List<double> entriesOf(Transform2 t) => [t.a, t.b, t.c, t.d, t.e, t.f];

Future<void> dragGlobal(WidgetTester tester, Offset a, Offset b) async {
  final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
  await gesture.down(a);
  await gesture.moveTo(a + const Offset(12, 7));
  await gesture.moveTo(b);
  await gesture.up();
  await gesture.removePointer();
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets(
      'DO1 sample → Save As → Open → Save: the second bytes are the first, '
      'the first are the plan\'s text computed apart from the app, and every '
      'object comes back (spec 12a D8, D13, S-9; M-12a-1)', (tester) async {
    final rig = await pumpApp(tester);
    final c = rig.controller;
    final files = rig.files;
    await rig.host.openSampleFlow();
    await tester.pump();
    final saved = c.document;
    final objects = objectsOf(c);
    expect((objects['walls']! as Map).length, greaterThan(5),
        reason: 'premise: the flat');

    files.scriptSaveLocation(name: 'flat.jetplan', location: '/plans/flat');
    expect(await rig.host.saveAsStep(), isTrue);
    await tester.pump();
    expect(files.saveLocationCalls, ['Untitled.jetplan']);
    final first = files.writes.single;
    expect(first.bytes, utf8.encode(sampleText()),
        reason: 'exactly the plan\'s text for the flat');
    expect((first.location, first.name), ('/plans/flat', 'flat.jetplan'));
    expect(rig.session.name, 'flat');

    files.scriptOpen(
        name: 'flat.jetplan', bytes: first.bytes, location: '/plans/flat');
    await rig.host.openFlow();
    await tester.pump();
    expect(identical(c.document, saved), isFalse, reason: 'premise: swapped');
    expect(objectsOf(c), objects);
    expect(c.dirty.value, isFalse);

    expect(await rig.host.saveStep(), isTrue);
    await tester.pump();
    expect(files.saveLocationCalls, hasLength(1), reason: 'no second ask');
    final second = files.writes.last;
    expect(files.writes, hasLength(2));
    expect(second.bytes, first.bytes, reason: 'byte-identical');
    expect((second.location, second.name), ('/plans/flat', 'flat.jetplan'));
  });

  testWidgets(
      'DO2 from New: a room walled in and a free wall rotated through the '
      'rotation grip, far from the origin → Save As → Open → Save: bytes '
      'equal, the rotated group\'s transform comes back (spec 12a S-3, T-10)',
      (tester) async {
    final rig = await pumpApp(tester);
    final c = rig.controller;
    final files = rig.files;
    final doc = c.document;
    final centre = Vector2(41000, 27000);
    await aimCamera(tester, c, centre);

    // Four walls closing a room, a room in it, and a wall on its own.
    await press(tester, LogicalKeyboardKey.keyW);
    for (final p in [
      centre + Vector2(-2000, -1500),
      centre + Vector2(2000, -1500),
      centre + Vector2(2000, 1500),
      centre + Vector2(-2000, 1500),
      centre + Vector2(-2000, -1500),
    ]) {
      await clickAt(tester, c, p);
    }
    await press(tester, LogicalKeyboardKey.enter);
    await press(tester, LogicalKeyboardKey.escape);
    expect(wallsOf(c), hasLength(4), reason: 'premise: the enclosure');
    await press(tester, LogicalKeyboardKey.keyM);
    await clickAt(tester, c, centre + Vector2(-300, 200));
    await press(tester, LogicalKeyboardKey.escape);
    expect(liveOf<RoomParams>(c, ArchitectureTypes.room), hasLength(1),
        reason: 'premise: the room');
    await drawWall(
        tester, c, centre + Vector2(3500, -1000), centre + Vector2(3500, 1000));
    final free = wallsOf(c).last;

    // Selected, then turned by its rotation grip.
    await clickAt(tester, c, centre + Vector2(3500, 300));
    expect(c.activeSelection.keys, [SelectionKey.root(free)],
        reason: 'premise');
    final grips = tester
        .widget<InteractionLayer>(find.byType(InteractionLayer))
        .tools
        .context
        .grips!;
    expect(grips.rotatable, isTrue, reason: 'premise');
    final grip = rotationGripOf(
            grips.box!, c.camera.value.worldToScreenMatrix, grips.frame)
        .centre;
    final origin = tester.getTopLeft(find.byType(InteractionLayer));
    await dragGlobal(
        tester, origin + grip, origin + grip + const Offset(90, 35));
    final turned = doc.tree[free]!.transform;
    expect(turned.isIdentity, isFalse, reason: 'premise: rotated');
    expect(math.atan2(turned.b, turned.a).abs(), greaterThan(0.05),
        reason: 'premise: a real turn, not a nudge');
    await press(tester, LogicalKeyboardKey.escape);
    final objects = objectsOf(c);

    files.scriptSaveLocation(name: 'room.jetplan', location: '/plans/room');
    expect(await rig.host.saveStep(), isTrue, reason: 'untitled: Save As');
    await tester.pump();
    final first = files.writes.single.bytes;
    expect(first, bytesOf(c));

    files.scriptOpen(
        name: 'room.jetplan', bytes: first, location: '/plans/room');
    await rig.host.openFlow();
    await tester.pump();
    final opened = c.document;
    expect(identical(opened, doc), isFalse, reason: 'premise: swapped');
    expect(entriesOf(opened.tree[free]!.transform), entriesOf(turned));
    expect(objectsOf(c), objects);
    expect(liveOf<RoomParams>(c, ArchitectureTypes.room), hasLength(1));

    expect(await rig.host.saveStep(), isTrue);
    await tester.pump();
    expect(files.writes, hasLength(2));
    expect(files.writes.last.bytes, first, reason: 'byte-identical');
  });

  testWidgets(
      'DO6 a file that cannot be read, from a dirty plan with history (Open, '
      'then Don\'t Save): the same document, depth and dirt; a dialog naming '
      'the file and the error; busy cleared, so Open asks again; a '
      'cancelled picker, after the replace dialog, shows no error dialog '
      '(spec 12a D8, S-12, S-13, T-9; M-12a-8, M-12a-16, M-12a-17)',
      (tester) async {
    final rig = await pumpApp(tester);
    final c = rig.controller;
    final files = rig.files;
    final session = rig.session;
    final host = rig.host;
    await aimCamera(tester, c, Vector2(41234.5, 27345.25));
    await drawWall(
        tester, c, Vector2(40234.5, 27345.25), Vector2(42734.5, 28045.25));
    final doc = c.document;
    final depth = doc.commands.undoDepth;
    expect(depth, 1, reason: 'premise: history');
    expect(c.dirty.value, isTrue, reason: 'premise: dirty');

    final failures = <String, List<int>>{
      'latin.jetplan': [0x7B, 0xFF, 0xFE, 0xC3, 0x28, 0x7D],
      'cut.jetplan': utf8.encode('{"schemaVersion": 1, "header": {'),
      'list.jetplan': utf8.encode('[]'),
      'bare.jetplan': utf8.encode('{"schemaVersion": 1}'),
      'future.jetplan':
          editedSample((json) => json['schemaVersion'] = kSchemaVersion + 1),
    };
    for (final MapEntry(key: name, value: bytes) in failures.entries) {
      final expected = decodeError(bytes);
      final calls = files.openCalls;
      files.scriptOpen(name: name, bytes: bytes, location: '/plans/$name');
      final flow = host.openFlow();
      await tester.pump();
      expect(files.openCalls, calls, reason: '$name: the dialog first');
      await answerReplace(tester, 'replace-discard');
      expect(files.openCalls, calls + 1, reason: '$name: the picker');
      expect(find.byKey(const Key('document-error')), findsOneWidget,
          reason: name);
      expect(
          tester
              .widget<Text>(find.byKey(const Key('document-error-title')))
              .data,
          'Could not open $name');
      expect(
          tester
              .widget<Text>(find.byKey(const Key('document-error-text')))
              .data,
          expected);
      expect(session.busy.value, isTrue,
          reason: '$name: busy under the dialog');
      await dismissError(tester);
      await flow;
      expect(find.byKey(const Key('document-error')), findsNothing);
      expect(identical(c.document, doc), isTrue, reason: name);
      expect(doc.commands.isDisposed, isFalse, reason: name);
      expect(doc.commands.undoDepth, depth, reason: name);
      expect(c.dirty.value, isTrue, reason: name);
      expect(session.name, 'Untitled', reason: name);
      expect(session.location, isNull, reason: name);
      expect(session.busy.value, isFalse, reason: '$name: busy cleared');
    }

    // The picker itself failing is reported the same way.
    files.scriptOpenThrow(StateError('the disk went away'));
    final thrown = host.openFlow();
    await tester.pump();
    await answerReplace(tester, 'replace-discard');
    expect(
        tester.widget<Text>(find.byKey(const Key('document-error-text'))).data,
        'Bad state: the disk went away');
    expect(
        tester.widget<Text>(find.byKey(const Key('document-error-title'))).data,
        'Could not open the file');
    await dismissError(tester);
    await thrown;
    expect(identical(c.document, doc), isTrue);

    // A cancelled picker, after Don't Save: no error dialog, nothing
    // changes.
    files.scriptOpenCancel();
    await discardAndRun(tester, host.openFlow());
    expect(find.byKey(const Key('document-error')), findsNothing);
    expect(identical(c.document, doc), isTrue);
    expect(doc.commands.undoDepth, depth);
    expect(c.dirty.value, isTrue);
    expect(session.busy.value, isFalse);
    expect(files.openCalls, failures.length + 2);
    expect(files.unscriptedCalls, 0);
  });

  testWidgets(
      'DO6-open-scale a page scale of 0 is not an unreadable file now: the '
      'plan opens, the page component is dropped and the library reports an '
      'unreadable component (spec 12a D8, T-9)', (tester) async {
    // Decided: premise impossible (the old decoder threw on a zero scale and
    // the Open flow showed its dialog; `load` keeps what it can read and
    // reports `componentUnreadable`, plan_controller.dart load -> decodePlan).
    // The intent -- a file that cannot be read changes nothing -- is the five
    // fixtures of DO6, which still fail.
    final rig = await pumpApp(tester);
    final c = rig.controller;
    var zeroed = 0;
    final bytes = editedSample((json) => zeroed = zeroScale(json));
    expect(zeroed, 1, reason: 'premise: the page\'s scale alone');
    rig.files.scriptOpen(name: 'scale.jetplan', bytes: bytes);
    await rig.host.openFlow();
    await tester.pump();
    expect(find.byKey(const Key('document-error')), findsNothing);
    expect(rig.session.name, 'scale');
    expect(c.document.components.get<PageComponent>(c.document.rootHandle),
        isNull);
    expect(c.diagnostics.value.map((d) => d.code),
        contains(KitDiagnosticCode.componentUnreadable));
  });

  // Not a port (the final review's M1): the host unmounted while the picker
  // is up, over a controller and a session the test owns -- so they outlive
  // the host, and a `load` that wrongly ran would replace the plan and name
  // the session. The picker then answers with a valid plan; the flow must
  // end there. Mutation M-OP-teardown: without the `mounted` check after
  // the pick, `load` and `named` run on the live controller.
  testWidgets(
      'OP-teardown the host unmounted while the picker is up: its late '
      'answer neither loads the plan nor names the session', (tester) async {
    final controller = PlanController(kits: [architectureKit]);
    addTearDown(controller.dispose);
    final session = DocumentSession();
    addTearDown(session.dispose);
    final files = FakeDocumentFiles()
      ..holdOpens = true
      ..scriptOpen(
          name: 'late.jetplan', bytes: sampleBytes(), location: '/p/late');
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        localizationsDelegates: planLocalizationsDelegates,
        supportedLocales: planSupportedLocales,
        home: DocumentHost(
            controller: controller,
            session: session,
            files: files,
            exitGuard: FakeExitGuard())));
    await tester.pump();
    final host = tester.state<DocumentHostState>(find.byType(DocumentHost));
    final before = controller.document;
    final running = host.openFlow();
    await tester.pump();
    await tester.pump();
    expect(files.heldOpens, hasLength(1), reason: 'premise: picker held');

    await tester.pumpWidget(const SizedBox());
    expect(host.mounted, isFalse, reason: 'premise: unmounted');
    files.heldOpens.single.complete();
    await running;
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(identical(controller.document, before), isTrue,
        reason: 'the late file was not loaded');
    expect(session.fileName, isNull, reason: 'the session was not named');
  });
}
