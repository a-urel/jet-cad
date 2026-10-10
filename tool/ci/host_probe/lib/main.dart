// The external-host probe (spec 14d P6) and the host guide's source
// (P2): a small point-of-sale screen that depends on the planner and the
// restaurant library by git, from outside the workspace, through their
// public barrels only. CI resolves, analyses and builds it at the commit it
// tests; tool/ci/check_guide.dart checks that every Dart snippet of
// docs/host-guide.md is in this file, so the guide's code compiles.
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show BrowserContextMenu, HardwareKeyboard, KeyDownEvent, LogicalKeyboardKey;
import 'package:jet_cad_floor_plan/jet_cad_floor_plan.dart';
import 'package:jet_cad_restaurant_symbols/jet_cad_restaurant_symbols.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await ensureFloorPlanFonts();
  } catch (error, stack) {
    // The plans then measure in the platform's font; the POS still starts.
    FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack));
  }
  registerFontLicences();
  if (kIsWeb) await BrowserContextMenu.disableContextMenu();
  runApp(PosApp(store: MemoryStore()));
}

/// Where the POS keeps its text: a database, files, a server. The planner
/// never stores anything itself.
abstract interface class PosStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class MemoryStore implements PosStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

/// The floor plan's look in the POS's light theme: bold captions in the
/// planner's own Roboto, fills a little lighter, group frames in the
/// POS's primary (the chips follow the frame), rounder chips, the POS's
/// muted colour around the page, a taller service bar and the POS's
/// accent for the selection, per paper.
const FloorPlanTheme floorLookLight = FloorPlanTheme(
  statusCaptionStyle: TextStyle(
      fontFamily: 'Roboto', fontSize: 12, fontWeight: FontWeight.bold),
  statusFillOpacity: 0.8,
  groupFrameColor: Color(0xFF18181B),
  groupChipTextStyle: TextStyle(fontFamily: 'Roboto'),
  groupChipRadius: 6,
  selectionOnLight: Color(0xFFEA580C),
  selectionOnDark: Color(0xFFFB923C),
  canvasBackground: Color(0xFFF4F4F5),
  serviceBarHeight: 52,
);

/// The same in the POS's dark theme: its dark primary and muted colours.
/// The selection colours stay: they are chosen by the paper, not by the
/// theme.
const FloorPlanTheme floorLookDark = FloorPlanTheme(
  statusCaptionStyle: TextStyle(
      fontFamily: 'Roboto', fontSize: 12, fontWeight: FontWeight.bold),
  statusFillOpacity: 0.8,
  groupFrameColor: Color(0xFFFAFAFA),
  groupChipTextStyle: TextStyle(fontFamily: 'Roboto'),
  groupChipRadius: 6,
  selectionOnLight: Color(0xFFEA580C),
  selectionOnDark: Color(0xFFFB923C),
  canvasBackground: Color(0xFF27272A),
  serviceBarHeight: 52,
);

final ThemeData posLightTheme = ThemeData(
  colorSchemeSeed: Colors.teal,
  extensions: const [floorLookLight],
);

final ThemeData posDarkTheme = ThemeData(
  colorSchemeSeed: Colors.teal,
  brightness: Brightness.dark,
  extensions: const [floorLookDark],
);

/// The POS's own colour tokens as a Material colour scheme, by hand: a
/// seeded scheme cannot reproduce another design system's colours.
ColorScheme posColorScheme(Brightness brightness) =>
    brightness == Brightness.light
        ? const ColorScheme(
            brightness: Brightness.light,
            primary: Color(0xFF18181B),
            onPrimary: Color(0xFFFAFAFA),
            secondary: Color(0xFFF4F4F5),
            onSecondary: Color(0xFF18181B),
            error: Color(0xFFEF4444),
            onError: Color(0xFFFAFAFA),
            surface: Color(0xFFFFFFFF),
            onSurface: Color(0xFF09090B),
            onSurfaceVariant: Color(0xFF71717A),
            surfaceContainer: Color(0xFFF4F4F5),
            outline: Color(0xFFE4E4E7),
          )
        : const ColorScheme(
            brightness: Brightness.dark,
            primary: Color(0xFFFAFAFA),
            onPrimary: Color(0xFF18181B),
            secondary: Color(0xFF27272A),
            onSecondary: Color(0xFFFAFAFA),
            error: Color(0xFF7F1D1D),
            onError: Color(0xFFFAFAFA),
            surface: Color(0xFF09090B),
            onSurface: Color(0xFFFAFAFA),
            onSurfaceVariant: Color(0xFFA1A1AA),
            surfaceContainer: Color(0xFF18181B),
            outline: Color(0xFF27272A),
          );

