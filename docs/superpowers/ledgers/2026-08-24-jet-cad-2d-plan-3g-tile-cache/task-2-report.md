# Task 2 report: `DocumentTables` gets a mutation counter and a `Listenable`

Commit: `3dcca1b` — "feat: table mutations finally emit a signal"

## R4 — the six real constructor signatures and how the test's call sites were corrected

Read from `packages/jet_cad_2d/lib/src/document/tables.dart` before writing the test:

1. **`LayerRecord`** (line ~85, unchanged from brief):
   ```dart
   const LayerRecord({
     required this.handle,
     required this.name,
     required this.color,        // DraftColor
     required this.linetype,     // Handle
     required this.lineweight,   // int
     required this.transparency, // int
     this.visible = true,
     this.locked = false,
   });
   ```
   Correction needed: the brief's `layer()` helper used `DraftColor.indexed(3)`, which does not
   exist — `DraftColor` is a `sealed` class with no such factory. The concrete non-default
   constructor is `IndexedColor(3)` (a `DraftColor` subtype). Changed
   `const DraftColor.indexed(3)` to `const IndexedColor(3)`. Everything else in the helper
   (`lineweight: 50`, `transparency: 40`) matched the real constructor as written.

2. **`LinetypeRecord`** (line ~177):
   ```dart
   const LinetypeRecord({
     required this.handle,
     required this.name,
     required this.description,
     required this.pattern,      // DashPattern, not List<double>
   });
   ```
   `DashPattern` itself requires `{required dashes: List<double>, required totalLength: double}`.
   Correction: the brief's `pattern: const [4.0, -2.0]` does not typecheck — `pattern` is a
   `DashPattern`, not a raw list. Changed to
   `pattern: const DashPattern(dashes: [4.0, -2.0], totalLength: 6.0)`, preserving the same
   non-trivial dash values (4.0 dash, 2.0 gap) the brief specified; `totalLength` is the sum of
   the absolute segment lengths, matching the convention documented on `DashPattern`. Also gave
   `description` a non-empty value (`'A test-only dash pattern'`) rather than leaving it at the
   brief's `''`, since `description` has no default to differ from (it's a required field) and an
   empty string reads as the degenerate case for a string field.

3. **`TextStyleRecord`** (line ~234):
   ```dart
   const TextStyleRecord({
     required this.handle,
     required this.name,
     required this.fontFamily,    // not "font"
     this.widthFactor = 1.0,
     this.obliqueAngle = 0.0,
     this.fixedHeight = 0.0,
     this.isShx = false,
     this.shxFileName = '',
   });
   ```
   Correction: the brief's `font: 'Roboto'` used a parameter name that does not exist; the real
   field is `fontFamily`. Fixed the call site to `fontFamily: 'Roboto'`. `widthFactor: 1.2`
   already matched the real optional parameter and is non-default (default `1.0`) — kept as is.

4. **`PatternRecord`** (line ~347):
   ```dart
   const PatternRecord({
     required this.handle,
     required this.name,
     required this.lines,   // List<PatternLine>, required, no default
   });
   ```
   Correction: the brief's call `PatternRecord(handle: Handle(913), name: 'NET')` omits the
   required `lines` parameter entirely and does not compile. `lines` has no default value to
   differ from — it must be supplied. Per R4's instruction to preserve non-default *character*
   where a default exists, and to supply something non-degenerate where it doesn't, I added one
   `PatternLine` with non-zero, non-identity values:
   ```dart
   lines: [
     PatternLine(
       angle: 45.0, baseX: 0.0, baseY: 0.0,
       deltaX: 0.0, deltaY: 3.0, dashes: [2.0, -1.0],
     ),
   ]
   ```
   An empty `lines: const []` would have compiled but made the record indistinguishable from a
   pattern with no lines at all — the degenerate case this codebase's fixture discipline warns
   against.

5. **`DimStyleRecord`** (line ~393):
   ```dart
   const DimStyleRecord({
     required this.handle,
     required this.name,
     this.opaque = const {},   // Map<String, Object?>, defaults to empty
   });
   ```
   The brief's call omitted `opaque`, which compiles (it's optional) but leaves the record at its
   default (`{}`) — exactly the pattern R4 flags as proving less than a fixture with a non-default
   field a resolver might read. Added `opaque: {'DIMASZ': 2.5}` so the record carries an actual
   opaque field rather than an empty map.

