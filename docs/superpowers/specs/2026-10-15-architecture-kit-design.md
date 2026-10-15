# The architecture kit (sub-project 3a) — design

**Date:** 2026-10-15. **Status:** revision 1, written after the human
approved the design section by section in chat; awaiting the human's review
of this file.

**Binds:** the umbrella spec
[2026-10-13-kit-architecture-design.md](2026-10-13-kit-architecture-design.md)
(A1-A17), the contract spec
[2026-10-13-kit-contract-design.md](2026-10-13-kit-contract-design.md)
(K1-K9), the 2a spec
[2026-10-14-plan-library-design-mode-design.md](2026-10-14-plan-library-design-mode-design.md)
(P1-P7, E1-E4) and the 2b spec
[2026-10-14-plan-library-service-mode-design.md](2026-10-14-plan-library-service-mode-design.md)
(S1-S5, E5). Their rules hold here unless a section below says otherwise.
Section C1 amends the 2a and 2b specs, as both their Risks sections foresaw
("Sub-project 3's six types are the real test. A field they need goes into
this spec as an amendment before the wave publishes 0.1.0").

**Branch:** `feat/architecture-kit`, cut by hand from `main` at `7e65905b`
(`origin/main` at `651e3d09`, an ancestor), worktree
`.claude/worktrees/architecture-kit`.

## Decisions taken in the brainstorm (the human, 2026-10-15)

1. **Sub-project 3 is split in two** (*"3a kit, 3b demo"*): 3a is this
   spec, the contract's amendments, `jet_cad_2d_kit_architecture` and the
   tests that run the kit inside the plan library; 3b is
   `apps/architecture_demo`, with its own spec. The human is told when the
   demo runs on the new packages at the end of 3b. This settles the
   conflict between umbrella A13 (the demos in sub-project 4) and STATUS
   (the demo at the end of sub-project 3): `apps/architecture_demo` is 3b's;
   `apps/restaurant_demo` stays sub-project 4's.
2. **The integration tests live in their own unpublished package**
   (*"Ayrı özel paket"*): `packages/jet_cad_2d_integration` (C6), after the
   human asked what it is and accepted the answer (*"uygun, devam et"*).
3. **The furniture library's dining tables are plain symbols, not units**
   (*"Hayır, düz sembol"*). The architecture kit draws buildings and
   furniture; serving is the restaurant kit's. Today's `seating_test.dart`
   SE10, SE10b and SE11 (the dining tables servable, their v1 to v2 copy)
   are dropped on the human's word (A14); SE8's generic half is C7's.
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

## Facts (at `7e65905b`, read from the code)

- **The contract** (`packages/jet_cad_2d_kit/lib/src/kit/`):
  - `PlanKit(id, version, symbols, types, tools, attachments, names)`
    (`plan_kit.dart:16-26`). No document-setup hook.
  - `PlanType<T>(id, fromJson, parametric, grips, properties, section,
    title, colour, exported)` (`plan_type.dart:36-48`).
  - `PropertySectionBuilder<T> = Widget Function(BuildContext, T value,
    void Function(T) commit, KitWords words)` (`plan_type.dart:24-25`): the
    escape hatch sees only the component.
  - `PlanTool(id, icon, letter, needs, settings, create)`
    (`plan_tool.dart:36-62`): no notice channel.
  - `PlanServices`: `document`, `index`, `camera`, `objectSnap`,
    `attachments`, `words`, `settingsOf`, `shared`, `symbolDefinition`,
    `symbolsState` (`plan_services.dart:86-130`). No `typeIdOf`, no frozen
    or locked set, no `allows`, no settings listenable.
  - Property specs (`properties.dart`): `LengthProperty` (constant
    `min`/`max`), `AngleProperty`, `NumberProperty`, `ChoiceProperty`,
    `ToggleProperty`, `TextProperty`, `ValueDisplay<T>(read: double
    Function(T), unit)`, `ActionProperty`; `enabled` greys a field, `gate`
    makes it read-only; no `visible`. A `write` that throws `ArgumentError`
    or `StateError` is a silent refusal
    (`jet_cad_2d_plan/lib/src/panels/plan_property_panel.dart:497-525`).
  - `KitNames` namespaces: `symbol:`, `category:`, `tool:`, `type:`,
    `property:`, `unit:`; anything else is `unknownWordId`
    (`plan_kit.dart:80-93`). Words are flat strings.
  - `AttachmentProvider { kind; attach(AttachmentQuery) }`
    (`attachment.dart:11-18`); `SymbolComponent.attachTo` and `family`
    (`model/symbol_component.dart:99-102`).
  - The symbol key rule: a kit id and two or more dot segments
    (`model/kit_ids.dart`).
- **The plan library** (`packages/jet_cad_2d_plan`):
  - `SymbolBox`, `boxOfDefinition` (`lib/src/symbols/symbol_box.dart:18,
    154, 170`) and `placementTransform` (`lib/src/symbols/symbol_placer.dart:59`)
    are plan-internal; `symbol_section.dart:132-136` copies `isOrthonormal`
    from today's `wall_attach.dart:402` "for sub-project 3".
  - `newPlanDocument` drops today's DASHED linetype record
    (`controller/new_plan.dart:3-4`, "the separator's, sub-project 3").
  - `PlanEditor`'s status line shows the tool label and the selection count
    only (`editor/plan_editor.dart:514-519`).
  - No app or package depends on it; its `example/` uses no kit, and none of
    its test kits draws walls.
- **The dependency check** (`tool/ci/lib/kit_deps.dart`) reads every Dart
  file of a `jet_cad_2d_kit_*` package, `test/` included; it does not bind a
  package of another name.
- **The engine** reserves `ReservedHandles.dashedLinetype = Handle(6)`
  (`jet_cad_2d/lib/src/document/style.dart:121`).
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
  62), the furniture catalog (`furniture_catalog.dart` 675,
  `furniture_names.dart` 113, `build_library.dart` 87, the generator and
  `assets/library/furniture.jetlib`: 41 symbols, 6 categories, 6 families,
  27 against the wall, 5 dining tables carrying `jetcad.seating@2`), and
  the sample flat (`startup_plan.dart` 422).
