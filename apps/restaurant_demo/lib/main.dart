// The restaurant embedding's demo host (spec 14b-2 H10): what a point-of-
// sale application does with the planner, through its public API only.
//
// Two dining areas (umbrella decision 12), each a FloorPlanController over
// a plan kept in memory; a Design / Service toggle that asks before it
// discards service edits; selection by table number; table groups merged
// and split from the service bar (table-groups spec G6); and a log of the
// API's state. An example and an integration surface, not a product.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:jet_cad_floor_plan/jet_cad_floor_plan.dart';
import 'package:jet_cad_restaurant_symbols/jet_cad_restaurant_symbols.dart';

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
class RestaurantDemo extends StatelessWidget {
  const RestaurantDemo({super.key, this.plans = const {}, this.random});

  final Map<String, String> plans;

  /// The source of "Random statuses" (tests seed it, 14c R-13).
  final math.Random? random;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Restaurant demo',
        // Dark theme spec D1: the planner follows the host's theme, and the
        // OS picks light or dark.
        theme: ThemeData(colorSchemeSeed: _seed),
        darkTheme:
            ThemeData(colorSchemeSeed: _seed, brightness: Brightness.dark),
        themeMode: ThemeMode.system,
        home: DemoHome(plans: plans, random: random),
      );
}

/// One dining area: its controller and the plan last saved, in memory.
final class Area {
  Area(this.name, this.controller, this.stored);

  final String name;
  final FloorPlanController controller;
  String? stored;
}

class DemoHome extends StatefulWidget {
  const DemoHome({super.key, required this.plans, this.random});

  final Map<String, String> plans;
  final math.Random? random;

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
      c.mode.addListener(() => _log('${a.name}: mode ${c.mode.value.name}'));
      c.selectedTables.addListener(() => _log(
          '${a.name}: selected {${(c.selectedTables.value.toList()..sort()).join(', ')}}'));
      c.dirty.addListener(
          () => _log('${a.name}: ${c.dirty.value ? 'edited' : 'saved'}'));
      // The tables and warnings follow every change of the active plan;
      // the groups line follows the groups and their statuses.
      for (final l in [c.revision, c.tableGroups, c.groupStatuses]) {
        l.addListener(() {
          if (mounted) setState(() {});
        });
      }
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

  void _log(String line) {
    if (!mounted) return;
    setState(() {
      log.insert(0, line);
      if (log.length > 40) log.removeLast();
    });
  }

