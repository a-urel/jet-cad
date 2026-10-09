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
    super.dispose();
  }
```

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
            ),
```

(`onLayoutChanged`, one call per service drag, still exists; for saving,
`serviceLayoutChanges` in [§ 6](#6-the-service-layout) replaces it. The
last two arguments draw your own widget on each table, *unreleased on
`main`*: [Your own widgets on the
tables](#your-own-widgets-on-the-tables).)

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
- `data`: empty in this release.

A table on a hidden layer, or one whose corners are not finite (a
hand-edited file), is listed with `center` and `size` null and no
corners. The list is cached and unmodifiable: read it in `build` as
often as you like, and again when `controller.revision` moves.

**The camera.** `controller.camera` is a `ValueListenable` of
`FloorPlanCamera`, a new value at every pan, zoom and fit, by the user
or by you: `scale` in logical pixels per millimetre, `worldToCanvas`,
`canvasToWorld`, and `visibleWorld(size)`, the world a canvas of that
size shows. The **canvas** is the view's drawing area, in logical
pixels, origin at its top left, y down: below the service bar in the
selection mode, inside the rulers in the design mode. The camera
notifies on every frame of a pan, so a widget that listens to it is
rebuilt at that rate; keep such a widget small, like this read-out:

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

## 9. Themes

The planner follows your `MaterialApp`'s theme. In a dark theme a light
page is shown on a dark canvas with its drawing re-toned to keep its
contrast; exports and prints are never re-toned.

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
