# Slice 4, Task 1: the page flows without their dialogs (independent review)

- **Commit reviewed:** `ffe0b9c` (parent `625bba1`), branch `claude/exciting-pasteur-9m22jv`.
- **Where:** my own clones, `/home/user/review-s4t1` (the gates) and `/home/user/review-s4t1-mut` (mutants and probes), both at `ffe0b9c`. Both are deleted now. Nothing was edited, committed or pushed in `/home/user/jet-cad`.
- **Scratch:** `/tmp/claude-0/-home-user/428cafca-0083-5012-a7ac-5456349e70a8/scratchpad/rv-s4t1/`:
  - the probes: `rv_probe_test.dart` (RV1–RV9) and `rv_base_probe_test.dart` (RVB1–RVB3, which compile against the base);
  - the mutant runner and specs: `mutant.sh`, `apply.py`, `mut/`, `mut2/`;
  - one log per mutant: `logs/`;
  - the gate outputs: `planner.out` / `.json`, `demo.out`, `fp.out`, `engine*.out`, `render*.out`.
- **Environment:** Flutter `/root/sdk/flutter/bin` with `CI=true`.

## Verdict

**Approve with minor fixes.** The code is correct on every point I checked:

- the scope;
- P-1 and P-6;
- the mapping;
- every Export entry point;
- the shared guard;
- the errors;
- the release of the guard;
- the `identical` checks.

The gates are green with the implementer's counts. Every named and task-local mutant goes red.

Six of my own mutants survive the committed tests, though. Each one breaks a behaviour that the plan or the code's own documentation promises: R-5's read-at-each-call, the settle, the answer after `dispose()`, the view's cancellation, and remembering the choice. Probes that kill each of them already exist (RV1–RV7). Landing them closes R-1 to R-5. None of the findings needs a `lib` change.

## 1. Scope, P-1, P-6

- **Diff** (`git diff --stat 625bba1 ffe0b9c`): 7 files, the ones the report lists.
  - The tests changed are `barrel_test.dart` (+3, B1 only) and the new `page_flows_test.dart`.
  - The engine, `jet_cad_2d_flutter`, `service_view.dart`, `planner_shell.dart`, `export_dialog.dart` and `export_bytes.dart` are not touched.
  - No `analysis_options.yaml`, golden, counter test or allocation test is touched.
- **The barrel** gains exactly `FloorPlanExportChoice`, `FloorPlanExportDpi` and `FloorPlanExportFormat`. B1 gains the same three names.
- **Value types (P-9):**
  - `FloorPlanExportChoice` is a `final class` and `@immutable`, with a `const` constructor, `initial` (PDF, 150), `copyWith`, `==`, `hashCode` and `toString` `FloorPlanExportChoice(pdf, 150 dpi)`.
  - `FloorPlanExportDpi.value` is a `switch`, not an index.
- **Extra members:** the controller gains `pageFlowReady` and `isDisposed`. Both are `@internal`, which follows the precedent of `exportChoice`. Neither enters the barrel, so this is not an R-1 breach.
- **With no new parameter, the behaviour is today's.** I checked it by reading the code and by running tests:
  - The Material dialog opens from the shell's button and both chords, and from the service bar's button and chord. V1, V5 and V11 run unedited, and PF5 covers the chords.
  - The choice is remembered in `controller.exportChoice`, before the bytes, as on the base.
  - The names: `<exportName>.pdf` / `.png`, and the printer's name.
  - The flows still run one at a time. With one view the guard is the controller's, which has the same effect as the view's own.
  - Errors propagate as before. **RVB1**, run against the base's five `lib` files and against the task's, gives the same observable form on both: exactly one uncaught `StateError('jam')` reaches a zone around the press, `takeException` is null, and Print is enabled again. This confirms the implementer's PF10 claim independently.
