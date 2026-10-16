# SDD ledger — plan: docs/superpowers/plans/2026-10-15-architecture-kit.md

Spec: docs/superpowers/specs/2026-10-15-architecture-kit-design.md (rev 2, approved 2026-10-15).
Branch feat/architecture-kit, worktree .claude/worktrees/architecture-kit; start b72c2ad8 (main 7e65905b).
The human: "kararları sana bırakıyorum. hemen başla." (2026-10-15).

## Pre-execution scan

The conflict scan was run during planning, by one reconcile pass (cross-task: every produce/consume pair, shared files, orders, moved cases; 235 fixes) and five pre-flight passes (per task: tests vs code, files created vs touched/committed, mutations, ported assertions, gates; ~280 fixes). Their tables are in planning/reconcile-log.md and planning/preflight-log-*.md (copied here). Rulings R-P1..R-P19 and the writers' rulings are in the plan's appendix.

| Pair / task | Produces vs consumes | Found | Ruling |
|---|---|---|---|
| 11/13/14/16 (wall, opening, room) | wall.dart uses opening_geometry, room_inputs | import cycle across tasks | R-P8: cut in 13, keptPut in 14, place hooks in 16 |
| 2 vs 21 | TextDisplay.read vs words | no words in PlanObject | R-P4/R-P7: PlanObject.words: PlanWords |
| 16 vs 17 | RoomInputs vs separator | mutual dependency | separator params in 16, tool in 17 |
| 7 vs 12 | grip refusal vs WG-refuse-short | RF3 said "commits last state" | R-P15/R-P17: today's: drop at refused point commits nothing |
| 23 vs 24 | furnitureSource vs provider | attachmentKindUnoffered | R-P2: source joins kit in 24 |
| 23/24/28 vs integration | placeSymbol/kit internals vs public-only | cases unplaceable | R-P1: kit with test-local place_entry.dart |
| 10..22 kit tests | test catalog names | 3 names | R-P13: test/support/catalog.dart testCatalog()/installParametric |
| 9 vs 23 | SC-conformance | empty catalog | Task 23 updates SC-conformance; furniture words in architectureNames |
| 14 vs 9 kit.dart | R14-1 catalog | import cycle | R-P19: lib/src/type_naming.dart |
| every task | self-consistency | see preflight logs | fixed in plan |

Ruling: analysis_options.yaml of the two new packages committed once in Task 9 — the human left it to the controller; 2a's precedent ("Bir kez commit edilsin") — cost if wrong: two files to remove from history-free tip (git rm), lint lost.
Ruling: the 19 dropped/instrument-changed ported assertion lines (plan appendix) accepted — the human left them to the controller — cost if wrong: those lines unpinned; restorable later by exposing the read.

