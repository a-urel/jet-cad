// 2a spec P2 (PlanEditor) and P7: today's editor layout over one
// PlanController: the top bar; the palette or the gallery on the left; the
// canvas; the property, layer and page panels on the right. Ported from
// jet_cad_floor_plan/lib/src/planner_shell.dart (build :1421-1611, the top
// bar :1278-1412, the left panel :1222-1276, the relay :1708-1752, the
// command flags :714-735 and :801-818), host/floor_plan_view.dart (the
// design branch of `_modes`, `_flowsFor` and the theme scope),
// document_toolbar.dart and shell_commands.dart:61-169.
import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show ValueListenable, defaultTargetPlatform, listEquals;
import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart' show DraftDocument, zoomOf;
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer, kLogicalPixelsPerMm, kRulerThickness;

import '../canvas/plan_canvas.dart';
import '../chrome/host_slot.dart';
import '../chrome/shad_scope.dart';
import '../controller/plan_controller.dart';
import '../export/editor_page_flows.dart';
import '../export/export_dialog.dart';
import '../export/page_printer.dart';
import '../export/registries.dart';
import '../l10n/locale_scope.dart';
import '../l10n/number_text.dart';
import '../l10n/strings.dart';
import '../objects/object_detail.dart';
import '../panels/frame_safe_relay.dart';
import '../panels/plan_layer_panel.dart';
import '../panels/plan_page_panel.dart';
import '../panels/plan_property_panel.dart';
import '../panels/plan_symbol_gallery.dart';
import '../service/service_session.dart' show PlanMode;
import '../service/service_tool.dart';
import '../service/view/plan_service_bar.dart';
import '../service/view/plan_service_view.dart';
import '../service/view/unit_overlays.dart';
import '../shortcuts/plan_shortcut_guard.dart';
import '../shortcuts/plan_shortcuts.dart';
import '../symbols/plan_symbol.dart';
import '../theme/plan_theme.dart';
import '../tools/generic_tools.dart';
import '../units/unit_detail.dart';
import 'editor_layout.dart';
import 'object_inspector.dart';
import 'plan_editor_bar.dart';
import 'plan_tool_palette.dart';
import 'selection_gate.dart';
import 'unit_inspector.dart';

/// A host's file command: called after the editor settles pending input.
typedef PlanFileCallback = Future<void> Function();

/// The design-mode editor over [controller] (2a spec P2): the top bar
/// ([bar]); the tool palette, or the Tools and Symbols tabs when a loaded
/// kit has symbols, on the left; the canvas; the property, layer and page
/// panels on the right. Every widget in it takes only the controller.
///
/// The bar's Export (only with [onExport]) and Print run the controller's
/// flows: the dialog ([onExportDialog] when given), the remembered answer,
/// one flow at a time, errors to [onPageFlowError] (or out of the dropped
/// `Future` without it). Export is enabled while some exporter can run: a
/// plan with no page offers only the exporters that plot none (the
/// built-in PDF and PNG plot the page), and Print needs the page.
/// [onNew], [onOpen], [onSave] and [onSaveAs] are the host's, offered as
/// buttons and chords only when given. Which buttons exist follows
/// `controller.permissions` (`export`, `print`, `undo`) at each build.
///
/// In `PlanMode.service` the editor shows a `PlanServiceView` over the
/// service copy with the options above, and the plan keeps its place on
/// the screen across a switch (today's R-13).
///
/// A host that owns the controller disposes it after the editor is gone
/// (in its own `State.dispose`, which Flutter calls after its children's).
class PlanEditor extends StatefulWidget {
  const PlanEditor({
    super.key,
    required this.controller,
    this.toolPalette = true,
    this.gallery = true,
    this.symbolFilter,
    this.propertyPanel = true,
    this.layerPanel = true,
    this.pagePanel = true,
    this.contextualPanels = true,
    this.rulers = true,
    this.grid = true,
    this.snapping = true,
    this.bar = const PlanEditorBar(),
    this.onNew,
    this.onOpen,
    this.onSave,
    this.onSaveAs,
    this.onExport,
    this.onExportDialog,
    this.onPageFlowError,
    this.printer,
    this.exportName = 'plan',
    this.shortcuts = true,
    this.autofocus = true,
    this.theme,
    this.unitInspectorBuilder,
    this.objectInspectorBuilder,
    this.serviceBar = const PlanServiceBar(),
    this.onUnitTap,
    this.onUnitDoubleTap,
    this.onUnitContextMenu,
    this.onGroupTap,
    this.onUnitHover,
    this.onMergeRequested,
    this.onSplitRequested,
    this.onLayoutChanged,
    this.onUnitsMoved,
    this.onFloorTap,
    this.longPress = PlanLongPress.toggleSelection,
    this.floorDrag = PlanFloorDrag.pan,
    this.userCamera = true,
    this.unitOverlayBuilder,
    this.unitOverlayLayout = const PlanOverlayLayout(),
    this.unitOverlayModes = const {PlanMode.service},
    this.breakpoints = const PlanLayoutBreakpoints(),
    this.layout,
    this.serviceSidePanel,
  });

  final PlanController controller;

  /// The widths at which the design mode changes layout (spec D4): the
  /// editor's own width decides, not the device's.
  final PlanLayoutBreakpoints breakpoints;

  /// Forces one layout whatever the width; null: [breakpoints] decide. On a
  /// phone or a tablet the left and right columns are drawers over the plan
  /// (one at a time; a tap on the plan, the same button or Escape closes
  /// it) and opening one never moves the camera.
  final PlanEditorLayout? layout;

