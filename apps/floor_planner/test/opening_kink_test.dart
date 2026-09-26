// The final review's I1 (spec 08 D8 and D9, as amended by the final fix
// wave): an opening clamped against the end of a wall whose joint is kinked
// a little. There the end cap runs from the right face out to a lobe, back
// to the endpoint on the centreline and on to the left face; the cap-vertex
// snap drops both of the cut's face points, and the end piece ran out to the
// left face and straight back over the endpoint: a spike the triangulator
// refused, so the whole edit was refused. Now the back-tracking vertex is
// dropped, and an opening is admitted only when every piece it leaves is
// simple, anticlockwise and triangulable; otherwise it is no-fit.
//
// Every wall is at the far origin in its own rotated group (`groupAt`), the
// plan is turned 23 degrees, and the camera of the shell tests is rotated.
import 'dart:math' as math;

import 'package:floor_planner/main.dart';
import 'package:floor_planner/parametric/catalog.dart';
import 'package:floor_planner/parametric/opening.dart';
import 'package:floor_planner/parametric/opening_geometry.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/parametric/wall_geometry.dart';
import 'package:floor_planner/planner_view.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind, kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/opening_fixture.dart';
import 'support/wall_fixture.dart';

const centre = Justification.centre;
const left = Justification.left;
const right = Justification.right;

const hA = Handle(1000), hB = Handle(1100), hO = Handle(5000);

/// The reviewer's joint: A (3,000, 200 centred) along the plan's x, and B
/// (1,800, [tb] thick, [jb]) out of A's end, [bend] degrees anticlockwise
/// of A's direction.
void addKink(DraftDocument doc, double bend,
    {double ta = 200,
    Justification ja = centre,
    double tb = 150,
    Justification jb = right}) {
  final e = plan(3000, 0);
  doc.commands.execute(addWall(doc, hA, plan(0, 0), e, ta, ja));
  doc.commands.execute(addWall(doc, hB, e, polar(e, 23 + bend, 1800), tb, jb));
}

/// [h]'s stored pieces, in its own group-local space, ascending by fill.
List<List<Vector2>> localPieces(DraftDocument doc, Handle h) => [
      for (final f in fillsOf(doc, h))
        pointsOf(payloadOf(doc, boundaryOf(doc, f)), closed: true),
    ];

/// Every diagnostic's code and handles.
List<String> reports(DraftDocument doc) =>
    [for (final d in diagnosticsOf(doc)) '${d.code} ${d.handles}'];

bool nofit(DraftDocument doc, Handle h) => diagnosticsOf(doc)
    .any((d) => d.code == 'opening.nofit' && d.handles.contains(h));

/// The one-command, one-history-entry, well-formed outcome every case must
/// have: stored pieces simple, anticlockwise and triangulating; no drift.
void expectWellFormed(DraftDocument doc, {required String reason}) {
  for (final h in [hA, hB]) {
    expect(storedPiecesTriangulate(doc, h), isTrue, reason: '$reason $h');
    expect(storedPiecesSimpleCcw(doc, h), isTrue, reason: '$reason $h');
  }
  expect(driftOf(doc), isEmpty, reason: reason);
}

// ---------------------------------------------------------------------------
// The shell, as `opening_grips_test.dart` drives it.

const double _scale = 0.15;
const double _gridStep = 10;

/// A 1:20 page near the far origin with grid snap on at [_gridStep], and
/// what [build] adds through a temporary parametric system, with no undo
/// history.
DraftDocument shellDoc(void Function(DraftDocument doc) build) {
  final doc = DraftDocument.empty(measurer: FlutterTextMeasurer());
  PageComponent.register(doc.components);
  doc.commands.execute(SetComponentCommand<PageComponent>(
      doc.rootHandle,
      PageComponent(
          scaleDenominator: 20,
          originX: ox - 2000,
          originY: oy - 2000,
          gridStepMm: _gridStep)));
  final system = installParametric(doc);
  build(doc);
  system.dispose();
  doc.commands.clearHistory();
  return doc;
}

Future<PlannerView> pumpShell(
    WidgetTester tester, DraftDocument doc, Vector2 centre) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: PlannerShell(document: doc)));
  await tester.pump();
  final view = tester.widget<PlannerView>(find.byType(PlannerView));
  final size = tester.getSize(find.byType(InteractionLayer));
  final linear =
      Transform2.rotation(0.35).multiply(Transform2.scale(_scale, _scale));
  final mid = linear.transformPoint(centre);
  view.camera.value = ViewportTransform(
      worldToScreenMatrix: Transform2.translation(
              size.width / 2 - mid.x, size.height / 2 - mid.y)
          .multiply(linear));
  await tester.pump();
  return view;
}

