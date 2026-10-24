# Embedding the floor planner in a POS: host guide

This guide is for a Flutter point-of-sale application (a **host**) that
embeds the plan library: staff design the restaurant's floors in the
**design** mode, and during **service** they see the tables, colour them by
status, group them and pick them. It covers `jet_cad_2d_plan` **1.0.0**
([CHANGELOG](../packages/jet_cad_2d_plan/CHANGELOG.md)), with the kits
`jet_cad_2d_kit_restaurant` **0.1.1** and `jet_cad_2d_kit_architecture`
**0.1.2**.

The plan library is the editor and the views. What a plan can hold (walls,
doors, tables, chairs) comes from **kits** the host lists when it makes a
controller. The restaurant kit brings 69 restaurant symbols, the servable
ones as *units*: a unit is a placed symbol the service mode can number,
colour, group and pick. The old `jet_cad_floor_plan` is covered at the end,
in [From `jet_cad_floor_plan`](#12-from-jet_cad_floor_plan).

Every Dart snippet below is taken from
[`tool/ci/host_probe/lib/main.dart`](../tool/ci/host_probe/lib/main.dart),
a small host that CI builds from outside the repository on every push.
`tool/ci/check_guide.dart` fails CI when a snippet here is no longer in that
file, so the code in this guide compiles against the release.
[`apps/restaurant_demo`](../apps/restaurant_demo) is a larger host built the
same way, with every feature of this guide in use; both example apps, it and
[`apps/architecture_demo`](../apps/architecture_demo), root in a plain
`ShadApp` (zinc, Roboto).

The sections run in the order a POS needs them: [1](#1-the-dependency)
the dependency, [2](#2-fonts) fonts, [3](#3-languages) languages,
[4](#4-the-controller-and-the-views) the controller and the views,
[5](#5-storing-the-plan) storing the plan, [6](#6-the-pos-tables-statuses-groups-and-the-layout)
**the POS: tables, statuses, groups and the layout**, [7](#7-permissions)
permissions, [8](#8-a-host-kit-your-own-symbols) your own symbols,
[9](#9-two-views-of-one-floor) two views, [10](#10-themes-and-your-own-widgets)
themes, [11](#11-touch), [12](#12-from-jet_cad_floor_plan) the move from the
old planner, [13](#13-what-a-host-must-never-assume) what a host must
never assume, and [14](#14-phones-and-tablets) phones and tablets. Inside the
POS section, [6.10](#610-linking-any-object) links any object,
[6.11](#611-sections) reads sections and [6.12](#612-the-inspector) builds
the inspectors. [10.1](#101-alignment-guides) covers
alignment guides.

## 1. The dependency

Add the plan library and the kits you load from pub.dev, with `dart pub add`
or in your pubspec:

```yaml
dependencies:
  flutter:
    sdk: flutter
  jet_cad_2d_kit: ^0.1.1
  jet_cad_2d_kit_architecture: ^0.1.2
  jet_cad_2d_kit_restaurant: ^0.1.1
  jet_cad_2d_plan: ^1.0.0
```

- `jet_cad_2d_plan` is the controller, the views and the editor.
  The engine (`jet_cad_2d`) and the renderer (`jet_cad_2d_flutter`) come with
  it.
- `jet_cad_2d_kit_restaurant` is the restaurant: tables, booths, bar, service
  and kitchen symbols, with their seats. Its symbol library is a Flutter asset
  *of the package*: there is nothing to copy into your app, and nothing to
  declare in your pubspec.
- `jet_cad_2d_kit_architecture` is walls, doors, windows, rooms, dimensions
  and a furniture library. A floor with no walls does not need it.
- `jet_cad_2d_kit` is the kit contract. You depend on it directly only to
  write a kit of your own ([section 8](#8-a-host-kit-your-own-symbols)); the
  snippets below import `KitNames`, `PlanKit`, `SymbolLibrarySource` and
  `bundledLibrary` from it.

Import only the packages' barrels, `package:jet_cad_2d_plan/jet_cad_2d_plan.dart`
and the kits' own. Anything under `src/` is not API.

The packages need Flutter 3.44 or later (the Dart that comes with it);
1.0.0 is built and tested with Flutter 3.47.6. The planner's chrome is
`shadcn_ui` (`^0.57.1`), and that package needs Dart 3.11: the plan library's
own SDK floor is unchanged, but a host that depends on it needs Dart 3.11
through `shadcn_ui`. A host that already uses `shadcn_ui` moves to `^0.57.1`
(the planner and the host share one copy). There is no GPU renderer, and
the one build hook the packages bring is `objective_c`'s native-assets hook,
which `shadcn_ui` pulls in (through `universal_image`, `extended_image_library`
and `path_provider_foundation`) for Apple platforms; no hook of the packages'
own runs at build time.

The imports the snippets below need:

```dart
import 'dart:async' show StreamSubscription;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show BrowserContextMenu;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart'
    show KitNames, PlanKit, SymbolLibrarySource, bundledLibrary;
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_kit_restaurant/jet_cad_2d_kit_restaurant.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
```

## 2. Fonts

Plans name the family `Roboto`, and the plan library ships its bytes. Declare
the family in your pubspec, so the web never fetches Google's Roboto instead:

```yaml
flutter:
  uses-material-design: true
  fonts:
    - family: Roboto
      fonts:
        - asset: packages/jet_cad_2d_plan/fonts/Roboto-Regular.ttf
```

Then register it before `runApp`, with its licence:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await ensurePlanFonts();
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

`ensurePlanFonts` registers once per process; a later call returns the first
one's future, or tries again if it failed. It throws when the font asset
cannot be read; catch it, or the app never starts. The `BrowserContextMenu`
line keeps the browser's own menu from covering the table menu you open on a
right click ([section 6.9](#69-callbacks-and-your-own-chrome)).

## 3. Languages

English, German and Turkish are built in. List them and the library's
delegates in your `MaterialApp`:

```dart
class _PosAppState extends State<PosApp> {
  Locale? _locale;

  @override
  Widget build(BuildContext context) => MaterialApp(
        theme: posLightTheme,
        locale: _locale,
        supportedLocales: planSupportedLocales,
        localizationsDelegates: planLocalizationsDelegates,
        home: FloorScreen(
            store: widget.store,
            onLocale: (locale) => setState(() => _locale = locale)),
      );
}
```

- The library follows the **resolved** locale: `locale` if you set it,
  otherwise the system's, matched against `supportedLocales`. A locale you do
  not list resolves to one you do; one the library does not know gives
  English.
- `planLocalizationsDelegates` holds the library's delegate and Flutter's
  Material, Widgets and Cupertino ones. If you list `de` or `tr` without
  Flutter's delegates, Material widgets throw.
- To switch language at run time, change `MaterialApp.locale`: the planner's
  notices and panels are worded again in the same frame. `Localizations.override`
  around the view alone is **not supported**: the Export dialog opens on the
  root navigator and would not see it.
- Your own words: `PlanStrings.of(context)` gives the library's language.
  To change only some words, subclass `PlanStringsEn`, `PlanStringsDe` or
  `PlanStringsTr`.
- The names of symbols come from the kits, in each kit's languages. A word of
  yours (a name in a language the kit has none for, or a name of your own for
  a symbol) goes in `PlanController(words:)`, a `KitNames` the controller reads
  before each kit's own, per locale:

```dart
/// The planner's words for a symbol, in a language the kit has none for.
const KitNames posWords = KitNames({
  'de': {'symbol:restaurant.table.round.four': 'Runder Vierertisch'},
});
```

  A word id names a kit (`symbol:<key>`, `category:<kit>/<name>`, ...); the
  controller throws an `ArgumentError` for an id in no known namespace or one
  that names no kit. `docs/kits.md` section 5 lists the ids.
- Panel numbers show and read with the language's decimal separator, per
  language, not per region: `de_CH` gets German's `,`. The plan's own text
  (dimensions and room areas, on screen and on the PDF and PNG) uses the
  separator **the plan** carries (the Page panel's *Decimal separator*), the
  same on every terminal; a new plan takes the UI language's.

## 4. The controller and the views

One `PlanController` holds one plan and everything over it: the document, the
selection, undo, the camera, the mode, the units and the service state. It
needs the kits the plan uses; list them in the order you want the gallery to
show them:

```dart
/// The kits the POS loads: walls and doors, then the restaurant's tables. The
/// order is the gallery's.
final List<PlanKit> posKits = [architectureKit, restaurantKit];
```

The controller does not store anything and does not dispose itself: make it
once per floor, keep it for the screen's lifetime and call `dispose()` when
the floor goes. A restaurant with two dining areas has two controllers; a
status, a selection or an undo in one never reaches the other.

```dart
/// One dining area: its plan, and what the POS keeps beside it.
class PosFloor {
  PosFloor(this.name, {String? json})
      : controller = PlanController(
            kits: posKits, json: json, words: posWords, permissions: waiter);

  final String name;
  final PlanController controller;

  /// The POS's state of each table, by the POS's own table id.
  final Map<String, PosStatus> statuses = {};

  /// The POS's groups: a group's id, the POS ids of its tables.
  final Map<String, Set<String>> groups = {};

  /// The POS's state of each group, by its id.
  final Map<String, PosStatus> groupStatuses = {};

  /// The service layout last seen (`serviceJson()`), kept for the next time
  /// the service is entered.
  String? layout;
}
```

`PlanController({required kits, json, symbols, thumbnails, exporters,
importers, minScale, maxScale, permissions, words, build})` throws, before it
builds anything, a `KitSetError` for kits that do not fit together, an
`ArgumentError` for bad scales or words, and a `PlanFormatException` when
`json` is not a plan. Its symbol libraries start loading at once and never
block an edit; `symbolsState` says where they are, and a failed load is
retried with `retrySymbols()`:

```dart
/// The symbol libraries' state: they load in the background and never block
/// an edit.
Widget symbolsNotice(PlanController c) => ValueListenableBuilder<SymbolsState>(
      valueListenable: c.symbolsState,
      builder: (context, state, _) => switch (state) {
        SymbolsState.loading => const Text('Loading symbols'),
        SymbolsState.ready => const SizedBox.shrink(),
        SymbolsState.failed => TextButton(
            onPressed: c.retrySymbols, child: const Text('Retry symbols')),
      },
    );
```

`build` fills a new plan in code (a `PlanBuild`); `apps/restaurant_demo/lib/samples`
builds two dining rooms that way.

### The views

There are three widgets over a controller, from the whole editor to the
canvas alone.

- **`PlanEditor`** is the editor: the bar, the tool palette or the symbol
  gallery, the canvas, the property, layer and page panels, and, when the
  controller is in service, the service view in its place. It follows
  `controller.mode`, so the host switches the mode (`setMode`) and the editor
  changes with it. It takes the host's file commands (`onNew`, `onOpen`,
  `onSave`, `onSaveAs`), which the bar's buttons and the chords of
  `kFileChords` run.
- **`PlanServiceView`** is the service mode alone: the service bar over the
  canvas of the service copy. It shows nothing while the controller is in
  design. A waiter's screen is this view with the mode set once:

```dart
/// The waiters' screen: no editor, the plan in service for good.
class ServiceFloor extends StatefulWidget {
  const ServiceFloor({super.key, required this.floor});

  final PosFloor floor;

  @override
  State<ServiceFloor> createState() => _ServiceFloorState();
}

class _ServiceFloorState extends State<ServiceFloor> {
  @override
  void initState() {
    super.initState();
    widget.floor.controller.setMode(PlanMode.service);
  }

  @override
  Widget build(BuildContext context) =>
      PlanServiceView(controller: widget.floor.controller);
}
```

- **`PlanCanvas`** is the design canvas alone, for a layout of your own. The
  tool palette, the symbol gallery and the property, layer and page panels are
  widgets too (`PlanToolPalette`, `PlanSymbolGallery`, `PlanPropertyPanel`,
  `PlanLayerPanel`, `PlanPagePanel`):

```dart
/// An editor of your own: the plan's widgets in a layout of yours.
Widget ownEditor(PlanController c) => Row(children: [
      SizedBox(width: 280, child: PlanSymbolGallery(controller: c)),
      Expanded(child: PlanCanvas(controller: c)),
      SizedBox(width: 300, child: PlanPropertyPanel(controller: c)),
    ]);
```

A controller is shown in **one `PlanCanvas` at a time**: a second one on the
same controller asserts in debug builds. (Two *service* views of one
controller are allowed, [section 9](#9-two-views-of-one-floor).)

The editor is the whole design experience; most hosts mount a `PlanEditor`
for the manager and a `PlanServiceView` for the floor staff. Section 6 shows
the editor with every callback a POS uses.

## 5. Storing the plan

The plan library never stores anything. A plan is one text, and the host
keeps it wherever it keeps its data:

```dart
/// Saves the plan and marks it saved.
Future<void> savePlan(PosStore store, PosFloor floor) async {
  final text = floor.controller.save();
  await store.write('plan.${floor.name}', text);
  floor.controller.markSaved();
}
```

- `save()` returns the plan's text, the design whatever the mode.
  `markSaved()` records that the host stored it: `dirty` is false again until
  the next edit. `dirty` is a microtask late; read it after a frame, not in
  the same statement as the edit.
- `load(text)` replaces the plan, or throws a `PlanFormatException` (a
  `FormatException` with a `code`) and changes nothing. Plans of the old
  planner (`jet_cad_floor_plan`, schema 7 to 10) are **not** read: the plan
  format is 1 (`kPlanFormat`) and there is no converter.
- A plan names the kits it uses and the version that saved it. When it uses a
  kit the controller was not given, `missingKits` lists it; its objects are
  still opened, drawn, locked and saved unchanged. Load with the same kits you
  save with:

```dart
/// Loads the plan last saved; false when there is none or it is not a plan.
Future<bool> revertPlan(PosStore store, PosFloor floor) async {
  final text = await store.read('plan.${floor.name}');
  if (text == null) return false;
  try {
    floor.controller.load(text);
  } on PlanFormatException catch (error) {
    debugPrint('not a plan: ${error.code.name}');
    return false;
  }
  if (floor.controller.missingKits.isNotEmpty) {
    debugPrint('kits the plan uses: ${floor.controller.missingKits}');
  }
  return true;
}
```

- `newPlan({decimalSeparator, build})` replaces the plan with an empty one.
- A host's own calls (`load`, `undo()`, `setUnitData`, `export`) are never
  gated by the controller's `permissions`.

## 6. The POS: tables, statuses, groups and the layout

This section is the one a POS reads first. A POS has its own tables, with its
own ids, and its own state for them: ordered, eating, billed, merged. The
plan draws the floor; the POS keeps the truth, and **pushes** its state to the
plan whenever it changes. The pattern, which the rest of the section builds,
is four steps:

1. a plan table carries the POS's table id as **host data** (6.2);
2. the POS keeps its states by its own ids (statuses, groups) (6.3, 6.5);
3. one function turns those states into the plan's calls, by looking up the
   label each id is linked to, and the POS calls it after *every* change of
   the plan or of its own state (6.3, 6.5, 6.6);
4. the plan's events (a tap, a merge request, a table changed) come back to
   the POS as callbacks and streams (6.7).

### 6.1 What a table is

The plan lists its *units*: `controller.units` (a `PlanUnit` each: `label`,
`kind`, `capacity`, `symbolKey`, `visible`) and `controller.unitDetails` (a
`PlanUnitDetail` each: the unit, its `center`, `size`, `rotation`, `layer`,
whether it is `locked`, the host `data` and the `colour`). A restaurant
table is a unit of kind `table` whose `capacity` is its seats: in the
restaurant kit every seated symbol is a numbered table. A kit may declare
other kinds (a seat generated in a row is of kind `seat`).

A unit's **label** is its identity for the host: the text printed on the
table (one to eight characters), and the key of every host call
(`setUnitStatus`, `select`, `centerOn`, ...). The plan's internal handles are
never API. Two tables may carry one label (the editor warns:
`labelWarnings` lists a `DuplicateLabel`), but a host call that names a label
two units share does nothing and returns false, so keep your labels unique.

### 6.2 Linking a table to the POS: host data

The label is for people; the POS has its own id. Write it on the table as
**host data**, a map of strings stored in the plan, saved and undone with it:

```dart
/// The plan's tables by the POS id they are linked by, as the label the plan
/// knows them by.
Map<String, String> labelsByPosId(PlanController c) => {
      for (final detail in c.unitDetails)
        if (detail.unit.label case final label? when detail.data['id'] != null)
          detail.data['id']!: label,
    };

/// Links the plan's table [label] to the POS's table [posId]. The table's
/// other data is kept. False when no table, or two, carry the label.
bool linkTable(PlanController c, String label, String posId) {
  final tables = [
    for (final detail in c.unitDetails)
      if (detail.unit.label == label) detail,
  ];
  if (tables.length != 1) return false;
  return c.setUnitData(label, {...tables.single.data, 'id': posId});
}

/// The POS's table ids that no table of the plan is linked to.
Set<String> unlinked(PlanController c, Set<String> posIds) =>
    posIds.difference(labelsByPosId(c).keys.toSet());
```

- `setUnitData(label, data)` replaces the unit's data (an empty map removes
  it): one undoable "Unit data" step, saved with the plan. It returns false,
  changing nothing, when the label names no unit or several, or the unit sits
  under a locked object. It throws a `StateError` in service (the design is
  not edited there) and an `ArgumentError` for data over the limits. Merge
  into `detail.data`, as `linkTable` does, so another key of yours survives.
- `setUnitsData({label: data})` links many in one step, all or nothing. A POS
  that links a whole floor, once, in design, does it in one undo step.
- `unlinked` finds the POS tables the floor does not draw: show them to the
  manager as a to-do list.

Because the id travels with the *table*, a relabel, a move or an undo never
breaks the link. That is why the rest of the section keys the POS's state by
POS id, never by label.

### 6.3 Statuses

A status is a fill colour and an optional caption on a table, drawn in
service. `setUnitStatus` replaces **every** status at once, by label; so the
POS keeps its states by id and draws them all:

```dart
/// What the POS knows of a table.
enum PosStatus {
  ordered(Color(0x99FFB300)),
  eating(Color(0x9943A047)),
  bill(Color(0x99E53935));

  const PosStatus(this.color);

  final Color color;
}

/// The status as the plan draws it: a fill, and for the bill a caption (at
/// most 12 characters, plain text the library never re-words).
UnitStatus statusOf(PosStatus status) => UnitStatus(
    color: status.color, caption: status == PosStatus.bill ? 'Bill' : null);
```

```dart
/// Draws the POS's states. The maps are the whole truth: the controller's
/// own are replaced at each call. A group's status fills its tables over
/// their own.
void paintStatuses(PosFloor floor) {
  final c = floor.controller;
  final labels = labelsByPosId(c);
  c.setUnitStatus({
    for (final MapEntry(:key, :value) in floor.statuses.entries)
      if (labels[key] case final label?) label: statusOf(value),
  });
  c.setGroupStatus({
    for (final MapEntry(:key, :value) in floor.groupStatuses.entries)
      if (floor.groups.containsKey(key)) key: statusOf(value),
  });
}
```

- A colour with an alpha is a fill over the table. `PlanTheme.statusFillOpacity`
  multiplies the colour's alpha once; left null, the colour is drawn as you
  gave it.
- A caption is cut to 12 characters (`UnitStatus.maxCaption`). It is plain
  text the library never re-words: when the UI language changes, set the
  statuses again with the new words.
- A status for a label no unit carries is kept and draws nothing, and
  applies again when a unit with that label comes back.
- `setGroupStatus` does the same for groups, by group id; a group's status
  fills every visible member and overrides each member's own while it is set.
- Statuses are drawn in service only. They are not part of the plan: they
  are not saved, not undone and do not make the plan dirty.
- `setUnitFocus(labels)` puts a veil over every table outside `labels` (null
  clears it): zones, "tables of waiter 2". Presentation only.

### 6.4 Selecting and finding

`controller.selectedUnits` is a `ValueListenable<Set<String>>` of labels, in
both modes; `select({labels})` sets it. A table the POS wants to show is
selected with `select` and brought into view with `centerOn`:

```dart
/// Table 7 in the middle of the view, its zoom kept.
void centerOnSeven(PlanController c) {
  for (final detail in c.unitDetails) {
    if (detail.unit.label == '7' && detail.center != null) {
      c.centerOn(detail.center!);
      return;
    }
  }
}
```

`fitToUnits({labels})` frames a set of tables (a zone) and returns false when
none is drawn; `centerOn(world)` keeps the zoom; `fitToView()` frames the
page. `unitAt(canvasPoint)` names the table under a point.

### 6.5 Groups: merge and split

A group is a set of tables served as one party: a frame and a chip on the
plan, selected, moved and coloured together. `setUnitGroups` replaces **all**
groups at once, `{id: UnitGroup(members: {labels}, label: 'Smith')}`. It
throws an `ArgumentError` (and changes nothing) for a blank or repeated id, a
group with no member, or a label in two groups. Groups act in service only.

The plan does not decide what a merge means: the service bar's Merge and
Split buttons (and the chords) ask the host through `onMergeRequested` and
`onSplitRequested`, and the host answers by setting groups. With the POS as
the truth, a merge changes the POS's groups and draws them:

```dart
/// Draws the POS's groups as the plan's, by the label each POS id is linked
/// to. A POS table the plan does not draw is left out; a group left with no
/// table is not drawn.
void paintGroups(PosFloor floor) {
  final labels = labelsByPosId(floor.controller);
  final drawn = <String, UnitGroup>{};
  for (final MapEntry(key: id, value: tables) in floor.groups.entries) {
    final members = {
      for (final table in tables)
        if (labels[table] case final label?) label,
    };
    if (members.isNotEmpty) drawn[id] = UnitGroup(members: members);
  }
  floor.controller.setUnitGroups(drawn);
}

/// A Merge request: the tables the staff selected become a new group
/// `G<n>`, leaving the groups they were in; a group left empty goes.
/// Returns the new group's id, or null when none of the labels is linked to
/// a POS table.
String? mergeTables(PosFloor floor, Set<String> labels) {
  final posIdOf = {
    for (final MapEntry(:key, :value)
        in labelsByPosId(floor.controller).entries)
      value: key,
  };
  final tables = {
    for (final label in labels)
      if (posIdOf[label] case final id?) id,
  };
  if (tables.isEmpty) return null;
  var highest = 0;
  for (final id in floor.groups.keys) {
    if (RegExp(r'^G(\d+)$').firstMatch(id) case final match?) {
      highest = math.max(highest, int.parse(match[1]!));
    }
  }
  final id = 'G${highest + 1}';
  for (final group in floor.groups.values) {
    group.removeAll(tables);
  }
  floor.groups.removeWhere((_, group) => group.isEmpty);
  floor.groupStatuses
      .removeWhere((group, _) => !floor.groups.containsKey(group));
  floor.groups[id] = tables;
  paintGroups(floor);
  paintStatuses(floor);
  return id;
}

/// A Split request: the group goes, and its status with it.
void splitGroup(PosFloor floor, String id) {
  floor.groups.remove(id);
  floor.groupStatuses.remove(id);
  paintGroups(floor);
  paintStatuses(floor);
}
```

- `mergeCandidate` is the label set Merge would send, null when Merge is
  disabled; `selectedGroup` is the id of the group the selection is exactly
  (what Split would split).
- A group's status goes with the group: `splitGroup` drops it, and
  `paintStatuses` ignores a group status whose group is gone.
- A tap on a member selects the whole group, and a drag moves it as one;
  `onGroupTap(id, label)` reports the tap.
- Groups, like statuses, are the host's state in the controller: they are not
  in the plan, not undone, and they **survive** a mode switch, `load` and
  `newPlan`. After a load the controller still holds the groups of the plan
  before it. Draw yours again, as `watchTables` below does on
  `PlanUnitsReplaced`.

### 6.6 Relabelling a table that belongs to a group

> **Warning.** A group lists *labels*, not tables. The plan does **not**
> follow a relabel into a group. Relabel table `2` as `9` while it is in group
> `G1 = {2, 3}` and the group stays `{2, 3}`: it now names a label no table
> carries, so `9` is not in the group and the group has one table, `3`. If the
> host then stores `serviceJson()` and restores it, `restoreService` **drops
> the whole group** (a group applies whole or not at all, and a member naming
> no table drops it) and reports its id in `ServiceRestore.droppedGroups`. A
> group status for it goes unused. The record's move of table `2` drops as
> well (a move applies only to the label it was recorded with). Nothing
> throws: the host only sees the dropped ids in the restore's result.

A relabel reaches the plan from three places: the Properties panel (when
`PlanPermissions.relabel` allows it), your own `setUnitLabel` / `setUnitsLabel`
calls, and an undo or redo of either. All are design-mode edits, so in service
the problem cannot arise; it appears the next time the host draws the groups,
saves the layout or enters service.

Two ways to keep groups right:

**1. Keep the groups in the POS, by POS id (recommended).** `paintGroups`
above looks every id up by the label it is linked to *now*, so redrawing after
a relabel is the whole fix. Redraw when the plan says a label changed, or
that it was replaced:

```dart
/// Hears the plan's tables change. A relabel (by the editor's panel, say)
/// moves a table to a label the plan's groups and statuses do not know, and a
/// load brings other tables: either way the POS draws its own state again.
StreamSubscription<PlanUnitChange> watchTables(PosFloor floor) =>
    floor.controller.unitChanges.listen((change) {
      void draw() {
        paintStatuses(floor);
        paintGroups(floor);
      }

      switch (change) {
        case PlanUnitAdded(:final unit):
          debugPrint('added table ${unit.unit.label}');
        case PlanUnitRemoved(:final unit):
          debugPrint('removed table ${unit.unit.label}');
        case PlanUnitChanged(:final before, :final after):
          if (before.unit.label != after.unit.label) draw();
        case PlanUnitsReplaced():
          draw();
      }
    });
```

`PlanUnitChanged(before, after)` carries both details, so a label change is
`before.unit.label != after.unit.label`. The stream is a microtask late, so
the host redraws a moment after the edit, not within it. `enterService`
below draws the POS's groups again after a restore, so a record that lost a
group costs nothing.

**2. Keep the groups in the plan only.** Then the host must carry the new
label into the groups in the same step as the relabel. `setUnitsLabel` is all
or nothing and lets two tables swap their labels, so one map covers every
case:

```dart
/// Relabels tables of a plan whose groups live in the plan alone: the
/// groups list labels, and the plan does not follow a relabel into them, so
/// each label is put where the old one was. [byLabel] is old label, new
/// label; two tables may swap theirs.
bool relabelTables(PlanController c, Map<String, String> byLabel) {
  if (!c.setUnitsLabel(byLabel)) return false;
  c.setUnitGroups({
    for (final MapEntry(key: id, value: group) in c.unitGroups.value.entries)
      id: UnitGroup(
        members: {for (final label in group.members) byLabel[label] ?? label},
        label: group.label,
      ),
  });
  return true;
}
```

This covers the host's own calls; a relabel by the editor's panel still
needs the stream above. Do not apply the renames to the groups one at a time:
after `1 -> 2` and then `2 -> 1` every member is back where it started.

### 6.7 Events

Everything the staff do reaches the host as a callback of the view, a stream
or a `ValueListenable`. The callbacks are the same on `PlanEditor` and
`PlanServiceView`:

| Event | Where |
|---|---|
| a tap, a double tap, a hover on a table | `onUnitTap(label)`, `onUnitDoubleTap(label)`, `onUnitHover(label)` |
| a right click, or a long press with `longPress: PlanLongPress.contextMenu` | `onUnitContextMenu(label, globalPosition)` |
| a tap on a grouped table | `onGroupTap(groupId, label)` |
| a tap on the floor | `onFloorTap(world)` (world millimetres) |
| Merge, Split | `onMergeRequested(labels)`, `onSplitRequested(groupId)` |
| tables moved in service | `onUnitsMoved(details)` |
| the service layout changed | `onLayoutChanged()` |
| the selection | `controller.selectedUnits`, `selectedGroup`, `mergeCandidate` |
| tables added, changed, removed, plan replaced | `controller.unitChanges` (`PlanUnitAdded`, `PlanUnitChanged`, `PlanUnitRemoved`, `PlanUnitsReplaced`) |
| any object of the plan | `controller.changes` (`PlanChange`: added, changed, removed, replaced; by handle) |
| mode, dirty, undo | `controller.mode`, `dirty`, `canUndo`, `canRedo` |

A double tap fires `onUnitTap` for each tap first: a host that acts on a tap
acts on both taps of a double tap. `PlanUnitsReplaced` means the whole plan
changed (a load, a new plan): read the tables again rather than patching.

### 6.8 Saving and restoring the layout

In service the staff may *move* tables (a party pushes two together). Those
moves, and the groups, are the **service layout**: a record on a copy of the
design, never in the plan. Entering service makes the copy; leaving it
discards the copy with every move. The host decides whether to keep the
layout, and keeps it as text:

- `serviceJson()` is the record (the moves and the groups), null in design.
- `serviceChanges` fires after a move, an undo or a redo, `resetService`,
  `restoreService` and `setUnitGroups` in service. It never fires on
  `setMode`, `load` or `newPlan`, so keeping the text on it can never
  overwrite the record with the empty one a new copy starts with.
- `serviceEdited` says whether the copy differs from the design (a table away
  from its place, groups that differ from those held on entering).
- `restoreService(text)` puts a record back: service only (a `StateError` in
  design), a `FormatException` and no change for text that is not a
  version-1 `jet_cad.service` record (the old planner's layout text is refused
  too). It rebuilds the copy from the design, applies every move that still
  matches, **replaces** the groups with the record's that apply and returns a
  `ServiceRestore`: `appliedMoves` and `droppedMoves` (labels),
  `appliedGroups` and `droppedGroups` (ids). A restore is not an undo step.
- `resetService()` rebuilds the copy from the design: every move gone and the
  groups split.
- Undo in service reaches service moves only, never a design edit.

```dart
/// Keeps the service layout on every change of its record, never on a mode
/// switch or a load.
void keepLayout(PosFloor floor) {
  final c = floor.controller;
  c.serviceChanges.addListener(() {
    if (c.serviceJson() case final json?) floor.layout = json;
  });
}

/// Enters the service and puts the kept layout back: the moves, and the
/// groups the plan still matches. Returns the ids of the groups it dropped,
/// and draws the POS's own groups over the record's.
List<String> enterService(PosFloor floor) {
  final c = floor.controller;
  c.setMode(PlanMode.service);
  var dropped = const <String>[];
  if (floor.layout case final layout?) {
    try {
      dropped = c.restoreService(layout).droppedGroups;
    } on FormatException {
      // Not a service record: an old text is refused, never read.
      floor.layout = null;
    }
  }
  paintGroups(floor);
  paintStatuses(floor);
  return dropped;
}
```

A move applies only while its table is still a placed unit, unlocked and on a
visible layer, with the label it was recorded with and at the place the
record saw; a group applies whole or not at all, and only when every member
names a table of the design. So relabelling a table in the design drops its
move and its group on restore
([6.6](#66-relabelling-a-table-that-belongs-to-a-group)).
`enterService` reports the dropped ids and then draws the POS's own groups
and statuses, which is why POS-held groups survive.

### 6.9 Callbacks and your own chrome

The editor with the callbacks a POS usually sets: its service bar headed by
the floor's name, Save wired to `savePlan`, the buttons of the app bar
switching the mode (Service goes through `enterService`, so the kept layout
comes back) and the language (`MaterialApp.locale`, [section 3](#3-languages)):

```dart
/// One floor, in the design or the service.
class FloorScreen extends StatefulWidget {
  const FloorScreen({super.key, required this.store, this.onLocale});

  final PosStore store;
  final ValueChanged<Locale>? onLocale;

  @override
  State<FloorScreen> createState() => _FloorScreenState();
}

class _FloorScreenState extends State<FloorScreen> {
  final PosFloor floor = PosFloor('Salon');
  late final StreamSubscription<PlanUnitChange> _tables = watchTables(floor);

  @override
  void initState() {
    super.initState();
    keepLayout(floor);
  }

  @override
  void dispose() {
    _tables.cancel();
    floor.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(floor.name), actions: [
          TextButton(
              onPressed: () => floor.controller.setMode(PlanMode.design),
              child: const Text('Design')),
          TextButton(
              onPressed: () => enterService(floor),
              child: const Text('Service')),
          for (final locale in planSupportedLocales)
            TextButton(
                onPressed: () => widget.onLocale?.call(locale),
                child: Text(locale.languageCode)),
        ]),
        body: PlanEditor(
          controller: floor.controller,
          exportName: floor.name,
          serviceBar: PlanServiceBar(leading: [
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(child: Text(floor.name))),
          ]),
          onSave: () => savePlan(widget.store, floor),
          onUnitTap: (label) => debugPrint('table $label'),
          onUnitDoubleTap: (label) => debugPrint('open table $label'),
          onMergeRequested: (labels) => mergeTables(floor, labels),
          onSplitRequested: (id) => splitGroup(floor, id),
          onLayoutChanged: () => debugPrint('the layout changed'),
          unitOverlayBuilder: tableBadge,
          unitOverlayLayout:
              const PlanOverlayLayout(anchor: Alignment.bottomCenter),
          longPress: PlanLongPress.contextMenu,
          floorDrag: PlanFloorDrag.band,
        ),
      );
}
```

- **Export and print.** The bar's Export and Print run the planner's own
  dialog; `onExport` hears the finished file, `onPageFlowError` an error,
  `printer` replaces the platform's print dialog, `exportName` names the
  file. A host with a bar of its own calls the controller. `export` shows no
  dialog itself, so a host that wants the library's shows it first:

```dart
/// Exports the plan as a PDF through the planner's dialog.
Future<PlanExport?> exportPdf(BuildContext context, PosFloor floor) async {
  final c = floor.controller;
  final answer = await showPlanExportDialog(
      context, PlanExportAnswer.initial, c.exporters);
  if (answer == null) return null;
  return c.export(answer.exporter, answer.choice, name: floor.name);
}
```

  `controller.export(exporterId, choice, {name})` returns the file (bytes,
  `name`, `mimeType`), or null when another export or a print is running or
  the plan was replaced; `controller.print(choice, {printer, name})` prints.
  `controller.exporters` lists `plan.pdf`, `plan.png` and the exporters you
  registered with `PlanController(exporters:)`. `pageFlowBusy` is a
  `ValueListenable<bool>`, true from the start of an export or a print (its
  dialog included) to its end; a bar of your own keeps its buttons off while
  it is:

```dart
/// A service bar of the POS's own, its Export off while a page flow runs.
Widget exportButton(PlanController c, VoidCallback onExport) =>
    ValueListenableBuilder<bool>(
      valueListenable: c.pageFlowBusy,
      builder: (context, busy, _) => TextButton(
          onPressed: busy ? null : onExport, child: const Text('Export')),
    );
```

- **The service bar.** `PlanServiceBar(actions:, leading:, trailing:, visible:)`
  shapes the planner's own bar; `visible: false` hides it for a bar of yours.
  The chords stay bound whatever the bar lists. A host text field in the bar
  takes the keys it needs.
- **Context menus.** `onUnitContextMenu` is where a POS opens its table menu.
  On the web the browser's own menu opens on a right click; the
  `BrowserContextMenu.disableContextMenu()` line of [section 2](#2-fonts) is
  the host's to decide because it is app-global.
- **Long press and floor drag.** `longPress` is `PlanLongPress.toggleSelection`
  (the default) or `contextMenu`; `floorDrag` is `PlanFloorDrag.pan` or
  `band`, a drag that selects tables.
- **Keys.** `shortcuts: false` gives the keyboard to the host; with it off
  nothing deletes in the editor but your own call, so bind a key or a button
  to `deleteSelection()`. `kFileChords` lists the file commands' chords for a
  host that binds them itself.

### 6.10 Linking any object

A table is not the only thing a POS links. A room is a section of the floor
(a terrace, a bar), a placed symbol may stand for a till or a printer, and the
host wants its own record on each. Host data is not limited to units: every
**root-level object** of the plan can carry it, a placed unit, a placed symbol
or an object of a kit's type (a room). The host names such an object by a
`PlanObjectRef`, an opaque reference read from the plan, never made by the
host.

```dart
/// The plan's objects of any kind (a table, a placed symbol, a room) by the
/// POS id they are linked by.
Map<String, PlanObjectRef> objectsByPosId(PlanController c) => {
      for (final detail in c.objectDetails)
        if (detail.data['id'] case final id?) id: detail.ref,
    };

/// Links the object [ref] to the POS record [posId]. The object's other data
/// is kept. False when [ref] names no object, or the object is locked.
bool linkObject(PlanController c, PlanObjectRef ref, String posId) {
  final detail = c.objectDetailOf(ref);
  if (detail == null) return false;
  return c.setObjectData(ref, {...detail.data, 'id': posId});
}
```

- `objectDetails` lists the objects that carry data, in draw order;
  `objectDetailOf(ref)` reads one object whether it carries data or not. A
  `PlanObjectDetail` has its `ref`, its `kind` (`PlanObjectKind.unit`,
  `symbol` or `type`), the `typeId` of a kit's type, the `symbolKey`, a
  `label` and the `data`. The `label` is a unit's label; for an object of a
  kit's type, the object's own name when the kit declares one (a room's
  "VIP"), else the type's title word ("Room"); null for a placed symbol.
- `setObjectData(ref, data)` and `setObjectsData({ref: data})` write what
  `setUnitData` writes, with the same limits, errors and one undoable step.
  They return false, changing nothing, when the reference names no object or
  the object sits under a lock. A unit's data is one and the same either way:
  `setUnitData` and `setObjectData` read each other's writes, and a plan saved
  before objects carried data opens with its unit data intact.
- A `PlanObjectRef` is **valid for its plan only**: for the plan it was read
  from, and for that plan saved and loaded again. After `newPlan`, or a `load`
  of another plan, drop every reference you kept and read them again; the
  controller cannot tell an old reference from a new one that happens to name
  the same object. A reference whose object was deleted names nothing, and the
  controller answers it with null or false.

### 6.11 Sections

A **section** is the area of the floor a table stands in: the terrace, the bar,
the upstairs room. The plan finds it for every unit:
`PlanUnitDetail.section` is the `PlanObjectDetail` of the section (its `label`
is the room's name, its `data` the host's link), or null when the table stands
in none.

- **What a section is.** A *room* of the architecture kit: the area its walls
  or separators enclose. A kit may declare other area objects, and they count
  the same. Walls that are frozen (locked) still bound an area.
- **The rule.** The unit's **centre** decides. Among the sections whose
  outline holds the centre, the one with the **smallest area** wins (a booth
  room inside a hall is the booth's). A centre on a boundary counts as inside.
  Two areas of equal size (within the tolerance) are a tie, and the tie goes
  to the lower, older object, so the answer never flips.

```dart
/// The section each linked table stands in, by the table's POS id: the
/// section's own POS id, or its name when it is not linked.
Map<String, String?> sectionsByPosId(PlanController c) => {
      for (final detail in c.unitDetails)
        if (detail.data['id'] case final id?)
          id: detail.section?.data['id'] ?? detail.section?.label,
    };

/// Writes a table's section to the POS's database whenever the plan moves
/// the table into another section, or the section's walls move.
StreamSubscription<PlanSectionChange> watchSections(
  PlanController c,
  void Function(String posTableId, String? section) write,
) =>
    c.sectionChanges.listen((change) {
      final posIdOf = {
        for (final MapEntry(:key, :value) in labelsByPosId(c).entries)
          value: key,
      };
      for (final MapEntry(key: label, value: section)
          in change.byLabel.entries) {
        if (posIdOf[label] case final id?) write(id, section?.label);
      }
    });
```

To list the sections themselves, not the tables in them, read
`sectionDetails`:

```dart
/// The plan's sections by name, whether or not they carry data: a room's own
/// name is its label, so a host can find "VIP" without a table in it.
Map<String, PlanObjectRef> sectionRefsByName(PlanController c) => {
      for (final section in c.sectionDetails)
        if (section.label case final name?) name: section.ref,
    };
```

- `sectionDetails` lists every object whose kit type declares an area, in draw
  order, whether it carries data or not (`objectDetails` lists only the
  objects that do). A room whose walls are open right now is still listed. It
  is how a host links its sections: match each `label` to a record of its own,
  then `setObjectData`.
- A room is selected by tapping its label; tapping its floor picks nothing.
  The host never needs to select a room to link it: it holds the `ref` from
  `sectionDetails`.
- `sectionChanges` sends one `PlanSectionChange` after every design edit, undo
  or redo that moves some table's section, and in service after a layout move;
  `byLabel` holds only the tables that changed, each with its new section
  (null: none any more). A table added or removed is not a section change:
  `unitChanges` reports it, and its detail already carries the section. A
  `load` or `newPlan` reports nothing: read `sectionsByPosId` once afterwards.
- A change of a room's **data alone** (a `setObjectData` on the room) reports
  no section change: no table moved between rooms. Read the tables' sections
  again yourself after you relink a room.
- `unitChanges` is unchanged: a section change alone is not a
  `PlanUnitChanged`.

### 6.12 The inspector

The editor's right column shows the property panel, and under it the host's
own widget for the selected object, so the staff link an object to a record
without leaving the plan. There are two builders, and the editor routes the
selection by one rule:

- `unitInspectorBuilder` takes a placed **unit**, with its `PlanUnitDetail`.
- `objectInspectorBuilder` takes **any one selected root object** (a unit, a
  placed symbol, a room), with its `PlanObjectDetail`.
- **The rule.** A selected unit goes to `unitInspectorBuilder` when it is
  given, else to `objectInspectorBuilder`. Every other object goes to
  `objectInspectorBuilder`. Give both and the units keep their own, with the
  units' fields; give only the object one and it serves everything.

Both are built for exactly one selected object that is not locked, in design
mode only, when the selection becomes it and at each change of the plan; a
null from a builder shows nothing. A combo over the host's records is the
usual body, writing the record's id on the object and keeping the object's
other data, as 6.2 does:

```dart
/// A combo over the POS's records for the one selected object: choosing one
/// writes its id on the object, the object's other data kept.
Widget recordPicker(
  PlanController c,
  PlanObjectDetail object,
  List<String> records,
) =>
    DropdownButton<String>(
      value: records.contains(object.data['id']) ? object.data['id'] : null,
      hint: const Text('Record'),
      items: [
        for (final record in records)
          DropdownMenuItem(value: record, child: Text(record)),
      ],
      onChanged: (id) {
        if (id != null) c.setObjectData(object.ref, {...object.data, 'id': id});
      },
    );

/// An editor with both inspectors: the units go to the unit inspector, every
/// other object (a room, a placed symbol) to the object inspector.
Widget inspectedEditor(PlanController c, List<String> records) => PlanEditor(
      controller: c,
      unitInspectorBuilder: (context, unit) => Text('${unit.unit.label}'),
      objectInspectorBuilder: (context, object) =>
          recordPicker(c, object, records),
    );
```

Hiding the property panel (`propertyPanel: false`) hides the inspectors too.

The right column follows the selection (`contextualPanels`, true by
default): with anything selected it shows the object's own properties and
the inspectors only; with nothing selected, the Layers and Page sections. The
same holds in the right drawer on a phone or a tablet. Pass
`contextualPanels: false` for 0.9.0's column, every section at all times.

## 7. Permissions

`PlanPermissions` decides what the editor offers its user: which tools, and
whether the user may move, rotate, mirror, reshape, delete, change layer,
recolour, edit layers, edit the page, relabel, undo, export and print. Two in
service: `serviceMove` (a drag from a table moves it) and `serviceMerge`
(Merge and Split). `selectUnitsOnly` keeps the selection to units.

```dart
/// What the waiter may do, and what the manager may.
const PlanPermissions waiter = PlanPermissions.readOnly;

const PlanPermissions manager = PlanPermissions(
  tools: {
    PlanToolIds.select,
    PlanToolIds.symbol,
    PlanToolIds.rectangle,
    ArchitectureTools.wall,
    ArchitectureTools.door,
  },
  editPage: false,
);
```

- Tools are string ids. `PlanToolIds` holds the plan library's
  (`select`, `line`, `polyline`, `rectangle`, `circle`, `arc`, `text`,
  `symbol`; `PlanToolIds.all`), and each kit exports its own
  (`ArchitectureTools.wall`, `.door`, ...). `plan.select` is always allowed.
  `tools: null` allows every tool.
- `PlanPermissions.full`, `readOnly` and `unitsOnly` (select and place units;
  no layers, page or reshaping) are ready-made. `copyWith` changes one flag.
- Set it on the controller (`permissions:` in the constructor, or the
  `permissions` setter at any time: a manager logs in, the views follow).
- `isUnitSymbol` is the gallery filter for `PlanEditor(symbolFilter:)` that
  leaves only servable symbols, for the `unitsOnly` profile.
- **Permissions are not a security boundary.** They decide what the editor
  offers; your own calls (`setUnitData`, `undo()`, `load`, `export`) stay
  allowed under every value and the value is never stored with the plan.
  Decide who may change a floor in your own application and check it where
  the plan is stored.

## 8. A host kit: your own symbols

A host adds its own symbols, a till or a pickup shelf, as a small kit of its
own. There is no other API: a kit is the unit the library loads, names and
checks.

```dart
/// The POS's own symbols, as a kit of its own.
final PlanKit acmeKit = PlanKit(
  id: 'acme',
  version: '1.0.0',
  symbols: [
    SymbolLibrarySource(
        label: 'acme', read: bundledLibrary('assets/acme.jetlib')),
  ],
);
```

List it with the others (`kits: [architectureKit, restaurantKit, acmeKit]`).
The rules:

- The kit **id** is the first segment of every key in its libraries
  (`acme.item.till`): the library refuses a library that does not carry its
  kit's id, and a `key@version` that is in two libraries.
- A library is a `.jetlib` file, built with the authoring toolkit
  (`package:jet_cad_2d_kit/authoring.dart`) and checked with its conformance
  test. `docs/kits.md` sections 4 and 7 to 9 describe the format and how to
  build one. The library is a Flutter asset of your app (`assets/acme.jetlib`
  in your pubspec's `flutter: assets:` list), and `bundledLibrary` reads it.
- A symbol becomes a servable unit when its definition carries the unit
  component (a kind and a capacity); a symbol without it places as plain
  drawing.
- A placed symbol copies its definition into the plan, so a plan opens
  without the library; the kit's id and version go in the plan's manifest,
  and `missingKits` names a kit the plan uses that the controller lacks.
- Symbol and category names come from the kit's `names` (English is
  required; other languages optional) and from `PlanController(words:)`.

## 9. Two views of one floor

"Two views" means two `PlanServiceView`s on one controller: an overview
beside a close-up, a floor map beside the order screen.

```dart
/// The same floor twice, in service: an overview beside a close-up.
class TwoViews extends StatefulWidget {
  const TwoViews({super.key, required this.controller});

  final PlanController controller;

  @override
  State<TwoViews> createState() => _TwoViewsState();
}

class _TwoViewsState extends State<TwoViews> {
  bool _closeUp = false;

  @override
  void initState() {
    super.initState();
    widget.controller.setMode(PlanMode.service);
    // The view mounted last drives the camera's zoom focus.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => setState(() => _closeUp = true));
  }

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: PlanServiceView(
                controller: widget.controller,
                bar: const PlanServiceBar(visible: false),
                autofocus: false)),
        if (_closeUp)
          Expanded(child: PlanServiceView(controller: widget.controller)),
      ]);
}
```

- The views share one **camera**. Pan or zoom in one and the other moves
  with it; there is one camera per controller.
- The view that **last reported its canvas** drives `controller.canvasRect`,
  and with it `zoomBy`'s default focus and `worldToGlobal` /
  `globalToWorld`. A canvas reports when it first mounts and again whenever
  it moves or resizes. The order among views mounted in one frame is not
  defined (a view still owing the plan's first fit reports after one that
  does not), so **mount the view that should drive after the others**, as
  `TwoViews` does by adding it a frame later. When the driving view goes, the
  most recent reporter among the rest takes over after the next frame.
- A `PlanEditor` in service shows a `PlanServiceView` itself, so an editor
  plus a second service view is two views too.
- The design canvas is different: a second `PlanCanvas` on one controller
  asserts in debug builds. Show the design once.
- `userCamera: false` on a view keeps the staff from panning and zooming it
  (a pinned overview); your own `centerOn` still moves it.

## 10. Themes and your own widgets

The planner's chrome (bars, panels, buttons, fields, selects, menus, tooltips
and the export dialog) is `shadcn_ui`; its canvas look is a `PlanTheme`
**extension**. Which design system your app uses decides what you put around
the view:

- **A shadcn host** puts its `ShadTheme` (or `ShadApp`) above the view; the
  planner uses it as is.
- **A Material host** needs nothing. The chrome is derived from the ambient
  `ThemeData`: its colours, its brightness and its font family. Light and dark
  themes work as before.
- **Icons** are Lucide icons. `IconData` stays the API: a kit may give any
  icon, and the architecture kit's tool icons are Lucide.

`PlanTheme` is for the plan's own look: status fills and captions, group
frames and chips, the selection, the focus veil, the canvas background and
the service bar's height (`serviceBarHeight` still sizes the service bar).
Put one in each of the host's themes; the system picks light or dark:

```dart
/// The planner's look in the POS's light theme.
const PlanTheme planLookLight = PlanTheme(
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

final ThemeData posLightTheme = ThemeData(
  colorSchemeSeed: Colors.teal,
  extensions: const [planLookLight],
);
```

- Every `PlanTheme` field is optional; a field left null keeps the library's
  default. `theme:` on a view overrides the ambient extension field by field.
- The selection colours are chosen by the paper (light or dark), not by the
  theme.
- A POS whose own design system is shadcn puts a `ShadTheme` with its tokens
  around the view; a Material scheme cannot reproduce another design
  system's colours. The restaurant demo's app is a plain `ShadApp` (zinc,
  Roboto) in both looks; its look toggle changes only the canvas side. The POS
  look is a `PlanTheme` (3 px selection, a 52 px service bar) that
  `ShadApp.materialThemeBuilder` puts on the Material theme the planner reads:
  `apps/restaurant_demo/lib/demo_theme.dart`.
- `PlanTheme.unitColourOpacity` is the opacity of a unit's own colour
  (`setUnitColour`, `setUnitsColour`); the export draws it at the same
  opacity as the screen.

**Moving to the shadcn chrome (0.9.x hosts).** What a host sees:

- Icon buttons are 40 px (they were 48), the service bar is painted with the
  shadcn background, and the export dialog is a shadcn dialog.
- A widget test that found Material types inside the planner (`IconButton`,
  `TextField`, `DropdownButton`, `SegmentedButton`, `Tooltip`, `ListTile`,
  `AlertDialog`) finds the planner's own widgets now; the keys are
  unchanged, so a finder by key keeps working. An open select or menu keeps
  the keyboard, as a Material route did.
- A host on `shadcn_ui` is on `^0.57.1`; a Material host adds nothing.

**Your own widgets on the tables.** A view calls `unitOverlayBuilder` for
each table to draw, in the modes in `unitOverlayModes` (service by default),
and lays the widget out by `unitOverlayLayout` (anchor, size, the scale it
hides below, and the detail levels):

```dart
/// A badge on each table in service: its label and its seats.
Widget? tableBadge(BuildContext context, PlanUnitOverlay table) {
  final unit = table.detail.unit;
  return Text('${unit.label} (${unit.capacity})');
}
```

A `PlanUnitOverlay` carries the table's `detail`, whether it is `selected` or
`focused`, its `status` and the `detailLevel`. The builder runs on a change of
the table, never on a pan or a zoom: live data (a minute counter) belongs in
a `ValueListenableBuilder` inside the widget.

### 10.1 Alignment guides

While a movable object is dragged or placed, a thin line shows where its
edges or its centre line up with a nearby object, and the object snaps there.
Where two gaps become equal, small marks across the gaps say so; nothing is
written on them. They are on by default.

- **What counts.** Edges (left, right, top, bottom), centres and **equal
  spacing**. Only movable objects count, as the moved object and as a
  reference: placed symbols, that is tables, the bar, fixed furniture and kit
  symbols. Walls, rooms and lines do not (object snap serves them), and a
  table's own seats are not references. A rotated or mirrored object aligns
  by its axis-aligned bounding box, not by its slanted edges. A selection of
  several objects aligns by the outer box of the group.
- **Both modes.** In design mode guides work when a selection of symbols is
  moved and when a symbol is placed (the ghost). In service mode a waiter
  dragging tables, or a whole group, gets them too. A selection that includes
  a wall, a room or a line moves as before.
- **Alt.** Holding Alt (Option on macOS) suspends the guides for the drag.
- **Reach.** A guide captures within 6 screen pixels of a mouse, 10 of a
  finger, at any zoom. A guide beats the grid and a pointer object-snap hit
  (a wall's corner under the pointer) while the drag is eligible; an
  attachment (a symbol that clings to a wall) still wins over a guide.

A host that does not want guides says so on the view. `PlanEditor`,
`PlanServiceView` and `PlanCanvas` take `alignmentGuides`, true by default;
false hides the bar's button and turns guides off in that view:

```dart
/// A floor editor that never offers alignment guides.
Widget plainEditor(PlanController c) =>
    PlanEditor(controller: c, alignmentGuides: false);
```

`PlanEditor` hands its value to the canvas and to the service view it mounts.
Two standalone views over one controller with different values: the one
mounted last wins.

The user's choice lives on the controller, as a `PlanGuideSettings`
(a `ChangeNotifier`): `on` is what the tools obey (the host's allowance and
the user's choice together), `userOn` the user's choice alone, `allowed` the
host's, and `toggle()` flips the user's. The choice is kept in memory for the
controller's life, shared by both modes, and not saved in the plan file.

```dart
/// Follow the guides' switch in the POS's own chrome, and flip it from code.
void watchGuides(PlanController c) {
  c.alignmentGuides.addListener(() {
    debugPrint('guides: ${c.alignmentGuides.on}');
  });
  c.alignmentGuides.toggle();
}
```

Both bars have a toggle button: `PlanEditorAction.guides` in the editor's bar
(after Redo, and also on the default path) and `PlanServiceAction.guides` in
the service bar (after Redo). Their widget keys are `toolbar-guides` and
`service-guides`. Two things follow for a host that was already built:

- a host that lists `actions` explicitly adds `guides` where it wants the
  button; a host whose `actions` equal `PlanEditorAction.values` or
  `PlanServiceAction.values` now gets the toggle;
- a `switch` over either enum without a fallback needs the new `guides` case.

The look comes from the theme. `PlanTheme.guideOnLight` and `guideOnDark` are
the line colours on a light and on a dark paper (the built-in magenta when
null), and `guideWidth` is the stroke in logical pixels (1 by default):

```dart
/// Guides in the brand's blue, twice as thick as the default.
const PlanTheme planLookGuides = PlanTheme(
  guideOnLight: Color(0xFF2563EB),
  guideOnDark: Color(0xFF60A5FA),
  guideWidth: 2,
);
```

A test of the host that pins where a dragged table lands should turn guides
off first (`controller.alignmentGuides.toggle()`, or `alignmentGuides: false`
on the view), because a drag near a neighbour now lands aligned.

## 11. Touch

Both modes work on a touch screen. Two fingers pinch about their midpoint and
pan together; once two fingers are down nothing reaches a tool until every
finger lifts, and a second finger during a table drag cancels the drag. A
finger's picks and grips are finger-sized. In service a tap selects, a drag
from a table moves it (or pans, with `serviceMove: false` in the
permissions), and a long press does what `longPress` says, about 500 ms from
contact. With `floorDrag: PlanFloorDrag.band` a one-finger drag on the floor
draws a band that selects tables and no longer pans; the camera then pans
with two fingers. Mouse, trackpad and stylus behave as on a desktop.

## 12. From `jet_cad_floor_plan`

The old planner (`jet_cad_floor_plan` 0.7.2, `jet_cad_restaurant_symbols`)
is replaced by `jet_cad_2d_plan` and the kits. Its guide stays at the tag
`v0.7.2`. The behaviours are the same; the names changed from *floor plan*
and *table* to *plan* and *unit*, and a table is now a unit a kit
declares. Every name the old barrel exported:

| `jet_cad_floor_plan` | now |
|---|---|
| `FloorPlanController` | `PlanController` (+ `kits:`) |
| `FloorPlanView` | `PlanEditor` (both modes), `PlanServiceView` (service), `PlanCanvas` (design canvas) |
| `FloorPlanMode` | `PlanMode` |
| `FloorPlanTable` | `PlanUnit` |
| `FloorPlanTableDetail` | `PlanUnitDetail` |
| `FloorPlanDesignChange`, `FloorPlanTableAdded` / `Changed` / `Removed`, `FloorPlanPlanReplaced` | `PlanUnitChange`, `PlanUnitAdded` / `Changed` / `Removed`, `PlanUnitsReplaced` |
| `TableStatus`, `TableGroup` | `UnitStatus`, `UnitGroup` |
| `ServiceLayoutRestore` | `ServiceRestore` |
| `FloorPlanTheme` | `PlanTheme` |
| `FloorPlanColor` | `PlanSwatch` (from `jet_cad_2d_kit`) |
| `FloorPlanSymbol` | `PlanSymbol` |
| `FloorPlanCamera` | `PlanCamera` |
| `FloorPlanEditorCapabilities` | `PlanPermissions` |
| `FloorPlanEditorAction`, `FloorPlanEditorBar` | `PlanEditorAction`, `PlanEditorBar` |
| `FloorPlanServiceAction`, `FloorPlanServiceBar` | `PlanServiceAction`, `PlanServiceBar` |
| `FloorPlanFloorDrag`, `FloorPlanLongPress` | `PlanFloorDrag`, `PlanLongPress` |
| `FloorPlanTableOverlay`, `FloorPlanTableOverlayBuilder`, `FloorPlanOverlayLayout`, `FloorPlanOverlaySize` | `PlanUnitOverlay`, `PlanUnitOverlayBuilder`, `PlanOverlayLayout`, `PlanOverlaySize` |
| `FloorPlanExport`, `FloorPlanExportChoice`, `FloorPlanExportDpi`, `FloorPlanExportFormat` | `PlanExport`, `PlanExportChoice`, `PlanExportDpi`, an exporter id (`plan.pdf`, `plan.png`) |
| `PagePrinter`, `PrintingPagePrinter` | the same |
| `ensureFloorPlanFonts`, `registerFontLicences` | `ensurePlanFonts`, `registerFontLicences` |
| `FloorPlanLocalizations`, `floorPlanLocalizationsDelegates`, `floorPlanSupportedLocales` | `PlanLocalizations`, `planLocalizationsDelegates`, `planSupportedLocales` |
| `FloorPlanStrings`, `…En`, `…De`, `…Tr` | `PlanStrings`, `PlanStringsEn`, `PlanStringsDe`, `PlanStringsTr` |
| `DuplicateNumber`, `Unnumbered`, `NumberingWarning`, `TableNumberProblem` | `DuplicateLabel`, `Unlabelled`, `UnitLabelWarning`, `UnitLabelProblem` (+ `BadLabel`) |
| `SymbolLibraryLoader`, `SymbolLibrarySource`, `furnitureSymbolSource` | `PlanSymbolLoader`; a kit's `SymbolLibrarySource` (the furniture library is in `jet_cad_2d_kit_architecture`) |
| `SymbolLibraryState` (`Loading`, `Ready`, `Failed`) | `SymbolsState` (`loading`, `ready`, `failed`) |
| `SymbolNames` | `KitNames` (a kit's words; the host's go in `PlanController(words:)`) |
| `SymbolThumbnails` | the same |
| `jet_cad_restaurant_symbols` | `jet_cad_2d_kit_restaurant`, loaded as `restaurantKit` |

The controller's members, where the name changed:

| `FloorPlanController` | `PlanController` |
|---|---|
| `designJson()` | `save()` |
| `serviceLayoutJson()`, `restoreServiceLayout(json)`, `resetLayout()`, `serviceLayoutChanges` | `serviceJson()`, `restoreService(json)`, `resetService()`, `serviceChanges` |
| `tables`, `tableDetails`, `selectedTables`, `editorSelectedTables` | `units`, `unitDetails`, `selectedUnits`, `editorSelectedUnits` |
| `tableStatuses`, `tableGroups`, `tableFocus` | `unitStatuses`, `unitGroups`, `unitFocus` |
| `setTableStatus`, `setTableGroups`, `setTableFocus` | `setUnitStatus`, `setUnitGroups`, `setUnitFocus` |
| `setTableData`, `setTablesData`, `setTableColor`, `setTablesColor` | `setUnitData`, `setUnitsData`, `setUnitColour`, `setUnitsColour` |
| `fitToTables`, `tableAt` | `fitToUnits`, `unitAt` |
| `designChanges`, `numberingWarnings` | `unitChanges`, `labelWarnings` |
| `camera` (a `ValueListenable`) | `cameraValue` |
| `exportPlan`, `printPlan` | `export`, `print` |
| `FloorPlanController(symbolSources:)` | a kit's symbols ([section 8](#8-a-host-kit-your-own-symbols)) |
| `FloorPlanView(editorCapabilities:, ...)` | `PlanController(permissions:)` and the `permissions` setter |

Not carried over, on purpose:

- **Plans saved by the old planner** (schema 7 to 10) do not open: the plan
  format is 1 and there is no converter. A POS with stored floors recreates
  them, or writes its own converter. The numbers, data and colours of an old
  plan are not read.
- **The old service-layout text** (`jet_cad.service_layout`) is refused by
  `restoreService`, which reads only the new record.
- **`FloorPlanTool`** is gone: tools are string ids, and `PlanToolIds` and
  each kit's constants name them.
- **`symbolSources`** is gone: your symbols come as a kit
  ([section 8](#8-a-host-kit-your-own-symbols)).
- **One view per controller** is no longer enforced with a `StateError`:
  [section 9](#9-two-views-of-one-floor) says what two views do.

## 13. What a host must never assume

- **Handles.** A unit's identity is its label (and, for the POS, the id you
  wrote in its data). The plan's internal handles are not API.
- **Permissions are not a security boundary.** See [section 7](#7-permissions).
- **With `shortcuts: false` nothing deletes in the editor** but your own call:
  the Delete and Backspace keys are unbound and the library has no Delete
  button, so bind a key or a button of yours to `deleteSelection()`.
- **Groups and statuses are keyed by label.** A relabel does not move them.
  Key your own state by POS id and draw it again after a relabel
  ([6.6](#66-relabelling-a-table-that-belongs-to-a-group)).
- **Statuses, groups and focus are not in the plan.** They are not saved,
  not undone and not dirty, and the controller keeps them across a `load`
  and a `newPlan`: draw yours again after one. Groups and moves are in the
  service record; keep that text yourself
  ([6.8](#68-saving-and-restoring-the-layout)).
- **The service layout's text.** Store it as it is, never parse or edit it
  or move it to another plan: a move names a table by an internal handle
  that belongs to the one plan it was saved from.
- **The service copy's undo.** Undo in service undoes service moves only; it
  never reaches a design edit, and a restored layout is not a step.
- **A stored name's language.** A placed symbol keeps its English name in the
  plan; the library shows the kit's name in the UI's language. Room and layer
  names are stored in the language they were created in.
- **The plan's text separator.** It belongs to the plan, not to the terminal:
  a plan you load keeps its own, whatever the language. An empty plan a
  controller creates takes the language of the first view that shows it; until
  then, and with no view, it is `.`. `newPlan()` takes the language a view of
  that controller last showed.
- **The kits you save with.** A plan that uses a kit the controller lacks
  opens with that kit's objects locked and untouched ([section 5](#5-storing-the-plan));
  a plan saved with a newer kit than the one loaded is reported. Every
  terminal that shares stored plans loads the same kits.
- **Plan format 1.** There is no migration from the old planner's schemas,
  and a library refuses (`PlanFormatCode.formatTooNew`) a plan written in a
  newer format than the one it writes.
- **A second `PlanCanvas` on one controller.** It asserts in debug builds;
  show the design canvas once.
- **A disposed controller.** Widgets do not dispose a controller they were
  given; the host disposes it, after the widgets that show it are gone.

## 14. Phones and tablets

The design mode follows the width of the **editor itself**, not the device's:

| Editor width | Layout | Shape |
| --- | --- | --- |
| below 600 | `PlanEditorLayout.phone` | no docked column |
| 600 to below 1000 | `PlanEditorLayout.tablet` | a docked icon-only tool strip |
| 1000 and up | `PlanEditorLayout.desktop` | both columns docked, as always |

- **The drawers.** On a phone the bar's left button (a menu icon) opens the
  tools and symbols over the plan, and its right button (a tune icon) the
  properties, layers and page. A tablet docks the tool strip, with a symbols
  icon at its foot that opens the symbols as a drawer, and keeps the right
  button. One drawer is open at a time. A tap on the plan, the same button or
  **Escape** closes it (Escape is left to a text field that has the focus).
  Opening a drawer never moves the camera.
- **A pick closes the left drawer.** Choosing a tool or a symbol in the left
  drawer closes it, so the plan is in front again to place the pick.
- **A double tap ends a chain.** A phone has no Enter key, so a quick second
  tap at the same spot ends a wall or polyline chain as Enter does: the first
  tap of the pair is the chain's last point and the second adds nothing.
  Picking another tool still ends it too. A mouse double click keeps meaning
  two clicks; a host's help text can mention the gesture.
- **A behaviour change from 0.8.x.** A `PlanEditor` narrower than 1000 px used
  to keep the desktop columns; it now gets the tablet or phone layout. A host
  that wants the desktop chrome at any width passes
  `layout: PlanEditorLayout.desktop`, which forces one layout whatever the
  width:

```dart
/// An editor whose design layout is the desktop's at any width, as in 0.8.x.
Widget desktopEditor(PlanController c) =>
    PlanEditor(controller: c, layout: PlanEditorLayout.desktop);
```

- **The breakpoints** are the host's to move, `PlanLayoutBreakpoints(tablet:,
  desktop:)`, and are read against the editor's own width, so an editor in a
  split view gets the layout of its pane. The service side panel is in the same
  block:

```dart
/// An editor that docks its columns from 900 logical pixels and uses the
/// tablet layout from 500, with the POS's orders beside the service.
Widget editorWithOrders(PlanController c, Widget orders) => PlanEditor(
      controller: c,
      breakpoints: const PlanLayoutBreakpoints(tablet: 500, desktop: 900),
      serviceSidePanel: orders,
    );
```

- **The service side panel.** `serviceSidePanel` is the host's panel beside the
  plan in service (orders, a table's detail). On a desktop layout it is docked
  on the right, 320 logical pixels wide. On a phone or a tablet it opens as a
  drawer over the plan from the **last button of the service bar**. Without a
  panel there is no button and no column. With `serviceBar.visible` false
  there is **no button** on a phone or a tablet and the panel cannot be
  opened: keep the bar, or show your own panel. `PlanServiceView` takes the
  same `serviceSidePanel`, `breakpoints` and `layout`. The service bar scrolls
  instead of overflowing on a narrow screen.
