# Task 5 report — `chrome_style.dart`, `page_fit.dart`, `PageNotifier`, the fixture

## What I implemented

Exactly as specified in the task brief (verbatim code blocks), with no
deviation:

- `test/support/page_fixture.dart` — the standard fixture: `standardPage()`
  (A4 landscape, 1:50, origin (7350, −1230)), `standardCamera()` (a
  `CameraController` seeded with a zoomed/panned `ViewportTransform`),
  `kChromeSize` (800×600), and `documentWithPage()` (a `DraftDocument` with
  `PageComponent` registered and attached to the root handle).
- `test/page_fit_test.dart` — one test: `fitToPage` fits the sheet rect (not
  document extents), keeps the sheet centred and confirms the y-flip.
- `test/page_notifier_test.dart` — four tests: seeding from the document
  before any event; following apply/undo/redo through the change stream;
  silence on an unrelated edit and on a `==` value; re-reading on
  `notifyLoaded()` and no further listening after `dispose()`.
- `lib/src/chrome_style.dart` — the ruler/grid/page-break constants
  (`kRulerThickness`, `kMajorTickPixels`, `kMinorTickPixels`,
  `kBreaksMinSheetPixels`, `kSheetEdgeColor`, `kMajorGridColor`,
  `kMinorGridColor`, `kPageBreakColor`, `kRulerBackground`, `kRulerInk`,
  `kRulerPointer`, `kRulerLabelSize`).
- `lib/src/page_fit.dart` — `fitToPage(PageComponent, Size)`, a thin wrapper
  over `ViewportTransform.fit(sheetWorldRect(page), viewport)`.
- `lib/src/page_notifier.dart` — `PageNotifier extends ValueNotifier<PageComponent?>`,
  seeded in the constructor from `document.components.get<PageComponent>(document.rootHandle)`,
  subscribed to `document.changes`, refreshing on any `CommandApplied` /
  `CommandUndone` / `CommandRedone` that touches the root handle and on any
  `DocumentLoaded` / `DocumentPurged`; cancels its subscription in `dispose`.
- `lib/jet_cad_2d_flutter.dart` — three new exports, inserted at sensible
  alphabetical positions: `chrome_style.dart` right after
  `canvas_draw_sink.dart` (ahead of the pre-existing `vertices_draw_sink.dart`
  anomaly, which I left untouched), and `page_fit.dart` / `page_notifier.dart`
  between `outline_cache.dart` and `reference_walk.dart`. The GPU-facade
  comment block was not touched.

## TDD evidence

### RED — fixture + both test files written, run before any implementation

```
$ CI=true flutter test test/page_fit_test.dart test/page_notifier_test.dart
...
test/page_fit_test.dart:12:20: Error: Method not found: 'fitToPage'.
    final fitted = fitToPage(page, kChromeSize);
                   ^^^^^^^^^
00:00 +0 -1: loading .../test/page_fit_test.dart [E]
  Failed to load "...page_fit_test.dart":
  Compilation failed for testPath=.../page_fit_test.dart: test/page_fit_test.dart:12:20: Error: Method not found: 'fitToPage'.
...
test/page_notifier_test.dart:11:15: Error: Method not found: 'PageNotifier'.
    final n = PageNotifier(doc);
              ^^^^^^^^^^^^
(× 4, once per call site)
00:00 +0 -2: loading .../test/page_notifier_test.dart [E]
  Failed to load "...page_notifier_test.dart": Compilation failed ...
00:00 +0 -2: Some tests failed.

Failing tests:
  .../test/page_fit_test.dart: loading .../test/page_fit_test.dart
  .../test/page_notifier_test.dart: loading .../test/page_notifier_test.dart
```

Confirms the tests fail for the right reason — the not-yet-implemented
symbols — not a typo or an unrelated compile error.

### GREEN — after implementing the three source files and the exports

```
$ CI=true flutter test test/page_fit_test.dart test/page_notifier_test.dart
...
00:00 +0: loading .../test/page_fit_test.dart
00:00 +0: .../test/page_fit_test.dart: fitToPage fits the sheet rect, not the extents
00:00 +1: .../test/page_notifier_test.dart: seeds from the document before any event
00:00 +2: .../test/page_notifier_test.dart: follows apply, undo and redo through the stream
00:00 +3: .../test/page_notifier_test.dart: an unrelated edit and an equal value do not notify
00:00 +4: .../test/page_notifier_test.dart: a load re-reads, and dispose stops listening
00:00 +5: All tests passed!
```

