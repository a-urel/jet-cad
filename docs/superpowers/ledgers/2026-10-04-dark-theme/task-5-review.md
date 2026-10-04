# Task 5 review: the canvas UI fixes (D6a, D6b, D6c; M-DT-12, M-DT-13)

**Reviewed:** `37a1797..6e3fa02`, in a detached worktree at `/home/user/jet-cad/.worktrees/dark-review` (Flutter 3.47.6, `CI=true`). Scratch logs are in `scratchpad/review5/`.

## Verdict: Needs fixes (1 minor, test-only)

The implementation is correct against D6a, D6b and D6c. Every named mutant I re-fired is red, and all gates match the implementer's counts. My mutant O1 survives: `_paper` set *after* the foreground-flip early return in `_onPage`. Nothing pins the ordering that the code's own doc comment calls deliberate. I wrote a test that kills O1 and passes on the real code; it is below.

## Findings

1. **minor: the `_onPage` ordering is unpinned.**
   - **Where:** `packages/jet_cad_floor_plan/lib/src/host/service_view.dart:126-129`.
   - **Evidence.** Mutant O1 moves `_paper.value = _paperArgb();` below `if (next == _resolver.foreground) return;`. All 3 tests of `test/host/status_caption_test.dart` still pass (`+3: All tests passed!`). The only page-change test goes White to Blueprint, which flips ACI 7 too, so the early return is never taken. The code is right; the test does not cover the case the comment describes.
   - **The real case.** A translucent mid-tone host status flips the caption between two light papers while ACI 7 stays black. For example, `Color(0x991E1E1E)`:
     - over White it is `0x787878`, which takes black ink;
     - over Ivory it is `0x767470`, and over Grey `0x717171`; both take white ink;
     - `foregroundFor` of all three papers is `0x000000`.
     
     I computed these with the `foregroundFor` formula from `style_resolver.dart`.
   - **Fix (test-only).** Add a test to `test/host/status_caption_test.dart`. I ran exactly this test as a temporary file and then deleted it:
     - **On the real code:** `+1: All tests passed!`.
     - **Under O1:** red, with `Expected: '0xffffff' Actual: '0x202020'`.

     ```dart
     testWidgets('D6c: a page change that does not flip ACI 7 can flip the caption: '
         'White to Ivory with a mid-tone status', (tester) async {
       const smoke = Color(0x991E1E1E);
       final c = statusController(white);
       await pumpService(tester, c, ThemeMode.light);
       c.setTableStatus({'1': TableStatus(color: smoke, caption: 'Bill')});
       await tester.pump();
       final box = captionBox(tester);
       expectDarkCaption(await shoot(tester), box, 'smoke on White');
       final doc = c.activeDocument;
       doc.commands.execute(SetComponentCommand<PageComponent>(doc.rootHandle,
           doc.components.get<PageComponent>(doc.rootHandle)!
               .copyWith(background: 0xFFFAF6EC)));
       await tester.pump();
       await tester.pump();
       expectLightCaption(await shoot(tester), box, 'smoke on Ivory');
     });
     ```

     A premise line such as `expect(foregroundFor(0xFAF6EC), foregroundFor(0xFFFFFF))` would make the "no ACI 7 flip" part explicit.

## Line-by-line check

### `ServiceView` (D6c)

**Creation order.**
- `_paper` is a plain `final` field initialiser, so it exists before the `late final _statusPainter` is first read in `build`.
- The first `didChangeDependencies` sets it, after `_surfaceArgb` and before the first `build`. The White placeholder only reaches the painter's first rebuild when the paper really is White.
- At the first call to `didChangeDependencies` the notifier has no listeners yet, so setting it is harmless.
- Setting it during later `didChangeDependencies` calls (a theme switch) only calls `markNeedsPaint` on the status layer, which is legal during build. The no-page theme-switch test exercises this path.

**Set in `_onPage` before the early return.** This is correct (see finding 1 for the missing pin). If O1 were present, the White to Ivory/Grey case would keep stale ink until the next `didChangeDependencies`.

**Repaint merge.** `_paper` is a member of `[_c.camera, _c.tableStatuses, _changed, _paper]`. Mutant N4 is red.

**Disposed.** `_paper` is disposed in `dispose()`. `_page.removeListener(_onPage)` runs before it, so `_onPage` cannot write to a disposed notifier.

### `TableStatusPainter` (D6c)

**Rebuild condition.** The condition gains `_paperBuilt != paperArgb`, and `_paperBuilt` is assigned after `_rebuild`. Inside `_rebuild` the ink reads `paper.value` fresh: my mutant O4, which reads the stale `_paperBuilt` instead, is red.

