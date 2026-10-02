# Plan 12b ledger — progress

Plan: docs/superpowers/plans/2026-10-01-layer-panel.md (9ee2e60).
Spec: docs/superpowers/specs/2026-10-01-layer-panel-design.md rev 3 (c8b55da), approved 2026-10-01 at 3b35ef2 ("onaylıyorum, devam et").
Worktree: /home/user/jet-cad/.claude/worktrees/plan-12b. Baseline main 7330c7b: engine 1121 + 2 standing; render 1154 + 1 skip + 7 standing; app 934.

## Tasks
| Task | Commit | Review |
|---|---|---|
| 1 header, target, schema 7 | a6cd4bb | Approved with notes (no defect; 17 mutants red; fingerprints macOS re-baseline owed -> results note + STATUS with the exact step; R-12b-3 real but narrow -> known limitation, not Task 2) |

- R-12b-1: the two generate_document fingerprints are macOS values (Ruling 07-7, trig differs on Linux); P-7's re-baseline cannot be computed here. Constants left, comments name the owed macOS re-baseline. Cost: the two tests now fail on macOS too until the human re-baselines them (a look-list item for the results note).
- R-12b-2: apps/floor_planner/assets/library/furniture.jetlib regenerated with tool/generate_furniture_library.dart (diff: version 6->7, header currentLayer only). Not in the plan. Cost: none.
- R-12b-3: open: a dangling stored currentLayer does not raise the handle seed on load; a later layer could get that handle and become current. Reviewer to rule.
| 2 layer commands + ObjectLayer | ab7a225 | Approved with notes (no product defect; R-12b-4 confirmed; R1-R4 survivors are test gaps -> 2b as Task 3's first commit; info: SetLayerCommand fires tables.changes twice with the record briefly missing) |

- R-12b-4: decision 7 read as 'refuse only a hide of the effective current layer' (a recolour/lock of an already-hidden effective current layer 0 is allowed, S-6 state). Reviewer to confirm. Cost if wrong: a dead end in a file-only state.
| 2b + 3 index | 582f78b (2b), f5998db, af87621 | Approved with notes (R-12b-5, R-12b-6 confirmed; minor: _reconcile skip misses an entity/node sharing a layer's handle (malformed file) -> guard; test gaps: nested-instance ATTRIB, lock substitution in acceptsNodeOnLayer -> 3b as Task 4's first commit) |

- R-12b-5: the allocation probe uses query_allocation_test's budgets, not literal zero (_descend already allocates per level; _Uint32List unobservable). Reviewer to confirm. 
- R-12b-6: the _ownerLayer memo relies on a node change rebuilding the index (SetInstanceLayerCommand -> rebuildAll). Reviewer to confirm it does and that cost is acceptable.
| 3b + 4 layer parameter | 540f9cf (3b), 4a735fb | Approved with notes (nothing to fix; M3b-4 unpinnable by answers, only by AddDefinition's rebuild contract -> recorded; info: index ignores a definition's base point, pre-existing, 09a placer applies it) |
| 5 stamp + detach | 04a14b3 | Approved with notes (no code defect; rollback injected and verified; minor: no test with a region's fill and boundary on different layers (R4 survives) -> 5b OL3b + the cascade-loss detach test; doc-comment order slip -> 5b; info: ObjectLayer on a nested group inert, left behind -> known limitation) |
| 5b + 6 selection/outline/oracle | 5b1c912 (5b), 0473696, 3a3286b | Approved with notes (R-12b-7 confirmed: oracle must match the painter below the root -> 6b; minor: outline does not gate a root instance key by its layer (key held without a DocChange); test gaps V3 (_addFill context) and V4 (missing layer treated hidden in oracle); doc on _addLeaf -> all 6b as Task 7's first commit) |

- R-12b-7: the brief (P-5) had the oracle skip hidden leaves/nested instances inside a definition, but spec D6 keeps the painter's definition walk unfiltered (residual). Ruling (controller): the spec wins; the oracle must match the painter below the root, i.e. drop the two skips below the root, and a test pins painter == oracle in that residual state. To be done as 6b unless the reviewer finds otherwise. Cost if wrong: none for the product (file-only state); the oracle would otherwise disagree with the painter there.
- R-12b-8: the render selection reads objectLayer for every group key (cannot tell parametric from plain); a plain group without ObjectLayer counts as layer 0. File-only. Recorded.
| 6b + 7 tools and frame | a4d85f0 (6b), 4c7eca3 | Approved with notes (no defect; all info: M-12e mutated in the engine's TableSection wiring accepted; the add-only bypass is equivalent for this test and killed by tables_revision_test -> results note) |
| 8 app tools and hosts | 27db262 | Approved with notes (no defect; R-12b-9 confirmed; test gaps R2 (attach with a dangling ObjectLayer and layer 0 hidden) and R3 (wall tool still joins a hidden wall) -> 8b as Task 9's first commit; open question for the human's look: the Wall tool snaps to a wall on a hidden layer) |

- R-12b-9: S-11 overlap reading: a wall that cannot host is skipped (the next wall in handle order hosts); the wall tool's band join stays unfiltered (decision 8). Reviewer to confirm.
| 8b + 9 LayerPanel | 1afcfdd (8b), 7e83eae | Approved with notes (minor defect: row callbacks copyWith a record captured at build, so a blur-rename then a same-frame lock tap reverts the name -> read the live record at dispatch; test gaps: full-record checks (O1, O2), delete vs drawingLayer (O3) -> 9b as Task 10's first commit; look list: 32 px rows below 48 px touch target, right column not scrollable as a whole; info: read-only delete tooltip) |

- Container restart during Task 10 (9b in progress): an uncommitted partial 9b edit to layer_panel.dart survived (the _update helper, read-only tooltip; reviewed by the controller: intentional work, not a mutant). The scratchpad survived (no l10 dir had been made). Task 10 relaunched.
| 9b + 10 LayerPicker | 8eef675 (9b), 5ef5673 | Approved with notes (no defect; test gaps: every parametric type in the picker (R-own-5), components vs transform (R-own-2), stored-value no-op rule (R-own-3) -> 10b; info: ATTRIB on its own non-zero layer (file-only) known limitation; _choose does not catch ArgumentError/StateError; runtime delete tooltip says Read-only; LayerRecord toString/reasons) |
| 10b + 11a e2e, results | c3ab7ca (10b), 1f2788a, 35af9b9 | Final review: Ready with fixes (minor defect: SetLayerCommand's user form checks the name even when unchanged, so a loaded invalid-named layer cannot be hidden/locked/recoloured and the panel throws; nits: the macOS fingerprint step order, 10b/11a reviewed only by the final review); 32 mutants re-fired on the tip, all red -> 11b |
| 11b final review fixes | 064965c, 93312dd | controller check: diff read (name check only on a rename; LayerPanel._execute catches ArgumentError/StateError); M11b-1 re-fired by the controller on layer_commands_test: `00:00 +42 -1: Some tests failed.`, restored diff=0, then `+43: All tests passed!` |
