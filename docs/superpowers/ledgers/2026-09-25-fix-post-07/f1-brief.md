# F1 brief — ACI 7 resolves to a foreground colour

You are the implementer for fix F1 on branch `fix/post-07`, worktree
`/home/user/jet-cad/.claude/worktrees/fix-post-07`. Work only there. Read
`CLAUDE.md` first; its non-negotiables bind you.

## The defect
Everything the app drafts is ByLayer on layer 0 (spec 05 D2; 06's boxes the
same). Layer 0 is ACI 7. `DocumentStyleResolver._rgbOf` maps ACI 7 through
`aciToRgb(7)` = 0xFFFFFF, and nothing contrasts it with the paper, so a line,
rectangle, circle or box renders white — invisible on the white page, barely
visible off it. Walls dodged it with a concrete `kWallColor`
(`apps/floor_planner/lib/parametric/wall.dart`).

## The human's decision (binding)
AutoCAD's rule: ACI 7 is the *foreground* colour. `DocumentStyleResolver`
takes a foreground RGB for ACI 7; its **default stays 0xFFFFFF**, so no
existing test or golden moves; the floor planner passes **black**. Drafting
stays ByLayer. `aciToRgb` itself is NOT changed.

## Scope
1. `packages/jet_cad_2d/lib/src/document/style_resolver.dart`: an optional
   named constructor parameter (e.g. `foreground`, 0xRRGGBB, default
   0xFFFFFF) used wherever an ACI 7 is turned into RGB — whichever route it
   arrives by (entity IndexedColor(7), ByLayer onto an ACI-7 layer, ByBlock
   inheriting an ACI 7 context, the document root's context). ACI 1–6, 8+,
   and every TrueColor — including TrueColor(0xFFFFFF) — are untouched.
   No per-entity allocation (the frame path is measured by
   `test/invariants/query_allocation_test.dart`). Doc comment says what and why.
2. `apps/floor_planner`: the canvas gets a `DocumentStyleResolver(doc,
   foreground: 0x000000)`. `DraftCanvas.didUpdateWidget` compares
   `widget.resolver != oldWidget.resolver`, so hold ONE instance per
   document (not a new one per build). Find where `DraftCanvas(` is built
   (`planner_view.dart`) and how the document is owned.
3. `wall.dart`'s `kWallColor` comment says "nothing in the renderer contrasts
   it with the paper" — now false. Keep `kWallColor` as is (walls are out of
   scope) and correct the comment.
4. Docs: an "Amended by fix/post-07" paragraph where spec 05 D2 speaks of
   ByLayer drafting (`docs/superpowers/specs/2026-09-23-drawing-tools-design.md`)
   and at spec 07 D3's colour amendment
   (`docs/superpowers/specs/2026-09-24-walls-design.md`). Short. Follow the
   existing "Amended at execution" paragraphs' style.

## Tests (the testing bar: a test lands only if a named mutant turns it red)
Fixtures must not be degenerate: use a foreground that is neither black nor
white (e.g. 0x123456) in engine tests, and include a TrueColor(0xFFFFFF)
entity and an ACI 1 entity as controls. Suggested mutants — fire each, record
the red test and line:
- M-F1a: the resolver ignores `foreground` (always `aciToRgb`).
- M-F1b: foreground applied only to an entity's own IndexedColor(7), not on
  the ByLayer route (or vice versa — whichever your code can separate).
- M-F1c: foreground replaces every rgb equal to 0xFFFFFF (kills a
  value-based shortcut: TrueColor white must stay white).
- M-F1d: the app drops the `foreground:` argument (an app test must see a
  drafted ByLayer entity resolve to 0xFF000000 through the canvas's own
  resolver, or its pixel on paper be dark).
- M-F1e (if you can pin it cheaply): the app builds a new resolver per build.
Mutant procedure (binding): `cp` the file to a backup in
`/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/`,
mutate, run, `cp` back, `diff` (exit 0). NEVER `git checkout --` a .dart
file. Prefix every test command with `CI=true`. Flutter/Dart are at
`/root/flutter/bin` (put it on PATH).

## Gate (all must hold before you commit)
```
cd packages/jet_cad_2d && CI=true dart test && dart analyze && dart format --output=none --set-exit-if-changed .
cd packages/jet_cad_2d_flutter && CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
cd apps/floor_planner && CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```
Standing failures on this Linux container, and ONLY these: engine -2 (two
hash tests in `test/testing/generate_document_test.dart`), render ~1 skip and
-7 (text_ladder rungs 1-5, text_lod_ladder rungs 1-2). Baseline: engine +972
-2, render +931 ~1 -7, app +142. Also `cd apps/floor_planner && flutter
build web --release` must print `✓ Built`.

## Commit
One commit, message in English, e.g. `fix: ACI 7 resolves to a foreground
colour; the floor planner draws it black`, ending with exactly:
```
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_013XiH3QE4FtMMNUjbASxiEv
```
`git status --short` before committing: if any `analysis_options.yaml` is
modified (`flutter pub get` rewrites them), restore it with
`git checkout -- <that yaml>` (yaml only) — never commit one. Do not push.

## Report
Commit hash; files changed; each gate line verbatim (copied from real
output — never synthesize); each mutant: the edit, the command, the red
test name and line, restore + diff result; any deviation from this brief
and why.
