# Task 10 report: the host guide and its checks

Status: DONE. One commit on `feat/restaurant-kit`: `9acb5767 docs: the host guide for jet_cad_2d_plan and the kits; its probe and check`. `git status --short` is empty.

## What changed

- `docs/host-guide.md` rewritten (1223 lines, 29 code blocks), for `jet_cad_2d_plan` 0.8.0 and the restaurant and architecture kits. Sections: 1 dependency, 2 fonts, 3 languages (host words), 4 controller and views (PlanEditor, PlanServiceView, PlanCanvas), 5 storing the plan, 6 the POS (6.1 what a table is, 6.2 link to POS ids as host data, 6.3 statuses, 6.4 selecting and finding, 6.5 groups merge/split, 6.6 relabelling a grouped table (warning and snippets), 6.7 events, 6.8 saving and restoring the layout, 6.9 callbacks, export/print, own chrome), 7 permissions with `PlanToolIds` (H1), 8 a host kit (H2), 9 two views (H3), 10 themes and unit overlays, 11 touch, 12 "From `jet_cad_floor_plan`" (every name of the old barrel, the controller members that changed, the decision-7 drops), 13 what a host must never assume. O3 (`pageFlowBusy`) is in 6.9 with a snippet, O4 in section 3 (a locale change re-words in the same frame; `PlanLocaleScope` is not exported, so it is not named).
- `tool/ci/host_probe/` is a new host (`lib/main.dart`, `pubspec.yaml.in`, `.gitignore`, `web/`) on `jet_cad_2d_plan` + `jet_cad_2d_kit` + the two kits, overrides to git for six packages. `tool/ci/host_probe.sh` builds it from outside the workspace (no symbol copying: the kit's library is a package asset).
- The old probe, which `old_host_probe.sh` and the released-host replays (v0.3.0, v0.4.0, v0.5.1, v0.6.0) still need, moved to `tool/ci/old_host_probe/` (git mv), with `old_host_probe_resolve.sh` (the old host_probe.sh) and `old_host_probe.sh <tag>` (reads the tag's `tool/ci/host_probe/lib/main.dart`, as the tag has it). Both stay until 4b.
- `check_host_lock.dart`/`lib/host_lock.dart`: `probedFromCommit` is the six new packages, `oldProbedFromCommit` the four old ones, `--old` selects them. `check_readmes.dart` and its test read the old probe's pubspec (the old planner's README yaml block).
- `.github/workflows/ci.yml`: the probe format step covers both probes; a step for `old_host_probe_resolve.sh` before the replays. Nothing else in CI changed (matrix moves are 4b's).
- Parity doc: the row "new guide / host probe" closed in "Closed (4a)", blockers 2 and 8 and the last paragraph updated. Results note: Task 10 pending lines changed to done.

## Relabel and groups (Review Focus 2), checked in code before writing

Run in a scratch test (deleted) on a real controller: `setUnitLabel('2','9')` leaves group `G1 = {2, 3}` as it was; in service the group still lists `2`, the selectable members are `{3}`; `serviceJson()` then `restoreService()` gives `applied=[] dropped=[G1]` and the groups end empty. With the guide's `relabelTables` (members rewritten from the same map, so swaps work) the group becomes `{9, 3}` and the restore applies it. `matchServiceMoves` also drops the relabelled table's move (the label is part of the strict match). Controller statuses, groups and focus are not cleared by `load` or `newPlan` (code: only `_groups` is assigned in setUnitGroups/restore/reset), so the guide says to redraw after a load. The recommended design: the POS keeps groups and statuses by POS id and redraws them from the host data after any relabel or load (`watchTables` on `unitChanges`), which also makes a dropped record group harmless.

A scratch widget test of the probe's POS functions against the Salon sample (deleted, not committed) printed: link (`unlinked: {pos-9}`), statuses by label, merge G1 then G2 with the first group shrinking to `{pos-1}`, group status, relabel redraw (`G2: {22, 3}`), enter service, split, `relabelTables` swap `{4, 3}`, save then `dirty false`, revert `true`.

## Gates (real output)

- `cd tool/ci && dart test`: `00:49 +129 -2: Some tests failed.` The two failures, `dependency_lines_test.dart DL2` (counts 20, expects 21) and `scripts_test.dart SC16` (`packages/jet_cad_2d_kit_restaurant` not in the CI matrix), also fail on a clean worktree of `aafb2840` (run: same two names). They come from earlier tasks (restaurant_demo's pubspec, the new kit) and are 4b's CI moves; not touched.
- `dart analyze --fatal-infos ...`: `No issues found!`. `dart format ... lib test ...`: 0 changed. `dart format --language-version=3.6 host_probe/lib old_host_probe/lib`: 0 changed.
- `dart run tool/ci/check_guide.dart`: `docs/host-guide.md: all 29 code blocks are in the host probe`. `check_readmes`: `package READMEs: all 6 code blocks are in the probes`. `check_kit_deps`: `kit dependencies: 3 package(s) checked, none names the plan library or another kit`. `check_screenshots`: `screenshots: every rule holds`.
- Host probe at the final commit (`tool/ci/host_probe.sh file:///Users/ahmeturel/Projects/oss/jet-cad 9acb5767...`): `pubspec.lock: 42 packages, none of flutter_scene, flutter_gpu, flutter_gpu_shaders, scene, jet_cad_2d_gpu`, `No issues found! (ran in 3.9s)`, `✓ Built build/web`, `host probe: no GPU renderer, no build hook; build/web is  42M`, exit 0.
- Old probe at the work-in-progress commit `7ae79387` (same `tool/ci` files as the final one): `old_host_probe_resolve.sh` exit 0 (`no GPU renderer, no build hook; build/web is  42M`), then `old_host_probe.sh` for `v0.3.0`, `v0.4.0`, `v0.5.1`, `v0.6.0`: each `analyses against 7ae79387...`, exit 0.
- No package under `packages/` or `apps/` was touched, so the package and app gates (CLAUDE.md) were not rerun; no analysis_options.yaml is in the commit.

## Mutations (each on committed code, reverted with `git checkout --`, `git diff --quiet` passing; the first run before the commit of guide_test.dart is noted)

| # | Mutation | Red |
|---|---|---|
| M1 (the brief's) | guide snippet edited alone: `c.setUnitData(` -> `c.setUnitDatum(` in `docs/host-guide.md` | `check_guide`: `not in the host probe: dart: /// The plan's tables by the POS id ...`, exit 1; reverted, green again |
| M2 | `FloorPlanController` in a snippet, guide and probe alike | `GD6` |
| M3 | `droppedGroups` renamed in the guide's prose only | `GD7` (after I strengthened it: the first version survived, because the code block also says `droppedGroups`; GD7 now reads the prose with code cut out) |
| M4 | `bool relabelTables` renamed (guide and probe) | `GD7` |
| M5 | the lock check deleted from `host_probe.sh` | `SC14 host_probe.sh ...` |
| M6 | `--old` dropped from `old_host_probe_resolve.sh` | `SC14 old_host_probe_resolve.sh ...` |
| M7 | architecture kit removed from `probedFromCommit` | `HL-N1`, `HL-N2`, `HL-N3 jet_cad_2d_kit_architecture`, `HL-N4` |
| M8 | `check_host_lock` ignores `--old` | `SC21`, `SC21b` |
| M9 | `old_host_probe.sh` reads the new probe's directory | `SC19` (two cases) |
| M10 | `check_readmes.dart` reads the new probe's pubspec | `jet_cad_floor_plan: yaml: flutter:`, exit 1 (a CI step, not a test) |

Not covered by a named test: the guide's prose claims beyond the relabel warning (they come from code and tests I read, listed under "Facts checked" below).

## Facts checked in code for the guide

`PlanLocaleScope` is internal; `PlanCanvas` asserts on a second canvas; `PlanServiceView` shows nothing in design; `PlanUnitChanged(before, after)` gives a label change; `PlanUnitsReplaced` on load/newPlan; `setUnitData` false for an ambiguous or locked label, `StateError` in service; `setUnitGroups` throws `ArgumentError` for a label in two groups; `UnitStatus.maxCaption` is 12; `statusFillOpacity` multiplies the alpha (null: as given); a restaurant symbol with seats is a `table` unit (`units.dart`); `ensurePlanFonts` once per process; `restoreService` refuses text that is not a version-1 `jet_cad.service` record; a move matches by handle, same label, same `from`.

## Decisions and concerns

- I split the old tooling rather than delete it (spec R4 says it stays until 4b), so the scripts are now `host_probe.sh` (new), `old_host_probe_resolve.sh`, `old_host_probe.sh`. The tests SC14/SC19/SC21 follow them. 4b removes the last two, `tool/ci/old_host_probe/`, `oldProbedFromCommit` and `--old`.
- The READMEs of `jet_cad_2d`, `jet_cad_2d_flutter` and `jet_cad_floor_plan` still link `docs/host-guide.md`; the floor planner's now points at a guide for another package. README work is 4b.
- The fixture `tool/ci/test/fixtures/host_probe.lock.txt` is a real lock from `host_probe.sh` with the clone's path replaced by `/home/user/jet-cad` (as the older fixtures have); its ref `99ab3f2e...` is the sha of an intermediate commit of this task that no longer exists after the squash. The ref is only a constant for the tests.
- `SC16` and `DL2` stay red in `tool/ci` (pre-existing, see above); a controller or 4b should add `packages/jet_cad_2d_kit_restaurant` to the matrix and fix the count.
- The guide is long (1223 lines) because the POS section carries the whole flow with compiled snippets; the other sections are short.
- `apps/restaurant_demo` is the reference host; the guide's POS functions are simplified from it (the demo's grow-or-new merge rule is not copied; the guide merges to a new group).
