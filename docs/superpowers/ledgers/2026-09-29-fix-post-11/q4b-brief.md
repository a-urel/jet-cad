# Q4b brief — the Q4 review's m1, m2, m3

You are a fresh implementer on branch `fix/post-11`, worktree
`/home/user/jet-cad/.claude/worktrees/fix-post-11` (HEAD `e82b4e7`). Work only
there. Read `CLAUDE.md`, then `.superpowers/sdd/fix-post-11/q4-review.md` and
the rulings after it in `progress.md` (binding). Commit; do NOT push. App files
only; stage only the files you change (`git add <paths>`).

1. **m1:** `selection_panel_test.dart` SE18's value list gains `1e19` (and one
   more value in [2^63, 2^64) if you like). Mutant M-R1 (the integer branch
   taken below 2^64 instead of 2^53) must go red.
2. **m2:** a Wall-tool test: `WallSettings(thickness: 1e25)` set through the
   tool's settings notifier (no panel), then a diagonal wall click
   (non-degenerate: turned, off the origin): no exception, no wall, history and
   handle seed unchanged — match what the tool does for a floor-violating
   setting (WT18). Mutant M-R4 (`_addWall` uses the floor-only predicate) must
   go red.
3. **m3:** `apps/floor_planner/lib/page_panel.dart` (~l.92, the scale field's
   text) and `apps/floor_planner/lib/main.dart` (~l.353, `_trimNumber`, the
   status line) use the same round-trip rule as `panelNumberText` — one shared
   function (move it somewhere both can import if needed; keep its
   `@visibleForTesting` test working). Tests: the page panel with a scale of
   1e20 committed by Enter, then Enter again on the unchanged text: still one
   step and the stored scale exactly 1e20 (read the existing page-panel tests,
   e.g. A18/A23, for the pattern); the status line's text for a 1e20 scale
   parses back to 1e20. Mutants: each site back to its old formula must go
   red.

Mutant procedure (binding): `cp` to a backup under
`/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/q4b-`
(yours alone), mutate, run, `cp` back, `diff` (exit 0). NEVER `git checkout --`
a .dart file. `CI=true` on every test command. Never synthesize output. Never
commit `analysis_options.yaml`.

Gate: `export PATH=/root/flutter/bin:$PATH; (cd apps/floor_planner && CI=true flutter test && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed . && CI=true flutter build web --release)` — app +500 at `e82b4e7`.

Commit(s) in English, ending with
```
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_013XiH3QE4FtMMNUjbASxiEv
```
Write `.superpowers/sdd/fix-post-11/q4b-report.md` and return it: hashes,
what changed, mutants with red lines, gate, deviations.
