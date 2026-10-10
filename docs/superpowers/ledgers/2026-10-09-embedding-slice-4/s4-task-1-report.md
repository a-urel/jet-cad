# Slice 4, Task 1: the page flows without their dialogs (implementer's report)

- **Branch:** `claude/exciting-pasteur-9m22jv`, from `625bba1` (the plan's commit).
- **Commit:** `ffe0b9c`. Pushed as `625bba1..ffe0b9c`.
- **Environment:** Flutter 3.47.6 at `/root/sdk/flutter/bin`, with `CI=true`. Scratch files and mutant runners: `/tmp/claude-0/-home-user/428cafca-0083-5012-a7ac-5456349e70a8/scratchpad/s4t1-impl/`.
- **`analysis_options.yaml`:** none touched or committed. Before the commit, `git status` showed only the seven task files; after it, the tree was clean.
- **Scope:**
  - Nothing of Tasks 2 to 7 is in this commit.
  - The engine (`jet_cad_2d`) and `jet_cad_2d_flutter` are not edited.
  - `service_view.dart`, `planner_shell.dart`, `export_dialog.dart` and `export_bytes.dart` are not edited.
  - No golden test, counter test or allocation test is edited.
  - No existing test is edited, with one exception: B1 in `barrel_test.dart`, which the plan names.

## Files

| File | What |
|---|---|
| `packages/jet_cad_floor_plan/lib/src/host/floor_plan_types.dart` (+54) | New: `enum FloorPlanExportFormat { pdf, png }` (`:76`), `enum FloorPlanExportDpi { d96, d150, d300 }` with `int get value` (`:79`), and `final class FloorPlanExportChoice` (`:98`). The class has a `const` constructor, `static const initial` (PDF at 150 dpi), `copyWith`, `==`, `hashCode` and `toString` (`FloorPlanExportChoice(pdf, 150 dpi)`). Its documentation calls it today's dialog's answer made public. |
| `lib/src/host/page_flows.dart` (+159 −30) | See "page_flows.dart" below. |
| `lib/src/host/floor_plan_controller.dart` (+64) | See "The controller" below. |
| `lib/src/host/floor_plan_view.dart` (+32 −2) | See "The view" below. |
| `lib/jet_cad_floor_plan.dart` (+3) | The `show` list of `floor_plan_types.dart` gains the three names. |
| `test/host/barrel_test.dart` (+3) | B1 gains the three names. This is the plan's one allowed edit for Task 1. |
| `test/host/page_flows_test.dart` (new, 689 lines, 15 tests) | See "Tests" below. |

### page_flows.dart

- **`PageFlowHooks`** (`:30`): an internal record, `({exportDialog, onError})`.
- **`toExportChoice`** (`:42`) and **`fromExportChoice`** (`:55`): exhaustive `switch`es on the format and the dpi, never by index.
- **`exportOnce(controller, choice, name, {document, cancelled})`** (`:72`): the export body.
  - It reads the page, makes the bytes and returns a `FloorPlanExport`.
  - It holds the two `identical(document, activeDocument)` checks: one before the bytes (the check that followed the dialog) and one after them.
  - `document` is the plan the dialog was opened on; it defaults to the active plan.
  - `cancelled` replaces the flows' old `_disposed` check after the bytes.
- **`printOnce(controller, printer, name, {cancelled})`** (`:94`): the print body. It returns `bool` and keeps the same two checks.
- **`PageFlows`** (`:112`) gains two optional parameters, `hooks = _noHooks` and `ValueNotifier<bool>? ready`.
  - When `ready` is given it is the guard. Otherwise the flows make their own guard, which is the form view_test V11 constructs.
  - The guard is released in `finally`. An owned guard is released while the flows are not disposed. The controller's guard is released while the controller is not disposed.
- **`export`** (`:141`) calls `hooks().exportDialog` when it is given, and `showExportDialog` otherwise. Either way it starts from `controller.exportChoice`.
  - A null answer cancels.
  - An answer is remembered in `controller.exportChoice`.
  - Then `exportOnce` runs, and `sink` receives the result.
- **`print`** (`:166`) calls `printOnce`.
- **`_run`** (`:172`) gains `catch (error)`:
  - With `hooks().onError`, the error is reported there and the flow ends normally.
  - Without it, the error is rethrown with its stack trace (S-8).
  - The hook's own errors are caught the same way.

### The controller

- **`pageFlowReady`** (`@internal`, `:321`): the guard, one per controller (S-7). It is disposed in `dispose()`.
- **`isDisposed`** (`@internal`, `:326`): a getter, read by `PageFlows` to decide whether to release the controller's guard.
- **`exportPlan(FloorPlanExportChoice choice, {String name = 'plan'})`** (`:1073`) and **`printPlan({PagePrinter? printer, String name = 'plan'})`** (`:1087`, the printer defaults to `PrintingPagePrinter`) both go through `_pageFlow` (`:1095`):
  - It takes the guard and settles.
  - It runs the shared body, with `cancelled: () => _disposed`.
  - It answers null or false in these cases: a flow is already running, there is no page, the plan shown was replaced, or `dispose()` has run.
  - An error completes the `Future` with that error.
  - `exportChoice` is not touched.
  - No capability is checked (V-5).
- The controller imports `page_flows.dart` with `show exportOnce, printOnce, toExportChoice`, and imports `page_printer.dart`.

### The view

- **`onExportDialog`** (`:203`) and **`onPageFlowError`** (`:212`): named, optional parameters, documented with C-4's sentence and C-3's sentence (plus S-8).
- **`_flowsFor`** passes `hooks:` as a closure that reads the current `widget` (R-5), and passes `ready: c.pageFlowReady` (`:290`).

## Tests (`test/host/page_flows_test.dart`)

Fixtures:

- **`embeddingPlanJson()`** under **`embeddingCamera()`**. This is used for the PNG flows, the dialog hook and the chords.
- **`finitePlanJson()`**: the same plan without table `9`. This is used for every print and PDF (see Finding 1). It is built in the test file, so the shared fixture is untouched.
- **Hooks and printers:** a recording hook (`RecordingHook`, which can throw once), `FakePagePrinter` (`test/support/fake_page_printer.dart`: `hold`, `failNext`), and the view in both modes.
- **Expected values** are computed in the test: PNG sizes as `round(effW / 25.4 · dpi)` from the page, and print formats as `effW · 72 / 25.4`.
- **Non-default values:** PNG at 300, PNG at 96, the export name `salon`, the print name `teras`.

| Test | What it pins |
|---|---|
| PF1 | The three types through the barrel alone (prefixed import `host.`). `==` and `hashCode`; each field changed alone makes the values unequal; `copyWith`; `toString`; dpi values `[96, 150, 300]`. |
| PF2 | `exportPlan(png96)` in each mode gives `image/png`, `plan.png` (or `salon.png`) and the page's pixel size at 96 dpi. In the selection mode the unmoved copy's bytes equal the design's, and a moved table changes them (V5's reading). `onExport` is not called. `exportChoice` is left at `initial`. |
| PF3 | A plan without a page gives null from `exportPlan` and false from `printPlan`. In each mode `printPlan` gives one printer call with `teras`, the page's format and `%PDF` bytes. |
| PF4 | With no view mounted, `exportPlan` and `printPlan` act. After `dispose()` they answer null and false. |
| PF5 | Without `onExportDialog`, Cmd+E and Ctrl+E open the Material `export-dialog` in each mode. |
| PF6 | **M-H46** (killer). |
| PF7 | **T1-a** (killer). It also checks that a host's `printPlan` disables both bars' Print and Export until it ends. |
| PF8 | **T1-b** (killer), for export and for print. |
| PF9, PF10 | **T1-c** (killers). |
| PF11 | `printPlan`'s error completes its `Future`; `onPageFlowError` hears nothing; the guard is free again. |
| PF12 | **T1-d** (killer). |
| PF13 | **T1-e** (killer). |
| PF14 | **T1-f** (killer). |
| PF15 | A view removed while its Print runs still releases the controller's guard when the printer finishes: `exportPlan` acts afterwards. |

