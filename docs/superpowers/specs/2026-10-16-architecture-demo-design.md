# The architecture demo (sub-project 3b) — design

**Date:** 2026-10-16. **Status:** revision 1, written after the human
approved the design section by section in chat (*"onaylıyorum"*, twice).
No independent Opus review: the human paused them to save cost (decision
2); the controller self-reviewed this file.

**Binds:** the umbrella spec
[2026-10-13-kit-architecture-design.md](2026-10-13-kit-architecture-design.md)
(A1-A17), the contract spec
[2026-10-13-kit-contract-design.md](2026-10-13-kit-contract-design.md),
the 2a spec
[2026-10-14-plan-library-design-mode-design.md](2026-10-14-plan-library-design-mode-design.md),
the 2b spec
[2026-10-14-plan-library-service-mode-design.md](2026-10-14-plan-library-service-mode-design.md)
and the 3a spec
[2026-10-15-architecture-kit-design.md](2026-10-15-architecture-kit-design.md)
(its Appendix A.3 hands this spec the old app's tests). Their rules hold
here unless a section below says otherwise.

**Branch:** `feat/architecture-demo`, cut by hand from `main` at
`a156c5a2` (`origin/main` an ancestor, 0 commits ahead of `main`),
worktree `.claude/worktrees/architecture-demo`.

**Companion:** [2026-10-16-architecture-demo-test-audit.md](2026-10-16-architecture-demo-test-audit.md),
the per-case disposition of every old app test this spec owns (B6).

## Decisions taken in the brainstorm (the human, 2026-10-16)

1. **`apps/floor_planner` stays beside the new app** (*"Yan yana kalsın"*).
   `apps/architecture_demo` is a new app; the old one is removed with the
   old packages in sub-project 4. The human can run both side by side.
2. **No independent Opus reviews for now** (*"şimdilik bağımsız opus
   review'ları durdur, tasarruf etmemiz gerek"*). Per-task reviews and the
   whole-branch review run on Sonnet; specs are self-reviewed.
3. **The approach: port the host onto the new controller** (approved with
   the design's first section). The file layer is copied; the document host
   is rewritten over `PlanController` and `PlanEditor`. The file layer is
   not moved into `jet_cad_2d_plan` (the library leaves files to the host
   on purpose, through `onNew`/`onOpen`/`onSave`/`onSaveAs`), and no
   minimal demo without web or the exit guard.
4. **Scope** (approved with the design's first section): the architecture
   kit only, design mode only, en/de/tr, macOS and web.

## Decisions taken by the controller (delegated, from the test audit)

5. **Busy.** The app's `busy` covers its own flows (New, Open sample, Open,
   Save, Save As, the export write, exit) and, through wrappers, the
   library's page flows: the app passes `PlanEditor` an `onExportDialog`
   that sets `busy` around the dialog, and a `PagePrinter` that sets it
   around the platform print job. While `busy`, the app's file callbacks
   return without acting. The buttons do not grey out (`PlanEditor` has no
   host hook for it); `PlanPermissions` is not toggled, since the library
   already holds Export and Print during its own flows (2a PF7). Why: the
   smallest mechanism that keeps the old intent "no second flow starts
   during a write". Cost if wrong: one more host hook in the library later.
6. **Error titles.** A failed write of an export (the app's `onExport`) is
   titled "Export failed", as today. A failure the library reports through
   `onPageFlowError` carries no flow kind; it is titled in neutral words
   ("The page could not be exported or printed"). Why: guessing the kind
   from the wrappers mislabels a print whose render fails before the
   printer runs. Cost if wrong: a title, and a field on the library's
   callback later.
7. **The armed symbol survives New and Open.** The library keeps
   `armedSymbol` on the controller across `newPlan` and `load` (the active
   tool resets to Select). The old SS7 expected it cleared; SS7 splits
   (C1.10's rule from 3a): the "-open" case pins today's library
   behaviour, the intent half pins that the active tool is Select and the
   gallery shows no armed cell after New.
8. **"Open sample"** is not a `PlanEditorAction`: it lives in
   `PlanEditorBar.leading`, with the document's name and dirty mark, in a
   widget of bounded width.
9. **The file extension stays `.jetplan`** and the app keeps its
   `FileKind` (jetplan, pdf, png). A file of the old format fails
   `decodePlan`'s manifest check and is reported in the open error dialog;
   no migration (the rewrite drops backward compatibility).
10. **Library gaps.** Where the audit found a `PlanEditor` behaviour that
    no library test pins (file buttons gated mid-shape, the Cmd variants
    of the file and print chords, the redo chords, per-platform tooltip
    glyphs, tab and cell focus, the gallery's search text across a tab
    switch, Export and Print following a page attached, undone and
    redone), the ported app test pins it through the app. If such a test
    finds a library defect, the fix lands in `jet_cad_2d_plan` in this
    branch, in its own task, with a library test beside the app test (3a's
    Task 21 precedent). A gap that is not app behaviour (`PrintingPagePrinter`'s
    channel, Escape in `PlanExportDialog`) gets a library test.

## B1. The app

`apps/architecture_demo`: a Flutter app, `publish_to: none`, a workspace
member, macOS and web (the old app's runner settings, entitlements and
`web/` files copied and renamed).

- **Dependencies:** `jet_cad_2d_plan`, `jet_cad_2d_kit_architecture`,
  `file_selector`, `web`, `pdf` (for `PdfPageFormat`, if the print flow
  still names it), `flutter_lints` (dev). Never `jet_cad_floor_plan` or
  `jet_cad_restaurant_symbols`: a test (B6, N1) fails when the pubspec or
  any Dart file under `lib/` or `test/` names either.
- **`main.dart`:** `ensurePlanFonts` before the first frame (a failure is
  reported, not fatal, as today); one `PlanController(kits:
  [architectureKit], symbols: PlanSymbolLoader())` for the app's life; the
  `MaterialApp` with the old seed colour in a light and a dark theme, the
  plan library's localization delegates and supported locales plus the
  app's own words.
- **Symbols:** the kit's furniture library (it ships with the kit,
  `symbols: [furnitureSource]`); no other source.
- **One controller.** New, Open sample and Open replace the plan inside
  the same controller (`newPlan`, `newPlan(build: buildSampleFlat)`,
  `load`); the editor, its panels and the font cache stay.

## B2. The session and the host

- **`DocumentSession`** keeps what the controller does not: the file name
  (null while untitled), the location (opaque, from the files object),
  the untitled name in the app's language, and `busy`. **Dirty is the
  controller's** (`controller.dirty`); the session computes none. The web
  tab's title is `name — jet-cad`, with `• ` in front while dirty.
- **`DocumentHost`** runs the flows, one at a time (`busy`):
  - **New:** ask to save when dirty, then `newPlan()`; untitled.
  - **Open sample:** ask to save when dirty, then
    `newPlan(build: buildSampleFlat)`; untitled, clean, nothing to undo.
  - **Open:** ask to save when dirty, read the file, `load(text)`; named
    after the file. A `PlanFormatException` or a read failure shows the
    open error dialog and changes nothing.
  - **Save / Save As:** `save()` (the controller settles pending input
    first), write through the files object, then `markSaved()`. A failed
    write leaves the plan dirty and shows the save error dialog. Save on an
    untitled plan is Save As.
  - **Export:** `PlanEditor.onExport` hands the app a `PlanExport`; the app
    asks for a location (kind from the export's extension) and writes the
    bytes. `PlanEditor.exportName` is the document's name.
  - **Print:** the library's flow, through the app's busy-setting printer
    wrapper over `PrintingPagePrinter`.
  - **Exit:** the exit guard asks to save when dirty; while `busy` the exit
    waits for the flow, as today.
- The "Save changes?" dialog, the name prompt (web Save As) and the error
  dialogs are the old app's, in the app's words.

## B3. The file layer

Copied from `apps/floor_planner/lib` with its tests: `document_files.dart`
(the interface, `FileKind`, the type groups, the name prompt typedef),
`document_files_io.dart`, `document_files_web.dart`,
`document_files_stub.dart`, `exit_guard*.dart`. It names no plan type; the
only change is the import of the app's words.

## B4. The app's words

`app_strings.dart`, en/de/tr: the untitled name, the menu's "Open
sample", the dialogs (save changes, name prompt, the error titles of
decision 6), the file type labels. Words the plan library already has are
not repeated. The old app's `app_words_test` cases port (B6).

## B5. What the app does not do

No service mode, no restaurant symbols, no host data, no custom
exporters or importers beyond the library's built-in PDF and PNG, no
iOS, Android or desktop other than macOS.

## B6. Tests

**The old tests.** The audit
([companion](2026-10-16-architecture-demo-test-audit.md)) classifies the
194 cases Appendix A.3 hands to 3b: **89 PORT, 73 COVERED, 26 SPLIT, 6
DROPPED**. Each row names its destination, its covering test (found by
grep), its two halves, or its reason. The plan carries each row to a task;
the exit gate checks every row is closed. The porting rules of 3a hold: a
ported assertion is never weakened; a case is never skipped; a case whose
premise is impossible splits into a "-open" case (what the app does now)
and its intent, marked "Decided: premise impossible". A COVERED row is
re-checked by the task that owns its file: the named test must still
exist and still assert the intent.

**The fakes.** The old app's in-memory files object and recording printer
move with the tests; every test runs a real `PlanController` with the
real `architectureKit`.

**New tests**, each with a named mutation that turns it red:
- **N1, the boundary:** the pubspec and every Dart file under `lib/` and
  `test/` name neither old package. Mutation: an import of
  `jet_cad_floor_plan` in a scratch file.
- **N2, the sample:** Open sample on a clean plan gives a plan with walls,
  rooms and furniture, clean and with nothing to undo; one edit makes it
  dirty and New then asks to save. Mutation: open the sample with `load`
  of an encoded copy built dirty, or skip the ask.
- **N3, the title:** the tab title follows `controller.dirty` (an edit
  adds `• `, a save removes it, an undo back to the save point removes it).
  Mutation: the title reads a session flag set only by the app's flows.
- **N4, the round trip:** Save then Open gives the same encoded text.
  Mutation: write `save()`'s text of a different state.
- **N5, the language:** switching the locale renames an untitled plan
  ("Untitled" → "Adsız") and leaves a named one. Mutation: the untitled
  name read once at launch.
- **N6, busy:** while an export dialog or a print job is pending, New,
  Open and Save do nothing and the exit waits. Mutation: drop either
  wrapper.

**Gates per task:** the app's `flutter test`, `flutter analyze` and
`dart format --output=none --set-exit-if-changed .`; a task that touches a
package runs that package's gates too. `analysis_options.yaml` is never
committed (the new app's own copy is committed once, in the scaffold task,
as 3a's packages were).

## B7. The exit gate

- The app's tests, analysis and format green; `jet_cad_2d_plan`,
  `jet_cad_2d_kit_architecture` and `jet_cad_2d_integration` green if the
  branch touched them; the engine packages and the old packages and
  `apps/floor_planner` unchanged (`git diff --stat main` names none of
  them, apart from a library-gap fix of decision 10).
- `flutter build macos` and `flutter build web` succeed.
- Every audit row closed.
- One manual smoke run on macOS: launch, Open sample, edit, Save, New,
  Open the saved file, a screenshot of the reopened plan in the results
  note. Its output is transcribed, never written from memory.
- One Sonnet review of the whole branch and its fix wave (decision 2);
  STATUS and a results note; the ledger archived onto the branch.
- Then the human is told the demo runs on the new packages.

## Out of scope

- Sub-project 4: the restaurant kit, `apps/restaurant_demo`, the README
  pictures, the host guide, the parity table (A14), removing the old
  packages and `apps/floor_planner`.
- 3a's four "For the human" items (the human decides them).
- `PlanObject.liveTypeIdOf`: the demo does not need it; carried to
  sub-project 4 as a contract candidate.
- iOS, Android, Windows, Linux.

## Risks

- **Library gaps.** Decision 10 may turn up library defects mid-plan; each
  is a task of its own, so the plan grows. The audit lists eight.
- **Busy through wrappers.** The wrappers see the export dialog and the
  print job but not the render between them; a Save clicked in that gap
  starts. The library serialises its own page flows, and `save()` settles
  pending input first, so the worst case is a save made during an export's
  render, which reads the same plan.
- **Platform runners.** Copying the macOS and web runners carries the old
  app's bundle id and entitlements; the scaffold task renames them and
  `flutter build` checks them.

## Amendments to other specs

- **Umbrella A11:** `apps/floor_planner` stays beside
  `apps/architecture_demo` until sub-project 4 removes it with the old
  packages (decision 1).
- **3a spec, Appendix A.3:** the 3b rows are closed in this spec's
  companion audit.

## Revision history

- **Revision 1:** the design approved in chat; the audit's decisions
  (5-10) taken by the controller.
