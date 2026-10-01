# Task 1b brief — test-only follow-up to Task 1's review
Read common.md first. Scratch prefix: /tmp/claude-0/-home-user-jet-cad/436a473c-2fd9-5dea-b1ee-ba84afc1ba81/scratchpad/b1b/.
Read the review .superpowers/sdd/symbol-palette/task-1-review.md (findings 1-3) and apply them in apps/floor_planner/test/symbols/symbol_search_test.dart ONLY (no lib change):
1. substring matching: add single-field tests with mid-word terms from the real asset that hit only one field, each through the hitsOnly self-check: 'seats' (name only), 'top' (tag 'worktop' only), 'room' (category only, incl. Bathroom) — verify each claim in the test itself.
2. key: add the key to fieldsHit/hitsOnly; add a hand-built entry with a term found ONLY in its key and assert the search does NOT find it.
3. case: give the hand-built fixture a mixed-case tag (e.g. 'Reading') and find it with 'reading' and 'READING'.
Fire and record (real output): name/tag/category contains->startsWith (each), match on key instead of name, key also searched, tags compared case-sensitively — each must now be RED. App gate (count + new), analyze, format. ONE commit: 'test(app): symbol search pins substrings, the key and tag case (1b)'. Append a 'Task 1b' section to task-1-report.md.
