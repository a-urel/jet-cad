# Final whole-branch review: plan library 2b (service mode)

Reviewer: Opus, read-only. Base 651e3d09, head e7b7ceb6, 43 commits. Read: the spec
(revision 4 plus amendments), the global constraints and Review Focus, the ledger, the
results note, the whole production diff (`final-lib.diff`), and the current files for
`unit_index.dart`, `unit_label_system.dart`, `service_record.dart`,
`unit_status_painter.dart`, the group and focus painters' `paint`, `unit_overlays.dart`
(layer state) and `firstLeafOf`. I opened test files only to check a named risk
(`service_record_controller_test.dart` SR-C14, `plan_service_view_test.dart` SV-7,
`unitAt` call sites, `theme_canvas_test.dart`). I ran no test and changed nothing.

## Strengths

- **E5 matches the spec closely.** `GeneratedInstance`/`GeneratedAttrib` validate as
  S1 says. `_planInstances` checks every definition before it plans any command. A
  match plans a command only on an exact difference: `Transform2.equals` with zero
  tolerance, `_samePayload`, and text `!=`. A text rewrite passes the ATTRIB's own
  tag. The guard's node branch compares `InstanceNode.==`, and a components-only
  write seeds nothing, as the comment in `_run` says. `_subtreeRemoval` now removes
  the instances' entities, which closes the dissolve gap. The survey stays O(entities
  + nodes). The CHANGELOG states the one behaviour change: any `InstanceNode` child of
  an object is generated, and a type without `instances` removes it.
- **The seams between tasks hold.**
  - `UnitLabelSystem` stamps root instances only.
  - `setUnitsLabel` refuses generated units.
  - The panel's unit section goes through `placedUnitOf`.
  - `serviceMovesOf` and `matchServiceMoves` skip generated units.
  - `ServiceTool._startDrag` keeps only placed roots, and groups with a generated
    member are refused.
  - The design gates map every key under a parametric or lock-set object to that
    object (`generatingObjectOf` allocates nothing and walks only the parents), and
    `bandAccepts` refuses those keys.
  - In design, `select(labels)` skips generated units.

  I found no path that selects a seat in design, drags one in service, or relabels
  one.
- **No service-side path edits the design or its history** among the controller's
  members (see I-1 for the widget path). Specifically:
  - `execute`, `deleteSelection` and every host write are refused in service.
  - `undo` and `redo` re-point to the active document's dispatcher.
  - The copy's boundary goes through `_lock(objects, copy.commands)`, so only the
    copy's history is cleared.
  - `_damageCopy` stays inside the copy.
- **Lifecycle is consistent.**
  - Every place that builds a copy (`setMode`, `_replace`, `resetService`,
    `restoreService`) goes `_buildService` → `_attachService` → swap → `_dropService`,
    and the old session is disposed after the frame that unmounts its view.
  - Each copy gets a `_ServiceCanvas` keyed by `ObjectKey(session.document)`.
  - `ServiceSession.host` is put back to `none` in `dispose`.
  - `detach` cancels the stream and removes the selection listener.
  - `dispose` empties `_droppedServices`, so a late post-frame callback is a no-op.
  - The listeners on `PlanCanvas`, `PlanServiceView`, `UnitInspector` and
    `UnitOverlayLayer` are paired with removals and re-bound on a controller or
    document swap.
- **The frame path is clean.**
  - The three painters rebuild on identity keys (the unit index, the maps, the paper,
    the theme). Each frame then runs an indexed loop with reused `Path`, `Paint`,
    `Paragraph` and matrix objects.
  - `UnitIndexCache.current` is O(1) when nothing moved.
  - The picker allocates nothing per unit (`_point` buffer, cached inverses).
  - A band does no unit work until pointer-up.
  - The hover's events record is cached per widget.
- **The public surface matches S3-S5 by name**, and the barrel leaks nothing internal
  (`ServiceSession`, `UnitIndex` and `ServiceHost` stay internal). No package version
  changed. Only `vm_service` was added. The old packages and every
  `analysis_options.yaml` are untouched (checked with `git diff --stat`).
- The ledger is honest, and the results note maps every spec line and every S5 row to
  a test id.

## Issues

### Critical (Must Fix)

None found.

### Important (Should Fix)