6. **`AppIdRecord`** (line ~446):
   ```dart
   const AppIdRecord({required this.handle, required this.name});
   ```
   **No non-default field to set** — `AppIdRecord` has exactly two fields, `handle` and `name`,
   both required and both already varied per-fixture in the test (`Handle(915)`, `'ACAD2'`).
   There is no optional or defaulted field on this record type at all, so the anti-degenerate
   habit has nothing further to apply to. Left the brief's call site unchanged
   (`AppIdRecord(handle: const Handle(915), name: 'ACAD2')`).

## Step 2 — failing run (compile failure), verbatim

```
00:00 +0: loading test/document/tables_revision_test.dart
00:00 +0 -1: loading test/document/tables_revision_test.dart [E]
  Failed to load "test/document/tables_revision_test.dart":
  test/document/tables_revision_test.dart:30:12: Error: The getter 'changes' isn't defined for the type 'DocumentTables'.
   - 'DocumentTables' is from 'package:jet_cad_2d/src/document/tables.dart' ('lib/src/document/tables.dart').
  Try correcting the name to the name of an existing getter, or defining a getter or field named 'changes'.
      tables.changes.addListener(listener);
             ^^^^^^^
  test/document/tables_revision_test.dart:31:30: Error: The getter 'changes' isn't defined for the type 'DocumentTables'.
   - 'DocumentTables' is from 'package:jet_cad_2d/src/document/tables.dart' ('lib/src/document/tables.dart').
  Try correcting the name to the name of an existing getter, or defining a getter or field named 'changes'.
      addTearDown(() => tables.changes.removeListener(listener));
                               ^^^^^^^
  test/document/tables_revision_test.dart:33:26: Error: The getter 'mutationRevision' isn't defined for the type 'DocumentTables'.
   - 'DocumentTables' is from 'package:jet_cad_2d/src/document/tables.dart' ('lib/src/document/tables.dart').
  Try correcting the name to the name of an existing getter, or defining a getter or field named 'mutationRevision'.
      final start = tables.mutationRevision;
                           ^^^^^^^^^^^^^^^^
  test/document/tables_revision_test.dart:36:19: Error: The getter 'mutationRevision' isn't defined for the type 'DocumentTables'.
   - 'DocumentTables' is from 'package:jet_cad_2d/src/document/tables.dart' ('lib/src/document/tables.dart').
  Try correcting the name to the name of an existing getter, or defining a getter or field named 'mutationRevision'.
      expect(tables.mutationRevision, start + 1, reason: 'add');
                    ^^^^^^^^^^^^^^^^
  test/document/tables_revision_test.dart:40:19: Error: The getter 'mutationRevision' isn't defined for the type 'DocumentTables'.
   - 'DocumentTables' is from 'package:jet_cad_2d/src/document/tables.dart' ('lib/src/document/tables.dart').
  Try correcting the name to the name of an existing getter, or defining a getter or field named 'mutationRevision'.
      expect(tables.mutationRevision, start + 2, reason: 'remove');
                    ^^^^^^^^^^^^^^^^
  test/document/tables_revision_test.dart:44:19: Error: The getter 'mutationRevision' isn't defined for the type 'DocumentTables'.
   - 'DocumentTables' is from 'package:jet_cad_2d/src/document/tables.dart' ('lib/src/document/tables.dart').
  Try correcting the name to the name of an existing getter, or defining a getter or field named 'mutationRevision'.
      expect(tables.mutationRevision, start + 3, reason: 'clear');
                    ^^^^^^^^^^^^^^^^
  test/document/tables_revision_test.dart:51:26: Error: The getter 'mutationRevision' isn't defined for the type 'DocumentTables'.
   - 'DocumentTables' is from 'package:jet_cad_2d/src/document/tables.dart' ('lib/src/document/tables.dart').
  Try correcting the name to the name of an existing getter, or defining a getter or field named 'mutationRevision'.
      final after = tables.mutationRevision;
                           ^^^^^^^^^^^^^^^^
  test/document/tables_revision_test.dart:55:19: Error: The getter 'mutationRevision' isn't defined for the type 'DocumentTables'.
   - 'DocumentTables' is from 'package:jet_cad_2d/src/document/tables.dart' ('lib/src/document/tables.dart').
  Try correcting the name to the name of an existing getter, or defining a getter or field named 'mutationRevision'.
      expect(tables.mutationRevision, after,
                    ^^^^^^^^^^^^^^^^
  test/document/tables_revision_test.dart:62:26: Error: The getter 'mutationRevision' isn't defined for the type 'DocumentTables'.
   - 'DocumentTables' is from 'package:jet_cad_2d/src/document/tables.dart' ('lib/src/document/tables.dart').
  Try correcting the name to the name of an existing getter, or defining a getter or field named 'mutationRevision'.
      final after = tables.mutationRevision;
                           ^^^^^^^^^^^^^^^^
  test/document/tables_revision_test.dart:64:19: Error: The getter 'mutationRevision' isn't defined for the type 'DocumentTables'.
   - 'DocumentTables' is from 'package:jet_cad_2d/src/document/tables.dart' ('lib/src/document/tables.dart').
  Try correcting the name to the name of an existing getter, or defining a getter or field named 'mutationRevision'.
      expect(tables.mutationRevision, after);
                    ^^^^^^^^^^^^^^^^
  test/document/tables_revision_test.dart:69:27: Error: The getter 'mutationRevision' isn't defined for the type 'DocumentTables'.
   - 'DocumentTables' is from 'package:jet_cad_2d/src/document/tables.dart' ('lib/src/document/tables.dart').
  Try correcting the name to the name of an existing getter, or defining a getter or field named 'mutationRevision'.
      var revision = tables.mutationRevision;
                            ^^^^^^^^^^^^^^^^
  test/document/tables_revision_test.dart:73:19: Error: The getter 'mutationRevision' isn't defined for the type 'DocumentTables'.
   - 'DocumentTables' is from 'package:jet_cad_2d/src/document/tables.dart' ('lib/src/document/tables.dart').
  Try correcting the name to the name of an existing getter, or defining a getter or field named 'mutationRevision'.
      expect(tables.mutationRevision, ++revision);
                    ^^^^^^^^^^^^^^^^
  test/document/tables_revision_test.dart:79:19: Error: The getter 'mutationRevision' isn't defined for the type 'DocumentTables'.
   - 'DocumentTables' is from 'package:jet_cad_2d/src/document/tables.dart' ('lib/src/document/tables.dart').
  Try correcting the name to the name of an existing getter, or defining a getter or field named 'mutationRevision'.
      expect(tables.mutationRevision, ++revision);
                    ^^^^^^^^^^^^^^^^
  test/document/tables_revision_test.dart:85:19: Error: The getter 'mutationRevision' isn't defined for the type 'DocumentTables'.
   - 'DocumentTables' is from 'package:jet_cad_2d/src/document/tables.dart' ('lib/src/document/tables.dart').
  Try correcting the name to the name of an existing getter, or defining a getter or field named 'mutationRevision'.
      expect(tables.mutationRevision, ++revision);
                    ^^^^^^^^^^^^^^^^
  test/document/tables_revision_test.dart:103:19: Error: The getter 'mutationRevision' isn't defined for the type 'DocumentTables'.
   - 'DocumentTables' is from 'package:jet_cad_2d/src/document/tables.dart' ('lib/src/document/tables.dart').
  Try correcting the name to the name of an existing getter, or defining a getter or field named 'mutationRevision'.
      expect(tables.mutationRevision, ++revision);
                    ^^^^^^^^^^^^^^^^
  test/document/tables_revision_test.dart:111:19: Error: The getter 'mutationRevision' isn't defined for the type 'DocumentTables'.
   - 'DocumentTables' is from 'package:jet_cad_2d/src/document/tables.dart' ('lib/src/document/tables.dart').
  Try correcting the name to the name of an existing getter, or defining a getter or field named 'mutationRevision'.
      expect(tables.mutationRevision, ++revision);
                    ^^^^^^^^^^^^^^^^
  test/document/tables_revision_test.dart:113:19: Error: The getter 'mutationRevision' isn't defined for the type 'DocumentTables'.
   - 'DocumentTables' is from 'package:jet_cad_2d/src/document/tables.dart' ('lib/src/document/tables.dart').
  Try correcting the name to the name of an existing getter, or defining a getter or field named 'mutationRevision'.
      expect(tables.mutationRevision, ++revision);
                    ^^^^^^^^^^^^^^^^
00:00 +0 -1: Some tests failed.

Failing tests:
  test/document/tables_revision_test.dart: loading test/document/tables_revision_test.dart
```

