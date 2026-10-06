// The external-host probe (spec 14d P6) and the host guide's source
// (P2): a small point-of-sale screen that depends on the planner and the
// restaurant library by git, from outside the workspace, through their
// public barrels only. CI resolves, analyses and builds it at the commit it
// tests; tool/ci/check_guide.dart checks that every Dart snippet of
// docs/host-guide.md is in this file, so the guide's code compiles.
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show BrowserContextMenu;
import 'package:jet_cad_floor_plan/jet_cad_floor_plan.dart';
import 'package:jet_cad_restaurant_symbols/jet_cad_restaurant_symbols.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ensureFloorPlanFonts();
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

class PosApp extends StatelessWidget {
  const PosApp({super.key, required this.store, this.locale});

  final PosStore store;

  /// The POS's language; the system's when null.
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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

  List<String> problems = const [];

  @override
  void initState() {
    super.initState();
    controller.serviceLayoutChanges.addListener(saveLayout);
    controller.revision.addListener(checkNumbers);
    controller.selectedTables.addListener(showOrders);
    openDesign();
  }

  @override
  void dispose() {
    controller.dispose();
    thumbnails.dispose();
    symbols.dispose();
    super.dispose();
  }

  Future<void> saveDesign() async {
    final json = controller.designJson();
    await store.write('floor-1.design', json);
    controller.markSaved();
  }

  Future<void> openDesign() async {
    final json = await store.read('floor-1.design');
    if (json == null) return;
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
    controller.setMode(FloorPlanMode.selection);
    final json = await store.read('floor-1.layout');
    if (json == null || controller.mode.value != FloorPlanMode.selection) {
      return;
    }
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
  }

  void showOrders() {
    final numbers = controller.selectedTables.value;
    debugPrint('orders for tables $numbers');
  }

  void checkNumbers() {
    final strings = FloorPlanStrings.of(context);
    setState(() {
      problems = [
        for (final warning in controller.numberingWarnings)
          strings.numberingWarning(warning),
      ];
    });
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

  void openOrder(String number) => controller.select({number});

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
        title: Text(problems.isEmpty ? 'Floor 1' : problems.first),
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
          Switch(
              value: staffMayMoveTables,
              onChanged: (v) => setState(() => staffMayMoveTables = v)),
        ],
      ),
      body: Column(
        children: [
          for (final table in controller.tables)
            if (table.number == null) Text('${table.seats} seats, unnumbered'),
          for (final warning in controller.numberingWarnings)
            Text(describe(warning)),
          Expanded(
            child: FloorPlanView(
              controller: controller,
              exportName: 'floor-1',
              onExport: saveExport,
              printer: const PrintingPagePrinter(),
              onTableTap: openOrder,
              onTableContextMenu: showTableMenu,
              serviceMoves: staffMayMoveTables,
              longPress: FloorPlanLongPress.toggleSelection,
            ),
          ),
        ],
      ),
    );
  }
}
