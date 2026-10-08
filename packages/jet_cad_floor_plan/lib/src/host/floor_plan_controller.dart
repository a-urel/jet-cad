// The host's controller (spec 14b-2 H1-H4, H11-H14): the designed plan and,
// in the selection mode, a service copy of it; the mode; the selection by
// table number; undo and redo of the active plan; the save point; the
// camera across mode switches.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' show Offset, Size;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

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
import '../tables/table_index.dart';
import 'floor_plan_types.dart';
import 'service_layout.dart';
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
        unsettled: json == null,
        symbolSources: symbolSources,
        symbols: symbols,
        thumbnails: thumbnails);
  }

  FloorPlanController._(
    _Plan design, {
    required bool unsettled,
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
    if (unsettled) {
      _unsettled = (document: design.document, at: _savedState);
    }
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

  /// A [fitToView] or [fitToTables] no mounted view has performed yet
  /// (review F-2): the next view fits on its first frame.
  bool _fitPending = false;

  /// What the next fit frames (zone spec Z5): null for the page, else the
  /// numbers of the last [fitToTables] that found a table, trimmed. The
  /// last request wins.
  Set<String>? _fitTarget;
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
  @internal
  ViewportTransform? framingFor(Size viewport) {
    final target = _fitTarget;
    if (target == null) return null;
    final box = _tablesBounds(target);
    if (box == null) return null;
    final framing = frameTables(box, viewport);
    final m = framing.worldToScreenMatrix;
    return [m.a, m.b, m.c, m.d, m.e, m.f].every((v) => v.isFinite)
        ? framing
        : null;
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
    if (a != b) camera.panBy(a - b);
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
    camera.panBy(shown == _mode.value ? assumed - origin : origin - assumed);
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

  /// The active plan's live tables, ascending (H3).
  List<FloorPlanTable> get tables => [
        for (final t in _tables.tables)
          FloorPlanTable(
              number: t.number, seats: t.seats, symbolKey: t.symbolKey)
      ];

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
  /// replaces an earlier [fitToTables] not yet performed (zone spec Z5).
  void fitToView() {
    _fitTarget = null;
    _fitPending = true;
    _fits.bump();
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
    _fitTarget = wanted;
    _fitPending = true;
    _fits.bump();
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
    camera.dispose();
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
    super.dispose();
  }
}
