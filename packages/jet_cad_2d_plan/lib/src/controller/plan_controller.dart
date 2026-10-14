// The plan controller (spec 2a P1 services and lifetimes, P2 controller):
// the validated kit set, one design document and every system and view
// over it, the kit-facing services, the camera, the save point and the
// history flags, the changes. Ported from jet_cad_floor_plan's
// FloorPlanController, design half (see Task 8's Ports), and PlannerShell's
// construction of the views (planner_shell.dart:277-671).
import 'dart:async';
import 'dart:ui' show Locale, Offset, PointerDeviceKind, Rect, Size;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' show FocusManager;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../file/manifest.dart';
import '../file/plan_file.dart';
import '../file/plan_format_exception.dart';
import '../kits/guard.dart';
import '../kits/kit_set.dart';
import '../kits/locks.dart';
import '../l10n/document_separator.dart';
import '../l10n/strings.dart';
import '../export/page_flows.dart';
import '../export/page_printer.dart';
import '../export/registries.dart';
import '../export/unit_colour_underlay.dart' show checkedUnitColourOpacity;
import '../service/service_record.dart';
import '../service/service_session.dart';
import '../service/service_state.dart';
import '../service/unit_picker.dart';
import '../service/view/plan_service_bar.dart' show kServiceBarHeight;
import '../shortcuts/tool_letters.dart';
import '../symbols/plan_symbol.dart';
import '../symbols/plan_symbol_loader.dart';
import '../tools/generic_tools.dart';
import '../tools/move_resolver.dart';
import '../tools/plan_select_gates.dart';
import '../tools/plan_symbol_tool.dart';
import '../units/unit_components.dart';
import '../units/unit_detail.dart';
import '../units/unit_fit.dart';
import '../units/unit_index.dart';
import '../units/unit_label.dart' show unitLabelProblem;
import '../units/unit_problems.dart' show UnitLabelWarning;
import '../units/unit_writes.dart';
import 'camera_bounds.dart';
import 'new_plan.dart';
import 'permissions.dart';
import 'plan_camera.dart';
import 'plan_change.dart';
import 'services.dart';
import 'session.dart';
import 'tool_settings_store.dart';

/// The thumbnail capacity of a controller's own cache (today's
/// `kFloorPlanThumbnailCapacity`).
const int kPlanThumbnailCapacity = 128;

/// Where each mode's canvas starts in a `PlanEditor`, by its chrome alone:
/// the top bar (44), the left column (240) and the rulers in design; the
/// service bar in service.
const Map<PlanMode, Offset> _defaultChromeOrigins = {
  PlanMode.design: Offset(240 + kRulerThickness, 44 + kRulerThickness),
  PlanMode.service: Offset(0, kServiceBarHeight),
};

/// Where each mode's canvas starts until an editor has measured it (R-13
/// as amended). Read when a controller is made; a test seam.
@visibleForTesting
final Map<PlanMode, Offset> planCanvasSeeds = Map.of(_defaultChromeOrigins);

/// The controller's camera (today's `_ViewCamera`): a pan made while a
/// view builds ([panUnheard]) is applied at once and heard after that
/// frame.
final class _PlanCamera extends CameraController {
  _PlanCamera(super.initial, {super.minScale, super.maxScale});

  bool _quiet = false;
  bool _owed = false;
  bool _gone = false;

  /// Pans by [canvasDelta] now, while a view builds: the frame being built
  /// lays out and paints at the new value; the listeners hear it once,
  /// after the frame.
  void panUnheard(Offset canvasDelta) {
    _quiet = true;
    try {
      panBy(canvasDelta);
    } finally {
      _quiet = false;
    }
    if (_owed) return;
    _owed = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        _owed = false;
        if (!_gone) notifyListeners();
      })
      ..ensureVisualUpdate();
  }

  @override
  void notifyListeners() {
    if (_quiet) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _gone = true;
    super.dispose();
  }
}

/// A bump-only notifier: each [bump] is one request.
final class _Requests extends ChangeNotifier {
  void bump() => notifyListeners();
}

/// The unit focus: each [replace] notifies, an equal set or a second null
/// included.
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

/// What a requested fit frames: a centring or some units.
sealed class _FitTarget {
  const _FitTarget();
}

/// A queued centring (today's `_Centre`): [world] at the canvas's centre.
final class _Centre extends _FitTarget {
  const _Centre(this.world, this.scale, {required this.pageScale});

  final Offset world;
  final double? scale;

  /// Asked with no [scale] before the plan's first fit: the page fit's
  /// scale at the canvas's size.
  final bool pageScale;
}

/// A queued framing of the units carrying [labels] (today's `_Tables`,
/// floor_plan_controller.dart:112-115), found again when it is performed.
final class _Units extends _FitTarget {
  const _Units(this.labels);
  final Set<String> labels;
}

/// The public camera (today's `_CameraValue`, floor_plan_controller.dart:
/// 128-155): one [PlanCamera] per camera value, made at the first read
/// after a change. Listening is the camera controller's own.
final class _PlanCameraValue implements ValueListenable<PlanCamera> {
  _PlanCameraValue(this._camera);

  final CameraController _camera;
  ViewportTransform? _for;
  PlanCamera? _value;

  @override
  PlanCamera get value {
    final now = _camera.value;
    if (!identical(now, _for)) {
      _for = now;
      _value = PlanCamera(now);
    }
    return _value!;
  }

  @override
  void addListener(VoidCallback listener) => _camera.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _camera.removeListener(listener);
}

/// The design's units as last reported for `unitChanges` (today's
/// `_DesignBaseline`, floor_plan_controller.dart:2180-2196): at the design
/// while its index is the identical object.
final class _UnitBaseline {
  const _UnitBaseline(this.index, this.instances, this.details);

  final UnitIndex index;
  final List<Handle> instances;
  final List<PlanUnitDetail> details;

  bool isAt(UnitIndex now) => identical(index, now);
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

  @override
  PlanSymbol? symbolById(String id) => _c.symbolById(id);

  @override
  ValueListenable<SymbolsState> get symbolsState => _c._symbolsState;

