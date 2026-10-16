# Task 16 report: room tracing, inputs and label; the separator's parameters

Status: DONE

Commits (branch feat/architecture-kit, on top of f3f25f3f):
- `60fb05de` feat(kit-architecture): room tracing, its inputs and the separator's type
- `d2c6d9ea` test(kit-architecture): every room-inputs reader drops a frozen object first

## Implementation summary

- `lib/src/separator/separator.dart`: source lines 1-120 unchanged except the header, the
  `../ids.dart` + `../room/room_inputs.dart` imports, and `componentTypeId =
  ArchitectureTypes.separator`. `kDashedLinetypeRecord` / `ensureDashedLinetype` are not
  copied; the tests and the fixture use Task 9's `separator_linetype.dart`.
- `lib/src/room/room_trace.dart` (1111 lines) and `room_label.dart` (179 lines): byte-identical
  to the source apart from a two-line "Ported from ... unchanged (spec 3a C3.5)" header (checked
  with `diff` after stripping those lines: identical).
- `lib/src/room/room_inputs.dart`: the brief's adaptations (header, imports, class doc,
  `RoomInputs(this.document, this.live)`, `implements PlaceSource, Disposable`, `_live<T>(typeId)`,
  `@override dispose`, `roomInputsOf(PlanServices)` over `s.shared`), **plus the freeze check**
  (below).
- `lib/src/wall/wall.dart`: `contributesPlace`, `placeBox`, `placeInput` added after `reach`, with
  `import '../room/room_inputs.dart' show placeBoxInView, roomInputInView;` (Step 1's grep found
  none: exit 1, as R-P8 expects).
- `lib/src/type_naming.dart`: the separator registered after the opening.
- Barrel: `export 'src/separator/separator.dart' show SeparatorParams;` after the opening export.
- `test/support/catalog.dart`: the separator's registration after the opening's.
- `test/support/room_fixture.dart`: source lines 1-758 with exactly the brief's adaptations
  (header paragraph, kit imports, `installParametric, liveOf, testCatalog` added to the
  `wall_fixture.dart` import and export, `testCatalog().registerComponents` in `reloadWithPage`
  and `staleFile`, `RoomInputs(doc, liveOf(doc))` in `faceAt`); `addRoom` (561-580),
  `addSampleRooms` (669-677), `renameRoom` (694-697) not copied.

### Freezes and the cache (the controller's task-specific note)

The brief's design alone (rebuild on a `changes` event or `invalidate()`) would keep a frozen
wall or separator as an input until the next edit: a freeze changes no document. `RoomInputs` now
re-checks the liveness of what it was built from at each read, allocation-free, following
`WallBands._stillLive`:

- `_held` (the live walls, then the live separators, the cache was built from; `_heldWalls` the
  split) is filled in `_refresh`.
- `_dropFrozen()` — iterates `_held` by index, `live(h)` against the expected id, `invalidate()`
  on the first mismatch. Run by the readers whose answer can depend on any cached object:
  `placedIn`, `bounds`, and the `generation` getter (so a tool's memo keyed on generation, like
  today's Room tool `_verdictAt`, drops at once).
- `_dropFrozenAround(h)` — for the one-handle readers `inputOf` (so `placeBoxOf`) and
  `wallNeighboursOf`: checks `h` and, for a wall, its cached wall neighbours (a frozen neighbour
  leaves its joint, so the band changes; a non-neighbour cannot change `h`'s input or neighbour
  list). Reason for the split: `traceRoomAmong` reads `bounds`, `placedIn` a few times, then one
  `inputOf` per candidate; a full O(n) check inside every `inputOf` would make a trace
  O(k·n·types) (hundreds of thousands of `typeIdOf` calls at the 600-wall sizes the room tool
  tests time). This keeps a trace at a few O(n) checks plus O(degree) per candidate.
- A freeze only ever grows the plan's frozen set (`guard.dart:722` `frozen.addAll`; no unfreeze
  path found), so an object the cache does not hold needs no check.

