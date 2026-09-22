# Final fix wave — Plan 02 (one dispatch)

Base: b02410a. Work in the worktree; every item below is a controller ruling on
a final-review or Task 12 finding. Fix all, in one or a few commits, each with
the trailer `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`. Do not
run a mutation sweep. Keep commands short; the two `flutter build`s run as
their own commands.

## A. Code (packages/jet_cad_2d_flutter, apps/floor_planner)

**A1 — Filter asymmetry in the tool's group rule (Important #1).**
`select_tool.dart` `_everyLeafIn` fails a group on any leaf the picking filter
rejects (hidden or locked), because `leavesByOwner()` is unfiltered while
`passing` only holds accepted slots. Ruling: a leaf the picking filter rejects
is **skipped** by the every-rule, not failed on — matching the engine's
`_bandDescend`, which applies `_filters.acceptsEntity` before counting.
Implementation: build one `FilterEvaluator(doc)` (engine, `query_filter.dart`;
check it is exported from `package:jet_cad_2d/jet_cad_2d.dart`, else export it
there — one line — and say so) per band release and `continue` on
`!evaluator.acceptsEntity(slot, const QueryFilter.picking())` inside
`_everyLeafIn`, before `any = true`. A group whose only leaves are all rejected
has no member leaves and is not selected. Test in `select_tool_test.dart`: a
group with one visible leaf and one leaf on a locked layer
(`LayerRecord(..., locked: true)` via `doc.tables.layers.add`), a window band
enclosing the visible leaf only → the group is selected; and the same with
the locked leaf made visible-and-unlocked but outside the band → not selected.

