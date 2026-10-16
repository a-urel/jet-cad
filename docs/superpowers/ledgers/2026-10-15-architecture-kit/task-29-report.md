# Task 29 report: the exit gate

Status: **DONE_WITH_CONCERNS** (every gate green or at exactly its standing
lines; Appendix A closed; the concerns are records for the final review,
not gate failures).

Commit: `13fb4933 docs: the architecture kit (3a), results of record` on
`20d592d9`. Files (staged by explicit path): the new results note
`docs/superpowers/notes/2026-10-15-architecture-kit-results.md`, `STATUS.md`,
the three CHANGELOGs, and the umbrella spec (`2026-10-13-kit-architecture-design.md`,
its missing 3a/3b amendment line, Step 9). No code changed. No
`analysis_options.yaml` touched. `git status --short` empty after the commit.

## Step 1: tree and branch (this run)

- `git status --short`: nothing.
- `git log --name-only --format= main..HEAD | grep analysis_options`:
  `packages/jet_cad_2d_integration/analysis_options.yaml`,
  `packages/jet_cad_2d_kit_architecture/analysis_options.yaml`, once each.
- `git log --format='%H %s' main..HEAD | wc -l`: `48`.
- HEAD `20d592d96745c965466ff3802fe738cb3ef8c914`; `main`
  `7e65905bf1e05852efa85f4afc50d6f789ceb955`; `origin/main`
  `651e3d09dd803a1e8e4239b9f98ede4c2adb7018`;
  `git merge-base --is-ancestor main HEAD; echo $?` → `ancestor exit: 0`.
- `origin/main` is behind local `main` (`git log main..origin/main` empty;
  `origin/main..main` holds the 2b follow-ups' merge `de6abda9` and STATUS
  `7e65905b`). Not a finding: local `main` is unpushed, as STATUS says.

## Step 2: the four plan-line packages (this run, each exit 0)

| Package | test | analyze | format |
|---|---|---|---|
| `jet_cad_2d_kit` (`flutter test`) | `00:04 +400: All tests passed!` | `No issues found! (ran in 3.4s)` | `Formatted 92 files (0 changed) in 0.10 seconds.` |
| `jet_cad_2d_plan` (`--enable-vmservice`) | `01:58 +1549: All tests passed!` | `No issues found! (ran in 4.4s)` | `Formatted 299 files (0 changed) in 0.78 seconds.` |
| `jet_cad_2d_kit_architecture` | `00:20 +650: All tests passed!` | `No issues found! (ran in 3.2s)` | `Formatted 136 files (0 changed) in 0.42 seconds.` |
| `jet_cad_2d_integration` (`--enable-vmservice`) | `00:55 +226: All tests passed!` | `No issues found! (ran in 3.1s)` | `Formatted 79 files (0 changed) in 0.21 seconds.` |

No `skip:` in the four packages' tests.
- `cd packages/jet_cad_2d_plan && flutter test --enable-vmservice test/invariants` → `00:09 +15: All tests passed!`
- IA-alloc alone → `00:00 +1: All tests passed!`

## Step 3: tools (this run)

- `cd tool/ci && dart test` → `00:44 +118: All tests passed!`
- `dart analyze --fatal-infos lib test expect_failures.dart check_guide.dart check_host_lock.dart package_root.dart check_screenshots.dart check_readmes.dart check_kit_deps.dart` → `No issues found!`, exit 0
- format (lib, test, scripts, `../readme_probe/lib`) → `Formatted 24 files (0 changed) in 0.03 seconds.`, exit 0; `--language-version=3.6 host_probe/lib` → `Formatted 1 file (0 changed) in 0.01 seconds.`, exit 0
- `cd tool/readme_probe && flutter analyze` → `No issues found! (ran in 3.1s)`
- `dart run tool/ci/check_kit_deps.dart` → `kit dependencies: 2 package(s) checked, none names the plan library or another kit`, exit 0 (the kit regex `^jet_cad_2d_kit_[a-z0-9_]+$`, `tool/ci/lib/kit_deps.dart:12`).
- `check_guide` → `docs/host-guide.md: all 56 code blocks are in the host probe` (0); `check_readmes` → `package READMEs: all 6 code blocks are in the probes` (0); `check_screenshots` → `screenshots: every rule holds` (0).

## Step 4: CLAUDE.md gates (this run)

- `jet_cad_2d`: `dart test` → `00:06 +1337 -2: Some tests failed.`; the two: `test/testing/generate_document_test.dart: the default document is the one Plan 2 measured, byte for byte [E]`, `... both text fractions default to zero and change nothing [E]` = exactly `standing_failures.txt`'s two engine lines. `dart analyze` → `No issues found!`; format → `Formatted 187 files (0 changed)`.
- `jet_cad_2d_flutter`: `flutter test` → `00:25 +1450 ~1 -5: Some tests failed.`; the five: `text ladder rung 1-5 (RenderBackend.canvas) [E]` = the standing file's five `text_ladder` lines. Its two `text_lod_ladder` lines pass on this macOS machine: they are Linux-only goldens (the file's header; plan 07 results note line 78). The skip is the standing rig test. analyze → `No issues found! (ran in 4.3s)`; format → `Formatted 234 files (0 changed)`.
- `jet_cad_2d_gpu`: `00:02 +20: All tests passed!`; `No issues found! (ran in 3.1s)`; `Formatted 10 files (0 changed)`.
- `query_allocation_test` → `00:05 +6: All tests passed!`; the Flutter layer's `paint_allocation_test` → `00:00 +3: All tests passed!`.
- Old line: `jet_cad_floor_plan` (`--enable-vmservice`) → `01:52 +2012: All tests passed!`; `jet_cad_restaurant_symbols` → `00:00 +97: All tests passed!`; `apps/floor_planner` → `00:33 +212: All tests passed!`. (Not compared against a run on `main`: this task does not touch `main`; the branch changes nothing under them, Step 6.)