No errors about the six record constructors — confirming the corrected call sites (per R4 above)
were the only fixes the test file needed to become a pure "API not defined yet" failure, exactly
the shape Step 2 calls for.

## Step 4 — passing run, verbatim

```
00:00 +0: loading test/document/tables_revision_test.dart
00:00 +0: every table mutator bumps the revision and notifies
00:00 +1: a rejected add bumps nothing
00:00 +2: a remove of an absent handle bumps nothing
00:00 +3: every section is wired, not just layers
00:00 +4: All tests passed!
```

## Step 5 — whole engine suite, verbatim (tail)

```
00:03 +796: test/invariants/query_allocation_test.dart: pickInto stays local: an over-wide broad phase would blow the time budget
00:03 +797: test/invariants/query_allocation_test.dart: (tearDownAll)
00:03 +797: All tests passed!
```
797 tests, 0 failures. `DocumentTables.standard()` and the JSON codec tests (which construct
`TableSection`s) all still pass with the constructor changed from bare field initializers to
`late final` fields assigned in the constructor body.

## Step 6 — mutant M8 (counter half), `clear`'s `onMutated?.call()` removed

Copied `lib/src/document/tables.dart` aside, removed the single `onMutated?.call();` line from
`TableSection.clear()` only (left `add` and `remove` untouched), and reran the target test.

