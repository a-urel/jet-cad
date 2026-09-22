# Final fix wave — Plan 02: report

Base `b02410a`. Two commits, both trailed
`Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`:

- **`0d69465`** — code, items A1–A7.
- **`7cd3697`** — docs, items B1–B8.

No mutation sweep was run, as the brief directs. Every test command below ran
with `CI=true`. `git status --short` after every one of them showed only the
wave's own source files; **no `analysis_options.yaml` was rewritten at any
point**, so nothing needed restoring.

---

## A — code

### A1 — the picking filter in the tool's group every-rule

`packages/jet_cad_2d_flutter/lib/src/select_tool.dart`. `_bandKeys` now builds
one `FilterEvaluator(doc)` per band release (lazily, beside `byOwner`) and
hands it to `_everyLeafIn`, which does
`if (!f.acceptsEntity(slot, const QueryFilter.picking())) continue;` **before**
`any = true`. A rejected leaf — hidden, or on a locked layer — is therefore
skipped rather than failed on, matching `_bandDescend`; a group whose leaves
are all rejected has no members and is not selected.

`FilterEvaluator` needed **no new export**: `packages/jet_cad_2d/lib/jet_cad_2d.dart`
line 49 already exports `src/index/query_filter.dart` whole, which is where
both `QueryFilter` and `FilterEvaluator` live. Nothing was added there.

**Covering test** — `packages/jet_cad_2d_flutter/test/select_tool_test.dart`:
`'a leaf the picking filter rejects is skipped by the group every-rule'`. One
group at `translation(500, 300)` under a camera at scale 2 with a non-zero
translation; first leaf inside the window band, second leaf outside it. Run
twice off one fixture builder: with the second leaf on a **locked** layer the
group is selected; with the same leaf on a visible, unlocked named layer it is
not. `addLayer` (new in `test/support/selection_fixture.dart`) gives the layer
a non-default colour and lineweight, and `addEntity` gained an optional
`layer:` parameter.

**Command**: `CI=true flutter test test/select_tool_test.dart` in
`packages/jet_cad_2d_flutter`.

Red first:

```
00:00 +8 -1: a leaf the picking filter rejects is skipped by the group every-rule [E]
  Expected: [SelectionKey:SelectionKey( 12)]
    Actual: []
     Which: at location [0] is [] which shorter than expected
  the locked leaf is not a member the every-rule can fail on
```

Green after:

```
00:00 +8: a leaf the picking filter rejects is skipped by the group every-rule
00:00 +19: All tests passed!
```

### A2 — the rendering filter in the outline

`packages/jet_cad_2d_flutter/lib/src/outline_cache.dart`. A `FilterEvaluator?
_filters` field is built once per walk and dropped with it, beside `_byOwner`
(a layer record or a node's visibility may have changed since the last walk,
and the evaluator memoises both). `_addLeaf` returns early on
`!filters.acceptsEntity(slot, const QueryFilter.rendering())`.

It sits in `_addLeaf` rather than in `_addContainer` so the one rule covers
the container walk **and** a directly-selected leaf — a superset of the
ruling, and the only place the decision needs to be written once. `rendering()`
drops a hidden leaf and keeps a locked one, exactly as the canvas does.

**Covering test** — `packages/jet_cad_2d_flutter/test/outline_cache_test.dart`:
`'a leaf the rendering filter rejects is left out of the outline'`. A group at
`translation(-17, 23) ∘ rotation(-π/5)` with three leaves: one on layer zero,
one on a **hidden** layer, one on a **locked** layer. The recorded segments are
eight doubles — the visible leaf and the locked one, in owner order — each
compared against the group's own accumulated transform, and the hidden leaf's
world x is asserted more than one unit from every recorded x so its absence
cannot be a rounding accident.

**Command**: `CI=true flutter test test/outline_cache_test.dart`.

Red first:

```
00:00 +5 -1: a leaf the rendering filter rejects is left out of the outline [E]
  Expected: <8>
    Actual: <12>
  the visible leaf and the locked one, not the hidden one
```

Green after:

```
00:00 +5: a leaf the rendering filter rejects is left out of the outline
00:00 +11: All tests passed!
```

### A3 — both band corners converted at release

`select_tool.dart`. `_bandKeys` now takes its first corner from
`ctx.camera.value.screenToWorld(Vector2(_start.dx, _start.dy))` and its second
from the up event's world. The `Vector2 _startWorld` field became dead and was
**removed**, along with the `setFrom` in `onPointerDown`.

