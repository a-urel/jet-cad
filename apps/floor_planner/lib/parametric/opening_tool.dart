import 'dart:ui' show Canvas, Offset, Rect;

import 'package:flutter/foundation.dart'
    show ValueNotifier, immutable, visibleForTesting;
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'opening.dart';
import 'opening_geometry.dart';
import 'wall_bands.dart';

/// An opening tool's settings (spec 08 D14, Ruling 08-17): the width of the
/// next opening, in mm. The shell owns one per kind; the Selection panel's
/// Opening section edits the active tool's.
@immutable
final class OpeningSettings {
  const OpeningSettings({required this.width});

  /// D14's defaults: 900 for a door, 1,200 for a window, 900 for a gap.
  factory OpeningSettings.defaultFor(OpeningKind kind) =>
      OpeningSettings(width: kind == OpeningKind.window ? 1200 : 900);

  final double width;

  OpeningSettings copyWith({double? width}) =>
      OpeningSettings(width: width ?? this.width);

  @override
  bool operator ==(Object other) =>
      other is OpeningSettings && other.width == width;

  @override
  int get hashCode => width.hashCode;

  @override
  String toString() => 'OpeningSettings($width)';
}

/// Where a click would put an opening (spec 08 D14): its parameters and its
/// cut (D8; null when it is no-fit).
typedef _Placement = ({OpeningParams params, Cut? cut});

/// Spec 08 D14: the Door (D), Window (N) and Gap (G) tools, one class and
/// three instances. A `PlacementTool` whose **first click commits** one
/// opening; the tool stays active, so a run of doors is a run of clicks,
/// and Escape (with nothing pending, ever) returns to the select tool.
///
/// - **The host** is the wall whose band contains the **raw** pointer, the
///   lowest handle when several do: [WallBands.hostAt], shared with the Wall
///   tool. The scan is not gated on object snap (Ruling 08-11): finding the
///   host is not a snap. No wall under the pointer: no preview, and a click
///   does nothing.
/// - **The position** is `u` of the **resolved** point (the snap chain's)
///   projected onto the host's centreline in its local space, unless an
///   **edge snap** wins (D15, [selfSnap]): with object snap on, an edge of
///   the would-be opening at the raw point's projection within the aperture
///   of one of the host's stretch ends or of its other openings' drawn cut
///   edges ([edgeSnap]) puts that edge on it, outright. What is
///   stored is the centre of the cut the opening would get there (D8): `u`
///   itself when it fits there, the clamped centre ([storedCentreOf]) when
///   it had to move into a stretch, `u` itself when it is no-fit.
/// - **A door's swing** is the side of the band's **midline** the raw
///   click lies on (D14 as amended, Ruling 08-23): `left` when
///   `(p − s)·n − (lOff + rOff)/2 ≥ 0`. **Its hinge** is `start` when the
///   stored centre is at most `L/2`, `end` otherwise. A window or a gap is
///   written `start` and `left`.
/// - **The commit** is one [CompoundCommand]: the opening's group at the
///   identity, then its `OpeningParams`. One undo step, in which the host
///   regenerates. A refused one (a malformed host from a file) places
///   nothing.
///
/// **The snap marker** ([markerPoint], Ruling 08-14) is drawn at the
/// projected point on the host's centreline, not at the chain's point.
///
/// **The frame cache** (Ruling 08-13): the hovered host's frame, stretches,
/// other openings and their drawn cuts, from the document adapter
/// ([wallsInDocument]). It is
/// rebuilt only when the hovered host changes, when the document reports a
/// change ([WallBands.generation]), and at every click. A pointer move over
/// the same host costs a projection, a placement and the preview's few
/// points.
class OpeningTool extends PlacementTool {
  /// [bands] is the band cache the shell shares with the Wall tool; without
  /// one the tool keeps its own.
  OpeningTool(this.kind, this.settings, {WallBands? bands})
      : _bands = bands ?? WallBands(),
        _ownsBands = bands == null;

  final OpeningKind kind;

  /// Owned by the shell; the tool only reads it, at each hover and click.
  final ValueNotifier<OpeningSettings> settings;

