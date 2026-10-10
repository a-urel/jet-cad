# Embedding the floor planner in a POS — host guide

This guide is for a Flutter point-of-sale application (a **host**) that
embeds the floor planner: staff design the restaurant's floors in the
**design** mode, and during service they see the tables, colour them by
status and pick them in the **selection** mode. It covers release
**0.3.0** ([CHANGELOG](../CHANGELOG.md)).

Every Dart snippet below is taken from
[`tool/ci/host_probe/lib/main.dart`](../tool/ci/host_probe/lib/main.dart),
a small host that CI builds from outside the repository on every push.
`tool/ci/check_guide.dart` fails CI when a snippet here is no longer in
that file, so the code in this guide compiles against the release.

## 1. The dependency

The packages are not on pub.dev. Depend on them by git, **both pinned to
the same commit SHA** — the SHA the release tag `v0.3.0` points at,
`1b0c37a82c288744b21da9e6edd99b2cc6d8ff97` (the merge of release 0.3.0 into
`main`):

```yaml
dependencies:
  flutter:
    sdk: flutter
  jet_cad_floor_plan:
    git:
      url: https://github.com/a-urel/jet-cad.git
      path: packages/jet_cad_floor_plan
      ref: 1b0c37a82c288744b21da9e6edd99b2cc6d8ff97
  jet_cad_restaurant_symbols:
    git:
      url: https://github.com/a-urel/jet-cad.git
      path: packages/jet_cad_restaurant_symbols
      ref: 1b0c37a82c288744b21da9e6edd99b2cc6d8ff97
```

Why a SHA and not the tag: the restaurant package depends on the planner
by a path inside the repository, which pub resolves at the commit's SHA.
If your `ref` is a tag or a branch, pub sees two different refs for the
planner and refuses. The other form that resolves is the restaurant
package **alone** at the tag (`ref: v0.3.0`), the planner arriving
through it; you then import the planner without listing it, which
`depend_on_referenced_packages` will flag.

The engine (`jet_cad_2d`) and the renderer (`jet_cad_2d_flutter`) come
with the planner. Import only the two barrels:
`package:jet_cad_floor_plan/jet_cad_floor_plan.dart` and
`package:jet_cad_restaurant_symbols/jet_cad_restaurant_symbols.dart`.
Anything under `src/` is not API.

The packages need Flutter 3.44 or later (the Dart that comes with it);
0.3.0 was built and tested with Flutter 3.47.6. They bring no build hook
and no GPU renderer: nothing runs at build time beyond Flutter's own.
(0.1.0 needed Flutter 3.47: it still resolved `flutter_scene`, whose build
hook compiles shaders.)

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
  try {
    await ensureFloorPlanFonts();
  } catch (error, stack) {
    // The plans then measure in the platform's font; the POS still starts.
    FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack));
  }
  registerFontLicences();
  if (kIsWeb) await BrowserContextMenu.disableContextMenu();
  runApp(PosApp(store: MemoryStore()));
}
```

`ensureFloorPlanFonts` registers once per process; a later call returns
the first one's future, or tries again if it failed. It throws when the
font asset cannot be read; catch it, or the app never starts. The `BrowserContextMenu` line is
[§ 8](#8-callbacks-options-and-the-webs-context-menu).

## 3. Languages

English, German and Turkish are built in. List them and the planner's
delegates in your `MaterialApp`:

```dart
    return MaterialApp(
      theme: posLightTheme,
      darkTheme: posDarkTheme,
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
- `theme` and `darkTheme` carry the floor plan's look:
  [§ 9](#9-themes).
- Panel numbers show and read with the language's decimal separator,
  per language, not per region: `de_CH` gets German's `,`.
  The plan's own text — dimensions and room areas, on screen and on the
  PDF and PNG, and the rulers on screen — uses the separator **the plan**
  carries (the Page panel's
  *Decimal separator*), the same on every terminal; a new plan takes the
  UI language's. *Since 0.2.0; in 0.1.0 it is always `.`.*

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
    hovered.dispose();
    super.dispose();
  }
```

(`hovered` is the host's own: [Events and host
data](#events-and-host-data).)

A single floor can skip both: `FloorPlanController(symbolSources: …)`
makes and owns its own.

The view, with the host's options:

```dart
                child: FloorPlanView(
                  controller: controller,
                  exportName: 'floor-1',
                  onExport: saveExport,
                  printer: const PrintingPagePrinter(),
                  onTableTap: openOrder,
                  onTableContextMenu: showTableMenu,
                  onGroupTap: (group, number) => openOrder(number),
                  onMergeRequested: mergeTables,
                  onSplitRequested: splitGroup,
                  serviceMoves: staffMayMoveTables,
                  longPress: FloorPlanLongPress.toggleSelection,
                  tableOverlayBuilder: tableBadge,
                  tableOverlayLayout: const FloorPlanOverlayLayout(
                    anchor: Alignment.bottomCenter,
                    detailBreakpoints: [0.05],
                  ),
                  onTablesMoved: tablesMoved,
                  onTableDoubleTap: openBill,
                  onFloorTap: floorTapped,
                  onTableHover: showHover,
                  theme: const FloorPlanTheme(selectionWidth: 3),
                  serviceBar: ownBar
                      ? const FloorPlanServiceBar(visible: false)
                      : serviceBar,
                  editorBar: editorBar,
                  editorCapabilities: editing,
                  tableInspectorBuilder: tableInspector,
                  onExportDialog: askExport,
                  onPageFlowError: (error) => showProblem('$error'),
                  shortcuts: !posOwnsKeys,
                  autofocus: !posOwnsKeys,
                ),
```

(`onLayoutChanged`, one call per service drag, still exists; for saving,
`serviceLayoutChanges` in [§ 6](#6-the-service-layout) replaces it. The
two arguments after `longPress` draw your own widget on each table, and
the four after them report a drag's moved tables, a double tap, a tap on
the floor and the table under the mouse, all *unreleased on `main`*: [Your
own widgets on the tables](#your-own-widgets-on-the-tables), [Events and
host data](#events-and-host-data). `theme`, this view's own look over
your app theme's, is also *unreleased on `main`*: [§ 9](#9-themes). In
the probe the view sits in a local `Theme`, § 9's recipe. The last
eight, *unreleased on `main`* too, are the host's own chrome and keys:
`serviceBar`, `editorBar`, `onExportDialog` and `onPageFlowError` in
[The bars](#the-bars); `editorCapabilities` and `tableInspectorBuilder`
in [The editor's capabilities](#the-editors-capabilities); `shortcuts`
and `autofocus` in [Keyboard and focus](#keyboard-and-focus).)

Show a controller in **one `FloorPlanView` at a time**: a second view of
the same controller mounted beside the first throws a `StateError`. Two
floors side by side are two controllers.

The mode is the controller's: `controller.setMode(FloorPlanMode.design)`
or `FloorPlanMode.selection`, read back from `controller.mode`. A switch
keeps the plan where it is on the screen, zoom included (*since 0.2.0*;
0.1.0 kept the camera's numbers, so the plan moved by the editor's
panels); `fitToView()`, `load` and `newPlan()` fit it again, and
`fitToTables` frames a set of tables (*since 0.3.0*, see
[Zones](#zones-framing-and-focus)). The camera itself is public
(*unreleased on `main`*): `controller.camera` says where the plan is on
the screen, and `panBy`, `zoomBy` and `centerOn` move it, within the
zoom bounds the constructor's `minScale` and `maxScale` set (see [Your
own widgets on the tables](#your-own-widgets-on-the-tables)). The
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
    if (json == null || !mounted) return;
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
- `newPlan()` starts an empty plan. Its decimal separator is that of the
  language a `FloorPlanView` of this controller last showed (*since
  0.2.0*).
- *Since 0.2.0:* the constructor's empty plan takes the
  language of the first `FloorPlanView` that shows it. Read it with
  `designJson()`, or edit it, before any view shows it, and it keeps
  `.`.

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
    // Read before switching: while the read waits, the plan stays in the
    // design mode, so no move can be saved over the stored layout.
    final String? json;
    try {
      json = await store.read('floor-1.layout');
    } catch (e) {
      showProblem('$e');
      return;
    }
    if (!mounted) return;
    controller.setMode(FloorPlanMode.selection);
    if (json == null) return;
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
- **Read the stored layout first, then switch and restore in one
  synchronous step**, as above. Switching before an `await` leaves the
  copy live while the store answers: a table dragged meanwhile is saved
  over your stored layout, then thrown away by the restore.
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
    controller.setGroupStatus({
      'G1': TableStatus(color: const Color(0x80E53935), caption: 'Bill'),
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
        title: ValueListenableBuilder<int>(
          valueListenable: controller.revision,
          builder: (context, _, __) {
            final strings = FloorPlanStrings.of(context);
            final problems = [
              for (final warning in controller.numberingWarnings)
                strings.numberingWarning(warning),
            ];
            return Text(problems.isEmpty ? 'Floor 1' : problems.first);
          },
        ),
```

Word them where you build, not when they change: a sentence kept in
state stays in the old language after a language switch.

### Table groups

A host can merge tables into a **group** — a party seated across tables.
In the selection mode a group's members are framed and labelled, a tap on
a member selects the whole group (Shift or Ctrl adds or removes it
whole), and a drag moves it as one. Groups, like statuses, are the
host's: never saved, exported, printed or undone, kept across mode
switches and loads.

- `controller.setTableGroups({id: TableGroup(members: {...}, label: ...)})`
  replaces every group. It throws an `ArgumentError`, assigning nothing,
  for a blank or repeated id, an empty group, or a number in two groups.
- `controller.setGroupStatus({id: status})`: a group's status fills
  every member and overrides their own while it is set.
- `controller.selectedGroup` is the id of the group the selection is
  exactly, or null; `controller.selectableMembers(id)` gives a group's
  visible, unlocked member numbers.
- The service bar shows **Merge** and **Split** only when you pass
  `onMergeRequested` and `onSplitRequested`. The planner only asks; you
  decide and call `setTableGroups`:

```dart
  void mergeTables(Set<String> numbers) {
    final groups = <String, TableGroup>{};
    for (final MapEntry(key: id, value: group)
        in controller.tableGroups.value.entries) {
      final rest = group.members.difference(numbers);
      if (rest.isNotEmpty) {
        groups[id] = TableGroup(members: rest, label: group.label);
      }
    }
    var n = 1;
    while (controller.tableGroups.value.containsKey('G$n')) {
      n++;
    }
    groups['G$n'] = TableGroup(members: numbers);
    controller.setTableGroups(groups);
  }

  /// Split: the group goes, and its status with it.
  void splitGroup(String id) {
    controller.setTableGroups({...controller.tableGroups.value}..remove(id));
    controller.setGroupStatus({...controller.groupStatuses.value}..remove(id));
  }
```

- `onGroupTap(groupId, number)` follows `onTableTap` for a member.
- A context click or a long-press menu on an unselected member selects
  its whole group first, as a tap does, so your menu acts on the group.

### Zones: framing and focus

*Since 0.3.0.* A zone (Salon, Teras, Bar…) is **yours**: the
table's attribute in your database. The plan stores no zone. One plan
per dining area still works; these two calls serve a floor that holds
several zones in one plan.

- `controller.fitToTables(numbers)` frames the tables carrying those
  numbers, in either mode, with half a metre of floor round them and at
  least 3 m in each direction, so one table never fills the screen.
  Numbers are trimmed; unknown ones are ignored; a number used twice
  frames both tables; a table on a hidden layer is not framed. It
  returns `false`, and changes nothing, when no table matches: the zone
  is not drawn yet, so decide yourself — keep the view, call
  `fitToView()`, or say so.
- A framing is a camera request, as `fitToView()` is: with no view shown
  the next view frames on its first frame, the last request wins, and a
  mode switch keeps it. `load` and `newPlan()` drop it (the numbers named
  the old plan): frame after a load, and set the focus again — it is kept
  by number, and after loading another area into the same controller the
  numbers may name its tables or none of them. Nothing goes into the plan, its
  undo or `serviceLayoutChanges`.
- `controller.setTableFocus(numbers)` fades every other table in the
  selection mode under a veil of the paper's colour; `null` ends the
  focus, and an empty set fades every table. `controller.tableFocus` is
  its listenable. It is kept across mode switches and loads, never
  saved. A group with a focused member draws as before; a group with
  none fades with its tables.
- **A faded table still works:** it can be tapped, selected, dragged
  and merged, because a waiter under "My tables" still acts on a
  colleague's table. If you want it inert, check
  `controller.tableFocus.value` in your `onTableTap`, `onGroupTap` (it
  fires right after `onTableTap` for a member), `onTableContextMenu`,
  `onMergeRequested` and `selectedTables` listener — the table is already
  selected when `onTableTap` fires — and pass `serviceMoves: false` for
  no moves.

A zone tab frames its tables and, if you choose, fades the rest; *All*
shows the floor again:

```dart
  void showZone(Set<String> numbers, {required bool fadeOthers}) {
    if (!controller.fitToTables(numbers)) controller.fitToView();
    controller.setTableFocus(fadeOthers ? numbers : null);
  }

  void showAllZones() {
    controller.fitToView();
    controller.setTableFocus(null);
  }
```

"My tables" is a focus on the waiter's numbers, renewed as they change;
with a zone tab, focus the intersection. A framing frames only the
numbers you give: a group that straddles two zones is cut unless you add
its members.

The tables your POS knows that a floor does not draw are a set
difference; over several plans, take it against every plan of the
location. `FloorPlanTable.visible` is false for a table on a hidden
layer, which is not drawn, so it counts as unplaced:

```dart
  /// The tables the POS knows that this floor does not draw: a table on
  /// a hidden layer is not drawn, so it counts as unplaced. Codes compare
  /// trimmed, as `fitToTables` and `setTableFocus` trim them.
  Set<String> unplacedTables(Set<String> codes) {
    final drawn = {
      for (final table in controller.tables)
        if (table.visible && table.number != null) table.number!,
    };
    return {
      for (final code in codes)
        if (!drawn.contains(code.trim())) code,
    };
  }
```

Your codes are compared with the plan's numbers trimmed and
case-sensitively. The planner lets staff type a number of 1 to 8
characters (UTF-16 units) with no control character, so keep your codes
within those rules: a longer code matches only a plan edited by hand.

*Unreleased on `main`:* a POS that links its tables by an id it stores in
each table's data ([Events and host data](#events-and-host-data))
compares ids, which no renumbering changes:

```dart
  /// The POS's tables, by the id stored in each table's `data['id']`, that
  /// this floor does not draw. Ids compare exactly, whatever the numbers.
  Set<String> unplacedIds(Set<String> ids) {
    final drawn = {
      for (final detail in controller.tableDetails)
        if (detail.table.visible && detail.data['id'] != null)
          detail.data['id']!,
    };
    return ids.difference(drawn);
  }
```

### Your own widgets on the tables

*Unreleased on `main`.* A POS shows its own things on a table: the
guests, the minutes since they sat down, the waiter, a bill to print.
The planner tells you where each table is and where the plan is on the
screen, and draws a widget of yours on each table, pinned to it while
staff pan and zoom. None of it is stored in the plan, exported, printed
or undone.

**A table's place.** `controller.tableDetails` lists the tables of the
plan the current mode shows — the service copy in the selection mode,
so a service move changes it — in the order of `controller.tables`, one
`FloorPlanTableDetail` per table:

- `table`: the `FloorPlanTable` (number, seats, symbol key, `visible`).
- `center`: the centre of the table's box, in world millimetres, y up.
  It is the box's centre, not the point the symbol was placed by.
- `size`: the box's width and height in millimetres, the table's scale
  included.
- `rotation` (radians, counter-clockwise) and `mirrored`: the table is
  its box scaled to `size`, flipped about its own x axis when
  `mirrored`, then turned by `rotation` about `center`.
- `corners`: the box's four corners in world millimetres,
  counter-clockwise, mirrored or not.
- `layer` and `locked`: the table's layer, and whether it is locked (a
  locked table can be tapped and selected, never moved).