/// The theme around the floor plan: the POS's colour scheme, for the
/// planner's bars, panels and dialogs, and the app theme's extensions
/// carried over, or the view would find no `FloorPlanTheme`.
ThemeData floorTheme(ThemeData app) => ThemeData(
      colorScheme: posColorScheme(app.brightness),
      extensions: app.extensions.values,
    );

class PosApp extends StatelessWidget {
  const PosApp({super.key, required this.store, this.locale});

  final PosStore store;

  /// The POS's language; the system's when null.
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: posLightTheme,
      darkTheme: posDarkTheme,
      locale: locale,
      supportedLocales: floorPlanSupportedLocales,
      localizationsDelegates: floorPlanLocalizationsDelegates,
      home: FloorScreen(store: store),
    );
  }
}

class FloorScreen extends StatefulWidget {
  const FloorScreen({super.key, required this.store});

  final PosStore store;

  @override
  State<FloorScreen> createState() => _FloorScreenState();
}

class _FloorScreenState extends State<FloorScreen> {
  PosStore get store => widget.store;

  // One loader and one thumbnail cache for every floor's controller.
  final symbols = SymbolLibraryLoader(
    sources: const [furnitureSymbolSource, restaurantSymbolSource],
  );
  final thumbnails = SymbolThumbnails(maxEntries: 128);

  late final FloorPlanController controller = FloorPlanController(
    symbols: symbols,
    thumbnails: thumbnails,
  );

  /// Whether staff may drag tables during service.
  bool staffMayMoveTables = true;

  /// The guests at each table, by number: the POS's own data.
  final Map<String, int> guestsAt = {'4': 2, '7': 5};

  /// The table the mouse is over, for the host's own line.
  final ValueNotifier<String?> hovered = ValueNotifier(null);

  /// Whether the service shows the POS's own bar instead of the planner's.
  bool ownBar = false;

  /// Whether the POS's shortcuts own the keyboard.
  bool posOwnsKeys = false;

  /// What the editor lets the user do.
  FloorPlanEditorCapabilities editing = FloorPlanEditorCapabilities.full;

  @override
  void initState() {
    super.initState();
    controller.serviceLayoutChanges.addListener(saveLayout);
    controller.selectedTables.addListener(showOrders);
    controller.mode.addListener(() => hovered.value = null);
    controller.designChanges.listen(designChanged);
    openDesign();
  }

  @override
  void dispose() {
    controller.dispose();
    thumbnails.dispose();
    symbols.dispose();
    hovered.dispose();
    super.dispose();
  }

  Future<void> saveDesign() async {
    final json = controller.designJson();
    await store.write('floor-1.design', json);
    controller.markSaved();
  }

  Future<void> openDesign() async {
    final json = await store.read('floor-1.design');
    if (json == null || !mounted) return;
    try {
      controller.load(json);
    } on FormatException catch (e) {
      showProblem('$e');
    }
  }

  Future<void> saveLayout() async {
    final json = controller.serviceLayoutJson();
    if (json != null) await store.write('floor-1.layout', json);
  }

