# The architecture kit (sub-project 3a) — design

**Date:** 2026-10-15. **Status:** revision 2. Revision 1 was written after
the human approved the design section by section in chat. Revision 2
applies an independent Opus review (2 blocking, 12 important, 14 minor
findings, each checked against the code) on the human's *"önce opus
incelemesi"*, and the human's two answers it asked for (decisions 6 and 7).
**Approved by the human** (*"onaylıyorum, devam et"*, 2026-10-15).

**Binds:** the umbrella spec
[2026-10-13-kit-architecture-design.md](2026-10-13-kit-architecture-design.md)
(A1-A17), the contract spec
[2026-10-13-kit-contract-design.md](2026-10-13-kit-contract-design.md)
(K1-K9), the 2a spec
[2026-10-14-plan-library-design-mode-design.md](2026-10-14-plan-library-design-mode-design.md)
(P1-P7, E1-E4) and the 2b spec
[2026-10-14-plan-library-service-mode-design.md](2026-10-14-plan-library-service-mode-design.md)
(S1-S5, E5). Their rules hold here unless a section below says otherwise;
"Amendments to other specs" lists every line this spec adds to them. Both
the 2a and the 2b spec foresaw this ("Sub-project 3's six types are the
real test. A field they need goes into this spec as an amendment before the
wave publishes 0.1.0").

**Branch:** `feat/architecture-kit`, cut by hand from `main` at `7e65905b`
(`origin/main` at `651e3d09`, an ancestor), worktree
`.claude/worktrees/architecture-kit`.

## Decisions taken in the brainstorm (the human, 2026-10-15)

1. **Sub-project 3 is split in two** (*"3a kit, 3b demo"*): 3a is this
   spec, the contract's amendments, `jet_cad_2d_kit_architecture` and the
   tests that run the kit inside the plan library; 3b is
   `apps/architecture_demo`, with its own spec. The human is told when the
   demo runs on the new packages, at the end of 3b. This settles the
   conflict between umbrella A13 (the demos in sub-project 4) and STATUS
   (the demo at the end of sub-project 3): `apps/architecture_demo` is 3b's;
   `apps/restaurant_demo` stays sub-project 4's.
2. **The integration tests live in their own unpublished package**
   (*"Ayrı özel paket"*): `packages/jet_cad_2d_integration` (C6), after the
   human asked what it is and accepted the answer (*"uygun, devam et"*).
3. **The furniture library's dining tables are plain symbols, not units**
   (*"Hayır, düz sembol"*). The architecture kit draws buildings and
   furniture; serving is the restaurant kit's.
4. **Approach A, the contract first** (*"evet, devam et"*): 3a's first tasks
   settle every contract amendment (C1) against the plan library's test
   kits; the kit is then written against interfaces that no longer move.
   Rejected: vertical slices (the contract changes five or six times while
   kit tasks are written against it, and cross-task names were 2b's
   recurring planning defect); a separate branch for the amendments (one
   more merge round for no gain, since 3a/3b is already a split).
5. **Sections C1 (the amendments), C2 (the package) and the order, parity
   and gate** were approved one by one (*"evet, devam et"*, *"evet devam
   et"*, *"uygun, devam et"*).
6. **A frozen object's references lock their targets** (*"Duvarı
   kilitle"*), asked after the review (C1.10): a live wall that a frozen
   opening references cannot be edited or deleted. Rejected: accepting the
   uncut wall and the orphan left by a delete (a visible defect); freezing
   the host too (the freeze spreads, and E2 changes).
7. **The tests that pin servable dining tables are dropped** (*"Evet,
   düşsün"*): `seating_test.dart` SE10, SE10b, SE11 and
   `furniture_library_test.dart`'s seating group (the five tables' seat
   counts), as decision 3's consequence (A14: "dropped" only with the
   human's word).

## Facts (at `7e65905b`, read from the code)

- **The contract** (`packages/jet_cad_2d_kit/lib/src/kit/`):
  - `PlanKit(id, version, symbols, types, tools, attachments, names)`
    (`plan_kit.dart:16-26`). No document-setup hook.
  - `PlanType<T>(id, fromJson, parametric, grips, properties, section,
    title, colour, exported)` (`plan_type.dart:36-48`); the plan reads a
    type's fields through `fieldsOf(CommandTarget, Handle)` (:88-95).
  - `PropertySectionBuilder<T> = Widget Function(BuildContext, T value,
    void Function(T) commit, KitWords words)` (`plan_type.dart:24-25`): the
    escape hatch sees only the component.
  - Property specs (`properties.dart`): `LengthProperty` (constant,
    inclusive `min`/`max`), `AngleProperty`, `NumberProperty`,
    `ChoiceProperty`, `ToggleProperty`, `TextProperty`, `ValueDisplay<T>(read:
    double Function(T), unit)`, `ActionProperty`. A spec reaches the panel
    only through `bind(Object? value, {wordId, onCommit})` (:66-67) as a
    `PropertyField` (:326-347); a member typed over `T` read through
    `PropertySpec<Object?>` throws `TypeError` (the covariance note, :36-40).
    `enabled` greys a field, `gate` makes it read-only; no `visible`. A
    `write` that throws `ArgumentError` or `StateError` is a silent refusal
    (`jet_cad_2d_plan/lib/src/panels/plan_property_panel.dart:497-525`).
  - `PlanTool(id, icon, letter, needs, settings, create)`
    (`plan_tool.dart:36-62`); `PlanToolSettings.fieldsOf(value, store,
    toolId:)` (:26-32) has no object.
  - `PlanServices`: `document`, `index`, `camera`, `objectSnap`,
    `attachments`, `words`, `settingsOf`, `shared`, `symbolDefinition`,
    `symbolsState` (`plan_services.dart:86-130`). `KitWords`: `word`,
    `maybe`, `locale` (:18-28); no decimal separator.
  - `KitNames` namespaces: `symbol:`, `category:`, `tool:`, `type:`,
    `property:`, `unit:`; anything else is `unknownWordId` in
    `PlanKit.validate` (`plan_kit.dart:80-93`) and in `validateHostWords`
    (`host_words.dart:17-41`), which the controller's constructor turns into
    an `ArgumentError`. Words are flat strings.
  - `AttachmentProvider { kind; attach(AttachmentQuery) }`
    (`attachment.dart:11-18`); `SymbolComponent.attachTo` and `family`
    (`model/symbol_component.dart:99-102`). The symbol key rule: a kit id and
    two or more dot segments (`model/kit_ids.dart`).
- **The plan library** (`packages/jet_cad_2d_plan`):
  - `SymbolBox`, `isOrthonormal` (public, :18), `boxOfLeaves` (:69),
    `boxOfEntry` (:124), `servedTopOfEntry` (:135), `boxOfDefinition` (:154)
    and `footprintOf` (:170) in `lib/src/symbols/symbol_box.dart`;
    `placementTransform` in `lib/src/symbols/symbol_placer.dart:59`. Two
    copies of `isOrthonormal` exist besides: `tools/move_resolver.dart:18`
    and `panels/symbol_section.dart:137`.
  - `PlanController({kits, json, ...})` makes its document with
    `newPlanDocument` or `decodePlan` (`plan_controller.dart:286-293`); the
    save point is taken after the document is opened (:1601). Neither
    `newPlanDocument` nor the registration is exported; `load(String)` is the
    only way in for a document (`lib/jet_cad_2d_plan.dart`).
  - `newPlanDocument` drops today's DASHED record
    (`controller/new_plan.dart:3-4`, "the separator's, sub-project 3").
  - `PlanEditor`'s status line is the tool label and, with a selection,
    ` — n selected` (`editor/plan_editor.dart:514-519`).
  - Every kit tool reaches the plan as a `GuardedTool extends Tool` around
    `inner` (`kits/guard.dart:253-276`); kit grips as `GuardedGrips`, which
    catches everything and blacks out the object's grips (:485-560).
  - `numberedNames` counts over the plan's `PlanStrings` classes
    (`l10n/numbered_names.dart:15-31`).
  - No app or package depends on the plan library; its test harnesses live
    under `test/support` and are not importable by another package.
- **The engine:** `ParametricSystem.install` throws when the document
  already has an expander (`parametric_system.dart:718-722`);
  `ParametricCatalog.typeIdOf` answers a frozen object's type id too
  (:672-675); a frozen object is in no survey, and a delete of an object it
  references does not cascade to it (:680-697); `ReservedHandles.dashedLinetype
  = Handle(6)` (`document/style.dart:121`).
- **The dependency check** (`tool/ci/lib/kit_deps.dart`) reads every Dart
  file of a `jet_cad_2d_kit_*` package, `test/` included; it does not bind a
  package of another name.
- **Today's architecture code** (`packages/jet_cad_floor_plan/lib/src/`),
  type ids `floor_planner.<type>` (`parametric/catalog.dart:27-39`):

  | Type | Lines | Tool, letter | Tests (files, cases) |
  |---|---|---|---|
  | box | 171 | Box, B | 2, 12 |
  | wall | 1,567 | Wall, W | 7, 73 |
  | opening | 1,658 | Door D, Window N, Gap G | 13, 85 |
  | separator | 400 | Separator, S | 2, 10 |
  | room | 2,862 | Room, M | 16, 100 |
  | dimension | 1,938 | Dimension, I | 14, 73 |

  Plus the wall attachment (`symbols/wall_attach.dart` 550, `symbol_move.dart`
  62); the furniture catalog (`furniture_catalog.dart` 675,
  `furniture_names.dart` 113, `build_library.dart` 87, the generator and
  `assets/library/furniture.jetlib`: 41 symbols, 6 categories, 6 families,
  30 tagged `against-wall`, 5 dining tables at version 2 carrying a
  `jetcad.seating` component); the sample flat (`startup_plan.dart` 422:
  `startupPlan(measurer, {strings})` at :70 builds on `prepareDocument`,
  installs its own system, disposes it and clears the history, :253).
- **Today's rules this spec must keep:**
  - **Open adds nothing** (lifecycle spec D8, R-3, S-20): a file without the
    DASHED record opens without one and saves back byte-identical; its
    separators draw continuous (`new_document.dart:1-5`;
    `apps/floor_planner/test/document_open_test.dart:217-247`, DO3, mutation
    M-12a-18). `ensureDashedLinetype` is defined at
    `parametric/separator.dart:144-149`.
  - **The status line appends a notice:** `label`, then ` — n selected`,
    then ` — <notice>` (`planner_shell.dart:1004-1011`). The room notice is
    a value (`RoomOccupied`) put into words when the line is read, so a
    language switch re-words it at once.
  - **Only the dimension tool has keys** (Shift, `dimension_tool.dart:193`);
    the wall tool consults no lock or layer; an opening's host is a wall on
    a visible, unlocked layer, read from the layer record
    (`opening_tool.dart:447-450`).
  - **Caches** `WallBands` and `RoomInputs` invalidate on the document's
    `changes` stream and on explicit `invalidate()` calls from the tools
    (`wall_bands.dart:22-46, 138-142`; `room_inputs.dart:210-239`); the
    placement tool invalidates the bands after a placement
    (`symbol_place_tool.dart:500`).
  - **Panel lines:** the area and the value show '—' when there is no TEXT
    child, and the axes line is omitted (`selection_panel.dart:948, 1385`);
    the area and value are memoised per document change (:825-868). The axes
    line prints degrees with the UI language's separator (:907-916); the
    area, the value and the dimension notice follow the page's (Q0).
  - **Strict bounds:** `isWallThickness` and `isOpeningWidth` are strict
    (`wall.dart:47-48`, `opening.dart:268-270`); an opening whose host is not
    a wall refuses every position (`selection_panel.dart:428-433`).
- **Words today** (`l10n/strings.dart`): about 38 architecture string
  members in English, German and Turkish, five with parameters
  (`roomName(n)`, `roomOccupied(name)`, `axesTurned(degrees)`,
  `endOnWall(wall, atStart, side)` choosing a word from a bool,
  `sampleBedroom(n)`).
- **What is owed** (Appendix A): of `jet_cad_floor_plan/test`'s 165 files
  and 1,674 cases, about 559 architecture cases are not ported; 68 of those
  files are named by no note, ledger or brief.

## Purpose

The first real kit. It moves today's walls, openings, separators, rooms,
dimensions, boxes, furniture and wall attachment onto the contract,
unchanged in behaviour, and is the test the contract was not given in 2a
and 2b: every field the six types need lands in the contract before 0.1.0.

## C1. The contract amendments

Each amendment is code in `jet_cad_2d_kit` or `jet_cad_2d_plan`, pinned by
the plan library's own test kits (never by the architecture kit) with a
named mutation, and recorded under "Amendments to other specs". All of them
land before the first kit task (decision 4). The labels G1-G9 are the gaps
the brainstorm found: G1 the room area, G2 the dimension value and axes,
G3 the opening's position bounds (C1.1); G4 tool notices (C1.2); G5 the
DASHED record (C1.3); G6 the symbol box (C1.4); G7 live objects seen by a
kit (C1.5); G8 parameterised words (C1.6); G9 hidden fields (C1.7).

### C1.1 An object view for properties and sections (G1-G3; Appendix A's D-41)

```dart
/// The object a property or section is shown for: read-only.
abstract interface class PlanObject {
  DraftDocument get document;
  Handle get handle;
  Transform2 get world; // tree.accumulatedTransform(handle)
}
```

- **The path:** `PropertySpec.bind(value, {wordId, onCommit, PlanObject?
  object})`; `PlanType.fieldsOf(target, handle)` builds the `PlanObject`
  and passes it. Tool settings bind with `object: null`, and
  `PlanKit.validate` refuses a `TextDisplay` or a `range` in a tool's
  settings (a new `KitProblemCode`).
- **`TextDisplay<T>(id, read: String? Function(T value, PlanObject object))`**,
  a read-only line; its `PropertyField.value` is the `String`, and null omits
  the line. The panel's exhaustive switches over the sealed `PropertySpec`
  gain its row. Users: the room's area and the dimension's value as drawn
  (the kit returns '—' when there is no TEXT child, today's), the dimension's
  axes line (null when it is not turned, today's) and End 1, End 2. The kit
  memoises the area and the value by `document.commands.stateId`, as today
  memoises them per document change.
- **`LengthProperty.range: (double, double)? Function(T, PlanObject)?`**,
  checked with the constant `min`/`max`: an opening's position in `[0, L]`,
  `L` its host wall's centreline length. Null refuses every value (an
  opening whose host is not a wall, today's). A value outside is a refusal,
  as a throwing `write` is. Strict bounds (wall thickness, opening width)
  stay in `write`, which throws.
- **The escape hatch takes one context:**
  `typedef PropertySectionBuilder<T> = Widget Function(BuildContext, PlanSection<T>)`
  with `PlanSection<T> { T value; void Function(T) commit; KitWords words;
  PlanObject object; PlanServices services; }`. A later field joins the
  context without breaking a kit.

### C1.2 Tool notices (G4)

```dart
/// A word id and its arguments, put into words when read (C1.6).
@immutable final class KitText { const KitText(this.id, [this.args = const {}]);
  final String id; final Map<String, Object> args; }

/// A kit tool that has something to say on the status line.
abstract interface class ToolNotice {
  ValueListenable<KitText?> get notice;
}
```

- A kit's `Tool` may implement it. **`GuardedTool` forwards it:** it
  exposes `ValueListenable<KitText?>? get notice`, the inner tool's when it
  is a `ToolNotice`, read through the guard (a throw is one `hookFailed`
  diagnostic, then null).
- **`PlanController.toolNotice`** is a `ValueListenable<KitText?>` for the
  active tool, so a host composing `PlanCanvas` and panels itself gets it
  too.
- **`PlanEditor`'s status line keeps today's composition:** the label, then
  ` — n selected` with a selection, then ` — <notice>` with a notice, the
  notice put into words at read time in the current language (a language
  switch re-words it at once, today's).
- Users: the room tool's "already a room" (`text:architecture.roomOccupied`
  with `{name}`) and the dimension tool's would-be value (a `text:` id whose
  one argument is the formatted value).

### C1.3 Document preparation (G5)

`PlanKit.prepare: void Function(DraftDocument)?` runs **only on documents
the plan library makes**: the constructor's plan when it has no `json`, and
`newPlan`. It runs for every loaded kit, in load order, outside history,
before `clearHistory`, the save point and the unsettled baseline are taken.
It must be idempotent. **A loaded or imported plan is never changed** (today's
R-3: Open adds nothing, a file saves back byte-identical, and a plan without
the record draws its separators continuous). A throwing `prepare` is a
`hookFailed` diagnostic and the plan opens. User: the separator's DASHED
record at `ReservedHandles.dashedLinetype` (today's `ensureDashedLinetype`).

### C1.4 The symbol box and the placement transform move into the contract (G6)

`SymbolBox`, `isOrthonormal`, `boxOfLeaves`, `boxOfEntry`,
`servedTopOfEntry`, `boxOfDefinition`, `footprintOf` and `placementTransform`
move from `jet_cad_2d_plan/lib/src/symbols/` into `jet_cad_2d_kit` (pure
Dart, exported by both libraries), unchanged; the plan library imports them
from there, and its two copies of `isOrthonormal` (`move_resolver.dart:18`,
`symbol_section.dart:137`) are deleted. The wall-face provider needs the
neighbours' boxes (09c D4's edge snap) and the exact transform. The test
groups of these functions move to the contract's tests; the rest of the
plan's `symbol_box_test` stays. The stale `WallFaces` doc comment
(`symbol_box.dart:153`) is fixed in the move.

### C1.5 Live objects as a kit sees them (G7)

`PlanServices.liveTypeIdOf(Handle h)` answers the type id of a **live**
object and null for a frozen one (E2), one of a missing kit, or anything
else. Its name differs from the catalog's `typeIdOf`, which answers a frozen
object's id too (the panels, gates and colour row keep using that one). The
kit's caches decide "is this a live wall" by `liveTypeIdOf`, never by a
catalog of their own: a frozen wall is then absent from the room tool's
preview, the wall faces and the opening host scan exactly as it is absent
from `generate`.

The 2a final review's other recommendations for `PlanServices` (`isLocked`,
`allows`, a settings listenable; Appendix A's D-40) have no user in today's
behaviour (the wall tool consults no lock; the opening tools have no keys;
today's tools read their settings per event) and are not added: a later kit
that needs one adds it as an amendment.

### C1.6 Words with parameters (G8)

- A new namespace, **`text:<kit>.<id>`**, for messages, templates and every
  kit word that is not a tool, type or property name. Placeholders are
  `{name}`; `KitWords.text(String id, [Map<String, Object> args])` fills
  them, and a missing argument is left as written. A choice of words (start
  or end) is two `text:` ids, one passed as an argument to the other.
- `PlanKit.validate` and `validateHostWords` accept the namespace, so a host
  can translate a kit's messages. The conformance test (A16) checks that
  every locale's text of an id has the same placeholder set as English.
- **`KitWords.decimalSeparator`** is the UI language's separator, filled by
  the plan from its current `PlanStrings`, so a kit formats a number in the
  UI language (the axes line). Numbers that follow the page (the area, the
  value, the dimension notice) keep reading the page's separator, as today.
- **Numbered names move into the contract** with a signature that names no
  plan type:
  `int? numberedNameIndex(String name, Iterable<String Function(int n)> patterns, {String Function(String) fold})`.
  The room tool passes one pattern per locale of its merged words (host
  words included); the plan's layer panel passes one per built-in
  `PlanStrings` and the current one, as today.

### C1.7 Hidden fields (G9)

`PropertySpec.visible: bool Function(T)?`, evaluated inside `bind` (under
the guard, so the covariance trap never fires) into `PropertyField.visible`.
A hidden field takes no room. An `ActionProperty` whose gate the host
refuses is hidden, not read-only (today: a button the capabilities refuse is
not shown, S-11). Users: the door's flip buttons (hidden for a window or a
gap, and without `reshape`).

### C1.8 Grip refusals (Appendix A's D-43)

A kit grip fails in two places; each gets its own rule and its own
mutation.

1. **During the drag** (`GuardedGrips.drag` and `preview`): an
   `ArgumentError` from the kit gives no move for that pointer event (null
   or no preview), without marking the object's grips failed and without a
   diagnostic. Anything else keeps 2a's rule (the object has no grips for
   the document's life, one `hookFailed`).
2. **At the drop:** `plan.select` executes the drop command through
   `controller.execute`; its `false` (every refusal, `PlanLocked` included)
   cancels the drag without an exception. `StateError` subclasses
   (`NonLiveWriteError`, `PartialMutationError`) keep today's handling. This
   retires 2a's parked `GuardedTool._failed` rethrow for grip drops.

2a's P4 "grips" row is amended accordingly.

### C1.9 A plan the host builds in code

```dart
typedef PlanBuild = void Function(DraftDocument document, KitWords words);
PlanController({..., PlanBuild? build}); // ignored with json
void newPlan({String? decimalSeparator, PlanBuild? build});
```

The plan library makes the document (its measurer, its tables, its
components), runs every kit's `prepare` (C1.3), installs its own parametric
system with every loaded kit's types, then runs `build`, which adds objects
by command; the history is then cleared and the save point taken, so the
built plan opens clean with nothing to undo (today's sample). A throwing
`build` leaves the empty plan and is reported as a `hookFailed` diagnostic.
`words` are the controller's (English until a locale is reported; a host
wanting the sample in the UI language builds it with `newPlan` after
`reportLocale`). User: the sample flat (C3.7), in 3a's integration tests and
3b's demo.

### C1.10 A frozen object's references are locked (decision 6)

The lock set (2a P4, `kits/locks.dart`) gains, for every frozen object, the
live objects it references (`references`). An edit or delete of one is
refused with `PlanLocked` and the lock hint, like any lock. User: a frozen
opening's host wall, which would otherwise regenerate uncut beside the
frozen door and, deleted, leave the opening pointing at a dead handle. The
pinned test covers an edit and a delete.

### C1.11 A test double for kit authors

`package:jet_cad_2d_kit/testing.dart` exports a `FakePlanServices`
implementing `PlanServices` over a given document (a real `SpatialIndex`, a
camera at a given scale, words from a `KitNames`, settings from a map). It
moves with the contract, so a kit's tool and grip tests do not break when
the contract adds a member. The plan library's and the contract's existing
test-local fakes may be replaced by it.

### C1.12 Plan-library pins carried in

Two parked plan-library items are pinned in the C1 tasks, each with a test
and a mutation: `PlanShortcuts(shortcuts: false)` remounted on the same
controller does not reopen `idleKeys` (D-44); 2a's deferred minors of the
attachment registry (the provider kind read inside the guard, the guarded
dispose), the move resolver's branches (a scaled instance, a non-symbol, a
node reset, the definition box against the entry box) and `_open`'s
unoffered-kind report (D-45).

## C2. The package `jet_cad_2d_kit_architecture`

- **0.1.0, publishable**, `dart pub publish --dry-run` with 0 warnings.
  Depends on `jet_cad_2d_kit`, `jet_cad_2d` and `jet_cad_2d_flutter` only;
  its `jet_cad_2d` floor is the plan library's (the wave raises every floor,
  sub-project 4's release checklist).
- **Public surface, kept narrow:** `architectureKit` (the `PlanKit`); the
  six types' parameter classes (`BoxParams`, `WallParams`, `OpeningParams`,
  `SeparatorParams`, `RoomParams`, `DimensionParams`, their enums and ends)
  and the type id constants, so a host and 3b's demo can build a plan in
  code; `buildSampleFlat` (C3.7). Everything else is under `lib/src/`.

```
lib/jet_cad_2d_kit_architecture.dart
lib/src/
  kit.dart          architectureKit: 6 PlanTypes, 8 PlanTools, the provider,
                    words, the furniture source, prepare
  box/  wall/  opening/  separator/  room/  dimension/
                    each: params and type, geometry, grips, tool, properties
  attach/           WallFaces and the wall-face provider
  furniture/        the catalog (authoring language) and its names
  sample/           the sample flat
  words/            en, de, tr
tool/generate_furniture_library.dart
assets/library/furniture.jetlib  (+ its geometry snapshot)
example/
```

- **Ids** (A7): types `architecture.box|wall|opening|separator|room|dimension`;
  tools `architecture.box` (B), `.wall` (W), `.door` (D), `.window` (N),
  `.gap` (G), `.room` (M), `.separator` (S), `.dimension` (I). None of the
  letters is a generic tool's; `M` is also `plan.symbol`'s mirror key while
  that tool is active, which is not a conflict (2a P2).
- **Shared caches:** `WallBands`, `RoomInputs` and `WallFaces` are
  `PlanServices.shared` objects (per kit, per document, disposed with it),
  no longer shell fields. `WallBands` and `RoomInputs` keep today's
  invalidation exactly (the `changes` stream and the kit tools' explicit
  `invalidate()`). `WallFaces` also compares `document.commands.stateId`,
  because `plan.symbol`, a plan tool, no longer invalidates the bands after a
  placement (D-06).
- **Words:** today's architecture strings and the property words the
  specs add (kind, axes, End 1, End 2, name), in English, German and
  Turkish, under `tool:`, `type:`, `property:` and `text:` (C1.6: the five
  parameterised words, the end and face words, the sample's room names).
  The plan lists every id. The conformance test checks every locale
  complete.
- **The failure boundary (A9) holds for every hook** this kit adds:
  `prepare`, `build`, the notices, the `PlanObject` readers, the ranges,
  `visible`. The plan library's every-hook-throws test kit gains them (C1).

## C3. The six types

Each type is today's code moved, its ids renamed, its closed-list entries
turned into `PlanType`/`PlanTool` declarations. The algorithms and the
behaviour do not change (A12).

### C3.1 Box

`BoxParams(width, height)`; overlapping boxes subtract each other. Tool B.
Properties: width and height, lengths `> 0` (strict, in `write`). No grips
(today's).

### C3.2 Wall

`WallParams(sx, sy, ex, ey, thickness, justification)`; joins through
`neighbours`; cut by its openings (referrers); contributes places. Tool W
with settings (thickness, justification), the panel editing the tool's
settings while the tool is active (today's WS cases). The tool consults no
lock or layer (today's). Grips: two stretch grips moving the joined walls'
ends too. Properties: thickness (`isWallThickness`, strict, in `write`),
justification (a `ChoiceProperty`; today a `SegmentedButton`, a dropdown
under A4: test finders change, assertions do not).

### C3.3 Opening

`OpeningParams(host, position, width, kind, hinge, swing)`; `references:
[host]`. Tools D, N, G (one opening tool per kind, each with its width
setting), with no keys (today's). A host is a live wall
(`liveTypeIdOf`) on a visible, unlocked layer, read from the layer record as
today's `isUsableHost` does. Grips: one slide grip with edge snap; not moved
or rotated. Properties: the title by kind (`title`), width
(`isOpeningWidth`, strict, in `write`), position (`range`, C1.1), Flip hinge
and Flip swing (`ActionProperty`, `visible` for doors only, C1.7). A frozen
opening locks its host (C1.10).

### C3.4 Separator

`SeparatorParams(sx, sy, ex, ey)`; contributes places; drawn DASHED at
lineweight 35 on `ReservedHandles.dashedLinetype`, whose record the kit's
`prepare` adds to a new plan (C1.3). `exported: false` (today's
`exportOmitOwners`). Tool S band-trims through `RoomInputs`. Grips: two ends
with band trim.

### C3.5 Room

`RoomParams(seedX, seedY, name, label, color)`; reads places; `pageKey`
(unit, scale, decimal separator); dissolves; generates its tint fill, its
name and its area text. Tool M names a new room with a numbered name
(`text:architecture.roomName` with `{n}`, C1.6) and notices "already a room"
(C1.2). Grips: the label grip, back to automatic inside the aperture.
Properties: name (`TextProperty`, trimmed, empty refused), area
(`TextDisplay`, as drawn, '—' without a TEXT child), colour (`ColourTarget`:
the colour row lists kit targets before units, today's "rooms first, then
tables").

**The tint in service mode and export** is the room's own generated fill;
2b's R-16 dropped only test lines for want of a room, and C6 brings them
back.

### C3.6 Dimension

`DimensionParams(a, b, kind, offset)`, an end fixed or attached to a wall
face; `references` the attached walls; `pageKey`. Tool I with the would-be
value as notice (the page's separator, today's). Grips: offset and two ends;
an end re-attaches through the index while F3 is on. Properties: value
(`TextDisplay`, '—' without a TEXT child), kind (`ChoiceProperty`), axes
(`TextDisplay` over `world`, degrees with `KitWords.decimalSeparator`,
omitted when not turned), End 1 and End 2 (`TextDisplay`,
`text:architecture.endOnWall` with the start or end word and the side word,
or the fixed word).

### C3.7 The sample flat

`buildSampleFlat(DraftDocument document, KitWords words)` is a `PlanBuild`
(C1.9): today's `startupPlan` (`startup_plan.dart:70`) moved, without its
`prepareDocument`, its own parametric system and its `clearHistory`, which
the plan library now does. It adds, by command in source order (draw order
is reading order, as today's `_Pen`), nine walls, seven doors, eight windows,
a column, a separator, rooms named in the given words
(`text:architecture.sample.*`, `sampleBedroom` with `{n}`), five dimensions
and eight furniture fills (hand-drawn fills, not library symbols, as today),
and sets the page (A4 landscape at 1:50, the separator from
`words.decimalSeparator`). Its users: the integration tests (C6), 3b's demo,
later the README pictures (A11). The kit's own `startup_plan_test` port runs
it on a document with a parametric system over the kit's types, built by
the test.

## C4. The furniture library

- The 41 symbols are rewritten in the authoring language (`CatalogSymbol`,
  the shared shape helpers in `authoring/shapes.dart`); the generator runs
  under `dart run` and writes `assets/library/furniture.jetlib` and its
  geometry snapshot; the conformance test (A16) runs on the committed
  library.
- **Keys:** `architecture.` followed by today's key, at `@1` (umbrella
  decision 9: no old plan is read, so versions restart). `armchair` has one
  segment and becomes `architecture.armchair.single`.
- **Behaviour is fields** (A5): exactly the symbols of today's D9
  against-the-wall set (30, `furniture_library_test.dart:352-358`) carry
  `attachTo: ['wall-face']`; the six families (`kitchen-base`, `bed-double`,
  `bed-single`, `wardrobe`, `sofa`, `desk`) are `family` fields; tags are
  search words only.
- **The five dining tables are plain symbols** (decision 3): no
  `UnitComponent`.
- Names in English, German and Turkish; categories under
  `category:architecture/<cat>`.
- The source is a `bundledLibrary` over the package's asset key, and the
  kit's `symbols` list carries it.

## C5. The wall-face provider

- `kind: 'wall-face'`; its targets are the straight runs of the live walls'
  faces (today's `WallFaces` over `WallBands`), and its neighbours every
  placed symbol with a box (C1.4).
- Today's `attachToWall` is the oracle (09c D4: face pick, hold check,
  rotation, centre, edge snap to run ends and neighbours, clamp; F-7's
  `keep`; under `mayRotate: false` only a face the symbol already faces).
  The capture and keep distances are today's, not the plan test kit's
  inverted hysteresis (D-07).
- A wall on a hidden or locked layer offers no face (today's opening-host
  rule, SS17).
- Its tests are 09c's, placed by C7's rule (in the kit where they use only
  the kit, the contract, the engine and the Flutter layer; in C6 where they
  use `placeSymbol`, `PlanMoveResolver` or another plan-library name).

## C6. The integration package `jet_cad_2d_integration`

- `publish_to: none`, a workspace member. Depends on `jet_cad_2d_plan` and
  `jet_cad_2d_kit_architecture` (sub-project 4 adds the restaurant kit). Its
  name is not a kit's (A1's check does not bind it): it imports the plan
  library and the kit together, as a host does, and **only through their
  public libraries** (an import of `src/` fails `implementation_imports`).
- `lib/` holds its own fixtures, built over the public API (the plan's test
  harnesses are not importable): a walled room, a wall with a door, a
  controller over the kit, a controller over the sample flat
  (`PlanController(kits: [architectureKit], build: buildSampleFlat)`).
- `test/` holds every test that needs the kit inside the plan library's
  widgets or names: the tools on `PlanCanvas`, the property panel's kit
  sections, the layer rules for live objects, grips through `plan.select`,
  the wall attachment end to end, the export of rooms and separators, and
  the rows 2a and 2b left to sub-project 3 (Appendix A).
- **R-16's lines come back here, not in the plan library's tests:** the
  plan's `unit_fill_test`, `unit_colour_export_test` and zone fixture stay
  domain-free; this package carries TF1, TF3 and TF7 with the room and its
  tint (TF3's count back to 6), EX2, EX3 and EX5's tint and room lines, and
  CZ1's room named `7`.
- **The paint-allocation invariant** runs here over the sample flat, so the
  package's tests run with `--enable-vmservice`.
- Its own CI job: `flutter test --enable-vmservice`, `flutter analyze`, the
  format check.

## C7. Ports and their rulings

- **The rule (A12):** a ported test keeps its assertions; fixtures, names
  and ids may change.
- **Where a ported test runs:** in the kit when every name it uses is the
  kit's, the contract's, the engine's or the Flutter layer's (with
  `FakePlanServices`, C1.11, for tools and grips); in C6 when it uses a
  plan-library name (`PlanCanvas`, `PlanEditor`,
  the panels, `placeSymbol`, `PlanMoveResolver`, the controller). A file
  may split by case. The plan assigns every file or case by this rule.
- **Known classes of change**, recorded as rulings in the plan, not left to
  tasks:
  1. **Ids:** `floor_planner.<type>` to `architecture.<type>`, furniture keys
     to C4's, word ids to C2's.
  2. **Tags to fields** (A5, umbrella decision 8): an assertion over the
     `against-wall` or `family:` tag asserts the same set over `attachTo` or
     `family`; "behaviour tags come last" is retired (tags carry no
     behaviour).
  3. **Widgets that changed form** (a `SegmentedButton` now a dropdown, A4):
     finders change, the asserted values do not.
- **Not ported, premise impossible under umbrella decision 9** (no plan of
  `jet_cad_floor_plan` is read): the furniture library's pre-09c fixture
  tests, its "14 new symbols carry their names; the old keys stay"
  (`entries.length - newNames.length == 27`, :421-431), and
  `wall_attach_end_to_end_test.dart` WE2.
- **Dropped on the human's word** (decision 7): `seating_test.dart` SE10,
  SE10b, SE11; `furniture_library_test.dart`'s seating group (:605-628).
  SE8 (placement copies the definition with its unit) is generic: if 2b's
  placement tests do not already pin it, it is ported over the plan's test
  unit kit in a C1 task.
- **Restored:** `selection_page_test.dart` SE13, SE15, SE16 were ported with
  W→B and 'Wall'→'Box' over the box stand-in; their Wall assertions come
  back in C6.
- Every other ported test that cannot keep an assertion is a ruling in the
  ledger, with its reason and cost.

## Amendments to other specs

Each is one line in the named spec's Amendments section, written in the C1
task that lands it:

- **Umbrella:** A13's "the demos" and A11's `apps/floor_planner` →
  `apps/architecture_demo` move to sub-project 3b (decision 1).
- **Contract spec:** K4 gains the `text:` namespace and placeholders
  (C1.6); the contract's surface gains the symbol box family and
  `placementTransform` (C1.4), `numberedNameIndex` (C1.6), `KitText` and
  `ToolNotice` (C1.2), `PlanObject`, `TextDisplay`, `range`, `visible`,
  `PlanSection` (C1.1, C1.7), `PlanKit.prepare` (C1.3),
  `PlanServices.liveTypeIdOf` (C1.5), `KitWords.text` and `decimalSeparator`
  (C1.6), and the `testing.dart` library (C1.11).
- **2a:** P3's property specs and section builder (C1.1, C1.7); P2's tool
  notice and status line (C1.2); P4's new plan and the kit's `prepare`
  (C1.3), the grips row (C1.8), the lock set (C1.10); the controller's
  `build` (C1.9).
- **2b:** none expected; a C1 task that touches a 2b rule adds its line.

## Tests

- **The testing bar** (CLAUDE.md): a new test lands only with a named
  mutation that turns it red; ported tests are the oracle and bring their
  own history. Every C1 amendment has its mutants.
- **The kit's own tests** (`flutter test` in the kit), placed by C7's rule:
  geometry, room tracing, opening cuts, dimension attachment, every type's
  `generate` through the engine's `ParametricSystem`, grips and tools over
  `FakePlanServices`, property specs over values, the provider's pure
  cases, the furniture library and the conformance test, the sample flat.
- **The integration tests** (C6).
- **The non-negotiables:** the engine's query-allocation invariant and the
  plan library's paint-allocation invariant stay green, the latter also with
  the kit loaded over the sample flat (C6); draw order is ascending handle;
  geometric decisions use `Tolerance`.
- **The failure boundary:** the plan library's every-hook-throws test kit
  covers C1's new hooks.

## Order of work

1. The contract amendments (C1.1-C1.12), each with its test-kit tests and
   mutants, and their amendment lines.
2. The scaffold: the kit package, the integration package, their CI jobs,
   `check_kit_deps` over the new kit, the words, `prepare`.
3. The types in dependency order: box; wall (geometry and bands, then type,
   grips, tool and settings); opening (cut geometry, then type and grips,
   then the three tools); separator; room (trace, inputs and label, then type
   and grips, then tool and notice); dimension (geometry and attachment, then
   type and grips, then tool and notice).
4. The property sections' parity (WS, V-5's wall, room and dimension parts,
   `visible`, the room colour).
5. The furniture library.
6. The wall-face provider and the 09c ports.
7. The sample flat and the integration rows (Appendix A).
8. The gate, the CHANGELOGs, the results note, the whole-branch review and
   its fix wave, the ledger archived onto the branch.

## Exit gate

- `jet_cad_2d`, `jet_cad_2d_flutter`, `jet_cad_2d_kit`, `jet_cad_2d_plan`
  (`--enable-vmservice`), `jet_cad_2d_kit_architecture` and
  `jet_cad_2d_integration` (`--enable-vmservice`): test, analyse and format
  green; the engine's two standing hash lines stay the only failures.
- Dry-runs of `jet_cad_2d_kit`, `jet_cad_2d_plan` and
  `jet_cad_2d_kit_architecture` with 0 warnings.
- `tool/ci`'s checks green, `check_kit_deps` covering the new kit.
- Every Appendix A row closed: ported (with its destination), ruled (with
  its ruling), or carried to 3b or 4 by name.
- Every new test with its mutation; every amendment line written.
- One Opus review of the whole branch and its fix wave; STATUS and the
  results note updated; the ledger archived onto the branch as its last
  commit.
- The old packages stay untouched (A12).

## Out of scope

- **3b:** `apps/architecture_demo` (the document flows, files, macOS and web,
  the app's tests), its own spec. The human is told when it runs.
- **Sub-project 4:** the restaurant kit, `apps/restaurant_demo`, the
  pictures, the host guide, the parity table (A14), the CI moves, removing
  the old packages, raising the dependency floors.
- `PlanServices.isLocked`, `allows` and a settings listenable (C1.5).
- Opening styles as data (umbrella, out of scope).
- Showing the engine's `diagnose` output in the UI (today's planner does not
  either).

## Risks

- **The size.** About 559 cases to port and about 10.8k lines to move.
  Appendix A is the guard: a row without an owner is a defect of this spec.
- **The amendments change the contract under the plan library's 1,519
  tests.** C1 lands first, each change with its mutants, before a kit task
  starts.
- **The hot path.** The guarded wall and room `generate` run on every
  regeneration; the allocation invariants run with the kit loaded.
- **The words.** Five parameterised words and the start/end choice move
  from Dart methods to templates; the conformance test's placeholder check
  is the guard against a locale that drops an argument.

## Appendix A. Everything carried to sub-project 3, with its owner

From two read-only audits on `7e65905b` and the spec review (2b's lesson: a
deferral written in a brief never reached the next spec). "3a" names this
spec's section; "3b" and "4" carry the row into their specs by name. Where a
row says "kit" or "C6", C7's placement rule decides per case.

### A.1 Deferrals (D-01 to D-50)

| # | Item | Owner |
|---|---|---|
| D-01 | `wall_attach_test` (23), `wall_faces_test` (9), `wall_attach_property_test` (2), `symbol_move_test` (6) | 3a C5: `wall_faces_test` kit; `wall_attach_test` and `wall_attach_property_test` C6 (they call `placeSymbol`); `symbol_move_test` C6 (`PlanMoveResolver`) |
| D-02 | `symbol_place_tool_test.dart:1368-1740`, the 09c D6 group (15) | 3a C6 |
| D-03 | `host/against_wall_rotate_test` (3, F-7) | 3a C6 |
| D-04 | app `wall_attach_end_to_end_test` WE1; `symbol_shell_test` SS16, SS17 | 3a C6; WE2 not ported (C7) |
| D-05 | `editor_tools_review_test`: the north-wall mirror case, O13a, O13b | 3a C6 |
| D-06 | Bands stale after a placement now that `plan.symbol` cannot invalidate them | 3a C2 (`WallFaces` compares `stateId`) |
| D-07 | The plan test kit's inverted hysteresis not copied | 3a C5 |
| D-08 | The provider fits `AttachmentProvider`; the `mayRotate: false` rule | 3a C5 |
| D-09 | The `isOrthonormal` copies | 3a C1.4 |
| D-10 | Stale `WallFaces` doc comment, `symbol_box.dart:153` | 3a C1.4 |
| D-11 | `furniture_library_test` (34) | 3a C4, kit (C7's rulings and drops) |
| D-12 | `symbol_search_test.dart:82-164, 191-267` (12, the real library) | 3a C6 |
| D-13 | `symbol_box_test.dart:321-339, 391-410` (3, the asset's boxes; `boxOfEntry`, `placeSymbol`) | 3a C6 |
| D-14 | `symbol_end_to_end_test` (2, `bed.double`) | 3a C6 |
| D-15 | `package_assets_test` PA2, PA3 (the library from a package-key bundle) | 3a C4, kit; PA4 (export font) 4 |
| D-16 | Restaurant tests over the furniture library (RL15, SC1-SC2, SNL) | 4 |
| D-17 | `seating_test` SE8-SE11 | SE10, SE10b, SE11 dropped (decision 7); SE8 3a C1 (C7) |
| D-18 | The old `example_test` | 3a C2 (`example/` and its test) |
| D-19 | The six types' test files (54 files, 353 cases) | 3a C3; A.2 |
| D-20 | `selection_panel_test` WS1-WS11; `selection_page_test` SE13, SE15, SE16's Wall assertions | 3a C6 |
| D-21 | `color_picker_test` CP2, CP1's separator line | 3a C6 |
| D-22 | `touch_tools_test` TD1 (Room tool) | 3a C6 |
| D-23 | `planner_shell_test`'s three sample-flat cases | 3a C6 (C1.9's sample) |
| D-24 | DT1, LK2, OV-H, PW1/PW2's Wall words, NN3, VW3, NS3's room label | 3a C6 |
| D-25 | The architecture words | 3a C2, C1.6 |
| D-26 | The eight palette rows and their letters | 3a C2 (kit), C6 (palette) |
| D-27 | The room and dimension status notices | 3a C1.2, C3 |
| D-28 | DASHED; `new_document_test` ND1-ND3 and its three registration cases (:98-113) | 3a C1.3, C3.4; the DASHED lines and "a live page and live walls" C6; the page, unit, page-only and catalog-only lines: C1.3's task ports them to the plan where no twin exists |
| D-29 | `layers/tools_layer_test` (10), `opening_host_layer_test` (6), `attach_layer_test` (2); the app's layer-picker wall case | 3a C6 |
| D-30 | The separator not exported | 3a C3.4, C6 (PDF and PNG) |
| D-31 | The room's colour target; `room_color_test`, `room_tint_test` | 3a C3.5, kit and C6 |
| D-32 | `decimal_separator_test` (6) | 3a C6 |
| D-33 | `delete_components_test` (3) | 3a C6 |
| D-34 | `startup_plan_test` (14), `intersection_snap_test` (1) | 3a C3.7: `startup_plan_test` kit, `intersection_snap_test` C6 |
| D-35 | TF1, TF7 room and tint lines | 3a C6 |
| D-36 | TF3's `hasLength(5)` back to 6 | 3a C6 |
| D-37 | EX2, EX3, EX5 tint and room lines; the premises' `R` | 3a C6 |
| D-38 | The zone fixture's room named `7`; CZ1 | 3a C6 |
| D-39 | 2a's room rows over the box kit's colour target | 3a C6 |
| D-40 | `PlanServices.isLocked`, `allows`, a settings listenable | Not added (C1.5: no user today) |
| D-41 | `PropertySectionBuilder` without handle or services | 3a C1.1 |
| D-42 | The `jet_cad_2d: ^0.7.2` floors predate E1-E5 | 4 (the wave) |
| D-43 | `GuardedTool._failed`'s rethrow for grip drops; the `_first` catch-all's probe | 3a C1.8 (the catch-all's probe cost: a ruling in C1.8's task) |
| D-44 | `PlanShortcuts(shortcuts: false)` remounted on the same controller | 3a C1.12 |
| D-45 | 2a's deferred minors: the registry, the move resolver, `_open` | 3a C1.12 |
| D-46 | Section titles by `title`, `ValueDisplay`'s units, `ActionProperty` never exercised | 3a C3, C6 |
| D-47 | A16 conformance for the kit | 3a C2, C4 |
| D-48 | The nine closed lists, each a kit hook | 3a C3, C6 |
| D-49 | Who owns `apps/architecture_demo` | 3b (decision 1) |
| D-50 | 2b's host-API differences | 4 |

### A.2 `jet_cad_floor_plan/test` files not fully ported

The six types' files (D-19). Each goes to the kit or to C6 by C7's rule; the
cases that pump `PlannerShell`, `SelectionPanel` or `PlannerView` today are
C6 (the review counted them in `dimension_paint`, `dimension_tool`,
`opening_grips`, `opening_kink`, `opening_paint`, `opening_symbol`,
`opening_tool`, `room_grips`, `room_paint`, `room_tool`, `separator_tool`,
`wall_grips`, `wall_paint`, `wall_tool`, besides the `_panel`, `_shell` and
`planner_box` files):

- box: `box_test` (6), `planner_box_test` (6).
- wall: `wall_bands`, `wall_geometry`, `wall_grips`, `wall_paint`,
  `wall_params`, `wall_regen`, `wall_tool` (73).
- opening: `opening_cost`, `_cut`, `_end_drag`, `_geometry`, `_grips`,
  `_kink`, `_object`, `_obstacle`, `_paint`, `_panel`, `_params`,
  `_symbol`, `_tool` (85).
- separator: `separator`, `separator_tool` (10).
- room: `room_color`, `_cost`, `_diagnostics`, `_dissolve`, `_follow`,
  `_grips`, `_inputs`, `_label`, `_localise`, `_object`, `_paint`, `_panel`,
  `_tie`, `_tint`, `_tool`, `_trace` (100).
- dimension: `dimension_attach_points`, `_attach`, `_follow`, `_format`,
  `_fuzz`, `_grips`, `_layout`, `_object`, `_paint`, `_panel`, `_params`,
  `_rotate`, `_shell`, `_tool` (73).

Other architecture files: as in A.1 (D-02 to D-05, D-11 to D-15, D-20 to
D-24, D-28, D-29, D-32 to D-38), and `planner_grips_test` A1-A4 (stretch, F3
and undo mid-drag on the sample flat's walls): 3a C6. `editor_panels_test`'s
architecture remainder (T5-f, the Wall-tool settings case, "a table, a wall,
a room and a dimension each selectable", R-3, R-4) and `keyboard_focus_test`'s
wall cases ("Wall tool chosen by the host", DS2, DS5, R-3 RP5): 3a C6.

Carried by name to sub-project 4's parity table (no architecture content,
or generic with no owner today): `host/camera_test` CM8-CM14, CM16, CR1-CR6,
UC1, UC2; `host/controller_test` CZ2-CZ6, CV1-CV3, CS1-CS4;
`host/page_flows_test` PF1; `host/editor_tools_test` T4-c, T4-d, T4-h, T4-i;
`host/editor_capabilities_test` EC3, EC4, EC6, EC7, PC8;
`host/editor_panels_test` T5-h; `host/seams_test` SM1-SM3;
`widget_theme_test` (7); `symbols/symbol_component_test` SC7-SC12;
`package_assets_test` PA4.

### A.3 `apps/floor_planner/test`

`wall_attach_end_to_end_test` WE1, `symbol_shell_test` SS16 and SS17, and
`layers/layer_picker_test`'s wall case: 3a C6. Everything else (the document
commands, exit, files, host, open (DO3 included, which C1.3 keeps green),
replace, save, separator, settle, export and print flows,
`symbol_library_loader_test`, `symbol_shell_test` SS1-SS15, the end-to-end
tests, `app_words_test`, `export_font_test` EF1-EF3, EF9-EF12): 3b.

## Revision history

- **Revision 1** (`565b233b`): the design approved in chat.
- **Revision 2:** an independent Opus review's findings applied (each
  checked against the code) and the human's decisions 6 and 7.
  - B1: `prepare` runs only on plans the library makes (C1.3), keeping R-3.
  - B2: the plan's `build` seam (C1.9), so the sample flat has a document.
  - The status line keeps today's composition, and the guard forwards
    notices as word ids (C1.2).
  - The object reaches fields through `bind`; settings have none (C1.1).
  - `KitWords.decimalSeparator`, `text:` for host words, choices as two ids
    (C1.6).
  - `isLocked`, `allows` and a settings listenable are not added (C1.5).
  - Grip refusals are split by where they fail (C1.8).
  - The frozen object's references are locked (C1.10).
  - `FakePlanServices` (C1.11) and the plan-library pins (C1.12).
  - 30 against-the-wall symbols.
  - Owners corrected and C7's placement rule added.
  - The missing rows, and the amendment lines for every other spec.
