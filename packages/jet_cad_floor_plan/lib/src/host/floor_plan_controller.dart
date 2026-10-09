// The host's controller (spec 14b-2 H1-H4, H11-H14): the designed plan and,
// in the selection mode, a service copy of it; the mode; the selection by
// table number; undo and redo of the active plan; the save point; the
// camera across mode switches.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' show Offset, Rect, Size;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../camera_bounds.dart';
import '../export/export_dialog.dart';
import '../export/export_font.dart';
import '../l10n/document_separator.dart';
import '../l10n/strings.dart';
import '../new_document.dart';
import '../parametric/catalog.dart';
import '../service/table_groups.dart';
import '../service/table_picker.dart';
import '../startup_plan.dart' show kMaxScale, kMinScale;
import '../symbols/symbol_library_loader.dart';
import '../tables/table_data_component.dart';
import '../tables/table_index.dart';
import 'design_changes.dart';
import 'floor_plan_camera.dart';
import 'floor_plan_types.dart';
import 'service_layout.dart';
import 'table_detail.dart';
import 'table_fit.dart';

/// The thumbnail capacity of a controller's own cache: the app's (spec
/// 14b-2 R-11), above the 96 symbols of both libraries.
const int kFloorPlanThumbnailCapacity = 128;

/// Where each mode's canvas starts in a `FloorPlanView`, until a view has
/// measured it (R-13 as amended): the editor's top bar (44), left panel
/// (240) and rulers; the service bar (44). Read when a controller is made;
/// a test seam.
@visibleForTesting
final Map<FloorPlanMode, Offset> floorPlanCanvasSeeds = {
  FloorPlanMode.design:
      const Offset(240 + kRulerThickness, 44 + kRulerThickness),
  FloorPlanMode.selection: const Offset(0, 44),
};

/// One plan the controller holds: the document, the measurer it was built
/// with, the selection over it, and the controller's subscription to it.
final class _Plan {
  _Plan(this.document, this.measurer)
      // The selection first: its pruning runs before the controller hears
      // the same change (R-6).
      : selection = SelectionController(document);

  final DraftDocument document;
  final FlutterTextMeasurer measurer;
  final SelectionController selection;
  StreamSubscription<DocChange>? changes;
  VoidCallback? onSelection;

  /// The history state last announced on `serviceLayoutChanges`, for a
  /// service copy: an Undo is announced at once and again by the change
  /// stream, which is heard once (review 14d-2).
  int? announced;

  /// Cancels what listens to it, at once (R-2).
  void detach() {
    changes?.cancel();
    changes = null;
    if (onSelection case final l?) selection.removeListener(l);
    onSelection = null;
  }

  /// Disposes it. After [detach], and after the frame that unmounts its
  /// view (R-2).
  void dispose() {
    selection.dispose();
    document.dispose();
    measurer.clear();
  }
}

/// A bump-only notifier: each [bump] is one request.
final class _Requests extends ChangeNotifier {
  void bump() => notifyListeners();
}

/// What the next fit frames (zone spec Z5; host embedding API spec G-3):
/// tables by number, or a world point at the canvas's centre.
sealed class _FitTarget {
  const _FitTarget();
}

final class _Tables extends _FitTarget {
  const _Tables(this.numbers);
  final Set<String> numbers;
}

final class _Centre extends _FitTarget {
  const _Centre(this.world, this.scale, {required this.pageScale});
  final Offset world;
  final double? scale;

  /// Asked with no [scale] before the plan's own first fit, while the
  /// camera's scale is still the 1440 x 900 placeholder's: the fit takes
  /// the page fit's scale at the canvas's size (final review F-1).
  final bool pageScale;
}

/// The public camera (spec G-2): the camera controller's value wrapped, one
/// [FloorPlanCamera] per camera value, made at the first read after a
/// change and kept while the value is the same object. Listening is the
/// camera controller's own.
final class _CameraValue implements ValueListenable<FloorPlanCamera> {
  _CameraValue(this._camera);

  final CameraController _camera;
  ViewportTransform? _for;
  FloorPlanCamera? _value;

  @override
  FloorPlanCamera get value {
    final now = _camera.value;
    if (!identical(now, _for)) {
      _for = now;
      _value = FloorPlanCamera(now);
    }
    return _value!;
  }

  @override
  void addListener(VoidCallback listener) => _camera.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _camera.removeListener(listener);
}

/// The table focus (zone spec Z10): each [replace] notifies, an equal set
/// or a second null included.
final class _Focus extends ChangeNotifier
    implements ValueListenable<Set<String>?> {
  Set<String>? _value;

  @override
  Set<String>? get value => _value;

  void replace(Set<String>? next) {
    _value = next;
    notifyListeners();
  }
}

/// The designed plan's tables as [FloorPlanController.designChanges] last
/// reported them (spec E-5): the details and their instances, index for
/// index, and the plan's state they were read at.
final class _DesignBaseline {
  const _DesignBaseline(
      this.document, this.state, this.layers, this.instances, this.details);

  final DraftDocument document;
  final int state;
  final int layers;
  final List<Handle> instances;
  final List<FloorPlanTableDetail> details;

  /// Whether [d] is still where this was read: the same plan, history
  /// state and layers.
  bool isAt(DraftDocument d) =>
      identical(document, d) &&
      state == d.commands.stateId &&
      layers == d.tables.mutationRevision;
}

/// The planner as a host embeds it (spec 14b-2): with [FloorPlanView].
///
/// Holds the **designed plan** -- the one the host loads with [load], saves
/// with [designJson] and edits in the design mode -- and, in the selection
/// mode, a **service copy** of it decoded under `runtime` permissions. The
/// selection mode shows and edits only the copy: its Undo never reaches a
/// design edit, and nothing done there changes [designJson] or [dirty]
/// (H1). Tables are named by their numbers, never by handles.
///
/// Notifies when the active plan changes (a mode switch, [load],
/// [newPlan], [resetLayout]).
///
/// An empty plan the controller makes takes the decimal separator of the
/// language of the [FloorPlanView] that first shows it (spec Q0 N1), unless
/// something read or edited it first; a plan given as JSON keeps its own
/// (N2).
class FloorPlanController extends ChangeNotifier {
  /// A controller over [json], or over an empty plan. Throws a
  /// [FormatException] when [json] is not a plan, as [load] does, before
  /// it builds anything it would have to dispose (review F-5).
  ///
  /// The empty plan prints the decimal separator of the language of the
  /// first [FloorPlanView] that shows it (spec Q0 N1): until a view has
  /// reported its language it is the engine's `point`, and it settles on
  /// the language as if it had been made so -- no undo step, not [dirty] --
  /// unless [designJson] read it or an edit touched it first.
  ///
  /// [minScale] and [maxScale] bound the camera's zoom, in logical pixels
  /// per millimetre (spec G-3): the user's pinch and wheel, [zoomBy],
  /// [centerOn] and every fit stay inside them. The defaults, 0.001 and
  /// 100, are the planner's own. Throws an [ArgumentError] unless both are
  /// finite and `1e-6 <= minScale < maxScale`: the bounds are decided with
  /// the engine's absolute tolerance of 1e-9, which below 1e-6 would be a
  /// sizable part of the bound (Task 2 review R-6).
  factory FloorPlanController({
    List<SymbolLibrarySource> symbolSources = const [furnitureSymbolSource],
    SymbolLibraryLoader? symbols,
    SymbolThumbnails? thumbnails,
    String? json,
    double minScale = kMinScale,
    double maxScale = kMaxScale,
  }) {
    if (!minScale.isFinite || minScale < _minScaleFloor) {
      throw ArgumentError.value(
          minScale, 'minScale', 'must be finite and at least 1e-6');
    }
    if (!maxScale.isFinite || maxScale <= minScale) {
      throw ArgumentError.value(
          maxScale, 'maxScale', 'must be finite and above minScale');
    }
    final measurer = FlutterTextMeasurer();
    final DraftDocument document;
    if (json == null) {
      document = newDocument(measurer);
    } else {
      try {
        document = _decode(json, measurer, DraftPermissions.all);
      } catch (e) {
        measurer.clear();
        throw FormatException('Not a floor plan: $e');
      }
    }
    return FloorPlanController._(_Plan(document, measurer),
        unsettled: json == null,
        symbolSources: symbolSources,
        symbols: symbols,
        thumbnails: thumbnails,
        minScale: minScale,
        maxScale: maxScale);
  }