  Future<void> enterService() async {
    // Read before switching: while the read waits, the plan stays in the
    // design mode, so no move can be saved over the stored layout.
    final String? json;
    try {
      json = await store.read('floor-1.layout');
    } catch (e) {
      showProblem('$e');
      return;
    }
    if (!mounted) return;
    controller.setMode(FloorPlanMode.selection);
    if (json == null) return;
    try {
      final result = controller.restoreServiceLayout(json);
      if (result.dropped.isNotEmpty) {
        showProblem('${result.dropped.length} tables are back in place');
      }
    } on FormatException {
      await store.delete('floor-1.layout');
    }
  }

  void showStatuses() {
    controller.setTableStatus({
      '4': TableStatus(color: const Color(0x8000C853), caption: 'Free'),
      '7': TableStatus(color: const Color(0x80FF6D00), caption: '12:40'),
    });
    controller.setGroupStatus({
      'G1': TableStatus(color: const Color(0x80E53935), caption: 'Bill'),
    });
  }

  /// Merge (the service bar's, when the host passes the callback): a new
  /// group of [numbers], taken out of any group that held them, since a
  /// number belongs to one group at most.
  void mergeTables(Set<String> numbers) {
    final groups = <String, TableGroup>{};
    for (final MapEntry(key: id, value: group)
        in controller.tableGroups.value.entries) {
      final rest = group.members.difference(numbers);
      if (rest.isNotEmpty) {
        groups[id] = TableGroup(members: rest, label: group.label);
      }
    }
    var n = 1;
    while (controller.tableGroups.value.containsKey('G$n')) {
      n++;
    }
    groups['G$n'] = TableGroup(members: numbers);
    controller.setTableGroups(groups);
  }

  /// Split: the group goes, and its status with it.
  void splitGroup(String id) {
    controller.setTableGroups({...controller.tableGroups.value}..remove(id));
    controller.setGroupStatus({...controller.groupStatuses.value}..remove(id));
  }

  void showZone(Set<String> numbers, {required bool fadeOthers}) {
    if (!controller.fitToTables(numbers)) controller.fitToView();
    controller.setTableFocus(fadeOthers ? numbers : null);
  }

  void showAllZones() {
    controller.fitToView();
    controller.setTableFocus(null);
  }

  /// The tables the POS knows that this floor does not draw: a table on
  /// a hidden layer is not drawn, so it counts as unplaced. Codes compare
  /// trimmed, as `fitToTables` and `setTableFocus` trim them.
  Set<String> unplacedTables(Set<String> codes) {
    final drawn = {
      for (final table in controller.tables)
        if (table.visible && table.number != null) table.number!,
    };
    return {
      for (final code in codes)
        if (!drawn.contains(code.trim())) code,
    };
  }

  /// The POS's tables, by the id stored in each table's `data['id']`, that
  /// this floor does not draw. Ids compare exactly, whatever the numbers.
  Set<String> unplacedIds(Set<String> ids) {
    final drawn = {
      for (final detail in controller.tableDetails)
        if (detail.table.visible && detail.data['id'] != null)
          detail.data['id']!,
    };
    return ids.difference(drawn);
  }

  /// A drag in the service moved these tables: tell the other terminals.
  void tablesMoved(List<FloorPlanTableDetail> moved) {
    for (final detail in moved) {
      debugPrint('${detail.table.number ?? 'a table'} is at ${detail.center}');
    }
  }

  /// A double tap: the bill. Its two taps have opened the order already.
  void openBill(String number) => debugPrint('the bill of $number');

  /// A tap on the floor, in metres.
  void floorTapped(Offset world) =>
      debugPrint('floor at ${world.dx / 1000}, ${world.dy / 1000} m');

  /// The table under the mouse, for a line of the host's own.
  void showHover(String? number) => hovered.value = number;

  /// Links table [number] to the POS's own table [id]: false, changing
  /// nothing, when this floor has no table [number] or two of them.
  bool linkTable(String number, String id) =>
      controller.setTableData(number, {'id': id});

  /// The POS's id of table [number]: null when no table carries the
  /// number, or when two do (it names neither).
  String? idOf(String number) {
    final tables = [
      for (final detail in controller.tableDetails)
        if (detail.table.number == number) detail,
    ];
    return tables.length == 1 ? tables.single.data['id'] : null;
  }

