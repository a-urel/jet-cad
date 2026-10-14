// The plan controller (spec 2a P1 services and lifetimes, P2 controller):
// the validated kit set, one design document and every system and view
// over it, the kit-facing services, the camera, the save point and the
// history flags, the changes. Ported from jet_cad_floor_plan's
// FloorPlanController, design half (see Task 8's Ports), and PlannerShell's
// construction of the views (planner_shell.dart:277-671).
import 'dart:async';
import 'dart:ui' show Locale, Offset, Rect, Size;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' show FocusManager;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import '../file/manifest.dart';
import '../file/plan_file.dart';
import '../kits/kit_set.dart';
import '../l10n/document_separator.dart';
import '../l10n/strings.dart';
import '../export/registries.dart';
import '../symbols/plan_symbols_state.dart';
import 'camera_bounds.dart';
import 'diagnostics_log.dart';
import 'new_plan.dart';
import 'plan_change.dart';
import 'services.dart';
import 'session.dart';
import 'tool_settings_store.dart';

/// The thumbnail capacity of a controller's own cache (today's
/// `kFloorPlanThumbnailCapacity`).
const int kPlanThumbnailCapacity = 128;

/// A bump-only notifier: each [bump] is one request.
final class _Requests extends ChangeNotifier {
  void bump() => notifyListeners();
}

/// A queued centring (today's `_Centre`): [world] at the canvas's centre.
final class _Centre {
  const _Centre(this.world, this.scale, {required this.pageScale});

  final Offset world;
  final double? scale;

  /// Asked with no [scale] before the plan's first fit: the page fit's
  /// scale at the canvas's size.
  final bool pageScale;
}

final class _Host implements ServicesHost {
  _Host(this._c);

  final PlanController _c;

  @override
  DocumentSession get session => _c._session;

  @override
  CameraController get camera => _c.camera;

  @override
  SnapSettings get snap => _c._snap;

  @override
  ToolSettingsStore get toolSettings => _c.toolSettings;
}

/// One plan and everything over it (spec P2). A controller is shown in one
/// `PlanCanvas` at a time (Task 15).
class PlanController extends ChangeNotifier {
  /// A controller over [kits] and [json], or an empty plan. Throws, before
  /// it builds anything it would have to dispose: a [KitSetError] for the
  /// kits (spec P4), an [ArgumentError] unless `1e-6 <= minScale <
  /// maxScale`, both finite (today's G-3), and a [PlanFormatException]
  /// when [json] is not a plan.
  ///
  /// The empty plan prints the decimal separator of the first locale a
  /// widget reports ([reportLocale]): until then the engine's point, and
  /// then as if made so -- no undo step, not [dirty] -- unless [save] read
  /// it or an edit touched it first (today's Q0 N1, N2).
  factory PlanController({
    required List<PlanKit> kits,
    String? json,
    SymbolThumbnails? thumbnails,
    List<PlanExporter> exporters = const [],
    List<PlanImporter> importers = const [],
    double minScale = kPlanMinScale,
    double maxScale = kPlanMaxScale,
  }) {
    final set = validateKitSet(kits);
    if (!minScale.isFinite || minScale < _minScaleFloor) {
      throw ArgumentError.value(
          minScale, 'minScale', 'must be finite and at least 1e-6');
    }
    if (!maxScale.isFinite || maxScale <= minScale) {
      throw ArgumentError.value(
          maxScale, 'maxScale', 'must be finite and above minScale');
    }
    final catalog = ParametricCatalog();
    for (final type in set.types) {
      type.registerInto(catalog);
    }
    final measurer = FlutterTextMeasurer();
    final diagnostics = <Diagnostic>[];
    final DraftDocument document;
    try {
      document = json == null
          ? newPlanDocument(measurer, register: (r) => _register(r, catalog))
          : decodePlan(json,
              register: (r) => _register(r, catalog),
              diagnostics: diagnostics,
              measurer: measurer);
    } catch (_) {
      measurer.clear();
      rethrow;
    }
    return PlanController._(set, catalog, document, measurer,
        unsettled: json == null,
        loadDiagnostics: diagnostics,
        thumbnails: thumbnails,
        exporters: exporters,
        importers: importers,
        minScale: minScale,
        maxScale: maxScale);
  }

