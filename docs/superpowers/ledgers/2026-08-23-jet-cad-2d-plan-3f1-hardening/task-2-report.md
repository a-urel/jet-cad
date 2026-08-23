# Task 2 report — `contextFor` resolves the three sentinel fields

## Deviation from the brief (flagged, not silently made)

The brief's `fixture()` helper (inside the `BYLAYER on an INSTANCE reads the
substituted layer, not node.layer` group) calls:

```dart
addLayer(doc, ReservedHandles.layerZero, '0',
    lineweight: 13, transparency: 9, linetype: const Handle(70));
```

`DraftDocument.empty()` seeds layer 0 via `DocumentTables.standard()`
(`lib/src/document/tables.dart:507-513`), so this collides on both handle and
name and throws `DuplicateHandleError(1)` before the test body's assertion
ever runs — verified by running the test file verbatim first (see the first
transcript below). This is a bug in the provided test code, not in
`contextFor`; the established fix pattern already exists in the repo at
`test/index/query_filter_test.dart:381` (`doc.tables.layers.remove(layer);`
before re-adding). I applied the same one-line fix inside the shared
`addLayer` helper:

```dart
Handle addLayer(
  DraftDocument doc,
  Handle handle,
  String name, {
  required int lineweight,
  required int transparency,
  required Handle linetype,
}) {
  // `DraftDocument.empty()` seeds layer 0 via `DocumentTables.standard()`, so
  // overriding it (as the BYLAYER-substitution fixture does, to give layer 0
  // and the substituted layer distinct values) collides on both handle and
  // name unless the existing record is removed first -- the same pattern
  // `test/index/query_filter_test.dart:381` uses to replace a layer record.
  doc.tables.layers.remove(handle);
  doc.tables.layers.add(LayerRecord(
    handle: handle,
    name: name,
    color: const IndexedColor(5),
    linetype: linetype,
    lineweight: lineweight,
    transparency: transparency,
    visible: true,
    locked: false,
  ));
  return handle;
}
```

`remove` on a handle that isn't present (the STRUCT / handle-100 and
DEFAULTED / handle-100 calls) is a no-op, so this doesn't change behaviour for
the non-colliding calls. Everything else in the test file is verbatim from
the brief. This does not change the fixture's semantics (four distinct
sources per property) — it only makes the layer-0 override actually take
effect instead of throwing.

## Step 1 — test file written

Created `packages/jet_cad_2d/test/document/instance_style_test.dart` per the
brief, with the one fix above.

## Step 2 — run it and watch it fail

First run, verbatim brief code (before the fixture fix), to confirm the
`DuplicateHandleError` diagnosis:

```
$ CI=true dart test test/document/instance_style_test.dart
00:00 +0: loading test/document/instance_style_test.dart
00:00 +0: an INSERT imposes its concrete lineweight on a BYBLOCK child
00:00 +0 -1: an INSERT imposes its concrete lineweight on a BYBLOCK child [E]
  Expected: <211>
    Actual: <25>

  package:matcher                               expect
  test/document/instance_style_test.dart 127:5  main.<fn>

00:00 +0 -1: an INSERT imposes its concrete transparency on a BYBLOCK child
00:00 +0 -2: an INSERT imposes its concrete transparency on a BYBLOCK child [E]
  Expected: <118>
    Actual: <255>

  package:matcher                               expect
  test/document/instance_style_test.dart 141:5  main.<fn>

00:00 +0 -2: an INSERT imposes its concrete linetype on a BYBLOCK child
00:00 +0 -3: an INSERT imposes its concrete linetype on a BYBLOCK child [E]
  Expected: <42>
    Actual: <4>

  package:matcher                               expect
  test/document/instance_style_test.dart 150:5  main.<fn>

00:00 +0 -3: BYLAYER on an INSTANCE reads the substituted layer, not node.layer lineweight
00:00 +0 -4: BYLAYER on an INSTANCE reads the substituted layer, not node.layer lineweight [E]
  DuplicateHandleError(1)
  package:jet_cad_2d/src/document/tables.dart 53:7  TableSection.add
  test/document/instance_style_test.dart 25:21      addLayer
  test/document/instance_style_test.dart 162:7      main.<fn>.fixture
  test/document/instance_style_test.dart 177:19     main.<fn>.<fn>