## Tasks
Task 1: dispatched (BASE b72c2ad8, implementer affcd7ef82aee3afb, sonnet)
Task 1: implemented d742f063 (DONE_WITH_CONCERNS: RED reproduced after the fact); review dispatched (a90ede006a795c0fb, sonnet)
Task 1: minor (deferred): contract_names_test regex matches column-0 declarations only.
Task 1: complete (commits b72c2ad8..d742f063, review clean)
Task 2: dispatched (BASE d742f063, opus)
Task 2: implementer af9746a0140c5bb11
Task 2: implementer DONE_WITH_CONCERNS (commit 31c2b976; 2 deviations: PO-hidden measured from Position row; M-PO-cov run as LengthProperty<Object>)
Task 2: reviewer a26f95971d0371645 (opus) on review-d742f063..31c2b976.diff
Task 2: review Approved (spec ✅, 0 Critical, 0 Important); both deviations accepted
Ruling: Task 2 Minors parked for the final fix wave — (1) object_view_test.dart:345 mutation comment should read LengthProperty<Object>; (2) _shows' `t is _ObjectTarget` clause unpinned, narrows C1.7 (gated action hidden on objects only) — plan's scope, record in spec amendment or pin with a settings-action fixture at final wave; (3) docs/kits.md new names lack backticks (plan-mandated text); (4) PO-gate-hidden title overstates — polish, not load-bearing — cost if wrong: a stale comment/title survives into merge
Task 2: complete (commit 31c2b976, review clean, Minors parked)
Task 3: dispatched (BASE 31c2b976, opus)
Task 3: implementer afb8d41abbcc19415
Task 3: implementer DONE (commit 1eef1a22)
Task 3: reviewer a2a1c9686316cd2ec (sonnet) on review-31c2b976..1eef1a22.diff
Task 3: review spec ✅, 0 Critical, 0 Important (reviewer omitted the Assessment line; with only Minors, read as Approved)
Ruling: Task 3 Minors parked for the final fix wave — (1) host_words.dart:11 doc line 82 chars, rewrap; (2) plan_kit.dart validate doc ragged wrap; (3) conformance's own-kit filter on text: words unpinned — add a one-case test (text:other.x not held to locales); (4) fillText single-pass (arg containing '{n}') unpinned — add a case — cost if wrong: two survivable mutations reach merge
Task 3: complete (commit 1eef1a22, review clean, Minors parked)
Task 4: dispatched (BASE 1eef1a22, opus)
Task 4: implementer aae2bca66698c5b30
Task 4: implementer DONE_WITH_CONCERNS (commit e5a9abb9; concern: stale notice-listener removal unpinned — removing _noticeSource?.removeListener in _rebindNotice keeps all TN tests green)
Ruling: pin the listener removal before review (pre-review fix, resumed implementer) — the testing bar requires a red mutation for every behavior; a leaked listener on a disposed controller throws at runtime — cost if wrong: one extra test commit
Task 4: pre-review fix DONE (commit 1672344b; TN-unbind, TN-unbind-dispose; swap routes redundant, joint removal pinned)
Task 4: reviewer ae628cb6e80f6ab65 (opus) on review-1eef1a22..1672344b.diff
Task 4: review Approved (spec ✅, 0 Critical, 0 Important)
Ruling: Task 4 relocale one-frame lag accepted as a known limit — it comes from PlanLocaleScope reporting the locale after the frame (pre-existing), the kit tool label lags identically so the line never mixes languages; record in the final results note — cost if wrong: one frame of the old language on a locale switch
Ruling: Task 4 Minors parked for the final fix wave — (2) _GuardedNotice add/removeListener throw branches unpinned (BoomNotice lacks hooks); (3) idle-Tool boilerplate copied 5× in test support — shared idle-tool base; (4) _open's _rebindNotice redundant with _replace route, only joint removal pinned — cost if wrong: test-only duplication and two survivable guard mutations
Task 4: complete (commits e5a9abb9, 1672344b, review clean, Minors parked)
Task 5: dispatched (BASE 1672344b, opus)
Task 5: implementer a55f62f97300e88a6
Task 5: implementer DONE (commit c91c046a; concerns: ported ND4 cases engine-only; PB3 byte check shadowed under M-PB-4)
Task 5: reviewer ad78523593aef4001 (opus) on review-1672344b..c91c046a.diff
Task 5: review Approved (spec ✅, 0 Critical, 0 Important)
Ruling: Task 5 Minors parked for the final fix wave — (1) docs/kits.md §10.8 overstates a failed prepare ("opens without what it would have added"; _prepare rolls nothing back) — reword to "what it added before the throw stays" (plan-mandated text, doc only); (2) build-words kit-vs-kit order unpinned (kits.reversed survives) — give prepKit a conflicting word; (3) _runBuild's catch-undo loop unguarded (brief-prescribed, narrow); (4) ND4 ported engine cases and PB3's shadowed byte check accepted as-is — cost if wrong: a misleading doc row and one survivable mutation reach merge
Task 5: complete (commit c91c046a, review clean, Minors parked)
Task 6: dispatched (BASE c91c046a, opus)
Task 6: implementer a6b09df08ad8ab7ca
Task 6: implementer DONE (commit 690e36e0; concerns: dispose release unpinned; settingsOf null branch message-only; _Host.catalog indirect)
Task 6: reviewer a0a178a7aab0ee7a9 (sonnet) on review-c91c046a..690e36e0.diff
Task 6: review Approved (spec ✅, 0 Critical, 0 Important); objectDocument deviation confirmed correct
Ruling: Task 6 Minors parked for the final fix wave — FakePlanServices.dispose's index/camera/notifier release unpinned (add a disposed-notifier probe); settingsOf null branch message-only and _Host.catalog indirect accepted — cost if wrong: one unpinned dispose line
Task 6: complete (commit 690e36e0, review clean, Minors parked)
Task 7: dispatched (BASE 690e36e0, opus)
Task 7: implementer a778d30e642dd7055
Task 7: implementer DONE_WITH_CONCERNS (commits 7e6b671d, 9117826c; grip tests made async with settleHistory; added FL-throw, FL-service; live-referent filter unreachable; KitHookFailure at drop via _refusal)
Task 7: reviewer a4ba4fb177dd8e5a7 (opus) on review-690e36e0..9117826c.diff
Task 7: review spec ✅, 1 Important (plan-mandated): GuardedTool._failed consults refusal for every plan.select event, not only the drop — an ArgumentError from SelectTool on down/move/exit/key is now swallowed silently
Ruling: narrow refusal to onPointerUp only (spec C1.8 (2) says "at the drop"; onKey's delete is already gated up front by deleteSelection/LockSet, so it keeps 2a's rethrow) — amends the brief's _failed placement — cost if wrong: a key-delete refusal rethrows as before, which 2a already accepted
Ruling: fold Minors 1 (KitHookFailure at drop: one diagnostic, pinned) and 3 (two referrers / two referents fixture) into fix round 1 since they are cheap and in the same files; Minors 2, 4, 5, 6 parked for the final wave — cost if wrong: a few extra test lines
Task 7: fix round 1 (resume a778d30e642dd7055)
Task 7: fix round 1 DONE (commit e5b2261a; M-F-T7a/b, M-GR-3, M-FL-6 red; live-referent filter still unpinned)
Task 7: re-reviewer a12ddc5d5124f994c (sonnet) on review-9117826c..e5b2261a.diff
Task 7: re-review fix round 1 Approved (3/3 addressed; M-GR-3 substitution sound)
Ruling: Task 7 Minors parked for the final fix wave — FL header comment spliced/over 80 cols; _referencesOf live-referent filter unpinned (document as defensive or remove); recover locking a host mid-command unpinned; GR-drop-refuse's activeTool assert non-discriminating; GR-drag-refuse integrated empty preview; FL-service premise relies on box-kit `reach` — cost if wrong: cosmetic and unpinned defensive code reach merge
Task 7: complete (commits 7e6b671d, 9117826c, e5b2261a; review clean after fix round 1)
Task 8: dispatched (BASE e5b2261a, sonnet)
Task 8: implementer ad4dcc9d4c0c07fc7
Task 8: implementer DONE (commit dbaf4bd4; M-PN-kind run as equivalent)
Task 8: reviewer aa609866e547a581b (sonnet) on review-e5b2261a..dbaf4bd4.diff
Task 8: review Approved (spec ✅, 0 Critical, 0 Important); Minors (shortcut earlier-state-leaves case; SE8 seats under rotation) parked for the final wave
Task 8: complete (commit dbaf4bd4, review clean) — contract wave (Tasks 1-8) done
Task 9: dispatched (BASE dbaf4bd4, opus); Step 1's analysis_options confirmation = the controller's delegated ruling (one commit per new package, 2a precedent)
Task 9: implementer af5c42e39447fcc49
Task 9: implementer DONE (commit 8102f8a4; red run via moved-aside lib file; editor_rig mostly unexercised until later tasks)
Task 9: reviewer a9759e8a208da3e63 (opus) on review-dbaf4bd4..8102f8a4.diff
Task 9: review Approved (spec ✅, 0 Critical, 0 Important; words 55/55 per locale verified independently)
Ruling: Task 9 Minors parked — example/main.dart:4 81 cols (brief text); editor_rig camera/press/globalAt paths unexercised until Task 10+ (their first users must exercise them); setSurfaceSize teardown per call (harmless) — cost if wrong: a rig defect surfaces in Task 10 instead of here
Task 9: complete (commit 8102f8a4, review clean)
Task 10: dispatched (BASE 8102f8a4, opus)
Task 10: implementer a800904554c325a92
Task 10: implementer DONE_WITH_CONCERNS (commit 711889c1; M-BX-4 run as equivalent, reds BT3 but not BX4)
Ruling: M-BX-4 pinned by the kit's BT3 only — clipping is kit-internal geometry (R-P1 puts kit-internal cases in the kit); BX4 is ported as-is (A12) with the old blind spot — cost if wrong: an integration-only clip regression would need the kit test to fail first, which it does
Task 10: reviewer a473b4c84747c450d (sonnet) on review-8102f8a4..711889c1.diff
Task 10: review spec ✅, 0 Critical, 0 Important (Assessment line omitted; only Minors → Approved); ports verified line-by-line against the old files
Ruling: Task 10 Minors parked — planner_box_test.dart header says the grid snap is needed but the report shows BX1-BX6 pass without it: reword the rationale to "keeps the clicks on today's exact corners" at the final wave; BX4 not a clipping pin (BT3 is) — cost if wrong: a misleading comment
Task 10: complete (commit 711889c1, review clean)
Task 11: dispatched (BASE 711889c1, opus)
Task 11: implementer add54ee0d312d9636 (dispatch notes now in kit-dispatch-notes.md)
Task 11: implementer DONE (commit 543d1bf2; RED via moved-aside lib; catalog.dart header wording stale)
Task 11: reviewer aa3a2f83500ed9114 (sonnet) on review-711889c1..543d1bf2.diff
Task 11: review Approved (spec ✅, 0 Critical, 0 Important; ports diffed against sources)
Ruling: Task 11 Minors — catalog.dart header wording stale (fix in Task 12 since it touches the registry next? no: Task 12 doesn't append; park for final wave); WallBands reads _live only on rebuild, so a freeze without a document change leaves a stale live set — carried into Task 12's dispatch (WT-frozen/WT-bands) to check whether the freeze path changes the document or must call invalidate — cost if wrong: a frozen wall keeps trimming neighbours until the next edit
Task 11: complete (commit 543d1bf2, review clean)
Task 12: dispatched (BASE 543d1bf2, opus)
Task 12: implementer aa1270486e3842f21
Task 12: implementer DONE_WITH_CONCERNS (commit e8f66cad; 14 mutations red; CONFIRMED: freeze emits no DocChange so WallBands keeps a frozen wall live — probe `Expected: not contains <18> / Actual: [18]`, a hover joins the frozen wall's band)
Ruling: fix it in the kit, centrally, now (pre-review fix round on Task 12): WallBands checks its cached live set on read — if any cached holder is no longer live (`_live(h) == null`) the cache is stale and rebuilds; set lookups only, no allocation, so the frame-path rule holds; a frozen wall's un-freeze comes with a document change (reload/undo) so the existing listener covers that direction — why: spec C1.5 needs frozen walls absent from host scans and bands; a contract signal (plan → kit freeze listenable) would be a contract amendment for one cache; per-action invalidate in every later consumer (Task 15 hostAt, Task 24 faces) spreads the duty — cost if wrong: O(walls) lookups per band read on hover
Task 12: pre-review fix DONE (commit 47a82226; WL4, WT-frozen-hover; M-WB-live reds both; no integration case — hover join not observable through public libraries)
Ruling: accept the read-time liveness check's cost (WT12, 600 walls: 35.86 µs vs 1.88 µs per hover band scan; allocation-free) — 36 µs is ~0.2% of a 16 ms frame, and the cheaper path needs a contract liveness signal for one cache; record the number in the results note — cost if wrong: a contract signal later, if a host with thousands of walls measures hover lag
Task 12: reviewer a4fa10aeb1dd83c1d (opus) on review-543d1bf2..47a82226.diff
Task 12: review Approved (spec ✅, 0 Critical, 0 Important; every ported assertion intact)
Ruling: Task 12 Minors parked — wall_bands.dart:35-37 doc wrong ("or an undo": Session.frozen only grows; reword to "a frozen object stays frozen for its document's life; a new document resets the cache"); WT-frozen-hover's click half is a control, comment it; O(walls) liveness check inherited by Tasks 15/24 — a PlanServices liveness revision is the follow-up if measured — cost if wrong: one misleading doc clause
Task 12: complete (commits e8f66cad, 47a82226, review clean)
Task 13: dispatched (BASE 47a82226, opus)
Task 13: implementer ad49414c8b7250b56
Task 13: implementer DONE (commit 597ae10c; 8 mutations red)
Task 13: reviewer ac5b29194b0fea8f9 (sonnet) on review-47a82226..597ae10c.diff
Task 13: review Approved (spec ✅, 0 Critical, 0 Important; 14 files diffed against sources)
Ruling: Task 13 Minors parked — long port-note comment lines; wall.dart ↔ opening_geometry.dart import cycle is plan-mandated (old line had it; no top-level initialisers) — note for the final review; whether a frozen opening still cuts its wall in WallType.generate (the engine's view shows frozen objects; spec C1.5 names host scans, not generate) — final review to confirm against C1.5 — cost if wrong: a frozen opening keeps its cut, which matches its frozen drawing
Task 13: complete (commit 597ae10c, review clean)
Task 14: dispatched (BASE 597ae10c, opus)
Task 14: implementer a3ab1e0bad0bf9e02
Task 14: implementer DONE_WITH_CONCERNS (commits 7ca6a275, 645bef75 OT-range-live; 19 mutations red)
Ruling: OT-frozen-host compares `canon` not `enc` after a refused edit — the lock applies then undoes, swapping two entities' slots; slot order is history, not state (06 D11), and the plan's own frozen_references_test uses canon; M-OT-13/14 still red — cost if wrong: a refused edit that changes state but not canon would slip (canon covers state)
Ruling: M-OT-14's file corrected to jet_cad_2d_plan/lib/src/kits/guard.dart (_freeze), plan text error
Task 14: reviewer a55f1996701d1a2d2 (opus) on review-597ae10c..645bef75.diff
Task 14: review Approved (spec ✅, 0 Critical, 0 Important; enc→canon sound; three fixture moves forced and assertion-neutral)
Ruling: Task 14 Minors parked — OT-frozen-host's delete half non-discriminating (reset lockHint before deleteSelection, assert it after, as the plan's frozen_references_test:117-119); opening_grips.dart:42 long port line — cost if wrong: the delete half adds no C1.10 pin (the plan's own test has one)
Task 14: complete (commits 7ca6a275, 645bef75, review clean)
Task 15: dispatched (BASE 645bef75, opus)
Task 15: implementer a9df5e1c68f080145
Task 15: implementer BLOCKED (uncommitted) — OS3's `expect(position, findsNothing)` (opening_panel_test.dart:334) fails: the plan panel shows the tool's settings AND the selected object's section; today only the settings showed
Ruling: (b) — the approved 2a design-mode spec (2026-10-14, PlanPropertyPanel row, line 345) says "The active tool's settings ... Below them, the one selected object's section", so both sections showing is the binding behaviour; OS3's line 334 changes instrument: assert the settings section is present and the window's section sits below it (position row present, below the settings' width row), not absent — an assertion line changed by a binding spec, the same class as the plan appendix's "Decided" lines; record in the results note — cost if wrong: a host expecting today's settings-only panel sees the object section too (2a already shipped that)
Ruling: accept the tool's frozen-wall memo fix (one bands re-check per pointer event; ~43 µs at 600 walls) with OL-frozen (memo) and M-OL-9
Task 15: implementer DONE after ruling (commit f3f25f3f; M-OL-1..9 red + 2 extras; OS1/OT1 now guard kit letters via plan shortcut guard)
Task 15: reviewer ad18aff01b56b0535 (opus) on review-645bef75..f3f25f3f.diff
Task 15: review Approved (spec ✅, 0 Critical, 0 Important; ruling-1 assertion meaningful; per-event re-check correct on every path, allocation-free)
Ruling: Task 15 Minors parked — a frozen opening stays in the tool's _others/_otherCuts on hover until a click or doc change (C1.5 names walls only; final review to judge); trailing clears unpinned separately (Shift path); OL-frozen (memo) only objectSnap off; OS1/rv9-guardDNG bite only on the plan's shortcut guard — cost if wrong: hover preview clamps against a just-frozen opening until the next click
Task 15: complete (commit f3f25f3f, review clean)
Task 16: dispatched (BASE f3f25f3f, opus)
Task 16: implementer a881ec9e91e371b6c
Task 16: implementer DONE (commits 60fb05de, d2c6d9ea; 14 mutations red; RoomInputs re-checks liveness on read: placedIn/bounds/generation O(n), inputOf/wallNeighboursOf O(degree))
Task 16: reviewer adfafc088c73f25a0 (opus) on review-f3f25f3f..d2c6d9ea.diff
Ruling: no contract liveness revision mid-plan — considered inserting a `PlanServices.liveRevision` (frozen-set size; caches compare O(1)), but every kit cache and geometry adapter takes a bare `LiveTypeOf` function (shared interfaces Tasks 9-16 and later), so the change would rewrite those signatures across seven tasks; measured costs are ~36-43 µs per hover at 600 walls; keep the per-cache allocation-free re-check pattern, carry it in kit-dispatch-notes for Tasks 17-24, and raise the revision as a follow-up proposal in the final results note — cost if wrong: O(n) liveness lookups per read in each cache until the follow-up
Task 16: review Needs fixes (spec ❌ 2 Important: I1 plan-mandated RoomInputs._live<T> duplicates live.dart liveObjectsOf verbatim; I2 _dropFrozenAround's frozen-wall self check unpinned)
Ruling: I1 — overrule the plan's Step 9 duplication: RoomInputs calls liveObjectsOf, _live deleted (the plan's own Global Constraints forbid verbatim logic duplication; Task 9 made liveObjectsOf for this) — cost if wrong: none observable; M-RR-5 retargets to live.dart's filter
Ruling: I2 — pin it (M-RR-15); fold Minors 2 (debugRebuilds unchanged after placedIn with nothing frozen) and 3 (class doc names the read-time re-check) into round 1; Minors 1, 4, 5 parked
Task 16: fix round 1 (resume a881ec9e91e371b6c)
Task 16: fix round 1 DONE (commit df16d97a; liveObjectsOf reused; M-RR-15/15b/16/17 red)
Task 16: re-reviewer ac20c807d8ecbb33f (sonnet) on review-d2c6d9ea..df16d97a.diff
Task 16: re-review fix round 1 Approved (4/4 addressed)
Ruling: Task 16 Minors parked — wall-only bounds-shrink step replaced by the outside separators (no dedicated wall-only bounds step); M-RR-9 redundant with M-RR-12; RoomInputs cost unmeasured until Task 19's TT6; barrel order — cost if wrong: one coverage gap the separators' step covers by the same code path
Task 16: complete (commits 60fb05de, d2c6d9ea, df16d97a; review clean after fix round 1)
Task 17: dispatched (BASE df16d97a, opus)
Task 17: implementer ac4a31a9d8757127b
Task 17: implementer DONE_WITH_CONCERNS (commit 660d3ffe; 3 brief defects fixed — unneeded imports, EG8-k unused reads; M-SP-1..10 + 8b red)
Ruling: kit CHANGELOG lacks the opening's entry (Tasks 13-15) — add at the final wave with the other doc fixes
Task 17: reviewer add7d7ca4f62ea4f8 (sonnet) on review-df16d97a..660d3ffe.diff
Task 17: review Approved (spec ✅, 0 Critical, 0 Important; ports verbatim, R-3 clean)
Ruling: Task 17 Minors parked — separator_tool.dart:39 84 cols; ragged wall_grips_test header; M-SP-8 comment should name M-SP-8b for the open half — cost if wrong: polish
Task 17: complete (commit 660d3ffe, review clean)
Task 18: dispatched (BASE 660d3ffe, opus)
Task 18: implementer af1602a02905976dd
Task 18: implementer DONE_WITH_CONCERNS (commit c511304d; 12+1 mutations red; RN5 committed skip:true — premise impossible: the plan freezes room A at open (C1.10), raw rename throws PlanLocked, frozen room shows no section)
Ruling: RN5 — the old premise (engine StateError reaching a live room's panel) cannot exist under C1.10; record as "Decided: premise impossible" (results note). Keep its intent instead of skipping: (1) RN5-open: the edited file opens with A frozen — A shows no Room section, raw rename throws PlanLocked, B's rename lands; (2) RN5-refused: a refused name edit through the panel on a live room (empty / whitespace name → write's ArgumentError) leaves the document unchanged and the field reverts to the stored name and keeps its pin. No skip:true left in the tree — cost if wrong: two new cases replace one ported case whose premise is gone
Task 18: pre-review fix DONE (commit 3746c3ed; RN5-open + RN5-refused, no skip; M-RM-2 reds RN5-refused)
Task 18: reviewer a3459245c4da098f6 (opus) on review-660d3ffe..3746c3ed.diff
Task 18: review Approved (spec ✅, 0 Critical, 0 Important; RN5 split keeps intent, B lines verbatim; M-RM-13 matches C3.5)
Ruling: Task 18 Minors parked for the final wave — (1) area memo keyed on stateId misses notifyLoaded/notifyPurged (E3 damage path can show a pre-damage Area until next command): key it on the change stream too or fix the comment; (2) roomPlan's room loop should call addRoom; (3) dragWorld/undoKey/select/clickAt near-copies across room_plans/opening_support/wall_shell — consolidate into the rig at the final wave (R-P14); (4) RN5-refused overlaps ported RN5's empty-name loop — note in accounting — cost if wrong: a rare stale Area string after a rollback failure
Task 18: complete (commits c511304d, 3746c3ed, review clean)
Task 19: dispatched (BASE 3746c3ed, opus)
Task 19: implementer a70b30794fe1e13b0
Task 19: implementer DONE_WITH_CONCERNS (commit 0d8a72c5; 9 brief mutations + M-RT-12/13 red; TT6 steady hover ~137-147 µs vs old 12-19 µs — RoomInputs' O(n) liveness re-check twice per hover; rig disposes the controller while the editor is mounted, so one failing widget test cascades "DiagnosticsLog used after dispose")
Ruling: TT6 cost — keep for now (well under a frame), record numbers in the results note and strengthen the follow-up (PlanServices liveness revision → O(1)); final wave may cut RoomInputs to one re-check per event like the opening tool — cost if wrong: ~0.15 ms hover cost on large plans until the follow-up
Ruling: rig teardown order (dispose after unmount) parked for the final wave — affects only failure diagnostics — cost if wrong: noisy cascades while debugging
Task 19: reviewer a7b8f9e93fb6d2290 (opus) on review-3746c3ed..0d8a72c5.diff
Task 19: review Approved (spec ✅, 0 Critical, 0 Important; every memo freeze-checked with first-reader steps)
Ruling: Task 19 Minors parked — TT7's `toolNotice.value isNull` after Esc is always true (plan-mandated; sibling line pins it): read the Room tool's notice directly in the final wave; _setOccupied set order; RT-tool icon unasserted; m² count wording — cost if wrong: one vacuous ported line
Task 19: complete (commit 0d8a72c5, review clean)
Task 20: dispatched (BASE 0d8a72c5, opus)
Task 20: implementer a68a1455640086716
Task 20: implementer DONE_WITH_CONCERNS (commit 83d84672; 9 mutations red, M-RT-10 run as equivalent; concern for 21-22: callers' `points` memo passed to attachCandidates can keep a live wall's joined points after a neighbour freezes)
Ruling: carry the `points` memo concern into Tasks 21-22's dispatch (FREEZE RULE: re-check, first-reader step, mutation)
Task 20: reviewer ad9a4b01391c284f2 (sonnet) on review-0d8a72c5..83d84672.diff
Task 20: review Approved (spec ✅, 0 Critical, 0 Important; dimension_attach.dart stateless)
Ruling: Task 20 Minors parked — M-DG2/M-DG3 red via `!` throw, not the test's reasons: add a candidate-set assertion before the points step at the final wave; DG-frozen single placement (brief) — cost if wrong: two mutations pinned indirectly
Task 20: complete (commit 83d84672, review clean)
Task 21: dispatched (BASE 83d84672, opus)
Task 21: implementer ac5798750e89bf475
Task 21: implementer NEEDS_CONTEXT (commit eef72684 without the panel test; kit 391 green; M-DM1..11 red incl. freeze re-check on the grips' per-drag memo; PN2 focus line fails: after a ChoiceProperty choice focus stays on the plan's DropdownButton, today's SegmentedButton left it on the canvas; PN5's refused edit frozen at open)
Ruling: PN2 — fix the plan library, keep the ported line: the approved 2a spec says "Focus rules are today's" (design-mode spec :393) and lists the panel-focus traps; a choice row that keeps focus is a 2a defect (Space/Enter/arrows go to the dropdown). The plan panel's ChoiceProperty row returns focus to where it was before the menu opened once a choice is made (or the dropdown never takes focus); pin it with a plan-library test and a mutation — cost if wrong: one small plan-library change in 3a's scope (3a already amends the plan library)
Ruling: PN5 — confirm PN5-open (Task 18 rule); the live half is "Decided: premise impossible" (no refusable kind switch on a live dimension; the panel's catch is exercised by PN5's runtime stale callback)
Task 21: rulings applied (commits 90417584 plan choice-row focus hand-back + P-choice-focus, 17294c58 panel cases; plan 1549, integration 90, kit 393; 13 mutations red)
Ruling: plan CHANGELOG entries for 3a's plan-library changes collected at the final wave (none written yet)
Task 21: reviewer a797b6f2b5367f3e8 (opus) on review-83d84672..17294c58.diff
Task 21: review Approved (spec ✅, 0 Critical, 0 Important; focus fix correct for a completed choice; freeze re-check genuine first-reader)
Ruling: Task 21 Minors parked — Esc/barrier dismiss keeps focus on the row, unpinned (add an Esc step + tool-settings scope to P-choice-focus at the final wave); hand-back relies on route microtask order (fragility note); _settle iterates _fields only; addSeparator/buildPlanIn duplicates (reconcile pass, R-P14); stale PN2 comment; UI separator not run end to end for the dimension — cost if wrong: an unpinned Esc path
Ruling: the latent groupFor name clash (room_plans groupFor(Placement,int) vs separator_plans groupFor(int)) is carried into Task 22's dispatch
Task 21: complete (commits eef72684, 90417584, 17294c58, review clean)
Task 22: dispatched (BASE 17294c58, opus)
Task 22: implementer ae1628d79bbc8d428
Task 22: implementer DONE_WITH_CONCERNS (commit 2dbf27c1; M-DT1..8b red; hover memo freeze re-check; notice value uses the PAGE's separator; TL8 612 walls idle band path ~110 µs vs 44 µs without the check, old 38 µs, D12 budget 1,000 µs)
Ruling: accept the cost (inside D12's 1,000 µs budget); record with the other liveness-check numbers for the follow-up (PlanServices liveness revision)
Task 22: reviewer acaee172ca0134232 (opus) on review-17294c58..2dbf27c1.diff
Task 22: review Approved (spec ✅, 0 Critical, 0 Important; notice uses the PAGE's separator per spec :523, :325-328)
Ruling: Task 22 Minors parked — split DT-freeze into four tests so each step's M-DT8 red is observable; display staleness (ring/preview/notice) after a freeze until the next event; no allocation pin on _memoStillLive — cost if wrong: indirect evidence for steps 2-3
Task 22: complete (commit 2dbf27c1, review clean)
Task 23: dispatched (BASE 2dbf27c1, opus)
Task 23: implementer a6f053f28e8376e75
Task 23: implementer DONE (commit b10cf092; 41 symbols/198 leaves exact vs today's jetlib; de/tr 47 words byte-exact; M-FU1..9 red)
Task 23: reviewer a49e71611e6b7267e (opus) on review-2dbf27c1..b10cf092.diff (assets excluded)
Task 23: review Approved (spec ✅, 0 Critical, 0 Important; geometry 41/198 exact and words 47+47 reproduced independently; generator deterministic)
Ruling: Task 23 Minors — placeEntry's copyOfEntry reuses a definition by key@version only (documented; carried into Tasks 24/28 notes); long mandated comment line; M-FU8 plan text uncompilable — cost if wrong: a test placing two libraries' same key@version into one doc reuses the wrong copy
Task 23: complete (commit b10cf092, review clean)
Task 24: dispatched (BASE b10cf092, opus)
Task 24: implementer ad70ae8170c098ae3
Task 24: implementer DONE_WITH_CONCERNS (commit 8bd6f97f; 12+2 mutations red; WF-frozen-first, WF-hidden-toggle added; no earlier integration test changed; concerns: no CHANGELOG entry, layers changed outside a command seen only on stream delivery, a command may cause two WallFaces rebuilds — Task 28 WA9 to confirm)
Task 24: reviewer ae05f88afceee47d9 (opus) on review-b10cf092..8bd6f97f.diff
Task 24: review Approved (spec ✅, 0 Critical, 0 Important; port exact, provider mapping exact, freeze re-check genuine)
Ruling: pin D-06's steady state now (one-line fix round, cheap; a rebuild on every query would break the frame non-negotiable): in WF-hidden-toggle a second identical query keeps builds at +1; M-WF14 (delete `_state = state`) must go red. Double-rebuild concern resolved by the reviewer (async change stream; only no-pump tests see two) — carry the microtask reasoning into Task 28's WA9 dispatch. CHANGELOG and stale class doc parked for the final wave
Task 24: fix round 1 (resume ad70ae8170c098ae3)
Task 24: fix round 1 DONE (commit e35cc9ff; M-WF14 red "Expected: <2> Actual: <3>"); scoped re-review by the controller (11-line test/doc diff: the two steady-state asserts land where ruled) — Approved
Task 24: complete (commits 8bd6f97f, e35cc9ff, review clean)
Task 25: dispatched (BASE e35cc9ff, opus)
Task 25: implementer ab7a8c119409392f3
Task 25: implementer DONE (commit 45be3170; sample flat byte-identical to today's startupPlan modulo ids, en/de/controller; M-SF1..5 red)
Task 25: reviewer a86a7f508c1d73b9f (sonnet) on review-e35cc9ff..45be3170.diff
Task 25: review Approved (spec ✅, 0 Critical, 0 Important; port exact, old line untouched)
Ruling: Task 25 Minors parked — WR9 non-vacuity pair (walls non-empty) at the final wave; ported print noise accepted
Task 25: complete (commit 45be3170, review clean)
Task 26: dispatched (BASE 45be3170, opus)
Task 26: implementer a24ef745bf65a1d42
Task 26: implementer DONE_WITH_CONCERNS (commit 675f7f2f; integration 138, kit 617; M-IT-1..9 red)
Ruling: accept the three deviations, all instrument/fixture with assertions unchanged — (1) TL9 reads the guarded tool's inner tool through @internal `toolFor` (R-P9's road; every plan tool is GuardedTool, spec P4); (2) never build a second SpatialIndex over a document the editor owns (one mutation-hook slot; a second index steals it → SlotStateError) — read the editor's index via `tools.context.index` (`indexOf` in canvas_rig); (3) A12b re-pumps the editor after a permissions change, as the source re-pumps its composition. D-48 table rows naming Task 27/28 tests are expected
Task 26: reviewer a6a6cc87f2f2349f9 (opus) on review-45be3170..675f7f2f.diff
Task 26: review Needs fixes (1 Important, plan-mandated: P-1's `.data isNotNull` on a non-nullable map is vacuous)
Ruling: P-1 → `equals(hostData())` if setUnitData stores it unchanged, else `isNotEmpty`; red with the undo removed. Fold Minors 2 (shared `symbolsReady(tester, c)` in canvas_rig, used by both callers) and 5 (resolve the `section` top-level clash canvas_rig vs opening_support before Tasks 27/28 import both) into round 1; Minors 1, 3, 4, 6, 7 parked (6: Task 27/28 dispatch notes get worldEndsOf's real record shape)
Task 26: fix round 1 (resume a24ef745bf65a1d42)
Task 26: fix round 1 DONE (commit c52df050; P-1 equals(hostData()), red with setUnitData removed while old isNotNull stays green; symbolsReady shared; canvas_rig section → sectionFinder); scoped re-review by the controller (26-line diff) — Approved
Task 26: complete (commits 675f7f2f, c52df050, review clean after fix round 1)
Task 27: dispatched (BASE c52df050, opus)
Task 27: implementer ae95029938c39d30c
Task 27: implementer DONE_WITH_CONCERNS (commit cdd95213; integration 176 + 1 skip WS9, kit 620; 7+1 mutations red)
Ruling: WS9 — apply the standing Task 18 rule (no skip in the tree): WS9-open (malformed plan opens with wall A frozen + hookFailed diagnostic, no section, raw edit PlanLocked, canon unchanged) + WS9-refused (the old intent on a live wall: an out-of-range thickness — 0, negative, > kWallMaxThickness — typed and committed through the panel is refused, field reverts, doc/undo unchanged); "Decided: premise impossible" in the accounting
Ruling: accept LK2's placeholder-only template exclusion + positive control (the brief's allowlist was vacuous; record as a plan-text correction), the optional `layerPanel` parameter on planEditorApp/pumpEditor (test package API), and the other deviations (instrument/fixture, assertions unchanged)
Task 27: fix round 1 (resume ae95029938c39d30c)
Task 27: fix round 1 DONE (commit a85e5f7e; WS9-open + WS9-refused, 0 skipped; M-WS9-r red) — POSSIBLE DEFECT: in the malformed plan, an edit of wall C (no neighbour of frozen A) is refused with PlanLocked; B too; the box edits fine. Old WS9 asserted "C is sound: its edit lands". Dispatching a read-only root-cause investigation in parallel with the Task 27 review
Task 27: reviewer ac1ca323f719487c7 (opus); investigator a0184061a2bd57676 (opus, read-only) on the WS9 C/B PlanLocked
Investigation (WS9 C/B PlanLocked): root cause found — not a defect. The malformed fixture makes A's fill 1301 name B's outline 2602; A frozen → B regenerates without A (C1.5) → B's corner changes → SetEntityGeometryCommand(2602) touches every fill naming it, incl. 1301 (owner = locked A) → _LockCheck refuses. C's closure reaches B by reach overlap. Lock set is exactly {A}; walls declare no references. Intended: the edit would visibly change frozen A's fill.
Ruling: not a defect; pin it in WS9-open (C and B edits refused with canon unchanged, the box edit lands, locked == {A}) with a plan-side mutation (`_check` skipping the covers hit) and the box control; dropping the old "C lands" lines was correct
Ruling (human-facing spec question, results note): in a WELL-FORMED plan a frozen wall's spatial neighbour silently un-joins its corner when an edit's closure reaches it, and the edit lands (C1.5 accepts frozen walls absent from generate; C1.10 locks references only). Closing it needs a spec decision ("a frozen wall locks its spatial neighbours"), not a code fix — raise in the final message
Task 27: review Needs fixes (I1: WS9-refused repeats WS3/WS11's ArgumentError path and drops the old WS9's document-refusal + justification-toggle intent; I2 plan-mandated IP-R4: fxKit has no KitNames, so DT1's tr==en and LK2's English allowances can't fail). Scratch files the reviewer saw were the investigator's, now gone (tree clean)
Ruling: I1 — the investigation found the real document-level refusal on a live object: in the malformed plan, C (live) is refused by the lock. Move the old intent there: WS9-open edits C's thickness THROUGH THE PANEL → refused (execute false), field reverts to C's stored value, canon unchanged; toggling C's justification is refused, shows C's value, no exception; B the same; the box edit lands (control); locked == {A}. Mutations: plan `_check` skipping the covers hit; the panel's revert on a false execute removed. Drop WS9-refused (duplicates WS3/WS11; record it). I2 — give fxKit KitNames with a Turkish symbol word and category word; DT1 and LK2 then allow the Turkish words. Minors folded: reuse room_plans' `select` in selection_page/decimal_separator tests; line-level ignore in determinism_test. Others parked
Task 27: fix round 2 (resume ae95029938c39d30c)
Task 27: fix round 2 DONE (commit 524cc375; WS9-open covers the document refusal on C/B through the panel, box control, locked=={A}; WS9-refused removed; fxNames de/tr; DT1/LK2 live; mutations red)
Task 27: re-reviewer add7c897f3f8d2ce3 (sonnet) on review-a85e5f7e..524cc375.diff
Task 27: re-review fix round 2 Approved (3/3 addressed; reverted values are the stored ones; fxNames copied from today's furniture words)
Ruling: Task 27 Minor parked — the justification toggle's refused-revert path is not independently shown red (the thickness step fails first under mutation b); IP-door-actions' field-only checks; stale source citations
Task 27: complete (commits cdd95213, a85e5f7e, 524cc375; review clean after fix round 2)
Task 28: dispatched (BASE 524cc375, opus)
Task 28: implementer ad6a05f2278fcc1ff
Task 28: implementer DONE_WITH_CONCERNS (commit 9ad8f0e5; kit 650, integration 226; IA-alloc green; M-IA-alloc/1/2/4/5 red, M-IA-3 green on SS16 — the pumps deliver the change stream so the stateId check never decides; Task 24's kit test reds it)
Ruling: W-5's and the permissions case's `bands.generation` lines — the human delegated decisions to the controller: not ported, instrument impossible under R-P1 (the bands live in the plan's services, no public read); their behaviour is pinned in the kit (WL/WB/WT-frozen generation steps); record as "Decided" in the results note
Ruling: M-IA-3 green on SS16 accepted — the stateId path is pinned by the kit's wall_face_provider_test steady-state/freeze steps; SS16 unchanged (A12)
Ruling: IA-R4 ghost reads as click-read-undo — pending the reviewer's judgement on whether the zoom case and R-3 lost their camera-listener / permission re-resolve pins
Task 28: reviewer a2e8360a4eb91db9d (opus) on review-524cc375..9ad8f0e5.diff
Task 28: review Needs fixes (I1 plan-mandated: IA-R4 click reads re-resolve on pointer events, so four cases — zoom, R-3, re-arm (hidden block can't fail), M/R keys — no longer pin re-resolves without a pointer event; I2: blank-query "library order" oracle swapped to c.symbols)
Ruling: I1 — read the resting ghost through the public SelectionOverlayPainter (paint the tool's overlay into a drawLine-recording spy right after the zoom / permissions change / re-arm; the marker at worldToScreen(want.marker) when attached), no click; restore those pins with named mutations (remove the camera listener, the gatesChanged re-resolve, _onArmed's re-resolve); cases whose immediate read cannot be made without a pointer event are marked "Not ported (IA-R4)" instead of asserting what cannot fail. I2 — compare with the asset's order (`furniture.entries`). Fold Minors: worldAt local copy in dimension_shell_test removed; answerAt/instancesOf/partsOf into attach_plans.dart; zone_room_test's shadowed kPlanMin/MaxScale removed; W-5 note; IA-alloc strengthened (frame b turned about the centre, a few architecture.* furniture instances placed) — the non-negotiable deserves a non-degenerate scene. Parked: kAttachPixels self-check, repeated save; the plan.select drag snapping to the dragged unit's own old edge midpoint → surface in the final review as a possible 2a defect
Task 28: fix round 1 (resume ad6a05f2278fcc1ff)
Task 28: fix round 1 DONE (commit 20d592d9; resting-ghost reads through the tool's overlay; 4 re-resolve mutations red; library order from the asset; IA-alloc turned camera + 6 furniture instances, green, M-IA-alloc red; bands.generation already ruled by the controller)
Task 28: re-reviewer aaae90f6d35fc7103 (sonnet) on review-9ad8f0e5..20d592d9.diff
Task 28: re-review fix round 1 Approved (painter reads via the tool's own paintOverlay, no pointer event; 4 re-resolve mutations; library order from the asset; IA-alloc turned + 6 instances)
Ruling: Task 28 Minors parked — `_onArmed`'s `_attached = null` unpinned (hidden path unreadable without a pointer; recorded Not ported IA-R4); restingMarker's 4-line hourglass heuristic
Ruling: the lines plan-marked "human" (IA-R3, IA-R4, IA-R5 and Task 28's bands.generation lines) are decided by the controller under the human's delegation ("kararları sana bırakıyorum", this session): not ported, reasons as recorded in task-28-report.md; Task 29's note lists them under "Lines dropped" as "decided by the controller (delegated)", not "pending"
Task 28: complete (commits 9ad8f0e5, 20d592d9, review clean after fix round 1)
Task 29: dispatched (BASE 20d592d9, opus)
Task 29: implementer a3995d4991d5bd9b0
Task 29: implementer DONE_WITH_CONCERNS (commit 13fb4933; every gate green or standing; Appendix A closed; findings: missing source lines in 10 dimension tests + wall_faces_test, D-36 path, cost prints higher in full run)
Task 29: reviewer a5173c8b26a692f18 (sonnet) on review-20d592d9..13fb4933.diff
Task 29: review Needs fixes (Critical: note quotes cost figures — WT12 80.38 µs, OT4 76.20/89.60 µs, GE5b 2595/112 µs — and dry-run file sizes as "this run" that task-29-report.md does not transcribe)
Ruling: re-run the cost prints and the three dry runs, transcribe their full printed lines into task-29-report.md, and make the note match exactly (cut any figure not re-printed); rename "Lines dropped, the human's word" → "Lines dropped, decided by the controller (delegated)" and align item 11; split the plan CHANGELOG bullet
Task 29: fix round 1 (resume a3995d4991d5bd9b0)
Task 29: fix round 1 DONE (commit 945502cb; cut untranscribed figures verified absent; reruns transcribed; heading renamed; CHANGELOG split); scoped re-review by the controller (grep of the cut figures: 0 hits; headings) — Approved. New: this run's TL8 prints a face-line move of 1481 µs, over D12's 1,000 µs (printed, not asserted) → final review
Task 29: complete (commits 13fb4933, 945502cb)
ALL TASKS 1-29 COMPLETE. Final whole-branch review next (opus), BASE 7e65905b HEAD 945502cb
Final review: a126b67fe923263c6 (opus), 7e65905b..945502cb, lib focus + cross-task seams + TL8 face-line 1481 µs
Final review: Ready to merge — 0 Critical, 0 Important, 8 Minor (M1 TL8 face line inherited: kit 1488 µs vs old line 1499 µs; M2 liveness check O(objects × types); M3 Room/Separator repeated RoomInputs passes; M4 build/prepare failure not re-reported; M5 PlanObject has no live view (contract candidate); M6 @internal ignores hard to audit; M7 DimensionGrips subscription after cancel; M8 RF5 room half kit-only)
Ruling: ONE fix wave per fix-wave-brief.md — A (M3, M4, the Task 18 area-memo doc), B (doc accuracy), C (cheap unpinned/vacuous tests from the parked list), D (rig teardown, line-level ignores, helper consolidation); not in the wave: cosmetic line lengths, the plan-mandated import cycle, the inherited/follow-up items (TL8 face line, liveness revision, neighbour-only wallsInDocument, PlanObject.liveTypeIdOf — results-note follow-ups), M7 (harmless), M8 (optional) — cost if wrong: a few Minors reach merge recorded
Fix wave: dispatched (BASE 945502cb, opus)
Fix wave: implementer a949b4716724427d9
Fix wave: implementer hit an API rate limit (HTTP 429) after 3 commits (ddc44e76 A1, 017480eb A2, 53743d55 A3+B1-B9); tree clean; resuming the same agent for C and D
Fix wave: DONE (HEAD 81950ac3; 22/23 items; C8 skipped — kits.reversed is an equivalent mutant: validateKitSet refuses a foreign word, so two kits' words never conflict; C2 deviation mirrors the plan's FL-delete; gates contract 403, plan 1551, kit 655, integration 227, invariants, IA-alloc, dry runs 0 warnings)
Ruling: accept C8's skip (equivalent mutant, evidence KitSetError foreignWordId) and C2's deviation
Fix wave: re-reviewer aad63363624514316 (opus) on review-945502cb..81950ac3.diff
Fix wave: re-review Approved (22 ✅, C8 ⏭ accepted; reviewer re-ran contract 403, plan 1551, kit 655, integration 227 at 81950ac3; D1 probe shows no cascade; results-note figures all attributed)
Ruling: residual Minors parked at merge (one fix dispatch done, per the workflow): room_inputs.dart:221-226/:244-249 docs say every read re-checks (now once per bracketed event); attach_plans.dart aimCamera near-copy of centreCamera; wall undoKey pump placement changed (count same, tests green) — cost if wrong: two stale doc sentences and one test-helper copy reach main
FINAL REVIEW CLEAN. Next: archive the ledger onto the branch, STATUS, then the finishing menu (merge is the human's)
