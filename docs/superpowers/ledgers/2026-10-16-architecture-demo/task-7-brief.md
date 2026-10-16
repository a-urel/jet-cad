### Task 7: Symbols and layers through the app; the library gaps

**Files:**
- Create (port): `test/symbols/symbol_library_loader_test.dart` (only
  its PORT/SPLIT rows; the audit says 0 PORT, 1 SPLIT),
  `test/symbols/symbol_shell_test.dart` (SS1-SS15 rows),
  `test/symbols/symbol_palette_end_to_end_test.dart`,
  `test/symbols/symbol_section_end_to_end_test.dart`,
  `test/layers/layers_end_to_end_test.dart`
- Create: `packages/jet_cad_2d_integration/test/layers/layer_picker_types_test.dart`
  (the layer picker's SPLIT row: the six architecture types alone enable
  the picker and show their layer — the audit puts it in the integration
  package)
- Create: `test/library_gaps_test.dart` (decision 10)

**Interfaces:**
- Consumes: Task 4's rig.

- [ ] **Step 1: Port the symbol and layer files** per their audit
  sections, as in Task 4 step 5. SS7 splits per decision 7: SS7-open pins
  that after New `controller.armedSymbol` is still the armed furniture
  symbol (today's library behaviour); SS7 (intent) pins that the active
  tool is Select and the gallery shows no armed cell. Mutation for SS7:
  reset the active tool to the symbol tool after `newPlan` in a scratch
  edit of the host (the intent half reds).

- [ ] **Step 2: Library gaps** (decision 10), one case each, through the
  app (`pumpApp`), each with a mutation in the library code it pins (run,
  revert):
  - LG1 file buttons gated mid-shape: press with the wall tool, before
    release the Save button does nothing (nothing written) and Cmd+S does
    nothing. Mutation: drop `_idleFlag` from the file buttons' enabled.
  - LG2 the Meta variants: Meta+S, Meta+O, Meta+N, Meta+Shift+S, Meta+P run
    the same flows as their Control forms. Mutation: drop the meta half
    of `_chord`.
  - LG3 redo chords: Meta/Control+Shift+Z and Control+Y redo. Mutation:
    drop one.
  - LG4 tab and cell focus in the Symbols gallery: Tab moves from the
    search field to the first cell; switching tabs does not change the
    active tool. Mutation: the tab switch arms Select.
  - LG5 the gallery's search text survives a tab switch and a New.
    Mutation: the editor rebuilds the gallery with a fresh query on
    `newPlan`.
  - LG6 Export and Print follow the page: with the page detached (the page
    panel's off switch) they are disabled; undo makes them enabled; redo
    disabled. Mutation: the flags read once at build.

  If an LG case is red on today's library (not a mutation), stop: report
  it as DONE_WITH_CONCERNS with the failing output; the controller adds a
  library fix task (decision 10) before this task closes.

- [ ] **Step 3: Library-side gaps** in `packages/jet_cad_2d_plan/test`:
  `PrintingPagePrinter` hands `Printing.layoutPdf` the name and format
  (old PR8, through the `printing` package's platform mock if it has one;
  if none, record in the report that PR8 stays DROPPED with this reason
  and add it to the audit row), and Escape in `PlanExportDialog` pops
  null. Mutations as above.

- [ ] **Step 4:** Gates for the app, `jet_cad_2d_plan` and
  `jet_cad_2d_integration`. **Commit** `test(demo): symbols and layers through the app`, `test(demo,plan): the library gaps pinned`.

---

