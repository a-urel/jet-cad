# Task 16 report: PlanToolPalette and PlanShortcuts

Status: DONE_WITH_CONCERNS (concerns are pre-existing design points, listed at the end; nothing open in this task's own scope)

Commit: `395fd873 feat(plan): PlanToolPalette and PlanShortcuts (P2)` (BASE 1d68c7a5). One commit, staged by explicit path, trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. No analysis_options.yaml touched.

## Implemented

- `lib/src/shortcuts/tool_letters.dart` (new): `kPlanKitId`, `PlanToolEntry` (`id`, `kitId`, `icon`, `needs`, `letter`, `key`), `planToolEntries(controller)` computed once per controller (an `Expando`). Generic tools keep V L P R C A T; F is reserved for Fill; a kit tool's letter is upper-cased and must be one A-Z letter; a taken letter, F, or a non-letter gets no letter and one `letterTaken` diagnostic (subject = the tool id, message names the owner).
- `lib/src/shortcuts/plan_shortcut_guard.dart`: `planLetterKeys` is now the letters in use (generic and kits', in palette order) plus F (ruling R-l: widened, the guard was not re-created). Its import of `generic_tools.dart` became `tool_letters.dart` (the two files import each other).
- `lib/src/controller/plan_controller.dart`: the constructor calls `planToolEntries(this)` last, so the `letterTaken` diagnostics are in `controller.diagnostics` before any widget is built.
- `lib/src/editor/plan_tool_palette.dart` (new): `fillOffered`, `planToolLabel` (PlanStrings for the generic ids, the kit's `tool:<id>` word in `controller.locale` with English fallback, the id last), and `PlanToolPalette` (port of `tool_palette.dart`): `ExcludeFocus`, transparent `Material`, a `ListenableBuilder` over the controller, `activeTool`, `fill` and `locale`, a `Divider` keyed `tool-group-<kit id>` before each kit's group, rows keyed `tool-<id>` (icon, label, letter as trailing text, selected while active, enabled exactly when `selectTool` would arm it), then the Fill `CheckboxListTile` keyed `tool-fill` while a fill tool is offered. It pushes the locale.
- `lib/src/shortcuts/plan_shortcuts.dart` (new): `PlanShortcuts` with the brief's binding rules: `shortcuts: false` binds nothing and closes `selectGates.idleKeys` (re-applied on every controller notification, so after a swap); file chords for the callbacks given, Export and Print also under their flag, a chord that cannot act now (mid-shape, or no page for Export and Print) consumes its key and does nothing; Undo and Redo while `permissions.undo`; F3 while `snappingAllowed`; F while a fill tool is offered (toggling only while geometry is allowed); Escape arms `plan.select` from an idle tool; letters bound while `permissions.allowsTool`. `PlanTextKeys` wraps everything. It pushes the locale.
- Barrel: exports `PlanToolPalette`, `PlanShortcutGuard`, `PlanShortcuts`.
- Test support: `test/support/stamp_kit.dart`, `test/support/design_harness.dart` (both as the brief's; Task 17 reuses them).
- Tests: `test/shortcuts/plan_shortcuts_test.dart` (KB-1 to KB-6, KB-10, plus KB-12), `test/editor/plan_tool_palette_test.dart` (KB-7 to KB-9, plus KB-11), ported `test/editor/palette_draw_test.dart` (A1-A6, A8, A10-A13) and `test/shortcuts/host_text_keys_test.dart` (the host-field cases).

## TDD evidence

RED (Step 5), `flutter test test/shortcuts/plan_shortcuts_test.dart test/editor/plan_tool_palette_test.dart`, before any lib code:

```
test/shortcuts/plan_shortcuts_test.dart:15:8: Error: Error when reading 'lib/src/shortcuts/tool_letters.dart': No such file or directory
test/support/design_harness.dart:14:8: Error: Error when reading 'lib/src/editor/plan_tool_palette.dart': No such file or directory
test/shortcuts/plan_shortcuts_test.dart:60:21: Error: Method not found: 'planToolEntries'.
test/support/design_harness.dart:68:28: Error: Method not found: 'PlanShortcutGuard'.
test/support/design_harness.dart:75:43: Error: Method not found: 'PlanToolPalette'.
test/support/design_harness.dart:51:33: Error: Method not found: 'PlanShortcuts'.
test/support/design_harness.dart:109:13: Error: The method 'planToolLabel' isn't defined for the type 'StatusLine'.
test/editor/plan_tool_palette_test.dart:20:27: Error: Undefined name 'PlanToolPalette'.
```

GREEN (Step 12), same command after the lib code: `00:01 +10: All tests passed!` (the brief's ten). `flutter test test/canvas`: `00:02 +53: All tests passed!` (Task 15's tests stay green under the widened guard).

KB-11 and KB-12 (my additions, see Deviations) were written after their code; their red is shown by M-KB-11 and M-KB-12 below. With them: `00:01 +12: All tests passed!`.

Ported (Step 14), `flutter test test/editor test/shortcuts`: `00:02 +27: All tests passed!` (12 new + 12 palette_draw + 3 host_text_keys). No ported assertion failed or changed.

## Mutations (on committed 395fd873; each reverted with `git checkout -- <file>`, then `git diff --quiet -- <file>` printed `clean 0`)

| Mutation | File: change | Test | Red line |
|---|---|---|---|
| M-KB-1a | tool_letters.dart: `} else if (owner != null) {` -> `} else if (false) {` | KB-1 | `Expected: Set:['stamp.clash', 'stamp.fill', 'late.star']  Actual: Set:[]` |
| M-KB-1b | tool_letters.dart: `<String, String>{'F': 'Fill'}` -> `<String, String>{}` | KB-1 | `Actual: Set:['stamp.clash', 'late.star']  Which: does not contain 'stamp.fill'` |
| M-KB-1c | plan_controller.dart: constructor's `planToolEntries(this);` deleted | KB-1 | `Expected: Set:['stamp.clash', 'stamp.fill', 'late.star']  Actual: Set:[]` |
| M-KB-2 | plan_shortcut_guard.dart: `planLetterKeys` -> `[for (final t in genericTools) letterKey(t.letter), keyF]` (plus the `generic_tools.dart` import it needs) | KB-2 | `Expected: false  Actual: <true>` (B taken from the field) |
| M-KB-3a | plan_shortcuts.dart: `if (!widget.shortcuts) return const {};` deleted | KB-3 | `Expected: <1>  Actual: <0>` reason `l` |
| M-KB-3b | plan_shortcuts.dart: `_applyIdleKeys` body -> `{}` | KB-3 | `Expected: <1>  Actual: <0>` reason `escape` |
| M-KB-4 | plan_shortcuts.dart: the Escape binding deleted | KB-4 | `Expected: 'plan.select'  Actual: 'plan.polyline'` |
| M-KB-5 | plan_shortcuts.dart: `if (p.undo) {` -> `if (true) {` | KB-5 | `Expected: <1>  Actual: <0>` |
| M-KB-6a | plan_shortcuts.dart: `if (needsPage && c.page.value == null) return;` deleted | KB-6 | `Expected: [1, 1]  Actual: [2, 2]` |
| M-KB-6b | plan_shortcuts.dart: `if (p.export) file(...)` -> `file(kExportChords, widget.onExport, needsPage: true);` | KB-6 | `Expected: <1>  Actual: <0>` |
| M-KB-7a | tool_letters.dart: `c.kits.kits` -> `c.kits.kits.reversed` | KB-7 and KB-1 | KB-7: row-order list mismatch (`Expected: [ 'tool-plan.select', ...`); KB-1: `Actual: Set:['stamp.star', 'stamp.clash', 'stamp.fill']  Which: does not contain 'late.star'` |
| M-KB-7b | plan_tool_palette.dart: `controller.locale.value.languageCode` -> `'en'` | KB-7 | `Expected: 'Yıldız'  Actual: 'Star'` |
| M-KB-8a | plan_tool_palette.dart: `enabled: _enabled(c, e),` -> `enabled: true,` | KB-8 | `Expected: false  Actual: <true>` |
| M-KB-8b | plan_shortcuts.dart: `if (key != null && p.allowsTool(e.id))` -> `if (key != null)` | KB-8 | `Expected: <1>  Actual: <0>` |
| M-KB-9 | plan_tool_palette.dart: `fillOffered` -> `true` | KB-9 | `Expected: no matching candidates  Actual: _KeyWidgetFinder:<Found 1 widget with key [<'tool-fill'>]` |
| M-KB-10 | plan_canvas.dart: `autofocus: widget.autofocus,` -> `autofocus: true,` | KB-10 | `Expected: same instance as FocusNode:<...(host-field)...>  Actual: FocusNode:<...(InteractionLayer [PRIMARY FOCUS])...>` |
| M-05m | plan_shortcuts.dart: the Escape binding's body -> `{}` | palette_draw A4 | `Expected: 'Select'  Actual: 'Line'` |
| M-05v | text_entry_overlay.dart: `PlanShortcutGuard(controller: widget.controller, child: …)` -> `KeyedSubtree(child: …)` | palette_draw A8 | `Expected: false  Actual: <true>` for `Key L` |
| M-KB-11 (added) | plan_tool_palette.dart: `if (c.isToolDisabled(e.id)) return false;` deleted | KB-11 | `Expected: false  Actual: <true>` |
| M-KB-12 (added) | plan_shortcuts.dart: `PlanLocaleScope.push` deleted from `didChangeDependencies` | KB-12 | `Expected: Locale:<tr>  Actual: Locale:<en>` |

## Gate (packages/jet_cad_2d_plan, before the commit)

```
dart format .                       -> Formatted 122 files (5 changed)
flutter test                        -> 00:11 +474: All tests passed!
flutter analyze                     -> No issues found! (ran in 3.4s)
dart format --output=none --set-exit-if-changed . -> Formatted 122 files (0 changed); format exit 0
```

`git status --short` before staging listed only this task's files; after the mutations the tree is clean (`git diff HEAD` empty).

## Files

- /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2a/packages/jet_cad_2d_plan/lib/src/shortcuts/tool_letters.dart (new)
- /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2a/packages/jet_cad_2d_plan/lib/src/shortcuts/plan_shortcuts.dart (new)
- /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2a/packages/jet_cad_2d_plan/lib/src/editor/plan_tool_palette.dart (new)
- /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2a/packages/jet_cad_2d_plan/lib/src/shortcuts/plan_shortcut_guard.dart
- /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2a/packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart
- /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2a/packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart
- /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2a/packages/jet_cad_2d_plan/test/support/stamp_kit.dart (new)
- /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2a/packages/jet_cad_2d_plan/test/support/design_harness.dart (new)
- /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2a/packages/jet_cad_2d_plan/test/shortcuts/plan_shortcuts_test.dart (new)
- /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2a/packages/jet_cad_2d_plan/test/editor/plan_tool_palette_test.dart (new)
- /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2a/packages/jet_cad_2d_plan/test/editor/palette_draw_test.dart (new, ported)
- /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2a/packages/jet_cad_2d_plan/test/shortcuts/host_text_keys_test.dart (new, ported)

## Deviations from the brief

The brief's code compiled and passed against the real code as written: `tool_letters.dart`, `plan_tool_palette.dart`, `plan_shortcuts.dart`, the `planLetterKeys` body, `stamp_kit.dart`, `design_harness.dart` and the ten KB tests are the brief's text (then `dart format`). Every name in "Assumed from earlier tasks" exists as assumed (`diagnosticsLog.report` is Task 11's alias of `add`). The deviations:

1. **The palette greys a tool whose factory threw** (`_enabled` first checks `c.isToolDisabled(e.id)`). The brief's rule is "enabled exactly when `selectTool` would arm it", and `selectTool` refuses such a tool (`session.toolById` is null for it, Task 11, spec P4); `PlanController.isToolDisabled`'s own doc says "the palette greys it". The brief's `_enabled` omitted it. Pinned by an added test, KB-11 (ThrowingKit with `toolCreate` failing; the healthy kit as the control), mutation M-KB-11.
2. **`PlanShortcuts` pushes the locale** (`PlanLocaleScope.push` in `didChangeDependencies` and on a controller change), per the dispatch's "every widget calls `PlanLocaleScope.push`"; the brief's `PlanShortcuts` did not. Pinned by an added test, KB-12 (PlanShortcuts alone under `tr`), mutation M-KB-12.
3. `plan_controller.dart`: the `tool_letters.dart` import sits in sorted position, and the constructor call carries a one-line comment.
4. Mutation mechanics, intent unchanged: M-KB-2 also re-adds the `generic_tools.dart` import its body needs (the guard now imports `tool_letters.dart`); M-05v replaces `PlanShortcutGuard(controller: …, child: X)` with `KeyedSubtree(child: X)`, a transparent wrapper, so the child stays and only the guard goes.
5. Ported `palette_draw_test.dart`: the original's `dart:convert` and `flutter/gestures.dart` imports are dropped (the helpers that used `jsonDecode` live in the fixture; `PointerDeviceKind` was only used by A14+, which are not ported here). The fixture is `drawController()`, whose page has a white background where `drawDoc`'s had the default; no ported assertion reads the background. The A12b comment notes the sub-project-3 rows that left (as the brief says).
6. Ported `host_text_keys_test.dart`: the two kept tests are renamed as the brief says ("a host field beside the plan keeps its keys …"; the F-6 test runs once, on `host-field`, with no mode loop); `PosHost` loses `caps` and `mountPos` is the brief's.

## Self-review

- The letters are computed once per controller and read by the palette, the keyboard and every guard (`identical(planToolEntries(c), entries)` is asserted in KB-1).
- The palette, the shortcuts and the guard all read the same `PlanToolEntry` list, so a kit letter the palette shows is exactly one the keyboard binds and the guard stops.
- `PlanShortcuts` rebinds on every controller notification (permissions, swap) through a `ListenableBuilder`; `_applyIdleKeys` also runs on every notification so a swapped-in document's gates get the setting.
- Ported assertions unchanged; KB-1 to KB-12, A1-A6, A8, A10-A13 and the host-field cases all have a red mutation.
- Untested by this task (no test in the brief): the "a chord that cannot act mid-shape consumes the key" branch (`isMidShape` in `_run`) and the F toggle refusing while geometry is denied.

## Concerns

1. **F3 and `snappingAllowed` (pre-existing design).** `snappingAllowed` is a plain field Task 15's canvas writes in `initState`/`didUpdateWidget`, with no notification. `PlanShortcuts` builds before the canvas below it, and rebuilds only when the controller notifies, so a canvas mounted with `snapping: false` leaves F3 bound (it toggles the user's setting) until the next controller notification; a later change of `snapping` likewise. Fixing it needs a listenable on the controller (Task 8/15 contract), so I left it. Untested.
2. **`idleKeys` stays closed after a `shortcuts: false` `PlanShortcuts` is removed** (the brief's `dispose` does not restore it). A host that drops the widget but keeps the canvas keeps the select tool's idle Delete/Escape closed. Restoring it in `dispose` would touch a possibly disposed controller's session, so I left it as the brief wrote it.
3. The Task 12 ledger note (canUndo/dirty lag a synchronous edit) is not touched by this task: the keyboard calls `undo()`/`redo()`, which read `commands.canUndo` directly.

## Fix round 1 (commit 9a76ce37)

Review: task-16-review.md, Important 1 (F3 stays bound under `PlanCanvas(snapping: false)`), plus Minors 1, 4 and 5.

### Changes

- `lib/src/controller/plan_controller.dart`: `snappingAllowed` is now a getter and a setter over a private bool. The setter changes the value at once, so the tools (`EffectiveSnap`) see it at once, as before. When the value changes it schedules one post-frame callback that copies it into a new `@internal ValueListenable<bool> snapping` (a `ValueNotifier`, disposed with the controller, not written after `dispose`). The canvas writes the flag in `initState` and `didUpdateWidget`, inside a build, where marking an ancestor such as `PlanShortcuts` dirty is not allowed. So the notification waits for the end of the frame, as `PlanLocaleScope.push` does with the locale.
- `lib/src/shortcuts/plan_shortcuts.dart`: the `ListenableBuilder` listens to `Listenable.merge([c, c.snapping])`, so F3 is rebound after the frame in which the canvas set its option. The bindings still read `c.snappingAllowed` live when they are built.
- Minor 1: the constructor calls `planToolEntries(this)` before `unawaited(_loadSymbols())`, which is last again, as its comment says.
- Minor 5: a comment at the letter bindings explains why a letter stays bound when the palette greys its row (a factory that threw, or needs the engine denies): the key is consumed and nothing arms, as the shell did under `runtime` (A12).
- Minor 4: in the ported `host_text_keys_test.dart`, only the `kPosKeys` comment changed. W is no plan letter here, and the comment now lists the keys the map actually holds (Enter, not Ctrl+Z). No assertion changed.
- `test/support/design_harness.dart`: `pumpDesign(..., snapping:)` and `Design.snapping`, a `ValueNotifier<bool>`. The harness now mounts its own `PlanCanvas(controller: c, snapping: d.snapping.value)` through a `ValueListenableBuilder`. With the default `true` it is the same widget `pumpDraw` built.
- New test KB-13 in `test/shortcuts/plan_shortcuts_test.dart`: under `PlanCanvas(snapping: false)` with the canvas focused, F3 reaches the host (`reached['f3'] == 1`) and `c.snap.objectSnap` is unchanged. The control: `snapping` set to true at runtime, then F3 toggles the setting and the host hears nothing more.
- Not done: Minor 2 (restoring `idleKeys` on dispose) and Minor 3 (tests for the mid-shape file chord and for F under denied geometry). Both stay open as concerns.

### Tests and gate

- `flutter test test/shortcuts test/editor test/canvas test/controller/lifetimes_test.dart` -> `00:04 +86: All tests passed!` (Task 15's CV tests and lifetimes' `snappingAllowed = false` stay green).
- Gate (packages/jet_cad_2d_plan): `dart format .` -> `Formatted 122 files (0 changed)`; `flutter test` -> `00:10 +475: All tests passed!`; `flutter analyze` -> `No issues found! (ran in 2.8s)`; `dart format --output=none --set-exit-if-changed .` -> `format exit 0`.

### Mutations (on committed 9a76ce37; each reverted with `git checkout -- <file>`, `git diff --quiet -- <file>` printed `clean 0`)

| Mutation | File: change | Test | Red line |
|---|---|---|---|
| M-KB-13a | plan_shortcuts.dart: `if (c.snappingAllowed) {` -> `if (true) {` | KB-13 | `Expected: <1>  Actual: <0>` (F3 consumed, never reached the host) |
| M-KB-13b | plan_shortcuts.dart: `listenable: Listenable.merge([c, c.snapping]),` -> `listenable: c,` (the original code) | KB-13 | `Expected: <1>  Actual: <0>` |
| M-KB-13c | plan_controller.dart: the post-frame `if (!_disposed) _snapping.value = _snappingAllowed;` deleted | KB-13 | `Expected: <1>  Actual: <0>` |
| M-KB-1c (spot-check) | plan_controller.dart: the constructor's `planToolEntries(this);` deleted | KB-1 | `Expected: Set:['stamp.clash', 'stamp.fill', 'late.star']  Actual: Set:[]  Which: does not contain 'stamp.clash'` |
| M-KB-3b (spot-check) | plan_shortcuts.dart: `_applyIdleKeys` body -> `{}` | KB-3 | `Expected: <1>  Actual: <0>` reason `escape` |

M-KB-13b is the code before this fix, so KB-13 is red against the bug the review reported.

### Remaining concerns

- With the fix there is a gap of one frame: between the end of the frame in which the canvas changed `snapping` and the next build of `PlanShortcuts`, the old F3 binding stands. A key event that arrives inside that gap would still see the old binding. It does not happen in tests, which pump between the change and the key.
- Minor 2 (`idleKeys` left closed after a `shortcuts: false` `PlanShortcuts` is removed) and Minor 3 (two untested branches) are still open.
