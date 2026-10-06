# Embedding the floor planner in a POS — host guide

This guide is for a Flutter point-of-sale application (a **host**) that
embeds the floor planner: staff design the restaurant's floors in the
**design** mode, and during service they see the tables, colour them by
status and pick them in the **selection** mode. It covers release
**0.1.0** ([CHANGELOG](../CHANGELOG.md)).

Every Dart snippet below is taken from
[`tool/ci/host_probe/lib/main.dart`](../tool/ci/host_probe/lib/main.dart),
a small host that CI builds from outside the repository on every push.
`tool/ci/check_guide.dart` fails CI when a snippet here is no longer in
that file, so the code in this guide compiles against the release.

## 1. The dependency

The packages are not on pub.dev. Depend on them by git, **both pinned to
the same commit SHA** — the SHA the release tag `v0.1.0` points at:

```yaml
dependencies:
  flutter:
    sdk: flutter
  jet_cad_floor_plan:
    git:
      url: https://github.com/a-urel/jet-cad.git
      path: packages/jet_cad_floor_plan
      ref: <the commit SHA of v0.1.0>
  jet_cad_restaurant_symbols:
    git:
      url: https://github.com/a-urel/jet-cad.git
      path: packages/jet_cad_restaurant_symbols
      ref: <the commit SHA of v0.1.0>
```

Why a SHA and not the tag: the restaurant package depends on the planner
by a path inside the repository, which pub resolves at the commit's SHA.
If your `ref` is a tag or a branch, pub sees two different refs for the
planner and refuses. The other form that resolves is the restaurant
package **alone** at the tag (`ref: v0.1.0`), the planner arriving
through it; you then import the planner without listing it, which
`depend_on_referenced_packages` will flag.

The engine (`jet_cad_2d`) and the renderer (`jet_cad_2d_flutter`) come
with the planner. Import only the two barrels:
`package:jet_cad_floor_plan/jet_cad_floor_plan.dart` and
`package:jet_cad_restaurant_symbols/jet_cad_restaurant_symbols.dart`.
Anything under `src/` is not API.

The packages need Flutter 3.44 or later and Dart 3.5 or later; the
release was built and tested with Flutter 3.47.6.

## 2. Fonts

Plans name the family `Roboto`, and the planner ships its bytes. Declare
the family in your pubspec, so the web never fetches Google's Roboto
instead:

```yaml
flutter:
  uses-material-design: true
  fonts:
    - family: Roboto
      fonts:
        - asset: packages/jet_cad_floor_plan/fonts/Roboto-Regular.ttf
```

Then register it before `runApp`, with its licence:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ensureFloorPlanFonts();
  registerFontLicences();
  if (kIsWeb) await BrowserContextMenu.disableContextMenu();
  runApp(PosApp(store: MemoryStore()));
}
```

`ensureFloorPlanFonts` registers once per process; a later call returns
the first one's future, or tries again if it failed. It throws when the
font asset cannot be read: the demo
([`apps/restaurant_demo/lib/main.dart`](../apps/restaurant_demo/lib/main.dart))
catches and reports it, and its plans then measure in the platform's
font. The `BrowserContextMenu` line is
[§ 8](#8-callbacks-options-and-the-webs-context-menu).

## 3. Languages

English, German and Turkish are built in. List them and the planner's
delegates in your `MaterialApp`:

```dart
    return MaterialApp(
      locale: locale,
      supportedLocales: floorPlanSupportedLocales,
      localizationsDelegates: floorPlanLocalizationsDelegates,
      home: FloorScreen(store: store),
    );
