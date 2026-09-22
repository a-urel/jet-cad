# Plan 04 — final fix wave (one dispatch)

Branch `plan-04/page-grid-rulers`, HEAD 1618111. Findings from the final
whole-branch review (Opus, 2026-09-22), adjudicated by the controller. Items
A1–A9 are code; B1–B5 are docs. One commit for the code (subject below), one
for the docs. Every gate line green after; the results note's numbers updated
to the post-wave tree.

## A — code

**A1 (Critical, Ruling 04-19).** `enum Capability` in
`packages/jet_cad_2d/lib/src/document/command.dart` is
`{ transform, components, geometry, structure }`; `CompoundCommand.capability`
is the greatest-index member; the D13 skips test `== Capability.components`.
So `CompoundCommand([TransformNodeCommand(...), SetComponentCommand<PageComponent>(...)])`
summarises as `components` and both the index and the tile cache skip a move.
Fix: reorder the enum to `{ components, transform, geometry, structure }` and
document on the enum: "`components` is declared first, so a compound's
summary (its highest-ranked member) is `components` only when every member
is — the property spec D13's skip relies on." Nothing serialises the ordinal
(`DraftPermissions` is by name; grep `Capability.values`/`.index` to confirm
and say so in the report). Update the `compound_command_test.dart` summary
test if its expectation changes (it asserts `structure` for
`[transform, geometry, structure]` — unchanged). Add to
`test/index/component_edit_skip_test.dart`, beside "a compound with one
geometry member still reconciles": **"a compound with a transform member and
a page edit still reconciles"** — a group node moved by
`TransformNodeCommand` plus a `SetComponentCommand<PageComponent>` on the
root, asserting `rebuildCount` grows; and the twin in
`packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart` next to the
components-only test: a `CommandApplied(..., capability: Capability.transform)`
still invalidates (assert `liveTileCount` drops or `invalidationCount`
grows — mirror what the neighbouring geometry test asserts). Mutant for the
log (B4): revert the enum order → the new test goes red.

