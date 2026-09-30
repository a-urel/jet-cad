// Spec 12a D8, D13 (plan 12a Task 5): Open decodes with the app's
// registrations and swaps; a file that cannot be read changes nothing but
// the dialog; Save As → Open → Save is byte-identical and the bytes are the
// codec's, from the sample, from a New document drawn and rotated through
// the tools far from the origin, and from a file without the DASHED
// record.
import 'dart:convert';
import 'dart:math' as math;

import 'package:floor_planner/parametric/catalog.dart';
import 'package:floor_planner/parametric/dimension.dart';
import 'package:floor_planner/parametric/live_objects.dart';
import 'package:floor_planner/parametric/opening.dart';
import 'package:floor_planner/parametric/room.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/startup_plan.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind, kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/document_rig.dart';
import 'support/fake_document_files.dart';

/// A freshly built sample, with a measurer of the test's own.
DraftDocument sample() {
  final m = FlutterTextMeasurer();
  addTearDown(m.clear);
  return startupPlan(m);
}

/// Every parametric object of [doc] with its parameters: what a round trip
/// must carry across.
Map<String, Object?> objectsOf(DraftDocument doc) {
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

/// What the Open flow would throw for [bytes], computed here: the dialog
/// shows the thrown object's text (spec 12a D8).
String decodeError(List<int> bytes) {
  try {
    DraftDocumentCodec.decodeString(utf8.decode(bytes),
        registerComponents: registerAppComponents);
  } catch (e) {
    return e.toString();
  }
  fail('premise: the fixture decodes');
}

/// The sample's JSON with [edit] applied, as bytes.
List<int> editedSample(void Function(Map<String, Object?> json) edit) {
  final json = jsonDecode(DraftDocumentCodec.encodeToString(sample()))
      as Map<String, Object?>;
  edit(json);
  return utf8.encode(jsonEncode(json));
}

/// Sets every `scaleDenominator` under [node] to 0: the page's (T-9).
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
      'the first are the codec\'s computed here, and every object comes '
      'back (spec 12a D8, D13, S-9; M-12a-1)', (tester) async {
    final files = FakeDocumentFiles();
    final host = await pumpApp(tester, files);
    await host.openSampleFlow();
    await tester.pump();
    final session = sessionOf(tester);
    final saved = session.document;
    final objects = objectsOf(saved);
    expect((objects['walls']! as Map).length, greaterThan(5),
        reason: 'premise: the flat');

    files.scriptSaveLocation(name: 'flat.jetplan', location: '/plans/flat');
    expect(await host.saveAsStep(), isTrue);
    await tester.pump();
    expect(files.saveLocationCalls, ['Untitled.jetplan']);
    final first = files.writes.single;
    expect(
        first.bytes, utf8.encode(DraftDocumentCodec.encodeToString(sample())),
        reason: 'exactly the codec\'s bytes for the flat');
    expect((first.location, first.name), ('/plans/flat', 'flat.jetplan'));
    expect(session.name, 'flat');

    files.scriptOpen(
        name: 'flat.jetplan', bytes: first.bytes, location: '/plans/flat');
    await host.openFlow();
    await tester.pump();
    final opened = session.document;
    expect(identical(opened, saved), isFalse, reason: 'premise: swapped');
    expect(objectsOf(opened), objects);
    expect(session.dirty.value, isFalse);

    expect(await host.saveStep(), isTrue);
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
    final files = FakeDocumentFiles();
    final host = await pumpApp(tester, files);
    final session = sessionOf(tester);
    final doc = session.document;
    final c = Vector2(41000, 27000);
    await aimCamera(tester, c);

    // Four walls closing a room, a room in it, and a wall on its own.
    await press(tester, LogicalKeyboardKey.keyW);
    for (final p in [
      c + Vector2(-2000, -1500),
      c + Vector2(2000, -1500),
      c + Vector2(2000, 1500),
      c + Vector2(-2000, 1500),
      c + Vector2(-2000, -1500),
    ]) {
      await clickAt(tester, p);
    }
    await press(tester, LogicalKeyboardKey.enter);
    await press(tester, LogicalKeyboardKey.escape);
    expect(wallsOf(doc), hasLength(4), reason: 'premise: the enclosure');
    await press(tester, LogicalKeyboardKey.keyM);
    await clickAt(tester, c + Vector2(-300, 200));
    await press(tester, LogicalKeyboardKey.escape);
    expect(liveObjectsOf<RoomParams>(doc), hasLength(1),
        reason: 'premise: the room');
    await drawWall(tester, c + Vector2(3500, -1000), c + Vector2(3500, 1000));
    final free = wallsOf(doc).last;

    // Selected, then turned by its rotation grip.
    await clickAt(tester, c + Vector2(3500, 300));
    final view = viewOf(tester);
    expect(view.selection.keys, [SelectionKey.root(free)], reason: 'premise');
    expect(view.grips.rotatable, isTrue, reason: 'premise');
    final grip = rotationGripOf(view.grips.box!,
            view.camera.value.worldToScreenMatrix, view.grips.frame)
        .centre;
    final origin = tester.getTopLeft(find.byType(InteractionLayer));
    await dragGlobal(
        tester, origin + grip, origin + grip + const Offset(90, 35));
    final turned = doc.tree[free]!.transform;
    expect(turned.isIdentity, isFalse, reason: 'premise: rotated');
    expect(math.atan2(turned.b, turned.a).abs(), greaterThan(0.05),
        reason: 'premise: a real turn, not a nudge');
    await press(tester, LogicalKeyboardKey.escape);
    final objects = objectsOf(doc);

    files.scriptSaveLocation(name: 'room.jetplan', location: '/plans/room');
    expect(await host.saveStep(), isTrue, reason: 'untitled: Save As');
    await tester.pump();
    final first = files.writes.single.bytes;
    expect(first, bytesOf(doc));

    files.scriptOpen(
        name: 'room.jetplan', bytes: first, location: '/plans/room');
    await host.openFlow();
    await tester.pump();
    final opened = session.document;
    expect(identical(opened, doc), isFalse, reason: 'premise: swapped');
    expect(entriesOf(opened.tree[free]!.transform), entriesOf(turned));
    expect(objectsOf(opened), objects);
    expect(liveObjectsOf<RoomParams>(opened), hasLength(1));

    expect(await host.saveStep(), isTrue);
    await tester.pump();
    expect(files.writes, hasLength(2));
    expect(files.writes.last.bytes, first, reason: 'byte-identical');
  });

  testWidgets(
      'DO3 a file without the DASHED record opens without one and saves back '
      'byte-identical (spec 12a D8, R-3, S-20; M-12a-18)', (tester) async {
    final m = FlutterTextMeasurer();
    addTearDown(m.clear);
    final source = DraftDocument.empty(measurer: m);
    registerAppComponents(source.components);
    final system = installParametric(source);
    final h = source.handleSeed.next();
    source.commands.execute(CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: h,
          parent: source.rootHandle,
          transform: Transform2.translation(33117.5, -21430.25)
              .multiply(Transform2.rotation(0.4)),
          children: const [])),
      SetComponentCommand<WallParams>(
          h, WallParams(120, 40, 3120, 790, 180, Justification.left)),
    ], label: 'Add wall'));
    system.dispose();
    source.commands.clearHistory();
    expect(source.tables.linetypes.byName('DASHED'), isNull, reason: 'premise');
    final file = bytesOf(source);

    final files = FakeDocumentFiles();
    final host = await pumpApp(tester, files);
    files.scriptOpen(name: 'old.jetplan', bytes: file, location: '/plans/old');
    await host.openFlow();
    await tester.pump();
    final opened = sessionOf(tester).document;
    expect(liveObjectsOf<WallParams>(opened), [h], reason: 'premise: open');
    expect(opened.tables.linetypes.byName('DASHED'), isNull,
        reason: 'Open adds no record');
    expect(await host.saveStep(), isTrue);
    await tester.pump();
    expect(files.writes.single.bytes, file);
  });

  testWidgets(
      'DO4 the page after Open is live: the notifier holds the sample\'s '
      'page, the zoom text reads it, the page panel shows it (spec 12a D8, '
      'S-1; M-12a-7)', (tester) async {
    final files = FakeDocumentFiles();
    final host = await pumpApp(tester, files);
    final built = sample();
    final page = built.components.get<PageComponent>(built.rootHandle)!;
    expect(page, isNot(viewOf(tester).page.value),
        reason: 'premise: not the launch page');
    files.scriptOpen(name: 'flat.jetplan', bytes: bytesOf(built));
    await host.openFlow();
    await tester.pump();

    final view = viewOf(tester);
    expect(view.page.value, page);
    expect(tester.widget<Text>(find.byKey(const Key('zoom-text'))).data,
        startsWith('1:50 · '));
    expect(find.byKey(const Key('page-scale')), findsOneWidget);
  });

  testWidgets(
      'DO5 the catalog after Open: the walls are live objects, and a '
      'selected wall shows its grips (spec 12a D8; M-12a-7b)', (tester) async {
    final files = FakeDocumentFiles();
    final host = await pumpApp(tester, files);
    final built = sample();
    files.scriptOpen(name: 'flat.jetplan', bytes: bytesOf(built));
    await host.openFlow();
    await tester.pump();

    final view = viewOf(tester);
    final doc = view.document;
    final walls = liveObjectsOf<WallParams>(doc);
    expect(walls, liveObjectsOf<WallParams>(built));
    expect(walls, isNotEmpty);
    view.selection.replace([SelectionKey.root(walls.first)]);
    await tester.pump();
    expect([
      for (final r in view.grips.grips)
        if (r.object && r.key == SelectionKey.root(walls.first)) r.grip
    ], hasLength(2), reason: 'a live wall\'s two end grips');
  });

  testWidgets(
      'DO6 a file that cannot be read, from a dirty document with history '
      '(Open, then Don\'t Save): '
      'the same document, depth and dirt; a dialog naming the file and the '
      'error; busy cleared, so Open asks again; a cancelled picker, after '
      'the replace dialog, shows no error dialog '
      '(spec 12a D8, S-12, S-13, T-9; M-12a-8, M-12a-16, M-12a-17)',
      (tester) async {
    final files = FakeDocumentFiles();
    final host = await pumpApp(tester, files);
    final session = sessionOf(tester);
    await aimCamera(tester, Vector2(41234.5, 27345.25));
    await drawWall(
        tester, Vector2(40234.5, 27345.25), Vector2(42734.5, 28045.25));
    final doc = session.document;
    final depth = doc.commands.undoDepth;
    expect(depth, 1, reason: 'premise: history');
    expect(session.dirty.value, isTrue, reason: 'premise: dirty');

    var zeroed = 0;
    final failures = <String, List<int>>{
      'latin.jetplan': [0x7B, 0xFF, 0xFE, 0xC3, 0x28, 0x7D],
      'cut.jetplan': utf8.encode('{"schemaVersion": 1, "header": {'),
      'list.jetplan': utf8.encode('[]'),
      'bare.jetplan': utf8.encode('{"schemaVersion": 1}'),
      'scale.jetplan': editedSample((json) => zeroed = zeroScale(json)),
      'future.jetplan':
          editedSample((json) => json['schemaVersion'] = kSchemaVersion + 1),
    };
    expect(zeroed, 1, reason: 'premise: the page\'s scale alone');
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
      expect(identical(session.document, doc), isTrue, reason: name);
      expect(identical(viewOf(tester).document, doc), isTrue, reason: name);
      expect(doc.commands.isDisposed, isFalse, reason: name);
      expect(doc.commands.undoDepth, depth, reason: name);
      expect(session.dirty.value, isTrue, reason: name);
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
    await dismissError(tester);
    await thrown;
    expect(identical(session.document, doc), isTrue);

    // A cancelled picker, after Don't Save: no error dialog, nothing
    // changes.
    files.scriptOpenCancel();
    await discardAndRun(tester, host.openFlow());
    expect(find.byKey(const Key('document-error')), findsNothing);
    expect(identical(session.document, doc), isTrue);
    expect(doc.commands.undoDepth, depth);
    expect(session.dirty.value, isTrue);
    expect(session.busy.value, isFalse);
    expect(files.openCalls, failures.length + 2);
    expect(files.unscriptedCalls, 0);
  });
}
