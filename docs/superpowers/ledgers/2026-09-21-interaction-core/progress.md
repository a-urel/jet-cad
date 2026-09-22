# SDD ledger — plan: docs/superpowers/plans/2026-09-21-interaction-core.md

Spec: docs/superpowers/specs/2026-09-21-interaction-core-design.md (revision 2).
Worktree: .claude/worktrees/plan-02-interaction-core, branch plan-02/interaction-core, cut from main at 3fedeb9.
Started 2026-09-21. `flutter pub get` rewrote packages/jet_cad/analysis_options.yaml; restored with `git checkout --` (Ruling 01-1 stands).

## Pre-flight scan

| pair / task | produces vs consumes | found |
|---|---|---|
| T1 ↔ T2 | `leafTouchedByBand(kind, payload, ta..tf, band, {textBox})`, `boxEnclosedByBand`, `textBoxOf` | consistent |
| T2 ↔ T5 | `forEachLeafInBand(band, mode, filter, visit(int))`, `forEachInstanceInBand(…, visit(Handle))` | consistent |
| T3 ↔ T5, T6 | `SelectionKey.root(Handle)`, `topmostGroupOf(doc, owner, ancestors)`, `remove`, `setHover` | consistent after the plan's dedupe edit |
| T4 ↔ T5, T9 | `ToolPointerEvent` nine fields; `ToolController(initial:, context:)`, `.context`, `.active` | consistent |
| T5 ↔ T7 | `kWindowBandColor`, `kCrossingBandColor`, `kBandFillAlpha` created in T5's `selection_style.dart`, T7 adds the rest | consistent |
| T5 ↔ T9 | `kPickRadiusPixels` defined in T5, moved to `interaction_layer.dart` in T9 | consistent, one move |
| T7 ↔ T8 | `OutlineCache(document, selection)`, `pathFor(key, origin)`, `rebaseOriginFor` (exported via camera_controller.dart) | consistent |
| T8 ↔ T10 | `SelectionOverlay({selection, tools, camera, outlines, repaint, onPaintForTest})` | identical |
| T9 ↔ T10 | `InteractionLayer({tools, child})` | consistent |
| T1 self | arc window test vs `_angleInWindow` (windows in (−π, 3π], start from atan2) | consistent via mod 2π normalisation |
| T2 self | `_leafPasses` window reads a container-space box and lifts by `toWorld`; `index.dirty` is a public field | consistent; `_scratchContains` is O(n²) at pointer-up rate — acceptable, noted for the reviewer |
| T2 self | `forEachLeafInBand` root search in window mode uses the band box (a box enclosed by the band overlaps it) | consistent |
| T3 self | prune rule by key shape; `debugOnChange` test hook | consistent |
| T5 self | a group's "member leaves" = its owned leaves and nested groups' leaves; child **instances** of a group do not enter the every/any rule | **Ruling P-1** below |
| T6 self | `doc.commands.permissions` is a public field; `doc.fills.fillsOf(boundary)` exists | consistent |
| T8 self | `_matrix[10] = 1, [15] = 1` set at construction | consistent |
| T10 self | `PlannerView` gains `selection`, `tools` | consistent |
| Global | overlay tests never rebuild between mutation and assertion | binding, carried to T8 and T9 briefs |

Ruling P-1: a group's band membership counts its owned leaves and its nested groups' leaves only; an instance placed inside a group is not a "member leaf" and does not decide the group's every/any verdict — because spec D8 says "member leaf", and an instance inside a group is itself selectable through the instance walk only when it is root-level, which it is not; a group containing only instances is therefore never band-selected in 02 — costs: a group of symbols cannot be band-selected until a later plan decides instances-in-groups; recorded in the results note.

Ruling P-2: implementer models — Sonnet for Tasks 1, 3, 4, 5, 6, 10; Opus for Tasks 2, 7, 8, 9 (engine descent, the rebase, the routing table); reviewers Sonnet for 1, 3, 4, 5, 6, 10 and Opus for 2, 7, 8, 9; final review Opus — because those four tasks carry the review's blockers; costs: more tokens on four tasks.