  PlanController._(this.kits, this.catalog, DraftDocument document,
      FlutterTextMeasurer measurer,
      {required bool unsettled,
      required List<Diagnostic> loadDiagnostics,
      required SymbolThumbnails? thumbnails,
      required List<PlanExporter> exporters,
      required List<PlanImporter> importers,
      required double minScale,
      required double maxScale})
      : exporters = List.unmodifiable(exporters),
        importers = List.unmodifiable(importers),
        _minScale = minScale,
        _maxScale = maxScale,
        _ownsThumbnails = thumbnails == null,
        thumbnails =
            thumbnails ?? SymbolThumbnails(maxEntries: kPlanThumbnailCapacity),
        camera = CameraController(
            ViewportTransform(
                worldToScreenMatrix: const Transform2(1, 0, 0, -1, 0, 0)),
            minScale: minScale,
            maxScale: maxScale),
        toolSettings = ToolSettingsStore(kits) {
    _services = {
      for (final kit in kits.kits)
        kit.id: KitServices(
            kit, _host, KitNamesWords(kit.names, () => _locale.value)),
    };
    _open(document, measurer, loadDiagnostics);
    _savedState = document.commands.stateId;
    if (unsettled) _unsettled = (document: document, at: _savedState);
    _placeNominally();
    _refreshFlags();
  }

  /// The page, the contract's four components and the kits' types: what a
  /// plan's registry holds. Once per registry.
  static void _register(ComponentRegistry r, ParametricCatalog catalog) {
    PageComponent.register(r);
    registerKitComponents(r);
    catalog.registerComponents(r);
  }

  void _registerComponents(ComponentRegistry r) => _register(r, catalog);

  /// The least `minScale`: a thousand times the bound decisions' tolerance.
  static const double _minScaleFloor = 1e-6;

  /// The validated kits, in load order (spec P4).
  final KitSet kits;

  /// Every kit's types, registered once for the controller's life.
  @internal
  final ParametricCatalog catalog;

  /// The one camera of the controller's views, bounded by the zoom bounds.
  final CameraController camera;

  @internal
  final ToolSettingsStore toolSettings;

  /// The symbol thumbnails: the given one, never disposed here, or the
  /// controller's own.
  final SymbolThumbnails thumbnails;
  final bool _ownsThumbnails;

  /// The host's exporters and importers, in order (spec P5); Task 19 adds
  /// the built-in ones and the flows.
  @internal
  final List<PlanExporter> exporters;
  @internal
  final List<PlanImporter> importers;

  final double _minScale, _maxScale;

  late final Map<String, KitServices> _services;
  late final _Host _host = _Host(this);
  late DocumentSession _session;
  List<Diagnostic> _loadDiagnostics = const [];

  final List<DocumentSession> _dropped = [];
  bool _disposed = false;

  final SnapSettings _userSnap = SnapSettings();
  late final EffectiveSnap _snap =
      EffectiveSnap(_userSnap, () => snappingAllowed);

  /// The canvas's `snapping` option (Task 15): object snap only while true.
  @internal
  bool snappingAllowed = true;

  final ValueNotifier<Locale> _locale = ValueNotifier(const Locale('en'));
  final DiagnosticsLog _diagnostics = DiagnosticsLog();
  final ValueNotifier<PlanSymbolsState> _symbolsState =
      ValueNotifier(PlanSymbolsState.ready);
  final ValueNotifier<bool> _dirty = ValueNotifier(false);
  final ValueNotifier<bool> _canUndo = ValueNotifier(false);
  final ValueNotifier<bool> _canRedo = ValueNotifier(false);
  final ValueNotifier<String> _activeTool = ValueNotifier(planSelectToolId);
  Set<String> _missingKits = const {};

  late final PlanChangeTracker _tracker = PlanChangeTracker(_emit);
  late final StreamController<PlanChange> _out =
      StreamController<PlanChange>.broadcast(
          onListen: _tracker.listen, onCancel: _tracker.cancel);
  late final Stream<PlanChange> _changeStream =
      _out.stream.where((_) => !_disposed);

  final List<VoidCallback> _settles = [];

  // ---------------------------------------------------------------------
  // The plan.

  /// The plan's document. Replaced by [load] and [newPlan].
  DraftDocument get document => _session.document;

  /// Whether the plan differs from its save point.
  ValueListenable<bool> get dirty => _dirty;

  int _savedState = 0;

