# L2 brief — every app spelling of "a live T" goes through the engine's rule

You are the implementer for L2 on branch `fix/live-object-rule`, worktree
`/home/user/jet-cad/.claude/worktrees/fix-live-object-rule`. Work only there.
Read `CLAUDE.md`; L1's commit (the branch's HEAD when you start: `git log -1`)
and its report `.superpowers/sdd/fix-live-object-rule/l1-report.md` — L1 added
`ParametricCatalog`'s public query (read its doc comments for the exact
names); spec 06 D5 as L1 amended it; spec 08's Ruling 08-8 (the document
adapter). Commit; do NOT push.

## The defect (fix/post-11 note, "Found, not fixed": shadowing + five spellings)
The engine names a root-level group carrying two registered types by the
**later** registration (`parametricCatalog` order: Box, Wall, Opening,
Separator, Room, Dimension). The app decides "is this a live `T`" on its
own, seven ways, none of which knows that rule. A file's root-level group
carrying `WallParams` and `OpeningParams` is an opening to the engine and a
wall to the app: it follows a wall joint as a phantom (fix/post-11 Q1+Q2
review, probe PR2), and when its `OpeningParams` names a host that does not
exist, a select-tool drag of a neighbouring wall's corner throws
`DanglingReferenceError` from pointer dispatch (probe PR2d; the review is
`docs/superpowers/ledgers/2026-09-29-fix-post-11/q12-review.md`, m2).

## The change (ruled)
One app module, `apps/floor_planner/lib/parametric/live_objects.dart` (name
it otherwise only with a reason), the only place the app asks "is `h` a live
`T`" and "the live `T`s, ascending": thin wrappers over L1's query on
`parametricCatalog` (`catalog.dart`). Every one of these goes through it,
and nothing else in `apps/floor_planner/lib` spells `node.parent ==
…root` or a type decision by `get<T>(h) != null`:
1. `opening_geometry.dart` `_isLiveGroup` (in `wallsInDocument` — the host
   and every other wall — and `openingsInDocument`): removed.
2. `dimension_attach.dart` `_isLiveGroup` and `_isLiveWall` (`thickestWall`,
   the candidate walks; the opening walk at the second `forEachInRect` asks
   "a live opening", not "a live group that happens to carry
   `OpeningParams`").
3. `wall_grips.dart` `_keptPut`'s opening walk.
4. `wall_bands.dart`'s cache build.
5. `room_inputs.dart` `liveObjectsOf` (move it to the module or make it the
   module's wrapper; update its callers in `room_tool.dart`,
   `room_inputs.dart`).
6. `selection_panel.dart` `_isObject<T>`.
7. `object_grips.dart` `_of`: the provider is the naming type's; today the
   first `get` wins (wall before opening), the opposite of the engine.
Then **grep the whole of `apps/floor_planner/lib`** for every other
`get<…Params>(h) != null` / `== null` used as a type or liveness decision
(files with such reads today: `room_grips`, `separator_grips`,
`dimension_grips`, `opening_grips`, `room_tool`, `selection_panel`, …). A
read of a component of a handle already known to be a live `T` is fine; a
read that decides what `h` *is* goes through the module. List every site in
the report with the verdict. Any site where the right answer is unclear:
stop and report it, do not guess.

Behaviour must be unchanged for every document the app can make (each
root-level group carries exactly one type). Only a shadowed group (a file)
changes: it is the later type's object everywhere and the earlier type's
nowhere.

Cost: the wrappers are O(registered types) per call; the band cache's
rebuild and the dimension attach walk call them per wall. Neither is on the
frame path (the band cache rebuilds on a document change; confirm and cite
the line). Say so; no caches.

## Tests (a test lands only if a named mutant turns it red)
Non-degenerate: rotated, translated groups; handles not the lowest.
Build the shadow group as a file would (regenerate a real opening on a live
wall, then attach `WallParams` to its group through the store directly, as
PR2 did; for PR2d, a dangling host handle).
- **The throw (PR2d), end to end through the select tool**: dragging a
  neighbouring wall's corner lands one undo step, no exception
  (`tester.takeException()` null), the shadow group's components `==` their
  loaded values. Red before the fix.
- **The phantom (PR2)**: the joint drag's command does not touch the shadow
  group; the preview draws only the real walls.
- The shadow group is an opening everywhere and a wall nowhere: not in
  `wallsInDocument`'s walls, not in the band cache, not in `thickestWall`,
  not a dimension attach candidate as a wall, listed by
  `openingsInDocument` for its host; its selection shows the Opening
  section, not the Wall section; its grips are the opening provider's.
- Pick at least one site per spelling and make sure some test goes red when
  that site alone reverts to its old spelling (the mutants below).
Mutants (fire each; record the red test and line): M-L2-1 … M-L2-7, one per
spelling above, each reverting that site alone to its pre-L2 code (the
`is GroupNode && parent == root && get<T> != null` form, or for `_of` the
first-match order). Every one must go red, or you say why it is equivalent.
Also re-fire fix/post-11's M-R1 (a `GroupNode` check dropped — now inside
the engine: L1 pins that; say whether any app test still catches it) and
M-Q2a (`_endsAt` not filtered) — both must still go red.

Procedure (binding): `cp` the file to a backup under
`/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/l2-`
(yours alone), mutate, run, `cp` back, `diff` (exit 0). NEVER `git checkout --`
a .dart file. `CI=true` on every test command. Never synthesize output. Never
commit `analysis_options.yaml`.

## Docs
Doc comments that describe a "live wall"/"live object" as "a root-level group
carrying `…Params`" say instead that it is the engine's rule, asked through
the module. Spec 08's Ruling 08-8 paragraph (the document adapter) and any
spec 10/11 sentence that spells the rule (grep "root-level group carrying"
in `docs/superpowers/specs/`): an "Amended by fix/live-object-rule" line
where the text would now be wrong. Do not touch notes or ledgers.

## Gates
```sh
export PATH=/root/flutter/bin:$PATH
(cd packages/jet_cad_2d_flutter && CI=true flutter test ; CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .)
(cd apps/floor_planner          && CI=true flutter test && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed . && CI=true flutter build web --release)
```
Engine as L1 left it (you change no engine file; if you find you must, stop
and report). Branch point app 503; render 940 + 1 skip + 7 standing. Paste
summaries and exit codes.

## Commit and report
`fix(app): one live-object rule, the engine's, for every type decision`,
ending with
```
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_013XiH3QE4FtMMNUjbASxiEv
```
Write `.superpowers/sdd/fix-live-object-rule/l2-report.md` and return it:
hash; the module; every site (the seven and the grep's) with its verdict;
red before the fix; every mutant with its red test and line; gates;
deviations; anything found outside scope (reported, not fixed).
