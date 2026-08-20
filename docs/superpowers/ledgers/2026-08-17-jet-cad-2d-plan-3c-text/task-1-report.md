# Task 1 report: Codec, schema 4, and the defensive scalar read

## What I implemented

1. **`lib/src/document/text_scalars.dart` (new)** — `scalarOr(GeometryPayload payload, int index, double fallback)`, reading a scalar defensively instead of assuming a schema-4-shaped payload. Exported from `lib/jet_cad_2d.dart`.
2. **`lib/src/store/entity_store.dart`** — `EntityRecord.toJson` now writes `text`, `tag`, `textStyle` (via `Handle.toJson()`), `textAttrs` immediately after `flags`, in that order. `EntityRecord.fromJson` defaults all four when absent (`'' `, `''`, `ReservedHandles.standardTextStyle`, `0`), with a comment explaining this is the whole v3→v4 migration.
3. **`lib/src/codec/schema_version.dart`** — `kSchemaVersion` bumped `3 -> 4`; doc comment gained a line naming what changed.
4. **`test/codec/schema_v3_fixture_test.dart` (new)** — a hand-built, genuinely-loadable schema-3 document (one text entity, one scalar) proving: the four new fields default correctly on load, `scalarOr` doesn't throw on a short `scalars` array, and the document round-trips without the payload being padded.
5. **`test/testing/generate_document_test.dart`** — re-baselined the two FNV-1a fingerprint constants and added a note dating the re-baseline to this task.
6. **`test/store/entity_store_test.dart`** — a pre-existing Task-0 test (`record json emits keys in a stable order`) hardcoded the old 10-key list; updated it to include the four new keys in order. Not in the brief's file list, but it fails deterministically as a direct consequence of the toJson change and is squarely inside "task ends green."

## Deviation from the brief worth flagging

The brief's illustrative fixture and its `decodeDocument`/`encodeDocument` calls don't match this codebase: there is no free `decodeDocument`/`encodeDocument` function (the API is `DraftDocumentCodec.decodeString`/`encodeToString`), and the real top-level document shape uses plain integer handles and `definitions`/`root`/`nodes` rather than a nested `tree` object with hex-string handles. Per decision #3 in the task instructions, I built a fixture from the actual shape (verified against `DraftDocumentCodec.encode(DraftDocument.empty())`'s real output) and mapped the brief's `decodeDocument`/`encodeDocument` calls onto `DraftDocumentCodec.decodeString`/`encodeToString`, which are the equivalent String-level entry points.

## TDD evidence

**RED** — `cd packages/jet_cad_2d && dart test test/codec/schema_v3_fixture_test.dart`, before `text_scalars.dart` existed:
```
test/codec/schema_v3_fixture_test.dart:69:12: Error: Method not found: 'scalarOr'.
      expect(scalarOr(payload, 1, 0.0), 0.0);
             ^^^^^^^^
test/codec/schema_v3_fixture_test.dart:70:12: Error: Method not found: 'scalarOr'.
      expect(scalarOr(payload, 0, 0.0), 100.0);
             ^^^^^^^^
```
Failed for the right reason: the helper didn't exist yet, not a fixture-shape problem (the fixture itself was already verified loadable before this run).

**GREEN** — same command, after implementation:
```
00:00 +0: loading test/codec/schema_v3_fixture_test.dart
00:00 +0: a version-3 document loads under the version-4 build
00:00 +1: a version-3 document survives a round-trip unpadded
00:00 +2: All tests passed!
```

## Fingerprint re-baseline (auditable)

| Corpus | Old value | New value |
|---|---|---|
| `generateDocument(2000, definitionCount: 20)` | `4478729767976143987` | `-4223683079839955300` |
| `generateDocument(20000, definitionCount: 20)` | `7265843217140545300` | `-1538364231202837705` |

Obtained by running `dart test test/testing/generate_document_test.dart` (first value came straight from the failure's `Actual:`), then a throwaway script computing the same FNV-1a fingerprint function for the second corpus size (script was not committed). The structural test in the same file (`defaults reproduce the Plan 2 corpus structurally too` — one layer, three linetypes, every entity ByLayer on layer zero) was left untouched and passes.

## Full suite

```
cd packages/jet_cad_2d && dart test
...
00:02 +671: All tests passed!
```

```
dart analyze
Analyzing jet_cad_2d...
No issues found!
```

```
dart format --output=none --set-exit-if-changed .
Formatted 99 files (0 changed) in 0.16 seconds.
```

## Files changed

- `packages/jet_cad_2d/lib/jet_cad_2d.dart` (export added)
- `packages/jet_cad_2d/lib/src/codec/schema_version.dart` (bump + doc comment)
- `packages/jet_cad_2d/lib/src/document/text_scalars.dart` (new)
- `packages/jet_cad_2d/lib/src/store/entity_store.dart` (toJson/fromJson)
- `packages/jet_cad_2d/test/codec/schema_v3_fixture_test.dart` (new)
- `packages/jet_cad_2d/test/store/entity_store_test.dart` (key-order assertion updated)
- `packages/jet_cad_2d/test/testing/generate_document_test.dart` (fingerprints re-baselined)

Commit: `7f85226` — `feat(jet_cad_2d): carry text fields through the codec at schema 4`

## Self-review findings

- Checked each new/changed assertion would actually fail if the implementation regressed: the four `fromJson` defaults, the `scalarOr` bounds check, the fixed key order (both the new fixture-level check implicitly via successful decode, and the explicit `entity_store_test.dart` key-list test), and the two fingerprints all have a code path that would move them if the corresponding line were removed or wrong.
- No migration framework, no payload padding — confirmed by reading `json_codec.dart:103`'s existing version bound and by the round-trip test explicitly asserting `"scalars":[100.0]` (not four values) survives.
- No stray scratch files committed (two throwaway Dart scripts used to inspect the empty-document encoding and compute the second fingerprint were deleted before committing; `git status` is clean).
- `analysis_options.yaml` untouched.

## Concerns

None. The only judgment call was updating `test/store/entity_store_test.dart`'s key-order test, which isn't in the brief's file list but is a direct, unavoidable consequence of the `toJson` change and was required for "task ends green."
