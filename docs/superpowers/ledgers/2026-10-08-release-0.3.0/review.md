# Release 0.3.0 — independent review

**Target:** `claude/exciting-pasteur-9m22jv` at `dcfff59`
(`dcfff598fa58c2ddbd7d1848d9f44ade7da21d35`, "chore: version 0.3.0 and its
changelog"), one commit on `main`'s `1335f37`. Compared against `v0.2.0`
= `7355c00`. The range holds zone focus (merged at `ffe8cb8`) and docs.

**Reviewer's setup:**
- My own clone at `/tmp/rel3-review/repo`, detached at `dcfff59`.
- A worktree of `v0.2.0` at `/tmp/rel3-review/old`.
- Flutter 3.47.6 (`/root/sdk/flutter`), `CI=true`.
- The API dump tool, analyzer 13.3.0, at `/tmp/rel3-review/apidump`.
  It is the 0.2.0 review's tool, copied, and lives outside the repo.

Nothing was committed or pushed. Nothing in `/home/user/jet-cad` was
written except this file. In my clones I made three temporary changes,
all removed or reverted afterwards: a test file, the probe's output, and
a simulated guide edit.

## Verdict

**Approved with fixes.** The checks that matter for a POS are all green:
- The versions, the lock, every `flutter analyze`, the planner (1,437),
  the demo (39), `tool/ci` (58) and `check_guide` (16 blocks).
- The host probe at the full SHA, and the 3.44 floor after a downgrade.
- **Compatibility:**
  - The engine, the renderer and the restaurant package changed only
    their pubspecs, and `service_layout.dart` is untouched.
  - A plan and a service layout written by each tree were re-read by the
    other byte-for-byte.
  - Monépro's real dependency graph resolves with 0.3.0 and holds no GPU
    renderer.

Every host-barrel addition except one is in the CHANGELOG, and nothing
it lists is wrong. The fixes are CHANGELOG wording, and none blocks the
merge:
- R-1: `editor.dart`'s `framing:` is not listed.
- R-2: a known limit that Monépro will meet.

## Findings

### R-1 — Minor: the CHANGELOG leaves out `editor.dart`'s `framing:`

The mechanical barrel diff (Check 1) shows that
`package:jet_cad_floor_plan/editor.dart` gains two things:
- an optional `framing:` parameter, typed
  `ViewportTransform? Function(Size)?`, on the constructors of
  **`PlannerShell`** and **`PlannerView`**;
- a matching public getter, `framing`, on each.

The CHANGELOG doesn't mention either. Nothing breaks, because both are
optional named parameters. But the 0.2.0 review held (R-4) that
`editor.dart`'s additions belong in the CHANGELOG, and 0.2.0's section
lists them.

**Fix:** add one bullet to 0.3.0:
"`jet_cad_floor_plan`'s `editor.dart`: `PlannerShell` and `PlannerView`
take an optional `framing:`, the camera a fit sets at the drawing area's
size (null fits the page, as before)."

### R-2 — Minor: Known limits leaves out what Monépro's phase 2 assumes

Monépro's spec 103 §11 says this of phase 2: "status drawn as Flutter
widgets positioned with `camera.worldToScreen`". In 0.3.0, as in 0.2.0:
- `FloorPlanController.camera` is `@internal`
  (`floor_plan_controller.dart` l. 205).
- A host has no public world-to-screen mapping. It colours tables only
  through `setTableStatus` and `setGroupStatus`.

This is exactly zone focus's **Q-Z1**, owed by Monépro. It is in STATUS
and in the results note, but not in the release's Known limits. The
CHANGELOG is what a POS reads when it pins 0.3.0. **Q-Z4** is also
Monépro's: its D21 links the drawing "by an app component carrying the
table's id", while jet-cad links by the table's number (`pos_tables.code`).

**Fix:** add one Known-limits line: "A host has no public world-to-screen
mapping: tables are coloured through `setTableStatus`/`setGroupStatus`,
not positioned widgets (Monépro's Q-Z1 is open). A table is linked by its
number (Q-Z4)."

### R-3 — Info: the non-finite-table sentence undersells its reach

CHANGELOG l. 37–40 says "a table whose corners are not finite … is no
longer picked". The rule is `TablePicker.candidatesOf`, and the framing,
the veil, the group lookup (`table_select_tool.dart` l. 330) and the
group frames (`table_group_painter.dart` l. 305) all share it. So such a
table is also never framed, veiled, or counted as a group member.

Only a hand-edited file produces one, so no fix is needed. If the line is
touched for R-1, "is no longer picked, framed or drawn in a group's
frame" would cover it.

### R-4 — Info: "Nothing a 0.2.0 host calls changes its signature" is exact as worded

The barrel diff shows that the only change to an existing host member is
an added optional named parameter, `FloorPlanTable({…, bool visible =
true})`, and that one is listed.

`FloorPlanController` is a plain `class … extends ChangeNotifier`, not
`final`. A host test double that `implements` it, rather than using a
mocktail `Mock`, would therefore have to add four members:
- `fitToTables`
- `setTableFocus`
- `tableFocus`
- `framingFor`, which is `@internal`

The sentence says "calls", so it remains true. `FloorPlanTable` is a
`final class`, so `visible` cannot break an implementer. No fix needed.

### R-5 — Info: a POS's lock moves `pdf` and `printing` by a patch

Resolving Monépro's own `pubspec.yaml`/`pubspec.lock` (develop, `88c96e0`)
with the two git dependencies at `dcfff59` gives these changes:
- `pdf` 3.13.0 → 3.13.1;
- `printing` 5.15.0 → 5.15.1;
- the four jet-cad packages added at 0.3.0.

The bumps come from the planner's `pdf: ^3.13.1` / `printing: ^5.15.1`,
which are unchanged since 0.2.0. Monépro pins Flutter 3.47.6, above the
3.44 floor. Info for Monépro's integration PR.

### R-6 — Info: other version strings, correctly left alone

- `packages/jet_cad/pubspec.yaml` says `0.3.0` and has done so since
  Plan 04 (`e4e3f80`). It is the dormant line, and it was not touched by
  this release.
- `.vscode/launch.json` `"version": "0.2.0"` is the launch-config schema
  version.
- `scene: ^0.3.0` / `">=0.3.0"` in `no_gpu_dependency_test.dart` and
  `host_lock_test.dart` are fixtures for the GPU renderer's `scene`
  package.
- `packages/jet_cad_2d/CHANGELOG.md` points to the root CHANGELOG, after
  0.2.0's R-8.
- In STATUS and the roadmap, every "0.2.0" left is historical, apart from
  the post-merge lines in Check 6.

## Check 1 — the CHANGELOG against the API diff

**Method.** I dumped every exported name and every public member's
signature, with `abstract`, `static` and `@internal` flags, from each
barrel at both trees. Then I diffed the two dumps. The barrels:
- `jet_cad_2d`: `jet_cad_2d.dart`, `testing.dart`.
- `jet_cad_2d_flutter`: `jet_cad_2d_flutter.dart`, `export_testing.dart`.
- `jet_cad_floor_plan`: `jet_cad_floor_plan.dart`, `editor.dart`,
  `symbols.dart`, `symbol_sources.dart`.
- `jet_cad_restaurant_symbols.dart`.
- `jet_cad_2d_gpu.dart`.

One limit of the tool: a field-level `@internal` is not shown on its
synthetic getter. So `camera`, `exportFont` and `exportChoice` print
without the flag, though the source marks them `@internal`, as at 0.2.0.

```
$ dart run bin/apidump.dart /tmp/rel3-review/old $B > old.api; echo old=$?
old=0
$ dart run bin/apidump.dart /tmp/rel3-review/repo $B > new.api; echo new=$?
new=0
   4795 old.api
   4802 new.api
      0 old.err
      0 new.err
$ diff old.api new.api
3272c3272
< …editor.dart :: PlannerShell .. PlannerShell({…, bool fitOnStart = true, void Function()? onFitted})
---
> …editor.dart :: PlannerShell .. PlannerShell({…, bool fitOnStart = true, void Function()? onFitted, ViewportTransform? Function(Size)? framing})
3281a3282
> …editor.dart :: PlannerShell .. ViewportTransform? Function(Size)? get framing
3296c3297
< …editor.dart :: PlannerView .. PlannerView({…, void Function()? onFitted, Widget? underlay, …})
---
> …editor.dart :: PlannerView .. PlannerView({…, void Function()? onFitted, ViewportTransform? Function(Size)? framing, Widget? underlay, …})
3302a3304
> …editor.dart :: PlannerView .. ViewportTransform? Function(Size)? get framing
4041a4044
> …jet_cad_floor_plan.dart :: FloorPlanController .. ValueListenable<Set<String>?> get tableFocus
4049a4053
> …jet_cad_floor_plan.dart :: FloorPlanController .. [@internal] ViewportTransform? framingFor(Size viewport)
4056a4061
> …jet_cad_floor_plan.dart :: FloorPlanController .. bool fitToTables(Set<String> numbers)
4068a4074
> …jet_cad_floor_plan.dart :: FloorPlanController .. void setTableFocus(Set<String>? numbers)
4589c4595
< …jet_cad_floor_plan.dart :: FloorPlanTable .. FloorPlanTable({required String? number, required int seats, required String? symbolKey})
---
> …jet_cad_floor_plan.dart :: FloorPlanTable .. FloorPlanTable({required String? number, required int seats, required String? symbolKey, bool visible = true})
4593a4600
> …jet_cad_floor_plan.dart :: FloorPlanTable .. bool get visible
```

The paths are elided with "…" here; the real lines carry
`packages/jet_cad_floor_plan/lib/`, and the elided parameters are
unchanged.

| Barrel | Change | In CHANGELOG |
|---|---|---|
| host barrel | `fitToTables`, `setTableFocus`, `tableFocus` | yes |
| host barrel | `FloorPlanTable.visible` (ctor param, getter; `==`, `hashCode`, `toString`) | yes |
| host barrel | `FloorPlanController.framingFor` (`@internal`) | rightly omitted |
| `editor.dart` | `framing:` + getter on `PlannerShell`, `PlannerView` | **no**: R-1 |
| `jet_cad_2d`, `jet_cad_2d_flutter`, `testing`, `export_testing`, `symbols`, `symbol_sources`, restaurant, GPU | none | — |

**The source diff behind it** (`git diff --stat v0.2.0..dcfff59 --
packages/`):
- `jet_cad_2d`, `jet_cad_2d_flutter`, `jet_cad_2d_gpu` and
  `jet_cad_restaurant_symbols` change only their `pubspec.yaml`.
- The planner's changes are in `host/` (the controller, types, view and
  service view, plus the new `table_fit.dart`), `planner_shell.dart`,
  `planner_view.dart` and `service/` (picker, group painter, the new
  `table_focus_painter.dart`).
- `lib/src/l10n` is untouched, so there is no new string.

**Behaviour a host may see, checked against the CHANGELOG:**
- **`fitToView()` reads the size when the fit is performed.** Listed.
  `_onFitRequest` now posts `_fit(_size!)` and no longer captures the
  size. `_size` is never reset to null, and `_fit` checks `mounted`.
- **Non-finite corners.** Listed; R-3 covers its wider reach.
- **`FloorPlanTable` `==`/`toString`.** Listed. `tables` listed
  hidden-layer tables at 0.2.0 too; now they carry `visible: false`.
- **The service view without a focus.** Unchanged: `TableFocusPainter`
  returns at once on a null focus (l. 85, 126 ff.), and the group painter
  has `faded = false` for every group. The overlay becomes a `Stack` of
  two `RepaintBoundary`s, and the `Key('table-group-chips')` is kept.
- **The fit target after a fit.** `fitted()` does not clear it (Z5), but
  only `load`/`newPlan` re-arm a first-frame fit, and both clear it. So
  a stale target never reframes unasked.
- **`fitToView()` replaces a pending `fitToTables`.** This is what "the
  last request wins" means. The guide l. 412–414 states it.

**Nothing listed is wrong.** I checked these against the source:
- 500 mm / 3 m (`kTableFitMarginMm`, `kTableFitMinSpanMm`).
- `false` with nothing changed (`_tablesBounds == null`, returning before
  any state is set).
- The no-view first-frame fit (`_fitPending` → `takeFitOnStart`).
- Faded tables still work: the veil is paint only.
- The focus is kept across `load` (no reset in `_replaceDesign`) and is
  never saved.

## Check 2 — the compatibility claim

The source facts:
- `kSchemaVersion = 8` (`packages/jet_cad_2d/lib/src/codec/schema_version.dart:38`).
- These are untouched since `v0.2.0` except for the pubspec version
  lines:

```
$ git diff --stat v0.2.0..HEAD -- packages/jet_cad_2d packages/jet_cad_2d_flutter \
    packages/jet_cad_restaurant_symbols packages/jet_cad_floor_plan/lib/src/host/service_layout.dart \
    packages/jet_cad_floor_plan/assets packages/jet_cad_floor_plan/lib/src/io packages/jet_cad_floor_plan/lib/src/l10n
 packages/jet_cad_2d/pubspec.yaml                 | 2 +-
 packages/jet_cad_2d_flutter/pubspec.yaml         | 2 +-
 packages/jet_cad_restaurant_symbols/pubspec.yaml | 2 +-
 3 files changed, 3 insertions(+), 3 deletions(-)
```

**A cross-tree round trip.** I placed a temporary test, outside git and
later removed, in each tree's `packages/jet_cad_floor_plan/test/`. It ran
in two halves:
- **Write.** Load the demo's `salon.json` (identical in both trees) into
  a `FloorPlanController`, take `designJson()`, switch to selection, move
  a table by (350, −125), and take `serviceLayoutJson()`.
- **Read.** In the *other* tree:
  1. Construct from that plan and require `designJson()` to equal it
     byte-for-byte.
  2. Compare `tables`.
  3. `restoreServiceLayout` it, requiring nothing dropped and every
     table's transform equal.
  4. Require `serviceLayoutJson()` to equal it byte-for-byte.

```
wrote 18926 B plan, 165 B layout, 11 tables, schema 8      # v0.2.0 tree
00:00 +1: All tests passed!
wrote 18926 B plan, 165 B layout, 11 tables, schema 8      # dcfff59 tree
00:00 +1: All tests passed!
read v020 in v030: plan and layout byte-equal, applied 1, dropped 0
00:00 +1: All tests passed!
read v030 in v020: plan and layout byte-equal, applied 1, dropped 0
00:00 +1: All tests passed!
$ cmp v020.design.json v030.design.json && echo "designs byte-equal"
designs byte-equal
$ cmp v020.layout.json v030.layout.json && echo "layouts byte-equal"
layouts byte-equal
```

The claim holds: 0.2.0 and 0.3.0 terminals can share plans and service
layouts in both directions.

## Check 3 — versions

```
$ grep -n "^version:" packages/*/pubspec.yaml
packages/jet_cad/pubspec.yaml:3:version: 0.3.0                 # dormant, since Plan 04 (R-6)
packages/jet_cad_2d/pubspec.yaml:5:version: 0.3.0
packages/jet_cad_2d_flutter/pubspec.yaml:6:version: 0.3.0
packages/jet_cad_2d_gpu/pubspec.yaml:6:version: 0.3.0
packages/jet_cad_floor_plan/pubspec.yaml:8:version: 0.3.0
packages/jet_cad_restaurant_symbols/pubspec.yaml:8:version: 0.3.0
```

I grepped for stale versions:
`git grep -nE '0\.2\.0|v0\.2|0\.3\.0|v0\.3' -- . ':!docs/superpowers' ':!packages/jet_cad' ':!*.lock' ':!*lock.txt'`.
- Every hit is historical, comparative, or one of the post-merge lines
  in Check 6.
- The rest are listed in R-6.
- Nothing stale needs to move.

Root lock and `analysis_options.yaml`:

```
$ flutter pub get | tail -1
Try `flutter pub outdated` for more information.
$ git status --short --untracked-files=no ; echo status-exit=$?
status-exit=0
$ git diff --stat v0.2.0..HEAD -- '*analysis_options.yaml' '*pubspec.lock'
(empty)
```

## Check 4 — `docs/host-guide.md`

- **Header** (l. 7): **0.3.0**.
- **§1:** it uses the placeholder form that 0.2.0's R-1 settled.
  - l. 18–19: "the SHA the release tag `v0.3.0` points at
    (`git rev-parse 'v0.3.0^{commit}'`; the guide on `main` names it)".
  - l. 29 and l. 34: `ref: <the commit SHA of v0.3.0>`.
  - l. 41: `ref: v0.3.0`.
  - This text is identical, version for version, to what `7355c00` (the
    0.2.0 tag) carried.
- **Markers:** "since 0.3.0" at l. 189 (`fitToTables` in §4) and l. 399
  (Zones). Every 0.2.0 behaviour keeps "since 0.2.0" (l. 127, 186, 224,
  226, 536, 543). `grep -n -i 'unreleased\|not yet released'` finds
  nothing.
- **The floor paragraph** (l. 51–55): "Flutter 3.44 or later; 0.3.0 was
  built and tested with Flutter 3.47.6". Both are true (Check 5 and
  `flutter --version`: `Flutter 3.47.6 • channel stable`).