00:00 +0 -4: BYLAYER on an INSTANCE reads the substituted layer, not node.layer transparency
00:00 +0 -5: BYLAYER on an INSTANCE reads the substituted layer, not node.layer transparency [E]
  DuplicateHandleError(1)
  package:jet_cad_2d/src/document/tables.dart 53:7  TableSection.add
  test/document/instance_style_test.dart 25:21      addLayer
  test/document/instance_style_test.dart 162:7      main.<fn>.fixture
  test/document/instance_style_test.dart 188:19     main.<fn>.<fn>

00:00 +0 -5: BYLAYER on an INSTANCE reads the substituted layer, not node.layer linetype
00:00 +0 -6: BYLAYER on an INSTANCE reads the substituted layer, not node.layer linetype [E]
  DuplicateHandleError(1)
  package:jet_cad_2d/src/document/tables.dart 53:7  TableSection.add
  test/document/instance_style_test.dart 25:21      addLayer
  test/document/instance_style_test.dart 162:7      main.<fn>.fixture
  test/document/instance_style_test.dart 200:19     main.<fn>.<fn>

00:00 +0 -6: kLineweightDefault never reaches a ResolvedStyle carried directly by the INSERT
00:00 +1 -6: kLineweightDefault never reaches a ResolvedStyle reached through the INSERT's BYLAYER lookup
00:00 +2 -6: Some tests failed.

Failing tests:
  test/document/instance_style_test.dart: BYLAYER on an INSTANCE reads the substituted layer, not node.layer linetype
  test/document/instance_style_test.dart: BYLAYER on an INSTANCE reads the substituted layer, not node.layer lineweight
  test/document/instance_style_test.dart: BYLAYER on an INSTANCE reads the substituted layer, not node.layer transparency
  test/document/instance_style_test.dart: an INSERT imposes its concrete linetype on a BYBLOCK child
  ... and 2 more
```

**Six FAIL, two PASS** — matches the controller's correction exactly. Passing:
both `kLineweightDefault` tests (`carried directly by the INSERT`, `reached
through the INSERT's BYLAYER lookup`). Failing: the three "imposes its
concrete X" tests (assertion mismatch, e.g. lineweight expected 211 got 25)
and the three BYLAYER tests (via `DuplicateHandleError`, since the fixture
bug fires before any assertion in that group can run).

Second run, after applying the `addLayer` fix above (still before touching
`contextFor`), to confirm the BYLAYER tests fail on the *right* assertion
once the fixture actually works:

```
$ CI=true dart test test/document/instance_style_test.dart
00:00 +0: loading test/document/instance_style_test.dart
00:00 +0: an INSERT imposes its concrete lineweight on a BYBLOCK child
00:00 +0 -1: an INSERT imposes its concrete lineweight on a BYBLOCK child [E]
  Expected: <211>
    Actual: <25>
  ...
00:00 +0 -2: an INSERT imposes its concrete transparency on a BYBLOCK child [E]
  Expected: <118>
    Actual: <255>
  ...
00:00 +0 -3: an INSERT imposes its concrete linetype on a BYBLOCK child [E]
  Expected: <42>
    Actual: <4>
  ...
00:00 +0 -4: BYLAYER on an INSTANCE reads the substituted layer, not node.layer lineweight [E]
  Expected: <191>
    Actual: <25>
  ...
00:00 +0 -5: BYLAYER on an INSTANCE reads the substituted layer, not node.layer transparency [E]
  Expected: <167>
    Actual: <255>
  ...
00:00 +0 -6: BYLAYER on an INSTANCE reads the substituted layer, not node.layer linetype [E]
  Expected: <71>
    Actual: <4>
  ...
00:00 +1 -6: kLineweightDefault never reaches a ResolvedStyle carried directly by the INSERT
00:00 +2 -6: kLineweightDefault never reaches a ResolvedStyle reached through the INSERT's BYLAYER lookup
00:00 +2 -6: Some tests failed.
```

Still six FAIL / two PASS, now every failure is a value mismatch rather than
a setup exception. Same two passing tests as before.

## Step 3 — `contextFor` rewritten