Pinned by the new case RR-freeze (in `room_inputs_services_test.dart`): the two-room box plus two
separators at the corpus far origin turned 23°, every object in its own rotated, translated
group, a `FakePlanServices` whose `frozen` set is grown in place (no document change; the test
asserts `stateId` unchanged). Each step freezes one object and makes a different reader the first:
`inputOf` (separator), the trace (partition; areas by hand: 5,320,950 → 10,830,000 → 23,371,900 →
29,640,000), `generation`, `inputOf` of a live wall whose neighbour was frozen (differential
against a fresh `RoomInputs`), `wallNeighboursOf`, `bounds` (differential against a fresh cache),
`placedIn`. Mutations M-RR-9 to M-RR-14 below each turn it red.

## TDD evidence

RED (tests and fixture written first; no lib file existed):
`cd packages/jet_cad_2d_kit_architecture && flutter test test/separator test/room` → exit 1:

```
  Compilation failed for testPath=.../test/room/room_inputs_services_test.dart: test/room/room_inputs_services_test.dart:18:8: Error: Error when reading 'lib/src/room/room_inputs.dart': No such file or directory
  Compilation failed for testPath=.../test/separator/separator_test.dart: test/separator/separator_test.dart:7:8: Error: Error when reading 'lib/src/room/room_inputs.dart': No such file or directory
  test/room/room_inputs_services_test.dart:19:8: Error: Error when reading 'lib/src/room/room_trace.dart': No such file or directory
  test/room/room_label_test.dart:11:8: Error: Error when reading 'lib/src/room/room_label.dart': No such file or directory
  test/room/room_inputs_services_test.dart:43:20: Error: Method not found: 'roomInputsOf'.
  test/room/room_inputs_test.dart:27:18: Error: Method not found: 'RoomInputs'.
```
(and the same "Error when reading" line for room_inputs_test, room_label_test, room_localise_test,
room_tie_test, room_trace_test.)

GREEN: `flutter test test/separator test/room` → `00:09 +26: All tests passed!`
(4 + 8 + 3 + 4 + 3 + 1 + 3 = 26 cases).

## Gates (final HEAD d2c6d9ea)

Kit `packages/jet_cad_2d_kit_architecture`:
- `flutter test` → `00:15 +190: All tests passed!`
- `flutter analyze` → `No issues found! (ran in 3.5s)`
- `dart format --output=none --set-exit-if-changed .` → `Formatted 69 files (0 changed)`, exit 0
- `dart pub publish --dry-run` → `Package has 0 warnings.`
Repo root: `dart run tool/ci/check_kit_deps.dart` → `kit dependencies: 2 package(s) checked, none
names the plan library or another kit`, exit 0.
`git status --short` → clean (no analysis_options.yaml, nothing under jet_cad_floor_plan).
No other package touched.

Non-ASCII check (Step 10): `m²` kit/source: room_label 17/17, `ft²` 17/17; room_trace 0/0;
room_tie 1/9 — the source's other 8 are in DE2/DE3 (lines 436+, Task 18); lines 1-14,16-435 of
the source hold exactly 1. room_tie verified identical to source lines 1-14,16-435 modulo the
named adaptations (`cmp` after reversing them: SAME).

## Mutation results (committed files; each reverted with `git checkout -- <file>`, then
`git diff --quiet -- <file>` exit 0 for all fourteen)

