# Task 7 report: Codec — schema 5, and the load-time rebuild

## What changed

- `packages/jet_cad_2d/lib/src/codec/schema_version.dart`: `kSchemaVersion`
  bumped 4 -> 5, with a doc comment explaining why (fill is an ordinary
  entity; the version floor is what makes a v4 build refuse it instead of
  failing inside `EntityKind.values.byName`).
- `packages/jet_cad_2d/lib/src/codec/json_codec.dart`:
  - Added `import '../document/commands.dart';` (for `triangulationFor`).
  - `DraftDocumentCodec.decode` now calls `_rebuildFills(doc, diagnostics)`
    after the handle seed is raised and before `doc.invalidateDerived()`.
  - Added the top-level `_rebuildFills` function exactly as specified in the
    brief: clears `doc.fills`, walks live fill slots, links each fill to its
    boundary via `boundaryHandleOf`, and — when the boundary exists and isn't
    already triangulated — stores triangles from `triangulationFor` only when
    the result is non-empty. A fill with a missing/unfillable boundary stays
    linked with no triangles.
- `packages/jet_cad_2d/test/codec/json_codec_test.dart`: added the brief's
  three tests, translated from the nonexistent `JsonCodec.save/load` onto the
  real `DraftDocumentCodec.encode`/`decode` API:
  - `a document with a region round-trips byte-identically`
  - `load leaves the fill index populated, not empty`
  - `the schema version is 5, and a v6 document is refused`
- `packages/jet_cad_2d/test/testing/generate_document_test.dart`: the schema
  bump moves the very first bytes of every serialisation, so the two golden
  FNV-1a fingerprints pinned in `the default document is the one Plan 2
  measured, byte for byte` and `both text fractions default to zero and
  change nothing` no longer matched. Re-baselined both (they must move in
  lockstep — same generator calls, same constants) from
  `-4223683079839955300` / `-1538364231202837705` to
  `4778422453512744465` / `2508170127112452780`, computed by running
  `generateDocument` + the file's own `fingerprint()` against the new
  `kSchemaVersion = 5` build. Added comments at both sites recording this was
  the schema bump, not a generator regression.

Not in the brief's list of files but required for "ends green on both
packages" — the fingerprint drift is a direct, mechanical consequence of
`kSchemaVersion` changing and nothing else.

## Suite output — jet_cad_2d

```
$ CI=true dart test
...
00:02 +752: test/invariants/query_allocation_test.dart: pickInto stays local: an over-wide broad phase would blow the time budget
00:02 +753: test/invariants/query_allocation_test.dart: (tearDownAll)
00:02 +753: All tests passed!

$ CI=true dart analyze
Analyzing jet_cad_2d...
No issues found!

$ dart format --output=none --set-exit-if-changed .
Formatted 110 files (0 changed) in 0.13 seconds.
```

## Suite output — jet_cad_2d_flutter

```
$ flutter test
...
00:02 +241 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: curves cannot be bypassed the threshold is exclusive, so a circle exactly at 2.0 is not counted
00:02 +242 ~1: All tests passed!

$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.0s)

$ dart format --output=none --set-exit-if-changed .
Formatted 45 files (0 changed) in 0.06 seconds.
```

(The `~1` is one pre-existing skip, unrelated to this task; not investigated
further since it predates these changes and the brief scopes this task to
`jet_cad_2d`'s codec.)

## schema_v3_fixture_test.dart

```
$ CI=true dart test test/codec/schema_v3_fixture_test.dart
00:00 +0: loading test/codec/schema_v3_fixture_test.dart
00:00 +0: a version-3 document loads under the version-4 build
00:00 +1: a version-3 document survives a round-trip unpadded
00:00 +2: All tests passed!
```

Confirmed passing, unmodified, across the bump.

## Mutation T7a — drop the `_rebuildFills` call

```
$ cp lib/src/codec/json_codec.dart /tmp/json_codec.dart.bak && \
  trap 'cp /tmp/json_codec.dart.bak lib/src/codec/json_codec.dart' EXIT && \
  perl -0pi -e 's/    _rebuildFills\(doc, diagnostics\);\n\n//' lib/src/codec/json_codec.dart && \
  grep -n "_rebuildFills" lib/src/codec/json_codec.dart && \
  CI=true dart test test/codec/json_codec_test.dart

277:void _rebuildFills(DraftDocument doc, List<Diagnostic>? diagnostics) {
...
00:00 +20 -1: load leaves the fill index populated, not empty [E]
  Expected: [18]
    Actual: []
     Which: at location [0] is [] which shorter than expected

  package:matcher                        expect
  test/codec/json_codec_test.dart 480:5  main.<fn>

00:00 +20 -1: the schema version is 5, and a v6 document is refused
00:00 +21 -1: Some tests failed.

Failing tests:
  test/codec/json_codec_test.dart: load leaves the fill index populated, not empty
```

**KILL** — `load leaves the fill index populated, not empty` fails on
`reloaded.fills.fillsOf(cmd.boundary.handle)`. File restored by the trap;
verified `_rebuildFills(doc, diagnostics);` present at line 137 afterward.

## Mutation T7b — leave `kSchemaVersion` at 4

```
$ cp lib/src/codec/schema_version.dart /tmp/schema_version.dart.bak && \
  trap 'cp /tmp/schema_version.dart.bak lib/src/codec/schema_version.dart' EXIT && \
  perl -0pi -e 's/const int kSchemaVersion = 5;/const int kSchemaVersion = 4;/' lib/src/codec/schema_version.dart && \
  grep -n "kSchemaVersion =" lib/src/codec/schema_version.dart && \
  CI=true dart test test/codec/json_codec_test.dart

15:const int kSchemaVersion = 4;
...
00:00 +21 -1: the schema version is 5, and a v6 document is refused [E]
  Expected: <5>
    Actual: <4>

  package:matcher                        expect
  test/codec/json_codec_test.dart 485:5  main.<fn>

00:00 +21 -1: Some tests failed.

Failing tests:
  test/codec/json_codec_test.dart: the schema version is 5, and a v6 document is refused
```

**KILL** — `the schema version is 5, and a v6 document is refused` fails on
`expect(kSchemaVersion, 5)`. File restored by the trap; verified
`const int kSchemaVersion = 5;` present afterward. `git status --porcelain`
showed only the four intended files modified after both mutation runs.

## API note

The brief's Step 1 snippet calls `JsonCodec.save(doc)` / `JsonCodec.load(json)`.
Neither exists — the real class is `DraftDocumentCodec` with
`encode`/`decode`/`encodeToString`/`decodeString`, confirmed by reading
`json_codec.dart` and the pre-existing `schema_v3_fixture_test.dart`, which
already uses `DraftDocumentCodec`. All three new tests were translated to
that API 1:1 (same fixture, same assertions), per the controller's ruling.

## Uncertainties / judgment calls

- The generator fingerprint re-baseline wasn't named in the brief's file
  list. It's a mechanical, unavoidable consequence of the schema bump (byte
  0 of every encoded document changes), and leaving it red would violate
  "ends green on both packages," so I fixed it and documented why at both
  call sites rather than silently editing the constants.
- `jet_cad_2d_flutter`'s one skip (`~1`, `draft_painter_recursion_test.dart`
  or similar) is pre-existing and untouched by this task; I did not
  investigate it since nothing in this diff touches that package.
