// The restaurant embedding's demo host (spec 14b-2 H10): what a point-of-
// sale application does with the planner, through its public API only.
//
// Two dining areas (umbrella decision 12), each a FloorPlanController over
// a plan kept in memory, with its service layout kept beside it (spec 14d
// S4, S9: Design and back shows the moves again; Reset layout drops them);
// a Design / Service toggle; selection by table number; a table's context
// menu; the service options; and a log of the API's state. An example and
// an integration surface, not a product.
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show AssetBundle, BrowserContextMenu, rootBundle;
import 'package:jet_cad_floor_plan/jet_cad_floor_plan.dart';
import 'package:jet_cad_restaurant_symbols/jet_cad_restaurant_symbols.dart';

import 'demo_strings.dart';

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

/// The demo. [plans] seeds the areas' stored plans by name (tests); an area
/// without one starts empty.
class RestaurantDemo extends StatefulWidget {
  const RestaurantDemo(
      {super.key, this.plans = const {}, this.random, this.locale});

  final Map<String, String> plans;

  /// The source of "Random statuses" (tests seed it, 14c R-13).
  final math.Random? random;

  /// The language to start in; the system's when null (spec 14d L17).
  final Locale? locale;

  @override
  State<RestaurantDemo> createState() => _RestaurantDemoState();
}

class _RestaurantDemoState extends State<RestaurantDemo> {
  late Locale? _locale = widget.locale;

  @override
  Widget build(BuildContext context) => MaterialApp(
        onGenerateTitle: (context) => DemoStrings.of(context).title,
        theme: ThemeData(colorSchemeSeed: Colors.teal),
        // Spec 14d L17: the three languages, switched in the app bar
        // through `MaterialApp.locale` (V-4), so all three can be looked at
        // without changing the system's language.
        locale: _locale,
        supportedLocales: floorPlanSupportedLocales,
        localizationsDelegates: floorPlanLocalizationsDelegates,
        home: DemoHome(
            plans: widget.plans,
            random: widget.random,
            onLocale: (l) => setState(() => _locale = l)),
      );
}

/// One dining area: its controller, the plan last saved and the service
/// layout last seen, in memory.
final class Area {
  Area(this.name, this.controller, this.stored);

  final String name;
  final FloorPlanController controller;
  String? stored;

  /// The service layout, kept on `serviceLayoutChanges` (spec 14d S4).
  String? layout;
}

class DemoHome extends StatefulWidget {
  const DemoHome({super.key, required this.plans, this.random, this.onLocale});

  final Map<String, String> plans;
  final math.Random? random;

  /// Switches the app's language (spec 14d L17).
  final void Function(Locale locale)? onLocale;

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
          widget.plans[name]),
  ];
  int _area = 0;
  late final math.Random _random = widget.random ?? math.Random();
  final TextEditingController _number = TextEditingController();

  /// The service options (spec 14d S5, S7).
  bool moves = true;
  bool longPressMenu = false;

  /// The newest line first.
  final List<String> log = [];

  Area get area => areas[_area];

  @override
  void initState() {
    super.initState();
    // The shared library is loaded by the first view that shows it; a host
    // need not call `load()` (14b-2 review F-3).
    for (final a in areas) {
      final c = a.controller;
      c.mode.addListener(() => _log(_words.logMode(
          a.name,
          c.mode.value == FloorPlanMode.design
              ? _words.design
              : _words.service)));
      c.selectedTables.addListener(() => _log(_words.logSelected(
          a.name, (c.selectedTables.value.toList()..sort()).join(', '))));
      c.dirty.addListener(() => _log(_words.logDirty(a.name, c.dirty.value)));
      // The tables and warnings follow every change of the active plan.
      c.revision.addListener(() {
        if (mounted) setState(() {});
      });
      // Kept on every change of the layout, never on a mode switch or a
      // load, which start from the design (S4).
      c.serviceLayoutChanges
          .addListener(() => a.layout = c.serviceLayoutJson());
    }
  }

  @override
  void dispose() {
    for (final a in areas) {
      a.controller.dispose();
    }
    _thumbnails.dispose();
    _symbols.dispose();
    _number.dispose();
    super.dispose();
  }

  /// The demo's words in the app's language (spec 14d L17).
  DemoStrings get _words => DemoStrings.of(context);

  void _log(String line) {
    if (!mounted) return;
    setState(() {
      log.insert(0, line);
      if (log.length > 40) log.removeLast();
    });
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
  /// alone, or with the selection that held it.
  Future<void> _tableMenu(String number, Offset at) async {
    final a = area;
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
      _setStatus(choice.substring('status:'.length));
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
    // A load in the service starts from the design: the layout goes back.
    if (area.controller.mode.value == FloorPlanMode.selection) {
      _restoreLayout(area);
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

  void _setStatus(String name) {
    final c = area.controller;
    final next = Map<String, TableStatus>.of(c.tableStatuses.value);
    final status = _statusFor(name);
    for (final n in c.selectedTables.value) {
      if (status == null) {
        next.remove(n);
      } else {
        next[n] = status;
      }
    }
    c.setTableStatus(next);
    _log(_words.logStatus(area.name, _words.statusName(name),
        (c.selectedTables.value.toList()..sort()).join(', ')));
  }

  void _randomStatuses() {
    final c = area.controller;
    final names = kStatuses.keys.toList();
    final next = <String, TableStatus>{};
    for (final t in c.tables) {
      final n = t.number;
      if (n == null) continue;
      final status = _statusFor(names[_random.nextInt(names.length)]);
      if (status != null) next[n] = status;
    }
    c.setTableStatus(next);
    _log(_words.logRandom(area.name, next.length));
  }

  void _select() {
    final numbers = {for (final n in _number.text.split(',')) n.trim()}
      ..remove('');
    area.controller.select(numbers);
  }

  @override
  Widget build(BuildContext context) {
    final c = area.controller;
    final words = _words;
    final title = Theme.of(context).textTheme.titleSmall;
    return Scaffold(
      appBar: AppBar(
        title: Text(words.title),
        actions: [
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
          SegmentedButton<int>(
            key: const Key('area-toggle'),
            showSelectedIcon: false,
            segments: [
              for (var i = 0; i < areas.length; i++)
                ButtonSegment(
                    value: i, label: Text(areas[i].name, key: Key('area-$i'))),
            ],
            selected: {_area},
            onSelectionChanged: (s) => setState(() => _area = s.single),
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
            child: FloorPlanView(
              key: ObjectKey(c),
              controller: c,
              exportName: area.name.toLowerCase(),
              onExport: (e) => _log(
                  _words.logExported(area.name, e.fileName, e.bytes.length)),
              onTableTap: (n) => _log(_words.logTapped(area.name, n)),
              onLayoutChanged: () => _log(_words.logLayoutChanged(area.name)),
              serviceMoves: moves,
              longPress: longPressMenu
                  ? FloorPlanLongPress.contextMenu
                  : FloorPlanLongPress.toggleSelection,
              onTableContextMenu: _tableMenu,
            ),
          ),
          SizedBox(
            width: 300,
            child: ListView(
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
                        onPressed: c.resetLayout,
                        child: Text(words.resetLayout)),
                  OutlinedButton(
                      key: const Key('fit'),
                      onPressed: c.fitToView,
                      child: Text(words.fit)),
                ]),
                if (c.mode.value == FloorPlanMode.selection) ...[
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
                for (final (i, w) in c.numberingWarnings.indexed)
                  Text(FloorPlanStrings.of(context).numberingWarning(w),
                      key: Key('numbering-warning-$i'),
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
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
