# Plan 04 — final fix wave: report

Branch `plan-04/page-grid-rulers`, worktree
`.claude/worktrees/plan-04-page-grid-rulers`. From HEAD `1618111` to
`e6537dd`, in two commits.

| | commit | subject |
|---|---|---|
| code (A1–A9) | `1fe1fcc` | `fix(engine,render): components ranks lowest so mixed compounds reconcile; three tests made real; ladders immutable` |
| docs (B1–B5) | `e6537dd` | `docs: Plan 04 final fix wave — results, spec, STATUS, README` |

`git log -1 --format=%B \| grep -c "Fable 5.1"` printed `1` on each.
`git status --short` was empty after each. No `analysis_options.yaml` was
rewritten at any point, so none needed restoring; `flutter pub get` ran
several times (inside the `flutter test` lines) and rewrote nothing.

---

## A — code

### A1 (Critical, Ruling 04-19) — `components` ranks lowest

- `packages/jet_cad_2d/lib/src/document/command.dart:11-36` — the enum is
  reordered to `{ components, transform, geometry, structure }` and gains a
  paragraph saying the declaration order **is** a ranking, that a compound's
  summary is `components` only when every member is, and that nothing
  serialises the ordinal.
- `packages/jet_cad_2d/test/index/component_edit_skip_test.dart:93-120` —
  new test **"a compound with a transform member and a page edit still
  reconciles"**: a group node added off the identity
  (`Transform2.translation(310, -47)`), then a `CompoundCommand` of
  `TransformNodeCommand(group, Transform2.translation(880, -412))` and
  `SetComponentCommand<PageComponent>(root, PageComponent(originX: 7350,
  originY: -1230))`, asserting `index.rebuildCount` grows.
- `packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart:228-252` —
  the twin, **"a transform change still invalidates"**, next to "a
  components-only change drops no tile": a `CommandApplied(…, capability:
  Capability.transform)` over the instanced fixture, asserting
  `liveTileCount` drops **and** `invalidationCount` grows (the neighbouring
  components test asserts both are unchanged, so this mirrors it in the
  opposite direction).

**Ordinal grep, as asked.** `grep -rEn "Capability" --include="*.dart"
packages/ apps/ | grep -E "\.values|\.index"` returns exactly one hit:
`packages/jet_cad_2d/test/document/command_test.dart:124`, a
`for (final c in Capability.values)` loop over `DraftPermissions.all` /
`readOnly` that is order-independent. `DraftPermissions` switches by name.
`CompoundCommand.capability`'s `child.capability.index > highest.index` is
the only `.index` read, and it is the ranking itself. **Nothing serialises
the ordinal**, so the reorder is behaviour-free apart from the fix.

`compound_command_test.dart` needed **no** change: its summary test asserts
`structure` for `[transform, geometry, structure]`, and `structure` is still
last. Confirmed by the engine gate line being green.

#### TDD evidence — A1

RED (the test written, the enum not yet reordered):

```
$ cd packages/jet_cad_2d && CI=true dart test test/index/component_edit_skip_test.dart \
    -n "a compound with a transform member and a page edit still reconciles"
00:00 +0: loading test/index/component_edit_skip_test.dart
00:00 +0: a compound with a transform member and a page edit still reconciles
00:00 +0 -1: a compound with a transform member and a page edit still reconciles [E]
  Expected: a value greater than <1>
    Actual: <1>
     Which: is not a value greater than <1>

  package:matcher                                 expect
  test/index/component_edit_skip_test.dart 119:5  main.<fn>

00:00 +0 -1: Some tests failed.

Failing tests:
  test/index/component_edit_skip_test.dart: a compound with a transform member and a page edit still reconciles
```

GREEN (after the enum reorder):

```
$ cd packages/jet_cad_2d && CI=true dart test test/index/component_edit_skip_test.dart \
    -n "a compound with a transform member and a page edit still reconciles"