Offset globalOf(WidgetTester tester, PlannerView view, Vector2 p) {
  final s = view.camera.value.worldToScreen(p);
  return tester.getTopLeft(find.byType(InteractionLayer)) + Offset(s.x, s.y);
}

Future<void> tapWorld(WidgetTester tester, PlannerView view, Vector2 p) async {
  await tester.tapAt(globalOf(tester, view, p));
  await tester.pump();
}

/// A mouse drag from world [from] to world [to], past the slop at once.
Future<void> dragWorld(
    WidgetTester tester, PlannerView view, Vector2 from, Vector2 to) async {
  final a = globalOf(tester, view, from), b = globalOf(tester, view, to);
  final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
  await gesture.down(a);
  await gesture.moveTo(a + const Offset(12, 0));
  await gesture.moveTo(b);
  await gesture.up();
  await gesture.removePointer();
  await tester.pump();
}

List<Grip> objectGripsOf(PlannerView view, Handle h) => [
      for (final r in view.grips.grips)
        if (r.object && r.key == SelectionKey.root(h)) r.grip,
    ];

/// The page grid's point nearest [p], as the snap chain computes it.
Vector2 gridOf(DraftDocument doc, Vector2 p) => snapToGrid(
    p, _gridStep, doc.components.get<PageComponent>(doc.rootHandle)!);

/// The angle in degrees from A's direction to B's, anticlockwise.
double bendOf(DraftDocument doc) {
  final a = worldWallOf(doc, hA), b = worldWallOf(doc, hB);
  return math.atan2(a.d.x * b.d.y - a.d.y * b.d.x, a.d.dot(b.d)) *
      180 /
      math.pi;
}

