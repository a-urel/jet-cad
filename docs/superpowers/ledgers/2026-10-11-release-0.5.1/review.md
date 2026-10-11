# Release 0.5.1 — independent review

**Target:** `release/0.5.1` at `eee57d44` (`eee57d4462a461600a842d3fd5868b376cf3dff0`,
"chore: version 0.5.1 and its changelog"), one commit on `main`'s `7854b69`.
**Baseline:** `v0.5.0` = `2fbb9c0`. **In range:** F-7 (merge `f279ce8`) and
the view replacement (merge `3f374dc`).

**Setup:**
- A review worktree at `/Users/ahmeturel/Projects/oss/jet-cad-0.5.1-review`, detached at `eee57d44`.
- A scratch worktree at `v0.5.0`.
- `flutter pub get` once in each, then `git status --short` empty.
- Flutter 3.47.6 on macOS.
- The 0.5.0 review's API dump tool (analyzer 13.3.0) and its differential tests were reused.

Untouched: the release worktree and the main checkout. Nothing was committed, pushed, tagged or merged. Every temporary test was removed, and `git status --short` was empty after each run. Both worktrees were removed afterwards.

## Verdict

**Approved with fixes.** Every host-relevant check is green:

- **API.** Of the ten barrels, three signatures change. All three are in `editor.dart` (internal), and each only gains an optional named parameter. The host barrel `jet_cad_floor_plan.dart`, `jet_cad_restaurant_symbols`, `jet_cad_2d` and `jet_cad_2d_flutter` are identical, line for line.
- **Old host probes.** The `v0.5.0`, `v0.4.0` and `v0.3.0` probes all analyse clean against `eee57d44`.
- **Stored data.** Schema 9 and service layout version 1 are unchanged. The same edits save the same bytes at both commits. Each release reads the other's plans and layouts byte for byte.
- **Versions.** The five pubspecs, and nothing else, are at 0.5.1. The guide is consistent, and STATUS's in-flight entry is accurate.
- **Gates run here.** All green.

The one fix, R-1, is a guide sentence that understated 0.5.0's failure. R-2 to R-5 are optional wording.

## Findings

### R-1 — Minor: the guide understated what a replaced view did in 0.5.0

`docs/host-guide.md:229-230` said "up to 0.5.0 it threw for that frame."

At `v0.5.0`, a probe replaced `FloorPlanView(key: 1)` with `FloorPlanView(key: 2)` over the same controller:
- The new view's shell failed to build, with a `StateError`: "the dispatcher already has an expander".
- Its place held an `ErrorWidget` for as long as the probe pumped (still there after 2.5 s, in both modes).
- It recovered only when the controller next notified: a `setMode` round trip brought the `ErrorWidget` count to 0.

**Fix:** "…up to 0.5.0 the new view failed to build, an error in its place until the controller next changed."

**Applied** to the guide and to the CHANGELOG bullet.

### R-2 — Info: "but for the two above" counted a limit that was never listed

`CHANGELOG.md:41`. Only F-7 was a listed known limit (0.4.0's Known limits; 0.5.0's are "0.4.0's stand"). The view replacement was a Slice 4 result that never reached a CHANGELOG.

**Fix:** "0.5.0's stand, but for F-7 (above)." **Applied.**

### R-3 — Info: the probe claim holds, and can be stated exactly

`CHANGELOG.md:42-43`. Evidence:
- `git diff v0.4.0 v0.5.0 -- tool/ci/host_probe/lib/main.dart` is empty.
- The blob is `ba8c9e55` at `v0.4.0`, `v0.5.0` and `eee57d44`. At `v0.3.0` it is `30a8387c`, 319 lines against 870.
- `old_host_probe.sh v0.5.0` is green.

**Wording:** "0.5.0's probe is 0.4.0's, byte for byte (0.5.1's too), so it adds nothing." **Applied.**

### R-4 — Info: the guide called lasting cases "a transition"

`docs/host-guide.md:230-233`. An `IndexedStack`, kept-alive tabs, or a route pushed over another (`maintainState`) keep both views mounted indefinitely, not "for a while".

**Wording:** "Anything that keeps two views of one controller mounted at once counts as side by side, for a moment or for good: an `AnimatedSwitcher` between them, a route showing one pushed over or replacing a route showing the other, an `IndexedStack` or kept-alive tabs holding both." **Applied.**

### R-5 — Info: what changed for side-by-side views is when the error comes, not where it goes

