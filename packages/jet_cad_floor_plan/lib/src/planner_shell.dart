// The planner shell (spec 03, 12a D2): moved out of main.dart (plan 14b-1
// Task 1) so the application frame and the shell live apart.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'l10n/number_text.dart';
import 'l10n/strings.dart';
import 'document_toolbar.dart';
import 'layers/layer_panel.dart';
import 'new_document.dart';
import 'page_panel.dart';
import 'panel_focus.dart';
import 'parametric/box_tool.dart';
import 'parametric/catalog.dart';
import 'parametric/dimension_tool.dart';
import 'parametric/object_grips.dart';
import 'parametric/opening.dart';
import 'parametric/opening_tool.dart';
import 'parametric/room_inputs.dart';
import 'parametric/room_tool.dart';
import 'parametric/separator_tool.dart';
import 'parametric/wall_bands.dart';
import 'parametric/wall_tool.dart';
import 'planner_view.dart';
import 'selection_panel.dart';
import 'shell_commands.dart';
import 'shortcut_guard.dart';
import 'startup_plan.dart' show kMaxScale, kMinScale;
import 'symbols/symbol_library.dart';
import 'symbols/symbol_library_loader.dart';
import 'symbols/symbol_panel.dart';
import 'symbols/symbol_place_tool.dart';
import 'symbols/symbol_library_state.dart';
import 'symbols/symbol_move.dart';
import 'symbols/wall_attach.dart';
import 'tables/table_label_system.dart';
import 'tool_palette.dart';

/// Registers the shell's synchronous settle with its host (spec 12a D2,
/// plan 12a P-4): the host calls [settle] before a flow reads or replaces
/// the document. Returns the function that withdraws the registration; the
/// shell calls it on dispose, and it withdraws only [settle] itself, since
/// a swap builds the next shell before the old one is disposed.
typedef ShellSettleRegistrar = VoidCallback Function(VoidCallback settle);

/// Owns the index, the camera and -- since 03 -- the outline cache and the
/// grip cache for the document's lifetime; since 05, the tools and the Fill
/// toggle. It lays out the chrome slots.
///
/// Since 12a the document comes from the `DocumentHost`, which keys the
/// shell by it (spec 12a D2): a new document is a new shell. The host also
/// passes the object-snap setting, which survives a swap, the file
/// commands, and the file state (name, dirty, busy) for the top bar of
/// spec 12a D7. Undo and Redo are the shell's own commands (D1, D6).
///
/// A bare shell is the test seam (spec 03, Architecture; Ruling 03-18;
/// plan 12a P-4).
/// - [document] must carry a `FlutterTextMeasurer`, which its caller owns.
///   Without one the shell builds the empty document of spec 12a D4
///   ([newDocument]) over a measurer of its own, which it clears on
///   dispose.
/// - [snap], when given, is the host's and is **not** disposed here (spec
///   12a D2, S-11); without one the shell owns a fresh one.
/// - With no [fileCommands] the toolbar shows Undo and Redo only.
/// - [initialCamera] replaces the nominal fit.
/// - `PlannerView` still fits once after its first frame, so a test sets a
///   camera of its own after the first pump.
class PlannerShell extends StatefulWidget {
  const PlannerShell({
    super.key,
    this.document,
    this.snap,
    this.fileCommands = const <ShellCommand>[],
    this.documentName,
    this.dirty,
    this.busy,
    this.onSettle,
    this.initialCamera,
    this.symbols,
    this.thumbnails,
    this.symbolSearch,
    this.selection,
    this.fitRequests,
    this.camera,
    this.fitOnStart = true,
    this.onFitted,
  });

  final DraftDocument? document;
  final SnapSettings? snap;

  /// The host's file commands (spec 12a D6): New, Open, Open sample, Save,
  /// Save As, Export. The shell adds its own idle condition (no shape
  /// part-way) to each, and its page to Export's (spec 13 D8), and binds
  /// and shows them with Undo and Redo.
  final List<ShellCommand> fileCommands;

  /// The document's name, for the top bar (spec 12a D7); null in a bare
  /// shell.
  final String? documentName;

  /// Whether the document differs from its save point (spec 12a D5); null
  /// in a bare shell.
  final ValueListenable<bool>? dirty;

  /// Whether a flow of the host is running (spec 12a D6); null in a bare
  /// shell.
  final ValueListenable<bool>? busy;

  /// Where the shell registers its settle (spec 12a D2).
  final ShellSettleRegistrar? onSettle;
  final ViewportTransform? initialCamera;