## Step 5: dry runs

- Before the CHANGELOG lines, at `20d592d9`: kit, plan, architecture kit each exit 0, `Package has 0 warnings.` The kit's list holds `CHANGELOG.md`, `LICENSE`, `README.md`, `assets/library/furniture.jetlib`, `example/main.dart`, `lib/jet_cad_2d_kit_architecture.dart`, `pubspec.yaml`; `Total compressed archive size: 536 KB.` `cmp LICENSE packages/jet_cad_2d_kit_architecture/LICENSE` → nothing, exit 0.
- After the CHANGELOG lines, uncommitted: each exit 65, `Package has 1 warning.`, the warning `* 1 checked-in file is modified in git.` / `CHANGELOG.md` only.
- **After the commit `13fb4933`** (not in the note, which is part of that commit): `jet_cad_2d_kit exit 0` `Package has 0 warnings.`; `jet_cad_2d_plan exit 0` `Package has 0 warnings.`; `jet_cad_2d_kit_architecture exit 0` `Package has 0 warnings.`

## Step 6: hand checks (this run)

All as expected; quoted in the note's "Hand checks": A12 diff prints
nothing; versions 0.1.0 / 0.8.0 / 0.1.0 / 0.0.0, `publish_to: none`, no
pubspec version or constraint change; the kit's dependencies are
`flutter`, `jet_cad_2d`, `jet_cad_2d_flutter`, `jet_cad_2d_kit`, `meta`,
`vector_math`; no plan or other-kit name in the kit; no `src/` import in
the integration package; 20 files carry `invalid_use_of_internal_member`,
each named by its task's report; the contract and the plan stay kit-free;
purity `00:00 +10: All tests passed!`; no `dart:io` in a library; the
generator `wrote assets/library/furniture.jetlib: 67083 bytes, 41 symbols`
and `git diff --quiet` on the assets exit 0; `ci.yml` has both packages in
the test matrix (integration with `--enable-vmservice`) and the kit in
`publishable`; `git status --short` empty.

(One shell note: `grep ... --include=*.dart` failed once under zsh's glob,
`no matches found`; re-run with the patterns quoted, exit 1, no output.)

## Step 7: Appendix A closure state