Replaced `lib/src/document/style_resolver.dart:27-52` with the brief's code
verbatim (single layer-record fetch, `kByLayer`/`kByBlock`/fourth-arm switch
for lineweight with the `concrete()` guard against `kLineweightDefault`,
transparency switch, nested-conditional linetype resolution, `linetypeScale:
inherited.linetypeScale` left untouched). Deleted the now-unused
`_layerColorOf` helper.

## Step 4 — full verification

```
$ CI=true dart test test/document/instance_style_test.dart
00:00 +0: loading test/document/instance_style_test.dart
00:00 +0: an INSERT imposes its concrete lineweight on a BYBLOCK child
00:00 +1: an INSERT imposes its concrete transparency on a BYBLOCK child
00:00 +2: an INSERT imposes its concrete linetype on a BYBLOCK child
00:00 +3: BYLAYER on an INSTANCE reads the substituted layer, not node.layer lineweight
00:00 +4: BYLAYER on an INSTANCE reads the substituted layer, not node.layer transparency
00:00 +5: BYLAYER on an INSTANCE reads the substituted layer, not node.layer linetype
00:00 +6: kLineweightDefault never reaches a ResolvedStyle carried directly by the INSERT
00:00 +7: kLineweightDefault never reaches a ResolvedStyle reached through the INSERT's BYLAYER lookup
00:00 +8: All tests passed!
```

```
$ CI=true dart test
...
00:02 +786: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +787: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +788: test/invariants/query_allocation_test.dart: pickInto stays local: an over-wide broad phase would blow the time budget
00:03 +789: test/invariants/query_allocation_test.dart: (tearDownAll)
00:03 +789: All tests passed!
```

```
$ dart analyze
Analyzing jet_cad_2d...
No issues found!
```

```
$ dart format --output=none --set-exit-if-changed .
Formatted 112 files (0 changed) in 0.20 seconds.
```

(One intermediate `dart format` run flagged and then reformatted the new test
file for wrapping/line-length; after running `dart format
test/document/instance_style_test.dart` once, the check above is clean.)

Eight PASS on the target file, 789 PASS across the whole engine suite,
`dart analyze` clean (proving `_layerColorOf` was actually removed), format
clean.

## Step 5 — seven mutants fired

Backed up via `cp lib/src/document/style_resolver.dart
/tmp/style_resolver.dart.bak`; each mutant applied via Edit, run, then
restored via `cp /tmp/style_resolver.dart.bak
lib/src/document/style_resolver.dart` (never `git checkout`). Verified the
restored file is byte-identical to the backup after the last mutant
(`diff /tmp/style_resolver.dart.bak lib/src/document/style_resolver.dart` →
no output).

### M1 — `lineweight:` in the `contextFor` return → `inherited.lineweight`

Edit: in the `return StyleContext(...)` block, changed
`lineweight: lineweight,` to `lineweight: inherited.lineweight,`.

```
$ CI=true dart test test/document/instance_style_test.dart
00:00 +0: loading test/document/instance_style_test.dart
00:00 +0: an INSERT imposes its concrete lineweight on a BYBLOCK child
00:00 +0 -1: an INSERT imposes its concrete lineweight on a BYBLOCK child [E]
  Expected: <211>
    Actual: <25>
  ...
00:00 +0 -1: an INSERT imposes its concrete transparency on a BYBLOCK child
00:00 +1 -1: an INSERT imposes its concrete linetype on a BYBLOCK child
00:00 +2 -1: BYLAYER on an INSTANCE reads the substituted layer, not node.layer lineweight
00:00 +2 -2: BYLAYER on an INSTANCE reads the substituted layer, not node.layer lineweight [E]
  Expected: <191>
    Actual: <25>
  ...
00:00 +2 -2: BYLAYER on an INSTANCE reads the substituted layer, not node.layer transparency
00:00 +3 -2: BYLAYER on an INSTANCE reads the substituted layer, not node.layer linetype
00:00 +4 -2: kLineweightDefault never reaches a ResolvedStyle carried directly by the INSERT
00:00 +5 -2: kLineweightDefault never reaches a ResolvedStyle reached through the INSERT's BYLAYER lookup
00:00 +6 -2: Some tests failed.

Failing tests:
  test/document/instance_style_test.dart: BYLAYER on an INSTANCE reads the substituted layer, not node.layer lineweight
  test/document/instance_style_test.dart: an INSERT imposes its concrete lineweight on a BYBLOCK child
```

