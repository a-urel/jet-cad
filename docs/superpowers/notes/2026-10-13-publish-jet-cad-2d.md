# Publishing `jet_cad_2d` on pub.dev — results

**Date:** 2026-10-13. **Branch:** `feat/publish-jet-cad-2d`, cut by hand from
`main` at `133cf03` (tag `v0.7.0` → `0fa649e`). Run natively in one session:
a bounded design in chat, no spec, no plan, no SDD ledger; this note is the
record.

## The request and the rulings

The human asked to prepare `packages/jet_cad_2d` alone for pub.dev; every
other package stays `publish_to: none` and keeps its `path:` dependency on
the engine. The publish itself is the human's: nothing here ran `dart pub
publish` without `--dry-run`.

The human's answers to the design's three questions (2026-10-13), then
*"evet"* to the whole design:

1. **Versioning:** *"Bağımsız, 0.7.1"*. The engine leaves the shared
   release line. The host packages keep one version and one `vX.Y.Z`
   tag; `jet_cad_2d` has its own semver and its own `jet_cad_2d-vX.Y.Z`
   tags, and moves only when its own code changes. The first pub.dev
   version is 0.7.1: 0.7.0's code, packaged. (Not 0.7.0: the tree at
   `v0.7.0` fails the dry run and the published files differ from it. Not
   0.8.0: under 0.x a minor bump announces a break that does not exist.)
2. **The barrel:** *"Olduğu gibi + not"*. It is published as it stands;
   the candidates for narrowing are listed below for a later 0.x minor.
3. **The SDK floor:** *"^3.6.0, analyzer'a güven"*. `sdk: ^3.6.0`, with no
   run on a 3.6 SDK.

Also in the approved design: the package CHANGELOG starts at 0.7.1 and
links the root's for the history, and CI gets a dry-run job.

## What was verified before the design

- `main` = `origin/main` = `133cf03`; `v0.7.0^{}` = `0fa649e`.
- `dart pub publish --dry-run` at `133cf03`: one error (*"You must have a
  LICENSE file in the root directory"*: pub reads only the package
  directory, so the repository's LICENSE is not seen) and one warning
  (CHANGELOG lacks 0.7.0). Archive 556 KB, `test/`, `benchmark/` and
  `build/` inside.
- `repository: https://github.com/ahmeturel/jet-cad` answers 404;
  `https://github.com/a-urel/jet-cad` answers 200 (it is `origin`).
- `https://pub.dev/api/packages/jet_cad_2d` answers 404: the name is free.
- **The SDK floor.** dart.dev's workspaces page: *"all your workspace
  packages (but not your dependencies) must have an SDK version constraint
  of `^3.6.0` or higher."* Pub itself accepted `^3.5.0` (the dry run and
  `pub get` raise nothing), so the document and the tool disagree; the
  document was followed. The dependencies' own floors allow it:
  `meta` 1.18.0 needs `^3.5.0`, `vector_math` 2.2.0 needs `^3.1.0`.
  The analyzer's `sdk_version_since` diagnostic reports an SDK API newer
  than the floor; nothing was run on a 3.6 SDK.
- **`resolution: workspace` and publishing.** The workspaces page says
  nothing about publishing a member beyond `dart pub -C <member> publish`;
  the dry run accepts the field, and a hosted consumer ignores it.
- **No `package:jet_cad_2d/src/` import** outside the package (0 hits in
  `packages/`, `apps/`, `tool/`).

## pana (0.23.19), on the archive's file set

The baseline is a copy of the files `--dry-run` would upload at `133cf03`
plus the root LICENSE (without it pana stops where pub does). The result is
`git archive HEAD packages/jet_cad_2d` at `8f8ed32` with `test/` and
`benchmark/` removed, as `.pubignore` removes them.

