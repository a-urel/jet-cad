# Task 18 review: PlanLayerPanel, PlanPagePanel, the layer picker (d510d4ea..7c0156a3)

### Spec Compliance

- ✅ Spec compliant. Every file in the brief's Files list has its hunk, and the brief's code (mark_kit.dart, layer_plan.dart, layer_page_controller_test.dart LP-1…LP-8, the picker's `_lockedOrUnderLock`, `layerPickerBlocked`, `_choose`, both panels' controller seams, the slot initializer, the barrel and the word) is in the diff as written.
  - Ports checked with `diff` against the sources (read-only):
    - `layer_row.dart` differs from `jet_cad_floor_plan/lib/src/layers/layer_row.dart` only by the five listed adaptations and a doc reference `[ShellShortcutGuard]`→`[PlanShortcutGuard]` (report Deviation 7).
    - `plan_layer_panel.dart` differs from `layer_panel.dart` only in the controller seam (`_onController`/`_bind`/`_unbind`, :143-170), `_allowed` = `permissions.editLayers && Capability.structure` (:174), `_execute` through `controller.execute` catching only `StateError` (:183), `_foreground` (:198), `PlanStrings`, and `controller:` on `LayerRow`.
    - `plan_page_panel.dart` differs from `page_panel.dart` only in the seam (`registerSettle` :58/:78, `_onController` :96, `_editable` :123, `_set` through `controller.execute` :159), `PlanStrings`, and the self-guard at :187 (controller ruling: accepted).
    - `layer_picker.dart`: `_owningInstance`, `_boundaryOfFill`, `layerOfKey`, `layerMoveCommand` and the build are the source with only `isParametricObject(doc, h)` → `isObject(h)` and `FloorPlanStrings` → `PlanStrings`. The source's `on ArgumentError` catch is gone because `execute` now answers false for it (R-b).
  - Spec P2: both panels take only the controller and follow a swapped document (LP-1, LP-3). Editing is gated by `editLayers`/`editPage` (LP-2, LP-4), and `changeLayer` is re-read at the choice (LP-8, layer_picker.dart:182). "Live object" comes from E1 (`catalog.typeIdOf`), not a closed list. Text fields keep their keys: the rename field is guarded in `LayerRow` (M-LP-10), and the scale field by the panel's own guard (M-LP-11).
  - P4: a locked object's layer change is refused up front (layer_picker.dart:79, ahead of the plain-group rule, LP-6) and at commit (LP-7: `lockBroken` after the menu opened; no exception, nothing changed, `lockHint` raised).
  - R-b: every commit goes through `controller.execute` (`_execute`, `_set`, `_choose`). None of them calls `document.commands.execute`.
  - R-f: `PanelFieldFocusNode` is imported from `panel_focus.dart`, and no second one is created.
  - R-g: the slot is filled (plan_property_panel.dart diff, one initializer plus the import). CP1's `layer-picker` assertion is restored at the source's place (color_picker_test.dart:357-358 order matches).
  - R-i: the scale is formatted and parsed with `_strings` (plan_page_panel.dart:114, :173). The separator segment writes `page.decimalSeparator` through `_set` (:326).
  - PlanLocaleScope.push: both public panels call it in `didChangeDependencies` and on a controller change, pinned by LP-L (M-LP-La/Lb). `LayerPicker` and `LayerRow` are internal and hosted by panels that push.
  - Ported tests keep their assertions. `expect(` counts: page_panel 46 → 46. layer_panel 181 → 170: the 11 are the "in the app" test the brief excludes. layer_picker 109 → 92: the 17 are the two excluded tests plus the two panel-level premises the brief drops. The `-w` diffs of all three show only fixture, import and name changes. A9/A14/A15/A18/A19/A23-A26, D6a + premise, NN1, PW1/PW2 (minus the wall and zoom parts the brief moves) and SE2L were compared line by line with their sources: unchanged.
  - The report's deviations 1-5 and 7-11 are fixture or mechanical adaptations within "fixtures may change". Deviation 6 is the controller-accepted self-guard. Deviation 10 (LP-L) is a small, justified extra.