`CHANGELOG.md:36-38`. `FlutterError.onError` was captured with two views in a `Row`:
- **0.5.0:** one report, the dispatcher `StateError`, in the context "building ListenableBuilder(…FloorPlanController…)", with an `ErrorWidget`.
- **0.5.1:** one report, "a FloorPlanController is shown in one FloorPlanView at a time…", in the context "during a scheduler callback", with no `ErrorWidget`.

**Wording:** "…now from a post-frame callback (still through `FlutterError.onError`) rather than while the second view builds." **Applied**, in the form "still raise a `StateError` through `FlutterError.onError`, now from the end of the frame both are built in rather than while the second one builds".

Folding the `editor.dart` additions into the F-7 bullet is fine. The public getter `SymbolMoveResolver.canRotate` comes with the parameter of the same name.

### R-6 — Info: other version strings, correctly left alone

- `packages/jet_cad/pubspec.yaml` stays at 0.3.0 (the dormant line).
- `.github/workflows/ci.yml:168,170` and `tool/ci/test/scripts_test.dart:286` name `v0.3.0` and `v0.4.0`. A `v0.5.0` step would analyse the same `main.dart` (R-3).
- STATUS's header ("`main` carries release 0.5.0") is correct until the merge; the post-merge commit moves it.
- STATUS's history lines, roadmap row 14, and the guide's "since 0.4.0" markers are history.

## Check 1 — API compatibility

```
$ dart run bin/apidump.dart <old=v0.5.0> … > old.api   → old=0
$ dart run bin/apidump.dart <new=eee57d44> … > new.api → new=0
   7889 old.api / 7891 new.api
names per barrel (old|new): jet_cad_2d 248|248, testing 5|5, jet_cad_2d_flutter 180|180,
  export_testing 16|16, jet_cad_floor_plan 50|50, editor 349|349, symbols 16|16,
  symbol_sources 4|4, jet_cad_restaurant_symbols 6|6, jet_cad_2d_gpu 9|9
$ diff old.api new.api
< editor.dart :: SymbolMoveResolver .. SymbolMoveResolver({required WallFaces faces, required SymbolLibrary? Function() library})
> editor.dart :: SymbolMoveResolver .. SymbolMoveResolver({…, bool Function()? canRotate})
> editor.dart :: SymbolMoveResolver .. bool Function()? get canRotate
> editor.dart :: SymbolMoveResolver .. field bool Function()? canRotate
< editor.dart :: WallFaces .. attach(…, {required bool mirrored, required double edgeCaptureWorld, Handle? exclude})
> editor.dart :: WallFaces .. attach(…, {…, Handle? exclude, Transform2? keep})
< editor.dart :: attachToWall :: function … {…, Handle? exclude})
> editor.dart :: attachToWall :: function … {…, Handle? exclude, Transform2? keep})
```

- `SymbolMoveResolver` and `WallFaces` are `final class`, so no host override can break.
- `DocumentSystems` is not exported.
- The test changes in range are additions only, in three files, so every 0.5.0 test runs unchanged.

The probes, in the review worktree:

```
$ tool/ci/host_probe.sh "file:///…/jet-cad-0.5.1-review" eee57d4462a461600a842d3fd5868b376cf3dff0
…/host_probe/pubspec.lock: 40 packages, none of flutter_scene, flutter_gpu, flutter_gpu_shaders, scene, jet_cad_2d_gpu
No issues found!
✓ Built build/web
host probe: no GPU renderer, no build hook; build/web is  42M        probe exit=0
$ tool/ci/old_host_probe.sh v0.5.0   → No issues found! … exit=0
$ tool/ci/old_host_probe.sh v0.4.0   → No issues found! … exit=0
$ tool/ci/old_host_probe.sh v0.3.0   → No issues found! … exit=0
```

## Check 2 — stored data

**Formats:**
- `kSchemaVersion = 9` (`packages/jet_cad_2d/lib/src/codec/schema_version.dart:48`).
- `kServiceLayoutFormat = 'jet_cad.service_layout'` and `kServiceLayoutVersion = 1` (`service_layout.dart:14,17`).
- Outside the two fixes, the range changes only pubspec version lines and one doc comment.

