# Task 1 report: PaperPalette.guide

Status: DONE. Commit: see `git log -1` on claude/alignment-guides-50cacb ("feat(flutter): PaperPalette.guide for alignment guides").

Implemented: `PaperPalette.guide` (Color?), `guideColor` getter, `lightGuide`/`darkGuide` static consts, `withGuide`; `light`/`dark` set `guide`; `withSelection`, `==`, `hashCode` carry it (no toString exists). Docs on `preview`/`guide` per brief. CHANGELOG `## Unreleased`.

TDD: RED = new test file failed to compile ("method 'withGuide' isn't defined"). GREEN = `flutter test test/canvas_palette_test.dart` -> `+38: All tests passed!`.
Existing equality test built copies via `paperFrom` (no guide), so it was updated to `.withGuide(dark.guide!)` on the copy, still checks every other field.

Mutations (each red, then reverted; file back to green `+38`):
- withSelection drops guide: `withSelection keeps the guide [E]`, `+37 -1`
- `==` ignores guide: `guide takes part in == and hashCode [E]`, `+37 -1`
- luminance test inverted (`< 0.5`): `an unset guide falls back by the grid's luminance [E]`, `+37 -1`

Gate (jet_cad_2d_flutter): flutter test: only the 7 standing failures (text_ladder rungs 1-5, text_lod_ladder rungs 1-2, all in tool/ci/standing_failures.txt), final `+1457 ~1 -7`; analyze: No issues found; format: 0 changed.
Files: canvas_palette.dart, canvas_palette_test.dart, CHANGELOG.md. No analysis_options.yaml staged.
Concerns: none.
