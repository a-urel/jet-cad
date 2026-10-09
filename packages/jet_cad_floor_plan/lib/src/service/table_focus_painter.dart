// The focus's veil (zone spec Z11-Z13, Z16, Z17): in the selection mode,
// every table outside the host's focus lies under the paper at
// [kTableFocusVeilAlpha], above the drafting and under the group chips and
// the selection outlines. Not document state: never exported, printed or
// drawn in the design mode.
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../host/floor_plan_theme.dart' show FloorPlanTheme;
import 'table_picker.dart';

/// The veil's opacity (Z13): a faded table shows at 1 - 0.6 = 0.4 over the
/// paper.
const double kTableFocusVeilAlpha = 0.6;

/// The veil's colour on [paper] (ARGB) under [theme] (host embedding API
/// spec T-1, S-9): the theme's `focusVeilColor` with its alpha multiplied
/// by the opacity, else the paper's RGB at the opacity, the paper's own
/// alpha replaced (the paper is opaque). The opacity is the theme's
/// `focusVeilOpacity`, else [kTableFocusVeilAlpha]. With no theme, today's
/// veil. Read when a painter recolours, never per frame.
Color focusVeilColour(int paper, FloorPlanTheme? theme) {
  final opacity = theme?.focusVeilOpacity ?? kTableFocusVeilAlpha;
  final colour = theme?.focusVeilColor;
  return colour == null
      ? Color(paper).withValues(alpha: opacity)
      : colour.withValues(alpha: colour.a * opacity);
}

/// Paints the veil over [document]'s tables outside [focus] through
/// [camera] (Z12, Z13).
///
/// What fades is every candidate of [TablePicker.candidatesOf] (Z0) whose
/// number is not in the focus: an unnumbered table fades, a locked one
/// too; a table on a hidden layer is no candidate and draws nothing. With
/// a null focus nothing is built or drawn.
///
/// Each table contributes its quad, the four world corners of its
/// definition box, reversed when its transform mirrors, so that every quad
/// winds counter-clockwise and overlapping quads add up instead of
/// cancelling. The veil is the union of the faded quads minus the union of
/// the focused ones, one `Path.combine` per rebuild, so a focused table is
/// never veiled where a faded neighbour overlaps it. It is filled with the
/// RGB of [paper] (its alpha ignored, as the paper is opaque) at
/// [kTableFocusVeilAlpha], or as [theme] sets it ([focusVeilColour]).
///
/// Rebuilt only when the plan's state id or its tables' revision moves, or
/// the focus is replaced; a paper or a theme change only recolours the
/// [Paint]. Each
/// frame then draws the one prebuilt path with one reused [Paint] under one
/// reused matrix: nothing per table (Z16).
class TableFocusPainter extends CustomPainter {
  TableFocusPainter({
    required this.document,
    required this.camera,
    required this.focus,
    required this.paper,
    this.theme,
    required Listenable repaint,
  }) : super(repaint: repaint) {
    debugAllocations += 2; // the paint and the matrix
  }

  final DraftDocument document;
  final ValueListenable<ViewportTransform> camera;

  /// The host's focus, as `FloorPlanController.tableFocus` holds it.
  final ValueListenable<Set<String>?> focus;

  /// The paper, ARGB: the veil takes its RGB.
  final ValueListenable<int> paper;

  /// The resolved look (host embedding API spec T-3): its veil colour and
  /// opacity; null, or a null value, is today's. The host puts it in
  /// [repaint] too, so a theme change recolours.
  final ValueListenable<FloorPlanTheme?>? theme;

  final Paint _paint = Paint();
  final Float64List _matrix = Float64List(16);

  /// The definitions' boxes, for the painter's life: under `runtime` a
  /// definition cannot change (14c R-8).
  final Map<Handle, Aabb2> _boxes = {};

  Path? _region;
  int? _state;
  int? _tablesRevision;
  Set<String>? _builtFor;
  int? _paperBuilt;
  FloorPlanTheme? _themeBuilt;

  /// Every `Path`, `Paint` and buffer this painter created: the allocation
  /// bar (Z16).
  @visibleForTesting
  int debugAllocations = 0;

  /// How many times the veil was rebuilt.
  @visibleForTesting
  int debugRebuilds = 0;

  /// How many times the veil's colour was derived (a paper or a theme
  /// change; never per frame, host embedding API spec P-4).
  @visibleForTesting
  int debugRecolours = 0;

  void _rebuild(Set<String>? focused) {
    debugRebuilds++;
    _region = null;
    if (focused == null) return;
    debugAllocations += 2;
    final faded = Path(), kept = Path();
    var any = false;
    for (final c in TablePicker.candidatesOf(document,
        boxes: _boxes, leaves: document.leavesByOwner)) {
      final number = c.table.number;
      if (number != null && focused.contains(number)) {
        _addQuad(kept, c);
      } else {
        _addQuad(faded, c);
        any = true;
      }
    }
    if (!any) return;
    debugAllocations++;
    _region = Path.combine(PathOperation.difference, faded, kept);
  }

  /// [c]'s quad, counter-clockwise (y up) whatever its transform's sign.
  static void _addQuad(Path path, TableCandidate c) {
    final p = c.corners;
    path.moveTo(p[0], p[1]);
    if (c.transform.determinant > 0) {
      path
        ..lineTo(p[2], p[3])
        ..lineTo(p[4], p[5])
        ..lineTo(p[6], p[7]);
    } else {
      path
        ..lineTo(p[6], p[7])
        ..lineTo(p[4], p[5])
        ..lineTo(p[2], p[3]);
    }
    path.close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final state = document.commands.stateId;
    final revision = document.tables.mutationRevision;
    final focused = focus.value;
    if (_state != state ||
        _tablesRevision != revision ||
        !identical(_builtFor, focused)) {
      _rebuild(focused);
      _state = state;
      _tablesRevision = revision;
      _builtFor = focused;
    }
    final region = _region;
    if (region == null) return;
    final paperArgb = paper.value;
    final look = theme?.value;
    if (_paperBuilt != paperArgb || !identical(_themeBuilt, look)) {
      // The paper's RGB, its own alpha replaced, or the theme's colour.
      debugRecolours++;
      _paint.color = focusVeilColour(paperArgb, look);
      _paperBuilt = paperArgb;
      _themeBuilt = look;
    }
    final cam = camera.value.worldToScreenMatrix;
    final scale = math.sqrt((cam.a * cam.d - cam.b * cam.c).abs());
    if (scale == 0 || !scale.isFinite) return;
    final m = _matrix;
    m[0] = cam.a;
    m[1] = cam.b;
    m[4] = cam.c;
    m[5] = cam.d;
    m[10] = 1;
    m[12] = cam.e;
    m[13] = cam.f;
    m[15] = 1;
    canvas
      ..save()
      ..transform(m)
      ..drawPath(region, _paint)
      ..restore();
  }

  @override
  bool shouldRepaint(TableFocusPainter oldDelegate) =>
      !identical(oldDelegate.document, document) ||
      !identical(oldDelegate.camera, camera) ||
      !identical(oldDelegate.focus, focus) ||
      !identical(oldDelegate.paper, paper) ||
      !identical(oldDelegate.theme, theme);
}
