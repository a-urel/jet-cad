# Release 0.2.0 — independent review

**Target:** `claude/exciting-pasteur-9m22jv` at `4e70588`
(`6d5db7d` + `4e70588` on `main`'s `79456ee`). Compared against `v0.1.0`
= `22206f5`.
**Reviewer's setup:** own clone at `/tmp/rel-review/repo`, detached at
`4e70588`; a worktree of `22206f5` at `/tmp/rel-review/old`; Flutter
3.47.6 (`/root/sdk/flutter`), `CI=true`. Nothing committed; nothing
written in `/home/user/jet-cad` except this file.

## Verdict

**Approved with fixes.** The versions, the lock, the gates and the
probe are all green, and every API removal or rename in the host barrels
is in the CHANGELOG, correctly. No change that breaks a host is left
unmarked: the one new abstract member is marked breaking, and the
`setMode` change can't be seen through API, because `camera` is
`@internal`. Two things need settling **before the tag**: R-1 (the tagged
tree's guide pins 0.1.0 under text that describes 0.2.0) and R-2 (the N1
behaviour ships while its ruling, Q2, is still open). The rest are
CHANGELOG and guide wording.

## Findings

### R-1 — Moderate: at the tag, the guide's header, pin and body disagree

At `4e70588`, and so at the merge commit that will carry `v0.2.0`,
`docs/host-guide.md` has these problems:
- It says it "covers release **0.1.0**" (l. 6–7).
- It pins `22206f527e…` (l. 18–20, 30, 35) and `ref: v0.1.0` (l. 42).
- Its body describes 0.2.0. Line 52 says "The packages need Flutter 3.44
  or later", which is false for the SHA it pins: 0.1.0 needs 3.47. It
  also has the "since 0.2.0" markers.

A host that reads the guide at tag `v0.2.0` is told to pin 0.1.0. Only
the SHA has to wait for the merge, because a commit cannot hold its own
SHA. The header and the tag name don't have to wait.

0.1.0 did this differently. Its release branch carried the placeholder
`ref: <the commit SHA of v0.1.0>`, and `26f5fce` filled it in after the
merge.

**Fix (on the branch, before the merge):**
- l. 7: change to `0.2.0`.
- l. 18: change to `v0.2.0`.
- l. 19–20: change to "the merge of release 0.2.0 into `main`".
- l. 30 and l. 35: change to `ref: <the commit SHA of v0.2.0>`.
- l. 42: change to `ref: v0.2.0`.
- The post-merge commit then replaces only the two placeholders and the
  SHA in l. 19.

I checked that the placeholder form passes both checks: `check_guide`
exits 0 and `tool/ci` `guide_test.dart` passes 5 of 5 (transcript under
Gates). If the human prefers the plan as written (everything changed
after the merge), record that the tagged tree's guide names 0.1.0, and
make the post-merge commit straight after the tag.

### R-2 — Moderate (decision for the human): N1 ships while Q2 is unruled

Two things now promise that a new plan takes the UI language's
separator, and that a controller's empty plan settles on the first
view's language:
- The 0.2.0 CHANGELOG.
- The guide (§3, §5, §10).

STATUS "Owed to the human" still lists *Q2's ruling* ("if `.` always,
`documentSeparatorFor` becomes a constant and the settling goes").
`roadmap/00-README.md` row 14 says "Q2 ruling and look owed".

If the ruling comes back "`.` always" after the tag, `newPlan()` and the
constructor change behaviour again in 0.3.0.

**Fix:** get the Q2 ruling before the tag. Otherwise, list it in a 0.2.0
"Known limits" (R-7): "a new plan's separator following the UI language
is provisional (Q2)".

### R-3 — Minor: the R-13 sentence in the guide has no version marker

Lines 186–188 say: "A switch keeps the plan where it is on the screen,
zoom included; `fitToView()` and `load` fit it again." This came in with
the cleanup batch (`c667ed6`) and is 0.2.0 behaviour. In 0.1.0 the
camera's numbers were kept, so the plan moved by the editor's panels and
rulers. Every other 0.2.0 behaviour in the guide carries *since 0.2.0*.

**Fix:** append "*(since 0.2.0; in 0.1.0 a switch kept the camera's
numbers, so the plan moved by the editor's panels and rulers)*". While
there, add `newPlan()` to "fit it again" (see R-5).

### R-4 — Minor: the CHANGELOG leaves out `editor.dart`'s additions

The mechanical barrel diff (below) shows `jet_cad_floor_plan`'s
`editor.dart` changed in two ways, and neither is in the CHANGELOG:
- It exports a new file, `src/l10n/document_separator.dart`, which
  provides `documentSeparatorFor(FloorPlanStrings)`.
- An optional `{DecimalSeparator decimalSeparator = DecimalSeparator.point}`
  parameter is added to `newDocument`, `defaultPage`, `startupPage`,
  `formatArea` and `formatDimension`.

In behaviour, `startupPlan(strings:)`'s page now takes the separator of
`strings`. None of this breaks anything: the parameters are optional
named ones.

**Fix:** add one bullet. "`jet_cad_floor_plan`'s `editor.dart`:
`documentSeparatorFor`; `decimalSeparator:` on `newDocument`,
`defaultPage`, `startupPage`, `formatArea`, `formatDimension`; the
sample plan (`startupPlan`) takes its strings' separator."

Not a host package, info only: `jet_cad_2d_gpu`'s `ResidentGeometry`
also gains the static `bundleAssetKey`, which is not in the GPU bullet's
list.

### R-5 — Minor: the Q0 and R-13 bullets skip host-visible rules

- **Q0 bullet.** It says "A new plan takes the UI language's separator"
  and "an empty plan a `FloorPlanController` creates takes the language
  of the first `FloorPlanView` that shows it". It leaves out three rules
  a host sees:
  - **`newPlan()`** takes the language a view of that controller **last**
    reported, not the first.
  - **`designJson()`**, or an edit, made before any view shows the
    constructor's plan keeps that plan at `.`.
  - The "UI language's" separator is **`FloorPlanStrings.decimalSeparator`**.
    A host's own strings class therefore now decides the separator of
    its new plans. That is a behaviour change for a host that implements
    `FloorPlanStrings`.

  The guide states the first two, but the CHANGELOG is what a host reads
  before upgrading.
- **R-13 bullet.** "`fitToView` and `load` still fit" leaves out
  `newPlan()` and a new controller. Both still fit, through
  `_replaceDesign` → `_fitOnStart = true`.

**Fix:** name `newPlan()`, `designJson()` and `FloorPlanStrings.decimalSeparator`
in the Q0 bullet. Change the R-13 bullet to "`fitToView`, `load` and
`newPlan` still fit".

### R-6 — Minor: schema 8 isn't labelled breaking

The intro puts schema 8 in bold ("Move every terminal … together"), but
its bullet is headed "**Schema 8.**". The bullets for the other two
breaks (`FloorPlanStrings` and the GPU types) are headed "**Breaking …**".
Schema 8 is the incompatibility most likely to hurt a POS fleet: once
any terminal saves a plan, the 0.1.0 terminals cannot load it.

**Fix:** head the bullet "**Breaking for stored plans: schema 8.**".

No other host break is unmarked. These are the ones I checked:
- `setMode`'s reframing can't be seen through API: `camera` is
  `@internal` and is not in the host barrel.
- `load` is unchanged except that it accepts schema 8.
- The new controller members (`canvasMeasured`, `reportLanguage`) are
  `@internal`, and the host barrel's `show` hides them.
- `PageComponent`, `formatLength` and the `editor.dart` functions gain
  only optional named parameters or fields.
- `resolveBackend(residentGpu)` falls back to `vertices` unless
  `installResidentGpu()` was called. No host requests `residentGpu`, and
  the CHANGELOG says so.

### R-7 — Minor: 0.2.0 has no "Known limits"

0.1.0's section ended with Known limits, as its plan's Task 1 required.
0.2.0's has none, though these are still true:
- The German and Turkish text has not had a native read.
- Q2 is assumed (R-2).
- `jet_cad_2d_gpu`'s device run is owed. It is the harness's, but worth
  one line.
- `packages/jet_cad`, the apps and `jet_cad_2d_gpu` are not part of the
  release.

**Fix:** add a short "Known limits" to 0.2.0 that carries these. This
also answers why `jet_cad_2d_gpu` is at 0.2.0 even though the header
says "four packages".

### R-8 — Minor: `packages/jet_cad_2d/CHANGELOG.md` is stale

That file's only entry is "## 0.1.0 — Initial development release.
Engine core: …", from Plan 04, but its pubspec now says `0.2.0`. It is
the one per-package changelog of a release package. `packages/jet_cad`'s
is dormant.

**Fix:** replace its content with a pointer to the root `CHANGELOG.md`,
or delete it.

### R-9 — Info: other "0.1.0" strings, correctly left alone

- `tool/ci/pubspec.yaml` (`jet_cad_ci`) and `tool/ci/host_probe/pubspec.yaml.in`
  (the probe app's own version) are not release packages. No check reads
  them as the release version.
- The `tool/ci/test/fixtures/host_*_split.lock.txt` files are recorded
  fixtures.
- `.vscode/launch.json`'s `"version": "0.2.0"` is the launch-config
  schema version.
- In `STATUS.md`, `STATUS-HISTORY.md` and `docs/host-guide.md`, the
  "0.1.0" mentions that remain are historical or comparative, apart from
  the post-merge lines listed below.

## Check 1 — the CHANGELOG against `git diff 22206f5..4e70588 -- packages/`

**Method.** A small analyzer-13.3.0 tool (in `/tmp/rel-review/apidump`,
outside the repo) resolved each barrel at both commits. It dumped each
exported name and each public member's signature, with `abstract`,
`static` and `@internal` flags. I then diffed the two dumps. The barrels:
- `jet_cad_2d`: `jet_cad_2d.dart`, `testing.dart`.
- `jet_cad_2d_flutter`: `jet_cad_2d_flutter.dart`, `export_testing.dart`.
- `jet_cad_floor_plan`: `jet_cad_floor_plan.dart`, `editor.dart`,
  `symbols.dart`, `symbol_sources.dart`.
- `jet_cad_restaurant_symbols.dart`.
- At `4e70588` only: `jet_cad_2d_gpu.dart`.

Result: 4747 lines at 0.1.0, 4795 at 0.2.0, and 107 changed lines
outside the GPU barrel. In summary:

| Barrel | Change | In CHANGELOG |
|---|---|---|
| `jet_cad_2d` | `enum DecimalSeparator {point, comma}` + `char`; `PageComponent.decimalSeparator`, ctor/`copyWith` param; `formatLength(…, {decimalSeparator})`; `kSchemaVersion` 7 → 8 (value) | yes |
| `jet_cad_2d_flutter` | removed: `GpuDrawBackend`, `ResidentGeometry`, `ResidentPatch`, `debugSetGpuAvailable`, `uploadResidentCollection` | yes (breaking, correct) |
| `jet_cad_2d_flutter` | added: `ResidentGpu` (abstract interface: `available`, `upload`), `registerResidentGpu`, `registeredResidentGpu`, `ResidentLayout` (`kCornerVertices`, `byteLengthFor`, `cornerVertexCount`, `kFloatsPerCorner`), `kFloatsPerInstance`, `InstanceFieldOffset` | yes |
| `jet_cad_2d_flutter` | `frame_info.dart` newly exported, but none of its names is new to the barrel (they moved there) | n/a |
| `jet_cad_2d_gpu` (new) | `GpuDrawBackend`, `ResidentGeometry` (+ new static `bundleAssetKey`), `ResidentPatch`, `uploadResidentCollection`, `installResidentGpu`, `gpuAvailable`, `debugSetGpuAvailable`, `debugSetGpuFactory`, `GpuContextFactory` | yes, except `bundleAssetKey` (info) |
| `jet_cad_floor_plan` (host barrel) | `FloorPlanStrings.pageDecimalSeparator` (abstract) + De/En/Tr overrides; `FloorPlanController.canvasMeasured`, `.reportLanguage` (`@internal`) | yes (breaking, correct); internals rightly omitted |
| `jet_cad_floor_plan/editor.dart` | `documentSeparatorFor`; `decimalSeparator:` on `defaultPage`, `newDocument`, `startupPage`, `formatArea`, `formatDimension` | **no** — R-4 |
| `testing.dart`, `export_testing.dart`, `symbols.dart`, `symbol_sources.dart`, `jet_cad_restaurant_symbols.dart` | none | — |

**Schema.** `kSchemaVersion = 8`. `PageComponent.toJson` always writes
`decimalSeparator`, and `fromJson` treats a missing key as `point`. Both
bundled `.jetlib` files are re-encoded at `"schemaVersion":8`. All of
this is in the CHANGELOG.

**Flutter floor.**
- `jet_cad_2d_flutter`, `jet_cad_floor_plan` and
  `jet_cad_restaurant_symbols` declare `flutter: ">=3.44.0"`.
- `jet_cad_2d_gpu` declares `">=3.47.0"`, and it is not a host package.
- The CHANGELOG's "3.44" and the "about 12 MB" (54 → 42 MB) match the
  GPU split's note and this probe's `42M`.

**l10n.** `FloorPlanStrings` gains exactly one member,
`pageDecimalSeparator`. The Page panel's segments are the literals
`1.5` and `1,5`, the same in every language, by design.

**Behaviour.**
- R-13 (`setMode` reframes, also with no view; a post-frame
  `canvasMeasured` correction): listed. Wording in R-5.
- Q0 settling (constructor, `newPlan`, `designJson`): partly listed
  (R-5).
- Rulers, dimensions and room areas print the page's separator: listed.
- `resolveBackend` needs a registered `ResidentGpu`: listed ("used only
  after `installResidentGpu()`").

**Nothing listed is wrong.** I checked each name in the GPU bullets
against the dumps. "a subclass of a built-in language inherits it" is
true, because `FloorPlanStringsDe`, `FloorPlanStringsEn` and
`FloorPlanStringsTr` are plain `class … extends FloorPlanStrings`.

## Check 3 — the versions

- All five `pubspec.yaml` say `version: 0.2.0`: `jet_cad_2d`,
  `jet_cad_2d_flutter`, `jet_cad_2d_gpu`, `jet_cad_floor_plan`,
  `jet_cad_restaurant_symbols`.
- I grepped the repo for `0\.1\.0|v0\.1|0\.2\.0|v0\.2`, excluding
  `docs/superpowers/`, `packages/jet_cad/` and lock files. The only
  stale version left is `packages/jet_cad_2d/CHANGELOG.md` (R-8). The
  rest is R-9, or the post-merge lines below.
- **The root `pubspec.lock` is unchanged by `flutter pub get`**:
  `git status --short` printed nothing afterwards. It is also unchanged
  across the whole `22206f5..4e70588`
  (`git diff --stat 22206f5..4e70588 -- '*pubspec.lock'` is empty).
- **No `analysis_options.yaml` was changed on the branch**
  (`git diff --stat 79456ee..4e70588 -- '*analysis_options.yaml'` is
  empty). Since 0.1.0, the only one is the new, tracked
  `packages/jet_cad_2d_gpu/analysis_options.yaml` from the GPU split. It
  was committed on purpose at scaffold, per that split's Task 1 review.

## Check 4 — `docs/host-guide.md`

- Every marker reads "since 0.2.0": l. 128, 222–224, 451 and 458. None
  still says "unreleased". (`grep -i 'unreleased\|not yet released\|on
  `main`'` finds nothing in the guide.)
- **The floor paragraph** (l. 52–56) is true of 0.2.0. Downgrade gives
  Flutter ≥3.44 and Dart ≥3.12, built here with 3.47.6, and the probe
  shows no `hooks_runner`. Its aside about 0.1.0 (3.47, `flutter_scene`)
  is also true. At the tag, though, it sits under a 0.1.0 header and a
  0.1.0 pin: R-1.
- **0.2.0 behaviour described without a marker:** the R-13 sentence
  (R-3). No 0.1.0 behaviour is claimed for 0.2.0.
- `dart run tool/ci/check_guide.dart` passes (below).

## Check 5 — gates (output as run)

`tool/ci` tests:

```
$ cd tool/ci && dart test 2>&1 | tail -5
00:03 +54: test/scripts_test.dart: SC15 host_probe.sh after the build main.dart.js names cad.shaderbundle: exit 1
00:03 +55: test/scripts_test.dart: SC15 host_probe.sh after the build no main.dart.js: exit 1
00:03 +56: test/scripts_test.dart: SC16 every live package is in the CI matrix
00:03 +57: test/scripts_test.dart: SC17 each app's web build asserts no flutter_scene assets
00:03 +58: All tests passed!
exit=0
```

Guide check:

```
$ dart run tool/ci/check_guide.dart
docs/host-guide.md: all 14 code blocks are in the host probe
check_guide exit=0
```

`flutter analyze` in each package:

```
== jet_cad_2d
No issues found! (ran in 10.4s)
exit=0
== jet_cad_2d_flutter
No issues found! (ran in 11.8s)
exit=0
== jet_cad_floor_plan
No issues found! (ran in 8.9s)
exit=0
== jet_cad_restaurant_symbols
No issues found! (ran in 2.9s)
exit=0
== jet_cad_2d_gpu
No issues found! (ran in 3.0s)
exit=0
```

Host probe at the full SHA:

```
$ git rev-parse HEAD
4e7058820e4be116edb8c7ab74f172e07c587fb7
$ tool/ci/host_probe.sh "file://$PWD" "$(git rev-parse HEAD)"   # tail
/tmp/rel-review/repo/tool/ci/host_probe/pubspec.lock: 40 packages, none of flutter_scene, flutter_gpu, flutter_gpu_shaders, scene, jet_cad_2d_gpu
Analyzing host_probe...
No issues found! (ran in 4.7s)
Compiling lib/main.dart for the Web...                             61.6s
✓ Built build/web
host probe: no GPU renderer, no build hook; build/web is 42M
probe exit=0
```

The probe's lock resolves all four host packages at `resolved-ref:
"4e7058820e4be116edb8c7ab74f172e07c587fb7"` and `version: "0.2.0"`.
After `pub get` its `sdks:` reads `dart: ">=3.13.0 <4.0.0"`,
`flutter: ">=3.44.0"`.

Downgrade in the probe:

```
$ flutter pub downgrade | tail -4
Changed 26 dependencies!
25 packages have newer versions incompatible with dependency constraints.
exit=0
sdks:
  dart: ">=3.12.0 <4.0.0"
  flutter: ">=3.44.0"
$ dart run ../check_host_lock.dart pubspec.lock
pubspec.lock: 40 packages, none of flutter_scene, flutter_gpu, flutter_gpu_shaders, scene, jet_cad_2d_gpu
lockcheck exit=0
$ flutter analyze        # at the downgraded versions
No issues found! (ran in 8.7s)
```

So the floor of Flutter 3.44 (Dart 3.12) holds at this commit. Cleanup:
`build/`, `.dart_tool/`, `pubspec.lock`, `pubspec.yaml` and
`.flutter-plugins-dependencies` are removed from `tool/ci/host_probe`.
`git status --short --ignored tool/ci/host_probe` is empty.

The post-merge guide edit, simulated in my clone and then reverted. I
replaced the SHA with a dummy 40-hex value, `v0.1.0` with `v0.2.0`, and
the header with 0.2.0. Then I tried the placeholder form of R-1:

```
docs/host-guide.md | 12 ++++++------
docs/host-guide.md: all 14 code blocks are in the host probe
check_guide exit=0
00:00 +5: All tests passed!          # tool/ci test/guide_test.dart
--- placeholder form (R-1) ---
docs/host-guide.md | 4 ++--
docs/host-guide.md: all 14 code blocks are in the host probe
check_guide exit=0
00:00 +5: All tests passed!
```

## Check 6 — the post-merge step, line by line (at `4e70588`)

Once the merge SHA `<S>` exists (and `v0.2.0` → `<S>` is pushed):

**`docs/host-guide.md`**
- l. 7: `**0.1.0**` → `**0.2.0**`. Do this now if R-1 is taken.
- l. 18: "the release tag `v0.1.0` points at," → `v0.2.0`. Now if R-1.
- l. 19–20: `` `22206f527e32e4677fe706731a751ec9de0d751e` (the merge of
  14d into `main`): `` → `` `<S>` (the merge of release 0.2.0 into
  `main`): ``.
- l. 30: `      ref: 22206f5…` → `      ref: <S>`. Placeholder now if
  R-1.
- l. 35: `      ref: 22206f5…` → `      ref: <S>`. Placeholder now if
  R-1.
- l. 42: `` (`ref: v0.1.0`) `` → `` (`ref: v0.2.0`) ``. Now if R-1.
- l. 186–188: the R-13 marker, if R-3 isn't done before the merge.
- Unchanged: l. 52–56 (floor), l. 128, 222–224, 451–460 ("since 0.2.0"
  and the 0.1.0 comparisons). They are correct once the header says
  0.2.0.

**`STATUS.md`**
- l. 3–4: "`main` carries release 0.1.0 (tag `v0.1.0` → `22206f5`)" →
  0.2.0, `v0.2.0` → `<S>`. Update the "Last updated" date too.
- l. 18: "**Release 0.1.0**" bullet → 0.2.0, or add a 0.2.0 bullet.
- l. 48 "(unreleased: CHANGELOG)" and l. 59 "(unreleased: CHANGELOG)"
  → "(released in 0.2.0)".
- l. 66–73 "In flight": the release moves to "Where the project stands"
  with `<S>` and the tag. Record that the tag was pushed by the human.
- l. 103–108 "Resume here": "a release (0.2.0: … are unreleased on
  `main`) whose SHA the POS pins" → name `<S>` as the SHA the POS pins.
- Remove Q2 from "Owed" if R-2 is settled.

**`roadmap/00-README.md`** row 14 (l. 267):
- "(**merged at `032880c`**, unreleased; …)" → "…, released in 0.2.0;
  …".
- "(**merged at `56974b6`**, unreleased; …)" → "…, released in 0.2.0;
  …".
- Add "release 0.2.0, tag `v0.2.0` → `<S>`".

**`CHANGELOG.md`:** nothing needs `<S>`, because 0.1.0's section names
no SHA either. Leave "## Unreleased — Nothing yet."

**`tool/ci`:** no test pins the ref.
- `lib/guide.dart` turns every `ref:` into `ref: REF`.
- `test/guide_test.dart` GD4 drops the first `ref:` line by pattern
  (`7c66658`).
- `host_probe/pubspec.yaml.in` uses `@REF@`.
- `grep -rn '22206f5\|v0\.1' tool/ci` finds nothing outside the lock
  fixtures, which record versions, not refs.

So `tool/ci` needs no edit. The simulation above shows both edited
forms pass `check_guide` and `guide_test`.

**Also:**
- CI's run on `main` at `<S>`: `host-probe` builds at `<S>` by
  `file://`.
- If the 0.1.0 precedent (`7c66658`) is followed, write a
  results/release note under `docs/superpowers/notes/`.

---

## Controller's disposition

All applied in `426954e` (R-9 is info). R-1: the tagged commit's guide
covers 0.2.0 with a placeholder ref and the command that resolves the
tag's SHA; the commit after the merge names it. R-2: listed as a known
limit; the ruling is put to the human with the merge question.