  FloorPlanController._(
    _Plan design, {
    required bool unsettled,
    required List<SymbolLibrarySource> symbolSources,
    SymbolLibraryLoader? symbols,
    SymbolThumbnails? thumbnails,
    required double minScale,
    required double maxScale,
  })  : _minScale = minScale,
        _maxScale = maxScale,
        _ownsSymbols = symbols == null,
        symbols = symbols ?? SymbolLibraryLoader(sources: symbolSources),
        _ownsThumbnails = thumbnails == null,
        thumbnails = thumbnails ??
            SymbolThumbnails(maxEntries: kFloorPlanThumbnailCapacity) {
    _design = _attach(design);
    _savedState = design.document.commands.stateId;
    if (unsettled) {
      _unsettled = (document: design.document, at: _savedState);
    }
    _placeNominally();
    _refreshFlags();
  }

  /// The shell's nominal fit (1440 x 900), so the first frame of a new
  /// plan's view is drawn near the right place before the real fit
  /// (review F-6), inside the zoom bounds as every fit is (spec G-3). Set
  /// here, never during a build.
  void _placeNominally() {
    const size = Size(1440, 900);
    cameraController.value = clampCameraScale(
        _pageFit(_design.document, size), size,
        minScale: _minScale, maxScale: _maxScale);
  }

  /// [d]'s page fitted to a drawing area of [size], unclamped, as a view
  /// fits it: the page when there is one, else the extents.
  static ViewportTransform _pageFit(DraftDocument d, Size size) {
    final page = d.components.isRegistered<PageComponent>()
        ? d.components.get<PageComponent>(d.rootHandle)
        : null;
    return page != null
        ? fitToPage(page, size)
        : ViewportTransform.fit(d.extents, size);
  }

  /// The symbol library the design mode's palette shows (H3, R-11): the
  /// controller's own unless one was passed, which it then never disposes.
  @internal
  final SymbolLibraryLoader symbols;
  final bool _ownsSymbols;
  bool _symbolsStarted = false;

  /// The palette's thumbnails, as [symbols].
  @internal
  final SymbolThumbnails thumbnails;
  final bool _ownsThumbnails;

  /// The export font's bytes and the last export choice, for the
  /// controller's life (R-9).
  @internal
  final ExportFontCache exportFont = ExportFontCache();
  @internal
  ExportChoice exportChoice = ExportChoice.initial;

  /// The zoom bounds (spec G-3), as the constructor was given them.
  final double _minScale, _maxScale;

  /// The least `minScale` (Task 2 review R-6): a thousand times the
  /// tolerance the bound decisions use.
  static const double _minScaleFloor = 1e-6;

  /// The one camera every view of this controller uses (R-13): a mode
  /// switch keeps its pan and zoom. Bounded by the constructor's
  /// `minScale` and `maxScale`. Named `camera` before the host embedding
  /// API (spec G-2), which gave that name to the public [camera].
  @internal
  late final CameraController cameraController = CameraController(
      ViewportTransform(worldToScreenMatrix: Transform2(1, 0, 0, -1, 0, 0)),
      minScale: _minScale,
      maxScale: _maxScale);

  late final _CameraValue _camera = _CameraValue(cameraController);

  /// Where the plan is on the canvas (spec G-2): a new [FloorPlanCamera] at
  /// every pan, zoom and fit, by the user or by the host; one per position,
  /// so two reads with no camera change in between are the identical
  /// object. One camera for both modes: a mode switch keeps the plan where
  /// it is on the screen (R-13), moving the camera by the difference of the
  /// two canvases' origins.
  ValueListenable<FloorPlanCamera> get camera => _camera;

  final ValueNotifier<Rect?> _canvasRect = ValueNotifier(null);

  /// Each mounted view's drawing area, as it last reported it, the last
  /// reporter last.
  final Map<Object, Rect> _canvases = {};

  /// The last rect reported in each mode (Task 2 review R-4), for
  /// [setMode].
  final Map<FloorPlanMode, Rect> _canvasIn = {};

  /// The canvas of the last [FloorPlanView] laid out, in global logical
  /// pixels (spec G-2): its origin and size, reported after every frame in
  /// which the view moved or was resized -- an ancestor's padding included.
  /// Null while no view is mounted. With it a widget outside the view
  /// places itself on the plan ([worldToGlobal], [globalToWorld]). The rect
  /// is the canvas's top left and its own size: an ancestor that scales or
  /// turns the view is not accounted for.
  ///
  /// A view first reports after its first fit (Task 2 review R-3): a host
  /// that waits for a non-null rect to [zoomBy] zooms the fitted plan. A
  /// view that has no size yet reports nothing.
  ///
  /// [setMode] sets it at once to where the new mode's canvas was when a
  /// view last showed that mode (review R-4), so [zoomBy]'s default focus
  /// and [worldToGlobal] are right from the switch; a mode no view has shown
  /// yet keeps the old mode's rect until the end of the next frame.
  ValueListenable<Rect?> get canvasRect => _canvasRect;

  /// The global point that shows [world] (millimetres, y up), or null with
  /// no view mounted ([canvasRect] null).
  Offset? worldToGlobal(Offset world) {
    final rect = _canvasRect.value;
    if (rect == null) return null;
    return camera.value.worldToCanvas(world) + rect.topLeft;
  }

  /// The world point (millimetres, y up) shown at the global point
  /// [global], or null with no view mounted ([canvasRect] null).
  Offset? globalToWorld(Offset global) {
    final rect = _canvasRect.value;
    if (rect == null) return null;
    return camera.value.canvasToWorld(global - rect.topLeft);
  }

