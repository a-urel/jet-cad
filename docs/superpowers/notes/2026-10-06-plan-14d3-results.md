# Plan 14d-3 results — a release a POS can pin

**Branch:** `claude/exciting-pasteur-9m22jv`, after 14d-2 and 14d-1
(`ad483c8`). **Spec:** [2026-10-06-pos-readiness-design.md](../specs/2026-10-06-pos-readiness-design.md),
revision 2 (P1–P7 as amended). **Plan:**
[2026-10-06-release.md](../plans/2026-10-06-release.md). **Approval:**
the human's *"evet, 14d-3'e başla"* (2026-10-06). **Not merged; not
tagged** — the tag `v0.1.0` (P3) is made on `main` after 14d merges, on
the human's word.

The four packages are at `0.1.0`, a root `CHANGELOG.md` says what 0.1.0
carries and what it does not. `docs/host-guide.md` walks a POS through
embedding the planner; every code block in it is code from
`tool/ci/host_probe`, a small host outside the workspace that depends on
the packages by git, and `check_guide.dart` fails when the two part. A
GitHub Actions workflow runs every gate on every push to `main` and
`claude/**` and on pull requests to `main`, compares the known failures
and skips exactly instead of skipping them, and builds the probe by git
from the commit under test.

## Commits

| Task | Commit |
|---|---|
| Plan | `8452600` |
| 1 Versions and the changelog (P1) | `4c9c8b1` |
| 2 The standing comparison (P5, M-14d-q) | `ad8fcf5` |
| 3 The host guide and its probe (P2, P6) | `97a1cac` |
| 4 The workflow (P4, P6, P7) | `0eb035c` |
| Exit (this note, STATUS, roadmap) | this commit |

**Process, stated plainly:** implemented by the controller, without a
fresh implementer or a per-task reviewer, as 14d-2 and 14d-1; every
mutant below was fired by the controller. No independent review.

## CI

**Run 1** of the workflow, on `0eb035c` (Task 4's commit):
[37504211890](https://github.com/a-urel/jet-cad/actions/runs/37504211890),
**success**, all nine jobs, about seven minutes. GitHub accepted the
workflow file from this session's push. Read from the job logs:

- `packages/jet_cad_2d_flutter`: the runner's own summary *1240 tests
  passed, 7 failed, 1 skipped* (shown as an error annotation, its exit
  code ignored), then the comparison: *1248 tests; the standing failures
  and skips, exactly*. GitHub's Ubuntu runner fails and skips exactly
  what this container does.
- `an external host, by git`: the probe resolved from
  `file://$GITHUB_WORKSPACE` at the run's commit, analysed and built
  (*✓ Built build/web*).
- The engine's allocation invariants ran there: a skip for want of the
  VM service would have failed the job.

The exit commit's push starts run 2.

## Gates (Linux container, Flutter 3.47.6 / Dart 3.13.5)

| Package | Result |
|---|---|
| engine `packages/jet_cad_2d` | **1,242 passed** + 2 standing; analyze, format clean; untouched |
| render `packages/jet_cad_2d_flutter` | **1,240 passed** + 1 skip + 7 standing; analyze, format clean; untouched |
| planner `packages/jet_cad_floor_plan` | **1,212 passed**; analyze, format clean; the version line only |
| restaurant symbols | **97 passed**; analyze, format clean; the version line only |
| app `apps/floor_planner` | **203 passed**; analyze, format clean; untouched |
| demo `apps/restaurant_demo` | **21 passed**; analyze, format clean; untouched |
| `tool/ci` (new) | **19 passed** (ST1–ST14, GD1–GD5); `dart analyze --fatal-infos`, format clean; `check_guide`: *all 13 code blocks are in the host probe* |
| host probe | from a shallow `file://` clone at `ad8fcf5`: resolved, *No issues found!*, *✓ Built build/web* |
| web builds | both apps, by CI's `web` job in run 1 |

The recorded runs of the engine and the render package
(`--file-reporter json`) pass `expect_failures.dart` locally: *1244
tests* and *1248 tests; the standing failures and skips, exactly*.

## Mutants fired

All red.

- **Task 2** (`tool/ci/test/standing_test.dart`, ST1–ST14, on runs
  recorded from `dart test` and `flutter test` and on a real VM-service
  skip, a throwaway test calling `markTestSkipped(vmServiceUnavailableReason)`):
  **M-14d-q** a subset comparison (standing failures that pass ignored:
  ST3, ST4); skips ignored (ST5, ST10, ST11); the VM-service rule removed
  (ST11, ST12); `done` not required (ST6); a run with no test accepted
  (ST7).
- **Task 3** (`tool/ci/test/guide_test.dart`, GD1–GD5): white space not
  collapsed (GD5); the URL and the ref not set aside (GD1, GD2); YAML
  blocks unchecked (GD3, GD4); Dart blocks unchecked (GD2, GD5).

## Amended at execution

- **`tool/ci` is a workspace member** (`jet_cad_ci`, dev dependency
  `test` only): the root `pubspec.lock` did not change. It has no
  `analysis_options.yaml` (CLAUDE.md: none is committed); CI analyses it
  with `--fatal-infos`.
- **Every gated package goes through the standing comparison**, not only
  the engine and the render package (P5 named those two): the others'
  lists are empty, so a skip or a failure anywhere is red.
- **A run that did not end, or had no test, is red**, beside P5's cases.
- **The probe's pubspec is a template** (`pubspec.yaml.in`), written by
  `host_probe.sh` and git-ignored, so the repository holds no pubspec
  that cannot resolve. Its `web/` is `flutter create`'s.
- **The host guide's code is checked against the probe** (P2 asked for
  the guide only): `check_guide.dart`, a CI step.
- **The dormant line is out of CI** (P4, V-19): `packages/jet_cad`
  (OCCT 3D over FFI) analyses clean and its tests pass with 6 skips;
  `apps/dev_harness` analyses clean. STATUS records both as dormant, and
  no gate of CLAUDE.md names them; the root `pub get` still resolves
  them.

## Found, not fixed

- **The engine's `pubspec.yaml` names `repository:
  https://github.com/ahmeturel/jet-cad`**; the repository is
  `a-urel/jet-cad`. Not changed (no package is published); the guide
  uses the real URL.
- **The probe's web build warns** that it expected the
  `CupertinoIcons` font (a transitive reference; the build succeeds).
- **`actions/checkout@v4` runs on Node.js 20**, which GitHub now forces
  onto Node.js 24 with a deprecation warning; a later version of the
  action is a one-line change.
- **The flutter-action caches race**: nine jobs try to save one cache
  key and all but one log *Unable to reserve cache*; harmless.

## For the human

- **The tag** `v0.1.0`, on `main`, after 14d merges, on your word; the
  guide then names its commit SHA.
- **Read the guide** as a POS developer would.
