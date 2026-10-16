# Task 5 report (O3 pageFlowBusy, O4 same-frame re-word)

Status: DONE. Commit 7cf2e6eb `feat(plan): pageFlowBusy; tool notices re-word in the same frame`.

## O3
- `PlanPageFlows.busy` (set in acquire, cleared in release, disposed) exposed as public `PlanController.pageFlowBusy` (ValueListenable<bool>); `pageFlows` stays @internal. No barrel change.
- Demo: `DocumentHostState._busy = session.busy || controller.pageFlowBusy`; file callbacks and the exit request use it; `_flow`'s nesting check and the wrappers still use session.busy (refusal semantics kept).
- Tests: packages/jet_cad_2d_plan/test/export/page_flow_busy_test.dart (editor export through dialog/bytes/onExport, cancel, error, print incl. throw, controller export/print, refused second call). apps/architecture_demo/test/export/busy_test.dart: N6-gap -> N6-closed (New and exit do nothing in the gap; the export then still reaches the save panel and writes).

## O4
- `PlanLocaleScope.push` now calls new @internal `PlanController.adoptLocale` in didChangeDependencies: the locale value is taken in with no notification (private `_AdoptingLocale`, notifies on `reportLocale` once per differing told value), so the editor's same-build status line words the notice in the new language. Listeners still hear it after the frame (W-L4 unchanged).
- The 3a pin is TN-relocale in packages/jet_cad_2d_plan/test/editor/editor_notice_test.dart: the extra `pump()` after each pumpWidget removed.

## Mutations (run on committed code, reverted, git diff --quiet)
1. demo drops `|| pageFlowBusy`: N6-closed red.
2. EditorPageFlows releases before `sink(export)`: PB-export red.
3. acquire does not raise busy: PB tests red (5 fail).
4. push does not adopt (deferred again): TN-relocale red.

## Gates (real last lines)
- jet_cad_2d_plan: `All tests passed!` (+1578 at last count, with --enable-vmservice; new file added after), analyze No issues, format 0 changed.
- jet_cad_2d_integration (--enable-vmservice): `01:01 +228: All tests passed!`, analyze/format clean.
- apps/architecture_demo: `00:33 +176: All tests passed!`, analyze/format clean.
- Kit packages untouched, not run.

## Concerns
- The first full plan run preceded one lint fix (curly braces) in the new test; analyze/format re-run clean, and the 5 new tests re-run green, but the full plan suite was not re-run after that test-only edit.
