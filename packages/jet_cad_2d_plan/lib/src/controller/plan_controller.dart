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
import '../file/plan_format_exception.dart';
import '../kits/guard.dart';
import '../kits/kit_set.dart';
import '../kits/locks.dart';
import '../l10n/document_separator.dart';
import '../l10n/strings.dart';
import '../export/page_flows.dart';
import '../export/page_printer.dart';
import '../export/registries.dart';
import '../shortcuts/tool_letters.dart';
import '../symbols/plan_symbol.dart';
import '../symbols/plan_symbol_loader.dart';
import '../tools/generic_tools.dart';
import '../tools/move_resolver.dart';
import '../tools/plan_select_gates.dart';
import '../tools/plan_symbol_tool.dart';
import '../units/unit_components.dart';
import '../units/unit_index.dart';
import 'camera_bounds.dart';
import 'new_plan.dart';
import 'permissions.dart';
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
        camera = CameraController(
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
      // `this.`: the constructor's own `document` parameter is the first
      // plan, never the current one.
      document: () => this.document,
      catalog: () => catalog,
      settle: settlePendingInput,
      load: load,
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
  Future<PlanExport?> export(String exporterId, PlanExportChoice choice,
          {String? name}) =>
      pageFlows.export(exporterId, choice, name: name ?? 'plan');

  /// The plan's page as a PDF to [printer] (the platform's print dialog
  /// when null), named [name] (`plan` when null). True once the printer
  /// is done; false under [export]'s rules for null. Not gated by
  /// [permissions].
  Future<bool> print(PlanExportChoice choice,
          {PagePrinter? printer, String? name}) =>
      pageFlows.print(choice,
          printer: printer ?? const PrintingPagePrinter(),
          name: name ?? 'plan');

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

  /// The design document's units (spec 2b S2). Task 11 re-points it at the
  /// active document.
  @internal
  UnitIndex get unitIndex => _session.units.current;

  /// Locks [objects] in the middle of a session (spec P4: a type's code
  /// failed, Task 11): adds them to the lock set, clears the undo history
  /// so no earlier edit can be undone onto them, and tells the listeners.
  @internal
  void lockBroken(Set<Handle> objects) {
    if (objects.isEmpty) return;
    _session.locks.addBroken(document, objects);
    document.commands.clearHistory();
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
  bool execute(DraftCommand command) {
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
  // Opening and replacing documents.

  void _open(DraftDocument document, FlutterTextMeasurer measurer,
      List<Diagnostic> loadDiagnostics) {
    _pendingDefinitions.clear();
    _damaged.value = false;
    _disabledTools.clear();
    // The engine's permissions follow the profile, before any system is
    // installed over the document (spec P2).
    document.commands.permissions = _permissions.draft;
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
      if (!_disposed) _refreshFlags();
    });
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
  /// active tool is part-way through a shape (today's S-4). A replay that
  /// leaves the plan partially mutated (E3) does not escape: the plan is
  /// rebuilt from what it holds and marked [damaged], as in [execute].
  void undo() {
    if (_midShape) return;
    settlePendingInput();
    final commands = document.commands;
    if (!commands.canUndo) return;
    try {
      _unrestricted(commands.undo);
    } on PartialMutationError catch (error) {
      _session.boundary.partialMutation(error);
    }
  }

  /// Runs [step] with the document's engine permissions lifted, then puts
  /// them back: a host's undo or redo is not gated (spec P2), and the
  /// dispatcher checks permissions on undo and redo too (undo.dart:213).
  void _unrestricted(void Function() step) {
    final commands = document.commands;
    final saved = commands.permissions;
    commands.permissions = DraftPermissions.all;
    try {
      step();
    } finally {
      commands.permissions = saved;
    }
  }

  /// Redoes the next step, as [undo].
  void redo() {
    if (_midShape) return;
    settlePendingInput();
    final commands = document.commands;
    if (!commands.canRedo) return;
    try {
      _unrestricted(commands.redo);
    } on PartialMutationError catch (error) {
      _session.boundary.partialMutation(error);
    }
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
  /// ([PlanPermissions.draft]), a drag whose gate closes is cancelled now,
  /// and an active tool no longer allowed is cancelled and plan.select
  /// armed.
  PlanPermissions get permissions => _permissions;
  set permissions(PlanPermissions value) {
    if (value == _permissions) return;
    final old = _permissions;
    _permissions = value;
    document.commands.permissions = value.draft;
    final select = _session.select;
    final stale = switch (select.dragKind) {
      DragKind.move => old.move && !value.move,
      DragKind.rotate => old.rotate && !value.rotate,
      DragKind.reshape => old.reshape && !value.reshape,
      DragKind.band || null => false,
    };
    if (stale) select.cancel(toolController.context);
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
  bool deleteSelection() {
    if (_midShape) return false;
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
    _unrestricted(() => d.commands.execute(SetComponentCommand<PageComponent>(
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
    lockHint.dispose();
    _damaged.dispose();
    _canvasRect.dispose();
    _fits.dispose();
    _snap.dispose();
    _snapping.dispose();
    _userSnap.dispose();
    camera.dispose();
    _settles.clear();
    pageFlows.dispose();
    unawaited(_out.close());
    super.dispose();
  }
}
