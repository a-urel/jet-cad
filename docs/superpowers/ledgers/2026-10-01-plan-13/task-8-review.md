# Task 8 review: App, `FileKind` (spec D8 "DocumentFiles", M-13ac)

Reviewer: independent. Commit f181afc (range f625d80..f181afc), checked in the detached worktree
`.claude/worktrees/plan-13-review2`, after `flutter pub get` (only `packages/jet_cad/analysis_options.yaml` shows as modified, and it is not staged). I committed and staged nothing. I mutated files only through cp backup → sed → run → cp back, and `diff` exited 0 every time.

## Scope read
CLAUDE.md; spec D8 (DocumentFiles bullets), F-12, T-10 (`fileNameFor` sentence), T-11, M-13ac; plan Task 8; common.md, progress.md R-13-21, task-8-brief.md, task-8-report.md; the full diff.

## Checks

**FileKind.** `jetplan('jetplan','Jet plan','application/json')`, `pdf('pdf','PDF document','application/pdf')`, `png('png','PNG image','image/png')`, plus the getter `typeGroup = XTypeGroup(label:, extensions:[extension])`. These match plan and spec. Before this commit, the web write used `application/json` (old `document_files_web.dart:66`), so the jetplan MIME type does not change. `kJetplanTypeGroup` is kept for the open panels. FK4 checks that the jetplan group's label and extensions equal it.

**fileNameFor / jetplanFileName.** The body is the old one with `const suffix='.jetplan'` replaced by `'.${kind.extension}'`. I compared them differentially. I copied the old and the new bodies verbatim into a standalone script (`scratchpad/r8/cmp.dart`) and ran 24 inputs through both: null, `''`, `' '`, `' \t\n '`, `plan`, `' plan '`, `'\tplan\n'`, `plan.jetplan`, `' plan.jetplan '`, `plan.JETPLAN`, `plan.Jetplan`, `planjetplan`, `jetplan`, `.jetplan`, `plan.jetplan.jetplan`, `'plan.jetplan '`, `'plan. jetplan'`, `plan.pdf`, `plan.png`, `a b.c`, `Küche`, `plan.`, NBSP-wrapped, a trailing ZWSP. Real tail: `inputs=24 diffs=0`. For jetplan the behaviour is unchanged, including case sensitivity (`plan.JETPLAN` → `plan.JETPLAN.jetplan`). The existing DF1 table in `document_files_test.dart` also still passes.

**saveTypeGroupsFor.** It returns `[kind.typeGroup]`, a pure helper that the VM can test (FK5).

**io.** `getSaveLocation(acceptedTypeGroups: saveTypeGroupsFor(kind), ...)` returns the path unchanged, and `write` ignores `kind`. The open panel still uses `const [kJetplanTypeGroup]`. *Is returning the path unchanged right on macOS when the person types a name without an extension?* I read `file_selector_macos-0.9.5+1`, the version resolved in `pubspec.lock`:
- The Dart side flattens the groups into `AllowedTypes.extensions`.
- In `FileSelectorPlugin.swift`, `configure(panel:with:)` takes the macOS 11+ branch (the app's `MACOSX_DEPLOYMENT_TARGET = 12.0`, and `forceLegacyTypes` defaults to false). That branch sets `panel.allowedContentTypes = [UTType(filenameExtension: "pdf"|"png"|"jetplan")]`. It never sets `allowsOtherFileTypes`, so that stays false.
- `displaySavePanel` returns `selection?.path`, the panel's URL.
- With `allowedContentTypes` set and other types disallowed, NSSavePanel itself makes the chosen URL carry the allowed type's extension: it appends `.pdf`/`.png` to a bare name, and it refuses or asks about a conflicting one. That last step is AppKit behaviour (Apple's documented contract for `allowedContentTypes`). It is not in the plugin source, and I could not verify it on a Mac here.

So the plugin adds nothing. The panel does, and the returned URL is what the sandbox grants. Not appending is therefore correct and consistent with S-16 / R-13-21. `pdf` and `png` are system-declared UTTypes, so this is, if anything, more reliable than for `.jetplan`, which 12a already relied on. The app ships only `macos/` and `web/`, so no GTK or Windows panel (neither appends) is in play.

**web.** `fileNameFor(await askName(suggestedName), kind)` and `BlobPropertyBag(type: kind.mimeType)` are correct. `CI=true flutter build web --release` gives `✓ Built build/web`.

**Callers.** Grep of `saveLocation(` and `.write(` across `lib/` and `test/`:
- The only production caller is `document_host.dart:465` and `:482` (`saveLocation('${_session.name}.jetplan')` and `write(location, fileName, encoded.bytes)`). Both use the defaults and are unchanged.
- The implementers of `DocumentFiles` are Io, Web and Fake. The stub has no class, so nothing changes there.
- The test call sites in `document_files_test.dart` and `document_commands_test.dart` are unchanged and green.

**Fake.** `FakeWrite` gains `kind`. `saveLocationKinds` runs parallel to `saveLocationCalls`, and `saveLocationCalls` stays `List<String>`, so the existing comparisons are untouched. FK6 checks both lists, including a call made without a kind, which records jetplan.

