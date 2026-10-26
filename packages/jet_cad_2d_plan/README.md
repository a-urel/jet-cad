# jet_cad_2d_plan

The plan library of jet_cad_2d. A `PlanController` owns one plan — its
document, the parametric system over it, the camera, the selection, the
tools, the undo history — and the design-mode widgets take only the
controller: `PlanCanvas`, `PlanToolPalette`, `PlanSymbolGallery`,
`PlanPropertyPanel`, `PlanLayerPanel`, `PlanPagePanel` and `PlanShortcuts`,
or `PlanEditor`, which lays them out as one editor.

In **service mode** (`controller.setMode(PlanMode.service)`) staff work on
a copy of the plan: `PlanServiceView` (which `PlanEditor` shows in that
mode) taps, selects, groups and moves its **units** -- the tables placed by
hand and the seats a kit's rows generate -- by their labels, with statuses,
groups, focus and the host's own widgets on them. Nothing done there
reaches the saved plan; `serviceJson()` and `restoreService` keep the
moves and groups apart from it.

What a plan holds beyond lines and shapes comes from **kits**
(`package:jet_cad_2d_kit`): their parametric types, tools, attachment
providers and symbol libraries. The library knows no domain. A plan that
names a kit the host did not load opens, draws and saves its objects
unchanged, and locks them; a kit whose code fails is contained to the
objects it broke.