- **Schema 8** (l. 543–547): "A plan saved by 0.2.0 or later is at schema
  8 … 0.2.0 and 0.3.0 save the same plans and service layouts". True
  (Check 2).
- **The Zones section** (l. 397–478) matches the source. That covers the
  trim, a hidden layer not framed, `false` changing nothing, the
  last-request rule, `load`/`newPlan` dropping the request, the focus
  kept, the empty-set and null semantics, and the inert-table recipe
  naming `onGroupTap` and `onMergeRequested`.

```
$ dart run tool/ci/check_guide.dart
docs/host-guide.md: all 16 code blocks are in the host probe
check_guide exit=0
$ cd tool/ci && dart test 2>&1 | tail -3
00:05 +56: test/scripts_test.dart: SC16 every live package is in the CI matrix
00:05 +57: test/scripts_test.dart: SC17 each app's web build asserts no flutter_scene assets
00:05 +58: All tests passed!
exit=0
```

## Check 5 — gates and the probe

`flutter analyze`:

```
== jet_cad_2d
No issues found! (ran in 2.0s)
exit=0
== jet_cad_2d_flutter
No issues found! (ran in 8.4s)
exit=0
== jet_cad_floor_plan
No issues found! (ran in 7.3s)
exit=0
== jet_cad_restaurant_symbols
No issues found! (ran in 4.2s)
exit=0
== jet_cad_2d_gpu
No issues found! (ran in 4.4s)
exit=0
== apps/restaurant_demo
No issues found! (ran in 5.4s)
exit=0
```

