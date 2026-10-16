// The wall-face attachment provider (spec 3a C5; umbrella A5; 09c D4, D6,
// D8): today's attachToWall over the kit's WallFaces, answering the plan
// library's AttachmentQuery. The capture and the edge snap are the query's
// (today's 16 px and snap aperture, which the plan passes); one capture,
// whether or not the query keeps an earlier answer (D-07); under
// mayRotate false only a face the symbol already faces (F-7, D-08).
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import 'wall_faces.dart';

/// The target kind the kit's symbols name in `attachTo`.
const String kWallFaceKind = 'wall-face';

/// The kit's provider for [services]' document: one per document, made by
/// the plan library from the kit's `attachments` (spec 2a P1, lifetimes).
AttachmentProvider wallFaceProvider(PlanServices services) =>
    _WallFaceProvider(services);

final class _WallFaceProvider implements AttachmentProvider {
  _WallFaceProvider(this._services);

  final PlanServices _services;

  @override
  String get kind => kWallFaceKind;

  /// [attachToWall] for the query's pointer over the document's faces, its
  /// footprint read as the symbol's box (front `minY`, back `maxY`, the
  /// inverse of `footprintOf`). The marker is the face point the symbol's
  /// back-centre lands on; the token is the run. Null for an empty
  /// footprint, for no face within the capture, for a query excluding
  /// more than one object (no caller asks it), and under `mayRotate:
  /// false` for a face the symbol's current turn does not face.
  @override
  Attachment? attach(AttachmentQuery query) {
    final f = query.footprint;
    if (f.isEmpty) return null;
    final exclude = query.exclude;
    if (exclude.length > 1) return null;
    final a = wallFacesOf(_services).attach(
      _services.document,
      SymbolBox(left: f.minX, right: f.maxX, front: f.minY, back: f.maxY),
      query.pointer,
      query.capture,
      mirrored: query.mirrored,
      edgeCaptureWorld: query.edgeCapture,
      exclude: exclude.isEmpty ? null : exclude.single,
      keep: query.mayRotate ? null : query.current,
    );
    if (a == null) return null;
    return Attachment(transform: a.transform, marker: a.q, token: a.run);
  }
}