  /// The state the last [save] encoded.
  int? _encodedState;

  /// The plan made with no locale known and its state then, while it is
  /// unsettled; null for a settled or a loaded plan.
  ({DraftDocument document, int at})? _unsettled;

  /// The last locale a widget reported, for [newPlan].
  Locale? _reported;

  /// The language class the last report carried (a host's own, NS7), or
  /// null when it carried none.
  PlanStrings? _reportedStrings;

  /// A new plan's separator under [locale]: the reported class's, else the
  /// built-in language's.
  DecimalSeparator _separatorOf(Locale locale) =>
      documentSeparatorFor(_reportedStrings ?? PlanStrings.forLocale(locale));

  /// The plan's text: the engine's JSON with the manifest of the kits it
  /// uses (Task 7). [markSaved] marks the state encoded here. An empty plan
  /// read here is settled as it is.
  String save() {
    settlePendingInput();
    _unsettled = null;
    _encodedState = document.commands.stateId;
    return encodePlan(document, kits);
  }

  /// The host stored the last [save]: that state is the save point; an
  /// edit made since stays dirty. With no [save] yet, the current state.
  void markSaved() {
    settlePendingInput();
    _savedState = _encodedState ?? document.commands.stateId;
    _refreshFlags();
  }

  /// Replaces the plan with [text] (spec P2). Pending input is settled into
  /// the old plan first. Throws a [PlanFormatException] (a
  /// [FormatException]) and changes nothing when [text] is not a plan.
  void load(String text) {
    settlePendingInput();
    final measurer = FlutterTextMeasurer();
    final diagnostics = <Diagnostic>[];
    final DraftDocument next;
    try {
      next = decodePlan(text,
          register: _registerComponents,
          diagnostics: diagnostics,
          measurer: measurer);
    } catch (_) {
      measurer.clear();
      rethrow;
    }
    _replace(next, measurer, unsettled: false, loadDiagnostics: diagnostics);
  }

  /// Replaces the plan with an empty one printing [decimalSeparator] (`.`
  /// or `,`; any other is an [ArgumentError], and nothing changes); without
  /// one, the separator of the locale last reported, or, with none
  /// reported yet, point and unsettled, as the constructor's plan.
  void newPlan({String? decimalSeparator}) {
    final DecimalSeparator? given = switch (decimalSeparator) {
      null => null,
      '.' => DecimalSeparator.point,
      ',' => DecimalSeparator.comma,
      _ => throw ArgumentError.value(
          decimalSeparator, 'decimalSeparator', 'must be "." or ","'),
    };
    settlePendingInput();
    final reported = _reported;
    final separator = given ??
        (reported == null ? DecimalSeparator.point : _separatorOf(reported));
    final measurer = FlutterTextMeasurer();
    _replace(
        newPlanDocument(measurer,
            register: _registerComponents, decimalSeparator: separator),
        measurer,
        unsettled: given == null && reported == null);
  }

  /// The kits the plan names or uses that are not loaded (spec P4).
  Set<String> get missingKits => _missingKits;

  /// The engine's diagnostics of the last load, kept (spec P4; Task 11).
  @internal
  List<Diagnostic> get loadDiagnostics => _loadDiagnostics;

  /// The type of [object] (E1), or null for anything that is not a live
  /// object of a loaded kit's type.
  PlanType<Component>? typeOf(Handle object) {
    final typeId = catalog.typeIdOf(document, object);
    return typeId == null ? null : kits.typeOf(typeId);
  }

  // ---------------------------------------------------------------------
  // Opening and replacing documents.

  void _open(DraftDocument document, FlutterTextMeasurer measurer,
      List<Diagnostic> loadDiagnostics) {
    final session = DocumentSession(
        document: document,
        measurer: measurer,
        catalog: catalog,
        camera: camera,
        snap: _snap);
    _session = session;
    session.runKitFactories(kits, _services);
    session.tools.addListener(_onTools);
    session.history = document.commands.changes.listen((_) {
      if (!_disposed) _refreshFlags();
    });
    _loadDiagnostics = List.unmodifiable(loadDiagnostics);
    _readManifest();
    _tracker.attach(document);
  }

