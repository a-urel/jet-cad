// Host embedding API spec C-5 (Slice 4 plan, Task 4; S-6, S-12, S-13,
// S-23): what the editor lets its user do. The default is today's editor,
// field for field; two profiles cut it down for a host that embeds the
// editor to place tables, or to show the plan only.
import 'package:flutter/foundation.dart'
    show immutable, internal, listEquals, setEquals;

import '../symbols/symbol_library.dart';

/// The editor's tools (host embedding API spec C-3, C-5, S-6): the tool
/// palette's rows in its order, then the symbol placement tool, which the
/// Symbols tab arms.
enum FloorPlanTool {
  select,
  line,
  polyline,
  rectangle,
  box,
  wall,
  door,
  window,
  gap,
  room,
  separator,
  dimension,
  circle,
  arc,
  text,
  symbol,
}

/// One symbol of the editor's library (host embedding API spec C-5), as a
/// [FloorPlanEditorCapabilities.symbolFilter] sees it.
///
/// - [key]: the library's key, stable across versions and languages.
/// - [name]: the library's stored (English) name (spec S-23), stable for a
///   filter; the palette shows the UI language's words.
/// - [category]: the library's category, as stored.
/// - [tags]: the library's tags.
/// - [seats]: how many it seats, or null when it is not a table.
@immutable
final class FloorPlanSymbol {
  const FloorPlanSymbol({
    required this.key,
    required this.name,
    required this.category,
    this.tags = const <String>[],
    this.seats,
  });

  /// [entry] as a host sees it; its tags unmodifiable.
  @internal
  factory FloorPlanSymbol.of(SymbolEntry entry) => FloorPlanSymbol(
      key: entry.key,
      name: entry.name,
      category: entry.category,
      tags: List.unmodifiable(entry.tags),
      seats: entry.seats);

  final String key;
  final String name;
  final String category;
  final List<String> tags;
  final int? seats;

  @override
  bool operator ==(Object other) =>
      other is FloorPlanSymbol &&
      other.key == key &&
      other.name == name &&
      other.category == category &&
      listEquals(other.tags, tags) &&
      other.seats == seats;

  @override
  int get hashCode =>
      Object.hash(key, name, category, Object.hashAll(tags), seats);

  @override
  String toString() => 'FloorPlanSymbol($key, name: $name, '
      'category: $category, tags: [${tags.join(', ')}]'
      '${seats == null ? '' : ', seats: $seats'})';
}

/// What the editor (the design mode) lets its user do (host embedding API
/// spec C-5). [full], the default, is today's editor; [tablesOnly] is the
/// profile for a host whose user places and arranges tables, [readOnly]
/// for one whose user only looks at the plan (spec S-12 lists their
/// fields).
///
/// - [tools]: the tools offered, as palette rows, letters and
///   `FloorPlanController.selectTool`; it must hold [FloorPlanTool.select]
///   (an [ArgumentError] naming `tools` when the view builds). The symbol
///   tool needs [symbolPalette] too. [copyWith] copies the set it is given,
///   unmodifiable; the `const` constructor cannot copy, so it keeps the set
///   as given, and the view takes its own copy of each value it is handed:
///   a host that changes its set afterwards changes nothing the editor
///   has, until it hands the view a new value.
/// - [symbolPalette]: the Symbols tab; [symbolFilter], when given, the
///   symbols it offers and searches. It is compared by `==`: a closure
///   written in `build` is a new value at each build, which re-applies the
///   capabilities (cheaply); a static function or a method tear-off is
///   equal to itself.
/// - [selectionPanel], [layerPanel], [pagePanel]: the right column's
///   panels (a hidden one keeps its state; with none, no column);
///   [editLayers], [editPage]: whether the Layer and Page panels edit
///   (refused, their controls are disabled and their values shown).
/// - [selectTablesOnly]: a click (inside a table's top, else its box,
///   within the mouse's pick tolerance or a finger's reach) and a rubber
///   band select tables only, never one on a hidden or locked layer; a
///   change to it keeps only the tables of the selection and cancels a
///   click, drag or band under way.
/// - [move], [rotate], [mirror], [reshape], [delete], [renumber],
///   [changeLayer]: which of the selection's edits the user may make;
///   [reshape] names an object's own fields too (a box's, a wall's, an
///   opening's, a room's, a dimension's) and Change size. A refused button
///   or menu (Mirror, ±90, a door's flips, the Size menu, the layer
///   picker) is not shown; a refused value field is shown read-only. A
///   drag whose flag is refused before it ends is cancelled: it executes
///   nothing. [rotate] and [mirror] also bound the symbol tool: its `R`
///   and `M`, and the turn and mirror of a placement, which are not used
///   while refused.
/// - [undo] (Undo and Redo), [export], [print]: the top bar's buttons and
///   their chords.
/// - [rulers], [grid]: the drafting aids; [snapping]: object snap for the
///   editor's tools and drags, its F3 key and its OSNAP read-out. The
///   user's own setting is kept while it is false.
///
/// It is the editor's alone: the selection mode is governed by the view's
/// own parameters (spec S-22). A host's own controller calls
/// (`setTableData`, `undo()`, `load`, `exportPlan`) stay allowed under
/// every value. Changing it at runtime takes effect at the next build: a
/// tool no longer allowed falls back to select, and the left tab, the
/// symbol search and the hidden panels keep their state.
@immutable
final class FloorPlanEditorCapabilities {
  const FloorPlanEditorCapabilities({
    this.tools = _everyTool,
    this.symbolPalette = true,
    this.symbolFilter,
    this.selectionPanel = true,
    this.layerPanel = true,
    this.pagePanel = true,
    this.editLayers = true,
    this.editPage = true,
    this.selectTablesOnly = false,
    this.move = true,
    this.rotate = true,
    this.mirror = true,
    this.reshape = true,
    this.delete = true,
    this.renumber = true,
    this.changeLayer = true,
    this.undo = true,
    this.export = true,
    this.print = true,
    this.rulers = true,
    this.grid = true,
    this.snapping = true,
  });