| Mutation | Test | Red line |
|---|---|---|
| M-RR-1 `_live<WallParams>(…)` → `withComponent<WallParams>()` | RR-live, RR-freeze | `Expected: null  Actual: RoomInput:<RoomInput(22, band, …)>`; RR-freeze `Expected: within 0.01 of <23371900> Actual: <10830000.000003764>` |
| M-RR-2 `_live<SeparatorParams>(…)` → `withComponent<SeparatorParams>()` | RR-live, RR-freeze | `Expected: null  Actual: RoomInput:<RoomInput(26, segment, …)>` |
| M-RR-3 `roomInputsOf` body → `RoomInputs(s.document, liveTypesOf(s))` | RR-shared | `Expected: same instance as <Instance of 'RoomInputs'>` |
| M-RR-4 drop `Disposable` (+ its `@override`) | RR-shared | `Expected: <1>  Actual: <2>` |
| M-RR-5 `_live`: `if (live(h) == typeId) h` → `h` | RR-live, RR-freeze | `Expected: null  Actual: RoomInput:<RoomInput(22, band, …)>` |
| M-RR-6 separator `lineweight: 35` → `25` | SR2 | `Expected: <35>  Actual: <25>` |
| M-RR-7 `componentTypeId` → `'architecture.separators'` | SR1 (and SR4) | `Expected: 'architecture.separator'  Actual: 'architecture.separators'` |
| M-RR-8 `kCertificateMargin = 1` → `0` | LZ1 | `Expected: [[18, 34], [22], [26], [30]]  Actual: [[18], [22], [26], [30]]` |
| M-RR-9 (new) `_dropFrozen` body → `return;` | RR-freeze | `Expected: a value greater than <2>  Actual: <2>` |
| M-RR-10 (new) neighbour loop in `_dropFrozenAround` skipped | RR-freeze | `Expected: not RoomInput:<RoomInput(16, band, …)>  Actual: RoomInput:<RoomInput(16, band, …)>` (same band) |
| M-RR-11 (new) `_dropFrozenAround` → `return;` | RR-freeze | `Expected: null  Actual: RoomInput:<RoomInput(28, segment, …)>` |
| M-RR-12 (new) `generation` without `_dropFrozen()` | RR-freeze | `Expected: a value greater than <2>  Actual: <2>` |
| M-RR-13 (new) `placedIn` without `_dropFrozen()` | RR-freeze | `Expected: empty  Actual: [22]` |
| M-RR-14 (new) `bounds` without `_dropFrozen()` | RR-freeze | `Expected: not (…4498345.025000698, 1199960.9268871513, 4507456.089312964, 1206846.941554573)  Actual: (same)` |

(Mutation driver: a scratchpad Python script that edits, runs `flutter test <file>`, checks out the
file and runs `git diff --quiet`; transcripts quoted above from its output.)

## Ported-test accounting (assertions unchanged in every case)

| Old (jet_cad_floor_plan/test) | New (kit test/) | Change classes |
|---|---|---|
| separator_test SR1, SR2, SR4, SR5 | separator/separator_test.dart, same cases | ids (`'floor_planner.separator'` → `'architecture.separator'`, C7 class 1); imports (catalog.dart dropped, `separator_linetype.dart` added); `RoomInputs(plan.doc, liveOf(plan.doc))` |
| room_trace_test RT1-RT4, RT6-RT9 | room/room_trace_test.dart | imports; `RoomInputs(…, liveOf(…))` |
| room_inputs_test RI1, RI2, RT5 | room/room_inputs_test.dart | imports (`separator.dart` → `separator_linetype.dart`); six `RoomInputs(…, liveOf(…))` |
| room_label_test RL1, RL2, RA1, Q0-RA1 | room/room_label_test.dart | imports; `RoomInputs(…, liveOf(…))` |
| room_localise_test LZ1, LZ2, LZ4 | room/room_localise_test.dart | imports; four `RoomInputs(…, liveOf(…))` |
| room_tie_test DE1 (+ helpers) | room/room_tie_test.dart | lines 1-14, 16-435 + closing `}`; imports; `RoomInputs(…, liveOf(…))`. DE2, DE3 → Task 18 |
| — | room/room_inputs_services_test.dart RR-live, RR-shared (brief, verbatim) and RR-freeze (new, see above) | new |

## Files changed

packages/jet_cad_2d_kit_architecture/:
- lib/jet_cad_2d_kit_architecture.dart, lib/src/type_naming.dart, lib/src/wall/wall.dart (modified)
- lib/src/separator/separator.dart, lib/src/room/room_inputs.dart, lib/src/room/room_trace.dart,
  lib/src/room/room_label.dart (new)
