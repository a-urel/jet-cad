# Task 4 review: app, DocumentFiles (plan 12a, spec D9, D12 entitlements)

**Commit reviewed:** `0b3bf76` `feat(app): DocumentFiles for macOS and web`, parent `7b08ae9`. I reviewed it in the detached worktree `.claude/worktrees/plan-12a-review`, with HEAD at `0b3bf76`.

**Verdict: Approved.** There is no Important finding. There are two minor test gaps (m-1, m-2), one item for the human's web look (m-3), and two notes for Task 5 (n-1, n-2).

## Scope

The commit touches exactly the 9 files that the plan's Task 4 row and checklist name:
- the four `lib/document_files*.dart` files
- `test/document_files_test.dart` and `test/support/fake_document_files.dart`
- `pubspec.yaml`
- the two entitlements files

Nothing outside `apps/floor_planner` changed.

Nothing in `lib/` other than the four files mentions `createDocumentFiles`. `main.dart` does not import it yet; Task 5 adds that import.

`pubspec.lock` is git-ignored (`.gitignore:3:*.lock`) and is not tracked. After my `flutter pub get`, the tree has only the known `packages/jet_cad/analysis_options.yaml` rewrite.

## Spec conformance (D9, D12, R-6, S-15, S-16, T-12)

**The interface** matches the D9 block and the plan's result records exactly. The doc comments carry the contract: cancel is null, failure is a throw, and a location is opaque.

**The conditional export** follows the plan: stub by default, `_io` if `dart.library.io`, `_web` if `dart.library.js_interop`. Probe S2 (the order swapped) passes on the VM. Neither order changes which file a platform selects, so the order is not load-bearing.

**`_io` (macOS):**
- `openFile` and `getSaveLocation` are called with `[kJetplanTypeGroup]`.
- The path is returned **unchanged** as the location (S-16), and nothing is appended.
- `write` is `File(path).writeAsBytes(bytes, flush: true)`, and `writesInPlace` is true.
- I checked the upstream source, `file_selector_macos 0.9.5+1`:
  - `getSaveLocation` passes `suggestedName` as `nameFieldStringValue` and `allowedFileTypes` from the group, then returns the panel's path as-is.
  - A group with only `extensions` is accepted on macOS; the `ArgumentError` fires only when the group has no extensions, no UTIs and no MIME types.
  - The podspec needs macOS 10.15, and the app's `MACOSX_DEPLOYMENT_TARGET` is 12.0.

**`_web`:**
- `open` goes through `openFile` and returns `location: null`.
- `saveLocation` passes the prompt's answer through `jetplanFileName`: null or blank means cancel, otherwise the suffix is added.
- `write` creates a `package:web` `Blob` of type `application/json`, then an object URL, then an anchor with `download = name`, then `click()`, then `revokeObjectURL`.
- `writesInPlace` is false.
- It has no `cross_file` import and no `saveTo` (R-6).
- The prompt is a constructor argument, and the interface has no `BuildContext` (T-12).

**Dependencies:**
- `file_selector: ^1.1.0` and `web: ^1.1.0`.
- They resolve to `file_selector 1.1.0`, `file_selector_macos 0.9.5+1`, `file_selector_web 0.9.5`, `file_selector_platform_interface 2.7.0` and `web 1.1.1`.
- `cross_file 0.3.5+5` comes in transitively, which is expected.

**Entitlements:** both files parse with `plistlib`. `com.apple.security.files.user-selected.read-write` is `True` in `Release.entitlements` and in `DebugProfile.entitlements`, and the existing keys are kept.

**Purity greps on `lib/`:**
- `dart:io` appears only at `document_files_io.dart:6`.
- `package:web` appears only at `document_files_web.dart:16`.
- `cross_file` does not appear in `lib/` or in `pubspec.yaml`.

## Tests (DF1 to DF6) and the testing bar

The fixtures are not degenerate:
- DF1 covers null, empty and blank names, trimming, a name already carrying the suffix, a different extension, and the traps `myjetplan` and `jetplan`.
- DF3 and DF4 use mixed scripts (file, cancel, throw, file), and the unscripted call comes after the scripted ones.
- DF5 changes the caller's buffer between writes, and puts a failure between two successes.
- DF6 holds two writes, completes one with a value and the other with an error, then releases the hold.
- DF3 and DF6 also cover a location that is present and one that is absent, and a `writesInPlace` that is not the default.

The throw fixture is `FileSystemLikeError`, which is neither an `Exception` nor a `StateError`, so it is distinct from the fake's own throw.

## Mutants

For every mutant I backed the file up with `cp` to `scratchpad/p12r4-<name>.bak`, mutated it, ran `CI=true flutter test test/document_files_test.dart`, restored it with `cp`, and ran `diff`. Every `diff` exited 0.

I wrote the mutants myself in `scratchpad/p12r4-mutants.py`; they are not the implementer's script. The logs are at `scratchpad/p12r4-<name>.log`. Line numbers refer to `test/document_files_test.dart`.

### The implementer's named mutants, re-fired

All of them reproduce as reported.

