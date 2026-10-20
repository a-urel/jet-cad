// The external-host probe (spec 14d P6) and the host guide's source (P2,
// sub-project 4a R4): a small point-of-sale screen that depends on the plan
// library and two kits from pub.dev (overridden to the commit under test),
// from outside the workspace, through the packages' public barrels only. CI
// resolves, analyses and builds it at the commit it tests;
// tool/ci/check_guide.dart checks that every Dart snippet of
// docs/host-guide.md is in this file, so the guide's code compiles.
import 'dart:async' show StreamSubscription;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show BrowserContextMenu;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart'
    show KitNames, PlanKit, SymbolLibrarySource, bundledLibrary;
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_kit_restaurant/jet_cad_2d_kit_restaurant.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await ensurePlanFonts();
  } catch (error, stack) {
    // The plans then measure in the platform's font; the POS still starts.
    FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack));
  }
  registerFontLicences();
  if (kIsWeb) await BrowserContextMenu.disableContextMenu();
  runApp(PosApp(store: MemoryStore()));
}

/// The kits the POS loads: walls and doors, then the restaurant's tables. The
/// order is the gallery's.
final List<PlanKit> posKits = [architectureKit, restaurantKit];

/// Where the POS keeps its text: a database, files, a server. The plan
/// library never stores anything itself.
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

/// One dining area: its plan, and what the POS keeps beside it.
class PosFloor {
  PosFloor(this.name, {String? json})
      : controller = PlanController(
            kits: posKits, json: json, words: posWords, permissions: waiter);

  final String name;
  final PlanController controller;

  /// The POS's state of each table, by the POS's own table id.
  final Map<String, PosStatus> statuses = {};

  /// The POS's groups: a group's id, the POS ids of its tables.
  final Map<String, Set<String>> groups = {};

  /// The POS's state of each group, by its id.
  final Map<String, PosStatus> groupStatuses = {};

  /// The service layout last seen (`serviceJson()`), kept for the next time
  /// the service is entered.
  String? layout;
}

/// The planner's words for a symbol, in a language the kit has none for.
const KitNames posWords = KitNames({
  'de': {'symbol:restaurant.table.round.four': 'Runder Vierertisch'},
});

/// The POS's own symbols, as a kit of its own.
final PlanKit acmeKit = PlanKit(
  id: 'acme',
  version: '1.0.0',
  symbols: [
    SymbolLibrarySource(
        label: 'acme', read: bundledLibrary('assets/acme.jetlib')),
  ],
);

/// What the POS knows of a table.
enum PosStatus {
  ordered(Color(0x99FFB300)),
  eating(Color(0x9943A047)),
  bill(Color(0x99E53935));

  const PosStatus(this.color);

  final Color color;
}

/// The status as the plan draws it: a fill, and for the bill a caption (at
/// most 12 characters, plain text the library never re-words).
UnitStatus statusOf(PosStatus status) => UnitStatus(
    color: status.color, caption: status == PosStatus.bill ? 'Bill' : null);

/// The plan's tables by the POS id they are linked by, as the label the plan
/// knows them by.
Map<String, String> labelsByPosId(PlanController c) => {
      for (final detail in c.unitDetails)
        if (detail.unit.label case final label? when detail.data['id'] != null)
          detail.data['id']!: label,
    };

/// Links the plan's table [label] to the POS's table [posId]. The table's
/// other data is kept. False when no table, or two, carry the label.
bool linkTable(PlanController c, String label, String posId) {
  final tables = [
    for (final detail in c.unitDetails)
      if (detail.unit.label == label) detail,
  ];
  if (tables.length != 1) return false;
  return c.setUnitData(label, {...tables.single.data, 'id': posId});
}

/// The POS's table ids that no table of the plan is linked to.
Set<String> unlinked(PlanController c, Set<String> posIds) =>
    posIds.difference(labelsByPosId(c).keys.toSet());

/// The plan's objects of any kind (a table, a placed symbol, a room) by the
/// POS id they are linked by.
Map<String, PlanObjectRef> objectsByPosId(PlanController c) => {
      for (final detail in c.objectDetails)
        if (detail.data['id'] case final id?) id: detail.ref,
    };

/// Links the object [ref] to the POS record [posId]. The object's other data
/// is kept. False when [ref] names no object, or the object is locked.
bool linkObject(PlanController c, PlanObjectRef ref, String posId) {
  final detail = c.objectDetailOf(ref);
  if (detail == null) return false;
  return c.setObjectData(ref, {...detail.data, 'id': posId});
}

/// The section each linked table stands in, by the table's POS id: the
/// section's own POS id, or its name when it is not linked.
Map<String, String?> sectionsByPosId(PlanController c) => {
      for (final detail in c.unitDetails)
        if (detail.data['id'] case final id?)
          id: detail.section?.data['id'] ?? detail.section?.label,
    };