  /// The app's symbol library loader (spec 09b D2), passed through the
  /// host; not owned here. With it the left panel has two tabs, Tools and
  /// Symbols (D8); null in a bare shell, which shows today's panel exactly.
  final SymbolLibraryLoader? symbols;

  /// The app's symbol thumbnail cache (spec 09b D5), passed through the
  /// host; not owned here. Read only with [symbols]: a shell given a loader
  /// and no cache makes a cache of its own and disposes it.
  final SymbolThumbnails? thumbnails;

  /// The Symbols tab's search text (spec 09c D13), passed by the host, which
  /// keeps it across document swaps; not disposed here. A shell given none
  /// makes one of its own and disposes it. Read once, in `initState`.
  final TextEditingController? symbolSearch;

  /// The host's selection over [document] (spec 14b-2 H4, H8): used and
  /// never disposed here, as [snap]; without one the shell owns its own.
  final SelectionController? selection;

  /// Each notification refits the camera (spec 14b-2 H8), forwarded to the
  /// view.
  final Listenable? fitRequests;

  /// The host's camera (spec 14b-2 R-13): used and never disposed here,
  /// so a mode switch keeps the view; [initialCamera] is then not read.
  final CameraController? camera;

  /// Forwarded to the view: false when [camera] is already placed.
  final bool fitOnStart;

  /// Forwarded to the view: called after each fit.
  final VoidCallback? onFitted;

  @override
  State<PlannerShell> createState() => _PlannerShellState();
}

class _PlannerShellState extends State<PlannerShell> {
  /// A bare shell's own measurer, for the document it builds itself; null
  /// when the document was passed in (its measurer is its caller's).
  FlutterTextMeasurer? _ownMeasurer;
  late final DraftDocument _document =
      widget.document ?? newDocument(_ownMeasurer = FlutterTextMeasurer());
  late final PageNotifier _page = PageNotifier(_document);
  late final SpatialIndex _index = SpatialIndex(_document);

  /// ACI 7's foreground follows the paper (fix/post-07): the app drafts
  /// ByLayer on layer 0, which is ACI 7, so drafting is black on a light
  /// paper and white on a dark one ([foregroundFor]). [_onPage] keeps it in
  /// step with the page by every route that changes it. Replaced only when
  /// the chosen foreground changes: `DraftCanvas` rebuilds its painter
  /// whenever the resolver it is handed is a different object, so White to
  /// Ivory, or a scale edit, must not build a new one.
  late DocumentStyleResolver _resolver =
      DocumentStyleResolver(_document, foreground: _foregroundOn(_page.value));

  /// A document without a page has no sheet to draw on: the chrome paints
  /// none, and the drafting lies on the shell's light surface, so it is
  /// read as white paper.
  static int _foregroundOn(PageComponent? page) =>
      foregroundFor(page?.background ?? 0xFFFFFFFF);

  /// The page notifier re-reads the page on a command that touches the
  /// root, its undo and redo, a load and a purge, and notifies only when
  /// the page is a different value; a swatch, an undo of one and a loaded
  /// document all arrive here.
  void _onPage() {
    final foreground = _foregroundOn(_page.value);
    if (foreground == _resolver.foreground) return;
    setState(() =>
        _resolver = DocumentStyleResolver(_document, foreground: foreground));
  }

  late final CameraController _camera = widget.camera ??
      CameraController(
        widget.initialCamera ?? _nominalFit(),
        minScale: kMinScale,
        maxScale: kMaxScale,
      );
  final GesturePolicy _policy = GesturePolicy.forPlatform();

  /// The host's when it passed one (spec 12a D2: object snap survives a
  /// swap), and then never disposed here (S-11).
  late final SnapSettings _snap;
  late final bool _ownsSnap;

  /// Withdraws [_settlePendingInput]'s registration with the host.
  VoidCallback? _releaseSettle;

  // Spec 06 D13, Ruling 06-12: installed in initState, disposed in dispose.
  late final ParametricSystem _parametric;

  // Spec 14a T12: stacked on the parametric system's expander, installed
  // after it and disposed before it (last in, first out).
  late final TableLabelSystem _tableLabels;

