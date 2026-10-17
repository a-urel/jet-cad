# 4b — versions and dependency floors (P4) — report

**Date:** 2026-10-17.
**Worktree:** `.claude/worktrees/4b-floors`, branch `chore/4b-floors`, cut by
hand from local `main` at `6b9c018e`.
**Base:** `6b9c018e` (P2's merge `c9fa618e` is in; P3 has not run — it is the
optional CI check and changes only CI, not versions).
**Umbrella spec:** [2026-10-13-kit-architecture-design.md](../specs/2026-10-13-kit-architecture-design.md),
A10 (versions and the release wave).

## What this session does, and where it stops

P4 has four steps. Per the task, this session does **step 1 only** and stops
**before any version is changed**:

1. **PROPOSE** the new versions of `jet_cad_2d` and `jet_cad_2d_flutter`,
   with the evidence, and let the human pick. ← **this session**
2. After the human's pick (a follow-up prompt): set the versions, turn
   `Unreleased` into the version heading, raise every dependent's caret
   floor, and update `tool/ci` DL2's expected caret and count.
3. Lower-bound check: `flutter pub downgrade` → tests → `flutter pub upgrade`
   in `jet_cad_2d_plan` and each kit.
4. `flutter pub publish --dry-run` (dry-run only) for every package in the
   wave; 0 warnings each.

**Nothing was changed in any package.** The only commit of this session is
this report.

## What I read

- The umbrella spec, A10 (versions and the release wave) and A12 (the engine
  and the Flutter layer change only where a seam is missing).
- `packages/jet_cad_2d/CHANGELOG.md` and
  `packages/jet_cad_2d_flutter/CHANGELOG.md`, the `## Unreleased` section of
  each.
- The full public API diff
  `git diff jet_cad_2d-v0.7.2..main -- packages/jet_cad_2d/lib` (1399 lines,
  9 files) and
  `git diff jet_cad_2d_flutter-v0.7.2..main -- packages/jet_cad_2d_flutter/lib`
  (54 lines, 2 files).
- `docs/kits.md` §8 (the repo's semver-at-0.x rule) and §10.9 (an engine
  change is a contract and kit change).
- The publish-host-packages spec, D1 and the line "a version bump of a
  sibling past its dependents' caret (0.7.x → 0.8.0) breaks `pub get` until
  every dependent's constraint follows, in the same commit".

## The change since the 0.7.2 tags

### `jet_cad_2d`

`git diff --stat jet_cad_2d-v0.7.2..main -- packages/jet_cad_2d/lib`:

```
 packages/jet_cad_2d/lib/jet_cad_2d.dart            |   1 +
 packages/jet_cad_2d/lib/src/codec/json_codec.dart  |  24 +-
 .../lib/src/core/partial_mutation_error.dart       |  15 +
 .../jet_cad_2d/lib/src/document/commands.dart      |  16 +-
 .../jet_cad_2d/lib/src/document/component.dart     |  62 ++-
 .../jet_cad_2d/lib/src/index/drag_snap.dart        |  10 +-
 .../jet_cad_2d/lib/src/index/spatial_index.dart    |  47 ++-
 .../lib/src/parametric/parametric_system.dart      | 260 +++++++++++-
 .../lib/src/parametric/regeneration.dart           | 439 ++++++++++++++++++---
 9 files changed, 783 insertions(+), 91 deletions(-)
```

The `Unreleased` section (the seams the kit wave needed, plus 4a's drag-snap
exclude) adds:

- `SpatialIndex.snapInto(…, exclude: Set<Handle>?)` and
  `resolveDragPoint(…, exclude: Set<Handle>?)`, and the private machinery
  that makes a drag never snap to its own pre-drag geometry (4a O1).
- `ParametricCatalog.typeIds` and `ParametricCatalog.typeIdOf(target, group)`
  (2a E1).
- `PartialMutationError` (`extends StateError`, same message) as what a
  failed rollback throws (2a E3); a caller catching `StateError` is
  unaffected.
- `ComponentRegistry.loadJson(…, diagnostics:)` and
  `DraftDocumentCodec.decode` / `decodeBytes`'s
  `keepUnreadableComponents:` (2a E4).
- `ParametricSystem(…, isFrozen:)`, `ParametricSystem.probe(handle)` and
  `NonLiveWriteError` (`extends StateError`, same message) (2a E2).
- `ParametricType.instances` (a non-abstract hook with a default), plus
  `GeneratedInstance`, `GeneratedAttrib` and `GeneratedDefinitionError`
  (2b S1 / E5).
- The edit guard now covers generated instances and their ATTRIBs (2b S1).