```

- The planner follows the **resolved** locale: `locale` if you set it,
  otherwise the system's, matched against `supportedLocales`. A locale
  you do not list resolves to one you do; one the planner does not know
  gives English.
- `floorPlanLocalizationsDelegates` holds the planner's delegate and
  Flutter's Material, Widgets and Cupertino ones. If you list `de` or
  `tr` without Flutter's delegates, Material widgets throw.
- To switch language at run time, change `MaterialApp.locale`.
  `Localizations.override` around the view alone is **not supported**:
  the Export dialog opens on the root navigator and would not see it.
- Your own words: `FloorPlanStrings.of(context)` gives the planner's
  language, and its `languageCode`.
- Panel numbers show and read with the language's decimal separator.
  The plan's own text — dimensions, room areas, the rulers, the PDF and
  PNG — keeps `.` in every language in 0.1.0.

## 4. The controller and the view

A `FloorPlanController` holds one floor's plan; a `FloorPlanView` shows
it. Give the controller the restaurant library beside the planner's
furniture. With several floors, share one symbol loader and one
thumbnail cache between their controllers:

```dart
  final symbols = SymbolLibraryLoader(
    sources: const [furnitureSymbolSource, restaurantSymbolSource],
  );
  final thumbnails = SymbolThumbnails(maxEntries: 128);

  late final FloorPlanController controller = FloorPlanController(
    symbols: symbols,
    thumbnails: thumbnails,
  );
```

A controller you give a loader or a cache never disposes them; dispose
them yourself after the controllers:

```dart
  void dispose() {
    controller.dispose();
    thumbnails.dispose();
    symbols.dispose();
    super.dispose();
  }
```

A single floor can skip both: `FloorPlanController(symbolSources: …)`
makes and owns its own.

The view, with every host option:

```dart
            child: FloorPlanView(
              controller: controller,
              exportName: 'floor-1',
              onExport: saveExport,
              printer: const PrintingPagePrinter(),
              onTableTap: openOrder,
              onTableContextMenu: showTableMenu,
              serviceMoves: staffMayMoveTables,
              longPress: FloorPlanLongPress.toggleSelection,
            ),
```

The mode is the controller's: `controller.setMode(FloorPlanMode.design)`
or `FloorPlanMode.selection`, read back from `controller.mode`. The
design mode is the full editor; the selection mode shows the canvas
alone, on a **service copy** of the plan.

## 5. Storing the plan

The planner stores nothing. The plan is a JSON string you keep where you
like:

```dart
  Future<void> saveDesign() async {
    final json = controller.designJson();
    await store.write('floor-1.design', json);
    controller.markSaved();
  }

  Future<void> openDesign() async {
    final json = await store.read('floor-1.design');
    if (json == null) return;
    try {
      controller.load(json);
    } on FormatException catch (e) {
      showProblem('$e');
    }
  }
```

- `designJson()` is always the **designed** plan, whatever the mode.
- `markSaved()` marks the state that `designJson()` last encoded as
  saved; `controller.dirty` is true while the design differs from it.
  Service moves never make it dirty.
- `load` throws a `FormatException`, and changes nothing, when the text
  is not a plan. So does the constructor's `json:`.
- `newPlan()` starts an empty plan.

## 6. The service layout

Staff may drag tables during service. Those moves live on the service
copy only — the design never changes — and are lost when the copy is
rebuilt (a mode switch, `load`, `resetLayout`). To keep them across a
mode switch or a restart, save the **service layout** and put it back:

```dart
    controller.serviceLayoutChanges.addListener(saveLayout);
```

```dart
  Future<void> saveLayout() async {
    final json = controller.serviceLayoutJson();
    if (json != null) await store.write('floor-1.layout', json);
  }

  Future<void> enterService() async {
    controller.setMode(FloorPlanMode.selection);
    final json = await store.read('floor-1.layout');
    if (json == null || controller.mode.value != FloorPlanMode.selection) {
      return;
    }
    try {
      final result = controller.restoreServiceLayout(json);
      if (result.dropped.isNotEmpty) {
        showProblem('${result.dropped.length} tables are back in place');
      }
    } on FormatException {
      await store.delete('floor-1.layout');
    }
  }