  // Spec 05 D5, D13: the shell owns the tools and the Fill toggle.
  final ValueNotifier<bool> _fill = ValueNotifier<bool>(false);
  // Spec 09c D8: one tagged symbol dragged near a wall face attaches, over
  // the faces the symbol tool shares; the library is read at each drag.
  late final SelectTool _select = SelectTool(
      moveResolver: SymbolMoveResolver(
          faces: _faces,
          library: () => switch (widget.symbols?.state) {
                SymbolLibraryReady(:final library) => library,
                _ => null,
              }));
  final LineTool _line = LineTool();
  late final PolylineTool _polyline = PolylineTool(fill: _fill);
  late final RectangleTool _rectangle = RectangleTool(fill: _fill);
  final BoxTool _box = BoxTool();
  // Spec 07 D11: the shell owns the Wall tool's settings; the Selection
  // panel's Wall section edits them while the tool is active.
  final ValueNotifier<WallSettings> _wallSettings =
      ValueNotifier<WallSettings>(const WallSettings());
  // Spec 08 D14, Ruling 08-11: one band cache, shared by the Wall tool and
  // the three opening tools.
  final WallBands _bands = WallBands();
  late final WallTool _wall = WallTool(_wallSettings, bands: _bands);
  // Spec 08 D14, Ruling 08-17: the shell owns each opening tool's settings.
  final Map<OpeningKind, ValueNotifier<OpeningSettings>> _openingSettings = {
    for (final k in OpeningKind.values)
      k: ValueNotifier<OpeningSettings>(OpeningSettings.defaultFor(k)),
  };
  late final Map<OpeningKind, OpeningTool> _openingTools = {
    for (final k in OpeningKind.values)
      k: OpeningTool(k, _openingSettings[k]!, bands: _bands),
  };
  // Spec 10 D19-D21, Ruling 10-11: one room-input cache, shared by the
  // Room tool, the Separator tool and the separator grips.
  late final RoomInputs _roomInputs = RoomInputs(_document);
  late final RoomTool _room = RoomTool(_roomInputs);
  late final SeparatorTool _separator = SeparatorTool(_roomInputs);
  // Spec 11 D12: the Dimension tool (I).
  late final DimensionTool _dimension = DimensionTool();
  late final CircleTool _circle = CircleTool(fill: _fill);
  final ArcTool _arc = ArcTool();
  final TextTool _text = TextTool();

  // Spec 09b D8: the symbol placement tool and its armed symbol. Outside
  // [_entries] (no letter: a gallery cell arms it), so disposed on its own.
  final ValueNotifier<SymbolEntry?> _armed = ValueNotifier<SymbolEntry?>(null);
  // Spec 09c D3, D6 (W-5): the wall faces a tagged symbol attaches to, over
  // the band cache the Wall and Opening tools share, with the openings'
  // host rule (a hidden or locked wall hosts nothing). It reads the
  // document each query hands it (this shell's, the host keys the shell by
  // its document) and holds no subscription of its own: [_bands] is
  // disposed below.
  late final WallFaces _faces = WallFaces(_bands, accept: isUsableHost);
  late final SymbolPlaceTool _symbolTool =
      SymbolPlaceTool(_armed, faces: _faces);

  /// The Symbols tab's search field (spec 09b D7, F-4): a panel field, so
  /// [_settlePendingInput] hands it back.
  final PanelFieldFocusNode _symbolSearch =
      PanelFieldFocusNode(debugLabel: 'symbol-search');

  /// The Symbols tab's search text (spec 09c D13): the shell's, not the
  /// panel's, which the Tools tab removes, so the text survives a tab
  /// switch. The host's when it passed one (a document swap keeps it);
  /// otherwise [_ownSymbolQuery]. Both set in [initState].
  late final TextEditingController _symbolQuery;
  TextEditingController? _ownSymbolQuery;

  /// A cache of the shell's own when it was given a loader and no cache.
  SymbolThumbnails? _ownThumbnails;

  /// The left panel's active tab (spec 09b D8): shell state, not persisted.
  _LeftTab _leftTab = _LeftTab.tools;