Reddened exactly `imposes its concrete lineweight` and `BYLAYER ...
lineweight` — matches the table. KILLED.

### M2 — `transparency:` in the `contextFor` return → `inherited.transparency`

Edit: changed `transparency: transparency,` to
`transparency: inherited.transparency,`.

```
$ CI=true dart test test/document/instance_style_test.dart
00:00 +0: loading test/document/instance_style_test.dart
00:00 +0: an INSERT imposes its concrete lineweight on a BYBLOCK child
00:00 +1: an INSERT imposes its concrete transparency on a BYBLOCK child
00:00 +1 -1: an INSERT imposes its concrete transparency on a BYBLOCK child [E]
  Expected: <118>
    Actual: <255>
  ...
00:00 +1 -1: an INSERT imposes its concrete linetype on a BYBLOCK child
00:00 +2 -1: BYLAYER on an INSTANCE reads the substituted layer, not node.layer lineweight
00:00 +3 -1: BYLAYER on an INSTANCE reads the substituted layer, not node.layer transparency
00:00 +3 -2: BYLAYER on an INSTANCE reads the substituted layer, not node.layer transparency [E]
  Expected: <167>
    Actual: <255>
  ...
00:00 +3 -2: BYLAYER on an INSTANCE reads the substituted layer, not node.layer linetype
00:00 +4 -2: kLineweightDefault never reaches a ResolvedStyle carried directly by the INSERT
00:00 +5 -2: kLineweightDefault never reaches a ResolvedStyle reached through the INSERT's BYLAYER lookup
00:00 +6 -2: Some tests failed.

Failing tests:
  test/document/instance_style_test.dart: BYLAYER on an INSTANCE reads the substituted layer, not node.layer transparency
  test/document/instance_style_test.dart: an INSERT imposes its concrete transparency on a BYBLOCK child
```

Reddened exactly `imposes its concrete transparency` and `BYLAYER ...
transparency`. KILLED.

### M3 — `linetype:` in the `contextFor` return → `inherited.linetype`

Edit: changed `linetype: linetype,` to `linetype: inherited.linetype,`.

```
$ CI=true dart test test/document/instance_style_test.dart
00:00 +0: loading test/document/instance_style_test.dart
00:00 +0: an INSERT imposes its concrete lineweight on a BYBLOCK child
00:00 +1: an INSERT imposes its concrete transparency on a BYBLOCK child
00:00 +2: an INSERT imposes its concrete linetype on a BYBLOCK child
00:00 +2 -1: an INSERT imposes its concrete linetype on a BYBLOCK child [E]
  Expected: <42>
    Actual: <4>
  ...
00:00 +2 -1: BYLAYER on an INSTANCE reads the substituted layer, not node.layer lineweight
00:00 +3 -1: BYLAYER on an INSTANCE reads the substituted layer, not node.layer transparency
00:00 +4 -1: BYLAYER on an INSTANCE reads the substituted layer, not node.layer linetype
00:00 +4 -2: BYLAYER on an INSTANCE reads the substituted layer, not node.layer linetype [E]
  Expected: <71>
    Actual: <4>
  ...
00:00 +4 -2: kLineweightDefault never reaches a ResolvedStyle carried directly by the INSERT
00:00 +5 -2: kLineweightDefault never reaches a ResolvedStyle reached through the INSERT's BYLAYER lookup
00:00 +6 -2: Some tests failed.

Failing tests:
  test/document/instance_style_test.dart: BYLAYER on an INSTANCE reads the substituted layer, not node.layer linetype
  test/document/instance_style_test.dart: an INSERT imposes its concrete linetype on a BYBLOCK child
```

Reddened exactly `imposes its concrete linetype` and `BYLAYER ...
linetype`. KILLED.

### M6 — `final record = document.tables.layers[node.layer];`

Edit: changed `final record = document.tables.layers[layer];` (the
`contextFor`-local one, immediately below the "One lookup, not four" comment)
to read `node.layer` instead of the substituted `layer`.

