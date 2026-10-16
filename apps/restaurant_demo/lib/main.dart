// The restaurant embedding's demo host, on the plan library and its two
// kits (sub-project 4a): two dining areas, each a `PlanController` over the
// architecture and restaurant kits (a plan built in code, lib/samples), an
// area switch, the Standard / POS look and the three languages; the
// Design / Service toggle, the editor's profiles and permissions, selection
// and find by table number, the table menu, statuses (random included),
// merge and split, the POS id linked as host data, zones and fading others;
// the host's own chrome and keys: the area's name in the planner's service
// bar or a service bar of the demo's own, the demo's own export dialog,
// export and print through the controller, a failed one logged, and the
// plan's keys given to the demo; save, revert and the service layout kept
// across Design and back; the Salon's badges on its tables; the POS look and
// the three languages; and a log of the API's state and events. An example
// and an integration surface, not a product.
import 'dart:async' show StreamSubscription, Timer, unawaited;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show BrowserContextMenu;
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_kit_restaurant/jet_cad_2d_kit_restaurant.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import 'area.dart';
import 'badges.dart' as badge_lib;
import 'badges.dart' show kBadgeAreas, kBadgeLayout, tableBadge;
import 'demo_keys.dart';
import 'demo_strings.dart';
import 'demo_theme.dart';
import 'editor_profiles.dart';
import 'export_flow.dart';
import 'groups.dart' as groups;
import 'own_bar.dart';
import 'pos_links.dart' as pos_links;
import 'pos_links.dart' show PointerLine, idOf, kDemoTableIds, linkTables;
import 'side_panel.dart';
import 'statuses.dart' as statuses;
import 'table_menu.dart';
import 'zones.dart';
import 'samples/salon.dart';
import 'samples/teras.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Native platforms: the documents' family from the package's bytes.
    // The web reads the family the pubspec declares.
    await ensurePlanFonts();
  } catch (error, stack) {
    // The text then measures in the platform's font; reported, and the demo
    // still starts.
    FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'restaurant_demo',
        context: ErrorDescription('registering the plan font')));
  }
  registerFontLicences();
  // A right click on a table opens the demo's menu, not the browser's:
  // app-global, so the host's to decide.
  if (kIsWeb) await BrowserContextMenu.disableContextMenu();
  runApp(const RestaurantDemo());
}

/// The demo's theme seed, for the light and the dark theme alike.
const Color _seed = Colors.teal;

/// The demo. [locale] is the language to start in; the system's when null.
/// [random] is the source of "Random statuses" (tests seed it); [printer]
/// is where Print sends the page, the platform's print dialog when null
/// (tests give their own).
class RestaurantDemo extends StatefulWidget {
  const RestaurantDemo({super.key, this.locale, this.random, this.printer});

  final Locale? locale;
  final math.Random? random;
  final PagePrinter? printer;

  @override
  State<RestaurantDemo> createState() => _RestaurantDemoState();
}

class _RestaurantDemoState extends State<RestaurantDemo> {
  late Locale? _locale = widget.locale;

  /// The look the app bar switches: the standard one by default.
  DemoLook _look = DemoLook.standard;

  /// The app's theme for [brightness]: the seed's; under the POS look it
  /// carries the POS's `PlanTheme` for that brightness, one extension per
  /// `ThemeData`.
  ThemeData _theme(Brightness brightness) =>
      ThemeData(colorSchemeSeed: _seed, brightness: brightness, extensions: [
        if (_look == DemoLook.pos) posPlanTheme(brightness),
      ]);

  @override
  Widget build(BuildContext context) => MaterialApp(
        onGenerateTitle: (context) => DemoStrings.of(context).title,
        // The planner follows the host's theme, and the OS picks light or
        // dark.
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        themeMode: ThemeMode.system,
        // The three languages, switched in the app bar through
        // `MaterialApp.locale`, so all three can be looked at without
        // changing the system's language.
        locale: _locale,
        supportedLocales: planSupportedLocales,
        localizationsDelegates: planLocalizationsDelegates,
        home: DemoHome(
            random: widget.random,
            printer: widget.printer,
            look: _look,
            onLook: (look) => setState(() => _look = look),
            onLocale: (l) => setState(() => _locale = l)),
      );
}

/// The demo's page: the find field, the area switch, the language and look
/// toggles, the mode toggle, the current area's editor and the side panel.
class DemoHome extends StatefulWidget {
  const DemoHome(
      {super.key,
      this.look = DemoLook.standard,
      this.random,
      this.printer,
      this.onLook,
      this.onLocale});