**I-1. In service, a mounted `PlanCanvas` still edits the design** (S3: "the design
is not edited in service … `dirty` never moves in service").
- **Where:** `packages/jet_cad_2d_plan/lib/src/canvas/plan_canvas.dart:361`
  (`build`, which never reads `mode`); `controller/plan_controller.dart:798-799`
  (only `execute` is gated); `jet_cad_2d_flutter/lib/src/tool.dart:108`
  (`ToolContext.execute` → `document.commands.execute`).
- **What goes wrong:**
  - S3's rule is enforced on the controller's members only. The design's tools (the
    select tool's move, rotate and Delete, the drawing tools, `plan.symbol`, kit
    tools, grips) execute through `ToolContext` straight on the design's
    dispatcher, whose engine permissions stay `_permissions.draft` in service.
  - `PlanEditor` hides this by swapping its canvas for the service view.
  - The composable path does not. README and 2a P2 offer `PlanCanvas` and the
    panels as standalone widgets, and `PlanServiceView` renders nothing in design,
    which invites a host to keep both mounted.
- **Why it matters:** a host that toggles `setMode(service)` with a `PlanCanvas` on
  screen lets staff move or delete design objects during service. `dirty` moves.
  `serviceMovesOf` then diffs the copy against a design that moved under it, and the
  record's `from` values go wrong. Neither the spec nor the CHANGELOG says this
  usage is unsupported.
- **Fix (minimal):**
  - While `_service != null`, set the design document's engine permissions to
    `DraftPermissions.readOnly`, and restore `_permissions.draft` on leaving.
  - In the `permissions` setter (`:2019`), write `value.draft` only in design.
  - `_settleSeparator` already lifts permissions via `_unrestricted`.
  - Pin it with one test: a `PlanCanvas` mounted in service, a drag on an object →
    `save()` and `dirty` unchanged.
- **Alternative:** `PlanCanvas` shows nothing or stays inert in service, mirroring
  `PlanServiceView` in design. That is less robust, because kit tools and grips
  would still need it.

**I-2. The ledger's fix-wave items are still open** (A12, ledger rulings after
Task 17):
- **Must land before merge:**
  - `jet_cad_floor_plan/test/host/view_palette_test.dart`'s service-mode palette
    tests (M-DT-10, M-DT-11 in selection mode, the ServiceView papers group) must
    be ported, as the ledger ruled after Task 17 ("ported in the final fix wave").
  - The results note still calls this gap "Open" (`…-2b-results.md:772-773`).
- **Documentation fixes:**
  - STATUS's In-flight 2a paragraph still says A14 "awaits the human's word".
  - STATUS's "Resume here" pointer needs updating.
  - The engine CHANGELOG's Unreleased section has a stray blank line between the
    E1-E4 bullets and E5's (`packages/jet_cad_2d/CHANGELOG.md`, just before
    "`ParametricType.instances…`"). It is a published file.

**I-3. `restoreService` and `resetService` do not pin their notifications** (ledger
Task 13, "FINAL REVIEW SHOULD TRIAGE").
- **Where:** `controller/plan_controller.dart:1915` and the `notifyListeners()`
  after it (restore); the `notifyListeners()` after `:1942` (reset).
- **The gap:**
  - S3 names both: "moves `revision`, notifies listeners".
  - `SR-C14` covers a move, `resetService`, a load and a mode switch, but not
    `restoreService`.
  - A host that re-reads `units`/`unitDetails` on `revision` would miss a restore.
- **Why `notifyListeners` matters more:** it is what moves `PlanServiceView` onto the
  new copy. `PlanServiceView` listens to the controller and to `mode` only.
  Without it, the view stays on a session that is disposed after the frame.
- **Fix:** extend `SR-C14` with a `restoreService` step (`moved() == 1`). Add a
  view test that restores, pumps, taps a moved unit and expects the tap and the new
  `activeDocument` (as SV-7 already does for `resetService`).

**I-4. The drag's `roots.isEmpty ||` spend is unpinned** (ledger Task 14, "FINAL
REVIEW SHOULD TRIAGE"; M-ST-empty survives).
- **Where:** `service/service_tool.dart:413`.
- **What the mutant does:** without the clause, a drag that starts on an unselected
  seat replaces the selection with the seat. The seat's outline then rides the drag
  preview (`selectionPreviewTransform`) and snaps back on release, and nothing
  executes.
- **Why it matters:** the class doc and S4 ("selected seats stay where they are")
  name this rule, and the visible behaviour of the mutant is wrong.
- **Fix:** one test. A mouse drag from an unselected seat (no group) leaves the
  selection unchanged, adds no Move step and calls neither `onLayoutChanged` nor
  `onUnitsMoved`. It must go red under M-ST-empty.

### Minor (Nice to Have)

