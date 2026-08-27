// A drawing built to be looked at, not measured.
//
// The measurement corpus is 50,000 entities of generated clutter. A tile seam
// -- a sub-pixel disagreement between a baked tile and the live fallback drawn
// over the same world -- is invisible in it: the eye has nothing to hold still
// against. This corpus holds still.
//
// Gap G1 is why it exists at all. Software Skia does not antialias
// `drawVertices`, so no widget test in this repository can produce an
// antialiased seam. Looking at a GPU is the only instrument left, and this is
// what it looks at.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d/testing.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

/// Half-width and half-height of the drawing, in world units.
const double _halfWidth = 2000.0;
const double _halfHeight = 1500.0;

/// The grid's pitch, in world units.
///
/// **Deliberately not a divisor of the tile pitch.** At the initial fit the
/// 4000 x 3000 drawing scales by 0.4 to a 1600 x 1200 window, putting these
/// 150 units at 60 logical pixels against a 512-device-pixel tile -- 256
/// logical at dpr 2, or 4.267 grid steps per tile. A pitch that divided the
/// tile evenly would land every grid line on a tile boundary at the *same*
/// sub-pixel offset: either all of them would show a seam or none would. This
/// spreads them across the whole range of offsets, so one screen carries the
/// whole range.
const double _gridPitch = 150.0;

/// The fan's angles, in degrees.
///
/// Shallow angles dominate the list because antialias beading is a
/// shallow-angle phenomenon: a line at 45 degrees steps one pixel across for
/// every pixel down and hides the disagreement inside its own staircase. The
/// two steep entries are the control -- what a seam looks like when the
/// geometry is not helping you see it.
const List<double> _fanDegrees = [0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 45.0, 80.0];

/// Lineweights, in 1/100 mm.
///
/// Both regimes are on screen at once and that is the point. A 1 mm stroke is
/// wide enough to absorb a half-pixel shift; a hairline is not. Seeing which
/// one you are looking at requires the other in the same frame.
const int _hairline = 0;
const int _fanWeight = 50;
const int _circleWeight = 25;
const int _arcWeight = 100;

/// The drawing's centre.
///
/// **Far from the origin, where the measurement corpus lives.** A drawing at
/// (0, 0) is the degenerate fixture this repository keeps rediscovering: the
/// residual reaching float32 shrinks, `rebaseOriginFor` stops earning its
/// keep, and a seam that only appears six million units out never appears at
/// all. Simplifying the drawing must not quietly simplify the arithmetic
/// under it.
const double _centreX = kDefaultOriginX + kFloorWidth / 2;
const double _centreY = kOriginY + kFloorHeight / 2;

/// Builds the naked-eye corpus: a grid, a shallow fan, three circles and two
/// arcs -- about sixty entities.
///
/// [measurer] exists because `DraftCanvas` refuses a document that does not
/// carry a `FlutterTextMeasurer`, and the refusal is an `ArgumentError` thrown
/// while building. In profile mode that renders as a plain grey `ErrorWidget`:
/// no red screen, no message, and nothing in the run log -- a window that
/// simply comes up empty. This corpus draws no text, but it still has to be
/// paintable.
///
/// `main()` passes the harness's own measurer so one cache serves both
/// corpora. A caller that does not care gets a fresh one.
DraftDocument seamCorpus({FlutterTextMeasurer? measurer}) {
  final doc = DraftDocument.empty(measurer: measurer ?? FlutterTextMeasurer());

  // The grid. Verticals and horizontals are added in separate loops so a
  // truncation to one of them leaves the other standing -- see the mutation
  // log for Task 2 of Plan 3h, where a single-loop fixture saturated all four
  // edges independently and reddened nothing.
  for (var x = -_halfWidth; x <= _halfWidth; x += _gridPitch) {
    _line(doc, _centreX + x, _centreY - _halfHeight, _centreX + x,
        _centreY + _halfHeight,
        lineweight: _hairline);
  }
  for (var y = -_halfHeight; y <= _halfHeight; y += _gridPitch) {
    _line(doc, _centreX - _halfWidth, _centreY + y, _centreX + _halfWidth,
        _centreY + y,
        lineweight: _hairline);
  }

  // The fan, drawn through the centre so each angle crosses the grid.
  const reach = 2100.0;
  for (final degrees in _fanDegrees) {
    final radians = degrees * math.pi / 180.0;
    final dx = reach * math.cos(radians), dy = reach * math.sin(radians);
    _line(doc, _centreX - dx, _centreY - dy, _centreX + dx, _centreY + dy,
        lineweight: _fanWeight, color: const TrueColor(0xCC2222));
  }

  // Circles: a curve crosses a tile boundary at every angle at once, which no
  // straight line does.
  for (final radius in const [400.0, 900.0, 1500.0]) {
    _curve(doc, EntityKind.circle, [radius],
        lineweight: _circleWeight, color: const TrueColor(0x2266CC));
  }

  // Arcs: the same curve with ends, so a seam at a stroke cap is reachable
  // too.
  _curve(doc, EntityKind.arc, [1200.0, 0.3, 2.0],
      lineweight: _arcWeight, color: const TrueColor(0x22AA55));
  _curve(doc, EntityKind.arc, [1800.0, 3.4, 1.2],
      lineweight: _arcWeight, color: const TrueColor(0x22AA55));

  return doc;
}

void _line(DraftDocument doc, double x0, double y0, double x1, double y1,
        {required int lineweight, DraftColor color = const ByLayerColor()}) =>
    _add(doc, EntityKind.line, [x0, y0, x1, y1], const [],
        lineweight: lineweight, color: color);

void _curve(DraftDocument doc, EntityKind kind, List<double> scalars,
        {required int lineweight, required DraftColor color}) =>
    _add(doc, kind, [_centreX, _centreY], scalars,
        lineweight: lineweight, color: color);

void _add(DraftDocument doc, EntityKind kind, List<double> coords,
    List<double> scalars,
    {required int lineweight, required DraftColor color}) {
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: doc.handleSeed.next(),
      owner: doc.rootHandle,
      kind: kind,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: color,
      lineweight: lineweight,
      transparency: kByLayer,
      flags: 0,
    ),
    payload: GeometryPayload(
      coords: Float64List.fromList(coords),
      scalars: Float64List.fromList(scalars),
    ),
  ));
}