| Section | Before | After |
|---|---|---|
| Dart file conventions | 25 / 30 | 20 / 30 |
| — valid pubspec | 10 (repository unreachable, not docked) | **0**: see below |
| — README | 5 | 5 |
| — CHANGELOG | 0 (no 0.7.0) | 5 |
| — OSI license | 10 (Apache-2.0) | 10 |
| Documentation | 10 / 20 | 20 / 20 |
| — dartdoc ≥ 20 % | 10 (645 / 1309, 49.3 %) | 10 (645 / 1309, 49.3 %) |
| — example | 0 | 10 |
| Platform support | 20 / 20 (6 of 6, WASM-ready) | 20 / 20 |
| Static analysis | 50 / 50 | 50 / 50 |
| Up-to-date dependencies | 40 / 40 | 40 / 40 |
| **Total** | **145 / 160** | **150 / 160** |

The 10 points the pubspec now loses are the branch not being on GitHub:
pana clones `repository`, finds `packages/jet_cad_2d/pubspec.yaml` there,
and reads `main`'s copy, whose `repository` is still the old URL
(*"expected `https://github.com/a-urel/jet-cad` but got
`https://github.com/ahmeturel/jet-cad`"*). Once this branch is on `main` on
GitHub that copy matches. **Owed:** pana re-run after the push and before
the publish; 160 / 160 is expected, not measured.

`dart doc --dry-run`: 11 unresolved references before, 0 after (`6f683f2`).

## The dry run

At `8f8ed32`, `dart pub -C packages/jet_cad_2d publish --dry-run`: *"Package
has 0 warnings."*, exit 0, archive 228 KB (LICENSE, README, CHANGELOG,
`analysis_options.yaml`, `example/`, `lib/`, `pubspec.yaml`).

With one warning (a byte appended to the README, uncommitted): *"Package
has 1 warning."*, **exit 65**. So the CI job runs the dry run bare: a
warning turns it red, no grep needed. The README was restored from a copy.

## The example and its mutants

`example/jet_cad_2d_example.dart` draws a line and a circle, picks, undoes,
redoes, saves and reloads; `test/example_test.dart` runs its `main` in a
zone and compares every printed line.

The first draft picked at (300, 299), inside the circle of radius 50 about
(300, 250). A probe showed a closed circle is picked from inside as
`HitKind.fill` at any radius (0.1 included), so that pick tested nothing
about the radius: the degenerate fixture. The pick moved to (300, 301),
1 unit outside the top of the circle, and prints the hit kind (`edge`).

| Mutant | Change | Result |
|---|---|---|
| M-EX1 | the `undo()` dropped | red |
| M-EX2 | pick radius 2 → 0.5 | red (it survived at (300, 299); see above) |
| M-EX3 | round trip compares against `saved.substring(1)` | red |

Each was fired from a copy of the file and restored from it (`cmp` checked).

The review (below) found two mutants the test survived: M-R1, the codec
writing no entity (`json_codec.dart`, `liveSlots.take(0)`), since an empty
document also round-trips identically; and M-R2, `redo()` not calling
`onAfterMutate` (`undo.dart`), since redo was checked through `liveCount`
only. The example now picks again after the redo, prints the decoded copy's
entity count, and picks on the copy through its own index (which must find
a circle). Both mutants now turn the test red, fired and restored the same
way.

## The barrel, audited

`lib/jet_cad_2d.dart` exports 56 files whole (no `show`, no `hide`).
`lib/testing.dart` is a second public library: `generateDocument`, used by
`jet_cad_2d_flutter`'s and `jet_cad_2d_gpu`'s tests and by
`apps/dev_harness_2d/lib`. It stays; its library comment and the README say
it is not API.

A rough grep (each top-level public name, as a whole word, in the `lib/` of
every other package and app) finds these exported names used by no other
package's code. They are candidates, not findings: some are API by intent
(error types, validation, geometry functions), others are infrastructure.

- Infrastructure: `PackedRTree`, `DirtyList`, `SlotAllocator`,
  `SlotStateError`, `FillIndex`, `RawDataStore`, `HandleSeed`, `scalarOr`,
  `ConvenienceQueries`.
- Likely API: `UndoStack`, `CommandDispatcher`, `DocumentValidation`,
  `ValidationCodes`, `SchemaVersionError`, `HandleRangeError`,
  `OriginComponent`, `SourceKind`, `distanceToArc`, `distanceToCircle`,
  `distanceToPolyline`, `distanceToSegment`, `insideClosedPolyline`,
  `nearestVertexDistance`, `projectOntoSegment`, `segmentIntersection`,
  `clipSegment`, `circleClipWindows`.

