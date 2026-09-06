# Task 9 report — mutation testing

## Summary table

| id | verdict |
|---|---|
| M-F1 | KILLED — `pending` null where `tables` expected; `landed` 1 where 2 |
| M-F2 | KILLED — `pending` null where `devicePixelRatio` expected |
| M-F3 | KILLED — `pending` null where `band` expected |
| M-F4 | KILLED — `texts` still contains `'COVERED'`, lacks `'EDITED'` |
| M-F5 | KILLED — `resident_collection_test.dart` (14→0 instances at the corner) and `zoom_defect_test.dart` (926 pixels uncovered). `band_sweep_test.dart` did not additionally fire — see note below |
| M-F6 | KILLED — `schedules` Expected 2, Actual 4 (corrected witness: `schedules`, not `rebuilds`, per the brief-superseding ruling) |
| M-F7 | KILLED — `pending` null and `rebuilds` already 1 before the pump |
| M-F8 | KILLED — a second pending exception where none is expected |
| M-F9 | KILLED — patch count 160 (brute force) vs 75 (grid) |
| M-F10 | EQUIVALENT (Ruling F7-a) — fired, green run recorded |
| M-F10′ | KILLED — patch count 160 (brute force) vs 80 (grid) |
| M-F11 | KILLED — `drawParagraph` count 2→4; 5 of 7 `text_order_test.dart` rows fail |
| M-F12 | KILLED — `identical(onScreen, out)` false |
| M-F13 | KILLED — `rebuilds` 2 where 3 expected |
| M-F14 | KILLED — `identical(written, out)` false |
| E-F1 | EQUIVALENT (spec-declared) — fired, green run recorded |

**14 named mutations plus the replacement witness M-F10′: 14 of 15 killed on
the first shot. Two equivalents (M-F10, E-F1) fired and their green runs
recorded per spec. One secondary witness (`band_sweep_test.dart` under M-F5)
did not additionally fire — investigated and recorded as a coincidental
miss, not a survivor of M-F5 as a whole (killed decisively by its other two
witnesses). Zero true survivors.**

Full log with diffs, commands and verbatim tails:
`/Users/ahmeturel/Projects/oss/jet-cad/.worktrees/plan-f-rebuild-and-band/docs/superpowers/notes/plan-f-mutation-log.md`

## Rows whose edit or witness differed from the brief

All fourteen numbered rows plus M-F10′ and E-F1 matched the brief's/ruling's
edits verbatim once the corrections in my task instructions were applied:

- **M-F6**: fired the corrected edit (delete the `_inFlightTrigger != null ||
  _scheduled` early return in `markDirty`) and asserted against `schedules`,
  not the brief's original `rebuilds` — per the ruling, `schedules` reads 4
  where 2 is expected; `rebuilds` stays 2 because `_run`'s own pending
  re-check absorbs the extra callbacks.
- **M-F10**: fired the plan's original `.floor()` → `.round()` edit in
  `cellX`/`cellY`. Confirmed EQUIVALENT (stays green) exactly as Ruling F7-a
  predicts, and recorded rather than skipped.
- **M-F10′**: fired the replacement witness — `cx1 = cx0;` right after the
  binning loop's `cellX(box[0]), cellX(box[2])` line — which required
  splitting the original `final cx0 = ..., cx1 = ...;` declaration so `cx1`
  could be reassigned (`final cx0 = ...; var cx1 = ...; cx1 = cx0;`). Killed:
  patch count 160 vs 80.
- **M-F5**: ran all three named witnesses. `resident_collection_test.dart`
  and `zoom_defect_test.dart` kill it decisively; `band_sweep_test.dart`
  stayed green. Investigated (not a fix, not a widened mutation) — see
  concerns below.
- **M-F8, M-F11, M-F12, M-F14, E-F1**: file/edit/witness exactly as the
  ruling/brief states; no deviation.

## Investigated non-firing: M-F5's `band_sweep_test.dart` witness

`band_sweep_test.dart` stays green under M-F5's mutation
(`collectionFrameFor` returning `CollectionFrame(live, const Size(800,
600))` unconditionally). Cause: every `sweep()` call in that file passes
`_size = Size(800, 600)` as both the live viewport and (via
`collectionFrameFor`) the collection viewport, and 800×600 is also the
mutation's hardcoded return value — a coincidence of this file's own
constant with the mutant's literal. Every corpus in that file is swept from
its own `ViewportTransform.fit(doc.extents, _size)` camera, so the whole
drawing already sits inside an 800×600 frame at the scale being tested, and
the mutation's dropped margin shift (`kScreenClipInflate`, a few logical
pixels) never crosses criterion 1's tolerance on a fitted corpus. This is the
same class of judgment call `plan-e-mutation-log.md` records for
M-E3/M-E4/M-E6/M-E10 (a named secondary witness that does not additionally
fire, investigated and explained rather than chased with a wider mutation or
an edited test) — the mutation itself is still KILLED, decisively, by the
other two named witnesses.

## Gate commands, output, exit codes

All run from the fully restored tree (`git status --short` clean except the
new log file) after the fifteen mutation rows.

**`packages/jet_cad_2d_flutter`:**

```
$ flutter test
...
00:10 +664 ~1: All tests passed!
EXIT=0

$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.2s)
EXIT=0

$ dart format --output=none --set-exit-if-changed .
Formatted 113 files (0 changed) in 0.16 seconds.
EXIT=0
```

**`packages/jet_cad_2d`:**

```
$ dart test
...
00:02 +798: All tests passed!
EXIT=0

$ dart analyze
Analyzing jet_cad_2d...
No issues found!
EXIT=0

$ dart format --output=none --set-exit-if-changed .
Formatted 113 files (0 changed) in 0.14 seconds.
EXIT=0
```

**`apps/dev_harness_2d`:**

```
$ flutter test --concurrency=1
...
00:15 +82: All tests passed!
EXIT=0

$ flutter analyze
Analyzing dev_harness_2d...
No issues found! (ran in 0.8s)
EXIT=0

$ dart format --output=none --set-exit-if-changed .
Formatted 22 files (0 changed) in 0.03 seconds.
EXIT=0
```

`git status --short` after the final gate run: clean (log file already
committed at that point, `a1ef1fe`).

## Commit

`a1ef1fe` — `test(gpu): Plan F mutation log -- fourteen fired, one declared
equivalent` — the only file: `docs/superpowers/notes/plan-f-mutation-log.md`.
`analysis_options.yaml` was not touched or committed.

## Concerns

None rise to NEEDS_CONTEXT. No mutation survived as a whole — every row
killed or confirmed equivalent per the corrected rulings supplied for this
task. The one item worth flagging for the record (not a plan defect): M-F5's
`band_sweep_test.dart` witness does not independently fire, for the
fixture-size-coincidence reason above; the mutation is still killed
decisively by its other two named witnesses, so this does not change the
row's verdict or require a code/test fix under the task's survivor rule.
