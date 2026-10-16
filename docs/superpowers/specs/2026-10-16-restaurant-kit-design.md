# The restaurant kit and a POS-ready plan library (sub-project 4a) — design

**Date:** 2026-10-16. **Status:** revision 1, written after the human
approved the design section by section in chat (*"onaylıyorum"*,
*"uygun"*, *"uygun, onaylıyorum"*). No independent review: the human's
approval is the gate (*"benim onaylamam yeterli olacak, bağımsız review
session'ı yaratma!"*); the controller self-reviewed this file.
**Approved by the human** (*"onaylıyorum"*, 2026-10-16), decision 9 included.

**Binds:** the umbrella spec
[2026-10-13-kit-architecture-design.md](2026-10-13-kit-architecture-design.md)
(A1-A17; A13's sub-project 4 is split here), the contract spec
[2026-10-13-kit-contract-design.md](2026-10-13-kit-contract-design.md),
the 2a and 2b specs, the 3a spec
[2026-10-15-architecture-kit-design.md](2026-10-15-architecture-kit-design.md)
and the 3b spec
[2026-10-16-architecture-demo-design.md](2026-10-16-architecture-demo-design.md).
Their rules hold here unless a section below says otherwise.

**Branch:** `feat/restaurant-kit`, cut by hand from `main` at `8caf8e00`
(`origin/main` an ancestor, 0 commits ahead), worktree
`.claude/worktrees/restaurant-kit`.

**Companions:**
- [2026-10-16-restaurant-kit-parity.md](2026-10-16-restaurant-kit-parity.md):
  the parity audit (A14's starting table): the old host guide §4-§11, the
  old barrel's names and the old demo's features against the new packages,
  each with its status.
- [2026-10-16-restaurant-kit-test-audit.md](2026-10-16-restaurant-kit-test-audit.md):
  the per-case disposition of the 95 old tests this spec owns.

## Decisions taken in the brainstorm (the human, 2026-10-16)

1. **The goal: a package ready for a real POS** (*"Gerçek POS'a hazır
   paket"*). At the end of sub-project 4 the restaurant kit and the plan
   library are complete and documented enough for a real POS (e.g.
   monepro) to host them: tables, statuses, groups, zones, events and host
   data closed in the parity table, the demo showing it. Integrating a POS
   is a separate project.
2. **Sub-project 4 is split** (*"Evet, 4a / 4b"*): **4a** (this spec) is
   the restaurant kit, the plan library's host gaps, the demo, the parity
   table and the host guide; **4b** is the release wave: the README
   pictures, removing the old packages and `apps/floor_planner`, the CI
   moves, the dependency floors and the release checklist.
3. **The open items that touch the restaurant go into 4a** (*"Restoranı
   etkileyenler"*): 3a's possible `plan.select` drag-snap defect and
   one-frame re-word lag, 3b's Landscape wrap and export gap. 3a's frozen
   neighbour question and liveness revision, 3b's open-before-picker,
   untestable A5 guard and interactive smoke stay for later.
4. **The approach: port the catalog with the authoring toolkit and add
   units** (section 1 approved); a parametric table type is a later piece
   of work; wrapping the old package is refused.
5. **The plan library's host gaps** as section 2 (approved): H1-H4 and
   O1-O4 below; no converter for old saved plans.
6. **The demo is rewritten in place** (section 3 approved): one app, every
   feature kept; the old one stays reachable at tag `v0.7.2`.
7. **Five parity rows are dropped on the human's word** (*"uygun,
   onaylıyorum"*, A14 requires it): old saved plans (schema 7-10) do not
   open; the old service layout text is refused; the one-view `StateError`
   is replaced by H3; `symbolSources` is replaced by a host kit (H2);
   `FloorPlanTool` is replaced by the kits' and `PlanToolIds`' constants
   (H1).
8. **No independent reviews** (*"bağımsız review session'ı yaratma!"*):
   no reviewer subagents of any model; the controller reviews each task
   itself (reads the diff, runs mutations, re-runs the gates) and the
   human approves.

## Decisions taken by the controller (from the test audit)

9. **The sample plans move from the kit to the demo.** Section 1 put
   `buildSalon` and `buildTeras` in the restaurant kit. The audit found
   that a kit may name neither the plan library nor another kit
   (`tool/ci/check_kit_deps.dart`), and the samples need walls (the
   architecture kit) and tables (this kit). They live in
   `apps/restaurant_demo/lib/samples/`. Cost if wrong: a host wanting the
   sample copies the demo's file. **The human confirms this on reading
   the spec.**
10. **Twenty-five units, not eleven.** Every old symbol with `seats` (25:
    tables, booths, banquettes, lounge sets, high bar tables and the bar
    stool) becomes `UnitComponent(kind: UnitKinds.table, capacity:
    seats, labelling: numbered)`. The "11" in the chat was the number of
    helper call sites. The bar stool stays a numbered table, as today (the
    Salon's stools are tables 8-11).
11. **No wall attachment in the kit.** None of the 69 symbols had
    `against-wall`; the kit declares no `attachTo`.
12. **Tests that need two kits or the plan library live in the demo**
    (or `jet_cad_2d_integration`); the kit holds pure-kit tests (catalog,
    asset, snapshot, words, conformance, placement through a helper
    copied into its `test/support/`, as the architecture kit's).
13. **Old data is dropped:** `apps/restaurant_demo/assets/plans/*.json`,
    their pubspec entries and the `UPDATE_SAMPLES` path go; the demo keeps
    `controller.save()` text in memory.
14. **Reset layout also splits the groups**, since the service record now
    carries them (2b), and the "layout restored" log line names the
    applied and dropped groups (`ServiceRestore.appliedGroups`,
    `droppedGroups`).
15. **The rest of the audit's decisions are taken as it proposes** (its
    list, items 1-18): the permission composition per editor profile, the
    kit order `[architectureKit, restaurantKit]` (gallery order), the
    Tables profile's gallery showing only units, the area name in
    `PlanServiceBar.leading` (key `bar-area`), the demo's own key bindings
    when the plan's shortcuts are off, status captions within 12
    graphemes in en/de/tr, `PlanTheme` with the POS look unchanged, the
    demo's own strings table, `onUnitHover(null)` worded as today, and the
    test fixtures for duplicate, unlabelled, locked and hidden units built
    with raw commands on `controller.document` through one finder in the
    demo's test support.

## R1. The restaurant kit

`packages/jet_cad_2d_kit_restaurant` 0.1.0, published with the wave (4b).

- **`restaurantKit`**: `PlanKit(id: 'restaurant', version: '0.1.0',
  symbols: [restaurantSymbolSource], names: restaurantNames)`. No types,
  no tools, no attachments.
- **The catalog**: the 69 symbols of `packages/jet_cad_restaurant_symbols`
  in six categories, ported to the contract's authoring toolkit
  (`CatalogSymbol`, `CatalogShape`, the shared chair helpers). Keys stay
  `restaurant.*` at version 1, except eight one-segment keys renamed to
  meet the contract's key rule (kit id and two or more segments; ruled in
  Task 1, never published): `cashier.desk`, `buffet.counter`,
  `highchair.child`, `parasol.round`, `heater.patio`, `partition.screen`,
  `stage.platform`, `piano.grand`. Each symbol's geometry equals the old
  one's: a test compares every key's shapes with the old catalog's (the
  old package stays in the workspace until 4b, so the test reads it from
  a committed fixture exported once, not by import: the kit may not name
  the old package).
- **Units** (decision 10): the 25 seated symbols. The library rules hold
  (a unit draws a closed polyline or circle first, no family,
  capacity ≥ 1); the conformance test checks them.
- **The asset**: `assets/library/restaurant.jetlib` and
  `restaurant.snapshot.json`, built by `tool/generate_restaurant_library.dart`;
  the old asset's bytes are not reused. A16's snapshot rule holds from the
  first publish.
- **Words**: `restaurantNames` in en, de, tr: every symbol, the six
  categories; `sameAsEnglish` where a word is the same (Bar, Service, WC);
  categories unique per locale.
- **Public surface**: `restaurantKit`, `restaurantSymbolSource`,
  `restaurantNames`, the key constants a host or the demo needs
  (`RestaurantSymbols`), and a synchronous `restaurantSymbolDefinitions()`
  (the built library's definitions by key) for a `PlanBuild` that places
  tables (a build gets no symbol services), and `restaurantSymbolEntries()`
  (symbol, unit, definition and leaves by key; added in Task 2, since a
  placed table needs its unit as well).
- **Tests**: the old package's 28 cases per the audit (24 PORT, 1 COVERED,
  1 SPLIT, 2 DROPPED; the PORTs that need two kits land in the demo,
  decision 12), plus
  U1 (exactly the 25 seated keys are units, each capacity equal to the old
  `seats`), U2 (no other key is a unit), conformance, the snapshot, the
  geometry comparison.
- **CI**: `check_kit_deps` covers the new kit.

## R2. The plan library ready for a POS host

Each item lands in `packages/jet_cad_2d_plan` (0.8.0, unpublished; these
join that release) with a test and a named mutation.

- **H1. Typed tool ids.** `PlanToolIds` is exported from the barrel. The
  host guide shows `PlanPermissions(tools: {PlanToolIds.select, ...})`.
- **H2. A host's own symbols** come as a small kit: `PlanKit(id:
  '<host>', symbols: [...])`. No new API; a test loads a host kit beside
  the restaurant kit and places its symbol; the guide shows it.
- **H3. Two views of one controller**: the last canvas placed drives the
  camera and `canvasRect`; the others draw. Written in the doc comment and
  the guide; a test mounts two, checks which drives, unmounts the last
  and checks the first takes over.
- **H4.** A test of `userCamera: false` alone (no pinch, pan or wheel
  moves the camera; the host's `centerOn` still does).
- **Groups across a relabel**: the 2b rule stays (a group naming a label
  no unit holds is dropped on restore); the guide warns a POS.
- **O1. The drag snap.** A test first: dragging a unit with `plan.select`
  must not snap to the dragged unit's own pre-drag geometry. If it does,
  the dragged objects are excluded from the snap candidates.
- **O2.** The Page panel's orientation row fits its labels at 1440 px and
  at the panel's narrowest width (no mid-word wrap); a golden-free test
  measures the text's line count.
- **O3. The page-flow signal.** A public `ValueListenable<bool>
  PlanController.pageFlowBusy`: true from an export's or a print's start
  (the dialog included) to its end. The 3b demo's busy wrappers move to
  it, closing the gap between the dialog and `onExport` (3b's N6-gap
  becomes N6-closed).
- **O4. Re-wording in the same frame.** A tool notice re-words in the
  frame the locale changes in; the 3a test that pins the one-frame lag
  flips.

## R3. The restaurant demo

`apps/restaurant_demo`, rewritten in place on `jet_cad_2d_plan`,
`jet_cad_2d_kit_architecture` and `jet_cad_2d_kit_restaurant`; it names
neither old package (a boundary test, as 3b's N1).

- **Every feature kept**, on the new API (the parity companion's §3):
  two areas (Salon, Teras), each a `PlanController`; the Design/Service
  toggle; selection and find by table number; the table menu (status,
  merge, split, link a POS id as host data); statuses, random included;
  zones and fade others; the demo's own service bar, export and print;
  save, revert and restore layout; the events log; en/de/tr.
- **The samples** (decision 9): `lib/samples/salon.dart` and
  `teras.dart` as `PlanBuild`s: walls from the architecture kit's
  parameter classes, tables placed from `restaurantSymbolDefinitions()`
  with their numbers in build order (Salon: 1-3, 4-5, 6-7, 8-11), opening
  clean with nothing to undo.
- **Platforms**: the runners stay (android, ios, linux, macos, web,
  windows). The gate builds macOS, web and the iOS simulator; Android if
  its toolchain is on the machine, else the reason is written in the
  results note.
- **Tests**: the old 67 demo cases per the audit (65 PORT, 2 SPLIT), the
  kit's moved cases (decision 12), the boundary test, and **POS1**, an
  integration test on macOS driving the real app: open the Salon, switch
  to service, set statuses, merge two tables, link a POS id, save and
  restore the layout, export a PNG, and a screenshot into the results
  note.

## R4. The parity table and the host guide

- **The parity table** (A14): the companion's rows become the table of
  record; each row closes as HAVE or RENAMED (with its test), as added in
  R2, or as one of decision 7's five drops. A row with no test is a
  defect. The table lives in the companion file, closed by the exit gate.
- **The host guide**: `docs/host-guide.md` is rewritten for
  `jet_cad_2d_plan` and the kits: install, the controller and the views,
  design and service, units and the POS example (restaurant kit, service
  mode, statuses, groups, host data, events), permissions with
  `PlanToolIds`, a host kit (H2), two views (H3), themes, touch, the
  "never assume" list, and a closing "From `jet_cad_floor_plan`" section
  mapping old names to new. The old guide stays at tag `v0.7.2`.
- **The guide's checks**: `tool/ci/check_guide.dart` and
  `tool/ci/host_probe` move to the new API, so the guide's snippets
  compile and run; `old_host_probe.sh` and whatever still needs the old
  packages stay until 4b removes them.

## R5. The exit gate

- Every touched package's tests, analysis and format green
  (`jet_cad_2d_plan` and `jet_cad_2d_integration` with
  `--enable-vmservice`); the new kit and the demo green; the engine
  packages unchanged.
- Dry-runs of `jet_cad_2d_kit_restaurant` and `jet_cad_2d_plan` with 0
  warnings; `check_kit_deps`, `check_guide` and the host probe green.
- Builds: the demo on macOS, web and the iOS simulator (Android as above).
- POS1 green on macOS, its screenshot in the results note.
- Every test-audit row and every parity row closed.
- The controller's review of each task in the ledger; STATUS and a
  results note; the ledger archived onto the branch.
- Then the human is told the restaurant demo runs on the new packages.

## Out of scope

- **4b:** the README pictures, removing `jet_cad_floor_plan`,
  `jet_cad_restaurant_symbols` and `apps/floor_planner`, the CI moves not
  needed by R4, raising the dependency floors, the release checklist, the
  publish (the human's).
- A parametric table type (decision 4).
- Integrating monepro or any POS.
- The open items left for later (decision 3).
- `PlanObject.liveTypeIdOf` (carried from 3b): only if R3 needs it.

## Risks

- **The demo's size**: 2,700 lines and 67 tests on an API that changed
  every name. The audit maps each case; the porting rules of 3a hold.
- **The samples' synchronous definitions**: a build gets no symbol
  services; `restaurantSymbolDefinitions()` must hand the same definitions
  the library loader yields, or a placed table differs from a gallery one.
  A test compares them.
- **O1 and O4 touch tested 2a code**; each lands with its mutation and
  the 2a suites green.

## Amendments to other specs

- **Umbrella A13:** sub-project 4 is split into 4a and 4b (decision 2);
  A11's "the restaurant kit's pictures" and the README work are 4b's.
- **Umbrella A14:** the five drops of decision 7, on the human's word.
- **3b spec:** N6-gap closes through O3.

## Revision history

- **Revision 1:** the design approved in chat; the audit's decisions
  (9-15) taken by the controller, decision 9 to be confirmed by the human.