The planner and the demo:

```
$ cd packages/jet_cad_floor_plan && flutter test      # tail
04:15 +1437: All tests passed!
exit=0
$ cd apps/restaurant_demo && flutter test             # tail
00:24 +38: …/demo_test.dart: DZ2 the zones' three strings in German and Turkish (Z22)
00:25 +39: All tests passed!
exit=0
```

The host probe at the full SHA. The pub git cache for
`file:///tmp/rel3-review/repo` did not exist, so nothing needed
clearing.

```
$ git rev-parse HEAD
dcfff598fa58c2ddbd7d1848d9f44ade7da21d35
$ tool/ci/host_probe.sh "file:///tmp/rel3-review/repo" "$(git rev-parse HEAD)"; echo "probe exit=$?"
probe exit=0
# from its log:
/tmp/rel3-review/repo/tool/ci/host_probe/pubspec.lock: 40 packages, none of flutter_scene, flutter_gpu, flutter_gpu_shaders, scene, jet_cad_2d_gpu
Analyzing host_probe...
No issues found! (ran in 5.3s)
Compiling lib/main.dart for the Web...                             70.4s
✓ Built build/web
host probe: no GPU renderer, no build hook; build/web is 42M
```

The probe's lock resolves all four host packages at
`resolved-ref: dcfff598fa58c2ddbd7d1848d9f44ade7da21d35` (4 matches), at
`version: "0.3.0"`. After `pub get`, its `sdks:` reads
`dart: ">=3.13.0 <4.0.0"`, `flutter: ">=3.44.0"`.