  final DemoLook look;
  final math.Random? random;
  final PagePrinter? printer;
  final ValueChanged<DemoLook>? onLook;
  final ValueChanged<Locale>? onLocale;

  @override
  State<DemoHome> createState() => DemoHomeState();
}

class DemoHomeState extends State<DemoHome> {
  /// The areas, each over its own controller: `[architectureKit,
  /// restaurantKit]`, the architecture kit first (the gallery's order), the
  /// plan built by the area's sample.
  late final List<Area> areas = [
    Area(
        'Salon',
        PlanController(
            kits: [architectureKit, restaurantKit], build: buildSalon),
        sample: buildSalon,
        zones: kDemoZones['Salon'] ?? const {},
        offersBadges: kBadgeAreas.contains('Salon'),
        tableIds: kDemoTableIds['Salon'] ?? const {}),
    Area(
        'Teras',
        PlanController(
            kits: [architectureKit, restaurantKit], build: buildTeras),
        sample: buildTeras,
        zones: kDemoZones['Teras'] ?? const {},
        offersBadges: kBadgeAreas.contains('Teras'),
        tableIds: kDemoTableIds['Teras'] ?? const {}),
  ];

  int _area = 0;

  late final math.Random _random = widget.random ?? math.Random();
  final TextEditingController _number = TextEditingController();
  final TextEditingController _search = TextEditingController();

  /// The service options: whether a drag moves the tables, a long press
  /// opens the menu, a drag on the floor draws a band.
  bool moves = true;
  bool longPressMenu = false;
  bool floorBand = false;

  /// The editor's profile, for both areas.
  DemoEditor editor = DemoEditor.full;

  /// Whether the service shows the demo's own bar in place of the
  /// planner's.
  bool ownBar = false;

  /// Whether every Export asks the demo's own dialog.
  bool ownExportDialog = false;

  /// Whether the plan binds its own keys; false gives the keyboard to the
  /// demo.
  bool planKeys = true;

  /// The last export made (tests read its bytes).
  PlanExport? lastExport;

  /// The newest line first.
  final List<String> log = [];

  /// The service's pointer line, null when there is nothing to show: a line
  /// of its own, not the log, rebuilt alone at hover rate. Cleared when the
  /// mode, the area or the plan changes, since the view then sends no null
  /// for the table it leaves.
  final ValueNotifier<PointerLine?> pointer = ValueNotifier(null);

  /// Each area's subscription to its design's unit changes.
  final List<StreamSubscription<PlanUnitChange>> _changes = [];

  /// Minutes since the demo started, one tick a minute. The badges' minute
  /// counters read it through a `ValueListenableBuilder` inside the badge:
  /// a tick rebuilds the counters, never the overlays (live data is the
  /// host's own state management).
  final ValueNotifier<int> minutes = ValueNotifier(0);
  Timer? _ticker;

  /// How many times the badge builder ran (tests: pan and zoom build none).
  int badgeBuilds = 0;

  Area get area => areas[_area];

  /// `G<n>`, n the largest numeric suffix among [ids] plus one.
  static String nextGroupId(Iterable<String> ids) => groups.nextGroupId(ids);

  /// A badge's figures (see [badgeFigures]).
  static ({int guests, int minutes})? badgeFigures(
          String number, int seats, String? name) =>
      badge_lib.badgeFigures(number, seats, name);

  /// The statuses by name.
  static Map<String, UnitStatus?> get kStatuses => statuses.kStatuses;

  @override
  void initState() {
    super.initState();
    _ticker =
        Timer.periodic(const Duration(minutes: 1), (_) => minutes.value++);
    for (final a in areas) {
      final c = a.controller;
      c.mode.addListener(() => _log(_words.logMode(a.name,
          c.mode.value == PlanMode.design ? _words.design : _words.service)));
      c.mode.addListener(_clearPointer);
      c.dirty.addListener(() => _log(_words.logDirty(a.name, c.dirty.value)));
      c.selectedUnits.addListener(() => _log(_words.logSelected(
          a.name, (c.selectedUnits.value.toList()..sort()).join(', '))));
      // The tables and the groups line follow every change of the plan.
      for (final l in [c.revision, c.unitGroups, c.groupStatuses]) {
        l.addListener(() {
          if (mounted) setState(() {});
        });
      }
      // Kept on every change of the record, never on a mode switch or a
      // load, which start from the design.
      c.serviceChanges.addListener(() {
        if (c.serviceJson() case final json?) a.layout = json;
      });
      _changes.add(c.unitChanges.listen((e) => _unitsChanged(a, e)));
      c.permissions = editor.compose(moves: moves);
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
    _number.dispose();
    _search.dispose();
    super.dispose();
  }

  /// The demo's words in the app's language.
  DemoStrings get _words => DemoStrings.of(context);

  /// The language the statuses were last worded in.
  Type? _wordedIn;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = _words.runtimeType;
    if (_wordedIn != null && _wordedIn != language) {
      for (final a in areas) {
        statuses.applyStatuses(a, _words);
      }
    }
    _wordedIn = language;
  }