- `data`: your own data on the table, empty unless you stored some
  ([Events and host data](#events-and-host-data)).

A table on a hidden layer, or one whose corners are not finite (a
hand-edited file), is listed with `center` and `size` null and no
corners. The list is cached and unmodifiable: read it in `build` as
often as you like, and again when `controller.revision` moves.

**The camera.** `controller.camera` is a `ValueListenable` of
`FloorPlanCamera`, a new value at every pan, zoom and fit, by the user
or by you: `scale` in logical pixels per millimetre, `worldToCanvas`,
`canvasToWorld`, and `visibleWorld(size)`, the world a canvas of that
size shows. The view pans it too when its own bars, or the editor's
left column or rulers, are shown or hidden, so the plan stays where it
is on the screen; you hear that pan after the frame that lays the new
chrome out. The **canvas** is the view's drawing area, in logical
pixels, origin at its top left, y down: below the service bar in the
selection mode, inside the rulers in the design mode. The camera notifies on every frame of a pan, so a widget that
listens to it is rebuilt at that rate; keep such a widget small, like
this read-out:

```dart
          ValueListenableBuilder<FloorPlanCamera>(
            valueListenable: controller.camera,
            builder: (context, camera, _) =>
                Text('${(camera.scale * 1000).round()} px/m'),
          ),
```

`controller.canvasRect` is where the canvas is on the screen, in global
coordinates (its top left and its size), null while no view is shown;
`worldToGlobal` and `globalToWorld` map through it and the camera, null
without a view. They serve a widget **outside** the view, such as a menu
opened from a list of orders; the builder below needs neither:

```dart
  /// Opens table [number]'s menu from outside the view (a list of open
  /// orders, say), at the table's centre on the screen.
  Future<void> openMenuAt(String number) async {
    for (final detail in controller.tableDetails) {
      final center = detail.center;
      if (detail.table.number != number || center == null) continue;
      final at = controller.worldToGlobal(center);
      if (at != null) await showTableMenu(number, at);
      return;
    }
  }
```

- A view reports `canvasRect` after its first frame's fit, and again
  whenever it moves or is resized, an ancestor's padding included. An
  ancestor that scales or turns the view (a `Transform`, a `FittedBox`)
  is not accounted for.
- A mode switch sets it at once to where the new mode's canvas was the
  last time a view showed that mode; a mode no view has shown yet keeps
  the old rect until the end of the next frame.

**Moving the camera.** Three commands, in either mode:

- `panBy(canvasDelta)` moves the plan on the screen by that many logical
  pixels. It needs no view. It throws an `ArgumentError` for a delta that
  is not finite.
- `zoomBy(factor, focus: point)` zooms about a canvas point, the canvas's
  centre by default. It returns `false`, changing nothing, while no view
  is shown, for a factor that is not finite and above 0, or for a focus
  that is not finite.
- `centerOn(world, scale: s)` puts a world point at the canvas's centre,
  at that scale or at the camera's own. Asked without a scale before a
  view has fitted the plan, it takes the scale of the plan's own fit at
  the real canvas, so the plan shows at the zoom it would have had. It
  throws an `ArgumentError` for a point that is not finite, or a scale
  that is not finite and above 0.

```dart
  /// Brings table [number] to the middle of the view, close enough to read.
  void showTable(String number) {
    for (final detail in controller.tableDetails) {
      final center = detail.center;
      if (detail.table.number == number && center != null) {
        final scale = controller.camera.value.scale;
        controller.centerOn(center, scale: scale < 0.1 ? 0.1 : null);
        return;
      }
    }
  }
```

```dart
          IconButton(
              icon: const Icon(Icons.zoom_in),
              onPressed: () => controller.zoomBy(1.25)),
```

- **The zoom bounds.** `FloorPlanController(minScale: …, maxScale: …)`,
  in logical pixels per millimetre, 0.001 and 100 by default (the
  planner's own). The user's pinch and wheel, `zoomBy`, `centerOn` and
  every fit stay inside them; a zoom that would pass a bound stops on it.
  The constructor throws an `ArgumentError` unless both are finite and
  `1e-6 <= minScale < maxScale`. Fits are now clamped to the bounds too;
  with the default bounds no real plan is affected.
- **Requests and commands.** `centerOn` is a request, as `fitToView()`
  and `fitToTables` are: the view performs it at the end of the frame;
  with no view shown, the next view does it on its first frame; the last
  request wins. `panBy` and `zoomBy` act at once and drop a request not
  performed yet.
- **A plan's first fit is not a request.** After the constructor, `load`
  or `newPlan()`, the first view to show the plan fits it on its first
  frame whatever came before: a `panBy` or `zoomBy` made earlier is
  overwritten. To place the camera before a view shows, use `centerOn`
  (or `fitToTables`). A host that waits for a non-null `canvasRect`
  before calling `zoomBy` zooms the fitted plan.
- **Locking the user out.** `FloorPlanView(userCamera: false)` switches
  off the user's pan, pinch, wheel and trackpad zoom in that view, for a
  wall display or a kiosk: a drag on the floor then does nothing; taps,
  selection and table moves are unchanged, and your commands still act.

**The table at a point.** `controller.tableAt(canvasPoint)` gives the
number of the table a tap there would hit in the current mode, or null
for none and for an unnumbered table: a point on the table's top, else
in its box, the one drawn on top among several. Pass
`kind: PointerDeviceKind.touch` (from `package:flutter/gestures.dart`)
for a finger's reach of 24 px. A table on a hidden layer is never found;
a locked one is. The point is a canvas point; from a global one,
subtract the canvas's top left:

```dart
  /// The table under a global point (an order dropped on the plan), or
  /// null.
  String? tableUnder(Offset global) {
    final rect = controller.canvasRect.value;
    if (rect == null) return null;
    return controller.tableAt(global - rect.topLeft);
  }
```

**The builder.** Give the view a `tableOverlayBuilder` (the last
arguments of the view in [§ 4](#4-the-controller-and-the-view)); without
one there is no overlay layer at all. It gets a `FloorPlanTableOverlay`
per numbered table with geometry and returns that table's widget, or
null for none:

```dart
  /// A badge on each table with guests: their count over the seats, faded
  /// outside the focus, a dot when the plan is zoomed far out.
  Widget? tableBadge(BuildContext context, FloorPlanTableOverlay table) {
    final number = table.detail.table.number!;
    final guests = guestsAt[number];
    if (guests == null) return null;
    final Widget badge = table.detailLevel == 0
        ? const Icon(Icons.circle, size: 10)
        : Chip(label: Text('$guests / ${table.detail.table.seats}'));
    return Opacity(opacity: table.focused ? 1 : 0.4, child: badge);
  }
```

- `detail`: the table's `FloorPlanTableDetail`.
- `selected`: its number is in `selectedTables` (two tables sharing a
  number are both selected when it is).
- `focused`: its number is in the focus, or no focus is set.
- `status`: the status the selection mode draws on it — its group's when
  its group has one, else its own — or null.
- `detailLevel`: see *Detail levels* below.

It carries no screen position and no scale: those change at every frame
of a pan, and the widget is not rebuilt for them.

**When the builder runs.** Once per table when the layer is built; again
for **one table** when its `FloorPlanTableOverlay` changes (the plan,
the selection, the focus, a status, the detail level); and again for
**every table** each time your widget rebuilds the `FloorPlanView`,
whatever the function — a closure written in `build` and a method
tear-off behave the same — so a builder that reads your own fields, as
`tableBadge` reads `guestsAt`, sees them after your `setState`. **Never
on pan or zoom.** Data that changes on its own (an order's total, a
timer) belongs in your own state management inside the widget — a
`ValueListenableBuilder`, a `BlocBuilder` — which rebuilds that widget
and nothing else.

**Placement.** `tableOverlayLayout`, a `FloorPlanOverlayLayout`:

- `anchor` (default `Alignment.center`): the point of the table's
  bounding box **on the screen** the widget is pinned to, and the
  widget's own point placed there, as `Align` places a child:
  `Alignment.bottomCenter` sits the widget on the inside of the box's
  bottom edge. A turned table's bounding box is larger than the table.
- `size`: `FloorPlanOverlaySize.natural` (the default) keeps the
  widget's own size at every zoom, laid out once with loose constraints
  up to `maxNaturalSize` (default 200 × 120); `FloorPlanOverlaySize.box`
  sizes it to the table's bounding box on the screen, exactly, and lays
  it out again at every camera change.
- `hideBelowScale` (default 0): below this camera scale no overlay is
  laid out or painted.
- `interactive`: see *Pointers* below.
- `tableOverlayModes` on the view (default the selection mode only): the
  modes that show the overlays; add `FloorPlanMode.design` to see them
  in the editor too.

**Detail levels.** `detailBreakpoints`, camera scales in strictly
ascending order (default none): `detailLevel` is how many of them are at
or below the current scale. Crossing one builds every overlay once;
nothing else about the zoom builds anything. With `[0.05]`, as above, a
badge is a dot below 0.05 px/mm (a 20 m floor on a 1000 px canvas) and
the full badge above it. The view throws an `ArgumentError` when it is
built with a builder and breakpoints that are not finite, positive and
strictly ascending, or a `hideBelowScale` or `maxNaturalSize` that is
negative or not finite.

**Pointers.** By default the overlays ignore every pointer: a tap on a
badge is a tap on its table (it selects it and calls `onTableTap`), and
a drag from it moves the table or pans as from the table itself. With
`interactive: true`, a pointer that goes down on an overlay's widget is
the widget's alone, from that down to its up:

| Over a badge, with `interactive: true` | What happens |
|---|---|
| A tap (mouse, finger, stylus) | The widget's own `GestureDetector` only: no selection, no `onTableTap` |
| A drag, any button | Nothing under it: the table does not move, the plan does not pan |
| A long press, a secondary click | Neither the table's long press nor `onTableContextMenu`; the widget's own recognizers decide |
| A finger of a pinch | Not part of the pinch: a finger on a badge and one on the floor are a one-finger gesture of the floor's |
| A mouse hovering | Not over the canvas: the editor's hover highlight goes |
| The mouse wheel | Still zooms the plan, unless the widget takes the wheel itself (a scrollable inside it does) |
| A trackpad's pan and zoom | Always the plan's |

A pointer that goes down off every overlay, or on a transparent gap in
one, is the canvas's as before, wherever it then moves: a pan may cross
a badge. Use `onTap` and `onLongPress` on your own `GestureDetector`.
The layer marks an interactive widget with `InputClaim`, a name of
`jet_cad_2d_flutter` the CHANGELOG lists; a host never needs it.

The wheel over a badge goes to the plan through Flutter's
`PointerSignalResolver`, so there it wins over a scrollable of yours
that holds the view, and on the web the browser does not scroll the
page; off the badges the wheel behaves as before.

**Lifetime.** The overlays live as long as the plan the view shows: a
mode switch, `resetLayout()`, `restoreServiceLayout`, `load` and
`newPlan()` build them afresh, and so does switching `interactive`. Keep
state in your own objects, not in an overlay's `State`. Two tables
sharing a number get two widgets. While staff drag a table, its widget
stays at the table's last place and moves on the drop.

**The look.** The overlays paint above the plan, the statuses, the
selection outlines, the focus veil and the number chips, clipped to the
canvas and below the service bar. The veil does not fade them: fade an
unfocused table's widget yourself with `focused`, as `tableBadge` does.
`setTableStatus` keeps painting its fill and caption under your widgets;
if your widget shows the status, set none, or set a colour without a
caption.

**The cost.** Pan and zoom rebuild none of your widgets; they move them.
At each camera change the planner does a little arithmetic per table
and paints each `natural` overlay on the canvas at its new place; a
`box` overlay is also laid out again at its new size, so keep a `box`
widget light. Overlays off the canvas, and all of them below
`hideBelowScale`, are not painted. Each overlay sits behind its own
`RepaintBoundary`, so a widget that changes repaints alone.

**A kiosk.** A wall display or a self-service terminal puts most of the
above together: zoom bounds of its own, no pan or zoom by hand, its own
arrows for `panBy`, and each table one button the size of the table,
hidden when the plan is too small to press it:

```dart
/// A floor on a kiosk: staff cannot pan or zoom it by hand, the arrows
/// move it, and each table is a button that opens its order.
class KioskFloor extends StatefulWidget {
  const KioskFloor({super.key, required this.json, required this.onOrder});

  /// The floor's plan, as `designJson()` wrote it.
  final String json;

  /// Opens the order of table [number].
  final void Function(String number) onOrder;

  @override
  State<KioskFloor> createState() => _KioskFloorState();
}

class _KioskFloorState extends State<KioskFloor> {
  late final FloorPlanController controller = FloorPlanController(
    json: widget.json,
    minScale: 0.02,
    maxScale: 0.5,
  )..setMode(FloorPlanMode.selection);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  /// The floor point (millimetres) under a global point, such as a
  /// waiter's tag dropped on the plan; null while no view is shown.
  Offset? floorPointAt(Offset global) => controller.globalToWorld(global);

  /// The floor point at the middle of the canvas, or null.
  Offset? middle() {
    final rect = controller.canvasRect.value;
    if (rect == null) return null;
    return controller.camera.value.canvasToWorld(rect.size.center(Offset.zero));
  }

  /// How many tables are off the screen now.
  int tablesOutOfSight() {
    final rect = controller.canvasRect.value;
    if (rect == null) return 0;
    final shown = controller.camera.value.visibleWorld(rect.size);
    return controller.tableDetails
        .where((d) => d.center != null && !shown.contains(d.center!))
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => controller.panBy(const Offset(200, 0))),
            IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: () => controller.panBy(const Offset(-200, 0))),
            ValueListenableBuilder<FloorPlanCamera>(
              valueListenable: controller.camera,
              builder: (context, camera, _) =>
                  Text('${tablesOutOfSight()} tables out of sight'),
            ),
          ],
        ),
        Expanded(
          child: FloorPlanView(
            controller: controller,
            userCamera: false,
            tableOverlayModes: const {FloorPlanMode.selection},
            tableOverlayBuilder: (context, table) => Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () => widget.onOrder(table.detail.table.number!),
              ),
            ),
            tableOverlayLayout: const FloorPlanOverlayLayout(
              interactive: true,
              size: FloorPlanOverlaySize.box,
              hideBelowScale: 0.04,
            ),
          ),
        ),
      ],
    );
  }
}
```

- `userCamera: false` leaves the user no pan or zoom; the arrows'
  `panBy` still moves the plan, so the camera, and the read-out that
  listens to it, change only when an arrow is pressed. The read-out
  walks every table: fine at that rate, not at a pan's.
- `tableOverlayModes` is the default written out: a kiosk never shows
  the editor, and an overlay that takes taps would get in its way.
- `FloorPlanOverlaySize.box` makes each button exactly the table's
  bounding box on the screen; with `interactive: true` a tap on it is the
  button's, not the table's. Below 0.04 px/mm (`hideBelowScale`) the
  buttons are gone and a tap reaches the table, as with no overlays.
- `visibleWorld` is a `Rect` in world millimetres, y up, so its `top` is
  the least y; `contains` works as for any `Rect`.

### Events and host data

*Unreleased on `main`.* Four more gestures of the selection mode reach
you, a table can carry data of yours that is saved with the plan, and
the controller reports what changes among the designed tables.

**Four gestures.** The four view arguments after `tableOverlayLayout`
in [§ 4](#4-the-controller-and-the-view), each read at each call, each in
the selection mode only:

- `onTablesMoved(moved)`: after a drag of tables ends, every table it
  moved, numbered or not, in the order of `controller.tables`, as a
  `FloorPlanTableDetail` with its new geometry, in an unmodifiable list;
  once per drag, right after `onLayoutChanged`. Undo, Redo,
  `resetLayout()` and `restoreServiceLayout` do not call it: they fire
  `serviceLayoutChanges`. If your `onLayoutChanged` replaces the service
  copy (a `resetLayout()`, a `load`, a mode switch), that drag's
  `onTablesMoved` is not called: the tables it moved are gone.
- `onTableDoubleTap(number)`: a second tap on the **same table** whose
  down comes at most 300 ms (`kDoubleTapTimeout`) after the first tap's
  down and at most 100 logical pixels (`kDoubleTapSlop`) from it, both
  timed and measured from the raw pointer events. Two tables sharing a
  number are two tables: a tap on each is no double tap. A locked table
  reports it; an unnumbered one does not. With Shift, Ctrl or Cmd held on
  either tap it is no double tap (each tap toggles the selection). A
  third tap starts anew.
- `onFloorTap(world)`: a tap that missed every table, with the point its
  down went on, in world millimetres, y up, as `tableDetails` gives a
  table's centre. It comes after the tap's own effect: the selection is
  already cleared, or kept when Shift, Ctrl or Cmd was held. A tap with
  a modifier reports it too. A tap on an unnumbered table is neither a
  table's tap nor the floor's.
- `onTableHover(number)`: the mouse or a stylus moved onto a numbered
  table, or off it (null: over the floor, over an unnumbered table, or
  off the canvas); only when the number changes; never for a finger. A
  table is under the pointer on its top or in its box, with no reach.
  Over an interactive overlay (`interactive: true`) the pointer is off
  the canvas, so it reads null while it is on your widget. Without the
  callback a hover does no work.

**A tap action runs on each tap of a double tap.** The single tap is not
delayed: both taps select and call `onTableTap` (and `onGroupTap`) as
before, and `onTableDoubleTap` follows the second. A host that opens a
table's order on a tap and its bill on a double tap does both on a
double tap. Make the tap's action harmless to repeat, as opening an
order that is already open is, and let the double tap's take over.

```dart
  /// A drag in the service moved these tables: tell the other terminals.
  void tablesMoved(List<FloorPlanTableDetail> moved) {
    for (final detail in moved) {
      debugPrint('${detail.table.number ?? 'a table'} is at ${detail.center}');
    }
  }

  /// A double tap: the bill. Its two taps have opened the order already.
  void openBill(String number) => debugPrint('the bill of $number');

  /// A tap on the floor, in metres.
  void floorTapped(Offset world) =>
      debugPrint('floor at ${world.dx / 1000}, ${world.dy / 1000} m');

  /// The table under the mouse, for a line of the host's own.
  void showHover(String? number) => hovered.value = number;
```

Keep the hovered table in a `ValueNotifier` and show it with a
`ValueListenableBuilder`, so a hover rebuilds that line only: a
`setState` that rebuilds the `FloorPlanView` runs your overlay builder
for every table.

```dart
  /// The table the mouse is over, for the host's own line.
  final ValueNotifier<String?> hovered = ValueNotifier(null);
```

```dart
          ValueListenableBuilder<String?>(
            valueListenable: hovered,
            builder: (context, number, _) =>
                Text(number == null ? '' : 'Table $number'),
          ),
```

A mode switch, `resetLayout()`, a restore, `load` and `newPlan()` build
the view afresh with the pointer still where it was, and send **no null**
for the table it was over. Clear your hover state yourself then: on the
mode, and on a replaced plan (below).

```dart
    controller.mode.addListener(() => hovered.value = null);
```

**Your data on a table.** A table can carry a small map of strings of
yours, typically the id of its row in your database. It is saved in the
plan with the table, and read back as `FloorPlanTableDetail.data`:

```dart
  /// Links table [number] to the POS's own table [id]: false, changing
  /// nothing, when this floor has no table [number] or two of them.
  bool linkTable(String number, String id) =>
      controller.setTableData(number, {'id': id});

  /// The POS's id of table [number]: null when no table carries the
  /// number, or when two do (it names neither).
  String? idOf(String number) {
    final tables = [
      for (final detail in controller.tableDetails)
        if (detail.table.number == number) detail,
    ];
    return tables.length == 1 ? tables.single.data['id'] : null;
  }
```

- `setTableData(number, data)` replaces the table's whole map; an empty
  map removes it. It is a design edit: undoable (labelled "Table data"),
  it makes the plan `dirty`, moves `revision` and is reported on
  `designChanges` (below); `dirty` and `canUndo` read it on return. Data
  equal to the table's own returns true with no edit.
- It returns **false**, changing nothing, when the number (trimmed, as
  everywhere) names no table **or more than one**: an ambiguous link is
  refused, not guessed. Mend the numbering first (`numberingWarnings`).
- **Read a link the same way.** A number on two tables names neither:
  `idOf` above returns null for it rather than the first table's id. A
  number can come to name two tables after the link, by a renumbering in
  the editor, which `numberingWarnings` reports but allows; a callback
  such as `onTableDoubleTap` then carries a number both tables answer to,
  and the first one's id would open the other table's bill.
- A table on a hidden or locked layer takes data: a link is not a drawing
  edit.
- **The selection mode refuses it** with a `StateError`: nothing done
  during service reaches the design. The service copy carries the
  design's data, read only, so `tableDetails` reads it in either mode.
- `setTablesData({number: data, …})` writes several tables as **one**
  undo step, all or nothing: a map outside the limits throws before
  anything changes; a number unknown or shared, or two keys that trim to
  the same number, return false with nothing changed. Entries equal to
  the table's own are skipped.

```dart
  /// Links every table the POS knows on this floor, in one undo step;
  /// false, changing nothing, if a number is not on the floor or is on two
  /// tables.
  bool linkAll(Map<String, String> idByNumber) => controller.setTablesData({
        for (final MapEntry(key: number, value: id) in idByNumber.entries)
          number: {'id': id},
      });
```

- **The limits**, checked when you write (an `ArgumentError`, nothing
  changed): at most 32 keys; a key of 1 to 64 characters among `a`–`z`,
  `0`–`9`, `_`, `.` and `-`; a value of at most 1024 UTF-16 code units
  (a character outside the Basic Multilingual Plane, an emoji, counts
  two) with no control character: no code unit below U+0020 or from
  U+007F to U+009F, the rule of table numbers. A value may be empty.
- **In the plan** the map is a component of the table's placement,
  `"jetcad.table_data"`, as `{"data": {key: value}}` with the keys
  written sorted. You never read or write it there; `data` and
  `setTableData` are the API.
- **Delete drops it; Undo brings it back.** Deleting a table in the
  editor removes its data in the same step.
- **Renumbering keeps it**: the data is the table's, not its number's.
- **A stored map outside the limits** (a plan edited by hand, or saved by
  a later release that relaxed a limit) does not stop the plan from
  opening. That table reads empty `data`; its stored map is kept as read
  (re-encoded) and saved back until you `setTableData` that table.
  Editor code sees it as the table diagnostic `table.invalid_data`; this
  release gives a host no other channel for it.
- **The data is yours to validate.** The planner checks shapes, never
  meaning: a plan saved at one location and loaded at another carries the
  first location's ids. Check an id against your own records before you
  act on it.
- A plan saved by this release is at **schema 9**, data or not
  ([§ 11](#11-what-a-host-must-never-assume)).

**The design's changes.** `controller.designChanges` is a broadcast
stream of `FloorPlanDesignChange`: after every design edit, undo or redo
(in the editor, through `setTableData`, a layer locked, hidden or shown),
the designed tables added, removed and changed since the last report.

```dart
    controller.designChanges.listen(designChanged);
```

```dart
  /// The designed floor changed: keep the POS's list of tables in step.
  void designChanged(FloorPlanDesignChange change) {
    switch (change) {
      case FloorPlanTableAdded(:final table):
        debugPrint('placed: ${table.table.number}');
      case FloorPlanTableRemoved(:final table):
        debugPrint('removed: ${table.table.number} (${table.data['id']})');
      case FloorPlanTableChanged(:final before, :final after):
        if (before.table.number != after.table.number) {
          debugPrint('${before.table.number} is now ${after.table.number}');
        }
      case FloorPlanPlanReplaced():
        hovered.value = null;
        debugPrint('another plan: read controller.tableDetails again');
    }
  }
```

- A table is followed as itself, never by its number: a renumbering is
  one `FloorPlanTableChanged` whose `before` and `after` differ in the
  number; an undone delete is one `FloorPlanTableAdded` equal to the
  `FloorPlanTableRemoved` the delete reported. `before` and `after` can
  differ in the number, the geometry, the layer, the lock, the
  visibility or the data. One edit can report several tables, in the
  order of `controller.tables`: locking a layer reports each table on it.
- `load` and `newPlan()`, in either mode, report what was still owed for
  the plan they replace, then `FloorPlanPlanReplaced` alone, with no
  change per table: read `tableDetails` again. A `load` that throws
  reports nothing.
- Nothing done in the selection mode is reported: a service move changes
  the copy, never the design (`onTablesMoved` and `serviceLayoutChanges`
  report it).
- **Delivery is asynchronous**, never from inside your call to `load`,
  `setTableData` or an undo: the edits made in one synchronous step
  arrive as one report, from the tables before the first edit to the
  tables after the last.
- **Nothing is sent on listen.** Read the starting tables from
  `tableDetails` in the design mode (in the selection mode it reads the
  service copy). A listener added while another listens may first hear an
  edit made just before it listened.
- The tables are compared only while the stream has a listener.
  `dispose()` closes it, so a listener on a controller you dispose needs
  no cancel: nothing reaches it after `dispose()`, not even a change
  reported before it and not yet delivered (a `load` in the same step).

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
- *Unreleased on `main`:* `onTablesMoved(moved)` after a drag of tables,
  `onTableDoubleTap(number)` after a double tap's second `onTableTap`,
  `onFloorTap(world)` for a tap that misses every table, and
  `onTableHover(number)` for the mouse or a stylus over a table: [Events
  and host data](#events-and-host-data).
- *Unreleased on `main`:* the host's own chrome and keys.
  `serviceBar` and `editorBar` cut down, reorder, extend or hide the two
  bars; `onExportDialog` is your export dialog at every Export;
  `onPageFlowError` hears a failed export or print: [The
  bars](#the-bars). `editorCapabilities` says what the editor lets its
  user do, and `tableInspectorBuilder` adds your widget for the one table
  selected: [The editor's capabilities](#the-editors-capabilities).
  `shortcuts: false` gives the keys to you, and `autofocus: false` leaves
  the focus where it is: [Keyboard and focus](#keyboard-and-focus).

On the web the browser opens its own menu on a right click as well,
unless you turn it off, app-wide, before `runApp` (the `main` of
[§ 2](#2-fonts)): `if (kIsWeb) await
BrowserContextMenu.disableContextMenu();`.

### The bars

*Unreleased on `main`.* The selection mode's bar and the editor's top
bar are yours to cut down, reorder, extend or hide, and everything their
buttons read and do is on the controller, for a bar of your own. With
neither argument both bars are today's.

**What a bar takes.** `serviceBar: FloorPlanServiceBar(…)` and
`editorBar: FloorPlanEditorBar(…)`, each read at each build:

- `visible` (true): false removes the bar. The canvas takes its height
  and the plan stays where it is on the screen, from the first frame,
  in both modes; the editor's tools stay in its left panel.
- `actions`: the buttons shown, **in the order given**. The service
  bar's are `FloorPlanServiceAction.undo`, `redo`, `merge`, `split`,
  `export` and `print`; the editor's are `FloorPlanEditorAction.export`,
  `print`, `undo`, `redo`, `snap` (the object snap's read-out, OSNAP)
  and `zoom` (the zoom's read-out). Each enum is declared in today's
  left-to-right order, and the default is all of it. Today's rules hold
  inside the subset: Merge shows only with `onMergeRequested`, Split only
  with `onSplitRequested`, Export only with `onExport`. In the service
  bar, two shown buttons of different groups (Undo and Redo, Merge and
  Split, Export and Print) stand 8 logical pixels apart. In the editor's,
  the buttons lie at the left with 12 pixels between a file button
  (Export, Print) and an edit button (Undo, Redo), the status line keeps
  the middle, and the read-outs lie at the right, 16 pixels apart, in
  the order given. An action listed twice is an `ArgumentError` naming
  `actions` when the view builds.
- `leading`, `trailing`: your widgets before and after the buttons (at
  the bar's two ends, in the editor), laid out in the bar's row at its
  height. Each needs a bounded width; a `Spacer` works.

```dart
  /// The service bar: Undo and Redo, then Print, with the floor's name
  /// before them.
  static const serviceBar = FloorPlanServiceBar(
    actions: [
      FloorPlanServiceAction.undo,
      FloorPlanServiceAction.redo,
      FloorPlanServiceAction.print,
    ],
    leading: [
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Center(child: Text('Floor 1')),
      ),
    ],
  );

  /// The editor's bar: Undo, Redo and the zoom, nothing else.
  static const editorBar = FloorPlanEditorBar(
    actions: [
      FloorPlanEditorAction.undo,
      FloorPlanEditorAction.redo,
      FloorPlanEditorAction.zoom,
    ],
  );
```

**`actions` shapes the bar, never the keys.** A chord stays bound
whatever the bar shows: with Undo hidden, Ctrl+Z still undoes. To unbind
keys, refuse the command in the editor's capabilities, or give the view
`shortcuts: false` ([Keyboard and focus](#keyboard-and-focus)).

**A field of yours in a bar** takes the focus and its keystrokes, but
for the file chords. In the service bar, Undo and Redo (Ctrl+Z, Ctrl+Y,
Ctrl+Shift+Z and their Cmd forms) stay in the field, but Export's Ctrl+E
and Print's Ctrl+P (and Cmd+E, Cmd+P) still reach the plan. In the
editor's bar, the tool letters, Undo, Redo and Escape stay in the field;
the file chords and F3 still act on the plan.

**A bar of your own.** Hide the planner's bar
(`FloorPlanServiceBar(visible: false)`, as the view in
[§ 4](#4-the-controller-and-the-view) does under `ownBar`) and build
yours from the controller:

- `canUndo` and `canRedo` (`ValueListenable<bool>`), `undo()` and
  `redo()`. In the design mode `undo()` and `redo()` do nothing while
  the editor's tool is part-way through a shape (a wall with its first
  point placed), as the editor's own Undo does. `canUndo` and `canRedo`
  keep reading the history, so your button may be enabled then, and a
  press does nothing.
- `mergeCandidate` (`ValueListenable<Set<String>?>`): the numbers the
  planner's Merge would send: in the selection mode the selected tables
  when they span two or more units (a unit is a group, or a table in no
  group), so one table, two tables sharing a number or exactly one group
  give null; always null in the design mode. It does not depend on
  `onMergeRequested`. Split's candidate is `selectedGroup`.
- `exportPlan(choice, {name})`, a `Future<FloorPlanExport?>`, and
  `printPlan({printer, name})`, a `Future<bool>`: Export and Print
  without any dialog of the planner's; they need no view shown.
  `FloorPlanExportChoice(format:, dpi:)` takes `FloorPlanExportFormat.pdf`
  or `png` and `FloorPlanExportDpi.d96`, `d150` or `d300` (`dpi.value` is
  the number); `FloorPlanExportChoice.initial` is a PDF at 150 dpi, and
  `copyWith` changes one field.
  **One export or print at a time per controller**, the view's bars and
  chords included: while one runs, `exportPlan` answers null and
  `printPlan` false, and so they do for a plan without a page, for a plan
  replaced while the bytes are made (a mode switch, `resetLayout()`,
  `load`) and after `dispose()`. Pending input (a typed value) is settled
  first. **An error completes the `Future`**: await them in a `try`.
  `exportPlan` leaves the dialog's remembered choice as it is, and both
  are allowed under every editor capability.
- In the design mode: `activeTool` and `selectTool` ([The editor's
  capabilities](#the-editors-capabilities)) and `deleteSelection()`
  ([Keyboard and focus](#keyboard-and-focus)).

```dart
  /// The POS's own service bar, shown instead of the planner's: each
  /// button enabled by the controller's state, each press a command.
  Widget posServiceBar() => Row(
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: controller.canUndo,
            builder: (context, can, _) => TextButton(
                onPressed: can ? controller.undo : null,
                child: const Text('Undo')),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: controller.canRedo,
            builder: (context, can, _) => TextButton(
                onPressed: can ? controller.redo : null,
                child: const Text('Redo')),
          ),
          ValueListenableBuilder<Set<String>?>(
            valueListenable: controller.mergeCandidate,
            builder: (context, numbers, _) => TextButton(
                onPressed: numbers == null ? null : () => mergeTables(numbers),
                child: const Text('Merge')),
          ),
          ValueListenableBuilder<String?>(
            valueListenable: controller.selectedGroup,
            builder: (context, group, _) => TextButton(
                onPressed: group == null ? null : () => splitGroup(group),
                child: const Text('Split')),
          ),
          TextButton(onPressed: exportPng, child: const Text('Export')),
          TextButton(onPressed: printFloor, child: const Text('Print')),
        ],
      );
```

```dart
  /// Export and Print without the planner's dialogs.
  Future<void> exportPng() async {
    try {
      final export = await controller.exportPlan(
        const FloorPlanExportChoice(
            format: FloorPlanExportFormat.png, dpi: FloorPlanExportDpi.d150),
        name: 'floor-1',
      );
      if (export != null) saveExport(export);
    } catch (error) {
      showProblem('$error');
    }
  }

  Future<void> printFloor() async {
    try {
      await controller.printPlan(name: 'floor-1');
    } catch (error) {
      showProblem('$error');
    }
  }
```

Show it in the selection mode only; a `ValueListenableBuilder` on the
mode keeps the tree around the view the same shape:

```dart
          ValueListenableBuilder<FloorPlanMode>(
            valueListenable: controller.mode,
            builder: (context, mode, _) =>
                ownBar && mode == FloorPlanMode.selection
                    ? posServiceBar()
                    : const SizedBox.shrink(),
          ),
```

**Your own export dialog.** `onExportDialog(context, initial)` replaces
the planner's Material dialog at **every** Export: both bars, the
editor's file commands, and Cmd+E and Ctrl+E, in both modes. `initial`
is the choice last made in this controller's life (a PDF at 150 dpi at
first); your answer is remembered as the next `initial`, and null
cancels. Print has no dialog of the planner's: it opens the platform's
print dialog, or calls your `printer`. Read at each Export.

```dart
  /// The POS's own export dialog, at every Export of the planner: a PDF,
  /// or a PNG at 300 dpi; null cancels.
  Future<FloorPlanExportChoice?> askExport(
          BuildContext context, FloorPlanExportChoice initial) =>
      showDialog<FloorPlanExportChoice>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Export'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(
                  context, initial.copyWith(format: FloorPlanExportFormat.pdf)),
              child: const Text('PDF'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(
                  context,
                  const FloorPlanExportChoice(
                      format: FloorPlanExportFormat.png,
                      dpi: FloorPlanExportDpi.d300)),
              child: const Text('PNG, 300 dpi'),
            ),
          ],
        ),
      );
```

**Errors.** `onPageFlowError(error)` hears an export or a print the
*view* started that failed, your dialog's own error included, once; the
flow then ends, and Export and Print are enabled again. Without it the
error propagates as it always did, out of a `Future` the press drops: an
uncaught asynchronous error. `exportPlan` and `printPlan` never report
there: their `Future` carries the error.

### The editor's capabilities

*Unreleased on `main`.* `editorCapabilities`, a
`FloorPlanEditorCapabilities`, says what the design mode's editor lets
its user do. The default, `FloorPlanEditorCapabilities.full`, is today's
editor; two profiles cut it down, `tablesOnly` for a user who places and
arranges tables, `readOnly` for one who only looks:

| Field | `full` | `tablesOnly` | `readOnly` |
|---|---|---|---|
| `tools` | all sixteen | `select`, `symbol` | `select` |
| `symbolPalette`, `symbolFilter` | yes, none | yes, the tables (`seats != null`) | no, none |
| `selectionPanel` | yes | yes | yes |
| `layerPanel`, `pagePanel` | yes | no | yes (read only) |
| `editLayers`, `editPage` | yes | no | no |
| `selectTablesOnly` | no | yes | no |
| `move`, `rotate`, `delete`, `renumber` | yes | yes | no |
| `mirror`, `reshape`, `changeLayer` | yes | no | no |
| `undo` | yes | yes | no |
| `export`, `print`, `rulers`, `grid`, `snapping` | yes | yes | yes |

Field by field:

- `tools`, a `Set<FloorPlanTool>`: `select`, `line`, `polyline`,
  `rectangle`, `box`, `wall`, `door`, `window`, `gap`, `room`,
  `separator`, `dimension`, `circle`, `arc`, `text` (the palette's rows,
  in its order) and `symbol` (the placement the Symbols tab arms). It
  must hold `select`: an `ArgumentError` naming `tools` when the view
  builds. A refused tool's row and letter are gone, and the letter
  reaches your own bindings. The Fill row and its F show only while
  Polyline, Rectangle or Circle is allowed; the symbol tool needs
  `symbolPalette` too. A `tools` set given to `copyWith` is copied, and
  the view takes its own copy of each value: changing your set
  afterwards changes nothing until you hand the view a new value.
- `symbolPalette`: the Symbols tab. `symbolFilter`, a
  `bool Function(FloorPlanSymbol)`: the symbols it offers and searches.
  A `FloorPlanSymbol` carries `key`, `name` (the library's stored English
  name, the same in every UI language; the palette shows the UI's
  words), `category`, `tags` and `seats` (null for what is not a table).
  The filter is compared by `==`: a static function or a method
  tear-off is equal to itself, while a closure written in `build` is a
  new value at each build, which re-applies the capabilities (cheaply).
  A filter that offers nothing leaves the gallery empty.
- `selectionPanel`, `layerPanel`, `pagePanel`: the right column's
  panels. A hidden panel keeps its state; with all three hidden there is
  no column (and their state is not kept). `editLayers`, `editPage`:
  refused, the Layer and Page panels' controls are disabled and their
  values shown.
- `selectTablesOnly`: a click and a rubber band select tables only. A
  click picks a table by its top, else its box (a mouse within a few
  pixels of it, a finger within its reach), never one on a hidden or
  locked layer; a table inside a group is no table here. Turned on at
  run time, it keeps only the tables of the selection; turned on or off,
  it cancels a click, drag or band the user has under way.
- `move`, `rotate`, `mirror`, `reshape`, `delete`, `renumber`,
  `changeLayer`: the selection's edits. A refused button or menu
  (Mirror, ±90, a door's flips, the Size menu, the layer picker) is not
  shown; a refused value field is shown read only. `reshape` covers an
  object's own grips and fields (a box's, a wall's thickness and
  justification, an opening's, a room's name, a dimension's kind) and
  Change size. A drag whose flag is refused before the pointer lifts is
  cancelled at once: it executes nothing, even if the flag is allowed
  again by then. `rotate` and `mirror` also bound the symbol tool: its R
  and M, and the turn and mirror of the next placement.
- `undo`, `export`, `print`: the bar's buttons **and** their chords.
- `rulers`, `grid`, `snapping`: the drafting aids. `snapping: false`
  turns object snap off for the editor's tools and drags and removes F3
  and the OSNAP read-out; the user's own setting comes back with it.
  Grid snap stays the page's setting.

`copyWith` changes some fields of a profile. Its null keeps a field, the
filter included: `copyWith(symbolFilter: null)` keeps the filter, so
start from `full` for none.

```dart
  /// The manager arranges the tables but never turns them, and places the
  /// round ones only.
  static final arrangeTables = FloorPlanEditorCapabilities.tablesOnly.copyWith(
    rotate: false,
    symbolFilter: roundTables,
  );

  /// A static function, so the capabilities stay equal at every build.
  static bool roundTables(FloorPlanSymbol symbol) =>
      symbol.seats != null && symbol.key.contains('.round');
```

**At run time.** Hand the view another value, and it takes effect at
that build:

```dart
          Switch(
              value: editing == arrangeTables,
              onChanged: (v) => setState(() => editing =
                  v ? arrangeTables : FloorPlanEditorCapabilities.full)),
```

A tool the new value refuses falls back to Select, cancelling a shape
it had begun; a hidden panel, the left tab and the symbol search keep
their state. An Export or a Print under way when the new value refuses
it hands nothing over: the dialog's answer, or the bytes, are dropped,
and the answer is not remembered. When the left column would hold the
Select row alone (`readOnly`), it goes, and the canvas starts at the
rulers; the plan stays where it is on the screen. Turning the rulers
off or on at run time cancels a shape part-way drawn (its tool stays
active).

**A tool strip of your own.** `activeTool`, a
`ValueListenable<FloorPlanTool>`, moves with a palette tap, a letter,
Escape, `selectTool`, a fallback and a mode switch; it reads `select` in
the selection mode and while no editor is shown. A change the editor
makes while the view builds (a fallback, a new plan's editor) is
announced after that frame. `selectTool(tool)` activates a tool as a
palette tap does and answers whether it is now active: false in the
selection mode, with no editor shown, and for a refused tool.

```dart
  /// The POS's own tool strip: the tools it offers, the active one marked.
  Widget toolStrip() => ValueListenableBuilder<FloorPlanTool>(
        valueListenable: controller.activeTool,
        builder: (context, active, _) => Row(children: [
          for (final tool in const [FloorPlanTool.select, FloorPlanTool.wall])
            ChoiceChip(
              label: Text(tool.name),
              selected: tool == active,
              onSelected: (_) => controller.selectTool(tool),
            ),
        ]),
      );
```

**The table inspector.** `tableInspectorBuilder(context, table)` puts
your widget in the editor's Selection panel, below the planner's own
fields, while **exactly one numbered table** is selected: the selection
is one object, and it is a table at the plan's root whose number no other
table has. A table whose number another table shares (selected alone or
with it: `setTableData` refuses that number, so renumber it first), a
table with a wall, a table inside a group and an unnumbered table show
none. `table` is the table's
`FloorPlanTableDetail`, its `data` included; null from the builder shows
nothing. It is called when the selection becomes such a table, at each
change of the plan (an edit, an undo: the detail is read afresh) and
each time you rebuild the view, never on pan or zoom. It is the design
mode's only, and absent while the Selection panel is hidden, so a widget
of yours there keeps no state across a hide. A field in it takes its
keystrokes. Link the table to your record there, with `setTableData`:

```dart
  /// The POS's table, linked from the one table selected in the editor.
  Widget? tableInspector(BuildContext context, FloorPlanTableDetail table) {
    final number = table.table.number!;
    return ListTile(
      title: Text('POS table: ${table.data['id'] ?? 'none'}'),
      trailing: TextButton(
        onPressed: () => linkTable(number, 'pos-$number'),
        child: const Text('Link'),
      ),
    );
  }
```

**A side panel of your own** instead: `editorSelectedTables`, a
`ValueListenable<Set<String>>`, holds the numbers selected in the
editor, and is empty in the selection mode.

```dart
          ValueListenableBuilder<Set<String>>(
            valueListenable: controller.editorSelectedTables,
            builder: (context, numbers, _) =>
                Text(numbers.isEmpty ? '' : 'Arranging tables $numbers'),
          ),
```

**Material inside the editor.** The editor's panels, menus and dialogs
are Material widgets and follow the ambient Material `Theme`
([§ 9](#9-themes)'s local `Theme`); there is no way to replace them.
`tablesOnly` hides the menus (the layer picker, the Size menu, the Layer
and Page panels), so under it the Selection panel shows fields and
buttons only.

**Limits.** Undo is the plan's history, not the profile's: after a
switch from `full` to `tablesOnly`, Undo (when `undo` allows it) still
undoes the edits made before the switch, a wall's move included; `load`
the plan to start the history afresh. Hiding all three panels at once
removes the right column, and with it their state (the Layers section's
open state, for one), while hiding one or two keeps it. While a symbol is armed, a refused R (under `rotate: false`)
or M (under `mirror: false`) is any other key and reaches the next
binding: under a value that also allows the Rectangle tool (R) or the
Room tool (M), it switches to that tool, as W switches to Wall. None of
the three profiles allows that. `selectTool(FloorPlanTool.symbol)` only brings back the symbol
last armed from the Symbols tab, while it is still offered: you cannot
choose a symbol through it.

### Keyboard and focus

*Unreleased on `main`.* For a host whose own shortcuts own the keyboard:

- `shortcuts: false` unbinds, in **both** modes, every key the planner
  binds while no gesture runs, so those keys reach your own bindings:
  the selection mode's Undo, Redo, Export and Print chords and its
  Escape (which clears the selection); the editor's command chords, its
  tool letters, F3, F, Escape, and the select tool's Delete, Backspace
  and Escape. A gesture's own keys stay: a drag's Escape and Shift, a
  drawing tool's Escape and Enter while it draws, the symbol tool's R
  and M while a symbol is armed. Read at each build and each key.
- The commands stay callable: `undo()`, `redo()`, `exportPlan`,
  `printPlan`, `selectTool`, and **`deleteSelection()`**, which deletes
  the editor's selection as the select tool's Delete key does, whichever
  tool is active, while it is idle: one undo step,
  a deleted table's data gone with it and back with its undo. Pending
  input is settled first. It answers whether anything was deleted: false
  in the selection mode, with no editor shown, with nothing selected,
  under `delete: false` (`readOnly`), when the plan's own permissions
  refuse every selected object, and while a drag or a shape is part-way.
- `autofocus: false`: the view does not take the focus when it is
  mounted, at start or when it is built afresh (a mode switch,
  `resetLayout()`, `load`). It is read at each mount, so a change takes
  effect at the next one. Flutter's autofocus acts only while nothing in
  the focus scope has the focus, so even with `true` the view never
  takes it from your field; `false` matters when nothing has it, at
  start and after the plan itself had it and was built afresh. A press
  on the canvas asks for the focus either way; a focused Material
  `TextField` keeps it from the canvas on that press unless its
  `onTapOutside` lets go (below).

```dart
  /// The POS's own keys over the plan while it owns the keyboard: its
  /// commands. A key typed into a text field inside the view never gets
  /// here: the view keeps it for the field.
  KeyEventResult posKey(FocusNode node, KeyEvent event) {
    if (!posOwnsKeys || event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.delete) {
      controller.deleteSelection();
    } else if (key == LogicalKeyboardKey.escape) {
      controller.selectTool(FloorPlanTool.select);
    } else if (key == LogicalKeyboardKey.keyZ &&
        HardwareKeyboard.instance.isControlPressed) {
      controller.undo();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }
```

The probe puts `posKey` on a `Focus(canRequestFocus: false, skipTraversal:
true, onKeyEvent: posKey, …)` around its screen's body, so the keys reach
it from the plan and from the screen's own buttons.

**A field inside the view keeps its keys.** A key typed into a text
field inside the view is the field's, in both modes and whatever
`shortcuts` says: a panel's field (a table number, a page scale), the
Symbols search, a layer's rename, the TEXT entry, and a field of yours
in a bar or in the inspector. Backspace, Delete, Enter, Space and every
key that types a character never reach your bindings above the view,
and the text-editing keys (the arrows, select all, copy, paste) work as
Flutter's defaults do. With the focus anywhere else in the view, your
bindings get the keys as before, so `posKey` needs no guard for the
planner's fields.

**A field of yours outside the view** under your own bindings is yours
to guard: skip your keys while it has the focus (for one,
`FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<EditableText>() != null`),
or your Backspace deletes tables while staff type there.

**A field of yours beside the plan.** A Material `TextField` loses the
focus on a mouse press outside it (on a desktop and on the web), after
the canvas has asked for it: one press on the plan right after typing
leaves the focus with neither, and the planner's keys reach nothing
until the next press. A press on one of your buttons unfocuses the field
too. Give the field `onTapOutside: (_) {}` to keep the focus there until
the plan or another field takes it.

## 9. Themes

The planner follows your `MaterialApp`'s theme. In a dark theme a light
page is shown on a dark canvas with its drawing re-toned to keep its
contrast; exports and prints are never re-toned.

*Unreleased on `main`:* the floor plan's own look, `FloorPlanTheme`.

**What it sets.** A `ThemeExtension` with sixteen optional fields; a
field you leave null is what the planner draws without a theme, so
`const FloorPlanTheme()` changes nothing. Widths, sizes, radii and
padding are logical pixels on the screen; the margin is millimetres of
the plan.

| Fields | What they reach | Null is |
|---|---|---|
| `statusCaptionStyle` | the status captions, selection mode | 11 px, the platform's default font, black or white ink |
| `statusFillOpacity` | multiplies a status colour's alpha, once, selection mode | the colour as you gave it |
| `groupFrameColor`, `groupFrameWidth`, `groupFrameMargin` | the group frames, selection mode | the paper's grip colour (a violet), 2 px, 150 mm |
| `groupChipColor`, `groupChipTextStyle`, `groupChipRadius`, `groupChipPadding` | the group label chips, selection mode | the frame's colour, the caption's defaults, 4 px, 5 px left and right and 2 px top and bottom |
| `selectionOnLight`, `selectionOnDark`, `selectionWidth` | the selection, **both modes** | the planner's blue for that paper, 2 px |
| `focusVeilColor`, `focusVeilOpacity` | the veil over the tables outside the focus, selection mode | the paper's colour, 0.6 |
| `canvasBackground` | the canvas around the page **and** a page-less plan's paper, **both modes** | your `ColorScheme.surface` |
| `serviceBarHeight` | the selection mode's bar | 44 px |

**Where it goes.** One `FloorPlanTheme` in each of your `ThemeData`s, a
light and a dark one, so the system's mode picks the right one:

```dart
/// The floor plan's look in the POS's light theme: bold captions in the
/// planner's own Roboto, fills a little lighter, group frames in the
/// POS's primary (the chips follow the frame), rounder chips, the POS's
/// muted colour around the page, a taller service bar and the POS's
/// accent for the selection, per paper.
const FloorPlanTheme floorLookLight = FloorPlanTheme(
  statusCaptionStyle: TextStyle(
      fontFamily: 'Roboto', fontSize: 12, fontWeight: FontWeight.bold),
  statusFillOpacity: 0.8,
  groupFrameColor: Color(0xFF18181B),
  groupChipTextStyle: TextStyle(fontFamily: 'Roboto'),
  groupChipRadius: 6,
  selectionOnLight: Color(0xFFEA580C),
  selectionOnDark: Color(0xFFFB923C),
  canvasBackground: Color(0xFFF4F4F5),
  serviceBarHeight: 52,
);

/// The same in the POS's dark theme: its dark primary and muted colours.
/// The selection colours stay: they are chosen by the paper, not by the
/// theme.
const FloorPlanTheme floorLookDark = FloorPlanTheme(
  statusCaptionStyle: TextStyle(
      fontFamily: 'Roboto', fontSize: 12, fontWeight: FontWeight.bold),
  statusFillOpacity: 0.8,
  groupFrameColor: Color(0xFFFAFAFA),
  groupChipTextStyle: TextStyle(fontFamily: 'Roboto'),
  groupChipRadius: 6,
  selectionOnLight: Color(0xFFEA580C),
  selectionOnDark: Color(0xFFFB923C),
  canvasBackground: Color(0xFF27272A),
  serviceBarHeight: 52,
);

final ThemeData posLightTheme = ThemeData(
  colorSchemeSeed: Colors.teal,
  extensions: const [floorLookLight],
);

final ThemeData posDarkTheme = ThemeData(
  colorSchemeSeed: Colors.teal,
  brightness: Brightness.dark,
  extensions: const [floorLookDark],
);
```

and both in your `MaterialApp`, as in [§ 3](#3-languages):

```dart
      theme: posLightTheme,
      darkTheme: posDarkTheme,
```

**One view's own look.** `FloorPlanView(theme: …)` sets fields for that
view over the extension it finds in the `Theme` where it is, **field by
field**: the extension first, the view's set fields over it, today's
values for the rest. The two text styles merge property by property
(`TextStyle.merge`): a view style that sets only `fontWeight` keeps the
extension's `fontSize`. With `theme: null` the view takes the extension
alone. In [§ 4](#4-the-controller-and-the-view) the view adds a 3 px
selection to whatever the app theme says:

```dart
              theme: const FloorPlanTheme(selectionWidth: 3),
```

The resolved look is compared by value (`==`) when the view builds: a
rebuild of yours with an equal theme, `const` or not, rebuilds none of
the planner's painters.

**The rest of the chrome.** The service bar, the editor's panels and
toolbars, their text and borders, and the Export dialog read the
ambient Material `ColorScheme`, as any Material widget does. A seeded
scheme (`colorSchemeSeed`, `ColorScheme.fromSeed`) cannot reproduce
another design system's tokens, so if your POS's own UI is not Material
(shadcn, say), wrap the view in a local `Theme` with a `ColorScheme`
built by hand from your tokens:

```dart
/// The POS's own colour tokens as a Material colour scheme, by hand: a
/// seeded scheme cannot reproduce another design system's colours.
ColorScheme posColorScheme(Brightness brightness) =>
    brightness == Brightness.light
        ? const ColorScheme(
            brightness: Brightness.light,
            primary: Color(0xFF18181B),
            onPrimary: Color(0xFFFAFAFA),
            secondary: Color(0xFFF4F4F5),
            onSecondary: Color(0xFF18181B),
            error: Color(0xFFEF4444),
            onError: Color(0xFFFAFAFA),
            surface: Color(0xFFFFFFFF),
            onSurface: Color(0xFF09090B),
            onSurfaceVariant: Color(0xFF71717A),
            surfaceContainer: Color(0xFFF4F4F5),
            outline: Color(0xFFE4E4E7),
          )
        : const ColorScheme(
            brightness: Brightness.dark,
            primary: Color(0xFFFAFAFA),
            onPrimary: Color(0xFF18181B),
            secondary: Color(0xFF27272A),
            onSecondary: Color(0xFFFAFAFA),
            error: Color(0xFF7F1D1D),
            onError: Color(0xFFFAFAFA),
            surface: Color(0xFF09090B),
            onSurface: Color(0xFFFAFAFA),
            onSurfaceVariant: Color(0xFFA1A1AA),
            surfaceContainer: Color(0xFF18181B),
            outline: Color(0xFF27272A),
          );

/// The theme around the floor plan: the POS's colour scheme, for the
/// planner's bars, panels and dialogs, and the app theme's extensions
/// carried over, or the view would find no `FloorPlanTheme`.
ThemeData floorTheme(ThemeData app) => ThemeData(
      colorScheme: posColorScheme(app.brightness),
      extensions: app.extensions.values,
    );
```

```dart
          Expanded(
            child: Theme(
              data: floorTheme(Theme.of(context)),
              child: FloorPlanView(
```

(The colours above are shadcn's published zinc tokens, an example: take
your own design system's.)

- A local `Theme` **replaces** the whole `ThemeData` below it: carry
  your extensions into it, as `floorTheme` does, or put the
  `FloorPlanTheme` in it yourself; otherwise the view finds none.
- **The Export dialog follows the local `Theme`** (a dialog takes the
  themes where it was opened), but **never the view's `theme:`**, which
  reaches that view only. It draws none of the floor plan's look anyway:
  exports and prints have a white page and the plan's own colours.
- The screen that builds the local `Theme` from `Theme.of(context)`
  rebuilds when the app's theme changes, and the view with it: your
  overlay builder then runs again for every table ([Your own widgets on
  the tables](#your-own-widgets-on-the-tables)). A theme switch is rare;
  pan and zoom are unaffected.

**Light and dark.** Put one `FloorPlanTheme` in each `ThemeData`. The
selection colours are chosen **by the paper**, as the planner chooses
its own: `selectionOnLight` on a light page or a light page-less canvas,
`selectionOnDark` on a dark one, whatever the theme. A light page in a
dark theme is shown on the dark canvas (above), so it takes
`selectionOnDark`. **`canvasBackground` does not decide the dark canvas:
your theme's brightness does.** A light `canvasBackground` in a dark
theme puts that dark-canvas sheet on a light surround; a page-less plan
in it is drawn on your light colour, with dark ink.

**What each field does, exactly.**

- **Captions and chip text.** A style's null `color` keeps the automatic
  ink: black or white, whichever reads on the status colour **as drawn**
  (its opacity applied) over the paper; a chip's text, on the chip's
  colour as drawn over the paper (a translucent chip colour is not read
  as opaque). A null `fontSize` is 11 px. A caption sits under the
  table's number, at least its own font size below the number's middle,
  the resolved size. A chip's box is centred on its frame: an uneven
  `groupChipPadding` moves the label inside the box, not the box. A
  caption wider than its table on the screen, or a chip wider than its
  frame, is not drawn, as before.
- **Fonts.** Without a theme the captions and chips are drawn in the
  platform's default font, not in the plans' Roboto: that is today's
  look, and a theme leaves it so. For the same captions on every
  terminal, set `fontFamily: 'Roboto'` in both styles, as above:
  `ensureFloorPlanFonts` ([§ 2](#2-fonts)) registers it, and on the web
  your pubspec's `fonts` entry declares it. Only the regular face ships;
  a bold style is drawn emboldened from it. A family you have not loaded
  falls back to the platform's font.
- **Defaults that follow another field.** A null `groupChipColor` is the
  frame's colour as resolved: set only `groupFrameColor` and the chips
  match it. With the focus on, a group none of whose tables is in it is
  faded: its frame in the frame's colour at its alpha × (1 − the veil's
  opacity), its chip under the veil's colour and opacity, one veil for
  tables and groups.
- **The veil.** `focusVeilColor`'s own alpha is **multiplied** by
  `focusVeilOpacity` (as `statusFillOpacity` multiplies a status
  colour's); with no colour the veil is the paper's colour at that
  opacity. Over the paper itself a paper-coloured veil does not show:
  it fades what is drawn. A veil of another colour shows as a tinted
  box over each faded table.
- **The selection's width** reaches the selection's outline, a selected
  point's cross (its stroke and its length) and the move preview's
  cross. The hover stays 1.5 px; its colour is the selection's at 60 %
  of its alpha. The grips, the preview and the snap marks keep the
  paper's colours.
- **The bar.** `serviceBarHeight` sets the bar; the plan's canvas starts
  under it. Changed while a plan is shown, the canvas moves and the plan
  with it, as on any change of your layout; a mode switch afterwards
  keeps the plan where it is on the screen, as always.
- **The canvas.** `canvasBackground` is the colour around the page and
  the paper of a plan with no page: the drawing's ink, the selection's
  colour set and the veil follow it as they follow a page. A translucent
  colour is used as given; the ink is chosen on its RGB.
- **Out of range.** The constructor is `const` and never throws. The
  view checks the resolved look when it builds and throws an
  `ArgumentError` naming the field: the two opacities must be in
  [0, 1]; `selectionWidth`, `groupFrameWidth` and `serviceBarHeight`
  finite and above 0; `groupFrameMargin`, `groupChipRadius` and each
  side of `groupChipPadding` finite and not negative; a style's
  `fontSize`, when set, finite and above 0.
- **An animated switch.** `MaterialApp` animates a theme change (200 ms
  by default), and the look follows frame by frame: colours, numbers,
  padding and text styles interpolate, each number kept between its two
  ends whatever the curve; a field set on one side only, or a style
  whose `color` is set on one side only, switches at the halfway point.
  An extension only the new theme has applies one frame later, from the
  switch's second frame (its first frame is t = 0, still the old theme);
  one only the old theme has stays until the switch ends. While the look
  changes, the selection mode's painters rebuild at most once per frame
  of the switch, and never for a pan or a zoom.
- **Never stored.** The look is never saved with the plan or the service
  layout, never exported and never printed.

## 10. Touch

Both modes work on a touch screen. Two fingers pinch about their
midpoint and pan together; once two fingers are down nothing reaches a
tool until every finger lifts, and a second finger during a table drag
cancels the drag. A finger's picks and grips are finger-sized. In the
selection mode a tap selects, a drag from a table moves it (or pans,
under `serviceMoves: false`), and a long press does what `longPress`
says, about 500 ms from contact. Mouse, trackpad and stylus behave as on
a desktop.

## 11. What a host must never assume

- **Handles.** A table's identity is its number. The plan's internal
  handles are not API.
- **Capabilities are not a security boundary** *(unreleased on
  `main`)*. `editorCapabilities` decides what the editor offers its
  user, nothing more: your own calls (`setTableData`, `undo()`, `load`,
  `exportPlan`, `printPlan`) stay allowed under every value, and the
  value is never stored with the plan. Decide who may change a floor in
  your own application, and check it where the plan is stored.
- **With `shortcuts: false` nothing deletes in the editor** *(unreleased
  on `main`)* but your own call: the Delete and Backspace keys are
  unbound and the planner has no Delete button, so bind a key or a
  button of yours to `deleteSelection()`.
- **The service layout's text.** It names tables by internal handles
  and belongs to the one plan it was saved from: store it as it is,
  never parse, edit or move it to another plan.
- **The service copy's undo.** Undo in the selection mode undoes service
  moves only; it never reaches a design edit, and a restored layout is
  not a step.
- **A stored name's language.** A placed symbol keeps the library's
  English name in the plan; the planner shows it in the UI's language.
  Room and layer names are stored in the language they were created in.
- **The plan's text separator** *(since 0.2.0)*. It belongs to
  the plan, not to the terminal: a plan you load keeps its own, whatever
  the language. An empty plan a controller creates takes the language of
  the first `FloorPlanView` that shows it; until then, and with no view,
  it is `.`. `newPlan()` takes the language a view of that controller
  last showed, which may be stale if the language changed while none was
  mounted. In 0.1.0 dimensions and areas always print with `.`.
- **Schema 8** *(since 0.2.0)*. A plan saved by 0.2.0 or later is
  at schema 8, which 0.1.0 refuses (`load` throws a `FormatException`
  that says why); a 0.1.0 plan opens here unchanged. Terminals that
  share stored plans leave 0.1.0 together. 0.2.0 and 0.3.0 save the same
  plans and service layouts, so they can share them.
- **Schema 9** *(unreleased on `main`)*. **A plan saved by this release
  is at schema 9, with or without table data, and 0.3.0 and every
  earlier release refuse it** (`load` throws a `FormatException` that
  says why). **Every terminal that shares stored plans moves to it
  together.** A schema 8 or 7 plan opens here unchanged; the service
  layout's format is unchanged.
