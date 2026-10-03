// The status layer (spec 14c S6, S7, R-3, R-4, R-14): each statused table's
// top filled in its status colour, under the drafting, with an optional
// caption. Not document state.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../host/floor_plan_types.dart';
import '../tables/table_index.dart';
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

/// Paints the statuses of [document]'s tables through [camera] (S7).
///
/// The fills are rebuilt when the statuses or the plan's state move; each
/// frame is an indexed loop over them that passes the same [Path], [Paint]
/// and [ui.Paragraph] objects and one reused matrix buffer to the canvas
/// (the allocation bar, measured structurally by its test). The matrix is
/// `camera . instance`, composed in doubles before it reaches the canvas.
class TableStatusPainter extends CustomPainter {
  TableStatusPainter({
    required this.document,
    required this.camera,
    required this.statuses,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final DraftDocument document;
  final ValueListenable<ViewportTransform> camera;
  final ValueListenable<Map<String, TableStatus>> statuses;

  List<_Fill> _fills = const [];
  int? _state;
  int? _tablesRevision;
  Map<String, TableStatus>? _builtFor;

  final Map<Handle, Path?> _paths = {};
  final Map<int, Paint> _paints = {};
  final Map<(String, int), ui.Paragraph> _captions = {};
  final Float64List _matrix = Float64List(16);

  /// Every `Path`, `Paint`, `Paragraph` and matrix this painter created: a
  /// second check of the allocation bar (S7).
  @visibleForTesting
  int debugAllocations = 0;

  /// How many paints and captions the caches hold (review F-8).
  @visibleForTesting
  int get debugCached => _paints.length + _captions.length;

  void _rebuild() {
    final map = statuses.value;
    final fills = <_Fill>[];
    if (map.isNotEmpty) {
      final survey = TableSurvey.of(document);
      for (final MapEntry(key: number, value: status) in map.entries) {
        for (final t in survey.withNumber(number)) {
          final node = document.tree[t.instance];
          if (node is! InstanceNode) continue;
          final layer = document.tables.layers[node.layer];
          if (layer != null && !layer.visible) continue;
          final path = _paths.putIfAbsent(t.definition, () => _pathOf(t));
          if (path == null) continue;
          final bounds = path.getBounds();
          final colour = status.color.toARGB32();
          final paint = _paints.putIfAbsent(colour, () {
            debugAllocations++;
            return Paint()
              ..style = PaintingStyle.fill
              ..color = status.color;
          });
          final caption = status.caption;
          final label = _labelOf(t.label);
          fills.add(_Fill(
            t.instance,
            path,
            paint,
            caption == null || caption.isEmpty
                ? null
                : _captions
                    .putIfAbsent((caption, colour), () => _paragraph(caption)),
            label?.x ?? bounds.center.dx,
            label?.y ?? bounds.center.dy,
            label?.half ?? 0,
            math.min(bounds.width, bounds.height),
          ));
        }
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

  ui.Paragraph _paragraph(String text) {
    debugAllocations++;
    final b = ui.ParagraphBuilder(ui.ParagraphStyle(
        fontSize: kStatusCaptionSize, textAlign: TextAlign.center))
      ..pushStyle(ui.TextStyle(
          color: const Color(0xFF202020), fontSize: kStatusCaptionSize))
      ..addText(text);
    return b.build()..layout(const ui.ParagraphConstraints(width: 120));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final state = document.commands.stateId;
    final revision = document.tables.mutationRevision;
    final map = statuses.value;
    if (_state != state ||
        _tablesRevision != revision ||
        !identical(_builtFor, map)) {
      _rebuild();
      _state = state;
      _tablesRevision = revision;
      _builtFor = map;
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
      final below =
          math.max(kStatusCaptionSize, f.half * scale + kStatusCaptionGap);
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
      !identical(oldDelegate.statuses, statuses);
}