**PF10 was pinned on the base first.**

- Its body was rewritten without the new parameters, as `zz_pf10_base_test.dart`, now kept in the scratch directory.
- It was run against the base's five `lib` files (restored with `git show HEAD:…`). Result: `00:02 +1: All tests passed!`
- So on the base, a printer that throws `StateError('jam')` behind the bar's Print delivers exactly that error once to a zone wrapped around the press, as an uncaught async error. `takeException` is null, and Print is enabled again.
- My files were then copied back and checked with `cmp`.

## Mutants (each applied, seen red, reverted from a copy, checked with `cmp`)

The runner is `scratchpad/s4t1-impl/mutant.sh`, with one edit file per mutant in `edits/` and logs in `logs/`.

| Mutant | Applied as | Killer (red) | Reason seen |
|---|---|---|---|
| **M-H46 (shell's file command, button and chord)** | `floor_plan_view.dart` `_commands`' Export runs a hook-less `PageFlows` | PF6 | `export-dialog` found at "design Cmd+E" |
| **M-H46 (service bar's button)** | `service_view.dart:513` uses a hook-less `PageFlows` | PF6 | `export-dialog` found at "service-export" |
| **M-H46 (service chord)** | `service_view.dart:476` uses a hook-less `PageFlows` | PF6 | `export-dialog` found at "selection Ctrl+E" |
| **T1-a** (the controller's guard) | `_pageFlow` without `!pageFlowReady.value` | PF7 | Expected null, got an export (the second `exportPlan`) |
| T1-a′ (the view's flows on their own guard) | `ready: c.pageFlowReady` removed in `_flowsFor` | PF7 | Expected false, got true (`printPlan` while the bar's Print runs) |
| **T1-b** | `exportOnce`'s check after the bytes removed | PF8 | Expected null, got an export |
| T1-b′ (both of `exportOnce`'s checks removed) | both removed | PF8 | Expected null, got an export |
| T1-b″ (`printOnce`'s check after the bytes removed) | the check removed | PF8 (its last part: swapped after the cached font, by microtask) | Expected false, got true |
| **T1-c** (swallowed without the callback) | `report?.call(error)`, no rethrow | PF10 | Expected 1 caught, got `[]` |
| **T1-c** (`onPageFlowError` not called) | `report(error)` removed | PF9 | Expected 1 error, got `[]` |
| T1-c′ (guard not restored on an error) | release moved into `try` | PF9 and PF10 | Print stays disabled (expected true, got false) |
| T1-c″ (the controller's guard not restored on an error) | `_pageFlow` releases in `try` only | PF11 | Expected true, got false |
| T1-c‴ (a flow outliving its view keeps the controller's guard) | `if (!_disposed)` in place of the owned/external rule | PF15 | Expected not null, got null |
| **T1-d** | `answer ?? fromExportChoice(controller.exportChoice)` | PF12 | Two exports where one was expected |
| **T1-e** (d96 ↔ d300 in `toExportChoice`) | the swap | PF13 | Expected 1123×794, got 3508×2480 |
| **T1-e** (by index after a reorder) | the public enum declared `d300, d150, d96`, and `ExportDpi.values[choice.dpi.index]` | PF13 and PF1 | PF13: 3508×2480 expected, got 1123×794. PF1: `[96, 150, 300]` expected, got `[300, 150, 96]`. |
| T1-e′ (format swapped in `toExportChoice`) | pdf ↔ png | PF13 | Expected `application/pdf`, got `image/png` |
| T1-e″ (d96 ↔ d300 in `fromExportChoice`) | the swap | PF14 | `initials` list differs |
| **T1-f** (the hook's answer not remembered) | `controller.exportChoice = choice;` removed | PF14 | `initials` list differs |
| **T1-f** (`exportPlan` writes the remembered choice) | `exportOnce(this..exportChoice = …)` | PF2 and PF14 | PF2: expected `ExportChoice(pdf, 150 dpi)`, got `(png, 96 dpi)`. PF14: `initials` differ. |

**Survivor:** T1-b‴ removes only `exportOnce`'s check *before* the bytes. Run against view_test V11, it **survives** (`All tests passed`).

- This is the check that followed the dialog on the base.
- The check after the bytes still refuses a replaced plan, so the export is still dropped. The mutant's only effect is that bytes are made for nothing.
- I left it as an equivalent mutant. If a test were wanted, it would need a document that throws once disposed.

## Gates (real results, at the committed tree)

| Gate | Command | Result |
|---|---|---|
| Planner tests | `flutter test --enable-vmservice --file-reporter json:…` | `05:14 +1707: All tests passed!` |
| Planner standing comparison | `dart run tool/ci/expect_failures.dart --package packages/jet_cad_floor_plan --root packages/jet_cad_floor_plan planner.json` | `packages/jet_cad_floor_plan: 1707 tests; the standing failures and skips, exactly` (exit 0) |
| Planner analyze | `flutter analyze` | `No issues found!` |
| Planner format | `dart format --output=none --set-exit-if-changed .` | `Formatted 265 files (0 changed)`, exit 0 |
| Demo tests (`apps/restaurant_demo`) | `flutter test` | `00:36 +60: All tests passed!` |
| Demo analyze | `flutter analyze` | `No issues found!` |
| Demo format | `dart format …` | 8 files, 0 changed, exit 0 |
| Floor planner tests (`apps/floor_planner`) | `flutter test` | `01:43 +212: All tests passed!` |
| Floor planner analyze | `flutter analyze` | `No issues found!` |
| Floor planner format | `dart format …` | 47 files, 0 changed, exit 0 |
| Engine (`jet_cad_2d`) | `dart test` (exit 1, from its standing failures) through the comparison | `packages/jet_cad_2d: 1258 tests; the standing failures and skips, exactly` (exit 0) |
| Render (`jet_cad_2d_flutter`) | `flutter test` (exit 1, from its standing failures) through the comparison | `packages/jet_cad_2d_flutter: 1390 tests; the standing failures and skips, exactly` (exit 0) |

These named tests pass unedited inside the planner run:

- `view_test.dart`: V1, V2, V5, V9 to V11, V13.
- `floor_plan_theme_test.dart`, `widget_theme_test.dart`, `l10n/leak_test.dart`, `theme_canvas_test.dart`.

These floor-planner tests pass unedited: `export_flow_test.dart`, `print_flow_test.dart` and `export_end_to_end_test.dart`.

## Findings and deviations

1. **The embedding fixture cannot be printed or exported as a PDF, on the base too.**
   - Table `9` (x scaled by 1e306, y by 1e-306) gives NaN transforms. The PDF writer then asserts: `package:pdf … num.dart:32 '!value.isNaN'`, raised from `PdfDrawSink._pushTransform` ← `DraftPainter._drawText`.
   - I saw this on the base: a scratch probe pressed `toolbar-print` with the base's `lib` on `embeddingPlanJson()`.
   - PNG export of the same plan works.
   - So every print and PDF test here runs on `finitePlanJson()`, which is the fixture without table `9`. The PNG flows, the hook and the chords stay on `embeddingPlanJson()`.
   - Two possible follow-ups, neither in this task: the fixture could gain a finite variant, or the PDF sink could skip non-finite text. This plan asks for neither.
2. **When the flows read the view's settings.**
   - On the base, Export read `exportName`, and Print read `printer` and `exportName`, *after* the bytes were made.
   - With the shared bodies (`exportOnce` and `printOnce` take a name and a printer), Export reads the name after the dialog and before the bytes. Print reads both at its start.
   - This differs only if a host rebuilds the view with another `exportName` or `printer` while a flow is making bytes. No test reads it (V10's rebuild during a print passes unedited).
3. **The flows now release the controller's guard after their view is gone.**
   - The base's flows owned their guard and skipped the release once disposed.
   - With one guard per controller (S-7), that skip would leave the controller unable to export or print for good if a view were removed while its Print ran.
   - So the rule is: an owned guard (V11's construction) is released only while the flows live; the controller's guard is released unless the controller is disposed (`isDisposed`, `@internal`). PF15 and T1-c‴ pin this.
4. **The rethrow.** `_run`'s `catch` rethrows when there is no callback. This keeps the original error and stack trace, so the base's observable form holds. PF10 was green on the base and is green now.
5. **Controller members added beyond the plan's six:** `pageFlowReady` and `isDisposed`. Both are `@internal`. The barrel and B1 gain exactly the three names.

## Fixes

- **Commit:** `82219f4`, `test(floor_plan): the page flows' review killers (Slice 4, Task 1 review)`. Test only: `test/host/page_flows_test.dart` (the task's own file, extended). No `lib` change (R-7: nothing, as ruled). Scratch: `/tmp/claude-0/-home-user/428cafca-0083-5012-a7ac-5456349e70a8/scratchpad/s4-fix123/t1/` (`specs/`, `logs/`, `results.txt`) and the runner `mut_planner.sh`.
- The review's probes, folded with PF numbers in the file's style:

| Finding | Test | Mutant re-applied (the review's own spec) | Red in |
|---|---|---|---|
| R-1 (R-5's read at each call) | **PF16**: the flows used once with the Material dialog, then a host rebuild adds a recording `onExportDialog` and `onPageFlowError`: `toolbar-export` calls the hook (no `export-dialog`, one PNG export); a printer that throws is reported once, no uncaught error | R03 (`_flowsFor` captures both when the flows are made) | PF16 |
| R-2 (the settle) | **PF17**: `1` selected, `42` typed in `table-number` and not committed; `exportPlan(png96)` commits it (`c.tables` holds `42`), its bytes differ from before and equal a second export's | R02 (no `_settle?.call()` in `_pageFlow`) | PF17 |
| R-3 (dispose during a flow) | **PF18**: `printPlan` on a held printer, `dispose()`, the printer released: `false` | R01 (`return result`) | PF18 |
| R-4 (cancellation after the bytes, print) | **PF19**: `PageFlows` as V11 builds it, the font cached, `flows.dispose` in a microtask right after `print`: nothing printed | R05 (`printOnce` without `cancelled()`) | PF19 |
| R-4 (cancellation after the bytes, export) | **PF20**: the view removed right after `toolbar-export` with a hook answering PNG at 96: `onExport` never called | R06 (`exportOnce` without `cancelled()`) | PF20 |
| R-5 (remembered when the plan is replaced) | **PF21**: a hook that calls `resetLayout()` and answers PNG at 300: nothing exported, `exportChoice` is PNG at 300 | R09 (remembered only on a successful export) | PF21 |
| R-6 (RV8) | **PF6** gains Cmd+E in the selection mode (the remembered initials gain one `png300`) | a service view binding only the Ctrl export chord (`kExportChords.where((c) => c.control)`) | PF5, PF6 |

- Each mutant was applied by exact replacement, `test/host/page_flows_test.dart` run, the file restored from a copy and checked with `cmp`; `git status` showed only the test file afterwards.
- `page_flows_test.dart` now has 21 tests (`00:21 +21: All tests passed!`).

### Final gates (at `834c832`, after the last fix commit; a fresh run after a container restart killed the first one; `gates.sh`, `gates.out` in the scratch directory)

| Package | Tests (standing comparison) | Analyze | Format |
|---|---|---|---|
| `packages/jet_cad_floor_plan` (`--enable-vmservice`) | `04:34 +1787: All tests passed!`; "1787 tests; the standing failures and skips, exactly" | No issues | 271 files, 0 changed |
| `apps/restaurant_demo` | `+60: All tests passed!` | No issues | 8 files, 0 changed |
| `apps/floor_planner` | `+212: All tests passed!` | No issues | 47 files, 0 changed |
| `packages/jet_cad_2d_gpu` | 20 tests; exactly | No issues | 10 files, 0 changed |
| `packages/jet_cad_2d` | exit 1 (the 2 standing); "1258 tests; the standing failures and skips, exactly" | `--fatal-infos`: No issues | 170 files, 0 changed |
| `packages/jet_cad_2d_flutter` | exit 1 (the 7 standing goldens); "1415 tests; the standing failures and skips, exactly" | No issues | 227 files, 0 changed |

`git status` clean afterwards; no `analysis_options.yaml` committed. Pushed as `5c72a5e..834c832`.
