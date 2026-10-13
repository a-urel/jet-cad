# jet_cad_floor_plan

An embeddable parametric floor planner for Flutter. It draws and edits a
plan of walls, doors and windows, rooms, dimensions and furniture symbols,
and gives a host application, such as a restaurant's point of sale, a
controller and a view to embed it with: the tables of the plan, their
numbers and status, a service view over the same plan, and PDF and PNG
export. The planner never stores anything itself; the host keeps the plan's
text wherever it likes.

## Embedding it

A `FloorPlanController` holds the plan and what is done to it; a
`FloorPlanView` shows it. The application owns the controller and disposes
of it.

```dart
final symbols = SymbolLibraryLoader(sources: const [furnitureSymbolSource]);
final controller = FloorPlanController(symbols: symbols);

MaterialApp(
  supportedLocales: floorPlanSupportedLocales,
  localizationsDelegates: floorPlanLocalizationsDelegates,
  home: Scaffold(body: FloorPlanView(controller: controller)),
)
```

Before `runApp`, load the planner's font and register its licence:

```dart
WidgetsFlutterBinding.ensureInitialized();
await ensureFloorPlanFonts();
registerFontLicences();
```

The plans name the family `Roboto`, and the package ships its bytes. Declare
the family in the host's `pubspec.yaml`, so the web never fetches Google's
Roboto instead:

```yaml
flutter:
  uses-material-design: true
  fonts:
    - family: Roboto
      fonts:
        - asset: packages/jet_cad_floor_plan/fonts/Roboto-Regular.ttf
```

The planner speaks English, German and Turkish: `floorPlanSupportedLocales`
and `floorPlanLocalizationsDelegates` list them, with Flutter's own words
for the same languages.

A complete app is
[`example/lib/main.dart`](https://github.com/a-urel/jet-cad/blob/main/packages/jet_cad_floor_plan/example/lib/main.dart).
Run it from the package directory with `flutter run -t example/lib/main.dart`.

## The host guide

Tables, their status and groups, the service view, the theme, the editor's
capabilities, saving and loading, printing: the host guide walks through
them all, in code that CI compiles:
<https://github.com/a-urel/jet-cad/blob/main/docs/host-guide.md>

## A symbol library of your own

The package ships a furniture library, `furnitureSymbolSource`. A host adds
its own beside it with a `SymbolLibrarySource` (a name, a reader of the
library's bytes, and its `SymbolNames` in other languages) and gives the
loader every source it should read:

```dart
SymbolLibraryLoader(sources: [furnitureSymbolSource, mySymbolSource])
```

Two sources must not hold the same key. `package:jet_cad_floor_plan/symbols.dart`
holds the catalog types and the library builder a catalog's generator is
written in; `symbol_sources.dart` holds the sources and their loader's
Flutter side.

## The API

- `package:jet_cad_floor_plan/jet_cad_floor_plan.dart` is the host API.
- `package:jet_cad_floor_plan/symbols.dart` and `symbol_sources.dart` are the
  symbol libraries' API.
- `package:jet_cad_floor_plan/editor.dart` is the editor frame of the
  jet-cad floor planner app. It is not host API and is outside semver: it
  may change in any release.
- Nothing under `src/` is API.

While the version is `0.x`, a minor release (`0.8.0`) may break the API, and a
patch release (`0.7.2`) does not.

## Where it comes from

This package is part of [jet-cad](https://github.com/a-urel/jet-cad). It
builds on [`jet_cad_2d`](https://pub.dev/packages/jet_cad_2d), the engine,
and [`jet_cad_2d_flutter`](https://pub.dev/packages/jet_cad_2d_flutter), its
rendering.

## License

Apache License 2.0. See [LICENSE](LICENSE). The Roboto font in
`lib/fonts/` is under its own Apache License 2.0, in `assets/fonts/`.
