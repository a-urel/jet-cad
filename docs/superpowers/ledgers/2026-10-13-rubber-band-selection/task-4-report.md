# Task 4 report: demo, guide, CHANGELOG, specs' notes, STATUS, exit gate

Status: DONE (one commit, `d15385bb6536599bde0c710c926328d60a38aec8`, on `feat/rubber-band`). Working tree clean afterwards; no `analysis_options.yaml` committed.

## Changes per file

- `apps/restaurant_demo/lib/main.dart`: `bool floorBand = false;` beside `longPressMenu`; `floorDrag: floorBand ? FloorPlanFloorDrag.band : FloorPlanFloorDrag.pan` on the view; a `SwitchListTile` keyed `'floor-band'` after `'long-press-menu'` (service options).
- `apps/restaurant_demo/lib/demo_strings.dart`: `floorBand` in the base class and English ("Floor drag: select"), German ("Ziehen auf dem Boden: Auswählen"), Turkish ("Zeminde sürükle: Seç").
- `apps/restaurant_demo/test/demo_test.dart`: D23. In service mode the `FloorPlanView` found by type has `floorDrag == pan` before, `band` after the tap on `floor-band`, `pan` after a second tap (also asserts `demo.floorBand`). Import of `FloorPlanFloorDrag` added to the `show` list.
- `docs/host-guide.md`: subsection "Selecting with a band" in §7 before "### Table groups" (one Dart block: `bandView()`); §8 gains a `floorDrag` bullet ("Since 0.7.0"); §10 Touch gains a sentence on `band`. The subsection covers the two triggers, the direction rule, groups whole/locked never/unnumbered, the camera under `band`, the finger near a table (tap selects, drag bands, on the table moves), cancelling (Escape also under `shortcuts: false`, second finger), the modifier read at the press (editor reads Shift at the release), and the change under the default.
- `tool/ci/host_probe/lib/main.dart`: `bandView()` in `_FloorScreenState`, identical to the guide's block.
- `CHANGELOG.md`: `## Unreleased` ("Nothing yet." replaced) with the brief's two entries (the band + the default-`pan` change; `bandModeFor`/`SelectionBandPainter`).
- Specs: host-embedding O-4 "Taken up" with link; selection-mode S3, restaurant-embedding D11 and D17, touch T6 each a dated "(2026-10-13) Except under `floorDrag: band` (rubber-band spec RB-2)." line.
- `STATUS.md`: "In flight" (slice implemented on `feat/rubber-band`, worktree, reviewed per task, final review pending, then the merge word and 0.7.0), "Resume here" (new lead paragraph, rest kept), "Owed to the human" (the look; de/tr read of the switch). "Last updated" was already 2026-10-13.

## Demo test RED / GREEN

- RED (before the implementation): `demo_test.dart` failed to compile: `The getter 'floorBand' isn't defined for the type 'DemoHomeState'`.
- GREEN after: `D23 ...` passes; demo suite `+69: All tests passed!`.
- Mutant (named M-RB7a: the view ignores the switch, `floorDrag: FloorPlanFloorDrag.pan`): D23 went red (`+0 -1 ... Some tests failed`); reverted from a copy; suite green again.

## Gates (last lines)

- Engine `packages/jet_cad_2d`: `dart test --file-reporter json:...` exits 1 on its two fingerprints; `expect_failures`: `packages/jet_cad_2d: 1290 tests; the standing failures and skips, exactly` (exit 0). analyze: `No issues found!`. format: `Formatted 175 files (0 changed)`.
- Render `packages/jet_cad_2d_flutter`: `expect_failures` exit 1 listing exactly `text_lod_ladder rung 1` and `rung 2` as "passed or did not run" (the recorded macOS difference). analyze `No issues found!`; format 232 files, 0 changed.
- GPU `packages/jet_cad_2d_gpu`: `flutter test` `+20: All tests passed!`; `expect_failures`: `packages/jet_cad_2d_gpu: 20 tests; the standing failures and skips, exactly`; analyze clean; format 0 changed.
- `packages/jet_cad_floor_plan`: `+2003 ~4: All tests passed!`; analyze clean; format 296 files, 0 changed.
- `packages/jet_cad_restaurant_symbols`: `+97: All tests passed!`; analyze clean; format 0 changed.
- `apps/floor_planner` (`--enable-vmservice`): `+212: All tests passed!`; analyze clean; format 0 changed.
- `apps/restaurant_demo`: `+69: All tests passed!`; analyze `No issues found!`; format 0 changed.
- `tool/ci`: `dart test` `+64: All tests passed!`; analyze `No issues found!`; format 0 changed; `dart run tool/ci/check_guide.dart`: `docs/host-guide.md: all 54 code blocks are in the host probe`.
- Host probe (`file://` worktree, full SHA above): `Analyzing host_probe... No issues found!`, `Built build/web`, `host probe: no GPU renderer, no build hook; build/web is  42M`.
- Old probes, each `exit=0`: `old host probe: v0.3.0's main.dart analyses against d15385bb...`, same for `v0.4.0`, `v0.5.1`, `v0.6.0`.

## Concerns

1. CI (`.github/workflows/ci.yml:169-173`) runs the old probes for v0.3.0, v0.4.0, v0.5.1 only; I ran v0.6.0 as asked but did not add it to CI or to STATUS's command list (outside the brief).
2. The spec's RB-7 says `FloorPlanLongPress.contextMenu`'s doc names `floorDrag: band` as a touch screen's multiple selection; that doc comment (in `packages/jet_cad_floor_plan`) is not in this brief's file list and was not changed. Someone should confirm it was done in Task 3 or add it.
3. The "two triggers" in the guide are read as: a plain drag on the floor under `band`, and a Shift/Ctrl/Cmd mouse or stylus drag under `pan` (a finger never bands under `pan`), per spec RB-2.
4. The 18 px slop and the other behaviour facts in the guide come from the task message, not re-verified against the code.
5. The demo's switch is a plain on/off ("Floor drag: select"), as the brief's strings say, not the spec's "Pan / Select" wording.

## Fix round 1 (commit cc196aa0fa2ab97d122fd18f36c2b5853d8842e7)

Only `docs/host-guide.md` changed:
- §8's `longPress` bullet: "a touch screen then has no multiple selection" is now "a touch screen's multiple selection is then a band, `floorDrag: FloorPlanFloorDrag.band`".
- "Selecting with a band" (the `band` trigger) and §10 Touch now say outright that one finger on the floor no longer pans under `band`.

`dart run tool/ci/check_guide.dart` from the repo root: `docs/host-guide.md: all 54 code blocks are in the host probe` (exit 0). No code block changed, so the host probe needs no re-run.
