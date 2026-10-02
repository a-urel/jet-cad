import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'document_files.dart';
import 'document_host.dart';
import 'document_toolbar.dart';
import 'exit_guard.dart';
import 'export/export_font.dart';
import 'export/page_printer.dart';
import 'layers/layer_panel.dart';
import 'new_document.dart';
import 'page_panel.dart';
import 'panel_focus.dart';
import 'panel_number.dart';
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
import 'tool_palette.dart';

void main() {
  registerFontLicences();
  runApp(const FloorPlannerApp());
}

/// The app (spec 12a D5, U-4, plan 12a P-3): it owns the [DocumentSession]
/// and the [DocumentFiles], and rebuilds [MaterialApp] from the session, so
/// `onGenerateTitle` -- which runs above `home` and re-runs only when the
/// app rebuilds -- follows the document's name and dirty state (the web
/// tab's title). The [DocumentHost] in `home` runs the flows and builds the
/// shell.
///
/// [files] and [exitGuard] are test seams: the platform's implementations
/// when null.
///
/// Since 09b (spec D2, D5, R-4) the app also owns the symbol library's
/// loader and the thumbnail cache: above the host, because the shell is
/// rebuilt per document and must neither read the asset again nor repaint
/// every thumbnail.
class FloorPlannerApp extends StatefulWidget {
  const FloorPlannerApp(
      {super.key,
      this.files,
      this.exitGuard,
      this.symbols,
      this.thumbnails,
      this.exportFont,
      this.printer = const PrintingPagePrinter()});

  final DocumentFiles? files;

  /// Handed to the [DocumentHost], which owns it (spec 12a D11).
  final ExitGuard? exitGuard;

  /// The symbol library's loader (spec 09b D2), a test seam: when null the
  /// app makes one over the bundled asset and disposes it; a given one is
  /// the caller's to dispose. Either way the app calls `load()` once.
  final SymbolLibraryLoader? symbols;

  /// The symbol thumbnail cache (spec 09b D5), a test seam: when null the
  /// app makes one and disposes it; a given one is the caller's to dispose.
  final SymbolThumbnails? thumbnails;

  /// The export font's bytes, read once per app (spec 13 D7), a test seam:
  /// when null the app makes a cache over the bundled asset.
  final ExportFontCache? exportFont;

  /// Where Print hands the page's PDF (spec 13 D9), a test seam: the
  /// platform's print dialog by default.
  final PagePrinter printer;

  @override
  State<FloorPlannerApp> createState() => _FloorPlannerAppState();
}

class _FloorPlannerAppState extends State<FloorPlannerApp> {
  final GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();
  final DocumentSession _session = DocumentSession.untitled();
  late final DocumentFiles _files =
      widget.files ?? createDocumentFiles(askName: _askName);

  /// The loader this app made itself, disposed with it; null when the
  /// caller gave one.
  SymbolLibraryLoader? _ownSymbols;
  late final SymbolLibraryLoader _symbols =
      widget.symbols ?? (_ownSymbols = SymbolLibraryLoader());

  /// The thumbnail cache this app made itself, disposed with it; null when
  /// the caller gave one.
  SymbolThumbnails? _ownThumbnails;
  late final SymbolThumbnails _thumbnails =
      widget.thumbnails ?? (_ownThumbnails = SymbolThumbnails());

  /// The export font (spec 13 D7): above the host, so a document swap never
  /// reads the asset again. Nothing is read until an export asks.
  late final ExportFontCache _exportFont =
      widget.exportFont ?? ExportFontCache();

  /// The web's save-name prompt (spec 12a D9, T-12), shown over the
  /// navigator: the files object is made above the `MaterialApp`, so it
  /// has no `BuildContext` of its own.
  Future<String?> _askName(String suggested) async {
    final context = _navigator.currentContext;
    if (context == null) return null;
    return showDocumentNamePrompt(context, suggested);
  }

  /// Marks a file chord handled, and does nothing.
  static void _consume() {}

  @override
  void initState() {
    super.initState();
    _symbols.load();
  }