  /// The host's panel beside the plan in service mode (orders, a table's
  /// detail): docked on the right, 320 logical pixels wide
  /// (`Key('service-side-panel')`), on a desktop layout; behind the service
  /// bar's last button (`Key('service-right-button')`) as a drawer over the
  /// plan on a phone or a tablet. Null: no panel and no button.
  ///
  /// The button is in the service bar: with `serviceBar.visible` false on a
  /// phone or a tablet there is no button and the panel cannot be opened (a
  /// host that hides the bar there has no way to open it; keep the bar, or
  /// show its own panel).
  final Widget? serviceSidePanel;

  /// Whether the left column offers the tool palette.
  final bool toolPalette;

  /// Whether the left column offers the Symbols tab (today's
  /// `symbolPalette`), when a loaded kit has symbols.
  final bool gallery;

  /// The gallery's filter (today's `symbolFilter`), read at each build.
  final bool Function(PlanSymbol symbol)? symbolFilter;

  /// Whether the property panel shows. A hidden right-column panel is kept
  /// offstage with its state and out of the focus order.
  final bool propertyPanel;

  /// The host's unit inspector (spec S4; today's `tableInspectorBuilder`):
  /// built under the property panel for exactly one selected placed unit
  /// whose label no other unit has, with nothing else selected, with that
  /// unit's detail as `unitDetails` reads it; null from it shows nothing.
  /// Built when the selection becomes such a unit, at each change of the
  /// plan, and at each host rebuild; never on pan, zoom or hover. Hidden
  /// with the property panel. A host links a drawn unit to its own record
  /// here, with `PlanController.setUnitData`.
  final Widget? Function(BuildContext context, PlanUnitDetail unit)?
      unitInspectorBuilder;

  /// The host's inspector for any one selected object (a unit, a placed
  /// symbol, an object of a kit's type such as a room): built under the
  /// property panel, in design mode, for exactly one selected root object
  /// that is not locked, with its [PlanObjectDetail] as
  /// `PlanController.objectDetailOf` reads it; null from it shows nothing.
  /// When [unitInspectorBuilder] is also given it keeps the units and this
  /// gets every other object; with only this one, it gets units too. Built
  /// when the selection becomes such an object and at each change of the
  /// plan; never on pan, zoom or hover. Hidden with the property panel. A
  /// host links the object to its own record here, with
  /// `PlanController.setObjectData`. A unit's section is read from
  /// `PlanController.unitDetails`.
  final Widget? Function(BuildContext context, PlanObjectDetail object)?
      objectInspectorBuilder;

  /// Whether the Layers section shows.
  final bool layerPanel;

  /// Whether the Page section shows.
  final bool pagePanel;

  /// Whether the right column follows the selection: with anything
  /// selected it shows the property panel and the host's inspectors only,
  /// the Layers and Page sections kept offstage with their state; with
  /// nothing selected, those sections too. False: every shown section at
  /// all times (0.9.0's column). The same on every layout, docked or in
  /// the right drawer.
  final bool contextualPanels;

  /// The canvas's rulers.
  final bool rulers;

  /// The canvas's grid.
  final bool grid;

  /// Whether object snap may act (and F3 and the OSNAP read-out exist).
  final bool snapping;

  /// The top bar.
  final PlanEditorBar bar;

  /// The host's New.
  final PlanFileCallback? onNew;

  /// The host's Open.
  final PlanFileCallback? onOpen;

  /// The host's Save.
  final PlanFileCallback? onSave;

  /// The host's Save As.
  final PlanFileCallback? onSaveAs;

  /// Receives Export's bytes; without it Export is not offered.
  final void Function(PlanExport export)? onExport;

  /// The host's export dialog, in place of the Material one.
  final PlanExportDialog? onExportDialog;

  /// Where an Export or Print flow's error goes.
  final void Function(Object error)? onPageFlowError;

  /// The platform's print dialog when null.
  final PagePrinter? printer;

  /// Exports are named `<exportName>.<extension>`.
  final String exportName;

  /// False binds no key at all: every key reaches the host.
  final bool shortcuts;

  /// Whether the canvas takes the focus when it is first built.
  final bool autofocus;

  /// A per-view theme over the ambient `PlanTheme`, field by field.
  final PlanTheme? theme;

  /// The service mode's bar; passed to the service view.
  final PlanServiceBar serviceBar;

  /// A tap on a labelled unit; passed to the service view.
  final void Function(String label)? onUnitTap;

  /// A double tap on a labelled unit; passed to the service view.
  final void Function(String label)? onUnitDoubleTap;

  /// A context menu asked on a labelled unit; passed to the service view.
  final void Function(String label, Offset globalPosition)? onUnitContextMenu;

  /// A tap on a member of a group; passed to the service view.
  final void Function(String groupId, String label)? onGroupTap;

  /// The labelled unit under the pointer, on change; passed to the service view.
  final void Function(String? label)? onUnitHover;

  /// The service bar's Merge; passed to the service view.
  final void Function(Set<String> labels)? onMergeRequested;

  /// The service bar's Split; passed to the service view.
  final void Function(String groupId)? onSplitRequested;

  /// After each drag in service; passed to the service view.
  final VoidCallback? onLayoutChanged;

  /// The units a drag moved, by detail; passed to the service view.
  final void Function(List<PlanUnitDetail> moved)? onUnitsMoved;

  /// A tap that missed every unit, in world millimetres; passed to the service view.
  final void Function(Offset world)? onFloorTap;

  /// What a long press on a unit does; passed to the service view.
  final PlanLongPress longPress;

  /// What a drag on the floor does; passed to the service view.
  final PlanFloorDrag floorDrag;

  /// False: no pan or zoom by the user in service; passed to the service view.
  final bool userCamera;

  /// The host's widget per labelled unit; passed to the service view.
  final PlanUnitOverlayBuilder? unitOverlayBuilder;

  /// Where the overlays sit; passed to the service view.
  final PlanOverlayLayout unitOverlayLayout;

  /// The modes that show the overlays; passed to the service view.
  final Set<PlanMode> unitOverlayModes;

  @override
  State<PlanEditor> createState() => _PlanEditorState();
}

