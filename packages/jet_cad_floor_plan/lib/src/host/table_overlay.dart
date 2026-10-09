// The host's widgets on the tables (host embedding API spec G-5, G-6, G-7,
// H-8): a builder called per table, the layout that pins each widget to its
// table's box on the screen, the detail levels, and the layer that holds
// them over the canvas. Pan and zoom reposition the widgets; they never
// rebuild them (P-4).
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart' show Handle;
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show ViewportTransform;

import '../service/table_groups.dart' show groupIdsByNumber;
import 'floor_plan_controller.dart';
import 'floor_plan_types.dart';
import 'table_detail.dart';

/// One table as a [FloorPlanTableOverlayBuilder] sees it (spec G-5): what
/// the widget may show, and nothing that moves with the camera, so pan and
/// zoom never ask for a new widget.
@immutable
final class FloorPlanTableOverlay {
  const FloorPlanTableOverlay({
    required this.detail,
    required this.selected,
    required this.focused,
    required this.status,
    required this.detailLevel,
  });

  /// The table, its geometry, layer and lock, as
  /// `FloorPlanController.tableDetails` lists it. Always numbered and with
  /// geometry: a table with neither gets no overlay.
  final FloorPlanTableDetail detail;

  /// Whether the table's number is in `FloorPlanController.selectedTables`.
  /// Two tables sharing a number are both selected when it is.
  final bool selected;

  /// Whether the table's number is in `FloorPlanController.tableFocus`, or
  /// no focus is set.
  ///
  /// The overlays paint above the focus veil and the number chips, so the
  /// veil does not fade an unfocused table's widget: a host fades it with
  /// this flag.
  final bool focused;

  /// The status the selection mode draws on the table: its group's
  /// (`FloorPlanController.groupStatuses`) when its group has one, else its
  /// own (`FloorPlanController.tableStatuses`); null for none.
  final TableStatus? status;

  /// How many of [FloorPlanOverlayLayout.detailBreakpoints] are at or below
  /// the camera's scale (spec G-7): 0 with none.
  final int detailLevel;

  @override
  bool operator ==(Object other) =>
      other is FloorPlanTableOverlay &&
      other.detail == detail &&
      other.selected == selected &&
      other.focused == focused &&
      other.status == status &&
      other.detailLevel == detailLevel;

  @override
  int get hashCode =>
      Object.hash(detail, selected, focused, status, detailLevel);

  @override
  String toString() => 'FloorPlanTableOverlay(${detail.table.number}, '
      'selected: $selected, focused: $focused, status: $status, '
      'detailLevel: $detailLevel)';
}

/// The host's widget for one table (spec G-5), or null for none.
///
/// Called once per numbered table with geometry when the layer is built;
/// again for that table only when its [FloorPlanTableOverlay] changes (the
/// plan, the selection, the focus, a status, the detail level); and again
/// for every table each time the host rebuilds the `FloorPlanView`,
/// whatever the function: a closure written in `build` and a method
/// tear-off behave the same, so a builder that reads the host's own fields
/// sees them after the host's `setState`. Never on pan or zoom. Live data
/// inside the widget is the host's own state management.
typedef FloorPlanTableOverlayBuilder = Widget? Function(
    BuildContext context, FloorPlanTableOverlay table);

/// How an overlay is sized (spec G-6).
enum FloorPlanOverlaySize {
  /// The widget's own size at every zoom: laid out once, loosely, up to
  /// [FloorPlanOverlayLayout.maxNaturalSize].
  natural,

  /// The table's bounding box on the screen, exactly: laid out again on
  /// every camera change.
  ///
  /// Its cost per frame, for each overlay on the canvas: a [Size] and a
  /// [BoxConstraints] for the new box, and a layout and a paint of the
  /// host's widget at that size. Overlays off the canvas cost nothing.
  /// [natural] costs one paint offset per overlay on the canvas, and no
  /// layout.
  box,
}

/// Where and how the host's widgets sit on their tables (spec G-6, G-7).
@immutable
final class FloorPlanOverlayLayout {
  /// The defaults: a widget of its own size, centred on its table's box,
  /// at every zoom, ignoring pointers.
  ///
  /// The view throws an [ArgumentError] when it is built with a builder and
  /// a layout whose [detailBreakpoints] are not finite, positive and
  /// strictly ascending, whose [hideBelowScale] is negative or not finite,
  /// or whose [maxNaturalSize] is negative or not finite.
  const FloorPlanOverlayLayout({
    this.anchor = Alignment.center,
    this.size = FloorPlanOverlaySize.natural,
    this.maxNaturalSize = const Size(200, 120),
    this.hideBelowScale = 0,
    this.detailBreakpoints = const <double>[],
    this.interactive = false,
  });

