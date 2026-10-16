# Task 12 report: the wall type, grips, tool and settings

Status: **DONE_WITH_CONCERNS** (one concern: freeze and the shared band cache, below; nothing in this task's scope is red).

Commit: `e8f66cad feat(architecture): the wall's type, grips, tool and settings (3a C3.2)`

## Implementation summary

Kit (`packages/jet_cad_2d_kit_architecture`):
- `lib/src/wall/wall_grips.dart`: ported from `jet_cad_floor_plan/lib/src/parametric/wall_grips.dart:1-203`. The changes are the ones the brief lists (Step 6):
  - the imports;
  - `WallGrips({required LiveTypeOf live})`;
  - `wallsInDocument(d, group, _live)` in both `gripsOf` and `_endsAt`, and `_endsAt` is now an instance method;
  - `_keptPut`/`_seated` and their class-doc bullet removed (R-P8, back in Task 14).
  `diff` against the source shows nothing else.
- `lib/src/wall/wall_tool.dart`: ported from `wall_tool.dart:1-278`, with the Step 7 changes:
  - the constructor is `WallTool(WallSettings Function() settings, WallBands bands)`, and the settings are read per commit and per paint;
  - `_ownsBands` and the `dispose` override are gone, because the cache is shared and the tool never disposes it;
  - the doc lines are reworded as listed.
  `WallSettings` itself is unchanged.
- `lib/src/wall/wall_plan.dart`: the brief's Step 8 verbatim (`wallPlanType`, `wallPlanTool`).
- `lib/src/kit.dart`: `types: [boxPlanType, wallPlanType]`, `tools: [boxPlanTool, wallPlanTool]`.
- The barrel gains `export 'src/wall/wall.dart' show Justification, WallParams;`, placed alphabetically after the `kit.dart` export.
- `CHANGELOG.md` gains the wall bullet.

Tests in the kit:
- `test/support/wall_shell.dart`
- `test/wall/wall_tool_test.dart` (WT10-13, WT15-18, WT20)
- `test/wall/wall_grips_test.dart` (EG1-k, EG3-k, EG4-k, EG6-k)
- `test/wall/wall_joint_kinds_test.dart` (WT3-k, WT9-k)
- `test/wall/wall_plan_test.dart` (WT-type, WT-settings, WT-bands, WT-frozen, WT-kit)

Integration (`packages/jet_cad_2d_integration`, public libraries only):
- `test/support/wall_fixture.dart`: the brief's header (`WorldWall` and `wallJoin` reproduced), then source `:10-44, 86-156, 164-170, 178-294`, then `wall_shell.dart:8-51`. Left out: `worldWall`, `spoke`, `ringOf`, `triangulates`, `wallDoc`, `reload`. `driftOf` and `diagnosticsOf` run over `kitCatalog()`.
- `test/support/wall_shell.dart`: the brief's Step 11.2 verbatim. It is built over `editor_rig.dart` (`pumpEditor`, `globalAt`, `press`); no rig helper is duplicated.
- `test/wall/wall_tool_test.dart` (12 cases), `test/wall/wall_grips_test.dart` (EG1-EG6 and WG-refuse-short), `test/wall/wall_paint_test.dart` (WP5).

## TDD evidence

RED: the kit tests were written first and run before any lib file existed. `cd packages/jet_cad_2d_kit_architecture && flutter test test/wall/`:
```
test/wall/wall_grips_test.dart:11:8: Error: Error when reading 'lib/src/wall/wall_grips.dart': No such file or directory
test/wall/wall_joint_kinds_test.dart:18:8: Error: Error when reading 'lib/src/wall/wall_tool.dart': No such file or directory
test/wall/wall_plan_test.dart:19:8: Error: Error when reading 'lib/src/wall/wall_plan.dart': No such file or directory
test/wall/wall_plan_test.dart:20:8: Error: Error when reading 'lib/src/wall/wall_tool.dart': No such file or directory
test/wall/wall_tool_test.dart:14:8: Error: Error when reading 'lib/src/wall/wall_tool.dart': No such file or directory
00:02 +44 -4: Some tests failed.
```

GREEN in the kit:
- `flutter test test/wall/` → `00:00 +64: All tests passed!`
- `flutter test` → `00:01 +78: All tests passed!` (64 under `test/wall/` plus 14 under box, scaffold and example).

Integration: the integration support and tests were ported after the kit's lib existed. They depend on the kit's public wall, so they cannot run before it.
- `flutter test --enable-vmservice test/wall/` → `00:04 +20: All tests passed!`
- `flutter test --enable-vmservice` (the whole package) → `00:04 +28: All tests passed!`

## Gates

| Package | Command | Result |
|---|---|---|
| kit | `flutter test` | `+78: All tests passed!` |
| kit | `flutter analyze` | `No issues found!` |
| kit | `dart format --output=none --set-exit-if-changed .` | exit 0 |
| kit | `dart pub publish --dry-run` (after the commit) | `Package has 0 warnings.` |
| integration | `flutter test --enable-vmservice` | `+28: All tests passed!` |
| integration | `flutter analyze` | `No issues found!` |
| integration | `dart format --output=none --set-exit-if-changed .` | exit 0 |
| integration | `grep -rn "/src/" test lib \| grep import` | prints nothing |
| repo root | `dart run tool/ci/check_kit_deps.dart` | `kit dependencies: 2 package(s) checked, none names the plan library or another kit` |

`git status --short` after the commit is empty, and no `analysis_options.yaml` was touched.

## Mutation results

Every mutation was run against committed files, reverted with `git checkout --`, and confirmed with `git diff --quiet`. All 14 went red.

| Id | Mutation | Red line(s) |
|---|---|---|
| M-WT-1 | `_thickness(t) => t` | WT-type: `Which: returned WallParams:<...0.000001, left)>`; WT-settings: `returned WallSettings:<WallSettings(0.000001, right)>` |
| M-WT-2 | the type's thickness gate deleted | WT-type: `Expected: [reshape, reshape] Actual: [null, PlanGate.reshape]` |
| M-WT-3 | `create` reads `const WallSettings()` | WT-settings: `Expected: [115, left] Actual: [200.0, centre]` |
| M-WT-4 | `create` builds `WallBands(liveTypesOf(services))` | WT-bands: `Expected: a value greater than <0> Actual: <0>` |
| M-WT-5 | `_endsAt` treats every wall as live | WT-frozen: `Expected: [1300, 2600] Actual: [1300, 2600, 3900]` |
| M-WT-6 | `gripsOf` treats every wall as live | WT-frozen: `Expected: empty Actual: [` |
| M-WT-7 | `grips:` deleted | WT-frozen: `Null check operator used on a null value` |
| M-WT-8 | `tools: [boxPlanTool]` | WT-kit: `Expected: ['architecture.box', 'architecture.wall'] Actual: ['architecture.box']`; integration WT7: `Expected: 'Wall' Actual: 'Select'` |
| M-WT-9 | `letter: 'Q'` | WT-settings: `Expected: 'W' Actual: 'Q'`; integration WT1: `Expected: 'Wall' Actual: 'Select'` |
| M-WT-10 | the tool's justification write returns `s` | WT-settings: `Expected: WallSettings(150.0, left) Actual: WallSettings(150.0, right)`; integration WT2: `Expected: [115, left] Actual: [115.0, centre]` |
| M-WT-11 | `_joinBandInto` returns false | WT3-k: `Expected: Tee Actual: Free`; WT10: `Actual: <60.00000000022894>` (also WT11, WT13, WT16 red) |
| M-WT-12 | `if (false) return false;` | WT9-k: `Expected: not <Instance of 'Tee'> Actual: <Instance of 'Tee'>` |
| M-WG-1 | `_moved` throws `StateError('short')` | EG1-k: `Bad state: short`; WG-refuse-short: `Expected: <1> Actual: <0>` (the first drag commits nothing) |
| M-WG-2 | `_moved`'s length check deleted | EG1-k: `Expected: null Actual: <Instance of 'CompoundCommand'>`; WG-refuse-short: `Expected: <1> Actual: <2>` |

## Ported-test accounting (A12, C7)

**Kit, `wall_tool_test.dart`.** Source cases WT10, WT11, WT12, WT13, WT15, WT16, WT17, WT18 and WT20 are copied unchanged. The only change is the fixture: `rig.tool.settings.value` became `rig.settings.value` in WT18 and WT20, with `directRig` over `WallBands(liveOf(doc))` and a local notifier.

**Kit, `wall_grips_test.dart`.** Fixture changes in all four cases: `WallGrips()` became `WallGrips(live: liveOf(doc))`, `gripDoc` uses `wallDoc()`, and `gridOf(p)` is the case's page.
- The EG1 tail `:270-272` became EG1-k.
- The EG3 tail `:334-371` became EG3-k.
- The EG4 tail `:411-421` became EG4-k.
- The EG6 tail `:549-579` became EG6-k. Its premises `:456-520` are copied too.

**Kit, `wall_joint_kinds_test.dart`.** WT3's `classify` lines (`:142-143`, `:303`, `:342-343`, `:365-366`) became WT3-k, and WT9's (`:544-545`) became WT9-k (ruling R12-2; the brief's code verbatim).

**Integration, `wall_tool_test.dart`.**
- WT1-WT9, WT14, RF2 and WT19 are ported with these changes:
  - the harness is `pumpWalls` over `wallController(wallShellPlan())`;
  - `isPending` is read as `activeTool(tester).isMidShape` (R-P1);
  - settings go through `setWallSettings` (R12-1);
  - the `classify` lines became comments (R12-2);
  - the palette key is `tool-wall` → `tool-architecture.wall` (C7 class 1).
- WT14 and WT19 build their documents through `wallPlanJson`, and WT19 pumps through `pumpEditor(scale: 100)`.
- Every other assertion is unchanged.

**Integration, `wall_grips_test.dart`.**
- EG1-EG6 use `wallController(gripPlan(...))`, `pumpEditor(scale: 0.15)`, `ctrl.grips.grips` (R-P9) and `globalAt`.
- The provider tails became comments (R12-3), and EG6's strays are written into `ctrl.document` before the pump.
- WG-refuse-short is new (the brief's code verbatim).

**Integration, `wall_paint_test.dart`.** WP5 uses `wallController(wallPlanJson(...))` and `pumpEditor(scale: 0.2)`. The capture is the outermost `RepaintBoundary` above `InteractionLayer`, with sample points offset by its origin. Luminance thresholds and sample points are unchanged.

**Moved to later tasks (R-P8).** EG7 and EG8 go to Task 17; EG9 and EG10 go to Task 21.

The `°`, `—` and `≈` literals were checked with `grep` against the sources, and they match.

## Files changed (16)

Kit:
- `lib/src/wall/wall_grips.dart`, `wall_tool.dart`, `wall_plan.dart`
- `lib/src/kit.dart`, `lib/jet_cad_2d_kit_architecture.dart`, `CHANGELOG.md`
- `test/support/wall_shell.dart`
- `test/wall/wall_tool_test.dart`, `wall_grips_test.dart`, `wall_joint_kinds_test.dart`, `wall_plan_test.dart`

Integration:
- `test/support/wall_fixture.dart`, `test/support/wall_shell.dart`
- `test/wall/wall_tool_test.dart`, `wall_grips_test.dart`, `wall_paint_test.dart`

## Deviations

- The barrel export sits after `kit.dart` (alphabetical), not directly under the box's line. The brief said "after the box's export"; it still is after it.
- Integration `pumpWalls` carries a short doc comment, which holds the source's `_scale` explanation. This is code-neutral.
- No assertion had to change. No test needed `settleHistory`/async changes. The settings dropdown and focus path (`setWallSettings`) worked as written: WT2 commits B at 115/left mid-chain, and Enter then ends the chain.

## Concerns

**Freeze and the shared band cache (the Task 11 review's open question): stale, but only on the hover path, and only when the edit that froze is refused on its retry.**

How a freeze reaches the cache:
- `FailureBoundary._freeze` (`jet_cad_2d_plan/lib/src/kits/guard.dart:721-731`) adds to the `frozen` set and calls `lockBroken`.
- `lockBroken` → `_lock` (`plan_controller.dart:832-848`) calls `history.clearHistory()`, which emits no `DocChange` (`jet_cad_2d/lib/src/document/undo.dart`: `clearHistory` only clears; a throwing `execute` emits nothing).
- `WallBands` rebuilds only on a `DocChange` or `invalidate()` (`wall_bands.dart:151-160`).

When that happens:
- **Mid-edit freeze, retry succeeds:** the retry emits `CommandApplied`, so the cache goes stale and rebuilds. Correct.
- **Mid-edit freeze, retry refused:** nothing is emitted, so the cache keeps the frozen wall until the next document change.
- **Load-time freezes:** these happen before any scan, and a new document resets the cache. Correct.

Evidence from a scratch probe (`FakePlanServices` with a mutable `frozen` set, which R-P12 and the plan's `liveTypeIdOf` both read live). It was run and not committed; a copy is at `/private/tmp/claude-501/-Users-ahmeturel-Projects-oss-jet-cad/ca29d59e-d5c8-4cfe-abd5-973c37552f1a/scratchpad/freeze_probe_test.dart`. The steps: draw wall A through `wallPlanTool.create(services)`, let the stream deliver, then `frozen.add(a)` with no document change.
- `expect(bands.liveWalls(doc), isNot(contains(a)))` failed with `Expected: not contains <18> / Actual: [18]`, and `bands.generation` was unchanged. The frozen wall stays in the cache.
- With the stale behaviour asserted positively, a hover in A's band ends the rubber band on the frozen A's centreline (test passed). On the same test, the click right after does **not** join A (`WallTool.accept` calls `_bands.invalidate()` on every click), so the committed wall is correct.

Observable effect today:
- In the Wall tool, only the rubber-band preview is affected, between a refused-retry freeze and the next click or edit.
- Later users of the cache that scan without invalidating would also see the frozen wall: the opening tools' `hostAt` (Task 15), the wall faces (Task 24) and `liveWalls`.

Spec C1.5 says a frozen wall is "absent from ... the opening host scan exactly as it is absent from `generate`". So Task 15/24 should either invalidate per action, as the Wall tool's click does, or the plan should signal a freeze to shared caches. I did not redesign the cache. This task's committed behaviour, commits and grips alike, is unaffected: `WallGrips` reads `liveTypeIdOf` per call, as WT-frozen pins.

`catalog.dart`'s "(this task the box's)" header is left as instructed.

---

# Fix report (pre-review round): a frozen wall leaves the band cache at the next read

Commit: `47a82226 fix(architecture): a frozen wall leaves the band cache at the next read` (on top of e8f66cad).

## Change

`packages/jet_cad_2d_kit_architecture/lib/src/wall/wall_bands.dart`:

- **The check.** `_refresh`, the one entry point every reader goes through (`liveWalls`, `hostAt`, `joinInto` via `_indexAt`, and anything Task 15/24 adds on top of them), now runs `if (!_stale && !_stillLive()) invalidate();` before its stale test.
- **`_stillLive()`.** It walks the cached handles in place (`for (var i = 0; i < _walls; i++)`) and answers false at the first one where `_live(h) != ArchitectureTypes.wall`. This is a superset of the `_live(h) == null` the ruling named: a frozen wall answers null. It builds no list and allocates nothing. `_live` is a set lookup plus the engine's `_naming`, which is map lookups only (`tree[h]`, `components.get<T>(h)` = `_stores[T]?[handle]`).
- **What is kept.** The doc-change listener and `invalidate()` are unchanged. `invalidate()` bumps `generation`, so a liveness change also moves it.
- **Doc comments.** The class doc now states the rule: the cache is refreshed on a document change or a change in liveness. It also says un-freezing comes with a document change, which the stream covers. The `generation` and `_stillLive` docs say the same.

## Tests (kit)

- **`test/wall/wall_live_test.dart` WL4** (it sits beside WL1-WL3, the liveness file).
  - The fixture is `liveDoc()`: A, B and F in turned, off-origin groups, plus a stray on a nested group inside a turned, mirrored group.
  - The cache is `wallBandsOf(FakePlanServices(..., frozen: <Handle>{}))`, read once with all three walls live.
  - Then three freezes, each with no document change. After each, a different reader is the first to read:
    - F frozen: `joinInto` at F's band is false and leaves `out` untouched; `liveWalls` is `[a, b]`; A still joins.
    - B frozen: `hostAt` at B's band is null; A still hosts.
    - A frozen: `liveWalls` is empty and `generation` moved.
  - `doc.commands.stateId` is unchanged throughout.
- **`test/wall/wall_plan_test.dart` WT-frozen-hover** (the probe as a test).
  - Wall A is drawn through `wallPlanTool.create(services)`, and a hover in A's band joins it (the control).
  - `frozen.add(a)`; the next hover's rubber band ends at the pointer, not on A.
  - The next click is not joined either.

## Integration case

Not added. The integration path cannot observe the hover join through public libraries:
- `WallTool`, its `debugBandEnd` and `WallBands` are kit internals.
- The rubber band is only painted.
- A click always invalidates, so it passes with or without the fix.

The plan's `@internal frozen` set could be mutated under R-P9, but nothing public would show the result. The kit tests above pin both the cache and the tool's hover.

## Evidence (real output)

Gates, run before the commit:
- Kit:
  - `flutter test` → `00:01 +80: All tests passed!` (78 + WL4 + WT-frozen-hover)
  - `flutter analyze` → `No issues found!`
  - format → exit 0
- Integration:
  - `flutter test --enable-vmservice` → `00:04 +28: All tests passed!`
  - `flutter analyze` → `No issues found!`
  - format → exit 0
- `dart run tool/ci/check_kit_deps.dart` → `kit dependencies: 2 package(s) checked, none names the plan library or another kit`
- After the commit:
  - `dart pub publish --dry-run` → `Package has 0 warnings.`
  - `git status --short` is empty.

Mutation **M-WB-live**: the line `if (!_stale && !_stillLive()) invalidate();` was deleted from the committed file, then reverted with `git checkout --` and checked with `git diff --quiet` (`reverted`). It also serves as this round's RED; the lib change was written before the tests in this round.
```
WL4 ... [E]
  Expected: false
    Actual: <true>
WT-frozen-hover ... [E]
  Expected: a value less than <0.000001>
    Actual: <69.3859530481017>
     Which: is not a value less than <0.000001>
```

## New concern: the hover cost (measured, not asserted)

WT12 prints the per-hover cost at 600 walls. With the check:
```
WT12 n=600: median per hover 38.04 us (whole pointer move), band scan alone 35.86 us
```
With the check removed:
```
WT12 n=600: median per hover 4.16 us (whole pointer move), band scan alone 1.88 us
```

- **What it costs.** The liveness pass makes each read about 19x slower at 600 walls: 600 calls of `_live`, each a frozen-set lookup plus the engine's naming rule over the registered types. It is still allocation-free and about 36 us per hover, well inside a frame.
- **Making it a pure set lookup per wall.** This would need a narrower signal than `LiveTypeOf`, for example "is h frozen", or a liveness revision/listenable on `PlanServices`. That is a contract amendment (C1.5 / D-40 territory). I did not make it.
- **What the controller decides.** Whether today's cost is acceptable, or the signal should be added.