**Covering test** — `select_tool_test.dart`:
`'both band corners are converted at release, not at press'`. Press at screen
(372, 340), move past the slop to (420, 260) — window — then
`camera.zoomAt(const Offset(100, 500), 2.0)`, then release. The camera's scale
is asserted to have really moved (2 → 4) and both post-zoom world corners are
asserted before the release ((418, 240) and (430, 260)). The fixture carries
two lines: one inside the release-time band and outside the press-time one,
one exactly the other way round, so the two rules select **disjoint** sets.

Red first — and the red is the wrong entity, not an empty set:

```
00:00 +8 -2: both band corners are converted at release, not at press [E]
  Expected: [SelectionKey:SelectionKey( 12)]
    Actual: [SelectionKey:SelectionKey( 13)]
     Which: at location [0] is SelectionKey:<SelectionKey( 13)> instead of SelectionKey:<SelectionKey( 12)>
  the band is the world box of both screen corners under the camera at release
```

Green after: `00:00 +9: both band corners are converted at release, not at press`,
file green at `+19`.

### A4 — `OutlineCache` is a `ChangeNotifier` in the repaint merge

`outline_cache.dart`: `class OutlineCache extends ChangeNotifier`, with
`notifyListeners()` at the end of `_onChange` — after a rebuild **and** after
the load/purge clear — and **nothing** on the selection-driven path
(`_onSelection`), because the selection controller has already notified the
same merge. `dispose()` is now `@override` and ends with `super.dispose()`;
the order of the rest of it, and of every caller's own dispose, is unchanged.

Added to three repaint merges:

- `apps/floor_planner/lib/planner_view.dart` — `_repaint`.
- `packages/jet_cad_2d_flutter/test/support/selection_fixture.dart` —
  `pumpInteraction`'s painter.
- `packages/jet_cad_2d_flutter/test/selection_overlay_test.dart` —
  `Rig.overlay`.

**Covering test** — `selection_overlay_test.dart`:
`'a DocChange under a selected instance repaints the overlay'`. An instance at
`kPlacement` is selected, a `SetEntityGeometryCommand` edits a leaf **inside
its definition**, then `await tester.idle(); await tester.pump();` (the
document's change stream delivers on a microtask; an awaited
`Future.delayed(Duration.zero)` deadlocks inside `testWidgets`' fake-async
zone — that was measured, the first draft of this test hung). The overlay's
paint count is +1 **and the canvas's is also +1**, which is what distinguishes
it from M-02e′, where only the overlay moves. The test also asserts the
outline the repaint carried is the new one (the moved endpoint, more than a
unit from the old). No widget rebuild happens between the mutation and the
assertion.

**Command**: `CI=true flutter test test/selection_overlay_test.dart`.

Red first:

```
Expected: <3>
  Actual: <2>
the cache notified, so the overlay repainted
```

Green after:

```
00:00 +1: a DocChange under a selected instance repaints the overlay
00:00 +12: All tests passed!
```

### A5 — undo in the shell

`apps/floor_planner/lib/main.dart`. The `Scaffold` body is wrapped in a
`CallbackShortcuts` binding `SingleActivator(LogicalKeyboardKey.keyZ, meta: true)`
and its `control: true` twin to `_undo()`, which is
`if (_document.commands.canUndo) _document.commands.undo();`. It sits above the
`InteractionLayer`'s `Focus`, whose `onKeyEvent` returns the active tool's own
`KeyEventResult` — the tool ignores Z, so the event bubbles up to the binding.
**No redo.**

**Covering test** — `apps/floor_planner/test/planner_shell_test.dart`:
`'cmd+Z undoes a Delete through the command log'`. Tap a wall in the running
shell, Delete (down+up), assert the entity is gone, send meta-left down /
keyZ down / keyZ up / meta-left up, assert the entity is back and the
selection still empty.

One premise of the brief's sketch measured false and is recorded here: the
**startup plan is itself built through the command log**, so `canUndo` is
already true before the Delete. The test therefore pins the undo to exactly
one command with `entities.liveCount` — `liveBefore`, then `liveBefore - 1`
after Delete, then `liveBefore` again after cmd+Z — rather than asserting an
empty log.

Because the binding and the test landed together, the test's discrimination
was established by a **named mutation** instead of a first red run: the two
`SingleActivator` bindings were deleted from `main.dart`, the file re-run, and
the test went red exactly where it should:

```
Expected: not null
  Actual: <null>
the wall is back
```

The bindings were then restored (`main.dart` byte-identical to before the
mutation) and the file re-run green:

```
00:00 +11: .../planner_shell_test.dart: cmd+Z undoes a Delete through the command log
00:00 +12: All tests passed!
```