  final WallBands _bands;
  final bool _ownsBands;

  /// The context of the last pointer event, for [hovered], which has none.
  ToolContext? _context;

  /// The raw world point of the last press (Ruling 08-14): `accept` is
  /// handed the resolved point only.
  final Vector2 _raw = Vector2.zero();

  // The frame cache (Ruling 08-13).
  Handle? _frameHost;
  DraftDocument? _frameDocument;
  int _frameGeneration = -1;
  HostLayout? _layout;
  Transform2? _toWorld, _toLocal;
  List<(Handle, double, double)> _others = const [];

  /// The drawn cuts (D8) of [_others] that fit: [edgeSnap]'s candidates.
  List<(double, double)> _otherCuts = const [];

  // The last host scan (Ruling 08-12): [selfSnap] and [hovered] ask for the
  // same raw point on one move, and the scan runs once.
  DraftDocument? _scanDocument;
  int _scanGeneration = -1;
  double _scanX = double.nan, _scanY = double.nan;
  Handle? _scanHost;

  /// Whether the last resolution's self-snap was an edge snap, on which
  /// host, and the centre it gave, exactly (spec 08 D15): the world point
  /// handed on is only its image through the host's transform.
  bool _edgeSnapped = false;
  Handle? _edgeHost;
  double _edgeU = 0;

  /// The snap marker's point while a host is hovered: the projected point on
  /// its centreline (Ruling 08-14).
  final Vector2 _marker = Vector2.zero();
  bool _onHost = false;

  /// The hover preview, in world: the would-be symbol, then the would-be
  /// cut's two jamb lines. Built per pointer move, painted per frame.
  List<(EntityKind, GeometryPayload)> _preview = const [];

  /// How many times the frame cache was rebuilt.
  @visibleForTesting
  int debugFrameBuilds = 0;

  /// How many hover previews were built.
  @visibleForTesting
  int debugPreviewBuilds = 0;

  /// The hover preview, in world.
  @visibleForTesting
  List<(EntityKind, GeometryPayload)> get debugPreview => _preview;

  @override
  String get name => switch (kind) {
        OpeningKind.door => 'Door',
        OpeningKind.window => 'Window',
        OpeningKind.gap => 'Gap',
      };

  @override
  void onPointerMove(ToolPointerEvent e, ToolContext ctx) {
    _context = ctx;
    super.onPointerMove(e, ctx);
  }

  @override
  void onPointerDown(ToolPointerEvent e, ToolContext ctx) {
    _context = ctx;
    if (e.buttons & kPrimaryButton != 0) {
      _raw.setFrom(e.world);
      // Rebuilt at every click (Ruling 08-13), before the press resolves:
      // the change stream delivers after the current task, so an edit in
      // the same synchronous task as this click would otherwise leave the
      // scan, the frame and the edge snap stale.
      _bands.invalidate();
    }
    super.onPointerDown(e, ctx);
  }

  /// Spec 08 D15's edge snap, as 05 D4's self-snap: it wins outright over
  /// the chain. With object snap on and a host under [raw], the raw point
  /// is projected onto the host's centreline and [edgeSnap] is applied
  /// there; on a hit, the snapped centre's world point on the centreline.
  @override
  Vector2? selfSnap(Vector2 raw, double apertureWorld) {
    _edgeSnapped = false;
    final ctx = _context;
    if (ctx == null || !(ctx.snap?.objectSnap ?? true)) return null;
    final doc = ctx.document;
    final host = _hostAt(doc, raw);
    if (host == null || !_ready(doc, host)) return null;
    final layout = _layout!;
    final toWorld = _toWorld!;
    final f = layout.frame;
    final v = edgeSnap(
        layout.stretches,
        _otherCuts,
        f.uOf(_toLocal!.transformPoint(raw)),
        settings.value.width,
        // The aperture in the host's local units.
        apertureWorld / toWorld.scaleMagnitude);
    if (v == null) return null;
    _edgeSnapped = true;
    _edgeHost = host;
    _edgeU = v;
    return toWorld.transformPoint(f.at(v, 0));
  }