  /// Today's editor: every tool, every flag true, no filter.
  static const FloorPlanEditorCapabilities full = FloorPlanEditorCapabilities();

  /// Tables only (spec C-5, S-12): the Select tool and the Symbols tab,
  /// filtered to the tables (`seats != null`); a click and a band select
  /// tables; move, rotate, delete, renumber and undo; no mirror, reshape or
  /// layer change; no Layer or Page panel. Export, print, the rulers, the
  /// grid and snapping stay.
  static const FloorPlanEditorCapabilities tablesOnly =
      FloorPlanEditorCapabilities(
    tools: {FloorPlanTool.select, FloorPlanTool.symbol},
    symbolFilter: _isTable,
    layerPanel: false,
    pagePanel: false,
    editLayers: false,
    editPage: false,
    selectTablesOnly: true,
    mirror: false,
    reshape: false,
    changeLayer: false,
  );

  /// Read only (spec C-5, S-12): select, pan and zoom; the panels shown;
  /// every edit flag false. Export, print, the rulers, the grid
  /// and snapping stay: none is an edit.
  static const FloorPlanEditorCapabilities readOnly =
      FloorPlanEditorCapabilities(
    tools: {FloorPlanTool.select},
    symbolPalette: false,
    editLayers: false,
    editPage: false,
    move: false,
    rotate: false,
    mirror: false,
    reshape: false,
    delete: false,
    renumber: false,
    changeLayer: false,
    undo: false,
  );

  /// [tablesOnly]'s filter: a symbol that seats is a table. A static
  /// function, so the profile is `const`.
  static bool _isTable(FloorPlanSymbol symbol) => symbol.seats != null;

  static const Set<FloorPlanTool> _everyTool = {
    FloorPlanTool.select,
    FloorPlanTool.line,
    FloorPlanTool.polyline,
    FloorPlanTool.rectangle,
    FloorPlanTool.box,
    FloorPlanTool.wall,
    FloorPlanTool.door,
    FloorPlanTool.window,
    FloorPlanTool.gap,
    FloorPlanTool.room,
    FloorPlanTool.separator,
    FloorPlanTool.dimension,
    FloorPlanTool.circle,
    FloorPlanTool.arc,
    FloorPlanTool.text,
    FloorPlanTool.symbol,
  };

  final Set<FloorPlanTool> tools;
  final bool symbolPalette;
  final bool Function(FloorPlanSymbol symbol)? symbolFilter;
  final bool selectionPanel, layerPanel, pagePanel;
  final bool editLayers, editPage;
  final bool selectTablesOnly;
  final bool move, rotate, mirror, reshape, delete, renumber, changeLayer;
  final bool undo, export, print;
  final bool rulers, grid, snapping;