**Additive, verified.** Comparing the top-level public type declarations of
the two revisions over all nine changed files, four public types are new
(`PartialMutationError`, `GeneratedAttrib`, `GeneratedInstance`,
`NonLiveWriteError`, `GeneratedDefinitionError` — five, three of them in one
file) and **none is removed or renamed**; the pre-existing public types move
only because content is inserted above them. Every other change is a new
optional named parameter on a method or constructor, a new method/getter, or
a new non-abstract hook with a default. Every existing 0.7.2 call site
compiles unchanged:

| Change | Kind |
|---|---|
| `PartialMutationError`, `GeneratedAttrib`, `GeneratedInstance`, `NonLiveWriteError`, `GeneratedDefinitionError` | new public types |
| `ParametricCatalog.typeIds`, `ParametricCatalog.typeIdOf`, `ParametricSystem.probe`, `ParametricType.instances` | new members |
| `SpatialIndex.snapInto(exclude:)`, `resolveDragPoint(exclude:)`, `ComponentRegistry.loadJson(diagnostics:)`, `DraftDocumentCodec.decode/decodeBytes(keepUnreadableComponents:)`, `ParametricSystem(isFrozen:)` | new **optional** parameters |
| `CompoundCommand.apply` / `ParametricEdit` now throw `PartialMutationError`; `_run` throws `NonLiveWriteError` | the new types are `StateError` subtypes with the old messages; a `StateError` catch is unaffected |

No public symbol is removed, no name is renamed, and no required parameter
changes. All nine changed files are exported by `lib/jet_cad_2d.dart`, so the
new declarations are public API.

### `jet_cad_2d_flutter`

`git diff --stat jet_cad_2d_flutter-v0.7.2..main -- packages/jet_cad_2d_flutter/lib`:

```
 packages/jet_cad_2d_flutter/lib/src/grip_drag.dart   | 4 ++++
 packages/jet_cad_2d_flutter/lib/src/select_tool.dart | 7 +++++++
 2 files changed, 11 insertions(+)
```

The `Unreleased` section: `SelectTool` passes the dragged selection as
`resolveDragPoint`'s new `exclude` while a move drag lives. The public
addition is one field, `GripDrag.handles` (a public `late final
Set<Handle>`); `SelectTool._exclude` is private. `GripDrag` is exported by
the barrel. **Additive:** nothing removed or renamed.

## Proposal (the human picks)

| Package | Current | Proposed | Change |
|---|---|---|---|
| `jet_cad_2d` | 0.7.2 | **0.7.3** (patch) | the seams of 2a/2b and 4a O1 |
| `jet_cad_2d_flutter` | 0.7.2 | **0.7.3** (patch) | the drag-snap `exclude` seam |

**I suggest a patch for both, not a minor.** Reasons:

1. **The change is purely additive and non-breaking** (above): no removal,
   no rename, no required parameter changed. Every 0.7.2 caller compiles.
2. **The repo's own 0.x rule reads that way.** `docs/kits.md` §8: "a new
   symbol, a new `@N`, words or tags is a patch; a removed or renamed Dart
   name, a type's parameters changed … is a minor (0.x+1.0)." The rule is
   written for kits, but it is this repo's stated 0.x doctrine: at 0.x, patch
   carries additive change and minor is reserved for a break. By that
   doctrine an additive engine seam is a patch.
3. **Precedent on the engine's independent line.** `jet_cad_2d` 0.7.1
   (packaging) and 0.7.2 (docs plus one small ruler change) are both patches;
   no feature has yet bumped its minor.
4. **A patch is honest about cost to a host.** `^0.7.2` already admits
   0.7.3, so an existing 0.7.2 host takes it on `pub upgrade` with no edit;
   the API is additive, so nothing it uses breaks.

**The case for a minor (`0.8.0`), stated fairly:** standard pub.dev semver
for `0.x` often reads "new functionality → minor", and this change is not a
one-liner — five new public types, new methods, a new hook and five new
optional parameters, all driven by the architecture rewrite. If the human
prefers the standard reading, the correct number is `0.8.0` for **both**
packages. Its consequence is mechanical and known (publish spec, F-1/D1): a
bump of `jet_cad_2d` past its dependents' caret breaks `pub get` until every
dependent's constraint follows in the same commit, so `jet_cad_2d_flutter`
must go to `0.8.0` too, and every dependent's `jet_cad_2d` and
`jet_cad_2d_flutter` caret moves to `^0.8.0`. Step 2 does that either way, so
the difference is the number and the auto-upgrade behaviour, not the amount
of editing.

