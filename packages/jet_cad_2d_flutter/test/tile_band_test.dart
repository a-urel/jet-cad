import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'support/tile_fixture.dart';

void main() {
  TileGrid gridAt(ViewportTransform camera) => TileGrid(
      anchor: camera, devicePixelRatio: kTileDpr, tileDevicePixels: 64);

  test('the bands partition the visible keys, in row order, without gaps', () {
    final camera = quantiseCamera(tileCamera(), kTileDpr);
    final grid = gridAt(camera);
    final bands = grid.bandsFor(camera, kTileViewport);
    final fromBands = bands.expand((b) => b.keys).toList();
    final visible = grid.visibleKeys(camera, kTileViewport).toList();

    expect(fromBands.toSet(), visible.toSet(),
        reason: 'every visible key belongs to exactly one band');
    expect(fromBands.length, visible.length, reason: 'and to only one');
    for (var i = 1; i < bands.length; i++) {
      expect(bands[i].row, bands[i - 1].row + 1,
          reason: 'rows are contiguous and ascending');
      expect(bands[i].deviceRect.top, bands[i - 1].deviceRect.bottom,
          reason: 'and the bands touch without gap or overlap');
    }
  });

  test('a band is one tile tall and the full union width', () {
    final camera = quantiseCamera(tileCamera(), kTileDpr);
    final bands = gridAt(camera).bandsFor(camera, kTileViewport);
    for (final band in bands) {
      expect(band.deviceRect.height, 64.0);
      expect(band.deviceRect.width, band.keys.length * 64.0);
    }
  });

  // The overhang is the point. `visibleKeys` yields every key the viewport
  // touches, including keys that extend past it, and a source sized to the
  // viewport has no pixels for those. This is M7's territory.
  test('the union overhangs the viewport, and the bands carry the overhang',
      () {
    final camera = quantiseCamera(tileCamera(), kTileDpr);
    final bands = gridAt(camera).bandsFor(camera, kTileViewport);
    final union =
        bands.map((b) => b.deviceRect).reduce((a, b) => a.expandToInclude(b));
    final device = Rect.fromLTWH(
        0, 0, kTileViewport.width * kTileDpr, kTileViewport.height * kTileDpr);
    expect(union.contains(device.topLeft), isTrue);
    expect(union.right, greaterThanOrEqualTo(device.right));
    expect(union.bottom, greaterThanOrEqualTo(device.bottom));
  });
}
