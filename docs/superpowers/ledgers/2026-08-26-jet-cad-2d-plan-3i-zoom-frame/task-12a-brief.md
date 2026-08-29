# Task 12a/13a — the two measurement seams, and the interleaved driver

This is the **code half** of Plan 3i's Tasks 12 and 13. The device half —
actually running the rig and writing the numbers — is blocked on machine power
and is NOT yours. You write code and unit tests. You never run `flutter run`
and you never write a measurement number anywhere.

## Why this task exists (read this, it is the whole point)

Plan 3i's Task 12 scores **criterion 4**: a ratio between two arms, run
**interleaved in one session** — a "rest" arm and a "tiled" arm, where the
tiled arm is *today's behaviour with the rest bake disabled*.

Plan 3i's Task 13 scores **criterion 8**: a ratio between a "narrow" arm and
an "M4" arm, also **interleaved in one session**, at n=9 per arm. M4 is a
source-code mutation (see below). Plan 3h ran those two arms as two separate
binaries, three-then-three; that blocked ordering is exactly the bias Task 13
exists to remove.

Neither arrangement is runnable today, for the same reason: **there is no way
to switch either behaviour at runtime**, and you cannot interleave two
binaries inside one session. If the arms are not actually switched, both arms
run identical code, every ratio reads 1.00, and a degenerate measurement gets
written into a document of record. Building the two switches is your job.

## Global constraints (binding — these are from CLAUDE.md and the plan)

- **Never commit `analysis_options.yaml`.** `flutter pub get` rewrites three
  of them in this workspace. Check `git status` before every `git add`, and
  never use `git add -A` at the repo root.
- **Never synthesize test output.** Paste only transcripts you actually
  produced. A fabricated transcript invalidates the task.
- **Never `git checkout` a file to revert a mutation.** Copy the file aside
  (`cp x x.bak`), mutate, restore with `cp x.bak x`, delete the backup.
  `git checkout` is additionally blocked by a sandbox classifier here.
- **Prefix every test command with `CI=true`** — otherwise Dart's analytics
  phone-home blocks the runner for minutes at ~0% CPU.
- **`package:jet_cad_2d` is pure Dart** — no Flutter, no `dart:ui`, ever.
  **This task does not touch it.**
- In `packages/jet_cad_2d_flutter`, `unused_import` and `unused_element` are
  **ERRORS**, not warnings.
- **No pre-existing golden PNG may be regenerated.**
- **The frame path allocates nothing per entity in steady state, and O(1) per
  flush.** Your new fields must not change that.
- Code and comments in English.

## Part 1 — `TileCache.debugRestBakeDisabled`

**File:** `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`

The rest bake fires at `tile_cache.dart:982-984`:

```dart
    if (_restGateSteps >= kRestGateFrames) {
      _restBake(grid, quantised, viewport, painter, sink, vertices, origin);
    }
```

Add a public mutable field on `TileCache`, defaulting to `false`, and gate
that call on it. Name it `debugRestBakeDisabled`. Put it near the other
debug-named members (`debugRestGateSteps` is at `:613`, `debugSetBand`,
`debugBakeBand`, `debugSliceTile`, `debugOnSliceForTest` are further down —
follow whichever placement convention that file already uses for debug
members).

Its doc comment must say, in substance:

- It exists so **one binary can run both arms of criterion 4's ratio in one
  session, interleaved**. That is the only reason a production field carries a
  measurement switch.
- With it set, the cache falls back to the ordinary budgeted per-tile path —
  which is *today's behaviour before the rest bake landed*, and is precisely
  what criterion 4's denominator arm is defined as.
- It is **not** a correctness switch: pixels stay correct either way; only how
  many frames coverage takes changes.
- Default `false`; no non-debug caller sets it.

## Part 2 — `TileCache.debugFullViewportQuery`

**Same file.** The live-fallback query is at `tile_cache.dart:1074`:

```dart
    final strip = stripFor(uncovered, viewport);
```

M4, as Plan 3h's mutation log defines it (§"M4 — narrow the clip but not the
query", `docs/superpowers/notes/plan-3h-mutation-log.md:524`), is: **keep the
narrow clip, hand the query the full viewport instead of the strip.** The clip
line immediately above (`canvas.clipRect(uncovered, doAntiAlias: false)`) is
NOT touched by M4 and must NOT be touched by your flag.

Add a public mutable field `debugFullViewportQuery`, default `false`, so that
when set the strip becomes the full viewport:

```dart
    final strip = debugFullViewportQuery
        ? Offset.zero & viewport
        : stripFor(uncovered, viewport);
```

Doc comment must say, in substance:

- It reproduces **Plan 3h's M4 mutation at runtime**, and cite it by name so a
  reader can find `plan-3h-mutation-log.md`'s M4 section.
- It exists so criterion 8's two arms can interleave inside one session; Plan
  3h could only run them as two binaries, three-then-three, and that blocked
  ordering is the bias Plan 3i's Task 13 exists to remove.