  late final List<PaletteEntry> _entries = [
    PaletteEntry(
        keyName: 'tool-select',
        label: (s) => s.toolSelect,
        shortcut: 'V',
        logicalKey: LogicalKeyboardKey.keyV,
        tool: _select,
        drawing: false),
    PaletteEntry(
        keyName: 'tool-line',
        label: (s) => s.toolLine,
        shortcut: 'L',
        logicalKey: LogicalKeyboardKey.keyL,
        tool: _line,
        drawing: true),
    PaletteEntry(
        keyName: 'tool-polyline',
        label: (s) => s.toolPolyline,
        shortcut: 'P',
        logicalKey: LogicalKeyboardKey.keyP,
        tool: _polyline,
        drawing: true),
    PaletteEntry(
        keyName: 'tool-rectangle',
        label: (s) => s.toolRectangle,
        shortcut: 'R',
        logicalKey: LogicalKeyboardKey.keyR,
        tool: _rectangle,
        drawing: true),
    PaletteEntry(
        keyName: 'tool-box',
        label: (s) => s.toolBox,
        shortcut: 'B',
        logicalKey: LogicalKeyboardKey.keyB,
        tool: _box,
        drawing: true),
    PaletteEntry(
        keyName: 'tool-wall',
        label: (s) => s.toolWall,
        shortcut: 'W',
        logicalKey: LogicalKeyboardKey.keyW,
        tool: _wall,
        drawing: true),
    PaletteEntry(
        keyName: 'tool-door',
        label: (s) => s.toolDoor,
        shortcut: 'D',
        logicalKey: LogicalKeyboardKey.keyD,
        tool: _openingTools[OpeningKind.door]!,
        drawing: true),
    PaletteEntry(
        keyName: 'tool-window',
        label: (s) => s.toolWindow,
        shortcut: 'N',
        logicalKey: LogicalKeyboardKey.keyN,
        tool: _openingTools[OpeningKind.window]!,
        drawing: true),
    PaletteEntry(
        keyName: 'tool-gap',
        label: (s) => s.toolGap,
        shortcut: 'G',
        logicalKey: LogicalKeyboardKey.keyG,
        tool: _openingTools[OpeningKind.gap]!,
        drawing: true),
    PaletteEntry(
        keyName: 'tool-room',
        label: (s) => s.toolRoom,
        shortcut: 'M',
        logicalKey: LogicalKeyboardKey.keyM,
        tool: _room,
        drawing: true),
    PaletteEntry(
        keyName: 'tool-separator',
        label: (s) => s.toolSeparator,
        shortcut: 'S',
        logicalKey: LogicalKeyboardKey.keyS,
        tool: _separator,
        drawing: true),
    PaletteEntry(
        keyName: 'tool-dimension',
        label: (s) => s.toolDimension,
        shortcut: 'I',
        logicalKey: LogicalKeyboardKey.keyI,
        tool: _dimension,
        drawing: true),
    PaletteEntry(
        keyName: 'tool-circle',
        label: (s) => s.toolCircle,
        shortcut: 'C',
        logicalKey: LogicalKeyboardKey.keyC,
        tool: _circle,
        drawing: true),
    PaletteEntry(
        keyName: 'tool-arc',
        label: (s) => s.toolArc,
        shortcut: 'A',
        logicalKey: LogicalKeyboardKey.keyA,
        tool: _arc,
        drawing: true),
    PaletteEntry(
        keyName: 'tool-text',
        label: (s) => s.toolText,
        shortcut: 'T',
        logicalKey: LogicalKeyboardKey.keyT,
        tool: _text,
        drawing: true),
  ];

  // Constructed before the tool controller and its context: the selection
  // controller's listener on `document.changes` must prune dead keys before
  // anything downstream (the outline cache, in PlannerView) walks them.
  late final SelectionController _selection =
      widget.selection ?? SelectionController(_document);

  // Spec 03 D6, moved from PlannerView. The order is load-bearing.
  // - The outline cache is built after the selection controller, so the
  //   controller prunes a dead key before the cache walks it.
  // - The grip cache is built after the outline cache, so on a selection
  //   change its listener runs after the outlines have been rebuilt.
  // - Spec 07 D11, 08 D16: a selected wall's end grips and an opening's
  //   slide grip come from `ObjectGrips`, which also tells the select tool
  //   not to move or rotate an opening. The slide grip's edge snaps follow
  //   object snap (F3) at the camera's current aperture (Ruling 08-15).
  // - Spec 10 D21: a room's label grip, which the select tool neither
  //   moves nor rotates (R-22), returns the label to auto on a drop within
  //   the snap aperture of its pole whatever F3 says (Ruling 10-17); a
  //   separator's end grips band-trim through the shared room inputs while
  //   F3 is on (D20).
  // - Spec 11 D13: a dimension's offset grip and end grips; an end grip
  //   attaches through the shared index while F3 is on (D10).
  late final OutlineCache _outlines = OutlineCache(_document, _selection);
  late final GripCache _grips = GripCache(_document, _selection, _outlines,
      objects: ObjectGrips(
          edgeAperture: () => _snap.objectSnap
              ? kSnapAperturePixels / _camera.value.scale
              : null,
          labelAperture: () => kSnapAperturePixels / _camera.value.scale,
          roomInputs: _roomInputs,
          index: _index,
          objectSnap: () => _snap.objectSnap));

