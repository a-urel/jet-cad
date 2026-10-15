# SDD ledger — plan: docs/superpowers/plans/2026-10-14-plan-library-2b.md

Spec: docs/superpowers/specs/2026-10-14-plan-library-service-mode-design.md (revision 4, approved 2026-10-14 "onaylıyorum"; amended 35d44660 "a held object stays held", R-9).
Branch feat/plan-library-2b, worktree .claude/worktrees/plan-library-2b, cut from main 651e3d09 (= origin/main, checked 2026-10-14).
Plan approved by the human 2026-10-14 ("onaylıyorum. başla"). Execution: subagent-driven. Plan commit 6bfd6d76.
Global constraints for reviewers: .superpowers/sdd/2026-10-14-plan-library-2b/global-constraints.md (plan's Global Constraints + Review Focus, verbatim).

## Pre-flight conflict scan (controller, 2026-10-14)

Sources: the planning passes' logs (scratchpad plan-2b/reconcile-log.md: 53 edits, 13 interface problems resolved; preflight-log.md: names, files, mutation ids, run commands, commit order, staging), plus a fresh parse of every task's Files block for shared paths (below).

### Pairs sharing a file or interface

| Tasks | Shared | Produces → consumes | Found |
|---|---|---|---|
| 1, 2 | engine parametric_system.dart, regeneration.dart, cascade_test.dart, CHANGELOG.md | 1: output, hook, survey, matching; 2: guard, seeding, adds, dissolve over 1's survey | consistent; CS11 premise changes in 1 (R-4), its adds refused in 2. CHANGELOG: 1 adds, 2 extends the same Unreleased entry |
| 1, 4 | plan lib/src/kits/guard.dart | 1 adds the `instances` forwarder (R-1); 4 only tests it (PB-guard) | consistent; 4's Step 2 tests pass at once (R-1, preflight) |
| 3, 4 | plan lib/src/controller/services.dart | 3 adds contract members (symbolDefinition, symbolsState) with stubs; 4 implements them | consistent (R-3 KitServices stubs in 3) |
| 3, 16 | CHANGELOG.md (kit / plan) | 3: kit CHANGELOG 0.1.0 additions; 16: plan CHANGELOG + README | different files per package; consistent |
| 6-16 | plan_controller.dart | each task adds its members; 6 declares `unitIndex` once (R-10) | consistent after reconcile (unitIndex single declaration) |
| 6, 7, 8 | controller/session.dart | 6 unit index/cache in session; 7 label system in expander stack; 8 select gates | consistent |
| 8, 9, 11, 12, 13, 16 | lib/jet_cad_2d_plan.dart barrel; test/barrel_test.dart (8-13) | each task exports its names; 16 adds only its 4 new exports (preflight fix d) | consistent |
| 6, 8, 14 | test/support/unit_fixtures.dart | 6 owns (ports table_fixture), 8 and 14 append (R-19) | consistent |
| 11, 12 | test/support/service_plans.dart | 11 creates, 12 appends; re-exports kDeg37/addLayer (R-19) | consistent |
| 11, 14 | service/service_session.dart | 11: session + ServiceHost; 14: ServiceTool replaces tool slot (R-17; 11 creates no _IdleTool factory beyond R-17's) | consistent |
| 9, 10 | units_only_select_test.dart, value_words_test.dart | 9 creates, 10 grows | consistent |
| 9, 11 | unit_data_test.dart | 9 creates; 11 appends TC6/HD4/TA3 (preflight) | consistent |
| 10, 16 | editor/plan_editor.dart | 10 unit section/inspector; 16 mode switch | consistent |
| 15, 16 | canvas/plan_canvas.dart | 15 painters, fills; 16 service view overlays | consistent; kUnitColourOpacity declared in 15 (R-22) |
| 12 → 17 | SS-relabel | written unrun (R-25) | Task 12 reviewer checks it |
| 14 → 16, 17 | allocation tests need --enable-vmservice | 14 adds the CI flag; 16 A10/B9/B10 and 17 Step 2 run with it | consistent after preflight |

### Each task against itself

| Task | Result |
|---|---|
| 1 | Files vs git add (7 paths incl. guard.dart); 9 tests vs Step 10 count; 24 mutation targets present in its code — clean |
| 2 | Step 13 widened to CI's dependents of the engine (preflight) — clean after fix |
| 3 | Files vs git add, exhaustive switches, PlanServices fakes — clean |
| 4 | git add of removed plan_symbols_state.dart dropped; Step 2 heading reworded (preflight) — clean after fix |
| 5 | `writeCharCodes` → `String.fromCharCodes` (preflight) — clean after fix |
| 6 | port lists cover mutations; Step 11b UI-def-missing added (R-24) — clean |
| 7 | prose ports; UL-seat relies on regeneration's touched including added seats (reconcile item 7) — clean |
| 8 | gates, picker, barrel — clean |
| 9 | unitIndex removed from Step 4's undefined list; M-UA1x/M-UA2 made concrete (preflight) — clean after fix |
| 10 | clean |
| 11 | _IdleTool per R-17; TC6/HD4/TA3 staged — clean |
| 12 | SS-relabel added unrun (R-25) — reviewer to confirm |
| 13 | clean |
| 14 | vm_service dev dependency (R-23); commit-step text made definite — clean after ruling |
| 15 | clean |
| 16 | skip notes, ED-9 set literal, barrel exports fixed (preflight) — clean after fix; dispatched as 16a/16b (R-7) |
| 17 | --enable-vmservice in Step 2, CI matrix once in Step 4 — clean after fix |

Rubric conflicts (plan-mandated defects): none found.

## Rulings carried from planning (plan appendix R-1 … R-25)

- Ruling: R-1 GuardedType forwarder for `instances` lands in Task 1 (guard.dart), Task 4 keeps only PB-guard tests — GuardedType implements ParametricType, the hook breaks compilation otherwise — if wrong: Task 4 duplicates or misses the forwarder, caught by analyze.
- Ruling: R-4 engine test CS11's premise `drift(doc) isEmpty` becomes `[hP1]` (Task 1) and its adds into P1 are refused (Task 2) — spec S1: an InstanceNode directly under a live object is a generated instance; CS11's purpose (cascade removes the object) is kept — if wrong: an engine test's assertion changed against A12; reverting means E5's instance rule must exclude hand-made instances.
- Ruling: R-9 spec S2 amended "a held object stays held" (35d44660) — 2a's lock rule always locks an unknown component — if wrong: UI-flip pins the opposite behaviour of revision 4.
- Ruling: R-10/P-1 fixture keys `fx.*`/`test.fixture.*` are fixture data (2a precedent) — if wrong: cosmetic rename of test keys.
- Ruling: R-11a VR1-VR3 not ported (sessions own the systems; premise impossible) — if wrong: three regression tests lost.
- Ruling: R-13a/b service record format name `jet_cad.service` v1 and renamed keys — no-compatibility wave (umbrella) — if wrong: saved service records from today's package do not load (accepted difference).
- Ruling: R-13c TG-C10's serviceEdited expectation flips: groups count (spec decision 4 difference) — if wrong: one ported assertion changed.
- Ruling: R-13d TG-C11's resetLayout step retired; SR-reset pins resetService's new rule (spec difference) — if wrong: one ported step lost.
- Ruling: R-13 (F-T9a/b/c) undo labels "Unit data"/"Unit colour"; toString texts gain the kind token; DC8/9/11/12/13/17 ported a second time for unitChanges — S5 renames — if wrong: label strings differ from today.
- Ruling: R-14 2a's PM-8 `restrictsPick` expectation becomes isTrue; PM-1/PM-7 grow; ED-9 gains exports — spec S2: the design's pick is always restricted — if wrong: one 2a assertion flipped.
- Ruling: R-16 TF1/TF7/EX5 room and tint lines go to sub-project 3 (2a precedent) — if wrong: those lines are unported until 3.
- Ruling: R-17 ServiceHost + settable ServiceSession.host; ServiceSession.tool is a ServiceTool; ServiceOptions has no serviceMove (the tool reads the permission per press) — if wrong: API shape rework in 11/14.
- Ruling: R-19..R-22 one owner per test-support helper; firstLeafOf in Task 6; placed label height reads one box; kUnitColourOpacity declared in Task 15 — reconcile — if wrong: duplicate helpers, caught by analyze.
- Ruling: R-23 `jet_cad_2d_plan` gains dev dependency `vm_service: ^15.2.0` in Task 14 — the ported VM allocation meter imports it; without it analyze and dry-run warn — if wrong: one dev_dependencies line to drop and two allocation tests to rework.
- Ruling: R-24 a missing definition's freeze is pinned on load by Task 6 Step 11b (UI-def-missing) — spec Tests coverage gap — if wrong: one extra test.
- Ruling: R-25 the preflight's nine mechanical fixes accepted; SS-relabel written unrun, Task 12's reviewer checks it — if wrong: Task 12 fix round.

## Task log
Task 1: dispatched (base 6bfd6d76, implementer sonnet, agent acbe8845c5c9624c7)
Task 1: implementer DONE (1012413b); review dispatched (opus, agent ae692f1877aca1120, package review-6bfd6d76..1012413b.diff)
Task 1: review — spec ✅, Needs fixes: 1 Important (plan-mandated coverage gap: matched instance's new definition/transform commands unpinned). Mutation count: 23 targets in Step 14 (controller's "24" was a miscount).
Ruling: Task 1 gains engine test E5-move (row 2 regenerated with new bend and seat: hStool; handles and SeatNote kept, definition hStool, transforms == seatAt exact, drift empty, one undo restores canon; mutations M-E5-def-set, M-E5-transform-set) — spec S1 "Matching" requires both commands and the testing bar requires a named mutation per behaviour; the plan's tests left the true side of both guards unpinned — if wrong: one extra engine test.
Task 1: minor (deferred): _instanceRemoval fill-first order untested (no FILL on a generated instance in fixtures).
Task 1: minor (deferred): non-ATTRIB entity on a matched instance "left alone" untested (kindAt != attrib skip; owned attrib-only mapping).
Task 1: minor (deferred): M-E5-tag-add evidence lacks a quoted failure line (pattern-match failure, not expect).
Task 1: minor (deferred): "instances after generate, same view" order not pinned by a test.
Task 1: fix round 1/5 (2 addressed, 0 open — E5-move test added, M-E5-tag-add evidence quoted; commits 1012413b..4ef4a8d4)
Task 1: complete (commits 6bfd6d76..4ef4a8d4, review clean)
Task 2: dispatched (base 4ef4a8d4, implementer sonnet)
Task 2: implementer DONE_WITH_CONCERNS (bcf4d6b8): E5G-refuse positive control `identical(doc.tree[seat.handle], seat)` → `expect(doc.tree[seat.handle], seat)` (exact InstanceNode ==).
Ruling: E5G-refuse's positive control compares by InstanceNode value (exact ==) instead of identity — a refused move is applied then rolled back, the rollback rebuilds an equal node; the control's purpose (the seat is unchanged) holds under exact == (spec M4 uses InstanceNode.== as the guard's measure); a new 2b test, not a ported assertion — if wrong: a refused edit leaks a value-equal but distinct node, harmless to readers.
Task 2: review — spec ✅, Approved; deviation's cause confirmed real (TransformNodeCommand inverse rebuilds via copyWith).
Task 2: minor (deferred): E5G-refuse could keep identity across the row move (re-read node after refusals, then identical()).
Task 2: minor (deferred): report evidence gaps (generate_document_test summary line, Step 11 three-file run, Step 2 RED lines paraphrased).
Task 2: minor (deferred): untested branches sharing pinned conditions (generated instance re-parented/recoloured; existing node re-parented into a live object).
Task 2: ⚠️ dependents (Step 13) resolved by controller: trusted the report; Task 17 re-runs the CI matrix.
Task 2: complete (commits 4ef4a8d4..bcf4d6b8, review clean)
Task 3: dispatched (base bcf4d6b8, implementer sonnet)
Task 3: implementer DONE_WITH_CONCERNS (b71ab4c8).
Ruling: K2B-ref's fixture `CompoundCommand(const [], label: 'Add')` → `AddDefinitionCommand(Definition(... children: const []))`, assertions unchanged — the engine refuses an empty compound; the test's subject (the pending ref) is untouched — if wrong: fixture-only change.
Ruling: the plan barrel's SymbolsState re-export and PlanSymbolsState's removal stay in Task 4 (its Step 8 git rm's plan_symbols_state.dart), not Task 3 — Task 3's file list leaves the barrel alone — if wrong: one export line moves a task earlier.
Task 3: review dispatched (opus)
Task 3: review — spec ✅, Needs fixes: 1 Important (SymbolDefinitionRef inserted between PlanServices' doc and the class). Evidence asks: M-K2B-2 re-run with 'TABLE'; quote every mutation's red line. ⚠️ Task 4's review must check SymbolsState re-export + PlanSymbolsState removal.
Task 3: minor (deferred): host_words.dart and plan_kit.dart repeat the colon split / namespace switch (plan-dictated); a shared parser would keep namespaces in step.
Task 3: minor (deferred): a `unit:` word present only in a declared locale not reported as wordOrphan — untested.
Task 3: minor (deferred): `unit:acme/` (empty kind) passes validateHostWords and validate (matches today's category: behaviour).
Task 3: fix round 1/5 (2 addressed, 1 open — doc comment moved, mutation red lines quoted; M-K2B-2 'TABLE' transcript missing; commits b71ab4c8..c4e69c78)
Task 3: fix round 2/5 (1 addressed, 0 open — M-K2B-2 'TABLE' transcript pasted verbatim; evidence only, no commit; controller read the report section: `Expected: 'UNIT' Actual: 'TABLE'`, revert exit 0)
Task 3: complete (commits bcf4d6b8..c4e69c78, review clean)
Task 4: dispatched (base c4e69c78, implementer sonnet)
Task 4: implementer DONE (dded3b45); evidence completed on request (no code change); review dispatched (sonnet)
Task 4: review — spec ✅, Approved, with 1 Important plan-mandated gap (servedTopOfEntry's closed-polyline arm and empty-leaves guard unpinned).
Ruling: Task 4 gains PB-def-top-poly (closed-polyline first leaf → its box; open polyline first leaf → whole box) with mutations M-PB9a/b(/c) — spec S2 "top = first leaf's box if closed polyline or circle, else the definition's box"; the plan's fixture never reaches the polyline arm; testing bar — if wrong: one extra test.
Task 4: minor (deferred): _named re-creates every PlanSymbol per load/retry with host words (identity caches see new objects; harmless today) — worth a doc line.
Task 4: minor (deferred): no ValueNotifier identity check across retrySymbols (loading → ready); M-PB8 killed anyway.
Task 4: fix round 1/5 (1 addressed, 0 Important open — PB-def-top-poly + M-PB9a/b; M-PB9c unreachable (SymbolLibraryError rule 4), confirmed by re-reviewer; commits dded3b45..d0af9540)
Task 4: minor (deferred): test/support/box_kit.dart:26 Switches doc line still 95 columns (comment not reflowed).
Task 4: complete (commits c4e69c78..d0af9540, review clean)
Task 5: dispatched (base d0af9540, implementer sonnet)
Task 5: implementer DONE (395ec35f); review dispatched (sonnet)
Task 5: review — spec ✅, Approved.
Task 5: ⚠️ no test moves/turns a row group; RowType.instances bakes view.toWorld(self) into the label stamp, so upright labels after a group move rely on regeneration on the object's transform change — carried to Task 7's dispatch (label system, rotation).
Task 5: minor (deferred): test_kit.dart entryTop re-implements servedTopOfEntry with a different fallback arm (plan-mandated); nothing compares them.
Task 5: minor (deferred): TK-row leaves the row tool's use of ref.basePoint/ref.top unpinned (params.base/top never compared to the seat entry).
Task 5: minor (deferred): rowSeatTransform is its own oracle in TK-row; no independent geometry check (base points spacing apart).
Task 5: minor (deferred): report calls it TDD though no separate RED run (mutations are the evidence).
Task 5: complete (commits d0af9540..395ec35f, review clean)
Task 6: dispatched (base 395ec35f, implementer opus)
Task 6: implementer DONE (9ce5096a, 85065219).
Ruling: P-1 — ported TI1's fixture keys read `fx.stool.round` / `fx.table.two` (R-10/R-19) — fixture data, 2a precedent; assertions unchanged — if wrong: cosmetic key rename.
Task 6: note — controller's dispatch wrongly listed placeSymbol(units:) and placeUnit for Task 6; the plan puts them in Task 7 and Task 8 (checked); implementer followed the plan.
Task 6: review dispatched (opus)
Task 6: review — ❌ 2 Important: TD1's U+00A0 input became an ASCII space during the port (unledgered A12 change); heldTypeOf duplicates LockSet._unknownKit (plan-mandated).
Ruling: heldTypeOf and LockSet._unknownKit share one helper in kits/locks.dart (plan text mandated a verbatim duplicate) — the lock rule and ownerType must name the same component; no behaviour change — if wrong: a small refactor of 2a's locks.dart to undo.
Ruling: TL5's 'TABLE' → 'UNIT' tag in the ported assertion (brief-directed) — spec S2 renames the tag (kUnitLabelTag), a no-compatibility rename (umbrella) — if wrong: saved tables' numbers do not load (accepted difference, S5 item 6).
Task 6: minor (carry to Task 8 dispatch): confirm Task 8's/9's hidden- and locked-layer tests exercise UnitIndexCache's key (tables.mutationRevision) and isLockedUnit's locked-layer branch, not just a fresh index.
Task 6: fix round 1 implementer DONE (abbc9612): escapes restored (TD1, TN7; 5 oracle files compared byte for byte), unknownKitTypeIdOf shared helper, headers reflowed, UnitIndexCache built last. implementer-instructions.md gained the escape trap note.
Task 6: fix round 1/5 (4 addressed, 0 open — TD1/TN7 escapes, unknownKitTypeIdOf, headers, session order; commits 85065219..abbc9612)
Task 6: complete (commits 395ec35f..abbc9612, review clean)
Task 7: dispatched (base abbc9612, implementer sonnet)
Task 7: implementer DONE_WITH_CONCERNS (1a2c645e).
Ruling: UL-place-number gains a placement on a bare plan() with no label system, asserting the label upright — the brief's M-UL-number was masked by UnitLabelEdit restamping touched instances; the added assertion makes the placer's own stamp pinned — if wrong: one extra assertion.
Ruling: UL-turn-row added (rowA turned 37° by TransformNodeCommand about an off-row pivot → every seat label upright, undo restores payloads; mutation M-UL-turn in test_kit.dart's row label stamp) — closes Task 5's ⚠️ (labels upright after an object turns) — if wrong: one extra test.
Ruling: ported LS tests build documents with plan(catalog: boxKit catalog) so SquareParams is registered; assertions unchanged — fixture-only — if wrong: fixture rework.
Ruling: P-2 — TP7's subject becomes the unit kit's square table (brief-directed) — the test kit replaces today's restaurant table; assertion unchanged — if wrong: fixture rename.
Task 7: review dispatched (sonnet)
Task 7: review — spec ✅, Approved.
Task 7: minor (deferred): M-UL-turn mutates the test kit (test_kit.dart), not production; UL-turn-row pins the test-kit + engine restamp pipeline (the label system deliberately does nothing for generated units; M-UL-root covers production).
Task 7: minor (deferred): unit_label_system_test.dart samePayload re-implements GeometryPayload.== (ported verbatim).
Task 7: minor (deferred): unit_label_stack_test.dart imports not alphabetized; symbol_placer.dart header still says "no table record".
Task 7: complete (commits abbc9612..1a2c645e, review clean)
Task 8: dispatched (base 1a2c645e, implementer opus)
Task 8: implementer DONE_WITH_CONCERNS (c612fa1b).
Ruling: 2a's PM-3 fixture value becomes `copyFlag(P.full, name, !flagsOf(P.full)[name]!)` (assertions unchanged) — the new selectUnitsOnly flag is already false in `full`, so the old fixed `false` no longer flips it; the test's purpose (every flag round-trips) holds — if wrong: a 2a fixture changed.
Ruling: M-DS2 is pinned by DS-click-seat, DS-locked-object and DS-plain-group, not DS-click-attrib (resolveHit already maps a seat's ATTRIB to the row; DS-click-attrib is a positive control) — the mutation is still killed — if wrong: none.
Ruling: DS-layer added (layer locked via the layer table, no command, state id unchanged) with M-DS12 (cache key revision) and M-DS13 (isLockedUnit layer check) — closes Task 6's carried minor — if wrong: one extra test.
Task 8: note — PM-6 stays take(10) as Task 3 left it (brief said 9); gates use super parameters; DS-plain-group CompoundCommand needs label:.
Task 8: review dispatched (opus)
Task 8: review — spec ✅, Approved (rulings judged sound: PM-3 fixture, PM-6 take(10), PM-11 separate cacheLocked notifier).
Task 8: minor (deferred): design_selection_test.dart DS-click-attrib comment still names M-DS2 as its killer; reword as a positive control.
Task 8: minor (deferred): no recorded mutation drops plan_controller.dart's `old.selectUnitsOnly != value.selectUnitsOnly ||` term (ported R-1 cases in units_only_select_test.dart should kill it; run once).
Task 8: minor (deferred): unit_picker.dart UnitTop doc still says "A table's top".
Task 8: complete (commits 1a2c645e..c612fa1b, review clean)
Task 9: dispatched (base c612fa1b, implementer opus)
Task 9: implementer stalled (watchdog 600s) mid-controller edit, uncommitted WIP kept; resumed same agent
Task 9: implementer DONE_WITH_CONCERNS (d8774732), full plan suite +929.
Ruling: TD8's setMode tail, HD6's service-copy block and TC7's service-copy block (cut in Task 9, marked "Task 11" in the tests; not in Task 11's plan, which only restores TC6/HD4/TA3) are restored in Task 11 with their assertions unchanged — they need PlanMode.service; A12 keeps ported assertions — CARRY TO TASK 11's DISPATCH — if wrong: three ported assertions lost.
Ruling: diagnostic codes follow Task 6's renames (`table.invalid_data` → `unit.invalid_data`, `table.invalid_color` → `unit.invalid_colour`, `TableDiagnosticCodes.invalidColor` → `UnitProblem.invalidColour`) inside ported expectations — S5 renames, no-compatibility wave; extends R-13's "a name inside an expected text follows the rename" — if wrong: diagnostic code strings differ from today (accepted difference).
Ruling: TC9's toString checks look for `colour` (the field is `colour:`) — left as `color`, the negative check would pass vacuously — if wrong: none.
Task 9: note — NT2 became a testWidgets with runAsync (export needs the binding); unit_api_test calls TestWidgetsFlutterBinding.ensureInitialized(); M-UA1x red at setUnitsData returning false (line 86), not a handle check; no compile-error RED seen.
Task 9: review dispatched (opus)
Task 9: review — spec ✅, Approved (service-mode cuts checked: exactly the setMode parts; every ported expect diffed against the oracle).
Task 9: minor (deferred): setUnitsLabel's `|| locks.covers(...)` clause unpinned (seat refused first by u.generated); UA-locked-write's title claims "no label" without calling setUnitLabel.
Task 9: minor (CARRY TO TASK 11): lockBroken flips unitDetails[].locked but emits no commands.changes, so revision/unitChanges hear nothing until the next edit — report and bump, or document.
Task 9: minor (CARRY TO TASK 10): unitLabelCommand's new-ATTRIB branch (unit_writes.dart) unreachable from the controller; Task 10's panel test should pin it. Also no test picks a generated unit via unitAt (placedOnly: true would survive).
Task 9: minor (deferred): framingFor doc stale (also frames _Units); value_words_test.dart comment ~97 columns; RED never observed (mutations are the evidence).
Task 9: complete (commits c612fa1b..d8774732, review clean)
Task 10: dispatched (base d8774732, implementer sonnet)
Task 10: implementer DONE_WITH_CONCERNS (106a8780), +967.
Ruling: the panel's placed-unit Rotation/Mirror need `transform` and `geometry` (today's `_turnableAt` ported) so SW9's premise (a unit's rotation read-only under runtime permissions) holds; pinned by new UW-runtime-unit + M-UW13 — 2a's panel needed only `transform`; today's code is the oracle — if wrong: a placed unit's rotation is read-only where 2a let it turn.
Ruling: CP11 uses `disc.draw` (as CP1) since `plan.line` has no settings; assertion unchanged — fixture only — if wrong: none.
Ruling: @visibleForTesting static UnitIndex.debugBuilds added for CP12's build count — Task 6 had no counter — if wrong: one test-only member.
Task 10: note — SW6/SW9 use the test kit's unit symbols; inspector's mode half is Task 16 B2 item 10 (checked); carried new-ATTRIB branch now pinned (TS5 + M-UW12).
Task 10: ⚠️ SW1/SW4's table halves in symbol_section_test are unported and no task of the 2b plan names them — reviewer asked to determine whether they are 2b's.
Task 10: review dispatched (sonnet)
Task 10: review — spec ✅, Approved with 1 Important: unitColourTargets' `!c.isLocked(h)` (and generated == false) exclusion unpinned — fix round pending the 2a-deferral audit (to bundle SW1/SW4 table halves if they land here).
Task 10: minor (deferred): UnitInspector class lacks a doc comment; inspector's generated/locked branches unpinned (check Task 16); LK1 Turkish sweep never selects a placed unit; strings_de BadLabel mixed quotes („…") verbatim from brief; RED step not captured.
Audit (2a deferrals vs 2b plan): 50 deferred, 28 placed, 21 missing, 1 unclear — audit-2a-deferrals.md.
Ruling: the 21 missing 2a-deferred items (+1 unclear) are ported in the 2b task whose scope fits, per carry-2a-deferrals.md (Task 10 fix round: SW1/SW4 table halves, T6-c, RP1 unitsOnly, RP12, V-5 table part; Task 11: DC7/10/15/16, NS5; Task 13: NS1 tail; Task 15: TH4 overshoot; Task 16: SW2/LK1 service, dark/theme canvas selection runs, PF2/17/23, snappingAllowed, PlanShortcuts remount) — A12 requires ported tests keep their assertions and 2a deferred these to 2b explicitly; the 2b plan omitted them — if wrong: extra ported tests (cost: time), or a premise found impossible is reported for a ruling.
Task 10: fix round 1 dispatched (colour-row lock pin + the Task 10 carry items)
Task 10: fix round 1/5 (2 addressed, 0 open — CP13/CP14 + M-UW14/15; SW1/SW4 table halves, T6-c, RP1 unitsOnly, RP12, V-5 table part ported; commits 106a8780..7ebae14d)
Task 10: minor (deferred): editor_options_test.dart imports units_only_select_test.dart as a library for helpers (move edgeOf/drag/rotationGripOf to test/support/); some V-5 assertions reachable by no named mutation (engine permissions already block).
Task 10: complete (commits d8774732..7ebae14d, review clean)
Task 11: dispatched (base 7ebae14d, implementer opus)
Task 11: implementer DONE_WITH_CONCERNS (e7f8e05a), +993. Restored TD8 tail, HD6, TC7 blocks; appended TC6, HD4, TA3; ported DC10, DC16.
Ruling: DC15 and NS5 move to Task 13, DC7 to Task 14 (carry-2a-deferrals.md updated) — they need Task 13's serviceEdited/serviceChanges/record/reset and Task 14's service tool; porting now would drop assertions — if wrong: none (still ported, later).
Ruling: SM-execute-false builds the addDrafted command before reading `before` (building it takes a handle from the design's seed, so save() differed by handleSeed alone); no assertion changed — test premise ordering — if wrong: none.
Ruling: ServiceSession builds its UnitIndexCache last (as DocumentSession after Task 6's fix) — the cache listens to `locked`; nothing after it may throw and leak — if wrong: none.
Ruling: lockBroken (and _lockFromCopy) neither report nor bump revision; documented in their doc comments — spec silent; the retried edit (or the next design change) reports the lock flip — if wrong: a host listening to unitChanges sees a lock flip one edit late.
Task 11: review dispatched (opus)
Task 11: review — spec ✅, Needs fixes: 1 Important (copy's E3 path unpinned: _damageCopy notifyLoaded target and undo/redo boundary routing survive mutation) — plan gap. ⚠️ isLockedUnit resolved by controller: exists since Task 6 (unit_locks.dart:11), per-document via UnitIndex. Minors 1-7 folded into fix round 1.
Task 11: fix round 1 dispatched
Task 11: fix round 1/5 (8 addressed, 0 open — SM-copy-damage + M-SM19..21, SM-tool-reset, SM-copy-unreadable, _lock helper, doc citation, markers, boundary asserts, _buildService cleanup; commits e7f8e05a..c0011082)
Task 11: minor (deferred): _buildService constructor-throw cleanup untested (no seam); SM-copy-boundary's added asserts have no mutation of their own.
Task 11: complete (commits 7ebae14d..c0011082, review clean)
Task 12: dispatched (base c0011082, implementer opus)
Task 12: implementer DONE_WITH_CONCERNS (352b3936), +1034. R-25: SS-relabel passed as written (unchanged); M-SS2 turns it red.
Task 12: minor (deferred): M-SS7 / M-SS6 mutation comments sit on lines other than where the tests go red (both still red).
Task 12: review dispatched (opus)
Task 12: review — spec ✅, Approved (ports checked by byte-level diff; SS-relabel judged non-vacuous).
Task 12: minor (deferred): M-SS7 marker (unit_groups_controller_test.dart:398) and M-SS5 marker (:480) sit above expects that stay green; move them to :405 / :483.
Task 12: minor (deferred): SS-relabel lacks a positive premise `statusOf(table) == bill` before the relabel.
Task 12: minor (CARRY TO TASK 14): _refreshSelectedGroup does O(units) + groupIdsByLabel per refresh; if the service band replaces the selection per pointer move, it becomes per-event work (Review Focus 5).
Task 12: ⚠️ (CARRY TO TASK 13): statuses/groups/focus kept across resetService, restoreService, newPlan (today's TG-C11, CF3/CF4) — Task 13 pins.
Task 12: complete (commits c0011082..352b3936, review clean)
Task 13: dispatched (base 352b3936, implementer opus)
Task 13: implementer DONE_WITH_CONCERNS (0e6ab3cf, 844431ba), +1071. TG-C10/TG-C11 in unit_groups_controller_test.dart (R13-c/d); NS1 tail, NS5, DC15 ported; SR-state-kept (M-SR21..23), SR-edited-after-load (M-SR24) added.
Ruling: spec S3's general sentence "groups kept across resetService and restoreService" amended (docs commit after 844431ba) — it contradicted decision 4 and S3's own rules (restore replaces groups, reset clears them); code follows decision 4 — if wrong: the human's decision 4 is misread (it is the human's "waiters merge tables, recorded without touching the design").
Ruling: SR-C16 casts `(jsonDecode(...) as Map)['moves']` and SR-old-format-refused uses `<Object?>[]` — type-only edits for analyze; values compared unchanged — if wrong: none.
Task 13: note — plan library CHANGELOG untouched so far; Task 16 writes it (plan).
Task 13: review dispatched (opus)
Task 13: review — spec ✅, Approved (lib = brief byte for byte; every ported expect matches its oracle except R13-a..d).
Task 13: minor (deferred, FINAL REVIEW SHOULD TRIAGE — spec-named behaviour unpinned): restoreService's `_revision.value++` and `notifyListeners()` (and resetService's notifyListeners) — no test reads revision/listener count across a successful restore; deleting either survives.
Task 13: minor (deferred): restoreService's apply-failure path (catch → next.dispose() → rethrow) untested (unreachable under the strict match).
Task 13: minor (deferred, FINAL REVIEW SHOULD TRIAGE): a restored group member naming only a hidden or locked unit is kept (plan decision) — unpinned.
Task 13: note — TG-C10/TG-C11 live in unit_groups_controller_test.dart (controller's dispatch wording; brief listed service_record_controller_test.dart) — harmless.
Task 13: complete (commits 352b3936..844431ba, review clean; spec amendment dc2a5d70)
Task 14: dispatched (base dc2a5d70, implementer opus)
Task 14: implementer DONE_WITH_CONCERNS (fa4050e3, 23206e81, d50976ed); +1137 with --enable-vmservice; tool/ci +117; DC7 ported (M-H29 service moves red).
Ruling: ST-locked-seat gains a tap on A5 (a locked seat outside the group) — as written the test could not go red under M-ST-locked (A2's group has only locked members) — if wrong: one extra assertion.
Ruling: M-14l re-worded to the drag branch (ST7 red) — the plan's edit deletes an unreachable `if (hit.locked) return;` in _longPress (unreachable today too) — if wrong: the long-press lock line stays unpinned (it is dead code).
Ruling (provisional, reviewer to judge): PA4/PA5 gain a Transform2 watch measured against a no-pick baseline (RB16's method) — M-PA-hall survived as written; ~3,700 live Transform2s appear in every epoch — if wrong: an allocation measure changed shape; ported PA1-PA3 still lack a Transform2 watch.
Ruling: ServiceSession builds picker, tool and tool controller after `units` — the brief's order throws LateInitializationError — if wrong: none.
Task 14: note — M-ST-mixed / M-ST-group go red via the copy's guard throwing GeneratedGeometryError; _refreshSelectedGroup never runs per pointer move (RB16-hall premise: 0 selection notifications over 5,000 frames).
Task 14: review dispatched (opus)
Task 14: review — spec ✅, Approved (port diffed against oracle; ported assertions unchanged).
Ruling (confirmed): PA4/PA5 are new 2b tests, not ported; their Transform2 watch over a no-pick baseline strengthens them (M-PA-hall now red: ~31 excess Transform2 per pick vs budget 0.5); the baseline can hide at most O(1) Transform2 per pick, never per entity; PA1-PA3/RB16 keep today's method exactly — frame-path rule enforced at least as strictly as today — if wrong: a constant handful of Transform2 per pick could go unseen.
Task 14: minor (deferred, FINAL REVIEW SHOULD TRIAGE — spec-named rule unpinned): service_tool.dart:413 `roots.isEmpty ||` spend (a drag from an unselected seat is spent, selection untouched) — M-ST-empty survives.
Task 14: minor (deferred): pick_allocation_test.dart:218 subtracts the baseline for every watched class; subtract only for Transform2 or bound the baseline.
Task 14: minor (deferred): RB16-hall lacks a premise that the band covers a seat; the per-unit claim rests on the band's frame path doing no unit work.
Task 14: minor (deferred): ORACLE GAP (A12 keeps it): PA1-PA3 do not watch Transform2 (today's tests too).
Task 14: minor (deferred): service_tool.dart:362 stale comment ("locked member" now also generated member / empty moving set).
Task 14: complete (commits dc2a5d70..d50976ed, review clean)
Task 15: dispatched (base d50976ed, implementer opus)
Task 15: implementer DONE_WITH_CONCERNS (ed218143); +1228 with --enable-vmservice; TH4 overshoot ported (M-TH4b).
Ruling: TF3's fill count is ported as `hasLength(5)` ('A, B, C, U and K'), not dropped — R-16 sends the room R to sub-project 3, but dropping the line left the fill count unpinned; sub-project 3 restores 6 when rooms land — if wrong: one ported count changed value (premise: no room in 2b). TF7's channelDistance line and the export premises' 'R' key go with R-16.
Ruling: unit_paint_test's spy records `Color(paint.color.toARGB32())` — Paint stores colour as float32, so `==` against a const Color never holds; assertions unchanged — if wrong: none.
Ruling: exportOnce/printOnce build the request and fills inside the `try` via `_requestOf` — built before it, a throw leaks the export copy; M-SP-request applied inside `_requestOf`, still red — if wrong: none.
Task 15: note — 2a's TH11 unchanged (hasLength(4)); source's 13-field validation added as TH21; T1-a → TH19, R-3 → TH20; Step 7.8 already satisfied.
Task 15: review dispatched (opus)
Task 15: review — ❌ 1 Important: TF3's fill count dropped instead of hasLength(5) (controller ruling confirmed by reviewer). Painters: no per-entity per-frame allocation (checked all three paint methods + cache key). Rulings on the spy and _requestOf agreed.
Task 15: minor (deferred): PlanExportRequest.unitColourOpacity unchecked in its constructor (all library paths pass checked values).
Task 15: fix round 1 dispatched (TF3 + minors: export premise keys, doc artefacts, reflow, SP-group-mixed caption owner)
Task 15: fix round 1/5 (5 addressed, 0 open — TF3 hasLength(5), export premise keys, doc artefacts, reflow, SP-group-mixed lead + M-SP-lead; commits ed218143..2daafc79)
Task 15: complete (commits d50976ed..2daafc79, review clean)
Task 16: split into 16a (Part A, Steps A1-A13) and 16b (Part B) per R-7; briefs task-16a-brief.md / task-16b-brief.md (both carry the task header and Files block).
Ruling: all Task 16 items of carry-2a-deferrals.md go to 16b — they exercise PlanServiceView/PlanEditor's mode switch, which exists only after Part A — if wrong: none.
Task 16a: dispatched (base 2daafc79, implementer opus)
Task 16a: implementer DONE_WITH_CONCERNS (b79df762); +1311 ~1 with --enable-vmservice (BT1 skip as briefed).
Ruling: TO32 moves to 16b, assertions unchanged — it toggles a layer with SetLayerCommand (needs Capability.structure), refused on the copy (DraftPermissions.runtime); it needs PlanEditor's design canvas with unitOverlayModes {design} — CARRY TO 16b — if wrong: none (ported later).
Task 16a: note — brief import fixes (PlanMode, PlanExportDialog, Vector2), unused imports removed, trapezoid key fx.trapezoid.two, VE18 uses setUnitsData (map form) so its single isTrue stays; RED via moving plan_service_view.dart aside; M-SV-3a red via `Bad state: No element` at exports.single.
Task 16a: review dispatched (opus)
Task 16a: review — spec ✅, Approved (ported expects compared mechanically: TO, VE, TB, service bar identical; TO32 ruling confirmed).
Task 16a: minor (CARRY TO 16b): Print's service bypass unpinned (_printAllowed true in service; no test prints with print: false) — add M-SV-3c.
Task 16a: minor (deferred): VE18 reordered vs oracle (brief-mandated A4; loses the after-round-trip copy coverage); unit_overlay_test.dart local helper `onTableTap`; redundant `c.mode` listener in _listen; pagePlan() unused in Part A (check 16b uses it).
Task 16a: complete (commits 2daafc79..b79df762, review clean)
Task 16b: dispatched (base b79df762, implementer opus)
Task 16b: implementer DONE_WITH_CONCERNS (99165864, e5835933, 91aacf3b, de40ee6a); +1498 --enable-vmservice; dry-run 0 warnings; all Task 16 carry items ported (incl. TO32, M-SV-3c, snappingAllowed lib fix CV-6b/M-CV-6c, SV-12 idle keys).
Ruling: DS4's last two lines (`deleteSelection()` false with no editor mounted) not ported — premise impossible under 2a spec P2 (the controller's commands act with no widget) — if wrong: one ported assertion lost.
Ruling: F-2 and F-3 of chrome_change_test.dart ported (16 tests, assertions unchanged) — F-3 is M-SV-R2's real killer; T2-f stays green under it (brief's claim wrong) — if wrong: none (extra coverage).
Ruling: F-1 (chrome_change_test.dart, design-only) stays unported in 2b and is reported to the human as a 2a port gap — design-only, outside 2b's scope; no 2a or 2b task placed it — if wrong: one design test unported until a follow-up.
Ruling: PlanCanvas resets the old controller's snappingAllowed to true on a controller swap (lib fix outside the brief) — 2a's parked final-review item carried to 16b — if wrong: a small lib change to revert.
Task 16b: note — no extra `mode` listener on PlanEditor (would duplicate the controller listener); exportPlan ported as exportAs(c, png96) to keep the PNG-size assertion; theme_service invariant 4 keeps the dialog flow.
Task 16b: review dispatched (opus)
Task 16b: review — ❌ 1 Important: theme_canvas_test.dart pumpView dropped the oracle's mode premise and made viewMode optional (design default) — test-only fix. All carry items landed (checked vs oracle); DS4/F-3/TO32 rulings judged sound.
Task 16b: minor (deferred): plan_editor.dart now 1126 lines (R-13 block could move to a part/mixin later).
Task 16b: minor (deferred): snappingAllowed reset asymmetry — a disposed canvas leaves its setting (PlanEditor(snapping: false) switched to service leaves false with no canvas); harmless today; 2a note said revisit with multi-view hosts.
Task 16b: minor (deferred): barrel_test B5 weak by its oracle's design (empty plan).
Task 16b: fix round 1 dispatched (theme_canvas premise + SV-9 onPageFlowError)
Task 16b: fix round 1/5 (2 addressed, 0 open — theme_canvas viewMode required + premise restored, M-TC-s1 red in 4 service tests; SV-9 onPageFlowError; commits de40ee6a..2ca9c84f)
Task 16b: complete (commits b79df762..2ca9c84f, review clean)
Task 16: complete (16a 2daafc79..b79df762, 16b b79df762..2ca9c84f)
Task 17: dispatched (base 2ca9c84f, implementer opus)
Task 17: implementer DONE_WITH_CONCERNS (e7b7ceb6): all gates green (kit +340; plan +1498 --enable-vmservice; tool/ci +117; engine +1337 -2 standing; renderer +1450 ~1 -5 standing text-ladder; gpu +20; floor_plan +2012; other CI entries pass); 5 dry-runs 0 warnings.
Ruling: jet_cad_floor_plan/test/host/view_palette_test.dart's service-mode ServiceView palette tests (M-DT-10/11) — unplaced by 2a and 2b — are ported in the final fix wave, assertions unchanged — A12; same class of gap as the 2a deferrals — if wrong: extra ported tests.
Task 17: minor (to the final fix wave): STATUS's In-flight 2a paragraph still says A14 "awaits the human's word" (decision 9 settled it); engine CHANGELOG Unreleased has a stray blank line before the E5 bullets.
Task 17: note — renderer's two standing text_lod_ladder lines passed on this machine (failures are a subset of standing_failures.txt).
Task 17: review dispatched (sonnet)
Task 17: review — spec ✅, Approved (~90 test ids grepped, all found; gate counts match; rulings all present in the note).
Task 17: minor (to the final fix wave): results note says view_palette gap "open" (ruled since); STATUS "Resume here" should point at the note's "Spec gaps" section / the queued fix-wave items.
Task 17: complete (commits 2ca9c84f..e7b7ceb6, review clean)
All 17 tasks complete. Final whole-branch review next.
Final review: dispatched (opus; base 651e3d09, head e7b7ceb6; production package final-lib.diff ~578 KB; output final-review.md)
Final review: With fixes — 0 Critical, 4 Important (I-1 a mounted PlanCanvas edits the design in service; I-2 ledger's own fix-wave items; I-3 restoreService revision/notify unpinned; I-4 roots.isEmpty spend unpinned), 9 Minor. Ledger triage in final-review.md.
Ruling: I-1 — the design document's engine permissions are read-only exactly while a service copy exists; restored on leaving; the permissions setter applies value.draft to the design only in design mode — spec "dirty never moves in service"; a host keeping PlanCanvas mounted must not edit the design — if wrong: a host that intends design edits during service is refused (none in the spec).
Ruling: fold cheap minors into the single fix wave (M-2, M-3, T8 mutation run, T12 premise, T14 premise, M-7 CHANGELOG completeness); M-1, M-4, M-5, M-6, M-8, M-9 and other minors wait — cheap pins on spec-named behaviour vs behaviour changes/polish — if wrong: minor follow-ups.
Final fix wave: dispatched (opus), findings in final-fix-findings.md
Final fix wave: DONE_WITH_CONCERNS (318d2844, 93e92a74, bb5b7c05, ed27e2ca, cd6c8957); plan +1512 --enable-vmservice; kit +340; dry-runs 0 warnings; T8's mutation already killed by two R-1 cases.
Ruling: with I-1, design widgets a host leaves mounted in service (palette, gallery, panels) see read-only permissions and selectTool of a drawing tool returns false in service — spec S3 intends the design untouched in service; CHANGELOG says so — if wrong: a host wanting design edits during service must switch to design first.
Final fix wave: scoped re-review dispatched (opus)
Final fix wave: re-review — all findings ADDRESSED (I-1..I-4, M-2, M-3, T8, T12, T14, M-7), no new Critical/Important.
Final: parked — no test pins that a permissions profile changed in service is the one applied on leaving (code reads the current profile; a capture-on-entry mutant survives) — Ruling: the code is right by reading; a one-line pin can follow — if wrong: a regression to capture-on-entry goes unseen.
Final: parked — kit CHANGELOG line past wrap width; fix report's "1501" count slip (report only) — Ruling: cosmetic / not of record — if wrong: none.
Final: parked — STATUS "Resume here" does not name the ledger archive — Ruling: the archive lands as the branch's last commit before the human's merge word, so "next: the human's word on the merge" is accurate after it — if wrong: none.
Final: parked (out of scope, predates the wave) — a _buildService throw during load/newPlan in service leaves the controller half-replaced (_replace) — Ruling: pre-existing edge, consistent with the read-only rule; follow-up — if wrong: a host sees a stale copy after a failed load in service.
Final review: complete (commits 651e3d09..cd6c8957).