  /// The point of the table's bounding box on the screen the widget is
  /// pinned to, and the widget's own point placed there, as [Align] places
  /// a child: [Alignment.center] centres the widget on the box,
  /// [Alignment.topLeft] puts its top left on the box's.
  final Alignment anchor;

  /// [FloorPlanOverlaySize.natural] or [FloorPlanOverlaySize.box].
  final FloorPlanOverlaySize size;

  /// The largest a [FloorPlanOverlaySize.natural] widget may be, in logical
  /// pixels.
  final Size maxNaturalSize;

  /// Below this camera scale (logical pixels per millimetre) no overlay is
  /// laid out or painted; 0 shows them at every scale.
  final double hideBelowScale;

  /// Camera scales, strictly ascending: [FloorPlanTableOverlay.detailLevel]
  /// counts those at or below the current scale. Crossing one builds every
  /// overlay once.
  final List<double> detailBreakpoints;

  /// Whether an overlay takes the pointers that land on it, so a tap on it
  /// is not the table's. Until interactive overlays arrive the layer
  /// ignores every pointer, whatever this says: each gesture reaches the
  /// canvas.
  final bool interactive;

  @override
  bool operator ==(Object other) =>
      other is FloorPlanOverlayLayout &&
      other.anchor == anchor &&
      other.size == size &&
      other.maxNaturalSize == maxNaturalSize &&
      other.hideBelowScale == hideBelowScale &&
      listEquals(other.detailBreakpoints, detailBreakpoints) &&
      other.interactive == interactive;

  @override
  int get hashCode => Object.hash(anchor, size, maxNaturalSize, hideBelowScale,
      Object.hashAll(detailBreakpoints), interactive);

  @override
  String toString() => 'FloorPlanOverlayLayout(anchor: $anchor, size: '
      '${size.name}, maxNaturalSize: $maxNaturalSize, hideBelowScale: '
      '$hideBelowScale, detailBreakpoints: $detailBreakpoints, interactive: '
      '$interactive)';
}

/// Throws an [ArgumentError] for a layout the view cannot use (spec G-7):
/// see [FloorPlanOverlayLayout]'s constructor.
@internal
void validateOverlayLayout(FloorPlanOverlayLayout layout) {
  final breakpoints = layout.detailBreakpoints;
  for (var i = 0; i < breakpoints.length; i++) {
    final b = breakpoints[i];
    if (!b.isFinite || b <= 0) {
      throw ArgumentError.value(breakpoints, 'detailBreakpoints',
          'must be finite and positive; $b is not');
    }
    if (i > 0 && b <= breakpoints[i - 1]) {
      throw ArgumentError.value(
          breakpoints, 'detailBreakpoints', 'must be strictly ascending');
    }
  }
  final hide = layout.hideBelowScale;
  if (!hide.isFinite || hide < 0) {
    throw ArgumentError.value(
        hide, 'hideBelowScale', 'must be finite and not negative');
  }
  final max = layout.maxNaturalSize;
  if (!max.width.isFinite ||
      !max.height.isFinite ||
      max.width < 0 ||
      max.height < 0) {
    throw ArgumentError.value(
        max, 'maxNaturalSize', 'must be finite and not negative');
  }
}

/// The detail level at camera [scale] (spec G-7): the number of
/// [breakpoints] at or below it.
@internal
int overlayDetailLevel(List<double> breakpoints, double scale) {
  var level = 0;
  // Indexed: an iterator would be an object per camera change.
  for (var i = 0; i < breakpoints.length; i++) {
    if (breakpoints[i] <= scale) level++;
  }
  return level;
}

/// The host's widgets over [controller]'s active plan (spec G-5, H-8): one
/// per numbered table with geometry, keyed by its instance, each behind a
/// [RepaintBoundary], placed by a [RenderFloorPlanOverlays].
///
/// Builds at the rate of the plan, the selection, the focus, the statuses,
/// the groups and the detail level, never at the camera's; such a build
/// builds again only the tables whose [FloorPlanTableOverlay] changed. A
/// new widget from the host's rebuild of the view builds every table again,
/// whatever [builder] is (G-5). The layer ignores pointers (G-5's
/// default).
class TableOverlayLayer extends StatefulWidget {
  const TableOverlayLayer(
      {super.key,
      required this.controller,
      required this.builder,
      required this.layout});