| # | Mutation | Red | Line |
|---|---|---|---|
| J1 | no `trim()` | DF1 | 15 |
| J2 | `endsWith(kJetplanExtension)` | DF1 | 24 |
| J3 | always append | DF1 | 19 |
| J4 | blank not a cancel | DF1 | 14 |
| J5 | the group's extension written `'.jetplan'` | survives, equivalent | `XTypeGroup.extensions` strips the dot (`_removeLeadingDots`, platform interface 2.7.0 `x_type_group.dart:73`) |
| J5b | the group has no `extensions` | DF2 | 32 |
| F1 | `open` answers last in, first out | DF3 | 53 |
| F2 | bytes copied when `open` is called | DF3 | 54 |
| F3 | an unscripted `open` is not counted | DF3 | 65 |
| F4 | `saveLocation` calls not recorded | DF4 | 89 |
| F5 | `saveLocation` answers last in, first out | DF4 | 78 |
| F6 | a failed write not recorded | DF5 | 110 |
| F7 | `failNextWrite` sticky (`.first`) | DF5 | 108 (103 is the async frame) |
| F8 | recorded bytes not copied | DF5 | 113 |
| F9 | `holdWrites` ignored | DF6 | 135 |
| F10 | `writesInPlace` defaults to false | DF6 | 125 |
| F11 | an unscripted `saveLocation` is not counted | DF4 | 88 |

### My own mutants, at seams the named ones miss

| # | Mutation | Red | Line |
|---|---|---|---|
| R1 | appends to the **untrimmed** typed name | DF1 | 18 |
| R2 | returns the untrimmed name when it already ends in `.jetplan` | DF1 | 20 |
| R3 | label `'Jet plans'` | DF2 | 34 |
| R4 | the group also allows `json` | DF2 | 32 |
| R5 | the fake's `open` drops the scripted location | DF3 | 55 |
| R6 | `openCalls` counts only scripted calls | DF3 | 66 |
| **R7** | `holdWrites` checked before `failNextWrite` | **survives** | see m-1 |
| R8 | a held write is completed at once | DF6 | 137 |
| R9 | a write records `name` as its location | DF5 | 111 |
| R10 | `scriptSaveLocation` returns the name as the location | DF4 | 81 |
| R11 | `scriptOpenCancel` scripts nothing | DF3 | 56 |
| R12 | only the first held write is kept in `heldWrites` | DF6 | 135 |

### Probes of the conditional selection and the web build

I ran these with `scratchpad/p12r4-probes.py`, plus a re-run of W1 and S1 with their logs kept. Every file was restored and every `diff` exited 0. The temporary probe test files were deleted.

- **W0.** I added a temporary `import 'document_files.dart'` to `main.dart` and called `createDocumentFiles(...)` in `main()`. `flutter build web --release` exited 0 with `✓ Built build/web`.
- **W1.** With the same import, I passed `bytes` to `revokeObjectURL` in `_web`. The build exited 1 with `lib/document_files_web.dart:74:31: Error: The argument type 'Uint8List' can't be assigned to the parameter type 'String'`. The web build therefore compiles `_web` once `main.dart` reaches it.
- **W2.** With the same import, I changed `flush: true` to `flush: 1` in `_io`. The web build exited 0, so `_io` is not compiled for the web. `flutter analyze` exited 1 with an error at `lib/document_files_io.dart:54:53`.
- **Analyze reads `_web` and `_stub` too.** I made a type error in each. `flutter analyze` exited 1 with errors at `lib/document_files_web.dart:74:31` and `lib/document_files_stub.dart:9:28`.
- **S0.** A temporary VM test asserting `createDocumentFiles(askName: …).writesInPlace` is true and that the runtime type is `IoDocumentFiles` passed.
- **S1.** Dropping the `if (dart.library.io)` line made the S0 probe fail (exit 1). The whole of `document_files_test.dart` stayed green (+6); see m-2.
- **S2.** Swapping the order of the two conditions left the S0 probe green, so the swap is equivalent.

## Findings

### Important

None.

### Minor

**m-1. The fake's precedence between `failNextWrite` and `holdWrites` is documented but not tested.**
- The fake's doc comment (`fake_document_files.dart:17-21`) says a write fails when `failNextWrite` has queued an error, and is held only otherwise.
- R7 swaps that order and survives, because no test sets both.
- The risk is low. A later host test that relies on the order and sees it swapped would hang or fail visibly; it would not pass silently.
- The fix is one test: set `holdWrites = true`, call `failNextWrite(e)`, then expect the write to throw with `heldWrites` still empty. R7 then goes red.
- This could go into Task 9's sweep.

**m-2. Nothing in the suite pins the conditional selection.**
- S1 shows that dropping the `dart.library.io` line leaves every committed test green. The macOS build would then use the stub, which throws `UnsupportedError`. Today only the human's macOS look would catch that.
- Task 5 does not close the gap by itself, because the host's tests inject `FakeDocumentFiles` and the app itself goes through the selection.
- A two-line VM test closes it and never touches a panel: `createDocumentFiles(askName: …)` is not a stub and `writesInPlace` is true. That is the S0 probe, and S1 turns it red.
- The implementer raised the same point and did not add the test because the plan says "no test of the real implementations". I read this as a test of the selection, not of an implementation. It is the controller's ruling.

