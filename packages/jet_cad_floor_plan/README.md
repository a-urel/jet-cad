# jet_cad_floor_plan

An embeddable parametric floor planner for Flutter. It draws and edits a
plan of walls, doors and windows, rooms, dimensions and furniture symbols,
and gives a host application, such as a restaurant's point of sale, a
controller and a view to embed it with: the tables of the plan, their
numbers and status, a service view over the same plan, and PDF and PNG
export. The planner never stores anything itself; the host keeps the plan's
text wherever it likes.

![FloorPlanView in design mode: tool palette, symbols, layers and the page, light theme](https://raw.githubusercontent.com/a-urel/jet-cad/jet_cad_floor_plan-v0.7.2/packages/jet_cad_floor_plan/doc/screenshots/design_light.png)


## Embedding it

A `FloorPlanController` holds the plan and what is done to it; a
`FloorPlanView` shows it. The application owns the controller and disposes
of it.

![The service view: tables with status colours and captions, and a group of two tables](https://raw.githubusercontent.com/a-urel/jet-cad/jet_cad_floor_plan-v0.7.2/packages/jet_cad_floor_plan/doc/screenshots/service_status.png)

```dart
final symbols = SymbolLibraryLoader(sources: const [furnitureSymbolSource]);
final controller = FloorPlanController(symbols: symbols);

final app = MaterialApp(
  supportedLocales: floorPlanSupportedLocales,
  localizationsDelegates: floorPlanLocalizationsDelegates,
  home: Scaffold(body: FloorPlanView(controller: controller)),
);
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

## Screenshots

![The editor in a dark theme](https://raw.githubusercontent.com/a-urel/jet-cad/jet_cad_floor_plan-v0.7.2/packages/jet_cad_floor_plan/doc/screenshots/design_dark.png)

The editor under a dark ambient `Theme`.

![The service view in a dark POS theme with one zone of tables in focus](https://raw.githubusercontent.com/a-urel/jet-cad/jet_cad_floor_plan-v0.7.2/packages/jet_cad_floor_plan/doc/screenshots/service_dark_focus.png)

The service view in a dark POS-like `FloorPlanTheme`, with one zone of tables in focus (`setTableFocus`) and the rest dimmed.

![A rubber band across the front row of tables](https://raw.githubusercontent.com/a-urel/jet-cad/jet_cad_floor_plan-v0.7.2/packages/jet_cad_floor_plan/doc/screenshots/service_band.png)

A rubber band (`floorDrag: FloorPlanFloorDrag.band`) mid-drag across the front row of tables.

![Tables in plan colours](https://raw.githubusercontent.com/a-urel/jet-cad/jet_cad_floor_plan-v0.7.2/packages/jet_cad_floor_plan/doc/screenshots/service_colors.png)

Tables in plan colours (`setTablesColor`).

The restaurant tables in the service pictures come from the repository's restaurant symbols, which a host copies as the host guide's "The restaurant symbols" describes; the furniture library ships with the package. The captions in the pictures are set in Roboto by the pictures' own app theme; a host asks for them in its theme.

## A symbol library of your own

The package ships a furniture library, `furnitureSymbolSource`. A host adds
its own beside it with a `SymbolLibrarySource` (a name, a reader of the
library's bytes, and its `SymbolNames` in other languages) and gives the
loader every source it should read:

```dart
final loader = SymbolLibraryLoader(
  sources: [furnitureSymbolSource, mySymbolSource],
);
```

Two sources must not hold the same key. `package:jet_cad_floor_plan/symbols.dart`
holds the catalog types and the library builder a catalog's generator is
written in; `symbol_sources.dart` exports `SymbolLibrarySource`,
`furnitureSymbolSource`, `readBundledLibrary` and `SymbolNames`. The loader,
`SymbolLibraryLoader`, is on the main barrel.

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

## The jet-cad packages

| Package | What it is | Depends on |
|---|---|---|
| [`jet_cad_floor_plan`](https://pub.dev/packages/jet_cad_floor_plan) | The embeddable floor planner and its host API | the renderer and the engine |
| [`jet_cad_2d_flutter`](https://pub.dev/packages/jet_cad_2d_flutter) | Flutter rendering and interaction | the engine |
| [`jet_cad_2d`](https://pub.dev/packages/jet_cad_2d) | The pure-Dart engine and document model | nothing of jet-cad |

A host that embeds the planner adds only `jet_cad_floor_plan`; the other two
come with it, and a host should not also depend on them directly unless it
uses their API itself.

## Support

If jet-cad is useful to you, you can support its development through
[GitHub Sponsors](https://github.com/sponsors/a-urel) or
[Buy Me a Coffee](https://buymeacoffee.com/yazemo).

## License

Apache License 2.0. See [LICENSE](LICENSE). The Roboto font in
`lib/fonts/` is under its own Apache License 2.0, in `assets/fonts/`.
