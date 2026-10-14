### Finding Verdicts

- **[Important] F3 stayed bound under PlanCanvas(snapping: false) (S-14 regression)** — ADDRESSED. plan_controller.dart: `snappingAllowed` is now a getter/setter; the setter changes the value at once (EffectiveSnap still reads it live) and schedules one post-frame write to the new `@internal ValueListenable<bool> snapping`, so nothing notifies during a build; guarded by `_disposed`, notifier disposed in dispose(). plan_shortcuts.dart build: `Listenable.merge([c, c.snapping])` rebinds; `_bindings` still gates F3 with `c.snappingAllowed`. KB-13 (plan_shortcuts_test.dart) drives PlanCanvas(snapping:false) through the extended harness (design_harness.dart `snapping` notifier), asserts F3 reaches the host with the user's objectSnap unchanged, then flips snapping true at runtime and asserts F3 toggles and the host hears nothing more. Report lists M-KB-13a (`if (c.snappingAllowed)` -> `if (true)`, red `Expected 1 Actual 0`), plus 13b (listener reverted) and 13c (post-frame write removed), all red; reverts shown clean. Full gate output quoted (+475, analyze clean, format clean).
- **Report quotes spot-check of M-KB-1c and M-KB-3b** — ADDRESSED. Both rows in the report's mutation table with red lines (KB-1 `Set:[]` missing 'stamp.clash'; KB-3 `Expected 1 Actual 0` reason `escape`).

### New Breakage in the Fix Diff

None. The self-reported one-frame gap between the canvas's write and the rebind is real but narrow (post-frame, before any later key event), is disclosed, and is Minor. Moving `planToolEntries(this)` before `_loadSymbols()` is harmless and restores the "last" comment.

### Out-of-Scope Observations

None. (Minors 2 and 3 from the first review stay open per the report.)

### Verdict

**Fix round:** All findings addressed, no new Critical/Important breakage.