**M-1. A mixed drag previews the seats moving.**
- **Where:** `service/service_tool.dart:286`, `service/service_session.dart:81-86`.
- **What happens:** the service `ToolContext` has no `grips`, so
  `SelectionOverlayPainter._paintPreview` draws every selected key on `T`
  (`jet_cad_2d_flutter/lib/src/selection_overlay.dart:243-248`). That includes the
  selected seats the drag leaves in place: their outlines travel with the pointer
  and jump back on release.
- **Fix:** give the service context an `isMovable` view (a small grips adapter that
  answers false for generated keys), or report a preview only for `_moving`.

**M-2. `unitAt` is never asked about a seat.**
- **Where:** `controller/plan_controller.dart:1025`.
- **The gap:** every `unitAt` call site in the tests targets a placed table. A
  mutant that builds the controller's picker with `placedOnly: true` survives (the
  ledger's Task 9 carry, never closed).
- **Fix:** one assertion in service: `unitAt` at a seat's centre returns its label.

**M-3. `setUnitsLabel`'s lock clause is unpinned.**
- **Where:** `controller/plan_controller.dart:1386`.
- **The gap:** without `|| _session.locks.covers(...)`, a label write on a placed
  unit of a missing kit's symbol still answers false, because the lock expander
  refuses it inside `execute`. But it also raises `lockHint` (the canvas toast) from
  a host call. `UA-locked-write`'s title says "no label" without calling
  `setUnitLabel`.
- **Fix:** add the call, with `lockHint` still false.

**M-4. Every design edit rebuilds the unit index, units or not.**
- **Where:** `_onDesignChange` → `_refreshSelected`, `controller/plan_controller.dart:1471-1476`.
- **The cost:** the read of `_activeUnits.current` forces a full `UnitIndex.of`
  (O(nodes + entities)) on every design edit, undo and redo, even with an empty
  selection and no unit definition in the plan. This is edit rate, not frame rate,
  so it breaks no non-negotiable. But a large plan without units pays it on every
  keystroke of the text tool.
- **Fix:** return early from `_refreshSelected` when the active selection is empty
  and nothing is selected; or have `UnitIndex.of` skip the walk when
  `withComponent<UnitComponent>()` is empty (the label system already uses that
  cheap test).

**M-5. Exporting coloured units is O(coloured units × entities).**
- **Where:** `export/unit_colour_underlay.dart:47`.
- **The cost:** `unitTopOf(document, u.definition)` is called without
  `leavesByOwner`, so `firstLeafOf` scans every live slot once per coloured unit.
- **Context:** this is the oracle's shape (`table_color_underlay.dart:52`), so it
  is not a regression. With 500 coloured seats on a large plan it is noticeable at
  export time.
- **Fix:** pass `document.leavesByOwner` once, or reuse `UnitInfo.top`.

**M-6. The design-side panels read the active index.** `PlanPropertyPanel` (`:305-308`,
`:377`) and `colour_row.dart:44` read `c.unitIndex`, which is the copy's in service,
while they work on the design's `selection` and `document`.
- **Impact:** harmless today (the handles are equal, and commits are refused in
  service), and only reachable when a host keeps these panels mounted in service.
- **Fix:** they should read `documentUnits.current`, so the design widgets never
  mix documents. This goes away with I-1's fix if the panels are made inert in
  service.

**M-7. The plan library's CHANGELOG omits public additions:**
- `cameraValue`/`PlanCamera`, `worldToGlobal`/`globalToWorld`;
- `export`/`print(unitColourOpacity:)` and `PlanExportRequest.unitColourOpacity`;
- `PlanEditor(unitInspectorBuilder:)` and the unit section in the property panel;
- `isUnitSymbol`;
- `symbolsState` now typed `SymbolsState` (2a's `PlanSymbolsState` removed).

The kit's CHANGELOG lists `unitLabelHeight`, `unitLabelStamp` and `unitLabelPayload`,
but not `kUnitLabelMaxHeight`, `kUnitLabelTopShare` and `kUnitLabelTextAttrs`, which
are now part of the published contract beyond the spec's list (justified: the plan
library needs them).

**M-8. `PlanExportRequest(unitColourOpacity:)` accepts any double** (Task 15
deferred, `export/registries.dart:130`). It is a public constructor whose doc implies
[0, 1]. Call `checkedUnitColourOpacity`-style validation there.

**M-9. Cosmetic leftovers from the ledger** (fold into the fix wave):
- the `UnitTop` doc says "A table's top" (`unit_picker.dart`);
- `symbol_placer.dart`'s header says "no table record";
- `service_tool.dart`'s stale "locked member" comment near `:362`;
- `DS-click-attrib`'s comment still names M-DS2;
- the M-SS5 and M-SS7 markers sit on the wrong lines;
- `UnitInspector` has no class doc;
- `box_kit.dart:26` is 95 columns;
- `PlanServiceView._listen` listens to both `c` and `c.mode`, so a mode switch
  makes two `setState`s (harmless).

