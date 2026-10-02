// Spec 09c's wall-attachment scenes (plan P-2, P-3), built once for Tasks
// 4, 6, 7 and 11: walls at 30° and −112.5°, each in its own group with a
// non-identity transform near (1e5, −7e4); a mirrored group and a scaled
// group, joined and fallen back; an L of 100 and 240 mm; a T; an X at 60°.
//
// Every scene is a document with the floor planner's parametric system
// installed, so each wall stores its outline (the drawn rectangle the face
// runs must lie on). Walls are drawn by world end points, taken back to
// their group's local space (`wall_fixture.dart`'s `addWall`), so a joint
// drawn at one world point meets within rounding, not bitwise.
import 'package:floor_planner/parametric/wall.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'wall_fixture.dart';

/// The attachment fixtures' far point (P-2).
const double attachX = 1e5, attachY = -7e4;

/// The point `(x, y)` from the far point (1e5, −7e4).
Vector2 farAt(double x, double y) => Vector2(attachX + x, attachY + y);

/// P-2's two wall angles, in degrees anticlockwise from world +x.
const List<double> attachAngles = [30, -112.5];

/// Wall [h]'s group in an attachment scene: a translation near the far
/// point times a rotation that is never a multiple of 90°, times a mirror
/// (`scale(1, −1)`) when [mirrored], times a uniform [scale].
Transform2 attachGroup(int h, {bool mirrored = false, double scale = 1}) =>
    Transform2.translation(
            attachX - 950 + 311.5 * (h % 7), attachY + 420 - 173.25 * (h % 5))
        .multiply(Transform2.rotation(0.3 + 0.7 * (h % 9)))
        .multiply(Transform2.scale(scale, mirrored ? -scale : scale));

/// One wall of a scene: world start and end, thickness, justification.
typedef SceneWall = (Vector2 s, Vector2 e, double t, Justification j);

/// A scene: its document and its walls' handles, in the order given
/// (ascending).
typedef AttachScene = ({DraftDocument doc, List<Handle> walls});

/// [walls] in a fresh document, each one command in its own
/// [attachGroup] (mirrored and scaled alike), handles ascending in order.
AttachScene attachScene(List<SceneWall> walls,
    {bool mirrored = false, double scale = 1}) {
  final doc = wallDoc();
  final hs = [for (final _ in walls) doc.handleSeed.next()];
  for (final (i, (s, e, t, j)) in walls.indexed) {
    doc.commands.execute(addWall(doc, hs[i], s, e, t, j,
        at: attachGroup(hs[i].value, mirrored: mirrored, scale: scale)));
  }
  return (doc: doc, walls: hs);
}

/// A free wall at [deg], 3600 long and 150 thick, justified [j], from
/// `farAt(1234.5, 678.25)`.
AttachScene freeWallScene(double deg, Justification j,
    {bool mirrored = false, double scale = 1}) {
  final s = farAt(1234.5, 678.25);
  return attachScene([(s, polar(s, deg, 3600), 150, j)],
      mirrored: mirrored, scale: scale);
}

/// The L's corner and lengths: A (100 thick) runs [lLengthA] along [deg]
/// into the corner, B (240 thick) runs [lLengthB] out of it along
/// `deg + turn`.
final Vector2 lCorner = farAt(-321.75, 987.5);
const double lLengthA = 4000, lLengthB = 3000;
const double lThickA = 100, lThickB = 240;

/// An L: A into [lCorner] along [deg], B out of it along `deg + turn`
/// (a left turn for a positive [turn], so the left faces are inside).
AttachScene lScene(double deg, double turn,
        {Justification ja = Justification.centre,
        Justification jb = Justification.centre,
        bool mirrored = false,
        double scale = 1}) =>
    attachScene([
      (polar(lCorner, deg + 180, lLengthA), lCorner, lThickA, ja),
      (lCorner, polar(lCorner, deg + turn, lLengthB), lThickB, jb),
    ], mirrored: mirrored, scale: scale);

/// The T's host start, foot and sizes: the host (200 thick) runs
/// [teeHostLength] along `deg` from [teeHostStart]; the stem (120 thick,
/// [teeStemLength] long) leaves the host's centreline at [teeFoot] along it.
final Vector2 teeHostStart = farAt(-1500.25, 402.5);
const double teeHostLength = 4200, teeFoot = 1700, teeStemLength = 2000;
const double teeThickHost = 200, teeThickStem = 120;

/// A T: the host along [deg], the stem from its centreline at [foot]
/// (default [teeFoot]) along `deg + stemTurn` (so on the host's left for
/// `0 < stemTurn < 180`), drawn towards the host (its end `k = 1` on it)
/// when [inward].
AttachScene teeScene(double deg, double stemTurn,
    {Justification hostJ = Justification.centre,
    Justification stemJ = Justification.centre,
    bool inward = false,
    double foot = teeFoot,
    bool mirrored = false,
    double scale = 1}) {
  final at = polar(teeHostStart, deg, foot);
  final tip = polar(at, deg + stemTurn, teeStemLength);
  return attachScene([
    (
      teeHostStart,
      polar(teeHostStart, deg, teeHostLength),
      teeThickHost,
      hostJ
    ),
    if (inward)
      (tip, at, teeThickStem, stemJ)
    else
      (at, tip, teeThickStem, stemJ),
  ], mirrored: mirrored, scale: scale);
}

/// An X: the host (200 thick, 4200 long) along [deg] from [teeHostStart];
/// B (160 thick, 3000 long) crossing it at its midpoint along
/// `deg + angle`.
AttachScene crossScene(double deg, double angle,
    {Justification hostJ = Justification.centre,
    Justification crossJ = Justification.centre}) {
  final mid = polar(teeHostStart, deg, 2100);
  return attachScene([
    (teeHostStart, polar(teeHostStart, deg, 4200), 200, hostJ),
    (
      polar(mid, deg + angle + 180, 1500),
      polar(mid, deg + angle, 1500),
      160,
      crossJ
    ),
  ]);
}

/// 07's short-wall fallback (spec 11's C9) at [deg]: a base A, 100 long,
/// between B and C, each 3000 long along `deg + 90` from A's end and from
/// A's start, all 200 thick. A's joined ring is not simple, so 07 squares
/// A's ends in world (`capsOf` falls back).
AttachScene shortBaseScene(double deg,
    {bool mirrored = false, double scale = 1}) {
  final a0 = farAt(612.5, -233.75), a1 = polar(a0, deg, 100);
  return attachScene([
    (a0, a1, 200, Justification.centre),
    (a1, polar(a1, deg + 90, 3000), 200, Justification.centre),
    (a0, polar(a0, deg + 90, 3000), 200, Justification.centre),
  ], mirrored: mirrored, scale: scale);
}