  /// The snap marker sits at the projected point on the hovered host's
  /// centreline (Ruling 08-14); elsewhere, at the chain's point.
  @override
  Vector2 get markerPoint => _onHost ? _marker : super.markerPoint;

  /// Runs after every hover's resolution, so [hoverPoint] is the resolved
  /// point and [raw] the pointer's.
  @override
  void hovered(Vector2 raw) {
    final ctx = _context;
    final host = ctx == null ? null : _hostAt(ctx.document, raw);
    if (host == null || !_ready(ctx!.document, host)) {
      _preview = const [];
      _onHost = false;
      return;
    }
    debugPreviewBuilds++;
    _preview = _previewOf(_place(host, raw, hoverPoint, null));
  }

  @override
  void accept(Vector2 point, ToolContext ctx) {
    final doc = ctx.document;
    _preview = const [];
    _onHost = false;
    final host = _hostAt(doc, _raw);
    if (host == null || !_ready(doc, host)) return;
    try {
      commit(ctx, () {
        // The new opening's handle, allocated first (after the permission
        // check, Ruling 05-3): the placement is decided among the host's
        // openings in ascending handle order (D8's "a wall keeps a piece"),
        // and this one takes its place there.
        final h = doc.handleSeed.next();
        final placed = _place(host, _raw, point, h);
        return CompoundCommand([
          AddNodeCommand(GroupNode(
              handle: h,
              parent: doc.rootHandle,
              transform: Transform2.identity(),
              children: const [])),
          SetComponentCommand<OpeningParams>(h, placed.params),
        ], label: 'Add $name');
      }, needs: const {
        Capability.structure,
        Capability.components,
        Capability.geometry,
      });
    } on ArgumentError {
      // A malformed host from a file: nothing is placed.
    } on StateError {
      // Likewise.
    } on DanglingReferenceError {
      // The host stopped being an object: nothing is placed.
    }
  }

  /// The wall whose band contains [raw] ([WallBands.hostAt]), scanned once
  /// per raw point and band generation.
  Handle? _hostAt(DraftDocument doc, Vector2 raw) {
    if (identical(doc, _scanDocument) &&
        _bands.generation == _scanGeneration &&
        raw.x == _scanX &&
        raw.y == _scanY) {
      return _scanHost;
    }
    final host = _bands.hostAt(doc, raw.x, raw.y);
    _scanDocument = doc;
    _scanGeneration = _bands.generation;
    _scanX = raw.x;
    _scanY = raw.y;
    return _scanHost = host;
  }

  /// Refreshes the frame cache for [host] (Ruling 08-13). False when [host]
  /// has no frame: not a live wall, or degenerate.
  bool _frameFor(DraftDocument doc, Handle host) {
    final generation = _bands.generation;
    if (host == _frameHost &&
        identical(doc, _frameDocument) &&
        generation == _frameGeneration) {
      return _layout != null;
    }
    debugFrameBuilds++;
    _frameHost = host;
    _frameDocument = doc;
    _frameGeneration = generation;
    final walls = wallsInDocument(doc, host);
    _layout = walls == null ? null : layoutOf(walls.host, walls.walls);
    _toWorld = walls?.host.toWorld;
    _toLocal = _toWorld?.invert();
    final layout = _layout;
    _others = layout == null
        ? const []
        : [
            for (final (h, o) in openingsInDocument(doc, host))
              (h, o.position, o.width),
          ];
    _otherCuts = layout == null
        ? const []
        : [
            for (final c in cutsOf(layout.frame, layout.stretches, [
              for (final (_, c, w) in _others) (c, w),
            ]).cuts)
              if (c != null) (c.a, c.b),
          ];
    return layout != null;
  }

  /// Whether an opening can be placed on [host] now: the settings hold a
  /// width the tools may give, and the frame cache holds [host]'s frame.
  bool _ready(DraftDocument doc, Handle host) =>
      isOpeningWidth(kind, settings.value.width) && _frameFor(doc, host);