I do **not** propose splitting the two: they are one seam (the engine
introduces `exclude`; the Flutter layer passes it), and A10 releases them in
the same wave. They should carry the same number.

## The other packages of the wave

Unchanged and confirmed: `jet_cad_2d_kit` 0.1.0, `jet_cad_2d_plan` 0.8.0,
`jet_cad_2d_kit_architecture` 0.1.0, `jet_cad_2d_kit_restaurant` 0.1.0
(A10: the kits and `jet_cad_2d_kit` start at 0.1.0; `jet_cad_2d_plan` starts
at 0.8.0 with `jet_cad_floor_plan` 0.7.x's product line).

## Dependent carets (what step 2 will touch)

Every caret line on the two published packages today, `^0.7.2` in all 22:

| Pubspec | `jet_cad_2d` | `jet_cad_2d_flutter` |
|---|---|---|
| `packages/jet_cad_2d_flutter` | yes | — |
| `packages/jet_cad_2d_gpu` | yes | yes |
| `packages/jet_cad_2d_integration` (unpublished) | yes | yes |
| `packages/jet_cad_2d_kit` | yes | yes |
| `packages/jet_cad_2d_kit_architecture` | yes | yes |
| `packages/jet_cad_2d_kit_restaurant` | yes | — |
| `packages/jet_cad_2d_plan` | yes | yes |
| `apps/architecture_demo` | yes | yes |
| `apps/dev_harness_2d` | yes | yes |
| `apps/restaurant_demo` | yes | yes |
| `tool/readme_probe` | yes | yes |
| `tool/screenshots` | yes | yes |

**`tool/ci` DL2** (`tool/ci/test/dependency_lines_test.dart`) currently
expects `'^0.7.2'` and `seen == 11`, over a `pubspecs` list of seven files —
`jet_cad_2d_flutter`, `jet_cad_2d_gpu`, `apps/restaurant_demo`,
`apps/dev_harness_2d`, `tool/screenshots`, `tool/readme_probe` (and the
engine, which carries none). Its premise text names "the renderer, the GPU
renderer, the two demos and the two probes". That list **does not include**
the four new packages, `apps/architecture_demo` or `packages/jet_cad_2d_integration`,
although all six carry hosted constraints on the two published packages
(11 more lines).

**Open question for step 2 (the human's call with the fix):** does DL2's
`pubspecs` list grow to cover the new packages (the count becomes 22), or
does it stay the same six holders and only its expected caret moves to the
new number (the count stays 11)? P2 re-derived DL2 as 20 → 11 over exactly
those six holders; the new packages were never added to its list. I would
grow the list — the check's purpose is that every live-line pubspec names a
published package by the current hosted caret, and the four kit/plan
packages and `apps/architecture_demo` are exactly that. But the task says
"update DL2's expected caret and count", so I will do whichever the human
picks, re-deriving the number from the files and moving the number and its
`reason:` text together, as P2's rule requires.

## What I did not do

- **No version was changed** in any pubspec; no `Unreleased` heading was
  turned into a version heading.
- No caret floor was raised.
- No lower-bound (`pub downgrade`) check and no publish dry-run was run —
  those are steps 3 and 4, after step 2.
- P3 (the CI matrix check) has not run; it is optional and touches no
  version.

## Commands (real last lines)

```
$ git diff --stat jet_cad_2d-v0.7.2..main -- packages/jet_cad_2d/lib
 9 files changed, 783 insertions(+), 91 deletions(-)

$ git diff --stat jet_cad_2d_flutter-v0.7.2..main -- packages/jet_cad_2d_flutter/lib
 2 files changed, 11 insertions(+)

$ for p in jet_cad_2d jet_cad_2d_flutter jet_cad_2d_kit jet_cad_2d_plan \
      jet_cad_2d_kit_architecture jet_cad_2d_kit_restaurant; do
      grep -E '^version:' packages/$p/pubspec.yaml; done
version: 0.7.2   (jet_cad_2d)
version: 0.7.2   (jet_cad_2d_flutter)
version: 0.1.0   (jet_cad_2d_kit)
version: 0.8.0   (jet_cad_2d_plan)
version: 0.1.0   (jet_cad_2d_kit_architecture)
version: 0.1.0   (jet_cad_2d_kit_restaurant)

$ grep -rn -E "^\s+jet_cad_2d(_flutter)?: \^" --include=pubspec.yaml . | wc -l
      22
```

**STOP.** Awaiting the human's pick of patch or minor for `jet_cad_2d` and
`jet_cad_2d_flutter`; step 2 follows on a fresh prompt.
