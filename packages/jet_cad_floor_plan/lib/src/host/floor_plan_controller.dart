// The host's controller (spec 14b-2 H1-H4, H11-H14): the designed plan and,
// in the selection mode, a service copy of it; the mode; the selection by
// table number; undo and redo of the active plan; the save point; the
// camera across mode switches.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' show Size;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../export/export_dialog.dart';
import '../export/export_font.dart';
import '../new_document.dart';
import '../parametric/catalog.dart';
import '../startup_plan.dart' show kMaxScale, kMinScale;
import '../symbols/symbol_library_loader.dart';
import '../tables/table_index.dart';
import 'floor_plan_types.dart';

/// The thumbnail capacity of a controller's own cache: the app's (spec
/// 14b-2 R-11), above the 96 symbols of both libraries.
const int kFloorPlanThumbnailCapacity = 128;

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
class FloorPlanController extends ChangeNotifier {
  /// A controller over [json], or over an empty plan. Throws a
  /// [FormatException] when [json] is not a plan, as [load] does, before
  /// it builds anything it would have to dispose (review F-5).
  factory FloorPlanController({
    List<SymbolLibrarySource> symbolSources = const [furnitureSymbolSource],
    SymbolLibraryLoader? symbols,
    SymbolThumbnails? thumbnails,
    String? json,
  }) {
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
        symbolSources: symbolSources, symbols: symbols, thumbnails: thumbnails);
  }

  FloorPlanController._(
    _Plan design, {
    required List<SymbolLibrarySource> symbolSources,
    SymbolLibraryLoader? symbols,
    SymbolThumbnails? thumbnails,
  })  : _ownsSymbols = symbols == null,
        symbols = symbols ?? SymbolLibraryLoader(sources: symbolSources),
        _ownsThumbnails = thumbnails == null,
        thumbnails = thumbnails ??
            SymbolThumbnails(maxEntries: kFloorPlanThumbnailCapacity) {
    _design = _attach(design);
    _savedState = design.document.commands.stateId;
    _placeNominally();
    _refreshFlags();
  }

  /// The shell's nominal fit (1440 x 900), so the first frame of a new
  /// plan's view is drawn near the right place before the real fit
  /// (review F-6). Set here, never during a build.
  void _placeNominally() {
    final d = _design.document;
    const size = Size(1440, 900);
    final page = d.components.isRegistered<PageComponent>()
        ? d.components.get<PageComponent>(d.rootHandle)
        : null;
    camera.value = page != null
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

  /// The one camera every view of this controller uses (R-13): a mode
  /// switch keeps its pan and zoom.
  @internal
  late final CameraController camera = CameraController(
      ViewportTransform(worldToScreenMatrix: Transform2(1, 0, 0, -1, 0, 0)),
      minScale: kMinScale,
      maxScale: kMaxScale);

  late _Plan _design;
  _Plan? _service;

  /// Plans let go of whose disposal waits for the next frame (R-2).
  final List<_Plan> _dropped = [];

  int _savedState = 0;

  /// The design's state when [designJson] last encoded it (R-8).
  int? _encodedState;

  final _Requests _fits = _Requests();
  bool _fitOnStart = true;

  /// A [fitToView] no mounted view has performed yet (review F-2): the
  /// next view fits on its first frame.
  bool _fitPending = false;
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
  /// construction, [load], [newPlan]; not after a mode switch (R-13).
  @internal
  bool takeFitOnStart() {
    final fit = _fitOnStart || _fitPending;
    _fitOnStart = false;
    return fit;
  }

  /// A view performed a fit: a pending [fitToView] is done (review F-2).
  @internal
  void fitted() => _fitPending = false;

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

  /// Whether the service copy has edits (H1): the demo asks before
  /// discarding them.
  bool get serviceEdited => (_service?.document.commands.undoDepth ?? 0) > 0;

  // ---------------------------------------------------------------------
  // The designed plan.

  /// The designed plan's encoding, whatever the mode (H1, D9). [markSaved]
  /// marks the state encoded here (R-8).
  String designJson() {
    _settle?.call();
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

  /// Replaces the designed plan with an empty one (H3), as [load] does.
  void newPlan() {
    _settle?.call();
    final measurer = FlutterTextMeasurer();
    _replaceDesign(_Plan(newDocument(measurer), measurer));
  }

  void _replaceDesign(_Plan next) {
    _drop(_design);
    if (_service case final s?) _drop(s);
    _design = _attach(next);
    _savedState = next.document.commands.stateId;
    _encodedState = null;
    if (_mode.value == FloorPlanMode.selection) {
      _service = _attach(_copyOf(_design));
    } else {
      _service = null;
    }
    _fitOnStart = true;
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
  }

  void redo() {
    _settle?.call();
    final commands = _active.document.commands;
    if (commands.canRedo) commands.redo();
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

  /// The active plan's live tables, ascending (H3).
  List<FloorPlanTable> get tables => [
        for (final t in _tables.tables)
          FloorPlanTable(
              number: t.number, seats: t.seats, symbolKey: t.symbolKey)
      ];

  /// The active plan's numbering problems, as text (umbrella D5, R-13):
  /// numbers used by several tables, and tables with no number.
  List<String> get numberingWarnings => [
        for (final d in _tables.diagnostics())
          if (d.code == TableDiagnosticCodes.duplicateNumber ||
              d.code == TableDiagnosticCodes.unnumbered)
            d.message
      ];

  /// Selects every live table carrying one of [numbers] that the selection
  /// can hold -- visible, on an unlocked layer -- replacing the selection
  /// (H3, H13). A number used twice selects both; an unknown one is
  /// ignored.
  void select(Set<String> numbers) {
    _settle?.call();
    _select(numbers);
  }

  void _select(Set<String> numbers) {
    final plan = _active;
    final layers = plan.document.tables.layers;
    final keys = <SelectionKey>[];
    for (final n in numbers) {
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
  }

  /// The active view frames the plan as on its first frame (H3, F-7).
  void fitToView() {
    _fitPending = true;
    _fits.bump();
  }

  // ---------------------------------------------------------------------
  // Bookkeeping.

  _Plan _attach(_Plan plan) {
    plan.changes = plan.document.commands.changes.listen((_) {
      if (_disposed) return;
      _refreshFlags();
      if (identical(plan, _active)) _revision.value++;
    });
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
    camera.dispose();
    _fits.dispose();
    _mode.dispose();
    _dirty.dispose();
    _canUndo.dispose();
    _canRedo.dispose();
    _selectedTables.dispose();
    _revision.dispose();
    _statuses.dispose();
    super.dispose();
  }
}