- **Shared caches today** are shell fields: `WallBands` (shared by the wall
  and opening tools and `WallFaces`), `RoomInputs` (room and separator tools,
  separator grips) (`planner_shell.dart:428-497`).
- **Words today** (`l10n/strings.dart`): about 45 architecture word ids in
  English, German and Turkish, four of them with parameters (`roomName(n)`,
  `roomOccupied(name)`, `axesTurned(degrees)`, `endOnWall(wall, atStart,
  side)`), and the sample flat's room names.
- **What is owed** (Appendix A): of `jet_cad_floor_plan/test`'s 165 files
  and 1,674 cases, about 559 architecture cases are not ported; 68 of
  those files are named by no note, ledger or brief.

## Purpose

The first real kit. It moves today's walls, openings, separators, rooms,
dimensions, boxes, furniture and wall attachment onto the contract,
unchanged in behaviour, and is the test the contract was not given in 2a
and 2b: every field the six types need lands in the contract before 0.1.0.

## C1. The contract amendments

Each amendment is code in `jet_cad_2d_kit` or `jet_cad_2d_plan`, pinned by
the plan library's own test kits (not by the architecture kit) with a named
mutation, and recorded as an amendment line in the 2a or 2b spec. All of
them come before the first kit task (decision 4).

### C1.1 An object view for properties and sections (G1-G3, 2a's D-41)

```dart
/// The object a property or section is shown for: read-only.
abstract interface class PlanObject {
  DraftDocument get document;
  Handle get handle;
  Transform2 get world; // the object's accumulated transform
}
```

