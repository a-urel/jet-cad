# Restaurant embedding (14) — umbrella design

**Date:** 2026-10-03. **Status:** design, **revision 2**, **not approved**.
Revision 1 (`c413ba6`) was reviewed independently: "Not ready", 10 major,
6 minor (R-1 to R-16), each applied below; see [Revision 2](#revision-2).
The human answered rev 1's open questions the same day; see
[Decisions](#decisions-the-human-made-on-2026-10-03).
**Sub-project:** new, `14` — the first consumer of the floor planner: a
restaurant (point-of-sale) application written in Flutter that embeds the
planner in two modes, **design** and **selection**.
**This is an umbrella spec (R-14).** It fixes the decisions, the slices and
their order. **Slice 14s (restaurant symbols) is specified in full here**
and may be planned from this document once approved. Every other slice
gets its own full spec (Facts at a sha, Files, Invariants, Testing,
Risks, the layer-panel spec's rigor) before its plan.
**Size:** L overall; five slices (below).
**Branch:** `claude/exciting-pasteur-9m22jv`, cut from `main` at `4d6b78f`.
**Depends on:** 09 (symbols), 12a (the session, the save point), 12b
(layers, `DraftPermissions` presets).

**Inputs read:** `CLAUDE.md`; `STATUS.md` (head); `roadmap/00-README.md`;
`roadmap/12-app-shell.md`;
`docs/superpowers/specs/2026-07-27-jet-cad-2d-architecture-design.md`
(lines 9-12, 902-910); `packages/jet_cad_2d/lib/src/document/{command,
commands,node,undo,tree,validate,draft_document}.dart`;
`lib/src/index/{query_filter,spatial_index,container_index}.dart`;
`packages/jet_cad_2d_flutter/lib/src/{selection,select_tool,grip_drag,
selection_overlay,outline_cache,draft_canvas,interaction_layer,
camera_gesture_detector,flutter_text_measurer,tool}.dart`;
`apps/floor_planner/pubspec.yaml`, `lib/{main,document_host,
planner_view}.dart`, `lib/parametric/catalog.dart`,
`lib/symbols/{symbol_component,symbol_library,symbol_placer,
symbol_library_loader,build_library,furniture_catalog}.dart`,
`lib/export/export_font.dart`,
`test/symbols/furniture_library_test.dart`.

## Why now

The human, 2026-10-03: *"Bu projenin ilk kullanımı bir restoran yazılımı
içinde olacak. Tasarım ve seçim için iki ayrı mod olmalı. Restoran yazılımı
içinde kullanmak için yapmamız gereken neler kaldı? Onları tamamlamamız
gerek ilk olarak."* — the first use is inside a restaurant application,
with separate design and selection modes; what is missing for that comes
first, before the remaining 12 slices, DXF, or the found items.

Not a new direction: the engine's founding spec names a WYSIWYG
**designer** and *"a lightweight **viewer** for runtime use (a
point-of-sale app showing a restaurant floor plan, selecting a table,
acting on it)"*; `DraftPermissions.runtime` (`command.dart:58-59`, its doc
comment at :56) was written for it. Today only the designer exists, and
only as an application.

## Decisions the human made on 2026-10-03

1. **The host is a Flutter application.** The planner is a Dart package
   dependency — no iframe, no web view, no JS bridge.
2. **The selection mode lets staff** select **one** table, select
   **several**, see each table's **status as a colour** supplied by the
   host, and **move** tables.
3. **A table's number is assigned in the design mode**; the POS refers to
   tables by it.
4. **A bar stool can be a "table"** (a servable place), and **this session
   completes the symbols a restaurant needs** (slice 14s).
5. **The number appears on the printed/exported plan too** (an ATTRIB, D3).
6. **Export and Print are available in both modes.**
7. **Undo is separated at the mode switch** (rev 1's proposal for Q5).
8. **A tap inside a table's area selects it**, not only on its lines.
9. **Multiple selection on touch is a long press** (toggle).
10. **No rotation in selection mode** (v1).
11. **Moves in selection mode last for the service, or until undone**:
    they never change the designed plan.
12. **One plan per dining area** (salon, garden, terrace): the host keeps
    several plans and shows them as it likes.

## Facts established (verified on `c413ba6`, by the review)

- **F-1.** The furniture catalog tags `table` on non-dining pieces too:
  the nightstand (`furniture_catalog.dart:366`), the coffee table (:427),
  the desk (:512). A tag cannot decide what is a table (R-1).
- **F-2.** `SymbolComponent` carries key, name, category, tags, version
  only (`symbol_component.dart:29-33`); no seat count exists anywhere but
  in tag words, and `dining.table.round` has none (R-2).
- **F-3.** `placeSymbol` reuses a plan's definition with the same key and
  version (`symbol_placer.dart:75-84`), and copies a different version
  beside it. A component outlives its node and its definition
  (`symbol_placer.dart:77-78`; `RemoveNodeCommand`, `commands.dart:371-395`,
  touches no component) (R-4).
- **F-4.** A symbol's **first leaf is its outline**, a closed polyline or a
  circle, asserted by `furniture_library_test.dart` ("the outline (first
  leaf) …"). For a dining set it is the **table top** without the chairs
  (`furniture_catalog.dart:136-146`).
- **F-5.** An unknown component **type** is preserved verbatim by the codec
  (`component.dart:66`); a known type's unknown **field** is not (each
  `fromJson` reads its own keys).
- **F-6.** A move drag issues `TransformNodeCommand` for an instance
  (`grip_drag.dart:306-312`), capability `transform` (`commands.dart:292`):
  allowed by `runtime`.
- **F-7.** Deleting an instance issues `RemoveNodeCommand` only
  (`select_tool.dart:638-640`); `tree.removeNode` drops only the node
  (`tree.dart:206-209`): an ATTRIB it owned is orphaned and `validate`
  reports `entity.owner_missing` (`validate.dart:96-102`) (R-3a).
- **F-8.** An instance-owned ATTRIB is a container leaf
  (`container_index.dart:209-225`); `resolveHit` returns it as its own key
  (`selection.dart:51-63`), so a click on the number selects the number
  alone (R-3b). ATTRIB coordinates are instance-local: a mirrored or
  rotated table draws a mirrored or rotated number (R-3c).
- **F-9.** `OutlineCache` holds selected/hovered strokes only
  (`outline_cache.dart:11-39, 64-77`); the paint-allocation invariant
  measures `DraftPainter` only (`paint_allocation_test.dart:135-140`) (R-5).
- **F-10.** `forEachInstanceInRect` reports **root-level** instances by
  world AABB (`spatial_index.dart:336-358`); `pickInto` is not re-entrant
  and cannot be restricted to candidates (:776-793) (R-6).
- **F-11.** `CameraGestureDetector` handles trackpad pan-zoom, scroll and
  button-held pan (`camera_gesture_detector.dart:11-13, 120-133`): **no
  multi-touch pinch, no two-finger pan**. The pick radius is a fixed 6 px
  (`interaction_layer.dart:20, 123`) (R-7).
- **F-12.** `main.dart` holds both `FloorPlannerApp` and the ~800-line
  `PlannerShell`; `document_host.dart:24` and 33 sites in lib/test import
  `main.dart`; the shell owns document, index, camera, selection and the
  parametric system as `late final` state and is rebuilt per document
  (`document_host.dart:626`) (R-8).
- **F-13.** Documents name `fontFamily: 'Roboto'`
  (`draft_document.dart:144`), used verbatim by the measurer
  (`flutter_text_measurer.dart:214-220`); a package font registers as
  `packages/<pkg>/Roboto`, so a host would measure with its platform font
  (R-9). The app has `macos` and `web` runners only.
- **F-14.** The engine has `clearHistory`/`notifyLoaded` and no undo floor
  (`undo.dart:261-277`); a redo under `runtime` of a design edit throws
  `PermissionDeniedError` (:287-293) (R-10).

## Slices and order (R-15)

| Slice | What | Package touched | Spec |
|---|---|---|---|
| **14s** | Restaurant symbols and seating metadata | app (catalog, library asset) | **here, full** |
| **14b-1** | Extract the planner into `packages/jet_cad_floor_plan`, behaviour-neutral; font and assets fixed | new package, app | own spec |
| **14a** | Table identity: `TableComponent`, numbering, the ATTRIB label | package, render (cascade, pick) | own spec |
| **14b-2** | The public API, the two modes, the undo barrier, `apps/restaurant_demo` | package | own spec |
| **14t** | Touch spike, then touch: pinch, two-finger pan, long press, finger pick radius | render | own spec, spike first |
| **14c** | Selection-mode behaviour: table pick, status layer, moves | package, render | own spec |

14s first: it is small, app-only, and the human asked for it in this
session. 14b-1 before 14a so identity code is written once, in its final
place. The touch spike (14t) may run in parallel with 14a, since it is the
largest unknown (R-7) and lives in the render package.

---

## Slice 14s — restaurant symbols (full)

### What it delivers

A **Restaurant** category in the symbol palette with the tables, seats and
fixtures a restaurant plan needs, and **seating metadata** on every symbol
that can be a served place, so later slices can tell a table from a
nightstand without guessing from tags.

### Decisions

- **S1. `SeatingComponent`** — a new app component, type id
  `jetcad.seating`, on a **definition's handle**, field `seats` (int ≥ 1;
  `ArgumentError` below 1, not an assert). Immutable, value-equal,
  fixed-key `toJson`, registered in `registerAppComponents` once per
  registry like `SymbolComponent`. **A symbol is servable iff its
  definition carries one** (R-1, R-2). A new type, not a field on
  `SymbolComponent`, because an older build preserves an unknown type
  verbatim and would drop an unknown field (F-5): **no schema bump**.