## Ledger triage

| Ledger line | Verdict | Reason |
|---|---|---|
| T1 `_instanceRemoval` fill-first order untested | can wait | no generated instance carries a FILL; only a loaded file could |
| T1 non-ATTRIB entity on a matched instance untested | can wait | loaded-file edge; the planner reads ATTRIB kind only |
| T1 M-E5-tag-add evidence lacks quoted line | closed | fix round 1 quoted it |
| T1 "instances after generate" order unpinned | can wait | ordering is internal to one plan; output equality is pinned |
| T2 E5G-refuse identity vs `==` | can wait | ruled; `==` is the guard's own measure |
| T2 report evidence gaps | closed | Task 17 re-ran the engine and the CI matrix |
| T2 untested branches (re-parent, recolour of a seat) | can wait | the same `InstanceNode.==` condition, already pinned, catches them |
| T2 dependents | closed | Task 17's matrix |
| T3 host_words/plan_kit duplicate namespace switch | can wait | refactor; both pinned by tests |
| T3 `unit:` word only in a declared locale not reported | can wait | conformance nit, pre-0.1.0 |
| T3 `unit:acme/` (empty kind) passes | can wait | matches `category:`'s rule; revisit with R4 before 0.1.0 |
| T4 `_named` re-creates PlanSymbols | can wait | identity caches unaffected today (gallery keys by id) |
| T4 no notifier identity check across `retrySymbols` | can wait | M-PB8 killed anyway |
| T4 box_kit.dart line length | can wait | cosmetic (M-9) |
| T5 test_kit `entryTop` re-implements `servedTopOfEntry` | can wait | test support only |
| T5 TK-row leaves `ref.basePoint`/`top` unpinned | can wait | the production values are pinned by PB-def-top(-poly) |
| T5 `rowSeatTransform` its own oracle | can wait | test kit geometry; UL-turn-row checks the labels independently |
| T5 "TDD" wording | closed | process only |
| T6 carry to Task 8 (cache key, locked layer) | closed | DS-layer (M-DS12, M-DS13) |
| T7 M-UL-turn mutates the test kit | can wait | production is pinned by M-UL-root |
| T7 `samePayload` re-implemented | can wait | ported verbatim |
| T7 imports, symbol_placer header | can wait | cosmetic (M-9) |
| T8 DS-click-attrib comment | can wait | cosmetic (M-9) |
| T8 `old.selectUnitsOnly != …` term unrecorded | can wait | run the mutation once in the fix wave; the ported R-1 cases should kill it |
| T8 UnitTop doc | can wait | cosmetic (M-9) |
| T9 `setUnitsLabel` lock clause unpinned | can wait (recommended) | the expander still refuses; only `lockHint` differs (M-3) |
| T9 lockBroken reports nothing | closed | ruled and documented |
| T9 new-ATTRIB branch / `unitAt` on a seat | branch closed (TS5); `unitAt` can wait (recommended) | M-2 |
| T9 framingFor doc, comment length, RED | can wait | cosmetic |
| T10 inspector doc; generated/locked branches; LK1; de quotes; RED | can wait | the generated branch is unreachable from the design selection; „…" is correct German typography |
| T10 editor_options_test imports a test as a library; V-5 reach | can wait | test hygiene |
| T11 `_buildService` constructor-throw cleanup untested; boundary asserts | can wait | no seam; code reviewed correct (copy disposed, measurer cleared) |
| T12 M-SS5/M-SS7 markers | can wait | cosmetic (M-9) |
| T12 SS-relabel positive premise | can wait | one-line premise; fold into the fix wave |
| T12 `_refreshSelectedGroup` per refresh | closed | RB16-hall: no selection notification per pointer move |
| T12 state kept across reset, restore, newPlan | closed | SR-state-kept, SR-CF3, TG-C11 |
| **T13 restore's `revision++`/`notifyListeners`, reset's `notifyListeners` unpinned** | **fix before merge** | spec-named; `notifyListeners` is what moves the view to the new copy (I-3) |
| T13 restore apply-failure path untested | can wait | unreachable under the strict match |
| T13 restored member naming only a hidden or locked unit kept | can wait | matches S3's wording ("names no unit of the design") and decision 7 (a locked unit is grouped); a pin is nice to have |
| T14 PA4/PA5 baseline ruling | closed | confirmed by the reviewer |
| **T14 `roots.isEmpty ||` spend unpinned (M-ST-empty)** | **fix before merge** | spec-named rule with a visible mis-behaviour under the mutant (I-4) |
| T14 baseline subtracted for every watched class | can wait | bounded O(1) per pick; the ruling stands |
| T14 RB16-hall lacks a "band covers a seat" premise | can wait (recommended) | Review Focus 5 leans on it; one-line premise |
| T14 PA1-PA3 lack a Transform2 watch | can wait | oracle gap kept by A12 |
| T14 service_tool stale comment | can wait | cosmetic (M-9) |
| T15 `PlanExportRequest.unitColourOpacity` unchecked | can wait | M-8; every library path passes checked values |
| T16a VE18 reorder; helper name; duplicate `mode` listener; `pagePlan` unused | can wait | brief-mandated or harmless |
| T16a print bypass (carry) | closed | M-SV-3c |
| T16b plan_editor.dart length | can wait | structure only |
| T16b `snappingAllowed` reset asymmetry | can wait | harmless today; revisit with multi-view hosts |
| T16b barrel_test B5 weak | can wait | the oracle's own weakness |
| **T17 STATUS A14 paragraph; engine CHANGELOG blank line** | **fix before merge** | ledger sends these to the final fix wave; published CHANGELOG and canonical STATUS (I-2) |
| **T17 note says view_palette gap "open"; STATUS resume pointer** | **fix before merge** | as above (I-2) |
| **Ruling: view_palette_test service tests ported in the final fix wave** | **fix before merge** | A12, ruled (I-2) |
| Ruling: F-1 of chrome_change_test unported | can wait (for the human) | a design-only 2a gap, ruled out of 2b |