  late final ToolContext _context = ToolContext(
      document: _document,
      index: _index,
      camera: _camera,
      selection: _selection,
      page: _page,
      snap: _snap,
      grips: _grips);
  late final ToolController _tools =
      ToolController(initial: _select, context: _context);
  // Spec 10 D19, R-29: the Room tool's notice joins the status line; spec
  // 11 D12 (R-24): so does the Dimension tool's value.
  late final Listenable _status =
      Listenable.merge([_selection, _tools, _room.notice, _dimension.notice]);

  /// Fitted to the nominal window; PlannerView re-fits once at the real
  /// size. A document without a page fits its extents.
  ViewportTransform _nominalFit() {
    final page = _page.value;
    return page != null
        ? fitToPage(page, const Size(1440, 900))
        : ViewportTransform.fit(_document.extents, const Size(1440, 900));
  }

  /// The host's busy flag; null in a bare shell. Read once, like [_snap].
  late final ValueListenable<bool>? _busy;

  /// Spec 12a D6: no flow is running, and the active tool is not part-way
  /// through a shape (T-2, `Tool.isMidShape`). A toolbar click is a
  /// pointer event no tool sees, so the commands themselves wait for the
  /// shape to end, and the buttons and the keys agree.
  bool get _idle => !(_busy?.value ?? false) && !_tools.active.isMidShape;

  /// Everything [_idle] reads that notifies: the tools (a tool's own
  /// notifications arrive through the controller) and busy.
  late final List<Listenable> _idleSources = [_tools, if (_busy != null) _busy];

  late final DerivedFlag _undoEnabled =
      DerivedFlag(_idleSources, () => _idle && _document.commands.canUndo);
  late final DerivedFlag _redoEnabled =
      DerivedFlag(_idleSources, () => _idle && _document.commands.canRedo);

  /// The history moves on the dispatcher's changes; Undo and Redo re-read
  /// `canUndo` and `canRedo` on each (spec 12a D5).
  StreamSubscription<DocChange>? _history;

  /// The file commands, each enabled only while the host's own condition
  /// holds and the shell is idle; Export and Print also only while the
  /// document has a page (spec 13 D8, [kPageCommandIds]).
  late final List<DerivedFlag> _fileEnabled = [
    for (final c in _firstFileCommands)
      kPageCommandIds.contains(c.id)
          ? DerivedFlag([c.enabled, ..._idleSources, _page],
              () => c.enabled.value && _idle && _page.value != null)
          : DerivedFlag(
              [c.enabled, ..._idleSources], () => c.enabled.value && _idle),
  ];

  /// The file commands the shell was built with: the set, and the
  /// conditions [_fileEnabled] watches, are fixed for its life.
  late final List<ShellCommand> _firstFileCommands = widget.fileCommands;

  /// That set, each command as the current widget names it when it still
  /// has one of that id (spec 14d L3: a language change renames them),
  /// each enabled only by [_fileEnabled].
  List<ShellCommand> get _fileCommands {
    final current = {for (final c in widget.fileCommands) c.id: c};
    return [
      for (final (i, c) in _firstFileCommands.indexed)
        (current[c.id] ?? c).withEnabled(_fileEnabled[i]),
    ];
  }

  /// Spec 12a D6: Undo and Redo are the shell's own commands, so a bare
  /// shell keeps them. Their bindings sit above the [InteractionLayer]'s
  /// `Focus`, which returns the active tool's own `KeyEventResult`: an idle
  /// tool ignores Z, so the event keeps bubbling and arrives here, and a
  /// tool part-way through a shape swallows it (spec 05 D3).
  List<ShellCommand> _editCommands(FloorPlanStrings strings) => [
        ShellCommand(
          id: 'undo',
          label: strings.undo,
          icon: Icons.undo,
          shortcuts: kUndoChords,
          enabled: _undoEnabled,
          run: _undo,
        ),
        ShellCommand(
          id: 'redo',
          label: strings.redo,
          icon: Icons.redo,
          shortcuts: kRedoChords,
          enabled: _redoEnabled,
          run: _redo,
        ),
      ];

  /// Undo settles pending input first (spec 12a D2, R-9): a typed value
  /// lands as its own step, which this undo then removes. It re-reads
  /// `canUndo` after the settle (U-2) and never relies on the dispatcher
  /// refusing.
  Future<void> _undo() async {
    _settlePendingInput();
    if (!_document.commands.canUndo) return;
    _document.commands.undo();
  }

  /// Redo settles first too; a value the settle committed cuts the redo
  /// branch, exactly as pressing Enter would, and then there is nothing to
  /// redo (spec 12a D6, U-2, R-9).
  Future<void> _redo() async {
    _settlePendingInput();
    if (!_document.commands.canRedo) return;
    _document.commands.redo();
  }

