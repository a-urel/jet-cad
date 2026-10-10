// The restaurant embedding's demo host (spec 14b-2 H10): what a point-of-
// sale application does with the planner, through its public API only.
//
// Two dining areas (umbrella decision 12), each a FloorPlanController over
// a plan kept in memory, with its service layout kept beside it (spec 14d
// S4, S9: Design and back shows the moves again; Reset layout drops them);
// a Design / Service toggle; selection by table number; a table's context
// menu; the service options; table groups merged and split from the service
// bar (table-groups spec G6); the Salon's zones, framed and optionally
// focused (zone spec Z22); the Salon's badges on its tables, through the
// host's own widgets on the tables, and a button that centres the view on
// table 7 (host embedding API spec G-1 to G-7); the tables linked to the
// POS's ids through their host data, a double tap that opens a table, the
// moved tables, the pointer's table or floor point, and the design's table
// changes (spec E-1 to E-8); a Standard / POS look switch, the POS's look
// a `FloorPlanTheme` in the app's themes, a local `Theme` with a hand-built
// `ColorScheme` around the view and one field of the view's own (spec T-1,
// T-2, F-4; lib/demo_theme.dart); the host's own chrome and keys (spec
// C-1 to C-8): the editor's three profiles, a table inspector linking a
// table to the POS's id, a service bar of the demo's own built from the
// controller's commands, its own export dialog at every Export, an error
// of an export or a print logged, a table search in the app bar, and the
// keys taken from the plan; and a log of the API's state, in English,
// German or Turkish. An example and an integration surface, not a product.
import 'dart:async' show StreamSubscription, Timer, unawaited;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show
        AssetBundle,
        BrowserContextMenu,
        HardwareKeyboard,
        LogicalKeyboardKey,
        rootBundle;
import 'package:jet_cad_floor_plan/jet_cad_floor_plan.dart';
import 'package:jet_cad_restaurant_symbols/jet_cad_restaurant_symbols.dart';

import 'demo_strings.dart';
import 'demo_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Native platforms: the documents' family from the package's bytes.
    // The web reads the family the pubspec declares (14b-1 V-11a).
    await ensureFloorPlanFonts();
  } catch (error, stack) {
    // The text then measures in the platform's font; reported, as the
    // planner app does, and the demo still starts.
    FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'restaurant_demo',
        context: ErrorDescription('registering the plan font')));
  }
  registerFontLicences();
  // A right click on a table opens the demo's menu, not the browser's
  // (spec 14d S8): app-global, so the host's to decide.
  if (kIsWeb) await BrowserContextMenu.disableContextMenu();
  runApp(RestaurantDemo(plans: await loadSamplePlans(rootBundle)));
}

/// The sample plans by area name, so the demo opens on two furnished
/// areas; an area whose sample does not load starts empty.
Future<Map<String, String>> loadSamplePlans(AssetBundle bundle) async {
  final plans = <String, String>{};
  for (final name in const ['Salon', 'Teras']) {
    try {
      plans[name] =
          await bundle.loadString('assets/plans/${name.toLowerCase()}.json');
    } catch (_) {
      // Left out: the area starts empty.
    }
  }
  return plans;
}

/// The demo's theme seed, for the light and the dark theme alike.
const Color _seed = Colors.teal;

/// The demo. [plans] seeds the areas' stored plans by name (tests); an area
/// without one starts empty.
class RestaurantDemo extends StatefulWidget {
  const RestaurantDemo(
      {super.key,
      this.plans = const {},
      this.random,
      this.locale,
      this.printer});

  final Map<String, String> plans;

  /// Where Print sends the page; the platform's print dialog when null
  /// (tests give their own).
  final PagePrinter? printer;

  /// The source of "Random statuses" (tests seed it, 14c R-13).
  final math.Random? random;

  /// The language to start in; the system's when null (spec 14d L17).
  final Locale? locale;

  @override
  State<RestaurantDemo> createState() => _RestaurantDemoState();
}

class _RestaurantDemoState extends State<RestaurantDemo> {
  late Locale? _locale = widget.locale;

  /// The look the app bar switches (spec T-1): today's by default.
  DemoLook _look = DemoLook.standard;

  /// The app's theme for [brightness]: the seed's; under the POS look it
  /// carries the POS's `FloorPlanTheme` for that brightness, one extension
  /// per `ThemeData` (spec T-1). A switch animates as any theme change.
  ThemeData _theme(Brightness brightness) =>
      ThemeData(colorSchemeSeed: _seed, brightness: brightness, extensions: [
        if (_look == DemoLook.pos) posFloorPlanTheme(brightness),
      ]);

  @override
  Widget build(BuildContext context) => MaterialApp(
        onGenerateTitle: (context) => DemoStrings.of(context).title,
        // Dark theme spec D1: the planner follows the host's theme, and the
        // OS picks light or dark.
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        themeMode: ThemeMode.system,
        // Spec 14d L17: the three languages, switched in the app bar
        // through `MaterialApp.locale` (V-4), so all three can be looked at
        // without changing the system's language.
        locale: _locale,
        supportedLocales: floorPlanSupportedLocales,
        localizationsDelegates: floorPlanLocalizationsDelegates,
        home: DemoHome(
            plans: widget.plans,
            random: widget.random,
            printer: widget.printer,
            onLocale: (l) => setState(() => _locale = l),
            look: _look,
            onLook: (look) => setState(() => _look = look)),
      );
}

/// The demo's zones by area (zone spec Z22): host data, a table's
/// attribute in a POS's database, never the plan's. Zone names are data,
/// not translated.
const Map<String, Map<String, Set<String>>> kDemoZones = {
  'Salon': {
    'A': {'1', '2', '3', '4', '5'},
    'B': {'6', '7'},
    'C': {'8', '9', '10', '11'},
  },
};

/// The areas whose service view offers badges on its tables (host
/// embedding API spec G-5): the Salon's.
const Set<String> kBadgeAreas = {'Salon'};

/// The camera scale, in logical pixels per millimetre, below which a badge
/// is a dot (spec G-7): the Salon fitted in a canvas 700 px wide or more is
/// above it, and a zoom out to half of that is below.
const double kBadgeDetailScale = 0.025;

/// Where the badges sit (spec G-6): at the bottom of each table's box on
/// the screen, so the table's number chip stays visible; a dot below
/// [kBadgeDetailScale].
const FloorPlanOverlayLayout kBadgeLayout = FloorPlanOverlayLayout(
  anchor: Alignment.bottomCenter,
  detailBreakpoints: [kBadgeDetailScale],
);

/// The POS's own tables by area, by the id it links each to a table of the
/// plan with (host embedding API spec E-6, E-8): `<area>-<number>`, lower
/// case, as "Link tables" writes it. Host data, the rows of a POS's
/// database; the plan carries an id only once a table is linked.
final Map<String, Set<String>> kDemoTableIds = {
  'Salon': {for (var n = 1; n <= 11; n++) 'salon-$n'},
  'Teras': {for (var n = 1; n <= 6; n++) 'teras-$n'},
};