- **`TextDisplay<T>(id, read: String? Function(T value, PlanObject object))`**,
  a read-only line beside `ValueDisplay`: the room's area and the
  dimension's value "as drawn" (today's `_areaOf`, `_valueOf`: the generated
  TEXT child's string), the dimension's axes line (the group's world
  rotation). Null hides the line.
- **`LengthProperty.range: (double, double) Function(T, PlanObject)?`**,
  checked with the constant `min`/`max`: an opening's position in `[0, L]`,
  `L` its host wall's centreline length. A value outside is a refusal (the
  field shows the stored value), as a throwing `write` is.
- **The escape hatch takes one context:**
  `typedef PropertySectionBuilder<T> = Widget Function(BuildContext, PlanSection<T>)`
  with `PlanSection<T> { T value; void Function(T) commit; KitWords words;
  PlanObject object; PlanServices services; }`. A later field joins the
  context without breaking a kit.

### C1.2 Tool notices (G4)

```dart
/// A kit tool that has something to say on the status line.
abstract interface class ToolNotice {
  ValueListenable<String?> get notice; // already in the UI language
}
```

A kit's `Tool` may implement it. `PlanEditor`'s status line shows the active
tool's notice when it is non-null, else today's label. Reading it is
guarded like every kit hook (A9). Users: the room tool's "already a room"
and the dimension tool's would-be value (today `planner_shell.dart:672-684,
989-1011`).

### C1.3 Document preparation (G5)

`PlanKit.prepare: void Function(DraftDocument)?` runs outside history on
`newPlan`, after `load` and after an import, for every loaded kit, in load
order. It must be idempotent (a loaded plan may already hold what it adds).
A throwing `prepare` is a `hookFailed` diagnostic and the plan opens. User:
the separator's DASHED linetype record at `ReservedHandles.dashedLinetype`
(today's `ensureDashedLinetype`, `new_document.dart:22`).

### C1.4 The symbol box and the placement transform move into the contract (G6)

`SymbolBox`, `boxOfDefinition`, `placementTransform` and `isOrthonormal`
move from `jet_cad_2d_plan/lib/src/symbols/` into `jet_cad_2d_kit` (pure
Dart, exported by both libraries), unchanged; the plan library imports them
from there. One owner for each rule: the wall-face provider needs the
neighbours' boxes (09c D4's edge snap) and the exact transform, and
`symbol_section.dart`'s copy of `isOrthonormal` goes. Their tests move with
them. The stale `WallFaces` doc comment (`symbol_box.dart:153`) is fixed in
the move.

### C1.5 What a kit may ask about the plan (G7, 2a's D-40)

`PlanServices` gains:

| Member | What it answers |
|---|---|
| `String? typeIdOf(Handle h)` | The type id of a **live** object, null for a frozen one (E2), one of a missing kit, or anything else. |
| `bool isLocked(Handle h)` | Whether the object sits under a locked layer or a lock (a wall tool neither joins nor snaps to a locked wall). |
| `bool allows(PlanGate gate)` | The host's permissions (an opening tool's flip keys respect `mirror`, as `plan.symbol` does). |
| `ValueListenable<S> settingsListenable<S extends Object>(String toolId)` | The tool's own settings, so a ghost re-renders on a panel change (own tools only, as `settingsOf`). |

The kit's caches decide "is this a live wall" by `typeIdOf`, never by a
catalog of their own: a frozen wall is then absent from the room tool's
preview, the wall faces and the opening host scan exactly as it is absent
from `generate`.

### C1.6 Words with parameters (G8)

- A new namespace, **`text:<kit>.<id>`**, for messages and templates.
  Placeholders are `{name}`; `KitWords.text(String id, Map<String, Object>
  args)` fills them, and a missing argument is left as written.
- `PlanKit.validate` accepts the namespace; the conformance test (A16)
  checks that every locale's text of an id has the same placeholder set as
  English.
- `numbered_names.dart` (a free numbered name: "Room 3") moves into the
  contract, so the room tool and the plan library share it.

### C1.7 Hidden fields (G9)

`PropertySpec.visible: bool Function(T)?`. A hidden field takes no room.
An `ActionProperty` whose gate the host refuses is hidden, not read-only
(today: a button the capabilities refuse is not shown, S-11). Users: the
door's flip buttons (hidden for a window or a gap, and without `reshape`).

### C1.8 Grip drags refuse as writes do (2a's D-43)

An `ArgumentError` or `StateError` thrown by a kit grip during a drag is a
refusal: the drag keeps its last accepted state and nothing is reported.
Anything else stays a `hookFailed` diagnostic. This retires 2a's parked
`GuardedTool._failed` rethrow for grips (wall-endpoint grips edit a
neighbour's parameters and the parameters refuse bad values).

## C2. The package `jet_cad_2d_kit_architecture`

- **0.1.0, publishable**, `dart pub publish --dry-run` with 0 warnings.
  Depends on `jet_cad_2d_kit`, `jet_cad_2d` and `jet_cad_2d_flutter` only;
  its `jet_cad_2d` floor is the plan library's (the wave raises every floor,
  sub-project 4's release checklist).
- **Public surface, kept narrow:** `architectureKit` (the `PlanKit`); the six
  types' parameter classes (`BoxParams`, `WallParams`, `OpeningParams`,
  `SeparatorParams`, `RoomParams`, `DimensionParams` and their enums and
  ends) and the type id constants, so a host and 3b's demo can build a plan
  in code; `buildSampleFlat` (C3.7). Everything else is under `lib/src/`.

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
  letters is a generic tool's.
- **Shared caches:** `WallBands`, `RoomInputs` and `WallFaces` are
  `PlanServices.shared` objects (per kit, per document, disposed with it),
  no longer shell fields. A caching provider reads
  `document.commands.stateId` (2a's D-06).
- **Words:** today's about 45 ids in English, German and Turkish, under
  `tool:`, `type:`, `property:` and, for the four with parameters,
  `text:architecture.*` (C1.6). The conformance test checks every locale
  complete.
- **The failure boundary (A9) holds for every hook** this kit adds:
  `prepare`, the notices, the `PlanObject` readers, the ranges, `visible`.
  The plan library's every-hook-throws test kit gains them (C1).

## C3. The six types

Each type is today's code moved, its ids renamed, its closed-list entries
turned into `PlanType`/`PlanTool` declarations. The algorithms do not change
(A12).

### C3.1 Box

`BoxParams(width, height)`; overlapping boxes subtract each other. Tool B.
Properties: width and height, lengths `> 0`. No grips (today's).

### C3.2 Wall

`WallParams(sx, sy, ex, ey, thickness, justification)`; joins through
`neighbours`; cut by its openings (referrers); contributes places. Tool W
with settings (thickness, justification), the panel editing the tool's
settings while the tool is active (today's WS cases). Grips: two stretch
grips moving the joined walls' ends too. Properties: thickness (today's
`isWallThickness`), justification (a `ChoiceProperty`; today a
`SegmentedButton`, a dropdown under A4: test finders change, assertions do
not).

### C3.3 Opening

`OpeningParams(host, position, width, kind, hinge, swing)`; `references:
[host]`. Tools D, N, G (one opening tool per kind, each with its width
setting); a host is a live wall on a visible, unlocked layer (today's
`isUsableHost`, now through `typeIdOf` and `isLocked`). Grips: one slide grip
with edge snap; not moved or rotated. Properties: the title by kind
(`title`), width (`isOpeningWidth`), position (`range`, C1.1), Flip hinge
and Flip swing (`ActionProperty`, `visible` for doors only, C1.7).

**A frozen opening (E2)** is absent from its host's survey, so a live host
regenerates uncut beside it. This is accepted (a frozen object is read-only
and drawn as saved) and pinned by a test, so a change of it is a decision.

### C3.4 Separator

`SeparatorParams(sx, sy, ex, ey)`; contributes places; drawn DASHED at
lineweight 35 on `ReservedHandles.dashedLinetype`, whose record the kit's
`prepare` adds (C1.3). `exported: false` (today's `exportOmitOwners`). Tool S
band-trims through `RoomInputs`. Grips: two ends with band trim.

### C3.5 Room

`RoomParams(seedX, seedY, name, label, color)`; reads places; `pageKey`
(unit, scale, decimal separator); dissolves; generates its tint fill, its
name and its area text. Tool M names a new room with a numbered name
(`text:architecture.roomName`, C1.6) and notices "already a room"
(C1.2). Grips: the label grip, back to automatic inside the aperture.
Properties: name (`TextProperty`, trimmed, empty refused), area
(`TextDisplay`, as drawn), colour (`ColourTarget`: the colour row lists kit
targets before units, today's "rooms first, then tables").

**The tint in service mode and export** is the room's own generated fill;
2b's R-16 dropped only test lines for want of a room, and C6 brings them
back.

### C3.6 Dimension

`DimensionParams(a, b, kind, offset)`, an end fixed or attached to a wall
face; `references` the attached walls; `pageKey`. Tool I with the would-be
value as notice. Grips: offset and two ends; an end re-attaches through the
index while F3 is on. Properties: value (`TextDisplay`), kind
(`ChoiceProperty`), axes (`TextDisplay` over `world`), End 1 and End 2
(`TextDisplay`, `text:architecture.endOnWall` or the fixed word).

### C3.7 The sample flat

`buildSampleFlat(DraftDocument document, KitWords words)`, today's
`startupPlan(measurer, strings:)` (`startup_plan.dart:70`) moved: nine
walls, seven doors, eight windows, a column, a separator, rooms named in the
given language (`text:architecture.sample.*`), five dimensions and
furniture, and the page (A4 landscape at 1:50, the language's decimal
separator; the engine's `PageComponent`).

- **It fills a document it is given**, empty and already set up by the plan
  library (its measurer, its tables, every loaded kit's `prepare`): the kit
  never makes a plan document, so today's `prepareDocument` stays the plan
  library's.
- It regenerates through a `ParametricSystem` over the kit's own six types,
  installed for the build and disposed after it (today's
  `installParametric`, `startup_plan.dart:81`), so the plan's own system then
  takes the finished document. Every entity is added by command in source
  order (draw order is reading order), as today's `_Pen` does; what a host
  can undo after opening the sample is today's behaviour, ported with
  `startup_plan_test`.
- Its users: 3b's demo (how the demo hands the document to its controller
  is 3b's), the integration tests (C6), and later the README pictures
  (A11). The kit owns it because it owns every word and type in it.

## C4. The furniture library

- The 41 symbols are rewritten in the authoring language (`CatalogSymbol`,
  the shared shape helpers in `authoring/shapes.dart`); the generator runs
  under `dart run` and writes `assets/library/furniture.jetlib` and its
  geometry snapshot; the conformance test (A16) runs on the committed
  library.
- **Keys:** `architecture.` followed by today's key, at `@1` (decision 9: no
  old plan is read, so versions restart). `armchair` has one segment and
  becomes `architecture.armchair.single`.
- **Behaviour is fields** (A5): the 27 symbols tagged `against-wall` carry
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
  The capture and keep distances are today's, not the test kit's inverted
  hysteresis (2a's D-07).
- A wall on a hidden or locked layer offers no face (today's opening-host
  rule, SS17).
- Its tests are 09c's: `wall_attach_test`, `wall_faces_test`,
  `wall_attach_property_test`, `symbol_move_test` in the kit; the tool and
  shell cases in C6.

## C6. The integration package `jet_cad_2d_integration`

- `publish_to: none`, a workspace member. Depends on `jet_cad_2d_plan` and
  `jet_cad_2d_kit_architecture` (sub-project 4 adds the restaurant kit). Its
  name is not a kit's (A1's check does not bind it): it imports the plan
  library and the kit together, as a host does.
- `lib/` holds shared fixtures only (a walled room, a wall with a door, a
  plan controller over the kit, the sample flat through C3.7).
- `test/` holds every test that needs the kit inside the plan library's
  widgets: the tools on `PlanCanvas`, the property panel's kit sections, the
  layer rules for live objects, grips through `plan.select`, the wall
  attachment end to end, the export of rooms and separators, and the rows
  2a and 2b left to sub-project 3 (Appendix A, D-20 to D-39).
- **R-16's lines come back here, not in the plan library's tests:** the
  plan's `unit_fill_test`, `unit_colour_export_test` and zone fixture stay
  domain-free; this package carries TF1, TF3 and TF7 with the room and its
  tint (TF3's count back to 6), EX2, EX3 and EX5's tint and room lines, and
  CZ1's room named `7`.
- Its own CI job: `flutter test` (with `--enable-vmservice` if it gains an
  allocation test), `flutter analyze`, the format check.

## C7. Ports and their rulings

- **The rule (A12):** a ported test keeps its assertions; fixtures, names
  and ids may change. Two classes of change are known now and recorded as
  rulings in the plan, not left to tasks:
  1. **Ids:** `floor_planner.<type>` to `architecture.<type>`, furniture keys
     to C4's, word ids to C2's.
  2. **Tags to fields** (A5, umbrella decision 8): an assertion over the
     `against-wall` or `family:` tag asserts the same set over `attachTo` or
     `family`; "behaviour tags come last" is retired (tags carry no
     behaviour).
- **Not ported, premise impossible under umbrella decision 9** (no plan of
  `jet_cad_floor_plan` is read): the furniture library's pre-09c fixture
  tests and `wall_attach_end_to_end_test.dart` WE2.
- **Dropped on the human's word:** `seating_test.dart` SE10, SE10b, SE11
  (decision 3). SE8 (placement copies the definition with its unit) is
  generic: if 2b's placement tests do not already pin it, it is ported over
  the plan library's test unit kit.
- **Widgets that changed form** (a `SegmentedButton` now a dropdown, A4):
  finders change, the asserted values do not.
- Every other ported test that cannot keep an assertion is a ruling in the
  ledger, with its reason and cost.

## Tests

- **The testing bar** (CLAUDE.md): a new test lands only with a named
  mutation that turns it red; ported tests are the oracle and bring their
  own history. Every C1 amendment has its mutants.
- **The kit's own tests** (`flutter test` in the kit): geometry, room
  tracing, opening cuts, dimension attachment, every type's `generate`
  through the engine's `ParametricSystem`, grips and tools at the Flutter
  layer, property specs over values, the provider, the furniture library and
  the conformance test, the sample flat.
- **The integration tests** (C6).
- **The non-negotiables:** the engine's query-allocation invariant and the
  plan library's paint-allocation invariant stay green with the kit loaded
  (the integration package runs the paint invariant over the sample flat);
  draw order is ascending handle; geometric decisions use `Tolerance`.
- **The failure boundary:** the plan library's every-hook-throws test kit
  covers C1's new hooks.

## Order of work

1. The contract amendments (C1), each with its test-kit tests and mutants.
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
  `jet_cad_2d_integration`: test, analyse and format green; the engine's
  two standing hash lines stay the only failures.
- Dry-runs of `jet_cad_2d_kit`, `jet_cad_2d_plan` and
  `jet_cad_2d_kit_architecture` with 0 warnings.
- `tool/ci`'s checks green, `check_kit_deps` covering the new kit.
- Every Appendix A row closed: ported (with its destination), ruled (with
  its ruling), or carried to 3b or 4 by name.
- Every new test with its mutation; every C1 amendment recorded in the 2a or
  2b spec.
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
- Opening styles as data (umbrella, out of scope).
- Showing the engine's `diagnose` output in the UI (today's planner does not
  either).

## Risks

- **The size.** About 559 cases to port and about 10.8k lines to move.
  Appendix A is the guard: a row without an owner is a defect of this spec.
- **The amendments change the contract under the plan library's 1,519
  tests.** C1 lands first and alone, each change with its mutants, before a
  kit task starts.
- **The hot path.** The guarded wall and room `generate` run on every
  regeneration; the allocation invariants run with the kit loaded.
- **A frozen opening** draws beside an uncut wall (C3.3): accepted and
  pinned.

## Appendix A. Everything carried to sub-project 3, with its owner

From two read-only audits on `7e65905b` (2b's lesson: a deferral written in
a brief never reached the next spec). "3a" names this spec's section; "3b"
and "4" carry the row into their specs by name.

### A.1 Deferrals (D-01 to D-50)

| # | Item | Owner |
|---|---|---|
| D-01 | `wall_attach_test` (23), `wall_faces_test` (9), `wall_attach_property_test` (2), `symbol_move_test` (6) | 3a C5 (kit) |
| D-02 | `symbol_place_tool_test.dart:1368-1740`, the 09c D6 group (15) | 3a C6 |
| D-03 | `host/against_wall_rotate_test` (3, F-7) | 3a C6 |
| D-04 | app `wall_attach_end_to_end_test` WE1; `symbol_shell_test` SS16, SS17 | 3a C6; WE2 not ported (C7) |
| D-05 | `editor_tools_review_test`: the north-wall mirror case, O13a, O13b | 3a C6 |
| D-06 | A caching provider reads `document.commands.stateId` | 3a C2, C5 |
| D-07 | The test kit's inverted hysteresis not copied | 3a C5 |
| D-08 | The provider fits `AttachmentProvider`; `rotate: false` rule | 3a C5 |
| D-09 | `symbol_section.dart`'s `isOrthonormal` copy | 3a C1.4 |
| D-10 | Stale `WallFaces` doc comment, `symbol_box.dart:153` | 3a C1.4 |
| D-11 | `furniture_library_test` (34) | 3a C4 (C7 rulings) |
| D-12 | `symbol_search_test.dart:82-164, 191-267` (12, the real library) | 3a C6 |
| D-13 | `symbol_box_test.dart:321-339, 391-410` (3, the asset's boxes) | 3a C4 (kit; C1.4 puts the box in the contract) |
| D-14 | `symbol_end_to_end_test` (2, `bed.double`) | 3a C6 |
| D-15 | `package_assets_test` PA2, PA3 (the library from a package-key bundle) | 3a C4; PA4 (export font) 4 |
| D-16 | Restaurant tests over the furniture library (RL15, SC1-SC2, SNL) | 4 |
| D-17 | `seating_test` SE8-SE11 | SE10, SE10b, SE11 dropped (decision 3); SE8 3a C7 |
| D-18 | The old `example_test` | 3a C2 (`example/` and its test) |
| D-19 | The six types' test files (54 files, 353 cases) | 3a C3 (kit) |
| D-20 | `selection_panel_test` WS1-WS11 | 3a C6 |
| D-21 | `color_picker_test` CP2, CP1's separator line | 3a C6 |
| D-22 | `touch_tools_test` TD1 (Room tool) | 3a C6 |
| D-23 | `planner_shell_test`'s three sample-flat cases | 3a C6 |
| D-24 | DT1, LK2, OV-H, PW1/PW2's Wall words, NN3, VW3, NS3's room label | 3a C6 |
| D-25 | The architecture words | 3a C2, C1.6 |
| D-26 | The eight palette rows and their letters | 3a C2 (kit), C6 (palette) |
| D-27 | The room and dimension status notices | 3a C1.2, C3 |
| D-28 | DASHED; `new_document_test` ND1-ND3 | 3a C1.3, C3.4; ND's DASHED lines C6; its page and unit lines 3a C1.3's task checks for a twin, else ports them to the plan |
| D-29 | `layers/tools_layer_test` (10), `opening_host_layer_test` (6), `attach_layer_test` (2); the app's layer-picker wall case | 3a C6 |
| D-30 | The separator not exported | 3a C3.4, C6 (PDF and PNG) |
| D-31 | The room's colour target; `room_color_test`, `room_tint_test` | 3a C3.5 (kit), C6 |
| D-32 | `decimal_separator_test` (6) | 3a C6 |
| D-33 | `delete_components_test` (3) | 3a C6 |
| D-34 | `startup_plan_test` (14), `intersection_snap_test` (1) | 3a C3.7 (kit), C6 |
| D-35 | TF1, TF7 room and tint lines | 3a C6 |
| D-36 | TF3's `hasLength(5)` back to 6 | 3a C6 |
| D-37 | EX2, EX3, EX5 tint and room lines; the premises' `R` | 3a C6 |
| D-38 | The zone fixture's room named `7`; CZ1 | 3a C6 |
| D-39 | 2a's room rows over the box kit's colour target | 3a C6 |
| D-40 | `PlanServices.isLocked`, `allows`, a settings listenable | 3a C1.5 |
| D-41 | `PropertySectionBuilder` without handle or services | 3a C1.1 |
| D-42 | The `jet_cad_2d: ^0.7.2` floors predate E1-E5 | 4 (the wave) |
| D-43 | `GuardedTool._failed`'s rethrow for grip drags; the `_first` catch-all's probe | 3a C1.8 (the catch-all's probe cost: 3a C1.8's task records a ruling) |
| D-44 | `PlanShortcuts(shortcuts: false)` remounted on the same controller | 3a C1 (a pin test in the plan library) |
| D-45 | 2a's deferred minors: the registry's provider kind and guarded dispose, the move resolver's branches, `_open`'s unoffered kind | 3a C5 |
| D-46 | Section titles by `title`, `ValueDisplay`'s units, `ActionProperty` never exercised | 3a C3, C6 |
| D-47 | A16 conformance for the kit | 3a C2, C4 |
| D-48 | The nine closed lists, each a kit hook | 3a C3, C6 |
| D-49 | Who owns `apps/architecture_demo` | 3b (decision 1) |
| D-50 | 2b's host-API differences | 4 |

### A.2 `jet_cad_floor_plan/test` files not fully ported

Files of the six types (D-19), all 3a C3 in the kit unless a case needs the
plan library's widgets, then C6:

- box: `box_test` (6), `planner_box_test` (6, C6).
- wall: `wall_bands`, `wall_geometry`, `wall_grips`, `wall_paint`,
  `wall_params`, `wall_regen`, `wall_tool` (73).
- opening: `opening_cost`, `_cut`, `_end_drag`, `_geometry`, `_grips`,
  `_kink`, `_object`, `_obstacle`, `_paint`, `_panel` (C6), `_params`,
  `_symbol`, `_tool` (85).
- separator: `separator`, `separator_tool` (10).
- room: `room_color`, `_cost`, `_diagnostics`, `_dissolve`, `_follow`,
  `_grips`, `_inputs`, `_label`, `_localise`, `_object`, `_paint`, `_panel`
  (C6), `_tie`, `_tint`, `_tool`, `_trace` (100).
- dimension: `dimension_attach_points`, `_attach`, `_follow`, `_format`,
  `_fuzz`, `_grips`, `_layout`, `_object`, `_paint`, `_panel` (C6),
  `_params`, `_rotate`, `_shell` (C6), `_tool` (73).

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
commands, exit, files, host, open, replace, save, separator, settle, export
and print flows, `symbol_library_loader_test`, `symbol_shell_test` SS1-SS15,
the end-to-end tests, `app_words_test`, `export_font_test` EF1-EF3,
EF9-EF12): 3b.

## Revision history

- **Revision 1:** the design approved in chat.