  void _clearPointer() => pointer.value = null;

  void _log(String line) {
    if (!mounted) return;
    setState(() {
      log.insert(0, line);
      if (log.length > 40) log.removeLast();
    });
  }

  /// The permissions both areas' controllers hold: the editor's profile
  /// with the Moves switch.
  void _permit() {
    for (final a in areas) {
      a.controller.permissions = editor.compose(moves: moves);
    }
  }

  /// Picks the editor's profile.
  void setEditor(DemoEditor next) {
    setState(() => editor = next);
    _permit();
  }

  /// The Moves switch: a drag from a table moves it, or pans.
  void setMoves(bool value) {
    setState(() => moves = value);
    _permit();
  }

  void setLongPressMenu(bool value) => setState(() => longPressMenu = value);

  void setFloorBand(bool value) => setState(() => floorBand = value);

  /// The Design / Service toggle of the current area. The service layout is
  /// kept, not discarded: entering the service puts it back.
  void setMode(PlanMode next) {
    area.controller.setMode(next);
    if (next == PlanMode.service) _restoreLayout(area);
  }

  /// Shows area [index].
  void setArea(int index) => setState(() {
        _area = index;
        _clearPointer();
      });

  void setOwnBar(bool value) => setState(() => ownBar = value);

  void setOwnExportDialog(bool value) =>
      setState(() => ownExportDialog = value);

  void setPlanKeys(bool value) => setState(() => planKeys = value);

  void setBadges(Area a, bool value) => setState(() => a.badges = value);

  /// [a]'s kept layout, put back on its service copy; entries the design no
  /// longer matches are dropped, and so are the groups the record does not
  /// hold (with their statuses): both are logged.
  void _restoreLayout(Area a) {
    final layout = a.layout;
    if (layout == null) return;
    final r = a.controller.restoreService(layout);
    _pruneGroupStatuses(a);
    if (r.appliedMoves.isEmpty &&
        r.droppedMoves.isEmpty &&
        r.appliedGroups.isEmpty &&
        r.droppedGroups.isEmpty) {
      return;
    }
    _log(_words.logRestored(
            a.name, r.appliedMoves.length, r.droppedMoves.length) +
        _words.restoredGroups(r.appliedGroups, r.droppedGroups));
  }

  /// A group's status goes with the group: those of groups the controller
  /// no longer holds are dropped.
  void _pruneGroupStatuses(Area a) {
    final held = a.controller.unitGroups.value;
    final before = a.groupStatusNames.length;
    a.groupStatusNames.removeWhere((id, _) => !held.containsKey(id));
    if (a.groupStatusNames.length != before) statuses.applyStatuses(a, _words);
  }

  /// Reset layout: the service copy rebuilt from the design, every move
  /// gone and the groups split, with their statuses.
  void resetLayout() {
    final a = area;
    _clearPointer();
    a.controller.resetService();
    _pruneGroupStatuses(a);
  }

  /// Save: the plan's text kept in memory, and the plan marked saved.
  void save() {
    final a = area;
    a.stored = a.controller.save();
    a.controller.markSaved();
    _log(_words.logStored(a.name, a.stored!.length));
  }

  /// Revert: the plan last saved is loaded again, or the area's sample
  /// rebuilt when nothing was saved. A load in the service starts from the design: the
  /// layout goes back when the unit changes report the replaced plan.
  void revert() {
    final a = area;
    final stored = a.stored;
    if (stored == null) {
      a.controller.newPlan(build: a.sample);
    } else {
      a.controller.load(stored);
    }
    _log(_words.logReloaded(a.name));
    _clearPointer();
    // A load drops a framing: frame again.
    if (a.zone case final z?) {
      showZone(a, a.zones[z]!, fadeOthers: a.fadeOthers);
    }
  }

