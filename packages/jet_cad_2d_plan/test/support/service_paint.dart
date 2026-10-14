// The service canvas's painted layers over one session, for the painter
// and invariant tests (2b Task 15): today's mounting in jet_cad_floor_plan's
// ServiceView (host/service_view.dart:282-351, :558-599), which Task 16's
// PlanServiceView repeats. The underlay is the group frames, then the unit
// colours and statuses (under the drafting); the overlay is the focus veil,
// then the group chips (above the drafting, under the selection outlines).
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:jet_cad_2d_plan/src/service/paint/unit_focus_painter.dart';
import 'package:jet_cad_2d_plan/src/service/paint/unit_group_painter.dart';
import 'package:jet_cad_2d_plan/src/service/paint/unit_status_painter.dart';
import 'package:jet_cad_2d_plan/src/service/service_session.dart';
import 'package:jet_cad_2d_plan/src/theme/plan_theme.dart' show PlanTheme;

/// The four painters of one service session and what they repaint on.
final class ServicePaintLayers {
  ServicePaintLayers(
      {required PlanController controller,
      required ServiceSession session,
      required bool Function() darkCanvas})
      : _c = controller,
        _session = session,
        _darkCanvas = darkCanvas {
    _changes = session.document.changes.listen((_) => _changed.bump());
  }

  final PlanController _c;
  final ServiceSession _session;
  final bool Function() _darkCanvas;

  /// The paper under the statuses, ARGB (dark theme spec D6c): the view
  /// sets it where today's did (`service_view.dart:429-451`).
  final ValueNotifier<int> paper = ValueNotifier<int>(0xFFFFFFFF);

  /// The resolved look: the view sets it from `PlanTheme.of` in
  /// `didChangeDependencies`.
  final ValueNotifier<PlanTheme?> theme = ValueNotifier<PlanTheme?>(null);

  final _Bump _changed = _Bump();
  StreamSubscription<DocChange>? _changes;

  /// The unit colours and statuses (today's TableStatusPainter mount).
  late final UnitStatusPainter statuses = UnitStatusPainter(
    document: _session.document,
    units: _session.units,
    camera: _c.camera,
    statuses: _c.unitStatuses,
    unitGroups: _c.unitGroups,
    groupStatuses: _c.groupStatuses,
    paper: paper,
    theme: theme,
    darkCanvas: _darkCanvas,
    repaint: Listenable.merge([
      _c.camera,
      _c.unitStatuses,
      _c.unitGroups,
      _c.groupStatuses,
      _changed,
      paper,
      theme
    ]),
  );

  late final Listenable _groupRepaint = Listenable.merge(
      [_c.camera, _c.unitGroups, _c.unitFocus, _changed, paper, theme]);

  /// The group frames, under the status fills.
  late final UnitGroupPainter frames = _groupPainter(UnitGroupLayer.frames);

  /// The group label chips, above the drafting.
  late final UnitGroupPainter chips = _groupPainter(UnitGroupLayer.chips);

  UnitGroupPainter _groupPainter(UnitGroupLayer layer) => UnitGroupPainter(
        layer: layer,
        document: _session.document,
        units: _session.units,
        camera: _c.camera,
        groups: _c.unitGroups,
        paper: paper,
        unitFocus: _c.unitFocus,
        theme: theme,
        repaint: _groupRepaint,
      );

  /// The veil over the units outside the host's focus.
  late final UnitFocusPainter focus = UnitFocusPainter(
    document: _session.document,
    units: _session.units,
    camera: _c.camera,
    focus: _c.unitFocus,
    paper: paper,
    theme: theme,
    repaint:
        Listenable.merge([_c.camera, _c.unitFocus, _changed, paper, theme]),
  );

  static Widget _layer(String key, CustomPainter painter) => RepaintBoundary(
        child:
            CustomPaint(key: Key(key), painter: painter, size: Size.infinite),
      );

  /// The frames under the status fills (G3), for `PlanCanvasView.underlay`.
  Widget get underlay => Stack(fit: StackFit.expand, children: [
        _layer('unit-group-layer', frames),
        _layer('unit-status-layer', statuses),
      ]);

  /// The focus's veil (Z13), then the label chips (G3, F-11), for
  /// `PlanCanvasView.overlay`.
  Widget get overlay => Stack(fit: StackFit.expand, children: [
        _layer('unit-focus-layer', focus),
        _layer('unit-group-chips', chips),
      ]);

  void dispose() {
    _changes?.cancel();
    _changed.dispose();
    paper.dispose();
    theme.dispose();
  }
}

/// A notifier whose every [bump] is one notification.
final class _Bump extends ChangeNotifier {
  void bump() => notifyListeners();
}