- **The deviations from today's behaviour:**
  - the read time of the name and the printer (implementer's finding 2);
  - the page re-read after the dialog (R-7, informational);
  - the guard released after the view is gone (finding 3, a fix S-7 needs).

  Each one is ruled below.

## 2. Correctness

- **The mapping** (`toExportChoice` / `fromExportChoice`):
  - Both are exhaustive `switch`es over each format and each dpi, never an index.
  - PF13 drives all six choices through `exportPlan` and compares them with the base's `exportBytes`: byte equality for PNG, and the magic and `/MediaBox` for PDF.
  - The swap and by-index mutants both go red (below).
- **The Export entry points.** I enumerated them myself:
  - Command: `grep -rn "showExportDialog\|flows\.export\|_flows\.export" packages/jet_cad_floor_plan/lib`.
  - The results:
    - `service_view.dart:476`: the service chords, both of `kExportChords`;
    - `:513`: the `service-export` button;
    - `floor_plan_view.dart:355`: the shell's `export` `ShellCommand`, which the shell shows as `toolbar-export` (`document_toolbar.dart:44,71`) and binds as chords (`planner_shell.dart:901-902`) through `ShellCommand.invoke`.
  - All of them go through `PageFlows.export`, the only place that calls `showExportDialog` or the hook.
  - **The floor planner app is not a `FloorPlanView`.** `apps/floor_planner/lib/document_host.dart:581-587` has its own `exportFlow` with its own `showExportDialog` and `_lastExport`. It is outside C-4, which is a `FloorPlanView` parameter, and it is correctly untouched.
  - The shell has no other menu: there is no `PlatformMenuBar` or `MenuItemButton` in `lib`.
  - The coverage:
    - PF6 covers Cmd+E and Ctrl+E (design mode), `toolbar-export`, Ctrl+E (selection mode) and `service-export`.
    - **RV8** adds Cmd+E in the selection mode, and passes.
- **The hook's null cancels:** PF12 (T1-d). **The answer is remembered:** PF14 (T1-f).
- **The guard (S-7):**
  - It is shared: `_flowsFor` passes `ready: c.pageFlowReady`, and `_pageFlow` takes the same notifier.
  - The cases, with what each one answers:

    | Case | Answer | Pinned by |
    |---|---|---|
    | Concurrent `exportPlan` | null | PF7 |
    | `exportPlan` while the bar's Print runs | null | PF7 |
    | `exportPlan` while the host's hook is open | null | RV9 (passes) |
    | No page | null / false | PF3 |
    | A replaced plan (`setMode`, `load`, a microtask swap after the cached font) | null / false | PF8 |
    | Disposed (after the call) | null / false | PF4 |
    | Disposed mid-flow | false | RV2 (passes; not pinned in the suite, R-3) |

  - An error completes the `Future` and the guard is released (PF11).
- **`onPageFlowError` (S-8):**
  - `_run` catches only the view's flows. `_pageFlow` has no `catch` (PF11).
  - It reads `hooks().onError` at the error, and rethrows with the original stack when the callback is absent.
  - The hook's own error is reported too (PF9).
- **The guard is always released:**
  - on errors: PF9, PF10 and PF11, and R19 goes red;
  - when the view is removed while Print runs: PF15, and R17 goes red;
  - on `dispose()`: no write to a disposed notifier, by `isDisposed` and `_disposed`.
- **The `identical` checks:**
  - `exportOnce` checks the dialog's document before and after the bytes. `printOnce` checks after the font and after the bytes.
  - `exportPlan` passes no `document`, so its "before" check is trivially true. That is correct: nothing awaits before it.

## 3. Gates (rerun by me at `ffe0b9c`, real output)

| Gate | Result |
|---|---|
| Planner `flutter test --enable-vmservice --file-reporter json:…` | `05:46 +1707: All tests passed!`, exit 0 |
| Planner standing comparison | `packages/jet_cad_floor_plan: 1707 tests; the standing failures and skips, exactly`, exit 0 |
| Planner `flutter analyze` / format | `No issues found!` / `Formatted 265 files (0 changed)`, exit 0 |
| Demo `flutter test` / analyze / format | `00:43 +60: All tests passed!` / `No issues found!` / 8 files, 0 changed, exit 0 |
| Floor planner `flutter test` / analyze / format | `01:54 +212: All tests passed!` / `No issues found!` / 47 files, 0 changed, exit 0 |
| Engine `dart test` (exit 1) + comparison | `packages/jet_cad_2d: 1258 tests; the standing failures and skips, exactly`, exit 0 |
| Render `flutter test` (exit 1) + comparison | `packages/jet_cad_2d_flutter: 1390 tests; the standing failures and skips, exactly`, exit 0 |

## 4. Mutants

**Method:**

- Each mutant was applied by exact string replacement.
- The tests run were `test/host/page_flows_test.dart` and `test/host/view_test.dart`.
- Each mutant was reverted with `git show HEAD:<path> > <path>`, and the tree was then checked clean with `git status -uno`.
- A mutant that survived was then run against my probes (`rv_probe_test.dart`).

### Named and task-local (all red)

| Mutant | Applied as | Red in |
|---|---|---|
| M-H46 (shell's file command, button and chord) | the `export` `ShellCommand` runs a hook-less `PageFlows` on the controller's guard | PF6, plus PF9, PF12 and PF14 |
| M-H46 (service bar's button) | `service_view.dart:513` uses a hook-less `PageFlows` | PF6, PF9, PF12, PF14 |
| M-H46 (service chord) | `service_view.dart:476` uses a hook-less `PageFlows` | PF6 |
| T1-a | `_pageFlow` without `!pageFlowReady.value` | PF7, PF15 |
| T1-b | `exportOnce`'s check after the bytes removed | PF8 |
| T1-c (swallowed) | `report?.call(error)`, no rethrow | PF10 |
| T1-c (not reported) | `report(error)` removed | PF9 |
| T1-d | `answer ?? fromExportChoice(controller.exportChoice)` | PF12 |
| T1-e (swap) | d96 ↔ d300 in `toExportChoice` | PF13, PF6, PF14, PF4, PF2, PF12 |
| T1-e (by index after a reorder) | `FloorPlanExportDpi` declared `d300, d150, d96` and `ExportDpi.values[choice.dpi.index]` | PF1, PF13, PF6, PF14, PF4, PF2, PF12 |
| T1-f | `controller.exportChoice = choice;` removed | PF6, PF14, PF12 |

### My own (18)

| # | Mutant | Committed tests | My probe |
|---|---|---|---|
| R01 | `_pageFlow` returns `result`, not `_disposed ? busy : result` | **survived** | RV2 red |
| R02 | `_pageFlow` without `_settle?.call()` | **survived** | RV7 red |
| R03 | `_flowsFor` captures `onExportDialog` / `onPageFlowError` when the flows are made (not read at each call) | **survived** | RV1 and RV5 red |
| R04 | `exportOnce` ignores `document` (re-reads the active plan) | V11 red | — |
| R05 | `printOnce` without `cancelled()` | **survived** | RV3 red |
| R06 | `exportOnce` without `cancelled()` | **survived** | RV4 red |
| R07 | `PageFlows.dispose` disposes the shared guard | red (PF6, PF10, PF11, view_test and others) | — |
| R08 | `report(error); rethrow;` | PF9 red | — |
| R09 | the choice remembered only when the export succeeds | **survived** | RV5 red |
| R10 | `==` ignores `dpi` | PF1 red | — |
| R11 | `hashCode` ignores `dpi` | PF1 red | — |
| R12 | `exportPlan` exports the remembered choice, not `choice` | PF2, PF4, PF13 red | — |
| R13 | `exportOnce`'s check before the bytes removed (the implementer's T1-b‴) | survived | **survived** RV6 too (equivalent; see the rulings) |
| R15 | `fromExportChoice` format swapped | PF6, PF12, PF14 red | — |
| R16 | the hook given `FloorPlanExportChoice.initial`, not the remembered choice | PF6, PF12, PF14 red | — |
| R17 | the shared guard released only `if (!_disposed)` | PF15 red | — |
| R18 | `printPlan` ignores `name` | PF3 red | — |
| R19 | `_pageFlow` releases the guard inside `try` | PF11 red | — |

**Totals:**

- 11 named and task-local mutants, all red.
- 18 of my own: 11 red on the committed tests; 6 survived the committed tests and are red on my probes; 1 is equivalent (R13).

## Findings

**R-1 (Medium): R-5's "read at each call" is unpinned for both new view parameters.**

- *Evidence:*
  - R03 captures `widget.onExportDialog` and `widget.onPageFlowError` when `_flowsFor` runs. `_flows` is `late`, so the capture happens at the first build. The mutant passes all 65 tests of `page_flows_test` and `view_test`.
  - Every PF test passes the hook from the first pump.
  - The plan's Builds requires "`_flowsFor` passes `hooks` reading the current widget (R-5)". Both new doc comments promise it ("Read at each Export", "Read at each error"). P-3 makes it a principle.
- *Fix:* land RV1 (`rv_probe_test.dart`). It pumps the view without either parameter and uses Export once with the Material dialog, so the flows exist. It then rebuilds with a recording hook and `onPageFlowError`, and checks that:
  - `toolbar-export` calls the hook (no `export-dialog`, one export);
  - a printer that throws is reported once.

  Name R03 as its mutant.

**R-2 (Medium–Low): `exportPlan` / `printPlan`'s settle is unpinned.**

- *Evidence:*
  - R02 removes `_settle?.call()` from `_pageFlow` and survives the committed tests.
  - C-3 and the plan ("the guard, `settle()`, the bodies") and the doc comment ("Pending input is settled first") all promise it.
  - Without it, a host's Export button exports the plan without the number the user is typing in the Table section.
- *Fix:* land RV7. In the design mode, with `1` selected, it types `42` in `table-number` without committing, then calls `exportPlan(png96)`. It checks that:
  - `c.tables` holds `42`;
  - the bytes differ from those made before the typing;
  - the bytes equal those of a second export made after.

**R-3 (Low): `dispose()` during a flow is unpinned.**

- *Evidence:*
  - R01 (`return result`) survives. PF4 disposes only *after* the calls.
  - `printPlan`'s documentation says "false … after [dispose]". A dispose while the printer runs answers true under the mutant.
- *Fix:* land RV2. `printPlan` runs with a held printer; `dispose()` is called while it is held; the printer is released; the result must be `false`.

**R-4 (Low): the view's cancellation after the bytes is unpinned.**

- *Evidence:*
  - R05 (`printOnce` without `cancelled()`) and R06 (`exportOnce` without `cancelled()`) survive.
  - These are the base's `_disposed` checks after the bytes. This task moved them into the shared bodies, so they are the code it restructured.
  - V10 removes the view only while the *printer* runs, which is after the check.
- *Fix:* land RV3 and RV4.
  - RV3: `PageFlows` built as V11 builds it, the font cached, `flows.dispose` scheduled in a microtask right after `print`. Nothing is printed.
  - RV4: the view removed right after `toolbar-export` with a hook answering PNG at 96. `onExport` is never called.

**R-5 (Low): "remembered" is unpinned when the plan is replaced while the dialog is open.**

- *Evidence:*
  - The base remembers the dialog's answer before the `identical` check, so a replaced plan still updates `exportChoice`. The task keeps that order.
  - R09 (remember only on a successful export) survives the committed tests: V11's second half replaces the copy under the dialog but never reads `exportChoice`.
- *Fix:* land RV5. A hook calls `resetLayout()` and answers PNG at 300. Nothing is exported, and `exportChoice` is PNG at 300.

**R-6 (Informational): PF6 omits Cmd+E in the selection mode.**

S-1 says "Cmd+E and Ctrl+E, in both modes". Both chords come from one `kExportChords` loop, so no realistic mutant separates them. RV8 shows it works. Adding the chord to PF6's selection half is cheap and makes PF6 read as S-1 does.

**R-7 (Informational): the page is re-read after the dialog.**

- On the base, `export` captured `page` before the dialog and used it for the bytes. `exportOnce` now calls `exportPageOf(d)` again after the dialog, on the same document.
- They differ only if the page component of that very document changes while the dialog is open (a host's `undo()` from outside the modal). Then the new code plots the current page, or returns null if the page was removed. The base plotted the stale page.
- I consider the new reading at least as right. No fix is needed. If strict structural P-6 is wanted, `exportOnce` could take an optional `page`.

## Rulings on the implementer's findings

1. **The embedding fixture cannot be printed or written as a PDF: confirmed, accepted.**
   - `exportPlan(pdf150)` on `embeddingPlanJson()` raises `'package:pdf/src/pdf/format/num.dart': Failed assertion: line 32 pos 12: '!value.isNaN'` (my RVN probe at `ffe0b9c`).
   - `exportPdfBytes` / `exportPagePdf` are unchanged from the base, so the base fails the same way.
   - `finitePlanJson()` keeps every turned, mirrored and non-uniformly scaled table 40 m off the origin, plus the hidden and locked layers. It is not a degenerate fixture.
   - The follow-up (a finite variant of the shared fixture, or the PDF sink skipping non-finite text) belongs in the slice's open points, not in this task.
2. **The name and the printer are read earlier: accepted, recorded.**
   - P-3 asks for a view parameter to be read "at each build or press, never captured". Reading at the press, or after the dialog, satisfies it.
   - My RVB2 probe (a rebuild with a new `exportName` right after the tap) gives the same name, `eski`, on the base and on the task. In tests the PDF bytes complete within microtasks.
   - The two differ only if a rebuild lands while real asynchronous byte work is in progress. No fix is required.
3. **The controller's guard is released after the view is gone: accepted, and it is needed.**
   - With S-7's shared guard, the base's "skip once disposed" would leave the controller unable to export or print for good.
   - PF15 pins the release (my R17 goes red). The `isDisposed` check prevents a write to a disposed notifier.

**The equivalent-mutant claim (T1-b‴, my R13): accepted, with stronger evidence.**

- RV6 lets a hook stay open while the selection copy is replaced by `resetLayout()`. Two frames pass, so the old copy is disposed (`copy.commands.isDisposed` is true).
- It then answers PDF at 150, and in a second pass PNG at 96.
- Under R13 the flow renders the disposed copy in both formats. It throws nothing (`onPageFlowError` hears nothing, `takeException` is null), and the check after the bytes still drops the result.
- The only effect is wasted work, so the mutant is observably equivalent.

## Probes for the fixer

All probes are in `scratchpad/rv-s4t1/`:

- `rv_probe_test.dart` (RV1–RV9) imports `page_flows_test.dart`'s helpers with the prefix `pf`. All nine pass at `ffe0b9c` (`00:08 +9: All tests passed!`).
- RV1–RV5 and RV7 are the killers for R-1 to R-5. They should be folded into `page_flows_test.dart` with PF numbers, in the file's style.
- RV6, RV8 and RV9 are optional.
- `rv_base_probe_test.dart` (RVB1–RVB3) compiles against both the base and the task. It was used for the P-6 checks.
