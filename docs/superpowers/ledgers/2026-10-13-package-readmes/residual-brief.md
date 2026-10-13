# Residual fix (the human: "1. evet"), one commit, before the merge

Open after the final re-review (Ruling R11): STATUS.md's 0.7.2 release checklist
("Resume here") lacks (a) a step 0 and (b) a runnable pana lower-bounds command; the
results note's "Final review" section claims both were added.

1. STATUS.md, Resume here, the 0.7.2 checklist:
   (a) Insert, before "1. Engine", a step 0: the human merges `feat/package-readmes`
       into `main`, runs `git push origin main`, and waits for CI on that merge commit
       to be green (all jobs) before any publish; that commit is `<merge commit>` in the
       steps below.
   (b) In the renderer's and the planner's steps, replace the pointer with the recipe
       this repository used for 0.7.1 (docs/superpowers/ledgers/2026-10-13-publish-host-packages/task-2-brief.md:219),
       written as commands, run after the package's dependencies are on pub.dev at 0.7.2:
       ```bash
       rm -rf /tmp/jet-cad-pana && mkdir -p /tmp/jet-cad-pana
       git archive <merge commit> packages/jet_cad_2d_flutter | tar -x -C /tmp/jet-cad-pana
       rm -rf /tmp/jet-cad-pana/packages/jet_cad_2d_flutter/test /tmp/jet-cad-pana/packages/jet_cad_2d_flutter/build /tmp/jet-cad-pana/packages/jet_cad_2d_flutter/shaders
       dart pub global run pana --no-warning /tmp/jet-cad-pana/packages/jet_cad_2d_flutter
       ```
       (the planner: its own directory, removing `test/`, `build/` and `tool/`), and say
       what to read: the "Support up-to-date dependencies" section's lower-bounds line
       (pana runs `pub downgrade` itself), which must pass before `dart pub publish`; if
       pana is not activated, `dart pub global activate pana`. Note that the copy is not
       a git checkout, so pana's repository-URL check fails there (as in 0.7.1's record);
       that line is not the gate.
   Keep the rest of the checklist as it is; keep each `cd` in the
   `"$(git rev-parse --show-toplevel)/packages/<pkg>"` form (make step 1 the same form).
   Also smooth STATUS.md:3 into one clean sentence (main carries release 0.7.0 and its
   tags; the three packages are on pub.dev at 0.7.1; 0.7.2 is in flight, below).
2. docs/superpowers/notes/2026-10-13-package-readmes-results.md, "Final review": correct
   item 2's text to say what is true now (step 0 and the pana commands were added in
   this residual commit after the re-review found them missing), and add a short
   "Residuals" line: the re-review's verdict, Ruling R11, the human's "1. evet", this commit.
3. Checks: `cd tool/ci && dart test`; `dart run tool/ci/check_guide.dart`; `git status --short`
   clean after the commit. Commit message ends with
   `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never stage analysis_options.yaml.
