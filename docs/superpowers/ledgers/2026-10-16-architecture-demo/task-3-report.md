# Task 3 report

Status: DONE_WITH_CONCERNS. Commit: 15cf9ba5 `feat(demo): the file layer and the app's words, ported with their tests`.
Gates (apps/architecture_demo): flutter test "+25: All tests passed!"; flutter analyze "No issues found!"; dart format exit 0. No analysis_options.yaml committed; main.dart untouched (AppStrings has no LocalizationsDelegate).

## Files
lib: document_files{,_io,_web,_stub}, exit_guard{,_web,_stub}, app_strings (copied; printFailed -> pageFlowFailed en/de/tr as briefed; header reworded). None of the copied files imported jet_cad_floor_plan, so no cancel word was needed. test/support/app_fakes.dart: FakeDocumentFiles + FakeExitGuard (one copy).

## Audit rows
- FK1-FK6, DK-L (document_files_kind_test): PORT, ported verbatim (imports only).
- DF1-DF8 (document_files_test): PORT, verbatim.
- DS1, DS2 (sources): PORT, verbatim (they read lib/ of the new app).
- DS3: moved to Task 4. It pins `createFiles(askName:, typeLabel:)` and `this.createFiles = createDocumentFiles` in main.dart; the ruling forbids adding that seam here. Task 4 must port it against the new main.dart.
- AW3: PORT, verbatim.
- AW1, AW2, AW4: moved to Task 4. They pump the whole app and read host UI (toolbar-open-sample, untitled name in the host, createFiles seam) that does not exist before Task 4. Not weakened or skipped silently; the file header says so. Their word-level content is pinned by new AW-locale (tr openSample/untitled, de untitled/saveAs, fr falls back to English) against a MaterialApp harness with planLocalizationsDelegates. The library-tooltip halves ('Yeni (Ctrl+N)' etc.) and the 'Duvar' find belong to the Task 4 app-level port.
- New AW-pageflow: pageFlowFailed en/de/tr.

## Mutations (each run on committed code, reverted with git checkout, `git diff --quiet` clean after)
- M-png-ext (png extension 'jpg'): red FK1, FK4.
- M-trim (typed.trim() removed): red FK1, FK2, DF1.
- M-mime (jetplan mime text/plain): red FK4.
- M-iogroup (io save panel fixed to kJetplanTypeGroup): red DS1.
- M-webmime (web blob fixed mime): red DS2.
- M-dede (de pageFlowFailed = en word): red AW-pageflow.
- M-trlabel (tr untitled 'Untitled'): red AW-locale.
- M-inplace (io writesInPlace false): red DF8.

## Concerns
- AW1/AW2/AW4/DS3 are carried to Task 4 (above).
- Task 4 needs a cancel word for the name prompt (_askName used FloorPlanStrings.cancel in the old main): PlanStrings has `cancel`; not needed by the copied layer files.