  /// What the plan's manifest says against the loaded kits (Task 7).
  void _readManifest() {
    _diagnostics.clearPlanScoped();
    final d = _session.document;
    final manifest = manifestOf(d);
    if (manifest == null) {
      _missingKits = const {};
      return;
    }
    final check = checkManifest(manifest, usedKits(d), kits);
    _missingKits = check.missing;
    _diagnostics.reportAll(check.diagnostics);
  }

  /// [document] becomes the plan (spec P1 lifetimes): 1. the active tool
  /// cancelled and select armed; the old plan's owed changes reported;
  /// 2. the old document's kit products disposed; 3. the factories run
  /// over the new document. The old views go after the next frame.
  void _replace(DraftDocument document, FlutterTextMeasurer measurer,
      {required bool unsettled, List<Diagnostic> loadDiagnostics = const []}) {
    final old = _session;
    old.tools.activate(old.select);
    old.tools.removeListener(_onTools);
    _tracker.detach();
    old.disposeKitProducts();
    old.detach();
    _open(document, measurer, loadDiagnostics);
    _tracker.replaced();
    _activeTool.value = planSelectToolId;
    _savedState = document.commands.stateId;
    _unsettled =
        unsettled ? (document: document, at: document.commands.stateId) : null;
    _encodedState = null;
    _fitOnStart = true;
    _fitTarget = null;
    _placeNominally();
    _refreshFlags();
    _drop(old);
    notifyListeners();
  }