- **It ships a known defect behind a flag.** Say so plainly. Default `false`;
  no non-debug caller sets it.
- The clip is deliberately left narrow — that is what makes this M4 and not
  M5. (M5 grows the query *and* leaves the clip untouched; see the same log.)

## Part 3 — the tests that prove the switches actually switch

**File:** `packages/jet_cad_2d_flutter/test/tile_regime_test.dart` — or a new
file if that one does not fit; your call, but state which you chose and why.

This is the part that matters. A flag that is read but changes nothing would
make both ratios read 1.00 and nobody would notice. Write, for each flag, a
test that **fails if the flag stops having an effect**, asserting on an
observable counter rather than on the field's own value:

1. **`debugRestBakeDisabled` suppresses the band bake.** Drive a cache to the
   resting regime (the existing fixtures in
   `test/support/tile_fixture.dart` and `test/support/tile_harness.dart`
   already know how — `settleFromBands` in `tile_regime_test.dart` is the
   closest existing example; read it before writing). With the flag off, the
   rest bake fires and slices; with it set, it does not — assert on the slice
   count (`debugOnSliceForTest` is the existing seam) or on band-unit
   `bakeCount`, not on the flag.
2. **`debugFullViewportQuery` grows the walk.** With the flag off, the live
   fallback's walk is strip-sized; with it set, it is viewport-sized. Assert
   on `_lastStrip`'s public accessor if one exists (grep for `lastStrip` —
   `tile_cache.dart:1075` writes `_lastStrip`), otherwise on the triangle or
   draw counts the existing fallback tests use. `test/tile_fallback_test.dart`
   already gates M4 by triangle-count ratio — read that test first, it tells
   you which counter separates the two arms.

**Both tests must be proven by mutation, and you must paste the real
transcripts:**

- **M13:** delete the `debugRestBakeDisabled` check (restore the unconditional
  `if (_restGateSteps >= kRestGateFrames)`). Test 1 must go RED.
- **M14:** replace the ternary with the unconditional
  `stripFor(uncovered, viewport)`. Test 2 must go RED.

Restore by `cp` from a backup, never `git checkout`. Record both mutations in
`docs/superpowers/notes/plan-3i-mutation-log.md`, following the format the
existing M1–M12 sections use exactly (read two of them first).

## Part 4 — `runInterleaved`

**File:** `apps/dev_harness_2d/lib/measurement_rig.dart`

Plan 3i's Task 12 pins this signature and it is not yours to change:

```dart
Future<void> runInterleaved({
  required int arms,
  required Future<void> Function() rest,
  required Future<void> Function() tiled,
})
```

Semantics, from the plan: **the interleaved unit is one whole arm, not one
frame.** It runs `rest`, then `tiled`, then `rest`, then `tiled`, … for
`arms` repeats of each — never all rests then all tileds. It awaits each
callback before starting the next. It reports nothing itself; the callbacks
own their own printing.

Give it a doc comment saying why the interleaving exists: session drift and
thermal drift land on both arms instead of concentrating on whichever ran
last, which is the bias Plan 3h's `docs/superpowers/notes/2026-08-25-plan-3h-results.md`
recorded in its own numbers (its M4 arm ran last, in a visibly noisier
session, on a phase M4 is inert on).

**Test it** in `apps/dev_harness_2d/test/` (new file; `zoom_script_test.dart`
shows the house style for a pure-Dart rig test). At minimum: the call order
for `arms: 3` is exactly `rest, tiled, rest, tiled, rest, tiled`, and
`arms: 0` calls neither. Record the order into a list from the callbacks and
assert the list.

**Do NOT wire `runInterleaved` into `main.dart` in this task.** The two arms'
bodies belong to the device half, which is blocked; wiring a driver whose arm
bodies do not exist yet would land untested code on the run path. Say in your
report that the wiring is deliberately left to the device half.

## The gate — run all of it, paste all of it

Every one of these must be green before you commit, and your report must carry
the real tail of each:

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && dart format --output=none --set-exit-if-changed .
cd apps/dev_harness_2d && CI=true flutter test && CI=true flutter analyze && dart format --output=none --set-exit-if-changed .
cd packages/jet_cad_2d && CI=true dart test && CI=true dart analyze && dart format --output=none --set-exit-if-changed .
```

Note: bare `flutter test` under default concurrency silently under-reports
which test *names* ran in `dev_harness_2d`; pass counts are correct. Use
`--concurrency=1` when the named files matter.

Baselines at HEAD `0cca785`, so you can tell a regression from a pre-existing
state: **797** tests in `jet_cad_2d`, **400** in `jet_cad_2d_flutter` with
**1 skip**, **20** in `dev_harness_2d`. Analyze and format clean in all three.

## Commits

Two commits, in this order, or one if you prefer — your call, but each commit
must be green on its own:

```
feat(tiles): runtime seams for criterion 4's and criterion 8's interleaved arms
test(harness): runInterleaved alternates whole arms, never blocks them
```

Never `git add -A` at the repo root. Stage named paths only.
