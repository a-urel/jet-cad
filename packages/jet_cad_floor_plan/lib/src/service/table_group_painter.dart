// Table groups as the selection mode draws them (table-groups spec G3): a
// rounded frame around each group's members, under the status fills, and
// one label chip per group, above the drafting. Not document state: never
// exported, printed or drawn in the design mode.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Tolerance;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../host/floor_plan_types.dart' show TableGroup;
import 'table_groups.dart';
import 'table_picker.dart';
import 'table_status_painter.dart' show kStatusCaptionSize;

/// How far the frame stands off its members' boxes, in world millimetres;
/// also the radius of its round joins (G3).
const double kGroupFrameMarginMm = 150;

/// The frame's stroke width, in screen pixels (G3).
const double kGroupFrameStrokePixels = 2;

/// The chip's padding around its label, in logical pixels.
const double kGroupChipPaddingX = 5, kGroupChipPaddingY = 2;

/// The chip's corner radius, in logical pixels.
const double kGroupChipRadius = 4;

/// Which of the two layers a [TableGroupPainter] draws (G3).
enum TableGroupLayer {
  /// The frames: `PlannerView`'s underlay, under the status fills.
  frames,

  /// The label chips: `PlannerView`'s overlay, above the drafting.
  chips,
}

/// A group's label (G3): its own [TableGroup.label] when it has one, else
/// the distinct numbers of [members] in lead order joined by `+` (`3+7+12`,
/// never `3+3+7+12` for a file duplicate).
String groupLabel(TableGroup group, Iterable<GroupTable> members) {
  final label = group.label;
  if (label != null) return label;
  final seen = <String>{};
  return [
    for (final t in inLeadOrder(members))
      if (seen.add(t.number!)) t.number!
  ].join('+');
}

/// The convex hull of the points `x0, y0, x1, y1, ...` in [xy],
/// counter-clockwise (y up), as `x0, y0, ...` (Andrew's monotone chain).
/// A point within [tolerance] of the line through its neighbours is
/// dropped, as a repeated point is: keeping it would only add a join of no
/// sweep.
@visibleForTesting
List<double> convexHull(List<double> xy, Tolerance tolerance) {
  final n = xy.length ~/ 2;
  final order = List<int>.generate(n, (i) => i)
    ..sort((i, j) {
      final byX = xy[2 * i].compareTo(xy[2 * j]);
      return byX != 0 ? byX : xy[2 * i + 1].compareTo(xy[2 * j + 1]);
    });
  if (n < 3) {
    // One point, or two (distinct unless within the tolerance).
    if (n == 2) {
      final i = order[0], j = order[1];
      final dx = xy[2 * j] - xy[2 * i], dy = xy[2 * j + 1] - xy[2 * i + 1];
      if (math.sqrt(dx * dx + dy * dy) <= tolerance.linear) {
        return [xy[2 * i], xy[2 * i + 1]];
      }
      return [xy[2 * i], xy[2 * i + 1], xy[2 * j], xy[2 * j + 1]];
    }
    return [
      for (final i in order) ...[xy[2 * i], xy[2 * i + 1]]
    ];
  }
  // Whether b turns left of o -> a by more than the tolerance (b's distance
  // from the line o-a).
  bool left(int o, int a, int b) {
    final ox = xy[2 * o], oy = xy[2 * o + 1];
    final ax = xy[2 * a] - ox, ay = xy[2 * a + 1] - oy;
    final bx = xy[2 * b] - ox, by = xy[2 * b + 1] - oy;
    final len = math.sqrt(ax * ax + ay * ay);
    if (len <= tolerance.linear) return false;
    return (ax * by - ay * bx) / len > tolerance.linear;
  }

  final hull = <int>[];
  for (final i in order) {
    while (hull.length >= 2 && !left(hull[hull.length - 2], hull.last, i)) {
      hull.removeLast();
    }
    hull.add(i);
  }
  final lower = hull.length + 1;
  for (final i in order.reversed.skip(1)) {
    while (hull.length >= lower && !left(hull[hull.length - 2], hull.last, i)) {
      hull.removeLast();
    }
    hull.add(i);
  }
  hull.removeLast(); // the first point, repeated
  if (hull.length < 2) {
    return [xy[2 * order.first], xy[2 * order.first + 1]];
  }
  return [
    for (final i in hull) ...[xy[2 * i], xy[2 * i + 1]]
  ];
}

