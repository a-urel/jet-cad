# Review T7 (symbols, layers, library gaps)

Verdicts: 1. Spec compliance: PASS. 2. Quality: PASS with Minor findings.
Counts: Critical 0, Important 0, Minor 5.

## Checks run
- Covering tests opened at the cited lines (all exist and match): furniture_library_test:68, plan_symbol_loader_test:110, symbols_controller_test:109/:148, lifetimes_test:23 (C-life1 asserts activeTool == plan.select after a swap), plan_symbol_tool_test:406, plan_symbol_gallery_test:289/:426, layer_picker_test:423 (all-types), layer_page_controller_test:319 (LP-7), failure_flow_test:364 (F-9), plan_shortcuts_test:255 (KB-4).
- SPLIT rows SL9b, SS7, SS8, SS13, SS14, picker all-types: -open halves present; DROPPED SL9c, SL12, SS15: none ported, as audited. SS7 split per decision 7 (SS7-open pins armedSymbol survives newPlan; SS7 pins Select + no armed cell on both tabs). LG1-LG6 present, each with a library mutation.
- Mutations I ran (reverted with git checkout --, git diff --quiet exit 0 each time):
  1. chords.dart: delete the Ctrl+Y redo chord -> library_gaps_test LG3 red (`+15 -1`).
  2. plan_editor.dart:367: `_printFlag` computed once at bind -> LG6 red (`+15 -1`).
- Gates, real last lines: `flutter test` -> `00:32 +171: All tests passed!`; `flutter analyze` -> `No issues found! (ran in 3.8s)`. Worktree clean after.

## Decided differences
- LG4 (Tab landing on the canvas): premise is WRONG in the brief, not a library parity defect. The old app had the same behaviour: packages/jet_cad_floor_plan/lib/src/symbols/symbol_panel.dart:314, :368, :398 wrap the cells in ExcludeFocus (Ruling 05-6); specs 2026-09-30-symbol-library-design.md:337 and 2026-10-01-symbol-palette-design.md:206 say "a cell never takes focus"; the old symbol_shell_test.dart has no Tab-to-cell expectation (SS6 pins that cells/strip take no focus; the only Tab in old tests is document_settle_test.dart:357, a page-scale field). The new LG4 pins the old behaviour (SS6 plus the focus walk). No fix task.
- LG6 page detach: the page panel has no off switch; the document command is the same route as EX9b. Premise really gone; port is not weaker.
- WE3 oracle: the exact attachToWall comparison cannot be made (resolver internal). expectFlush (symbol_rig.dart:268) is strict (1e-9 tolerance, back edge on face, span equals width, orientation to 1e-12) and checks one undo step, the ~700 mm slide and turn to wall B. Acceptable; exact resolver output stays with MV4. See Minor 1.
- Palette e2e snap oracle: line end as oracle with three premise guards (raw > 50 mm away, grid alone > 10 mm away, press > 1000 mm away). Equivalent strength to the old resolveDragPoint oracle; independent of the code under test. OK.
- Palette cell image: see Minor 2.

## Weakening comparison (old vs ported, 7 cases)
SS2 (adds nothing lost), SS6 (same), SS8 (same), SS12 (same, plus clear button), WE3, palette e2e, SS7/SS13/SS14 (below). No assertion removed without a premise reason except the Minor items.

## Minor
1. apps/architecture_demo/test/symbols/symbol_section_end_to_end_test.dart ~:150: the drop onto wall B checks flushness and turn, not the position along B (old compared the transform byte for byte). A resolver that landed the bed anywhere flush on B's face would pass. Fix (optional): assert the back-centre's along-wall coordinate on B equals the drop point's projection within the page grid step.
2. symbol_palette_end_to_end_test.dart ~:112: cell image check is `RawImage.image != null && width > 0`; old test proved the image was a clone of the cache's. A cell fed by a different cache, or the wrong symbol's picture, passes. `c.thumbnails` is public, so a stronger port could render the same key from `c.thumbnails` and compare with isCloneOf if the gallery key is reachable; otherwise note the lost oracle in the audit row.
3. symbol_shell_test.dart SS7: the old `panel.tool.ghostVisible` isFalse and old-tool-disposed checks are dropped. The tool is long-lived now so disposal is moot, but a ghost left visible after New is a real intent; consider asserting the canvas shows no ghost.
4. symbol_shell_test.dart SS14-open: old `everyElement(startsWith('sofa.'))` became `contains('sofa')`; ids are now `architecture.<name>@n`, so `contains('.sofa')`-style anchoring would keep the strength. SS13-open also dropped `before.commands.isDisposed` (old document disposed on replace).
5. task-7-report.md mutation table, M-LG2 row has a duplicated phrase ("8 red in library_gaps_test.dart alone" twice); and M-L2 equivalent mutant is genuine: the app's `_symbols` loader is unused by the controller (controller makes its own). Controller's call whether to delete the field in a later task.
