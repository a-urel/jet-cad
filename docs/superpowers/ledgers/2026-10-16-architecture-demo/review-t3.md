# Review T3 (file layer and words)

Verdict 1 Spec compliance: PASS. Verdict 2 Quality: PASS.

## Evidence
- Lib files: `diff` old vs new is empty for all 7 document_files*/exit_guard* files; app_strings differs only in header word, printFailed -> pageFlowFailed (en/de/tr exactly the briefed strings). No stale `printFailed` in apps/architecture_demo.
- Tests: document_files_test, _kind_test differ from old only by header, package import and fake import. _sources_test differs only by header and DS3 removal. app_words_test: AW3 verbatim; AW1/AW2/AW4 moved (need FloorPlannerApp-equivalent wiring, ruling allows); AW-locale and AW-pageflow added.
- Fakes: old fake_document_files + fake_exit_guard concatenate into test/support/app_fakes.dart (diff is import lines only). One home; no other `class Fake*` in the app.
- Gates rerun: `flutter test` last line "00:01 +25: All tests passed!"; `flutter analyze` "No issues found! (ran in 3.4s)".
- Mutations run on committed code, reverted, `git diff --quiet` clean: png ext 'jpg' -> red FK1, FK4; de pageFlowFailed = en word -> red AW-pageflow (suite "+7 -3").

## Critical
none

## Important
none

## Minor
1. app_words_test.dart:1-7 / sources_test: moved cases AW1, AW2, AW4, DS3 must be carried by Task 4's brief; AW-locale only pins words, not the toolbar tooltips ('Yeni (Ctrl+N)', 'Duvar', 'toolbar-print') nor AW4's read-at-each-call behaviour. Fix: ensure Task 4 brief lists AW1/AW2/AW4/DS3 explicitly with full original assertions (the ledger should record it).
2. app_words_test.dart AW-locale: no assertion that a mutation of en `openSample` is caught beyond the fr fallback; acceptable.
3. Header comments in the three document_files tests are single lines >80 chars (format passes; style only).
