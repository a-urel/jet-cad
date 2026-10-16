// The restaurant embedding's demo host, on the plan library and its two
// kits (sub-project 4a): two dining areas, each a `PlanController` over the
// architecture and restaurant kits (a plan built in code, lib/samples), an
// area switch, the Standard / POS look and the three languages. This is the
// shell; the service features (Design / Service, statuses, groups, the
// table menu, selection and find, zones, the bars, export, the events log)
// come back in Tasks 7 and 8 of the restaurant-kit plan, against the audit.
// An example and an integration surface, not a product.
import 'package:flutter/material.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_kit_restaurant/jet_cad_2d_kit_restaurant.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import 'demo_strings.dart';
import 'demo_theme.dart';
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
  runApp(const RestaurantDemo());
}

/// The demo's theme seed, for the light and the dark theme alike.
const Color _seed = Colors.teal;

/// The demo. [locale] is the language to start in; the system's when null.
class RestaurantDemo extends StatefulWidget {
  const RestaurantDemo({super.key, this.locale});

  final Locale? locale;

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
            look: _look,
            onLook: (look) => setState(() => _look = look),
            onLocale: (l) => setState(() => _locale = l)),
      );
}

/// One dining area: its name and its own controller.
final class Area {
  Area(this.name, this.controller);

  final String name;
  final PlanController controller;
}

/// The demo's page: the area switch, the language and look toggles, and the
/// current area's editor.
class DemoHome extends StatefulWidget {
  const DemoHome(
      {super.key, this.look = DemoLook.standard, this.onLook, this.onLocale});

  final DemoLook look;
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
            kits: [architectureKit, restaurantKit], build: buildSalon)),
    Area(
        'Teras',
        PlanController(
            kits: [architectureKit, restaurantKit], build: buildTeras)),
  ];

  int _area = 0;

  Area get area => areas[_area];

  @override
  void dispose() {
    for (final a in areas) {
      a.controller.dispose();
    }
    super.dispose();
  }

  /// The local `Theme` around the editor under the POS look: the POS's
  /// tokens as the Material scheme.
  ThemeData _viewTheme(ThemeData ambient) =>
      widget.look == DemoLook.pos ? posViewTheme(ambient) : ambient;

  @override
  Widget build(BuildContext context) {
    final words = DemoStrings.of(context);
    final a = area;
    return Scaffold(
      appBar: AppBar(
        title: Text(words.title),
        actions: [
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
            onSelectionChanged: (s) => setState(() => _area = s.single),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Theme(
        data: _viewTheme(Theme.of(context)),
        // One editor at a time, keyed by the area: a second canvas on one
        // controller asserts, and a switch mounts the other area's.
        child: PlanEditor(
          key: ValueKey(a.name),
          controller: a.controller,
          exportName: a.name,
          theme: widget.look == DemoLook.pos ? kPosViewOverride : null,
        ),
      ),
    );
  }
}
