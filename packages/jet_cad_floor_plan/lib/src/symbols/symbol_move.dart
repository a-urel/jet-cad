// The wall-aware move (spec 09c D8): the Select tool's move resolver for a
// symbol tagged against-wall. Dragging one such symbol by its body near a
// wall's face attaches it as a placement does (D4), anchored on its
// plain-moved back-centre, so a drag along the wall stays on the face.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'symbol_library.dart';
import 'symbol_place_tool.dart' show kWallAttachPixels;
import 'symbol_section.dart';
import 'wall_attach.dart';

/// The shell's [MoveResolver] (D8) over its [faces] and its library.
final class SymbolMoveResolver implements MoveResolver {
  SymbolMoveResolver({required this.faces, required this.library});

  /// The shell's face cache, shared with the placement tool (D3).
  final WallFaces faces;

  /// The library when it is ready, read at each call; null: never attach.
  final SymbolLibrary? Function() library;

  /// For a root-level instance whose library entry carries
  /// [againstWallTag], with object snap on, the library ready and an
  /// orthonormal transform (W-8: a file's scaled instance never attaches,
  /// so its scale is never dropped): [attachToWall] for the plain-moved
  /// back-centre `delta · T · c` (S-1), its own instance excluded from the
  /// neighbours, its mirror kept; the marker is the face point. Else null.
  @override
  ({Transform2 transform, Vector2 marker})? resolveMove(
      ToolContext ctx, Handle node, Transform2 delta) {
    final doc = ctx.document;
    if (!(ctx.snap?.objectSnap ?? true)) return null;
    final lib = library();
    if (lib == null || !isSymbolInstance(doc, node)) return null;
    final entry = entryOfInstance(lib, doc, node);
    if (entry == null || !entry.tags.contains(againstWallTag)) return null;
    final instance = doc.tree[node]! as InstanceNode;
    final t = instance.transform;
    if (!isOrthonormal(t)) return null;
    final box = faces.boxOf(doc, instance.definition);
    if (box == null) return null;
    final p = delta.multiply(t).transformPoint(box.backCentre);
    final scale = ctx.camera.value.scale;
    final attached = faces.attach(doc, box, p, kWallAttachPixels / scale,
        mirrored: t.a * t.d - t.b * t.c < 0,
        edgeCaptureWorld: kSnapAperturePixels / scale,
        exclude: node);
    if (attached == null) return null;
    return (transform: attached.transform, marker: attached.q);
  }
}