/// Writes a table's section to the POS's database whenever the plan moves
/// the table into another section, or the section's walls move.
StreamSubscription<PlanSectionChange> watchSections(
  PlanController c,
  void Function(String posTableId, String? section) write,
) =>
    c.sectionChanges.listen((change) {
      final posIdOf = {
        for (final MapEntry(:key, :value) in labelsByPosId(c).entries)
          value: key,
      };
      for (final MapEntry(key: label, value: section)
          in change.byLabel.entries) {
        if (posIdOf[label] case final id?) write(id, section?.label);
      }
    });

/// A combo over the POS's records for the one selected object: choosing one
/// writes its id on the object, the object's other data kept.
Widget recordPicker(
  PlanController c,
  PlanObjectDetail object,
  List<String> records,
) =>
    DropdownButton<String>(
      value: records.contains(object.data['id']) ? object.data['id'] : null,
      hint: const Text('Record'),
      items: [
        for (final record in records)
          DropdownMenuItem(value: record, child: Text(record)),
      ],
      onChanged: (id) {
        if (id != null) c.setObjectData(object.ref, {...object.data, 'id': id});
      },
    );

/// An editor with both inspectors: the units go to the unit inspector, every
/// other object (a room, a placed symbol) to the object inspector.
Widget inspectedEditor(PlanController c, List<String> records) => PlanEditor(
      controller: c,
      unitInspectorBuilder: (context, unit) => Text('${unit.unit.label}'),
      objectInspectorBuilder: (context, object) =>
          recordPicker(c, object, records),
    );

/// An editor whose design layout is the desktop's at any width, as in 0.8.x.
Widget desktopEditor(PlanController c) =>
    PlanEditor(controller: c, layout: PlanEditorLayout.desktop);

/// An editor that docks its columns from 900 logical pixels and uses the
/// tablet layout from 500, with the POS's orders beside the service.
Widget editorWithOrders(PlanController c, Widget orders) => PlanEditor(
      controller: c,
      breakpoints: const PlanLayoutBreakpoints(tablet: 500, desktop: 900),
      serviceSidePanel: orders,
    );

/// Draws the POS's states. The maps are the whole truth: the controller's
/// own are replaced at each call. A group's status fills its tables over
/// their own.
void paintStatuses(PosFloor floor) {
  final c = floor.controller;
  final labels = labelsByPosId(c);
  c.setUnitStatus({
    for (final MapEntry(:key, :value) in floor.statuses.entries)
      if (labels[key] case final label?) label: statusOf(value),
  });
  c.setGroupStatus({
    for (final MapEntry(:key, :value) in floor.groupStatuses.entries)
      if (floor.groups.containsKey(key)) key: statusOf(value),
  });
}

/// Draws the POS's groups as the plan's, by the label each POS id is linked
/// to. A POS table the plan does not draw is left out; a group left with no
/// table is not drawn.
void paintGroups(PosFloor floor) {
  final labels = labelsByPosId(floor.controller);
  final drawn = <String, UnitGroup>{};
  for (final MapEntry(key: id, value: tables) in floor.groups.entries) {
    final members = {
      for (final table in tables)
        if (labels[table] case final label?) label,
    };
    if (members.isNotEmpty) drawn[id] = UnitGroup(members: members);
  }
  floor.controller.setUnitGroups(drawn);
}

/// A Merge request: the tables the staff selected become a new group
/// `G<n>`, leaving the groups they were in; a group left empty goes.
/// Returns the new group's id, or null when none of the labels is linked to
/// a POS table.
String? mergeTables(PosFloor floor, Set<String> labels) {
  final posIdOf = {
    for (final MapEntry(:key, :value)
        in labelsByPosId(floor.controller).entries)
      value: key,
  };
  final tables = {
    for (final label in labels)
      if (posIdOf[label] case final id?) id,
  };
  if (tables.isEmpty) return null;
  var highest = 0;
  for (final id in floor.groups.keys) {
    if (RegExp(r'^G(\d+)$').firstMatch(id) case final match?) {
      highest = math.max(highest, int.parse(match[1]!));
    }
  }
  final id = 'G${highest + 1}';
  for (final group in floor.groups.values) {
    group.removeAll(tables);
  }
  floor.groups.removeWhere((_, group) => group.isEmpty);
  floor.groupStatuses
      .removeWhere((group, _) => !floor.groups.containsKey(group));
  floor.groups[id] = tables;
  paintGroups(floor);
  paintStatuses(floor);
  return id;
}

/// A Split request: the group goes, and its status with it.
void splitGroup(PosFloor floor, String id) {
  floor.groups.remove(id);
  floor.groupStatuses.remove(id);
  paintGroups(floor);
  paintStatuses(floor);
}

