// The restaurant embedding's demo host (spec 14b-2 H10): what a point-of-
// sale application does with the planner, through its public API only.
//
// Two dining areas (umbrella decision 12), each a FloorPlanController over
// a plan kept in memory; a Design / Service toggle that asks before it
// discards service edits; selection by table number; and a log of the
// API's state. An example and an integration surface, not a product.
import 'package:flutter/material.dart';
import 'package:jet_cad_floor_plan/jet_cad_floor_plan.dart';
import 'package:jet_cad_restaurant_symbols/jet_cad_restaurant_symbols.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Native platforms: the documents' family from the package's bytes.
    // The web reads the family the pubspec declares (14b-1 V-11a).
    await ensureFloorPlanFonts();
  } catch (_) {
    // The text then measures in the platform's font; nothing else fails.
  }
  registerFontLicences();
  runApp(const RestaurantDemo());
}

/// The demo. [plans] seeds the areas' stored plans by name (tests); an area
/// without one starts empty.
class RestaurantDemo extends StatelessWidget {
  const RestaurantDemo({super.key, this.plans = const {}});

  final Map<String, String> plans;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Restaurant demo',
        theme: ThemeData(colorSchemeSeed: Colors.teal),
        home: DemoHome(plans: plans),
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
  const DemoHome({super.key, required this.plans});

  final Map<String, String> plans;

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
  final TextEditingController _number = TextEditingController();

  /// The newest line first.
  final List<String> log = [];

  Area get area => areas[_area];

  @override
  void initState() {
    super.initState();
    _symbols.load();
    for (final a in areas) {
      final c = a.controller;
      c.mode.addListener(() => _log('${a.name}: mode ${c.mode.value.name}'));
      c.selectedTables.addListener(() => _log(
          '${a.name}: selected {${(c.selectedTables.value.toList()..sort()).join(', ')}}'));
      c.dirty.addListener(
          () => _log('${a.name}: ${c.dirty.value ? 'edited' : 'saved'}'));
      c.addListener(() => setState(() {}));
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
      if (discard != true) return;
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

  void _select() {
    final numbers = {for (final n in _number.text.split(',')) n.trim()}
      ..remove('');
    area.controller.select(numbers);
  }

  @override
  Widget build(BuildContext context) {
    final c = area.controller;
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
                Text('Tables', style: title),
                Text(
                    key: const Key('tables'),
                    c.tables.isEmpty
                        ? 'none'
                        : [
                            for (final t in c.tables)
                              '${t.number ?? '—'} (${t.seats})'
                          ].join(', ')),
                for (final w in c.numberingWarnings)
                  Text(w,
                      key: const Key('numbering-warning'),
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
