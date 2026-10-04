// A table's number, drawn (spec 14a T2, T8, T10): an ATTRIB owned by the
// table's instance, tag `TABLE`, its text the number, anchored at the
// symbol's base point and stamped so it reads upright in world whatever the
// instance's rotation and mirror.
//
// No Flutter import: this file is Dart over `package:jet_cad_2d` only.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// The tag of the ATTRIB that holds a table's number (T2).
const String kTableLabelTag = 'TABLE';

/// The label's height on a top of 500 mm and more, in drawing units (T8).
const double kTableLabelMaxHeight = 200;

/// The share of the top's smaller side a label may take (T8).
const double kTableLabelTopShare = 0.4;

/// `min(200, 0.4 × min(w, h))`, where `w × h` is the local bounding box of
/// the served top: the definition's first leaf (14s S4), a closed polyline
/// or a circle. Any other kind gives the full height.
double tableLabelHeight(EntityKind kind, GeometryPayload top) {
  final double side;
  switch (kind) {
    case EntityKind.circle:
      side = 2 * top.scalars[0];
    case EntityKind.polyline:
      final c = top.coords;
      var minX = c[0], maxX = c[0], minY = c[1], maxY = c[1];
      for (var i = 2; i + 1 < c.length; i += 2) {
        minX = math.min(minX, c[i]);
        maxX = math.max(maxX, c[i]);
        minY = math.min(minY, c[i + 1]);
        maxY = math.max(maxY, c[i + 1]);
      }
      side = math.min(maxX - minX, maxY - minY);
    default:
      return kTableLabelMaxHeight;
  }
  return math.min(kTableLabelMaxHeight, kTableLabelTopShare * side);
}

/// The rotation and width factor that make a label owned by an instance
/// placed by [placement] read left to right, unmirrored, along world +x
/// (T10). The only place this is computed.
///
/// With the linear part's columns `(a, b)`, `(c, d)`, `φ = atan2(b, a)`:
/// a proper placement (`det > 0`) takes rotation `−φ` and width factor `+1`;
/// a mirrored one takes `φ + π` and `−1`, since a reflection is
/// `R(φ) · diag(1, −1)` and the text's own map is `R(rot) · diag(wf, 1)`.
/// The rotation is normalised to `(−π, π]`, and `0.0` is stored for `−0.0`.
({double rotation, double widthFactor}) tableLabelStamp(Transform2 placement) {
  final phi = math.atan2(placement.b, placement.a);
  final det = placement.a * placement.d - placement.b * placement.c;
  final mirrored = det < 0;
  var rotation = mirrored ? phi + math.pi : -phi;
  if (rotation > math.pi) rotation -= 2 * math.pi;
  if (rotation <= -math.pi) rotation += 2 * math.pi;
  if (rotation == 0) rotation = 0.0;
  return (rotation: rotation, widthFactor: mirrored ? -1.0 : 1.0);
}

/// `textAttrs` of every table label: centred on its anchor both ways, the
/// width factor its own (bit 8), so a mirror can be undone by `−1`.
final int kTableLabelTextAttrs = packTextAttrs(
    h: TextJustifyH.centre, v: TextJustifyV.middle, overrideWidthFactor: true);

/// The label payload: [anchor], `[height, rotation, widthFactor]` stamped
/// for [placement].
GeometryPayload tableLabelPayload(
    {required Vector2 anchor,
    required double height,
    required Transform2 placement}) {
  final s = tableLabelStamp(placement);
  return GeometryPayload(
    coords: Float64List.fromList([anchor.x, anchor.y]),
    scalars: Float64List.fromList([height, s.rotation, s.widthFactor]),
  );
}

/// [payload] re-stamped for [placement]: anchor and height kept, rotation
/// and width factor replaced. Null when they already match by exact `==`
/// (stored values), so a translation writes nothing (T12).
GeometryPayload? restampedTableLabel(
    GeometryPayload payload, Transform2 placement) {
  final s = tableLabelStamp(placement);
  final scalars = payload.scalars;
  if (scalars.length >= 3 &&
      scalars[1] == s.rotation &&
      scalars[2] == s.widthFactor) {
    return null;
  }
  return GeometryPayload(
    coords: Float64List.fromList(payload.coords),
    scalars: Float64List.fromList([
      scalars.isEmpty ? kTableLabelMaxHeight : scalars[0],
      s.rotation,
      s.widthFactor,
    ]),
  );
}

/// The label record of a table: owned by [instance], on layer 0 (so it
/// follows the instance's layer, spec 12b S-2), BYBLOCK style, the
/// standard text style, tag `TABLE`, text [number] (T8).
EntityRecord tableLabelRecord(
        {required Handle handle,
        required Handle instance,
        required String number}) =>
    EntityRecord(
      handle: handle,
      owner: instance,
      kind: EntityKind.attrib,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byBlockLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByBlockColor(),
      lineweight: kByBlock,
      transparency: kByBlock,
      flags: 0,
      text: number,
      tag: kTableLabelTag,
      textStyle: ReservedHandles.standardTextStyle,
      textAttrs: kTableLabelTextAttrs,
    );

/// The command that adds [number] as the label of [instance], an instance
/// of [definition] placed by [placement] (T13, T14). Allocates one handle.
AddEntityCommand addTableLabelCommand(
  DraftDocument doc, {
  required Handle instance,
  required Handle definition,
  required Transform2 placement,
  required String number,
}) {
  final def = doc.tree.definition(definition);
  final top = firstLeafOf(doc, definition);
  return AddEntityCommand(
    record: tableLabelRecord(
        handle: doc.handleSeed.next(), instance: instance, number: number),
    payload: tableLabelPayload(
      anchor: def?.basePoint ?? Vector2.zero(),
      height: top == null
          ? kTableLabelMaxHeight
          : tableLabelHeight(top.kind, top.payload),
      placement: placement,
    ),
  );
}

/// The lowest-handle leaf [owner] owns, or null. O(entities): at command
/// or document-change rate, never per frame.
({EntityKind kind, GeometryPayload payload})? firstLeafOf(
    DraftDocument doc, Handle owner) {
  final entities = doc.entities;
  int? best;
  for (final slot in entities.liveSlots) {
    if (entities.ownerAt(slot) != owner) continue;
    if (best == null ||
        entities.handleAt(slot).value < entities.handleAt(best).value) {
      best = slot;
    }
  }
  if (best == null) return null;
  return (
    kind: entities.kindAt(best),
    payload: doc.geometry.read(entities.geomIndexAt(best)),
  );
}