```
$ CI=true dart test test/document/instance_style_test.dart
00:00 +0: loading test/document/instance_style_test.dart
00:00 +0: an INSERT imposes its concrete lineweight on a BYBLOCK child
00:00 +1: an INSERT imposes its concrete transparency on a BYBLOCK child
00:00 +2: an INSERT imposes its concrete linetype on a BYBLOCK child
00:00 +3: BYLAYER on an INSTANCE reads the substituted layer, not node.layer lineweight
00:00 +3 -1: BYLAYER on an INSTANCE reads the substituted layer, not node.layer lineweight [E]
  Expected: <191>
    Actual: <13>
  ...
00:00 +3 -1: BYLAYER on an INSTANCE reads the substituted layer, not node.layer transparency
00:00 +3 -2: BYLAYER on an INSTANCE reads the substituted layer, not node.layer transparency [E]
  Expected: <167>
    Actual: <246>
  ...
00:00 +3 -2: BYLAYER on an INSTANCE reads the substituted layer, not node.layer linetype
00:00 +3 -3: BYLAYER on an INSTANCE reads the substituted layer, not node.layer linetype [E]
  Expected: <71>
    Actual: <70>
  ...
00:00 +3 -3: kLineweightDefault never reaches a ResolvedStyle carried directly by the INSERT
00:00 +4 -3: kLineweightDefault never reaches a ResolvedStyle reached through the INSERT's BYLAYER lookup
00:00 +5 -3: Some tests failed.

Failing tests:
  test/document/instance_style_test.dart: BYLAYER on an INSTANCE reads the substituted layer, not node.layer linetype
  test/document/instance_style_test.dart: BYLAYER on an INSTANCE reads the substituted layer, not node.layer lineweight
  test/document/instance_style_test.dart: BYLAYER on an INSTANCE reads the substituted layer, not node.layer transparency
```

Reddened exactly all three BYLAYER tests. KILLED.

### M7 — transparency's `kByLayer` arm → `node.transparency`

Edit: changed
```dart
final transparency = switch (node.transparency) {
  kByBlock => inherited.transparency,
  kByLayer => record?.transparency ?? inherited.transparency,
  _ => node.transparency,
};
```
to have the `kByLayer` arm read `node.transparency` instead of
`record?.transparency ?? inherited.transparency`.

```
$ CI=true dart test test/document/instance_style_test.dart
00:00 +0: loading test/document/instance_style_test.dart
00:00 +0: an INSERT imposes its concrete lineweight on a BYBLOCK child
00:00 +1: an INSERT imposes its concrete transparency on a BYBLOCK child
00:00 +2: an INSERT imposes its concrete linetype on a BYBLOCK child
00:00 +3: BYLAYER on an INSTANCE reads the substituted layer, not node.layer lineweight
00:00 +4: BYLAYER on an INSTANCE reads the substituted layer, not node.layer transparency
00:00 +4 -1: BYLAYER on an INSTANCE reads the substituted layer, not node.layer transparency [E]
  Expected: <167>
    Actual: <255>
  ...
00:00 +4 -1: BYLAYER on an INSTANCE reads the substituted layer, not node.layer linetype
00:00 +5 -1: kLineweightDefault never reaches a ResolvedStyle carried directly by the INSERT
00:00 +6 -1: kLineweightDefault never reaches a ResolvedStyle reached through the INSERT's BYLAYER lookup
00:00 +7 -1: Some tests failed.

Failing tests:
  test/document/instance_style_test.dart: BYLAYER on an INSTANCE reads the substituted layer, not node.layer transparency
```

Reddened exactly `BYLAYER ... transparency`. KILLED.

### M8 — linetype's `byLayerLinetype` branch → `node.linetype`

Edit: changed
```dart
final linetype = node.linetype == ReservedHandles.byBlockLinetype
    ? inherited.linetype
    : node.linetype == ReservedHandles.byLayerLinetype
        ? (record?.linetype ?? inherited.linetype)
        : node.linetype;
```
so the `byLayerLinetype` branch reads `node.linetype` instead of
`(record?.linetype ?? inherited.linetype)`.