  /// Links every table the POS knows on this floor, in one undo step;
  /// false, changing nothing, if a number is not on the floor or is on two
  /// tables.
  bool linkAll(Map<String, String> idByNumber) => controller.setTablesData({
        for (final MapEntry(key: number, value: id) in idByNumber.entries)
          number: {'id': id},
      });

  /// The designed floor changed: keep the POS's list of tables in step.
  void designChanged(FloorPlanDesignChange change) {
    switch (change) {
      case FloorPlanTableAdded(:final table):
        debugPrint('placed: ${table.table.number}');
      case FloorPlanTableRemoved(:final table):
        debugPrint('removed: ${table.table.number} (${table.data['id']})');
      case FloorPlanTableChanged(:final before, :final after):
        if (before.table.number != after.table.number) {
          debugPrint('${before.table.number} is now ${after.table.number}');
        }
      case FloorPlanPlanReplaced():
        hovered.value = null;
        debugPrint('another plan: read controller.tableDetails again');
    }
  }

  /// A badge on each table with guests: their count over the seats, faded
  /// outside the focus, a dot when the plan is zoomed far out.
  Widget? tableBadge(BuildContext context, FloorPlanTableOverlay table) {
    final number = table.detail.table.number!;
    final guests = guestsAt[number];
    if (guests == null) return null;
    final Widget badge = table.detailLevel == 0
        ? const Icon(Icons.circle, size: 10)
        : Chip(label: Text('$guests / ${table.detail.table.seats}'));
    return Opacity(opacity: table.focused ? 1 : 0.4, child: badge);
  }

  /// Brings table [number] to the middle of the view, close enough to read.
  void showTable(String number) {
    for (final detail in controller.tableDetails) {
      final center = detail.center;
      if (detail.table.number == number && center != null) {
        final scale = controller.camera.value.scale;
        controller.centerOn(center, scale: scale < 0.1 ? 0.1 : null);
        return;
      }
    }
  }

  /// Opens table [number]'s menu from outside the view (a list of open
  /// orders, say), at the table's centre on the screen.
  Future<void> openMenuAt(String number) async {
    for (final detail in controller.tableDetails) {
      final center = detail.center;
      if (detail.table.number != number || center == null) continue;
      final at = controller.worldToGlobal(center);
      if (at != null) await showTableMenu(number, at);
      return;
    }
  }

  /// The table under a global point (an order dropped on the plan), or
  /// null.
  String? tableUnder(Offset global) {
    final rect = controller.canvasRect.value;
    if (rect == null) return null;
    return controller.tableAt(global - rect.topLeft);
  }