## Task log
Task 1: dispatched (BASE 3fedeb9, implementer sonnet)
Task 1: minor (deferred): point branch duplicates containsPoint inline (brief's own sketch)
Task 1: minor (deferred): no test for the one-point polyline branch
Task 1: complete (commits 3fedeb9..0ca5ca0, review clean)
Task 2: dispatched (BASE 0ca5ca0, implementer opus)
Task 2: Ruling: M-02s fixture band raised to maxY 1030 — the plan's band (maxY 1010) could not enclose the leaf moved to y=1020; the dirty-overlay property is what the test guards — costs nothing if wrong beyond a fixture number
Task 2: Ruling: dedupe by adjacent pair after the sort, not the plan's O(n^2) scan — same result, linear — costs nothing
Task 2: Ruling: TableSection.add, not put (plan named the wrong method)
Task 2: note: implementer committed with an Opus trailer; amended to the house line, head 0ca5ca0..29f2376
Task 2: review round 0 — Needs fixes: (1) mutation table totals do not reconcile (16 claimed, 15 rows, 12+3); (2) singular instance transform decided by an inverse window never uses (plan-mandated shape); (3) six fixtures at identity/origin, three bands without a straddler, M-02z cannot tell the modes apart
Task 2: Ruling: on SingularTransformError the walk does not refuse — window never inverts (its box lift is forward-only); crossing falls back to the all box for that container's local query and tests leaves forward, so a collapsed instance is judged by the same forward geometry the brute-force arm uses — because spec D8 states both rules in world space and the inverse is only a broad-phase convenience — costs: one whole-container scan for a degenerate instance, which is a malformed document anyway
Task 2: minor (deferred): M11 equivalence argument incomplete (dirty overlay case; holds via _growPlacements); M14 analysis vs the dedupe comment; _localBandBox duplicates _localQueryBox (plan-mandated placement, allocation reason undocumented); untested world.isEmpty/disposed order, fill under an instance, instances-only definition; spatial_index.dart +306 lines (plan-mandated location); report cites fff06e4, head is 29f2376 after the trailer amend
Task 2: fix round 1/5 dispatched (fix commit 29f2376..b5e7a0a; re-review sonnet)
Task 2: fix round 1/5 (3 addressed, 0 open — mutation table reconciled 16/13/3; singular transform judged forward; six fixtures off identity with straddlers; commits 29f2376..b5e7a0a)
Task 2: complete (commits 0ca5ca0..b5e7a0a, review clean after round 1)
Task 3: dispatched (BASE b5e7a0a, implementer sonnet)
Task 3: Ruling: dart:collection import added and cameraAt(translation) typed Offset — brief omissions, local — costs nothing
Task 3: review dispatched (b5e7a0a..00fee71, reviewer sonnet)
Task 3: review round 0 — Needs fixes: toggle notifies on a self-cancelling duplicate input (plan-mandated snippet)
Task 3: Ruling: toggle compares the set before and after and notifies only on a net change — spec D6 'none when nothing changed' is binding over the plan's snippet — costs nothing
Task 3: minor (deferred): no test for remove of an absent key or setHover of a selected key; report says prune on Command* only, code prunes on every non-load change (report wording); == compares target before chain (no behavioural effect)
Task 3: fix round 1/5 dispatched
Task 3: fix round 1/5 fix commit 00fee71..a864a8b; re-review sonnet dispatched
Task 3: fix round 1/5 (1 addressed, 0 open — toggle net-change notify; commits 00fee71..a864a8b)
Task 3: complete (commits b5e7a0a..a864a8b, review clean after round 1)
Task 4: dispatched (BASE a864a8b, implementer sonnet)
Task 4: note: implementer committed with a Sonnet trailer; amended to the house line (e6c530b rewritten); review dispatched on a864a8b..e6c530b (reviewer sonnet, falls back to git diff)
Ruling P-3: every implementer dispatch from Task 5 on states the trailer line in bold and the check 'git log -1 --format=%B | tail -1' before reporting — two of four implementers used their own model name — costs nothing
Task 4: review round 0 — Needs fixes: activate notifies twice when the outgoing tool's cancel notifies (plan-mandated order); minor: identity camera in the test fixture
Task 4: Ruling: activate removes the outgoing tool's listener before calling cancel, so the controller notifies exactly once per activate; the cancel's own repaint need is covered by that one notify — spec Architecture says 'notifies once' — costs nothing
Task 4: Ruling: the identity-camera fixture is fixed in the same round (binding constraint, one line) rather than deferred
Task 4: fix round 1/5 dispatched
Task 4: fix round 1/5 fix commit 4626779..fae61c4; re-review sonnet dispatched
Task 4: fix round 1/5 (2 addressed, 0 open — unhook before cancel, non-identity camera; commits 4626779..fae61c4)
Task 4: minor (deferred): second controller test does not dispose its controller
Task 4: complete (commits a864a8b..fae61c4, review clean after round 1)
Task 5: dispatched (BASE fae61c4, implementer sonnet)
Task 5: DONE_WITH_CONCERNS-shaped observations (seenGroups dedup untested; paintOverlay untested until Task 8) — noted, proceeding to review; review dispatched (fae61c4..fc05c43, reviewer sonnet)
Task 5: review round 0 — Needs fixes: tests 7/8/9 at camera scale 1.0; tests 8/9 bands without a straddling entity
Task 5: minor (deferred): seenGroups dedupe unfalsifiable; paintOverlay/_drawDashedRect untested until Task 8; test 2's second line inert
Task 5: fix round 1/5 dispatched
Task 5: fix round 1/5 fix commit fc05c43..6fdfe91; re-review sonnet dispatched
Task 5: fix round 1/5 (2 addressed, 0 open — non-identity cameras, straddlers in tests 8 and 9; commits fc05c43..6fdfe91)
Task 5: complete (commits fae61c4..6fdfe91, review clean after round 1)
Task 6: dispatched (BASE 6fdfe91, implementer sonnet)
Task 6: Ruling: fixtures seeded under DraftPermissions.all then dispatcher.permissions flipped to the restrictive grant — the existing command_test idiom; costs nothing
Task 6: review dispatched (6fdfe91..24e09d8, reviewer sonnet)
Task 6: minor (deferred): _groupCascade and _everyLeafIn walk the group subtree in two shapes; a shared visitor if a third consumer appears
Task 6: complete (commits 6fdfe91..24e09d8, review clean)
Task 7: dispatched (BASE 24e09d8, implementer opus)
Task 7: Ruling: the outline of a group descends into its child instances (agrees with Task 6's cascade: the outline shows what Delete removes) even though Ruling P-1 keeps instances out of the band every/any rule — costs: a visual/selection asymmetry for instances inside groups, recorded for the results note
Task 7: Ruling (carried to Task 8): a selected point has a one-point path and draws nothing; the overlay draws a point key as a screen-space cross of 3 x kSelectionStrokePixels at worldToScreen(point), read from the cache's world record, never zoom-dependent geometry in the rebased path
Task 7: minor (deferred): _byOwner batch-clearing has no direct witness (an added leaf would be one); text-corner branch and mirrored-arc sweep sign untested in this task
Task 7: review dispatched (24e09d8..87bed32, reviewer opus)
Task 7: review round 0 — Approved on the rebase; Important: no public worldPointOf for Task 8's point cross
Task 7: Ruling: fix round 1 takes the accessor plus minors 2, 3 and 11 (origin getter doc, debugRebuilds getter, text-arm and mirrored-arc tests) — cheap now, Task 8 builds on them; minors 4-10 deferred
Task 7: minor (deferred): two Sets per selection notify; third container walk of the same shape (a shared forEachLeafUnder if a fourth appears); _byOwner declared mid-class; unreachable fill case uncommented; text literals hoistable; zero-radius arc untested; M-02v's discriminating assertion never the one that fires; construct SelectionController before OutlineCache (Task 8/10 wiring note)
Task 7: fix round 1/5 dispatched
Task 7: fix round 1/5 fix commit 87bed32..17d36e2; re-review sonnet dispatched
Task 7: Ruling: the mirrored-arc fixture asserts the world record (debugWorldArcsOf) to 1e-9 and only a containment bound on the path, because ui.Path.getBounds returns the conic control-point hull, not the curve's bound (measured: 19.1 vs 17.0 for a 2.6 rad sweep of radius 7) — costs: the path itself is pinned only to within the hull; the record is exact
Task 7: minor (deferred): worldPointOf returns null for a group holding a point plus other leaves
Task 7: fix round 1/5 (4 addressed, 0 open — worldPointOf, origin doc, rebuild getter, text and mirrored-arc fixtures; commits 87bed32..17d36e2)
Task 7: complete (commits 24e09d8..17d36e2, review clean after round 1)
Task 8: dispatched (BASE 17d36e2, implementer opus)
Task 8: Ruling: the painter class is renamed SelectionOverlayPainter (file stays selection_overlay.dart) — Flutter's widgets library exports a SelectionOverlay and the app imports material plus the barrel, so the spec's name would force a hide at every app import — costs: a name that departs from spec D9's; the spec is amended in Task 12
Task 8: Ruling: worldPointOf's one Vector2 per point key per frame is accepted — points are rare in a floor plan and the per-entity rule is about entities walked, not keys selected — costs: a small allocation while a point is selected; recorded in the results note
Task 8: review dispatched (17d36e2..f213f14, reviewer opus)
Task 8: review round 0 — Needs fixes: zero-size paint pushes absolute world coordinates (origin zero) and rebuilds twice; screen-space pass unclipped; no off-diagonal matrix fixture (transpose survives)
Task 8: Ruling: fix round 1 takes the three Importants, the rename, and minors 1-3 (canvasBefore > 0, copy the recorded matrix, fractional criterion-14 offset) — minors 4-8 deferred
Task 8: minor (deferred): four Offsets per point key per frame (drawRawPoints would remove them); selection.keys called twice per frame; worldPointOf doc says subtract origin, painter maps to screen instead — amend the doc; cross half-length derived from a stroke constant; SelectTool.paintOverlay allocates two Paints per frame while dragging (Task 5 note)
Task 8: fix round 1/5 dispatched
Task 8: fix round 1/5 fix commit f213f14..531c91f; re-review sonnet dispatched
Task 8: note: the tool's band is now clipped to the overlay's bounds (a band dragged past the viewport edge is cut at the edge) — intended by the clip fix; results note records it
Task 8: fix round 1/5 (R + 3 Important + 3 minors addressed, 0 open; commits f213f14..531c91f)
Task 8: minor (deferred, carried to Task 9): selection_style.dart:11 doc still names SelectionOverlay
Task 8: complete (commits 17d36e2..531c91f, review clean after round 1)
Task 9: dispatched (BASE 531c91f, implementer opus)
Task 9: Ruling: the plan's test 8 text is superseded — a move whose mask contains the pan button is camera-owned and ignored entirely (spec routing table row 1), so 'primary released while middle is held' leaves the tool in its phase until the PointerUpEvent with buttons == 0 ends it; the plan said 'phase idle' after the middle-only move — because the spec's first row outranks the plan's test prose — costs: a band survives one extra move when a user chords middle over primary, which the look can judge
Task 9: implementer stalled 600s in an unrequested mutation sweep (work uncommitted, backup interaction_layer.orig.dart in the session scratchpad); resumed with: restore from backup, no sweep, gate, commit, report
Ruling P-4: implementer dispatches from here on say 'do not run a mutation sweep; Task 11 does it' — two implementers spent their longest stretch there and one stalled — costs nothing
Task 9: implementer resumed after the stall, then hit the account rate limit after committing dd60158 (trailer ok, tree clean, file matches the pre-mutation backup, report complete at 368 lines); review dispatched (531c91f..dd60158, reviewer opus)
Task 9: review round 0 — Needs fixes: the 'primary disappears on a move' row unpinned (the test-8 ruling retired its only test); MouseRegion.onExit unguarded so a band dragged past the layer edge is cancelled (plan-mandated wiring)
Task 9: Ruling: onExit calls the tool's onPointerExit only when no pointer is active; a band dragged past the edge continues (Flutter keeps delivering the captured pointer's moves and up), and the spec's SelectTool row 'exit while dragging → idle' is amended in Task 12 to 'exit with no active pointer clears hover' — because destroying a live gesture at the widget edge is a defect the look would report on day one — costs: a band can end outside the layer, which the up event handles
Task 9: Ruling: fix round 1 takes both Importants plus minors 3 (synthesised down requests focus) and 4 (assert the vertical drag's selection); minors 5-6 deferred
Task 9: minor (deferred): no didUpdateWidget for a swapped ToolController (nothing swaps it in 02); deactivate + dispose both release, so a GlobalKey reparent cancels a live drag
Task 9: fix round 1/5 dispatched
Task 9: fix round 1/5 fix commit dd60158..9722287; re-review sonnet dispatched
Task 9: minor (deferred): the synthesised-down branch is unreachable from a widget test (GestureBinding drops a move for a pointer with no recorded down); a state-object unit test would pin it
Task 9: fix round 1/5 (2 Important + 2 minors addressed, 0 open; commits dd60158..9722287)
Task 9: complete (commits 531c91f..9722287, review clean after round 1)
Task 10: dispatched (BASE 9722287, implementer sonnet)
Task 10: review dispatched (9722287..e6eb713, reviewer sonnet)
Task 10: minor (deferred): the tap test reuses test 1's probe without re-asserting the pick; _statusLine re-runs per notify (negligible)
Task 10: complete (commits 9722287..e6eb713, review clean)
Task 11: dispatched (BASE e6eb713, implementer sonnet, incremental log)
Task 11: DONE dd27af0 — 28 fired/28 killed/2 equivalent; tree clean, only the log in the diff, 30 entries, 28 restores; review dispatched (e6eb713..dd27af0, reviewer sonnet)
Task 11: review round 0 — Needs fixes: M-02b fired at _bandDescend's nested recursion, not at forEachInstanceInBand's root-level transformOfInstance the spec's fixture targets; the named fixture stayed green under the applied mutant (self-disclosed)
Task 11: fix round 1/5 dispatched
Task 11: fix round 1/5 fix commit dd27af0..afe7d64; re-review sonnet dispatched
Task 11: fix round 1/5 (1 addressed, 0 open — M-02b re-fired at the root composition; commits dd27af0..afe7d64)
Task 11: complete (commits e6eb713..afe7d64, review clean after round 1)
Task 12: dispatched (BASE afe7d64, implementer sonnet)
Task 12: DONE b02410a — gate 14 of 15, criterion 15 OWED; review dispatched (afe7d64..b02410a, sonnet) in parallel with the final whole-branch review (3fedeb9..b02410a, opus)
Task 12: review round 0 — Needs fixes: floor_planner test count stated 12 in results note and STATUS while the pasted line and the tree say 11; D9 Files-list cell rewritten (SelectionOverlay replaced) instead of appended, falsifying the 'none rewriting' claim
Task 12: Ruling: both findings join the final-review fix wave as one dispatch rather than a separate fix round — the final whole-branch review is running and two implementers must not share the worktree — costs: Task 12 closes with the wave, not before it
Final review (opus, 3fedeb9..b02410a): ready with fixes — Important: (1) filter asymmetry across the four container walks (tool group rule fails on a hidden/locked leaf; outline draws hidden leaves); (2) band world corner taken at press, spec says at release; (3) no undo affordance in the app while the look asks for undo; (4) no repaint source for a DocChange (latent in 02, blocking in 03). Minors 5-15; deferred triage: only 11a (worldPointOf doc) FIX BEFORE MERGE, rest MAY WAIT
Final: Ruling: the tool's every-rule skips leaves the picking filter rejects (matches _bandDescend); the outline skips leaves the rendering filter rejects; the delete cascade stays unfiltered (mirrors what RemoveNodeCommand would orphan) — recorded as the four-walks table in the results note — costs: a fifth walk in 03 must consult the table
Final: Ruling: band corners converted at release, spec D8's spelling — costs nothing
Final: Ruling: OutlineCache becomes a ChangeNotifier in the overlay's repaint merge, notifying after DocChange rebuilds — costs: one more listener per overlay
Final: Ruling: cmd/ctrl+Z undo bound in the shell (no redo) so the look's items 6-7 are performable — costs: a keybinding 12 will fold into its shell
Final: Ruling: minor 5 (root-level _kAllBox in window mode) stays, recorded as debt with the safe prefilter named for 03 — plan-mandated, pointer-up rate
Final: Ruling: minors 6 and 11a and 15 taken in the wave (one-liners, doc accuracy); minors 7-14 parked — documented deadlock, unspecified Escape-in-pressed, clear() drops hover (tested), painter built in build (shouldRepaint false), tool not disposed, brute-force arm mirrors the verdict algebra (header candid), duplications
Final fix wave dispatched (one implementer, opus; brief final-fix-brief.md; includes Task 12's two findings)
Final fix wave landed: 0d69465 (A1-A7) + 7cd3697 (B1-B8); gates: 820 / 769+1skip+5 goldens / 82 / 12 + both builds; scoped re-review dispatched (b02410a..7cd3697, opus)
Final re-review (opus, b02410a..7cd3697): all fifteen addressed, no new Critical/Important breakage
Final: parked — selection_overlay.dart:22 class doc still names a three-member merge — Ruling: real, documentation only, deferred; the spec amendment and all three call sites say four
Final: parked — STATUS.md 'Four rulings a reader must know' heading followed by 'added a fifth'; results note 'the six amendments above' where ten are listed — Ruling: real, wording only, deferred
Final: parked — criterion 5's witness cell cites the two undo tests but no longer the shift-toggle and Escape tests — Ruling: my B4 wording caused it; the coverage exists (select_tool_test 'click replaces, shift-click toggles', 'Escape during a band drops it'); deferred as a doc edit
Final: parked — the control+Z binding has no test (meta+Z is driven end to end) — Ruling: symmetric binding, two lines; deferred, the browser look exercises it
Final: parked — after A2 the outline omits hidden leaves that Delete still removes; the four-walks table records it — Ruling: consistent with the canvas, disclosed, 03 inherits the table
Plan 02: all 12 tasks complete; final review clean after one fix wave; head 7cd3697; exit gate 14 of 15, criterion 15 OWED to the human; ledger archived next
