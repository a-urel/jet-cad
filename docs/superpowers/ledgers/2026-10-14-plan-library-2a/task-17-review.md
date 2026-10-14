# Task 17 review: PlanPropertyPanel (9a76ce37..9658faf4)

### Spec Compliance

- ✅ Spec compliant. Every file the brief lists has its hunk: the 5 lib files, the barrel export (`jet_cad_2d_plan.dart:+39`, `show PlanPropertyPanel` only, the layer slot stays internal), `test/support/panel_kits.dart`, the new `property_panel_test.dart` and the 4 ported test files. Nothing under the old packages, `jet_cad_2d`, `jet_cad_2d_flutter` or any `analysis_options.yaml` changed (diff stat: 12 files, all under `packages/jet_cad_2d_plan`).
  - `plan_property_panel.dart` is the brief's Step 8 code. Checked by extracting brief lines 991-1832 and running `diff -w` against `git show 9658faf4:…/plan_property_panel.dart`. The only differences are 6 `dart format` re-wraps.
  - `symbol_section.dart` is the brief's Step 6 port. Checked with `diff -w` against `floor_plan/lib/src/symbols/symbol_section.dart`: exactly adaptations 1-8. `_isOrthonormal` is `wall_attach.dart:402-407` unchanged. The changed `familyMembers` and the appended `symbolEntriesOf`, `shownRotation` and `degreesShown` match the brief.
  - The `ColourRow` widget is `color_picker.dart:88-187` with the listed renames. Checked with `diff -w`. `_choose` matches the brief and goes through `controller.execute`.
  - `BoxType`, `_corners` and `_insideInterval` in `panel_kits.dart` are `box.dart:35-124` unchanged. The `diff -w` differs only in order.
  - P3 rules, each checked in the code:
    - read/write/apply go through `commitField` (one `SetComponentCommand<T>`, `plan_type.dart:129-143`).
    - Every panel commit goes through `c.execute` (R-b). There is no `document.commands.execute` in lib.
    - Pin on focus gain, commit on focus loss and on Enter, then hand back.
    - Out-of-range input reverts (SE4 `'0'`, `'-3'`; P-1 maxLength).
    - Numbers use `formatPanelNumber`/`parsePanelNumber` with the language's strings (R-i).
    - ValueDisplay units: `_valueText`.
    - Titles come from `titleWordOf`. Settings words are `property:<tool id>.<id>` (Task 4 `fieldsOf(toolId:)`).
    - The escape hatch sits behind `KitSectionBoundary`.
    - The colour row covers every selected unlocked target as one compound command. It is gated by `recolor` and hidden while a tool's settings show.
  - P4: a locked object shows no section and is filtered out of `colourTargets`. P-lock-recolour shows that `execute` refuses the locked object and sets `lockHint`.
  - R-f: `PanelFieldFocusNode` is imported from `panel_focus.dart`, not created again.
  - R-g: only the `@internal` slot `propertyPanelLayerField`, left null.
  - Carried mirror rule: the button is behind `if (p.mirror)` (P-mirror).
  - Review Focus 3 is covered by P-two-types and Review Focus 4 by P-swap-pending.
  - `PlanLocaleScope.push` is called in `didChangeDependencies` and `didUpdateWidget`.
- Named risk, Review Focus 4 (settle before every swap). I checked `plan_controller.dart`: `settlePendingInput()` runs at the top of `load` (:403), `newPlan` (:431) and the other swap and save paths (:383, :394, :704, :731, :840).
- ⚠️ Cannot verify from diff:
  - The implementer's mutation red lines (the table in the report). The checkout is read-only for this review and nothing was re-run.
  - Whether Task 11's throwing kit, or a later task, exercises a property `read`, `title`, `enabled` or colour hook throwing through the panel. See Minor 3.

### Strengths

- The implementer caught a survivor in the brief's own test. M-P-5a survived P-5 as briefed, because the canvas tap's `onTapOutside` commits the field before the tool accepts. The fix (9658faf4) asserts `c.toolSettings.valueOf('disc.draw') == DiscToolSettings(radius: 250)` right after the keystrokes. That strengthens the test without weakening anything.
- The carried items got real tests with their own mutations:
  - P-lock-recolour: a locked box next to a free one; the row recolours the free one only, in one step. `execute` on the locked one answers false and sets `lockHint`. Pinned by M-P-6b and M-P-lock-exec.
  - P-mirror is pinned by M-P-mirror.
- Ported assertions are intact. I diffed the assertion lines of CP3-CP6 and of the symbol section tests against the originals, and compared every hunk of `selection_panel_test.dart`. Only the subject names change (`roomOf`→`boxOf`, `.key`→`.symbol.key`) and the halves the brief authorised are dropped (separator, `layer-picker`, table halves, SS9).
- Fixtures sit away from the defaults:
  - The boxes are off the origin, A is turned 0.61 rad, and the boxes carry non-default label, count and finish values.
  - The P-1 angle is π/6 (turn) inside a turned group.
  - The colour hues under test are teal and purple, not the palette's first.
- Fixture deviations are disclosed with reasons and evidence: grid snap in `pumpBoxPanel`, `test.corner.seat`, K2 rule 9's `familyEntries`, CP1's second pump, the fresh `GlobalKey` per rig.

### Issues

#### Critical (Must Fix)

None.

#### Important (Should Fix)