**Cache and steady state.**
- **The cache key** is `(caption, colour, ink)`, with `ink` one of two const `Color`s.
- **No per-frame work.** `statusCaptionInk` / `over` run only in `_rebuild`. Nothing new runs per frame.
- **Measured.** SP12 counts `debugAllocations` at `made + 1` after the flip, unchanged over ten steady frames, with `debugCached == 2`.
- **Flipping back** re-allocates one paragraph, because the eviction drops the old one. That is still one per flip, which invariant 1 allows.

**`shouldRepaint`.** It gains `!identical(oldDelegate.paper, paper)`. Mutant O3 removes that term and survives. I agree it is unreachable in `ServiceView`, whose painter is a `late final`, and no test in the suite pins this painter's `shouldRepaint` for `document` or `statuses` either. It is a note, not a finding: if one is wanted, a one-line unit test would do, `painterFor(..., paper: a).shouldRepaint(painterFor(..., paper: b))` is true.

**`over`.**
- It uses straight alpha, `round(a*s + (1-a)*p)` per channel, and never reads the paper's alpha.
- I checked SP10 by hand: `0x99E53935` over White is (239.4, 136.2, 133.8), giving `0xEF8886`; over `0x1F3A5F` it is (149.8, 57.4, 69.8), giving `0x963946`.
- My premultiplied-maths mutant (O2) is red, with 6 failures.

**No `Color(foregroundFor(...))`.**
- The mapping to `kStatusCaptionOnLight` / `kStatusCaptionOnDark` is the only conversion. Both constants live in `canvas_palette.dart` (Task 1), with values `0xFF202020` and `0xFFFFFFFF`.
- The `const Color(0xFF202020)` literal is gone from the painter.

**Light theme.**
- The existing `table_status_painter_test.dart` expectations are unchanged. The only edit is the mechanical `painterFor` change: an optional `paper:` that defaults to White and also joins the merge.
- SP11 asserts that the demo's three statuses on White map to `0xFF202020`. SP12 reads the pixel `0x202020` on White.

### D6a (`page_panel.dart`)

- The selected border is `scheme.primary`, the others `scheme.outline`, with widths 2 and 1 unchanged.
- The scheme is read in the builder, so a theme switch follows.
- The test starts on Ivory (swatch 1), moves to Blueprint, checks all four swatches, and runs in both themes.

### D6b (`text_entry_overlay.dart`)

- The decoration has `filled: true` and `fillColor: colorScheme.surfaceContainerHighest`.
- M-DT-12 runs in the dark theme on White and, crossed, in the light theme on Blueprint. Each run has a premise that the sampled pixel is the paper before the field opens.

## Rulings

**R-C5-1: a dark opaque status takes the white caption in the light theme. Accept; consistent with D6c.**
- D6c makes the ink a function of the status colour over the *paper*. The theme does not enter at all when there is a page.
- The spec's phrase "so the light theme holds" holds for every status whose composite takes black ink. That covers the demo's three statuses on White, Ivory and Grey (SP11), and every existing pixel test and golden, all green.
- A `0xFF202020` caption on a dark opaque fill was unreadable, so the change is the intent of D6c, not a regression.
- Record it as a clarification in the spec's "Amended at execution": D7's caption identity covers statuses whose composite takes black ink.

**R-C5-2: removing `fillColor` is an equivalent mutant. Accept as equivalent.**
- Neither app sets an `inputDecorationTheme` (grep over `apps/` and `packages/` finds none). Material 3's filled default is `surfaceContainerHighest`, so under the shipping themes the mutant changes no pixel.
- **Recommendation: optional, not required.** A third M-DT-12 variant under `ThemeData(..., inputDecorationTheme: InputDecorationTheme(fillColor: <distinct colour>))` would kill the mutant. It would pin the spec's explicit choice, the scheme fill over a host input theme. It is cheap; add it if the file is touched again, for example in Task 6. Not blocking: it pins a configuration no app ships.

**R-C5-3: the ServiceView fixture runs at 0.07 px/mm. Accept.**
- The comment says why.
- The fixture is not degenerate:
  - the camera is not the identity (it is translated and Y-flipped);
  - the table is off the origin;
  - the tests run with no page and in both themes, and the White/Blueprint crossing runs under the dark theme.

**R-C5-4: `over` returns `0xRRGGBB` and lives in a library no barrel exports. Accept.** `foregroundFor` reads only the RGB bytes.

## "Found, not fixed": the caption overlaps the number label

**Pre-existing at `37a1797`; not caused by this task.**
- The diff does not touch the caption placement: `below = max(kStatusCaptionSize, half*scale + kStatusCaptionGap)` and the translate.
- The diff does not touch the label's geometry either. `packages/jet_cad_2d` and `packages/jet_cad_2d_flutter` are unchanged.