### A6 — `worldPointOf`'s doc

`outline_cache.dart`. The sentence that told the caller to subtract `origin`
is now: *"The value is an absolute world position; map it to screen with
`worldToScreen` (or rebase it) before it reaches `dart:ui`"* — which is what
the one caller, `_drawPointCross`, actually does. Doc only, no covering test.

### A7 — the stale `byOwner` slot in the delete cascade

`select_tool.dart`, `_groupCascade`'s leaf loop, one line plus its comment:
`if (doc.entities.slotOf(h) == null) continue;`. `byOwner` is scanned once per
Delete while the keys execute one after another, so a later key's cascade can
meet a slot an earlier one already removed and compacted over. Carried by the
existing cascade tests, which stayed green.

---

## B — docs

### B1 — the app's real test count

`+N` on a `flutter test` line counts tests **passed**, so `00:00 +11` meant
eleven tests, not twelve. The results note's app gate block now reads
`00:00 +12: All tests passed!` with the correction spelled out in place
(*"eleven before this wave, plus A5's `cmd+Z undoes a Delete through the
command log`"*), and `STATUS.md`'s measured table says the same. Every other
gate figure in both files was re-pasted from this wave's own run, including
`jet_cad_2d_flutter` **765 → 769** in three places (the gate block, the Plan 01
baseline paragraph and STATUS's table).

### B2 — the spec's Files list cell

`docs/superpowers/specs/2026-09-21-interaction-core-design.md` line 554. The
rewritten cell is restored to the original `SelectionOverlay`, with the
amendment appended after it in the same cell: *"`SelectionOverlay` — amended
at execution (Plan 02): the class is `SelectionOverlayPainter`, Flutter's
widgets library exports a `SelectionOverlay`"*. No other amendment was
touched.

### B3 — the four walks

The results note's debt section gains a table, **"Four walks over a
container's members, and they differ on two axes"** — whether a child
*instance* is followed, and which `QueryFilter` applies: engine band walk
(descend, filter applied), tool group rule (instances excluded per Ruling P-1,
filter applied after A1), outline cache (descend, `rendering()` after A2), and
the delete cascade (descend, **unfiltered** — hidden and locked leaves go with
their group, which mirrors what `RemoveNodeCommand` would otherwise orphan).

### B4 — results-note accuracy

Criterion 5's witness column now names `select_tool_test.dart`'s
`'Delete removes a leaf and an instance through the log; undo restores
geometry, not selection'` and A5's new shell test, and the two tests it cited
that do not discharge undo (`click replaces, shift-click toggles` and
`Escape during a band drops it, selection untouched; cancel returns to idle`)
are removed; `interaction_layer_test.dart`'s `one Delete press is one remove`
stays. The point-key debt bullet now reads *"one `Vector2` and four
`Offset`s per frame"* and names `_drawPointCross`'s two `drawLine` calls as
where the four come from.

### B5 — the window band's root walk

One debt sentence added, in the brief's own words: in window mode
`forEachInstanceInBand` enumerates and descends every root-level instance
(`_kAllBox` at the root, plan-mandated), which the spec's "must not walk the
whole document" did not anticipate; a band-box prefilter at the root is safe
(an instance whose box misses the band fails window) and is left for 03 with a
measurement.

### B6 — spec amendments for this wave

Four **"Amended at execution (Plan 02, 2026-09-22)"** paragraphs appended, none
rewriting the original text:

- **D8** — the tool's group every-rule skips leaves the picking filter rejects.
- **D8** — both band corners are converted at release.
- **D9** — the outline skips leaves the rendering filter rejects, and
  `OutlineCache` is a `ChangeNotifier` in the overlay's repaint merge.
- **D12** — cmd/ctrl+Z undoes through the command log, no redo in 02, and the
  look checklist stands as written.

The results note's "Spec amendments" list and STATUS's "six amendments" both
now say ten.

### B7 — the look checklist

Items 6 and 7 are kept on both platforms and now name the keys: *"cmd+Z
(macOS) / ctrl+Z (browsers)"* in the macOS list, *"ctrl+Z (browsers), cmd+Z on
macOS"* in the browser list. The count of owed checks is unchanged at
fourteen.

### B8 — `STATUS.md`

The Plan 02 task table gains a **final fix wave** row naming `0d69465` and the
docs commit; Task 12's row now carries `b02410a` instead of "(this commit)".
The measured table carries the new counts, the "rulings a reader must know"
paragraph gains the four-walks table and the new debt items, and the exit-gate
and Resume-here paragraphs say the gate was re-measured after the wave. **No
merge claim anywhere** — the gate is still 14 of 15 with criterion 15 OWED and
the merge still the human's decision.

---

## C — the gate lines

All four run one at a time, `CI=true` on every test command, both builds as
their own commands. `dart format` was run for real, not just checked: it
reported one changed file in `jet_cad_2d_flutter` (`test/support/selection_fixture.dart`)
and one in `floor_planner` (`lib/planner_view.dart`), both formatted and both
suites **re-run afterwards** so the pasted output matches the committed tree.

**`packages/jet_cad_2d`** — `CI=true dart test`:

```
00:03 +820: All tests passed!
```

Exit 0 — **unchanged**, as expected: this wave touches nothing under it.
`dart analyze`: `Analyzing jet_cad_2d... No issues found!` Exit 0.
`dart format --output=none --set-exit-if-changed .`:
`Formatted 116 files (0 changed) in 0.21 seconds.` Exit 0.

**`packages/jet_cad_2d_flutter`** — `CI=true flutter test`:

```
00:11 +769 ~1 -5: Some tests failed.

Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```

Exit 1 — **769 pass (765 + this wave's four new tests), 1 pre-existing skip,
and exactly the same five pre-existing `text_ladder_golden_test.dart` failures
and nothing else.** The Plan 01 baseline ruling stands. `flutter analyze`:
`Analyzing jet_cad_2d_flutter... No issues found! (ran in 1.5s)` Exit 0.
`dart format --output=none --set-exit-if-changed .`:
`Formatted 136 files (0 changed) in 0.26 seconds.` Exit 0.

**`apps/dev_harness_2d`** — `CI=true flutter test --concurrency=1`:

```
00:19 +82: All tests passed!
```

Exit 0 — **82**, untouched. `flutter analyze`:
`Analyzing dev_harness_2d... No issues found! (ran in 1.3s)` Exit 0.
`dart format --output=none --set-exit-if-changed .`:
`Formatted 22 files (0 changed) in 0.05 seconds.` Exit 0.

**`apps/floor_planner`** — `CI=true flutter test`:

```
00:00 +11: .../test/planner_shell_test.dart: cmd+Z undoes a Delete through the command log
00:00 +12: All tests passed!
```

Exit 0 — **12 tests**, all green. `flutter analyze`:
`Analyzing floor_planner... No issues found! (ran in 1.0s)` Exit 0.
`dart format --output=none --set-exit-if-changed .`:
`Formatted 5 files (0 changed) in 0.02 seconds.` Exit 0.

`flutter build macos --debug`:

```
Building macOS application...
✓ Built build/macos/Build/Products/Debug/floor_planner.app
```

`flutter build web`:

```
Font asset "MaterialIcons-Regular.otf" was tree-shaken, reducing it from 1645184 to 7736 bytes (99.5% reduction).
Compiling lib/main.dart for the Web...                             22.8s
✓ Built build/web
```

Both `✓ Built`. The short status after every line in this block listed only
the wave's own source files; **no `analysis_options.yaml` was rewritten at any
point**, and none needed `git checkout --`.

---

## Commits

| commit | what |
|---|---|
| `0d69465` | `fix(interaction): filter the group rule and the outline, band at release, undo in the shell` — A1–A7 |
| `7cd3697` | `docs: Plan 02 final fix wave — results, spec amendments, STATUS` — B1–B8 |

Both verified with `git log -1 --format=%B | grep -c "Fable 5.1"` → `1`.

## Concerns

- **The brief's A5 premise about the undo log measured false** and the test
  was built differently, as recorded under A5: the startup plan goes through
  the command log, so `canUndo` is true before the Delete. The test pins the
  undo to one command by live-entity count instead.
- **A5's red came from a named mutation, not a first red run** — the binding
  and the test landed in the same edit. The mutation (both `SingleActivator`
  bindings deleted) is pasted above; the file was restored byte-identical.
- **A2 is implemented in `_addLeaf`, not `_addContainer`.** That is a superset
  of the ruling: a *directly selected* hidden leaf now also gets no outline.
  Deliberate, and stated here so a reviewer reads it as a choice.
- **B4's removal leaves criterion 5's shift and Escape clauses without a
  witness in that cell**, as the ruling directs. Their coverage is unchanged
  in the suite (`select_tool_test.dart`'s `click replaces, shift-click
  toggles`, `keys and delete Escape when idle clears`, and criterion 1's own
  row); only the cell's citation changed.
- **Criterion 15 is still OWED.** No human looked, nothing was simulated. The
  wave gives the look something to press for its two undo items; it does not
  discharge them.