All 5 new tests pass.

`dart format --output=none --set-exit-if-changed .` flagged the three new
test files on the first pass (I hadn't hand-formatted them to the formatter's
own line-wrap choices). I ran `dart format` on exactly those three files,
reran the full test file pair to confirm no behavioural change, and reran the
format check clean:

```
$ dart format --output=none --set-exit-if-changed .
Changed test/page_fit_test.dart
Changed test/page_notifier_test.dart
Changed test/support/page_fixture.dart
Formatted 142 files (3 changed) in 0.27 seconds.
$ dart format test/page_fit_test.dart test/page_notifier_test.dart test/support/page_fixture.dart
Formatted test/page_fit_test.dart
Formatted test/page_notifier_test.dart
Formatted test/support/page_fixture.dart
Formatted 3 files (3 changed) in 0.01 seconds.
$ CI=true flutter test test/page_fit_test.dart test/page_notifier_test.dart
...
00:00 +5: All tests passed!
$ dart format --output=none --set-exit-if-changed .
Formatted 142 files (0 changed) in 0.26 seconds.
```

## Gate line (`packages/jet_cad_2d_flutter`)

```
$ CI=true flutter test
...
00:12 +777 ~1 -5: Some tests failed.

Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
$ echo $?
1
```

Exit code 1, and the failing set is exactly the five pre-existing
`text_ladder_golden_test.dart` failures named in the task brief — nothing
else failed. (677 passing tests at the branch point plus the 5 new ones, plus
the 1 skip already in the suite before this task, add up to the `+777 ~1 -5`
printed above; the brief's own count of "82 tests at the branch point" refers
to a different, earlier package-wide count and is not this suite's total.)

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.5s)
$ echo $?
0

$ dart format --output=none --set-exit-if-changed .
Formatted 142 files (0 changed) in 0.27 seconds.
$ echo $?
0
```

`git status --short` after every `flutter pub get`/test run showed no
`analysis_options.yaml` rewrite in this session, so no `git checkout --` was
needed.

## Files changed

- `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart` (modified —
  3 new exports)
- `packages/jet_cad_2d_flutter/lib/src/chrome_style.dart` (new)
- `packages/jet_cad_2d_flutter/lib/src/page_fit.dart` (new)
- `packages/jet_cad_2d_flutter/lib/src/page_notifier.dart` (new)
- `packages/jet_cad_2d_flutter/test/page_fit_test.dart` (new)
- `packages/jet_cad_2d_flutter/test/page_notifier_test.dart` (new)
- `packages/jet_cad_2d_flutter/test/support/page_fixture.dart` (new)

Commit: `34e27ce` — `feat(render): chrome style, fitToPage, PageNotifier`
(trailer verified: `git log -1 --format=%B | grep -c "Fable 5.1"` → `1`).

## Self-review

- **Completeness**: both test files carry every test from the brief, verbatim
  (5 tests total); the fixture has all four helpers plus the `kChromeSize`
  constant; `chrome_style.dart` carries all twelve constants from the brief;
  `PageNotifier` seeds synchronously in its constructor and cancels its
  subscription in `dispose`; the barrel gained exactly the three exports.
- **Quality**: every new file is a direct, unmodified transcription of the
  brief's code blocks (the brief is unusually prescriptive here, down to
  doc comments) — no additional logic, no scope creep. `flutter analyze`
  is clean; no `unused_import`/`unused_element` issues, which this package
  treats as errors.
- **Discipline**: no subagents dispatched, no mutation sweep run beyond what
  the brief asked for. `git status --short` was checked after every command
  that could touch `analysis_options.yaml`; none needed restoring.
- **Pristine output**: `git status --short` before commit showed only the
  seven intended files; nothing extraneous was staged.

## Concerns

- None outstanding. Task 8's promised three more exports (per the brief's
  "three exports now, six by Task 8" note) are out of this task's scope and
  untouched.
