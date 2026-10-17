// Ported from jet_cad_floor_plan/lib/src/service/table_status_painter.dart (2b spec S4 "Painting"): over units, placed and generated.
// The status layer (spec 14c S6, S7, R-3, R-4, R-14): each statused unit's
// top filled in its status colour, under the drafting, with an optional
// caption. A group's status (table-groups spec G3) fills every visible
// member over its own status, with one caption, under the lead. A unit
// with neither is filled in its colour, when the plan gives it one (plan
// colours spec PC-5), with no caption. The statuses are not document state;
// the colours are.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../../theme/plan_theme.dart' show PlanTheme, kUnitColourOpacity;
import '../../units/unit_components.dart' show UnitColour;
import '../../units/unit_index.dart' show UnitIndex, UnitIndexCache, UnitInfo;
import '../service_state.dart'
    show GroupUnit, UnitGroup, UnitStatus, groupIdsByLabel, inLeadOrder;
import '../unit_picker.dart' show CircleTop, PolygonTop, unitTopOf;

/// One filled unit, prebuilt at status-change or plan-change rate (R-3):
/// the frame reads it and creates nothing.
final class _Fill {
  _Fill(this.instance, this.toWorld, this.path, this.paint, this.caption,
      this.lx, this.ly, this.half, this.size, this.box);

  final Handle instance;

  /// Definition space to world: the unit's, captured at rebuild (a seat's
  /// is its row's group × its instance).
  final Transform2 toWorld;
  final Path path;
  final Paint paint;
  final ui.Paragraph? caption;

  /// The unit label's anchor and half its height, in definition space:
  /// the caption goes below the label (S7, review F-5).
  final double lx, ly, half;

  /// The top's smaller side, in definition space.
  final double size;

  /// The symbol's box in definition space: the caption is clamped below its
  /// bottom on screen, so it clears the chairs at any rotation (P7).
  final Aabb2 box;
}

/// The caption's height in logical pixels (S7).
const double kStatusCaptionSize = 11;

/// The gap between the unit label's bottom and the caption, in logical
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