  /// The design's unit changes, logged: the tables added and removed, and a
  /// replaced plan; a changed table (a number, a move, its data) is not
  /// logged. A plan replaced in the service starts from the design, so the
  /// area's kept layout goes back on it then, whoever replaced it: the
  /// report comes after the load, never inside it.
  void _unitsChanged(Area a, PlanUnitChange change) {
    if (!mounted) return;
    final words = _words;
    switch (change) {
      case PlanUnitAdded(:final unit):
        _log(words.logTableAdded(a.name, unit.unit.label ?? '—'));
      case PlanUnitRemoved(:final unit):
        _log(words.logTableRemoved(a.name, unit.unit.label ?? '—'));
      case PlanUnitsReplaced():
        _log(words.logPlanReplaced(a.name));
        if (a.controller.mode.value == PlanMode.service) _restoreLayout(a);
      case PlanUnitChanged():
        break;
    }
  }

  /// "Link tables": see [linkTables].
  void link(Area a) => _log(_words.logLinked(a.name, linkTables(a)));

  /// The POS's tables in [a] that its floor does not draw.
  Set<String> unlinkedTables(Area a) => pos_links.unlinkedTables(a);

  /// A double tap opens table [number]: logged with the id the table is
  /// linked by. Its two taps were logged first: a host that acts on a tap
  /// acts on each tap of a double tap too.
  void _opened(Area a, String number) =>
      _log(_words.logOpened(a.name, number, idOf(a, number)));

  /// Table 7 in the middle of [a]'s view, its zoom kept. Nothing when the
  /// plan draws no table 7.
  void centerOnSeven(Area a) {
    final c = a.controller;
    for (final detail in c.unitDetails) {
      final center = detail.center;
      if (detail.unit.label == '7' && center != null) {
        c.centerOn(center);
        return;
      }
    }
  }

  /// An export made by the planner's Export or the demo's own bar: logged
  /// with its file name and size.
  void _exported(Area a, PlanExport export) {
    lastExport = export;
    _log(_words.logExported(a.name, export.name, export.bytes.length));
  }

  /// The own bar's Export: the demo's dialog (or the library's), then the
  /// controller's `export`, which shows no dialog. The area is [a], read
  /// when the export started: the dialog may be up while another area is
  /// shown. Null from `export` (another export or a print running, no page,
  /// the plan replaced) exports nothing.
  Future<void> _ownExport(Area a) async {
    final name = a.name.toLowerCase();
    final ask = ownExportDialog ? showDemoExportDialog : showPlanExportDialog;
    final answer = await ask(context, a.ownAnswer, a.controller.exporters);
    if (answer == null || !mounted) return;
    a.ownAnswer = answer;
    try {
      final export =
          await a.controller.export(answer.exporter, answer.choice, name: name);
      if (export != null) _exported(a, export);
    } catch (error) {
      _log(_words.logPageFlowError(a.name, error));
    }
  }

  /// The own bar's Print: the controller's `print`.
  Future<void> _ownPrint(Area a) async {
    try {
      await a.controller.print(a.ownAnswer.choice,
          printer: widget.printer, name: a.name.toLowerCase());
    } catch (error) {
      _log(_words.logPageFlowError(a.name, error));
    }
  }