The Flutter floor, in the probe:

```
$ flutter pub downgrade | tail -3
Changed 26 dependencies!
25 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
exit=0
sdks:
  dart: ">=3.12.0 <4.0.0"
  flutter: ">=3.44.0"
$ dart run ../check_host_lock.dart pubspec.lock
pubspec.lock: 40 packages, none of flutter_scene, flutter_gpu, flutter_gpu_shaders, scene, jet_cad_2d_gpu
lockcheck exit=0
$ flutter analyze           # at the downgraded versions
No issues found! (ran in 8.9s)
analyze exit=0
```

The floor of Flutter 3.44 (Dart 3.12) holds.

**Cleanup:** I removed `build`, `.dart_tool`, `pubspec.lock`,
`pubspec.yaml` and `.flutter-plugins-dependencies` from
`tool/ci/host_probe`. Afterwards, `git status --short --ignored
tool/ci/host_probe` was empty.

Not run: the engine's, the renderer's and the GPU package's test suites.
Their `lib/` and `test/` are unchanged since `v0.2.0`, and the slice's
results note records them green at `5022cc9`.

## Check 6 — the post-merge step, line by line (at `dcfff59`)

The merge SHA is `<S>`, and the tag `v0.3.0` → `<S>` is pushed by the
human.

**`docs/host-guide.md`**, the same three edits as `14616d9` made for
0.2.0:
- l. 18–19: "…points at\n(`git rev-parse 'v0.3.0^{commit}'`; the guide
  on `main` names it):" → "…points at,\n`<S>` (the merge of release
  0.3.0 into\n`main`):".