/// What the service's pointer line shows (spec E-3, E-4): the table the
/// mouse or stylus is over ([table]), no table (both null), or the floor
/// point a tap that missed every table went down at ([floor], world
/// millimetres, y up).
typedef PointerLine = ({String? table, Offset? floor});

/// The editor's profiles the side panel offers (host embedding API spec
/// C-5): today's editor, a floor whose staff place and arrange tables only,
/// and a plan only looked at.
enum DemoEditor {
  full(FloorPlanEditorCapabilities.full),
  tables(FloorPlanEditorCapabilities.tablesOnly),
  readOnly(FloorPlanEditorCapabilities.readOnly);

  const DemoEditor(this.capabilities);

  final FloorPlanEditorCapabilities capabilities;
}

/// The editor's top bar under [DemoEditor.readOnly] (spec C-2): Print and
/// Export, then the zoom; no object snap's read-out, since nothing is
/// drawn. The other profiles keep today's bar.
const FloorPlanEditorBar kReadOnlyEditorBar = FloorPlanEditorBar(actions: [
  FloorPlanEditorAction.print,
  FloorPlanEditorAction.export,
  FloorPlanEditorAction.zoom,
]);

/// The demo's own export dialog (host embedding API spec C-4): one list of
/// the four choices, the one last made marked, a tap on one exports it.
/// [initial] is the planner's remembered choice (or the demo's own, for its
/// own bar); null cancels.
Future<FloorPlanExportChoice?> showDemoExportDialog(
    BuildContext context, FloorPlanExportChoice initial) {
  final words = FloorPlanStrings.of(context);
  final choices = [
    (
      FloorPlanExportChoice(
          format: FloorPlanExportFormat.pdf, dpi: initial.dpi),
      'PDF',
      'demo-export-pdf'
    ),
    for (final dpi in FloorPlanExportDpi.values)
      (
        FloorPlanExportChoice(format: FloorPlanExportFormat.png, dpi: dpi),
        'PNG, ${dpi.value} dpi',
        'demo-export-png-${dpi.value}'
      ),
  ];
  return showDialog<FloorPlanExportChoice>(
    context: context,
    builder: (context) => SimpleDialog(
      key: const Key('demo-export-dialog'),
      title: Text(words.exportTitle),
      children: [
        for (final (choice, label, key) in choices)
          SimpleDialogOption(
            key: Key(key),
            onPressed: () => Navigator.of(context).pop(choice),
            child: Row(children: [
              SizedBox(
                  width: 28,
                  child: choice == initial
                      ? const Icon(Icons.check, size: 18)
                      : null),
              Text(label),
            ]),
          ),
        SimpleDialogOption(
          key: const Key('demo-export-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(words.cancel)),
        ),
      ],
    ),
  );
}

/// The demo's table inspector (host embedding API spec C-6): the POS's id
/// of the one table selected in the editor, written by
/// `FloorPlanController.setTableData` on Enter (an empty field unlinks).
class PosIdField extends StatefulWidget {
  const PosIdField({super.key, required this.id, required this.onSubmitted});

  /// The table's `data['id']`, null when it has none.
  final String? id;
  final void Function(String id) onSubmitted;

  @override
  State<PosIdField> createState() => _PosIdFieldState();
}

class _PosIdFieldState extends State<PosIdField> {
  late final TextEditingController _text =
      TextEditingController(text: widget.id ?? '');

  @override
  void didUpdateWidget(PosIdField old) {
    super.didUpdateWidget(old);
    // Linked elsewhere ("Link tables", an undo): shown at once.
    if (widget.id != old.id) _text.text = widget.id ?? '';
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: TextField(
          key: const Key('pos-id'),
          controller: _text,
          decoration: InputDecoration(
              labelText: DemoStrings.of(context).posId, isDense: true),
          onSubmitted: widget.onSubmitted,
        ),
      );
}

/// One dining area: its controller, the plan last saved and the service
/// layout last seen, in memory.
final class Area {
  Area(this.name, this.controller, this.stored,
      {this.zones = const {},
      this.offersBadges = false,
      this.tableIds = const {}});

  final String name;
  final FloorPlanController controller;
  String? stored;

  /// The POS's tables in this area, by id ([kDemoTableIds]).
  final Set<String> tableIds;

  /// The area's zones by name, each its table numbers (Z22): none for an
  /// area without zones.
  final Map<String, Set<String>> zones;

  /// The zone shown, null for all of them; kept with the area.
  String? zone;

  /// Whether the tables outside [zone] fade; kept with the area.
  bool fadeOthers = false;

  /// Whether the service view offers the "Badges" switch ([kBadgeAreas]).
  final bool offersBadges;

  /// Whether the service view shows a badge on each table; kept with the
  /// area.
  bool badges = false;

  /// The service layout, kept on `serviceLayoutChanges` (spec 14d S4).
  String? layout;

  /// Each table's status by its [DemoHomeState.kStatuses] name, so the
  /// captions are worded again when the language changes (review F-6).
  final Map<String, String> statusNames = {};

  /// Each group's status by name, as [statusNames] (G6).
  final Map<String, String> groupStatusNames = {};
}

class DemoHome extends StatefulWidget {
  const DemoHome(
      {super.key,
      required this.plans,
      this.random,
      this.printer,
      this.onLocale,
      this.look = DemoLook.standard,
      this.onLook});

  final Map<String, String> plans;
  final math.Random? random;
  final PagePrinter? printer;

  /// Switches the app's language (spec 14d L17).
  final void Function(Locale locale)? onLocale;

  /// The app's look (spec T-1): under [DemoLook.pos] the view sits in a
  /// local `Theme` ([posViewTheme]) and passes [kPosViewOverride].
  final DemoLook look;

  /// Switches the app's look.
  final void Function(DemoLook look)? onLook;

  @override
  State<DemoHome> createState() => DemoHomeState();
}

class DemoHomeState extends State<DemoHome> {
  /// One library and one thumbnail cache for both areas (R-11).
  final SymbolLibraryLoader _symbols = SymbolLibraryLoader(
      sources: const [furnitureSymbolSource, restaurantSymbolSource]);
  final SymbolThumbnails _thumbnails = SymbolThumbnails(maxEntries: 128);
  late final List<Area> areas = [
    for (final name in const ['Salon', 'Teras'])
      Area(
          name,
          FloorPlanController(
              symbols: _symbols,
              thumbnails: _thumbnails,
              json: widget.plans[name]),
          widget.plans[name],
          zones: kDemoZones[name] ?? const {},
          offersBadges: kBadgeAreas.contains(name),
          tableIds: kDemoTableIds[name] ?? const {}),
  ];
  int _area = 0;
  late final math.Random _random = widget.random ?? math.Random();
  final TextEditingController _number = TextEditingController();

  /// The service options (spec 14d S5, S7).
  bool moves = true;
  bool longPressMenu = false;

  /// The newest line first.
  final List<String> log = [];

  /// The service's pointer line (spec E-3, E-4), null when there is nothing
  /// to show: a line of its own, not the log, rebuilt alone at hover rate.
  /// Cleared when the mode, the area or the plan changes, since the view
  /// then sends no null for the table it leaves (S-5).
  final ValueNotifier<PointerLine?> pointer = ValueNotifier(null);

  /// Each area's subscription to its design's table changes (spec E-5).
  final List<StreamSubscription<FloorPlanDesignChange>> _changes = [];

  /// Minutes since the demo started, one tick a minute. The badges' minute
  /// counters read it through a `ValueListenableBuilder` inside the badge:
  /// a tick rebuilds the counters, never the overlays (spec G-5: live data
  /// is the host's own state management).
  final ValueNotifier<int> minutes = ValueNotifier(0);
  Timer? _ticker;

  /// How many times the badge builder ran (tests: pan and zoom build none).
  int badgeBuilds = 0;

  /// The editor's profile, for both areas (spec C-5): today's by default.
  DemoEditor editor = DemoEditor.full;

  /// Whether the service shows the demo's own bar in place of the planner's
  /// (spec C-1, C-3).
  bool ownBar = false;

  /// Whether every Export asks the demo's own dialog (spec C-4).
  bool ownExportDialog = false;

  /// Whether the plan binds its own keys and takes the focus when shown
  /// (spec C-7); false gives the keyboard to the demo.
  bool planKeys = true;

  /// The own bar's last export choice, as the planner remembers its own.
  FloorPlanExportChoice ownChoice = FloorPlanExportChoice.initial;

  /// The last export made (tests read its bytes).
  FloorPlanExport? lastExport;

  final TextEditingController _search = TextEditingController();

  Area get area => areas[_area];

  @override
  void initState() {
    super.initState();
    _ticker =
        Timer.periodic(const Duration(minutes: 1), (_) => minutes.value++);
    // The shared library is loaded by the first view that shows it; a host
    // need not call `load()` (14b-2 review F-3).
    for (final a in areas) {
      final c = a.controller;
      c.mode.addListener(() => _log(_words.logMode(
          a.name,
          c.mode.value == FloorPlanMode.design
              ? _words.design
              : _words.service)));
      c.mode.addListener(_clearPointer);
      c.selectedTables.addListener(() => _log(_words.logSelected(
          a.name, (c.selectedTables.value.toList()..sort()).join(', '))));
      c.dirty.addListener(() => _log(_words.logDirty(a.name, c.dirty.value)));
      // The tables and warnings follow every change of the active plan;
      // the groups line follows the groups and their statuses.
      for (final l in [c.revision, c.tableGroups, c.groupStatuses]) {
        l.addListener(() {
          if (mounted) setState(() {});
        });
      }
      // Kept on every change of the layout, never on a mode switch or a
      // load, which start from the design (S4).
      c.serviceLayoutChanges
          .addListener(() => a.layout = c.serviceLayoutJson());
      _changes.add(c.designChanges.listen((e) => _designChanged(a, e)));
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    minutes.dispose();
    pointer.dispose();
    for (final s in _changes) {
      unawaited(s.cancel());
    }
    for (final a in areas) {
      a.controller.dispose();
    }
    _thumbnails.dispose();
    _symbols.dispose();
    _number.dispose();
    _search.dispose();
    super.dispose();
  }

  /// The demo's words in the app's language (spec 14d L17).
  DemoStrings get _words => DemoStrings.of(context);

  /// The language the statuses were last worded in.
  Type? _wordedIn;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = _words.runtimeType;
    if (_wordedIn != null && _wordedIn != language) {
      for (final a in areas) {
        _applyStatuses(a);
      }
    }
    _wordedIn = language;
  }

  void _log(String line) {
    if (!mounted) return;
    setState(() {
      log.insert(0, line);
      if (log.length > 40) log.removeLast();
    });
  }

  void _clearPointer() => pointer.value = null;

  /// The design's table changes (spec E-5), logged: the tables added and
  /// removed, and a replaced plan; a changed table (a number, a move, its
  /// data) is not logged. A plan replaced in the service starts from the
  /// design, so the area's kept layout goes back on it then (S4), whoever
  /// replaced it: the report comes after the load, never inside it.
  void _designChanged(Area a, FloorPlanDesignChange change) {
    if (!mounted) return;
    final words = _words;
    switch (change) {
      case FloorPlanTableAdded(:final table):
        _log(words.logTableAdded(a.name, table.table.number ?? '—'));
      case FloorPlanTableRemoved(:final table):
        _log(words.logTableRemoved(a.name, table.table.number ?? '—'));
      case FloorPlanPlanReplaced():
        _log(words.logPlanReplaced(a.name));
        if (a.controller.mode.value == FloorPlanMode.selection) {
          _restoreLayout(a);
        }
      case FloorPlanTableChanged():
        break;
    }
  }

  /// "Link tables" (spec E-6): every numbered table without an id gets
  /// `<area>-<number>`, lower case, beside the data it carries, in one undo
  /// step. A number two tables share is left out: the planner refuses an
  /// ambiguous link, and the whole batch with it. Design mode only.
  void linkTables(Area a) {
    final c = a.controller;
    final shared = {
      for (final w in c.numberingWarnings)
        if (w is DuplicateNumber) w.number,
    };
    final byNumber = <String, Map<String, String>>{};
    for (final detail in c.tableDetails) {
      final n = detail.table.number;
      if (n == null || shared.contains(n) || detail.data.containsKey('id')) {
        continue;
      }
      byNumber[n] = {...detail.data, 'id': '${a.name}-$n'.toLowerCase()};
    }
    c.setTablesData(byNumber);
    _log(_words.logLinked(a.name, byNumber.length));
  }

  /// The POS's tables in [a] that its floor does not draw, by id (spec E-8,
  /// the guide's recipe): the ids no visible table carries. A table on a
  /// hidden layer is not drawn, so its id counts as unlinked.
  Set<String> unlinkedTables(Area a) {
    final drawn = {
      for (final detail in a.controller.tableDetails)
        if (detail.table.visible && detail.data['id'] != null)
          detail.data['id']!,
    };
    return a.tableIds.difference(drawn);
  }

  /// A double tap opens table [number] (spec E-2): logged with the id the
  /// table is linked by, read from the service copy's details, which carry
  /// the design's data (E-6); no id when two tables carry the number, which
  /// names neither (the guide's `idOf`: an ambiguous link is refused on
  /// write and read the same way). Its two taps were logged first: a host
  /// that acts on a tap acts on each tap of a double tap too (R-3).
  void _opened(Area a, String number) {
    final tables = [
      for (final detail in a.controller.tableDetails)
        if (detail.table.number == number) detail,
    ];
    final id = tables.length == 1 ? tables.single.data['id'] : null;
    _log(_words.logOpened(a.name, number, id));
  }

  /// The toggle (H10). The service layout is kept, not discarded (spec
  /// 14d S9): entering the service puts it back.
  void _setMode(FloorPlanMode next) {
    area.controller.setMode(next);
    if (next == FloorPlanMode.selection) _restoreLayout(area);
  }

  /// [a]'s kept layout, put back on its service copy (S4); entries the
  /// design no longer matches are dropped and logged.
  void _restoreLayout(Area a) {
    final layout = a.layout;
    if (layout == null) return;
    final r = a.controller.restoreServiceLayout(layout);
    if (r.applied.isEmpty && r.dropped.isEmpty) return;
    _log(_words.logRestored(a.name, r.applied.length, r.dropped.length));
  }

  /// A table's context menu (spec 14d S6): the table is already selected
  /// alone, or with the selection that held it -- unless it is locked,
  /// which leaves the selection alone: the menu then acts on the table
  /// only (review F-1).
  Future<void> _tableMenu(String number, Offset at) async {
    final a = area;
    final selected = a.controller.selectedTables.value;
    final locked = !selected.contains(number);
    final tables = locked ? {number} : selected;
    _log(_words.logMenu(a.name, number));
    final words = _words;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(at.dx, at.dy, at.dx, at.dy),
      items: [
        PopupMenuItem(enabled: false, child: Text(words.tableTitle(number))),
        PopupMenuItem(
            key: const Key('menu-select'),
            value: 'select',
            enabled: !locked,
            child: Text(words.selectOnlyThis)),
        const PopupMenuDivider(),
        for (final name in kStatuses.keys)
          PopupMenuItem(
              key: Key('menu-status-${name.toLowerCase()}'),
              value: 'status:$name',
              child: Text(words.statusName(name))),
      ],
    );
    if (choice == null || !mounted || !identical(a, area)) return;
    if (choice == 'select') {
      a.controller.select({number});
    } else if (choice.startsWith('status:')) {
      // A locked table alone; otherwise the selection, a group's whole.
      _setStatus(choice.substring('status:'.length), locked ? tables : null);
    }
  }

  void _save() {
    area.stored = area.controller.designJson();
    area.controller.markSaved();
    _log(_words.logStored(area.name, area.stored!.length));
  }

  void _revert() {
    final stored = area.stored;
    if (stored == null) {
      area.controller.newPlan();
    } else {
      area.controller.load(stored);
    }
    _log(_words.logReloaded(area.name));
    _clearPointer();
    // A load in the service starts from the design: the layout goes back
    // when designChanges reports the replaced plan (_designChanged).
    // A load drops a framing (the guide: frame after a load).
    if (area.zone case final z?) {
      showZone(area, area.zones[z]!, fadeOthers: area.fadeOthers);
    }
  }

  /// The statuses a POS would set (14c S10): by the selected tables.
  static final Map<String, TableStatus?> kStatuses = {
    'Free': null,
    'Ordered': TableStatus(color: const Color(0x99FFB300)),
    'Eating': TableStatus(color: const Color(0x9943A047)),
    'Bill': TableStatus(color: const Color(0x99E53935), caption: 'Bill'),
  };

  /// [kStatuses]'s status [name], its caption in the app's language.
  TableStatus? _statusFor(String name) {
    final status = kStatuses[name];
    if (status == null || status.caption == null) return status;
    return TableStatus(color: status.color, caption: _words.statusName(name));
  }

  /// Sets status [name] on [tables], the selected ones when null. A
  /// selected group, when no [tables] are given, gets a group status (G6),
  /// which overrides its members' own; Free clears it.
  void _setStatus(String name, [Set<String>? tables]) {
    final a = area;
    final group = tables == null ? a.controller.selectedGroup.value : null;
    if (group != null) {
      if (kStatuses[name] == null) {
        a.groupStatusNames.remove(group);
      } else {
        a.groupStatusNames[group] = name;
      }
      _applyStatuses(a);
      _log(_words.logGroupStatus(a.name, _words.statusName(name), group));
      return;
    }
    final targets = tables ?? a.controller.selectedTables.value;
    for (final n in targets) {
      if (kStatuses[name] == null) {
        a.statusNames.remove(n);
      } else {
        a.statusNames[n] = name;
      }
    }
    _applyStatuses(a);
    _log(_words.logStatus(a.name, _words.statusName(name),
        (targets.toList()..sort()).join(', ')));
  }

  /// [a]'s table and group statuses, worded in the app's language.
  void _applyStatuses(Area a) {
    a.controller.setTableStatus({
      for (final e in a.statusNames.entries)
        if (_statusFor(e.value) case final status?) e.key: status,
    });
    a.controller.setGroupStatus({
      for (final e in a.groupStatusNames.entries)
        if (_statusFor(e.value) case final status?) e.key: status,
    });
  }

  void _randomStatuses() {
    final a = area;
    final names = kStatuses.keys.toList();
    a.statusNames.clear();
    for (final t in a.controller.tables) {
      final n = t.number;
      if (n == null) continue;
      final name = names[_random.nextInt(names.length)];
      if (kStatuses[name] != null) a.statusNames[n] = name;
    }
    _applyStatuses(a);
    _log(_words.logRandom(a.name, a.controller.tableStatuses.value.length));
  }

  /// Orders numbers and group ids as people read them: a shared prefix,
  /// then the digits by value (`G2` before `G10`, `3` before `12`).
  static int byNumber(String a, String b) {
    final x = _tail.firstMatch(a), y = _tail.firstMatch(b);
    if (x != null && y != null && x[1] == y[1]) {
      final order = BigInt.parse(x[2]!).compareTo(BigInt.parse(y[2]!));
      if (order != 0) return order;
    }
    return a.compareTo(b);
  }

  static final RegExp _tail = RegExp(r'^(\D*)(\d+)$');

  /// The trailing digits of any group id, whatever its prefix: a POS's own
  /// `VIP9` counts as 9, so the next id is `G10` (G6).
  static final RegExp _idSuffix = RegExp(r'(\d+)$');

  static String _sorted(Iterable<String> numbers) =>
      (numbers.toList()..sort(byNumber)).join(', ');

  /// `G<n>`, n the largest numeric suffix among [ids] plus one; `G1` when
  /// none has one (G6).
  static String nextGroupId(Iterable<String> ids) {
    var max = BigInt.zero;
    for (final id in ids) {
      final m = _idSuffix.firstMatch(id.trim());
      if (m == null) continue;
      final n = BigInt.parse(m[1]!);
      if (n > max) max = n;
    }
    return 'G${max + BigInt.one}';
  }

  /// G6's merge rule for the requested [numbers] over [groups]: the groups
  /// to set and the id merged into. [selectable] gives a group's selectable
  /// members' numbers over the same [groups] (in `_merge`,
  /// `FloorPlanController.selectableMembers`, table-groups fixes spec X2).
  ///
  /// **Grow:** when exactly one group has selectable members and [numbers]
  /// include all of them, that group grows by the other numbers under its
  /// id and label. Those numbers leave any other group they were in; a group
  /// left empty goes. A request of exactly that group's selectable members
  /// grows it by nothing: the same groups again.
  ///
  /// **New group:** otherwise [numbers] leave every group they are in (a
  /// group left empty goes) and form [nextGroupId] of the groups before the
  /// merge. [numbers] are not empty (a group needs a member).
  static ({Map<String, TableGroup> groups, String id}) mergeGroups(
      Map<String, TableGroup> groups,
      Set<String> numbers,
      Set<String> Function(String id) selectable) {
    final whole = [
      for (final id in groups.keys)
        if (selectable(id) case final s
            when s.isNotEmpty && numbers.containsAll(s))
          id
    ];
    final id = whole.length == 1 ? whole.single : nextGroupId(groups.keys);
    final next = <String, TableGroup>{};
    for (final e in groups.entries) {
      final rest = e.value.members.difference(numbers);
      if (e.key == id) {
        next[id] = TableGroup(
            members: {...e.value.members, ...numbers}, label: e.value.label);
      } else if (rest.length == e.value.members.length) {
        next[e.key] = e.value;
      } else if (rest.isNotEmpty) {
        next[e.key] = TableGroup(members: rest, label: e.value.label);
      }
    }
    next.putIfAbsent(id, () => TableGroup(members: numbers));
    return (groups: next, id: id);
  }

  /// The service bar's Merge (G6): any request is accepted, an empty one
  /// changes nothing. A group the merge empties takes its group status with
  /// it (ruling R-C5-2).
  void _merge(Area a, Set<String> numbers) {
    if (numbers.isEmpty) return;
    final c = a.controller;
    final before = c.tableGroups.value;
    final merged = mergeGroups(before, numbers, c.selectableMembers);
    c.setTableGroups(merged.groups);
    final gone = {
      for (final id in before.keys)
        if (!merged.groups.containsKey(id)) id
    };
    if (gone.any(a.groupStatusNames.containsKey)) {
      a.groupStatusNames.removeWhere((id, _) => gone.contains(id));
      _applyStatuses(a);
    }
    _log(_words.logMerged(a.name, _sorted(numbers), merged.id));
  }

  /// The service bar's Split (G6): the group goes, and its status with it.
  void _split(Area a, String id) {
    final c = a.controller;
    c.setTableGroups({...c.tableGroups.value}..remove(id));
    a.groupStatusNames.remove(id);
    _applyStatuses(a);
    _log(_words.logSplit(a.name, id));
  }

  /// The name [kStatuses] gives [status], by its colour (a caption is
  /// worded), or `status` for another one.
  static String _statusName(TableStatus status) => kStatuses.entries
      .firstWhere((e) => e.value?.color == status.color,
          orElse: () => const MapEntry('status', null))
      .key;

  /// The groups line: `G1: 3+7+12 (Bill)`, by id.
  String _groupsText(FloorPlanController c) {
    final groups = c.tableGroups.value;
    if (groups.isEmpty) return _words.none;
    final statuses = c.groupStatuses.value;
    return [
      for (final id in groups.keys.toList()..sort(byNumber))
        [
          '$id: ${(groups[id]!.members.toList()..sort(byNumber)).join('+')}',
          if (statuses[id] case final s?)
            ' (${_words.statusName(_statusName(s))})',
        ].join()
    ].join(', ');
  }

  void _select() {
    final numbers = {for (final n in _number.text.split(',')) n.trim()}
      ..remove('');
    area.controller.select(numbers);
  }

  /// A zone tab (zone spec Z19, Z21): the zone's tables framed, the page
  /// when none is drawn, and the others faded when [fadeOthers].
  void showZone(Area a, Set<String> numbers, {required bool fadeOthers}) {
    final controller = a.controller;
    if (!controller.fitToTables(numbers)) controller.fitToView();
    controller.setTableFocus(fadeOthers ? numbers : null);
  }

  /// The All tab (Z19, Z21): the page, no focus.
  void showAllZones(Area a) {
    final controller = a.controller;
    controller.fitToView();
    controller.setTableFocus(null);
  }

  /// A badge's figures (spec G-5's demo): the guests at table [number] of
  /// [seats] seats and the minutes they had been seated when the demo
  /// started, under the [kStatuses] status [name]; null for a free table
  /// (no status, Free, or a status the demo does not know). Made up, but
  /// fixed by the number, the seats and the status, so a seeded "Random
  /// statuses" gives the same badges every run.
  static ({int guests, int minutes})? badgeFigures(
      String number, int seats, String? name) {
    final k = int.tryParse(number) ?? number.length;
    final minutes = switch (name) {
      'Ordered' => 5 + k % 10,
      'Eating' => 20 + 3 * k % 25,
      'Bill' => 45 + 7 * k % 30,
      _ => null,
    };
    if (minutes == null) return null;
    return (guests: 1 + k % math.max(seats, 1), minutes: minutes);
  }

  /// A table's badge (spec G-5): its guests over its seats and their
  /// minutes, framed in the table's status colour (the effective one: a
  /// group's over the table's), outlined when selected, a dot below
  /// [kBadgeDetailScale] (G-7), faded when the zone focus leaves the table
  /// out -- the badges paint above the planner's veil, so the host fades
  /// them with [FloorPlanTableOverlay.focused].
  Widget? tableBadge(BuildContext context, FloorPlanTableOverlay table) {
    badgeBuilds++;
    final number = table.detail.table.number!;
    final seats = table.detail.table.seats;
    final status = table.status;
    final figures = badgeFigures(
        number, seats, status == null ? null : _statusName(status));
    final scheme = Theme.of(context).colorScheme;
    final tone = status?.color.withAlpha(255) ?? scheme.outline;
    final Widget badge;
    if (table.detailLevel == 0) {
      badge = Container(
        key: Key('badge-dot-$number'),
        width: 12,
        height: 12,
        decoration: BoxDecoration(
            color: figures == null ? scheme.surface : tone,
            shape: BoxShape.circle,
            border: Border.all(color: tone, width: 2)),
      );
    } else {
      final style = Theme.of(context).textTheme.labelSmall;
      final words = DemoStrings.of(context);
      badge = Container(
        key: Key('badge-$number'),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: table.selected ? scheme.primary : tone,
                width: table.selected ? 2 : 1)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.person, size: 12, color: tone),
          Text('${figures?.guests ?? 0}/$seats',
              key: Key('badge-guests-$number'), style: style),
          if (figures != null) ...[
            const SizedBox(width: 6),
            ValueListenableBuilder<int>(
              valueListenable: minutes,
              builder: (context, now, _) => Text(
                  words.minutes(figures.minutes + now),
                  key: Key('badge-minutes-$number'),
                  style: style),
            ),
          ],
        ]),
      );
    }
    // One semantics node per badge, named by its table: a screen reader
    // (and the web's accessibility tree) reads each badge apart.
    return Semantics(
      container: true,
      label: DemoStrings.of(context).tableTitle(number),
      child: Opacity(opacity: table.focused ? 1 : 0.35, child: badge),
    );
  }

  /// Table 7 in the middle of [a]'s view, its zoom kept (spec G-3): its
  /// centre from `tableDetails`. Nothing when the plan draws no table 7.
  void centerOnSeven(Area a) {
    final c = a.controller;
    for (final detail in c.tableDetails) {
      final center = detail.center;
      if (detail.table.number == '7' && center != null) {
        c.centerOn(center);
        return;
      }
    }
  }

  /// An export made by the planner's Export or the demo's own bar: logged
  /// with its file name and size.
  void _exported(Area a, FloorPlanExport export) {
    lastExport = export;
    _log(_words.logExported(a.name, export.fileName, export.bytes.length));
  }

  /// The own bar's Export (spec C-3): the demo's dialog, then the
  /// controller's `exportPlan`, which shows no dialog; null from it (another
  /// export or a print running, no page, the plan replaced) exports nothing.
  Future<void> _ownExport(Area a) async {
    final choice = await showDemoExportDialog(context, ownChoice);
    if (choice == null || !mounted) return;
    ownChoice = choice;
    try {
      final export =
          await a.controller.exportPlan(choice, name: a.name.toLowerCase());
      if (export != null) _exported(a, export);
    } catch (error) {
      _log(_words.logPageFlowError(a.name, error));
    }
  }

  /// The own bar's Print (spec C-3): the controller's `printPlan`.
  Future<void> _ownPrint(Area a) async {
    try {
      await a.controller
          .printPlan(printer: widget.printer, name: a.name.toLowerCase());
    } catch (error) {
      _log(_words.logPageFlowError(a.name, error));
    }
  }

  /// The service bar of the demo's own (spec C-1, C-3), in place of the
  /// planner's: the area's name, then Undo, Redo, Merge, Split, Export and
  /// Print in the planner's words, each enabled by the controller's own
  /// state as the planner's buttons are.
  Widget _ownServiceBar(Area a) {
    final c = a.controller;
    final words = FloorPlanStrings.of(context);
    Widget button(String key, String label, VoidCallback? onPressed) =>
        TextButton(key: Key(key), onPressed: onPressed, child: Text(label));
    return Material(
      key: const Key('own-bar-row'),
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: SizedBox(
        height: 44,
        child: Row(children: [
          const SizedBox(width: 12),
          Text(a.name),
          const SizedBox(width: 12),
          ValueListenableBuilder<bool>(
              valueListenable: c.canUndo,
              builder: (_, can, __) =>
                  button('own-undo', words.undo, can ? c.undo : null)),
          ValueListenableBuilder<bool>(
              valueListenable: c.canRedo,
              builder: (_, can, __) =>
                  button('own-redo', words.redo, can ? c.redo : null)),
          // What the planner's Merge would send, null when it would be
          // disabled; Split's is the selected group.
          ValueListenableBuilder<Set<String>?>(
              valueListenable: c.mergeCandidate,
              builder: (_, numbers, __) => button('own-merge', words.merge,
                  numbers == null ? null : () => _merge(a, numbers))),
          ValueListenableBuilder<String?>(
              valueListenable: c.selectedGroup,
              builder: (_, id, __) => button('own-split', words.split,
                  id == null ? null : () => _split(a, id))),
          button('own-export', words.exportEllipsis, () => _ownExport(a)),
          button('own-print', words.printEllipsis, () => _ownPrint(a)),
        ]),
      ),
    );
  }

  /// The service bar's look (spec C-1): the planner's own, with the area's
  /// name before its buttons; hidden under [ownBar].
  FloorPlanServiceBar _serviceBar(Area a) => ownBar
      ? const FloorPlanServiceBar(visible: false)
      : FloorPlanServiceBar(leading: [
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(child: Text(a.name, key: const Key('bar-area')))),
        ]);

  /// The demo's table inspector (spec C-6), under [DemoEditor.tables]: the
  /// one numbered table selected in the editor, linked to the POS's id.
  Widget? _inspector(BuildContext context, FloorPlanTableDetail table) {
    final number = table.table.number!;
    return PosIdField(
        key: ValueKey(number),
        id: table.data['id'],
        onSubmitted: (id) => _linkTable(area, number, id));
  }

  /// Links table [number] of [a] to [id], its other data kept; an empty
  /// [id] unlinks it (spec E-6, E-7).
  void _linkTable(Area a, String number, String id) {
    final c = a.controller;
    final tables = [
      for (final d in c.tableDetails)
        if (d.table.number == number) d,
    ];
    if (tables.length != 1) return;
    final data = {...tables.single.data};
    final trimmed = id.trim();
    if (trimmed.isEmpty) {
      data.remove('id');
    } else {
      data['id'] = trimmed;
    }
    if (c.setTableData(number, data)) {
      _log(_words.logLinkedTable(a.name, number, data['id']));
    }
  }

  /// The app bar's search (spec C-7's host field): selects the table and
  /// brings it to the middle of the view, its zoom kept.
  void _find(String text) {
    final a = area;
    final c = a.controller;
    final number = text.trim();
    if (number.isEmpty) return;
    for (final detail in c.tableDetails) {
      final center = detail.center;
      if (detail.table.number == number && center != null) {
        c.select({number});
        c.centerOn(center);
        _log(_words.logFound(a.name, number));
        return;
      }
    }
    _log(_words.logNotFound(a.name, number));
  }

  /// The demo's own keys (spec C-7), while [planKeys] is off: Undo, Redo,
  /// Delete and Escape call the controller's commands. A key typed into
  /// a text field inside the view (the inspector, the editor's panels)
  /// stays the field's.
  KeyEventResult _demoKey(Area a, KeyEvent event) {
    if (planKeys) return KeyEventResult.ignored;
    final typing = FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<EditableText>() !=
        null;
    if (typing) return KeyEventResult.ignored;
    final c = a.controller;
    final design = c.mode.value == FloorPlanMode.design;
    for (final (activator, name, command)
        in <(SingleActivator, String, void Function())>[
      (
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true),
        'Ctrl+Z',
        c.undo
      ),
      (
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true),
        'Cmd+Z',
        c.undo
      ),
      (
        const SingleActivator(LogicalKeyboardKey.keyY, control: true),
        'Ctrl+Y',
        c.redo
      ),
      (
        const SingleActivator(LogicalKeyboardKey.keyZ,
            control: true, shift: true),
        'Ctrl+Shift+Z',
        c.redo
      ),
      (
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true),
        'Cmd+Shift+Z',
        c.redo
      ),
      // The planner's Delete has no other path: the command deletes the
      // editor's selection, as the key would.
      (
        const SingleActivator(LogicalKeyboardKey.delete),
        'Delete',
        c.deleteSelection
      ),
      (
        const SingleActivator(LogicalKeyboardKey.backspace),
        'Backspace',
        c.deleteSelection
      ),
      // Escape: back to the Select tool, then no selection.
      (
        const SingleActivator(LogicalKeyboardKey.escape),
        'Escape',
        () {
          if (design && c.activeTool.value != FloorPlanTool.select) {
            c.selectTool(FloorPlanTool.select);
          } else {
            c.select(const {});
          }
        }
      ),
    ]) {
      if (activator.accepts(event, HardwareKeyboard.instance)) {
        command();
        _log(_words.logKey(a.name, name));
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  /// [a]'s view, with the host's options.
  Widget _view(Area a) {
    final c = a.controller;
    return FloorPlanView(
      key: ObjectKey(c),
      controller: c,
      exportName: a.name.toLowerCase(),
      printer: widget.printer,
      onExport: (e) => _exported(a, e),
      onTableTap: (n) => _log(_words.logTapped(a.name, n)),
      onLayoutChanged: () => _log(_words.logLayoutChanged(a.name)),
      serviceMoves: moves,
      longPress: longPressMenu
          ? FloorPlanLongPress.contextMenu
          : FloorPlanLongPress.toggleSelection,
      onTableContextMenu: _tableMenu,
      onGroupTap: (id, n) => _log(_words.logGroupTapped(a.name, id, n)),
      onMergeRequested: (numbers) => _merge(a, numbers),
      onSplitRequested: (id) => _split(a, id),
      tableOverlayBuilder: a.badges ? tableBadge : null,
      tableOverlayLayout: kBadgeLayout,
      onTableDoubleTap: (n) => _opened(a, n),
      onTablesMoved: (moved) => _log(_words.logMoved(
          a.name, _sorted([for (final d in moved) d.table.number ?? '—']))),
      onTableHover: (n) => pointer.value = (table: n, floor: null),
      onFloorTap: (w) => pointer.value = (table: null, floor: w),
      theme: widget.look == DemoLook.pos ? kPosViewOverride : null,
      // Spec C-1 to C-7: the host's own chrome and keys.
      serviceBar: _serviceBar(a),
      editorBar: editor == DemoEditor.readOnly
          ? kReadOnlyEditorBar
          : const FloorPlanEditorBar(),
      editorCapabilities: editor.capabilities,
      tableInspectorBuilder: editor == DemoEditor.tables ? _inspector : null,
      onExportDialog: ownExportDialog ? showDemoExportDialog : null,
      onPageFlowError: (error) => _log(_words.logPageFlowError(a.name, error)),
      shortcuts: planKeys,
      autofocus: planKeys,
    );
  }

  /// The ambient theme [posViewTheme] last built from, and what it built:
  /// built again only when the ambient one changes, not at every build.
  ThemeData? _posAmbient;
  ThemeData? _posTheme;

  /// The view's `Theme`: under the POS look [posViewTheme] of [ambient];
  /// otherwise [ambient] itself, so the tree keeps its shape (a view
  /// remounted on its controller within one frame would throw) and the
  /// standard look is today's.
  ThemeData _viewTheme(ThemeData ambient) {
    if (widget.look != DemoLook.pos) return ambient;
    if (!identical(ambient, _posAmbient)) {
      _posAmbient = ambient;
      _posTheme = posViewTheme(ambient);
    }
    return _posTheme!;
  }

  /// [zone] of [a], or all of them when null.
  void _setZone(Area a, String? zone) {
    setState(() => a.zone = zone);
    if (zone == null) {
      showAllZones(a);
    } else {
      showZone(a, a.zones[zone]!, fadeOthers: a.fadeOthers);
    }
  }

  /// "Fade the others": applied at once to the zone shown.
  void _setFadeOthers(Area a, bool fade) {
    setState(() => a.fadeOthers = fade);
    if (a.zone case final zone?) {
      showZone(a, a.zones[zone]!, fadeOthers: fade);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = area;
    final c = a.controller;
    final words = _words;
    final title = Theme.of(context).textTheme.titleSmall;
    return Scaffold(
      appBar: AppBar(
        title: Text(words.title),
        actions: [
          // Spec C-7: a field of the host's beside the plan. It keeps the
          // focus when a button of the app is pressed (a press on the plan
          // still takes it), and Enter leaves it there for the next search.
          SizedBox(
            width: 160,
            child: TextField(
              key: const Key('find-table'),
              controller: _search,
              decoration: InputDecoration(
                  hintText: words.findTable,
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 18)),
              onTapOutside: (_) {},
              onEditingComplete: () {},
              onSubmitted: _find,
            ),
          ),
          const SizedBox(width: 16),
          // Spec 14d L17: the app's language.
          SegmentedButton<String>(
            key: const Key('language-toggle'),
            showSelectedIcon: false,
            segments: [
              for (final code in const ['en', 'de', 'tr'])
                ButtonSegment(
                    value: code,
                    label: Text(code.toUpperCase(), key: Key('lang-$code'))),
            ],
            selected: {FloorPlanStrings.of(context).languageCode},
            onSelectionChanged: (s) => widget.onLocale?.call(Locale(s.single)),
          ),
          const SizedBox(width: 16),
          // Spec T-1, T-2: today's look or the POS's.
          Tooltip(
            message: words.look,
            child: SegmentedButton<DemoLook>(
              key: const Key('look-toggle'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                    value: DemoLook.standard,
                    label: Text(words.lookStandard,
                        key: const Key('look-standard'))),
                ButtonSegment(
                    value: DemoLook.pos,
                    label: Text(words.lookPos, key: const Key('look-pos'))),
              ],
              selected: {widget.look},
              onSelectionChanged: (s) => widget.onLook?.call(s.single),
            ),
          ),
          const SizedBox(width: 16),
          SegmentedButton<int>(
            key: const Key('area-toggle'),
            showSelectedIcon: false,
            segments: [
              for (var i = 0; i < areas.length; i++)
                ButtonSegment(
                    value: i, label: Text(areas[i].name, key: Key('area-$i'))),
            ],
            selected: {_area},
            onSelectionChanged: (s) => setState(() {
              _area = s.single;
              _clearPointer();
            }),
          ),
          const SizedBox(width: 16),
          ValueListenableBuilder<FloorPlanMode>(
            valueListenable: c.mode,
            builder: (_, mode, __) => SegmentedButton<FloorPlanMode>(
              key: const Key('mode-toggle'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                    value: FloorPlanMode.design,
                    label: Text(words.design, key: const Key('mode-design'))),
                ButtonSegment(
                    value: FloorPlanMode.selection,
                    label: Text(words.service, key: const Key('mode-service'))),
              ],
              selected: {mode},
              onSelectionChanged: (s) => _setMode(s.single),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            child: Theme(
              data: _viewTheme(Theme.of(context)),
              child: Column(children: [
                if (ownBar && c.mode.value == FloorPlanMode.selection)
                  _ownServiceBar(a),
                Expanded(
                  // The demo's keys, while the plan's are off (spec C-7).
                  child: Focus(
                    canRequestFocus: false,
                    skipTraversal: true,
                    onKeyEvent: (_, event) => _demoKey(a, event),
                    child: _view(a),
                  ),
                ),
              ]),
            ),
          ),
          SizedBox(
            width: 300,
            child: ListView(
              key: const Key('side-panel'),
              padding: const EdgeInsets.all(12),
              children: [
                Text(area.name, style: title),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: c.dirty,
                    builder: (_, dirty, __) => FilledButton(
                        key: const Key('save'),
                        onPressed: dirty ? _save : null,
                        child: Text(words.save)),
                  ),
                  OutlinedButton(
                      key: const Key('revert'),
                      onPressed: _revert,
                      child: Text(words.revert)),
                  if (c.mode.value == FloorPlanMode.selection)
                    OutlinedButton(
                        key: const Key('reset-layout'),
                        onPressed: () {
                          _clearPointer();
                          c.resetLayout();
                        },
                        child: Text(words.resetLayout)),
                  OutlinedButton(
                      key: const Key('fit'),
                      onPressed: c.fitToView,
                      child: Text(words.fit)),
                ]),
                // Spec E-6, E-8: the POS's ids written into the design.
                if (c.mode.value == FloorPlanMode.design) ...[
                  const SizedBox(height: 8),
                  Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton(
                            key: const Key('link-tables'),
                            onPressed: () => linkTables(a),
                            child: Text(words.linkTables)),
                        Text(words.unlinked(unlinkedTables(a).length),
                            key: const Key('unlinked')),
                      ]),
                ],
                if (c.mode.value == FloorPlanMode.selection) ...[
                  // Spec E-3, E-4: one line, rebuilt alone.
                  const SizedBox(height: 8),
                  ValueListenableBuilder<PointerLine?>(
                    valueListenable: pointer,
                    builder: (context, line, _) => Text(
                        key: const Key('pointer-line'),
                        switch (line) {
                          null => '',
                          (table: final n?, floor: _) => words.overTable(n),
                          (table: null, floor: final w?) =>
                            words.floorAt(w.dx, w.dy),
                          (table: null, floor: null) => words.overNoTable,
                        }),
                  ),
                  SwitchListTile(
                      key: const Key('moves'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(words.moves),
                      value: moves,
                      onChanged: (v) => setState(() => moves = v)),
                  SwitchListTile(
                      key: const Key('long-press-menu'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(words.longPressMenu),
                      value: longPressMenu,
                      onChanged: (v) => setState(() => longPressMenu = v)),
                ],
                const SizedBox(height: 16),
                TextField(
                  key: const Key('select-number'),
                  controller: _number,
                  decoration:
                      InputDecoration(labelText: words.tableNumbersField),
                  onSubmitted: (_) => _select(),
                ),
                const SizedBox(height: 8),
                FilledButton.tonal(
                    key: const Key('select'),
                    onPressed: _select,
                    child: Text(words.select)),
                const SizedBox(height: 16),
                Text(words.statusOfSelected, style: title),
                const SizedBox(height: 4),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final name in kStatuses.keys)
                    OutlinedButton(
                        key: Key('status-${name.toLowerCase()}'),
                        onPressed: () => _setStatus(name),
                        child: Text(words.statusName(name))),
                  OutlinedButton(
                      key: const Key('status-random'),
                      onPressed: _randomStatuses,
                      child: Text(words.randomStatuses)),
                ]),
                const SizedBox(height: 16),
                Text(words.tables, style: title),
                Text(
                    key: const Key('tables'),
                    c.tables.isEmpty
                        ? words.none
                        : [
                            for (final t in c.tables)
                              '${t.number ?? '—'} (${t.seats})'
                          ].join(', ')),
                const SizedBox(height: 8),
                Text(words.groups, style: title),
                Text(key: const Key('groups'), _groupsText(c)),
                for (final (i, w) in c.numberingWarnings.indexed)
                  Text(FloorPlanStrings.of(context).numberingWarning(w),
                      key: Key('numbering-warning-$i'),
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                // Zone spec Z22: only an area with zones; below the lines the
                // tests read, above the log.
                if (a.zones.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(words.zones, style: title),
                  const SizedBox(height: 4),
                  SegmentedButton<String>(
                    key: const Key('zone-toggle'),
                    showSelectedIcon: false,
                    segments: [
                      // '' is All: a zone name is never empty.
                      ButtonSegment(
                          value: '',
                          label:
                              Text(words.allZones, key: const Key('zone-all'))),
                      for (final zone in a.zones.keys)
                        ButtonSegment(
                            value: zone,
                            label: Text(zone, key: Key('zone-$zone'))),
                    ],
                    selected: {a.zone ?? ''},
                    onSelectionChanged: (s) =>
                        _setZone(a, s.single.isEmpty ? null : s.single),
                  ),
                  SwitchListTile(
                      key: const Key('fade-others'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(words.fadeOthers),
                      value: a.fadeOthers,
                      onChanged: (v) => _setFadeOthers(a, v)),
                ],
                // Spec G-3, G-5: the Salon's badges and its table 7, in the
                // service; below the zones, above the log.
                if (a.offersBadges &&
                    c.mode.value == FloorPlanMode.selection) ...[
                  const SizedBox(height: 16),
                  SwitchListTile(
                      key: const Key('badges'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(words.badges),
                      value: a.badges,
                      onChanged: (v) => setState(() => a.badges = v)),
                  OutlinedButton(
                      key: const Key('center-7'),
                      onPressed: () => centerOnSeven(a),
                      child: Text(words.centerOnTable('7'))),
                ],
                // Spec C-1 to C-7: the host's own chrome and keys; below the
                // badges, above the log.
                const SizedBox(height: 16),
                Text(words.hostChoices, style: title),
                if (c.mode.value == FloorPlanMode.design) ...[
                  const SizedBox(height: 4),
                  Text(words.editor),
                  const SizedBox(height: 4),
                  SegmentedButton<DemoEditor>(
                    key: const Key('editor-profile'),
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                          value: DemoEditor.full,
                          label: Text(words.editorFull,
                              key: const Key('editor-full'))),
                      ButtonSegment(
                          value: DemoEditor.tables,
                          label: Text(words.editorTables,
                              key: const Key('editor-tables'))),
                      ButtonSegment(
                          value: DemoEditor.readOnly,
                          label: Text(words.editorReadOnly,
                              key: const Key('editor-read-only'))),
                    ],
                    selected: {editor},
                    onSelectionChanged: (s) =>
                        setState(() => editor = s.single),
                  ),
                ],
                if (c.mode.value == FloorPlanMode.selection)
                  SwitchListTile(
                      key: const Key('own-bar'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(words.ownBar),
                      value: ownBar,
                      onChanged: (v) => setState(() => ownBar = v)),
                SwitchListTile(
                    key: const Key('own-export-dialog'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(words.ownExportDialog),
                    value: ownExportDialog,
                    onChanged: (v) => setState(() => ownExportDialog = v)),
                SwitchListTile(
                    key: const Key('plan-keys'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(words.planKeys),
                    value: planKeys,
                    onChanged: (v) => setState(() => planKeys = v)),
                const SizedBox(height: 16),
                Text(words.log, style: title),
                for (final (i, line) in log.indexed)
                  Text(line, key: Key('log-$i')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