![The plan editor over a sample flat: walls, rooms, doors, windows and furniture](https://raw.githubusercontent.com/a-urel/jet-cad/jet_cad_2d_plan-v1.0.2/packages/jet_cad_2d_plan/doc/screenshots/plan_editor.png)

## Use

```dart
// PlanEditor over an empty plan with no kit: the plan library's own tools,
// the layers and the page; a button in each bar switches to the service
// mode and back. Run from the package directory with
// `flutter run -t example/main.dart`.
import 'package:flutter/material.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ensurePlanFonts();
  registerFontLicences();
  runApp(const PlanExampleApp());
}

class PlanExampleApp extends StatefulWidget {
  const PlanExampleApp({super.key});

  @override
  State<PlanExampleApp> createState() => PlanExampleAppState();
}

class PlanExampleAppState extends State<PlanExampleApp> {
  /// One plan and no kit: a kit package adds its types, tools and symbols
  /// through `PlanController(kits: [...])`.
  final PlanController controller = PlanController(kits: const []);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  /// Switches the plan to [next]: the service mode works on a copy, so
  /// nothing done there reaches the saved plan.
  Widget modeButton(PlanMode next) => IconButton(
        key: Key('example-${next.name}'),
        tooltip: next.name,
        icon: Icon(next == PlanMode.service
            ? Icons.room_service_outlined
            : Icons.edit_outlined),
        onPressed: () => controller.setMode(next),
      );

  @override
  Widget build(BuildContext context) => MaterialApp(
        supportedLocales: planSupportedLocales,
        localizationsDelegates: planLocalizationsDelegates,
        home: Scaffold(
          body: PlanEditor(
            controller: controller,
            bar: PlanEditorBar(trailing: [modeButton(PlanMode.service)]),
            serviceBar: PlanServiceBar(trailing: [modeButton(PlanMode.design)]),
          ),
        ),
      );
}
```

- `PlanController.save()` and `load(text)` read and write a plan;
  `export('plan.pdf' or 'plan.png', choice)` and `print(choice)` make its
  page's bytes; a host adds its own exporters and importers.
- `PlanPermissions` decide what the editor lets a user change.
- The kit author's contract is `docs/kits.md` in the repository.

## What the editor offers

- **Every device.** `PlanEditor` lays itself out by its own width: docked
  side columns on a desktop, a docked tool strip and a right drawer on a
  tablet, two drawers on a phone. `breakpoints` moves the widths and
  `layout` forces one.
- **Alignment guides**, in design and in service. While an object is dragged
  or placed, lines show where its edges or centre line up with a neighbour,
  or where its gap equals another gap, and it snaps there. Alt (Option)
  suspends them for a drag; `alignmentGuides: false` turns them off.
- **The host's own widgets.** `objectInspectorBuilder` puts the host's
  widget (a combo over its records, say) in the property panel for the one
  selected object, and `setObjectData` keeps the host's ids on any object,
  saved with the plan. `unitOverlayBuilder` draws the host's badges on the
  tables; taps and the service events (moves, merges, splits) reach the host
  as callbacks.
- **Sections.** A unit's section is the smallest kit area (a room) its
  centre stands in, read from `unitDetails` and announced on
  `sectionChanges`.
- **The right column follows the selection**: an object's own properties
  while something is selected, the layers and the page while nothing is.

## Requirements and theming

- Flutter 3.44 or later. The editor's chrome is built on `shadcn_ui`
  (`^0.57.1`), which needs Dart 3.11, so a host needs Dart 3.11 too. A host
  that already uses `shadcn_ui` moves to `^0.57.1`; the planner and the host
  share one copy.
- A host's `ShadTheme` above the editor is used as it is. A Material host
  needs nothing: the chrome takes its colours, brightness and font family
  from the app's `ThemeData`. `PlanTheme` styles the canvas.
- No `shadcn_ui` type is part of this package's API.

## Screenshots

![PlanSymbolGallery, the plan library's symbol library, over the architecture kit's furniture](https://raw.githubusercontent.com/a-urel/jet-cad/jet_cad_2d_plan-v1.0.2/packages/jet_cad_2d_plan/doc/screenshots/plan_gallery.png)

`PlanSymbolGallery`: the plan library's symbol library, the loaded kits'
symbols in collapsible categories of thumbnail cells, browsable with a search
over names and tags.

These pictures are made by `tool/screenshots` in the repository, with the
plan's own theme.

## The API

`package:jet_cad_2d_plan/jet_cad_2d_plan.dart` is the API. Nothing under
`src/` is.

From 1.0.0 the package follows semantic versioning: a minor release adds,
a patch release fixes, and only a major release breaks the API. The
[CHANGELOG](CHANGELOG.md) lists every change.

## The jet-cad packages

| Package | What it is | Depends on |
|---|---|---|
| [`jet_cad_2d_plan`](https://pub.dev/packages/jet_cad_2d_plan) | The plan library: the editor, the widgets and the host API | the kit contract, the renderer and the engine |
| [`jet_cad_2d_kit_architecture`](https://pub.dev/packages/jet_cad_2d_kit_architecture) | The architecture kit: walls, openings, rooms, dimensions and furniture | the kit contract, the renderer and the engine |
| [`jet_cad_2d_kit_restaurant`](https://pub.dev/packages/jet_cad_2d_kit_restaurant) | The restaurant kit: furniture and service units | the kit contract and the engine |
| [`jet_cad_2d_kit`](https://pub.dev/packages/jet_cad_2d_kit) | The kit contract: types, tools and the symbol library format | the renderer and the engine |
| [`jet_cad_2d_flutter`](https://pub.dev/packages/jet_cad_2d_flutter) | Flutter rendering and interaction | the engine |
| [`jet_cad_2d`](https://pub.dev/packages/jet_cad_2d) | The pure-Dart engine and document model | nothing of jet-cad |

A host that embeds the planner adds `jet_cad_2d_plan` and the kits it loads;
the kit contract, the renderer and the engine come with them, and a host
should not also depend on them directly unless it uses their API itself.

Embedding the floor planner in an app is walked through in the
[host guide](https://github.com/a-urel/jet-cad/blob/main/docs/host-guide.md).

## Support

If jet-cad is useful to you, you can support its development through
[GitHub Sponsors](https://github.com/sponsors/a-urel) or
[Buy Me a Coffee](https://buymeacoffee.com/yazemo).

## License

Apache License 2.0. See [LICENSE](LICENSE).