- l. 29: `ref: <the commit SHA of v0.3.0>` → `ref: <S>`.
- l. 34: the same.
- Unchanged: l. 7 (header), l. 41 (`ref: v0.3.0`), l. 52 (floor), and
  the markers.

**`STATUS.md`**
- l. 3–4: "`main` carries release 0.2.0 (tag `v0.2.0` → `7355c00`, …)" →
  0.3.0, `v0.3.0` → `<S>`, after `v0.2.0` → `7355c00`. Update "Last
  updated".
- l. 75–80, the Zone focus bullet: "(unreleased: CHANGELOG)" →
  "(released in 0.3.0)".
- l. 86–94, "In flight": the Release 0.3.0 bullet moves to "Where the
  project stands". It should carry:
  - "merged into `main` at `<S>`" and the human's words;
  - the review's verdict and the ledger link
    (`docs/superpowers/ledgers/2026-10-08-release-0.3.0/`);
  - "the guide names `<S>`";
  - the tag pushed by the human, once it is.

  "In flight" is then empty, or names the next item.
- l. 129–133, "Resume here": "Next: release 0.3.0 … its review, then the
  merge question" → the next item. "a consumable version (0.2.0,
  tagged)" → "(0.3.0, tagged at `<S>`)". "zones (on `main`; 0.3.0
  carries them)" → "zones (0.3.0)".
