// A unit's label, drawn (spec 2b S2 "The label"): an ATTRIB tagged `UNIT`
// owned by the unit's instance, its text the label, anchored at the
// definition's base point and stamped so it reads upright and unmirrored in
// the world whatever the instance's rotation and mirror. Ported from
// jet_cad_floor_plan's tables/table_label.dart (spec 14a T2, T8, T10): the
// tag, the height rule, the stamp, the text attributes and the payload; the
// height now reads the top's box. unitLabelAttrib is new: a kit's
// parametric type gives a generated unit its label with it (E5).
//
// Pure Dart: no Flutter, no dart:io.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// The tag of the ATTRIB that holds a unit's label (today's `TABLE`).
const String kUnitLabelTag = 'UNIT';

/// The label's height on a top whose smaller side is 500 and more, in
/// drawing units (T8).
const double kUnitLabelMaxHeight = 200;

/// The share of the top's smaller side a label may take (T8).
const double kUnitLabelTopShare = 0.4;

/// `min(200, 0.4 × min(w, h))`, where `w × h` is [top], the served top's
/// box in definition space (`SymbolDefinitionRef.top`). An empty [top] (no
/// served top) gives the full height: today's rule for a definition whose
/// first leaf is neither a closed polyline nor a circle.
double unitLabelHeight(Aabb2 top) {
  if (top.isEmpty) return kUnitLabelMaxHeight;
  final side = math.min(top.maxX - top.minX, top.maxY - top.minY);
  return math.min(kUnitLabelMaxHeight, kUnitLabelTopShare * side);
}

/// The rotation and width factor that make a label owned by an instance
/// whose definition-to-world map is [instanceToWorld] read left to right,
/// unmirrored, along world +x (T10). The only place this is computed.
///
/// With the linear part's columns `(a, b)`, `(c, d)`, `φ = atan2(b, a)`:
/// a proper map (`det > 0`) takes rotation `−φ` and width factor `+1`; a
/// mirrored one takes `φ + π` and `−1`, since a reflection is
/// `R(φ) · diag(1, −1)` and the text's own map is `R(rot) · diag(wf, 1)`.
/// The rotation is normalised to `(−π, π]`, and `0.0` is stored for `−0.0`.
({double rotation, double widthFactor}) unitLabelStamp(
    Transform2 instanceToWorld) {
  final phi = math.atan2(instanceToWorld.b, instanceToWorld.a);
  final det = instanceToWorld.a * instanceToWorld.d -
      instanceToWorld.b * instanceToWorld.c;
  final mirrored = det < 0;
  var rotation = mirrored ? phi + math.pi : -phi;
  if (rotation > math.pi) rotation -= 2 * math.pi;
  if (rotation <= -math.pi) rotation += 2 * math.pi;
  if (rotation == 0) rotation = 0.0;
  return (rotation: rotation, widthFactor: mirrored ? -1.0 : 1.0);
}

/// `textAttrs` of every unit label: centred on its anchor both ways, the
/// width factor its own (bit 8), so a mirror can be undone by `−1`.
final int kUnitLabelTextAttrs = packTextAttrs(
    h: TextJustifyH.centre, v: TextJustifyV.middle, overrideWidthFactor: true);

/// The label payload, in definition space: [anchor], then
/// `[height, rotation, widthFactor]` stamped for [instanceToWorld].
GeometryPayload unitLabelPayload(
    {required Vector2 anchor,
    required double height,
    required Transform2 instanceToWorld}) {
  final s = unitLabelStamp(instanceToWorld);
  return GeometryPayload(
    coords: Float64List.fromList([anchor.x, anchor.y]),
    scalars: Float64List.fromList([height, s.rotation, s.widthFactor]),
  );
}

/// A generated unit's label (spec 2b S2, E5): [text] tagged
/// [kUnitLabelTag], anchored at [anchor] (the definition's base point),
/// its height from [top] (the definition's top box) and its stamp from
/// [instanceToWorld] (the object's world map times the instance's
/// transform, `view.toWorld(self).multiply(instanceTransform)`). The
/// payload is in the instance's local (definition) space, so a kit never
/// re-derives it. The text is not checked: a label outside the text rule
/// is the plan library's `unit.bad_label`.
GeneratedAttrib unitLabelAttrib(String text,
        {required Transform2 instanceToWorld,
        required Vector2 anchor,
        required Aabb2 top}) =>
    GeneratedAttrib(
        kUnitLabelTag,
        text,
        unitLabelPayload(
            anchor: anchor,
            height: unitLabelHeight(top),
            instanceToWorld: instanceToWorld),
        textAttrs: kUnitLabelTextAttrs);
