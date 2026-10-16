# Task 5 report: the exit, the title and the language

Status: DONE. Commits: 7d1bcba0 feat(demo): the exit request, the exit guard and the untitled name; 9ad321d6 test(demo): exit, title and language.

## Decisions
- Exit settle route: a discarded `controller.save()` (in try/catch; a throwing save is not an exit blocker, the dialog's Save reports it), then `_mayDiscard` yields one microtask and reads `controller.dirty`. No library public settle exists.
- Teardown carry-over: no error found, so no host guard added. A dialog left up when the app unmounts never completes (flow future stays pending, touches nothing; a first attempt that popped it in the same turn ran its continuation while still mounted, so it proved nothing). The live path is a held Save: write finishes after unmount, `_write` skips the disposed controller, `_mayDiscard` loops, `_askToSave`'s existing `!mounted` check cancels. Pinned by RP-teardown (new/open-sample/open) in document_replace_test.dart.
- N5: `tester.platformDispatcher.localesTestValue` reaches the app; no `locale:` seam added. Bar updates in the first pump; the title needs two pumps (host rebuild, post-frame nameChanged, app rebuild).

## Audit rows (document_exit_test.dart)
EX1-EX7, EG1: PORT, all pass (8). Differences: controller.document/dirty replace session; Wall tool edits; EX5 types the kit's `property-thickness`.

## Mutations (each run on committed code, reverted with git checkout, git diff --quiet clean)
- exit does not settle (`controller.save()` removed): EX5 red.
- exit ignores busy: EX4 red.
- `_exitListener.dispose()` removed: EX2, EX3, EX4, EX5 and 2 more red.
- exit always answers exit: EX2, EX3, EX5 red.
- dirty listener for the guard removed: EG1 red.
- `_exitGuard.dispose()` removed: EG1 red.
- `_askToSave` without `mounted`: RP-teardown x3 red.
- M-N5 untitled name set once only: N5 red.
- M-N3 title dotted while named and redoable (undo case stays dotted): N3 red.

## Gates (apps/architecture_demo)
- flutter test: `+107: All tests passed!`
- flutter analyze: `No issues found!`
- dart format: `Formatted 29 files (0 changed)`

## Concerns
- None blocking. `save()` as settle also records the encoded state; harmless since every markSaved follows its own save.
