# Independent review: "A removed node takes its components", revision 2

You are an independent reviewer of a design spec in the jet-cad repository
(a Dart/Flutter CAD engine and floor planner). You did not write it. Your
job is to find what is wrong with it before a plan is written from it.

## What to review

- The spec: `docs/superpowers/specs/2026-10-09-node-components-on-delete-design.md`
- At commit `e8b48a96b94780eab6c1242c0508a747b6ee45a8` on branch
  `spec/node-components-on-delete`, in the worktree
  `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/confident-ardinghelli-29b386`.
  The code the spec describes is the same as `main` at `e281372`
  (release 0.4.0); the branch adds only this spec revision and a STATUS
  line.
- House rules: `CLAUDE.md` at the repo root (read it first), especially
  the **Testing bar**: defects surface through mutation and differential
  testing, the dominant failure is the degenerate fixture, and a test is
  only worth landing if a named mutation turns it red.
- Context you may need: the shipped host embedding API spec
  `docs/superpowers/specs/2026-10-09-host-embedding-api-design.md`
  (O-8, O-10, E-6, E-9, F-14), the parametric plan's rulings
  `docs/superpowers/ledgers/2026-09-24-parametric-layer/plan-rulings.md`,
  and the code under `packages/jet_cad_2d`, `packages/jet_cad_2d_flutter`,
  `packages/jet_cad_floor_plan`.

## Rules for you

- **Do not modify the worktree above.** Read it only.
- If you want to run code (a spike, a mutant, a test), make your own
  scratch worktree: `git -C /Users/ahmeturel/Projects/oss/jet-cad worktree
  add --detach <scratch path> e8b48a96` under
  `/private/tmp/claude-501/-Users-ahmeturel-Projects-oss-jet-cad/f8275290-e443-48f0-ac6f-5249af1d8688/scratchpad/review/`,
  run `flutter pub get` there once, and remove it with `git worktree
  remove --force` when done. Never commit, push, stash or touch any other
  worktree or branch. `jet_cad_floor_plan` tests need
  `flutter test --enable-vmservice`.
- On this machine, these fail at `e281372` and are standing, not caused
  by anything: in `jet_cad_2d`, the two `generate_document_test`
  fingerprints; in `jet_cad_2d_flutter`, the five text-ladder goldens.
- **Never invent output.** Every finding must rest on code you read
  (cite `file:line` at `e8b48a96`) or a command you ran (say which, and
  what it printed). If you could not verify something, say so and mark
  it unverified.

## What to attack (at least these)

1. **Facts F-1 to F-14.** Is each true at `e8b48a96`, line references
   included? Is anything relevant missing (another production
   `RemoveNodeCommand` or `AddNodeCommand` caller, another permission
   profile, another place that reads components on removed handles,
   another expander, another place components are attached to nodes)?
2. **D-1's all-or-nothing.** Is check → `addNode` → `restore` truly
   exact for every refusal? Can `restore` still throw after
   `checkRestorable` passes? What does `restore` do on a handle that
   already carries components (a dangling handle that had an orphan)?
   Is rejected design (A)'s defect real (the dangling-entry case, F-4)?
   Does `RemoveNodeCommand`'s order (index, snapshot, removeNode,
   detachAll) leave anything out?
3. **D-2's capabilities.** Every place that reads `capabilities` or
   `capability` of these commands or of compounds holding them (the
   dispatcher, the select tool's preflight, `CompoundCommand`,
   `ParametricReplay`, `TableLabelEdit`, the host controller, the
   spatial index, tile cache, anything else): does any break or change
   behaviour?
4. **D-3's re-parent idiom and D-4's removal of the parametric cleanup.**
   Is `lost ⊆ seeds` true? Does removing the cleanup change any outcome
   (history depth, undo order, `touched`, the 06 D6 guard, `_written`,
   page seeds, dissolve, a lost object whose node is removed by something
   other than `RemoveNodeCommand`)? Is "only `RemoveNodeCommand` removes a
   node" true?
5. **D-7's removal of `_detachFor`.** Is it really unreachable after
   D-1 for every path that deletes a table? Can table data sit on a
   handle that is removed some other way (a definition, a leaf, a
   replace, a load)? Does removing it change `TableLabelEdit`'s
   `capability`, `touched`, replay, or the "cheap path"?
6. **D-6 and schema 9.** Is "no schema concern" right? Mixed 0.4.0 and
   new terminals sharing plans? Undo/redo across save?
7. **Testing and mutants.** Is any fixture degenerate? Is any named
   mutant not killed by the named test, or equivalent? Is a likely
   defect left without a mutant? Are N-4's cases constructible through
   public API (e.g. the dangling entry)? Do TD7/HD12 really kill M-1,
   M-2, M-15 as F-14 claims?
8. **Anything else**: contradictions inside the spec, scope gaps, risks
   missed, wrong claims in Revision 2's change list.

## Output

Write your review to
`/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/confident-ardinghelli-29b386/.superpowers/sdd/2026-10-09-node-components-on-delete/spec-review.md`
(that one file is the only thing you may write in the worktree; it is
git-ignored). Structure:

- A verdict: **Approve**, **Approve with fixes**, or **Redesign needed**.
- Your setup (worktrees made, commands run).
- Findings, most severe first, numbered **V-1, V-2, …**, each with:
  severity (**Blocker** / **Major** / **Minor** / **Info**), the spec
  section, the claim, the evidence (`file:line` or command and output),
  why it matters, and a proposed fix.
- A short table of the facts F-1 to F-14: held / wrong / partly.

Then reply with the verdict and a one-line summary per finding.