void main() {
  test(
      'KJ1 (ffw-validPiece, ffw-dropBacktrack) the reviewer\'s repro: A '
      '(3,000, 200 centre), B out of A\'s end at a 2° kink (150 right), a '
      '600 gap at 2,900 lands in one step, clamped against the end; the end '
      'piece is the cap\'s lobe without the back-tracking left face; every '
      'piece valid, the tiling exact, no drift, undo and redo exact', () {
    final doc = wallDoc();
    addKink(doc, 2);
    doc.handleSeed.raiseTo(const Handle(9000));
    final depth = doc.commands.undoDepth;
    final before = canon(doc);
    doc.commands.execute(addOpening(
        doc, hO, const OpeningParams(hA, 2900, 600, OpeningKind.gap)));
    expect(doc.commands.undoDepth, depth + 1, reason: 'one history entry');
    expect(reports(doc), ['opening.clamped [$hO]'], reason: 'it fits');
    final after = canon(doc);

    // The end cap (right face, lobe, endpoint, left face) as 08 reads it,
    // in A's local space; the end piece is its first three vertices, bit
    // for bit: the left face is where the ring ran back over the endpoint.
    final f = hostFrameInDocument(doc, hA)!;
    expect(f.endCap, hasLength(4));
    double off(Vector2 q) => (q - f.s).dot(f.n);
    expect(off(f.endCap[0]), closeTo(-100, 1e-6), reason: 'the right face');
    expect(off(f.endCap[1]), lessThan(-120), reason: 'the lobe, beyond it');
    expect(off(f.endCap[2]), closeTo(0, 1e-6), reason: 'the endpoint');
    expect(off(f.endCap[3]), closeTo(100, 1e-6), reason: 'the left face');
    expect(f.uOf(f.endCap[1]) - f.uE, greaterThan(1),
        reason: 'the lobe makes the end piece longer than the tolerance');
    final pieces = localPieces(doc, hA);
    expect(pieces, hasLength(2));
    expect([for (final q in pieces[1]) q.storage.toList()],
        [for (final q in f.endCap.take(3)) q.storage.toList()]);

    final oracle = OpeningOracle(doc);
    expect(violations(oracle.tilingOf(hA)), 0);
    expectWellFormed(doc, reason: 'repro');
    doc.commands.undo();
    // The seed stays raised past the opening's children; all else is back.
    expect(canon(doc).replaceAll('"handleSeed":9004', '"handleSeed":9000'),
        before);
    doc.commands.redo();
    expect(canon(doc), after);
  });

  test(
      'KJ1 (ffw-validPiece) a 1e-6° kink (A 200 left, B 150 centre): the end '
      'cap zigzags across the jamb (a cap vertex lies on it), so no end '
      'piece is valid; a window clamped against the end is no-fit, and the '
      'edit lands in one step instead of being refused', () {
    final doc = wallDoc();
    addKink(doc, 1e-6, ja: left, jb: centre);
    doc.handleSeed.raiseTo(const Handle(9000));
    final f = hostFrameInDocument(doc, hA)!;
    // The cap: the endpoint (A's right face), a vertex just past uE outside
    // the band, one exactly at uE inside it, the left face.
    expect(f.endCap, hasLength(4));
    expect(f.uOf(f.endCap[2]), f.uE, reason: 'on the jamb at uE');
    final depth = doc.commands.undoDepth;
    const window = OpeningParams(hA, 2900, 600, OpeningKind.window);
    doc.commands.execute(addOpening(doc, hO, window));
    expect(doc.commands.undoDepth, depth + 1, reason: 'not refused');
    expect(reports(doc), ['opening.nofit [$hO]']);
    expect(fillsOf(doc, hA), hasLength(1), reason: 'A takes 07\'s path');
    expect(OpeningOracle(doc).cut(window), isNotNull,
        reason: 'it fits by extent alone');
    expectWellFormed(doc, reason: '1e-6');
  });

  test(
      'KJ2 the kink sweep: 15 bends (0° to 60°, both signs) × A 200 or 115 × '
      'B 150, 200 or 300 × all nine justification pairs × a window clamped '
      'against the kinked start or end: 1,620 cases, none refused, none '
      'no-fit, every piece valid, no drift', () {
    var tried = 0, refused = 0, noFit = 0;
    final samples = <String>[];
    for (final bend in const [
      0.0, 0.25, 0.5, 1.0, 2.0, 3.0, 5.0, 8.0, 12.0, 20.0, 35.0, 60.0, //
      -2.0, -5.0, -20.0,
    ]) {
      for (final ta in const [200.0, 115.0]) {
        for (final tb in const [150.0, 200.0, 300.0]) {
          for (final ja in Justification.values) {
            for (final jb in Justification.values) {
              for (final atStart in const [false, true]) {
                final doc = wallDoc();
                final s = plan(0, 0), e = plan(3000, 0);
                doc.commands.execute(addWall(doc, hA, s, e, ta, ja));
                // B continues from A's end, or runs into A's start.
                doc.commands.execute(atStart
                    ? addWall(
                        doc, hB, polar(s, 23 + 180 + bend, 1800), s, tb, jb)
                    : addWall(doc, hB, e, polar(e, 23 + bend, 1800), tb, jb));
                doc.handleSeed.raiseTo(const Handle(9000));
                tried++;
                final what = '$bend° A $ta ${ja.name} B $tb ${jb.name} '
                    '${atStart ? 'start' : 'end'}';
                final depth = doc.commands.undoDepth;
                try {
                  doc.commands.execute(addOpening(
                      doc,
                      hO,
                      OpeningParams(
                          hA, atStart ? 100 : 2900, 600, OpeningKind.window)));
                } on Object {
                  refused++;
                  if (samples.length < 8) samples.add(what);
                  continue;
                }
                expect(doc.commands.undoDepth, depth + 1, reason: what);
                if (nofit(doc, hO)) noFit++;
                expectWellFormed(doc, reason: what);
              }
            }
          }
        }
      }
    }
    // ignore: avoid_print
    print('KJ2: $tried cases, $refused refused, $noFit no-fit');
    expect(tried, 1620);
    expect(samples, isEmpty);
    expect(refused, 0);
    expect(noFit, 0, reason: 'the back-tracking vertex dropped: all fit');
  });

  testWidgets(
      'KJ3 (shell) the Window tool clicked near the 2°-kinked end places one '
      'window, clamped against it, in one history entry', (tester) async {
    final doc = shellDoc((d) => addKink(d, 2));
    final view = await pumpShell(tester, doc, plan(2500, 0));
    final f = oracleFrameOf(doc, hA);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.pump();
    await tapWorld(tester, view, oracleAt(f, 2850, 40));
    expect(doc.commands.undoDepth, 1, reason: 'one history entry');
    final o = doc.components.withComponent<OpeningParams>().single;
    final p = doc.components.get<OpeningParams>(o)!;
    expect(p.kind, OpeningKind.window);
    expect(p.width, 1200);
    expect(reports(doc), isEmpty, reason: 'fits, stored where it is drawn');
    expect(p.position + 600, closeTo(hostFrameInDocument(doc, hA)!.uE, 1e-6),
        reason: 'against the end');
    expect(fillsOf(doc, hA), hasLength(2));
    for (final h in [hA, hB]) {
      expect(storedPiecesTriangulate(doc, h), isTrue);
      expect(storedPiecesSimpleCcw(doc, h), isTrue);
    }
    expect(driftOf(doc), isEmpty);
  });

  testWidgets(
      'KJ4 (shell) a window\'s slide grip dragged to the 2°-kinked end lands '
      'one command, clamped against the end; nothing escapes pointer-up',
      (tester) async {
    final doc = shellDoc((d) {
      addKink(d, 2);
      d.handleSeed.raiseTo(const Handle(9000));
      d.commands.execute(addOpening(
          d, hO, const OpeningParams(hA, 1500, 600, OpeningKind.window)));
    });
    final view = await pumpShell(tester, doc, plan(2200, 0));
    final f = oracleFrameOf(doc, hA);
    // Select the window: a click on its midline, off its centre.
    await tapWorld(tester, view, oracleAt(f, 1400, 0));
    expect(view.selection.keys, [SelectionKey.root(hO)]);
    final g = objectGripsOf(view, hO).single;
    await dragWorld(tester, view, Vector2(g.x, g.y), oracleAt(f, 2990, 30));
    expect(tester.takeException(), isNull);
    expect(doc.commands.undoDepth, 1, reason: 'one command');
    final p = doc.components.get<OpeningParams>(hO)!;
    expect(p.position + 300, closeTo(hostFrameInDocument(doc, hA)!.uE, 1e-6),
        reason: 'stored where it is drawn, against the end');
    expect(reports(doc), isEmpty);
    expect(fillsOf(doc, hA), hasLength(2));
    for (final h in [hA, hB]) {
      expect(storedPiecesTriangulate(doc, h), isTrue);
      expect(storedPiecesSimpleCcw(doc, h), isTrue);
    }
    expect(driftOf(doc), isEmpty);
  });

  testWidgets(
      'KJ5 (shell) with a gap clamped against A\'s end at a 30° joint, B\'s '
      'far end dragged so that B turns to about 2° lands one command: A '
      'keeps its gap, every piece valid', (tester) async {
    final doc = shellDoc((d) {
      addKink(d, 30);
      d.handleSeed.raiseTo(const Handle(9000));
      d.commands.execute(addOpening(
          d, hO, const OpeningParams(hA, 2900, 600, OpeningKind.gap)));
    });
    final view = await pumpShell(tester, doc, plan(3000, 400));
    expect(reports(doc), ['opening.clamped [$hO]']);
    final b = worldWallOf(doc, hB);
    // Select B: a click in the middle of its band, 40% along it.
    final bn = Vector2(-b.d.y, b.d.x);
    await tapWorld(tester, view, b.s + (b.e - b.s) * 0.4 + bn * -75);
    expect(view.selection.keys, [SelectionKey.root(hB)]);
    final e = plan(3000, 0);
    final target = gridOf(doc, polar(e, 23 + 2, 1800));
    await dragWorld(tester, view, b.e, target);
    expect(tester.takeException(), isNull);
    expect(doc.commands.undoDepth, 1, reason: 'not refused');
    expect((worldWallOf(doc, hB).e - target).length, lessThan(1e-6));
    final bend = bendOf(doc);
    // ignore: avoid_print
    print('KJ5: B turned to $bend°');
    expect(bend, inInclusiveRange(1.5, 2.5));
    expect(reports(doc), ['opening.clamped [$hO]'], reason: 'still cuts');
    expect(fillsOf(doc, hA), hasLength(2));
    for (final h in [hA, hB]) {
      expect(storedPiecesTriangulate(doc, h), isTrue);
      expect(storedPiecesSimpleCcw(doc, h), isTrue);
    }
    expect(driftOf(doc), isEmpty);
  });

  test(
      'KJ6 (ffw-validNoSimple, ffw-validNoTri) the piece predicate is both '
      'checks: a clockwise rectangle triangulates but is refused; a ring '
      'with an exact zero-width spike has no proper crossing and positive '
      'area but does not triangulate, and is refused; the anticlockwise '
      'rectangle is accepted. Rings at the far origin, turned 23°', () {
    List<Vector2> ring(List<(double, double)> xy) =>
        [for (final (x, y) in xy) plan(x, y)];
    final ccw = ring([(0, 0), (1000, 0), (1000, 200), (0, 200)]);
    final cw = ring([(0, 0), (0, 200), (1000, 200), (1000, 0)]);
    final spike = ring([
      (0, 0), (1000, 0), (1000, 200), (500, 200), (500, 700), (500, 200), //
      (0, 200),
    ]);
    List<int>? triangles(List<Vector2> r) =>
        triangulationFor(EntityKind.polyline, polylinePayload(r, closed: true));

    expect(isSimpleCcw(ccw), isTrue);
    expect(triangles(ccw), isNotEmpty);
    expect(isValidPiece(ccw), isTrue);

    expect(isSimpleCcw(cw), isFalse, reason: 'clockwise');
    expect(triangles(cw), isNotEmpty, reason: 'the engine takes either way');
    expect(isValidPiece(cw), isFalse);

    expect(isSimpleCcw(spike), isTrue, reason: 'no proper crossing');
    expect(triangles(spike), isEmpty, reason: 'the ear clipper stalls');
    expect(isValidPiece(spike), isFalse);
  });
}