/// Paints the statuses and colours of [document]'s units through [camera]
/// (S7; plan colours spec PC-5).
///
/// Each visible unit's fill is the first of a chain: its group's status
/// (table-groups spec G3: [groupStatuses], through [unitGroups]) when the
/// group has one, else its own [statuses] entry, else its colour (the
/// plan's `jetcad.unit_colour`, PC-4), so a status covers a colour. The
/// status rungs key by the unit's label; the colour rung needs none, so
/// an unlabelled unit is filled in its colour. A locked unit is filled
/// (spec S2); one on a hidden layer is not; a colour name this release does
/// not know fills nothing. A group status's caption is drawn once, under
/// the lead: the visible member with a top that [inLeadOrder] puts first
/// (a file duplicate ties to the lower handle). A colour has no caption.
///
/// A colour's fill is its hue — re-toned through `darkCanvasTone` when
/// [darkCanvas] says the canvas re-tones, as a room's tint is — at alpha
/// `round(255 * o)`, `o` the theme's `unitColourOpacity`, else
/// [kUnitColourOpacity] (PC-6), applied once at rebuild.
///
/// The design mode mounts this painter too, with no statuses and no groups
/// (PC-5): only the colours draw there.
///
/// The fills are rebuilt when the statuses, the groups, the unit index
/// ([units] gives a new one on a state, layer or lock change), the paper
/// or the theme move; each
/// frame is an indexed loop over them that passes the same [Path], [Paint]
/// and [ui.Paragraph] objects and one reused matrix buffer to the canvas
/// (the allocation bar, measured structurally by its test). The matrix is
/// `camera . toWorld` (the unit's world transform, captured at rebuild),
/// composed in doubles before it reaches the canvas.
///
/// A caption's ink follows what it sits on (dark theme spec D6c): the
/// status colour over [paper], through [statusCaptionInk]. The host puts
/// [paper] in [repaint] too (F-16), so a paper change repaints, and the
/// rebuild then builds each flipped caption once.
///
/// A caption sits below its unit label, but never above the unit's own box
/// on screen (P7): a status caption whose 11 px floor put it on the lower
/// chairs now clears them however the table is turned and mirrored. The
/// caption is drawn upright in screen space, so only the box's greatest
/// screen y is read.
///
/// The host's look, [theme] (host embedding API spec T-1, T-3), joins the
/// rebuild key: its `statusFillOpacity` multiplies each status colour's
/// alpha once, at rebuild, and the caption's ink is taken on that drawn
/// colour (S-6); its `statusCaptionStyle` styles the captions, the null
/// properties today's ([paintedTextStyle]).
class UnitStatusPainter extends CustomPainter {
  UnitStatusPainter({
    required this.document,
    required this.units,
    required this.camera,
    required this.statuses,
    required this.unitGroups,
    required this.groupStatuses,
    required this.paper,
    this.theme,
    this.darkCanvas,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final DraftDocument document;

  /// The document's units, as the session's cache holds them.
  final UnitIndexCache units;

  final ValueListenable<ViewportTransform> camera;
  final ValueListenable<Map<String, UnitStatus>> statuses;

  /// The host's groups and their statuses, as `PlanController`'s
  /// `unitGroups` and `groupStatuses` hold them (ids trimmed).
  final ValueListenable<Map<String, UnitGroup>> unitGroups;
  final ValueListenable<Map<String, UnitStatus>> groupStatuses;

  /// The paper under the statuses, ARGB: the page's background, or the
  /// theme's surface with no page (D4, D6c).
  final ValueListenable<int> paper;

  /// The resolved look (host embedding API spec T-3); null, or a null
  /// value, is today's. The host puts it in [repaint] too, so a theme
  /// change repaints, and the rebuild then builds what it changed.
  final ValueListenable<PlanTheme?>? theme;

  /// Whether the canvas re-tones its colours (dark canvas K3): a unit
  /// colour's hue is drawn through `darkCanvasTone` then, as a room's tint
  /// is; null: never. Read at rebuild. The canvas re-tones only on its dark
  /// paper, so a flip of it always moves [paper] too, which rebuilds.
  final bool Function()? darkCanvas;

  List<_Fill> _fills = const [];
  UnitIndex? _indexBuilt;
  Map<String, UnitStatus>? _builtFor;
  Map<String, UnitGroup>? _groupsBuilt;
  Map<String, UnitStatus>? _groupStatusesBuilt;
  int? _paperBuilt;
  PlanTheme? _themeBuilt;

  /// The caption's least distance below the label's anchor, in logical
  /// pixels: its size, set at rebuild (S7; T-1's `statusCaptionStyle`).
  double _captionSize = kStatusCaptionSize;

  final Map<Handle, Path?> _paths = {};

  /// Keyed by the drawn colour's ARGB (the status colour, its alpha
  /// multiplied by the theme's `statusFillOpacity`; or the unit colour at
  /// the theme's `unitColourOpacity`).
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

  void _rebuild(PlanTheme? look) {
    debugRebuilds++;
    final map = statuses.value;
    final groupMap = groupStatuses.value;
    final paperArgb = paper.value;
    final opacity = look?.statusFillOpacity;
    final style = look?.statusCaptionStyle;
    _captionSize = style?.fontSize ?? kStatusCaptionSize;
    final fills = <_Fill>[];
    // Every unit of the index, placed or generated; the colours live in
    // the document (PC-5).
    final index = units.current;
    final groupOf = groupMap.isEmpty
        ? const <String, String>{}
        : groupIdsByLabel(unitGroups.value);
    final tone = darkCanvas?.call() ?? false;
    final colourAlpha =
        (255 * (look?.unitColourOpacity ?? kUnitColourOpacity)).round();
    // Each visible unit with a top and a fill, in draw order (the index is
    // ascending by handle): its drawn colour, and its status when the fill
    // is one (a status's group id when it is the group's); per statused
    // group its members that may lead.
    final filled = <(UnitInfo, Path, Color, UnitStatus?, String?)>[];
    final candidates = <String, List<GroupUnit>>{};
    for (final u in index.units) {
      // The status rungs key by label; the colour rung needs none.
      final label = u.text;
      final id = label == null ? null : groupOf[label];
      final groupStatus = id == null ? null : groupMap[id];
      final status = label == null ? null : (groupStatus ?? map[label]);
      final colour = status == null
          ? document.components.get<UnitColour>(u.instance)?.swatch
          : null;
      if (status == null && colour == null) continue;
      // A hidden layer's unit is not filled; a locked one is (S2).
      if (!u.visible) continue;
      final path = _paths.putIfAbsent(u.definition, () => _pathOf(u));
      if (path == null) continue;
      final Color drawn;
      if (status != null) {
        // The theme's opacity multiplies the host colour's alpha, once.
        drawn = opacity == null
            ? status.color
            : status.color.withValues(alpha: status.color.a * opacity);
      } else {
        // A colour: its hue, toned on the dark canvas as a room's tint is,
        // at the theme's opacity, once (PC-5, PC-6).
        final rgb = tone
            ? darkCanvasTone(colour!.rgb, paperArgb & 0xFFFFFF)
            : colour!.rgb;
        drawn = Color((colourAlpha << 24) | rgb);
      }
      filled.add((u, path, drawn, status, groupStatus == null ? null : id));
      if (groupStatus != null) {
        (candidates[id!] ??= []).add(GroupUnit(
            handle: u.instance, label: label!, visible: true, locked: false));
      }
    }
    // The lead of each statused group: its caption's one place.
    final leads = <Handle>{
      for (final list in candidates.values) inLeadOrder(list).first.handle,
    };
    for (final (u, path, drawn, status, id) in filled) {
      final bounds = path.getBounds();
      final argb = drawn.toARGB32();
      final paint = _paints.putIfAbsent(argb, () {
        debugAllocations++;
        return Paint()
          ..style = PaintingStyle.fill
          ..color = drawn;
      });
      // Captions for a status only; a colour carries none.
      final caption = status?.caption;
      final captioned = caption != null &&
          caption.isNotEmpty &&
          (id == null || leads.contains(u.instance));
      final label = _labelOf(u.label);
      fills.add(_Fill(
        u.instance,
        u.toWorld,
        path,
        paint,
        captioned
            ? _captionOf(caption, argb,
                style?.color ?? statusCaptionInk(drawn, paperArgb), style)
            : null,
        label?.x ?? bounds.center.dx,
        label?.y ?? bounds.center.dy,
        label?.half ?? 0,
        math.min(bounds.width, bounds.height),
        u.box,
      ));
    }
    // Draw order (ascending handle), whatever the map's order.
    fills.sort((a, b) => a.instance.value.compareTo(b.instance.value));
    _fills = fills;
    // Paints and captions no fill holds are dropped (review F-8): a host
    // whose captions change ("12 min", "13 min") does not grow the caches.
    final paints = {for (final f in fills) f.paint};
    final captions = {for (final f in fills) f.caption};
    _paints.removeWhere((_, p) => !paints.contains(p));
    _captions.removeWhere((_, p) => !captions.contains(p));
  }

  /// The anchor and half height of the unit label [label], in the
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

  /// The unit's top as a local path, or null when it has none (R-8).
  Path? _pathOf(UnitInfo u) {
    final top = unitTopOf(document, u.definition);
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
    final index = units.current;
    final map = statuses.value;
    final groups = unitGroups.value;
    final groupMap = groupStatuses.value;
    final paperArgb = paper.value;
    final look = theme?.value;
    if (!identical(_indexBuilt, index) ||
        !identical(_builtFor, map) ||
        !identical(_groupsBuilt, groups) ||
        !identical(_groupStatusesBuilt, groupMap) ||
        _paperBuilt != paperArgb ||
        !identical(_themeBuilt, look)) {
      _rebuild(look);
      _indexBuilt = index;
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
      final t = f.toWorld;
      // camera . toWorld, in doubles.
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
      // Skipped when the unit is smaller on screen than its caption.
      final scale = math.sqrt((a * d - b * c).abs());
      if (f.size * scale < caption.maxIntrinsicWidth) continue;
      final sx = a * f.lx + c * f.ly + e;
      final sy = b * f.lx + d * f.ly + g;
      // Below the label: its half height on screen and a gap, at least
      // one caption height from the anchor.
      var below = math.max(_captionSize, f.half * scale + kStatusCaptionGap);
      // Never above the unit's own box: the caption clears the chairs
      // however the unit is turned (P7). The box is a parallelogram on
      // screen, so its greatest screen y is at a corner.
      final box = f.box;
      if (!box.isEmpty) {
        final y00 = b * box.minX + d * box.minY + g;
        final y10 = b * box.maxX + d * box.minY + g;
        final y01 = b * box.minX + d * box.maxY + g;
        final y11 = b * box.maxX + d * box.maxY + g;
        final bottom = math.max(math.max(y00, y10), math.max(y01, y11));
        below = math.max(below, bottom - sy + kStatusCaptionGap);
      }
      canvas
        ..save()
        ..translate(sx - caption.width / 2, sy + below)
        ..drawParagraph(caption, Offset.zero)
        ..restore();
    }
  }

  @override
  bool shouldRepaint(UnitStatusPainter oldDelegate) =>
      !identical(oldDelegate.document, document) ||
      !identical(oldDelegate.statuses, statuses) ||
      !identical(oldDelegate.unitGroups, unitGroups) ||
      !identical(oldDelegate.groupStatuses, groupStatuses) ||
      !identical(oldDelegate.paper, paper) ||
      !identical(oldDelegate.theme, theme) ||
      !identical(oldDelegate.units, units);
}