/// Relabels tables of a plan whose groups live in the plan alone: the
/// groups list labels, and the plan does not follow a relabel into them, so
/// each label is put where the old one was. [byLabel] is old label, new
/// label; two tables may swap theirs.
bool relabelTables(PlanController c, Map<String, String> byLabel) {
  if (!c.setUnitsLabel(byLabel)) return false;
  c.setUnitGroups({
    for (final MapEntry(key: id, value: group) in c.unitGroups.value.entries)
      id: UnitGroup(
        members: {for (final label in group.members) byLabel[label] ?? label},
        label: group.label,
      ),
  });
  return true;
}

/// Hears the plan's tables change. A relabel (by the editor's panel, say)
/// moves a table to a label the plan's groups and statuses do not know, and a
/// load brings other tables: either way the POS draws its own state again.
StreamSubscription<PlanUnitChange> watchTables(PosFloor floor) =>
    floor.controller.unitChanges.listen((change) {
      void draw() {
        paintStatuses(floor);
        paintGroups(floor);
      }

      switch (change) {
        case PlanUnitAdded(:final unit):
          debugPrint('added table ${unit.unit.label}');
        case PlanUnitRemoved(:final unit):
          debugPrint('removed table ${unit.unit.label}');
        case PlanUnitChanged(:final before, :final after):
          if (before.unit.label != after.unit.label) draw();
        case PlanUnitsReplaced():
          draw();
      }
    });

/// Keeps the service layout on every change of its record, never on a mode
/// switch or a load.
void keepLayout(PosFloor floor) {
  final c = floor.controller;
  c.serviceChanges.addListener(() {
    if (c.serviceJson() case final json?) floor.layout = json;
  });
}

/// Enters the service and puts the kept layout back: the moves, and the
/// groups the plan still matches. Returns the ids of the groups it dropped,
/// and draws the POS's own groups over the record's.
List<String> enterService(PosFloor floor) {
  final c = floor.controller;
  c.setMode(PlanMode.service);
  var dropped = const <String>[];
  if (floor.layout case final layout?) {
    try {
      dropped = c.restoreService(layout).droppedGroups;
    } on FormatException {
      // Not a service record: an old text is refused, never read.
      floor.layout = null;
    }
  }
  paintGroups(floor);
  paintStatuses(floor);
  return dropped;
}

/// Saves the plan and marks it saved.
Future<void> savePlan(PosStore store, PosFloor floor) async {
  final text = floor.controller.save();
  await store.write('plan.${floor.name}', text);
  floor.controller.markSaved();
}

/// Loads the plan last saved; false when there is none or it is not a plan.
Future<bool> revertPlan(PosStore store, PosFloor floor) async {
  final text = await store.read('plan.${floor.name}');
  if (text == null) return false;
  try {
    floor.controller.load(text);
  } on PlanFormatException catch (error) {
    debugPrint('not a plan: ${error.code.name}');
    return false;
  }
  if (floor.controller.missingKits.isNotEmpty) {
    debugPrint('kits the plan uses: ${floor.controller.missingKits}');
  }
  return true;
}

/// Exports the plan as a PDF through the planner's dialog.
Future<PlanExport?> exportPdf(BuildContext context, PosFloor floor) async {
  final c = floor.controller;
  final answer = await showPlanExportDialog(
      context, PlanExportAnswer.initial, c.exporters);
  if (answer == null) return null;
  return c.export(answer.exporter, answer.choice, name: floor.name);
}

/// What the waiter may do, and what the manager may.
const PlanPermissions waiter = PlanPermissions.readOnly;

const PlanPermissions manager = PlanPermissions(
  tools: {
    PlanToolIds.select,
    PlanToolIds.symbol,
    PlanToolIds.rectangle,
    ArchitectureTools.wall,
    ArchitectureTools.door,
  },
  editPage: false,
);

/// A badge on each table in service: its label and its seats.
Widget? tableBadge(BuildContext context, PlanUnitOverlay table) {
  final unit = table.detail.unit;
  return Text('${unit.label} (${unit.capacity})');
}