## Declined to judge

- **The design's history surviving a freeze made in the copy:** the spec rules it
  (Risks, B3).
- **A window band over a seats-only row selecting nothing:** decision 9, the
  human's ruling.
- **`selectTool` true with no view:** decision 9.
- **The no-compatibility renames** (`UNIT`, `jetcad.unit_*`, `jet_cad.service`):
  the umbrella's decision 9 and R-13.
- **A drag from an unselected seat being spent rather than selecting or panning:**
  a plan decision (Task 14).
- **`unitColourUnderlay` skipping a self-intersecting top while the canvas fills
  it:** documented as today's known difference.
- **`_ChromeOrigins` calling controller methods during build (R-13 reframing):**
  ported verbatim from the oracle; its correctness is the ported V7/K1 tests'.
- **The E3/`notifyLoaded` interplay with `UnitIndexCache`'s state-id key after a
  damaged rollback:** an engine or 2a contract, outside 2b's diff.
- **A hook failure during `restoreService`'s apply firing `_lockFromCopy` before
  the swap** (it refreshes flags against the old copy): transient, and the spec is
  silent on hook failures during a restore.
- **`_replace` in service when `_buildService` throws:** unreachable for a design
  that just decoded; the spec is silent.
- **Seats a neighbour-reading row regenerates differently in the copy:** the test
  kit's row reads only its own parameters; this belongs to the cinema kit's spec.
- **Test-file quality beyond the named risks:** each was reviewed per task.
- **The gate counts in the results note:** reviewers re-ran them per task; I did
  not re-run them (I was told to run no full suite).

## Recommendations

1. In one fix wave:
   - I-1: the design read-only in service, plus its test.
   - I-2: port view_palette's service tests; fix STATUS, the note and the engine
     CHANGELOG.
   - I-3: the restore's revision and listener tests.
   - I-4: the M-ST-empty test.
   - Fold in M-2, M-3, the RB16-hall premise and the M-9 cosmetics; they are cheap.
2. Take M-1 (preview of the seats in a mixed drag) and M-4 (an index rebuild per
   design edit) into the same wave if time allows. Otherwise record them for
   sub-project 4's parity work.
3. Before 0.1.0 of the kit, decide whether `unitLabelHeight`, `unitLabelStamp`,
   `unitLabelPayload` and the `kUnitLabel*` constants stay public contract or move
   behind `authoring.dart`.

## Assessment

**Ready to merge?** With fixes.

**Reasoning:** I found no data loss and no broken spec behaviour among the branch's
own paths. E5, the units, the copy and the service tool are sound and well isolated.
Four things should land first: the ledger's own fix-wave items (the ported palette
tests, STATUS, the note and the engine CHANGELOG), pins for two spec-named rules
(the restore's notifications and the seat-drag spend), and closing the composable
path where a mounted `PlanCanvas` still edits the design in service.