**Likely cause: the test font.** The label is `TextJustifyV.middle`, whose reference point is `(ascent - descent)/2` in font metrics (`text_geometry.dart:259`), scaled so that cap height equals the text height. Real digits span the baseline to the cap height, so with a real font they sit roughly centred on the anchor and the caption clears them by about the 2 px gap. In the test font, every glyph is a full em box reaching down to the descent, which matches the implementer's "0.68 of its height below the anchor".

**Not verified with the app's real font.** Task 7's service-view screenshot should look at a captioned table at around 0.25 px/mm. Do not fix it here.

## Gates (re-run by me, this container)

| Package | test | analyze | format |
|---|---|---|---|
| `jet_cad_floor_plan` | `+1198: All tests passed!` | No issues found! | 198 files (0 changed) |
| `jet_cad_2d_flutter` | `+1302 ~1 -7: Some tests failed`: exactly the standing 7 (text ladder rungs 1-5, text lod ladder rungs 1-2, all `RenderBackend.canvas`) | No issues found! | 218 files (0 changed) |
| `jet_cad_restaurant_symbols` | `+94: All tests passed!` | No issues found! | 13 files (0 changed) |
| `apps/floor_planner` | `+201: All tests passed!` | No issues found! | 44 files (0 changed) |
| `apps/restaurant_demo` | `+17: All tests passed!` | No issues found! | 3 files (0 changed) |
| `apps/dev_harness_2d` | `+82: All tests passed!` | No issues found! | 22 files (0 changed) |

These match the implementer's table exactly.

**Untouched files.** `git diff 37a1797..6e3fa02 --stat` over `packages/jet_cad_2d`, `packages/jet_cad_2d_flutter`, `*golden*`, `*invariants*` and `*analysis_options*` is empty. The commit touches 7 files, all in `jet_cad_floor_plan`. No `analysis_options.yaml` is committed: the worktree shows only the pub-get rewrite of `packages/jet_cad/analysis_options.yaml`, unstaged. The engine is untouched.

## Mutants (re-fired by me)

**Method.** `scratchpad/review5/mut.py` does the following for each mutant:
1. `cp` the file to a backup;
2. apply an exact-string edit, which must match exactly once;
3. run `flutter test` on the listed files;
4. `cp` the backup back and run `diff -q`.

Every mutant printed `restored diff= 0`. A final `sha256sum -c` of the 4 lib files against a pre-run snapshot printed OK for all four.

| ID | change | result |
|---|---|---|
| N1 caption fixed (named) | `TextStyle(color: const Color(0xFF202020)` | red `+12 -3`; `Expected 0xffffff Actual '0x583a53'` |
| N2 ink ignores paper (named) | `over(colour, 0xFFFFFFFF)` | red `+10 -5`; Expected white, Actual `0.1255` grey |
| N3 cache key without ink (named) | key `(caption, colour, kStatusCaptionOnLight)` | red `+12 -3`; SP12 `Actual '0x583a53'` |
| N4 `_paper` not in the repaint merge (named) | `_changed]` | red `+2 -1`; `Actual '0x202020'` |
| N5 `filled: false` (named) | | red `+3 -2`; `Expected 0x33353a Actual '0xffffff'` |
| N6 swatch `Colors.blue` (named) | | red `+3 -2`; `Actual: MaterialColor...` |
| N7 `_paper` not set in `didChangeDependencies` (named) | | red `+2 -1`; `Actual '0x202020'` |
| O1 (own) | `_paper` set after the early return in `_onPage` | **SURVIVES** `+3: All tests passed!` (finding 1); killed by the proposed test, `Expected '0xffffff' Actual '0x202020'` |
| O2 (own) | `over` with premultiplied maths, `(s + (1-a)*p).clamp(0,255)` | red `+9 -6` |
| O3 (own) | `shouldRepaint` without the paper term | survives `+15`; unreachable in `ServiceView` (note) |
| O4 (own) | `_rebuild` reads the stale `_paperBuilt ?? White` instead of `paper.value` | red `+12 -3` |
| O5 (own) | fill `surfaceContainerHigh` (the neighbouring role) | red `+3 -2`; `Expected 0x33353a Actual '0x282a2f'` |

## Degenerate fixtures

None found.
- **SP12:** a mirrored placement rotated 37°, at 0.2 px/mm, off the origin.
- **ServiceView tests:** no page (theme surface) in both themes, a White page under the dark theme, and White to Blueprint.
- **M-DT-12:** both crossings.
- **D6a:** a non-first swatch, both themes, and the selection moves.

The one gap is finding 1: the page change in the host tests always flips ACI 7 as well.
