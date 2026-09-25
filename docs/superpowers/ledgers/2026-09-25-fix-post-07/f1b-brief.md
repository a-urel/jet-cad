# F1b brief — the foreground follows the paper

You are the implementer for follow-up F1b on branch `fix/post-07`, worktree
`/home/user/jet-cad/.claude/worktrees/fix-post-07`. Work only there. Read
`CLAUDE.md` first.

## Where things stand
- F1 (`c960d1e`, reviewed Approved): `DocumentStyleResolver(document,
  {foreground = 0xFFFFFF})` resolves every ACI 7 to `foreground` (0xRRGGBB;
  ArgumentError outside 0..0xFFFFFF). The shell (`apps/floor_planner/lib/main.dart`)
  owns one `DocumentStyleResolver(_document, foreground: 0x000000)`, passed
  through `PlannerView.resolver` to `DraftCanvas`, which rebuilds its painter
  when the resolver instance changes. Test A17 in `test/planner_draw_test.dart`.
- F2+F3 (panel focus) have also been committed on this branch; don't touch them.
- The reviewer's finding: the Page panel (`page_panel.dart`) offers paper
  swatches White 0xFFFFFFFF, Ivory 0xFFFAF6EC, Grey 0xFFEDEDED, **Blueprint
  0xFF1F3A5F** (navy). Hard-wired black makes ByLayer drafting nearly
  invisible on Blueprint (it was white there before F1).

## The human's decision (binding)
The foreground follows the paper: **black on light paper, white on dark
paper**, decided by the page background's luminance. The shell swaps its
resolver when the paper colour changes. **Walls keep their concrete black
(`kWallColor`) — unchanged.**

## Scope
1. A pure function choosing the foreground from a paper ARGB: pick whichever
   of black and white has the higher WCAG contrast ratio against the paper
   (relative luminance with sRGB linearisation; ties → black). Put it where
   it fits best (engine next to the resolver if it reads as a general rule,
   else the app); doc comment says why. Ignore the paper's alpha.
2. The shell: the resolver's foreground comes from the page component's
   `background` at startup, and is re-evaluated whenever the page changes
   (every route: the swatch, undo/redo of a page edit, a loaded document).
   Build a **new resolver only when the chosen foreground actually changes**
   (White → Ivory keeps the same instance; White → Blueprint swaps it).
   Find how the shell owns/observes `_page` (PageComponent) today.
3. Rewrite the two "Amended by fix/post-07" paragraphs (spec 05 D2 in
   `docs/superpowers/specs/2026-09-23-drawing-tools-design.md`, spec 07 D3 in
   `docs/superpowers/specs/2026-09-24-walls-design.md`) so they state the
   final rule accurately (the host gives the resolver a foreground; the
   floor planner derives it from the paper; walls stay concrete black, so on
   Blueprint a wall is black while drafting is white). Correct the
   `kWallColor` comment in `wall.dart` if it now says anything false.

## Tests (a test lands only if a named mutant turns it red)
- The pure function: White, Ivory, Grey → black; Blueprint → white; plus a
  mid-grey near the crossover on each side (compute the crossover — for
  pure greys it is where the luminance ≈ 0.179 — and put one fixture just
  above and one just below), so a sloppy threshold (e.g. 0.5 on the raw
  byte) goes red.
- App: start on White, draft a line with L → resolves 0xFF000000 through the
  canvas's own resolver; pick Blueprint in the Page panel (the real
  swatch) → the same line resolves 0xFFFFFFFF; undo → black again. White →
  Ivory keeps the identical resolver/painter instance.
Suggested mutants: M-F1b-a the shell ignores the paper (fixed black);
M-F1b-b threshold inverted; M-F1b-c raw-byte threshold at 0.5 (no
linearisation); M-F1b-d the resolver rebuilt on every page change; M-F1b-e
not re-evaluated on undo (if your structure can separate it).
Mutant procedure (binding): `cp` the file to a backup in
`/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/`,
mutate, run, `cp` back, `diff` (exit 0). NEVER `git checkout --` a .dart
file. Prefix every test command with `CI=true`. Flutter/Dart at `/root/flutter/bin`.

## Gate
```
cd packages/jet_cad_2d && CI=true dart test && dart analyze && dart format --output=none --set-exit-if-changed .
cd packages/jet_cad_2d_flutter && CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
cd apps/floor_planner && CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed . && flutter build web --release
```
Standing failures, and only these: engine -2 (two hash tests in
`test/testing/generate_document_test.dart`), render ~1 -7 (text_ladder rungs
1-5, text_lod_ladder rungs 1-2).

## Commit
One commit, English, ending with exactly:
```
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_013XiH3QE4FtMMNUjbASxiEv
```
Restore any modified `analysis_options.yaml` (yaml only); never commit one.
Stage only your own files (`git add <paths>`), never `git add -A`. Do not push.

## Report
Commit hash; files; where the function lives and why; gate lines verbatim
from real output; each mutant: edit, command, red test and line (or
survived, honestly), restore + diff; deviations and why.
