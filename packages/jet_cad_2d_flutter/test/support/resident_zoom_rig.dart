import 'dart:ui';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'gpu_comparison.dart';
import 'tile_fixture.dart';

/// The resident arm as a rig (Ruling F13): the collection frame a rebuild
/// would take at the gesture's start, re-collected whenever a frame's ratio
/// leaves the band -- `ResidentRebuilder`'s policy applied in-rig -- and
/// every frame compared against a live reference at the same camera.
///
/// **A frame out of band is drawn from the collection the rig has**, counted
/// in [staleFrames], and the re-collection lands for the NEXT frame, exactly
/// as the rebuilder's post-frame callback would order it.
class ResidentZoomRig {
  ResidentZoomRig(this.doc, this.measurer, ViewportTransform start,
      {this.bandLowerScale = kBandLowerScale,
      this.bandUpperScale = kBandUpperScale,
      this.size = kTileViewport,
      this.dpr = kTileDpr}) {
    _collectAt(start);
  }

  final DraftDocument doc;
  final FlutterTextMeasurer measurer;
  final double bandLowerScale, bandUpperScale;
  final Size size;
  final double dpr;

  late CollectionFrame collectionFrame;
  int rebuilds = 0;
  int staleFrames = 0;

  void _collectAt(ViewportTransform live) {
    collectionFrame = collectionFrameFor(live, doc.extents);
  }

  bool inBand(ViewportTransform live) {
    final ratio = live.scale / collectionFrame.camera.scale;
    return ratio >= bandLowerScale && ratio <= bandUpperScale;
  }

  Future<CompositedAgreement> frame(ViewportTransform live) async {
    final m = await measureCompositedAgreement(doc,
        collectionCamera: collectionFrame.camera,
        collectionViewport: collectionFrame.viewport,
        liveCamera: live,
        size: size,
        devicePixelRatio: dpr,
        pixelsPerPaperMm: kLogicalPixelsPerMm,
        measurer: measurer);
    if (!inBand(live)) {
      staleFrames++;
      _collectAt(live);
      rebuilds++;
    }
    return m;
  }
}
