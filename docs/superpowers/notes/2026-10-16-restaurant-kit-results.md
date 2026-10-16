# The restaurant kit (sub-project 4a): results of record

Branch `feat/restaurant-kit`, cut from `main` at `8caf8e00`. Spec:
`docs/superpowers/specs/2026-10-16-restaurant-kit-design.md`; plan:
`docs/superpowers/plans/2026-10-16-restaurant-kit.md`. Closures:
`docs/superpowers/specs/2026-10-16-restaurant-kit-parity.md` ("Closed (4a)")
and `...-test-audit.md` ("Closed (4a)"). Gates and builds were run on
2026-10-17 at `026ad859` (Task 11's commit sits on top of it). Transcripts are
last lines copied from those runs.

**Status of 4a:** the kit, the plan library's host gaps (H1-H4, O1-O4), the
ported demo, POS1 and the builds are done and green on the branch. **Task 10
(the host guide, `check_guide` and the host probe moved to the new API) is
done** (its report: `.superpowers/sdd/2026-10-16-restaurant-kit/task-10-report.md`);
the parity row "new guide / host probe" is closed, so no row is open. The
whole-branch review, the ledger archive and the merge are the controller's and
the human's.

## Gates (this run)

| Package | test | analyze | format |
|---|---|---|---|
| `packages/jet_cad_2d` | `+1343 -2` (the two standing failures, below) | `No issues found!` | exit 0 |
| `packages/jet_cad_2d_flutter` | `+1453 ~1 -5` (the five standing goldens, below) | `No issues found! (ran in 3.4s)` | exit 0 |
| `packages/jet_cad_2d_gpu` | `00:01 +20: All tests passed!` | `No issues found! (ran in 2.7s)` | exit 0 |
| `packages/jet_cad_2d_plan` (`--enable-vmservice`) | `02:03 +1579: All tests passed!` | `No issues found! (ran in 3.9s)` | exit 0 |
| `packages/jet_cad_2d_kit_restaurant` | `00:01 +184: All tests passed!` | `No issues found! (ran in 2.6s)` | exit 0 |
| `packages/jet_cad_2d_kit` | `00:06 +403: All tests passed!` | `No issues found! (ran in 3.5s)` | exit 0 |
| `packages/jet_cad_2d_kit_architecture` | `00:21 +655: All tests passed!` | `No issues found! (ran in 4.0s)` | exit 0 |
| `packages/jet_cad_2d_integration` (`--enable-vmservice`) | `00:55 +228: All tests passed!` | `No issues found! (ran in 3.1s)` | exit 0 |
| `apps/architecture_demo` | `00:38 +176: All tests passed!` | `No issues found! (ran in 3.3s)` | exit 0 |
| `apps/restaurant_demo` | `00:24 +102: All tests passed!` | `No issues found! (ran in 3.9s)` | exit 0 |

**Standing failures, none from this branch.** `jet_cad_2d`'s
`generate_document_test.dart` (two fingerprint cases) and `jet_cad_2d_flutter`'s
`text_ladder_golden_test.dart` rungs 1-5 fail on this machine (macOS 27,
Flutter 3.47.6); both are listed in `tool/ci/standing_failures.txt`. The
`jet_cad_2d` pair fails identically on a clean worktree of `8caf8e00` (the base
`main`), run on 2026-10-17; the goldens render text and no commit of this
branch touches text measurement. Everything else in the engine packages passes,
including both allocation invariants (`query_allocation_test.dart` is in the
`jet_cad_2d` run above, outside the two failures).

**The engine packages changed** (decision of the human, "Motoru 4a'da
düzelt"): `jet_cad_2d` (`drag_snap.dart`, `spatial_index.dart`,
`snap_exclude_test.dart`) and `jet_cad_2d_flutter` (`select_tool.dart`,
`grip_drag.dart`, `select_tool_drag_test.dart`), each with an Unreleased
CHANGELOG line; they join 4b's release wave (umbrella A10).

`tool/ci/check_kit_deps.dart`: `kit dependencies: 3 package(s) checked, none
names the plan library or another kit`. `tool/ci/check_guide.dart`:
`docs/host-guide.md: all 56 code blocks are in the host probe` at `026ad859`
(the old guide; Task 10 then moved it: `all 29 code blocks are in the host
probe` for the new one, see Task 10's report). Host probe (`bash
tool/ci/host_probe.sh file://$PWD $(git rev-parse HEAD)` at `026ad859`): `host
probe: no GPU renderer, no build hook; build/web is  42M`, exit 0. After Task
10 the probe is on the new packages (`jet_cad_2d_plan` and the two kits), the
old one is `tool/ci/old_host_probe*`.

Dry-runs, never published: `jet_cad_2d_kit_restaurant` (`Total compressed
archive size: 57 KB.`) and `jet_cad_2d_plan` (`950 KB`): both
`Package has 0 warnings.`

## POS1

`apps/restaurant_demo/integration_test/pos_test.dart`, the real app on the
macOS binary (`flutter test integration_test/pos_test.dart -d macos`): the
Salon opens clean with its 11 tables; Link tables writes `salon-<n>` on every
table; in the Service, statuses Eating, Bill and Ordered on tables 1-3; tables
4 and 5 merged as G1; the layout saved after one move of stool 8, the stool
moved again, the saved layout restored (`appliedGroups == ['G1']`, no dropped
move, the earlier move back, the statuses kept); a PNG exported through the
demo's own bar (96 dpi, `salon.png`) and written to a temporary directory,
checked for the PNG signature; and the screen captured through a
`RepaintBoundary`.

```
cd apps/restaurant_demo && flutter test integration_test/pos_test.dart -d macos
00:00 +0: POS1 Salon, Service, statuses, a merge, a POS id, the layout kept and put back, a PNG export and a screenshot
POS_PNG .../Containers/com.jetcad.restaurantDemo/Data/tmp/2026-10-16-restaurant-kit-pos.png 247547 bytes; export 71495 bytes
00:05 +1: (tearDownAll)
00:05 +1: All tests passed!
```

The screenshot: [2026-10-16-restaurant-kit-pos.png](2026-10-16-restaurant-kit-pos.png)
(the sandbox keeps the app in its container, so the PNG was copied out by
hand). It shows the Salon's room inside its sheet.

## Builds, in `apps/restaurant_demo`

- `flutter build macos`: `✓ Built build/macos/Build/Products/Release/restaurant_demo.app (49.7MB)`
- `flutter build web`: `✓ Built build/web`
- `flutter build ios --simulator --no-codesign`: `✓ Built build/ios/iphonesimulator/Runner.app`
- `flutter build apk --debug`: `✓ Built build/app/outputs/flutter-apk/app-debug.apk`
  (`flutter doctor` shows the Android toolchain, SDK 36.0.0; three
  Java-8-obsolete warnings from Gradle, not the app's).

## The fix wave (2026-10-17)

Two real defects (parked in the ledger after Tasks 6 and 8), fixed before
the gate, each with a named mutation (run on the committed code, seen
red, reverted with `git checkout --`, `git diff --quiet` passing):

1. `e6e72a5b`, `026ad859`: the Salon's room (centrelines x 400..15250) was
   wider than its A4 1:50 sheet (14850 x 10500 mm). Chosen: the Salon's build
   sets an **A3 sheet at 1:50** (21000 x 14850 mm) centred where the default
   sheet is, because it is the least invasive: the walls, the placements and
   the SP1/SW2 assertions (1200 mm clear, absolute translations) stay exact,
   where narrowing the room would break SW2's 1200 mm and 1:75 would need a
   different scale for a 14850 mm room. The sheet keeps the plan's decimal
   separator (the first version replaced the page and lost the German comma;
   DQ2 caught it). Test SW3 (room incl. wall thickness inside the sheet;
   sheet centred on the origin). Mutations: `_sheet(document)` commented out
   -> SW3 red; the sheet built from a fresh `PageComponent(...)` instead of
   the plan's own -> DQ2 red.
2. `f7e498a7`, `026ad859`: Revert before any Save emptied the plan. Revert with
   nothing stored now rebuilds the area's sample (`newPlan(build: a.sample)`;
   `Area` carries its `sample`). Test DE11 (a pristine Salon keeps its 11
   tables; one with table 3 deleted gets it back; the Teras keeps its 6).
   Mutation: `newPlan()` without the build -> DE11 red. Ported D10 and DQ2
   asserted the old empty result; they now assert the sample (`salonTables`),
   with a `// Decided:` note in D10 and the separator assertion in DQ2
   unchanged.

POS1's mutation: the POS id written as `<area>_<n>` instead of `<area>-<n>`
(`lib/pos_links.dart`) -> POS1 red (its id table); reverted, `git diff
--quiet` passes.

## Rulings of record (from the ledger)

- Eight one-segment old keys renamed to meet the contract's key rule (T1):
  `cashier.desk`, `buffet.counter`, `highchair.child`, `parasol.round`,
  `heater.patio`, `partition.screen`, `stage.platform`, `piano.grand`.
- `restaurantSymbolEntries()` added beside `restaurantSymbolDefinitions()` (a
  placed table needs its unit); the snapshot was regenerated, not appended
  (the keys are unpublished; from the first publish the K7 rule holds).
- RL15 and the SC3 behaviour moved to the demo (a kit may not import the plan
  library or another kit).
- H3 means two `PlanServiceView`s (a second `PlanCanvas` on one controller
  asserts in debug); the most recent reporter drives `canvasRect`.
- O1 fixed in the engine (human ruling): `snapInto`/`resolveDragPoint` take
  `Set<Handle>? exclude`; `SelectTool` excludes the dragged objects for the
  move target only, the move base keeps the own-geometry snaps.
- O3 `pageFlowBusy` public; the architecture demo's busy = session flows OR
  `pageFlowBusy` (3b's N6-gap is N6-closed). O4: locale adopted in the build
  (`adoptLocale`), notices re-word in the same frame.
- The old sample JSON held no walls; the Salon gets a plain room (4 walls, a
  door, 2 windows) built first; the Teras stays outdoor.
- The demo polices its own colours (`test/invariants/theme_colours_test.dart`);
  the old package's test lost its demo root, the one sanctioned edit to
  `jet_cad_floor_plan`.
- Ordered has no caption, as the old demo; status captions are cut to 12
  graphemes (host captions drive the tests).
- No independent reviewers (the human): the controller reviewed each task.

## Follow-ups and open items

- **Task 10, the host guide**: done (rewrite, `check_guide` and the host probe
  on the new API, the groups-across-a-relabel warning with its snippet, the
  "From `jet_cad_floor_plan`" section). The old guide stays at the tag
  `v0.7.2`. For 4b: the old probe (`tool/ci/old_host_probe`,
  `old_host_probe_resolve.sh`, `old_host_probe.sh`) goes with
  `jet_cad_floor_plan`; the READMEs of the old packages still link the guide.
- **4b**: the release wave (the engine packages join it), removing the old
  packages and `apps/floor_planner`, the README pictures, the CI moves.
- `lib/main.dart` is 821 lines after Task 8 added the bars, export, layout,
  events and badges (it was 510 after Task 7's split).
- The planner's own Export flow dies with its editor when the area is switched
  while its dialog is up (a library rule; it writes nothing). The demo's own
  bar's Export completes for the area it started in (EX-area-own).
- The macOS integration test's screenshot is written to the container's
  temporary directory (the sandbox); copy it out by hand.

## For the human

1. **The restaurant demo now runs on the new packages** (`jet_cad_2d_plan`,
   the architecture and restaurant kits); POS1 green on macOS, builds green
   (macOS, web, iOS simulator, Android debug APK).
2. **Decision 9 needs your confirmation:** the sample plans (`buildSalon`,
   `buildTeras`) live in the demo, not the kit, because a kit may not name the
   plan library or another kit. A host wanting the sample copies the demo's file.
3. **The Salon's sheet is A3 at 1:50** (not the default A4): its room could
   not fit A4 and keep the 1200 mm clearance. Say if you prefer 1:75 or a
   smaller room.
4. **Revert before any Save** now rebuilds the area's sample (the old demo's
   behaviour), not an empty plan.
5. **The host guide is rewritten** (`docs/host-guide.md`, for the plan library
   and the kits; the POS section is 6); nothing is open in the parity or audit
   tables.
6. **The engine packages changed** (O1, drag snap): they are released with 4b,
   not alone.
7. **Two standing failures per package on this machine** (the engine's
   document fingerprints, the render package's text ladders) are not from this
   branch; the first pair fails the same on the base commit.
8. Nothing was pushed, merged, tagged or published; the dry-runs show 0
   warnings.