  /// The service bar's look: the planner's own, with the area's name before
  /// its buttons; hidden under [ownBar].
  PlanServiceBar _serviceBar(Area a) => ownBar
      ? const PlanServiceBar(visible: false)
      : PlanServiceBar(leading: [
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(child: Text(a.name, key: const Key('bar-area')))),
        ]);

  /// The demo's own keys, while [planKeys] is off.
  KeyEventResult _demoKey(Area a, KeyEvent event) {
    if (planKeys) return KeyEventResult.ignored;
    final ran = runDemoKey(a.controller, event);
    if (ran == null) return KeyEventResult.ignored;
    _log(_words.logKey(a.name, ran));
    return KeyEventResult.handled;
  }

  /// A table's context menu: the table is already selected alone, or with
  /// the selection that held it -- unless it is locked, which leaves the
  /// selection alone: the menu then acts on the table only.
  Future<void> _tableMenu(String number, Offset at) async {
    final a = area;
    final selected = a.controller.selectedUnits.value;
    final locked = !selected.contains(number);
    _log(_words.logMenu(a.name, number));
    final choice =
        await showTableMenu(context, at, number: number, locked: locked);
    if (choice == null || !mounted || !identical(a, area)) return;
    if (choice == 'select') {
      a.controller.select({number});
    } else if (choice.startsWith('status:')) {
      // A locked table alone; otherwise the selection, a group's whole.
      setStatus(choice.substring('status:'.length), locked ? {number} : null);
    }
  }

  /// Sets status [name] on [labels], the selection (a selected group's
  /// whole) when null.
  void setStatus(String name, [Set<String>? labels]) {
    final a = area;
    final words = _words;
    final done = statuses.setStatus(a, name, words, labels);
    if (done.group != null) {
      _log(words.logGroupStatus(a.name, words.statusName(name), done.group!));
    } else {
      _log(words.logStatus(a.name, words.statusName(name),
          (done.labels.toList()..sort()).join(', ')));
    }
  }

  void randomStatuses() {
    final a = area;
    final count = statuses.randomStatuses(a, _random, _words);
    _log(_words.logRandom(a.name, count));
  }

  void _merge(Area a, Set<String> numbers) {
    final id = groups.mergeRequested(a, numbers, _words);
    if (id != null) {
      _log(_words.logMerged(a.name, groups.sortedNumbers(numbers), id));
    }
  }

  void _split(Area a, String id) {
    groups.splitRequested(a, id, _words);
    _log(_words.logSplit(a.name, id));
  }

  /// The numbers typed in the side panel's field, selected.
  void selectTyped() {
    final numbers = {for (final n in _number.text.split(',')) n.trim()}
      ..remove('');
    area.controller.select(numbers);
  }

  /// The side panel's number field.
  TextEditingController get numberField => _number;

  /// The app bar's search: selects the table and brings it to the middle of
  /// the view, its zoom kept.
  void _find(String text) {
    final a = area;
    final c = a.controller;
    final number = text.trim();
    if (number.isEmpty) return;
    for (final detail in c.unitDetails) {
      final center = detail.center;
      if (detail.unit.label == number && center != null) {
        c.select({number});
        c.centerOn(center);
        _log(_words.logFound(a.name, number));
        return;
      }
    }
    _log(_words.logNotFound(a.name, number));
  }

  /// The table inspector (the Tables profile): the one placed table
  /// selected in the editor, linked to the POS's id.
  Widget? _inspector(BuildContext context, PlanUnitDetail table) {
    final number = table.unit.label!;
    final a = area;
    return PosIdField(
        key: ValueKey(number),
        id: table.data['id'],
        onSubmitted: (id) => _linkTable(a, number, id));
  }

  /// Links table [number] of [a] to [id], its other data kept; an empty [id]
  /// unlinks it.
  void _linkTable(Area a, String number, String id) {
    final c = a.controller;
    final tables = [
      for (final d in c.unitDetails)
        if (d.unit.label == number) d,
    ];
    if (tables.length != 1) return;
    final data = {...tables.single.data};
    final trimmed = id.trim();
    if (trimmed.isEmpty) {
      data.remove('id');
    } else {
      data['id'] = trimmed;
    }
    if (c.setUnitData(number, data)) {
      _log(_words.logLinkedTable(a.name, number, data['id']));
    }
  }

  /// [zone] of [a], or all of them when null.
  void setZone(Area a, String? zone) {
    setState(() => a.zone = zone);
    if (zone == null) {
      showAllZones(a);
    } else {
      showZone(a, a.zones[zone]!, fadeOthers: a.fadeOthers);
    }
  }

  /// "Fade the others": applied at once to the zone shown.
  void setFadeOthers(Area a, bool fade) {
    setState(() => a.fadeOthers = fade);
    if (a.zone case final zone?) {
      showZone(a, a.zones[zone]!, fadeOthers: fade);
    }
  }

  /// The local `Theme` around the editor under the POS look: the POS's
  /// tokens as the Material scheme.
  ThemeData _viewTheme(ThemeData ambient) =>
      widget.look == DemoLook.pos ? posViewTheme(ambient) : ambient;

  /// A badge: counted, so a test sees pan and zoom build none.
  Widget _badge(BuildContext context, PlanUnitOverlay unit) {
    badgeBuilds++;
    return tableBadge(context, unit, minutes);
  }

  /// [a]'s editor, with the host's options.
  Widget _editor(Area a) => PlanEditor(
        // One editor at a time, keyed by the area: a second canvas on one
        // controller asserts, and a switch mounts the other area's.
        key: ValueKey(a.name),
        controller: a.controller,
        exportName: a.name.toLowerCase(),
        printer: widget.printer,
        onExport: (e) => _exported(a, e),
        onExportDialog: ownExportDialog ? showDemoExportDialog : null,
        onPageFlowError: (error) =>
            _log(_words.logPageFlowError(a.name, error)),
        shortcuts: planKeys,
        autofocus: planKeys,
        serviceBar: _serviceBar(a),
        unitOverlayBuilder:
            a.badges ? (context, unit) => _badge(context, unit) : null,
        unitOverlayLayout: kBadgeLayout,
        onUnitDoubleTap: (n) => _opened(a, n),
        onUnitsMoved: (moved) => _log(_words.logMoved(
            a.name,
            groups
                .sortedNumbers([for (final d in moved) d.unit.label ?? '—']))),
        onUnitHover: (n) => pointer.value = (table: n, floor: null),
        onFloorTap: (w) => pointer.value = (table: null, floor: w),
        theme: widget.look == DemoLook.pos ? kPosViewOverride : null,
        layerPanel: editor.showsLayersAndPage,
        pagePanel: editor.showsLayersAndPage,
        symbolFilter: editor.symbolFilter,
        bar: editor.bar,
        unitInspectorBuilder: editor == DemoEditor.tables ? _inspector : null,
        onUnitTap: (n) => _log(_words.logTapped(a.name, n)),
        onLayoutChanged: () => _log(_words.logLayoutChanged(a.name)),
        longPress: longPressMenu
            ? PlanLongPress.contextMenu
            : PlanLongPress.toggleSelection,
        floorDrag: floorBand ? PlanFloorDrag.band : PlanFloorDrag.pan,
        onUnitContextMenu: _tableMenu,
        onGroupTap: (id, n) => _log(_words.logGroupTapped(a.name, id, n)),
        onMergeRequested: (numbers) => _merge(a, numbers),
        onSplitRequested: (id) => _split(a, id),
      );

  @override
  Widget build(BuildContext context) {
    final words = _words;
    final a = area;
    final c = a.controller;
    return Scaffold(
      appBar: AppBar(
        title: Text(words.title),
        actions: [
          // A field of the host's beside the plan: Enter selects the table
          // and brings it to the middle of the view.
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
          SegmentedButton<String>(
            key: const Key('language-toggle'),
            showSelectedIcon: false,
            segments: [
              for (final code in const ['en', 'de', 'tr'])
                ButtonSegment(
                    value: code,
                    label: Text(code.toUpperCase(), key: Key('lang-$code'))),
            ],
            selected: {Localizations.localeOf(context).languageCode},
            onSelectionChanged: (s) => widget.onLocale?.call(Locale(s.single)),
          ),
          const SizedBox(width: 16),
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
            onSelectionChanged: (s) => setArea(s.single),
          ),
          const SizedBox(width: 16),
          ValueListenableBuilder<PlanMode>(
            valueListenable: c.mode,
            builder: (_, mode, __) => SegmentedButton<PlanMode>(
              key: const Key('mode-toggle'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                    value: PlanMode.design,
                    label: Text(words.design, key: const Key('mode-design'))),
                ButtonSegment(
                    value: PlanMode.service,
                    label: Text(words.service, key: const Key('mode-service'))),
              ],
              selected: {mode},
              onSelectionChanged: (s) => setMode(s.single),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(children: [
        Expanded(
          child: Theme(
            data: _viewTheme(Theme.of(context)),
            child: Column(children: [
              if (ownBar && c.mode.value == PlanMode.service)
                OwnServiceBar(
                    name: a.name,
                    controller: c,
                    onMerge: (numbers) => _merge(a, numbers),
                    onSplit: (id) => _split(a, id),
                    onExport: () => _ownExport(a),
                    onPrint: () => _ownPrint(a)),
              Expanded(
                // Keyed: the editor is not remounted when the own bar comes
                // and goes above it (a second canvas on one controller
                // asserts).
                key: const Key('editor-slot'),
                // The demo's keys, while the plan's are off.
                child: Focus(
                  canRequestFocus: false,
                  skipTraversal: true,
                  onKeyEvent: (_, event) => _demoKey(a, event),
                  child: _editor(a),
                ),
              ),
            ]),
          ),
        ),
        SizedBox(width: 300, child: DemoSidePanel(home: this)),
      ]),
    );
  }
}