  /// The page panel, whose scale field [_settlePendingInput] re-syncs.
  final GlobalKey<PagePanelState> _pagePanel = GlobalKey<PagePanelState>();

  /// Spec 12a D2 (S-4, S-5, T-4): settles input that is typed but not yet
  /// committed, before a host flow or Undo/Redo reads the document.
  /// **Synchronous**, and never called in a build.
  /// - **The text entry**, open: the Text tool's `finish` commits its typed
  ///   text as one step, as Enter would (R-5), and closes it; the entry
  ///   hands the focus back to the canvas. A focus loss alone would cancel
  ///   it, and still does everywhere else.
  /// - **A panel field** with the focus: handed back to the canvas. Its
  ///   focus-loss listener commits a Selection panel value as its own step
  ///   (a value that would be refused reverts, as on Enter).
  /// - **The page scale**: an unsubmitted scale is not saved (the field's
  ///   own rule); the field is re-synced to the stored scale, so the panel
  ///   never shows a scale the document does not have (D14).
  /// - Then the pending focus changes are applied **now**
  ///   (`applyFocusChangesIfNeeded`, as `MenuAnchor` does before a menu
  ///   item's callback): the focus-loss listeners run before the caller
  ///   reads the state id or encodes, not a microtask later.
  void _settlePendingInput() {
    if (_text.isPending) _text.finish(_context);
    final focused = FocusManager.instance.primaryFocus;
    if (focused is PanelFieldFocusNode) focused.handBack();
    _pagePanel.currentState?.resyncScale();
    FocusManager.instance.applyFocusChangesIfNeeded();
  }

  bool get _geometryAllowed =>
      _document.commands.permissions.allows(Capability.geometry);

  /// Spec 05 D5: the one way a tool becomes active. A drawing tool clears
  /// the selection first, because the overlay paints the selection's
  /// outlines and grips under any active tool. It is refused while geometry
  /// is denied. Focus never leaves the canvas (Ruling 05-6).
  void _activate(Tool tool) {
    final drawing = !identical(tool, _select);
    if (drawing && !_geometryAllowed) return;
    if (drawing) _selection.clear();
    _tools.activate(tool);
  }

  /// Spec 09b D8: a gallery cell arms [entry] and activates the placement
  /// tool through [_activate], which refuses it while geometry is denied
  /// and clears the selection.
  void _armSymbol(SymbolEntry entry) {
    _armed.value = entry;
    _activate(_symbolTool);
  }

  /// An idle drawing tool leaves Escape unhandled; it arrives here.
  void _escape() {
    if (!identical(_tools.active, _select)) _activate(_select);
  }

  /// The active tool, the selection's size when it is not empty, and the
  /// Room tool's notice (spec 10 D19, R-29) or the Dimension tool's
  /// would-be value (spec 11 D12, S-8: `Dimension — 4.69`) when one is set.
  /// Only the active tool sets one, and each clears on deactivation.
  String _statusLine() {
    final strings = FloorPlanStrings.of(context);
    final active = _tools.active;
    // A palette tool by its row's words; the symbol placement tool, which
    // has no row, by its own (spec 14d L5).
    final base = identical(active, _symbolTool)
        ? strings.toolSymbol
        : [
              for (final e in _entries)
                if (identical(e.tool, active)) e.label(strings)
            ].firstOrNull ??
            active.name;
    final line = _selection.isEmpty
        ? base
        : '$base — ${strings.selectedCount(_selection.length)}';
    final occupied = _room.notice.value;
    final notice = occupied != null
        ? FloorPlanStrings.of(context).roomOccupied(occupied.name)
        : _dimension.notice.value;
    return notice == null ? line : '$line — $notice';
  }

  String _zoomLine() {
    final page = _page.value;
    if (page == null) return '';
    final zoom = zoomOf(_camera.value.scale, page, kLogicalPixelsPerMm);
    final scale =
        formatPanelNumber(page.scaleDenominator, FloorPlanStrings.of(context));
    return '1:$scale · ${(zoom * 100).round()}%';
  }