00:00 +0: loading test/index/component_edit_skip_test.dart
00:00 +0: a compound with a transform member and a page edit still reconciles
00:00 +1: All tests passed!
```

**The tile-cache twin was green when written**, and that is expected: the
D13 skip compares `capability == Capability.components`, so a change already
carrying `transform` never skipped regardless of enum order. It is a
narrowness guard on the skip, not the enum-order killer — the enum-order
mutant (M-04w) is killed by the engine test above, exactly as the brief
says. Recorded here rather than presented as a red-then-green.

### A2 (Important) — the circular ruler-frame assertion

`packages/jet_cad_2d_flutter/test/ruler_frame_test.dart:74-107`. The old
third test inverted the camera on the tick it was checking and re-applied
it, so it asserted only that the camera is invertible. Replaced, and renamed
to **"the sheet corner's major tick sits at its screen x in the top bar"**:

- `topBar.left == child.left` and `topBar.width == child.width` from
  `tester.getRect`, so a screen x means the same thing in both;
- the independent world point is the fixture's own sheet corner,
  `Vector2(7350, 0)` → `camera.worldToScreen(...).x`, asserted
  `closeTo(395.45, 1e-9)` as a fixture guard and `inInclusiveRange(0,
  child.width)` so the tick is inside the 400 px bar;
- `painter.debugLastTicks` must contain a major within `1e-6` of that x
  (page x = 0 is a major), with the whole major list in the failure reason.

**Deviation, stated.** The brief's part (c) says to assert `topBar.left +
tickX == child.left + tickX`, notes that it is trivially true, and asks for
`topBar.left == child.left` plus "the tick x lies in `[0, child.width]`"
instead. I did the latter, which is what the brief itself settles on; the
trivial identity is not asserted.

### A3 (Important) — the two vacuous page-notifier assertions

`packages/jet_cad_2d_flutter/test/page_notifier_test.dart:53-95` ("a load
re-reads, and dispose stops listening").

Load branch, now real: after the edit, `doc.components.attach<PageComponent>(
doc.rootHandle, standardPage().copyWith(pageBreaks: true))` out of band (no
command, no event); `n.value!.pageBreaks` is asserted **still false**; then
`doc.commands.notifyLoaded()`, a `Duration.zero` await, and
`n.value!.pageBreaks` is asserted **true** — plus `gridVisible` flipping
back to true, so the assertion is about the whole component being re-read
rather than one field.

Dispose branch, now real: `final atDispose = n.value;` is read **before**
`n.dispose()`, then a `SetComponentCommand` with `scaleDenominator: 20` is
executed, a microtask awaited, and `n.value` asserted equal to `atDispose`.
A fixture guard asserts the registry really holds `20`, so an unchanged
notifier means it stopped listening rather than that nothing happened.

**Which observable I used, as the brief asks to state.** The notifier's own
field, compared before and after — the brief's first choice. I confirmed the
fallback is also available but did not need it: under the mutant that removes
`_subscription.cancel()`, `ValueNotifier.value=` sets `_value` *and then*
`notifyListeners()` throws "A PageNotifier was used after being disposed",
so both the field comparison and an exception out of the stream callback
fire. The field comparison is the one asserted.

#### TDD evidence — A3

The A3 item is a **vacuity** fix: there is no production defect behind it, so
the rewritten test is green against correct code. RED is therefore shown
against the two mutants the old test survived and the new one kills, under
the `cp` / one edit / named test / `cp` restore / `diff -q` discipline. Both
mutants were backed up to `/tmp/claude-501/pn.bak` and restored from it; no
`git checkout --` touched a `.dart`.

**Mutant 1** — `page_notifier.dart:26`, `DocumentLoaded() ||
DocumentPurged() => true` → `=> false`:

```
$ CI=true flutter test test/page_notifier_test.dart
00:00 +3: a load re-reads, and dispose stops listening
00:00 +3 -1: a load re-reads, and dispose stops listening [E]
  Expected: true
    Actual: <false>
  the load arm re-reads the registry rather than trusting the value it already holds

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/page_notifier_test.dart 72:5                   main.<fn>