  final FloorPlanController controller;
  final FloorPlanTableOverlayBuilder builder;
  final FloorPlanOverlayLayout layout;

  @override
  State<TableOverlayLayer> createState() => _TableOverlayLayerState();
}

/// A table's built widget, kept while its value holds.
final class _Built {
  _Built(this.value, this.widget);

  final FloorPlanTableOverlay value;
  final Widget widget;
}

class _TableOverlayLayerState extends State<TableOverlayLayer> {
  /// The instance of each overlay, ascending (the draw order).
  List<Handle> _instances = const [];

  /// Each overlay's value, index for index with [_instances].
  List<FloorPlanTableOverlay> _values = const [];

  /// Each overlay's table's four world corners, `x0, y0, ..., x3, y3` per
  /// slot: the render object's box cache, rebuilt only when the instances
  /// or their details change (the plan's rate), never per frame.
  Float64List _corners = Float64List(0);

  int _level = 0;
  final Map<Handle, _Built> _built = {};

  /// A refresh waiting for the end of the frame: a source notified while
  /// the tree was being built or laid out.
  bool _deferred = false;

  List<Listenable> _sources(FloorPlanController c) => [
        c.revision,
        c.selectedTables,
        c.tableFocus,
        c.tableStatuses,
        c.tableGroups,
        c.groupStatuses,
      ];

  void _listen(FloorPlanController c) {
    for (final s in _sources(c)) {
      s.addListener(_onSource);
    }
    c.cameraController.addListener(_onCamera);
  }

  void _unlisten(FloorPlanController c) {
    for (final s in _sources(c)) {
      s.removeListener(_onSource);
    }
    c.cameraController.removeListener(_onCamera);
  }

  @override
  void initState() {
    super.initState();
    _listen(widget.controller);
    _recompute();
  }

  @override
  void didUpdateWidget(TableOverlayLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _unlisten(oldWidget.controller);
      _listen(widget.controller);
    }
    // The host rebuilt the view: every table again, whatever the builder
    // (G-5). A tear-off is == across the host's builds, yet may read the
    // host's fields that changed. The view hands down one widget per
    // build of its own, so the layer's internal rebuilds (a source, a
    // detail level) do not come here.
    _built.clear();
    _recompute();
  }

  @override
  void dispose() {
    _unlisten(widget.controller);
    super.dispose();
  }

  /// The camera moved: only a detail level crossed asks for a build.
  void _onCamera() {
    final level = overlayDetailLevel(widget.layout.detailBreakpoints,
        widget.controller.cameraController.value.scale);
    if (level != _level) _onSource();
  }

  void _onSource() {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      // Not while the tree is built or laid out: at the end of the frame.
      if (_deferred) return;
      _deferred = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _deferred = false;
        if (mounted) _onSource();
      });
      return;
    }
    if (_recompute()) setState(() {});
  }

  /// Recomputes every overlay's value; true when one changed.
  bool _recompute() {
    final c = widget.controller;
    final details = c.tableDetails;
    final instances = c.tableDetailInstances;
    final level = overlayDetailLevel(
        widget.layout.detailBreakpoints, c.cameraController.value.scale);
    final selected = c.selectedTables.value;
    final focus = c.tableFocus.value;
    final statuses = c.tableStatuses.value;
    final groupStatuses = c.groupStatuses.value;
    final groupOf = groupStatuses.isEmpty
        ? const <String, String>{}
        : groupIdsByNumber(c.tableGroups.value);
    final nextInstances = <Handle>[];
    final next = <FloorPlanTableOverlay>[];
    for (var i = 0; i < details.length; i++) {
      final d = details[i];
      final number = d.table.number;
      if (number == null || d.center == null) continue;
      final group = groupOf[number];
      nextInstances.add(instances[i]);
      next.add(FloorPlanTableOverlay(
        detail: d,
        selected: selected.contains(number),
        focused: focus == null || focus.contains(number),
        status:
            (group == null ? null : groupStatuses[group]) ?? statuses[number],
        detailLevel: level,
      ));
    }
    _level = level;
    final sameInstances = listEquals(nextInstances, _instances);
    if (sameInstances && listEquals(next, _values)) return false;
    // The box cache follows the geometry alone (H-8): a selection, a focus,
    // a status or a detail level keeps it, so the render object neither
    // re-measures nor, in the box mode, relays out.
    if (!sameInstances || !_sameDetails(next)) {
      final corners = Float64List(8 * next.length);
      for (var i = 0; i < next.length; i++) {
        final points = next[i].detail.corners;
        for (var k = 0; k < 4; k++) {
          corners[8 * i + 2 * k] = points[k].dx;
          corners[8 * i + 2 * k + 1] = points[k].dy;
        }
      }
      _corners = corners;
    }
    _instances = List.unmodifiable(nextInstances);
    _values = List.unmodifiable(next);
    final live = nextInstances.toSet();
    _built.removeWhere((h, _) => !live.contains(h));
    return true;
  }

  /// Whether each of [next]'s details is the one of [_values] at its index
  /// (the instances already equal).
  bool _sameDetails(List<FloorPlanTableOverlay> next) {
    if (next.length != _values.length) return false;
    for (var i = 0; i < next.length; i++) {
      if (next[i].detail != _values[i].detail) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < _values.length; i++) {
      final h = _instances[i];
      final value = _values[i];
      var built = _built[h];
      if (built == null || built.value != value) {
        built = _built[h] = _Built(
            value, _OverlayChild(builder: widget.builder, overlay: value));
      }
      children.add(_OverlaySlot(
          key: ValueKey<int>(h.value),
          slot: i,
          child: RepaintBoundary(child: built.widget)));
    }
    // Non-interactive (G-5's default): every gesture reaches the canvas.
    return IgnorePointer(
      child: RepaintBoundary(
        child: _OverlayStack(
          camera: widget.controller.cameraController,
          corners: _corners,
          layout: widget.layout,
          children: children,
        ),
      ),
    );
  }
}

