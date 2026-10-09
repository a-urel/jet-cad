// The status layer (spec 14c S6, S7, R-3, R-4, R-14): each statused table's
// top filled in its status colour, under the drafting, with an optional
// caption. A group's status (table-groups spec G3) fills every visible
// member over its own status, with one caption, under the lead. Not
// document state.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../host/floor_plan_theme.dart' show FloorPlanTheme;
import '../host/floor_plan_types.dart';
import '../tables/table_index.dart';
import 'table_groups.dart';
import 'table_picker.dart';

/// One statused table, prebuilt at status-change or plan-change rate (R-3):
/// the frame reads it and creates nothing.
final class _Fill {
  _Fill(this.instance, this.path, this.paint, this.caption, this.lx, this.ly,
      this.half, this.size);

  final Handle instance;
  final Path path;
  final Paint paint;
  final ui.Paragraph? caption;

  /// The number label's anchor and half its height, in definition space:
  /// the caption goes below the number (S7, review F-5).
  final double lx, ly, half;

  /// The top's smaller side, in definition space.
  final double size;
}

/// The caption's height in logical pixels (S7).
const double kStatusCaptionSize = 11;

/// The gap between the number label's bottom and the caption, in logical
/// pixels.
const double kStatusCaptionGap = 2;

/// [colour] composited onto [paper]'s RGB (dark theme spec D6c), as
/// `0xRRGGBB`: straight alpha, per channel `round(a * s + (1 - a) * p)`
/// with `a` the colour's alpha over 255. The paper's own alpha is ignored:
/// the paper is opaque.
int over(Color colour, int paper) {
  final argb = colour.toARGB32();
  final a = ((argb >> 24) & 0xFF) / 255;
  var rgb = 0;
  for (final shift in const [16, 8, 0]) {
    final s = (argb >> shift) & 0xFF;
    final p = (paper >> shift) & 0xFF;
    rgb |= (a * s + (1 - a) * p).round() << shift;
  }
  return rgb;
}

/// The caption colour for a status [colour] on [paper] (D6c): the ink
/// [foregroundFor] picks for the colour over the paper, mapped to
/// [kStatusCaptionOnLight] (black ink, today's caption) or
/// [kStatusCaptionOnDark] (white ink). `foregroundFor` returns `0xRRGGBB`,
/// so this mapping is the only conversion: `Color(foregroundFor(...))`
/// would be fully transparent.
Color statusCaptionInk(Color colour, int paper) =>
    foregroundFor(over(colour, paper)) == 0xFFFFFF
        ? kStatusCaptionOnDark
        : kStatusCaptionOnLight;

/// A host's text [style] for painted text (host embedding API spec T-1,
/// T-4, S-3) with today's values where it leaves them null: [ink] as its
/// colour when it has none (a style with a foreground paint keeps it), and
/// [kStatusCaptionSize] as its size. Its family, weight and the rest as
/// given. Built when a painter rebuilds, never per frame.
TextStyle paintedTextStyle(TextStyle style, Color ink) => style.copyWith(
    color: style.color ?? ink, fontSize: style.fontSize ?? kStatusCaptionSize);