  @override
  Map<String, SymbolDefinitionRef> get pendingDefinitions =>
      _c._pendingDefinitions;
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
  ///
  /// [symbols] and [thumbnails] may be shared by several controllers (a
  /// host's own); a controller never disposes one it was given, and makes
  /// and disposes its own otherwise. The symbol libraries start loading
  /// here and never block an edit ([symbolsState]).
  ///
  /// [words] are the host's words (spec 2b S4): each kit reads them before
  /// its own, per locale; an id in no known namespace or naming no kit is an
  /// [ArgumentError] naming the first problem (`validateHostWords`).
  factory PlanController({
    required List<PlanKit> kits,
    String? json,
    PlanSymbolLoader? symbols,
    SymbolThumbnails? thumbnails,
    List<PlanExporter> exporters = const [],
    List<PlanImporter> importers = const [],
    double minScale = kPlanMinScale,
    double maxScale = kPlanMaxScale,
    PlanPermissions permissions = PlanPermissions.full,
    KitNames words = KitNames.empty,
  }) {
    final set = validateKitSet(kits);
    final wordProblems = validateHostWords(words);
    if (wordProblems.isNotEmpty) {
      throw ArgumentError.value(words, 'words', '${wordProblems.first}');
    }
    PlanPageFlows.checkRegistry(exporters: exporters, importers: importers);
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
      type.registerInto(catalog, guard: const PlanTypeGuard());
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
        symbols: symbols,
        thumbnails: thumbnails,
        exporters: exporters,
        importers: importers,
        minScale: minScale,
        maxScale: maxScale,
        permissions: permissions,
        words: words);
  }

  PlanController._(this.kits, this.catalog, DraftDocument document,
      FlutterTextMeasurer measurer,
      {required bool unsettled,
      required List<Diagnostic> loadDiagnostics,
      required PlanSymbolLoader? symbols,
      required SymbolThumbnails? thumbnails,
      required List<PlanExporter> exporters,
      required List<PlanImporter> importers,
      required double minScale,
      required double maxScale,
      required PlanPermissions permissions,
      required KitNames words})
      : _permissions = permissions,
        _hostWords = words,
        _minScale = minScale,
        _maxScale = maxScale,
        _symbolLoader = symbols ?? PlanSymbolLoader(),
        _ownsSymbolLoader = symbols == null,
        _ownsThumbnails = thumbnails == null,
        thumbnails =
            thumbnails ?? SymbolThumbnails(maxEntries: kPlanThumbnailCapacity),
        camera = _PlanCamera(
            ViewportTransform(
                worldToScreenMatrix: const Transform2(1, 0, 0, -1, 0, 0)),
            minScale: minScale,
            maxScale: maxScale),
        toolSettings = ToolSettingsStore(kits) {
    pageFlows = PlanPageFlows(
      exporters: exporters,
      importers: importers,
      unexported: {
        for (final kit in kits.kits)
          for (final type in kit.types)
            if (!type.exported) type.id,
      },
      // The active document (spec 2b S3): export and print act on the
      // copy in service. A switch before the bytes are made answers null,
      // as a replaced plan does.
      document: () => activeDocument,
      catalog: () => catalog,
      settle: settlePendingInput,
      load: load,
      // The active document's units (Task 9): the built-ins' fills.
      units: () => unitIndex,
    );
    _services = {
      for (final kit in kits.kits)
        kit.id: KitServices(
            kit, _host, KitNamesWords(_names[kit.id]!, () => _locale.value)),
    };
    _open(document, measurer, loadDiagnostics);
    _savedState = document.commands.stateId;
    if (unsettled) _unsettled = (document: document, at: _savedState);
    _placeNominally();
    _refreshFlags();
    // The tool letters are the kit set's (Task 16): a letterTaken
    // diagnostic is in the log before any widget is built.
    planToolEntries(this);
    // Last: a constructor that threw leaves no load running.
    unawaited(_loadSymbols());
  }

  /// The page, the contract's four components, the unit components and the
  /// kits' types: what a plan's registry holds. Once per registry.
  static void _register(ComponentRegistry r, ParametricCatalog catalog) {
    PageComponent.register(r);
    registerKitComponents(r);
    registerUnitComponents(r);
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

  /// The symbol libraries' loader: the given one, never disposed here, or
  /// the controller's own.
  final PlanSymbolLoader _symbolLoader;
  final bool _ownsSymbolLoader;
  final ValueNotifier<PlanSymbol?> _armed = ValueNotifier<PlanSymbol?>(null);
  List<PlanSymbol> _symbols = const [];
  Map<String, PlanSymbol> _symbolsById = const {};
  int _symbolRun = 0;

  /// The export, print and import flows (spec P2, P5): the registries,
  /// the one-flow guard every view of this controller shares, the
  /// remembered dialog answer and the font.
  @internal
  late final PlanPageFlows pageFlows;

  /// `plan.pdf`, `plan.png`, then the host's exporters, in order.
  List<PlanExporter> get exporters => pageFlows.exporters;

  /// The host's importers, in order.
  List<PlanImporter> get importers => pageFlows.importers;

  /// [exporterId]'s bytes of the plan as [choice] says, named
  /// `<name>.<extension>` (`name` defaults to `plan`), with no view
  /// mounted (spec P2).
  ///
  /// Null when an export or a print already runs for this controller
  /// (one at a time, its views' included), when the exporter plots the
  /// page and the plan has none, when the plan is replaced (`load`,
  /// `newPlan`, `import`) before the bytes are made, or after [dispose].
  /// Pending input is settled first; the exporter is handed a copy of the
  /// plan made then. The dialog's remembered answer is left as it is. An
  /// error completes the `Future` with it; an unknown [exporterId] is an
  /// [ArgumentError] at once. Not gated by [permissions] (a host call).
  ///
  /// The coloured units are filled under the drawing at
  /// [unitColourOpacity] when given, else at 0.35: with no view there is
  /// no theme to read. A given opacity not finite or outside `[0, 1]`
  /// throws an [ArgumentError] at once, before any flow runs.
  Future<PlanExport?> export(String exporterId, PlanExportChoice choice,
      {String? name, double? unitColourOpacity}) {
    final opacity = checkedUnitColourOpacity(unitColourOpacity);
    return pageFlows.export(exporterId, choice,
        name: name ?? 'plan', unitColourOpacity: opacity);
  }

  /// The plan's page as a PDF to [printer] (the platform's print dialog
  /// when null), named [name] (`plan` when null). True once the printer
  /// is done; false under [export]'s rules for null. Not gated by
  /// [permissions].
  ///
  /// The coloured units are filled under the drawing at
  /// [unitColourOpacity] when given, else at 0.35: with no view there is
  /// no theme to read. A given opacity not finite or outside `[0, 1]`
  /// throws an [ArgumentError] at once, before any flow runs.
  Future<bool> print(PlanExportChoice choice,
      {PagePrinter? printer, String? name, double? unitColourOpacity}) {
    final opacity = checkedUnitColourOpacity(unitColourOpacity);
    return pageFlows.print(choice,
        printer: printer ?? const PrintingPagePrinter(),
        name: name ?? 'plan',
        unitColourOpacity: opacity);
  }

  /// Reads [bytes] with [importerId]'s importer and loads the plan's
  /// text, an empty manifest added when it has none (spec P5). An
  /// importer's error, or a load that refuses ([PlanFormatException]),
  /// completes the `Future` with it and changes nothing; an unknown
  /// [importerId] is an [ArgumentError] at once.
  Future<void> import(String importerId, Uint8List bytes) =>
      pageFlows.import(importerId, bytes);

  final double _minScale, _maxScale;

  late final Map<String, KitServices> _services;

  /// The host's words (spec 2b S4).
  final KitNames _hostWords;

  /// Each loaded kit's words with the host's first, per locale.
  late final Map<String, KitNames> _names = {
    for (final kit in kits.kits) kit.id: _hostWords.merge(kit.names),
  };

  /// The words of the loaded kit [kitId], the host's first (spec 2b S4);
  /// null for a kit that is not loaded. Every reader of a kit's words reads
  /// them here or through its services.
  @internal
  KitNames? namesOf(String kitId) => _names[kitId];

  /// The refs `symbolDefinition` handed out whose `add` has not executed
  /// (spec 2b S2): cleared by [execute] and by a document swap.
  final Map<String, SymbolDefinitionRef> _pendingDefinitions = {};
  late final _Host _host = _Host(this);
  late DocumentSession _session;
  List<Diagnostic> _loadDiagnostics = const [];

  final List<DocumentSession> _dropped = [];
  bool _disposed = false;

  /// Whether [dispose] ran: a report owed after a frame (the locale push,
  /// Task 15) checks it before it lands.
  @internal
  bool get isDisposed => _disposed;

  final SnapSettings _userSnap = SnapSettings();
  late final EffectiveSnap _snap =
      EffectiveSnap(_userSnap, () => snappingAllowed);

  bool _snappingAllowed = true;
  bool _snappingNoticeOwed = false;
  final ValueNotifier<bool> _snapping = ValueNotifier<bool>(true);

  /// The canvas's `snapping` option (Task 15): object snap only while true.
  /// The tools read it at once ([EffectiveSnap]); [snapping] tells the
  /// keyboard (F3, Task 16) after the current frame.
  @internal
  bool get snappingAllowed => _snappingAllowed;

  /// Written by the canvas in `initState` and `didUpdateWidget`, inside a
  /// build, where an ancestor (PlanShortcuts) may not be marked dirty: the
  /// value changes now, and [snapping] follows it after the frame (as
  /// `PlanLocaleScope.push` reports the locale).
  @internal
  set snappingAllowed(bool value) {
    if (value == _snappingAllowed) return;
    _snappingAllowed = value;
    if (_snappingNoticeOwed) return;
    _snappingNoticeOwed = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        _snappingNoticeOwed = false;
        if (!_disposed) _snapping.value = _snappingAllowed;
      })
      ..ensureVisualUpdate();
  }

  /// [snappingAllowed] as of the last frame: PlanShortcuts rebinds F3 when
  /// it changes (S-14: F3 only while snapping is allowed).
  @internal
  ValueListenable<bool> get snapping => _snapping;

  final ValueNotifier<Locale> _locale = ValueNotifier(const Locale('en'));
  final DiagnosticsLog _diagnostics = DiagnosticsLog();
  final ValueNotifier<SymbolsState> _symbolsState =
      ValueNotifier(SymbolsState.ready);
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

  /// The editor's permissions (spec P2); the Fill toggle; each known tool
  /// id's needs. Kept across document swaps.
  PlanPermissions _permissions;
  final ValueNotifier<bool> _fill = ValueNotifier<bool>(false);
  final Map<String, Set<Capability>> _toolNeeds = <String, Set<Capability>>{};

  /// plan.select's move resolver (Task 14): one for the controller's life,
  /// reading the current document from each call's context and the current
  /// registry from the session.
  late final PlanMoveResolver _moveResolver = PlanMoveResolver(
      attachments: () => _session.attachments,
      canRotate: () => _permissions.rotate);

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

  /// The language class the widgets last reported (a host's own included),
  /// else the built-in language of [locale]: the plan library's words
  /// outside a widget (the unit kinds', `unitKindWord`).
  @internal
  PlanStrings get planStrings =>
      _reportedStrings ?? PlanStrings.forLocale(_locale.value);

  /// A new plan's separator under [locale]: the reported class's, else the
  /// built-in language's.
  DecimalSeparator _separatorOf(Locale locale) =>
      documentSeparatorFor(_reportedStrings ?? PlanStrings.forLocale(locale));

  /// The plan's text: the engine's JSON with the manifest of the kits it
  /// uses (Task 7). [markSaved] marks the state encoded here. An empty plan
  /// read here is settled as it is.
  ///
  /// A damaged plan (E3) is first read back; if it does not encode or does
  /// not decode, nothing is returned: a [PlanFormatException]
  /// (`damagedUnsavable`), and a diagnostic.
  String save() {
    if (!_damaged.value) return _saveUnchecked();
    final ({String text, int state}) encoded;
    try {
      encoded = _encode();
      unawaited(decodePlan(encoded.text,
          register: _registerComponents,
          diagnostics: <Diagnostic>[]).dispose());
    } catch (error) {
      _diagnostics.add(KitDiagnostic(
          kitId: 'plan',
          code: KitDiagnosticCode.damagedUnsavable,
          message: '$error',
          error: error));
      throw PlanFormatException(PlanFormatCode.damagedUnsavable,
          'the damaged plan does not read back: $error');
    }
    // Only a text that read back is one [markSaved] may mark (final
    // review).
    _encodedState = encoded.state;
    return encoded.text;
  }

  /// Task 8's save: the state is marked encoded only once it encoded.
  String _saveUnchecked() {
    final encoded = _encode();
    _encodedState = encoded.state;
    return encoded.text;
  }

  /// The plan's text and the state it encodes, pending input settled
  /// first; nothing is marked.
  ({String text, int state}) _encode() {
    settlePendingInput();
    _unsettled = null;
    final state = document.commands.stateId;
    return (text: encodePlan(document, kits), state: state);
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

  // ---------------------------------------------------------------------
  // Locks (spec P4).

  /// The locked objects of the current document (spec P4).
  final ValueNotifier<Set<Handle>> _locked = ValueNotifier(const {});

  /// The locked objects: a missing kit's, an unknown type's, a broken
  /// one's. Never the root.
  ValueListenable<Set<Handle>> get locked => _locked;

  /// Whether [handle] is locked: a locked object, inside one, or inside a
  /// locked symbol's definition. The property panel shows no section for
  /// it; the pickers refuse it.
  bool isLocked(Handle handle) => _session.locks.covers(document, handle);

  /// Locks [objects] in the middle of a session (spec P4: a type's code
  /// failed, Task 11): adds them to the lock set, clears the undo history
  /// so no earlier edit can be undone onto them, and tells the listeners.
  ///
  /// A lock is no edit (it moves no state id): by itself it moves neither
  /// [revision] nor [unitChanges], though [unitDetails] reads the new
  /// `locked` at once. Neither member names a lock: [unitChanges] reports
  /// design edits, undos and redos, [load] and [newPlan] (spec 2b S3), and
  /// [revision] is today's (spec S5), whose doc names an edit, an undo or a
  /// redo, a mode switch, `load`, `newPlan` and `resetLayout`
  /// (jet_cad_floor_plan's floor_plan_controller.dart:570-573). When the
  /// edit that froze the objects applies on its retry, that edit reports
  /// the lock with it; when the retry is refused, the lock is reported with
  /// the next design change.
  @internal
  void lockBroken(Set<Handle> objects) => _lock(objects, document.commands);

  /// [objects] join the design's lock set (refreshed over the design, whose
  /// handles a service copy shares), [history]'s undo history is cleared
  /// so no earlier step is undone onto them, and the listeners are told:
  /// [lockBroken] clears the design's, the copy's boundary the copy's.
  void _lock(Set<Handle> objects, CommandDispatcher history) {
    if (objects.isEmpty) return;
    _session.locks.addBroken(document, objects);
    history.clearHistory();
    _locked.value = _session.locks.objects;
    // clearHistory emits no change: refresh the undo listenables here.
    _refreshFlags();
    grips.gatesChanged();
    notifyListeners();
  }

  /// Set when an edit is refused because it would change a locked object;
  /// the canvas shows a short hint and clears it (Task 15).
  final ValueNotifier<bool> lockHint = ValueNotifier(false);

  final ValueNotifier<bool> _damaged = ValueNotifier(false);

  /// Whether a rollback threw in this document (E3): the plan was rebuilt
  /// from what it holds, and saving reads it back first. Listenable: the
  /// editor's bar shows a warning while it holds (Task 20).
  ValueListenable<bool> get damaged => _damaged;

  final Set<String> _disabledTools = {};

  /// Whether [toolId]'s factory threw for the current document (spec P4):
  /// the palette greys it, and [selectTool] leaves `plan.select` armed.
  bool isToolDisabled(String toolId) => _disabledTools.contains(toolId);

  /// Executes [command] on the current document: the commit path of every
  /// widget and panel (controller ruling R-b; no widget calls
  /// `document.commands.execute`). True when it applied; false when it was
  /// refused, the refusal caught here: [PlanLocked] (and [lockHint] set;
  /// the engine's refusal of a write on a frozen, locked object is one),
  /// `DanglingReferenceError` (E2's refusal of a frozen object's
  /// referrer), `PermissionDeniedError` (the engine permissions the
  /// editor's permissions set, e.g. [PlanPermissions.readOnly]),
  /// `ArgumentError`, and a kit's hook failure the retry did not cure (one
  /// diagnostic). `StateError` (`PartialMutationError` included, after the
  /// damage is handled) goes on to the caller.
  ///
  /// Drops the pending symbol definitions (spec 2b S2).
  ///
  /// False in service (spec 2b S3): the design is not edited there.
  bool execute(DraftCommand command) {
    if (_service != null) return false;
    _pendingDefinitions.clear();
    try {
      document.commands.execute(command);
      return true;
    } on PlanLocked {
      lockHint.value = true;
      return false;
    } on DanglingReferenceError {
      return false;
    } on PermissionDeniedError {
      return false;
    } on ArgumentError {
      return false;
    } on KitHookFailure catch (failure) {
      _reportFailure(failure);
      return false;
    }
  }

  void _reportFailure(KitHookFailure failure) => _diagnostics.add(KitDiagnostic(
      kitId: failure.kitId,
      subject: failure.typeId,
      code: KitDiagnosticCode.hookFailed,
      message: '${failure.hook}: ${failure.error}',
      error: failure.error));

  /// E3: a rollback threw. The plan is rebuilt from what it holds (the
  /// history cleared, every view told the document was loaded), the locks
  /// refreshed over it, and it is marked damaged.
  void _damage(PartialMutationError error) {
    _damaged.value = true;
    document.commands.notifyLoaded();
    _session.locks.addBroken(document, const []);
    _refreshFlags();
    notifyListeners();
  }

  /// The decorator every tool of a document's map wears (spec P4).
  Tool _guardTool(String kitId, String toolId, Tool tool) => GuardedTool(
      inner: tool,
      kitId: kitId,
      toolId: toolId,
      log: _diagnostics,
      lockHint: lockHint,
      onFailed: () {
        if (!_disposed) selectTool(planSelectToolId);
      });

  /// The type of [object] (E1), or null for anything that is not a live
  /// object of a loaded kit's type.
  PlanType<Component>? typeOf(Handle object) {
    final typeId = catalog.typeIdOf(document, object);
    return typeId == null ? null : kits.typeOf(typeId);
  }

  // ---------------------------------------------------------------------
  // The unit API (spec 2b S3), design side (Task 9). Task 11 re-points the
  // seams below to the service copy in service; every member that switches
  // on the mode reads them.

  /// The active document's units: the copy's in service (spec S3).
  UnitIndexCache get _activeUnits => _service?.units ?? _session.units;

  /// The active document: the copy in service.
  DraftDocument get _activeDocument => activeDocument;

  /// The active selection: the copy's in service.
  SelectionController get _activeSelection => activeSelection;

  /// Whether the design is the active document.
  bool get _inDesign => _service == null;

  /// Throws a [StateError] naming [who] in service: a design write is
  /// refused there (spec S3, today's P-5). Nothing in design.
  void _requireDesign(String who) {
    if (_service != null) {
      throw StateError('$who needs the design mode (P-5)');
    }
  }

  /// The design session's unit index cache (Task 6): the design canvas's
  /// colours read it, whatever the mode.
  @internal
  UnitIndexCache get documentUnits => _session.units;

  /// The active document's unit index (`@internal`): the panels, the
  /// inspector and the tests read it.
  @internal
  UnitIndex get unitIndex => _activeUnits.current;

  final ValueNotifier<int> _revision = ValueNotifier(0);

  /// Moves whenever the active plan changes: an edit, an undo or a redo of
  /// it (the design's in design, the copy's in service), a mode switch,
  /// [load], [newPlan], [resetService], [restoreService]. A host
  /// re-reads [units] and [labelWarnings] on it.
  ValueListenable<int> get revision => _revision;

  late final _PlanCameraValue _cameraValue = _PlanCameraValue(camera);

  /// Where the plan is on the canvas: a new [PlanCamera] at every pan, zoom
  /// and fit; two reads with no camera change in between are identical.
  ValueListenable<PlanCamera> get cameraValue => _cameraValue;

  /// The global point that shows [world], or null with no canvas mounted.
  Offset? worldToGlobal(Offset world) {
    final rect = _canvasRect.value;
    if (rect == null) return null;
    return cameraValue.value.worldToCanvas(world) + rect.topLeft;
  }

  /// The world point shown at the global point [global], or null with no
  /// canvas mounted.
  Offset? globalToWorld(Offset global) {
    final rect = _canvasRect.value;
    if (rect == null) return null;
    return cameraValue.value.canvasToWorld(global - rect.topLeft);
  }

  /// The active plan's units, ascending by instance, placed and generated
  /// (a unit on a hidden layer is listed, [PlanUnit.visible] false).
  List<PlanUnit> get units => [
        for (final u in _activeUnits.current.units) _unitOf(u),
      ];

  static PlanUnit _unitOf(UnitInfo u) => PlanUnit(
      label: u.text,
      kind: u.kind,
      capacity: u.capacity,
      symbolKey: u.symbolKey,
      visible: u.visible,
      generatedBy: u.ownerType);

  List<PlanUnitDetail>? _details;
  List<Handle> _detailInstances = const [];
  UnitIndex? _detailsIndex;

  /// The active plan's units with their geometry (today's `tableDetails`,
  /// floor_plan_controller.dart:1495-1514), ascending by instance like
  /// [units], one per unit. Cached per unit index (a state, a layer or a
  /// lock change makes a new one): two reads with nothing changed return
  /// the identical, unmodifiable list.
  List<PlanUnitDetail> get unitDetails {
    final index = _activeUnits.current;
    if (_details == null || !identical(index, _detailsIndex)) {
      final instances = <Handle>[];
      _details = _detailsOf(_activeDocument, index, instances);
      _detailInstances = List.unmodifiable(instances);
      _detailsIndex = index;
    }
    return _details!;
  }

  /// The instance of each entry of [unitDetails], index for index (the
  /// inspector and the overlays key by it). Never a host's.
  @internal
  List<Handle> get unitDetailInstances {
    unitDetails;
    return _detailInstances;
  }

  /// [index]'s units of [d] joined to the picker's candidates by instance
  /// (today's `_detailsOf`, :1527-1555), each instance added to
  /// [instances] in the same order. O(nodes + entities), at document-change
  /// rate.
  List<PlanUnitDetail> _detailsOf(
      DraftDocument d, UnitIndex index, List<Handle> instances) {
    final candidates = {
      for (final c in UnitPicker.candidatesOf(d, index,
          boxes: <Handle, Aabb2>{}, leaves: d.leavesByOwner))
        c.unit.instance: c,
    };
    final layers = d.tables.layers;
    final details = <PlanUnitDetail>[];
    for (final u in index.units) {
      final node = d.tree[u.instance];
      if (node is! InstanceNode) continue;
      instances.add(u.instance);
      final unit = _unitOf(u);
      final layer = layers[node.layer]?.name ?? '';
      final data = d.components.get<UnitData>(u.instance)?.data ??
          const <String, String>{};
      final colour = d.components.get<UnitColour>(u.instance)?.swatch;
      final c = candidates[u.instance];
      details.add(c == null
          ? unitDetailWithoutGeometry(
              unit: unit,
              layer: layer,
              locked: u.locked,
              data: data,
              colour: colour)
          : unitDetailOf(
              unit: unit,
              transform: c.transform,
              box: c.box,
              corners: c.corners,
              layer: layer,
              locked: u.locked,
              data: data,
              colour: colour));
    }
    return List.unmodifiable(details);
  }

  /// The active plan's labelling problems (today's `numberingWarnings`):
  /// duplicates by first appearance, then the unlabelled units, then the
  /// bad labels (Task 6's order).
  List<UnitLabelWarning> get labelWarnings => _activeUnits.current.warnings();

  UnitPicker? _atPicker;
  UnitIndex? _atIndex;

  /// The label of the unit at [canvasPoint] (today's `tableAt`, :1792-
  /// 1818): a point on its top, else in its symbol's box, the one drawn on
  /// top among several; for a touch, failing both, the unit whose box is
  /// nearest within a finger's reach (24 px). A unit on a hidden layer is
  /// never found; a locked one is; an unlabelled one answers null.
  String? unitAt(Offset canvasPoint,
      {PointerDeviceKind kind = PointerDeviceKind.mouse}) {
    final units = _activeUnits;
    final index = units.current;
    var picker = _atPicker;
    if (picker == null ||
        !identical(picker.units, units) ||
        !identical(_atIndex, index)) {
      picker = _atPicker = UnitPicker(_activeDocument, units);
      _atIndex = index;
    }
    final cam = camera.value;
    final world = cam.screenToWorld(Vector2(canvasPoint.dx, canvasPoint.dy));
    final reach = kind == PointerDeviceKind.touch
        ? kTouchPickRadiusPixels / cam.scale
        : 0.0;
    return picker.pick(world, reach: reach)?.text;
  }

  /// Selects every unit carrying one of [labels] that the selection can
  /// hold -- visible, not locked -- replacing the selection (today's
  /// `select`, :1834-1870). A label two units share selects both; an
  /// unknown one is ignored. In design, placed units only (the design's
  /// selection holds root objects). In service a label in a group stands
  /// for the group's selectable members (the same filter).
  void select(Set<String> labels) {
    settlePendingInput();
    _select(labels);
  }

  void _select(Set<String> labels) {
    final index = _activeUnits.current;
    final placedOnly = _inDesign;
    final keys = <SelectionKey>[];
    for (final l in _expandLabels(labels)) {
      for (final u in index.withLabel(l)) {
        if (placedOnly && u.generated) continue;
        if (!u.visible || u.locked) continue;
        keys.add(SelectionKey.root(u.instance));
      }
    }
    _activeSelection.replace(keys);
    _refreshSelected();
  }

  final ValueNotifier<Set<String>> _selectedUnits =
      ValueNotifier(const <String>{});
  final ValueNotifier<Set<String>> _editorSelected =
      ValueNotifier(const <String>{});

  /// The labels of the units selected in the design's editor (today's
  /// `editorSelectedTables`, :796-800): the active selection's in design,
  /// empty in service. Unmodifiable; it notifies only when the set changes.
  ValueListenable<Set<String>> get editorSelectedUnits => _editorSelected;

  /// The labels of the active selection's units (today's
  /// `selectedTables`): the design's in design, the copy's in service.
  ValueListenable<Set<String>> get selectedUnits => _selectedUnits;

  /// The labels of the active selection's units (today's
  /// `_refreshSelected`, :1921-1940).
  void _refreshSelected() {
    final index = _activeUnits.current;
    final labels = <String>{
      for (final k in _activeSelection.keys)
        if (k.chain.isEmpty)
          if (index[k.target]?.text case final t?) t,
    };
    if (!setEquals(labels, _selectedUnits.value)) {
      _selectedUnits.value = Set.unmodifiable(labels);
    }
    final editor = _inDesign ? _selectedUnits.value : const <String>{};
    if (!setEquals(editor, _editorSelected.value)) {
      _editorSelected.value = editor;
    }
    _refreshSelectedGroup();
  }

  // ---------------------------------------------------------------------
  // Service state (spec 2b S3 "Service state"), by label. Kept for the
  // controller's life: across mode switches, resetService, restoreService,
  // load and newPlan. Not document state: no command, undo step, dirty or
  // revision; never saved, exported or printed.

  final ValueNotifier<Map<String, UnitStatus>> _statuses =
      ValueNotifier(const <String, UnitStatus>{});
  final ValueNotifier<Map<String, UnitGroup>> _groups =
      ValueNotifier(const <String, UnitGroup>{});
  final ValueNotifier<Map<String, UnitStatus>> _groupStatuses =
      ValueNotifier(const <String, UnitStatus>{});
  final ValueNotifier<String?> _selectedGroup = ValueNotifier(null);
  final ValueNotifier<Set<String>?> _mergeCandidate = ValueNotifier(null);
  final _Focus _focus = _Focus();

  /// The units' statuses by label, as [setUnitStatus] last set them; drawn
  /// in service only, on every live, visible unit carrying the label.
  ValueListenable<Map<String, UnitStatus>> get unitStatuses => _statuses;

  /// Replaces every status at once: labels trimmed.
  void setUnitStatus(Map<String, UnitStatus> statuses) {
    _statuses.value = Map.unmodifiable(
        {for (final e in statuses.entries) e.key.trim(): e.value});
  }

  /// The unit groups by trimmed id, as [setUnitGroups] last set them; they
  /// act in service only.
  ValueListenable<Map<String, UnitGroup>> get unitGroups => _groups;

  /// Replaces every group at once: ids trimmed. Throws an [ArgumentError]
  /// for a blank id, two ids the same after trimming, a group with no
  /// member after trimming, or a label in two groups; then nothing is
  /// assigned and no listener is notified. A member label with no live
  /// unit is kept; a shared label is allowed; a group may mix kinds. In
  /// service it fires [serviceChanges] (the groups are in the record); in
  /// design it notifies [unitGroups] only.
  void setUnitGroups(Map<String, UnitGroup> groups) {
    final valid = validateUnitGroups(groups);
    _groups.value = valid;
    _refreshSelectedGroup();
    if (_service != null) _serviceChanges.bump();
  }

  /// The groups' statuses by trimmed id, as [setGroupStatus] last set them.
  ValueListenable<Map<String, UnitStatus>> get groupStatuses => _groupStatuses;

  /// Replaces every group status at once: ids trimmed. A group's status
  /// fills every visible member and overrides each member's own status
  /// while it is set. A status whose id has no group is kept, draws
  /// nothing, and applies again when a group with that id comes back.
  void setGroupStatus(Map<String, UnitStatus> statuses) {
    _groupStatuses.value = Map.unmodifiable(
        {for (final e in statuses.entries) e.key.trim(): e.value});
  }

  /// The labels in focus, as [setUnitFocus] last set them: null for none.
  /// In service every unit outside a focus lies under a veil.
  ValueListenable<Set<String>?> get unitFocus => _focus;

  /// Replaces the focus: null for none, else [labels] trimmed, blanks
  /// dropped, copied into an unmodifiable set, so `{}` and `{''}` are a
  /// focus with no unit. Every call notifies [unitFocus], an equal set
  /// included. Presentation only: no command, undo step, dirty, revision,
  /// service change or notification of this controller.
  void setUnitFocus(Set<String>? labels) {
    _focus.replace(labels == null
        ? null
        : Set<String>.unmodifiable({
            for (final l in labels)
              if (l.trim() case final t when t.isNotEmpty) t,
          }));
  }

  /// The id of the group the selection is exactly (the Split rule): the
  /// selected labels are that group's selectable members' labels, and no
  /// unlabelled unit is selected. Null otherwise, and always in design.
  /// It updates after [selectedUnits] and [unitGroups] have notified.
  ValueListenable<String?> get selectedGroup => _selectedGroup;

  /// The labels the service bar's Merge would send: in service
  /// [selectedUnits], unmodifiable, when they span two or more groups or
  /// ungrouped labels; null otherwise, and always in design.
  ValueListenable<Set<String>?> get mergeCandidate => _mergeCandidate;

  /// The labels of group [groupId]'s (trimmed) selectable members in the
  /// active document: its live members on a shown layer that no lock
  /// covers. A label several units carry is in it once. Empty for an
  /// unknown id; unmodifiable; valid in both modes, fresh at every call.
  Set<String> selectableMembers(String groupId) => Set.unmodifiable({
        for (final u in _groupLookup.selectableMembers(groupId.trim()))
          u.label!,
      });

  /// The groups resolved against the active document's units (Tasks
  /// 14-16).
  @internal
  UnitGroupLookup get groupLookup => _groupLookup;

  /// The status [unit] shows (Tasks 15-16): its group's over its own.
  @internal
  UnitStatus? statusOf(UnitInfo unit) => statusOfUnit(unit.text,
      statuses: _statuses.value,
      groupStatuses: _groupStatuses.value,
      groupByLabel: _groupLookup.byLabel);

  UnitGroupLookup? _lookup;
  UnitIndex? _lookupUnits;
  Map<String, UnitGroup>? _lookupGroups;

  /// The groups resolved against the active units, made again when the
  /// unit index (a state, layer or lock change) or the groups move.
  UnitGroupLookup get _groupLookup {
    final units = _activeUnits.current;
    final groups = _groups.value;
    if (_lookup == null ||
        !identical(_lookupUnits, units) ||
        !identical(_lookupGroups, groups)) {
      _lookup = UnitGroupLookup(groups, groupUnitsOf(units));
      _lookupUnits = units;
      _lookupGroups = groups;
    }
    return _lookup!;
  }

  /// [labels], each label of a group replaced by all its members: in
  /// service only, where groups act. (Task 9's seam, given its body here.)
  Set<String> _expandLabels(Set<String> labels) {
    final groups = _groups.value;
    if (_service == null || groups.isEmpty) return labels;
    final lookup = _groupLookup;
    return {
      for (final l in labels)
        ...switch (lookup.groupOf(l)) {
          null => [l],
          final id => groups[id]!.members,
        }
    };
  }

  /// [selectedGroup] and [mergeCandidate] over the active document.
  void _refreshSelectedGroup() {
    final service = _service != null;
    String? id;
    if (service && _groups.value.isNotEmpty) {
      final keys = activeSelection.keys;
      final unlabelled = _activeUnits.current.units.any((u) =>
          u.text == null && keys.contains(SelectionKey.root(u.instance)));
      id = _groupLookup.splitGroup(_selectedUnits.value,
          unlabelledSelected: unlabelled);
    }
    _selectedGroup.value = id;
    final selected = _selectedUnits.value;
    final candidate =
        service && mergeQualifies(selected, _groups.value) ? selected : null;
    final last = _mergeCandidate.value;
    if (candidate == null ? last != null : !setEquals(candidate, last)) {
      _mergeCandidate.value = candidate;
    }
  }

  /// Frames the units of the active plan carrying one of [labels] (today's
  /// `fitToTables`, :2068-2093): labels trimmed, blanks dropped; a label
  /// two units share frames both; a unit on a hidden layer is not framed,
  /// a locked one is; an unlabelled unit never matches. The world framed is
  /// the bound of each unit's box at its place, grown by [kUnitFitMarginMm]
  /// per side and to at least [kUnitFitMinSpanMm] per axis. Returns whether
  /// one such unit exists now; when none does, nothing changes. Not
  /// document state.
  bool fitToUnits(Set<String> labels) {
    final wanted = Set<String>.unmodifiable({
      for (final l in labels)
        if (l.trim() case final t when t.isNotEmpty) t,
    });
    if (_unitsBounds(wanted) == null) return false;
    _fitTarget = _Units(wanted);
    _request();
    return true;
  }

  Aabb2? _unitsBounds(Set<String> labels) {
    final d = _activeDocument;
    var box = Aabb2.empty();
    for (final c in UnitPicker.candidatesOf(d, _activeUnits.current,
        boxes: <Handle, Aabb2>{}, leaves: d.leavesByOwner)) {
      if (labels.contains(c.unit.text)) box = box.union(c.worldBounds);
    }
    return box.isEmpty ? null : box;
  }

  /// Stores the host's [data] on the unit labelled [label] (today's
  /// `setTableData`, :1593): one design edit, labelled "Unit data",
  /// undoable, saved with the plan, read back as [PlanUnitDetail.data]. An
  /// empty map removes the data. True when the unit's data is now [data];
  /// false, changing nothing, when the trimmed [label] names no unit or
  /// several, or a unit under a locked object (spec S3). A unit on a hidden
  /// or locked layer takes data. Not gated by [permissions] (a host call).
  /// A [StateError] in service; an [ArgumentError] outside the limits.
  bool setUnitData(String label, Map<String, String> data) =>
      setUnitsData({label: data});

  /// [setUnitData] for several units, all or nothing, one undo step.
  bool setUnitsData(Map<String, Map<String, String>> byLabel) {
    _requireDesign('setUnitData');
    final wanted = <String, UnitData?>{};
    for (final MapEntry(key: label, value: data) in byLabel.entries) {
      if (unitDataProblem(data) case final problem?) {
        throw ArgumentError.value(data, 'data', problem);
      }
      wanted[label] = data.isEmpty ? null : UnitData(data);
    }
    return _setUnitComponents<UnitData>(wanted, 'Unit data');
  }

  /// Gives the unit labelled [label] the swatch [colour] (null removes it),
  /// one "Unit colour" step (today's `setTableColor`, :1631), under
  /// [setUnitData]'s rules.
  bool setUnitColour(String label, PlanSwatch? colour) =>
      setUnitsColour({label: colour});

  /// [setUnitColour] for several units, all or nothing, one undo step.
  bool setUnitsColour(Map<String, PlanSwatch?> byLabel) {
    _requireDesign('setUnitColour');
    return _setUnitComponents<UnitColour>({
      for (final MapEntry(key: l, value: c) in byLabel.entries)
        l: c == null ? null : UnitColour(c),
    }, 'Unit colour');
  }

  /// The one path of the data and colour writes (today's
  /// `_setTableComponents`, :1650-1673).
  bool _setUnitComponents<T extends Component>(
      Map<String, T?> wanted, String label) {
    settlePendingInput();
    final index = _session.units.current;
    final doc = document;
    final labels = <String>{};
    final edits = <DraftCommand>[];
    for (final MapEntry(key: raw, value: next) in wanted.entries) {
      if (!labels.add(raw.trim())) return false;
      final found = index.withLabel(raw);
      if (found.length != 1) return false;
      final instance = found.single.instance;
      if (_session.locks.covers(doc, instance)) return false;
      if (doc.components.get<T>(instance) == next) continue;
      edits.add(SetComponentCommand<T>(instance, next));
    }
    return _runHostEdit(edits, label);
  }

  /// Executes [edits] as one step labelled [label], the engine's
  /// permissions lifted (a host call is not gated, 2a P2); true with
  /// nothing to do.
  bool _runHostEdit(List<DraftCommand> edits, String label) {
    if (edits.isEmpty) return true;
    var applied = false;
    final commands = document.commands;
    _unrestricted(commands,
        () => applied = execute(CompoundCommand(edits, label: label)));
    _refreshFlags();
    return applied;
  }

  /// Makes [next] the label of the placed unit labelled [label] (spec S3):
  /// one "Label" step. An [ArgumentError] when [next] breaks the text rule
  /// (one to eight UTF-16 units, no control character, trimmed); false,
  /// changing nothing, when [label] names no unit or several, a generated
  /// unit (its type gives its label), a unit under a locked object, or when
  /// another unit already holds [next]. A [StateError] in service.
  bool setUnitLabel(String label, String next) => setUnitsLabel({label: next});

  /// [setUnitLabel] for several units, all or nothing, one step: a [next]
  /// is free when no unit outside the call holds it and no other entry
  /// names it, so two units may swap their labels.
  bool setUnitsLabel(Map<String, String> byLabel) {
    _requireDesign('setUnitLabel');
    for (final next in byLabel.values) {
      if (unitLabelProblem(next) case final problem?) {
        throw ArgumentError.value(next, 'next', 'not a label: $problem');
      }
    }
    settlePendingInput();
    final index = _session.units.current;
    final doc = document;
    final keys = <String>{};
    final renamed = <Handle, String>{};
    for (final MapEntry(key: raw, value: next) in byLabel.entries) {
      if (!keys.add(raw.trim())) return false;
      final found = index.withLabel(raw);
      if (found.length != 1) return false;
      final u = found.single;
      if (u.generated || _session.locks.covers(doc, u.instance)) return false;
      renamed[u.instance] = next.trim();
    }
    final taken = <String>{};
    for (final MapEntry(key: h, value: next) in renamed.entries) {
      if (!taken.add(next)) return false;
      for (final other in index.withLabel(next)) {
        if (other.instance != h && !renamed.containsKey(other.instance)) {
          return false;
        }
      }
    }
    return _runHostEdit([
      for (final MapEntry(key: h, value: next) in renamed.entries)
        if (unitLabelCommand(doc, index[h]!, next) case final command?) command,
    ], 'Label');
  }

  // ---- unitChanges (today's designChanges, :1680-1776) ----

  late final StreamController<PlanUnitChange> _unitOut =
      StreamController<PlanUnitChange>.broadcast(
          onListen: _watchUnits, onCancel: _unwatchUnits);
  late final Stream<PlanUnitChange> _unitStream =
      _unitOut.stream.where((_) => !_disposed);
  _UnitBaseline? _unitBaseline;
  int _unitScans = 0;

  /// How many times the design's units were read for [unitChanges].
  @visibleForTesting
  int get debugUnitScans => _unitScans;

  /// The design's unit changes (spec S3), a broadcast stream: after every
  /// design edit, undo or redo, the units added, removed and changed since
  /// the last report, ascending by instance; matched by instance, so a
  /// relabel is one [PlanUnitChanged] and a row edit one change per seat it
  /// changed, an add or a remove per seat it grew or shrank. [load] and
  /// [newPlan] report what is still owed, then [PlanUnitsReplaced] alone.
  /// Nothing done in service is reported. Delivered asynchronously; nothing
  /// is sent on listen; nothing is read while no one listens; closed by
  /// [dispose].
  Stream<PlanUnitChange> get unitChanges => _unitStream;

  void _watchUnits() {
    if (_disposed) return;
    _unitBaseline = _unitsNow();
  }

  void _unwatchUnits() => _unitBaseline = null;

  /// The design's units now: the cached [unitDetails] while the design is
  /// active, else read from the design's own index.
  _UnitBaseline _unitsNow() {
    _unitScans++;
    final cache = _session.units;
    final index = cache.current;
    if (identical(cache, _activeUnits)) {
      return _UnitBaseline(index, unitDetailInstances, unitDetails);
    }
    final found = <Handle>[];
    final details = _detailsOf(_session.document, index, found);
    return _UnitBaseline(index, List.unmodifiable(found), details);
  }

  /// Reports what changed in the design since the baseline, and moves it.
  void _reportUnits() {
    final before = _unitBaseline;
    if (before == null || _disposed || before.isAt(_session.units.current)) {
      return;
    }
    final after = _unitBaseline = _unitsNow();
    for (final change in diffUnitDetails(
        before.instances, before.details, after.instances, after.details)) {
      _unitOut.add(change);
    }
  }

  /// The design's selection changed: the selected labels follow it while
  /// the design is active (in service they are the copy's).
  void _onDesignSelection() {
    if (_inDesign) _refreshSelected();
  }

  /// A design change (its `commands.changes`): the flags, the revision
  /// while the design is active, the selected labels, the unit changes.
  void _onDesignChange() {
    _refreshFlags();
    if (_inDesign) _revision.value++;
    _refreshSelected();
    _reportUnits();
  }

  // ---------------------------------------------------------------------
  // Opening and replacing documents.

  void _open(DraftDocument document, FlutterTextMeasurer measurer,
      List<Diagnostic> loadDiagnostics) {
    _pendingDefinitions.clear();
    _damaged.value = false;
    _disabledTools.clear();
    // The engine's permissions follow the profile, before any system is
    // installed over the document (spec P2); read-only while a service
    // copy exists (a load in service, spec 2b S3).
    document.commands.permissions = _designDraft;
    for (final t in genericTools) {
      _toolNeeds[t.id] = t.needs;
    }
    for (final kit in kits.kits) {
      for (final planTool in kit.tools) {
        _toolNeeds[planTool.id] = planTool.needs;
      }
    }
    final session = DocumentSession(
        document: document,
        measurer: measurer,
        catalog: catalog,
        camera: camera,
        snap: _snap,
        kitLoaded: (kitId) => kits.kitOf(kitId) != null,
        locked: _locked,
        log: _diagnostics,
        permissions: () => _permissions,
        fill: _fill,
        guard: _guardTool,
        moveResolver: _moveResolver);
    _session = session;
    // The attachment providers, once per document, before the kits' tools
    // (the kits' services read this session's registry), then plan.symbol
    // over the registry (Task 14).
    session.runAttachmentFactories(kits, _services, _diagnostics.add);
    session.addSymbolTool(PlanSymbolTool(_armed,
        attachments: session.attachments,
        canRotate: () => _permissions.rotate,
        canMirror: () => _permissions.mirror,
        units: () => session.units.current));
    registerToolNeeds(PlanToolIds.symbol, PlanToolIds.symbolNeeds);
    _locked.value = session.locks.objects;
    session.boundary = FailureBoundary(
        document: document,
        catalog: catalog,
        system: session.parametric,
        frozen: session.frozen,
        log: _diagnostics,
        lock: lockBroken,
        damage: _damage);
    session.lockExpander
      ..onHookFailure = session.boundary.recover
      ..onPartialMutation = session.boundary.partialMutation
      ..onRefusedEdit = session.boundary.recoverRefused
      ..onRetryFailed = session.boundary.retryFailed;
    session.runKitFactories(kits, _services, _disabledTools);
    session.tools.addListener(_onTools);
    session.history = document.commands.changes.listen((_) {
      if (!_disposed) _onDesignChange();
    });
    session.selection.addListener(_onDesignSelection);
    _loadDiagnostics = List.unmodifiable(loadDiagnostics);
    _readManifest();
    _tracker.attach(document);
    // The load's checks (spec P4), once the views, the kit products and the
    // manifest's diagnostics are in place: E4's unreadable components, then
    // one dry run of the plan.
    session.boundary.reportUnreadable(_loadDiagnostics);
    session.boundary.probeLoaded();
    _reportUnofferedKinds();
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
    old.tools.activate(old.toolById(planSelectToolId)!);
    old.tools.removeListener(_onTools);
    _tracker.detach();
    _reportUnits();
    old.selection.removeListener(_onDesignSelection);
    old.disposeKitProducts();
    old.detach();
    _open(document, measurer, loadDiagnostics);
    // In service the copy is rebuilt from the new design, the mode kept
    // (today's `_replaceDesign`).
    final service = _service;
    if (service != null) {
      final copy = _buildService();
      _attachService(copy);
      _service = copy;
      _groupsAtEnter = _groups.value;
      _dropService(service);
    }
    _tracker.replaced();
    if (_unitBaseline != null) {
      _unitOut.add(const PlanUnitsReplaced());
      _unitBaseline = _unitsNow();
    }
    _atPicker = null;
    _refreshSelected();
    _revision.value++;
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

  // ---------------------------------------------------------------------
  // The mode (spec 2b S3 "Mode and copy").

  final ValueNotifier<PlanMode> _mode = ValueNotifier(PlanMode.design);

  /// The service copy while the mode is service; null in design.
  ServiceSession? _service;

  /// Copies let go of whose disposal waits for the next frame (R-2).
  final List<ServiceSession> _droppedServices = [];

  /// The mode. Changed by [setMode].
  ValueListenable<PlanMode> get mode => _mode;

  /// The document the mode shows: the design, or the service copy.
  DraftDocument get activeDocument => _service?.document ?? _session.document;

  /// The active document's selection: the design's, or the copy's.
  SelectionController get activeSelection =>
      _service?.selection ?? _session.selection;

  /// The service copy and its systems; null in design.
  @internal
  ServiceSession? get serviceSession => _service;

  /// Switches the mode (spec S3). Into service: a copy of the design, the
  /// design's tool back to plan.select. Out of it: the copy is discarded
  /// with every service edit. The selected labels are selected again in
  /// the new mode, by its rules. Moves [revision] and notifies.
  void setMode(PlanMode next) {
    if (next == _mode.value) return;
    settlePendingInput();
    // The settle may have relabelled a selected unit: read it now.
    _refreshSelected();
    final labels = _selectedUnits.value;
    if (next == PlanMode.service) {
      final design = _session;
      // `_onTools` moves `activeTool` back to plan.select.
      design.tools.activate(design.toolById(planSelectToolId)!);
      final copy = _buildService();
      _attachService(copy);
      _service = copy;
      _groupsAtEnter = _groups.value;
      // The design is not edited in service (S3): its own tools, a mounted
      // PlanCanvas's included, write through its dispatcher.
      design.document.commands.permissions = _designDraft;
    } else {
      final old = _service!;
      _service = null;
      _dropService(old);
      document.commands.permissions = _designDraft;
    }
    _reframe(_mode.value, next);
    // The new mode's canvas, where an editor last showed it.
    final shownIn = _canvasIn[next];
    if (_canvasRect.value != null && shownIn != null) {
      _canvasRect.value = shownIn;
    }
    _mode.value = next;
    _select(labels);
    _refreshFlags();
    _revision.value++;
    notifyListeners();
  }

  /// The design document's engine permissions: [DraftPermissions.readOnly]
  /// exactly while a service copy exists (S3: the design is not edited in
  /// service, whatever widget its tools run in), else the profile's
  /// [PlanPermissions.draft].
  DraftPermissions get _designDraft =>
      _service != null ? DraftPermissions.readOnly : _permissions.draft;

  /// A copy of the design, its systems installed, nothing listening yet.
  ServiceSession _buildService() {
    final design = _session;
    final measurer = FlutterTextMeasurer();
    final DraftDocument copy;
    try {
      copy = serviceCopyOf(design.document,
          register: _registerComponents, measurer: measurer);
    } catch (_) {
      measurer.clear();
      rethrow;
    }
    try {
      return ServiceSession(
          document: copy,
          measurer: measurer,
          catalog: catalog,
          camera: camera,
          locks: design.locks,
          frozen: design.frozen,
          locked: _locked,
          log: _diagnostics,
          lock: _lockFromCopy,
          damage: _damageCopy,
          groups: unitGroups,
          moves: () => permissions.serviceMove);
    } catch (_) {
      // The decoded copy is let go as the decode failure's measurer is.
      unawaited(copy.dispose());
      measurer.clear();
      rethrow;
    }
  }

  /// The controller listens to [s]: its changes and its selection.
  void _attachService(ServiceSession s) {
    s.history = s.document.commands.changes.listen((_) {
      if (_disposed || !identical(s, _service)) return;
      _onServiceChanged();
    });
    void onSelection() {
      if (!_disposed && identical(s, _service)) _refreshSelected();
    }

    s.onSelection = onSelection;
    s.selection.addListener(onSelection);
    _announced = s.document.commands.stateId;
  }

  /// The active copy changed (a move, an undo or a redo of one).
  void _onServiceChanged() {
    _refreshFlags();
    _revision.value++;
    _refreshSelected();
    _announceService();
  }

  /// Lets [s] go (R-2): its listeners now, the session after the frame
  /// that unmounts its view.
  void _dropService(ServiceSession s) {
    s.detach();
    _droppedServices.add(s);
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        if (_droppedServices.remove(s)) s.dispose();
      })
      ..ensureVisualUpdate();
  }

  /// The copy's boundary froze [objects] (spec S3): they join the design's
  /// lock set (refreshed over the design, whose handles the copy shares),
  /// the copy's history is cleared so no earlier service step is undone
  /// onto them, and the listeners are told. The design's history is never
  /// touched (Risks, B3). As [lockBroken], it moves neither [revision] nor
  /// [unitChanges] by itself.
  void _lockFromCopy(ServiceSession s, Set<Handle> objects) =>
      _lock(objects, s.document.commands);

  /// E3 in the copy: a rollback threw there. The copy is rebuilt from
  /// what it holds (its history cleared); the design is not touched.
  void _damageCopy(ServiceSession s, PartialMutationError error) {
    s.document.commands.notifyLoaded();
    _refreshFlags();
    notifyListeners();
  }

  /// [dirty] reads the design; the history flags the active document.
  void _refreshFlags() {
    _dirty.value = document.commands.stateId != _savedState;
    final active = activeDocument.commands;
    _canUndo.value = active.canUndo;
    _canRedo.value = active.canRedo;
  }

  // ---------------------------------------------------------------------
  // Undo and redo.

  ValueListenable<bool> get canUndo => _canUndo;
  ValueListenable<bool> get canRedo => _canRedo;

  bool get _midShape => _session.tools.active.isMidShape;

  /// Undoes the active document's last step (the copy's in service, spec
  /// 2b S3), after settling pending input; in design, nothing while the
  /// active tool is part-way through a shape (today's S-4). A replay that
  /// leaves the plan partially mutated (E3) does not escape: the document
  /// is rebuilt from what it holds (the design marked [damaged]), as in
  /// [execute].
  void undo() {
    if (_service == null && _midShape) return;
    settlePendingInput();
    final commands = activeDocument.commands;
    if (!commands.canUndo) return;
    try {
      _unrestricted(commands, commands.undo);
    } on PartialMutationError catch (error) {
      (_service?.boundary ?? _session.boundary).partialMutation(error);
    }
    _announceService();
  }

  /// Runs [step] with [commands]' engine permissions lifted, then puts
  /// them back: a host's undo or redo is not gated (spec P2), and the
  /// dispatcher checks permissions on undo and redo too (undo.dart:213).
  void _unrestricted(CommandDispatcher commands, void Function() step) {
    final saved = commands.permissions;
    commands.permissions = DraftPermissions.all;
    try {
      step();
    } finally {
      commands.permissions = saved;
    }
  }

  /// Redoes the active document's next step, as [undo].
  void redo() {
    if (_service == null && _midShape) return;
    settlePendingInput();
    final commands = activeDocument.commands;
    if (!commands.canRedo) return;
    try {
      _unrestricted(commands, commands.redo);
    } on PartialMutationError catch (error) {
      (_service?.boundary ?? _session.boundary).partialMutation(error);
    }
    _announceService();
  }

  // ---------------------------------------------------------------------
  // The service record (spec 2b S3, decision 4).

  final _Requests _serviceChanges = _Requests();

  /// The active copy's history state last announced on [serviceChanges]:
  /// an undo is announced at once and again by the change stream, which is
  /// heard once.
  int? _announced;

  /// The groups held when service was entered (or the copy rebuilt by a
  /// load or a new plan; none after a reset): what [serviceEdited]
  /// compares the groups with.
  Map<String, UnitGroup> _groupsAtEnter = const {};

  /// Whether service has something to record: the copy has a placed unit
  /// away from its design place, or the groups differ from those held when
  /// service was entered. Not the undo depth. Surveys the copy at each
  /// read: read it on a change, not per frame. False in design.
  bool get serviceEdited {
    final s = _service;
    if (s == null) return false;
    return serviceMovesOf(document, s.document, s.units.current).isNotEmpty ||
        !mapEquals(_groups.value, _groupsAtEnter);
  }

  /// Fires after a move, an undo or a redo of the copy (for [undo] and
  /// [redo], before they return), [resetService], [restoreService], and
  /// [setUnitGroups] in service. Never on [setMode], [load] or [newPlan],
  /// so a host that saves [serviceJson] on it never overwrites its record
  /// with the empty one a new copy starts with.
  Listenable get serviceChanges => _serviceChanges;

  /// The service record as JSON (spec S3): the placed units moved away
  /// from the design, ascending by handle, and the groups. Null in design.
  String? serviceJson() {
    settlePendingInput();
    final s = _service;
    if (s == null) return null;
    return encodeServiceRecord(
        serviceMovesOf(document, s.document, s.units.current), _groups.value);
  }

  /// Puts a stored record back (spec S3): service only (a [StateError] in
  /// design). A [json] that is not a version-1 `jet_cad.service` record
  /// throws a [FormatException] and changes nothing. Otherwise the copy is
  /// rebuilt from the design, every move of the strict match applied and
  /// the copy's history cleared (Undo does not remove them), and the
  /// groups **replaced** by the record's that apply, each whole or not at
  /// all. The focus is kept; the selection is selected again by label;
  /// [revision] moves; [serviceChanges] fires.
  ServiceRestore restoreService(String json) {
    final old = _service;
    if (old == null) {
      throw StateError('restoreService needs the service mode (spec 2b S3)');
    }
    final record = decodeServiceRecord(json);
    settlePendingInput();
    _refreshSelected();
    final labels = _selectedUnits.value;
    final designUnits = _session.units.current;
    final moves = matchServiceMoves(document, designUnits, record.moves);
    final groups = matchServiceGroups(record.groups, designUnits);
    final next = _buildService();
    if (moves.applied.isNotEmpty) {
      final commands = next.document.commands;
      try {
        commands.execute(CompoundCommand([
          for (final m in moves.applied) TransformNodeCommand(m.handle, m.to)
        ], label: 'Restore'));
      } catch (_) {
        next.dispose();
        rethrow;
      }
      // The restore is the copy's floor, no step (today's C16).
      commands.clearHistory();
    }
    _attachService(next);
    _service = next;
    _dropService(old);
    _groups.value = groups.applied;
    _select(labels);
    _refreshFlags();
    _revision.value++;
    _serviceChanges.bump();
    notifyListeners();
    return ServiceRestore(
        appliedMoves: [for (final m in moves.applied) m.label],
        droppedMoves: [for (final m in moves.dropped) m.label],
        appliedGroups: groups.appliedIds,
        droppedGroups: groups.droppedIds);
  }

  /// Service only: the copy rebuilt from the design, every service move
  /// gone, and the groups cleared (today's `resetLayout` kept them: spec
  /// S5). The selection is kept by label. A silent no-op in design.
  void resetService() {
    final old = _service;
    if (old == null) return;
    settlePendingInput();
    _refreshSelected();
    final labels = _selectedUnits.value;
    final next = _buildService();
    _attachService(next);
    _service = next;
    _dropService(old);
    _groups.value = const <String, UnitGroup>{};
    _groupsAtEnter = const <String, UnitGroup>{};
    _select(labels);
    _refreshFlags();
    _revision.value++;
    _serviceChanges.bump();
    notifyListeners();
  }

  /// Fires [serviceChanges] if the active copy's history moved since it
  /// last did. The change stream is asynchronous: without this, a host
  /// that calls [undo] and then [setMode] in one synchronous step would
  /// never hear the undo (review 14d-2).
  void _announceService() {
    final s = _service;
    if (s == null) return;
    final state = s.document.commands.stateId;
    if (state == _announced) return;
    _announced = state;
    _serviceChanges.bump();
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
  /// permissions' ids refuse, and a tool whose needs the document's engine
  /// permissions deny (a drawing tool while geometry is denied,
  /// planner_shell.dart:926-933). A drawing tool clears the selection.
  bool selectTool(String id) {
    final session = _session;
    final tool = session.toolById(id);
    if (tool == null || !_allowsTool(id)) return false;
    if (id != planSelectToolId) session.selection.clear();
    session.tools.activate(tool);
    return true;
  }

  /// Whether [id] may be armed: offered by the permissions' ids, a tool
  /// this controller knows, and every capability its commits need allowed
  /// by the document's engine permissions (spec P2).
  bool _allowsTool(String id) {
    // plan.symbol is refused with nothing armed (planner_shell.dart:945).
    if (id == PlanToolIds.symbol && _armed.value == null) return false;
    if (!_permissions.allowsTool(id)) return false;
    final needs = _toolNeeds[id];
    if (needs == null) return false;
    final engine = document.commands.permissions;
    for (final c in needs) {
      if (!engine.allows(c)) return false;
    }
    return true;
  }

  /// [id]'s needs, or null for an id this controller does not know.
  @internal
  Set<Capability>? needsOf(String id) => _toolNeeds[id];

  /// plan.symbol's needs (Task 14), which is built outside the generic set.
  @internal
  void registerToolNeeds(String id, Set<Capability> needs) =>
      _toolNeeds[id] = needs;

  /// The editor's permissions. Settable at runtime: the widgets rebuild
  /// (this notifies), the document's engine permissions follow
  /// ([PlanPermissions.draft]; in service the design stays read-only and
  /// takes them on leaving), a drag whose gate closes is cancelled now,
  /// and an active tool no longer allowed is cancelled and plan.select
  /// armed.
  PlanPermissions get permissions => _permissions;
  set permissions(PlanPermissions value) {
    if (value == _permissions) return;
    final old = _permissions;
    _permissions = value;
    document.commands.permissions = _designDraft;
    final select = _session.select;
    final stale = old.selectUnitsOnly != value.selectUnitsOnly ||
        switch (select.dragKind) {
          DragKind.move => old.move && !value.move,
          DragKind.rotate => old.rotate && !value.rotate,
          DragKind.reshape => old.reshape && !value.reshape,
          DragKind.band || null => false,
        };
    if (stale) select.cancel(toolController.context);
    // Today's S-9 g (planner_shell.dart:1085-1095): a change to units only
    // keeps the placed units of the selection.
    if (value.selectUnitsOnly && !old.selectUnitsOnly) {
      final index = _session.units.current;
      final drop = [
        for (final k in selection.keys)
          if (!isPlacedUnitKey(index, k)) k
      ];
      if (drop.isNotEmpty) selection.remove(drop);
    }
    grips.gatesChanged();
    if (!_allowsTool(activeTool.value)) {
      selectTool(PlanToolIds.select);
    } else if (activeTool.value == PlanToolIds.symbol &&
        (old.rotate != value.rotate || old.mirror != value.mirror)) {
      // The ghost never shows a turn or a mirror a click would not place
      // (planner_shell.dart:1100-1104).
      _session.symbolTool.gatesChanged();
    }
    notifyListeners();
  }

  @internal
  PlanSelectGates get selectGates => _session.gates;

  @internal
  SelectTool get planSelect => _session.select;

  /// The Fill toggle (Task 16's palette row and F key).
  @internal
  ValueNotifier<bool> get fill => _fill;

  /// Deletes the selection as the select tool's Delete does, one undo step
  /// (spec P2), after settling pending input: through the select tool's
  /// gates (the permissions' `delete`, the locks). False with nothing
  /// selected, while a shape is part-way, under `delete: false`, with a
  /// locked object selected, and when every selected object is refused. A
  /// delete a lock refuses on commit (a locked object inside a selected
  /// group, Task 11) answers false and sets [lockHint], as [execute] does.
  /// False in service (spec 2b S3): the design is not edited there.
  bool deleteSelection() {
    if (_service != null || _midShape) return false;
    settlePendingInput();
    final session = _session;
    try {
      return session.select.deleteSelection(session.toolContext);
    } on PlanLocked {
      lockHint.value = true;
      return false;
    } on DanglingReferenceError {
      return false;
    } on KitHookFailure catch (failure) {
      _reportFailure(failure);
      return false;
    }
  }

  @internal
  ToolController get toolController => _session.tools;

  /// The current document's TEXT tool, unwrapped: the canvas's inline
  /// field (TextEntryOverlay) drives its pending placement.
  @internal
  TextTool get textTool => _session.generic.byId[PlanToolIds.text]! as TextTool;
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

  /// The tool [id] of the current document, or null: the tool its factory
  /// made, without the guard the tool controller holds it in.
  @internal
  Tool? toolFor(String id) {
    final tool = _session.toolById(id);
    return tool is GuardedTool ? tool.inner : tool;
  }

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
    // The controller's own settling, not an edit: not gated (spec P2).
    // The design's, even in service: it settles the design's separator.
    _unrestricted(
        d.commands,
        () => d.commands.execute(SetComponentCommand<PageComponent>(
            d.rootHandle, page.copyWith(decimalSeparator: separator))));
    d.commands.clearHistory();
    _savedState = d.commands.stateId;
  }

  // ---------------------------------------------------------------------
  // State.

  ValueListenable<List<KitDiagnostic>> get diagnostics => _diagnostics;

  /// The symbol libraries' state (spec P2): loading until every source has
  /// settled; failed when every source failed; else ready.
  ValueListenable<SymbolsState> get symbolsState => _symbolsState;

  /// The loaded symbols in load order, retired ones included (a placed
  /// retired symbol still resolves; the gallery hides them).
  List<PlanSymbol> get symbols => _symbols;

  PlanSymbol? symbolById(String id) => _symbolsById[id];

  /// The symbol plan.symbol places.
  ValueListenable<PlanSymbol?> get armedSymbol => _armed;

  /// Arms [symbol] and activates plan.symbol (a gallery cell, or the
  /// host). Answers whether plan.symbol is now active; the symbol stays
  /// armed either way (today's _armSymbol, planner_shell.dart:940-943).
  bool armSymbol(PlanSymbol symbol) {
    _armed.value = symbol;
    return selectTool(PlanToolIds.symbol);
  }

  /// Loads the libraries again after a failure; nothing in another state.
  Future<void> retrySymbols() async {
    if (_symbolsState.value != SymbolsState.failed) return;
    await _loadSymbols();
  }

  /// The codes a symbol load reports, one load's set at a time.
  static const Set<KitDiagnosticCode> _libraryCodes = {
    KitDiagnosticCode.libraryUnreadable,
    KitDiagnosticCode.libraryKitMismatch,
    KitDiagnosticCode.symbolDuplicate,
  };

  Future<void> _loadSymbols() async {
    final run = ++_symbolRun;
    // A kit set without a symbol library is ready at once, empty (Task
    // 8's C1 reads `ready` right after construction).
    if (kits.kits.every((kit) => kit.symbols.isEmpty)) {
      _symbolsState.value = SymbolsState.ready;
      return;
    }
    _symbolsState.value = SymbolsState.loading;
    PlanSymbolLoad? load;
    Object? error;
    try {
      load = await _symbolLoader.load(kits);
    } catch (e) {
      error = e; // a loader the host disposed
    }
    if (_disposed || run != _symbolRun) return;
    if (load == null) {
      _symbolsState.value = SymbolsState.failed;
      debugPrint('The symbol libraries could not be loaded: $error');
      return;
    }
    _symbols = _named(load.symbols);
    _symbolsById = {for (final s in _symbols) s.id: s};
    // This load's library problems replace the last one's: a source that
    // read on a retry has none left (Task 13 ruling, final review I3).
    _diagnostics.removeWhere((d) => _libraryCodes.contains(d.code));
    for (final d in load.diagnostics) {
      _diagnostics.add(d);
    }
    _reportUnofferedKinds();
    _symbolsState.value = load.state;
  }

  /// [symbols] named with the host's words first (spec 2b S4): each wrapped
  /// again with its kit's merged words; as loaded when the host gave none
  /// (a loader may serve several controllers).
  List<PlanSymbol> _named(List<PlanSymbol> symbols) => _hostWords.words.isEmpty
      ? symbols
      : List.unmodifiable([
          for (final s in symbols)
            PlanSymbol(
                kitId: s.kitId,
                names: _names[s.kitId] ?? s.names,
                entry: s.entry),
        ]);

  /// One attachmentKindUnoffered per kit and kind (the log keeps one per
  /// kit, subject and code) for each loaded symbol's attachTo kind that no
  /// provider of the current document offers.
  void _reportUnofferedKinds() {
    final offered = _session.attachments.kinds;
    for (final s in _symbols) {
      for (final kind in s.component.attachTo) {
        if (offered.contains(kind)) continue;
        _diagnostics.add(KitDiagnostic(
            kitId: s.kitId,
            subject: kind,
            code: KitDiagnosticCode.attachmentKindUnoffered,
            message: '${s.id} attaches to "$kind", which no loaded kit '
                'offers'));
      }
    }
  }

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

  /// The last rect a canvas reported in each mode, for [setMode].
  final Map<PlanMode, Rect> _canvasIn = {};

  // R-13 as amended (the human, 2026-10-07): a mode switch keeps the plan
  // where it is on the screen. The camera's numbers are in the shown
  // canvas's coordinates and the two modes' canvases start at different
  // places in the editor, so [setMode] reframes the camera by the
  // difference of their origins -- here, not in a widget, so a switch made
  // while no editor is shown keeps the place too.
  final Map<PlanMode, Offset> _canvasAt = Map.of(planCanvasSeeds);

  /// The origins a reframing used and no measurement has confirmed yet.
  final Map<PlanMode, Offset> _assumed = {};

  /// Where each mode's chrome alone put its canvas when its origin was
  /// seeded or measured: the basis [canvasAssumed] moves it from.
  final Map<PlanMode, Offset> _chromeAt = Map.of(_defaultChromeOrigins);

  /// An editor lays out [mode]'s chrome so that its canvas starts at
  /// [chrome]. For a mode not shown, the origin a switch into it reframes
  /// by moves by what the chrome moved, and so do a reframing's assumption
  /// and the rect [canvasRect] takes at the switch: the first frame after
  /// the switch is exact. The shown mode waits for its measurement.
  @internal
  void canvasAssumed(PlanMode mode, Offset chrome) {
    if (mode == this.mode.value) return;
    final delta = chrome - _chromeAt[mode]!;
    _chromeAt[mode] = chrome;
    if (delta == Offset.zero) return;
    _canvasAt[mode] = _canvasAt[mode]! + delta;
    final assumed = _assumed[mode];
    if (assumed != null) _assumed[mode] = assumed + delta;
    final rect = _canvasIn[mode];
    if (rect != null) {
      _canvasIn[mode] = Rect.fromLTRB(
          rect.left + delta.dx, rect.top + delta.dy, rect.right, rect.bottom);
    }
  }

  void _reframe(PlanMode from, PlanMode to) {
    final a = _canvasAt[from]!, b = _canvasAt[to]!;
    _assumed.putIfAbsent(from, () => a);
    _assumed.putIfAbsent(to, () => b);
    if (a != b) camera.panBy(a - b);
  }

  /// An editor measured where [shown]'s canvas starts in it, after the
  /// frame that first showed a plan in that mode; a reframing that assumed
  /// another origin is corrected. [chrome] is the basis a later
  /// [canvasAssumed] moves the origin from.
  @internal
  void canvasMeasured(PlanMode shown, Offset origin, {Offset? chrome}) {
    _canvasAt[shown] = origin;
    if (chrome != null) _chromeAt[shown] = chrome;
    final assumed = _assumed.remove(shown);
    if (assumed == null || assumed == origin) return;
    camera.panBy(shown == mode.value ? assumed - origin : origin - assumed);
  }

  /// An editor's chrome in the shown mode moved its canvas from [from] to
  /// [to]: the camera pans by the difference, applied at once and heard
  /// after the frame. No camera command: a pending fit still runs.
  @internal
  void chromeMoved(Offset from, Offset to) {
    if (_disposed || from == to) return;
    (camera as _PlanCamera).panUnheard(from - to);
  }

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
      _canvasIn[mode.value] = global;
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
  _FitTarget? _fitTarget;

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
    final ViewportTransform framing;
    switch (_fitTarget) {
      case null:
        return null;
      case _Units(:final labels):
        final box = _unitsBounds(labels);
        if (box == null) return null;
        framing =
            frameUnits(box, viewport, minScale: _minScale, maxScale: _maxScale);
      case _Centre(:final world, :final scale, :final pageScale):
        framing = _centred(
            world,
            pageScale
                ? _pageFit(_activeDocument, viewport)
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
    for (final s in _droppedServices) {
      s.dispose();
    }
    _droppedServices.clear();
    final service = _service;
    _service = null;
    if (service != null) {
      service
        ..detach()
        ..dispose();
    }
    final session = _session;
    session.tools.removeListener(_onTools);
    session.selection.removeListener(_onDesignSelection);
    session
      ..disposeKitProducts()
      ..detach()
      ..dispose();
    if (_ownsThumbnails) thumbnails.dispose();
    if (_ownsSymbolLoader) _symbolLoader.dispose();
    _armed.dispose();
    toolSettings.dispose();
    _diagnostics.dispose();
    _locale.dispose();
    _symbolsState.dispose();
    _dirty.dispose();
    _canUndo.dispose();
    _canRedo.dispose();
    _activeTool.dispose();
    _fill.dispose();
    _locked.dispose();
    _mode.dispose();
    _serviceChanges.dispose();
    _statuses.dispose();
    _groups.dispose();
    _groupStatuses.dispose();
    _selectedGroup.dispose();
    _mergeCandidate.dispose();
    _focus.dispose();
    lockHint.dispose();
    _damaged.dispose();
    _canvasRect.dispose();
    _fits.dispose();
    _revision.dispose();
    _selectedUnits.dispose();
    _editorSelected.dispose();
    _unitBaseline = null;
    _snap.dispose();
    _snapping.dispose();
    _userSnap.dispose();
    camera.dispose();
    _settles.clear();
    pageFlows.dispose();
    unawaited(_out.close());
    unawaited(_unitOut.close());
    super.dispose();
  }
}