Every row of A.1 (D-01 to D-50), A.2 and A.3 has a state in the note's
table: ported (destination + test names found by `grep -rln` in this run),
ruled (D-10 is in fact ported: the contract's `symbol_box.dart:153-159`;
D-18, D-40, D-43's probe, D-46's `ValueDisplay` half), or carried (D-16,
D-42, D-50, PA4, A.2's parity rows to 4; D-49 and the rest of
`apps/floor_planner/test` to 3b). **No row without one of the three.**
- D-36: `grep -n "hasLength(6), reason: 'A, B, C, U, K and R'" packages/jet_cad_2d_integration/test/service/room_fill_test.dart` → `159:    expect(spy.fills, hasLength(6), reason: 'A, B, C, U, K and R');`; the plan's test is at `packages/jet_cad_2d_plan/test/service/paint/unit_fill_test.dart:535` (the brief's path omitted `paint/`), `hasLength(5), reason: 'A, B, C, U and K'`.
- The 54 six-type source files each map to a destination (table in the note).
- D-48: all ten rows' tests found, including Task 27/28's O13a, O13b, PW1, Q0-E3b, WS1, IP-title, CP1, CP2 (absent at Task 26's time).
- Lines dropped: 27, all decided; none pending. IA-R3, IA-R4, IA-R5 and Task 28's `bands.generation` lines are "decided by the controller (delegated)".

## Step 8: CHANGELOGs (names checked by grep over each package's `lib`)

- Contract: the brief's bullet, with `PlanWords` (`word`, `maybe`, `text`, `decimalSeparator`, `plan_words.dart:8-24`) which `KitWords` implements, `KitNamesWords(decimalSeparator:)`, and `fieldsOf`/`commitField`/`sectionFor` taking a `DraftDocument` and the words (fact d). `KitWords.text`/`.decimalSeparator` are written as `PlanWords`' (where the code declares them).
- Plan: fact (a) — "plan.select's drop is refused by the rule `execute` uses (no edit, no exception; a `StateError` still escapes)", not "goes through `execute`" (`_refusal`, `plan_controller.dart:900`; `drop: true` only at `guard.dart:458`); fact (b) the choice row's focus hand-back (`_handBackAfterChoice`); plus D-44's `PlanShortcuts` remount (Task 8, `plan_shortcuts.dart`).
- Architecture kit: the brief's body, with 41 symbols (the generator printed `41 symbols`; `grep -c "CatalogSymbol("` gives 27 because the six family helpers build several each), six size families (`bed-double`, `bed-single`, `desk`, `kitchen-base`, `sofa`, `wardrobe`), 30 wall-attached ones (Task 23), and fact (c): the caches and memos re-check liveness on read.

## Step 9: amendment lines

- Umbrella: missing (`grep -n "architecture_demo"` found only A13's `:356`); **appended** the brief's line to `## Amendments` (`:520-526`).
- Contract spec: all present (`:418`, `:424`, `:433`, `:440`, `:445`, `:448`, `:452`).
- 2a spec: all present (`:833`, `:844`, `:852`, `:858`, `:864`, `:869`).
- 2b spec: `git diff main -- ...service-mode-design.md` prints nothing.

## Step 10: ports and mutations

From the reports, tabled in the note. Every named mutation red, except
the ones the reports and rulings resolved (M-BX-4 on BX4, M-IA-3 on SS16,
`_onArmed`'s `_attached = null`, Task 7's live-referent probe, Task 4's
single swap routes), each listed with its resolution.

## Findings and concerns (for the coordinator's final review; none fixed here)

1. **Port comments (Minor).** The brief's port-comment grep lists 86 files. Ported files carrying no line naming their `jet_cad_floor_plan` source: K `dimension/dimension_{attach_points,attach,follow,format,fuzz,grips,layout,object,params,rotate}_test.dart` (Tasks 20, 21) and K `attach/wall_faces_test.dart` (Task 24). They keep today's headers. Every one is in its report's accounting; a provenance comment only.
2. **The brief's D-36 path** omits `paint/` (`packages/jet_cad_2d_plan/test/service/paint/unit_fill_test.dart:535`); the line holds there.
3. **`text_lod_ladder` rungs 1-2** pass on this machine while `standing_failures.txt` lists them (Linux-only goldens); not a branch effect (the branch changes nothing under `jet_cad_2d_flutter`).
4. **The cost prints** (superseded by fix report 1): the first version quoted full-suite figures this report did not transcribe; they are cut from the note and replaced by focused runs transcribed below.
5. The four "For the human" items and the parked Minors (28 ledger `Ruling:` lines) are in the note; the CHANGELOG items among the parked Minors (Tasks 17, 21, 24) are now written.

## Deviations

- The STATUS "In flight" paragraph adds one sentence naming the note's four "For the human" items (the brief's paragraph otherwise verbatim). "Resume here": the brief's sentence, set inside the paragraph's existing bold so the markup stays balanced; no "Owed to the human" sentence, since no line is pending.
- The kit CHANGELOG keeps "(sub-project 3a)" in its opening line and lists each type's exported names and the liveness re-check (fact c), beyond the brief's text.
- The note's Mutations table groups each task's sibling mutations into one row (id range, files, changes, red tests) to stay readable; every id is in its task report.
- The plan's CHANGELOG mentions D-44's `PlanShortcuts` remount, which the brief's text did not.

---

# Fix report 1 (review: one Critical, no-synthesized-output; folded minors)

Commit: `945502cb docs: 3a results note quotes only transcribed runs (Task 29 fix)` on `13fb4933`. Files: the results note and `packages/jet_cad_2d_plan/CHANGELOG.md`, staged by explicit path; no `analysis_options.yaml`; `git status --short` empty after the commit.

## Changes

- The note's cost prints: the untranscribed full-suite figures (WT12 80.38/77.66, OT4 76.20/73.72/89.60, TT6 153.2/176.9, TL8 104.0, GE5b 2595/112) are cut. In their place: this round's focused runs (transcribed below), and beside them the task reports' figures, each labelled with its report (Task 12 WT12 38.04/35.86 and 4.16/1.88; Task 15 OT4 43.68/41.64/50.52; Task 21 GE5b 102 µs; Task 19 TT6 137.5/147.5 vs today's 19.2/12.3; Task 22 TL8 104-116 vs 44 vs 38, Shift 96).
- New record in the note: this run's TL8 prints a face-line move of 1481 us, over D12's 1,000 µs budget (printed, not asserted; Task 22's report quotes no face-line figure). For the final review.
- The note's dry runs: the archive sizes and file list now come from this round's run at `13fb4933` (transcribed below); the pre-CHANGELOG and uncommitted runs are cited to Step 5 of this report.
- Heading "Lines dropped, the human's word" → "Lines dropped, decided by the controller (delegated)"; item 11 now reads "dropped by the spec's decision 7 (the human's, taken in the brainstorm)".
- The plan CHANGELOG's 3a entry split into ten `- Sub-project 3a: ...` bullets, every claim and name unchanged (`git diff` shows the same words re-cut); the note's CHANGELOG paragraph says "ten bullets".
- This report's concern 4 marked superseded (it carried the same untranscribed figures).

## Transcripts (this round)

`cd packages/jet_cad_2d_kit_architecture && flutter test test/wall/wall_tool_test.dart --plain-name "WT12"` (exit 0):
```
00:00 +0: WT12 the per-hover cost at 600 walls, printed, not asserted (review round 2, I2)
WT12 n=600: median per hover 75.06 us (whole pointer move), band scan alone 73.22 us
00:01 +1: All tests passed!
```

`cd packages/jet_cad_2d_kit_architecture && flutter test test/opening/opening_tool_test.dart --plain-name "OT4 (cost)"` (exit 0):
```
00:00 +0: OT4 (cost) the per-hover cost at 600 walls, printed, not asserted (07 WT12's method)
OT4 n=600: median per hover over no wall 96.84 us (whole pointer move), host scan alone 92.32 us; over a wall, with the preview, 106.02 us
00:03 +1: All tests passed!
```

`cd packages/jet_cad_2d_kit_architecture && flutter test test/dimension/dimension_grips_test.dart --plain-name "GE5b"` (exit 0):
```
00:00 +0: GE5b among 612 walls the end grip's previews along a face line lay each wall out once per drag, the drop lays out afresh, and a document change starts the memo afresh; the time per preview is printed
GE5b 612 walls: end-grip preview along a face line: first 7199 us, median 109 us, worst 7199 us, over 1 ms 1/61 (printed, not asserted)
00:00 +1: All tests passed!
```

`cd packages/jet_cad_2d_kit_architecture && flutter test test/room/room_tool_test.dart --plain-name "TT6"` (exit 0):
```
00:00 +0: TT6 steady hovers re-trace nothing; outside the bounding box of every place box nothing is traced; the Kitchen seed, outside every place box but inside that box, is traced and previewed; a band's verdict is reused; an Unbounded hover at 600 walls is timed
TT6 600 walls, a courtyard among 600 free walls: median per Unbounded hover 143.8 us; the first, which builds the contours, 12519 us
TT6 636 walls, outside a connected 636-wall plan: median per Unbounded hover 155.4 us; the first, which builds the contours, 7524 us
00:01 +1: All tests passed!
```

`cd packages/jet_cad_2d_kit_architecture && flutter test test/dimension/dimension_tool_test.dart --plain-name "TL8"` (exit 0):
```
00:00 +0: TL8 hovering among 600 walls searches once per distinct resolved point, passes no line test between a centreline and its faces or past a door, passes one on a face line and one on a centreline, and a commit searches afresh once per end; the time per move is printed
TL8 612 walls, 0.3 px/mm: median per move over the band path 116.0 us idle, 111.0 us with two points placed (the preview rebuilt each move); on the face line 1481 us, on the centreline 124 us; a Shift slide along a face line 95.0 us per move (worst 190 us); budget 1000 us per move (D12; printed, not asserted)
00:00 +1: All tests passed!
```

`cd packages/jet_cad_2d_integration && flutter test --enable-vmservice test/invariants/paint_allocation_test.dart`:
```
00:00 +0: IA-alloc a rebuilt steady-state PlanCanvas frame over the sample flat allocates O(1) per flush, the kit loaded (M-IA-alloc)
00:00 +1: All tests passed!
```

`cd packages/jet_cad_2d_plan && flutter test --enable-vmservice test/invariants`: files run (grep of the output) `band_allocation_test.dart`, `canvas_paint_allocation_test.dart`, `contract_names_test.dart`, `pick_allocation_test.dart`, `theme_colours_test.dart`; last line `00:09 +15: All tests passed!`

`cd packages/jet_cad_2d_kit && dart pub publish --dry-run` (at 13fb4933, exit 0), its summary lines:
```
├── CHANGELOG.md (3 KB)
├── LICENSE (11 KB)
Total compressed archive size: 120 KB.
Package has 0 warnings.
```

`cd packages/jet_cad_2d_plan && dart pub publish --dry-run` (at 13fb4933, exit 0), its summary lines:
```
├── CHANGELOG.md (5 KB)
├── LICENSE (11 KB)
Total compressed archive size: 938 KB.
Package has 0 warnings.
```

`cd packages/jet_cad_2d_kit_architecture && dart pub publish --dry-run` (at 13fb4933, exit 0), from `Publishing` on:
```
Publishing jet_cad_2d_kit_architecture 0.1.0 to https://pub.dev:
├── CHANGELOG.md (1 KB)
├── LICENSE (11 KB)
├── README.md (<1 KB)
├── analysis_options.yaml (<1 KB)
├── assets
│   └── library
│       ├── furniture.jetlib (65 KB)
│       └── furniture.snapshot.json (17 KB)
├── example
│   └── main.dart (1 KB)
├── lib
│   ├── jet_cad_2d_kit_architecture.dart (<1 KB)
│   └── src
│       ├── attach
│       │   ├── wall_attach.dart (15 KB)
│       │   ├── wall_face_provider.dart (2 KB)
│       │   └── wall_faces.dart (7 KB)
│       ├── box
│       │   ├── box.dart (3 KB)
│       │   ├── box_plan.dart (1 KB)
│       │   └── box_tool.dart (1 KB)
│       ├── dimension
│       │   ├── dimension.dart (12 KB)
│       │   ├── dimension_attach.dart (14 KB)
│       │   ├── dimension_geometry.dart (20 KB)
│       │   ├── dimension_grips.dart (12 KB)
│       │   ├── dimension_plan.dart (5 KB)
│       │   └── dimension_tool.dart (24 KB)
│       ├── furniture
│       │   ├── furniture_catalog.dart (16 KB)
│       │   ├── furniture_names.dart (5 KB)
│       │   └── furniture_source.dart (1 KB)
│       ├── ids.dart (1 KB)
│       ├── kit.dart (1 KB)
│       ├── live.dart (1 KB)
│       ├── opening
│       │   ├── opening.dart (11 KB)
│       │   ├── opening_geometry.dart (29 KB)
│       │   ├── opening_grips.dart (7 KB)
│       │   ├── opening_plan.dart (5 KB)
│       │   └── opening_tool.dart (19 KB)
│       ├── room
│       │   ├── room.dart (19 KB)
│       │   ├── room_grips.dart (6 KB)
│       │   ├── room_inputs.dart (22 KB)
│       │   ├── room_label.dart (6 KB)
│       │   ├── room_plan.dart (4 KB)
│       │   ├── room_tool.dart (19 KB)
│       │   └── room_trace.dart (42 KB)
│       ├── sample
│       │   └── sample_flat.dart (17 KB)
│       ├── separator
│       │   ├── separator.dart (4 KB)
│       │   ├── separator_grips.dart (4 KB)
│       │   ├── separator_plan.dart (1 KB)
│       │   └── separator_tool.dart (4 KB)
│       ├── separator_linetype.dart (1 KB)
│       ├── type_naming.dart (1 KB)
│       ├── wall
│       │   ├── wall.dart (12 KB)
│       │   ├── wall_bands.dart (8 KB)
│       │   ├── wall_geometry.dart (26 KB)
│       │   ├── wall_grips.dart (8 KB)
│       │   ├── wall_plan.dart (2 KB)
│       │   └── wall_tool.dart (9 KB)
│       └── words
│           ├── de.dart (3 KB)
│           ├── en.dart (2 KB)
│           ├── tr.dart (3 KB)
│           └── words.dart (1 KB)
├── pubspec.yaml (<1 KB)
├── test
│   ├── attach
│   │   ├── wall_attach_property_test.dart (11 KB)
│   │   ├── wall_attach_test.dart (46 KB)
│   │   ├── wall_face_provider_test.dart (15 KB)
│   │   └── wall_faces_test.dart (28 KB)
│   ├── box
│   │   ├── box_plan_test.dart (4 KB)
│   │   └── box_test.dart (3 KB)
│   ├── dimension
│   │   ├── dimension_attach_points_test.dart (21 KB)
│   │   ├── dimension_attach_test.dart (45 KB)
│   │   ├── dimension_follow_test.dart (16 KB)
│   │   ├── dimension_format_test.dart (15 KB)
│   │   ├── dimension_fuzz_test.dart (12 KB)
│   │   ├── dimension_grips_test.dart (33 KB)
│   │   ├── dimension_layout_test.dart (21 KB)
│   │   ├── dimension_live_test.dart (4 KB)
│   │   ├── dimension_notice_test.dart (11 KB)
│   │   ├── dimension_object_test.dart (38 KB)
│   │   ├── dimension_params_test.dart (6 KB)
│   │   ├── dimension_plan_test.dart (10 KB)
│   │   ├── dimension_rotate_test.dart (22 KB)
│   │   └── dimension_tool_test.dart (70 KB)
│   ├── example_test.dart (1 KB)
│   ├── furniture
│   │   ├── furniture_library_test.dart (25 KB)
│   │   ├── package_assets_test.dart (2 KB)
│   │   ├── symbol_box_asset_test.dart (6 KB)
│   │   └── symbol_end_to_end_test.dart (14 KB)
│   ├── intersection_snap_test.dart (8 KB)
│   ├── layers
│   │   ├── attach_layer_test.dart (6 KB)
│   │   ├── opening_host_layer_test.dart (5 KB)
│   │   └── tools_layer_test.dart (9 KB)
│   ├── opening
│   │   ├── opening_cost_test.dart (3 KB)
│   │   ├── opening_cut_test.dart (25 KB)
│   │   ├── opening_end_drag_test.dart (31 KB)
│   │   ├── opening_geometry_test.dart (21 KB)
│   │   ├── opening_grips_test.dart (22 KB)
│   │   ├── opening_kink_test.dart (10 KB)
│   │   ├── opening_live_test.dart (3 KB)
│   │   ├── opening_object_test.dart (21 KB)
│   │   ├── opening_obstacle_test.dart (24 KB)
│   │   ├── opening_params_test.dart (5 KB)
│   │   ├── opening_plan_test.dart (9 KB)
│   │   ├── opening_symbol_test.dart (13 KB)
│   │   └── opening_tool_test.dart (46 KB)
│   ├── room
│   │   ├── decimal_separator_test.dart (5 KB)
│   │   ├── room_color_test.dart (15 KB)
│   │   ├── room_cost_test.dart (14 KB)
│   │   ├── room_diagnostics_test.dart (19 KB)
│   │   ├── room_dissolve_test.dart (32 KB)
│   │   ├── room_follow_test.dart (42 KB)
│   │   ├── room_grips_test.dart (20 KB)
│   │   ├── room_inputs_services_test.dart (9 KB)
│   │   ├── room_inputs_test.dart (15 KB)
│   │   ├── room_label_test.dart (10 KB)
│   │   ├── room_localise_test.dart (16 KB)
│   │   ├── room_object_test.dart (27 KB)
│   │   ├── room_plan_test.dart (7 KB)
│   │   ├── room_tie_test.dart (25 KB)
│   │   ├── room_tint_test.dart (29 KB)
│   │   ├── room_tool_test.dart (45 KB)
│   │   └── room_trace_test.dart (32 KB)
│   ├── sample
│   │   └── sample_flat_test.dart (36 KB)
│   ├── scaffold
│   │   ├── kit_test.dart (1 KB)
│   │   ├── live_test.dart (3 KB)
│   │   └── words_test.dart (6 KB)
│   ├── separator
│   │   ├── separator_plan_test.dart (6 KB)
│   │   ├── separator_test.dart (8 KB)
│   │   └── separator_tool_test.dart (18 KB)
│   ├── support
│   │   ├── catalog.dart (1 KB)
│   │   ├── dimension_fixture.dart (22 KB)
│   │   ├── layer_fixture.dart (12 KB)
│   │   ├── opening_fixture.dart (36 KB)
│   │   ├── place_entry.dart (4 KB)
│   │   ├── room_fixture.dart (28 KB)
│   │   ├── select_rig.dart (3 KB)
│   │   ├── wall_attach_fixture.dart (6 KB)
│   │   ├── wall_fixture.dart (11 KB)
│   │   └── wall_shell.dart (2 KB)
│   ├── wall
│   │   ├── wall_bands_test.dart (4 KB)
│   │   ├── wall_geometry_test.dart (28 KB)
│   │   ├── wall_grips_test.dart (24 KB)
│   │   ├── wall_joint_kinds_test.dart (6 KB)
│   │   ├── wall_live_test.dart (7 KB)
│   │   ├── wall_params_test.dart (4 KB)
│   │   ├── wall_plan_test.dart (11 KB)
│   │   ├── wall_regen_test.dart (30 KB)
│   │   └── wall_tool_test.dart (12 KB)
│   └── words
│       └── value_words_test.dart (1 KB)
└── tool
    └── generate_furniture_library.dart (1 KB)

Total compressed archive size: 536 KB.
Validating package...
The server may enforce additional checks.

Package has 0 warnings.
```

After the fix commit `945502cb` (the plan CHANGELOG changed): `cd packages/jet_cad_2d_plan && dart pub publish --dry-run` → `├── CHANGELOG.md (5 KB)`, `Total compressed archive size: 938 KB.`, `Package has 0 warnings.`, exit 0.

Hand checks re-run this round (from the root), as the note quotes them:
```
$ git diff --stat main -- packages/jet_cad_floor_plan packages/jet_cad_restaurant_symbols packages/jet_cad_2d_gpu packages/jet_cad_2d packages/jet_cad_2d_flutter apps
(no output)
$ grep -n "^version:" packages/jet_cad_2d_kit/pubspec.yaml packages/jet_cad_2d_plan/pubspec.yaml packages/jet_cad_2d_kit_architecture/pubspec.yaml packages/jet_cad_2d_integration/pubspec.yaml
packages/jet_cad_2d_plan/pubspec.yaml:5:version: 0.8.0
packages/jet_cad_2d_kit/pubspec.yaml:5:version: 0.1.0
packages/jet_cad_2d_kit_architecture/pubspec.yaml:6:version: 0.1.0
packages/jet_cad_2d_integration/pubspec.yaml:6:version: 0.0.0
$ grep -n "publish_to" packages/jet_cad_2d_integration/pubspec.yaml
5:publish_to: none
$ git diff main -- packages/jet_cad_2d_kit/pubspec.yaml packages/jet_cad_2d_plan/pubspec.yaml | grep "^[-+][^-+]"
(no output)
$ sed -n '/^dependencies:/,/^dev_dependencies:/p' packages/jet_cad_2d_kit_architecture/pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  jet_cad_2d: ^0.7.2
  jet_cad_2d_flutter: ^0.7.2
  jet_cad_2d_kit: ^0.1.0
  meta: ^1.18.0
  vector_math: ^2.2.0

dev_dependencies:
$ (kit names grep, src-import grep, contract/plan pubspec grep, import grep, dart:io grep): each no output, exit 1
$ grep -rln "invalid_use_of_internal_member" packages/jet_cad_2d_integration/test | sort
packages/jet_cad_2d_integration/test/controller/zone_room_test.dart
packages/jet_cad_2d_integration/test/dimension/dimension_panel_test.dart
packages/jet_cad_2d_integration/test/dimension/dimension_shell_test.dart
packages/jet_cad_2d_integration/test/l10n/determinism_test.dart
packages/jet_cad_2d_integration/test/l10n/leak_test.dart
packages/jet_cad_2d_integration/test/l10n/locale_separator_test.dart
packages/jet_cad_2d_integration/test/l10n/numbered_names_test.dart
packages/jet_cad_2d_integration/test/opening/opening_frozen_test.dart
packages/jet_cad_2d_integration/test/opening/opening_grips_test.dart
packages/jet_cad_2d_integration/test/opening/opening_kink_test.dart
packages/jet_cad_2d_integration/test/opening/opening_paint_test.dart
packages/jet_cad_2d_integration/test/opening/opening_panel_test.dart
packages/jet_cad_2d_integration/test/opening/opening_symbol_test.dart
packages/jet_cad_2d_integration/test/opening/opening_tool_test.dart
packages/jet_cad_2d_integration/test/panels/wall_section_test.dart
packages/jet_cad_2d_integration/test/room/room_grips_test.dart
packages/jet_cad_2d_integration/test/room/room_paint_test.dart
packages/jet_cad_2d_integration/test/room/room_panel_test.dart
packages/jet_cad_2d_integration/test/support/opening_support.dart
packages/jet_cad_2d_integration/test/wall/wall_grips_test.dart
$ grep -n "jet_cad_2d_kit_architecture\|jet_cad_2d_integration" .github/workflows/ci.yml
50:          - package: packages/jet_cad_2d_kit_architecture
52:          - package: packages/jet_cad_2d_integration
188:          - packages/jet_cad_2d_kit_architecture
$ sed -n 52,57p .github/workflows/ci.yml
          - package: packages/jet_cad_2d_integration
            tool: flutter
            # The paint-allocation invariant over the sample flat (spec 3a
            # C6) reads the VM's allocation profiler, as the plan
            # library's does.
            test_flags: --enable-vmservice
$ (generator) wrote assets/library/furniture.jetlib: 67083 bytes, 41 symbols; git diff --quiet -- packages/jet_cad_2d_kit_architecture/assets/library → exit 0
$ cd packages/jet_cad_2d_kit && flutter test test/invariants/purity_test.dart → 00:00 +10: All tests passed!
$ ls packages/jet_cad_floor_plan/test/*_test.dart | xargs -n1 basename | grep -cE "^(box_|wall_|opening_|separator|room_|dimension_|planner_box)" → 54
$ (the brief's port-comment grep) | wc -l → 86
$ grep -n "hasLength(6), reason: 'A, B, C, U, K and R'" packages/jet_cad_2d_integration/test/service/room_fill_test.dart
159:    expect(spy.fills, hasLength(6), reason: 'A, B, C, U, K and R');
$ grep -n "hasLength(5), reason" packages/jet_cad_2d_plan/test/service/paint/unit_fill_test.dart
535:    expect(spy.fills, hasLength(5), reason: 'A, B, C, U and K');
$ sed -n 153,159p packages/jet_cad_2d_kit/lib/src/model/symbol_box.dart
/// The local box of the definition [definition] in [doc], from its **live**
/// leaves (the entities it owns); null when [definition] names no definition
/// or none of its leaves draws.
///
/// Not memoised: O(entities) per call. A caller that asks often keeps its
/// own memo and drops it when the document changes (its
/// `commands.stateId`).
$ grep -n "architecture_demo\|2026-10-15, sub-project 3 split" docs/superpowers/specs/2026-10-13-kit-architecture-design.md
356:  `apps/architecture_demo` (the architecture kit only); `apps/restaurant_demo`
520:- **2026-10-15, sub-project 3 split** (the human: *"3a kit, 3b demo"*;
524:  and 3b (`apps/architecture_demo`). A13's "the demos" and A11's
525:  `apps/floor_planner` → `apps/architecture_demo` are 3b's for the
$ amendment bullets (awk over the contract spec :412-460 and the 2a spec :827-874)
418: - **The symbol box family** (3a C1.4): `SymbolBox`, `isOrthonormal`,
424: - **Object views and hidden fields** (3a C1.1, C1.7): the surface gain
433: - **K4, texts** (3a C1.6): a fourth kind of word id, `text:<kit id>.<i
440: - **Words with parameters** (3a C1.6, C1.2): the surface gains `KitTex
445: - **Tool notices** (3a C1.2): the surface gains `ToolNotice`, a kit to
448: - **Preparing and building a plan** (3a C1.3, C1.9): `PlanKit.prepare`
452: - **Live objects and the kit authors' double** (3a C1.5, C1.11):
833: - **P3, property specs and the section builder** (3a C1.1, C1.7): a sp
844: - **P2, the status line and tool notices** (3a C1.2): a kit's `Tool` m
852: - **P4, a new plan and the kit's `prepare`** (3a C1.3): the constructo
858: - **P2, the controller's `build`** (3a C1.9): `PlanController(build:)`
864: - **P4, the failure boundary's grips row** (3a C1.8): an `ArgumentErro
869: - **P4, the lock set** (3a C1.10, decision 6): the live objects a froz
```

The Appendix A test-name greps, re-run this round (`grep -rlF -- <name>` over the four packages' `test/`, first three hits; K kit, I integration, P plan, C contract). 132 names, none without a hit:
```
WF1  => K:attach/wall_faces_test.dart 
WA1  => K:attach/wall_attach_test.dart 
WP1  => K:wall/wall_params_test.dart K:attach/wall_attach_property_test.dart 
MV1  => I:attach/symbol_move_test.dart 
a tagged symbol attaches on hover => I:attach/wall_attach_tool_test.dart 
rotate: false => I:attach/against_wall_rotate_test.dart P:tools/plan_select_gates_test.dart P:controller/attachment_controller_test.dart 
WE1  => I:attach/wall_attach_end_to_end_test.dart 
SS16 => I:attach/symbol_shell_test.dart 
SS17 => K:attach/wall_face_provider_test.dart I:attach/symbol_shell_test.dart 
against the north wall => I:attach/editor_tools_review_test.dart 
O13a => I:attach/editor_tools_review_test.dart 
O13b => I:attach/editor_tools_review_test.dart 
WF-hidden-toggle => K:attach/wall_face_provider_test.dart 
WF-state => K:attach/wall_face_provider_test.dart 
WF-hysteresis => K:attach/wall_face_provider_test.dart 
WF-keep => K:attach/wall_face_provider_test.dart 
SB-one-owner => P:invariants/contract_names_test.dart 
the committed bytes equal the built library => K:furniture/furniture_library_test.dart 
ships 41 symbols in six categories => K:furniture/furniture_library_test.dart 
the name alone finds a symbol => I:symbols/symbol_search_test.dart 
PA2 => K:furniture/package_assets_test.dart P:invariants/pick_allocation_test.dart 
PA3 => K:furniture/package_assets_test.dart P:invariants/pick_allocation_test.dart 
SE8 => P:panels/selection_panel_test.dart P:symbols/unit_copy_test.dart P:service/service_events_test.dart 
SC-example => K:example_test.dart 
WS1  => I:panels/wall_section_test.dart 
WS9-open => I:panels/wall_section_test.dart 
WS11 => I:panels/wall_section_test.dart 
SE13 => I:panels/selection_page_test.dart P:panels/selection_panel_test.dart P:panels/selection_page_test.dart 
SE15 => I:panels/selection_page_test.dart P:panels/selection_panel_test.dart P:panels/selection_page_test.dart 
SE16 => I:panels/selection_page_test.dart P:l10n/stale_error_test.dart P:panels/selection_panel_test.dart 
CP1  => I:panels/colour_row_test.dart P:panels/colour_row_test.dart 
CP2  => I:panels/colour_row_test.dart P:panels/colour_row_test.dart 
CP3 => I:panels/colour_row_test.dart P:panels/colour_row_test.dart 
CP4 => I:panels/colour_row_test.dart P:panels/colour_row_test.dart 
CP5 => I:panels/colour_row_test.dart P:panels/colour_row_test.dart 
CP6b => I:panels/colour_row_test.dart P:panels/colour_row_test.dart 
TD1  => I:canvas/touch_tools_test.dart P:controller/unit_detail_test.dart P:canvas/touch_tools_test.dart 
a click on a wall selects it => I:shell/planner_shell_test.dart 
cmd+Z undoes a Delete => I:shell/planner_shell_test.dart 
ctrl+Z after deleting two walls => I:shell/planner_shell_test.dart 
DT1  => I:l10n/determinism_test.dart 
LK2  => I:l10n/leak_test.dart 
OV-H => I:l10n/overflow_test.dart P:editor/editor_words_test.dart 
PW1  => I:l10n/panel_words_test.dart P:l10n/layer_page_words_test.dart P:editor/editor_words_test.dart 
PW2  => I:l10n/panel_words_test.dart P:l10n/layer_page_words_test.dart 
NN3  => I:l10n/numbered_names_test.dart P:l10n/numbered_names_test.dart 
VW3 => K:words/value_words_test.dart P:l10n/value_words_test.dart 
NS3 => I:l10n/locale_separator_test.dart P:controller/locale_separator_test.dart P:editor/editor_separator_test.dart 
SC-words => K:scaffold/words_test.dart 
SC-text => K:scaffold/words_test.dart 
SC-conformance => K:scaffold/words_test.dart 
A12b => I:editor/architecture_palette_test.dart P:editor/palette_draw_test.dart 
IT-letters => I:editor/architecture_palette_test.dart 
IT-ids => I:editor/architecture_palette_test.dart 
IT-guard => I:editor/architecture_palette_test.dart 
TN-status => P:editor/editor_notice_test.dart 
TN-relocale => P:editor/editor_notice_test.dart 
RT-notice => K:room/room_tool_test.dart I:room/room_tool_test.dart 
DT-notice => K:dimension/dimension_notice_test.dart I:dimension/dimension_tool_test.dart 
ND1  => I:separator/separator_dashed_test.dart P:controller/new_plan_test.dart 
ND2  => K:separator/separator_plan_test.dart 
ND3  => I:separator/separator_dashed_test.dart P:controller/new_plan_test.dart 
ND4  => I:separator/separator_dashed_test.dart P:controller/new_plan_test.dart 
SC-prepare => I:scaffold/prepare_test.dart 
SP-dashed-open => I:separator/separator_dashed_test.dart 
the Room tool creates its room => K:layers/tools_layer_test.dart 
a wall on the hidden C hosts nothing => K:layers/opening_host_layer_test.dart 
placer => K:layers/tools_layer_test.dart K:furniture/furniture_library_test.dart K:furniture/symbol_end_to_end_test.dart 
in the app: below the Selection => I:layers/layer_picker_wall_test.dart 
SP-type => K:separator/separator_plan_test.dart 
SP-export-png => I:separator/separator_export_test.dart 
SP-export-pdf => I:separator/separator_export_test.dart 
RC1  => K:room/room_color_test.dart 
RC8 => K:room/room_color_test.dart I:room/room_color_test.dart 
TN1  => K:room/room_tint_test.dart P:units/unit_numbers_test.dart 
RM-colour => K:room/room_plan_test.dart 
RM-area => K:room/room_plan_test.dart 
Q0-S1 => K:room/decimal_separator_test.dart I:panels/decimal_separator_test.dart 
Q0-S2 => K:room/decimal_separator_test.dart I:panels/decimal_separator_test.dart 
Q0-E1 => K:room/decimal_separator_test.dart I:panels/decimal_separator_test.dart 
Q0-E2 => I:panels/decimal_separator_test.dart 
Q0-E3  => I:panels/decimal_separator_test.dart 
Q0-E3b => K:room/decimal_separator_test.dart I:panels/decimal_separator_test.dart 
P-1  => I:separator/separator_export_test.dart I:controller/delete_components_test.dart P:panels/property_panel_test.dart 
P-2  => I:controller/delete_components_test.dart P:panels/property_panel_test.dart P:panels/layer_page_controller_test.dart 
P-3  => I:controller/delete_components_test.dart P:panels/property_panel_test.dart P:panels/layer_page_controller_test.dart 
SP1  => K:sample/sample_flat_test.dart P:service/paint/unit_theme_painter_test.dart P:service/paint/unit_status_painter_test.dart 
SP9 => K:sample/sample_flat_test.dart P:service/paint/unit_status_painter_test.dart 
SF-controller => I:sample/sample_flat_test.dart 
intersection => K:intersection_snap_test.dart K:room/room_localise_test.dart K:room/room_tie_test.dart 
TF1-room => I:service/room_fill_test.dart 
TF3-count => I:service/room_fill_test.dart 
TF7-tint => I:service/room_fill_test.dart 
EX2-room => I:export/room_export_test.dart 
EX3-room => I:export/room_export_test.dart 
EX5-room => I:export/room_export_test.dart 
CZ1 => I:controller/zone_room_test.dart I:support/zone_plan.dart 
PO-section => P:panels/object_view_panel_test.dart C:kit/object_view_test.dart 
GR-1  => P:kits/grip_refusal_test.dart 
GR-drag-refuse => P:kits/grip_refusal_test.dart 
GR-drop-refuse => P:kits/grip_refusal_test.dart 
GR-drop-hook => P:kits/grip_refusal_test.dart 
F-T7 => P:kits/guarded_tool_test.dart 
PN-remount => P:shortcuts/plan_shortcuts_test.dart 
PN-kind => P:attach/attachment_registry_test.dart 
PN-dispose => P:attach/attachment_registry_test.dart 
MV-2 => P:tools/move_resolver_test.dart 
PN-MV-nested => P:tools/move_resolver_test.dart 
PN-MV-node => P:tools/move_resolver_test.dart 
PN-MV-live => P:tools/move_resolver_test.dart 
PN-open => P:controller/attachment_controller_test.dart 
IP-title => I:panels/titles_test.dart 
IP-door-actions => I:panels/titles_test.dart 
T5-f => I:editor/editor_panels_test.dart 
WG-refuse-short => I:wall/wall_grips_test.dart 
RR-live => K:room/room_inputs_services_test.dart 
RT-frozen-wall => K:room/room_tool_test.dart 
(A1, M-03au) => I:canvas/planner_grips_test.dart 
(A2, M-03x) => I:canvas/planner_grips_test.dart 
(A3, M-03af) => I:canvas/planner_grips_test.dart 
M-03aa => I:canvas/planner_grips_test.dart 
M-03ao => I:canvas/planner_grips_test.dart 
DS2 => I:shortcuts/keyboard_focus_test.dart P:tools/design_selection_test.dart 
DS5 => I:shortcuts/keyboard_focus_test.dart P:tools/design_selection_test.dart 
RP5 => I:shortcuts/keyboard_focus_test.dart 
R-4 => K:room/room_inputs_services_test.dart K:dimension/dimension_tool_test.dart I:attach/editor_tools_review_test.dart 
RR1  => I:room/room_paint_test.dart I:dimension/dimension_paint_test.dart 
RR4 => I:room/room_paint_test.dart 
PN1 => K:dimension/dimension_plan_test.dart I:dimension/dimension_panel_test.dart 
IA-alloc => I:invariants/paint_allocation_test.dart 
box equals its hand-derived literal => K:furniture/symbol_box_asset_test.dart 
reads the live leaves: a removed leaf no longer counts => K:furniture/symbol_box_asset_test.dart 
```

## Gates after the fix

No code or test changed; the note and the plan's CHANGELOG only. The plan's dry run after the commit: 0 warnings (above). `git status --short` empty.

## Remaining concerns

- This run's TL8 face-line move (1481 us, over D12's budget; printed, not asserted) is new information for the final review; it was not in Task 22's report.
- The findings of the first report stand (port comments; D-36 path; text_lod_ladder on macOS).