**m-3. The web download uses a detached anchor and revokes the URL synchronously.**
- The spec's sequence is followed literally, and it is valid under the File API: a navigation resolves the blob URL at the time of the click.
- Upstream `cross_file`'s `saveFileAs` does it differently: it attaches the anchor to a DOM container before `click()`.
- The human's web look should confirm that a download actually lands, ideally in Safari and Firefox as well as Chrome. This is the implementer's deviation 4.

### Notes for Task 5 (not defects of Task 4)

**n-1. A titled document opened on the web has `location == null`.**
- `write` takes a non-null `Object location`, and `WebDocumentFiles.write` ignores the location and downloads as `name`.
- D9 says "on web, a titled document's Save downloads under the current name without asking". So the host must pass some non-null location there, such as the name, for a titled but location-less document when `!writesInPlace`.
- Task 5's brief or reviewer should check that path.

**n-2. The web build gate does not yet compile `document_files_web.dart`.**
- Until `main.dart` imports `document_files.dart`, which is Task 5, the plan's web build gate compiles nothing of the web implementation. W0 and W1 above supplied that proof for Task 4.
- Task 5's reviewer should confirm that the import lands.
- Upstream's web `openFile` resolves a cancel through the input's `cancel` event. On browsers without that event (Safari before 16.4), the picker's future never completes, and the busy flag would stay set. This is upstream behaviour, recorded only.

## The four deviations and three precisions

**Deviations**

1. **`createDocumentFiles({required askName})` on every platform: accept.** The plan asks for web construction with the prompt. One factory signature is the natural seam for a conditional export. `_io` ignores `askName` and is `const`. The stub throws.
2. **`jetplanFileName` is shared, and blank means cancel and names are trimmed: accept.** Otherwise a blank name would download as `" .jetplan"`. The rule is pure and DF1 pins it (J1–J4, R1 and R2 are all red). The case-sensitive suffix check (`Plan.JETPLAN` becomes `Plan.JETPLAN.jetplan`) follows "lacks it" literally, and is harmless.
3. **The picked file's object URL is revoked after the read: accept, and it is correct.** `file_selector_web 0.9.5`'s `dom_helper.dart` creates `URL.createObjectURL(file)` for each picked file and never revokes it. `cross_file`'s web `readAsBytes` fetches that URL with an XHR and completes before the `finally` runs. The `XFile` is then discarded. This is the same concern as R-6.
4. **Synchronous revoke after `click()` on a detached anchor: accept for now.** It meets the spec, and m-3 routes it to the human's web look.

**Precisions**

5. **The fake's extras (`failNextWrite`, `scriptSaveLocationThrow`, the call counters, `unscriptedCalls`): accept.** Tasks 5 and 8 need failed saves. Every extra is pinned by a red mutant except the precedence in m-1.
6. **The test file is named `test/document_files_test.dart`: accept.** The plan names no file.
7. **`web: ^1.1.0` rather than a copy of `>=0.5.1 <2.0.0`: accept.** It is a subset of `file_selector_web`'s range and resolves to the same `web 1.1.1`. It is also the API the web file uses.

The implementer's items found outside scope:
- **Transitive `cross_file`:** confirmed in `pubspec.lock`.
- **Dart and Flutter floor:** confirmed. `file_selector_web 0.9.5`'s pubspec declares `sdk: ^3.10.0` and `flutter: ">=3.38.0"`, and the app declares `^3.5.0` and `>=3.24.0`.
- **First macOS plugin:** plausible, and it cannot be checked on Linux.

The ledger already carries the controller's rulings on all three.

## Gates (review worktree, `CI=true`, `PATH=/root/flutter/bin:$PATH`)

| Package | Command | Result | Exit |
|---|---|---|---|
| engine | `dart test` | `+1106 -2: Some tests failed.` Only the two standing failures in `generate_document_test.dart` ("the default document is the one Plan 2 measured…", "both text fractions default to zero…") | 1 (standing) |
| engine | `dart analyze` | No issues found! | 0 |
| engine | `dart format --set-exit-if-changed` | 159 files (0 changed) | 0 |
| render | `flutter test` | `+974 ~1 -7: Some tests failed.` Only the standing failures: `text_ladder` rungs 1–5 and `text_lod_ladder` rungs 1–2 | 1 (standing) |
| render | `flutter analyze` | No issues found! | 0 |
| render | `dart format` | 178 files (0 changed) | 0 |
| app | `flutter test` | `+526: All tests passed!` (520 + 6) | 0 |
| app | `flutter analyze` | No issues found! | 0 |
| app | `dart format` | 112 files (0 changed) | 0 |
| app | `flutter build web --release` | `✓ Built build/web` ("Wasm dry run succeeded") | 0 |

The engine and render counts are unchanged from the brief's baseline. The app's count is 520 plus the 6 new tests.

At the end, `git status --short` shows only ` M packages/jet_cad/analysis_options.yaml`, the known rewrite by `pub get`.
