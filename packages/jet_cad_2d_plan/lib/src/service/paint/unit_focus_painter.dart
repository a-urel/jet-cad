// Ported from jet_cad_floor_plan/lib/src/service/table_focus_painter.dart (2b spec S4 "Painting"): over units, placed and generated.
// The focus's veil (zone spec Z11-Z13, Z16, Z17): in the service,
// every unit outside the host's focus lies under the paper at
// [kUnitFocusVeilAlpha], above the drafting and under the group chips and
// the selection outlines. Not document state: never exported, printed or
// drawn in the design mode.
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../../theme/plan_theme.dart' show PlanTheme;
import '../../units/unit_index.dart' show UnitIndex, UnitIndexCache;
import '../unit_picker.dart' show UnitCandidate, UnitPicker;

/// The veil's opacity (Z13): a faded unit shows at 1 - 0.6 = 0.4 over the
/// paper.
const double kUnitFocusVeilAlpha = 0.6;

/// The veil's colour on [paper] (ARGB) under [theme] (host embedding API
/// spec T-1, S-9): the theme's `focusVeilColor` with its alpha multiplied
/// by the opacity, else the paper's RGB at the opacity, the paper's own
/// alpha replaced (the paper is opaque). The opacity is the theme's
/// `focusVeilOpacity`, else [kUnitFocusVeilAlpha]. With no theme, today's
/// veil. Read when a painter recolours, never per frame.
Color focusVeilColour(int paper, PlanTheme? theme) {
  final opacity = theme?.focusVeilOpacity ?? kUnitFocusVeilAlpha;
  final colour = theme?.focusVeilColor;
  return colour == null
      ? Color(paper).withValues(alpha: opacity)
      : colour.withValues(alpha: colour.a * opacity);
}

/// Paints the veil over [document]'s units outside [focus] through
/// [camera] (Z12, Z13).
///
/// What fades is every candidate of [UnitPicker.candidatesOf] (Z0) whose
/// label is not in the focus: an unlabelled unit fades, a locked one
/// too; a unit on a hidden layer is no candidate and draws nothing. With
/// a null focus nothing is built or drawn.
///
/// Each unit contributes its quad, the four world corners of its
/// definition box, reversed when its transform mirrors, so that every quad
/// winds counter-clockwise and overlapping quads add up instead of
/// cancelling. The veil is the union of the faded quads minus the union of
/// the focused ones, one `Path.combine` per rebuild, so a focused unit is
/// never veiled where a faded neighbour overlaps it. It is filled with the
/// RGB of [paper] (its alpha ignored, as the paper is opaque) at
/// [kUnitFocusVeilAlpha], or as [theme] sets it ([focusVeilColour]).
///
/// Rebuilt only when [units] gives a new index (a state, layer or lock
/// change), or the focus is replaced; a paper or a theme change only
/// recolours the [Paint]. Each frame then draws the one prebuilt path with
/// one reused [Paint] under one reused matrix: nothing per unit (Z16).
class UnitFocusPainter extends CustomPainter {
  UnitFocusPainter({
    required this.document,
    required this.units,
    required this.camera,
    required this.focus,
    required this.paper,
    this.theme,
    required Listenable repaint,
  }) : super(repaint: repaint) {
    debugAllocations += 2; // the paint and the matrix
  }

  final DraftDocument document;

  /// The document's units, as the session's cache holds them.
  final UnitIndexCache units;

  final ValueListenable<ViewportTransform> camera;

  /// The host's focus, as `PlanController.unitFocus` holds it.
  final ValueListenable<Set<String>?> focus;

  /// The paper, ARGB: the veil takes its RGB.
  final ValueListenable<int> paper;

  /// The resolved look (host embedding API spec T-3): its veil colour and
  /// opacity; null, or a null value, is today's. The host puts it in
  /// [repaint] too, so a theme change recolours.
  final ValueListenable<PlanTheme?>? theme;

  final Paint _paint = Paint();
  final Float64List _matrix = Float64List(16);

  /// The definitions' boxes, for the painter's life: under `runtime` a
  /// definition cannot change (14c R-8).
  final Map<Handle, Aabb2> _boxes = {};

  Path? _region;
  UnitIndex? _indexBuilt;
  Set<String>? _builtFor;
  int? _paperBuilt;
  PlanTheme? _themeBuilt;

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
    for (final c in UnitPicker.candidatesOf(document, units.current,
        boxes: _boxes, leaves: document.leavesByOwner)) {
      final label = c.unit.text;
      if (label != null && focused.contains(label)) {
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
  static void _addQuad(Path path, UnitCandidate c) {
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
    final index = units.current;
    final focused = focus.value;
    if (!identical(_indexBuilt, index) || !identical(_builtFor, focused)) {
      _rebuild(focused);
      _indexBuilt = index;
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
  bool shouldRepaint(UnitFocusPainter oldDelegate) =>
      !identical(oldDelegate.document, document) ||
      !identical(oldDelegate.camera, camera) ||
      !identical(oldDelegate.focus, focus) ||
      !identical(oldDelegate.paper, paper) ||
      !identical(oldDelegate.theme, theme) ||
      !identical(oldDelegate.units, units);
}
