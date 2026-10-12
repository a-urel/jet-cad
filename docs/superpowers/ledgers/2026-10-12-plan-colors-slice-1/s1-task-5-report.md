# Task 5 report: CHANGELOG, guide, STATUS, CI, exit gate

Status: DONE_WITH_CONCERNS (all gates green; one standing macOS difference, one small guide deviation).

## Doc edits
- `CHANGELOG.md`: `## Unreleased` replaced verbatim with the brief's text.
- `docs/host-guide.md`:
  - capabilities table: row `| recolor | yes | yes | no |` after the `mirror, reshape, changeLayer` row.
  - "Field by field": the `recolor` (*since 0.6.0*) bullet after the `move, rotate, mirror, ...` bullet (before `undo, export, print`).
  - section 11: the schema 9 bullet gained "A plan saved by 0.6.0 is at **schema 10**, which 0.5.1 and every older release refuse; a schema 9, 8 or 7 plan opens here unchanged."
- `STATUS.md`: the Plan colours "In flight" entry now says Slice 1 is implemented on `spec/plan-colors`, each task reviewed, next its whole-branch review, then Slice 2 (tables). "Owed to the human" gained: native German and Turkish read of the Colour row's words (PC-10), and a look at a coloured room on the light and dark canvas.
- `check_guide`: `docs/host-guide.md: all 48 code blocks are in the host probe`, exit 0.

## CI edit
`.github/workflows/ci.yml`: after the v0.4.0 step, a step "The 0.5.1 host probe against this commit" running `tool/ci/old_host_probe.sh v0.5.1`.

## Gates (all run at HEAD dd35caf, before the docs commit; docs do not affect them)
- jet_cad_2d `dart test`: exit 1, the two standing fingerprints only (generate_document_test: "both text fractions default to zero and change nothing", "the default document is the one Plan 2 measured, byte for byte"). `expect_failures`: `packages/jet_cad_2d: 1290 tests; the standing failures and skips, exactly`, exit 0. `dart analyze`: `No issues found!`. Format: `Formatted 175 files (0 changed)`.
- jet_cad_2d_flutter: `flutter test` exit 1 (`+1432 ~1 -5: Some tests failed.`); `expect_failures` exit 1 with exactly two lines: `standing failure passed or did not run: test/golden/text_lod_ladder_golden_test.dart :: text lod ladder rung 1 (RenderBackend.canvas)` and `... rung 2 ...`. That is the recorded macOS standing difference (rungs 1-2 pass), no other difference. analyze `No issues found!`; format `Formatted 228 files (0 changed)`.
- jet_cad_2d_gpu: `00:00 +20: All tests passed!`; `expect_failures`: `packages/jet_cad_2d_gpu: 20 tests; the standing failures and skips, exactly`, exit 0; analyze clean; format 10 files (0 changed).
- jet_cad_floor_plan (`--enable-vmservice`): `01:59 +1948: All tests passed!`; analyze clean; format 288 files (0 changed).
- jet_cad_restaurant_symbols: `00:01 +97: All tests passed!`; analyze clean; format 15 files (0 changed).
- apps/floor_planner (`--enable-vmservice`): `00:35 +212: All tests passed!`; analyze clean; format 47 files (0 changed).
- apps/restaurant_demo: `00:19 +68: All tests passed!`; analyze clean; format 9 files (0 changed).
- tool/ci: `00:04 +63: All tests passed!`; analyze `No issues found!`; format 11 files (0 changed); `check_guide` as above.
- Host probe (`tool/ci/host_probe.sh file:///Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-colors dd35caf0...`): `host probe: no GPU renderer, no build hook; build/web is  42M`, exit 0.
- Old-host probes, each exit 0: `old host probe: v0.3.0's main.dart analyses against dd35caf09bfc...`, same for `v0.4.0` and `v0.5.1`.

## Deviations
- Section 11's schema 9 bullet said "A plan saved by 0.4.0 or later is at schema 9", which the new sentence would contradict; I changed "or later" to "0.5.0 or 0.5.1" (read: "0.4.0, 0.5.0 or 0.5.1") so the bullet stays true. Nothing else changed in it.
- The probes were run with the literal path and full SHA (worktree guard), not `$PWD`.
- Commit trailer names Claude Sonnet 5.5 (the model that did the work), not the brief's Opus 5.5 text.

## Concerns
- None beyond the standing macOS difference above. `git status` was clean after the commit (no probe leftovers, no analysis_options.yaml).

## Fix round 1

Finding (Important): `docs/host-guide.md:1122` (table-data section) said "A plan saved by this release is at **schema 9**".

Changes:
- `docs/host-guide.md:1122`: now "A plan saved by this release is at **schema 10** (0.4.0 to 0.5.1 saved 9), data or not ([§ 11](...))".
- `grep -n -i "schema" docs/host-guide.md` shows no other sentence claiming this release saves schema 9: the remaining hits are 1122 (fixed), section 11's Schema 8 / Schema 9 bullets (historical, about 0.2.0 to 0.5.1) and the new 0.6.0 / schema 10 sentence. Nothing else needed a change.
- `.github/workflows/ci.yml`: the comment above the old-host probe steps now ends "0.4.0 (the embedding API, 8367010) followed its tag, and 0.5.1 is the last release that saves schema 9."

Command: `dart run tool/ci/check_guide.dart` (repo root), output:
`docs/host-guide.md: all 48 code blocks are in the host probe` (exit 0).

Commit: "docs: the guide says this release saves schema 10" (only those two files; tree clean afterwards).