/// Paints the statuses of [document]'s tables through [camera] (S7).
///
/// Each visible table's effective status is its group's (table-groups spec
/// G3: [groupStatuses], through [tableGroups]) when the group has one, else
/// its own [statuses] entry. A group status's caption is drawn once, under
/// the lead: the visible member with a top that [inLeadOrder] puts first
/// (a file duplicate ties to the lower handle).
///
/// The fills are rebuilt when the statuses, the groups or the plan's state
/// move; each
/// frame is an indexed loop over them that passes the same [Path], [Paint]
/// and [ui.Paragraph] objects and one reused matrix buffer to the canvas
/// (the allocation bar, measured structurally by its test). The matrix is
/// `camera . instance`, composed in doubles before it reaches the canvas.
///
/// A caption's ink follows what it sits on (dark theme spec D6c): the
/// status colour over [paper], through [statusCaptionInk]. The host puts
/// [paper] in [repaint] too (F-16), so a paper change repaints, and the
/// rebuild then builds each flipped caption once.
///
/// The host's look, [theme] (host embedding API spec T-1, T-3), joins the
/// rebuild key: its `statusFillOpacity` multiplies each status colour's
/// alpha once, at rebuild, and the caption's ink is taken on that drawn
/// colour (S-6); its `statusCaptionStyle` styles the captions, the null
/// properties today's ([paintedTextStyle]).
class TableStatusPainter extends CustomPainter {
  TableStatusPainter({
    required this.document,
    required this.camera,
    required this.statuses,
    required this.tableGroups,
    required this.groupStatuses,
    required this.paper,
    this.theme,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final DraftDocument document;
  final ValueListenable<ViewportTransform> camera;
  final ValueListenable<Map<String, TableStatus>> statuses;

  /// The host's groups and their statuses, as `FloorPlanController`'s
  /// `tableGroups` and `groupStatuses` hold them (ids trimmed).
  final ValueListenable<Map<String, TableGroup>> tableGroups;
  final ValueListenable<Map<String, TableStatus>> groupStatuses;

  /// The paper under the statuses, ARGB: the page's background, or the
  /// theme's surface with no page (D4, D6c).
  final ValueListenable<int> paper;

  /// The resolved look (host embedding API spec T-3); null, or a null
  /// value, is today's. The host puts it in [repaint] too, so a theme
  /// change repaints, and the rebuild then builds what it changed.
  final ValueListenable<FloorPlanTheme?>? theme;

  List<_Fill> _fills = const [];
  int? _state;
  int? _tablesRevision;
  Map<String, TableStatus>? _builtFor;
  Map<String, TableGroup>? _groupsBuilt;
  Map<String, TableStatus>? _groupStatusesBuilt;
  int? _paperBuilt;
  FloorPlanTheme? _themeBuilt;

  /// The caption's least distance below the number's anchor, in logical
  /// pixels: its size, set at rebuild (S7; T-1's `statusCaptionStyle`).
  double _captionSize = kStatusCaptionSize;

  final Map<Handle, Path?> _paths = {};

  /// Keyed by the drawn colour's ARGB (the status colour, its alpha
  /// multiplied by the theme's `statusFillOpacity`).
  final Map<int, Paint> _paints = {};

  /// Keyed by (caption, drawn colour, ink, the theme's caption style): a
  /// paper flip that flips the ink builds the new paragraph once; steady
  /// frames build none (D6c).
  final Map<(String, int, Color, TextStyle?), ui.Paragraph> _captions = {};
  final Float64List _matrix = Float64List(16);

  /// Every `Path`, `Paint`, `Paragraph` and matrix this painter created: a
  /// second check of the allocation bar (S7).
  @visibleForTesting
  int debugAllocations = 0;

  /// How many times the fills were rebuilt (table-groups spec invariant 1:
  /// at rebuild rate only).
  @visibleForTesting
  int debugRebuilds = 0;

  /// How many paints and captions the caches hold (review F-8).
  @visibleForTesting
  int get debugCached => _paints.length + _captions.length;

  void _rebuild(FloorPlanTheme? look) {
    debugRebuilds++;
    final map = statuses.value;
    final groupMap = groupStatuses.value;
    final paperArgb = paper.value;
    final opacity = look?.statusFillOpacity;
    final style = look?.statusCaptionStyle;
    _captionSize = style?.fontSize ?? kStatusCaptionSize;
    final fills = <_Fill>[];
    // With neither map set nothing can fill: no survey.
    if (map.isNotEmpty || groupMap.isNotEmpty) {
      final survey = TableSurvey.of(document);
      final groupOf = groupMap.isEmpty
          ? const <String, String>{}
          : groupIdsByNumber(tableGroups.value);
      // Each visible table with a top and an effective status, in draw
      // order (the survey is ascending by handle), and per statused group
      // its members that may lead.
      final statused = <(TableInfo, Path, TableStatus, String?)>[];
      final candidates = <String, List<GroupTable>>{};
      for (final t in survey.tables) {
        final number = t.number;
        if (number == null) continue;
        final id = groupOf[number];
        final groupStatus = id == null ? null : groupMap[id];
        final status = groupStatus ?? map[number];
        if (status == null) continue;
        final node = document.tree[t.instance];
        if (node is! InstanceNode) continue;
        final layer = document.tables.layers[node.layer];
        if (layer != null && !layer.visible) continue;
        final path = _paths.putIfAbsent(t.definition, () => _pathOf(t));
        if (path == null) continue;
        statused.add((t, path, status, groupStatus == null ? null : id));
        if (groupStatus != null) {
          (candidates[id!] ??= []).add(GroupTable(
              handle: t.instance,
              number: number,
              visible: true,
              locked: false));
        }
      }
      // The lead of each statused group: its caption's one place.
      final leads = <Handle>{
        for (final list in candidates.values) inLeadOrder(list).first.handle,
      };
      for (final (t, path, status, id) in statused) {
        final bounds = path.getBounds();
        // The theme's opacity multiplies the host colour's alpha, once.
        final drawn = opacity == null
            ? status.color
            : status.color.withValues(alpha: status.color.a * opacity);
        final colour = drawn.toARGB32();
        final paint = _paints.putIfAbsent(colour, () {
          debugAllocations++;
          return Paint()
            ..style = PaintingStyle.fill
            ..color = drawn;
        });
        final caption = status.caption;
        final captioned = caption != null &&
            caption.isNotEmpty &&
            (id == null || leads.contains(t.instance));
        final label = _labelOf(t.label);
        fills.add(_Fill(
          t.instance,
          path,
          paint,
          captioned
              ? _captionOf(caption, colour,
                  style?.color ?? statusCaptionInk(drawn, paperArgb), style)
              : null,
          label?.x ?? bounds.center.dx,
          label?.y ?? bounds.center.dy,
          label?.half ?? 0,
          math.min(bounds.width, bounds.height),
        ));
      }
      // Draw order (ascending handle), whatever the map's order.
      fills.sort((a, b) => a.instance.value.compareTo(b.instance.value));
    }
    _fills = fills;
    // Paints and captions no fill holds are dropped (review F-8): a host
    // whose captions change ("12 min", "13 min") does not grow the caches.
    final paints = {for (final f in fills) f.paint};
    final captions = {for (final f in fills) f.caption};
    _paints.removeWhere((_, p) => !paints.contains(p));
    _captions.removeWhere((_, p) => !captions.contains(p));
  }

  /// The anchor and half height of the number label [label], in the
  /// instance's space; null when there is none.
  ({double x, double y, double half})? _labelOf(Handle? label) {
    if (label == null) return null;
    final e = document.entities;
    final slot = e.slotOf(label);
    if (slot == null) return null;
    final payload = document.geometry.read(e.geomIndexAt(slot));
    if (payload.coords.length < 2 || payload.scalars.isEmpty) return null;
    return (
      x: payload.coords[0],
      y: payload.coords[1],
      half: payload.scalars[0] / 2,
    );
  }

  /// The table's top as a local path, or null when it has none (R-8).
  Path? _pathOf(TableInfo t) {
    final top = tableTopOf(document, t.definition);
    if (top == null) return null;
    debugAllocations++;
    switch (top) {
      case PolygonTop(:final xy):
        final p = Path()..moveTo(xy[0], xy[1]);
        for (var i = 2; i + 1 < xy.length; i += 2) {
          p.lineTo(xy[i], xy[i + 1]);
        }
        return p..close();
      case CircleTop(:final cx, :final cy, :final r):
        return Path()
          ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    }
  }

  ui.Paragraph _captionOf(
          String caption, int colour, Color ink, TextStyle? style) =>
      _captions.putIfAbsent(
          (caption, colour, ink, style), () => _paragraph(caption, ink, style));

  /// Today's caption with no [style]; with one, the host's style with
  /// today's values where it leaves them null (T-1, T-4).
  ui.Paragraph _paragraph(String text, Color ink, TextStyle? style) {
    debugAllocations++;
    final ui.ParagraphBuilder b;
    if (style == null) {
      b = ui.ParagraphBuilder(ui.ParagraphStyle(
          fontSize: kStatusCaptionSize, textAlign: TextAlign.center))
        ..pushStyle(ui.TextStyle(color: ink, fontSize: kStatusCaptionSize));
    } else {
      final resolved = paintedTextStyle(style, ink);
      b = ui.ParagraphBuilder(
          resolved.getParagraphStyle(textAlign: TextAlign.center))
        ..pushStyle(resolved.getTextStyle());
    }
    b.addText(text);
    return b.build()..layout(const ui.ParagraphConstraints(width: 120));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final state = document.commands.stateId;
    final revision = document.tables.mutationRevision;
    final map = statuses.value;
    final groups = tableGroups.value;
    final groupMap = groupStatuses.value;
    final paperArgb = paper.value;
    final look = theme?.value;
    if (_state != state ||
        _tablesRevision != revision ||
        !identical(_builtFor, map) ||
        !identical(_groupsBuilt, groups) ||
        !identical(_groupStatusesBuilt, groupMap) ||
        _paperBuilt != paperArgb ||
        !identical(_themeBuilt, look)) {
      _rebuild(look);
      _state = state;
      _tablesRevision = revision;
      _builtFor = map;
      _groupsBuilt = groups;
      _groupStatusesBuilt = groupMap;
      _paperBuilt = paperArgb;
      _themeBuilt = look;
    }
    final fills = _fills;
    if (fills.isEmpty) return;
    final cam = camera.value.worldToScreenMatrix;
    final m = _matrix;
    for (var i = 0; i < fills.length; i++) {
      final f = fills[i];
      final node = document.tree[f.instance];
      if (node is! InstanceNode) continue;
      final t = node.transform;
      // camera . instance, in doubles.
      final a = cam.a * t.a + cam.c * t.b;
      final b = cam.b * t.a + cam.d * t.b;
      final c = cam.a * t.c + cam.c * t.d;
      final d = cam.b * t.c + cam.d * t.d;
      final e = cam.a * t.e + cam.c * t.f + cam.e;
      final g = cam.b * t.e + cam.d * t.f + cam.f;
      m[0] = a;
      m[1] = b;
      m[4] = c;
      m[5] = d;
      m[10] = 1;
      m[12] = e;
      m[13] = g;
      m[15] = 1;
      canvas
        ..save()
        ..transform(m)
        ..drawPath(f.path, f.paint)
        ..restore();
      final caption = f.caption;
      if (caption == null) continue;
      // Skipped when the table is smaller on screen than its caption.
      final scale = math.sqrt((a * d - b * c).abs());
      if (f.size * scale < caption.maxIntrinsicWidth) continue;
      final sx = a * f.lx + c * f.ly + e;
      final sy = b * f.lx + d * f.ly + g;
      // Below the number: its half height on screen and a gap, at least
      // one caption height from the anchor.
      final below = math.max(_captionSize, f.half * scale + kStatusCaptionGap);
      canvas
        ..save()
        ..translate(sx - caption.width / 2, sy + below)
        ..drawParagraph(caption, Offset.zero)
        ..restore();
    }
  }

  @override
  bool shouldRepaint(TableStatusPainter oldDelegate) =>
      !identical(oldDelegate.document, document) ||
      !identical(oldDelegate.statuses, statuses) ||
      !identical(oldDelegate.tableGroups, tableGroups) ||
      !identical(oldDelegate.groupStatuses, groupStatuses) ||
      !identical(oldDelegate.paper, paper) ||
      !identical(oldDelegate.theme, theme);
}
