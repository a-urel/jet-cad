# Task 6 report: export and print

Status: DONE_WITH_CONCERNS

Commits:
- e9d7c93a feat(demo): export writes, print and the busy wrappers
- 1b133ff4 test(demo): export and print, ported; N6

Gates (apps/architecture_demo), real last lines:
- flutter test: `00:32 +140: All tests passed!`
- flutter analyze: `No issues found! (ran in 3.9s)`
- dart format --output=none --set-exit-if-changed .: `Formatted 36 files (0 changed) in 0.07 seconds.` (exit 0)
No library file changed (temporary library mutations M-EX9b and M-PR8 were reverted; `git diff --quiet` clean).

## What changed
- lib/busy_wrappers.dart: `busyExportDialog`, `BusyPagePrinter`.
- lib/document_host.dart: `onExport` -> public `exportFlow(PlanExport)` (a flow; kind from the name's extension: pdf, png, else ArgumentError shown as `exportFailed`; `saveLocation(name, kind:)` then `write(place..., kind:)`; cancel writes nothing), `onExportDialog`, `printer` (both made once, `late final`), `onPageFlowError` -> `pageFlowFailed` dialog.
- pubspec.yaml: bare family Roboto from `packages/jet_cad_2d_plan/fonts/Roboto-Regular.ttf` (EF12).
- Name widget `maxWidth` 160 -> 144 and document_commands_test.dart adjusted (DC1-open bar order now has `export`; DC12 asserts 144; DC12c floor 800 px, measured: 799 overflows by 1 px). Cause: the Export button now exists (it needs `onExport`), which added ~16 px at 800 px. This edits a Task 4/4b test; the test's own comment had anticipated the Export button.

## Decisions and deviations (please read)
1. **Wrappers refuse while busy (deviation from the brief's code).** The brief's wrappers nest (`outer = busy.value`). With nesting, Export or Print pressed during a held Save As write opens the dialog / prints (the library's Export and Print are enabled and its guard is free; the app's busy does not reach them). That is a second flow during a write, the opposite of decision 5's intent and the old EX10/PR5. So `busyExportDialog` returns null (the library reads it as a cancel) and `BusyPagePrinter.print` returns without printing when busy is already up. Tests EX10-open, PR5-open, the wrapper units pin it; mutations M-W1, M-W2. If you want the brief's nesting back, those four tests are the ones to change.
2. **Exact export sequence** (also in the comments in busy_wrappers.dart, document_host.dart `exportFlow`, busy_test.dart header): dialog runs inside the busy span, which ends when it answers; the library then makes the bytes with ITS guard held and the app NOT busy; then it calls `onExport` -> `exportFlow` (busy again, covers the save panel and the write). 
3. **Concern: the gap.** Between the dialog closing and `onExport` (bytes being made; PNG at 300 dpi takes about a second) the app is not busy, and the library has no hook (`pageFlows.ready` is `@internal`). A New/Open/Save started there runs. N6-gap pins the outcome: New replaces the plan, the library drops the export (document no longer identical), nothing asked, nothing written, busy ends false. Open sample/Open likewise; a Save in the gap writes its own file and the export then writes too (independent). Holding busy across the gap would need the library to signal the end of a flow (a field on the library's callbacks or a public ready listenable); holding it from the wrapper risks a permanently busy app when the export returns null (page removed by undo during the bytes). I did not do that. N6-write pins that from `onExport` on, nothing starts.
4. `onPageFlowError` shows the dialog unheld (as the brief's code): the printer's busy span has ended when the library reports a throw, so busy is false while the error dialog is up (PR3-open says so). The dialog is modal and the file chords are consumed above it. `exportFlow` errors keep busy while the dialog is up (EX8).
5. `exportFlow` is public (like the other flows) so the extension rule is testable (the library only makes pdf/png).

## Audit rows
export_flow_test.dart (16): 
- EX1 SPLIT: EX1-open (writes flat.pdf, kind pdf, MediaBox, content stream equals the export command's, camera turned off the sheet); intent PF13 page_flows_test.dart:441
- EX2 COVERED, checked: packages/jet_cad_2d_plan/test/export/registry_test.dart:115 (X-4)
- EX2b COVERED, checked: registry_test.dart:260 (X-8), page_flows_test.dart:849 (PF17)
- EX3 SPLIT: EX3-open; intent PF13 page_flows_test.dart:441
- EX4 COVERED, checked: page_flows_test.dart:479 (PF14), :627 (PF21), plan_export_types_test.dart:8 (X-1)
- EX5 SPLIT: EX5-open; intent PF12 page_flows_test.dart:414
- EX6 PORT: EX6 (Escape)
- EX7 PORT: EX7
- EX8 PORT: EX8 (+ EX8b, a throwing save panel, added)
- EX9 COVERED, checked: editor/plan_editor_test.dart:360 (ED-X1), shortcuts/plan_shortcuts_test.dart:308 (KB-6), page_flows_test.dart:161 (PF3)
- EX9b PORT: EX9b (page removed, undone, redone; buttons follow)
- EX10 SPLIT: EX10-open (Export during a held Save As does nothing); intent PF7 page_flows_test.dart:217
- EX11 COVERED, checked: editor/editor_bar_test.dart:385 (PF5), :402 (PF6)
- EX12 PORT: EX12 (Cmd and Ctrl; also asserts no print queued)
- EX13 SPLIT: EX13-open (kind from extension; .svg and none are errors); intent PF2 page_flows_test.dart:143, X-1
- EX14 SPLIT: EX14-open (Untitled.pdf, kind pdf, %PDF); intent PF13, EF4 (export/export_font_test.dart:38)

print_flow_test.dart (10):
- PR1 SPLIT: PR1-open (name `flat`, A4 pt, content stream equals the export command's, MediaBox); intent X-7 registry_test.dart:240, PF3. (Separator half: not in the architecture kit's plan; I separator/separator_export_test.dart.)
- PR2 COVERED, checked: registry_test.dart:240 (X-7)
- PR3 SPLIT: PR3-open (neutral title, thrown text, one dialog); intent PF9 :324, PF11 :388
- PR4 COVERED, checked: ED-X1 plan_editor_test.dart:360, KB-6 plan_shortcuts_test.dart:308, PF3 page_flows_test.dart:161
- PR5 SPLIT: PR5-open (Print during a held write prints nothing, works after); intent PF7
- PR6 PORT: PR6 (Cmd and Ctrl, once, name `flat`)
- PR7 COVERED, checked: plan_editor_test.dart:133 (ED-3), editor/editor_words_test.dart:134 (SW1)
- PR8 PORT: PR8 (printing channel; into the app, as the audit says)
- PR9 COVERED, checked: registry_test.dart:260 (X-8)
- PR10 SPLIT: PR10-open (held job: Save does nothing, second Cmd+P prints nothing, library holds Print/Export buttons, busy ends); intent PF7

export_end_to_end_test.dart: E2E PORT (Open sample, Save, PDF, PNG 150, Print, Save byte-identical; `controller.dirty` false).

export_font_test.dart: EF1, EF2 COVERED, checked: packages/jet_cad_2d_plan/test/fonts/plan_assets_test.dart:55 (W-F1). EF3 DROPPED. EF9 SPLIT: EF9-open (one controller kept across New, Open sample, Open; export embeds the font after each). EF10 COVERED, checked: export_font_test.dart:38 (EF4), page_flows_test.dart:441 (PF13). EF11 PORT (source pin: ensureInitialized < await ensurePlanFonts < registerFontLicences < runApp). EF12 PORT (pubspec).

New N6 (busy_test.dart): N6-dialog, N6-print, N6-exit, N6-write, N6-gap, N6-once, and three wrapper unit tests.

## Mutations (all on committed code; reverted with `git checkout -- <file>`, `git diff --quiet` passing each time)
- M-N6a pass `showPlanExportDialog` directly: red N6-dialog, N6-exit, EX5-open, EX10-open
- M-N6b pass `widget.printer` directly: red N6-print, N6-once, PR5-open, PR10-open
- M-W1 dialog wrapper without the busy refusal: red wrapper unit "during another flow", EX10-open
- M-W2 printer wrapper without the refusal: red BusyPagePrinter unit, PR5-open
- M-W3 dialog wrapper never clears busy: red N6-dialog, N6-exit, N6-gap, N6-write
- M-W4 printer wrapper never clears busy: red N6-print, BusyPagePrinter unit, E2E, PR1-open
- M-E1 exportFlow not a flow (no busy): red N6-write, EX8
- M-E2 png written as pdf kind: red EX3-open, E2E
- M-E3 unknown extension falls back to pdf: red EX13-open
- M-E4 cancelled panel still writes: red EX7
- M-E5 write failure titled pageFlowFailed: red EX8, EX8b, EX13-open
- M-E6 page-flow error titled exportFailed: red PR3-open
- M-E7 `_printer` a getter (made per build): red N6-once
- M-E8 exportName 'plan' not the session's: red EX1-open, EX3-open, E2E, N6-write
- M-E9 write empty bytes: red EX1-open, EX3-open, EX14-open, E2E
- M-E10 write without kind: red EX1-open, EX3-open, EX14-open, E2E
- M-E11 saveLocation without kind: red EX1-open, EX3-open
- M-E12 onExport a no-op: red EX1-open, EX3-open, N6-write, E2E
- M-F1 licence registration removed from main: red EF11
- M-F2 `ensurePlanFonts` not awaited: red EF11
- M-F3b pubspec family renamed: red EF12 (a path mutation breaks the asset build instead, not EF12)
- M-F4 controller a getter: red EF9-open
- Temporary library mutations, reverted: M-EX9b (Export flag ignores the page): red EX9b; M-PR8 (`dynamicLayout: true`): red PR8.
- Not mutated: EX6, EX12 (library behaviour: dialog Escape, chord consumption above a route; no app code to mutate).

## Ported case red against the library
None.

## Fix round 1
Commit: e0e19eda test(demo): export and print keep the old assertions
- EX12: `chordHandled` added to test/support/app_rig.dart (the old helper); asserted `isTrue` for Cmd/Ctrl+P and +E under the open dialog, alongside the effect checks. Mutation M-chord (the `kFileChords` consume removed from main.dart's builder): red both EX12 cases.
- EX1-open, PR1-open: the PDF's text runs must equal the plan's live TEXT entities (`liveTexts`, read from the document apart from the exporter), and every path vertex lies on the sheet (`expectInsideSheet`). `// Decided:` comments name what has no premise left (instance colour/lineweight/placement, separator, `fontLoads == 1`: covered by jet_cad_2d_flutter export_pdf_test, PF13, SP-export-pdf; no font injection). Temporary library mutations, reverted: M-place (page origin shifted 100000 in the PDF exporter) red EX1-open, PR1-open; M-text (all objects omitted) red EX1-open, PR1-open.
- EF12: compares the declared asset's bytes with the vendored golden font. M-ef12 (one byte dropped) red.
- Cosmetics: busy_test.dart import order; document_commands_test.dart comment lines wrapped (other files' long comment lines are from earlier tasks, untouched).
Each mutation reverted; `git diff --quiet` clean. Gates: see the task's final lines below.