- **S2. The catalog states it.** `FurnitureSymbol` gains `int? seats`
  (null: not servable). `buildFurnitureLibrary` adds the
  `SetComponentCommand<SeatingComponent>` right after the symbol component
  when it is non-null; `SymbolEntry` gains `seats`, read by the loader
  (a definition with a seating component of `seats < 1` is a
  `SymbolLibraryError`); `placeSymbol` copies it with the definition.
- **S3. The existing dining tables become servable** and move to
  **version 2** (`dining.table.square.two`, `.square.four`, `.rect.four`,
  `.rect.six`, `.round`), geometry unchanged: a plan holding a version-1
  copy keeps it (not servable) and a new placement copies version 2 beside
  it (F-3, 09's decision 8). `dining.table.round` gets its four chairs drawn
  (it has none, F-2), so its seat count is visible. Chairs, the bench, the
  coffee table, the desk and the nightstand stay unservable.
- **S4. Servable symbols put the served place's outline first** (F-4): a
  table's first leaf is the **table top**; a stool's is its seat circle.
  14c's status fill and pick region are that leaf, never the chairs.
- **S5. The new Restaurant category** (`restaurant`, displayed
  `Restaurant`), after `Dining Room` in the palette's category order. Keys,
  seats and sizes (mm; every chair 450 × 450, tucked 100 mm, as the dining
  sets; every base point at the table centre, off the origin):

  | Key | Name | Seats | Size / note |
  |---|---|---|---|
  | `restaurant.table.square.two` | Square table, 2 seats | 2 | 700 × 700, chairs on two opposite sides |
  | `restaurant.table.square.four` | Square table, 4 seats | 4 | 800 × 800 |
  | `restaurant.table.rect.four` | Rectangular table, 4 seats | 4 | 1200 × 750 |
  | `restaurant.table.rect.six` | Rectangular table, 6 seats | 6 | 1800 × 800 |
  | `restaurant.table.rect.eight` | Rectangular table, 8 seats | 8 | 2400 × 900 |
  | `restaurant.table.round.two` | Round table, 2 seats | 2 | Ø 700 |
  | `restaurant.table.round.four` | Round table, 4 seats | 4 | Ø 900 |
  | `restaurant.table.round.six` | Round table, 6 seats | 6 | Ø 1200 |
  | `restaurant.table.round.eight` | Round table, 8 seats | 8 | Ø 1500 |
  | `restaurant.booth.two` | Booth, 2 seats | 2 | table 700 × 700 between two 600-deep benches with backs |
  | `restaurant.booth.four` | Booth, 4 seats | 4 | table 1200 × 700, benches 1200 long |
  | `restaurant.booth.six` | Booth, 6 seats | 6 | table 1800 × 750, benches 1800 long |
  | `restaurant.table.high.two` | High table, 2 stools | 2 | Ø 600 top, two Ø 380 stools |
  | `restaurant.table.high.four` | High table, 4 stools | 4 | Ø 700 top, four Ø 380 stools |
  | `restaurant.bar.stool` | Bar stool | 1 | Ø 380 seat, Ø 300 footrest ring |
  | `restaurant.bar.counter` | Bar counter | — | 3000 × 600, a 250 back bar line |
  | `restaurant.bar.counter.corner` | Corner bar counter | — | L, 2400 × 1800 legs, 600 deep |
  | `restaurant.cashier` | Cashier desk | — | 1400 × 700, a register outline |
  | `restaurant.host.stand` | Host stand | — | 600 × 450 |
  | `restaurant.service.station` | Service station | — | 1200 × 600, two drawer lines |
  | `restaurant.buffet` | Buffet counter | — | 2400 × 800, four tray outlines |
  | `restaurant.highchair` | Highchair | — | 500 × 550, a tray line |
  | `restaurant.planter` | Planter | — | Ø 600, an inner Ø 450 |
  | `restaurant.parasol` | Parasol | — | Ø 2700, eight spokes |

  The bar counter is not servable: the stools along it are (decision 4).
  Turkish names are not in the library: the symbol `name` is English, as
  every key's is today; localisation is the app's later concern.
- **S6. Geometry only** (09's R-5): lines, closed polylines, arcs, circles;
  no text, no fill. Every polyline closed (the existing test).

### Files

- `apps/floor_planner/lib/symbols/seating_component.dart` (new),
  `furniture_catalog.dart` (the category, `seats`, the new builders and
  entries, version 2 for the dining tables, the round table's chairs),
  `build_library.dart`, `symbol_library.dart` (`SymbolEntry.seats`, the
  loader check), `symbol_placer.dart` (copy the seating component),
  `parametric/catalog.dart` (`registerAppComponents`).
- `apps/floor_planner/assets/library/furniture.jetlib`, regenerated by
  `dart run tool/generate_furniture_library.dart`.
- Tests: `test/symbols/{furniture_library_test,seating_component_test,
  symbol_library_test,symbol_placer_test}.dart`, and whichever existing
  test pins the library's entry count or categories.

### Invariants

- The committed asset equals the built library, byte for byte; two builds
  are identical (existing tests).
- Leaf and definition handles ascend in catalog order (draw order).
- Every servable symbol's first leaf is a closed polyline or a circle, and
  every one of its seats lies outside that outline (a chair or stool does
  not overlap the top, beyond the 100 mm tuck for chairs).
- The two allocation invariant tests are untouched and green (14s touches
  nothing on the frame path).

### Testing and named mutants

Every count below is **written out by hand** in the test, not derived from
the catalog (the existing test's rule).

- **M-14s-1:** drop the `SetComponentCommand<SeatingComponent>` from
  `buildFurnitureLibrary` — the "seats per servable key" table test goes
  red.
- **M-14s-2:** leave the dining tables at version 1 — a test placing
  `dining.table.square.four` into a plan that already holds a v1 copy must
  find the new instance's definition servable.
- **M-14s-3:** `placeSymbol` copies the definition but not the seating
  component — the placer test on an **off-origin, quarter-turned,
  mirrored** placement goes red (the degenerate-fixture rule).
- **M-14s-4:** put a stool's seat circle, not the table top, first in a
  high table — the "first leaf is the served outline" test (its centre is
  the base point and its area the largest) goes red.
- **M-14s-5:** `SeatingComponent(seats: 0)` accepted — the constructor
  test goes red; a library carrying one is refused by the loader.
- **M-14s-6:** a booth's bench drawn overlapping its table — the
  "seats lie outside the top" test goes red.
- The count of library entries, categories and the closed-polyline table
  are updated by hand to the new totals.

### Risks

- A palette with 24 more thumbnails: the thumbnail cache is LRU; the
  09b capacity must be checked against 51 entries (a plan detail).
- The golden thumbnails, if any test pins one, change; no engine golden
  PNG may change.

---

## The other slices — the decisions, for their own specs

### 14b-1 — Extraction (behaviour-neutral)

- **D7.** A new package `packages/jet_cad_floor_plan` (name proposed;
  **Q11**) holds `apps/floor_planner/lib/` except the application frame
  (`main()`, `FloorPlannerApp`, the exit guard, the platform file
  dialogs and their conditional `web` imports, which stay in the app).
  `PlannerShell` moves out of `main.dart` into its own file first, so the
  33 `main.dart` imports resolve (F-12). The app's tests move with the
  code, importing `src/` through a second, explicitly internal library
  `jet_cad_floor_plan/editor.dart` that the app uses and a host need not
  (R-8).
- **D7a. Fonts (R-9).** The package registers family `'Roboto'` at
  initialisation with `FontLoader` over its own asset bytes, before the
  first document is measured; tested on a platform whose default font is
  not Roboto (a widget test that measures a string with and without the
  registration).
- **D7b. Assets** load as `packages/jet_cad_floor_plan/...`.
- **D7c. Platforms (Q12).** The host's target platforms decide which
  runners the demo gets and whether `printing` works there.
- Exit: `apps/floor_planner` behaves exactly as before; every existing test
  green from its new place.

### 14a — Table identity

- **D1.** `TableComponent` on a servable **instance's** handle: `number`
  (non-empty, trimmed string) and `seats` (≥ 1, defaulting from the
  definition's `SeatingComponent`, S1).
- **D2.** An instance is a table iff its definition carries a
  `SeatingComponent` and the instance is **live** (in the tree). Placing
  one numbers it inside the placement's `CompoundCommand`.
- **D2a. Numbers (R-13).** Compared with exact `==` after trimming,
  case-sensitive (no Turkish case folding). The next number is
  `max + 1` over the **live** tables whose number parses as a plain
  decimal integer (`^[0-9]+$`, leading zeros allowed, `"07"` reads 7);
  `"1"` when none does. Non-numeric numbers (`"B4"`) are kept and never
  counted.
- **D2b. Dead components (R-4).** Every query (next number, uniqueness,
  `tables`, statuses) counts **live instances only**; additionally the
  delete of a table removes its `TableComponent` in the same compound, so
  a saved file carries none for a deleted table.
- **D3. The label is an ATTRIB owned by the instance** (decision 5), and
  three things go with it (R-3):
  - **Cascade:** deleting an instance removes the entities it owns, in the
    same compound (`select_tool.dart`'s delete, a render-package change,
    generally right for any instance-owned ATTRIB).
  - **Pick:** `resolveHit` maps an instance-owned ATTRIB to its owning
    instance's key.
  - **Upright:** the ATTRIB's local placement compensates the instance's
    rotation and mirror so the number reads upright and unmirrored in
    world; an app-side system re-stamps it, in the same undo step, on any
    command that changes a table instance's transform (the parametric
    system's after-mutate hook is the model). Named mutants on mirrored
    and rotated fixtures.
- **D4.** A Table group in the Selection section: Number and Seats, each
  commit one command; a number already used by a live table is refused at
  the field, never renamed.
- **D5. Duplicates (R-11)** can only arrive by load (there is no paste or
  duplicate today). A duplicate is a diagnostic; in the API a table is
  addressed by number, and a duplicated number addresses **both** tables
  (selecting it selects both; a status colours both); the demo shows the
  diagnostic.

### 14b-2 — API, modes, barrier

- **D8. Public API**, the package's main barrel:
  - `FloorPlanController` — owns the document, index, camera, selection
    and parametric system for its life (R-8); `load(String json)` replaces
    the document, **clears selection and statuses' resolution** (statuses
    are re-resolved by number against the new plan), and fits the camera;
    `String designJson()` (the designed plan; D12); `bool dirty`;
    `markSaved()`; `undo()`/`redo()` (honouring D12); `mode`
    (`ValueNotifier<FloorPlanMode>`); `selectedTables`
    (`ValueListenable<Set<String>>`); `select(Set<String>)`;
    `setTableStatus(Map<String, TableStatus>)`; `fitToView()`;
    `List<TableInfo> tables` (number, seats, symbol key; live only);
    `resetLayout()` (D12).
  - `FloorPlanView({controller, multiSelectByLongPress = true,
    onTableTap, onSelectionChanged, onLayoutChanged, onExport})`.
  - `enum FloorPlanMode { design, selection }`; `TableStatus` (a colour, an
    optional short caption).
- **D9. Storage is the host's**; no file dialogs when embedded. **Export
  and Print in both modes** (decision 6), handing bytes to `onExport` or
  to `printing`.
- **D10. Design mode:** today's editor under `DraftPermissions.all`.
- **D11. Selection mode:** canvas only, under `runtime`, with a dedicated
  `TableSelectTool` (R-12): no grips, no band, no snapping, no keyboard
  shortcuts but Undo/Redo; no affordance needing `geometry` or
  `structure` exists (M-12a: the UI never relies on the dispatcher
  refusing; asserted with a dispatcher spy).
- **D12. The barrier and service moves** (decisions 7, 11; R-10). Entering
  selection mode records the design (`designJson()` snapshot, the undo
  depth as a floor) and **clears redo**; selection-mode Undo stops at the
  floor; Redo reaches only selection-mode moves. Service moves never
  touch the design: `designJson()` returns the snapshot, `dirty` does not
  change, `resetLayout()` restores the designed positions. Entering design
  mode **restores the design** (service moves are discarded; the demo
  asks first when there are any). M-14f covers undo **and** redo.
- **D19.** `apps/restaurant_demo`: a Design / Service toggle, two dining
  areas (decision 12), a fake order list setting statuses, the callbacks
  printed. Example and integration surface, not a product.

### 14t — Touch (spike first)

- **D17 (R-7).** A render-package decision: pointer tracking for
  multi-touch, pinch zoom about the focal point, two-finger pan, one-finger
  pan on empty floor in selection mode, the rule for a second finger during
  a drag (cancels the drag, becomes a pinch — proposed), long press
  (500 ms, within the slop) for decision 9. Pick radius in logical pixels,
  about 24 dp (a 48 dp target) for touch, today's 6 px for a mouse, by
  pointer kind. `fitToView()` frames the live tables' extents.

### 14c — Selection-mode behaviour

- **D13. Status layer (R-5).** Not document state: no command, no undo, no
  dirty, not saved, not exported. A `TableStatusPainter`, its own
  `CustomPaint` and `RepaintBoundary`, in the `Stack` between
  `PageChromePainter` and `DraftCanvas` (`planner_view.dart:130-153`), so
  the fill is under the lines. It fills **one cached local-space path per
  servable definition** (its first leaf, S4) under each table's instance
  transform and the rebase origin, through reused matrices; captions are
  cached paragraphs, rebuilt at status-change rate. **The
  paint-allocation invariant is extended** to this painter, its steady
  state measured at N tables (it is not "untouched": F-9).
- **D14. Picking tables (R-6).** Candidates are the live table instances
  (a list the controller keeps, rebuilt on document change, not per
  pointer event); the pointer's world point is taken through each
  candidate's inverse instance transform and tested inside the first
  leaf's region (decision 8), a containment decision with `Tolerance`;
  the hit with the highest handle wins (draw order). Hidden-layer tables:
  not drawn, not picked, no status, not in `fitToView`, still in `tables`
  (flagged hidden). Locked-layer tables: picked and statused, **not
  movable**. Tables inside a group: not tables in v1 (a diagnostic).
- **D15.** Tap selects alone; tap on empty floor clears; **long press
  toggles** a table in or out of the selection (decision 9). No band.
- **D16.** Dragging a selected table moves the selection (one
  `TransformNodeCommand` per instance in one compound, F-6), translation
  only, no snapping; dragging an unselected table selects it alone and
  moves it. One undo step per drag; `onLayoutChanged` once on release.
- **D18.** Callbacks carry table numbers, never handles.

## Named mutants (later slices; each slice's spec adds its own)

- **M-14a:** next number `count + 1` — tables 1 and 3 must not yield a
  second 3.
- **M-14b:** `TableComponent` on the definition — two tables of one shape
  keep different numbers.
- **M-14c:** selection mode picks the topmost anything — a table under a
  wall line must still be picked.
- **M-14d:** status by `InstanceNode.color` — `dirty` and undo depth go red.
- **M-14e:** `onSelectionChanged` with handles, or stale numbers after
  `load` — the reload test goes red.
- **M-14f:** no barrier — selection-mode Undo must not undo a wall, and
  Redo must not redo a design edit.
- **M-14g:** statuses tested only at the origin / identity — fixtures are
  rotated, mirrored and translated.
- **M-14h:** pick without the inverse instance transform — a rotated,
  mirrored table goes red.
- **M-14i:** the label not re-stamped upright — a mirrored table's number
  reads mirrored.
- **M-14j:** delete without the ATTRIB cascade — `validate` reports
  `entity.owner_missing`.
- **M-14k:** count dead `TableComponent`s — a deleted table's number is
  still refused.
- **M-14l:** a locked-layer table moves in selection mode.

## Open questions for the human

- **Q11.** Package name `jet_cad_floor_plan`?
- **Q12.** Which platforms does the restaurant application ship on
  (Android tablet, iPad, Windows, web)? It decides 14b-1's runners, the
  touch spike's devices and Print.
- **Q13.** Should 14s's table list (S5) change — sizes, missing pieces
  (a sofa booth corner, a pass-through, a coat rack, a kids' area)?

## Not in scope

DXF, the remaining 12 slices, Plan G, table merging as a document concept,
reservations and time-based state, live sync between terminals.

## Revision 2

Applied from the independent review of rev 1 (`c413ba6`), and the human's
answers of 2026-10-03:

- R-1, R-2: servable = a `SeatingComponent` on the definition (S1–S3), not
  a tag; F-1, F-2.
- R-3: D3's cascade, pick mapping and upright re-stamp; F-7, F-8; M-14i,
  M-14j.
- R-4: live-only queries and the delete detaching the component (D2b);
  M-14k.
- R-5: D13 rewritten (one region per definition, the slot, the invariant
  extended); F-9.
- R-6: D14 rewritten (candidates, inverse transform, `Tolerance`, hidden
  and locked layers, groups); F-10; M-14h, M-14l.
- R-7: touch is its own slice, 14t, spike first; F-11.
- R-8: `PlannerShell` out of `main.dart`, the internal editor library,
  the controller owns the state, `load()`'s effects; F-12.
- R-9: D7a, D7b, Q12; F-13.
- R-10: D12's undo floor plus cleared redo; M-14f covers redo; F-14.
- R-11: D5 restated for load; duplicates in the API.
- R-12: `TableSelectTool` (D11).
- R-13: D2a.
- R-14: this is an umbrella; 14s full here, others their own spec.
- R-15: the order 14s → 14b-1 → 14a → 14b-2 → 14c, 14t spiked early.
- R-16: M-14h to M-14l.
- Citations corrected: `command.dart:58-59`, `node.dart:163`.
- The human's answers became decisions 4–12; rev 1's Q1–Q10 are closed.