00:00 +3 -1: Some tests failed.
```
EXIT: 1. Restored: `diff -q` clean.

**Mutant 2** — `page_notifier.dart:33`, `unawaited(_subscription.cancel());`
removed:

```
$ CI=true flutter test test/page_notifier_test.dart
00:00 +3 -1: a load re-reads, and dispose stops listening [E]
  A PageNotifier was used after being disposed.
  Once you have called dispose() on a PageNotifier, it can no longer be used.
  package:flutter/src/foundation/change_notifier.dart 184:9   ChangeNotifier.debugAssertNotDisposed.<fn>
  ...
  package:jet_cad_2d_flutter/src/page_notifier.dart 28:18     PageNotifier._onChange
  ===== asynchronous gap ===========================
  dart:async                                                  _StreamImpl.listen
  package:jet_cad_2d_flutter/src/page_notifier.dart 13:38     new PageNotifier
  test/page_notifier_test.dart 55:15                          main.<fn>

  Expected: PageComponent:<PageComponent(A4 landscape 1:50.0 at (7350.0, -1230.0), meters)>
    Actual: PageComponent:<PageComponent(A4 landscape 1:20.0 at (7350.0, -1230.0), meters)>
  a disposed notifier follows nothing
```
EXIT: 1. Restored: `diff -q` clean.

GREEN, after both restores:

```
$ CI=true flutter test test/page_notifier_test.dart
00:00 +0: seeds from the document before any event
00:00 +1: follows apply, undo and redo through the stream
00:00 +2: an unrelated edit and an equal value do not notify
00:00 +3: a load re-reads, and dispose stops listening
00:00 +4: All tests passed!
```
EXIT: 0. (Four tests at this point; A7 added a fifth afterwards.)

The old test survived both mutants: its load assertion checked
`gridVisible == false`, which the edit before `notifyLoaded` had already
set, and its dispose assertion was `returnsNormally` on the *execute*, which
says nothing about a notifier.

### A4 (Important) — M-04i's false claim in `ruler_painter_test.dart`

`packages/jet_cad_2d_flutter/test/ruler_painter_test.dart:26-31` — the
comment no longer claims M-04i; it now says why the loop cannot kill it (the
label expectation calls `formatLength`, the function a unit mutant would
change, so it moves with the mutant) and names `grid_scale_test.dart` as the
kill site. `:38-43` adds the one literal: the major whose page x rounds to
`500` must be labelled `'0.5 m'`, with the whole label list in the failure
message if no such major exists.

### A5 (Important) — two stale doc comments

- `packages/jet_cad_2d/lib/src/document/commands.dart:725-729` —
  `CompoundCommand`'s class doc: "`[capability]` … is informational only" is
  replaced by "…summarises it as the highest-ranked member, and is what
  `SpatialIndex` and `TileCache` read to skip a components-only compound
  (spec D13); it is `components` only when every member is, which is why
  `Capability.components` is declared first (A1, Ruling 04-19)."
- `packages/jet_cad_2d/lib/src/index/spatial_index.dart:2587-2592` —
  `_onChange`'s "re-derive and compare" doc gains the sentence the brief
  gives, that since Plan 04 the change does say one thing about itself, and
  that the re-derive rule applies to every other kind.

### A6 (upgraded from deferred) — the ladders are unmodifiable

`packages/jet_cad_2d/lib/src/geometry/grid_scale.dart:31-77`.
`_metricLadder` and `_imperialLadder` are wrapped in `List.unmodifiable`,
and `ladderFor`'s floored list is too, so a caller cannot tell the cached
ladders from the floored one by whether it may be written. Both statics
carry a line saying why.

Test: `packages/jet_cad_2d/test/geometry/grid_scale_test.dart:87-93`, **"the
ladder is not writable by its callers"** — exactly the assertion the brief
gives.

#### TDD evidence — A6

RED (test written, `List.unmodifiable` not yet applied):

```
$ cd packages/jet_cad_2d && CI=true dart test test/geometry/grid_scale_test.dart \
    -n "the ladder is not writable by its callers"
