# Embedding the floor planner in a POS — host guide

This guide is for a Flutter point-of-sale application (a **host**) that
embeds the floor planner: staff design the restaurant's floors in the
**design** mode, and during service they see the tables, colour them by
status and pick them in the **selection** mode. It covers release
**0.2.0** ([CHANGELOG](../CHANGELOG.md)).

Every Dart snippet below is taken from
[`tool/ci/host_probe/lib/main.dart`](../tool/ci/host_probe/lib/main.dart),
a small host that CI builds from outside the repository on every push.
`tool/ci/check_guide.dart` fails CI when a snippet here is no longer in
that file, so the code in this guide compiles against the release.

## 1. The dependency

The packages are not on pub.dev. Depend on them by git, **both pinned to
the same commit SHA** — the SHA the release tag `v0.2.0` points at,
`7355c001f585910a1c61a76db11203f6d451bfc4` (the merge of release 0.2.0 into
`main`):

```yaml
dependencies:
  flutter:
    sdk: flutter
  jet_cad_floor_plan:
    git:
      url: https://github.com/a-urel/jet-cad.git
      path: packages/jet_cad_floor_plan
      ref: 7355c001f585910a1c61a76db11203f6d451bfc4
  jet_cad_restaurant_symbols:
    git:
      url: https://github.com/a-urel/jet-cad.git
      path: packages/jet_cad_restaurant_symbols
      ref: 7355c001f585910a1c61a76db11203f6d451bfc4
```

Why a SHA and not the tag: the restaurant package depends on the planner
by a path inside the repository, which pub resolves at the commit's SHA.
If your `ref` is a tag or a branch, pub sees two different refs for the
planner and refuses. The other form that resolves is the restaurant
package **alone** at the tag (`ref: v0.2.0`), the planner arriving
through it; you then import the planner without listing it, which
`depend_on_referenced_packages` will flag.

The engine (`jet_cad_2d`) and the renderer (`jet_cad_2d_flutter`) come
with the planner. Import only the two barrels:
`package:jet_cad_floor_plan/jet_cad_floor_plan.dart` and
`package:jet_cad_restaurant_symbols/jet_cad_restaurant_symbols.dart`.
Anything under `src/` is not API.

The packages need Flutter 3.44 or later (the Dart that comes with it);
0.2.0 was built and tested with Flutter 3.47.6. They bring no build hook
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
            ),
```

(`onLayoutChanged`, one call per service drag, still exists; for saving,
`serviceLayoutChanges` in [§ 6](#6-the-service-layout) replaces it.)

The mode is the controller's: `controller.setMode(FloorPlanMode.design)`
or `FloorPlanMode.selection`, read back from `controller.mode`. A switch
keeps the plan where it is on the screen, zoom included (*since 0.2.0*;
0.1.0 kept the camera's numbers, so the plan moved by the editor's
panels); `fitToView()`, `load` and `newPlan()` fit it again, and
`fitToTables` frames a set of tables (*unreleased on `main`*, see
[Zones](#zones-framing-and-focus)). The
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

*Unreleased on `main`.* A zone (Salon, Teras, Bar…) is **yours**: the
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
- **Schema 8** *(since 0.2.0)*. A plan saved by 0.2.0 is
  at schema 8, which 0.1.0 refuses (`load` throws a `FormatException`
  that says why); a 0.1.0 plan opens here unchanged. Move every terminal
  that shares stored plans to the same commit together.