### Red run, verbatim

```
00:00 +0: loading test/document/tables_revision_test.dart
00:00 +0: every table mutator bumps the revision and notifies
00:00 +0 -1: every table mutator bumps the revision and notifies [E]
  Expected: <8>
    Actual: <7>
  clear
  
  package:matcher                               expect
  test/document/tables_revision_test.dart 44:5  main.<fn>
  
00:00 +0 -1: a rejected add bumps nothing
00:00 +1 -1: a remove of an absent handle bumps nothing
00:00 +2 -1: every section is wired, not just layers
00:00 +3 -1: Some tests failed.

Failing tests:
  test/document/tables_revision_test.dart: every table mutator bumps the revision and notifies

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

Exactly the `clear` assertion at line 44 (`reason: 'clear'`) went red; the `add` and `remove`
assertions in the same test, and every other test in the file, stayed green — confirming the
mutation is caught specifically by the `clear` check and would be invisible to a test that only
exercised `add`.

Restored the file from the copy (`cp` from the backup, never `git checkout`), then reran:

### Restored green run, verbatim

```
00:00 +0: loading test/document/tables_revision_test.dart
00:00 +0: every table mutator bumps the revision and notifies
00:00 +1: a rejected add bumps nothing
00:00 +2: a remove of an absent handle bumps nothing
00:00 +3: every section is wired, not just layers
00:00 +4: All tests passed!
```

## Step 7 — both packages' full-suite gate, verbatim (tails)

### `packages/jet_cad_2d`

`CI=true dart test` (tail):
```
00:03 +796: test/invariants/query_allocation_test.dart: pickInto stays local: an over-wide broad phase would blow the time budget
00:03 +797: test/invariants/query_allocation_test.dart: (tearDownAll)
00:03 +797: All tests passed!
```

`CI=true dart analyze`:
```
Analyzing jet_cad_2d...
No issues found!
```

`CI=true dart format --output=none --set-exit-if-changed .`:
```
Formatted 113 files (0 changed) in 0.19 seconds.
```

### `packages/jet_cad_2d_flutter`

`CI=true flutter test` (tail):
```
00:04 +305 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink fillCircle leaves the paint on stroke afterwards
00:04 +306 ~1: All tests passed!
```
306 tests passed, 1 skipped (pre-existing skip, unrelated to this task's change).

`CI=true flutter analyze`:
```
Analyzing jet_cad_2d_flutter...                                 
No issues found! (ran in 1.2s)
```

`CI=true dart format --output=none --set-exit-if-changed .`:
```
Formatted 55 files (0 changed) in 0.10 seconds.
```

## Deviations from the brief

1. **R4 corrections** to the six record constructor call sites in the test, detailed above
   (`DraftColor.indexed(3)` → `IndexedColor(3)`; `LinetypeRecord.pattern` as `List<double>` →
   `DashPattern(...)`; `TextStyleRecord.font` → `fontFamily`; `PatternRecord` given a required
   `lines` list with one non-trivial `PatternLine`; `DimStyleRecord` given a non-default `opaque`
   map). These are corrections to the plan's assumed shapes, not deviations in the implementation
   itself — the tree was treated as the authority, as instructed.
2. **`AppIdRecord`** has no optional/defaulted field beyond `handle`/`name` to make non-default —
   reported per the brief's instruction rather than invented.
3. No other deviation. `tables.dart`'s implementation (Step 3) — `TableSection`'s `onMutated`
   callback, `add`/`remove`/`clear` bump semantics, `DocumentTables`'s `late final` sections,
   `_revision`/`mutationRevision`/`changes`/`_bump`, the `_TablesNotifier`, `VoidCallback`
   typedef, and `TableListenable` interface — was implemented exactly as specified in the brief,
   verbatim.

## Git safety notes

`git status` was checked before staging; `flutter pub get` (invoked by `flutter test`/`flutter
analyze`) did not modify any `analysis_options.yaml` file in this run, and only the two intended
files (`lib/src/document/tables.dart`, `test/document/tables_revision_test.dart`) were staged and
committed, by explicit path.
