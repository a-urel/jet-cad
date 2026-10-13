# Task 5 report

Commit: d7f81056 feat(kit): SymbolLibrary.merge, KitNames and KitProblem (K3, K4)

Implemented merge (symbol_library.dart), kit_names.dart, kit_problem.dart, model.dart exports, and the three test files, verbatim from the brief (tests reformatted by dart format).
Note: tests and implementation were written together, so no separate RED run was recorded (brief Step 2 skipped); the mutation checks below prove each test goes red.

Gate: `flutter test` -> "All tests passed!" (169); `flutter analyze` -> "No issues found!"; `dart format --output=none --set-exit-if-changed .` exit 0.

Mutations (on committed files, each reverted with git checkout, git diff --quiet exit 0), red lines as printed:
- M-M1: `00:00 +0 -1: M1 entries in order, kits and categories in first appearance [E]`
- M-M2: `00:00 +1 -1: M2 a key@version in two libraries names both, by position and kit [E]`
- M-W2a: `00:00 +1 -1: W2 a symbol name: the locale, then English, then the stored name [E]` (also W4 red)
- M-W2b: `00:00 +1 -1: W2 a symbol name: the locale, then English, then the stored name [E]`
- M-W5a: `00:00 +4 -1: W5 merge joins locales and keeps the earlier word on a clash [E]`
- M-W5b: `00:00 +4 -1: W5 merge joins locales and keeps the earlier word on a clash [E]`
- M-W3: `00:00 +0 -1: W1 the word ids [E]` and `00:00 +1 -2: W3 a category: under its kit, the locale, then English, then itself [E]`
- M-KP1: `00:00 +0 -1: KP1 value equality over the code and the message [E]`