- "Owed": unchanged. Q-Z3, Q2, the reads and the GPU device run are all
  still owed. Add R-2's limit there if the human wants it tracked.

**`roadmap/00-README.md`**, row 14 (l. 267):
- "**Zone focus** … (**merged at `ffe8cb8`**, unreleased; a look owed)" →
  "…, released in 0.3.0; a look owed".
- After "**Release 0.2.0**: merged at `7355c00`, tag `v0.2.0`.", add
  "**Release 0.3.0**: merged at `<S>`, tag `v0.3.0`."

**`CHANGELOG.md`:** nothing. No section names a SHA, and
"## Unreleased — Nothing yet." stays.

**The ledger:** `.superpowers/sdd/2026-10-08-release-0.3.0/` (this file
and any others) is archived to
`docs/superpowers/ledgers/2026-10-08-release-0.3.0/`. 0.2.0 did this on
the branch before the merge (`5d5fbdb`).

**`tool/ci`:** no edit needed.
- `lib/guide.dart` l. 28 rewrites every `ref: .*` to `ref: REF`.
- `test/guide_test.dart` GD4 drops the first `ref:` line by pattern.
- `host_probe/pubspec.yaml.in` uses `@REF@`.
- `grep -rn "7355c00\|v0\.2\|v0\.3\|0\.3\.0" tool/ci` finds only the
  `scene: ">=0.3.0"` fixture in `host_lock_test.dart` (R-6).