```
$ CI=true dart test test/document/instance_style_test.dart
00:00 +0: loading test/document/instance_style_test.dart
00:00 +0: an INSERT imposes its concrete lineweight on a BYBLOCK child
00:00 +1: an INSERT imposes its concrete transparency on a BYBLOCK child
00:00 +2: an INSERT imposes its concrete linetype on a BYBLOCK child
00:00 +3: BYLAYER on an INSTANCE reads the substituted layer, not node.layer lineweight
00:00 +4: BYLAYER on an INSTANCE reads the substituted layer, not node.layer transparency
00:00 +5: BYLAYER on an INSTANCE reads the substituted layer, not node.layer linetype
00:00 +5 -1: BYLAYER on an INSTANCE reads the substituted layer, not node.layer linetype [E]
  Expected: <71>
    Actual: <2>
  ...
00:00 +5 -1: kLineweightDefault never reaches a ResolvedStyle carried directly by the INSERT
00:00 +6 -1: kLineweightDefault never reaches a ResolvedStyle reached through the INSERT's BYLAYER lookup
00:00 +7 -1: Some tests failed.

Failing tests:
  test/document/instance_style_test.dart: BYLAYER on an INSTANCE reads the substituted layer, not node.layer linetype
```

Reddened exactly `BYLAYER ... linetype`. KILLED.

### M9 — delete `concrete(...)`, use the raw values

Edit: changed
```dart
int concrete(int value) =>
    value == kLineweightDefault ? inherited.lineweight : value;
final lineweight = switch (node.lineweight) {
  kByBlock => inherited.lineweight,
  kByLayer => concrete(record?.lineweight ?? inherited.lineweight),
  _ => concrete(node.lineweight),
};
```
to
```dart
final lineweight = switch (node.lineweight) {
  kByBlock => inherited.lineweight,
  kByLayer => record?.lineweight ?? inherited.lineweight,
  _ => node.lineweight,
};
```
(the `concrete()` guard removed, raw values used directly).

```
$ CI=true dart test test/document/instance_style_test.dart
00:00 +0: loading test/document/instance_style_test.dart
00:00 +0: an INSERT imposes its concrete lineweight on a BYBLOCK child
00:00 +1: an INSERT imposes its concrete transparency on a BYBLOCK child
00:00 +2: an INSERT imposes its concrete linetype on a BYBLOCK child
00:00 +3: BYLAYER on an INSTANCE reads the substituted layer, not node.layer lineweight
00:00 +4: BYLAYER on an INSTANCE reads the substituted layer, not node.layer transparency
00:00 +5: BYLAYER on an INSTANCE reads the substituted layer, not node.layer linetype
00:00 +6: kLineweightDefault never reaches a ResolvedStyle carried directly by the INSERT
00:00 +6 -1: kLineweightDefault never reaches a ResolvedStyle carried directly by the INSERT [E]
  Expected: <25>
    Actual: <-3>
  ...
00:00 +6 -1: kLineweightDefault never reaches a ResolvedStyle reached through the INSERT's BYLAYER lookup
00:00 +6 -2: kLineweightDefault never reaches a ResolvedStyle reached through the INSERT's BYLAYER lookup [E]
  Expected: <25>
    Actual: <-3>
  ...
00:00 +6 -2: Some tests failed.

Failing tests:
  test/document/instance_style_test.dart: kLineweightDefault never reaches a ResolvedStyle carried directly by the INSERT
  test/document/instance_style_test.dart: kLineweightDefault never reaches a ResolvedStyle reached through the INSERT's BYLAYER lookup
```

Reddened exactly both `kLineweightDefault` tests. KILLED.

## Mutant summary

| mutant | must redden | actually reddened | verdict |
|---|---|---|---|
| M1 | `imposes its concrete lineweight`, `BYLAYER ... lineweight` | same two | KILLED |
| M2 | `imposes its concrete transparency`, `BYLAYER ... transparency` | same two | KILLED |
| M3 | `imposes its concrete linetype`, `BYLAYER ... linetype` | same two | KILLED |
| M6 | all three BYLAYER tests | same three | KILLED |
| M7 | `BYLAYER ... transparency` | same one | KILLED |
| M8 | `BYLAYER ... linetype` | same one | KILLED |
| M9 | both `kLineweightDefault` tests | same two | KILLED |

All seven mutants killed with the exact expected reddening pattern. File
restored to clean state after the last mutant, confirmed byte-identical to
the pre-mutation backup.

## Step 6 — commit

```
$ git add packages/jet_cad_2d/lib/src/document/style_resolver.dart \
        packages/jet_cad_2d/test/document/instance_style_test.dart
$ git commit -m "..."
```

See commit SHA reported separately. `git status` after commit showed no
modified `analysis_options.yaml` (none was touched).