  /// A copy with the given fields replaced; a null argument keeps the
  /// field, so `copyWith(symbolFilter: null)` keeps the filter: start from
  /// [full] to have none. A given [tools] is copied, unmodifiable.
  FloorPlanEditorCapabilities copyWith({
    Set<FloorPlanTool>? tools,
    bool? symbolPalette,
    bool Function(FloorPlanSymbol symbol)? symbolFilter,
    bool? selectionPanel,
    bool? layerPanel,
    bool? pagePanel,
    bool? editLayers,
    bool? editPage,
    bool? selectTablesOnly,
    bool? move,
    bool? rotate,
    bool? mirror,
    bool? reshape,
    bool? delete,
    bool? renumber,
    bool? changeLayer,
    bool? undo,
    bool? export,
    bool? print,
    bool? rulers,
    bool? grid,
    bool? snapping,
  }) =>
      FloorPlanEditorCapabilities(
        tools: tools == null ? this.tools : Set.unmodifiable(tools),
        symbolPalette: symbolPalette ?? this.symbolPalette,
        symbolFilter: symbolFilter ?? this.symbolFilter,
        selectionPanel: selectionPanel ?? this.selectionPanel,
        layerPanel: layerPanel ?? this.layerPanel,
        pagePanel: pagePanel ?? this.pagePanel,
        editLayers: editLayers ?? this.editLayers,
        editPage: editPage ?? this.editPage,
        selectTablesOnly: selectTablesOnly ?? this.selectTablesOnly,
        move: move ?? this.move,
        rotate: rotate ?? this.rotate,
        mirror: mirror ?? this.mirror,
        reshape: reshape ?? this.reshape,
        delete: delete ?? this.delete,
        renumber: renumber ?? this.renumber,
        changeLayer: changeLayer ?? this.changeLayer,
        undo: undo ?? this.undo,
        export: export ?? this.export,
        print: print ?? this.print,
        rulers: rulers ?? this.rulers,
        grid: grid ?? this.grid,
        snapping: snapping ?? this.snapping,
      );

  /// The flags, in declaration order, by name.
  List<(String, bool)> get _flags => [
        ('symbolPalette', symbolPalette),
        ('selectionPanel', selectionPanel),
        ('layerPanel', layerPanel),
        ('pagePanel', pagePanel),
        ('editLayers', editLayers),
        ('editPage', editPage),
        ('selectTablesOnly', selectTablesOnly),
        ('move', move),
        ('rotate', rotate),
        ('mirror', mirror),
        ('reshape', reshape),
        ('delete', delete),
        ('renumber', renumber),
        ('changeLayer', changeLayer),
        ('undo', undo),
        ('export', export),
        ('print', print),
        ('rulers', rulers),
        ('grid', grid),
        ('snapping', snapping),
      ];

  @override
  bool operator ==(Object other) =>
      other is FloorPlanEditorCapabilities &&
      setEquals(other.tools, tools) &&
      other.symbolFilter == symbolFilter &&
      listEquals([for (final (_, v) in other._flags) v],
          [for (final (_, v) in _flags) v]);

  @override
  int get hashCode => Object.hash(Object.hashAllUnordered(tools), symbolFilter,
      Object.hashAll([for (final (_, v) in _flags) v]));

  /// The fields that differ from [full], as `name: value`; the tools in
  /// the palette's order.
  @override
  String toString() {
    final full = FloorPlanEditorCapabilities.full;
    final fullFlags = {for (final (n, v) in full._flags) n: v};
    return 'FloorPlanEditorCapabilities(${[
      if (!setEquals(tools, full.tools))
        'tools: {${[
          for (final t in FloorPlanTool.values)
            if (tools.contains(t)) t.name
        ].join(', ')}}',
      if (symbolFilter != null) 'symbolFilter: given',
      for (final (n, v) in _flags)
        if (v != fullFlags[n]) '$n: $v',
    ].join(', ')})';
  }
}

/// Throws an [ArgumentError] naming `tools` for capabilities whose tools
/// lack [FloorPlanTool.select] (spec S-12); called when the view builds.
void validateEditorCapabilities(FloorPlanEditorCapabilities capabilities) {
  if (!capabilities.tools.contains(FloorPlanTool.select)) {
    throw ArgumentError.value(capabilities.tools, 'tools',
        'must hold FloorPlanTool.select, the tool every other falls back to');
  }
}

/// Whether the editor's left column is built (spec S-13): only while it
/// holds more than the Select row, that is a Symbols tab ([symbols]: the
/// shell has a library loader, which a view always gives) or another tool.
bool leftColumnShown(FloorPlanEditorCapabilities capabilities,
        {required bool symbols}) =>
    (symbols && capabilities.symbolPalette) ||
    capabilities.tools
        .any((t) => t != FloorPlanTool.select && t != FloorPlanTool.symbol);