**Same edits, same bytes**, from temporary tests run in both trees:
- **F-7 under `full`:** the F-7 test's steps followed by two undos. Result: `attach: old == new byte for byte`, and `attach-undone: old == new byte for byte`.
- **The 0.5.0 review's `xfer_plain_test`,** through a mounted `FloorPlanView`, so `DocumentSystems` is in the path: `plain3`, `salon-empty` and `salon-undone` are each `old == new byte for byte`.
- **The 0.5.0 review's `xfer_review_test`,** seeded by old (7352 B, schema 9):
  - Each tree deletes, undoes to the input, and saves a 169 B layout.
  - Each tree then reads the other's files byte-equal and clean, and the layouts restore and apply both ways.
  - `cmp`: the layouts and the deletes are byte-equal.

Under `rotate: false`, F-7 deliberately stores a different transform for an `against-wall` move or placement. That is the fix, not a format change.

## Check 3 — behaviour change

Probes at both commits, in both modes, on the editor fixture:

| Case | 0.5.0 | 0.5.1 |
|---|---|---|
| View replaced (new key) | `StateError` "dispatcher already has an expander"; an `ErrorWidget` until the controller notifies (R-1) | no exception, no `ErrorWidget` |
| Two views in a `Row` | 1 report "building ListenableBuilder…", an `ErrorWidget` | 1 report "…one FloorPlanView at a time…", "during a scheduler callback", no `ErrorWidget` |
| `AnimatedSwitcher` between two views | `StateError` (dispatcher), an `ErrorWidget` | `StateError` (one view at a time), no `ErrorWidget` |

`ServiceView` uses `_c.activeDocument`, so the selection mode shares the same `DocumentSystems` and behaves as the design mode does.

## Check 4 — CHANGELOG

- **Intro.** "Nothing is stored differently" and "Nothing a 0.5.0 host calls changes its signature" hold. The Flutter line is unchanged.
- **F-7 bullet.** "A known limit of 0.4.0 and 0.5.0" and "Under `rotate: true` nothing changes" hold: with `keep == null` the path is unchanged, and the same-bytes differential confirms it.
- **The replacement bullet.** Accurate, with R-1 and R-5 applied.
- **Style.** It follows 0.5.0's.

## Check 5 — versions and docs

- **Versions.** `jet_cad` stays at 0.3.0 (dormant). The five released packages are at 0.5.1, the apps at 0.0.1, and `tool/ci` at 0.1.0.
- **Guide.** Every `0.5.` mention is consistent. §1 is identical to `v0.5.0`'s, version for version.
- **The post-merge guide edit, simulated.** `a9f7362`'s diff, with 0.5.0 → 0.5.1 and a dummy SHA, applies. `check_guide` then reports "all 48 code blocks are in the host probe", and `test/guide_test.dart` reports `+5: All tests passed!`. The edit was reverted afterwards.
- **Stray versions.** None outside the five pubspecs, STATUS and the roadmap row (R-6).
- **STATUS's in-flight entry.** Accurate.

## Check 6 — gates (review worktree)

```
packages/jet_cad_restaurant_symbols$ flutter test        → +97: All tests passed!   exit=0
packages/jet_cad_restaurant_symbols$ flutter analyze     → No issues found!         exit=0
packages/jet_cad_floor_plan$ flutter analyze             → No issues found!         exit=0
packages/jet_cad_floor_plan$ dart format --output=none --set-exit-if-changed .  → 284 files (0 changed)  exit=0
tool/ci$ dart run check_guide.dart                       → all 48 code blocks are in the host probe  exit=0
tool/ci$ dart test                                       → +63: All tests passed!   exit=0
packages/jet_cad_floor_plan$ flutter test test/host/view_replace_test.dart test/host/against_wall_rotate_test.dart test/symbols/wall_attach_test.dart
                                                         → +34: All tests passed!   exit=0
```

The whole planner, engine and render suites were left to the release's own gate run.

## The release's own gate run (at `eee57d44`, the release worktree)

| Package / check | Result |
|---|---|
| engine | 1283 tests; standing set exactly; `dart analyze --fatal-infos` and format clean |
| render | standing set but text-ladder rungs 1–2 (passing on macOS, the known difference); analyze, format clean |
| gpu | 20 tests; standing set exactly |
| planner | 1931 tests (`--enable-vmservice`); standing set exactly |
| restaurant symbols | 97 tests |
| `apps/floor_planner` | 212 tests |
| `apps/restaurant_demo` | 68 tests |
| `tool/ci` | 63 tests; `check_guide` green |
| host probe | exit 0, by `file://` at `eee57d44`; 42M web build, no GPU renderer, no build hook |
| old probes | `v0.3.0` and `v0.4.0` analyse against `eee57d44` |
