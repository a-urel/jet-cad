// Ported from jet_cad_floor_plan/test/opening_kink_test.dart (spec 3a C3.3, C7).
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

import 'package:jet_cad_2d_kit_architecture/src/opening/opening.dart';
import 'package:jet_cad_2d_kit_architecture/src/opening/opening_geometry.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall_geometry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/opening_fixture.dart';
import '../support/wall_fixture.dart';

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
    final f = hostFrameInDocument(doc, hA, liveOf(doc))!;
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
    final f = hostFrameInDocument(doc, hA, liveOf(doc))!;
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