Several appear in public signatures (`DraftDocument.fills` is a
`FillIndex`, `DraftDocument.rawData` a `RawDataStore`, `.handleSeed` a
`HandleSeed`, `.commands` a `CommandDispatcher`), so hiding one is an API
change, not a cleanup: a 0.x minor of its own, with a spec.

## Gates

- `packages/jet_cad_2d`: `dart test` +1289 −2. The two failures are the
  standing `generate_document_test.dart` fingerprints;
  `tool/ci/expect_failures.dart` reports *"1291 tests; the standing
  failures and skips, exactly"*. `dart analyze --fatal-infos`: no issues.
  Format: 0 changed.
- `tool/ci/check_guide.dart`: *"all 54 code blocks are in the host probe"*.
  `tool/ci`: `dart test` +64.
- The other gates, on macOS with Flutter 3.47.6 (`test`, `analyze`, format,
  each package):
  - `jet_cad_2d_flutter`: +1446 ~1 −5. The five are the text ladder
    goldens, rungs 1–5. `expect_failures.dart` exits 1 because the text
    lod ladder's rungs 1 and 2, standing failures on Linux, pass on macOS
    (STATUS: recorded, not ruled). The same five fail at `main`
    (`133cf03`) on this machine, run in a detached worktree. Analyze and
    format: clean.
  - `jet_cad_floor_plan` (`--enable-vmservice`): +2010; *"the standing
    failures and skips, exactly"*. Analyze and format: clean.
  - `jet_cad_2d_gpu` +20, `jet_cad_restaurant_symbols` +97,
    `apps/floor_planner` +212, `apps/restaurant_demo` +69: all passed;
    analyze and format clean.
- CI (Linux) runs on a push, which waits for the human's word.

## Independent review

One Opus reviewer subagent on the branch diff at `943a9ad` (read-only; it
re-ran the dry run, `dart doc`, the gates of the engine and pana itself):
**Approve with fixes**, R-1 to R-10.

- R-1, applied: "the frame-path queries allocate nothing" overstated the
  invariant; a pick allocates a few objects per level of instance nesting
  (`query_allocation_test.dart` budgets `Aabb2` 4.004 and `Transform2`
  7.007 per `pickInto` on its four-level fixture). README and the
  example's comment now say "nothing per entity".
- R-2, applied: "preserves fields written by a newer version" was wrong; a
  newer schema version is refused (`SchemaVersionError`). README now says
  what is kept: unknown fields and components within a readable version.
- R-3, applied: the two surviving mutants, above.
- R-4, **left for the human**: the dormant `packages/jet_cad/pubspec.yaml`
  has no `publish_to: none` (the name `jet_cad` is free on pub.dev). The
  STATUS ruling now says "every other package of the live line".
- R-5, R-6, applied: the root CHANGELOG header no longer puts the engine
  under the shared version; STATUS no longer calls `jet_cad_2d_gpu` a
  host package.
- R-7, no change: the present tense ("is on pub.dev") holds once the
  publish follows the merge, as Resume orders it.
- R-8, applied: `.pubignore` anchors its patterns at the package root.
- R-9, applied: every added line wraps at 80 columns.
- R-10, applied: README says the snippet needs `vector_math` too.
- Not taken: a `tree/main/packages/jet_cad_2d` repository URL (pana
  already finds the package in the repository) and automated publishing
  from tags (the publish is the human's).

## Owed

- **The human:** the word to push and merge; then, from
  `packages/jet_cad_2d` on `main`, the pana re-run, `dart pub publish`,
  and the tag `jet_cad_2d-v0.7.1` on the merge commit.
- **The human's ruling (R-4):** whether the dormant `packages/jet_cad`
  gets `publish_to: none`.
- **After the publish:** the host guide's new sentence (a host must not
  also take `jet_cad_2d` from pub.dev: pub takes a package from one source
  only) states pub's rule; it was not run, since there was no hosted
  version to resolve against.