- ⚠️ Cannot verify from diff:
  - The mutation table (M-LP-1…M-LP-11, La/Lb) and the gates (602 passing, analyze clean, format exit 0). This review is read-only, so none were re-run; the report quotes a red line for each.
  - That `PlanPropertyPanel` (Task 17's, unchanged here) rebuilds the picker after `lockBroken` or a document swap, and mounts it only while `changeLayer` is on. The brief states it; this diff touches only the slot.

### Strengths

- The controller seam is small and symmetric in both panels: rebind only when `document`/`page` is another object, and rebuild on every notification. `_unbind` works from the bound objects, not from `widget`, so a swap releases the old document. LP-1 proves this by the old document's listener count, with handles that are shared across the two plans so that a stale panel would be visible.
- The `_foreground` derivation (plan_layer_panel.dart:198) is exactly the canvas's (`plan_canvas.dart:220-241`: `PlanTheme.of(context)?.canvasBackground ?? scheme.surface`, `displayPaperFor`). The panel's ACI 7 swatch and the drawn ink cannot disagree.
- LP-6 builds a genuinely missing kit (the plan is saved with the kit and reopened without it) and asserts both premises (`isLocked`, `typeIdOf == null`) before the reason. It pins the lock-before-plain-group ordering.
- LP-7 separates M-LP-7 (an exception escaping) from M-LP-7b (the hint not raised) with distinct assertions.
- The fixtures follow the testing bar. Marks sit far off the origin (`at()` offset −31250.5/+18420.25) and are turned (0.35, −0.6, 1.1, 0.7, −0.3). Layers have non-default ACIs, and one is locked and one hidden.

### Issues

#### Critical (Must Fix)

None.

#### Important (Should Fix)

None.

#### Minor (Nice to Have)

1. **layer_picker.dart:54-65, the walk in `_lockedOrUnderLock` duplicates the lock set's (plan-mandated, brief Step 7).** `PlanController.isLocked` is `LockSet.covers`, which already walks an entity's owner and the node parents up to the root or a definition (locks.dart:112-113, :140). So once `isLocked(h)` is false, the `up` loop can never return true.
   - Why it matters: no test can turn red if the loop is deleted, and the loop is code with no live behaviour.
   - Fix: reduce the helper to `isLocked(h)`, or keep it and record why. The brief prescribed the loop, so this is for the controller to decide.
2. **plan_layer_panel.dart:198-207, only one input of `_foreground` is pinned.** The ported swatch test (layer_panel_test.dart:288) drives only the page-background input. The other three are not exercised: a page without a background, a dark canvas's paper, and `PlanTheme.canvasBackground`. Hard-coding `brightness: Brightness.light` or dropping the `PlanTheme` lookup would leave every test green.
   - Fix (optional): add a dark-theme, no-background case asserting the ACI 7 swatch is white ink.
3. **layer_page_words_test.dart:195 and :206, test names describe a section the tests no longer cover.** The names of PW1 and PW2 still say "the Wall section", but the wall parts moved to sub-project 3. The file header explains this, but the names alone mislead.
4. **selection_page_test.dart, two small departures from the source.**
   - :58: the window is enlarged to 1440 x 1080 after `pumpDesign`, so the scale field is reachable. That is harmless: `globalOf` maps through the live camera, and the boxes are drawn after the resize.
   - SE13/15/16 also change an asserted literal: `status 'Wall'` → `'Box'`, with W → B. This follows Task 17's accepted precedent for SE11-SE14 (selection_panel_test.dart:396-412), because W is a sub-project 3 tool.
   - Listed so the controller sees that a literal in a ported assertion changed under A12.
5. **plan_layer_panel.dart:220-236, `_add` behaves as before on a refusal.** It still selects the new handle and opens its rename even when `execute` answered false. This is the ported behaviour, and it is inert because `build` checks `layers.contains`. The report flags it, and no action is needed now.

### Assessment

**Task quality:** Approved

**Reasoning:** The ports are faithful (checked by `diff` against all four source files). The controller seam is correct and pinned by mutation-named tests for every new behaviour: swap, `editLayers`, `editPage`, the settle, the lock up front and at commit, `changeLayer`, and the locale. The ported assertions are intact apart from the brief-sanctioned removals and Task 17's accepted W→B substitution. The remaining items are a mandated redundant walk and coverage polish.