  /// Lets [session] go after the frame that unmounts its views (today's
  /// R-2).
  void _drop(DocumentSession session) {
    _dropped.add(session);
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        if (_dropped.remove(session)) session.dispose();
      })
      ..ensureVisualUpdate();
  }

  void _refreshFlags() {
    final commands = document.commands;
    _dirty.value = commands.stateId != _savedState;
    _canUndo.value = commands.canUndo;
    _canRedo.value = commands.canRedo;
  }

  // ---------------------------------------------------------------------
  // Undo and redo.

  ValueListenable<bool> get canUndo => _canUndo;
  ValueListenable<bool> get canRedo => _canRedo;

  bool get _midShape => _session.tools.active.isMidShape;

  /// Undoes the last step, after settling pending input; nothing while the
  /// active tool is part-way through a shape (today's S-4).
  void undo() {
    if (_midShape) return;
    settlePendingInput();
    final commands = document.commands;
    if (commands.canUndo) commands.undo();
  }

  /// Redoes the next step, as [undo].
  void redo() {
    if (_midShape) return;
    settlePendingInput();
    final commands = document.commands;
    if (commands.canRedo) commands.redo();
  }

  // ---------------------------------------------------------------------
  // Tools and the selection.

  /// The active tool's id (`plan.select`, a kit's `<kit>.<tool>`).
  ValueListenable<String> get activeTool => _activeTool;

  void _onTools() {
    _activeTool.value = _session.idOf(_session.tools.active);
  }

  /// Arms the tool [id] (spec P2), as a palette tap would, and answers
  /// whether it is now active: false for an unknown id, a tool the
  /// permissions refuse (Task 12), and a drawing tool while the plan's
  /// permissions deny geometry. A drawing tool clears the selection
  /// (planner_shell.dart:926-933).
  bool selectTool(String id) {
    final session = _session;
    final tool = session.toolById(id);
    if (tool == null || !_allowsTool(id)) return false;
    final drawing = !identical(tool, session.select);
    if (drawing && !document.commands.permissions.allows(Capability.geometry)) {
      return false;
    }
    if (drawing) session.selection.clear();
    session.tools.activate(tool);
    return true;
  }

  /// The permissions' say on a tool; Task 12 fills it.
  bool _allowsTool(String id) => true;

  /// Deletes the selection as the select tool's Delete does, one undo step
  /// (spec P2), after settling pending input. False with nothing selected,
  /// while a shape is part-way, and when every selected object is refused.
  /// Tasks 10 and 12 add the lock and `delete: false`.
  bool deleteSelection() {
    if (_midShape) return false;
    settlePendingInput();
    final session = _session;
    return session.select.deleteSelection(session.toolContext);
  }

  @internal
  ToolController get toolController => _session.tools;
  @internal
  ToolContext get toolContext => _session.toolContext;
  @internal
  SelectionController get selection => _session.selection;
  @internal
  SpatialIndex get index => _session.index;
  @internal
  PageNotifier get page => _session.page;
  @internal
  GripCache get grips => _session.grips;
  @internal
  OutlineCache get outlines => _session.outlines;

  /// The user's F3 setting (Tasks 15, 16, 20 read and toggle it). The
  /// tools and the kits read the effective flag: this while
  /// [snappingAllowed] ([EffectiveSnap]).
  @internal
  SnapSettings get snap => _userSnap;
  @internal
  ParametricSystem get parametric => _session.parametric;
  @internal
  Set<Handle> get frozen => _session.frozen;
  @internal
  DiagnosticsLog get diagnosticsLog => _diagnostics;

  /// The tool [id] of the current document, or null.
  @internal
  Tool? toolFor(String id) => _session.toolById(id);

  /// The kit [kitId]'s services.
  @internal
  PlanServices servicesOf(String kitId) =>
      _services[kitId] ??
      (throw ArgumentError.value(kitId, 'kitId', 'is no loaded kit'));

  // ---------------------------------------------------------------------
  // Pending input.

  /// Registers a settle (a panel field's, the text entry's): called, in
  /// order, before the controller reads or replaces the plan. Returns its
  /// withdrawal, which withdraws only [settle].
  @internal
  VoidCallback registerSettle(VoidCallback settle) {
    _settles.add(settle);
    return () => _settles.remove(settle);
  }

  /// Settles input typed and not committed (planner_shell.dart:859-865):
  /// each registered settle, then the pending focus changes now, so a
  /// field's focus-loss commit lands before the caller reads the plan.
  /// Synchronous, and never called in a build.
  @internal
  void settlePendingInput() {
    for (final settle in List.of(_settles)) {
      settle();
    }
    FocusManager.instance.applyFocusChangesIfNeeded();
  }

  // ---------------------------------------------------------------------
  // The locale.

  /// The app's locale, as the widgets report it (spec P5). Kits' words
  /// read it live.
  ValueListenable<Locale> get locale => _locale;

  bool get _untouched {
    final u = _unsettled;
    if (u == null || !identical(u.document, document)) return false;
    final commands = u.document.commands;
    return commands.stateId == u.at && !commands.canRedo;
  }

  /// A widget's locale (floor_plan_controller.dart:1028-1045) and, when it
  /// has one, its language class [strings] (a host's own gives its own
  /// separator, NS7): kept for [newPlan] and the kits' words. An
  /// unsettled, untouched plan takes its separator now, as if made so: the
  /// page's command, then the history cleared and the save point moved, so
  /// it stays clean with no step.
  @internal
  void reportLocale(Locale locale, {PlanStrings? strings}) {
    _locale.value = locale;
    _reported = locale;
    _reportedStrings = strings;
    final untouched = _untouched;
    _unsettled = null;
    if (!untouched) return;
    final d = document;
    final page = d.components.get<PageComponent>(d.rootHandle)!;
    final separator = _separatorOf(locale);
    if (page.decimalSeparator == separator) return;
    d.commands.execute(SetComponentCommand<PageComponent>(
        d.rootHandle, page.copyWith(decimalSeparator: separator)));
    d.commands.clearHistory();
    _savedState = d.commands.stateId;
  }

  // ---------------------------------------------------------------------
  // State.

  ValueListenable<List<KitDiagnostic>> get diagnostics => _diagnostics;

  /// Task 13 drives it; `ready` until then.
  ValueListenable<PlanSymbolsState> get symbolsState => _symbolsState;

  /// The plan's changes (spec P2 "Events"), a broadcast stream delivered
  /// asynchronously, one report per synchronous step. Closed by [dispose]:
  /// nothing reaches a listener after it.
  Stream<PlanChange> get changes => _changeStream;

  void _emit(PlanChange change) {
    if (!_disposed) _out.add(change);
  }

  @visibleForTesting
  int get debugChangeScans => _tracker.debugScans;

  // ---------------------------------------------------------------------
  // The camera (floor_plan_controller.dart:340-356, :419-526, :812-893,
  // :1966-2060).

  void _placeNominally() {
    const size = Size(1440, 900);
    camera.value = clampCameraScale(_pageFit(document, size), size,
        minScale: _minScale, maxScale: _maxScale);
  }

  static ViewportTransform _pageFit(DraftDocument d, Size size) {
    final page = d.components.isRegistered<PageComponent>()
        ? d.components.get<PageComponent>(d.rootHandle)
        : null;
    return page != null
        ? fitToPage(page, size)
        : ViewportTransform.fit(d.extents, size);
  }

  final ValueNotifier<Rect?> _canvasRect = ValueNotifier(null);
  final Map<Object, Rect> _canvases = {};

  /// The canvas's place in global logical pixels, or null while none is
  /// mounted.
  ValueListenable<Rect?> get canvasRect => _canvasRect;

  /// A canvas is at [global], or, null, [view] is going.
  @internal
  void canvasPlaced(Object view, Rect? global) {
    if (_disposed) return;
    if (global != null) {
      _canvases
        ..remove(view)
        ..[view] = global;
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

  int _cameraEpoch = 0;

  @internal
  int get cameraEpoch => _cameraEpoch;

  final _Requests _fits = _Requests();

  @internal
  Listenable get fitRequests => _fits;

  bool _fitOnStart = true;
  bool _fitPending = false;
  _Centre? _fitTarget;

  @internal
  bool takeFitOnStart() {
    final fit = _fitOnStart || _fitPending;
    _fitOnStart = false;
    return fit;
  }

  @internal
  bool get owesFirstFit => _fitOnStart;

  @internal
  void fitted() => _fitPending = false;

  /// The camera a fit sets in a canvas of [viewport]: null for the page,
  /// else the queued centring. Not finite: none.
  @internal
  ViewportTransform? framingFor(Size viewport) {
    final target = _fitTarget;
    if (target == null) return null;
    final framing = _centred(
        target.world,
        target.pageScale
            ? _pageFit(document, viewport).worldToScreenMatrix.scaleMagnitude
            : target.scale,
        viewport);
    final m = framing.worldToScreenMatrix;
    return [m.a, m.b, m.c, m.d, m.e, m.f].every((v) => v.isFinite)
        ? framing
        : null;
  }

  ViewportTransform _centred(Offset world, double? scale, Size viewport) {
    final m = camera.value.worldToScreenMatrix;
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

  /// The canvas frames the plan as on its first frame; it replaces a
  /// [centerOn] not yet performed.
  void fitToView() {
    _fitTarget = null;
    _request();
  }

  void _request() {
    _fitPending = true;
    _cameraEpoch++;
    _fits.bump();
  }

  /// Puts [world] at the canvas's centre, at [scale] or the camera's, the
  /// next time the canvas fits. An [ArgumentError] for a [world] that is
  /// not finite or a [scale] that is not finite and above 0.
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

  /// Pans by [canvasDelta] at once; a fit requested and not performed is
  /// dropped. An [ArgumentError] for a delta that is not finite.
  void panBy(Offset canvasDelta) {
    if (!canvasDelta.isFinite) {
      throw ArgumentError.value(canvasDelta, 'canvasDelta', 'must be finite');
    }
    _command();
    camera.panBy(canvasDelta);
  }

  /// Zooms by [factor] about [focus] (the canvas's centre by default),
  /// clamped to the bounds; false, changing nothing, with no canvas, a
  /// [factor] that is not finite and above 0, or a [focus] not finite.
  bool zoomBy(double factor, {Offset? focus}) {
    final rect = _canvasRect.value;
    if (rect == null || !factor.isFinite || factor <= 0) return false;
    if (focus != null && !focus.isFinite) return false;
    _command();
    camera.zoomAt(focus ?? rect.size.center(Offset.zero), factor);
    return true;
  }

  void _command() {
    _cameraEpoch++;
    if (_fitPending) {
      _fitPending = false;
      _fitTarget = null;
    }
  }

  // ---------------------------------------------------------------------

  @override
  void dispose() {
    _disposed = true;
    _tracker.detach();
    for (final s in _dropped) {
      s.dispose();
    }
    _dropped.clear();
    final session = _session;
    session.tools.removeListener(_onTools);
    session
      ..disposeKitProducts()
      ..detach()
      ..dispose();
    if (_ownsThumbnails) thumbnails.dispose();
    toolSettings.dispose();
    _diagnostics.dispose();
    _locale.dispose();
    _symbolsState.dispose();
    _dirty.dispose();
    _canUndo.dispose();
    _canRedo.dispose();
    _activeTool.dispose();
    _canvasRect.dispose();
    _fits.dispose();
    _snap.dispose();
    _userSnap.dispose();
    camera.dispose();
    _settles.clear();
    unawaited(_out.close());
    super.dispose();
  }
}