  /// A view's drawing area is at [global] (spec G-2), or, null, [view] is
  /// going. [canvasRect] is the last report's; when a view goes, at the end
  /// of that frame it is the rect of the view that reported last among
  /// those left, or null with none. A mode switch's new view reports in the
  /// same frame, before that, so no listener hears a null between the two;
  /// and no listener is told anything while the tree is locked.
  @internal
  void canvasPlaced(Object view, Rect? global) {
    if (_disposed) return;
    if (global != null) {
      _canvases
        ..remove(view)
        ..[view] = global;
      _canvasIn[_mode.value] = global;
      _canvasRect.value = global;
      return;
    }
    if (_canvases.remove(view) == null) return;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        if (_disposed) return;
        _canvasRect.value = _canvases.isEmpty ? null : _canvases.values.last;
      })
      ..ensureVisualUpdate();
  }

  /// Moves at every camera request a host makes (spec G-3): [fitToView],
  /// [fitToTables] that found a table, [centerOn], [panBy] and a [zoomBy]
  /// that acts. A view's fit reads it when it becomes due and is dropped
  /// when it has moved, so the last request wins.
  int _cameraEpoch = 0;

  /// [_cameraEpoch], for the views' fits.
  @internal
  int get cameraEpoch => _cameraEpoch;

  late _Plan _design;
  _Plan? _service;

  /// Plans let go of whose disposal waits for the next frame (R-2).
  final List<_Plan> _dropped = [];

  int _savedState = 0;

  /// The design's state when [designJson] last encoded it (R-8).
  int? _encodedState;

  final _Requests _fits = _Requests();

  /// The plan's own first fit (Ruling 01-2), owed from construction,
  /// [load] and [newPlan] until a view takes it. A camera command does not
  /// cancel it (Task 2 review R-1): it is not a host request.
  bool _fitOnStart = true;

  /// A [fitToView] or [fitToTables] no mounted view has performed yet
  /// (review F-2): the next view fits on its first frame.
  bool _fitPending = false;

  /// What the next fit frames (zone spec Z5): null for the page, else the
  /// numbers of the last [fitToTables] that found a table, trimmed, or the
  /// point of the last [centerOn] (spec G-3). The last request wins.
  _FitTarget? _fitTarget;
  VoidCallback? _settle;
  bool _disposed = false;

  final ValueNotifier<FloorPlanMode> _mode =
      ValueNotifier(FloorPlanMode.design);
  final ValueNotifier<bool> _dirty = ValueNotifier(false);
  final ValueNotifier<bool> _canUndo = ValueNotifier(false);
  final ValueNotifier<bool> _canRedo = ValueNotifier(false);
  final ValueNotifier<Set<String>> _selectedTables =
      ValueNotifier(const <String>{});
  final ValueNotifier<int> _revision = ValueNotifier(0);
  final ValueNotifier<Map<String, TableStatus>> _statuses =
      ValueNotifier(const <String, TableStatus>{});
  final ValueNotifier<Map<String, TableGroup>> _groups =
      ValueNotifier(const <String, TableGroup>{});
  final ValueNotifier<Map<String, TableStatus>> _groupStatuses =
      ValueNotifier(const <String, TableStatus>{});
  final ValueNotifier<String?> _selectedGroup = ValueNotifier(null);
  final _Focus _focus = _Focus();

  /// Moves whenever the active plan changes: an edit, an undo or a redo
  /// of it, a mode switch, [load], [newPlan], [resetLayout] (demo review
  /// F-1). A host re-reads [tables] and [numberingWarnings] on it.
  ValueListenable<int> get revision => _revision;

  /// The tables' statuses by number (spec 14c S6), as [setTableStatus]
  /// last set them. Kept for the controller's life, across mode switches,
  /// [resetLayout] and [load]; drawn in the selection mode only, on every
  /// live, visible table carrying the number.
  ValueListenable<Map<String, TableStatus>> get tableStatuses => _statuses;

  /// Replaces every status at once (S6): numbers trimmed. Not document
  /// state -- no command, no undo, no [dirty], no [revision]; never saved,
  /// exported or printed (D13).
  void setTableStatus(Map<String, TableStatus> statuses) {
    _statuses.value = Map.unmodifiable(
        {for (final e in statuses.entries) e.key.trim(): e.value});
  }

  /// The table groups by trimmed group id (table-groups spec G1), as
  /// [setTableGroups] last set them. Kept for the controller's life, across
  /// mode switches, [resetLayout] and [load], like [tableStatuses]; they act
  /// in the selection mode only.
  ValueListenable<Map<String, TableGroup>> get tableGroups => _groups;

  /// Replaces every group at once (G1): ids trimmed. Not document state --
  /// no command, no undo, no [dirty], no [revision]; never saved, exported
  /// or printed. The planner never changes a group itself.
  ///
  /// Throws an [ArgumentError] (G2) for a blank id, two ids the same after
  /// trimming, a group with no member after trimming, or a number in two
  /// groups; then nothing is assigned and no listener is notified. A member
  /// number with no live table is kept.
  void setTableGroups(Map<String, TableGroup> groups) {
    final valid = validateTableGroups(groups);
    _groups.value = valid;
    _refreshSelectedGroup();
  }

  /// The groups' statuses by trimmed group id (G1), as [setGroupStatus]
  /// last set them; kept like [tableStatuses].
  ValueListenable<Map<String, TableStatus>> get groupStatuses => _groupStatuses;

  /// Replaces every group status at once (G1): ids trimmed. A group's
  /// status fills every visible member and **overrides** each member's own
  /// [tableStatuses] entry while it is set (G3). A status whose id has no
  /// group is kept, draws nothing, and applies again when a group with that
  /// id comes back (G2). Not document state, as [setTableStatus].
  void setGroupStatus(Map<String, TableStatus> statuses) {
    _groupStatuses.value = Map.unmodifiable(
        {for (final e in statuses.entries) e.key.trim(): e.value});
  }

  /// The numbers in focus (zone spec Z10), as [setTableFocus] last set
  /// them: null for no focus. In the selection mode every table outside a
  /// focus lies under a veil of the paper (Z11-Z13); a focus with no
  /// number fades every table. Kept by number for the controller's life,
  /// across mode switches, [load], [newPlan], [resetLayout] and
  /// [restoreServiceLayout].
  ValueListenable<Set<String>?> get tableFocus => _focus;

  /// Replaces the focus (Z10): null for none, else [numbers] trimmed, blanks
  /// dropped, copied into an unmodifiable set -- so `{}` and `{''}` are a
  /// focus with no table. Every call notifies [tableFocus], an equal set
  /// included.
  ///
  /// Presentation only (Z15): a faded table is tapped, selected, moved and
  /// merged as any other; a host that wants it inert checks
  /// [tableFocus] in its own callbacks. Not document state -- no command,
  /// undo step, [dirty], [revision], [serviceLayoutChanges] or
  /// notification of this controller; never saved, exported or printed.
  void setTableFocus(Set<String>? numbers) {
    _focus.replace(numbers == null
        ? null
        : Set<String>.unmodifiable({
            for (final n in numbers)
              if (n.trim() case final t when t.isNotEmpty) t,
          }));
  }

  /// The id of the group the selection is exactly (G1, G5's Split rule):
  /// the selected numbers are the numbers of that group's selectable
  /// members (visible, unlocked), none is missing or extra, and no
  /// unnumbered table is selected. Null otherwise, and always in the design
  /// mode, where groups do not act (G4). Follows the selection, the groups
  /// and the active plan.
  ///
  /// It updates after [selectedTables] and [tableGroups] have notified, so
  /// a listener that reads it alongside them listens to it too (e.g. a
  /// `Listenable.merge` of all three).
  ValueListenable<String?> get selectedGroup => _selectedGroup;

  /// The numbers of the selectable members of group [groupId] (trimmed) in
  /// the active plan: its live members on a visible, unlocked layer, by the
  /// rule Merge and Split use (table-groups fixes spec X1, closing the
  /// table-groups spec's F-1). A number carried by several tables is in it
  /// once, when any of them is selectable.
  ///
  /// Empty for an unknown id or a group with no selectable member;
  /// unmodifiable. A pure query, valid in both modes (in the design mode it
  /// answers for the design plan, where groups do not act), and fresh at
  /// every call: right after [setTableGroups], a mode switch or a layer
  /// edit.
  Set<String> selectableMembers(String groupId) => Set.unmodifiable({
        for (final t in _groupLookup.selectableMembers(groupId.trim()))
          t.number!,
      });

  /// The mode (H3). Changed by [setMode].
  ValueListenable<FloorPlanMode> get mode => _mode;

  /// Whether the designed plan differs from its save point (H3, F-2).
  /// Never moved by the selection mode.
  ValueListenable<bool> get dirty => _dirty;

  /// Whether [undo] and [redo] can act on the active plan.
  ValueListenable<bool> get canUndo => _canUndo;
  ValueListenable<bool> get canRedo => _canRedo;

  /// The numbers of the tables selected in the active view (H3): a
  /// selected object that is not a numbered table is not in it.
  ValueListenable<Set<String>> get selectedTables => _selectedTables;

  /// The active plan: the design's, or the service copy's in the
  /// selection mode. For [FloorPlanView].
  @internal
  DraftDocument get activeDocument => _active.document;

  /// The active plan's selection, which the view hands to its canvas (H4)
  /// and never disposes.
  @internal
  SelectionController get activeSelection => _active.selection;

  /// Each notification refits the active view (H3 [fitToView]).
  @internal
  Listenable get fitRequests => _fits;

  /// Whether the next view fits its camera on its first frame: after
  /// construction, [load], [newPlan], or a fit no view has performed yet;
  /// not after a mode switch (R-13).
  @internal
  bool takeFitOnStart() {
    final fit = _fitOnStart || _fitPending;
    _fitOnStart = false;
    return fit;
  }

  /// Whether the next view's fit on start is the plan's own first fit
  /// ([takeFitOnStart] not called since construction, [load] or
  /// [newPlan]), which no camera command cancels (Task 2 review R-1);
  /// otherwise it performs only a request, which a later command drops.
  @internal
  bool get owesFirstFit => _fitOnStart;

  /// A view performed a fit: a pending [fitToView] or [fitToTables] is
  /// done (review F-2). The fit target stays (zone spec Z5).
  @internal
  void fitted() => _fitPending = false;

  /// The camera a fit sets in a drawing area of [viewport] (zone spec Z7):
  /// null for the page -- the target is the page, or no table of the last
  /// [fitToTables] is a candidate in the active plan now (Z6) -- else the
  /// tables framed ([frameTables]). Resolved here, when the fit is
  /// performed: a restore, an Undo or a mode switch since the request is
  /// followed. One entity-store scan per call, at fit rate. A camera that
  /// is not finite is none: the page is fitted (Task 1 review R-1).
  ///
  /// A [centerOn] target is the camera with the point at the drawing
  /// area's centre, at the scale asked or else the camera's own when the
  /// fit is performed -- but one asked with no scale before the plan's own
  /// first fit takes the scale of the page fitted to [viewport] (final
  /// review F-1); the view then clamps it to the bounds about that centre.
  @internal
  ViewportTransform? framingFor(Size viewport) {
    final ViewportTransform framing;
    switch (_fitTarget) {
      case null:
        return null;
      case _Tables(:final numbers):
        final box = _tablesBounds(numbers);
        if (box == null) return null;
        framing = frameTables(box, viewport,
            minScale: _minScale, maxScale: _maxScale);
      case _Centre(:final world, :final scale, :final pageScale):
        framing = _centred(
            world,
            pageScale
                ? _pageFit(_active.document, viewport)
                    .worldToScreenMatrix
                    .scaleMagnitude
                : scale,
            viewport);
    }
    final m = framing.worldToScreenMatrix;
    return [m.a, m.b, m.c, m.d, m.e, m.f].every((v) => v.isFinite)
        ? framing
        : null;
  }

  /// The camera with [world] at the centre of a drawing area of
  /// [viewport]: the camera's linear part, scaled to [scale] when one is
  /// given, translated to put the point there.
  ViewportTransform _centred(Offset world, double? scale, Size viewport) {
    final m = cameraController.value.worldToScreenMatrix;
    final k = scale == null ? 1.0 : scale / m.scaleMagnitude;
    final a = m.a * k, b = m.b * k, c = m.c * k, d = m.d * k;
    return ViewportTransform(
        worldToScreenMatrix: Transform2(
            a,
            b,
            c,
            d,
            viewport.width / 2 - (a * world.dx + c * world.dy),
            viewport.height / 2 - (b * world.dx + d * world.dy)));
  }

  /// The bound of the four transformed corners of every candidate of the
  /// active plan (zone spec Z0, Z2) numbered in [numbers]; null when there
  /// is none. A fresh box cache per call: the design mode has no picker.
  Aabb2? _tablesBounds(Set<String> numbers) {
    final document = _active.document;
    var box = Aabb2.empty();
    for (final c in TablePicker.candidatesOf(document,
        boxes: <Handle, Aabb2>{}, leaves: document.leavesByOwner)) {
      if (numbers.contains(c.table.number)) box = box.union(c.worldBounds);
    }
    return box.isEmpty ? null : box;
  }

  // R-13, amended by the human (2026-10-07, "planın yeri korunsun"): a mode
  // switch keeps the plan where it is on the screen. The camera's numbers
  // are in the shown canvas's coordinates, and the two modes' canvases
  // start at different places in the view, so [setMode] reframes the
  // camera by the difference of their origins -- here, not in a view, so a
  // switch made while no view is shown keeps the place too. The origins
  // are seeded ([floorPlanCanvasSeeds]) and replaced by what a view
  // measures; a reframing made with an origin a measurement then corrects
  // is corrected with it.
  final Map<FloorPlanMode, Offset> _canvasAt = Map.of(floorPlanCanvasSeeds);

  /// The origins a reframing used and no measurement has confirmed yet.
  final Map<FloorPlanMode, Offset> _assumed = {};

  void _reframe(FloorPlanMode from, FloorPlanMode to) {
    final a = _canvasAt[from]!, b = _canvasAt[to]!;
    _assumed.putIfAbsent(from, () => a);
    _assumed.putIfAbsent(to, () => b);
    if (a != b) cameraController.panBy(a - b);
  }

  /// A view measured where mode [shown]'s canvas starts in it, after the
  /// frame that first showed a plan in that mode. When a reframing assumed
  /// another origin, the camera is corrected: into the shown mode, by what
  /// the assumption missed; out of a mode no longer shown, by the same the
  /// other way.
  @internal
  void canvasMeasured(FloorPlanMode shown, Offset origin) {
    _canvasAt[shown] = origin;
    final assumed = _assumed.remove(shown);
    if (assumed == null || assumed == origin) return;
    cameraController
        .panBy(shown == _mode.value ? assumed - origin : origin - assumed);
  }

  // Spec Q0 N1 (R-4): an empty plan the controller makes is unsettled
  // until a language is known. A controller cannot know its host's
  // language and a host passes none (it makes the controller where no
  // locale can be read), so each [FloorPlanView] reports the language of
  // its context; the first report settles the designed plan, if nothing
  // has touched it, and [newPlan] uses the last one.

  /// The separator of the language a view last reported; null before any.
  DecimalSeparator? _reported;

  /// The designed plan and its state id when it was made with no language
  /// known, while it is unsettled; null for a settled or a loaded plan
  /// (N2). The plan is kept with the id: state ids are per history, so an
  /// id alone could match another plan's (the final review's F-4).
  ({DraftDocument document, int at})? _unsettled;

  /// Whether the designed plan is unsettled and untouched: no command since
  /// it was made -- its state is still the one it was made in, and no
  /// command was undone back to it (an undone step leaves a redo) -- and no
  /// [designJson] since (which clears [_unsettled]). Read when a language
  /// is reported, synchronously, so an edit whose change has not been
  /// heard yet counts.
  bool get _untouched {
    final u = _unsettled;
    if (u == null || !identical(u.document, _design.document)) return false;
    final commands = u.document.commands;
    return commands.stateId == u.at && !commands.canRedo;
  }

  /// A view's language (spec Q0 N1): [FloorPlanView] reports
  /// `FloorPlanStrings.of(context)` when its dependencies change and when
  /// it is handed this controller. Kept for [newPlan]. An unsettled,
  /// untouched designed plan takes its separator now, as if made so: the
  /// page's command and then the history cleared, so no undo step is left;
  /// the save point moved with it, so it stays clean; nothing goes out on
  /// [serviceLayoutChanges], and a service copy already taken keeps its
  /// page (it holds no text). Only the page changes (I-2), and none of its
  /// geometry, so the camera stays.
  @internal
  void reportLanguage(FloorPlanStrings strings) {
    final separator = documentSeparatorFor(strings);
    _reported = separator;
    // The first language settles the plan or finds it touched; either way
    // it is unsettled no more (Task 4 review).
    final untouched = _untouched;
    _unsettled = null;
    if (!untouched) return;
    final d = _design.document;
    final page = d.components.get<PageComponent>(d.rootHandle)!;
    if (page.decimalSeparator == separator) return;
    d.commands.execute(SetComponentCommand<PageComponent>(
        d.rootHandle, page.copyWith(decimalSeparator: separator)));
    d.commands.clearHistory();
    // Untouched, so it was clean: no designJson, so no other save point.
    _savedState = d.commands.stateId;
  }

  /// Starts loading the symbol library, once, when the design view first
  /// mounts (R-11): the binding exists then.
  @internal
  void startSymbols() {
    // A shared loader too (review F-3): `load` is once-only, and the host
    // that shares one need not call it.
    if (_symbolsStarted) return;
    _symbolsStarted = true;
    unawaited(symbols.load());
  }

  /// Where the active view registers its settle (H11): the controller
  /// calls it before it reads or replaces a plan, so a typed value or a
  /// pending text is committed first. Returns the withdrawal.
  @internal
  VoidCallback registerSettle(VoidCallback settle) {
    _settle = settle;
    return () {
      if (identical(_settle, settle)) _settle = null;
    };
  }

  /// Settles the active view's pending input (H11): for the view's own
  /// flows (Export, Print) before they read the plan.
  @internal
  void settle() => _settle?.call();

  _Plan get _active => _service ?? _design;

  /// Whether the service copy has a layout (spec 14d S3): a table stands
  /// elsewhere than in the design. Not the undo depth: a restored layout
  /// has none, and a table dragged back exactly to its place is no edit.
  /// Surveys the copy's tables at each read: read it on a change, not per
  /// frame.
  bool get serviceEdited {
    final service = _service;
    return service != null &&
        serviceLayoutOf(_design.document, service.document).isNotEmpty;
  }

  /// Fires after every change of the service layout a mode switch or a
  /// load did not make (spec 14d S4, revision 2): a move, an Undo or a
  /// Redo in the selection mode, [resetLayout], [restoreServiceLayout];
  /// for [undo] and [redo], before they return. Never on [setMode], [load]
  /// or [newPlan], so a host that saves
  /// [serviceLayoutJson] on it never overwrites its stored layout with the
  /// empty one a new copy starts with.
  Listenable get serviceLayoutChanges => _layoutChanges;
  final _Requests _layoutChanges = _Requests();

  /// The service layout as JSON (spec 14d S1): the tables the selection
  /// mode moved away from the design, ascending by handle. Null in the
  /// design mode.
  String? serviceLayoutJson() {
    _settle?.call();
    final service = _service;
    if (service == null) return null;
    return encodeServiceLayout(
        serviceLayoutOf(_design.document, service.document));
  }

  /// Puts a stored service layout back (spec 14d S2, revision 2): the
  /// selection mode only (a [StateError] in the design mode). A [json]
  /// that is not a layout throws a [FormatException] and changes nothing.
  /// Otherwise the service copy is rebuilt from the design, as
  /// [resetLayout] does, and every entry whose table is still the same
  /// table at the same designed place, visible and unlocked, is moved to
  /// its stored place; the others are dropped. The restored places are
  /// the copy's floor: Undo does not remove them, [resetLayout] does.
  ServiceLayoutRestore restoreServiceLayout(String json) {
    final old = _service;
    if (old == null) {
      throw StateError('restoreServiceLayout needs the selection mode');
    }
    final entries = decodeServiceLayout(json);
    _settle?.call();
    _refreshSelected();
    final numbers = _selectedTables.value;
    final match = matchServiceLayout(_design.document, entries);
    final copy = _copyOf(_design);
    if (match.applied.isNotEmpty) {
      // No system is installed for this edit: an entry only translates
      // (S2), a translation re-stamps no table label (14a T12) and no
      // parametric object reads a table. The history is cleared before
      // anything listens, so the restore is no step and fires nothing.
      final commands = copy.document.commands;
      commands.execute(CompoundCommand(
          [for (final e in match.applied) TransformNodeCommand(e.handle, e.to)],
          label: 'Restore layout'));
      commands.clearHistory();
    }
    _drop(old);
    _service = _attach(copy);
    _select(numbers);
    _refreshFlags();
    _revision.value++;
    _layoutChanges.bump();
    notifyListeners();
    return ServiceLayoutRestore(
        applied: [for (final e in match.applied) e.number],
        dropped: [for (final e in match.dropped) e.number]);
  }

  // ---------------------------------------------------------------------
  // The designed plan.

  /// The designed plan's encoding, whatever the mode (H1, D9). [markSaved]
  /// marks the state encoded here (R-8). An empty plan read here is settled
  /// as it is (spec Q0 N2): no language reported later changes it.
  String designJson() {
    _settle?.call();
    _unsettled = null;
    _encodedState = _design.document.commands.stateId;
    return DraftDocumentCodec.encodeToString(_design.document);
  }

  /// The host stored the last [designJson]: that state is the save point
  /// (R-8); an edit made since stays dirty. With no [designJson] yet, the
  /// current state.
  void markSaved() {
    _settle?.call();
    _savedState = _encodedState ?? _design.document.commands.stateId;
    _refreshFlags();
  }

  /// Replaces the designed plan with [json] (H3). Throws a
  /// [FormatException] when [json] is not a plan, and then changes
  /// nothing. The selection is cleared; in the selection mode the service
  /// copy is rebuilt from the new plan; the camera fits again.
  void load(String json) {
    _settle?.call();
    final measurer = FlutterTextMeasurer();
    final DraftDocument document;
    try {
      document = _decode(json, measurer, DraftPermissions.all);
    } catch (e) {
      measurer.clear();
      throw FormatException('Not a floor plan: $e');
    }
    _replaceDesign(_Plan(document, measurer));
  }

  /// Replaces the designed plan with an empty one (H3), as [load] does. It
  /// prints the decimal separator of the language a [FloorPlanView] last
  /// reported (spec Q0 N1); with none reported yet, it is unsettled, as the
  /// constructor's empty plan is.
  void newPlan() {
    _settle?.call();
    final measurer = FlutterTextMeasurer();
    final reported = _reported;
    _replaceDesign(
        _Plan(
            newDocument(measurer,
                decimalSeparator: reported ?? DecimalSeparator.point),
            measurer),
        unsettled: reported == null);
  }

  /// [next] becomes the designed plan; [unsettled] for an empty one made
  /// with no language known (spec Q0 N1), never for a loaded one (N2).
  void _replaceDesign(_Plan next, {bool unsettled = false}) {
    // Spec E-5: the old design's changes not reported yet first, now -- its
    // change events still queued are never delivered once it is dropped.
    _reportDesign();
    _drop(_design);
    if (_service case final s?) _drop(s);
    _design = _attach(next);
    _savedState = next.document.commands.stateId;
    _unsettled = unsettled
        ? (document: next.document, at: next.document.commands.stateId)
        : null;
    _encodedState = null;
    if (_mode.value == FloorPlanMode.selection) {
      _service = _attach(_copyOf(_design));
    } else {
      _service = null;
    }
    if (_baseline != null) {
      _designChanges.add(const FloorPlanPlanReplaced());
      _baseline = _designNow();
    }
    _fitOnStart = true;
    // The numbers named the old plan (zone spec Z8): a host frames after
    // a load.
    _fitTarget = null;
    _placeNominally();
    _refreshFlags();
    _revision.value++;
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // The modes.

  /// Switches the mode (H1). Into the selection mode: a service copy of
  /// the design. Out of it: the copy is discarded, with every service
  /// edit. The selected numbers are selected again in the new plan.
  void setMode(FloorPlanMode next) {
    if (next == _mode.value) return;
    _settle?.call();
    // The settle may have renumbered a selected table: read it now (V4).
    _refreshSelected();
    final numbers = _selectedTables.value;
    if (next == FloorPlanMode.selection) {
      _service = _attach(_copyOf(_design));
    } else {
      _drop(_service!);
      _service = null;
    }
    _reframe(_mode.value, next);
    // Review R-4: the new mode's canvas, where a view last showed it.
    final shownIn = _canvasIn[next];
    if (_canvasRect.value != null && shownIn != null) {
      _canvasRect.value = shownIn;
    }
    _mode.value = next;
    _select(numbers);
    _refreshFlags();
    _revision.value++;
    notifyListeners();
  }

  /// The selection mode only: the service copy rebuilt from the design,
  /// every service edit gone (H1, D12). The selection is kept.
  void resetLayout() {
    final service = _service;
    if (service == null) return;
    _settle?.call();
    _refreshSelected();
    final numbers = _selectedTables.value;
    _drop(service);
    _service = _attach(_copyOf(_design));
    _select(numbers);
    _refreshFlags();
    _revision.value++;
    _layoutChanges.bump();
    notifyListeners();
  }

  _Plan _copyOf(_Plan design) {
    final measurer = FlutterTextMeasurer();
    return _Plan(
        _decode(DraftDocumentCodec.encodeToString(design.document), measurer,
            DraftPermissions.runtime),
        measurer);
  }

  static DraftDocument _decode(
          String json, FlutterTextMeasurer measurer, DraftPermissions p) =>
      DraftDocumentCodec.decodeString(json,
          measurer: measurer,
          permissions: p,
          registerComponents: registerAppComponents,
          diagnostics: <Diagnostic>[]);

  // ---------------------------------------------------------------------
  // Undo and redo, of the active plan.

  void undo() {
    _settle?.call();
    final commands = _active.document.commands;
    if (commands.canUndo) commands.undo();
    _announceLayout();
  }

  void redo() {
    _settle?.call();
    final commands = _active.document.commands;
    if (commands.canRedo) commands.redo();
    _announceLayout();
  }

  /// Fires [serviceLayoutChanges] if the service copy's history moved since
  /// it last did. The change stream is asynchronous: without this, a host
  /// that calls [undo] and then [setMode] in one synchronous step would
  /// never hear the Undo, and would keep the undone move (review 14d-2).
  void _announceLayout() {
    final service = _service;
    if (service == null) return;
    final state = service.document.commands.stateId;
    if (state == service.announced) return;
    service.announced = state;
    _layoutChanges.bump();
  }

  // ---------------------------------------------------------------------
  // Tables and the selection.

  TableSurvey? _survey;
  DraftDocument? _surveyDocument;
  int? _surveyState;

  /// The active plan's survey, recomputed when the plan or its state moved
  /// (R-7): fresh right after a synchronous edit.
  TableSurvey get _tables {
    final d = _active.document;
    if (_survey == null ||
        !identical(_surveyDocument, d) ||
        _surveyState != d.commands.stateId) {
      _survey = TableSurvey.of(d);
      _surveyDocument = d;
      _surveyState = d.commands.stateId;
    }
    return _survey!;
  }

  /// The active plan's live tables, ascending (H3). A table on a hidden
  /// layer is listed, [FloorPlanTable.visible] false (zone spec Z24): read
  /// from its layer at the call, so a layer shown or hidden reads at the
  /// next [revision].
  List<FloorPlanTable> get tables {
    final d = _active.document;
    return [
      for (final t in _tables.tables)
        FloorPlanTable(
            number: t.number,
            seats: t.seats,
            symbolKey: t.symbolKey,
            visible: _onVisibleLayer(d, t.instance))
    ];
  }

  List<FloorPlanTableDetail>? _details;
  List<Handle> _detailInstances = const [];
  DraftDocument? _detailsDocument;
  int? _detailsState;
  int? _detailsLayers;

  /// The active plan's live tables with their geometry (host embedding API
  /// spec G-1), ascending by handle like [tables], one per table: the plan
  /// the current mode shows, so a service move changes it. Read it again
  /// when [revision] moves, as [tables].
  ///
  /// The geometry is the one the fit, the focus veil and the group frames
  /// use. A table on a hidden layer, or whose placement is singular or has
  /// a corner that is not finite, is listed with no geometry
  /// ([FloorPlanTableDetail.center] null).
  ///
  /// Cached: built once per state of the active plan and of its layers, so
  /// a read inside a `build` costs nothing after the first. The list is
  /// unmodifiable, and two reads with nothing changed in between return the
  /// identical list.
  List<FloorPlanTableDetail> get tableDetails {
    final d = _active.document;
    final state = d.commands.stateId;
    final layers = d.tables.mutationRevision;
    if (_details == null ||
        !identical(_detailsDocument, d) ||
        _detailsState != state ||
        _detailsLayers != layers) {
      final instances = <Handle>[];
      _details = _detailsOf(d, _tables, instances);
      _detailInstances = List.unmodifiable(instances);
      _detailsDocument = d;
      _detailsState = state;
      _detailsLayers = layers;
    }
    return _details!;
  }

  /// The instance of each entry of [tableDetails], index for index: the
  /// overlay layer keys a host's widget by it (spec G-5), so two tables
  /// sharing a number keep two widgets. Built with [tableDetails] and kept
  /// as long as it is; never a host's (umbrella D18).
  @internal
  List<Handle> get tableDetailInstances {
    tableDetails;
    return _detailInstances;
  }

  /// [survey]'s tables (of [d]) joined to the picker's candidates by
  /// instance (spec F-8), each one's instance added to [instances] in the
  /// same order. O(nodes + entities): `candidatesOf`'s own survey and a
  /// `leavesByOwner` scan, on top of the survey; at document-change rate.
  List<FloorPlanTableDetail> _detailsOf(
      DraftDocument d, TableSurvey survey, List<Handle> instances) {
    final candidates = {
      for (final c in TablePicker.candidatesOf(d,
          boxes: <Handle, Aabb2>{}, leaves: d.leavesByOwner))
        c.table.instance: c,
    };
    final layers = d.tables.layers;
    final details = <FloorPlanTableDetail>[];
    for (final t in survey.tables) {
      if (d.tree[t.instance] case final InstanceNode node) {
        instances.add(t.instance);
        details.add(_detailOf(
            FloorPlanTable(
                number: t.number,
                seats: t.seats,
                symbolKey: t.symbolKey,
                visible: layers[node.layer]?.visible ?? true),
            candidates[t.instance],
            layers[node.layer],
            // Spec E-6: unmodifiable already; empty when absent or kept.
            d.components.get<FloorPlanTableData>(t.instance)?.data ??
                const <String, String>{}));
      }
    }
    return List.unmodifiable(details);
  }

  static FloorPlanTableDetail _detailOf(FloorPlanTable table, TableCandidate? c,
      LayerRecord? layer, Map<String, String> data) {
    final name = layer?.name ?? '';
    final locked = layer?.locked ?? false;
    if (c == null) {
      return tableDetailWithoutGeometry(
          table: table, layer: name, locked: locked, data: data);
    }
    return tableDetailOf(
        table: table,
        transform: c.transform,
        box: c.box,
        corners: c.corners,
        layer: name,
        locked: locked,
        data: data);
  }

  /// Stores the host's [data] on the table numbered [number] (spec E-6):
  /// one design edit, labelled "Table data", undoable, saved with the plan
  /// and read back as [FloorPlanTableDetail.data]. An empty map removes the
  /// table's data. Returns true when the table's data is now [data] (with
  /// no edit when it already was), false -- changing nothing -- when the
  /// trimmed [number] names no table or more than one (an ambiguous link is
  /// refused, not guessed). A table on a hidden or locked layer takes data:
  /// a link is not a drawing edit.
  ///
  /// Throws a [StateError] in the selection mode (P-5: nothing done there
  /// reaches the design), and an [ArgumentError] -- changing nothing --
  /// when [data] is outside the limits: at most 32 keys, each 1 to 64
  /// characters of `[a-z0-9_.-]`, each value at most 1024 UTF-16 code
  /// units with no control character.
  ///
  /// [dirty] and [canUndo] read the edit on return; [revision] moves as
  /// for any edit.
  bool setTableData(String number, Map<String, String> data) =>
      setTablesData({number: data});

  /// [setTableData] for several tables at once, **all or nothing**, as one
  /// undo step: every map is checked first (an [ArgumentError] for any
  /// outside the limits); then false, changing nothing, when any number
  /// names no table or more than one, or when two keys trim to the same
  /// number. Entries already equal to the table's data are skipped;
  /// nothing left to change is true with no edit. A [StateError] in the
  /// selection mode.
  bool setTablesData(Map<String, Map<String, String>> byNumber) {
    if (_service != null) {
      throw StateError('setTableData needs the design mode (P-5)');
    }
    final wanted = <String, FloorPlanTableData?>{};
    for (final MapEntry(key: number, value: data) in byNumber.entries) {
      if (tableDataProblem(data) case final problem?) {
        throw ArgumentError.value(data, 'data', problem);
      }
      wanted[number] = data.isEmpty ? null : FloorPlanTableData(data);
    }
    _settle?.call();
    final survey = _tables;
    final components = _design.document.components;
    final numbers = <String>{};
    final edits = <DraftCommand>[];
    for (final MapEntry(key: raw, value: next) in wanted.entries) {
      if (!numbers.add(raw.trim())) return false;
      final found = survey.withNumber(raw);
      if (found.length != 1) return false;
      final instance = found.single.instance;
      if (components.get<FloorPlanTableData>(instance) == next) continue;
      edits.add(SetComponentCommand<FloorPlanTableData>(instance, next));
    }
    if (edits.isEmpty) return true;
    _design.document.commands
        .execute(CompoundCommand(edits, label: 'Table data'));
    _refreshFlags();
    return true;
  }

  // ---------------------------------------------------------------------
  // The design's changes (spec E-5).

  late final StreamController<FloorPlanDesignChange> _designChanges =
      StreamController<FloorPlanDesignChange>.broadcast(
          onListen: _watchDesign, onCancel: _unwatchDesign);

  /// The design's tables as last reported, while [designChanges] has a
  /// listener; null otherwise, and then nothing is surveyed for it.
  _DesignBaseline? _baseline;

  int _designScans = 0;

  /// How many times the design's tables were read for [designChanges]: a
  /// test seam proving that nothing is read while no one listens.
  @visibleForTesting
  int get designScans => _designScans;

  /// The designed plan's table changes (spec E-5), a broadcast stream:
  /// after every design edit, undo or redo -- in the editor, through
  /// [setTableData] or [setTablesData], a layer locked, hidden or shown
  /// (one change per table on it) -- the tables added, removed and changed
  /// since the last report, in ascending order of the tables' placement (a
  /// table keeps its place in that order for its life, whatever its
  /// number). A table is matched by its instance, never by its number: a
  /// renumbering is one [FloorPlanTableChanged], an undone delete one
  /// [FloorPlanTableAdded] equal to the [FloorPlanTableRemoved] the delete
  /// reported.
  ///
  /// [load] and [newPlan], in either mode, report the changes still owed
  /// for the plan they replace and then [FloorPlanPlanReplaced] alone: no
  /// change per table. Nothing done in the selection mode is reported: the
  /// service copy is not the design (P-5).
  ///
  /// Delivered asynchronously, as the plan's own changes are: the edits made
  /// in one synchronous step arrive as one report, from the tables before
  /// the first to the tables after the last.
  ///
  /// Nothing is sent on listen: a host reads the starting tables itself,
  /// from [tableDetails] in the design mode (in the selection mode
  /// [tableDetails] is the service copy's, not the design's). The tables are
  /// compared only while the stream has a listener. The first listener
  /// starts from the design as it is when it listens; a listener added
  /// while another listens starts where that one is, so its first report
  /// may include an edit made just before it listened. Closed by [dispose]:
  /// changes not yet delivered then are dropped.
  Stream<FloorPlanDesignChange> get designChanges => _designChanges.stream;

  void _watchDesign() {
    if (_disposed) return;
    _baseline = _designNow();
  }

  void _unwatchDesign() => _baseline = null;

  /// The design's tables now: the cached [tableDetails] while the design
  /// is the active plan, else read from the design's own survey.
  _DesignBaseline _designNow() {
    _designScans++;
    final plan = _design;
    final d = plan.document;
    final List<FloorPlanTableDetail> details;
    final List<Handle> instances;
    if (identical(plan, _active)) {
      details = tableDetails;
      instances = _detailInstances;
    } else {
      final found = <Handle>[];
      details = _detailsOf(d, TableSurvey.of(d), found);
      instances = List.unmodifiable(found);
    }
    return _DesignBaseline(
        d, d.commands.stateId, d.tables.mutationRevision, instances, details);
  }

  /// Reports what changed in the design since the baseline, and moves the
  /// baseline: nothing while no one listens, or when the design has not
  /// moved since (a second change of one synchronous step).
  void _reportDesign() {
    final before = _baseline;
    if (before == null || _disposed || before.isAt(_design.document)) return;
    final after = _baseline = _designNow();
    for (final change in diffTableDetails(
        before.instances, before.details, after.instances, after.details)) {
      _designChanges.add(change);
    }
  }

  TablePicker? _picker;
  int? _pickerState;
  int? _pickerLayers;

  /// The number of the table at [canvasPoint] in the current mode (spec
  /// G-4), or null for none or for an unnumbered table. [canvasPoint] is in
  /// the view's drawing area, logical pixels, origin top left, mapped
  /// through the camera as it is now. A table is found as a tap finds it: a
  /// point on its top, else in its symbol's box, the one drawn on top among
  /// several; with [kind] [PointerDeviceKind.touch], failing both, the
  /// table whose box is nearest within a finger's reach (24 px). A table
  /// on a hidden layer is never found; a locked one is.
  ///
  /// At call rate: the tables are surveyed again only after the active plan
  /// or its layers changed.
  String? tableAt(Offset canvasPoint,
      {PointerDeviceKind kind = PointerDeviceKind.mouse}) {
    final d = _active.document;
    final state = d.commands.stateId;
    final layers = d.tables.mutationRevision;
    var picker = _picker;
    // A picker keeps its definitions' boxes for its life, which only a
    // service copy's runtime permissions make safe: a new one per state.
    if (picker == null ||
        !identical(picker.document, d) ||
        _pickerState != state ||
        _pickerLayers != layers) {
      picker = _picker = TablePicker(d);
      _pickerState = state;
      _pickerLayers = layers;
    }
    final cam = cameraController.value;
    final world = cam.screenToWorld(Vector2(canvasPoint.dx, canvasPoint.dy));
    final reach = kind == PointerDeviceKind.touch
        ? kTouchPickRadiusPixels / cam.scale
        : 0.0;
    return picker.pick(world, reach: reach)?.table.number;
  }

  /// Whether [instance]'s own layer is shown, as the picker reads it (a
  /// layer missing from the table counts as shown): a table is at the root
  /// (14a T1), so no enclosing layer hides it.
  static bool _onVisibleLayer(DraftDocument d, Handle instance) {
    final node = d.tree[instance];
    if (node is! InstanceNode) return true;
    return d.tables.layers[node.layer]?.visible ?? true;
  }

  /// The active plan's numbering problems (umbrella D5, R-13; spec 14d
  /// L6): numbers used by several tables, by first appearance, then the
  /// tables with no number, ascending. Values, not text:
  /// `FloorPlanStrings.numberingWarning` words one.
  List<NumberingWarning> get numberingWarnings {
    final survey = _tables;
    final byNumber = <String, int>{};
    for (final t in survey.tables) {
      if (t.number case final n?) byNumber[n] = (byNumber[n] ?? 0) + 1;
    }
    return [
      for (final MapEntry(key: number, value: count) in byNumber.entries)
        if (count > 1) DuplicateNumber(number: number, count: count),
      for (final t in survey.tables)
        if (t.number == null)
          Unnumbered(seats: t.seats, symbolKey: t.symbolKey),
    ];
  }

  /// Selects every live table carrying one of [numbers] that the selection
  /// can hold -- visible, on an unlocked layer -- replacing the selection
  /// (H3, H13). A number used twice selects both; an unknown one is
  /// ignored. In the selection mode a number in a group stands for every
  /// member of it (table-groups spec G4), filtered by the same rule, so a
  /// hidden or locked member is never selected.
  void select(Set<String> numbers) {
    _settle?.call();
    _select(numbers);
  }

  void _select(Set<String> numbers) {
    final plan = _active;
    final layers = plan.document.tables.layers;
    final keys = <SelectionKey>[];
    for (final n in _expandGroups(numbers)) {
      for (final t in _tables.withNumber(n)) {
        final node = plan.document.tree[t.instance];
        if (node is! InstanceNode) continue;
        final layer = layers[node.layer];
        if (layer != null && (!layer.visible || layer.locked)) continue;
        keys.add(SelectionKey.root(t.instance));
      }
    }
    plan.selection.replace(keys);
    _refreshSelected();
  }

  /// [numbers], each number of a group replaced by all its members (G4):
  /// in the selection mode only, where groups act.
  Set<String> _expandGroups(Set<String> numbers) {
    final groups = _groups.value;
    if (_mode.value != FloorPlanMode.selection || groups.isEmpty) {
      return numbers;
    }
    final lookup = _groupLookup;
    return {
      for (final n in numbers)
        ...switch (lookup.groupOf(n)) {
          null => [n],
          final id => groups[id]!.members,
        }
    };
  }

  TableGroupLookup? _lookup;
  TableSurvey? _lookupSurvey;
  Map<String, TableGroup>? _lookupGroups;
  int? _lookupLayers;

  /// The groups resolved against the active plan's tables, rebuilt when the
  /// survey, the groups or the layers moved.
  TableGroupLookup get _groupLookup {
    final survey = _tables;
    final groups = _groups.value;
    final document = _active.document;
    final layersRevision = document.tables.mutationRevision;
    if (_lookup == null ||
        !identical(_lookupSurvey, survey) ||
        !identical(_lookupGroups, groups) ||
        _lookupLayers != layersRevision) {
      final layers = document.tables.layers;
      _lookup = TableGroupLookup(groups, [
        for (final t in survey.tables)
          if (document.tree[t.instance] case final InstanceNode node)
            GroupTable(
                handle: t.instance,
                number: t.number,
                visible: layers[node.layer]?.visible ?? true,
                locked: layers[node.layer]?.locked ?? false),
      ]);
      _lookupSurvey = survey;
      _lookupGroups = groups;
      _lookupLayers = layersRevision;
    }
    return _lookup!;
  }

  void _refreshSelected() {
    final keys = _active.selection.keys;
    final numbers = <String>{
      for (final t in _tables.tables)
        if (t.number != null && keys.contains(SelectionKey.root(t.instance)))
          t.number!
    };
    if (!setEquals(numbers, _selectedTables.value)) {
      _selectedTables.value = Set.unmodifiable(numbers);
    }
    _refreshSelectedGroup();
  }

  /// [selectedGroup] by G5's Split rule, over the active plan.
  void _refreshSelectedGroup() {
    String? id;
    if (_mode.value == FloorPlanMode.selection && _groups.value.isNotEmpty) {
      final keys = _active.selection.keys;
      final unnumbered = _tables.tables.any((t) =>
          t.number == null && keys.contains(SelectionKey.root(t.instance)));
      id = _groupLookup.splitGroup(_selectedTables.value,
          unnumberedSelected: unnumbered);
    }
    _selectedGroup.value = id;
  }

  /// The active view frames the plan as on its first frame (H3, F-7). It
  /// replaces an earlier [fitToTables] or [centerOn] not yet performed
  /// (zone spec Z5), and a camera command made after it, before the view
  /// performs it, wins over it (spec G-3). The framing is clamped to the
  /// zoom bounds.
  void fitToView() {
    _fitTarget = null;
    _request();
  }

  /// A fit request (spec G-3): the epoch moves, then the views hear it.
  void _request() {
    _fitPending = true;
    _cameraEpoch++;
    _fits.bump();
  }

  /// Puts [world] (millimetres, y up) at the centre of the canvas (spec
  /// G-3), at [scale] (logical pixels per millimetre) when given, else at
  /// the camera's scale; clamped to the zoom bounds about the centre.
  /// Asked with no [scale] before the plan's first frame (after
  /// construction, [load] or [newPlan], until a view has fitted the plan),
  /// it takes the scale the plan's own page fit has at the canvas's size
  /// when it is performed (final review F-1).
  ///
  /// Queued like [fitToView]: the active view performs it at the end of
  /// the frame, at its canvas's size; with no view mounted, the next view
  /// does it on its first frame. The last request wins: a later
  /// [fitToView], [fitToTables], [centerOn], [panBy] or [zoomBy] replaces
  /// it. Throws an [ArgumentError] for a [world] that is not finite or a
  /// [scale] that is not finite and above 0.
  ///
  /// Not document state, as [fitToTables].
  void centerOn(Offset world, {double? scale}) {
    if (!world.isFinite) {
      throw ArgumentError.value(world, 'world', 'must be finite');
    }
    if (scale != null && (!scale.isFinite || scale <= 0)) {
      throw ArgumentError.value(scale, 'scale', 'must be finite and above 0');
    }
    _fitTarget = _Centre(world, scale, pageScale: scale == null && _fitOnStart);
    _request();
  }

  /// Pans the camera by [canvasDelta], logical pixels (spec G-3): the plan
  /// moves by it on the screen. Acts at once, with or without a view; a fit
  /// requested before it ([fitToView], [fitToTables], [centerOn]) and not
  /// performed yet is dropped. Throws an [ArgumentError] for a delta that
  /// is not finite.
  ///
  /// Before a plan's first frame -- after construction, [load] or
  /// [newPlan], until a view has fitted the plan -- the plan's own fit is
  /// still performed after it and overwrites it (Task 2 review R-1): place
  /// the camera before a view shows with [centerOn].
  void panBy(Offset canvasDelta) {
    if (!canvasDelta.isFinite) {
      throw ArgumentError.value(canvasDelta, 'canvasDelta', 'must be finite');
    }
    _command();
    cameraController.panBy(canvasDelta);
  }

  /// Zooms the camera by [factor] about [focus], a canvas point, by default
  /// the canvas's centre (spec G-3); the result is clamped to the zoom
  /// bounds as the user's pinch is, landing on a bound it would pass. Acts
  /// at once, and a fit requested before it ([fitToView], [fitToTables],
  /// [centerOn]) and not performed yet is dropped. Before a plan's first
  /// frame the plan's own fit overwrites it, as for [panBy]; a view
  /// reports [canvasRect] only after that fit, so a [zoomBy] made once
  /// [canvasRect] is known acts on the fitted plan.
  ///
  /// Returns false, changing nothing, while no view is mounted
  /// ([canvasRect] null), or for a [factor] that is not finite and above 0
  /// or a [focus] that is not finite.
  bool zoomBy(double factor, {Offset? focus}) {
    final rect = _canvasRect.value;
    if (rect == null || !factor.isFinite || factor <= 0) return false;
    if (focus != null && !focus.isFinite) return false;
    _command();
    cameraController.zoomAt(focus ?? rect.size.center(Offset.zero), factor);
    return true;
  }

  /// A camera command (spec G-3): the epoch moves, so a view's fit
  /// requested before it is dropped, and a request no view has performed
  /// yet is dropped with its target -- the plan's own first fit, which
  /// stays, then frames the page. That fit is not a host request (Task 2
  /// review R-1): a view performs it whatever the epoch.
  void _command() {
    _cameraEpoch++;
    if (_fitPending) {
      _fitPending = false;
      _fitTarget = null;
    }
  }

  /// Frames the tables of the active plan carrying one of [numbers] (zone
  /// spec Z1-Z9), in either mode, as [fitToView] frames the page: only
  /// the camera moves. Numbers are trimmed and blanks dropped; a number
  /// used twice frames both tables; an unknown one is ignored. A table on
  /// a hidden layer is not framed, a locked one is; an unnumbered table or
  /// a servable instance nested in another block never matches.
  ///
  /// The framed world is the bound of each table's box at its place (its
  /// four corners), grown by [kTableFitMarginMm] per side and to at least
  /// [kTableFitMinSpanMm] per axis.
  ///
  /// Returns whether at least one such table exists now. When none does,
  /// nothing changes: no request is made, the camera stays, and an earlier
  /// request not yet performed stays. Otherwise the last request wins, as
  /// for [fitToView]; with no view mounted, the next view frames on its
  /// first frame. The tables are found again when the view performs it,
  /// so a restore, an Undo or a mode switch in between is followed, and
  /// the page is fitted if none is left. [load] and [newPlan] drop a
  /// request: the numbers named the old plan.
  ///
  /// Not document state: no command, undo step, [dirty], [revision],
  /// [serviceLayoutChanges] or notification; nothing typed is settled.
  bool fitToTables(Set<String> numbers) {
    final wanted = Set<String>.unmodifiable({
      for (final n in numbers)
        if (n.trim() case final t when t.isNotEmpty) t,
    });
    if (_tablesBounds(wanted) == null) return false;
    _fitTarget = _Tables(wanted);
    _request();
    return true;
  }

  // ---------------------------------------------------------------------
  // Bookkeeping.

  _Plan _attach(_Plan plan) {
    plan.changes = plan.document.commands.changes.listen((_) {
      if (_disposed) return;
      _refreshFlags();
      if (identical(plan, _active)) _revision.value++;
      if (identical(plan, _service)) _announceLayout();
      // Spec E-5: the design's changes, never a service copy's.
      if (identical(plan, _design)) _reportDesign();
    });
    plan.announced = plan.document.commands.stateId;
    void onSelection() {
      if (!_disposed && identical(plan, _active)) _refreshSelected();
    }

    plan.onSelection = onSelection;
    plan.selection.addListener(onSelection);
    return plan;
  }

  void _refreshFlags() {
    _dirty.value = _design.document.commands.stateId != _savedState;
    final commands = _active.document.commands;
    _canUndo.value = commands.canUndo;
    _canRedo.value = commands.canRedo;
    _refreshSelected();
  }

  /// Lets [plan] go (R-2): its subscriptions now; the plan itself after
  /// the frame that unmounts its view.
  void _drop(_Plan plan) {
    plan.detach();
    _dropped.add(plan);
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        if (_dropped.remove(plan)) plan.dispose();
      })
      ..ensureVisualUpdate();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final p in _dropped) {
      p.dispose();
    }
    _dropped.clear();
    for (final p in [_design, if (_service != null) _service!]) {
      p
        ..detach()
        ..dispose();
    }
    if (_ownsSymbols) symbols.dispose();
    if (_ownsThumbnails) thumbnails.dispose();
    cameraController.dispose();
    _canvasRect.dispose();
    _fits.dispose();
    _layoutChanges.dispose();
    _mode.dispose();
    _dirty.dispose();
    _canUndo.dispose();
    _canRedo.dispose();
    _selectedTables.dispose();
    _revision.dispose();
    _statuses.dispose();
    _groups.dispose();
    _groupStatuses.dispose();
    _selectedGroup.dispose();
    _focus.dispose();
    _baseline = null;
    unawaited(_designChanges.close());
    super.dispose();
  }
}