/// [hull] (counter-clockwise, as [convexHull] returns it) offset outwards
/// by [margin] with round joins of radius [margin], as a closed path: each
/// offset edge runs parallel to its hull edge, and each vertex is rounded
/// by a circular arc ([Path.arcTo], exact, not a polyline). One point gives
/// a circle, two a stadium.
@visibleForTesting
Path offsetHull(List<double> hull, double margin) {
  final n = hull.length ~/ 2;
  final path = Path();
  if (n == 1) {
    return path
      ..addOval(
          Rect.fromCircle(center: Offset(hull[0], hull[1]), radius: margin));
  }
  // The outward normal's angle of the edge from vertex i to i + 1 (the
  // right-hand normal of a counter-clockwise outline, y up).
  double normal(int i) {
    final j = (i + 1) % n;
    final dx = hull[2 * j] - hull[2 * i],
        dy = hull[2 * j + 1] - hull[2 * i + 1];
    return math.atan2(-dx, dy);
  }

  for (var i = 0; i < n; i++) {
    final from = normal((i - 1 + n) % n);
    var sweep = normal(i) - from;
    // A convex outline turns left by (0, pi] at each vertex (pi for a
    // segment's two ends); rounding cannot make it a near full turn.
    while (sweep < 0) {
      sweep += 2 * math.pi;
    }
    if (sweep > 1.5 * math.pi) sweep -= 2 * math.pi;
    if (sweep < 0) sweep = 0;
    path.arcTo(
        Rect.fromCircle(
            center: Offset(hull[2 * i], hull[2 * i + 1]), radius: margin),
        from,
        sweep,
        i == 0);
  }
  return path..close();
}

/// One group with a frame, prebuilt at rebuild rate (R-3, R-7): the frame
/// reads it and creates nothing.
final class _Group {
  _Group(this.order, this.frame, this.width, this.anchorX, this.anchorY,
      this.text, this.chip, this.rrect);

  /// The lowest member handle: the draw order.
  final int order;

  /// The world-space outline ([TableGroupLayer.frames] only).
  final Path? frame;

  /// The frame's bounds' width, in world units.
  final double width;

  /// The frame's top-most point (its bounds' centre x at its maximum
  /// world y): where the chip is centred.
  final double anchorX, anchorY;

  /// The label's text and its paragraph, laid out on one line
  /// ([TableGroupLayer.chips] only).
  final String? text;
  final ui.Paragraph? chip;

  /// The chip, in the paragraph's coordinates ([TableGroupLayer.chips]
  /// only).
  final RRect? rrect;
}

/// Paints [layer] of the groups of [groups] over [document]'s tables
/// through [camera] (G3).
///
/// A group with two or more visible members gets a frame: the convex hull
/// of the four corners of each such member's definition box (the
/// [picker]'s candidates and their cached `box`: a member on a hidden
/// layer, with a singular transform or an empty box is skipped, as the
/// picker skips it), offset by [kGroupFrameMarginMm] with round joins,
/// stroked [kGroupFrameStrokePixels] screen pixels wide in the paper set's
/// `gripMove`, never filled; and a chip, centred on the frame's top-most
/// point, filled `gripMove`, with [groupLabel] in the status caption's size
/// and the ink [foregroundFor] picks on `gripMove`. A chip is skipped when
/// the frame is narrower on screen than it.
///
/// Rebuilt only when the groups map is replaced, the plan's state id or
/// its tables' revision moves, or [paper] changes. Each frame then draws
/// the prebuilt paths under one reused matrix with one reused [Paint]
/// whose stroke width alone is set, or translates to each chip's anchor and
/// draws its prebuilt [RRect] and [ui.Paragraph] (14c S7, R-3).
class TableGroupPainter extends CustomPainter {
  TableGroupPainter({
    required this.layer,
    required this.document,
    required this.picker,
    required this.camera,
    required this.groups,
    required this.paper,
    required Listenable repaint,
  }) : super(repaint: repaint) {
    debugAllocations += 2; // the paint and the matrix
  }