  @override
  void initState() {
    super.initState();
    // Read once: the host keys the shell by its document and passes the
    // same settings for the shell's whole life.
    _ownsSnap = widget.snap == null;
    _snap = widget.snap ?? SnapSettings();
    _symbolQuery =
        widget.symbolSearch ?? (_ownSymbolQuery = TextEditingController());
    _busy = widget.busy;
    // Spec 06 D13, Ruling 06-12, spec 08 D18, spec 10 D23: the document
    // arrives built. The sample (startupPlan) builds its walls, openings,
    // separator and rooms through a parametric system of its own and
    // disposes it before returning, and an opened file was decoded, so this
    // one installs over a finished document and trusts its geometry (06
    // D10).
    _parametric = installParametric(_document);
    _tableLabels = TableLabelSystem(_document)..install();
    _page.addListener(_onPage);
    _releaseSettle = widget.onSettle?.call(_settlePendingInput);
    _history = _document.commands.changes.listen((_) {
      _undoEnabled.update();
      _redoEnabled.update();
    });
  }

  @override
  void dispose() {
    // The command flags listen to the tools and the host's busy flag: they
    // go first.
    _history?.cancel();
    _undoEnabled.dispose();
    _redoEnabled.dispose();
    for (final f in _fileEnabled) {
      f.dispose();
    }
    _tools.dispose();
    for (final e in _entries) {
      e.tool.dispose();
    }
    // The tool removes its listener from [_armed]: it goes first.
    _symbolTool.dispose();
    _armed.dispose();
    _symbolSearch.dispose();
    // After the tabs' panel has gone with the tree; the host's is the
    // host's.
    _ownSymbolQuery?.dispose();
    _ownThumbnails?.dispose();
    _fill.dispose();
    _wallSettings.dispose();
    for (final s in _openingSettings.values) {
      s.dispose();
    }
    _bands.dispose();
    _roomInputs.dispose();
    _grips.dispose();
    _outlines.dispose();
    if (widget.selection == null) _selection.dispose();
    if (_ownsSnap) _snap.dispose();
    _page
      ..removeListener(_onPage)
      ..dispose();
    if (widget.camera == null) _camera.dispose();
    _tableLabels.dispose();
    _parametric.dispose();
    // Last in, first out (spec 14a T12): both released, the slot is empty.
    assert(_document.commands.expander == null,
        'the expander slot was not released: dispose order');
    _index.dispose();
    _releaseSettle?.call();
    _ownMeasurer?.clear();
    super.dispose();
  }

  /// The document's name, with `• ` in front and an `Edited` tooltip while
  /// it is dirty (spec 12a D5, D7).
  Widget _documentName(String name) {
    final dirty = widget.dirty;
    Widget text(bool isDirty) => Text(isDirty ? '• $name' : name,
        key: const Key('document-name'),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis);
    if (dirty == null) return text(false);
    return ValueListenableBuilder<bool>(
      valueListenable: dirty,
      builder: (_, isDirty, __) => isDirty
          ? Tooltip(
              message: FloorPlanStrings.of(context).edited, child: text(true))
          : text(false),
    );
  }

  Widget _toolPalette() => ToolPalette(
        entries: _entries,
        tools: _tools,
        fill: _fill,
        geometryAllowed: _geometryAllowed,
        onSelect: _activate,
      );

