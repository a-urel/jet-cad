# Task 5b brief — the Task 5 review's I-1, m-1, m-2, m-4

Implementer, branch `plan-12a/document-lifecycle`, worktree
`/home/user/jet-cad/.claude/worktrees/plan-12a` (HEAD = Task 6's commit,
on top of Task 5's efb8700). Read `CLAUDE.md`, and in
`.superpowers/sdd/plan-12a/`: `t5-report.md`, `t5-review.md` (I-1, m-1,
m-2, m-4, and its probes P3, P4, P5; copies of the reviewer's probe file
are at `/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/p12r5_probe_test.final.dart`),
`t6-report.md` (what Task 6 changed). Test-only; no `lib` change (if a
test cannot be written without one, stop and report).

1. **I-1**: in `test/document_host_test.dart`, New and Open sample from a
   **titled** document (opened from the fake with a location, then edited
   through a real tool off-origin and saved or left clean): after each,
   name `Untitled`, file name null, location null, the title `Untitled —
   jet-cad`; and a following Cmd+S (or the Save step) asks for a location
   (a Save As) rather than writing in place. Mutant R3 (`replace` keeps
   `fileName ?? _fileName` and the location) must go red.
2. **m-1**: the post-frame disposal: right after a swap flow returns the
   old document is not disposed; after one `pump()` it is. Mutant R1 (the
   old document disposed synchronously in `replace`) red.
3. **m-2**: a Save As whose `saveLocation` throws (`scriptSaveLocationThrow`)
   shows the error dialog, returns false, leaves the document dirty and
   busy cleared. Mutant R10 (the throw uncaught) red.
4. **m-4**: DH5 gains the premise `expect(old.commands.onBeforeMutate,
   isNotNull)` before the swap.

Re-fire M-12a-19, 20, 21 afterwards to confirm they stay red. Procedure:
backups under
`/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/p12t5b-`,
mutate, run, `cp` back, `diff` exit 0. NEVER `git checkout --` a .dart
file. `CI=true`; `export PATH=/root/flutter/bin:$PATH`. Never synthesize
output. Gates: app `flutter test`, `analyze`, `format`. Commit
`test(app): a replaced titled document forgets its file` with the two
trailers; do not push. Write `t5b-report.md` in the ledger directory and
return it.