enum _LeftTab { tools, symbols }

class _PlanEditorState extends State<PlanEditor> {
  late EditorPageFlows _flows = _flowsFor(widget.controller);

  /// The gallery's search text, kept across tab switches.
  final TextEditingController _symbolQuery = TextEditingController();

  _LeftTab _leftTab = _LeftTab.tools;

  /// The layout last built and the drawer open in it (phone, tablet).
  PlanEditorLayout? _builtLayout;
  PlanDrawerSide? _drawer;

  /// The document the relays and flags below are built over.
  Object? _bound;
  FrameSafeRelay? _status;
  FrameSafeRelay? _commandSources;
  _Flag? _idleFlag;
  _Flag? _exportFlag;
  _Flag? _printFlag;
  _Flag? _undoFlag;
  _Flag? _redoFlag;

  EditorPageFlows _flowsFor(PlanController c) => EditorPageFlows(
        controller: c,
        settings: () => (
          onExport: widget.onExport,
          printer: widget.printer ?? const PrintingPagePrinter(),
          exportName: widget.exportName,
        ),
        hooks: () => (
          exportDialog: widget.onExportDialog,
          onError: widget.onPageFlowError,
        ),
        unitColourOpacity: _unitColourOpacity,
      );

  /// The opacity an export or a print fills the units' colours at: the
  /// ambient extension with the editor's `theme` over it, else the
  /// editor's, else 0.35 (floor_plan_view.dart:540-546). A state gone
  /// meanwhile reads its own theme.
  double _unitColourOpacity() {
    final theme = mounted
        ? (Theme.of(context).extension<PlanTheme>()?.merge(widget.theme) ??
            widget.theme)
        : widget.theme;
    return theme?.unitColourOpacity ?? kUnitColourOpacity;
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onController);
    _listenPicks(widget.controller);
    _bind();
  }

  void _listenPicks(PlanController c) {
    c.activeTool.addListener(_onPick);
    c.armedSymbol.addListener(_onPick);
  }

  void _unlistenPicks(PlanController c) {
    c.activeTool.removeListener(_onPick);
    c.armedSymbol.removeListener(_onPick);
  }

  /// A tool or a symbol picked while the left drawer is open (phone and
  /// tablet) closes it, so the next touch on the canvas draws or places.
  void _onPick() {
    if (_drawer != PlanDrawerSide.left || !mounted) return;
    setState(() => _drawer = null);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    PlanLocaleScope.push(context, widget.controller);
  }

  @override
  void didUpdateWidget(PlanEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Every new widget is the host's rebuild: a new service view.
    _service = null;
    if (!identical(oldWidget.controller, widget.controller)) {
      // The new controller's camera is its own (floor_plan_view.dart:568).
      _laidOutMode = null;
      oldWidget.controller.removeListener(_onController);
      _unlistenPicks(oldWidget.controller);
      widget.controller.addListener(_onController);
      _listenPicks(widget.controller);
      _flows.dispose();
      _flows = _flowsFor(widget.controller);
      _bind();
      PlanLocaleScope.push(context, widget.controller);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    _unlistenPicks(widget.controller);
    _flows.dispose();
    _unbind();
    _symbolQuery.dispose();
    super.dispose();
  }

  /// A swapped document (its selection, tools and page are new) rebinds;
  /// new permissions rebuild the bar and the columns.
  void _onController() {
    if (!identical(_bound, widget.controller.document)) _bind();
    if (mounted) setState(() {});
  }

  void _bind() {
    _unbind();
    final c = widget.controller;
    _bound = c.document;
    _status = FrameSafeRelay(Listenable.merge([
      c.selection,
      c.toolController,
      c.activeTool,
      c.toolNotice,
      c.locale,
    ]));
    final sources = _commandSources = FrameSafeRelay(Listenable.merge([
      c.toolController,
      c.canUndo,
      c.canRedo,
      c.page,
      c.pageFlows.ready,
    ]));
    bool ready() => _idle && c.pageFlows.ready.value;
    _idleFlag = _Flag(sources, () => _idle);
    _exportFlag = _Flag(sources, () => ready() && exportRunnable(c));
    _printFlag = _Flag(sources, () => ready() && c.page.value != null);
    // The history read at each call, as today's DerivedFlag reads
    // `commands.canUndo` (planner_shell.dart:728-731); `canUndo` and
    // `canRedo` are only what tells it to look again.
    _undoFlag = _Flag(sources, () => _idle && c.document.commands.canUndo);
    _redoFlag = _Flag(sources, () => _idle && c.document.commands.canRedo);
  }

  void _unbind() {
    for (final f in [
      _idleFlag,
      _exportFlag,
      _printFlag,
      _undoFlag,
      _redoFlag
    ]) {
      f?.dispose();
    }
    _status?.dispose();
    _commandSources?.dispose();
    _idleFlag = _exportFlag = _printFlag = _undoFlag = _redoFlag = null;
    _status = _commandSources = null;
  }

  /// No tool is part-way through a shape (planner_shell.dart:714-718): a
  /// toolbar click is a pointer event no tool sees, so the commands wait.
  bool get _idle => !widget.controller.toolController.active.isMidShape;

  /// The host's [pick] of the current widget, after a settle.
  Future<void> Function() _file(
          PlanFileCallback? Function(PlanEditor w) pick) =>
      () async {
        final callback = pick(widget);
        if (callback == null) return;
        widget.controller.settlePendingInput();
        await callback();
      };

  List<_BarCommand> _fileCommands(PlanStrings s) {
    final w = widget;
    final permissions = w.controller.permissions;
    return [
      if (w.onNew != null)
        _BarCommand(
            id: 'new',
            label: s.newDocument,
            icon: Icons.note_add_outlined,
            shortcuts: kNewChords,
            enabled: _idleFlag!,
            run: _file((w) => w.onNew)),
      if (w.onOpen != null)
        _BarCommand(
            id: 'open',
            label: s.open,
            icon: Icons.folder_open_outlined,
            shortcuts: kOpenChords,
            enabled: _idleFlag!,
            run: _file((w) => w.onOpen)),
      if (w.onSave != null)
        _BarCommand(
            id: 'save',
            label: s.save,
            icon: Icons.save_outlined,
            shortcuts: kSaveChords,
            enabled: _idleFlag!,
            run: _file((w) => w.onSave)),
      if (w.onSaveAs != null)
        _BarCommand(
            id: 'save-as',
            label: s.saveAs,
            icon: Icons.save_as_outlined,
            shortcuts: kSaveAsChords,
            enabled: _idleFlag!,
            run: _file((w) => w.onSaveAs)),
      if (_flows.canExport && permissions.export)
        _BarCommand(
            id: 'export',
            label: s.exportEllipsis,
            icon: Icons.ios_share_outlined,
            shortcuts: kExportChords,
            enabled: _exportFlag!,
            run: () => _flows.export(context)),
      if (permissions.print)
        _BarCommand(
            id: 'print',
            label: s.printEllipsis,
            icon: Icons.print_outlined,
            shortcuts: kPrintChords,
            enabled: _printFlag!,
            run: () => _flows.print(context)),
    ];
  }

  List<_BarCommand> _editCommands(PlanStrings s) =>
      widget.controller.permissions.undo
          ? [
              _BarCommand(
                  id: 'undo',
                  label: s.undo,
                  icon: Icons.undo,
                  shortcuts: kUndoChords,
                  enabled: _undoFlag!,
                  run: () async => widget.controller.undo()),
              _BarCommand(
                  id: 'redo',
                  label: s.redo,
                  icon: Icons.redo,
                  shortcuts: kRedoChords,
                  enabled: _redoFlag!,
                  run: () async => widget.controller.redo()),
            ]
          : const [];

  static _BarCommand? _byId(List<_BarCommand> commands, String id) =>
      commands.where((c) => c.id == id).firstOrNull;

  /// [command] for `PlanShortcuts`: its chord invokes the command, which
  /// does nothing while it is disabled (the key is still consumed, S-26).
  static Future<void> Function()? _chord(_BarCommand? command) =>
      command == null ? null : () async => command.invoke();

  /// The toolbar for a host's [actions] (planner_shell.dart:1384-1412): the
  /// host's file commands first (New to Save As), then the buttons in the
  /// host's order, a run of file buttons (Export, Print) and a run of edit
  /// buttons (Undo, Redo) [_Toolbar.groupGap] apart. Null with no button.
  _Toolbar? _toolbarFor(List<PlanEditorAction> actions, List<_BarCommand> file,
      List<_BarCommand> edit) {
    const page = {'export', 'print'};
    final groups = <List<_BarCommand>>[
      [
        for (final c in file)
          if (!page.contains(c.id)) c
      ],
    ];
    bool? lastFile = groups.first.isEmpty ? null : true;
    for (final action in actions) {
      final (command, isFile) = switch (action) {
        PlanEditorAction.export => (_byId(file, 'export'), true),
        PlanEditorAction.print => (_byId(file, 'print'), true),
        PlanEditorAction.undo => (_byId(edit, 'undo'), false),
        PlanEditorAction.redo => (_byId(edit, 'redo'), false),
        _ => (null, false),
      };
      if (command == null) continue;
      if (isFile != lastFile) groups.add([]);
      lastFile = isFile;
      groups.last.add(command);
    }
    if (groups.every((g) => g.isEmpty)) return null;
    return _Toolbar(groups: groups);
  }

  /// The active tool's label, the selection's size when it is not empty,
  /// and the tool's notice when it has one (today's composition,
  /// planner_shell.dart:989-1011; spec 3a C1.2), the notice worded now, in
  /// the current language.
  String _statusLine(PlanStrings strings) {
    final c = widget.controller;
    final base = planToolLabel(context, c, c.activeTool.value);
    final n = c.selection.length;
    final line = n == 0 ? base : '$base — ${strings.selectedCount(n)}';
    final notice = c.toolNotice.value;
    return notice == null ? line : '$line — ${c.textOf(notice)}';
  }

  String _zoomLine(PlanStrings strings) {
    final c = widget.controller;
    final page = c.page.value;
    if (page == null) return '';
    final zoom = zoomOf(c.camera.value.scale, page, kLogicalPixelsPerMm);
    final scale = formatPanelNumber(page.scaleDenominator, strings);
    return '1:$scale · ${(zoom * 100).round()}%';
  }

  /// The top bar (planner_shell.dart:1278-1376 without the document name):
  /// the host's leading widgets; the toolbar; 16 px; the damaged warning
  /// and the status line, flexible; the read-outs; the host's trailing
  /// widgets. The host's widgets sit under the shortcut guard, never in
  /// the toolbar's `ExcludeFocus`.
  ///
  /// [first] and [last] are the compact layouts' drawer buttons, the bar's
  /// first and last items. With [phone] the status line and the read-outs
  /// are left out and the toolbar scrolls, so the bar fits 320 px.
  Widget _topBar(ColorScheme scheme, PlanStrings strings,
      List<_BarCommand> file, List<_BarCommand> edit,
      {Widget? first, Widget? last, bool phone = false}) {
    final c = widget.controller;
    final bar = widget.bar;
    final toolbar = listEquals(bar.actions, PlanEditorAction.values)
        ? (file.isEmpty && edit.isEmpty ? null : _Toolbar(groups: [file, edit]))
        : _toolbarFor(bar.actions, file, edit);
    final readOuts = <Widget>[];
    for (final action in bar.actions) {
      final readOut = switch (action) {
        PlanEditorAction.snap when !widget.snapping => null,
        PlanEditorAction.snap => ListenableBuilder(
            listenable: c.snap,
            builder: (_, __) => Text(
                c.snap.objectSnap
                    ? strings.objectSnapOn
                    : strings.objectSnapOff,
                key: const Key('osnap-text')),
          ),
        PlanEditorAction.zoom => ListenableBuilder(
            listenable: Listenable.merge([c.camera, c.page]),
            builder: (_, __) =>
                Text(_zoomLine(strings), key: const Key('zoom-text')),
          ),
        _ => null,
      };
      if (readOut == null) continue;
      if (readOuts.isNotEmpty) readOuts.add(const SizedBox(width: 16));
      readOuts.add(readOut);
    }
    final damagedIcon = ValueListenableBuilder<bool>(
      valueListenable: c.damaged,
      builder: (_, damaged, __) => damaged
          ? Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Tooltip(
                message: strings.planDamaged,
                child: Icon(Icons.warning_amber,
                    key: const Key('plan-damaged'),
                    size: 18,
                    color: scheme.error),
              ),
            )
          : const SizedBox.shrink(),
    );
    final row = phone
        ? Row(
            children: [
              if (first != null) first,
              ...bar.leading,
              damagedIcon,
              Expanded(
                child: toolbar == null
                    ? const SizedBox.shrink()
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal, child: toolbar),
              ),
              ...bar.trailing,
              if (last != null) last,
            ],
          )
        : Row(
            children: [
              if (first != null) first,
              ...bar.leading,
              if (toolbar != null) ...[toolbar, const SizedBox(width: 16)],
              Expanded(
                child: LayoutBuilder(builder: (_, constraints) {
                  // In a narrow window the 16 px before the read-outs shrinks
                  // with the free width, down to 0, so it never overflows.
                  final tail = math.min(16.0, constraints.maxWidth);
                  return Row(
                    children: [
                      damagedIcon,
                      Expanded(
                        child: ListenableBuilder(
                          listenable: _status!,
                          builder: (_, __) => Text(_statusLine(strings),
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
              ...readOuts,
              ...bar.trailing,
              if (last != null) last,
            ],
          );
    return Container(
      key: const Key('chrome-top'),
      height: 44,
      color: scheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: bar.leading.isEmpty && bar.trailing.isEmpty
            ? row
            : PlanShortcutGuard(controller: c, child: PlanHostSlot(child: row)),
      ),
    );
  }

  /// A loaded kit has a symbol source and the host offers the gallery.
  bool get _gallery =>
      widget.gallery &&
      widget.controller.kits.kits.any((k) => k.symbols.isNotEmpty);

  /// The left column holds more than the Select row (spec S-13): the
  /// Symbols tab, or a palette with another allowed tool.
  bool get _leftShown {
    final c = widget.controller;
    if (_gallery) return true;
    if (!widget.toolPalette) return false;
    final ids = [
      for (final g in genericTools) g.id,
      for (final k in c.kits.kits)
        for (final t in k.tools) t.id,
    ];
    return ids.any((id) =>
        id != PlanToolIds.select &&
        id != PlanToolIds.symbol &&
        c.permissions.allowsTool(id));
  }

  PlanSymbolGallery _galleryOf(PlanController c) => PlanSymbolGallery(
      controller: c, filter: widget.symbolFilter, query: _symbolQuery);

  /// The palette alone, the gallery alone (no palette offered), or the
  /// Tools and Symbols tabs over the chosen one (planner_shell.dart:
  /// 1222-1276). The strip never takes focus; switching tabs changes no
  /// tool.
  Widget _leftPanel(PlanStrings strings) {
    final c = widget.controller;
    if (!_gallery) return PlanToolPalette(controller: c);
    if (!widget.toolPalette) return _galleryOf(c);
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
                    label: Text(strings.tabTools, key: const Key('tab-tools'))),
                ButtonSegment(
                    value: _LeftTab.symbols,
                    label: Text(strings.tabSymbols,
                        key: const Key('tab-symbols'))),
              ],
              selected: {_leftTab},
              onSelectionChanged: (s) => setState(() => _leftTab = s.single),
            ),
          ),
        ),
        Expanded(
          child: switch (_leftTab) {
            _LeftTab.tools => PlanToolPalette(controller: c),
            _LeftTab.symbols => _galleryOf(c),
          },
        ),
      ],
    );
  }

  /// A right-column panel: shown while [shown]; otherwise kept offstage,
  /// its state kept, and out of the focus order.
  static Widget _kept(bool shown, Widget panel) =>
      Visibility(visible: shown, maintainState: true, child: panel);

  // ---- The service mode ----

  /// The PlanServiceView handed down, made once per widget the host hands
  /// in: the editor's own rebuilds hand the same one, so they build no
  /// overlay (G-5).
  PlanServiceView? _service;

  /// The design canvas's overlay layer, likewise.
  PlanEditor? _overlaysOf;
  Widget? _designLayer;

  PlanServiceView _serviceView() => _service ??= PlanServiceView(
        controller: widget.controller,
        breakpoints: widget.breakpoints,
        layout: widget.layout,
        serviceSidePanel: widget.serviceSidePanel,
        bar: widget.serviceBar,
        onUnitTap: widget.onUnitTap,
        onUnitDoubleTap: widget.onUnitDoubleTap,
        onUnitContextMenu: widget.onUnitContextMenu,
        onGroupTap: widget.onGroupTap,
        onUnitHover: widget.onUnitHover,
        onMergeRequested: widget.onMergeRequested,
        onSplitRequested: widget.onSplitRequested,
        onLayoutChanged: widget.onLayoutChanged,
        onUnitsMoved: widget.onUnitsMoved,
        onFloorTap: widget.onFloorTap,
        longPress: widget.longPress,
        floorDrag: widget.floorDrag,
        userCamera: widget.userCamera,
        shortcuts: widget.shortcuts,
        autofocus: widget.autofocus,
        unitOverlayBuilder: widget.unitOverlayBuilder,
        unitOverlayLayout: widget.unitOverlayLayout,
        unitOverlayModes: widget.unitOverlayModes,
        onExport: widget.onExport,
        onExportDialog: widget.onExportDialog,
        onPageFlowError: widget.onPageFlowError,
        printer: widget.printer,
        exportName: widget.exportName,
        theme: widget.theme,
      );

  Widget? _designOverlays() {
    final w = widget;
    if (!identical(w, _overlaysOf)) {
      _overlaysOf = w;
      final builder = w.unitOverlayBuilder;
      _designLayer =
          builder == null || !w.unitOverlayModes.contains(PlanMode.design)
              ? null
              : UnitOverlayLayer(
                  controller: w.controller,
                  builder: builder,
                  layout: w.unitOverlayLayout);
    }
    return _designLayer;
  }

  // ---- R-13 (floor_plan_view.dart:327-500) ----

  /// The plan last measured: each plan shown, a mode's or a new copy's,
  /// is measured once, after its first frame.
  DraftDocument? _measuredFor;

  void _measureAfterFrame(PlanMode shown, DraftDocument document) {
    if (identical(_measuredFor, document)) return;
    _measuredFor = document;
    final c = widget.controller;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(c, widget.controller)) return;
      final origin = _canvasOrigin();
      if (origin != null) {
        c.canvasMeasured(shown, origin, chrome: _chromeOrigin(shown));
      }
    });
  }

  /// The service bar's height under this editor's resolved theme.
  double _serviceBarHeight = kServiceBarHeight;

  /// Where [mode]'s canvas starts in this editor by its chrome alone.
  Offset _chromeOrigin(PlanMode mode) {
    switch (mode) {
      case PlanMode.service:
        return Offset(0, widget.serviceBar.visible ? _serviceBarHeight : 0);
      case PlanMode.design:
        final ruler = widget.rulers ? kRulerThickness : 0.0;
        final left = _leftShown ? 240.0 : 0.0;
        final top = widget.bar.visible ? 44.0 : 0.0;
        return Offset(left + ruler, top + ruler);
    }
  }

  /// At each build and each change of the theme: the mode not shown is
  /// assumed from its chrome; the shown one is kept in place. A changed
  /// service bar height while service shows moves the canvas with the plan
  /// (today's S-10); the canvas is measured again after the frame.
  void _assumeCanvases(PlanTheme? theme) {
    final height = theme?.serviceBarHeight ?? kServiceBarHeight;
    final moved = height != _serviceBarHeight;
    _serviceBarHeight = height;
    final c = widget.controller;
    for (final mode in PlanMode.values) {
      if (mode != c.mode.value) c.canvasAssumed(mode, _chromeOrigin(mode));
    }
    _keepPlanInPlace();
    if (moved && c.mode.value == PlanMode.service) _scheduleCanvasMoved();
  }

  PlanMode? _laidOutMode;
  Offset _laidOutChrome = Offset.zero;

  /// When the shown mode's chrome changes (a bar, the left column or the
  /// rulers shown or hidden), the camera pans by the canvas origin's move,
  /// so the plan keeps its place from the frame that lays the new chrome
  /// out. The theme's bar height is not compensated.
  void _keepPlanInPlace() {
    final c = widget.controller;
    final mode = c.mode.value;
    final chrome = _chromeOrigin(mode);
    final lastMode = _laidOutMode;
    var last = _laidOutChrome;
    if (mode == PlanMode.service && last.dy != 0) {
      last = Offset(0, _serviceBarHeight);
    }
    _laidOutMode = mode;
    _laidOutChrome = chrome;
    if (lastMode != mode || last == chrome) return;
    c.chromeMoved(last, chrome);
  }

  PlanMode? _shown;
  (bool, bool, bool, bool)? _chrome;
  bool _canvasMoveDue = false;

  /// After the frame that lays out other chrome than the last, the shown
  /// canvas is measured again.
  void _measureChrome() {
    final chrome = (
      widget.serviceBar.visible,
      widget.bar.visible,
      widget.rulers,
      _leftShown,
    );
    final last = _chrome;
    _chrome = chrome;
    if (last == null || last == chrome) return;
    _scheduleCanvasMoved();
  }

  void _scheduleCanvasMoved() {
    if (_canvasMoveDue) return;
    _canvasMoveDue = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _canvasMoveDue = false;
      _canvasMoved();
    });
  }

  void _canvasMoved() {
    final c = widget.controller;
    final shown = _shown;
    if (!mounted || shown == null || c.mode.value != shown) return;
    final origin = _canvasOrigin();
    if (origin != null) {
      c.canvasMeasured(shown, origin, chrome: _chromeOrigin(shown));
    }
  }

  /// The shown canvas's top left (its interaction layer's) in this editor.
  Offset? _canvasOrigin() {
    final view = context.findRenderObject();
    if (view is! RenderBox || !view.attached) return null;
    RenderBox? canvas;
    void visit(Element e) {
      if (canvas != null) return;
      if (e.widget is InteractionLayer) {
        final r = e.findRenderObject();
        if (r is RenderBox && r.attached && r.hasSize) canvas = r;
        return;
      }
      e.visitChildElements(visit);
    }

    context.visitChildElements(visit);
    return canvas?.localToGlobal(Offset.zero, ancestor: view);
  }

  @override
  Widget build(BuildContext context) => PlanShadScope(child: _body(context));

  Widget _body(BuildContext context) {
    validatePlanEditorBar(widget.bar);
    validatePlanServiceBar(widget.serviceBar);
    if (widget.unitOverlayBuilder != null) {
      validatePlanOverlayLayout(widget.unitOverlayLayout);
    }
    _measureChrome();
    // The theme reader rebuilds alone on a theme change, handing back the
    // same child, so no overlay is built again (G-5); the modes are built
    // below it, after it assumed the canvases (floor_plan_view.dart:675-684).
    return PlanThemeScope(
      view: widget.theme,
      child: _ChromeOrigins(
        onTheme: _assumeCanvases,
        child: Builder(builder: _modes),
      ),
    );
  }

  Widget _modes(BuildContext context) {
    final c = widget.controller;
    final mode = c.mode.value;
    _shown = mode;
    // Design's drawer does not outlive design (SL4).
    if (mode == PlanMode.service) _drawer = null;
    _measureAfterFrame(mode, c.activeDocument);
    _keepPlanInPlace();
    return mode == PlanMode.service ? _serviceView() : _editor(context);
  }

  /// The design mode in the layout the editor's width (or `layout`) gives.
  /// Desktop is 2a's docked tree, unchanged; phone and tablet are in
  /// editor_layout.dart's terms (spec D1-D5).
  Widget _editor(BuildContext context) {
    final forced = widget.layout;
    if (forced == PlanEditorLayout.desktop) return _docked(context);
    return LayoutBuilder(builder: (context, constraints) {
      final layout =
          forced ?? widget.breakpoints.layoutFor(constraints.maxWidth);
      // A layout change closes the drawer (EL6); the selection is not
      // touched.
      if (layout != _builtLayout) {
        _builtLayout = layout;
        _drawer = null;
      }
      return layout == PlanEditorLayout.desktop
          ? _docked(context)
          : _compact(context, layout);
    });
  }

  void _toggleDrawer(PlanDrawerSide side) =>
      setState(() => _drawer = _drawer == side ? null : side);

  bool get _rightShown =>
      widget.propertyPanel || widget.layerPanel || widget.pagePanel;

  /// The phone's and the tablet's editor: the bar, the canvas under the
  /// drawers, and on a tablet the tool strip docked at the left.
  Widget _compact(BuildContext context, PlanEditorLayout layout) {
    final c = widget.controller;
    final scheme = Theme.of(context).colorScheme;
    final strings = PlanStrings.of(context);
    final file = _fileCommands(strings);
    final edit = _editCommands(strings);
    final phone = layout == PlanEditorLayout.phone;
    Widget button(String key, IconData icon, String tip, PlanDrawerSide side) =>
        ExcludeFocus(
          child: IconButton(
            key: Key(key),
            tooltip: tip,
            icon: Icon(icon),
            iconSize: 20,
            visualDensity: VisualDensity.compact,
            isSelected: _drawer == side,
            onPressed: () => _toggleDrawer(side),
          ),
        );
    final strip = !phone && _leftShown;
    return PlanShortcuts(
      controller: c,
      shortcuts: widget.shortcuts,
      onNew: _chord(_byId(file, 'new')),
      onOpen: _chord(_byId(file, 'open')),
      onSave: _chord(_byId(file, 'save')),
      onSaveAs: _chord(_byId(file, 'save-as')),
      onExport: _chord(_byId(file, 'export')),
      onPrint: _chord(_byId(file, 'print')),
      child: Scaffold(
        body: Column(
          children: [
            if (widget.bar.visible)
              _topBar(scheme, strings, file, edit,
                  phone: phone,
                  first: phone && _leftShown
                      ? button('chrome-left-button', Icons.menu,
                          strings.openToolsPanel, PlanDrawerSide.left)
                      : null,
                  last: _rightShown
                      ? button('chrome-right-button', Icons.tune,
                          strings.openPropertiesPanel, PlanDrawerSide.right)
                      : null),
            Expanded(
              child: Row(
                children: [
                  if (strip)
                    Container(
                      key: const Key('chrome-tool-strip'),
                      width: 56,
                      color: scheme.surfaceContainerLow,
                      child: Column(
                        children: [
                          Expanded(
                              child: widget.toolPalette
                                  ? PlanToolPalette(
                                      controller: c, compact: true)
                                  : const SizedBox.shrink()),
                          if (_gallery)
                            ExcludeFocus(
                              child: IconButton(
                                key: const Key('chrome-symbols-button'),
                                tooltip: strings.tabSymbols,
                                icon: const Icon(Icons.category_outlined),
                                isSelected: _drawer == PlanDrawerSide.left,
                                onPressed: () =>
                                    _toggleDrawer(PlanDrawerSide.left),
                              ),
                            ),
                        ],
                      ),
                    ),
                  Expanded(
                    key: const Key('chrome-canvas'),
                    child: PlanDrawerHost(
                      open: _drawer,
                      onClose: () => setState(() => _drawer = null),
                      left: phone
                          ? (_leftShown ? _leftPanel(strings) : null)
                          : (_gallery ? _galleryOf(c) : null),
                      right: _rightShown ? _rightColumn(c) : null,
                      canvas: PlanCanvas(
                        controller: c,
                        rulers: widget.rulers,
                        grid: widget.grid,
                        snapping: widget.snapping,
                        autofocus: widget.autofocus,
                        unitOverlays: _designOverlays(),
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

  /// The right column's content, docked or in its drawer.
  Widget _rightColumn(PlanController c) => PlanShortcutGuard(
        controller: c,
        child: SingleChildScrollView(
          key: const Key('chrome-right-scroll'),
          child: Column(
            children: [
              _kept(widget.propertyPanel, PlanPropertyPanel(controller: c)),
              // Spec S4: the host's inspector under the panel's fields,
              // with the panel. Keyed, so adding or removing it keeps the
              // panels below.
              if (widget.unitInspectorBuilder case final inspect?
                  when widget.propertyPanel)
                UnitInspector(
                    key: const Key('unit-inspector'),
                    controller: c,
                    builder: inspect),
              if (widget.objectInspectorBuilder case final inspect?
                  when widget.propertyPanel)
                ObjectInspector(
                    key: const Key('object-inspector'),
                    controller: c,
                    unitsElsewhere: widget.unitInspectorBuilder != null,
                    builder: inspect),
              SelectionGate(
                controller: c,
                builder: (context, selected) {
                  final shown = !(widget.contextualPanels && selected);
                  return Column(children: [
                    _kept(widget.layerPanel && shown,
                        PlanLayerPanel(controller: c)),
                    _kept(widget.pagePanel && shown,
                        PlanPagePanel(controller: c)),
                  ]);
                },
              ),
            ],
          ),
        ),
      );

  /// 2a's editor: the shortcuts, the bar, the columns and the canvas.
  Widget _docked(BuildContext context) {
    final c = widget.controller;
    final scheme = Theme.of(context).colorScheme;
    final strings = PlanStrings.of(context);
    final file = _fileCommands(strings);
    final edit = _editCommands(strings);
    return PlanShortcuts(
      controller: c,
      shortcuts: widget.shortcuts,
      onNew: _chord(_byId(file, 'new')),
      onOpen: _chord(_byId(file, 'open')),
      onSave: _chord(_byId(file, 'save')),
      onSaveAs: _chord(_byId(file, 'save-as')),
      onExport: _chord(_byId(file, 'export')),
      onPrint: _chord(_byId(file, 'print')),
      child: Scaffold(
        body: Column(
          children: [
            if (widget.bar.visible) _topBar(scheme, strings, file, edit),
            Expanded(
              child: Row(
                children: [
                  if (_leftShown)
                    Container(
                      key: const Key('chrome-left'),
                      width: 240,
                      color: scheme.surfaceContainerLow,
                      child: _leftPanel(strings),
                    ),
                  // Keyed: when the columns on both sides come or go at
                  // once, the row still matches the canvas, so the
                  // camera and the user's zoom stay.
                  Expanded(
                    key: const Key('chrome-canvas'),
                    child: PlanCanvas(
                      controller: c,
                      rulers: widget.rulers,
                      grid: widget.grid,
                      snapping: widget.snapping,
                      autofocus: widget.autofocus,
                      unitOverlays: _designOverlays(),
                    ),
                  ),
                  if (_rightShown)
                    Container(
                      key: const Key('chrome-right'),
                      width: 280,
                      color: scheme.surfaceContainerLow,
                      child: _rightColumn(c),
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

/// One command of the bar (shell_commands.dart:61-133): invoked only
/// through [invoke], by its button and its chords alike; a disabled
/// command's chord stays bound and does nothing.
@immutable
final class _BarCommand {
  const _BarCommand({
    required this.id,
    required this.label,
    required this.icon,
    this.shortcuts = const <SingleActivator>[],
    required this.enabled,
    required this.run,
  });

  /// The button's key is `toolbar-<id>`.
  final String id;
  final String label;
  final IconData icon;
  final List<SingleActivator> shortcuts;
  final ValueListenable<bool> enabled;
  final Future<void> Function() run;

  /// The label and the first chord's glyph on [platform] (`⌘S` on macOS,
  /// `Ctrl+S` elsewhere, the modifiers in the UI's language).
  String tooltipFor(TargetPlatform platform,
      {String control = 'Ctrl', String shift = 'Shift'}) {
    if (shortcuts.isEmpty) return label;
    final chord = shortcuts.first;
    final key = chord.trigger.keyLabel;
    final glyph = platform == TargetPlatform.macOS
        ? '⌘${chord.shift ? '⇧' : ''}$key'
        : '$control+${chord.shift ? '$shift+' : ''}$key';
    return '$label ($glyph)';
  }

  void invoke() {
    if (!enabled.value) return;
    unawaited(run());
  }
}

/// The toolbar (document_toolbar.dart:23-98): one icon button per command,
/// keyed `toolbar-<id>`, a [groupGap] between two non-empty groups. It
/// never takes focus and sits inside a [TextFieldTapRegion], so a press is
/// not a tap outside an open text entry.
class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.groups});

  final List<List<_BarCommand>> groups;

  static const double groupGap = 12;

  @override
  Widget build(BuildContext context) {
    final strings = PlanStrings.of(context);
    final children = <Widget>[];
    for (final group in groups) {
      if (group.isEmpty) continue;
      if (children.isNotEmpty) children.add(const SizedBox(width: groupGap));
      for (final c in group) {
        children.add(ValueListenableBuilder<bool>(
          valueListenable: c.enabled,
          builder: (context, enabled, _) => IconButton(
            key: Key('toolbar-${c.id}'),
            tooltip: c.tooltipFor(defaultTargetPlatform,
                control: strings.controlKey, shift: strings.shiftKey),
            icon: Icon(c.icon),
            iconSize: 20,
            visualDensity: VisualDensity.compact,
            onPressed: enabled ? c.invoke : null,
          ),
        ));
      }
    }
    return TextFieldTapRegion(
      child: ExcludeFocus(
        child: Material(
          color: Colors.transparent,
          child: Row(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}

/// A flag computed from other state (shell_commands.dart:129-169): its
/// value is [_compute]'s answer at the read; listeners hear when that
/// answer changes.
final class _Flag extends ChangeNotifier implements ValueListenable<bool> {
  _Flag(this._source, this._compute) {
    _last = _compute();
    _source.addListener(_update);
  }

  final Listenable _source;
  final bool Function() _compute;
  late bool _last;

  @override
  bool get value => _compute();

  void _update() {
    final now = _compute();
    if (now == _last) return;
    _last = now;
    notifyListeners();
  }

  @override
  void dispose() {
    _source.removeListener(_update);
    super.dispose();
  }
}

/// Reads the resolved theme for [onTheme] at each build of the editor and
/// each change of the theme, and builds [child] as given
/// (floor_plan_view.dart:758-773).
class _ChromeOrigins extends StatelessWidget {
  const _ChromeOrigins({required this.onTheme, required this.child});

  final void Function(PlanTheme? theme) onTheme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    onTheme(PlanThemeScope.of(context));
    return child;
  }
}