## Mutants (re-fired by me; each run on `test/document_files_kind_test.dart` in the foreground, restored=0)
| id | mutation | result |
|---|---|---|
| M-13ac | document_files.dart:103 `'.${kind.extension}'` → `'.${FileKind.jetplan.extension}'` | red FK1, `Expected: 'plan.pdf'  Actual: 'plan.jetplan'` |
| M-8mime | :36 pdf `'application/pdf'` → `'application/json'` | red FK4, `Expected: 'application/pdf'  Actual: 'application/json'` |
| M-8io | :61 `[kind.typeGroup]` → `[FileKind.jetplan.typeGroup]` | red FK5, `Expected: 'PDF document'  Actual: 'Jet plan'` |
| M-8fake | fake:119 `kind: kind` → `kind: FileKind.jetplan` | red FK6, `Expected: [FileKind:FileKind.png, FileKind:FileKind.jetplan, FileKind:FileKind.pdf]` |
| M-8webmime | document_files_web.dart:68 `type: kind.mimeType` → `type: 'application/json'` | **survives the whole app suite**, `03:17 +901: All tests passed!` (as reported) |
| M-8webname | web:56 `fileNameFor(..., kind)` → `fileNameFor(..., FileKind.jetplan)` | **survives** (kind + document_files + document_commands tests, `00:15 +32: All tests passed!`) |
| M-8iocall | io:44 `saveTypeGroupsFor(kind)` → `saveTypeGroupsFor(FileKind.jetplan)` | **survives** (same 3 files, `+32: All tests passed!`) |

M-8webname is the spec's M-13ac as the spec words it ("the web save appends `.jetplan` to every kind"), placed at the web call site. The plan told the implementer to mutate `fileNameFor`, and the implementer did. But M-13ac's real failure mode, the call site passing a fixed kind, is not caught. T-10 in Task 9 will run through the fake, so it will not catch it either.

**Would a structural test (the T-11 precedent, `packages/jet_cad_2d_flutter/test/export/export_sources_test.dart`) be worth it?** Yes. It is cheap and kills all three survivors. I wrote a prototype in scratch only (`scratchpad/r8/document_files_sources_test.dart`, run from the app directory with `flutter test <abs path>`). It reads both files and asserts:
- io contains `acceptedTypeGroups: saveTypeGroupsFor(kind)`, and `kJetplanTypeGroup` occurs exactly once (the open panel);
- web contains `fileNameFor(await askName(suggestedName), kind)` and `BlobPropertyBag(type: kind.mimeType)`, and contains neither `application/` nor `jetplanFileName`.

Results:
- Clean: `00:00 +2: All tests passed!`
- M-8webmime: red.
- M-8webname: red.
- M-8iocall: red.
- An extra variant, io `const <XTypeGroup>[kJetplanTypeGroup]`: red.

All restored=0.

## Gates (run by me at f181afc)
- `CI=true flutter test` (app): `04:20 +901: All tests passed!` (895 + 6)
- `CI=true flutter analyze`: `No issues found! (ran in 4.8s)`
- `CI=true dart format --output=none --set-exit-if-changed .`: `Formatted 156 files (0 changed)`
- `CI=true flutter build web --release`: `✓ Built build/web`
- Engine and render: `git diff --name-only f625d80..f181afc -- packages | wc -l` → `0`. Both are unchanged, so I did not re-run them.

## Verdict: Approved with notes

## Findings
1. **Minor (test gap). Files: `apps/floor_planner/lib/document_files_web.dart:56,68` and `apps/floor_planner/lib/document_files_io.dart:44`.** The platform files' use of `kind` is pinned by nothing. The spec-level M-13ac (web call site passing a fixed kind) survives, as do a hard-coded MIME type and an io constant type group. *Fix:* add `apps/floor_planner/test/document_files_sources_test.dart` along the lines of the prototype above (T-11 precedent). It reads the two files and asserts the four call-site strings, the single `kJetplanTypeGroup` in io, and no `application/` literal or `jetplanFileName` in web. Record M-8webname, M-8webmime and M-8iocall as killed. You can land it in Task 8 as a follow-up or in Task 9 next to T-10. If it is not landed, R-13-21's "checked by analyze, the web build and review only" stands. Analyze and the web build do not catch any of the three.
2. **Info. File: `apps/floor_planner/lib/document_files.dart:58-61` (comment on `saveTypeGroupsFor`) and `document_files_io.dart:35-39`.** The claim that the panel enforces and appends the extension itself rests on NSSavePanel's `allowedContentTypes` behaviour. The plugin (`file_selector_macos` 0.9.5+1) only sets `allowedContentTypes` and returns `panel.url.path`, without appending anything. The claim is correct for the macOS-12 deployment target. Nobody has verified it on a device for `.pdf`/`.png`. *Fix:* none in code. Add "type `plan` in the Export… panel and get `plan.pdf`" to the human's macOS look in Task 11.
3. **Info. File: `apps/floor_planner/lib/document_files.dart:97-98`.** Matching is case-sensitive, so a web export typed `plan.PDF` downloads as `plan.PDF.pdf`. This is consistent with `jetplanFileName` (differential check: 24 inputs, 0 differences) and is recorded as R-13-21. No fix needed.