  /// The toggle (H10): leaving the service asks first when it has edits.
  Future<void> _setMode(FloorPlanMode next) async {
    final c = area.controller;
    if (next == FloorPlanMode.design && c.serviceEdited) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          key: const Key('discard-dialog'),
          title: const Text('Discard the service layout?'),
          content: const Text(
              'Tables moved during the service go back to the designed plan.'),
          actions: [
            TextButton(
                key: const Key('discard-cancel'),
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel')),
            FilledButton(
                key: const Key('discard-ok'),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Discard')),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    c.setMode(next);
  }

  void _save() {
    area.stored = area.controller.designJson();
    area.controller.markSaved();
    _log('${area.name}: stored ${area.stored!.length} characters');
  }

  void _revert() {
    final stored = area.stored;
    if (stored == null) {
      area.controller.newPlan();
    } else {
      area.controller.load(stored);
    }
    _log('${area.name}: reloaded');
  }

  /// The statuses a POS would set (14c S10): by the selected tables.
  static final Map<String, TableStatus?> kStatuses = {
    'Free': null,
    'Ordered': TableStatus(color: const Color(0x99FFB300)),
    'Eating': TableStatus(color: const Color(0x9943A047)),
    'Bill': TableStatus(color: const Color(0x99E53935), caption: 'Bill'),
  };

  void _setStatus(String name) {
    final c = area.controller;
    final status = kStatuses[name];
    // A selected group gets a group status (G6), which overrides its
    // members' own; Free clears it.
    final group = c.selectedGroup.value;
    if (group != null) {
      final next = Map<String, TableStatus>.of(c.groupStatuses.value);
      if (status == null) {
        next.remove(group);
      } else {
        next[group] = status;
      }
      c.setGroupStatus(next);
      _log('${area.name}: $name for $group');
      return;
    }
    final next = Map<String, TableStatus>.of(c.tableStatuses.value);
    for (final n in c.selectedTables.value) {
      if (status == null) {
        next.remove(n);
      } else {
        next[n] = status;
      }
    }
    c.setTableStatus(next);
    _log('${area.name}: $name for '
        '{${(c.selectedTables.value.toList()..sort()).join(', ')}}');
  }

  void _randomStatuses() {
    final c = area.controller;
    final names = kStatuses.keys.toList();
    final next = <String, TableStatus>{};
    for (final t in c.tables) {
      final n = t.number;
      if (n == null) continue;
      final status = kStatuses[names[_random.nextInt(names.length)]];
      if (status != null) next[n] = status;
    }
    c.setTableStatus(next);
    _log('${area.name}: random statuses for ${next.length} tables');
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
    if (gone.any(c.groupStatuses.value.containsKey)) {
      c.setGroupStatus({...c.groupStatuses.value}
        ..removeWhere((id, _) => gone.contains(id)));
    }
    _log('${a.name}: Merged {${_sorted(numbers)}} as ${merged.id}');
  }

  /// The service bar's Split (G6): the group goes, and its status with it.
  void _split(Area a, String id) {
    final c = a.controller;
    c.setTableGroups({...c.tableGroups.value}..remove(id));
    c.setGroupStatus({...c.groupStatuses.value}..remove(id));
    _log('${a.name}: Split $id');
  }

  /// The name [kStatuses] gives [status], or `status` for another one.
  static String _statusName(TableStatus status) => kStatuses.entries
      .firstWhere((e) => e.value == status,
          orElse: () => const MapEntry('status', null))
      .key;

  /// The groups line: `G1: 3+7+12 (Bill)`, by id.
  String _groupsText(FloorPlanController c) {
    final groups = c.tableGroups.value;
    if (groups.isEmpty) return 'none';
    final statuses = c.groupStatuses.value;
    return [
      for (final id in groups.keys.toList()..sort(byNumber))
        [
          '$id: ${(groups[id]!.members.toList()..sort(byNumber)).join('+')}',
          if (statuses[id] case final s?) ' (${_statusName(s)})',
        ].join()
    ].join(', ');
  }

  void _select() {
    final numbers = {for (final n in _number.text.split(',')) n.trim()}
      ..remove('');
    area.controller.select(numbers);
  }

  @override
  Widget build(BuildContext context) {
    final a = area;
    final c = a.controller;
    final title = Theme.of(context).textTheme.titleSmall;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurant demo'),
        actions: [
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
              segments: const [
                ButtonSegment(
                    value: FloorPlanMode.design,
                    label: Text('Design', key: Key('mode-design'))),
                ButtonSegment(
                    value: FloorPlanMode.selection,
                    label: Text('Service', key: Key('mode-service'))),
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
              onExport: (e) => _log('${area.name}: exported ${e.fileName}, '
                  '${e.bytes.length} bytes'),
              onTableTap: (n) => _log('${area.name}: tapped $n'),
              onLayoutChanged: () => _log('${area.name}: layout changed'),
              onGroupTap: (id, n) => _log('${a.name}: group $id tapped at $n'),
              onMergeRequested: (numbers) => _merge(a, numbers),
              onSplitRequested: (id) => _split(a, id),
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
                        child: const Text('Save')),
                  ),
                  OutlinedButton(
                      key: const Key('revert'),
                      onPressed: _revert,
                      child: const Text('Revert')),
                  if (c.mode.value == FloorPlanMode.selection)
                    OutlinedButton(
                        key: const Key('reset-layout'),
                        onPressed: c.resetLayout,
                        child: const Text('Reset layout')),
                  OutlinedButton(
                      key: const Key('fit'),
                      onPressed: c.fitToView,
                      child: const Text('Fit')),
                ]),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('select-number'),
                  controller: _number,
                  decoration: const InputDecoration(
                      labelText: 'Table numbers (comma separated)'),
                  onSubmitted: (_) => _select(),
                ),
                const SizedBox(height: 8),
                FilledButton.tonal(
                    key: const Key('select'),
                    onPressed: _select,
                    child: const Text('Select')),
                const SizedBox(height: 16),
                Text('Status of the selected tables or group', style: title),
                const SizedBox(height: 4),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final name in kStatuses.keys)
                    OutlinedButton(
                        key: Key('status-${name.toLowerCase()}'),
                        onPressed: () => _setStatus(name),
                        child: Text(name)),
                  OutlinedButton(
                      key: const Key('status-random'),
                      onPressed: _randomStatuses,
                      child: const Text('Random statuses')),
                ]),
                const SizedBox(height: 16),
                Text('Tables', style: title),
                Text(
                    key: const Key('tables'),
                    c.tables.isEmpty
                        ? 'none'
                        : [
                            for (final t in c.tables)
                              '${t.number ?? '—'} (${t.seats})'
                          ].join(', ')),
                const SizedBox(height: 8),
                Text('Groups', style: title),
                Text(key: const Key('groups'), _groupsText(c)),
                for (final (i, w) in c.numberingWarnings.indexed)
                  Text(w,
                      key: Key('numbering-warning-$i'),
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 16),
                Text('Log', style: title),
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