```

- **Save on `serviceLayoutChanges`, never on `revision`.** It fires after
  a drag, Undo, Redo, `resetLayout` and a restore, and **never** on
  `setMode` or `load`: those start a copy with no moves, and saving then
  would overwrite your stored layout with an empty one.
- `serviceLayoutJson()` is null in the design mode.
- Restore after `setMode(FloorPlanMode.selection)`, and after a `load`
  in the selection mode. `restoreServiceLayout` throws a `StateError` in
  the design mode, and a `FormatException` (changing nothing) on text
  that is not a layout.
- A stored entry is applied only if its table is still the same table at
  the same designed place, visible and unlocked; the others are dropped
  and counted in `result.dropped` (an unnumbered table's number is null).
- After a restore, Undo does not remove the restored places;
  `resetLayout()` does, and fires `serviceLayoutChanges`, so the layout
  you store becomes empty too. `serviceEdited` tells whether any table
  stands away from its designed place.

## 7. Tables, statuses and selection

Tables are known by their **numbers** (strings), never by handles.

```dart
  void showStatuses() {
    controller.setTableStatus({
      '4': TableStatus(color: const Color(0x8000C853), caption: 'Free'),
      '7': TableStatus(color: const Color(0x80FF6D00), caption: '12:40'),
    });
  }
```

- `setTableStatus` replaces every status at once. Statuses are drawn in
  the selection mode only, are kept across mode switches and loads, and
  are never saved, exported, printed or undone. A caption is cut to 12
  characters.
- `controller.select({...})` selects by number;
  `controller.selectedTables` is what is selected in the active view.
- `controller.tables` lists the tables (number, seats, symbol key);
  `controller.revision` moves on every change of the active plan — re-read
  `tables` and `numberingWarnings` on it.

Numbering problems are values. Word them yourself, or let the planner
word them in its language:

```dart
  String describe(NumberingWarning warning) => switch (warning) {
        DuplicateNumber(:final number, :final count) =>
          'Table $number is used $count times',
        Unnumbered(:final seats) => 'A table with $seats seats has no number',
      };
```

```dart
  void checkNumbers() {
    final strings = FloorPlanStrings.of(context);
    setState(() {
      problems = [
        for (final warning in controller.numberingWarnings)
          strings.numberingWarning(warning),
      ];
    });
  }
```

## 8. Callbacks, options, and the web's context menu

- `onTableTap(number)`: a tap on a numbered table in the selection mode
  (a locked table reports its tap too).
- `onTableContextMenu(number, globalPosition)`: a **secondary click** on
  a table, or a long press when `longPress` is
  `FloorPlanLongPress.contextMenu`. An unselected table is first selected
  alone; a selected one keeps the selection, so your menu acts on
  `selectedTables`; a locked table is reported without a selection
  change; an unnumbered one is not reported.
- `longPress`: `toggleSelection` (the default: a long press adds or
  removes a table, for multiple selection on a touch screen) or
  `contextMenu` (a long press opens your menu; a touch screen then has no
  multiple selection).
- `serviceMoves: false` forbids moving tables during service (a host
  stand, a kitchen screen): a drag from a table pans the plan. It is read
  at each press, so you can change it while the view is shown.
- `onExport(FloorPlanExport)`: Export's bytes, file name and MIME type,
  for you to store or share. `printer` prints; without one, Print uses
  the platform's dialog.

On the web the browser opens its own menu on a right click as well,
unless you turn it off, app-wide, before `runApp` (the `main` of
[§ 2](#2-fonts)): `if (kIsWeb) await
BrowserContextMenu.disableContextMenu();`.

## 9. Touch

Both modes work on a touch screen. Two fingers pinch about their
midpoint and pan together; once two fingers are down nothing reaches a
tool until every finger lifts, and a second finger during a table drag
cancels the drag. A finger's picks and grips are finger-sized. In the
selection mode a tap selects, a drag from a table moves it (or pans,
under `serviceMoves: false`), and a long press does what `longPress`
says, about 500 ms from contact. Mouse, trackpad and stylus behave as on
a desktop.

## 10. What a host must never assume

- **Handles.** A table's identity is its number. The plan's internal
  handles are not API, and nothing in it hands one out.
- **The service copy's undo.** Undo in the selection mode undoes service
  moves only; it never reaches a design edit, and a restored layout is
  not a step.
- **A stored name's language.** A placed symbol keeps the library's
  English name in the plan; the planner shows it in the UI's language.
  Room and layer names are stored in the language they were created in.
- **The plan's text separator.** Dimensions and areas print with `.` in
  0.1.0, whatever the language.