- test/support/catalog.dart (modified), test/support/room_fixture.dart (new)
- test/separator/separator_test.dart, test/room/room_trace_test.dart,
  test/room/room_inputs_test.dart, test/room/room_label_test.dart,
  test/room/room_localise_test.dart, test/room/room_tie_test.dart,
  test/room/room_inputs_services_test.dart (new)

## Deviations

1. **Freeze check added to `RoomInputs`** (beyond the brief's Step 9; asked for by the
   controller's task note): `_held`/`_heldWalls`, `_dropFrozen`, `_dropFrozenAround`, and
   `generation` became a getter body that runs `_dropFrozen()`. Its doc says so. M-RR-1/2/5 still
   apply verbatim.
2. **RR-freeze** added as a third case of `room_inputs_services_test.dart`, with mutations
   M-RR-9 to M-RR-14; landed in a second, test-only commit (`d2c6d9ea`) after the first version
   of RR-freeze left `placedIn`-first and `bounds`-first unpinned (M-RR-9 was red only through
   `generation`). Both commits are this task's.
3. `room_inputs_services_test.dart` imports `package:jet_cad_2d/jet_cad_2d.dart show Aabb2,
   Handle` (RR-freeze's mutable frozen set and box tuples); RR-live / RR-shared are the brief's
   text, only `dart format`ted.
4. Separator header: placed at the top of the file (the file's header) rather than between the
   imports and the class doc ("before line 6's doc comment"); same text.
5. Ported-test "Ported from" line wrapped over two lines (`… (3a Task 16);` / `// assertions
   unchanged.`) to stay within 80 columns, as Task 11's ports do.
6. Commit subject uses the brief's `feat(kit-architecture):` scope; earlier tasks' commits use
   `feat(architecture):`. Left as the brief wrote it.

## Concerns

- Cost: `placedIn`, `bounds` and `generation` now make O(n) `liveTypeIdOf` calls per read (as
  `WallBands` does per read). A Room-tool hover reads `generation` and `bounds`, so two O(n)
  checks per event. Task 19's TT6 timing (printed, not asserted) will show it; if it matters,
  the plan could expose a frozen-set version for an O(1) check.
- `_dropFrozenAround` relies on a freeze only removing objects (no unfreeze in the plan library
  today). An unfreeze path, if ever added, would need a document change or an explicit
  `invalidate()`.

---

# Fix round 1 (review: "Needs fixes", two Important, two Minor)

Commit: `df16d97a` fix(kit-architecture): room inputs reuse liveObjectsOf; pin each freeze check
(on top of d2c6d9ea).

## Changes

1. **Important 1 (controller overrules Step 9):** `RoomInputs._live<T>` deleted; `_refresh` calls
   `liveObjectsOf<WallParams>(doc, live, ArchitectureTypes.wall)` and
   `liveObjectsOf<SeparatorParams>(doc, live, ArchitectureTypes.separator)` (Task 9's `live.dart`).
   `grep -n "_live<\|_live(" lib/src/room/room_inputs.dart` → no match (exit 1).
2. **Important 2:** RR-freeze rewritten so each liveness check has a first-reader step. The plan
   gains two separators outside the box (x 9,000.5 and x 10,000.25; they bound no face, they widen
   the bounds) so every reader can be first once. Step order, one freeze each, no document change:
   `left` → `inputOf(left)`; `partition` → the trace (5,320,950 → 10,830,000 → 23,371,900);
   `right` → `placedIn` (then 29,640,000); `outB` → `bounds` (differential against a fresh
   cache); `outA` → `generation`; `w0` → `inputOf(w1)` (neighbour; differential band);
   **`w2` → `wallNeighboursOf(w2)`, the frozen wall asked for itself** (premise `[w1, w3]`, both
   live); **`w1` → `inputOf(w1)`, the frozen wall asked for itself**; `w3` → `placedIn` (empty),
   then `bounds` null; `stateId` unchanged.
3. **Minor 3:** with nothing frozen, `placedIn`, `bounds`, `inputOf`, `wallNeighboursOf` and
   `generation` are read and `(debugRebuilds, generation)` must be unchanged.
4. **Minor 4:** the class doc now states the read-time re-check (whole cache for `placedIn`,
   `bounds`, `generation`; the handle and its wall neighbours for `inputOf`, `wallNeighboursOf`).

## Mutations (committed files at df16d97a; each reverted with `git checkout --`, then
`git diff --quiet -- <file>` exit 0 for every one; test `test/room/room_inputs_services_test.dart`)

| Mutation | Red line |
|---|---|
| M-RR-1 `liveObjectsOf<WallParams>(doc, live, …wall)` → `doc.components.withComponent<WallParams>()` | `Expected: null  Actual: RoomInput:<RoomInput(22, band, …)>`; `Expected: a numeric value within <0.01> of <23371900>  Actual: <10830000.000003764>` |
| M-RR-2 the separator `liveObjectsOf` → `doc.components.withComponent<SeparatorParams>()` | `Expected: null  Actual: RoomInput:<RoomInput(26, segment, …)>` |
| M-RR-5 (now `lib/src/live.dart`) `if (live(h) == typeId) h,` → `h,` | `Expected: null  Actual: RoomInput:<RoomInput(22, band, …)>` |
| M-RR-9 `_dropFrozen` → `return;` | `Expected: [18, 22, 26, 30, 42, 44]  Actual: [18, 22, 26, 30, 38, 42, 44]` |
| M-RR-10 neighbour loop skipped | `Expected: not RoomInput:<RoomInput(16, band, …)>  Actual: RoomInput:<RoomInput(16, band, …)>` |
| M-RR-11 `_dropFrozenAround` → `return;` | `Expected: null  Actual: RoomInput:<RoomInput(28, segment, …)>` |
| M-RR-12 `generation` without `_dropFrozen()` | `Expected: a value greater than <4>  Actual: <4>` |
| M-RR-13 `placedIn` without `_dropFrozen()` | `Expected: [18, 22, 26, 30, 42, 44]  Actual: [18, 22, 26, 30, 38, 42, 44]` |
| M-RR-14 `bounds` without `_dropFrozen()` | `Expected: not (…4498305.951887848, 1199868.8764018053, 4509009.815413712, 1207129.8663333987)  Actual: (same)` |
| **M-RR-15** delete `if (live(h) != ArchitectureTypes.wall) { invalidate(); return; }` | `Expected: empty  Actual: [22, 30]` (the `wallNeighboursOf(w2)` step) |
| M-RR-15b M-RR-15 plus `wallNeighboursOf` switched to the whole-cache `_dropFrozen()`, to show the `inputOf` self step catches it alone | `Expected: null  Actual: RoomInput:<RoomInput(16, band, …)>` (the `inputOf(w1)` step) |
| M-RR-16 `want` always `ArchitectureTypes.wall` (the `_heldWalls` split) | `Expected: (int, int):<(5, 5)>  Actual: (int, int):<(7, 7)>` |
| M-RR-17 `_dropFrozen` always invalidates (`… != want \|\| true`) | `Expected: (int, int):<(5, 5)>  Actual: (int, int):<(7, 7)>` |

The second commit's message (d2c6d9ea) said that removing any one reader's check turns a test red.
After df16d97a that holds for every check: M-RR-12/13/14 (whole-cache readers), M-RR-10 (neighbour),
M-RR-11/15/15b (self, separator and wall, through both one-handle readers).

## Gates (df16d97a)

- kit `flutter test` → `00:11 +190: All tests passed!`
- `flutter analyze` → `No issues found! (ran in 3.4s)`
- `dart format --output=none --set-exit-if-changed .` → `Formatted 69 files (0 changed)`, exit 0
- `dart pub publish --dry-run` → `Package has 0 warnings.`
- `dart run tool/ci/check_kit_deps.dart` → `kit dependencies: 2 package(s) checked, none names the
  plan library or another kit`, exit 0
- `git status --short` → clean