  final TableGroupLayer layer;
  final DraftDocument document;

  /// The service copy's picker: its candidates are the visible tables with
  /// their cached definition boxes.
  final TablePicker picker;
  final ValueListenable<ViewportTransform> camera;

  /// The host's groups, as `FloorPlanController.tableGroups` holds them.
  final ValueListenable<Map<String, TableGroup>> groups;

  /// The paper, ARGB: its [PaperPalette.forPaper] set gives `gripMove`
  /// (dark theme spec D3, D4), as the view's own overlays.
  final ValueListenable<int> paper;

  late final Paint _paint = Paint()
    ..style = layer == TableGroupLayer.frames
        ? PaintingStyle.stroke
        : PaintingStyle.fill;
  final Float64List _matrix = Float64List(16);

  List<_Group> _groups = const [];
  int? _state;
  int? _tablesRevision;
  Map<String, TableGroup>? _builtFor;
  int? _paperBuilt;

  /// Keyed by (text, ink): a steady frame builds none.
  final Map<(String, Color), ui.Paragraph> _chips = {};

  /// Every `Path`, `Paint`, `Paragraph`, `RRect` and matrix this painter
  /// created: the allocation bar (spec invariant 1).
  @visibleForTesting
  int debugAllocations = 0;

  /// How many times the groups were rebuilt.
  @visibleForTesting
  int debugRebuilds = 0;

  /// The chips' texts, in draw order ([TableGroupLayer.chips]).
  @visibleForTesting
  List<String> get debugChipTexts => [
        for (final g in _groups)
          if (g.text case final text?) text
      ];

  void _rebuild() {
    debugRebuilds++;
    final map = groups.value;
    final gripMove = PaperPalette.forPaper(paper.value).gripMove;
    _paint.color = gripMove;
    final out = <_Group>[];
    if (map.isNotEmpty) {
      final candidates = picker.candidates;
      final byHandle = {for (final c in candidates) c.table.instance: c};
      final lookup = TableGroupLookup(map, [
        for (final c in candidates)
          GroupTable(
              handle: c.table.instance,
              number: c.table.number,
              visible: true,
              locked: c.locked),
      ]);
      final ink = foregroundFor(gripMove.toARGB32() & 0xFFFFFF) == 0xFFFFFF
          ? kStatusCaptionOnDark
          : kStatusCaptionOnLight;
      for (final MapEntry(key: id, value: group) in map.entries) {
        final members = lookup.visibleMembers(id);
        if (members.length < 2) continue;
        final xy = <double>[];
        for (final m in members) {
          final node = document.tree[m.handle];
          if (node is! InstanceNode) continue;
          final t = node.transform;
          final b = byHandle[m.handle]!.box;
          for (final (x, y) in [
            (b.minX, b.minY),
            (b.maxX, b.minY),
            (b.maxX, b.maxY),
            (b.minX, b.maxY),
          ]) {
            xy
              ..add(t.a * x + t.c * y + t.e)
              ..add(t.b * x + t.d * y + t.f);
          }
        }
        final hull = convexHull(xy, TablePicker.tolerance);
        // The offset outline's bounds are the hull's grown by the margin
        // (a round offset): not the path's, whose arcs' control points
        // reach further.
        var minX = double.infinity, maxX = -double.infinity;
        var maxY = -double.infinity;
        for (var i = 0; i < hull.length; i += 2) {
          minX = math.min(minX, hull[i]);
          maxX = math.max(maxX, hull[i]);
          maxY = math.max(maxY, hull[i + 1]);
        }
        Path? frame;
        String? text;
        ui.Paragraph? chip;
        RRect? rrect;
        if (layer == TableGroupLayer.frames) {
          debugAllocations++;
          frame = offsetHull(hull, kGroupFrameMarginMm);
        } else {
          final label = text = groupLabel(group, members);
          final p =
              _chips.putIfAbsent((label, ink), () => _paragraph(label, ink));
          chip = p;
          debugAllocations++;
          rrect = RRect.fromLTRBR(
              -kGroupChipPaddingX,
              -kGroupChipPaddingY,
              p.width + kGroupChipPaddingX,
              p.height + kGroupChipPaddingY,
              const Radius.circular(kGroupChipRadius));
        }
        out.add(_Group(
            members.first.handle.value,
            frame,
            maxX - minX + 2 * kGroupFrameMarginMm,
            (minX + maxX) / 2,
            maxY + kGroupFrameMarginMm,
            text,
            chip,
            rrect));
      }
      // Draw order: ascending lowest member handle, whatever the map's
      // order.
      out.sort((a, b) => a.order.compareTo(b.order));
    }
    _groups = out;
    final held = {for (final g in out) g.chip};
    _chips.removeWhere((_, p) => !held.contains(p));
  }