  /// The service bar: Undo and Redo, then Print, with the floor's name
  /// before them.
  static const serviceBar = FloorPlanServiceBar(
    actions: [
      FloorPlanServiceAction.undo,
      FloorPlanServiceAction.redo,
      FloorPlanServiceAction.print,
    ],
    leading: [
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Center(child: Text('Floor 1')),
      ),
    ],
  );

  /// The editor's bar: Undo, Redo and the zoom, nothing else.
  static const editorBar = FloorPlanEditorBar(
    actions: [
      FloorPlanEditorAction.undo,
      FloorPlanEditorAction.redo,
      FloorPlanEditorAction.zoom,
    ],
  );

  /// The POS's own service bar, shown instead of the planner's: each
  /// button enabled by the controller's state, each press a command.
  Widget posServiceBar() => Row(
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: controller.canUndo,
            builder: (context, can, _) => TextButton(
                onPressed: can ? controller.undo : null,
                child: const Text('Undo')),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: controller.canRedo,
            builder: (context, can, _) => TextButton(
                onPressed: can ? controller.redo : null,
                child: const Text('Redo')),
          ),
          ValueListenableBuilder<Set<String>?>(
            valueListenable: controller.mergeCandidate,
            builder: (context, numbers, _) => TextButton(
                onPressed: numbers == null ? null : () => mergeTables(numbers),
                child: const Text('Merge')),
          ),
          ValueListenableBuilder<String?>(
            valueListenable: controller.selectedGroup,
            builder: (context, group, _) => TextButton(
                onPressed: group == null ? null : () => splitGroup(group),
                child: const Text('Split')),
          ),
          TextButton(onPressed: exportPng, child: const Text('Export')),
          TextButton(onPressed: printFloor, child: const Text('Print')),
        ],
      );

  /// Export and Print without the planner's dialogs.
  Future<void> exportPng() async {
    try {
      final export = await controller.exportPlan(
        const FloorPlanExportChoice(
            format: FloorPlanExportFormat.png, dpi: FloorPlanExportDpi.d150),
        name: 'floor-1',
      );
      if (export != null) saveExport(export);
    } catch (error) {
      showProblem('$error');
    }
  }

  Future<void> printFloor() async {
    try {
      await controller.printPlan(name: 'floor-1');
    } catch (error) {
      showProblem('$error');
    }
  }

  /// The POS's own export dialog, at every Export of the planner: a PDF,
  /// or a PNG at 300 dpi; null cancels.
  Future<FloorPlanExportChoice?> askExport(
          BuildContext context, FloorPlanExportChoice initial) =>
      showDialog<FloorPlanExportChoice>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Export'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(
                  context, initial.copyWith(format: FloorPlanExportFormat.pdf)),
              child: const Text('PDF'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(
                  context,
                  const FloorPlanExportChoice(
                      format: FloorPlanExportFormat.png,
                      dpi: FloorPlanExportDpi.d300)),
              child: const Text('PNG, 300 dpi'),
            ),
          ],
        ),
      );

  /// The manager arranges the tables but never turns them, and places the
  /// round ones only.
  static final arrangeTables = FloorPlanEditorCapabilities.tablesOnly.copyWith(
    rotate: false,
    symbolFilter: roundTables,
  );

  /// A static function, so the capabilities stay equal at every build.
  static bool roundTables(FloorPlanSymbol symbol) =>
      symbol.seats != null && symbol.key.contains('.round');

  /// The POS's table, linked from the one table selected in the editor.
  Widget? tableInspector(BuildContext context, FloorPlanTableDetail table) {
    final number = table.table.number!;
    return ListTile(
      title: Text('POS table: ${table.data['id'] ?? 'none'}'),
      trailing: TextButton(
        onPressed: () => linkTable(number, 'pos-$number'),
        child: const Text('Link'),
      ),
    );
  }

  /// The POS's own tool strip: the tools it offers, the active one marked.
  Widget toolStrip() => ValueListenableBuilder<FloorPlanTool>(
        valueListenable: controller.activeTool,
        builder: (context, active, _) => Row(children: [
          for (final tool in const [FloorPlanTool.select, FloorPlanTool.wall])
            ChoiceChip(
              label: Text(tool.name),
              selected: tool == active,
              onSelected: (_) => controller.selectTool(tool),
            ),
        ]),
      );

  /// The POS's own keys over the plan while it owns the keyboard: its
  /// commands. A key typed into a text field inside the view never gets
  /// here: the view keeps it for the field.
  KeyEventResult posKey(FocusNode node, KeyEvent event) {
    if (!posOwnsKeys || event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.delete) {
      controller.deleteSelection();
    } else if (key == LogicalKeyboardKey.escape) {
      controller.selectTool(FloorPlanTool.select);
    } else if (key == LogicalKeyboardKey.keyZ &&
        HardwareKeyboard.instance.isControlPressed) {
      controller.undo();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void showOrders() {
    final numbers = controller.selectedTables.value;
    debugPrint('orders for tables $numbers');
  }

  String describe(NumberingWarning warning) => switch (warning) {
        DuplicateNumber(:final number, :final count) =>
          'Table $number is used $count times',
        Unnumbered(:final seats) => 'A table with $seats seats has no number',
      };

  void saveExport(FloorPlanExport export) {
    debugPrint('${export.fileName}: ${export.bytes.length} bytes, '
        '${export.mimeType}');
  }

  void openOrder(String number) => debugPrint('open the order of $number');

  Future<void> showTableMenu(String number, Offset position) async {
    final tables = controller.selectedTables.value;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx, position.dy),
      items: [
        PopupMenuItem(value: 'bill', child: Text('Bill for $tables')),
      ],
    );
    if (choice == 'bill') showStatuses();
  }

  void showProblem(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ValueListenableBuilder<int>(
          valueListenable: controller.revision,
          builder: (context, _, __) {
            final strings = FloorPlanStrings.of(context);
            final problems = [
              for (final warning in controller.numberingWarnings)
                strings.numberingWarning(warning),
            ];
            return Text(problems.isEmpty ? 'Floor 1' : problems.first);
          },
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.save), onPressed: () => saveDesign()),
          IconButton(
              icon: const Icon(Icons.room_service),
              onPressed: () => enterService()),
          IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => controller.setMode(FloorPlanMode.design)),
          IconButton(
              icon: const Icon(Icons.restart_alt),
              onPressed: () => controller.resetLayout()),
          IconButton(
              icon: const Icon(Icons.filter_center_focus),
              onPressed: () => showZone({'1', '2'}, fadeOthers: true)),
          IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: () => showAllZones()),
          IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: () =>
                  debugPrint('unplaced: ${unplacedTables({'1', '2', '99'})}')),
          IconButton(
              icon: const Icon(Icons.zoom_in),
              onPressed: () => controller.zoomBy(1.25)),
          IconButton(
              icon: const Icon(Icons.my_location),
              onPressed: () => showTable('7')),
          IconButton(
              icon: const Icon(Icons.receipt_long),
              onPressed: () => openMenuAt('4')),
          IconButton(
              icon: const Icon(Icons.ads_click),
              onPressed: () => debugPrint(
                  'at (400, 300): ${tableUnder(const Offset(400, 300))}')),
          IconButton(
              icon: const Icon(Icons.link),
              onPressed: () =>
                  debugPrint('linked 4: ${linkTable('4', 'pos-4')}, '
                      'all: ${linkAll({'1': 'pos-1', '2': 'pos-2'})}, '
                      'id of 4: ${idOf('4')}, '
                      'unplaced: ${unplacedIds({'pos-1', 'pos-9'})}')),
          ValueListenableBuilder<FloorPlanCamera>(
            valueListenable: controller.camera,
            builder: (context, camera, _) =>
                Text('${(camera.scale * 1000).round()} px/m'),
          ),
          Switch(
              value: staffMayMoveTables,
              onChanged: (v) => setState(() => staffMayMoveTables = v)),
          Switch(value: ownBar, onChanged: (v) => setState(() => ownBar = v)),
          Switch(
              value: editing == arrangeTables,
              onChanged: (v) => setState(() => editing =
                  v ? arrangeTables : FloorPlanEditorCapabilities.full)),
          Switch(
              value: posOwnsKeys,
              onChanged: (v) => setState(() => posOwnsKeys = v)),
        ],
      ),
      // The POS's own keys, over everything the screen shows.
      body: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: posKey,
        child: Column(
          children: [
            ValueListenableBuilder<int>(
              valueListenable: controller.revision,
              builder: (context, _, __) => Column(children: [
                for (final warning in controller.numberingWarnings)
                  Text(describe(warning)),
              ]),
            ),
            ValueListenableBuilder<String?>(
              valueListenable: hovered,
              builder: (context, number, _) =>
                  Text(number == null ? '' : 'Table $number'),
            ),
            ValueListenableBuilder<Set<String>>(
              valueListenable: controller.editorSelectedTables,
              builder: (context, numbers, _) =>
                  Text(numbers.isEmpty ? '' : 'Arranging tables $numbers'),
            ),
            toolStrip(),
            ValueListenableBuilder<FloorPlanMode>(
              valueListenable: controller.mode,
              builder: (context, mode, _) =>
                  ownBar && mode == FloorPlanMode.selection
                      ? posServiceBar()
                      : const SizedBox.shrink(),
            ),
            Expanded(
              child: Theme(
                data: floorTheme(Theme.of(context)),
                child: FloorPlanView(
                  controller: controller,
                  exportName: 'floor-1',
                  onExport: saveExport,
                  printer: const PrintingPagePrinter(),
                  onTableTap: openOrder,
                  onTableContextMenu: showTableMenu,
                  onGroupTap: (group, number) => openOrder(number),
                  onMergeRequested: mergeTables,
                  onSplitRequested: splitGroup,
                  serviceMoves: staffMayMoveTables,
                  longPress: FloorPlanLongPress.toggleSelection,
                  tableOverlayBuilder: tableBadge,
                  tableOverlayLayout: const FloorPlanOverlayLayout(
                    anchor: Alignment.bottomCenter,
                    detailBreakpoints: [0.05],
                  ),
                  onTablesMoved: tablesMoved,
                  onTableDoubleTap: openBill,
                  onFloorTap: floorTapped,
                  onTableHover: showHover,
                  theme: const FloorPlanTheme(selectionWidth: 3),
                  serviceBar: ownBar
                      ? const FloorPlanServiceBar(visible: false)
                      : serviceBar,
                  editorBar: editorBar,
                  editorCapabilities: editing,
                  tableInspectorBuilder: tableInspector,
                  onExportDialog: askExport,
                  onPageFlowError: (error) => showProblem('$error'),
                  shortcuts: !posOwnsKeys,
                  autofocus: !posOwnsKeys,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A floor on a kiosk: staff cannot pan or zoom it by hand, the arrows
/// move it, and each table is a button that opens its order.
class KioskFloor extends StatefulWidget {
  const KioskFloor({super.key, required this.json, required this.onOrder});

  /// The floor's plan, as `designJson()` wrote it.
  final String json;

  /// Opens the order of table [number].
  final void Function(String number) onOrder;

  @override
  State<KioskFloor> createState() => _KioskFloorState();
}

class _KioskFloorState extends State<KioskFloor> {
  late final FloorPlanController controller = FloorPlanController(
    json: widget.json,
    minScale: 0.02,
    maxScale: 0.5,
  )..setMode(FloorPlanMode.selection);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  /// The floor point (millimetres) under a global point, such as a
  /// waiter's tag dropped on the plan; null while no view is shown.
  Offset? floorPointAt(Offset global) => controller.globalToWorld(global);

  /// The floor point at the middle of the canvas, or null.
  Offset? middle() {
    final rect = controller.canvasRect.value;
    if (rect == null) return null;
    return controller.camera.value.canvasToWorld(rect.size.center(Offset.zero));
  }

  /// How many tables are off the screen now.
  int tablesOutOfSight() {
    final rect = controller.canvasRect.value;
    if (rect == null) return 0;
    final shown = controller.camera.value.visibleWorld(rect.size);
    return controller.tableDetails
        .where((d) => d.center != null && !shown.contains(d.center!))
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => controller.panBy(const Offset(200, 0))),
            IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: () => controller.panBy(const Offset(-200, 0))),
            ValueListenableBuilder<FloorPlanCamera>(
              valueListenable: controller.camera,
              builder: (context, camera, _) =>
                  Text('${tablesOutOfSight()} tables out of sight'),
            ),
          ],
        ),
        Expanded(
          child: FloorPlanView(
            controller: controller,
            userCamera: false,
            tableOverlayModes: const {FloorPlanMode.selection},
            tableOverlayBuilder: (context, table) => Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () => widget.onOrder(table.detail.table.number!),
              ),
            ),
            tableOverlayLayout: const FloorPlanOverlayLayout(
              interactive: true,
              size: FloorPlanOverlaySize.box,
              hideBelowScale: 0.04,
            ),
          ),
        ),
      ],
    );
  }
}
