# Fix wave re-review

Verdict: Approved.

- A1 done; dialog-wiring-unit-only fallback sound (route dies with navigator). Mutation run by me: printer guard removed -> BU-teardown-print red; reverted, git diff --quiet.
- A2 done; test-owned controller fallback sound (makes the wrongly-run load visible). Mutation run by me: `!mounted` removed -> OP-teardown red; reverted, clean.
- A3 done (check after panel; post-write check already existed at _write). A4 done. A5: guard `!damaged` in place, documented; no red test (damaged plan not producible publicly): acceptable, minor.
- A6, B1-B4 present in diff with named mutations; nothing from the old T7 weakenings (SS7 ghost, SS13 dispose, SS14 anchor, WE3 position, cache match) remains dropped. B1 tolerance 250 is loose but mutation-checked.
- C1/C2 done (renamed/thin helpers are justified).
- D: smoke test drives real ArchitectureDemoApp, real-disk DirectoryFiles only; asserts file text == c.save() before and after New/Open, 11 walls. PNG copied by hand: acceptable. Macos run not re-run per instructions.
- App `flutter test`: `00:32 +176: All tests passed!`; `flutter analyze`: `No issues found! (ran in 3.5s)`. git status clean.
