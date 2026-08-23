# Task 1 report: `InstanceNode` gains four style fields, and the schema bumps to 6

## Status: DONE (committed — see Addendum: coordinator ruling and completion)

Steps 1-7 of the brief were executed exactly as specified. Step 8 (commit) was
withheld because Step 6's gate — "the pre-existing suite is unchanged and
green" — did not hold: three pre-existing tests fail as a direct, mechanical
consequence of this change. Per the explicit instruction given for this task
("if any pre-existing test moves, stop and report it as a concern rather than
adjusting the test"), I did not touch those three tests and I did not commit.
All code changes described below are present in the working tree, uncommitted.

## Step 1: failing round-trip test written

Created `packages/jet_cad_2d/test/codec/instance_style_codec_test.dart` with
the exact content from the brief, with one mechanical adjustment: the brief's
own code block imports `dart:typed_data` and
`package:vector_math/vector_math_64.dart`, neither of which is referenced by
the test body. `dart analyze` flags both as `unused_import` errors (see Step
6). I removed the two unused imports; no test logic, assertion, or fixture
value was changed. Final imports:

```dart
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
```

## Step 2: confirmed it fails to compile

```
$ cd packages/jet_cad_2d && CI=true dart test test/codec/instance_style_codec_test.dart
00:00 +0: loading test/codec/instance_style_codec_test.dart
00:00 +0 -1: loading test/codec/instance_style_codec_test.dart [E]
  Failed to load "test/codec/instance_style_codec_test.dart":
  test/codec/instance_style_codec_test.dart:22:7: Error: No named parameter with the name 'lineweight'.
        lineweight: 211,
        ^^^^^^^^^^
  lib/src/document/node.dart:165:9: Context: Found this candidate, but the arguments don't match.
    const InstanceNode({
          ^^^^^^^^^^^^
  test/codec/instance_style_codec_test.dart:34:17: Error: The getter 'lineweight' isn't defined for the type 'InstanceNode'.
  ... (getter errors for transparency, linetype, linetypeScale, and the
       copyWith named-parameter error for linetypeScale, all as expected)
00:00 +0 -1: Some tests failed.

Failing tests:
  test/codec/instance_style_codec_test.dart: loading test/codec/instance_style_codec_test.dart
```

Matches the brief's expectation exactly: compile failure, "No named parameter
with the name 'lineweight'."

## Step 3 & 4: `InstanceNode` fields, constructor, `copyWith`, JSON, `==`/`hashCode`

Applied verbatim to `packages/jet_cad_2d/lib/src/document/node.dart`:
- Four new fields (`lineweight`, `transparency`, `linetype`, `linetypeScale`)
  with the brief's exact doc comments, after `color`.
- Constructor extended with the four named parameters and the brief's exact
  defaults (`kByBlock`, `kByBlock`, `ReservedHandles.byBlockLinetype`, `1.0`).
- `copyWith` extended with the four nullable parameters.
- `toJson` extended with the four keys (`'lineweight'`, `'transparency'`,
  `'linetype'`, `'linetypeScale'`).
- `fromJson` extended with the brief's exact absent-tolerant defaulting logic
  and comment.
- `operator ==` and `hashCode` extended with all four fields, `linetypeScale`
  compared with exact `==` per the brief's comment (stored value, not a
  geometric decision).

`dart format` reformatted my edit's whitespace to match project style
(wrapping/indentation only); no semantic change.

## Step 5: schema bump and stale citation

`packages/jet_cad_2d/lib/src/codec/schema_version.dart`:
- Added the v6 doc-comment entry verbatim from the brief.
- Changed `const int kSchemaVersion = 5` to `= 6`.
- Fixed the v5 entry's citation from `json_codec.dart:103` to `:104` (verified:
  the version guard `if (version is! int || version < 1 || version >
  kSchemaVersion)` is at `packages/jet_cad_2d/lib/src/codec/json_codec.dart:104`).

## Step 6: new test + full suite + analyze + format

New test file, isolated:

```
$ cd packages/jet_cad_2d && CI=true dart test test/codec/instance_style_codec_test.dart
00:00 +0: loading test/codec/instance_style_codec_test.dart
00:00 +0: an instance round-trips all four style fields at non-default values
00:00 +1: the four fields are absent-tolerant and default to the no-op values
00:00 +2: two instances differing only in linetypeScale are not equal
00:00 +3: the schema this build writes is 6
00:00 +4: All tests passed!
```

All four new tests pass.

`dart analyze` (after removing the two unused imports from Step 1):

```
$ dart analyze
Analyzing jet_cad_2d...
No issues found!
```

`dart format`:

```
$ dart format --output=none --set-exit-if-changed .
Formatted 111 files (0 changed) in 0.19 seconds.
```

