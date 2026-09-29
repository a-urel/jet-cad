# Q3 brief — ParametricEdit refuses a parametric component off a live root-level group

You are the implementer for Q3 on branch `fix/post-11`, worktree
`/home/user/jet-cad/.claude/worktrees/fix-post-11`. Work only there. Read
`CLAUDE.md`, then `docs/superpowers/specs/2026-09-24-parametric-layer-design.md`
(spec 06: D2, D4, D9 and the `parametric.misplaced` diagnostic). Commit; do NOT
push.

## The defect (post-11 found item (d))
`SetComponentCommand<T>` for a registered parametric type `T`, on a handle with
no node (or on a node that is not a root-level `GroupNode`), attaches the
component without complaint. `ParametricSystem.diagnostics()` then reports
`parametric.misplaced`; the component survives save, load and purge and is never
regenerated or drawn. No shipped app path reaches it (every app
`SetComponentCommand` re-checks liveness), but the engine lets any client do it.
Record: `docs/superpowers/notes/2026-09-28-plan-11-results.md`, "Found, not
fixed" (d); confirmed on `main` by Plan 11's Task 12 reviewer.

## The fix (already ruled; binding)
A guard in the `ParametricEdit` path (`packages/jet_cad_2d/lib/src/parametric/`:
`parametric_system.dart`, `regeneration.dart` `_run`), **after the inner command
applies**, beside the existing `_refused` check: a handle the inner command
touched that now carries a non-null registered parametric component and is not a
live root-level group is refused — `inner` is undone and the edit throws, leaving
nothing in history, the same way the existing refusal does. **Not** a guard in
`SetComponentCommand` itself: undo of a delete replays a re-attach before the node
is restored (`ParametricReplay`), and a naive guard would break it.

Decide and justify:
- **Which handles are checked.** Only handles the inner edit touched (so a file
  that already carries a misplaced component does not refuse unrelated edits —
  compare Ruling 10-4's reasoning in `_run`), or every handle of every type (one
  survey already enumerates them — read `_survey` / `_isObject`). Prefer the
  narrow form unless you find a reason; cost it in the report.
- **What is thrown.** Reuse an existing error type if one fits (read
  `GeneratedGeometryError` and `_refused`), or a `StateError` with a precise
  message; the doc comment says which and why. Whatever it is, the app must
  never hit it (confirm: grep every app `SetComponentCommand` call).
- **Detaching stays legal:** `SetComponentCommand<T>(h, null)` on a dead or
  nested handle must not be refused (the cascade's cleanup detaches exactly
  those).
- The existing `parametric.misplaced` diagnostic stays (a file can still carry
  one; loading does not go through `ParametricEdit`). Say so in a doc comment.

## Tests (the testing bar: a test lands only if a named mutant turns it red)
Engine tests beside the existing parametric tests (find them under
`packages/jet_cad_2d/test/parametric/`). Non-degenerate: use a registered test
type that is not the first registered, a handle that once was a live group
(deleted), a handle never allocated, a nested group, and a live root-level group
as the control. At least:
- attaching to a dead handle, a never-allocated handle, and a nested group is
  refused: nothing in history, the component store unchanged, the document
  byte-identical where the suite has such a check;
- attaching to a live root-level group works (control);
- the refusal inside a `CompoundCommand` whose other child is legal refuses the
  whole compound;
- detaching (`null`) from a dead handle is not refused;
- delete a live object, undo, redo, undo again: all work (the replay path the
  naive guard would break);
- an unrelated edit on a document that already carries a misplaced component
  (build it the way a file would: through whatever the loader or a direct
  store write uses, without `ParametricEdit`) is not refused, if you took the
  narrow form;
- a non-parametric component type on a dead handle behaves exactly as before
  (the guard is for registered parametric types only).
Mutants (fire each, record the red test and line): M-Q3a the guard removed;
M-Q3b the guard checks liveness only (a nested group passes); M-Q3c the guard
also refuses `null`; M-Q3d the guard refuses without undoing `inner` (state
leaks); M-Q3e the guard in `SetComponentCommand.apply` instead (undo of delete
must go red); M-Q3f (narrow form) every handle checked, not only touched ones.
Add your own at seams these miss.

Procedure (binding): `cp` to a backup under
`/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/q3-`
(yours alone), mutate, run, `cp` back, `diff` (exit 0). NEVER `git checkout --`
a .dart file. `CI=true` on every test command. Never synthesize output. Never
commit `analysis_options.yaml`.

## Docs
A short "Amended by fix/post-11" paragraph in spec 06 where it describes the
edit's refusals (D4 step 8 or wherever `_refused` is specified). Follow the
existing "Amended at execution" paragraphs' style.

## Gates
```sh
export PATH=/root/flutter/bin:$PATH
(cd packages/jet_cad_2d         && CI=true dart test ; CI=true dart analyze && CI=true dart format --output=none --set-exit-if-changed .)
(cd packages/jet_cad_2d_flutter && CI=true flutter test ; CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .)
(cd apps/floor_planner          && CI=true flutter test && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed . && CI=true flutter build web --release)
```
Branch point (a025c2f): engine 1,078 + 2 standing (`test/testing/generate_document_test.dart`);
render 940 + 1 skip + 7 standing (`text_ladder` 1–5, `text_lod_ladder` 1–2);
app 491. Paste summaries and exit codes.

## Commit and report
`fix(engine): ParametricEdit refuses a parametric component off a live root-level group (post-11 (d))`,
ending with
```
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_013XiH3QE4FtMMNUjbASxiEv
```
Write `.superpowers/sdd/fix-post-11/q3-report.md` and return it: hash; the
guard's shape and the two decisions with their cost; red before the fix; every
mutant; gates; deviations; anything found outside scope (reported, not fixed).