**Simulated** in my clone with a dummy 40-hex `<S>`, then reverted:

```
 docs/host-guide.md | 9 +++++----
 1 file changed, 5 insertions(+), 4 deletions(-)
docs/host-guide.md: all 16 code blocks are in the host probe
check_guide exit=0
00:00 +5: All tests passed!          # tool/ci test/guide_test.dart
guide_test exit=0
reverted
```

The placeholder form at `dcfff59` passes too: `check_guide` exit 0, and
`tool/ci` 58 of 58, including `guide_test` (Check 4).

## Check 7 — what a POS pinning 0.3.0 would meet

- **Resolution in Monépro's real graph.** I copied Monépro's
  `pubspec.yaml` and `pubspec.lock` (develop, `88c96e0`) to
  `/tmp/rel3-review/monepro-res`. There I added the guide's two git
  dependencies at `file:///tmp/rel3-review/repo` @ `dcfff59…`; nothing in
  Monépro was touched.

  ```
  $ flutter pub get | tail -4
    yaml 3.1.3 (3.1.4 available)
  Changed 6 dependencies!
  88 packages have newer versions incompatible with dependency constraints.
  Try `flutter pub outdated` for more information.
  exit=0
  $ dart run …/tool/ci/check_host_lock.dart pubspec.lock
  pubspec.lock: 190 packages, none of flutter_scene, flutter_gpu, flutter_gpu_shaders, scene, jet_cad_2d_gpu
  lockcheck exit=0
  # versions changed against Monépro's lock:
  jet_cad_2d None -> 0.3.0
  jet_cad_2d_flutter None -> 0.3.0
  jet_cad_floor_plan None -> 0.3.0
  jet_cad_restaurant_symbols None -> 0.3.0
  pdf 3.13.0 -> 3.13.1
  printing 5.15.0 -> 5.15.1
  ```

  Monépro pins Flutter 3.47.6 in all four workflows, which is above the
  floor. See R-5.
- **Known limits accuracy.** The four listed limits are true:
  - The focus's look is unchecked (Q-Z3 in STATUS "Owed").
  - Q2 is still owed.
  - No native German or Turkish read has been done.
  - The GPU package, `packages/jet_cad` and the apps are not part of the
    release.

  Missing: Q-Z1 and Q-Z4 (R-2). The results note's other open items stay
  out of a host's Known limits:
  - Headless Chromium with the `en-US@posix` locale fails at app start,
    which is the same at 0.2.0 and is the apps' issue.
  - A table near 1e308 has not been tried on the web renderers. Only a
    hand-edited file has one.
- **Monépro does not depend on jet-cad yet:** no `jet_cad` in its
  `pubspec.yaml`, `lib/` or `test/`. Its floor view is phase 2 (spec 103
  §8, §10), so nothing in Monépro breaks today.

---

## Controller's disposition

- R-1: applied; the 0.3.0 section lists `editor.dart`'s `framing:` on
  `PlannerShell` and `PlannerView`.
- R-2: applied; Known limits names the missing world-to-screen mapping
  (Q-Z1) and the link by number (Q-Z4).
- R-3: applied; the non-finite line says picked, framed or counted in a
  group's frame.
- R-4: applied as a CHANGELOG line (a class implementing
  `FloorPlanController` must add the new members), though the sentence
  was exact.
- R-5, R-6: info, nothing to change.