  /// Spec 09b D8: today's palette in a bare shell; with a loader, a tab
  /// strip (Tools, the default, and Symbols) over the chosen tab. The
  /// strip never takes focus (Ruling 05-6, R-5): the canvas keeps it.
  /// Switching tabs changes no tool.
  Widget _leftPanel() {
    final symbols = widget.symbols;
    if (symbols == null) return _toolPalette();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: ExcludeFocus(
            child: SegmentedButton<_LeftTab>(
              key: const Key('left-tabs'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                    value: _LeftTab.tools,
                    label: Text(FloorPlanStrings.of(context).tabTools,
                        key: const Key('tab-tools'))),
                ButtonSegment(
                    value: _LeftTab.symbols,
                    label: Text(FloorPlanStrings.of(context).tabSymbols,
                        key: const Key('tab-symbols'))),
              ],
              selected: {_leftTab},
              onSelectionChanged: (s) => setState(() => _leftTab = s.single),
            ),
          ),
        ),
        Expanded(
          child: switch (_leftTab) {
            _LeftTab.tools => _toolPalette(),
            _LeftTab.symbols => SymbolPanel(
                loader: symbols,
                thumbnails: widget.thumbnails ??
                    (_ownThumbnails ??= SymbolThumbnails()),
                tools: _tools,
                tool: _symbolTool,
                armed: _armed,
                permissions: _document.commands.permissions,
                searchFocus: _symbolSearch,
                query: _symbolQuery,
                onSelect: _armSymbol,
              ),
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fileCommands = _fileCommands;
    final editCommands = _editCommands(FloorPlanStrings.of(context));
    return Scaffold(
      body: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          // Spec 12a D6: the command table's chords. A disabled command's
          // binding stays and does nothing (S-26), so the key is consumed.
          for (final c in [...fileCommands, ...editCommands])
            for (final chord in c.shortcuts) chord: c.invoke,
          // Spec 03 D10: one toggle per press, never per key repeat.
          const SingleActivator(LogicalKeyboardKey.f3, includeRepeats: false):
              _snap.toggleObjectSnap,
          // Spec 05 D5: the tool letters, then Fill, then Escape.
          for (final e in _entries)
            SingleActivator(e.logicalKey, includeRepeats: false): () =>
                _activate(e.tool),
          const SingleActivator(LogicalKeyboardKey.keyF, includeRepeats: false):
              () {
            if (_geometryAllowed) _fill.value = !_fill.value;
          },
          const SingleActivator(LogicalKeyboardKey.escape): _escape,
        },
        child: Column(
          children: [
            Container(
              key: const Key('chrome-top'),
              height: 44,
              color: scheme.surfaceContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    // Spec 12a D7: the toolbar, the document's name, then
                    // the status line; the name and the status give way
                    // (ellipsis) before the row would overflow. The status
                    // takes all the width the name leaves: the name is
                    // capped at half of their shared width and takes only
                    // what it needs below that.
                    DocumentToolbar(
                        fileCommands: fileCommands, editCommands: editCommands),
                    const SizedBox(width: 16),
                    Expanded(
                      child: LayoutBuilder(builder: (_, constraints) {
                        // In a narrow window the two 16 px gaps (after the
                        // name, before OSNAP) shrink with the free width,
                        // down to 0, so they never overflow the bar; the
                        // half cap gives way to them below 32 px.
                        final free = constraints.maxWidth;
                        final tail = math.min(16.0, free);
                        final shared = free - tail;
                        final gap = math.min(16.0, shared);
                        return Row(
                          children: [
                            if (widget.documentName != null) ...[
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                    maxWidth:
                                        math.min(shared / 2, shared - gap)),
                                child: _documentName(widget.documentName!),
                              ),
                              SizedBox(width: gap),
                            ],
                            Expanded(
                              child: ListenableBuilder(
                                listenable: _status,
                                builder: (_, __) => Text(_statusLine(),
                                    key: const Key('status-text'),
                                    maxLines: 1,
                                    softWrap: false,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ),
                            SizedBox(width: tail),
                          ],
                        );
                      }),
                    ),
                    ListenableBuilder(
                      listenable: _snap,
                      builder: (_, __) => Text(
                          _snap.objectSnap
                              ? FloorPlanStrings.of(context).objectSnapOn
                              : FloorPlanStrings.of(context).objectSnapOff,
                          key: const Key('osnap-text')),
                    ),
                    const SizedBox(width: 16),
                    ListenableBuilder(
                      listenable: Listenable.merge([_camera, _page]),
                      builder: (_, __) =>
                          Text(_zoomLine(), key: const Key('zoom-text')),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Container(
                    key: const Key('chrome-left'),
                    width: 240,
                    color: scheme.surfaceContainerLow,
                    child: _leftPanel(),
                  ),
                  Expanded(
                    child: ColoredBox(
                      color: scheme.surface,
                      child: PlannerView(
                        document: _document,
                        index: _index,
                        resolver: _resolver,
                        camera: _camera,
                        page: _page,
                        policy: _policy,
                        selection: _selection,
                        tools: _tools,
                        outlines: _outlines,
                        grips: _grips,
                        textTool: _text,
                        fitRequests: widget.fitRequests,
                        fitOnStart: widget.fitOnStart,
                        onFitted: widget.onFitted,
                      ),
                    ),
                  ),
                  Container(
                    key: const Key('chrome-right'),
                    width: 280,
                    color: scheme.surfaceContainerLow,
                    child: ShellShortcutGuard(
                      child: Column(
                        children: [
                          // Spec 07 D11, 08 D16: while the Wall tool or
                          // an opening tool is active, the panel edits its
                          // settings.
                          SelectionPanel(
                              document: _document,
                              selection: _selection,
                              tools: _tools,
                              wallTool: _wall,
                              wallSettings: _wallSettings,
                              openingTools: _openingTools,
                              openingSettings: _openingSettings,
                              symbols: widget.symbols),
                          // Spec 12b D9: the Layers section, placed only.
                          LayerPanel(
                              document: _document,
                              foreground: _resolver.foreground),
                          Expanded(
                            child: PagePanel(
                                key: _pagePanel,
                                document: _document,
                                page: _page),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The left panel's tabs (spec 09b D8).
enum _LeftTab { tools, symbols }