Full engine suite:

```
$ CI=true dart test
...
00:03 +778 -3: test/invariants/query_allocation_test.dart: (tearDownAll)
00:03 +778 -3: Some tests failed.

Failing tests:
  test/codec/json_codec_test.dart: the schema version is 5, and a v6 document is refused
  test/testing/generate_document_test.dart: both text fractions default to zero and change nothing
  test/testing/generate_document_test.dart: the default document is the one Plan 2 measured, byte for byte
```

778 pass, 3 fail. This is the concern — see below. Nothing else moved: no
allocation-invariant test, no differential test, no other codec test failed.

## Step 7: mutants M10 and M11

Backed up first, never used `git checkout`:

```
$ cp lib/src/document/node.dart /tmp/node.dart.bak
```

**M11** — deleted the `'linetypeScale': linetypeScale,` line from `toJson`:

```diff
-        'linetype': linetype.toJson(),
-        'linetypeScale': linetypeScale,
+        'linetype': linetype.toJson(),
       };
```

```
$ CI=true dart test test/codec/instance_style_codec_test.dart
00:00 +0: loading test/codec/instance_style_codec_test.dart
00:00 +0: an instance round-trips all four style fields at non-default values
00:00 +0 -1: an instance round-trips all four style fields at non-default values [E]
  Expected: <4.0>
    Actual: <1.0>

  package:matcher                                 expect
  test/codec/instance_style_codec_test.dart 36:5  main.<fn>

00:00 +0 -1: the four fields are absent-tolerant and default to the no-op values
00:00 +1 -1: two instances differing only in linetypeScale are not equal
00:00 +2 -1: the schema this build writes is 6
00:00 +3 -1: Some tests failed.
```

Killed as expected: `an instance round-trips all four style fields at
non-default values` goes red on `expect(back.linetypeScale, 4.0)` — dropped
field silently defaults back to `1.0` on read, exactly as the brief predicted.

Restored from the backup:

```
$ cp /tmp/node.dart.bak lib/src/document/node.dart
```

**M10** — changed `fromJson`'s absent-`linetype` default from
`ReservedHandles.byBlockLinetype` to `ReservedHandles.byLayerLinetype`:

```diff
         linetype: json['linetype'] == null
-            ? ReservedHandles.byBlockLinetype
+            ? ReservedHandles.byLayerLinetype
             : Handle.fromJson(json['linetype']),
```

```
$ CI=true dart test test/codec/instance_style_codec_test.dart
00:00 +0: loading test/codec/instance_style_codec_test.dart
00:00 +0: an instance round-trips all four style fields at non-default values
00:00 +1: the four fields are absent-tolerant and default to the no-op values
00:00 +1 -1: the four fields are absent-tolerant and default to the no-op values [E]
  Expected: <3>
    Actual: <2>

  package:matcher                                 expect
  test/codec/instance_style_codec_test.dart 61:5  main.<fn>

00:00 +2 -1: two instances differing only in linetypeScale are not equal
00:00 +3 -1: the schema this build writes is 6
00:00 +4 -1: Some tests failed.
```

Killed as expected: `the four fields are absent-tolerant and default to the
no-op values` goes red — `expect(back.linetype,
ReservedHandles.byBlockLinetype)` (Handle(3)) got Handle(2) instead. Matches
the brief exactly, including its note that M10's *resolution* consequence
(BYLAYER's linetype leaking into a BYBLOCK entity) is Task 4's concern, not
this one's.

Restored from the backup again and diffed to confirm byte-identical restore:

```
$ cp /tmp/node.dart.bak lib/src/document/node.dart
$ diff /tmp/node.dart.bak lib/src/document/node.dart && echo "IDENTICAL - restore confirmed"
IDENTICAL - restore confirmed
```

Re-ran analyze/format/full-suite after the restore to confirm the working
tree is back to exactly the Step 6 state (same 778 pass / 3 fail, `dart
analyze` clean, `dart format` clean). Confirmed.

`git status` at the end shows only the intended three files touched
(`schema_version.dart`, `node.dart` modified; the new test file untracked); no
`analysis_options.yaml` change.

## Step 8: NOT executed — see Concerns

## Concerns

Three pre-existing tests fail, all as a direct and — on inspection —
apparently expected mechanical consequence of this task's two changes (adding
four keys to `InstanceNode.toJson`, and bumping `kSchemaVersion` 5→6), not of
any actual behavioural drift in `contextFor` or rendering:

1. **`test/codec/json_codec_test.dart`: "the schema version is 5, and a v6
   document is refused"** — this test literally asserts `expect(kSchemaVersion,
   5)`. Any Step-5 schema bump breaks this by construction; it is not a
   consequence of the four new fields specifically.

2. **`test/testing/generate_document_test.dart`: "the default document is the
   one Plan 2 measured, byte for byte"** and **"both text fractions default to
   zero and change nothing"** — both assert a hardcoded FNV-1a fingerprint over
   `DraftDocumentCodec.encodeToString(generateDocument(...))`. Adding four keys
   to every `InstanceNode`'s JSON, and changing the written `schemaVersion`,
   necessarily changes this fingerprint even though nothing about how the
   document *resolves* or *renders* has changed. Notably, both tests carry
   their own precedent for this exact situation — comments already present in
   the file read:
   - "Re-baselined in Plan 3e Task 7: kSchemaVersion moved from 4 to 5, and
     that value is the first thing every serialisation writes."
   - "Re-baselined in Plan 3e Task 7 in step with the sibling test above:
     kSchemaVersion moved from 4 to 5, which shifts every fingerprint in this
     file regardless of what `extra` drew."

   That is, the last time `kSchemaVersion` moved, these two fingerprints were
   re-baselined as part of that same task, with a comment documenting why. The
   same pattern would apply here (new fingerprints would need computing and a
   third re-baseline comment added), but I was explicitly instructed not to
   adjust any pre-existing test if one moved, and to report it as a concern
   instead — so I stopped rather than exercising that judgment call myself.

All 778 other pre-existing tests remain green, including every
allocation-invariant and differential test. `dart analyze` and `dart format`
are clean on the full working tree.

**Decision needed:** either (a) authorize re-baselining the two
`generate_document_test.dart` fingerprints and updating the
`json_codec_test.dart` schema-version literal as part of this task (consistent
with the Plan 3e Task 7 precedent already recorded in the file), or (b) treat
this as a real gate failure requiring a different Step 5 approach. I did not
make this call unilaterally.

## Files changed (uncommitted)

- `packages/jet_cad_2d/lib/src/document/node.dart` — four fields, constructor,
  `copyWith`, `toJson`/`fromJson`, `==`/`hashCode`.
- `packages/jet_cad_2d/lib/src/codec/schema_version.dart` — v6 doc entry,
  `kSchemaVersion = 6`, citation fix.
- `packages/jet_cad_2d/test/codec/instance_style_codec_test.dart` (new) — four
  tests per the brief, minus two unused imports the brief's code block
  included but the body never references.

## Addendum: coordinator ruling and completion

The coordinator reviewed the Concerns above and issued two rulings.

### Ruling T1-A — the three moved tests are authorised for re-baseline

Evidence requested and gathered before touching any test:

**1. The diff never touches the generator.**

```
$ git diff --name-only
packages/jet_cad_2d/lib/src/codec/schema_version.dart
packages/jet_cad_2d/lib/src/document/node.dart
```

`lib/src/testing/generate_document.dart` does not appear — the RNG draw order
cannot have changed, because the code that drives the RNG was never edited.

**2. The structural sibling tests stayed green**, run before any re-baseline
edit, against the pre-ruling tree:

```
$ CI=true dart test test/testing/generate_document_test.dart
00:00 +0: loading test/testing/generate_document_test.dart
00:00 +0: generateDocument is deterministic across calls
00:00 +1: the default document is the one Plan 2 measured, byte for byte
00:00 +1 -1: the default document is the one Plan 2 measured, byte for byte [E]
  Expected: <4778422453512744465>
    Actual: <1593811103237081036>

  package:matcher                                expect
  test/testing/generate_document_test.dart 56:5  main.<fn>

00:00 +1 -1: defaults reproduce the Plan 2 corpus structurally too
00:00 +2 -1: nestingDepth places instances inside definitions
00:00 +3 -1: nesting terminates: no definition reaches itself
00:00 +4 -1: mirroredFraction produces negative-determinant instances
00:00 +5 -1: nonUniformFraction produces anisotropic instances
00:00 +6 -1: groupCount puts leaves under group nodes
00:00 +7 -1: byBlockFraction and layerCount create more than one resolution path
00:00 +8 -1: byBlock entities live where ByBlock means something
00:00 +9 -1: dashedFraction is reported and non-zero when asked for
00:00 +10 -1: every extension stays deterministic
00:00 +11 -1: both text fractions default to zero and change nothing
00:00 +11 -2: both text fractions default to zero and change nothing [E]
  Expected: <4778422453512744465>
    Actual: <1593811103237081036>

  package:matcher                                 expect
  test/testing/generate_document_test.dart 233:5  main.<fn>

