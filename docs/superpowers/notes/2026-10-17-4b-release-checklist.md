# 4b — the release wave: the human's checklist

**Date:** 2026-10-17.
**Branch:** `docs/4b-release-checklist`, worktree `.claude/worktrees/4b-release`,
cut by hand from local `main` at `a428dee7` (P2's removal merge `c9fa618e`,
P4's floors merge `89607a23`, P5's pictures merge `a428dee7`).
**Umbrella spec:** [2026-10-13-kit-architecture-design.md](../specs/2026-10-13-kit-architecture-design.md),
**A10** (versions and the release wave) and A13 (the wave is sub-project 4's
last step).
**Model:** the earlier release records,
[2026-10-13-release-0.7.0/](../ledgers/2026-10-13-release-0.7.0/review.md)
and
[2026-10-13-publish-host-packages/](../ledgers/2026-10-13-publish-host-packages/progress.md),
plus the 0.7.2 checklist in
[2026-10-13-package-readmes-results.md](2026-10-13-package-readmes-results.md)
and the 0.7.1 record in
[2026-10-13-publish-jet-cad-2d.md](2026-10-13-publish-jet-cad-2d.md).

This is the wave the kit architecture ends with: the old line's packages are
gone from the repository, the new line's packages are ready, and A10 says the
human publishes them. **This note ran no publish.** Every command it ran is
in [The dry-runs, run here](#the-dry-runs-run-here) and
[The gates run here](#the-gates-run-here).

The versions and the dependency floors were set by P4
([2026-10-17-4b-floors-report.md](2026-10-17-4b-floors-report.md)); the README
pictures by P5
([2026-10-17-4b-pictures-report.md](2026-10-17-4b-pictures-report.md)). This
note is the end of the prep and the publish order the human follows.

## The wave at a glance

A10's order: **the engine and the Flutter layer first, then the kit contract,
then the plan library and the two kits** (any order among the last three;
each is checked with pana's lower bounds once its dependencies are on
pub.dev). All six publish at the same version-number they already carry in
`main`; nothing in this note changes a version.

| # | Package | Version | CHANGELOG heading | Tag | Its hosted dependencies |
|---|---|---|---|---|---|
| 1 | `jet_cad_2d` | 0.7.3 | `## 0.7.3` | `jet_cad_2d-v0.7.3` | — |
| 2 | `jet_cad_2d_flutter` | 0.7.3 | `## 0.7.3` | `jet_cad_2d_flutter-v0.7.3` | `jet_cad_2d: ^0.7.3` |
| 3 | `jet_cad_2d_kit` | 0.1.0 | `## 0.1.0` | `jet_cad_2d_kit-v0.1.0` | `jet_cad_2d: ^0.7.3`, `jet_cad_2d_flutter: ^0.7.3` |
| 4 | `jet_cad_2d_plan` | 0.8.0 | `## 0.8.0` | `jet_cad_2d_plan-v0.8.0` | `jet_cad_2d: ^0.7.3`, `jet_cad_2d_flutter: ^0.7.3`, `jet_cad_2d_kit: ^0.1.0` |
| 5 | `jet_cad_2d_kit_architecture` | 0.1.0 | `## 0.1.0` | `jet_cad_2d_kit_architecture-v0.1.0` | `jet_cad_2d: ^0.7.3`, `jet_cad_2d_flutter: ^0.7.3`, `jet_cad_2d_kit: ^0.1.0` |
| 6 | `jet_cad_2d_kit_restaurant` | 0.1.0 | `## 0.1.0` | `jet_cad_2d_kit_restaurant-v0.1.0` | `jet_cad_2d: ^0.7.3`, `jet_cad_2d_kit: ^0.1.0` |

Notes on the table:

- The three CHANGELOG headings that still read `## 0.8.0 (unreleased)` or
  `## 0.1.0 (unreleased)` (the plan library and the two kits) and the plan
  library README's sentence *"Version 0.8.0 is unreleased: it ships with the
  kits of the next wave."* are turned in the prep commit
  `d9dd74d7` on this branch; they would otherwise ship as false on pub.dev.
  The engine's, the renderer's and the kit contract's headings already read
  their version.
- **The repository tags are the package's own name plus its version** —
  `<package>-v<version>`, Decision 4 of the host packages' spec — not the old
  shared `vX.Y.Z`. The six README image URLs already pin exactly these tags
  (`jet_cad_2d_flutter-v0.7.3`, `jet_cad_2d_plan-v0.8.0`,
  `jet_cad_2d_kit_architecture-v0.1.0`, `jet_cad_2d_kit_restaurant-v0.1.0`),
  and `tool/ci/check_screenshots.dart` holds the pin; the images resolve once
  each tag is pushed.
- `jet_cad_2d_gpu` and `jet_cad_2d_integration` are **not** in the wave:
  neither is published (both carry `publish_to: none`). The dormant
  `packages/jet_cad` is untouched and unpublished.

## Step 0 — merge this branch, push `main`, CI green

1. `git merge --no-ff docs/4b-release-checklist` into `main` (the human's
   word; the wave's prep — P4's versions and floors, this branch's headings
   and README — is then on `main`).
2. `git push origin main` and wait for CI on the merge commit to be green
   (all jobs; the `publishable` matrix runs all six dry-runs).
3. Call that commit **`<merge commit>`** below. Every package publishes from
   `main` at it, and every tag points at it.

Nothing is published before step 0. If CI is red, stop.

## Steps 1–6 — each package, in order

For each package in the table's order, the four actions below. Do them **one
package at a time** and finish a package (pana, dry run, publish, tag) before
the next, so each dependent's dependencies are on pub.dev before its pana
step.

### The four actions

**(a) The pana lower-bound check — once the package's dependencies are on
pub.dev.** D1's lower-bound rule (STATUS's "Rulings that still bind"): a
dependent's lower bound on each published sibling is raised to that sibling's
current version, and pana's lower-bounds section is run on the archive
*before* `dart pub publish`. pana runs `pub downgrade` itself. For package 1
the check can run at once (its dependencies are not jet-cad packages); for
package 2 it waits for 1; for 3 for 1–2; for 4–6 for the kit contract (3).

```bash
cd "$(git rev-parse --show-toplevel)"
rm -rf /tmp/jet-cad-pana && mkdir -p /tmp/jet-cad-pana
git archive <merge commit> packages/<pkg> | tar -x -C /tmp/jet-cad-pana
rm -rf /tmp/jet-cad-pana/packages/<pkg>/test \
       /tmp/jet-cad-pana/packages/<pkg>/build <the package's other .pubignore dirs>
dart pub global run pana --no-warning /tmp/jet-cad-pana/packages/<pkg>
```

The `.pubignore` directories to remove, per package: `jet_cad_2d`
`test build benchmark`; `jet_cad_2d_flutter` `test build shaders`;
`jet_cad_2d_kit` `test build`; `jet_cad_2d_plan` `test build`;
`jet_cad_2d_kit_architecture` and `jet_cad_2d_kit_restaurant` `test tool
build`. **What to read:** the *Support up-to-date dependencies* section's
lower-bounds line — it must pass. **If pana is not activated:** `dart pub
global activate pana`. The copied tree is not a git checkout; pana reads
`repository` from GitHub's `main`, which holds the copied package after step
0, so the repository check is the same one a real publish sees. Expect
160 / 160 for the renderer and the plan library, as 0.7.2 scored them; a
first release scores whatever its docs score (the 0.7.1 `jet_cad_2d` scored
150 / 160 for exactly one reason, a repository URL not yet on `main`).

**(b) The dry run.** From the package directory, at `<merge commit>`:

```bash
cd "$(git rev-parse --show-toplevel)/packages/<pkg>"
flutter pub publish --dry-run     # CI runs the same as: dart pub publish --dry-run
```

**Expected: `Package has 0 warnings.`, exit 0** — that is what the wave
recorded in P4 and what this note records below. Any warning (a modified
file, a missing entry) turns CI's `publishable` job red (exit 65); fix it
before publishing.

**(c) The publish — yours.** From the package directory:

```bash
cd "$(git rev-parse --show-toplevel)/packages/<pkg>"
dart pub publish
```

The upload answers `Successfully uploaded … version <version> …`. Do not
publish from a session; a session never runs this.

**(d) The tag — yours.** At `<merge commit>`, and push it, so the README
images resolve:

```bash
git tag <package>-v<version> <merge commit>
git push origin <package>-v<version>
```

### The packages, one block each

**1. `jet_cad_2d` 0.7.3** — tag `jet_cad_2d-v0.7.3`. The seams the kit wave
needed (the `exclude` drag snap, the catalog/enumeration hooks, the codec's
diagnostics) and 4a's O1; additive, no removal. pana lower bounds now (no
jet-cad dependencies). Then dry run, publish, tag.

