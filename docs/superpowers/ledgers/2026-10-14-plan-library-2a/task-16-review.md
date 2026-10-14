# Task 16 review: PlanToolPalette and PlanShortcuts (1d68c7a5..395fd873)

### Spec Compliance

- ✅ Spec compliant for everything the brief lists, file by file: `tool_letters.dart` (diff :490-601), `plan_shortcuts.dart` (:305-489), `plan_tool_palette.dart` (:115-259), `plan_shortcut_guard.dart` `planLetterKeys` widened from the entries (:285-296, ruling R-l: Task 15's guard consumed, not re-created), `plan_controller.dart` constructor call (:102-104), barrel exports (:37, :59-60), `stamp_kit.dart`, `design_harness.dart`, the four test files. Every brief-listed file has its hunk.
  - Keyboard (spec P2): file chords call the host's callbacks only when given (:420-431), Export/Print also under their flag (:432-433), a bound chord that cannot act consumes and does nothing (:409-414); Undo/Redo under `permissions.undo` (:436-443); F3 under `snappingAllowed` (:446-449, but see Important 1); letters bound under `allowsTool` (:452-458); F while a fill tool is offered, toggling only under geometry (:459-466); Escape arms `plan.select` (:468-472); `shortcuts: false` returns no bindings and closes `idleKeys` (:404-405, :417). Matches `planner_shell.dart:1444-1469` (checked) line for line in intent.
  - Letters: V L P R C A T kept; `taken` seeded with `'F': 'Fill'` (:559); kit letters upper-cased, regex `^[A-Z]$` (:555, :572-576); taken / F / non-letter -> no letter + one `letterTaken` (subject = tool id, message names owner) (:577-579, :596-601); load order (:570); computed once per controller via `Expando` (:546-553) and at construction (:104). plan.symbol has no row (KB-1's id list pins it).
  - Palette: generic then each kit in load order, `Divider` keyed `tool-group-<kit>` before each kit (:222-227), label via `planToolLabel` (generic -> `PlanStrings`, kit -> `tool:<id>` in `controller.locale` with English fallback via `KitNames.word`, id last; :146-164), letter as trailing text, selected while active, `enabled` = `selectTool`'s rule (:195-202, compared against `_allowsTool` / `toolById` at `plan_controller.dart:727-750`), Fill toggle keyed `tool-fill` (:239-249), `ExcludeFocus` (:207), locale pushed (:178-188).
  - "Every widget calls `PlanLocaleScope.push`": both widgets do (palette :180/:187, shortcuts :381/:390; the latter is a deviation the brief omitted, pinned by KB-12).
  - Ported tests keep their assertions: checked by diffing every `expect(` line of `jet_cad_floor_plan/test/planner_draw_test.dart:89-412` against `palette_draw_test.dart` — differences are only `view`->`c`, `d.doc`->`c.document` and line wrapping; the expects absent from the port are A7 (:209, Task 15's) and A9 (:258, Task 18's), as the brief assigns. `host_text_keys_test.dart`'s `typeInto` and the F-6 test bodies (original :160-179, :276-301) match, with `t.press` -> `press` and the mode loop dropped as the brief says.
  - Every new test names its mutation in its title (KB-1..KB-12; KB-11 and KB-12 are additions with M-KB-11/M-KB-12).
- ⚠️ Cannot verify from diff: the mutation table's red lines (report "Mutations") and the gate transcript; the controller should spot-check M-KB-1c and M-KB-3b, whose reds depend on construction-time and gate state outside the diff.

### Strengths

- One source of truth: palette, keyboard and guard all read `planToolEntries(c)` (diff :223, :452, :293), so a letter the palette shows is exactly one the keyboard binds and the guard stops; KB-1 pins identity (`identical(planToolEntries(c), entries)`).
- `letterTaken` is not plan-scoped (`diagnostics_log.dart:14-20` checked), so the construction-time diagnostic survives `clearPlanScoped()` on every load (`plan_controller.dart:604`) even though the entries are never recomputed — the Expando design holds.
- The implementer caught a real gap in the brief's `_enabled` (a tool whose factory threw was shown enabled though `selectTool` refuses it) and pinned it with KB-11 using a healthy control.
- Fixtures are non-degenerate: kits exercise free / taken / lower-case-F / no-letter / later-kit-collision; the design harness runs under the drawing fixture's rotated, zoomed camera off the origin; KB-3 checks both the `shortcuts: false` side and the control side in one test.

### Issues

#### Critical (Must Fix)

None.

#### Important (Should Fix)

1. **`plan_shortcuts.dart:136` (diff :446-449) — F3 stays bound under `PlanCanvas(snapping: false)`; S-14 regression vs. the shell.** `snappingAllowed` is a plain `@internal bool` (`plan_controller.dart:261`) that the canvas writes in `initState`/`didUpdateWidget` (`plan_canvas.dart:111`, `:145`) without notifying. `PlanShortcuts` is the canvas's ancestor, so its `ListenableBuilder` computes `_bindings` before the canvas's `initState` runs, reading the default `true`; it only recomputes on a controller notification (permissions change, swap), which may never come. Result: with `snapping: false`, F3 is consumed by the plan instead of bubbling to the host (C-5/S-14: "only while snapping is allowed"), and it silently flips the user's hidden `_userSnap.objectSnap`, which surfaces later if the host turns snapping on. Same staleness after a runtime `snapping` change. The shell read `caps.snapping` from its own widget synchronously (`planner_shell.dart:1453-1456`), so this is a behaviour regression the port introduced. Checked: `_enter`/`_bind` (`plan_canvas.dart:161-192`) do not notify, and `PlanLocaleScope.push` reports the locale post-frame on `c.locale`, not the controller. The implementer flagged it (Concern 1) and left it as needing a Task 8/15 contract change; it is the one binding rule in the brief with no test. Fix: make the snapping flag observable (a `ValueListenable<bool>`, or a setter that notifies on change) and add it to the `ListenableBuilder`'s listenable; add a KB test mounting the harness with `snapping: false` (F3 reaches the host, `c.snap.objectSnap` unchanged), named mutation: `if (c.snappingAllowed)` -> `if (true)`. Not run (review is read-only; adding a test would mutate the tree) — the ordering argument is Flutter's parent-builds-before-child-`initState` rule.

#### Minor (Nice to Have)

1. `plan_controller.dart` diff :100-104 — `planToolEntries(this)` is placed after `unawaited(_loadSymbols())`, whose comment says "Last: a constructor that threw leaves no load running". `_assign` is unlikely to throw, but the new call contradicts the invariant the comment states; move it before `_loadSymbols()`.
2. `plan_shortcuts.dart` `dispose` (diff :395-399) — a `shortcuts: false` `PlanShortcuts` that is removed while the canvas stays leaves `selectGates.idleKeys` closed (the select tool's idle Delete/Escape stay dead). Brief-as-written; implementer's Concern 2. Restoring `true` when the state disposes (guarded by `!controller.isDisposed`) would close it.
3. Untested branches: a file chord mid-shape consuming and doing nothing (`_run`'s `isMidShape` return, diff :411), and F refusing to toggle while geometry is denied (diff :462). Both are spec S-26 / "toggling only while geometry is allowed" rules with no red mutation.
4. `host_text_keys_test.dart` diff :1128-1129 — the ported comment still says W is "a letter the planner binds"; in this library W is no plan letter, so the ported host-field test now exercises no plan-bound letter (KB-2 with B and A8 cover the guarded-letter case). Update the comment (the assertions must stay).
5. `plan_shortcuts.dart` diff :452-458 — a letter is bound while `allowsTool` even when the tool's factory threw (`isToolDisabled`) or the engine refuses its needs, so the key is consumed and `selectTool` refuses. This matches the brief's rule and the shell's behaviour under `runtime` (A12 pins it), but the palette greys exactly those rows; a one-line doc note on the asymmetry would save a future reader.

### Assessment

**Task quality:** Needs fixes

**Reasoning:** The palette, the letter assignment and the keyboard are a faithful, well-tested port with one shared entry list, and the ported assertions are verifiably unchanged; but the F3 binding reads a non-notifying flag written by a descendant, so under `snapping: false` F3 is swallowed and toggles a hidden setting — a regression from the shell's S-14 behaviour with no test.
