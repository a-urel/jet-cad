# SDD ledger — plan: docs/superpowers/plans/2026-10-14-plan-library-2a.md

Started 2026-10-14 on feat/plan-library-2a at 36ff21ac (the human: "onaylıyorum, başla"). Execution: subagent-driven.

## Pre-flight

Scan: preflight.md in this directory (154 pair rows, 18 flagged; 21 task rows, 5 not self-consistent; 13 findings). The plan's own planning rulings are in its appendix ("rulings made while planning").

- Ruling: F1, per-document objects (locks, lock expander, boundary, gates, generic tools, attachment registry, symbol tool) are DocumentSession members disposed with their document; the attachment registry in disposeKitProducts — spec P1 Lifetimes step 2 — if wrong: live document's systems disposed one frame after a swap.
- Ruling: F2, the session's tool map owns every tool; no separate dispose of generic or symbol tools — Tool is a ChangeNotifier, a double dispose asserts — if wrong: debug assertion on every swap.
- Ruling: F3, from Task 12 the session's only plan.select is generic.select (gated) — spec P2 permissions and P4 locks — if wrong: select armed without gates.
- Ruling: F4, Task 10 build order: LockSet.scan, selection, LockGates, outlines, GripCache with LockedGrips, install(), then the lock expander — Task 8 installs last — if wrong: LateInitializationError.
- Ruling: F5, PlanSelectGates extends LockGates (base class) — no duplicated lock scan, no dead LockGates — if wrong: two copies drift.
- Ruling: F6, ED-9 includes the 15 names Tasks 6-8 and 16 export — Task 20's own decision says earlier exports win — if wrong: ED-9 red or an export silently dropped.
- Ruling: F7, Task 21's coverage rows name L-1 and F-2 — the real ids — if wrong: false "missing" findings.
- Ruling: F8, only the engine's CHANGELOG gains Unreleased (the Flutter layer does not change, spec E) — if wrong: a needless edit in a package the plan keeps untouched.
- Ruling: F9, Files blocks list every staged file; T15's git add carries plan_controller.dart — if wrong: an unstaged file left behind.
- Ruling: F10, the File structure block is regenerated from the tasks' Files lists — the tasks win — if wrong: implementers misled by a stale map.
- Ruling: F11, T13's port table states the fixture-key prefix as an allowed departure — A12 allows fixture changes — if wrong: a reviewer flags an unlisted assertion change.
- Ruling: F12, S-13 asserts explicitly (errors collected, expect empty) — a test must assert — if wrong: a test that passes on nothing.
- Ruling: F13, Task 9 adds a jet_cad_2d_kit CHANGELOG bullet for PlanSwatch — every kit API change has one — if wrong: an undocumented contract addition.
Pre-flight applied to the plan at aee66cb7.
Task 1: dispatched (BASE aee66cb7, implementer opus, agent a42c092dfcdc1a699)
Task 1: implementer DONE at 3d84a62c. Note for Task 11: a group whose only component was kept raw (E4) is a plain group (typeIdOf null, children editable) — Task 11 must lock it.
Task 1: minor (deferred): commands.dart:958 a 115-column comment line (report claimed re-wrapped).
Task 1: minor (deferred): no test pins typeIdOf == null for a group whose only component was kept raw (E4).
Task 1: minor (deferred): the toJson reorder (raw before registered) also changes output when restore/attachUnknown collides with a registered value.
Task 1: cannot-verify resolved: dependents' suites — implementer's report quotes flutter +1450 -5 (standing goldens) and floor_plan +2008; Task 21 re-runs every gate. Task 7's keepUnreadableComponents: true is checked at Task 7's review.
Task 1: complete (commits aee66cb7..3d84a62c, review clean, 3 minor deferred)
Task 2: dispatched (BASE 3d84a62c, implementer opus, agent a22e17cbf88d6656e)
Task 2: implementer DONE at 40912bf7 (M-E2p-catch reddens 7/9 rows; the other 2 pinned by an extra mutation, see report).
Task 2: review — spec ✅, quality needs fixes: 1 Important (plan-mandated): probe blames a place reader for a contributor's placeBox error.
Task 2: Ruling: widen probe's isolation pass — every other live place contributor's placeBox/placeInput is asked first and a throwing one is left out (as reach/references are), so probe(reader) answers only for the reader's own hooks — spec E2 "returns the first error" of the object's hooks; Task 11 would otherwise freeze healthy readers — if wrong: probe slower by one pass over contributors.
Task 2: minor (deferred): brief's M-E2p-catch claim (all 9 rows) is 7/9 by construction; M-E2p-self covers the other 2.
Task 2: minor (deferred): no test for deleting a frozen object or an orphan referrer of one.
Task 2: minor (deferred): probe repeats the survey's walk over objects.
Task 2: fix round 1/5 (1 addressed, 0 open — probe place isolation; commits 40912bf7..7ba09b31)
Task 2: minor (deferred): probe's isolation is one pass, not a fixpoint; "runs once" doc claim untrue after a re-survey.
Task 2: complete (commits 3d84a62c..7ba09b31, review clean after round 1)
Task 3: dispatched (BASE 7ba09b31, implementer sonnet, agent a98294f230aa6b207)
Task 3: implementer DONE at 560554a2 (no deviations).
Task 3: minor (deferred): PS11 lacks an astral code-point fixture (runes.length -> length mutant survives).
Task 3: minor (deferred): choice value segments containing '.' or ':' are not refused (ambiguous word id).
Task 3: minor (deferred): NumberProperty can store -0.0.
Task 3: complete (commits 7ba09b31..560554a2, review clean)
Task 4: dispatched (BASE 560554a2, implementer sonnet, agent a7bd234af0c8a3438)
Task 4: implementer DONE at eb369f81 (no deviations).
Task 4: minor (deferred): AttachmentQuery is documented immutable but pointer/marker are mutable Vector2s (a provider could change what the next sees).
Task 4: minor (deferred): no test of a tool without settings (validate/propertyIds null path).
Task 4: minor (deferred): no test commits a field whose enabled state changed after it was read.
Task 4: minor (deferred): propertyIds may list an id twice; undocumented.
Task 4: minor (deferred): `properties` doc does not warn that spec function members fail through PlanType<Component>.
Task 4: minor (deferred): validate uses settings! where propertyIds uses a pattern.
Task 4: cannot-verify resolved: reservedKitId is Task 6's validateKitSet; shared keyed by (kit, type) is Task 8's — both in their briefs.
Task 4: complete (commits 560554a2..eb369f81, review clean)
Task 5: dispatched (BASE eb369f81, implementer sonnet, agent a1946d364c3c59e08)
Task 5: implementer DONE at 06ee312e.
Task 5: minor (deferred): R3 property-id check is dot plus kit prefix only; the boundary is not pinned by tests.
Task 5: minor (deferred): one missingEnglish per word when `en` is absent entirely (noisy).
Task 5: complete (commits eb369f81..06ee312e, review clean)
Task 6: dispatched (BASE 06ee312e, implementer opus, agent ab18bc0eab7b9bb54)
Task 6: implementer DONE at aeb5e610 (kit tools, grips, TestEdge compile but are first exercised in Task 8+).
Task 6: minor (deferred): KitLog doc order (tool+1 before cache+1) contradicts SlabTool's initializer.
Task 6: minor (deferred): TestEdge uses edgeCapture as its hysteresis radius (not the contract's meaning of that field).
Task 6: minor (deferred, carry to Task 11): the throwing kit cannot make Tool getters (isMidShape, cursor…), dispose, `enabled`, non-Number read or tool settings throw — Task 11 may need to add these hooks.
Task 6: minor (deferred): 4 further minors in task-6-review.md.
Task 6: cannot-verify carried: PlanController(kits:) calls validateKitSet (Task 8); SlabTool/BoomTool/SlabGrips drag+preview/TestEdge hysteresis/pumpApp first driven in Tasks 8, 11, 14 — those reviews must see them exercised.
Task 6: complete (commits 06ee312e..aeb5e610, review clean)
Task 7: dispatched (BASE aeb5e610, implementer opus, agent a8cb7a2be620b573d)
Task 7: implementer DONE at 6df8967a.
Task 7: minor (deferred): usedKitsIn re-implements kitOfKey; decodePlan's catch drops the original error and stack; no test pins "save never mutates"; reserved `plan` not excluded like `jetcad` in usedKits; semver overflow guard VM-only.
Task 7: carry to Task 8: the controller must call checkManifest on load and report kitMissing/kitNewer; pass a fresh diagnostics list per decodePlan so a refused load leaves no entries behind.
Task 7: complete (commits aeb5e610..6df8967a, review clean)
Task 8: dispatched (BASE 6df8967a, implementer opus, agent afbab9504d6efdf0a)
Task 8: implementer DONE at 551985c8. Carry to Task 11: a kit factory that throws during a swap leaves the controller half-swapped.
Task 8: minor (deferred): PlanController.dispose disposes kit tools without arming select first (breaks disposeKitProducts' stated precondition; harmless today).
Task 8: minor (deferred): a refused load still commits a pending field into the old plan (ported behaviour); the report's claim that C11 tests it is wrong.
Task 8: minor (deferred, carry to Task 11): a kit factory that throws mid-swap leaves the controller half-swapped and never disposes the old session.
Task 8: minor (deferred): no test checks each load gets a fresh diagnostics list; C-ch7 names no mutation inline.
Task 8: complete (commits 6df8967a..551985c8, review clean)
Task 9: dispatched (BASE 551985c8, implementer opus, agent afb53ff58f6a6ca1b)
Task 9: implementer DONE at 5229bd1b.
Task 9: minor (deferred): newPlan's use of the reported strings unpinned (surviving mutant at plan_controller.dart:322).
Task 9: minor (deferred): decimalSeparatorFor in new_plan.dart has no caller (plan-mandated).
Task 9: minor (deferred): no test exercises the barrel's new exports (Task 20's barrel test covers it).
Task 9: minor (deferred, carry to Task 15): PlanLocaleScope's post-frame callback checks the context is mounted but not that the controller is still live (a disposed controller's reportLocale would assert).
Task 9: minor (deferred): several theme and port tests name no mutation (plan-mandated).
Task 9: complete (commits 551985c8..5229bd1b, review clean)
Task 10: dispatched (BASE 5229bd1b, implementer opus, agent a95563a0864217467)
Task 10: implementer DONE at 96422ea4..8d93ff40. execute() landed here in a minimal form (PlanLocked, DanglingReferenceError, ArgumentError -> false).
Task 10: carry to Task 11: extend the existing execute() (lockHint, KitHookFailure), never add a second; freeze a broken object at the same time as locking it; deleteSelection does not catch PlanLocked.
Task 10: minor (deferred): L-10's name promises a chain check no test covers (plan-mandated).
Task 10: minor (deferred): _locksUnknown always true, parameters unused (plan-mandated, kept for M-L4).
Task 10: minor (deferred): a duplicated instance of a locked symbol would not itself be locked (LockSet scans at load only).
Task 10: minor (deferred, carry to Tasks 11-12): PlanLocked can escape deleteSelection and a nested-group delete instead of answering false.
Task 10: cannot-verify carried: the mirror gate is Task 12's; no panel section for a locked object is Task 17's; layer change and recolour of a locked object must be tested in Tasks 17/18.
Task 10: complete (commits 5229bd1b..8d93ff40, review clean)
Task 11: dispatched (BASE 8d93ff40, implementer opus, agent ad23038716592347e; carries from Tasks 1, 6, 8, 10 in the dispatch)
Task 11: implementer DONE_WITH_CONCERNS at 5b4cff41..3bd18b90.
Task 11: Ruling: Task 8's C14 expectation extended with ('test', componentUnreadable) — the E4 diagnostic now reported is spec P4's componentUnreadable row; the assertion grows, nothing is weakened — if wrong: a test pins a diagnostic the spec did not want.
Task 11: review — spec ✅, quality needs fixes: 1 Important (plan-mandated): probeLoaded's catch (_) { return; } drops drift()'s error.
Task 11: Ruling: when drift() throws after a load, run the per-object probe (the plan's own rule: probe object by object only if drift throws), freeze+lock what fails; if no object's probe fails, report the engine error with FlutterError.reportError and continue — spec P4 "the same hooks, on load" — if wrong: a broken object found only at its first edit.
Task 11: Ruling: a PartialMutationError during undo/redo replay is handled like one during execute (notifyLoaded, damaged, diagnostic) — spec P4 "a rollback that throws" names no command path — if wrong: an undo that half-applies leaves stale index and caches.
Task 11: fix round 1/5 (2 addressed, 0 open — drift error probed/reported; partial undo/redo damaged; commits 3bd18b90..51906ea4)
Task 11: minor (deferred): a refused key answers `ignored` (host may also handle it); DanglingReferenceError hint differs between execute and GuardedTool; damaged save sets _encodedState before a failed read-back; GuardedGrips session wiring unpinned at controller level; toolFor returns the unguarded tool; inner cancel runs twice; _probeAll and probeType look only at root-level kit objects.
Task 11: cannot-verify carried: a grip drag in flight ending cleanly when drag answers null (Flutter layer; Task 15/17 widget tests); _LockCheck is one object per execute (allocation gate is Task 15's).
Task 11: complete (commits 8d93ff40..51906ea4, review clean after round 1)
Task 12: dispatched (BASE 51906ea4, implementer opus, agent a4e6b1dda17b6b4d9)
Task 12: implementer DONE_WITH_CONCERNS at 23621eb9. Notes: canUndo/dirty lag a synchronous edit (async change stream) — check against today's FloorPlanController at Task 16/20 (a host bar listening); readOnly's reportLocale now runs with permissions lifted (PM-21).
Task 12: minor (deferred): grips.gatesChanged() in the permissions setter unpinned (plan_controller.dart:722); 3 further minors in task-12-review.md.
Task 12: Ruling: execute() must also catch PermissionDeniedError and answer false — R-b says execute turns every refusal into false — carried into Task 13's dispatch (one catch + one test) — if wrong: a widget commit under readOnly throws.
Task 12: cannot-verify carried: mirror has no SelectGates member, so mirror is gated by Tasks 14 (plan.symbol M) and 17 (panel); palette/panel/bar enforcement are Tasks 16, 17, 20.
Task 12: complete (commits 51906ea4..23621eb9, review clean)
Task 13: dispatched (BASE 23621eb9, implementer opus, agent a4df1f5424cefeb89; carries execute catching PermissionDeniedError)
Task 13: implementer DONE_WITH_CONCERNS at 25b56f97..0d314ba4 (+292 ~1).
Task 13: Ruling: the ported "a mixed-case tag is found in any case" test is retired, not skipped — K2 (approved) admits only lower-case tags, so its premise cannot exist, and a new skip breaks CI's exact standing-skips comparison; its intent (case-insensitive match) is pinned by a query-side test (a mixed-case query finds a lower-case tag) — if wrong: a mixed-case tag path untested, which K2 makes unreachable.
Task 13: F-1 ruling applied at 953356d8 (SF-Q added; no skips).
Task 13: minor (deferred): Ruling: a successful retry of a library source should clear that source's earlier libraryUnreadable diagnostics (plan_controller.dart:924-951) — a fixed failure must not stay visible — for the final fix wave; if wrong: the bar shows a resolved failure.
Task 13: minor (deferred): S-15 never taps, so _onSelect's filter check is untested; S-1, S-3, S-8, GM-1, GM-8, GM-9 name no mutation; no test reuses an equal-but-not-identical unit (symbol_placer.dart:97 == vs identical).
Task 13: complete (commits 23621eb9..953356d8, review clean)
Task 14: dispatched (BASE 953356d8, implementer opus, agent ad6a511da715451a2; carries: plan.symbol M respects PlanPermissions.mirror)
Task 14: implementer DONE_WITH_CONCERNS at b2a6f29a..29aaea73 (393 passing).
Task 14: Ruling: the ghost and "keys compose" ports changed fixtures only (an own library shaped like the asset's entries; fixture.armchair.single as the chair), assertions unchanged — A12 allows fixture changes — if wrong: a port drifted from its source's intent.
Task 14: Ruling: Task 8's C-life1 and C-svc expectations include the test kit's edge provider now that the registry exists — assertions added, none removed — if wrong: those tests pin Task 14's internals.
Task 14: minor (deferred): _syncAttachment's unused context; registry's provider-kind-in-try and guarded dispose untested; move-resolver branches without named mutants (scaled instance, non-symbol, node reset; MV-4 cannot tell definition box from entry box); AT-20 pins the test kit's inverted hysteresis (TestEdge fixture, see Task 6 minor); _open's unoffered-kind report unpinned; stale WallFaces doc comment in symbol_box.dart.
Task 14: complete (commits 953356d8..29aaea73, review clean)
Task 15: dispatched (BASE 29aaea73, implementer opus, agent ac6f6e31b488d4725; carries: locale push vs disposed controller, lock hint, grip drag ending when drag answers null)
Task 15: implementer DONE_WITH_CONCERNS at 539b0676..a6958db4 (+445).
Task 15: review — spec ✅, quality needs fixes: 1 Important (lockHint already true never clears: refusal before mount, canvas re-created within 2 s, swap while shown); 8 minor (task-15-review.md).
Task 15: fix round 1/5 (1 addressed, 0 open — lock hint clears when bound already set; spot-check of M-CV-alloc-1/-2, M-CV-2b quoted red; commits a6958db4..1d68c7a5)
Task 15: minor (deferred): a refusal while the hint shows does not restart the 2 s window (needs a notifier API); a swap away from a controller whose hint shows leaves it true until a canvas binds it; PlanTextKeys landed untested; CV-8 contrived; 8 review minors in task-15-review.md.
Task 15: complete (commits 29aaea73..1d68c7a5, review clean after round 1)
Task 16: dispatched (BASE 1d68c7a5, implementer opus, agent affaddeabb21872fe)
Task 16: implementer DONE_WITH_CONCERNS at 395fd873 (+474).
Task 16: review — spec ✅, quality needs fixes: 1 Important (F3 stays bound under PlanCanvas(snapping: false): snappingAllowed not observable; S-14 regression); 5 minor.
Task 16: fix round 1/5 (1 addressed, 0 open — observable snapping, F3 rebinds; spot-check M-KB-1c/M-KB-3b red; commits 395fd873..9a76ce37)
Task 16: minor (deferred): one frame before F3 rebinds after a snapping change; idleKeys not restored after a shortcuts:false PlanShortcuts is removed; file chord mid-shape and F under denied geometry untested.
Task 16: complete (commits 1d68c7a5..9a76ce37, review clean after round 1)
Task 17: dispatched (BASE 9a76ce37, implementer opus, agent a1367b1e9ef2fc198; carries: recolour of a locked object refused, panel mirror respects permissions)
Task 17: implementer DONE_WITH_CONCERNS at 667f40c8..9658faf4 (+525). Note: 'DiagnosticsLog used after dispose' spills after a failing test (harness teardown order) — check at Task 20/final whether a host disposing its controller before the view can hit it.
Task 17: review — spec ✅, quality needs fixes: 1 Important (SW5 cannot go red under M-09c-bf: the Size-menu guard isServableInstance is unpinned); spec question: panel-called kit hooks (property read, enabled, title, colour read/write) unguarded.
Task 17: Ruling: the panel guards every kit hook it calls while building or acting (read, enabled, title, colour read/write): a throwing build-time hook shows the "section failed" box with a hookFailed diagnostic; a throwing colour write is refused with a diagnostic — spec P4 "every kit hook is called at the contract's boundary" — if wrong: one kit's bad read takes the whole panel down.
Task 17: fix round 1/5 (2 addressed, 0 open — sizeMenuMembers pinned by SS12; panel kit hooks guarded P-G1..P-G3; commits 9658faf4..d510d4ea)
Task 17: minor (deferred): parametric.editCapability read unguarded; tool-settings guard untested (no throwing-settings fixture); last block of P-swap-pending cannot fail alone; _guarded cannot tell a kit's own ArgumentError/StateError from a refusal (no diagnostic); review minors 1, 2, 4, 6, 7 in task-17-review.md.
Task 17: complete (commits 9a76ce37..d510d4ea, review clean after round 1)
Task 18: dispatched (BASE d510d4ea, implementer opus, agent abf735c4bc14aae69; carries: layer change of a locked object refused)
Task 18: implementer DONE_WITH_CONCERNS at 7b566fae..7c0156a3 (+602).
Task 18: Ruling: PlanPagePanel wraps itself in PlanShortcutGuard (not in the brief) — spec P2 "text fields keep their keys"; composable panels guard themselves as the property panel and layer rows do; today's shell guarded its right column — if wrong: a redundant guard when PlanEditor also guards.
Task 18: Ruling: SE13/15/16's asserted section word 'Wall' becomes 'Box' — the wall type moves to sub-project 3 and the test kit's box stands in; the literal follows the fixture, the assertion's check is unchanged (as in Task 17) — if wrong: the ported test pins another section's title.
Task 18: minor (deferred): _lockedOrUnderLock's parent walk duplicates isLocked (unkillable mutant; brief-mandated); only the page-background input of the layer panel's foreground colour tested; PW1/PW2 names mention the Wall section; _add selects the new layer even when refused (old behaviour, no effect).
Task 18: cannot-verify carried to Task 20: PlanPropertyPanel rebuilds the layer picker after a lock or a swap and shows it only while changeLayer is on — pin in the PlanEditor composite tests.
Task 18: complete (commits d510d4ea..7c0156a3, review clean)
Task 19: dispatched (BASE 7c0156a3, implementer opus, agent af4d0c2732f2424cc)
Task 19: implementer DONE_WITH_CONCERNS at 826ee7e1 (+635). Carry to Task 20: on a plan with no page, the editor's export dialog still lists PDF/PNG and picking one silently exports nothing — filter or explain.
Task 19: cannot-verify resolved: spot-check M-X-4, M-X-6, M-X-10 red at their lines, reverts clean (report "Spot-check").
Task 19: minor (deferred): dialogAnswer stored before the exporter id is checked; _copyOf repeats the registration list; ExportFontCache doc says once per app (per controller); PF8 stale comment; PF23 lacks a positive control; M-X-10/11/12 unnamed in test files; print copies before awaiting the font; import not under the one-flow guard.
Task 19: complete (commits 7c0156a3..826ee7e1, review clean)
Task 20: dispatched (BASE 826ee7e1, implementer opus, agent afd2c7c72c9a4ba4f; carries: layer picker rebuild/visibility, page-less export dialog, canUndo lag vs today, DiagnosticsLog after dispose)
Task 20: implementer DONE_WITH_CONCERNS at 112e734b..1ed407b8 (714 passing). Carried items: ED-L (layer picker), ED-U (canUndo lags one async delivery — today's too, kept), ED-D (no DiagnosticsLog-after-dispose on host disposal; positive control); export enabled with a page or a page-less exporter, dialog lists only runnable exporters, Ctrl+E rule in PlanShortcuts aligned.
Task 20: Ruling: RV6 split — a PlanCanvas that unmounts cancels the active tool and arms plan.select (RV6's first assertion, ported); RV6's "selectTool returns false with no view" is retired: the controller owns the tools and works without a canvas (a deliberate host-API difference, listed for the human's word at the finish per A14) — if wrong: hosts that relied on selectTool failing without a view see true.
Task 20: RV6 ruling applied at ce212b7c (715 passing).
Task 20: review — spec ✅, quality needs fixes: 1 Important (toolPalette incl. gallery-alone branch, symbolFilter, shortcuts, autofocus, onPageFlowError pass-throughs untested; mutants survive); 5 minor.
Task 20: Ruling: ported tests need not name a mutation — CLAUDE.md's bar is for a new test; a ported test is the oracle of the move (A12) and keeps its source's assertions — if wrong: some ported tests are degenerate and unflagged.
Task 20: fix round 1/5 (4 addressed, 0 open — editor option tests, ED-6b, ED-L second plan, expect comparison 57 ports: 23 identical, 34 listed; commits ce212b7c..e1e577d5)
Task 20: minor (deferred): ED-6b's isMidShape line does not go red under its mutation; review minors in task-20-review.md.
Task 20: complete (commits 826ee7e1..e1e577d5, review clean after round 1)
Task 21: dispatched (BASE e1e577d5, implementer opus, agent ad98bba2d0caa07f6)
Task 21: implementer DONE at ca81499d (all gates green bar standing; dry-runs 0 warnings; untouched diff empty).
Task 21: cannot-verify resolved: three invariant lines re-run alone and quoted (canvas_paint_allocation +1, query_allocation +6, paint_allocation +3, all passed) at 2fa4cc6f.
Task 21: minor (deferred): mutation table grouped by id range; half the ported-test counts read "not counted"; plan-decisions list an unlabelled subset (task-21-review.md).
Task 21: complete (commits e1e577d5..2fa4cc6f, review clean)
Final review: dispatched (BASE 60839065, HEAD 2fa4cc6f, opus, agent ac6333fcf94e13788)
Final review: ready after fixes — 0 Critical, 3 Important (I1 own-type write on a frozen object escapes as StateError, not PlanLocked; I2 a generate output the planner refuses blocks the object and its neighbours forever with no diagnostic/lock; I3 the Task 13 retry-clears-diagnostics ruling not done), 8 Minor; triage: must fix I3, should fix 8 deferred minors (final-review.md).
Ruling: the final fix wave carries I1, I2, I3 and the reviewer's eight "should fix" minors; the other minors stay deferred — skill: one fix dispatch with the complete list — if wrong: a deferred minor surfaces in sub-project 3.
Ruling: I1 extends seam E2 with a typed refusal carrying the handle (engine), turned into PlanLocked in _LockCheck; recorded as a spec amendment — the plan library cannot tell the engine's refusal from a kit failure otherwise — if wrong: one more engine type in the public API.
Final fix wave: DONE at f44899f0..07128eb1 (plan +735, kit +314, engine +1322 -2 standing, floor_plan +2008, tool/ci +116, dry-runs 0 warnings).
Final re-review: all 11 findings ADDRESSED; no new Critical/Important.
Final: parked — I1 mapping's rethrow for an unlocked handle untested (locks.dart:263) — Ruling: real, deferred; nothing downstream builds on it.
Final: parked — _first's catch-all runs _probeAll on any plain error from any command — Ruling: real, deferred; costs a probe on a rare error path.
Final: parked — remounting PlanShortcuts(shortcuts:false) on the same controller can reopen idleKeys (old dispose after new initState) — Ruling: real, deferred to 2b/sub-project 3 where views are swapped.
Final: parked — revision-history entry out of order in the spec — Ruling: cosmetic.
Final: parked — GuardedTool._failed rethrows an ArgumentError the probe could not cure out of a plan.select grip drag — Ruling: real, deferred; noted for sub-project 3's grips.
Final: parked — M3's second half (fail a damaged save on component.unreadable) — Ruling: left out; would make every damaged plan holding a kept-raw component unsavable; a narrower check (handles the load did not report) is future work.
Final review clean after one fix wave (commits 2fa4cc6f..07128eb1).