  /// The label on one line at its intrinsic width: never wrapped, so a
  /// 24-character label never breaks (G3).
  ui.Paragraph _paragraph(String text, Color ink) {
    debugAllocations++;
    final b = ui.ParagraphBuilder(
        ui.ParagraphStyle(fontSize: kStatusCaptionSize, maxLines: 1))
      ..pushStyle(ui.TextStyle(color: ink, fontSize: kStatusCaptionSize))
      ..addText(text);
    final p = b.build()
      ..layout(const ui.ParagraphConstraints(width: double.infinity));
    return p
      ..layout(
          ui.ParagraphConstraints(width: p.maxIntrinsicWidth.ceilToDouble()));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final state = document.commands.stateId;
    final revision = document.tables.mutationRevision;
    final map = groups.value;
    final paperArgb = paper.value;
    if (_state != state ||
        _tablesRevision != revision ||
        !identical(_builtFor, map) ||
        _paperBuilt != paperArgb) {
      _rebuild();
      _state = state;
      _tablesRevision = revision;
      _builtFor = map;
      _paperBuilt = paperArgb;
    }
    final list = _groups;
    if (list.isEmpty) return;
    final cam = camera.value.worldToScreenMatrix;
    final scale = math.sqrt((cam.a * cam.d - cam.b * cam.c).abs());
    if (scale == 0 || !scale.isFinite) return;
    if (layer == TableGroupLayer.frames) {
      final m = _matrix;
      m[0] = cam.a;
      m[1] = cam.b;
      m[4] = cam.c;
      m[5] = cam.d;
      m[10] = 1;
      m[12] = cam.e;
      m[13] = cam.f;
      m[15] = 1;
      _paint.strokeWidth = kGroupFrameStrokePixels / scale;
      canvas
        ..save()
        ..transform(m);
      for (var i = 0; i < list.length; i++) {
        canvas.drawPath(list[i].frame!, _paint);
      }
      canvas.restore();
      return;
    }
    for (var i = 0; i < list.length; i++) {
      final g = list[i];
      final p = g.chip!;
      final rrect = g.rrect!;
      // Skipped when the frame is narrower on screen than the chip.
      if (g.width * scale < rrect.width) continue;
      final sx = cam.a * g.anchorX + cam.c * g.anchorY + cam.e;
      final sy = cam.b * g.anchorX + cam.d * g.anchorY + cam.f;
      canvas
        ..save()
        ..translate(sx - p.width / 2, sy - p.height / 2)
        ..drawRRect(rrect, _paint)
        ..drawParagraph(p, Offset.zero)
        ..restore();
    }
  }

  @override
  bool shouldRepaint(TableGroupPainter oldDelegate) =>
      oldDelegate.layer != layer ||
      !identical(oldDelegate.document, document) ||
      !identical(oldDelegate.picker, picker) ||
      !identical(oldDelegate.camera, camera) ||
      !identical(oldDelegate.groups, groups) ||
      !identical(oldDelegate.paper, paper);
}
