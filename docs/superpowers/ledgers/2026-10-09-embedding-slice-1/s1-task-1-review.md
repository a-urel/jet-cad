# Slice 1, Task 1 — a table's detail and `tableAt` (G-1, G-4): independent review

**Commit reviewed:** `85918c4` (parent `a136a43`), in a separate clone
(`/tmp/s1t1-review/repo` for the gates, `/tmp/s1t1-review/mut` for the
mutants). Nothing in `/home/user/jet-cad` was edited apart from this file.

## Verdict: **Approved with fixes**

The code is correct against G-1 and G-4 as far as I could break it; all
eight named mutants are killed (re-run here, four of them and four more);
every gate is green. The fixes are test gaps: two cache branches that are
**load-bearing** (keys really do collide across documents) survive their
mutants, plus a few cheap pins. None needs a code change except one wrong
comment.

## What I checked, and how it reads

**Decomposition (`table_detail.dart`).** `rotation = atan2(b, a)` is the
angle of column 0, which is `sx·(cos θ, sin θ)` under `R(θ)·diag(sx, sy)`
with `sx > 0`, so it is θ for mirrored, scaled and turned placements alike
(the table label's reading). `mirrored = det < 0`. `size` uses the column
lengths (not rows, not `sqrt|det|`), right under rotation + non-uniform
scale. `center` is the box's centre through the full affine map.
`TableCandidate.corners` are in box order (min,min),(max,min),(max,max),
(min,max) and **not** reversed by `candidatesOf` (the spec's F-8 line
"reversed when mirrored" misdescribes `table_picker.dart:113-116`; the
picker's own doc says "counter-clockwise unless the transform mirrors");
the implementation reverses `[0,3,2,1]` when mirrored, so the result is
counter-clockwise starting at the image of (min,min) in both cases. A
negative `a` in a mirrored table (L at 120°, ` 7 ` at −150°) is handled by
`det`, not by the sign of `a`.

**Join.** `_tables.tables` (survey, ascending by handle) joined to
`candidatesOf` by instance: duplicate numbers keep two entries (keyed by
instance, not number); unnumbered keeps `number: null`; hidden and
non-finite fall to `tableDetailWithoutGeometry`; locked keeps geometry with
`locked: true`. `TableSurvey` only lists `InstanceNode`s, so the
`case final InstanceNode node` filter cannot drop a table, and the list
has `tables`' length and order (TD1 pins `[d.table] == c.tables`).

**Active plan.** `_active.document` (`_service ?? _design`) for both
members; CD1 and TA3 pin it.

**Cache key.** Every path that changes a detail moves one of (document,
`stateId`, `mutationRevision`): commands (incl. `SetLayerCommand`,
`SetInstanceLayerCommand`, `Change size`) move `stateId`; out-of-history
table edits move `mutationRevision`; `setMode`, `load`, `newPlan`,
`resetLayout` and `restoreServiceLayout` install a new document. The
document identity is **necessary**, not decorative: measured here, a
freshly decoded copy and a freshly loaded plan sit at the same key as the
design (`R1 keys: design (0, 18), service (0, 18)`,
`R2 keys: before (0, 18), after load (0, 18)`). The code has it; the suite
does not pin it (R-1, R-2).

**`tableAt`.** `camera.value.screenToWorld` (canvas logical px → world mm,
y up), reach `kTouchPickRadiusPixels / cam.scale` only for
`PointerDeviceKind.touch` — the same constant and condition as
`InteractionLayer._event` (`interaction_layer.dart:163-175`) and the same
`pick(..., reach: touch ? … : 0)` as `TableSelectTool`
(`table_select_tool.dart:147`). Hidden tables are never candidates;
unnumbered → `number` null. The picker is rebuilt per (document, state,
revision) — conservative (choice 5), see O7.

**Cost.** `tableDetails` is O(nodes + entities) only on a key change;
reads at the same key return the identical unmodifiable list. `tableAt` is
call-rate (one `Vector2`), as G-4 allows. Nothing is on the frame path.

**P-1.** The diff to `floor_plan_controller.dart` only adds imports and
members; the barrel only adds `export 'src/host/table_detail.dart' show
FloorPlanTableDetail;`; `barrel_test` only adds the name; `controller_test`
only appends CD1 and a prefixed import. No existing signature, `==`,
`hashCode` or `toString` changed. `vector_math` is already a dependency.

**Fixture.** Non-degenerate as the plan asks: box (300..1100, −200..400)
about base (0,0) with an asymmetric top; 30°, mirrored 90°, (1.5, 0.8) at
−20°, 180° unmirrored; every table ≥ 40 m off the origin; hidden and
locked layers; two `7`s; an unnumbered table; table 9's corners overflow
to infinity with a finite det of 1; camera `(0.37, 0, 0, −0.37, …)`, set
before every `tableAt`. Expectations come from `embeddingBox` and each
table's own transform / `degrees` / `sx` / `sy`, not from the code; TD6's
corner order is the documented convention (spec says only "CCW"), checked
independently by the shoelace sign. One soft spot: table 2's "90°" has
`a = cos(π/2) = 6.1e-17`, not 0 (R-3).

**Docs.** Accurate except the `-0.0` comment (R-4) and "one entity-store
scan" (R-6).

## Findings

- **R-1 (Medium, test gap) — `tableDetails`' document identity is
  unpinned.** Mutant O6 (drop `!identical(_detailsDocument, d)`) passes
  the whole task suite. TD8's "a mode switch makes a new list" does not
  catch it because TD8 edits the design first (state 0 → 1), so the copy's
  key (0, 18) differs by accident. Without the edit, design and copy share
  (0, 18); after a `load` too. Under O6 a host that loads another plan
  reads the **old plan's geometry**. **Fix:** add a test that reads
  `tableDetails`, `load`s the fixture with table 1 moved 2 m (built by a
  second controller and `designJson()`), and expects the new centre
  (my probe R2, kills O6 by value); optionally also move TD8's mode
  switch before its edit (probe R1, kills O6 by identity).
- **R-2 (Medium, test gap) — `tableAt`'s picker document identity is
  unpinned.** Mutant O10 (drop `!identical(picker.document, d)`) passes
  the suite; after a `load` at the same key it answers from the old plan.
  **Fix:** the same load-based test for `tableAt` (probe R6: table 1's top
  answers `'1'`, after the load of the moved plan it answers null).
- **R-3 (Low) — `mirrored` is pinned only up to equivalence with
  `a·d < 0`.** Mutant O4 (`mirrored = m.a * m.d < 0`) survives: for every
  fixture placement `a·d` has det's sign because table 2's `a`, `d` are
  ±6.1e-17 rather than 0. It differs from `det < 0` at an exact quarter
  turn and on sheared placements. **Fix:** write table 2 exactly,
  `Transform2(0, 1, 1, 0, 43000, -27000)` (= R(90°)·diag(1, −1)); M-H3's
  `a < 0` is still killed (a = 0), and O4 dies (probe R4).
- **R-4 (Low) — the rotation normalisations are untested; one comment is
  wrong.** O2 (drop `if (rotation <= -π) rotation += 2π`) survives; it
  matters for a placement written with `b = -0.0`, `a < 0`, which
  `atan2` reads as −π against the documented `(-π, π]`. **Fix:** a
  `tableDetailOf` unit test with `Transform2(-1, -0.0, 0, -1, …)` →
  `rotation == π` (probe R3). O3 (drop `if (rotation == 0) rotation =
  0.0`) is an **equivalent** mutant: `num.hashCode`'s contract
  (`dart:core` num.dart:51-53) gives zero and minus zero the same hash
  (measured on the VM: `[0, 0, true]`), so the comment "their hash codes
  need not agree" is false. **Fix:** drop the line and the comment, or
  reword it as normalising `-0.0` for `toString` only.
- **R-5 (Low, optional pins).** O8 (`kind != mouse` gets reach, so a
  stylus does) survives — one line in TA2 with `PointerDeviceKind.stylus`
  → null kills it (probe R5). O9 (a layer missing from the table reads
  hidden) survives — choice 3 is unpinned; pin it or leave it recorded.
- **R-6 (Nit) — `_detailsOf`'s doc says "One entity-store scan".**
  `candidatesOf` runs its own `TableSurvey.of` (a scan of the entity
  store's attribs) plus `leavesByOwner`, on top of the controller's
  cached survey. Say "O(nodes + entities), at document-change rate".
- **R-7 (Info) — O7 survives, equivalent today.** Keeping one picker per
  document (no state/revision check) changes nothing observable: the
  picker rebuilds its candidates by (stateId, revision) itself, and
  definition handles are never reused. The per-state rebuild is the
  implementer's conservative choice 5; no action.
- **R-8 (Info) — the implementer's F-1 is confirmed.** CI runs
  `dart run tool/ci/expect_failures.dart --package ${{ matrix.package }}
  --root ${{ matrix.package }}` from the repo root with
  `matrix.package: packages/jet_cad_2d` (`.github/workflows/ci.yml:63-68`,
  `:37`). The bare name reports the two standing engine failures as new
  (transcript below). Later briefs should write the path form.
- **R-9 (Info) — spec F-8 wording.** "corners … reversed when mirrored"
  does not describe `candidatesOf`; the implementation is right, the
  spec's fact line is not. Fix the spec line when it is next touched.

## Mutants

Applied in `/tmp/s1t1-review/mut` by a script that copies the file aside,
replaces exactly one occurrence, runs the tests, restores from the copy
and `cmp`s it (`git status` clean afterwards). Default tests:
`test/host/table_detail_test.dart test/host/controller_test.dart`
(baseline `00:02 +49: All tests passed!`). Probes R1–R6 were a scratch
file `test/host/zz_review_test.dart` (removed afterwards; all six pass on
the unmutated code: `00:00 +6: All tests passed!`).

| # | Mutant | Result | Killer / red line |
|---|---|---|---|
| M-H1 | `cx, cy = box.minX, box.minY` | killed | TD2, CD1 |
| M-H2 | `rotation = -atan2(b, a)` | killed | TD3 |
| M-H3 | `mirrored = m.a < 0` | killed | TD4 `Expected: false / Actual: <true>` (`180 degrees, unmirrored`); TD6 `… of <43400.0> / Actual: <42800.0>` (`2 corner 1: x`) |
| M-H4 | `tableDetails` reads `_design.document` | killed | TD8, CD1 |
| M-H13 | `center = Offset(m.e, m.f)` | killed | TD2, CD1 |
| M-H14 | `size = Size(box.width, box.height)` | killed | TD5, TD6 |
| M-H15 | cache key without `_detailsLayers` | killed | TD9 `Expected: null / Actual: Offset:<Offset(42736.6, -30343.8)>` (`its layer is hidden now`) |
| M-H19b(tableAt) | touch reach → 0 | killed | TA2 |
| O1 | corners not reversed when mirrored | killed | TD6 |
| O2 | drop the `<= -π` normalisation | **survived** | probe R3 kills it (R-4) |
| O3 | drop the `-0.0 → 0.0` line | **survived** | equivalent (R-4) |
| O4 | `mirrored = m.a * m.d < 0` | **survived** | probe R4 kills it (R-3) |
| O5 | size by row lengths `sqrt(a²+c²)`, `sqrt(b²+d²)` | killed | TD5, TD6 |
| O6 | `tableDetails` key without document identity | **survived** | probes R1, R2 kill it (R-1) |
| O7 | `tableAt` picker kept per document (no state/revision) | **survived** | equivalent today (R-7) |
| O8 | reach for `kind != mouse` (stylus too) | **survived** | probe R5 kills it (R-5) |
| O9 | missing layer reads hidden (`?? false`) | **survived** | unpinned choice 3 (R-5) |
| O10 | `tableAt` picker without document identity | **survived** | probe R6 kills it (R-2) |

Probe runs against the surviving mutants (real output):

```
O6z: exit 1; restored; failing tests:
    00:00 +0 -1: R1 a mode switch with no edit before it gives a new list [E]
    00:00 +0 -2: R2 a load of another plan gives that plan's details [E]
O2z: exit 1; restored; failing tests:
    00:00 +2 -1: R3 an exact half turn written with b = -0.0 reads +pi [E]
O4z: exit 1; restored; failing tests:
    00:00 +3 -1: R4 a mirror at exactly 90 degrees (a = d = 0) is mirrored [E]
O8z: exit 1; restored; failing tests:
    00:00 +4 -1: R5 a stylus gets no finger reach [E]
O10z: exit 1; restored; failing tests:
    00:00 +5 -1: R6 tableAt after a load reads the loaded plan [E]
```

Key collision, printed by the probes on the unmutated code:

```
R1 keys: design (0, 18), service (0, 18)
R2 keys: before (0, 18), after load (0, 18)
```

## Gates (tails, `export PATH=/root/sdk/flutter/bin:$PATH CI=true`, at `85918c4`)

```
### packages/jet_cad_floor_plan :: flutter test
05:07 +1452: All tests passed!
### packages/jet_cad_floor_plan :: flutter analyze
No issues found! (ran in 8.8s)
### packages/jet_cad_floor_plan :: dart format --output=none --set-exit-if-changed .
Formatted 245 files (0 changed) in 1.26 seconds.
exit 0
### apps/restaurant_demo :: flutter test
00:28 +39: All tests passed!
### apps/restaurant_demo :: flutter analyze
No issues found! (ran in 5.8s)
### apps/restaurant_demo :: dart format --output=none --set-exit-if-changed .
Formatted 4 files (0 changed) in 0.09 seconds.
exit 0
### apps/floor_planner :: flutter test
02:21 +212: All tests passed!
### apps/floor_planner :: flutter analyze
No issues found! (ran in 6.5s)
### apps/floor_planner :: dart format --output=none --set-exit-if-changed .
Formatted 47 files (0 changed) in 0.22 seconds.
exit 0
### packages/jet_cad_2d :: dart test --file-reporter json:/tmp/s1t1-review/e.json
test-exit 1
### . :: dart run tool/ci/expect_failures.dart --package packages/jet_cad_2d --root packages/jet_cad_2d /tmp/s1t1-review/e.json
packages/jet_cad_2d: 1255 tests; the standing failures and skips, exactly
exit 0
### packages/jet_cad_2d_flutter :: flutter test --file-reporter json:/tmp/s1t1-review/r.json
test-exit 1
### . :: dart run tool/ci/expect_failures.dart --package packages/jet_cad_2d_flutter --root packages/jet_cad_2d_flutter /tmp/s1t1-review/r.json
packages/jet_cad_2d_flutter: 1363 tests; the standing failures and skips, exactly
exit 0
### . :: dart run tool/ci/expect_failures.dart --package jet_cad_2d --root packages/jet_cad_2d /tmp/s1t1-review/e.json   (F-1: the bare name)
jet_cad_2d: new failure: test/testing/generate_document_test.dart :: both text fractions default to zero and change nothing
jet_cad_2d: new failure: test/testing/generate_document_test.dart :: the default document is the one Plan 2 measured, byte for byte
exit 1
```

## Fix list for the implementer

1. R-1 + R-2: one load-based test for `tableDetails` and `tableAt`
   (kills O6, O10); optionally move TD8's mode switch before its edit.
2. R-3: table 2 written exactly as `Transform2(0, 1, 1, 0, 43000, -27000)`;
   re-run M-H3 and O4.
3. R-4: a `tableDetailOf` test for `b = -0.0`, `a < 0` → π; drop or reword
   the `-0.0` comment/line.
4. R-5 (optional): a stylus line in TA2.
5. R-6: the scan comment.

## Fixes (controller's)

**Commit:** `6c742b4` on `claude/exciting-pasteur-9m22jv` (parent
`03c6d66`), not pushed. Tests and comments only, plus the spec's F-8 line;
no behaviour change.

| Finding | What changed |
|---|---|
| R-1, R-2 | New `TD11` (`table_detail_test.dart`): reads `tableDetails` and `tableAt` (builds the cache and the picker), builds the fixture with table 1 moved 2 m along x in a second controller (`designJson()`), `load`s it, resets the camera, asserts the premise (a new document at the **same** `(stateId, mutationRevision)` key), then expects table 1's centre at the moved box centre (computed from `embeddingBox` and `translation(2000, 0)·transform`), null at its old top and `'1'` at its moved top. TD8 left as it was. |
| R-3 | `embedding_fixture.dart`: table 2 is `const EmbeddingTable('2', Transform2(0, 1, 1, 0, 43000, -27000), degrees: 90, sy: -1)` (= R(90°)·diag(1, −1) with columns (0, 1) and (1, 0), worked by hand, det −1). TD4 gains the premise `a·d == 0`, `det == -1` and names O4. Task 2's camera tests pass with it (full suite below). |
| R-4 | New `TD12` (a `tableDetailOf` unit test): `Transform2(-1, -0.0, 0, -1, …)` reads `rotation == π` (premise `atan2(-0.0, -1) == -π`), not mirrored; `Transform2(1, -0.0, 0, 1, …)` reads a rotation that is not negative, `toString` contains `rotation: 0.0,`, and equals the `b = +0.0` detail. The `-0.0 → 0.0` line is **kept** (harmless, and it keeps `-0.0` out of `toString`, so O3 is no longer equivalent: TD12 kills it); its comment now says the hash codes agree (`num.hashCode`) and the line is for `toString`. |
| R-5 | TA2 gains `tableAt(near, kind: PointerDeviceKind.stylus)` → null. New `TD13`: the locked layer removed from the plan's layers (out of history, before any read) → `L` reads `table.visible` true, `layer ''`, `locked` false, its centre, `tables[i].visible` true, and `tableAt` on its top `'L'` (choice 3 pinned). |
| R-6 | `_detailsOf`'s doc: "O(nodes + entities): `candidatesOf`'s own survey and a `leavesByOwner` scan, on top of the controller's cached survey; at document-change rate." |
| R-7, R-8 | No action (info). |
| R-9 | Spec F-8: corners are "always in the box's order, (min, min), (max, min), (max, max), (min, max) through the transform, never reordered: counter-clockwise unless the transform mirrors, clockwise when it does" (`table_picker.dart:119-122`, `:255-258`); "G-1's detail reverses a mirrored table's". |

### Mutants

Each applied in this tree by a script that copied the file aside to the
scratchpad, replaced exactly one occurrence, ran `flutter test
test/host/table_detail_test.dart test/host/controller_test.dart`, restored
the file from the copy and `cmp`ed it (every run: `exit 1; restored (cmp
ok)`; `git status` showed only this task's edits afterwards). Red lines
copied from the logs.

| # | Mutant | Killer | Red line |
|---|---|---|---|
| O6 | drop `!identical(_detailsDocument, d) \|\|` | TD11 | `Expected: a numeric value within <4.2556217782649106e-8> of <42556.21778264911>` / `Actual: <40556.21778264911>` / `Which: differs by <2000.0>` (`O6: 1 moved by the load: x`) |
| O10 | drop `!identical(picker.document, d) \|\|` | TD11 | `Expected: null` / `Actual: '1'` (`O10: 1 is gone from there`) |
| O4 | `mirrored = m.a * m.d < 0` | TD4, TD6 | `Expected: true` / `Actual: <false>` (`mirrored at 90 degrees`); TD6 `Expected: a numeric value within <4.34e-8> of <43400.0>` / `Actual: <42800.0>` (`2 corner 1: x`) |
| M-H3 (re-run) | `mirrored = m.a < 0` | TD4, TD6, TD12 | TD4 `Expected: false` / `Actual: <true>`; TD6 `… of <43400.0>` / `Actual: <42800.0>`; TD12 `Expected: false` / `Actual: <true>` (the half turn's `mirrored`) |
| O2 | drop `if (rotation <= -math.pi) rotation += 2 * math.pi;` | TD12 | `Expected: <3.141592653589793>` / `Actual: <-3.141592653589793>` |
| O3 | drop `if (rotation == 0) rotation = 0.0;` | TD12 | `Expected: false` / `Actual: <true>` (`rotation.isNegative`) |
| O8 | `kind != PointerDeviceKind.mouse` gets the reach | TA2 | `Expected: null` / `Actual: '1'` (`O8: only a finger gets the reach`) |
| O9 | `visible: layers[node.layer]?.visible ?? false` | TD13 | `Expected: true` / `Actual: <false>` (`table.visible`, `table_detail_test.dart:392`) |

### Gates (tails, `export PATH=/root/sdk/flutter/bin:$PATH CI=true`, at the working tree committed as `6c742b4`)

```
### packages/jet_cad_floor_plan :: flutter test
test-exit 0
07:12 +1471: All tests passed!
### packages/jet_cad_floor_plan :: flutter analyze
analyze-exit 0
No issues found! (ran in 5.1s)
### packages/jet_cad_floor_plan :: dart format --output=none --set-exit-if-changed .
format-exit 0
Formatted 248 files (0 changed) in 1.27 seconds.
### apps/restaurant_demo :: flutter test
test-exit 0
00:28 +39: All tests passed!
### apps/restaurant_demo :: flutter analyze
analyze-exit 0
No issues found! (ran in 4.2s)
### apps/restaurant_demo :: dart format --output=none --set-exit-if-changed .
format-exit 0
Formatted 4 files (0 changed) in 0.06 seconds.
```

No `analysis_options.yaml` was touched or committed.