  /// Where an opening [self] of this tool's kind and width goes on [host]
  /// for a press at [raw] resolved to [resolved] (spec 08 D14), once
  /// [_ready]. A null [self] is the hover's would-be opening: the handle the
  /// next commit allocates is above every handle in the document, so it is
  /// admitted after all of the host's openings.
  _Placement _place(Handle host, Vector2 raw, Vector2 resolved, Handle? self) {
    final w = settings.value.width;
    final layout = _layout!;
    final f = layout.frame;
    final toLocal = _toLocal!;
    // An edge snap's centre exactly; otherwise the resolved point projected.
    final u = _edgeSnapped && host == _edgeHost
        ? _edgeU
        : f.uOf(toLocal.transformPoint(resolved));
    _marker.setFrom(_toWorld!.transformPoint(f.at(u, 0)));
    _onHost = true;
    final cut = _cutAmong(layout, u, w, self);
    final c = cut == null || !cut.clamped
        ? u
        : storedCentreOf(layout.stretches, cut, w);
    // The raw click's side of the band's midline (D14 as amended, Ruling
    // 08-23): exactly on it swings left.
    final side =
        (toLocal.transformPoint(raw) - f.s).dot(f.n) - (f.lOff + f.rOff) / 2;
    final params = switch (kind) {
      OpeningKind.door => OpeningParams(host, c, w, kind,
          hinge: c <= f.len / 2 ? HingeEnd.start : HingeEnd.end,
          swing: side >= 0 ? SwingSide.left : SwingSide.right),
      _ => OpeningParams(host, c, w, kind),
    };
    return (params: params, cut: c == u ? cut : _cutAmong(layout, c, w, self));
  }

  /// The cut (D8) an opening [self] centred at [c], [w] wide, gets among the
  /// host's cached openings: admitted in ascending handle order, a null
  /// [self] after all of them.
  Cut? _cutAmong(HostLayout layout, double c, double w, Handle? self) {
    final before = self == null
        ? _others.length
        : [
            for (final (h, _, _) in _others)
              if (h.value < self.value) h,
          ].length;
    final openings = [
      for (final (_, oc, ow) in _others) (oc, ow),
    ]..insert(before, (c, w));
    return cutsOf(layout.frame, layout.stretches, openings).cuts[before];
  }

  /// The preview of [placed], in world: its symbol ([symbolOf], host-local
  /// to world through the host's transform, the opening's own group being
  /// at the identity), then, when it fits, its cut's two jamb lines across
  /// the band.
  List<(EntityKind, GeometryPayload)> _previewOf(_Placement placed) {
    final f = _layout!.frame;
    final toWorld = _toWorld!;
    final cut = placed.cut;
    Vector2 world(double u, double off) => toWorld.transformPoint(f.at(u, off));
    return [
      for (final g in symbolOf(f, placed.params, cut, toWorld))
        (g.kind, g.payload),
      if (cut != null)
        for (final u in [cut.a, cut.b])
          (
            EntityKind.line,
            linePayload(world(u, f.lOff), world(u, f.rOff)),
          ),
    ];
  }

  @override
  void dispose() {
    if (_ownsBands) _bands.dispose();
    super.dispose();
  }

  /// The would-be symbol and cut, from the payloads the last pointer move
  /// built; nothing is computed here.
  @override
  void paintRubberBand(Canvas canvas, Vector2 origin, double scale) {
    final preview = _preview;
    if (!hoverVisible || preview.isEmpty) return;
    final ox = origin.x, oy = origin.y;
    band.reset();
    // Indexed: no iterator per frame.
    for (var i = 0; i < preview.length; i++) {
      final (kind, p) = preview[i];
      final c = p.coords;
      if (kind == EntityKind.arc) {
        band.addArc(
            Rect.fromCircle(
                center: Offset(c[0] - ox, c[1] - oy), radius: p.scalars[0]),
            p.scalars[1],
            p.scalars[2]);
      } else {
        band
          ..moveTo(c[0] - ox, c[1] - oy)
          ..lineTo(c[2] - ox, c[3] - oy);
      }
    }
    canvas.drawPath(band, bandPaint);
  }
}
