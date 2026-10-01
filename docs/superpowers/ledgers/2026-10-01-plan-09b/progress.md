# Plan 09b ledger — progress

Plan: docs/superpowers/plans/2026-10-01-symbol-palette.md (eb50a53).
Spec: docs/superpowers/specs/2026-10-01-symbol-palette-design.md rev 3 (121d944), approved 2026-10-01 ("onaylıyorum, planı yaz").
Worktree: /home/user/jet-cad/.claude/worktrees/plan-09b. Baseline main 75dc2e0: engine 1121 + 2 standing; render 974 + 1 skip + 7 standing; app 790.

## Rulings (each with cost-if-wrong)

## Tasks
| Task | Commit | Review |
|---|---|---|
| 1 search | d4e85f6 | Needs fixes (substring, key, case-sensitive-tag mutants survive: test-only) -> 1b 7bed823, re-review Approved |
| 2 loader + wiring | 674f717 | Approved; minor m-T2-1 (SL11: the app-made loader reaching ready over rootBundle unasserted; add one expect) + doc sentence on the late final loader, owed in a later test-only follow-up |
| 3 thumbnails (render) | 359a70a | Needs fixes (padding untested: two mutants survive; sink DPR untested: sub-pixel path never runs) -> 3b 3faabd4, re-review Approved (note: hairline fixture not in the non-degeneracy guard loop; fold into a later touch) |

- R-B3-1: the FloorPlannerApp `thumbnails` parameter (plan Task 2 says "Task 3 adds it", Task 3 is render-only) moves to Task 9, which owns the app wiring. Cost if wrong: none.
- R-B3-2: an evicted pending image is disposed one microtask after completion; holders must clone in their completion callback (Task 4's cells). Cost if wrong: a cell shows a disposed image (caught by Task 4's clone tests).
| 4 gallery (render) | 1951d01 | Needs fixes (imageFor per rebuild and clone-after-await mutants survive: test-only) -> 4b 8a44a5c, re-review Approved; material.dart import accepted; clone race accepted as known limit |

- R-B4-1: the render package's lib imports package:flutter/material.dart for the first time (spec D4: Material, InkWell, Tooltip; Tooltip needs an Overlay). Cost if wrong: a later decoupling. Reviewer to judge.
- R-B4-2 (known limit): a cache hit on a finished entry delivers the image one microtask later; an eviction in between makes clone() throw; the cell shows an empty cell, no retry. Unreachable with 64 entries and 27 symbols. Cost if wrong: one blank cell until rebuild.
- R-B4-3: M-09b12's red test is 'the cell cannot take focus when asked' (a tap never focuses an InkWell, so the tap test alone is not discriminating).
| 5 ghost | 637a429 | Needs fixes (close() and per-component base-point change unpinned: test-only) -> 5b c975d1d, re-review Approved |

- R-B5-1: GhostMatrix.update also recomputes P when the base point changes (re-arming another symbol). Accepted. Cost if wrong: none.
- R-B5-2: the plan's name ghostPathFor is kept (spec says ghostPath). Cost: none.
| 6 tool: pointer, snap, ghost | df916b7 | Needs fixes (F3 object-snap toggle and zoom-adaptive grid unpinned: test-only) -> 6b 76e5f8b, re-review Approved; R-B6-1..3 accepted; note: the cross allocates 4 Offsets per paint (constant, within the rule) |

- R-B6-1: no 'cancelled' flag: a primary move with no live press is ignored and an up with no live press places nothing (covers pointer cancel, cancel(), Task 7's Esc). Cost if wrong: a stray up after a cancel could place (tested).
- R-B6-2: re-arming keeps the current turns and mirror. Spec silent. Task 7 keeps it unless a reason appears. Cost if wrong: a re-armed symbol starts turned.
- R-B6-3: the ghost does not follow a wheel zoom until the next pointer event (no camera listener; drawing tools only listen mid-shape). Known limit.
- Rotated+mirrored tool fixtures are Task 7's (the keys live there).
| 7 tool keys + permissions | 67688a1 | Approved (R-B7-1 accepted; Ctrl+R swallowed mid-press: mid-press rule wins) |

- R-B7-1: key-ups always pass through (incl. R/M's); Esc mid-press = cancel(ctx) (ends the press as R-B6-1 and hides the ghost until the next hover); Shift+M toggles the mirror (spec excludes only Ctrl/Meta/Alt); Ctrl+R/Ctrl+M pass through armed-idle, swallowed mid-press. Cost if wrong: small key-handling surprises; reviewer to judge.
| 8 Symbols tab | af704cf | Needs fixes (three ExcludeFocus wrappers unguarded: test-only) -> 8b 7693621 (+ 2b ebfd8bf, 3c 5566da3), re-review Approved (nit: a misplaced doc comment above canTakeFocus, symbol_panel_test.dart:195-196); R-B8-1..3 accepted; note: panel rebuilds per hover via ToolController (like the palette; no thumbnail requests per 4b) |

- R-B8-1: SymbolPanel takes an optional measurer (default InsertionPointMeasurer) for the thumbnail's prepareDocument; symbols hold no text. Cost: none.
- R-B8-2: permissions as a DraftPermissions value; needs = kSymbolPlacementNeeds {structure, geometry, components}.
- R-B8-3: onSelect returns the SymbolEntry (looked up from the gallery id); symbolIdOf and symbolThumbnailDocument are top-level.
- Note: a widget test's sendKeyEvent inserts no text: the r/w/m test proves no shortcut fires; filtering is proven by enterText.
| 9 shell tabs + wiring | 7d3bff7 | Approved (R-B9-1..4 accepted; R-B9-2 flagged for the human's look) |

- R-B9-1: a shell with a loader but no cache makes and disposes its own cache (only a bare shell hits it; the app always passes one).
- R-B9-2: switching to Tools removes the Symbols panel, so the search text clears on every tab switch (spec silent). User-visible: flagged for the human's look. Cost if wrong: retype a query.
- R-B9-3: the document measurer is not passed to SymbolPanel (the cache outlives the shell; symbols hold no text).
- R-B9-4: with geometry denied a cell tap sets armed but _activate refuses; the gallery is disabled then anyway.
| 10a end to end | c8f7a21 | covered by the final whole-branch review |

- R-B10-1: M-09b1's one-line form (up without _resolve) is equivalent at the end-to-end level (the tool follows every pressed move, the up arrives where the last move was); Task 6's tool-level test is its red test. The two-line form is red end to end.
- Observation: the shell has no guard of its own against tool letters mid-press; today the tool swallows every mid-press key except F/F3, so unreachable.
| 10b results, amendments, roadmap | 47ccd78 | covered by the final review |
| final whole-branch review | tip 47ccd78 | Ready with fixes (0 blocking, 0 important; 1 minor: the spec's status line; 3 nits): applied in 688c84a. Sample: 17 non-equivalent mutants red, the recorded equivalent green as recorded; cross-task hunts passed. |

## Closing
Branch plan-09b/symbol-palette: tasks 1-10 with follow-ups 1b, 3b, 4b, 5b, 6b, 8b (+2b, 3c), the final review's fixes; the archive of this ledger is the branch's last commit. Merge and the look are the human's.