/// Calls the host's builder for one table, in the table's own context.
class _OverlayChild extends StatelessWidget {
  const _OverlayChild({required this.builder, required this.overlay});

  final FloorPlanTableOverlayBuilder builder;
  final FloorPlanTableOverlay overlay;

  @override
  Widget build(BuildContext context) =>
      builder(context, overlay) ?? const SizedBox.shrink();
}

/// A child's slot: its index into the box cache.
class _OverlaySlot extends ParentDataWidget<FloorPlanOverlayParentData> {
  const _OverlaySlot(
      {required super.key, required this.slot, required super.child});

  final int slot;

  @override
  void applyParentData(RenderObject renderObject) {
    final data = renderObject.parentData! as FloorPlanOverlayParentData;
    if (data.slot == slot) return;
    data.slot = slot;
    final parent = renderObject.parent;
    if (parent is RenderObject) parent.markNeedsLayout();
  }

  @override
  Type get debugTypicalAncestorWidgetClass => _OverlayStack;
}

class _OverlayStack extends MultiChildRenderObjectWidget {
  const _OverlayStack(
      {required this.camera,
      required this.corners,
      required this.layout,
      required super.children});

  final ValueListenable<ViewportTransform> camera;
  final Float64List corners;
  final FloorPlanOverlayLayout layout;

  @override
  RenderFloorPlanOverlays createRenderObject(BuildContext context) =>
      RenderFloorPlanOverlays(camera: camera, corners: corners, layout: layout);

  @override
  void updateRenderObject(
      BuildContext context, RenderFloorPlanOverlays renderObject) {
    renderObject
      ..camera = camera
      ..corners = corners
      ..overlayLayout = layout;
  }
}

/// A [RenderFloorPlanOverlays] child's place (spec H-8): its slot in the box
/// cache and its offset in the layer, as two doubles the camera listener
/// writes in place. [paint], hit testing and [RenderObject.applyPaintTransform]
/// all read [dx] and [dy].
class FloorPlanOverlayParentData extends ContainerBoxParentData<RenderBox> {
  /// The child's index into the box cache; -1 before it is set.
  int slot = -1;

  /// The child's top left in the layer, logical pixels.
  double dx = 0, dy = 0;

  /// Whether the child is painted (and hit): on the canvas, the layer not
  /// hidden by scale, laid out.
  bool shown = false;

  @override
  String toString() =>
      'slot=$slot; dx=$dx; dy=$dy; ${shown ? 'shown' : 'culled'}';
}

