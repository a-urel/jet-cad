# Review T5 (exit request, exit guard, untitled name; N3, N5; RP-teardown)

Verdict 1 (spec compliance): PASS. Verdict 2 (quality): PASS WITH FINDINGS. 0 Critical, 0 Important, 2 Minor.

## Spec compliance
- `_onExitRequested` (document_host.dart:147-158) keeps the old order: busy -> cancel with no flow, so no second dialog; settle; `_mayDiscard` (clean exits, dirty asks). Guard armed from `_controller.dirty` in initState plus a listener, removed and disposed in dispose. EG1 pins the armings sequence.
- All 8 PORT rows (EX1-EX7, EG1) are present with assertions at least as strong as the old file. I diffed them case by case. New extras: EX4 and EX5 also check identity/thickness. EX5's focus premise uses a runtimeType name match because the type is not exported; the strength is the same.
- N3 and N5 are as the brief specifies, including the Turkish editor word in the same pump and the German switch keeping the file's name.
- RP-teardown x3 (new, open-sample, open) closes the carry-over. The premise guards (isDisposed, controller disposed) make it non-degenerate.

## Quality
Mutations I ran on the committed code, each reverted with `git checkout --` and `git diff --quiet` confirmed:
- `_controller.save()` commented out in the exit: EX5 red (only).
- busy check removed: EX4 red (only).
Gates in apps/architecture_demo:
- flutter test: `00:23 +107: All tests passed!`
- flutter analyze: `No issues found! (ran in 4.0s)`
- dart format: `Formatted 29 files (0 changed) in 0.06 seconds.`

### Settle by discarded `save()`: side effects (judged acceptable)
- Throw: caught. A damaged plan makes `save()` throw `damagedUnsavable`, and the exit then asks as it stands. That is the right call.
- Recorded state: `_encodedState` is overwritten (plan_controller.dart:659). Every `markSaved` in the app follows its own `saveStep` `save()`, and busy blocks the exit during a held write, so the exit's record can never be mistaken for a write's. No bug.

## Minor
1. document_host.dart:150-154 and plan_controller.dart:645-668: on a damaged plan each exit request appends a `damagedUnsavable` `KitDiagnostic` (a duplicate per request, even when the user cancels). Also `_encode` clears `_unsettled` (plan_controller.dart:675), so an unsettled empty plan that was exit-requested then cancelled would stop following the locale. The second needs a dirty unsettled plan and is unlikely. Fix: when Task 4b's library route (a public settle) exists, use it; until then, say so in the comment. Nothing to change now.
2. document_host.dart:146 comment says "Save shows the error" but no test pins the throwing-save exit path (a damaged plan at exit). Fix: either add a damaged-plan exit case or drop the claim. Mutation: removing the try/catch is not caught by any test.