  @override
  void dispose() {
    _ownSymbols?.dispose();
    _ownThumbnails?.dispose();
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([_session, _session.dirty]),
        builder: (context, _) => MaterialApp(
          navigatorKey: _navigator,
          onGenerateTitle: (_) =>
              documentTitle(_session.name, dirty: _session.dirty.value),
          debugShowCheckedModeBanner: false,
          theme: ThemeData(colorSchemeSeed: const Color(0xFF2266CC)),
          // Spec 12a D6 (T-3, U-3, R-10): the file chords once more above
          // the Navigator, consume-only. A dialog or a dropdown's route is
          // outside the shell's focus chain, and on web a key nobody
          // handles is not `preventDefault`ed: Cmd/Ctrl+S would open the
          // browser's Save Page. Here the key is marked handled and nothing
          // runs; the shell's own bindings run the commands whenever the
          // home route has the focus, so no flow starts over another route.
          builder: (context, child) => CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              for (final chord in kFileChords) chord: _consume,
            },
            child: child!,
          ),
          home: DocumentHost(
              session: _session,
              files: _files,
              exitGuard: widget.exitGuard,
              symbols: _symbols,
              thumbnails: _thumbnails,
              exportFont: _exportFont,
              printer: widget.printer),
        ),
      );
}

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
/// Since 12a the document comes from the [DocumentHost], which keys the
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

  late final CameraController _camera = CameraController(
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

  // Spec 05 D5, D13: the shell owns the tools and the Fill toggle.
  final ValueNotifier<bool> _fill = ValueNotifier<bool>(false);
  final SelectTool _select = SelectTool();
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
  late final SymbolPlaceTool _symbolTool = SymbolPlaceTool(_armed);

  /// The Symbols tab's search field (spec 09b D7, F-4): a panel field, so
  /// [_settlePendingInput] hands it back.
  final PanelFieldFocusNode _symbolSearch =
      PanelFieldFocusNode(debugLabel: 'symbol-search');

  /// A cache of the shell's own when it was given a loader and no cache.
  SymbolThumbnails? _ownThumbnails;

  /// The left panel's active tab (spec 09b D8): shell state, not persisted.
  _LeftTab _leftTab = _LeftTab.tools;

  late final List<PaletteEntry> _entries = [
    PaletteEntry(
        keyName: 'tool-select',
        label: 'Select',
        shortcut: 'V',
        logicalKey: LogicalKeyboardKey.keyV,
        tool: _select,
        drawing: false),
    PaletteEntry(
        keyName: 'tool-line',
        label: 'Line',
        shortcut: 'L',
        logicalKey: LogicalKeyboardKey.keyL,
        tool: _line,
        drawing: true),
    PaletteEntry(
        keyName: 'tool-polyline',
        label: 'Polyline',
        shortcut: 'P',
        logicalKey: LogicalKeyboardKey.keyP,
        tool: _polyline,
        drawing: true),
    PaletteEntry(
        keyName: 'tool-rectangle',
        label: 'Rectangle',
        shortcut: 'R',
        logicalKey: LogicalKeyboardKey.keyR,
        tool: _rectangle,
        drawing: true),
    PaletteEntry(
        keyName: 'tool-box',
        label: 'Box',
        shortcut: 'B',
        logicalKey: LogicalKeyboardKey.keyB,
        tool: _box,
        drawing: true),
    PaletteEntry(
        keyName: 'tool-wall',
        label: 'Wall',
        shortcut: 'W',
        logicalKey: LogicalKeyboardKey.keyW,
        tool: _wall,
        drawing: true),
    PaletteEntry(
        keyName: 'tool-door',
        label: 'Door',
        shortcut: 'D',
        logicalKey: LogicalKeyboardKey.keyD,
        tool: _openingTools[OpeningKind.door]!,
        drawing: true),
    PaletteEntry(
        keyName: 'tool-window',
        label: 'Window',
        shortcut: 'N',
        logicalKey: LogicalKeyboardKey.keyN,
        tool: _openingTools[OpeningKind.window]!,
        drawing: true),
    PaletteEntry(
        keyName: 'tool-gap',
        label: 'Gap',
        shortcut: 'G',
        logicalKey: LogicalKeyboardKey.keyG,
        tool: _openingTools[OpeningKind.gap]!,
        drawing: true),
    PaletteEntry(
        keyName: 'tool-room',
        label: 'Room',
        shortcut: 'M',
        logicalKey: LogicalKeyboardKey.keyM,
        tool: _room,
        drawing: true),
    PaletteEntry(
        keyName: 'tool-separator',
        label: 'Separator',
        shortcut: 'S',
        logicalKey: LogicalKeyboardKey.keyS,
        tool: _separator,
        drawing: true),
    PaletteEntry(
        keyName: 'tool-dimension',
        label: 'Dimension',
        shortcut: 'I',
        logicalKey: LogicalKeyboardKey.keyI,
        tool: _dimension,
        drawing: true),
    PaletteEntry(
        keyName: 'tool-circle',
        label: 'Circle',
        shortcut: 'C',
        logicalKey: LogicalKeyboardKey.keyC,
        tool: _circle,
        drawing: true),
    PaletteEntry(
        keyName: 'tool-arc',
        label: 'Arc',
        shortcut: 'A',
        logicalKey: LogicalKeyboardKey.keyA,
        tool: _arc,
        drawing: true),
    PaletteEntry(
        keyName: 'tool-text',
        label: 'Text',
        shortcut: 'T',
        logicalKey: LogicalKeyboardKey.keyT,
        tool: _text,
        drawing: true),
  ];

  // Constructed before the tool controller and its context: the selection
  // controller's listener on `document.changes` must prune dead keys before
  // anything downstream (the outline cache, in PlannerView) walks them.
  late final SelectionController _selection = SelectionController(_document);

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
    for (final c in widget.fileCommands)
      kPageCommandIds.contains(c.id)
          ? DerivedFlag([c.enabled, ..._idleSources, _page],
              () => c.enabled.value && _idle && _page.value != null)
          : DerivedFlag(
              [c.enabled, ..._idleSources], () => c.enabled.value && _idle),
  ];
  late final List<ShellCommand> _fileCommands = [
    for (var i = 0; i < widget.fileCommands.length; i++)
      widget.fileCommands[i].withEnabled(_fileEnabled[i]),
  ];

  /// Spec 12a D6: Undo and Redo are the shell's own commands, so a bare
  /// shell keeps them. Their bindings sit above the [InteractionLayer]'s
  /// `Focus`, which returns the active tool's own `KeyEventResult`: an idle
  /// tool ignores Z, so the event keeps bubbling and arrives here, and a
  /// tool part-way through a shape swallows it (spec 05 D3).
  late final List<ShellCommand> _editCommands = [
    ShellCommand(
      id: 'undo',
      label: 'Undo',
      icon: Icons.undo,
      shortcuts: kUndoChords,
      enabled: _undoEnabled,
      run: _undo,
    ),
    ShellCommand(
      id: 'redo',
      label: 'Redo',
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
    final base = _tools.active.name;
    final line =
        _selection.isEmpty ? base : '$base — ${_selection.length} selected';
    final notice = _room.notice.value ?? _dimension.notice.value;
    return notice == null ? line : '$line — $notice';
  }

  String _zoomLine() {
    final page = _page.value;
    if (page == null) return '';
    final zoom = zoomOf(_camera.value.scale, page, kLogicalPixelsPerMm);
    return '1:${panelNumberText(page.scaleDenominator)} · ${(zoom * 100).round()}%';
  }

  @override
  void initState() {
    super.initState();
    // Read once: the host keys the shell by its document and passes the
    // same settings for the shell's whole life.
    _ownsSnap = widget.snap == null;
    _snap = widget.snap ?? SnapSettings();
    _busy = widget.busy;
    // Spec 06 D13, Ruling 06-12, spec 08 D18, spec 10 D23: the document
    // arrives built. The sample (startupPlan) builds its walls, openings,
    // separator and rooms through a parametric system of its own and
    // disposes it before returning, and an opened file was decoded, so this
    // one installs over a finished document and trusts its geometry (06
    // D10).
    _parametric = installParametric(_document);
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
    _selection.dispose();
    if (_ownsSnap) _snap.dispose();
    _page
      ..removeListener(_onPage)
      ..dispose();
    _camera.dispose();
    _parametric.dispose();
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
      builder: (_, isDirty, __) =>
          isDirty ? Tooltip(message: 'Edited', child: text(true)) : text(false),
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
              segments: const [
                ButtonSegment(
                    value: _LeftTab.tools,
                    label: Text('Tools', key: Key('tab-tools'))),
                ButtonSegment(
                    value: _LeftTab.symbols,
                    label: Text('Symbols', key: Key('tab-symbols'))),
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
    return Scaffold(
      body: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          // Spec 12a D6: the command table's chords. A disabled command's
          // binding stays and does nothing (S-26), so the key is consumed.
          for (final c in [..._fileCommands, ..._editCommands])
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
                        fileCommands: _fileCommands,
                        editCommands: _editCommands),
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
                          _snap.objectSnap ? 'OSNAP' : 'osnap off',
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
                              openingSettings: _openingSettings),
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