/// The overlays' render box (spec H-8), a [RenderFlow]-like multi-child
/// box over the canvas: each child (a [RepaintBoundary] around a host's
/// widget) sits on its table's bounding box on the screen.
///
/// The box cache, [corners], holds each slot's four world corners; it is
/// replaced at the plan's rate. On every camera change the listener maps
/// them into [Float64List]s it reuses -- the screen boxes -- and writes
/// each child's offset into its [FloorPlanOverlayParentData]: arithmetic,
/// nothing created per table. Then a [FloorPlanOverlaySize.natural] layer
/// repaints (its children keep their layout) and a
/// [FloorPlanOverlaySize.box] layer lays its shown children out again,
/// tight to their boxes. A child whose rectangle misses the canvas, or
/// every child below [FloorPlanOverlayLayout.hideBelowScale], is neither
/// painted nor hit, and a `box` one is not laid out. Nothing is built.
///
/// Painting passes each painted child's offset to the framework as an
/// [Offset], since `PaintingContext.paintChild` takes one: one per painted
/// overlay that moved, per frame, the framework's floor
/// ([debugPaintOffsets], kept apart from [debugAllocations]); the culled
/// cost nothing.
class RenderFloorPlanOverlays extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, FloorPlanOverlayParentData> {
  RenderFloorPlanOverlays({
    required ValueListenable<ViewportTransform> camera,
    required Float64List corners,
    required FloorPlanOverlayLayout layout,
  })  : _camera = camera,
        _corners = corners,
        _layout = layout;

  ValueListenable<ViewportTransform> _camera;
  ValueListenable<ViewportTransform> get camera => _camera;
  set camera(ValueListenable<ViewportTransform> value) {
    if (identical(value, _camera)) return;
    if (attached) {
      _camera.removeListener(_onCamera);
      value.addListener(_onCamera);
    }
    _camera = value;
    _stale = true;
    markNeedsLayout();
  }

  /// Each slot's four world corners, `x0, y0, ..., x3, y3`.
  Float64List _corners;
  Float64List get corners => _corners;
  set corners(Float64List value) {
    if (identical(value, _corners)) return;
    _corners = value;
    _stale = true;
    markNeedsLayout();
  }

  FloorPlanOverlayLayout _layout;
  FloorPlanOverlayLayout get overlayLayout => _layout;
  set overlayLayout(FloorPlanOverlayLayout value) {
    if (value == _layout) return;
    _layout = value;
    _stale = true;
    markNeedsLayout();
  }

  /// Each slot's bounding box on the screen, `minX, minY, maxX, maxY`:
  /// rewritten in place at every camera change, grown with the plan.
  Float64List _boxes = Float64List(0);

  /// Below [FloorPlanOverlayLayout.hideBelowScale].
  bool _hidden = false;

  /// Whether the natural children were laid out at the last layout (not
  /// hidden then).
  bool _naturalLaidOut = false;

  /// The camera value and size the boxes were last computed for, and
  /// whether the cache or layout changed since.
  ViewportTransform? _placedAt;
  Size? _placedIn;
  bool _stale = true;

  /// Every buffer this render object created: the allocation bar (H-8).
  /// A steady camera frame adds nothing.
  @visibleForTesting
  int debugAllocations = 0;

  /// How many [Offset]s painting handed to the framework: one per painted
  /// child whose offset moved since its last paint.
  @visibleForTesting
  int debugPaintOffsets = 0;

  /// How many child layouts this render object asked for.
  @visibleForTesting
  int debugChildLayouts = 0;