**A2 — The outline draws hidden leaves (Important #1, second half).**
`outline_cache.dart` `_addContainer`/group walk records every owned leaf.
Ruling: the outline skips leaves the **rendering** filter rejects
(`QueryFilter.rendering()`: hidden only; a locked leaf still draws, as the
canvas does), through the same `FilterEvaluator`. Test in
`outline_cache_test.dart`: a group with one visible and one hidden-layer leaf
(`LayerRecord(..., visible: false)`) → `debugWorldSegmentsOf(key)` holds the
visible leaf's segment only. The delete cascade keeps deleting hidden leaves
(recorded as policy in D below).

**A3 — Band corner taken at press time (Important #2).**
`select_tool.dart` `_bandKeys` uses `_startWorld` captured on press. Ruling:
spec D8's spelling — both corners converted at release:
`ctx.camera.value.screenToWorld(Vector2(_start.dx, _start.dy))` and the up
event's world. Remove `_startWorld` if it becomes dead. Test in
`select_tool_test.dart`: press on empty space, move past the slop, then
`camera.zoomAt(some focus, 2.0)`, then release; the selected set equals what
the world band computed from the *current* camera's `screenToWorld` of both
screen corners covers (pick a fixture where the pre-zoom corner would select a
different set, and assert the difference).

**A4 — No repaint source for a DocChange (Important #4).**
`OutlineCache` rebuilds on `document.changes` and notifies nobody. Ruling:
`OutlineCache extends ChangeNotifier`, calls `notifyListeners()` at the end of
its changes handler (after a rebuild, and after a load/purge clear) and on a
selection-driven rebuild is silent (the selection already notified). Add the
cache to the overlay's repaint merge in `planner_view.dart` and in every test
fixture that builds the merge (`selection_fixture.dart`'s `pumpInteraction`,
`selection_overlay_test.dart`'s rig). Dispose order unchanged. Widget test in
`selection_overlay_test.dart`: select an instance, `SetEntityGeometryCommand`
on a leaf in its definition, pump a microtask and a frame, overlay paint
count +1, canvas count also +1 (the canvas has its own document listener —
assert both moved so the test is not confused with M-02e′'s).

**A5 — Undo affordance (Important #3).**
The app has no undo control, and the look asks the human to undo. Ruling:
bind undo in `_PlannerShellState` — wrap the `Scaffold` body in
`Shortcuts`/`Actions` (or a `CallbackShortcuts`) mapping
`SingleActivator(LogicalKeyboardKey.keyZ, meta: true)` and
`SingleActivator(LogicalKeyboardKey.keyZ, control: true)` to
`if (_document.commands.canUndo) _document.commands.undo()`. Keys the tool
returns `ignored` for bubble up to it (the layer's `Focus` returns the tool's
result). Test in `planner_shell_test.dart`: select a wall by tap, send Delete
(down+up), assert the entity is gone, send cmd+Z (`sendKeyDownEvent` for meta
then keyZ, then the ups), assert the entity is back and the selection empty.
Do **not** add redo.

**A6 — `worldPointOf` doc (deferred 11a, FIX BEFORE MERGE).**
`outline_cache.dart` ~110–113: the doc says subtract `origin`; the only caller
maps through `worldToScreen`. Reword: "an absolute world position; map it to
screen with `worldToScreen` (or rebase it) before it reaches `dart:ui`".

**A7 — Stale `byOwner` in `_deleteSelection` (minor 6, one line).**
Inside `_groupCascade`'s leaf loop, `if (doc.entities.slotOf(h) == null) continue;`.

## B. Docs (results note, spec, STATUS)

**B1 — Task 12 finding 1.** `apps/floor_planner` has 11 tests (12 after A5's
new test — re-run the app line and state the real count). Fix every place the
results note and `STATUS.md` say 12 (or the old number) to what the gate line
prints after this wave.

**B2 — Task 12 finding 2.** The spec's Files list cell for
`selection_overlay.dart` was rewritten. Restore the original cell text
`SelectionOverlay` and **append** the amendment after it in the same cell:
"`SelectionOverlay` — amended at execution (Plan 02): the class is
`SelectionOverlayPainter`, Flutter's widgets library exports a
`SelectionOverlay`". Keep every other amendment as is.

**B3 — Four walks paragraph (final review recommendation 4).** Add to the
results note's debt section a short table "walks over a container's members":
engine band walk (filter applied, instances descend), tool group rule (filter
applied after A1, instances excluded — Ruling P-1), outline cache (rendering
filter after A2, instances descend), delete cascade (unfiltered — hidden and
locked leaves are deleted with their group, which mirrors what
`RemoveNodeCommand` would otherwise orphan). Two axes: instances and the
query filter.

**B4 — Results note accuracy (minor 15).** Criterion 5's witness column must
name `select_tool_test.dart`'s `'Delete removes a leaf and an instance through
the log; undo restores geometry, not selection'` and A5's new shell test;
remove the two tests it cites that do not discharge undo. The point-key debt
sentence names the four `Offset`s per point key per frame as well as the
`Vector2`.

**B5 — Window band walks every root instance (minor 5).** Add one debt
sentence: "in window mode `forEachInstanceInBand` enumerates and descends
every root-level instance (`_kAllBox` at the root, plan-mandated), which the
spec's 'must not walk the whole document' did not anticipate; a band-box
prefilter at the root is safe (an instance whose box misses the band fails
window) and is left for 03 with a measurement."

**B6 — Spec amendments for this wave.** Append "Amended at execution
(Plan 02, 2026-09-22)" sentences: D8 — the tool's group every-rule skips
leaves the picking filter rejects; D9 — the outline skips leaves the
rendering filter rejects, and `OutlineCache` is a `ChangeNotifier` in the
overlay's repaint merge; D12 — cmd/ctrl+Z undoes through the command log,
no redo in 02; the look checklist stands as written.

**B7 — The look checklist** in the results note: keep items 6 and 7 (undo)
now that A5 exists; add "cmd+Z (macOS) / ctrl+Z (browsers)" to the wording.

**B8 — STATUS.md**: the Plan 02 section's task table gains a "final fix wave"
row with the commit(s); the gate summary reflects the new counts; still no
merge claim.

## C. Gates and report

Run all four gate lines (one at a time, `CI=true`), including both builds;
`git status --short` after each, restore any `analysis_options.yaml` with
`git checkout --`. Expect: `jet_cad_2d` unchanged; `jet_cad_2d_flutter` the
same five goldens and nothing else; harness 82; app all green and `✓ Built`
twice. Paste the summaries into the results note's criterion-12 row (replace
the old ones) and into your report.

Report: `.superpowers/sdd/2026-09-21-interaction-core/final-fix-report.md` —
per item A1–A7, B1–B8: what changed, the covering test, the command, the
pasted output; then the gate lines; then the commit list. Reply with the short
contract: Status; commits; one-line gate summary; concerns; report path.