1. **SW5 cannot go red under the mutation its title names (M-09c-bf). The `isServableInstance` guard in the Size menu is unpinned.**
   - Where: `test/panels/symbol_section_test.dart`, SW5 at port lines 525-543; `plan_property_panel.dart` `_symbolSection`, the line `members = entry == null || isServableInstance(doc, h) ? const <SymbolEntry>[] : familyMembers(entries, entry)`.
   - Why it cannot fail: K2's rule 9 refuses a unit inside a size family. So the library the controller actually loads gives `test.bed.table` no family, and the tables lost theirs too (`family: 'test-tables'` was dropped). In the panel, `entryOfInstance(symbolEntriesOf(c.symbols), …)` therefore returns an entry with `family == null`, and `familyMembers` is empty whether or not the guard exists.
   - The premise is checked on a different list. The assertion `familyMembers(familyEntries, entry('test.bed.table')), hasLength(3)` reads the hand-built `familyEntries`, not the entries the panel reads.
   - By reading the code, both halves of SW5 (`test.table.a` and `bedTable`) stay green with the guard deleted. This was not run, because the checkout is read-only. The implementer flagged it (concern 3) and left it.
   - This is the degenerate-fixture failure CLAUDE.md names: a test whose named mutation cannot turn it red.
   - Fix, either of:
     - Extract the decision into `symbol_section.dart` (for example `List<SymbolEntry> sizeMenuMembers(List<SymbolEntry> entries, DraftDocument doc, Handle h)`), call it from `_symbolSection`, and pin it with a model test over `familyEntries` (an instance of `test.bed.table` gets no members). Then run M-09c-bf against that test.
    - Or record in SW5 that rule 9 makes the guard unreachable through a loaded library, and remove the M-09c-bf claim from its title.

#### Minor (Nice to Have)

1. **(plan-mandated) The last block of P-swap-pending cannot fail on its own.**
   - Where: `property_panel_test.dart` port lines 291-297.
   - With `registerSettle` in place, the field has already lost focus before the swap, and `_commit` has set `pinned = null` (`plan_property_panel.dart`, `_commit`'s last lines). So deleting `_forgetTargets()` from `_onController` and `build` leaves it green (by reading, not run).
   - Fix: add a case that swaps without a settle, or name the block a positive control.
2. **(plan-mandated) `_guarded` cannot tell a spec refusal from a kit hook's own `ArgumentError` or `StateError`.**
   - Where: `plan_property_panel.dart`, `_guarded`'s `on ArgumentError` and `on StateError`.
   - `properties.dart:347-360` calls the kit's `change` (its `write`/`apply`) inside the same closure as the `enabled` check. So a kit `write` that throws `StateError('…')` or `ArgumentError` reverts silently, with no `hookFailed` diagnostic. The brief says anything a kit's `write`/`apply` throws besides the spec's refusals is reported.
   - The field reverts either way; only the diagnostic is lost.
3. **(spec question for the controller) The kit hooks that run while the panel builds or acts are unguarded.**
   - These are: spec `read` and `enabled` (via `fieldsOf` in `_bound`), `title` (via `titleWordOf` in `_objectSection`), the colour `read` (via `pickedColours` in `ColourRow.build`), and the colour `write` (via `recolourCommand` in `ColourRow._choose`, outside `execute`).
   - Effect: one throwing hook takes down the panel's build, or raises out of a tap handler.
   - The spec says "Every kit hook is called at the contract's boundary" (`…design-mode-design.md:562`). Its outcome table (:567-580) names only write/apply and the section builder for panel hooks.
4. **A NumberProperty value that rounds back to the stored value still records a no-op undo step.**
   - Example: stored 2.3, the user types 2.31. The text differs from the shown `'2.3'` and the parsed 2.31 differs from 2.3, so `commitField` emits a `SetComponentCommand` holding 2.3.
   - `SetComponentCommand` has no equal-value skip (`commands.dart` ~645), so an empty step is recorded. Angles finer than 1e-6° behave the same way.
   - P3: "a parsed value equal to the stored one" commits nothing.
   - Fix: in `_write`, compare the result of `field.commit!(input)` with the current component before executing.
5. **Some ported titles and comments describe halves that were dropped.**
   - Titles: SW1 ("a table shows the Symbol and the Table sections"), SW4 ("a table does neither"), SW5 ("its family all tables").
   - Comment: `hover_removal_test.dart` still says "under pumpDraw's rotated, zoomed camera".
6. **P-lock-recolour's title names only M-P-6b.** Its second half (`execute` answers false, `lockHint`) is pinned by M-P-lock-exec (report), which the title does not name.
7. **`ColourRow` does not call `PlanLocaleScope.push`.** It is internal and only the panel builds it, after the panel's own push, so the effect is nil today. It does depart from the letter of "every widget calls push".

Report notes (not findings against the code):
- M-PC9-a goes red through the engine's `ArgumentError` for an empty `CompoundCommand`, not through the "second step" the brief predicted.
- M-P-1c goes red one assertion earlier than predicted.
- Both are disclosed.
- Concern 1 (a disposed `DiagnosticsLog` cascading noise into later tests on a red run) is harness ordering. Passing output is reported clean.

### Assessment

**Task quality:** Needs fixes

**Reasoning:**
- The panel is the brief's code verbatim, with correct ports and intact ported assertions, and the implementer strengthened P-5 beyond the brief.
- SW5 is a degenerate fixture: its named mutation cannot turn it red, so the Size menu's servable guard is unpinned.
- The panel's handling of kit hooks that throw is narrower than the spec's "every hook at the boundary". That is a question for the controller.