  /// How many camera changes were placed.
  @visibleForTesting
  int debugCameraPasses = 0;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! FloorPlanOverlayParentData) {
      child.parentData = FloorPlanOverlayParentData();
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _camera.addListener(_onCamera);
  }

  @override
  void detach() {
    _camera.removeListener(_onCamera);
    super.detach();
  }

  bool get _natural => _layout.size == FloorPlanOverlaySize.natural;

  void _onCamera() {
    if (!hasSize) return;
    debugCameraPasses++;
    final camera = _camera.value;
    _measure(camera);
    _place();
    _placedAt = camera;
    if (!_natural || (!_hidden && !_naturalLaidOut)) {
      markNeedsLayout();
    } else {
      markNeedsPaint();
    }
    markNeedsSemanticsUpdate();
  }

  /// The boxes at [camera], into [_boxes]; [_hidden].
  void _measure(ViewportTransform camera) {
    _hidden = camera.scale < _layout.hideBelowScale;
    final slots = _corners.length ~/ 8;
    if (_boxes.length < 4 * slots) {
      _boxes = Float64List(4 * slots);
      debugAllocations++;
    }
    if (_hidden) return;
    final m = camera.worldToScreenMatrix;
    final a = m.a, b = m.b, c = m.c, d = m.d, e = m.e, f = m.f;
    final corners = _corners, boxes = _boxes;
    for (var i = 0; i < slots; i++) {
      var minX = double.infinity, minY = double.infinity;
      var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
      for (var k = 0; k < 4; k++) {
        final x = corners[8 * i + 2 * k], y = corners[8 * i + 2 * k + 1];
        final sx = a * x + c * y + e, sy = b * x + d * y + f;
        minX = math.min(minX, sx);
        minY = math.min(minY, sy);
        maxX = math.max(maxX, sx);
        maxY = math.max(maxY, sy);
      }
      boxes[4 * i] = minX;
      boxes[4 * i + 1] = minY;
      boxes[4 * i + 2] = maxX;
      boxes[4 * i + 3] = maxY;
    }
  }

  /// Each child's offset and whether it is shown, from [_boxes] (and a
  /// natural child's size).
  void _place() {
    final width = size.width, height = size.height;
    final boxes = _boxes;
    final ax = (_layout.anchor.x + 1) / 2, ay = (_layout.anchor.y + 1) / 2;
    final natural = _natural;
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as FloorPlanOverlayParentData;
      final i = data.slot;
      if (_hidden || i < 0 || 4 * i + 3 >= boxes.length) {
        data.shown = false;
      } else {
        final minX = boxes[4 * i], minY = boxes[4 * i + 1];
        final boxW = boxes[4 * i + 2] - minX, boxH = boxes[4 * i + 3] - minY;
        double w, h;
        if (natural) {
          if (child.hasSize) {
            w = child.size.width;
            h = child.size.height;
            data
              ..dx = minX + ax * boxW - ax * w
              ..dy = minY + ay * boxH - ay * h;
          } else {
            w = h = 0;
          }
        } else {
          w = boxW;
          h = boxH;
          data
            ..dx = minX
            ..dy = minY;
        }
        data.shown = (!natural || child.hasSize) &&
            data.dx < width &&
            data.dx + w > 0 &&
            data.dy < height &&
            data.dy + h > 0;
      }
      child = data.nextSibling;
    }
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      constraints.biggest.isFinite ? constraints.biggest : constraints.smallest;

  @override
  void performLayout() {
    final camera = _camera.value;
    if (_stale || !identical(camera, _placedAt) || size != _placedIn) {
      _measure(camera);
      _place();
    }
    if (_natural) {
      if (!_hidden) {
        final loose = BoxConstraints.loose(_layout.maxNaturalSize);
        var child = firstChild;
        while (child != null) {
          child.layout(loose, parentUsesSize: true);
          debugChildLayouts++;
          child = childAfter(child);
        }
      }
      _naturalLaidOut = !_hidden;
      // The offsets need the sizes.
      _place();
    } else {
      final boxes = _boxes;
      var child = firstChild;
      while (child != null) {
        final data = child.parentData! as FloorPlanOverlayParentData;
        if (data.shown) {
          final i = data.slot;
          child.layout(BoxConstraints.tight(Size(
              boxes[4 * i + 2] - boxes[4 * i],
              boxes[4 * i + 3] - boxes[4 * i + 1])));
          debugChildLayouts++;
        }
        child = data.nextSibling;
      }
    }
    _stale = false;
    _placedAt = camera;
    _placedIn = size;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as FloorPlanOverlayParentData;
      if (data.shown) {
        // The framework takes an Offset: made only when the place moved.
        if (data.offset.dx != data.dx || data.offset.dy != data.dy) {
          data.offset = Offset(data.dx, data.dy);
          debugPaintOffsets++;
        }
        context.paintChild(
            child, offset == Offset.zero ? data.offset : offset + data.offset);
      }
      child = data.nextSibling;
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    var child = lastChild;
    while (child != null) {
      final data = child.parentData! as FloorPlanOverlayParentData;
      if (data.shown && child.hasSize) {
        final hit = result.addWithPaintOffset(
          offset: Offset(data.dx, data.dy),
          position: position,
          hitTest: (result, transformed) =>
              child!.hitTest(result, position: transformed),
        );
        if (hit) return true;
      }
      child = data.previousSibling;
    }
    return false;
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final data = child.parentData! as FloorPlanOverlayParentData;
    transform.translateByDouble(data.dx, data.dy, 0, 1);
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as FloorPlanOverlayParentData;
      if (data.shown) visitor(child);
      child = data.nextSibling;
    }
  }
}
