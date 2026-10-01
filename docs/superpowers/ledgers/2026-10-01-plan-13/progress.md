# Plan 13 ledger — progress

Plan: docs/superpowers/plans/2026-10-01-export-and-print.md (7fab442).
Spec: docs/superpowers/specs/2026-10-01-export-and-print-design.md rev 3 (5b81c1c), approved 2026-10-01 at 7c3847b ("onaylıyorum, planı yaz").
Worktree: /home/user/jet-cad/.claude/worktrees/plan-13. Baseline main a0a1920: engine 1121 + 2 standing; render 1001 + 1 skip + 7 standing; app 885.

## Rulings (each with cost-if-wrong)

## Tasks
| Task | Commit | Review |
|---|---|---|
| 1 page camera + fixture | c96bb9b | Approved with notes (minor: outside line inside the sheet at 1:100 -> fixed first in Task 2 as a separate commit) |

- R-13-1: the fixture's basePoint is stored but never read by the renderer (09a finding: the placer applies it). Not an export concern; no mutant claimed for it. Cost if wrong: none.
- R-13-2: the spec's Architecture table lists test/support/pdf_content.dart; plan P-2 (lib/src/export/testing/) wins. Amend the spec at Task 11. Cost: none.
- R-13-3: the fixture's separator keeps the real separator's style (ByLayer, DASHED, 35), a deliberate exception to "no default style". Cost if wrong: none (T-8 tests presence, not style).
| 2 omitOwners | 749e8b1 (1b fixture), 32d488f (painter fix, unplanned), 257876e, 64bb01c | Approved with notes (bug real, fix correct, no allocation; low: debugOnVisit-before-skip in containers and attrib-leaf walk mutants survive, stale comment in differential.dart:137 -> 2b as Task 3's first commit; perf: grouped root instance does a linear lookup per frame -> found-not-fixed) |

- R-13-4: unplanned screen-painter fix 32d488f: a root-level instance whose parent is a group was drawn without the group's transform (groups fold into the root index; the painter used the instance's own transform). Needed for T-2 (the outer group's instance). Kept pending review; reported to the human. Cost if wrong: an instance in a group moves on screen.
- R-13-5: the painter-vs-walk comparison is test/support/differential.dart (sink_comparison.dart compares backends by pixels); spec and plan named the wrong file. Amend at Task 11. Cost: none.
- R-13-6: T-2 records the painter with RecordingDrawSink(shadesDashes: true) (the walk does not cut dashes); the painter's dash cutting is not covered by T-2 (it is by existing tests). Cost: none.
| 3 PdfDrawSink geometry + reader | ff0d853 (2b), babfcc1 | Needs fixes, test-only (no path under a rotated/mirrored cm: transposed residual in sink and in reader both survive; tolerance loose; odd hex) -> 3b d61d567, re-review Approved. Code correct; 3.44 bound confirmed; CanvasDrawSink unmatched save latent, not a screen defect today (found-not-fixed) |

- R-13-7: pdf 3.13 needs Dart 3.12, first shipped in Flutter 3.44.0: the render package's flutter bound is >=3.44.0 (spec R-4 said 3.41). Task 10 raises the app to >=3.44.0. The human's macOS Flutter must be >= 3.44. Cost if wrong: the human cannot build until upgrading.
- R-13-8: M-13ad, M-13y, M-13k are killed by T-3b (direct calls) only; the painter never produces those cases through the fixture. Amend the spec's mutant table at Task 11. Cost: none.
- R-13-9: an empty page has no /Contents; Task 5 must not expect the set-up on an empty page.
- R-13-10: reported: CanvasDrawSink may leave a save without restore outside a transform (screen); not changed here; reviewer to confirm; found-not-fixed candidate.
| 4 PdfDrawSink text | 94653f6 | Approved with notes (medium for Task 5: w_flutter from document.textMeasurer; low: OWN-style and reader FontFile2-not-stream survive, utf16 drops trailing digits -> 4b as Task 5's first commit; package writes malformed /ToUnicode for astral code points -> results note; no /ObjStm in pdf 3.13.1 output: reader fine for Tasks 9-10) |

- R-13-11: the painter lays text out with document.textMeasurer; the sink's w_flutter must come from the same measurement. Task 5 must make the sink's width source agree with document.textMeasurer (reviewer to advise). Cost if wrong: Tz stretches text to a width the box was not laid out with.
- R-13-12: the font is embedded lazily on the first text op (a page without text embeds none). Accepted.
- R-13-13: whether compress:true output uses object streams (reader's sequential scan) is unchecked: Task 9 must check before relying on the reader for app flows.
- R-13-14: PdfDrawSink.measurer typed as the TextMeasurer interface; exportPagePdf passes document.textMeasurer (the painter's own box measurement); the plan's 'own FlutterTextMeasurer cleared in finally' is dropped for the PDF path (spec D4 does not require it; D5's PNG keeps its own). Cost if wrong: none; Tz then matches the box by construction.
| 5 exportPagePdf | d3063ab (4b), c134c14, 72827ed | Needs fixes: HIGH an export's SpatialIndex takes and then nulls the dispatcher's single mutation hooks, unhooking the app's screen index (demonstrated) -> 5b 8fe438b (save/restore both hooks around a synchronous body; no detached-index option in the engine), re-review Approved; low A3 portrait test added |

- R-13-15: M-13x uses SetComponentCommand<PageComponent> (no AttachComponentCommand exists). M-13c fired in two forms (raw camera-scale product: red at both scales; normalised at 1:50: red at 1:100 only). Cost: none.
- R-13-16: the package drops a content stream that holds only set-up/state operators (extends R-13-9).
- R-13-17: exports save and restore the dispatcher's two mutation hooks around a synchronous paint body (_withExportIndex). Spec D4 and I-3 to name the hooks at Task 11; T-10 (Task 9) makes an edit after an export in the shell. Cost if wrong: the screen index goes deaf after an export.
| 6 exportPagePng | ca163b9 | Approved with notes (independent PNG decode: all CRCs valid, one pHYs; low: stroke width pinned only from above; info: existing-pHYs branch untested -> 6b d538aa2, re-review Approved; R-13-19 and measurer.clear() survivor accepted) |

- R-13-18: M-13p on the PNG is red at 150 dpi only ("WC" cap 2.95 px; 5.9 px at 300 dpi is above the cull). Amend T-7 at Task 11. Cost: none.
- R-13-19: the PNG measures text with its own FlutterTextMeasurer while the painter lays out with document.textMeasurer; identical in the app (the canvas requires a FlutterTextMeasurer), off only for non-Flutter measurers, which cannot reach the app's export. Accepted, recorded for the results note.
- Render layer FROZEN at d538aa2.
| 7 font | f625d80 | Approved with notes (licence verified: cmp 0, sha256 matches, licence shipped in web build and registered; low: H (registration call in main) survives -> a main.dart source test owed at Task 11 sweep; info: web already fetched Roboto from fonts.gstatic.com when the manifest had none, so the web look changes little) |

- R-13-20: the export font cache (ExportFontCache) is created by FloorPlannerApp and passed to DocumentHost.exportFont (nullable; a bare host has none). Task 9 decides the fallback. The registerFontLicences() call in main() is checked by review only (no test runs main()). Cost: none.
| 8 FileKind | f181afc | Approved with notes (jetplan naming unchanged on 24 inputs; minor: io/web files' use of kind unpinned (3 survivors) -> document_files_sources_test.dart owed at Task 11 sweep (reviewer's prototype in scratchpad/r8); info: the macOS panel appending .pdf/.png is Apple behaviour, add to the human's look) |

- R-13-21: the io side adds no extension (the panel does; the sandbox allows only the returned path): the io per-kind rule is the type group only (saveTypeGroupsFor). Extension matching stays case-sensitive (plan.PDF -> plan.PDF.pdf), as jetplanFileName always was. The io/web files' own calls are checked by analyze, the web build and review only. Cost if wrong: a web PDF download named plan.PDF.pdf.
- R-13-22: spec F-11 and R-7 are wrong for the web (the web engine fetched Roboto from Google when none was bundled); amend at Task 11; L-1 on web expects nearly identical text, and no start-up fetch of a font from Google now. Cost: none.
| 9 Export… | 1e26b85, 91b13ee | Approved with notes (medium: settle-before-export untested (an open text entry would be lost); low: enabled flag across undo/redo of a page, busy over the dialog untested -> 9b 7f81838 (on top of Task 10), re-review Approved) |

- R-13-23: Task 9 changed 12a's DC12c (the narrowest top bar without overflow): floor 576 -> 616 px for the Export button; Task 10's Print moves it to 656. A layout consequence of two new toolbar buttons. Cost if wrong: the top bar overflows on a narrow window (L-look).
| 10 Print… | 6a726a9, 3057e13 | Approved with notes (exactly 2 new packages, Apache-2.0; no CDN fetch on web print; medium: Print's settle untested; low: busy over a successful print unpinned, fake's stale 'hold' comment -> 10b ff85f02, re-review Approved; info: web print ignores name/format, MediaBox governs) |

- R-13-24: the app depends on pdf directly (PdfPageFormat; printing does not re-export it). DC12c floor 656 px; DC12b's status line slot shrank (room notice cut ~40 px sooner; test name shortened). New packages: printing 5.15.1, pdf_widget_wrapper 1.0.4, both Apache-2.0. E2 (export twice, print once) recorded equivalent (pure export, no seam). Cost: none.
| 11a end to end, sweep, results, spec amendment | 2153621, 4ede95c, 76559cc | final whole-branch review: Ready with fixes (docs only: note's 10b verdict and review record, spec R-13-20 bullet, M-13q on T-8; stale main.dart comment recorded found-not-fixed) -> applied by the orchestrator |
- R-13-25: EF11 (4ede95c) supersedes R-13-20's 'registration checked by review only'.