**2. `jet_cad_2d_flutter` 0.7.3** — tag `jet_cad_2d_flutter-v0.7.3`. One
public field, `GripDrag.handles`; `SelectTool` passes the dragged selection
as the engine's `exclude`. pana after `jet_cad_2d` 0.7.3 is on pub.dev. Dry
run, publish, tag.

**3. `jet_cad_2d_kit` 0.1.0** — tag `jet_cad_2d_kit-v0.1.0`. The kit contract
(new): the plan components, the `.jetlib` format, the authoring toolkit and
the conformance test. pana after `jet_cad_2d` and `jet_cad_2d_flutter`
0.7.3. Dry run, publish, tag.

**4–6. `jet_cad_2d_plan` 0.8.0, `jet_cad_2d_kit_architecture` 0.1.0,
`jet_cad_2d_kit_restaurant` 0.1.0** — tags `jet_cad_2d_plan-v0.8.0`,
`jet_cad_2d_kit_architecture-v0.1.0`, `jet_cad_2d_kit_restaurant-v0.1.0`.
A10 allows any order among the three. Each waits for the kit contract (3) for
its pana step: `jet_cad_2d_plan` is the plan library (its widgets, its two
modes and its host API); `jet_cad_2d_kit_architecture` is the six architecture
types and the furniture library; `jet_cad_2d_kit_restaurant` is the 69-symbol
restaurant catalog as service units. Dry run, publish, tag each.