/// The planner's look in the POS's light theme.
const PlanTheme planLookLight = PlanTheme(
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

final ThemeData posLightTheme = ThemeData(
  colorSchemeSeed: Colors.teal,
  extensions: const [planLookLight],
);

/// The POS.
class PosApp extends StatefulWidget {
  const PosApp({super.key, required this.store});

  final PosStore store;

  @override
  State<PosApp> createState() => _PosAppState();
}

class _PosAppState extends State<PosApp> {
  Locale? _locale;

  @override
  Widget build(BuildContext context) => MaterialApp(
        theme: posLightTheme,
        locale: _locale,
        supportedLocales: planSupportedLocales,
        localizationsDelegates: planLocalizationsDelegates,
        home: FloorScreen(
            store: widget.store,
            onLocale: (locale) => setState(() => _locale = locale)),
      );
}

/// One floor, in the design or the service.
class FloorScreen extends StatefulWidget {
  const FloorScreen({super.key, required this.store, this.onLocale});

  final PosStore store;
  final ValueChanged<Locale>? onLocale;

  @override
  State<FloorScreen> createState() => _FloorScreenState();
}

class _FloorScreenState extends State<FloorScreen> {
  final PosFloor floor = PosFloor('Salon');
  late final StreamSubscription<PlanUnitChange> _tables = watchTables(floor);

  @override
  void initState() {
    super.initState();
    keepLayout(floor);
  }

  @override
  void dispose() {
    _tables.cancel();
    floor.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(floor.name), actions: [
          TextButton(
              onPressed: () => floor.controller.setMode(PlanMode.design),
              child: const Text('Design')),
          TextButton(
              onPressed: () => enterService(floor),
              child: const Text('Service')),
          for (final locale in planSupportedLocales)
            TextButton(
                onPressed: () => widget.onLocale?.call(locale),
                child: Text(locale.languageCode)),
        ]),
        body: PlanEditor(
          controller: floor.controller,
          exportName: floor.name,
          serviceBar: PlanServiceBar(leading: [
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(child: Text(floor.name))),
          ]),
          onSave: () => savePlan(widget.store, floor),
          onUnitTap: (label) => debugPrint('table $label'),
          onUnitDoubleTap: (label) => debugPrint('open table $label'),
          onMergeRequested: (labels) => mergeTables(floor, labels),
          onSplitRequested: (id) => splitGroup(floor, id),
          onLayoutChanged: () => debugPrint('the layout changed'),
          unitOverlayBuilder: tableBadge,
          unitOverlayLayout:
              const PlanOverlayLayout(anchor: Alignment.bottomCenter),
          longPress: PlanLongPress.contextMenu,
          floorDrag: PlanFloorDrag.band,
        ),
      );
}

/// The waiters' screen: no editor, the plan in service for good.
class ServiceFloor extends StatefulWidget {
  const ServiceFloor({super.key, required this.floor});

  final PosFloor floor;

  @override
  State<ServiceFloor> createState() => _ServiceFloorState();
}

class _ServiceFloorState extends State<ServiceFloor> {
  @override
  void initState() {
    super.initState();
    widget.floor.controller.setMode(PlanMode.service);
  }

  @override
  Widget build(BuildContext context) =>
      PlanServiceView(controller: widget.floor.controller);
}

/// An editor of your own: the plan's widgets in a layout of yours.
Widget ownEditor(PlanController c) => Row(children: [
      SizedBox(width: 280, child: PlanSymbolGallery(controller: c)),
      Expanded(child: PlanCanvas(controller: c)),
      SizedBox(width: 300, child: PlanPropertyPanel(controller: c)),
    ]);

/// The same floor twice, in service: an overview beside a close-up.
class TwoViews extends StatefulWidget {
  const TwoViews({super.key, required this.controller});

  final PlanController controller;

  @override
  State<TwoViews> createState() => _TwoViewsState();
}

class _TwoViewsState extends State<TwoViews> {
  bool _closeUp = false;

  @override
  void initState() {
    super.initState();
    widget.controller.setMode(PlanMode.service);
    // The view mounted last drives the camera's zoom focus.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => setState(() => _closeUp = true));
  }

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: PlanServiceView(
                controller: widget.controller,
                bar: const PlanServiceBar(visible: false),
                autofocus: false)),
        if (_closeUp)
          Expanded(child: PlanServiceView(controller: widget.controller)),
      ]);
}

/// A service bar of the POS's own, its Export off while a page flow runs.
Widget exportButton(PlanController c, VoidCallback onExport) =>
    ValueListenableBuilder<bool>(
      valueListenable: c.pageFlowBusy,
      builder: (context, busy, _) => TextButton(
          onPressed: busy ? null : onExport, child: const Text('Export')),
    );

/// Table 7 in the middle of the view, its zoom kept.
void centerOnSeven(PlanController c) {
  for (final detail in c.unitDetails) {
    if (detail.unit.label == '7' && detail.center != null) {
      c.centerOn(detail.center!);
      return;
    }
  }
}

/// The symbol libraries' state: they load in the background and never block
/// an edit.
Widget symbolsNotice(PlanController c) => ValueListenableBuilder<SymbolsState>(
      valueListenable: c.symbolsState,
      builder: (context, state, _) => switch (state) {
        SymbolsState.loading => const Text('Loading symbols'),
        SymbolsState.ready => const SizedBox.shrink(),
        SymbolsState.failed => TextButton(
            onPressed: c.retrySymbols, child: const Text('Retry symbols')),
      },
    );
