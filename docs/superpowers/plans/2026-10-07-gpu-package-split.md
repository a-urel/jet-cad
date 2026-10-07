# Plan — the GPU renderer in its own package

**Spec:** [2026-10-07-gpu-package-split-design.md](../specs/2026-10-07-gpu-package-split-design.md),
revision 2, reviewed independently with the fixes folded in.

**Started** on the human's *"Önce jet-cad ön koşulu"* (2026-10-07). It is
Monépro's first jet-cad prerequisite, from its spec 103 §10.

**Branch:** `claude/exciting-pasteur-9m22jv`, from `main` at `23a8950`.

**Ledger:** `.superpowers/sdd/2026-10-07-gpu-split/`.

## Global constraints

- `CLAUDE.md`'s non-negotiables. The allocation invariants and the
  goldens stay untouched, and the standing sets stay exactly as they are.
- **Behaviour is unchanged (S5).** Every existing test stays green. A test
  may change only to follow a moved name or the registry, and each such
  change is recorded.
- **No host code changes.** B1 stays unchanged.
- **Never commit an `analysis_options.yaml` rewrite.** The new package's
  is committed once, at scaffold, as its siblings' were (plan 01's Ruling
  01-1); a rewrite by `pub get` is never committed. Check `git status`
  before each commit. (Corrected after Task 1's review: this line first
  said "left uncommitted, as its siblings' are", which was wrong; all nine
  siblings' are tracked.)
- **Never `git checkout` a file to revert it.** Use
  `git show HEAD:path > path`.
- Each named mutant is applied, seen red and reverted; record the result.

## Tasks

### Task 1 — the split (S1–S7)

**Create `packages/jet_cad_2d_gpu`:**
- `pubspec.yaml`, with `flutter >=3.47.0`;
- the barrel;
- `lib/src/` with the facade, `ResidentGeometry`, `GpuDrawBackend`,
  `uploadResidentCollection` and `installResidentGpu()`;
- `assets/shaders/cad.shaderbundle`, moved with `git mv`;
- `tool/build_shaders.sh`, compiling `../jet_cad_2d_flutter/shaders/`.

Add it to the root workspace.

**In core:**
- `frame_info.dart`, `resident_layout.dart` and `resident_gpu.dart`
  (the registry);
- `resolveBackend` and `DraftCanvas` work through the registry, with the
  two fallback wordings;
- the barrel's exports;
- `flutter_scene`, its pubspec comment and the asset declaration go;
- the S7 guard test.

**Tests:**
- core's tests follow S6 and F-12;
- the GPU package's tests are the moved facade and geometry tests, plus
  M-G4.

**The harness:**
- depends on `jet_cad_2d_gpu`;
- calls `installResidentGpu()` first in `main()` and in its integration
  test;
- uses `ResidentLayout`.

**Mutants:** M-G1, M-G3, M-G4.

**Gates:**
- render (the standing comparison);
- `jet_cad_2d_gpu`;
- planner, symbols, floor planner and demo;
- `flutter analyze` of `apps/dev_harness_2d`;
- engine untouched, but run.

### Task 2 — the guards (S8)

- `tool/ci/check_host_lock.dart` and its library, with fixtures
  `*.lock.txt` and tests (M-G2).
- `host_probe.sh`: clean first, check the lock, then the three post-build
  assertions.
- `ci.yml`:
  - the matrix gains `packages/jet_cad_2d_gpu`;
  - the `ci-tools` analysis and format lists name `check_host_lock.dart`;
  - the web job's assertions.
- **Local acceptance:**
  - Commit the split.
  - Run `host_probe.sh "file://$PWD" <sha>` locally: green.
  - Record:
    - the lock's packages;
    - the absence of `hooks_runner`;
    - the `build/web` size against the pre-split measurement (54 MB to
      42 MB in the review's trial).

**Gates:** `tool/ci` tests, analyze and format.

### Task 3 — docs and the exit (S9)

- **CHANGELOG, Unreleased:**
  - the split;
  - the host floor, 3.47 → 3.44;
  - the breaking names;
  - `jet_cad_2d_gpu` is not a host package.
- **The host guide:**
  - the floor, measured by `flutter pub downgrade` in the probe;
  - a line that the planner brings no build hook.
- The roadmap.
- `CLAUDE.md` and `AGENTS.md`: the gate line.
- **The results note** `docs/superpowers/notes/2026-10-07-gpu-split-results.md`:
  - the mutants;
  - the gates;
  - the probe's acceptance;
  - owed: a GPU run of the harness on a device.
- STATUS.
- Every gate, and both web builds without `flutter_scene` assets.

Then an independent code review of the range, its fixes, and the merge on
the human's word.

## Exit gate

- Task 3 green, every named mutant red, the probe's acceptance green
  locally and in CI.
- The independent review applied.
- Owed to the human: the harness's GPU arm on a device (macOS), as every
  GPU run was.