**A2 (Important).** `packages/jet_cad_2d_flutter/test/ruler_frame_test.dart`,
the third test ("a major tick in the top bar sits at its world point's x in
the child"): the assertion inverts the camera and re-applies it, so it is
circular. Replace the body with a genuine frame-level check: (a) the top
bar's rect and the child's rect from `tester.getRect(...)` share `left` and
`width` (keep — the first test also pins it); (b) an **independent** world
point: the sheet corner, `Vector2(7350, 0)` → `camera.worldToScreen(...).x`
(= 395.45 at the standard camera, inside the 400 px child); assert
`painter.debugLastTicks` contains a major tick within 1e-6 of that x (page
x = 0 is a major); (c) assert that same x, offset by the bar's `left`,
equals the tick's global position — i.e. `topBar.left + tickX == child.left
+ tickX` trivially, so instead assert `topBar.left == child.left` once and
that the tick x lies in `[0, child.width]`. Keep the test name honest:
"the sheet corner's major tick sits at its screen x in the top bar".

**A3 (Important).** `packages/jet_cad_2d_flutter/test/page_notifier_test.dart`,
"a load re-reads, and dispose stops listening": both assertions are vacuous.
Make the load branch real: after the edit, `doc.components.attach<PageComponent>(doc.rootHandle, standardPage().copyWith(pageBreaks: true))`
out of band (no command, no event), assert `n.value` still shows the old
value, then `doc.commands.notifyLoaded()`, `await Future<void>.delayed(Duration.zero)`,
assert `n.value!.pageBreaks` is true. Make the dispose check real: after
`n.dispose()`, execute a `SetComponentCommand` with a different value, await
a microtask, and assert `n.value` did not change (read the field before and
after; a disposed `ValueNotifier` may throw on `value=` — if it does, that is
the observable, assert `returnsNormally` on the *execute* and that no
exception surfaced from the stream; state in the report which observable you
used).

**A4 (Important).** `packages/jet_cad_2d_flutter/test/ruler_painter_test.dart`,
first test: the label expectation calls `formatLength`, the function under
test, so M-04i cannot be killed there. Drop "M-04i (unit)" from the comment
(M-04i is killed by `grid_scale_test.dart`) and add one literal: find the
major tick whose page x rounds to 500 and assert its label `== '0.5 m'`.

**A5 (Important).** Two stale doc comments: (1)
`packages/jet_cad_2d/lib/src/document/commands.dart`, the `CompoundCommand`
class doc says `[capability]` "is informational only" — rewrite: "…and is
what `SpatialIndex` and `TileCache` read to skip a components-only compound
(spec D13); it is `components` only when every member is (A1)." (2)
`packages/jet_cad_2d/lib/src/index/spatial_index.dart`, the `_onChange` doc
("So this cannot be *told* what changed … `SetComponentCommand` touches the
entity handle exactly as a geometry edit would"): add one sentence after it:
"Since Plan 04 the change *does* say one thing about itself — its
`capability` — and a components-only change returns before `_reconcile`
(spec D13); the re-derive-and-compare rule below applies to every other
kind."

**A6 (upgraded from deferred).** `packages/jet_cad_2d/lib/src/geometry/grid_scale.dart`:
`_metricLadder` and `_imperialLadder` become `List.unmodifiable(...)`, and
`ladderFor`'s floored list is also returned unmodifiable. Add one test:
`expect(() => GridScale.ladderFor(DisplayUnit.meters)[0] = 0, throwsUnsupportedError)`.

**A7 (Minor, taken).** `packages/jet_cad_2d_flutter/lib/src/page_notifier.dart`:
treat an empty `touched` as "the whole document changed" like the index and
the tile cache do: `touched.isEmpty || touched.contains(root)`. One test:
a `CommandApplied(label: 'x', touched: const {})` pushed through
`doc.commands.onAfterMutate`? No — the notifier listens to the stream, which
only the dispatcher feeds. Test it through a fake command whose `apply`
returns `touched: const {}` after attaching a new page out of band; assert
the notifier re-read. (A `DraftCommand` subclass in the test file, like
`command_test.dart`'s `CounterCommand`.)

**A8 (Minor, taken).** `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`:
one sentence in the comment above the D13 skip saying the skip deliberately
sits after `_dropCarryOver()`, which still runs for a components-only edit
(a composite re-bake, no tile dropped).

**A9 (Minor, taken).** `apps/floor_planner/test/planner_shell_test.dart`:
rename "the three chrome slots are laid out and empty" → "the three chrome
slots are laid out". `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart`:
swap the `ruler_frame.dart` / `ruler_painter.dart` export lines so the block
is alphabetical.

Not taken (recorded in B2 as debt): #9 the floored ladder allocates per
`pick` (unreachable from the app — `gridStepMm` is not editable); #10 the
buffer grows to the pass's need rather than the bound (spec text vs code;
amend the spec's D8 sentence in B3 to say "grown as needed, never shrunk");
#11 metre labels collapse to `0 m` below a 0.5 mm major (unreachable under
`kMaxScale = 100`); #13 `fitToPage`'s result bypasses the camera clamp
(pre-existing from Plan 01); #14 the scale field resets on any page change.

Code commit subject: `fix(engine,render): components ranks lowest so mixed compounds reconcile; three tests made real; ladders immutable`.

## B — docs (second commit: `docs: Plan 04 final fix wave — results, spec, STATUS, README`)

**B1.** Spec D13: an `**Amended at execution (Plan 04, 2026-09-22):**`
paragraph — Ruling 04-19, the enum order, and the sentence "a compound
reconciles when any member is not `components`; the summary capability
carries that because `components` is declared first". Spec D8: the buffer
sentence amended per #10.

**B2.** Results note `docs/superpowers/notes/2026-09-22-plan-04-results.md`:
the gate lines re-run after the code commit and pasted (the counts change:
engine +2 or so, render layer +3 or so, app unchanged — paste what prints);
the mutation summary gains M-04w (the enum order, B4); the debt section
gains: the not-taken items above, "a future `open file` must pass
`registerComponents: PageComponent.register` to `decode`/`decodeString` —
registering after the decode does not rescue a page already landed as
unknown bytes, and `main.dart`'s `get<PageComponent>(root)!` needs a
null-safe path that day", and "`OutlineCache._onChange` still rebuilds on
every `DocChange`, page edits included — the obvious second consumer of
`capability` when 06 asks"; the rulings list gains 04-19; the exit-gate
witnesses for criteria 7 (add the mixed-compound tests) and 14 (23 → 24
fired).

**B3.** `STATUS.md` Plan 04 section and header: the new HEAD, the counts,
"final fix wave" sentence in Plan 02's shape; the Resume paragraph likewise.

**B4.** Mutation log `docs/superpowers/notes/plan-04-mutation-log.md`: append
`### M-04w — Capability enum order reverted (transform before components)`
fired against `test/index/component_edit_skip_test.dart` with the cp/restore
discipline; head count 24 fired.

**B5.** `roadmap/00-README.md:265`: "**01 has a spec as of 2026-09-21**; the
other twelve have not started" → "01, 02 and 04 are executed (02 merged);
the other ten have not started" (check STATUS's own sentence at ~1278 says
"ten" and align). `roadmap/04-page-grid-rulers.md` status line: the new
HEAD.

## Gates

All four lines, `CI=true`, from each directory, after the code commit and
again after the docs commit if any test file moved (none should). Restore
`analysis_options.yaml` with `git checkout --` (yaml only). Trailer exactly
`Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>` on both commits.
