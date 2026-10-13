### Task 9: The record — results note, STATUS, the full gate

**Files:**
- Create: `docs/superpowers/notes/2026-10-13-package-readmes-results.md`
- Modify: `STATUS.md` (In flight, Resume here, the release checklist), `roadmap/00-README.md` only if its Status table lists releases (check; leave it otherwise)

- [ ] **Step 1: The results note**: what landed per task with commit SHAs; the font route (manifest or fallback); the ratio and every PNG's size; the archive sizes before and after per package; the machine and Flutter that generated the PNGs; every named mutation (M-R10a/b, M-FT1/2, M-SH3, M-SS-a/b/c, M-RM-a/b/c, M-T8) with the line that showed it red; the spec's amendments A1–A4; anything found and not fixed.

- [ ] **Step 2: STATUS.** "In flight": this branch, spec, plan, note. "Resume here": the release checklist of spec D11, in order, each step a command:

```bash
cd packages/jet_cad_2d
dart pub publish --dry-run
dart pub publish
git tag jet_cad_2d-v0.7.2 <merge commit>
git push origin jet_cad_2d-v0.7.2
```

then the renderer and the planner the same way, each preceded by pana's lower-bounds section on the package's archive once its dependencies are on pub.dev, and a note: run from the package directory, never the root ("private package"); if `main` has moved past the merge commit, publish from a worktree at that commit (`git worktree add /tmp/jet-cad-0.7.2 <merge commit>`). After the planner: D7's pub-only probe (STATUS's existing recipe), and a look at the three pages on pub.dev (images, gallery, Funding block).

- [ ] **Step 3: The full gate**, every command run and its last line quoted in the note: the three package gates of CLAUDE.md with the standing comparison; `tool/screenshots` test/analyze/format; `tool/readme_probe` analyze/format; `cd tool/ci && dart test`; `check_guide`, `check_readmes`, `check_screenshots`; three dry runs at 0 warnings; `git status --short` clean, no `analysis_options.yaml` in `git log --name-only main..HEAD`.

- [ ] **Step 4: Commit** the note and STATUS: `git commit -m "docs: package READMEs results and the 0.7.2 release checklist"`.

- [ ] **Step 5: The whole-branch review.** An Opus subagent reviews `main..HEAD` against the spec and this plan (the reviewer verifies claims itself; the note's outputs are claims). Apply its fixes in one wave or rule on each in the note; commit. If the plan ran subagent-driven, archive `.superpowers/sdd/2026-10-13-package-readmes/` to `docs/superpowers/ledgers/2026-10-13-package-readmes/` and commit. Then stop: the merge waits for the human's word.
