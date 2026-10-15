// Ported from jet_cad_floor_plan/test/opening_kink_test.dart (spec 3a C6, C7):
// KJ3 (Task 15), KJ4 and KJ5 over architectureController in PlanEditor;
// KJ1, KJ1 (1e-6°), KJ2 and KJ6 run in the kit.
// ignore_for_file: invalid_use_of_internal_member
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

import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/opening_support.dart';

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

/// Every diagnostic's code and handles.
List<String> reports(DraftDocument doc) =>
    [for (final d in diagnosticsOf(doc)) '${d.code} ${d.handles}'];

bool nofit(DraftDocument doc, Handle h) => diagnosticsOf(doc)
    .any((d) => d.code == 'opening.nofit' && d.handles.contains(h));

/// The angle in degrees from A's direction to B's, anticlockwise.
double bendOf(DraftDocument doc) {
  final a = worldEndsOf(doc, hA), b = worldEndsOf(doc, hB);
  return math.atan2(a.d.x * b.d.y - a.d.y * b.d.x, a.d.dot(b.d)) *
      180 /
      math.pi;
}

void main() {
  testWidgets(
      'KJ3 (shell) the Window tool clicked near the 2°-kinked end places one '
      'window, clamped against it, in one history entry', (tester) async {
    final c =
        openingController(openingPlanText(shellPage, (d) => addKink(d, 2)));
    final doc = c.document;
    await pumpEditor(tester, c, centre: plan(2500, 0), scale: 0.15);
    final f = oracleFrameOf(doc, hA);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.pump();
    await tapWorld(tester, c, oracleAt(f, 2850, 40));
    expect(doc.commands.undoDepth, 1, reason: 'one history entry');
    final o = doc.components.withComponent<OpeningParams>().single;
    final p = doc.components.get<OpeningParams>(o)!;
    expect(p.kind, OpeningKind.window);
    expect(p.width, 1200);
    expect(reports(doc), isEmpty, reason: 'fits, stored where it is drawn');
    expect(
        p.position + 600, closeTo(OpeningOracle(c.document).span(hA).$2, 1e-6),
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
    final c = openingController(openingPlanText(shellPage, (d) {
      addKink(d, 2);
      d.handleSeed.raiseTo(const Handle(9000));
      d.commands.execute(addOpening(
          d, hO, const OpeningParams(hA, 1500, 600, OpeningKind.window)));
    }));
    final doc = c.document;
    await pumpEditor(tester, c, centre: plan(2200, 0), scale: 0.15);
    final f = oracleFrameOf(doc, hA);
    // Select the window: a click on its midline, off its centre.
    await tapWorld(tester, c, oracleAt(f, 1400, 0));
    expect(c.selection.keys, [SelectionKey.root(hO)]);
    final g = objectGripsOf(c, hO).single;
    await dragWorld(tester, c, Vector2(g.x, g.y), oracleAt(f, 2990, 30));
    expect(tester.takeException(), isNull);
    expect(doc.commands.undoDepth, 1, reason: 'one command');
    final p = doc.components.get<OpeningParams>(hO)!;
    expect(
        p.position + 300, closeTo(OpeningOracle(c.document).span(hA).$2, 1e-6),
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
    final c = openingController(openingPlanText(shellPage, (d) {
      addKink(d, 30);
      d.handleSeed.raiseTo(const Handle(9000));
      d.commands.execute(addOpening(
          d, hO, const OpeningParams(hA, 2900, 600, OpeningKind.gap)));
    }));
    final doc = c.document;
    await pumpEditor(tester, c, centre: plan(3000, 400), scale: 0.15);
    expect(reports(doc), ['opening.clamped [$hO]']);
    final b = worldEndsOf(c.document, hB);
    // Select B: a click in the middle of its band, 40% along it.
    final bn = Vector2(-b.d.y, b.d.x);
    await tapWorld(tester, c, b.s + (b.e - b.s) * 0.4 + bn * -75);
    expect(c.selection.keys, [SelectionKey.root(hB)]);
    final e = plan(3000, 0);
    final target = gridOf(doc, polar(e, 23 + 2, 1800));
    await dragWorld(tester, c, b.e, target);
    expect(tester.takeException(), isNull);
    expect(doc.commands.undoDepth, 1, reason: 'not refused');
    expect((worldEndsOf(c.document, hB).e - target).length, lessThan(1e-6));
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
}
