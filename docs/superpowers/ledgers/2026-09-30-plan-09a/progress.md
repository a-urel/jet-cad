# Plan 09a ledger — progress

Plan: docs/superpowers/plans/2026-09-30-symbol-library-core.md (40157af).
Spec: docs/superpowers/specs/2026-09-30-symbol-library-design.md rev 3.
Worktree: /home/user/jet-cad/.claude/worktrees/plan-09. Flutter 3.47.2 installed
at /root/flutter this session (was absent; downloaded from storage.googleapis.com).
Baseline at 40157af: engine 1106 + 2 standing; render standing text-ladder failures
(count taken in the final sweep); app 596. `flutter pub get` modifies
packages/jet_cad/analysis_options.yaml: never commit it.

## Rulings
- (none yet) — each with cost-if-wrong.

## Tasks
| Task | Commit | Review |
|---|---|---|
| 1 engine definition commands | 477138f, 1b e96c9cc | Needs fixes (Remove capability and touched unpinned) -> 1b, re-review Approved (1b) |
| 2 SymbolComponent | 51a9bda | Approved; minor m-T2-1 (fromJson leniency per field unpinned: one expectation per omitted field, test-only) owed to a follow-up before the final review; m-T2-2 hashCode (legal, no action) |

## Rulings (running)
- R-T2-1: plan said ParametricSystem.regenerate; it does not exist; SC10 checks drift()/diagnostics() after an edit. Cost if wrong: none (test wording).
- R-T2-2: purge never touches components (P-6.1): RemoveDefinitionCommand does not clear the component, so the placer's undo must include SetComponentCommand<SymbolComponent>(h,null) (already in D6). Cost if wrong: a stale component on a removed definition's handle survives save.
- R-T2-3: CompoundCommand needs a named label.
| 3 SymbolLibrary loader | f9e4c33 (+ 2b 5b9237f test-only) | Approved; minor m-T3-1 (zero-sweep tolerance: add a case with a tiny non-zero sweep below Tolerance.standard.angular, test-only) owed before the final review |

- R-T3-1 (spec amendment owed at Task 7): D5 "non-finite bulge" is void: polylines here carry no scalars; replaced by "a polyline carries no scalars" + finite-scalar check. Cost if wrong: none.
- R-T3-2 (spec amendment owed): the codec silently repairs a definition cycle (drops the closing instance), so the loader refuses any codec diagnostic. Cost if wrong: a cyclic library would load "clean".
- R-T3-3: loader adds two rules beyond D5 from D3: keys lower-case, no white space; tags lower-case. Cost if wrong: a hand-edited mixed-case library is refused.
| 4 placer | 478c6dc | Approved; info i-T4-1 (a placement cannot mutate the library entry: GeometryStore copies on add; no separate test) to fold into the m-T3-1 follow-up as a cheap aliasing test |

- R-T4-1: reuse requires the definition to still exist (orphan SymbolComponent guard). Cost if wrong: none observable.
- R-T4-2 (spec gap, recorded): AddNodeCommand does not check the instance's definition exists; a wrongly ordered compound fails only on undo. Cost: placer order is pinned by tests P5/P9/P10.
- M-09w owed to 09b (placement tool).
| 5 content, generator, asset | 81a3271, a5e38a0 | Approved; minors m-T5-1 (outline closedness unpinned: every rectangle polyline open stays green) and m-T5-2 (per-symbol category unpinned: bed.single -> Kitchen stays green) owed in the final test-only follow-up; info: rootBundle load is 09b |

- R-T5-1: the spec's D7 list adds up to 25 symbols (not "about 24"): 5 Dining, 5 Kitchen, 4 Bed, 4 Living, 4 Bath, 3 Office. Cost: none.
- R-T5-2: library document = DraftDocument.empty + registerAppComponents + mm (no DASHED record). Leaf style: layer 0, BYBLOCK linetype, ByBlockColor, kByBlock lineweight/transparency. Task 6 must confirm the BYBLOCK lineweight resolves sensibly end to end. Cost if wrong: thumbnails/placements draw hairlines.
| 6 end to end (+ Part B: m-T3-1, i-T4-1) | ba812dd, 22bc83d | Approved; info: e2e fixed at quarter turn 1 mirrored, other turns covered by P1-P4 |

- R-T6-1: NO engine/render defect found by the first combined transform+style+paint+pick+snap test (F-7 closed). Select-tool move and rotate grips work on a placed mirrored InstanceNode (P-6.2): nothing for 09b. BYBLOCK lineweight under a default instance resolves to 25 / ACI 7 (R-T5-2 confirmed). Grip/outline caches follow the change stream asynchronously (tests need a Future.delayed(Duration.zero)).
| 6c test-only follow-up (m-T5-1, m-T5-2) | 971eb76 | folded into the final whole-branch review (test-only) |

- P-8 (controller ruling, Task 7): the plan's "re-run every mutant of Tasks 1-6 in the final tree" is replaced by: the results note compiles each task's mutant matrix from its report and its independent review (both fired real runs at the task commit), and the final whole-branch review re-fires a sample across every task. Reason: after Task 5 no lib/ file changed (Tasks 6, 6b, 6c are test-only; git diff a5e38a0..HEAD -- apps/floor_planner/lib packages is empty), so the task-time results still describe the final tree. Cost if wrong: a mutant that went green only because of a later test edit; the final review's sample and the diff check bound it.
| 7 results, spec amendments, roadmap | bdca1ed, 27770dc (final review applied) | covered by the final whole-branch review |
| final whole-branch review | tip bdca1ed | Ready with fixes (0 blocking, 0 important; 3 minor, 3 nit: header, line refs, dining tables draw no chairs, radius bound, ledger link, contrast): applied in 27770dc except the catalog/radius items, recorded as found-not-fixed. P-8 sample: 20 mutants, all red. |

## Closing
Branch plan-09/symbol-library-core: tasks 1,1b,2,2b,3,4,5,6,6b,6c,7 + final review fixes; the archive of this ledger is the branch's last commit. Merge is the human's word. 09b (palette, search, gallery, thumbnails, placement tool) is unwritten. The spec's two independent reviews were conversational (their findings are the spec's Revision 2 and Revision 3 sections).

## Post-final-review change requested by the human (2026-10-01)
The human decided: dining tables WITH CHAIRS: square 2-seat, square 4-seat, rectangular 4-seat, rectangular 6-seat (replaces dining.table.four / dining.table.six). Approved the merge ("2. onaylıyorum") in the same message; the merge follows this change's independent review.
- R-T8-1: the old keys were never shipped (version 1 stays); the four tables replace the two. Symbol count 25 -> 27 (Dining Room 5 -> 7). Cost if wrong: none (nothing consumed the old keys).

| 8 dining tables with chairs (the human's decision) | 10770f8 | Approved by the final reviewer (follow-up section of final-review.md); minors applied in 8b |
| 8b doc fixes + base-point-is-table-centre test | 2d12067 | covered by the follow-up review's own findings; the author's gates re-run by the controller: app 790, analyze/format clean, web built |