00:00 +11 -2: labelFraction produces repeating strings out of the root budget
00:00 +12 -2: labelFraction is not capped by the old floor-text ceiling at a larger corpus
00:00 +13 -2: labelFraction does not change the total leaf count
00:00 +14 -2: attributedInstanceFraction gives each chosen instance a unique attrib
00:00 +15 -2: attributedInstanceFraction places attributes in the instance's local space, not world space
00:00 +16 -2: Some tests failed.
```

Every structural assertion in the file — `defaults reproduce the Plan 2
corpus structurally too`, `nestingDepth places instances inside definitions`,
`nesting terminates: no definition reaches itself`, `mirroredFraction
produces negative-determinant instances`, `nonUniformFraction produces
anisotropic instances`, `groupCount puts leaves under group nodes`,
`byBlockFraction and layerCount create more than one resolution path`,
`byBlock entities live where ByBlock means something`, `dashedFraction is
reported and non-zero when asked for`, `every extension stays deterministic`,
`labelFraction produces repeating strings out of the root budget`,
`labelFraction is not capped by the old floor-text ceiling at a larger
corpus`, `labelFraction does not change the total leaf count`,
`attributedInstanceFraction gives each chosen instance a unique attrib`,
`attributedInstanceFraction places attributes in the instance's local space,
not world space` — passed. Only the two fingerprint assertions moved, and
both moved to the *same* actual value on the *same* input in both tests
(`1593811103237081036` for `generateDocument(2000, definitionCount: 20)`),
confirming the cause is the serialisation shape, not an RNG draw-order shift
(which would not reproduce identically across two independently-written test
bodies calling the same generator arguments). Per the discriminator the
coordinator gave, this is the benign case.

New fingerprints were computed directly (not guessed, not lifted from the
failure's `Actual:` line alone — cross-checked with a standalone script using
the test file's own `fingerprint` function, run twice to confirm
determinism):

```
$ dart run tool/_scratch_fingerprint.dart
1593811103237081036
-4104570370941889723
1593811103237081036
-4104570370941889723
```

(Scratch script written to `packages/jet_cad_2d/tool/_scratch_fingerprint.dart`
for this check only, then deleted — it is not part of the commit.)

Updated both fingerprint tests in
`packages/jet_cad_2d/test/testing/generate_document_test.dart` with the new
values and a third re-baseline comment line, continuing the existing voice and
leaving the surrounding warning text (including the "not a signal to update
the expected value" caution) untouched:

- `'the default document is the one Plan 2 measured, byte for byte'`: values
  `4778422453512744465` / `2508170127112452780` → `1593811103237081036` /
  `-4104570370941889723`, with the added comment `// Re-baselined in Plan
  3f.1 Task 1: InstanceNode.toJson gained four style keys and kSchemaVersion
  moved from 5 to 6.`
- `'both text fractions default to zero and change nothing'`: same two values
  updated, with `// Re-baselined in Plan 3f.1 Task 1 in step with the sibling
  test above: InstanceNode.toJson gained four style keys and kSchemaVersion
  moved from 5 to 6.`

No structural test was touched, as instructed.

### Ruling T1-B — `json_codec_test.dart` tightened, not just re-pointed

Replaced the test at `test/codec/json_codec_test.dart` with the coordinator's
exact replacement (renamed to `'the schema version is 6, and a v7 document is
refused by version'`, asserts `kSchemaVersion == 6`, decodes
`{'schemaVersion': 7}`, and matches `throwsA(isA<SchemaVersionError>())`
instead of `throwsA(anything)`). `SchemaVersionError` is already reachable
through the file's existing `package:jet_cad_2d/jet_cad_2d.dart` import, so no
new import was needed.

### Final verification

```
$ CI=true dart test
...
00:03 +781: test/invariants/query_allocation_test.dart: (tearDownAll)
00:03 +781: All tests passed!

$ dart analyze
Analyzing jet_cad_2d...
No issues found!

$ dart format --output=none --set-exit-if-changed .
Formatted 111 files (0 changed) in 0.19 seconds.
```

All tests green, 781 total (778 pre-existing + 4 new from
`instance_style_codec_test.dart` − 1 renamed-in-place, net +3 vs. the
pre-task baseline of 778... the exact count is incidental; what matters is 0
failures). `git status` before commit:

```
$ git status --porcelain
 M packages/jet_cad_2d/lib/src/codec/schema_version.dart
 M packages/jet_cad_2d/lib/src/document/node.dart
 M packages/jet_cad_2d/test/codec/json_codec_test.dart
 M packages/jet_cad_2d/test/testing/generate_document_test.dart
?? packages/jet_cad_2d/test/codec/instance_style_codec_test.dart
```

No `analysis_options.yaml` change.

### Commit

Committed with the exact message from the brief's Step 8, plus the two
re-baselined/tightened test files added to the commit (they are part of
making this task's own change land green, per the coordinator's ruling).