00:00 +0: loading test/geometry/grid_scale_test.dart
00:00 +0: the ladder is not writable by its callers
00:00 +0 -1: the ladder is not writable by its callers [E]
  Expected: throws <Instance of 'UnsupportedError'>
    Actual: <Closure: () => double>
     Which: returned <0.0>

  package:matcher                          expect
  test/geometry/grid_scale_test.dart 91:5  main.<fn>

00:00 +0 -1: Some tests failed.

Failing tests:
  test/geometry/grid_scale_test.dart: the ladder is not writable by its callers
```
EXIT: 1.

GREEN (whole file, so the ladder's other users are covered too):

```
$ cd packages/jet_cad_2d && CI=true dart test test/geometry/grid_scale_test.dart
00:00 +0: pick metric: the smallest ladder step at or above 64 px
00:00 +1: pick a mantissa-2 major divides by 4
00:00 +2: pick minor is null under the minor threshold
00:00 +3: pick imperial ladder in inches and feet
00:00 +4: pick imperial divisor is 4 even with a floor
00:00 +5: pick null past the top of the ladder, and for a bad scale
00:00 +6: pick a floor is exact when it fits and the ladder climbs from it
00:00 +7: pick the ladders are ascending and the metric one is 1-2-5
00:00 +8: the ladder is not writable by its callers
00:00 +9: formatLength per unit
00:00 +10: snapToGrid nearest, anchored at the sheet origin, negative side too
00:00 +11: snapToGrid an adaptive step lands on the drawn lattice
00:00 +12: snapToGrid refuses a non-positive step
00:00 +13: All tests passed!
```
EXIT: 0.

### A7 (Minor, taken) — an empty `touched` is "everything changed"

`packages/jet_cad_2d_flutter/lib/src/page_notifier.dart:21-27` — the three
command arms become `touched.isEmpty || touched.contains(root)`, with a
comment citing `doc_change.dart:11-12` and the two consumers that already
read it that way.

Test: `packages/jet_cad_2d_flutter/test/page_notifier_test.dart:9-28` adds a
`DraftCommand` subclass in the test file (the brief's `CounterCommand`
shape), `WholeDocumentCommand`, whose `apply` returns `touched: const {}`;
`:53-72` is the test **"an empty touched set means the whole document
changed"** — a page attached out of band, asserted invisible to the
notifier, then the empty-`touched` command executed and the notifier
asserted to have re-read.

#### TDD evidence — A7

RED:

```
$ CI=true flutter test test/page_notifier_test.dart \
    --plain-name "an empty touched set means the whole document changed"
00:00 +0: an empty touched set means the whole document changed
00:00 +0 -1: an empty touched set means the whole document changed [E]
  Expected: true
    Actual: <false>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/page_notifier_test.dart 93:5                   main.<fn>

00:00 +0 -1: Some tests failed.

Failing tests:
  .../test/page_notifier_test.dart: an empty touched set means the whole document changed
