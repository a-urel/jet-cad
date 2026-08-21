# Task 3 report — FillIndex

**Provenance, stated first because it is unusual.** The code in this task was
written by an implementer subagent. That agent, and two successors, died four
times on a 600-second stream watchdog without ever reaching verification. The
**controller** ran the verification, the mutations and the commit. Every
transcript in `task-3-mutations.md` is real output from a run the controller
made; none is reconstructed. The independent task review still gates this task —
nothing here is self-approved.

## Why the agents died

Three of the four stalls had one environmental cause: **Flutter auto-updated
3.47.0 -> 3.47.1 mid-session**, triggering a full Dart SDK re-download
(`curl --continue-at - ... dart-sdk-darwin-arm64.zip`, about ten minutes).
Every `flutter` invocation in the workspace blocked on it with no stream output.
Diagnosed with `ps aux`, not by re-reading transcripts: a hung
`bash flutter analyze` and the curl were both visible, and the curl finished
inside a 20-second observation window.

The fourth stall was a real defect in the controller's own instructions: a
`trap ... EXIT` restore only holds **within one shell invocation**. An agent
that mutates in one Bash call and tests in the next has its file restored by the
trap before the test runs, so the mutation measures nothing. The agent diagnosed
this itself. Every mutation below is one invocation: mutate, test, restore.

## What the code does

`FillIndex` holds two maps and is the derived state for fills:

- `Map<Handle, Int32List> _triangles` — one triangulation per boundary
- `Map<Handle, Handle> _boundaryOfFill` — the reverse map

Both halves live in one object because the same three commands write both and
the same moments invalidate both. Two objects would be two chances to update one
and forget the other.

**The key is the boundary's `Handle`, never its `geomIndex`.**
`DraftDocument.purge()` renumbers every `geomIndex` from a remap table while
leaving handles untouched, so a slot-keyed cache is not *stale* after a purge —
it is **permuted**, every surviving entry attached to the wrong entity at once.
Handles are never reissued and undo restores them, so the worst a missed
handle-keyed invalidation can do is leak.

`trianglesFor` returns the stored list **itself**, not a copy: the frame path
reads it per fill per frame and a defensive copy would allocate per entity,
against the project's standing constraint.

`fillsOf` sorts into ascending handle order, because callers put its result into
a command's `touched` set and into removal cascades, and this project's
determinism rests on stable orders.

## `CommandTarget` has three implementers, not one

The plan's Modify list named only `DraftDocument`. `CommandTarget` is also
implemented by two test fakes — `FakeTarget` (test/document/command_test.dart)
and `TestTarget` (test/document/commands_test.dart) — and adding `fills` breaks
both. Each was given a **real `FillIndex` instance**, not a throwing stub: a
throwing fake would make Tasks 4 and 6 fail for the wrong reason.

`DraftDocument.purge()` deliberately does **not** touch `fills`, and carries a
comment saying so. Adding an invalidation there would be correct-looking and
wrong — it would throw away work that nothing invalidated.

## Verification — controller-run

```
cd packages/jet_cad_2d
dart test                                          -> 737 tests, All tests passed!
dart analyze                                       -> No issues found!
dart format --output=none --set-exit-if-changed .  -> 109 files, 0 changed
```

Flutter half, verified by the controller after the SDK download completed:

```
flutter --version           -> 3.47.1, framework 6655482ec0, engine 5d53178869
flutter analyze             -> No issues found! (ran in 1.2s)
flutter test                -> 242 pass, 1 skip
flutter test --tags golden  -> 23 pass
```

`git status --porcelain` shows only this task's files. No `analysis_options.yaml`
appeared at any point.

## Mutations

Full transcripts: `task-3-mutations.md`. Summary:

| # | mutation | verdict | killed by |
|---|---|---|---|
| T3a | `trianglesFor` returns a defensive copy | KILLED | `a hit returns the stored list itself, not a copy` |
| T3b | `dropBoundary` forgets the links | KILLED | `dropBoundary removes the triangles and every link naming it` |
| T3c | `fillsOf` returns insertion order | KILLED | `fillsOf returns every fill naming a boundary, in handle order` |
| keying | the cache keyed by `geomIndex` instead of `Handle` | **KILLED** | `the index survives a purge because handles do` |

**Two earlier controller attempts at T3a-T3c were discarded, and both are
recorded in the transcript file because both produced confident wrong answers.**

1. The stalled agent had left the *test* file half-mutated — bare ints where
   `const Handle(n)` belongs — so every run failed to **load** and all three
   mutants read KILLED when nothing had been measured. The test file was
   restored by hand and re-verified 6/6 green before the real runs.
2. The compile-error guard added after (1) matched `dart test`'s own
   `loading test/...` **progress** line, so all three then read INVALID. The
   guard now keys on `Failed to load` and on a compiler `Error:` line, and a
   verdict is KILLED only when the suite ran and a **named** test failed.

The keying mutant is the deliverable. Under `geomIndex` keying, five tests still
pass and exactly one fails — `the index survives a purge because handles do`. So
the purge test is genuinely exercising slot renumbering, and the handle-keying
decision is evidenced rather than asserted.

## Concerns

- This task was verified and committed by the controller rather than by an
  implementer. The reviewer should treat every claim here as unverified and
  re-run what it needs, exactly as it would for any task.
- Task 17's results note must record that Plan 3e is measured on Flutter
  **3.47.1**, not the 3.47.0 the plan header states, and that the change landed
  mid-plan between Tasks 2 and 3.