## After the wave — discontinue the old planner

A10: *"After the wave the human marks `jet_cad_floor_plan` discontinued on
pub.dev, replaced by `jet_cad_2d_plan`."* No bridge release (decision 9: a
file without a manifest is refused, so no plan from `jet_cad_floor_plan` is
read by the new line).

On <https://pub.dev/packages/jet_cad_floor_plan>, as its uploader:

1. Open the package's **Admin** tab.
2. Choose to **discontinue** the package; pub.dev lets you name the
   **replacement package** — give `jet_cad_2d_plan`.
3. The package's page then shows the discontinued banner and points at the
   replacement. The published versions stay downloadable; only the page
   changes.

`jet_cad_2d_plan` 0.8.0 carries `jet_cad_floor_plan` 0.7.x's product line
(A10) and the host guide's
[§12 "From `jet_cad_floor_plan`"](../../host-guide.md#12-from-jet_cad_floor_plan)
maps the old names to the new. A host that still uses the old planner keeps
working; a new host adds `jet_cad_2d_plan` and the kits it loads (host guide
§1).

## The dry-runs, run here

`flutter pub publish --dry-run`, one run per package, on the prep commit
`d9dd74d7` (the tree with the headings and the README turned). **Every run:
`Package has 0 warnings.`, exit 0.** The archive sizes are pub's own line:

```
jet_cad_2d                    Total compressed archive size: 239 KB.
                              Package has 0 warnings.
                              exit=0
jet_cad_2d_flutter            Total compressed archive size: 799 KB.
                              Package has 0 warnings.
                              exit=0
jet_cad_2d_kit                Total compressed archive size: 121 KB.
                              Package has 0 warnings.
                              exit=0
jet_cad_2d_plan               Total compressed archive size: 530 KB.
                              Package has 0 warnings.
                              exit=0
jet_cad_2d_kit_architecture   Total compressed archive size: 212 KB.
                              Package has 0 warnings.
                              exit=0
jet_cad_2d_kit_restaurant     Total compressed archive size: 225 KB.
                              Package has 0 warnings.
                              exit=0
```

The last lines of the engine's run, verbatim, as the shape of all six:

```
$ cd packages/jet_cad_2d && flutter pub publish --dry-run
└── pubspec.yaml (<1 KB)

Total compressed archive size: 239 KB.
Validating package...
The server may enforce additional checks.

Package has 0 warnings.
exit=0
```

Before `d9dd74d7` the three packages this commit touched warned once —
pub's "modified files in git" check — and the run exited **65**:

```
Package has 1 warning.
Failed to update packages.
exit=65
```

so the dry run is also why the prep is committed before the wave.

## The gates run here

The prep touches four files, all Markdown, in three packages. Their packages'
own gates, `tool/ci`, and the script checks, on the final tree:

```
### packages/jet_cad_2d_plan (flutter --enable-vmservice)
02:07 +1579: All tests passed!
No issues found! (ran in 5.6s)
Formatted 308 files (0 changed) in 0.82 seconds.
### packages/jet_cad_2d_kit_architecture (flutter)
00:20 +655: All tests passed!
No issues found! (ran in 4.0s)
Formatted 136 files (0 changed) in 0.42 seconds.
### packages/jet_cad_2d_kit_restaurant (flutter)
00:03 +184: All tests passed!
No issues found! (ran in 2.9s)
Formatted 22 files (0 changed) in 0.04 seconds.
### tool/ci
00:45 +114: All tests passed!
$ dart run tool/ci/check_guide.dart
docs/host-guide.md: all 29 code blocks are in the host probe        # exit 0
$ dart run tool/ci/check_readmes.dart
package READMEs: all 2 code blocks are in the probes                # exit 0
$ dart run tool/ci/check_screenshots.dart
screenshots: every rule holds                                       # exit 0
$ dart run tool/ci/check_kit_deps.dart
kit dependencies: 3 package(s) checked, none names the plan library or another kit  # exit 0
```

The engine's, renderer's, kit contract's, integration's and the apps' gates
were green at P4/P5 on the same code (no code changed since). The P4 record
also carries the lower-bound check the workspace can run before publication:
one `flutter pub downgrade`, the four new packages' tests against that lock,
one `flutter pub upgrade` — **no floor too low**
([2026-10-17-4b-floors-report.md](2026-10-17-4b-floors-report.md#step-3-the-lower-bound-check)).

## Open items before you publish

**Both closed in `e5383f9c`** (after the merge, on the human's word): the kit
contract gained a `.pubignore` (`/test/`, `/build/`; its archive went from
121 KB to 51 KB, dry run 0 warnings), and the root `CHANGELOG.md` lists the
six packages of the wave and names `jet_cad_floor_plan`'s last tag. The two
items as first written:

Not blockers, but the wave should decide them:

- **`jet_cad_2d_kit` has no `.pubignore`**, so its archive ships its
  `test/` (121 KB; the other five packages exclude theirs). The dry run is 0
  warnings, so pub accepts it, but pana's documentation score counts every
  undocumented test file. If a `.pubignore` is wanted, it is `/test/` and
  `/build/`, as `jet_cad_2d_plan`'s. Left here rather than added: the kit's
  archive has never excluded its tests in any record, and changing a
  published file set is the wave's call.
- **The root `CHANGELOG.md` is an index and is now half-false.** Its list of
  packages still names `jet_cad_floor_plan` (a dead link —
  `packages/jet_cad_floor_plan/` was removed by P2) and does not name the
  four new packages. It is not in A10; a small docs task in the wave, or the
  first commit after the merge, should list the six published packages and
  keep the shared history below.
- **`docs/host-guide.md` §12** ("From `jet_cad_floor_plan`") is left as
  history; it is true at the old tag and is the mapping a migrating host
  needs.

## What this note did not do

- **No publish, no merge, no push, no tag.** Every publish command above is
  the human's; this session ran only `--dry-run`.
- **No pana run.** pana's lower-bound step needs each package's dependencies
  on pub.dev and is part of the wave itself (steps 1–6, action (a)); the
  workspace's own downgrade check passed at P4.
- **No version change.** The versions and carets are P4's, already in `main`
  at `a428dee7`; this branch changes only Markdown (the three `(unreleased)`
  CHANGELOG headings, the one README sentence, this note and `STATUS.md`).

## This branch's commits

All on `docs/4b-release-checklist`, off `main` at `a428dee7`:

- `d9dd74d7` — `release: the four new packages' headings and the plan README
  (4b)`: drops `(unreleased)` from the three headings that carry it and the
  plan README's stale sentence. This is the prep that makes the dry runs
  above clean (an uncommitted change makes `pub publish --dry-run` warn and
  exit 65).
- `892f65c7` — `docs: the 4b release checklist (P6)`: this note.
- `da21f390` — `docs: STATUS 4b state and the resume point (P6)`: `STATUS.md`,
  the 4b state and the human's next step.

After `da21f390` the tree is clean. `tool/ci` (`+114`) and the four script
checks (`check_guide`, `check_readmes`, `check_screenshots`,
`check_kit_deps`) were re-run green on that tree: none reads `STATUS.md`, so
the transcript in [The gates run here](#the-gates-run-here) still holds. The
three code packages' gates are P4/P5's, unchanged by this Markdown branch.

**Open items:** the two in [Open items before you publish](#open-items-before-you-publish)
— `jet_cad_2d_kit`'s missing `.pubignore` and the half-false root
`CHANGELOG.md` index. Neither blocks the publish; both are the wave's call.