```
EXIT: 1.

GREEN (whole file):

```
$ CI=true flutter test test/page_notifier_test.dart
00:00 +0: seeds from the document before any event
00:00 +1: follows apply, undo and redo through the stream
00:00 +2: an unrelated edit and an equal value do not notify
00:00 +3: an empty touched set means the whole document changed
00:00 +4: a load re-reads, and dispose stops listening
00:00 +5: All tests passed!
```
EXIT: 0.

### A8 (Minor, taken) — why the D13 skip sits after `_dropCarryOver()`

`packages/jet_cad_2d_flutter/lib/src/tile_cache.dart:1875-1882` — the
comment above the skip now says the placement is deliberate: the carry-over
is a composite re-bake of what is already on screen, not a tile, so dropping
it costs a composite and no cached pixels, and keeping it across an edit the
cache declines to look at is the one way a components-only edit could still
show stale pixels.

### A9 (Minor, taken)

- `apps/floor_planner/test/planner_shell_test.dart:93` — "the three chrome
  slots are laid out and empty" → **"the three chrome slots are laid out"**.
- `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart:54-55` — the
  `ruler_frame.dart` / `ruler_painter.dart` export lines are swapped so the
  block is alphabetical.

---

## The four gate lines, after the code commit

Run from each directory on the tree `1fe1fcc` leaves behind. Pasted as
printed, with the exit code.

**`packages/jet_cad_2d`** — `CI=true dart test`:
```
00:04 +862: All tests passed!
```
Exit 0. `dart analyze`: `Analyzing jet_cad_2d... No issues found!` Exit 0.
`dart format --output=none --set-exit-if-changed .`: `Formatted 125 files (0
changed) in 0.29 seconds.` Exit 0.

**`packages/jet_cad_2d_flutter`** — `CI=true flutter test`:
```
00:30 +797 ~1 -5: Some tests failed.

Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```
Exit 1 — **797 pass, 1 pre-existing skip, and exactly the five pre-existing
`text_ladder_golden_test.dart` rungs and nothing else**, as the constraints
say it must. `flutter analyze`: `Analyzing jet_cad_2d_flutter... No issues
found! (ran in 3.2s)` Exit 0. `dart format --output=none
--set-exit-if-changed .`: `Formatted 148 files (0 changed) in 0.37 seconds.`
Exit 0.

**`apps/dev_harness_2d`** — `CI=true flutter test --concurrency=1`:
```
00:29 +82: All tests passed!
```
Exit 0 — **82**, the branch-point count, the harness untouched.
`flutter analyze`: `Analyzing dev_harness_2d... No issues found! (ran in
1.7s)` Exit 0. `dart format --output=none --set-exit-if-changed .`:
`Formatted 22 files (0 changed) in 0.08 seconds.` Exit 0.

**`apps/floor_planner`** — `CI=true flutter test`:
```
00:03 +21: All tests passed!
```
Exit 0. `flutter analyze`: `Analyzing floor_planner... No issues found! (ran
in 1.3s)` Exit 0. `dart format --output=none --set-exit-if-changed .`:
`Formatted 7 files (0 changed) in 0.04 seconds.` Exit 0.
`flutter build macos --release`:
```
Building macOS application...
✓ Built build/macos/Build/Products/Release/floor_planner.app (51.0MB)
```
Exit 0. `flutter build web --release`:
```
Compiling lib/main.dart for the Web...                             24.7s
✓ Built build/web
```
Exit 0.

Counts moved exactly as the items predict: engine 860 → **862** (A1, A6),
render layer 795 → **797** (A1's twin, A7); A2, A3 and A4 rewrote existing
tests and added none; the two apps are unchanged (A9 renamed one
`floor_planner` test).

The docs commit moved no test file — its diff is five markdown files — so
the gate lines were not re-run after it.

---

## M-04w (B4)

Fired on the tree at `1fe1fcc`, under the required discipline.

- backup: `cp packages/jet_cad_2d/lib/src/document/command.dart
  /tmp/claude-501/cmd.bak`
- edit: one — the enum's first two members swapped back, `{ components,
  transform, geometry, structure }` → `{ transform, components, geometry,
  structure }` (`command.dart:24-29`)
- test: `CI=true dart test test/index/component_edit_skip_test.dart`
- result: **FIRED** — `a compound with a transform member and a page edit
  still reconciles` [E], `Expected: a value greater than <1> / Actual: <1>`,
  `00:00 +4 -1: Some tests failed.`, EXIT 1. The three older tests in the
  file stayed green, so the mutant is separable.
- restore: `cp /tmp/claude-501/cmd.bak packages/jet_cad_2d/lib/src/document/command.dart`,
  then `diff -q` — clean; `git status --short` — empty.
- no `git checkout --` was used on any `.dart` file at any point in this
  task.

Logged at `docs/superpowers/notes/plan-04-mutation-log.md` between the
tile-cache twin and the Tally, with the head count and the Tally moved to
**24 fired, 0 survived**.

---

## B — docs (commit `e6537dd`)

**B1** `docs/superpowers/specs/2026-09-22-page-grid-rulers-design.md`:
D13 gains an `**Amended at execution (Plan 04, 2026-09-22, Ruling
04-19):**` paragraph carrying the enum order, why the decision's own
sentence was false of the code, and the restated rule verbatim — "a compound
reconciles when any member is not `components`; the summary capability
carries that because `components` is declared first". D8's buffer sentence
becomes "reused across frames, grown as needed and never shrunk", the
amendment block's "grown once to the sum of both bounds" loses "once", and a
fourth numbered amendment records finding #10 explicitly.

**B2** `docs/superpowers/notes/2026-09-22-plan-04-results.md`: the header
gains the fix wave in Plan 02's shape; "The four gate lines, pasted" is
re-titled **"Re-run in full after the final fix wave"** and every summary
line and exit code above is pasted into it, with a paragraph explaining
which item moved which count; the mutation summary goes to 23 named + twin =
**24 fired** with an M-04w paragraph; criterion 7's witness gains both new
tests, criterion 8's "860 / 795" becomes "862 / 797", criterion 14 goes to
24 and criterion 15 to the new counts; the debt section marks the mutable
ladders **taken** and gains a new block, "Left open by the final fix wave,
with the reason each was not taken", covering #9, #10, #11, #13, #14 plus
the `registerComponents` / `get<PageComponent>(root)!` item and the
`OutlineCache._onChange` item, both in the brief's words; the rulings list
gains **04-19** at the top; "Spec amendments" records D8's fourth and D13's;
"Files this task touched" now separates Task 12 from the wave.

**B3** `STATUS.md`: the header's "Last updated" paragraph (the wave, both
SHAs, 24 mutants, and one sentence naming the defect); the Plan 04 section's
intro (Task 12 at `1618111`, the wave on top), its spec-amendment count
(seven → nine), its mutation-log line (23 → 24), a **final fix wave** row at
the end of the task table in Plan 02's exact shape, "Five rulings" → "Six
rulings" with 04-19 written first, the debt pointer, every row of the "What
Plan 04 measured" table, and the Resume paragraph.

**B4** as above.

**B5** `roadmap/00-README.md:265` — "**01 has a spec as of 2026-09-21**; the
other twelve have not started" → "**01, 02 and 04 are executed (02
merged)**; the other ten have not started". Checked against STATUS's own
sentence, `STATUS.md:1300`, which already says "The other ten sub-projects
have not started" — they now agree. The 04 row of the execution-status table
and `roadmap/04-page-grid-rulers.md:3-5`'s status line both carry the new
head.

---

## Deviations

1. **A1's tile-cache twin was green on first run, not red.** The D13 skip
   tests `capability == Capability.components`, so a change already carrying
   `transform` never skipped, whatever the enum order. It is a narrowness
   guard; the enum-order mutant is killed by the engine test, which is what
   the brief nominates for M-04w. Nothing was skipped — the test the brief
   asks for exists and asserts both `liveTileCount` dropping and
   `invalidationCount` growing.

2. **A3's RED is against two mutants, not against production code.** A3 is a
   vacuity fix with no defect behind it, so the rewritten test is green
   against a correct notifier. The honest analogue of "see it red" is the
   pair of mutants the old test survived and the new one kills; both are
   pasted above and both were restored by `cp` with a clean `diff -q`. They
   are not added to the mutation log, which the brief scopes to M-04w alone.

3. **A2 part (c)**: the brief notes its own `topBar.left + tickX ==
   child.left + tickX` is trivially true and substitutes `topBar.left ==
   child.left` plus a range check. I did the substitute only.

4. **A3's `PageScale` does not exist.** The brief's dispose branch needed
   "a different value"; `PageComponent` has `scaleDenominator`, not a
   `PageScale` enum, so the edit is `copyWith(scaleDenominator: 20)` (1:50 →
   1:20, off the fixture's default either way).

5. **The roadmap and `roadmap/04` status lines name `1fe1fcc` + "the docs
   commit"** rather than a single SHA, since the docs commit's own hash is
   not knowable while writing it. This is the shape STATUS uses for Plan
   02's wave (`0d69465` + this commit).

Nothing else in the brief was skipped, and nothing outside it was touched.
