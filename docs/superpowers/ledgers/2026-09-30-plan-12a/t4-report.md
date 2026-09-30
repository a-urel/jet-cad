# Task 4 report: app, DocumentFiles (plan 12a, spec D9, D12 entitlements)

**Commit:** `0b3bf76` `feat(app): DocumentFiles for macOS and web` on
`plan-12a/document-lifecycle` (parent `7b08ae9`). Not pushed. It has 9 files and +486 lines:
`lib/document_files.dart`, `lib/document_files_io.dart`,
`lib/document_files_web.dart`, `lib/document_files_stub.dart` (all new),
`test/document_files_test.dart` and `test/support/fake_document_files.dart`
(new), `pubspec.yaml`, `macos/Runner/Release.entitlements`,
`macos/Runner/DebugProfile.entitlements`. `pubspec.lock` is git-ignored
(`.gitignore:3 *.lock`, confirmed with `git check-ignore -v`). `flutter pub
get` rewrote `packages/jet_cad/analysis_options.yaml`, which is left
unstaged and was not committed.

## The API as landed

`lib/document_files.dart` holds only pure Dart plus `file_selector`'s `XTypeGroup`:
```dart
export 'document_files_stub.dart'
    if (dart.library.io) 'document_files_io.dart'
    if (dart.library.js_interop) 'document_files_web.dart';

const String kJetplanExtension = 'jetplan';
const XTypeGroup kJetplanTypeGroup =
    XTypeGroup(label: 'Jet plan', extensions: <String>[kJetplanExtension]);
typedef DocumentNamePrompt = Future<String?> Function(String suggested);

abstract interface class DocumentFiles {
  Future<({String name, Uint8List bytes, Object? location})?> open();
  Future<({String name, Object location})?> saveLocation(String suggestedName);
  Future<void> write(Object location, String name, Uint8List bytes);
  bool get writesInPlace;
}

String? jetplanFileName(String? typed); // null/blank -> null; trim; append ".jetplan" unless it ends in it
```
Every platform file exports
`DocumentFiles createDocumentFiles({required DocumentNamePrompt askName})`:
- **`_io` (`IoDocumentFiles`, const):**
  - `open` calls `openFile(acceptedTypeGroups: [kJetplanTypeGroup])` then `readAsBytes`. The name is the path's base name and the location is the path.
  - `saveLocation` calls `getSaveLocation(acceptedTypeGroups: [...], suggestedName:)`. The returned **path is the location, unchanged** (S-16), and the name is its base name.
  - `write` calls `File(path).writeAsBytes(bytes, flush: true)`. A location that is not a `String` throws an `ArgumentError`.
  - `writesInPlace` is true, and `askName` is ignored.
- **`_web` (`WebDocumentFiles(askName)`):**
  - `open` goes through `file_selector`'s `openFile`. The name is `XFile.name`, the location is null, and the object URL is revoked after the read.
  - `saveLocation` is `jetplanFileName(await askName(suggested))`: null means cancel, otherwise it returns `(name: n, location: n)`.
  - `write` builds a `package:web` `Blob([bytes.toJS], type: application/json)`, calls `URL.createObjectURL`, clicks `HTMLAnchorElement()..href..download = name`, and calls `URL.revokeObjectURL` in a `finally`.
  - `writesInPlace` is false. There is no `cross_file` import and no `saveTo` (R-6).
- **`_stub`:** `createDocumentFiles` throws `UnsupportedError`.

`pubspec.yaml` gains `file_selector: ^1.1.0` (resolved 1.1.0, macos 0.9.5+1, web 0.9.5) and `web: ^1.1.0` (resolved 1.1.1). The spec's range for `web` is the one `file_selector_web` already resolves, and 1.1.1 is inside its `>=0.5.1 <2.0.0`. I used `^1.1.0` because the web file calls the `HTMLAnchorElement()` constructor, which the 1.x API has.

Both entitlements files now have `com.apple.security.files.user-selected.read-write` set to `<true/>`.

**FakeDocumentFiles** (`test/support/fake_document_files.dart`, P-5):
- **Constructor:** `FakeDocumentFiles({bool writesInPlace = true})`.
- **Scripting `open`:** `scriptOpen(name:, bytes:, location:)` (it copies the bytes), `scriptOpenCancel()`, `scriptOpenThrow(e)`.
- **Scripting `saveLocation`:** `scriptSaveLocation(name:, location:)`, `scriptSaveCancel()`, `scriptSaveLocationThrow(e)`.
- **Answer order:** both queues answer first in, first out.
- **Unscripted calls:** a call with nothing scripted throws a `StateError` and counts it in `unscriptedCalls`. A host test can then detect an unexpected call even though the host catches the throw.
- **Call records:** `openCalls` counts calls to `open`, and `saveLocationCalls` lists every suggested name.
- **Writes:** `writes` records every `write` call as `(location, name, bytes-copy)`, including calls that fail or are still held.
  - `failNextWrite(e)` makes exactly the next write fail.
  - `holdWrites` makes each write return the future of a `Completer`, stored in `heldWrites` for the test to complete.

## Tests (`test/document_files_test.dart`, 6 new; app 520 → 526)

| Test | What it pins |
|---|---|
| DF1 | `jetplanFileName`: null, `''` and `' \t '` mean cancel. It trims white space. It appends the suffix only when the name does not end in `.jetplan`, and does not double it. Another extension is kept (`plan.v2`). `myjetplan` and `jetplan` get the suffix, because ending in the letters is not ending in `.jetplan`. |
| DF2 | `kJetplanExtension == 'jetplan'`. The type group's extensions are `['jetplan']`, `allowsAny` is false, and the label is `Jet plan`. |
| DF3 | The fake's `open` answers in scripted order: file, cancel, throw, file. The scripted bytes are a copy, and a location is optional (null). An unscripted call throws a `StateError` and is counted, and `openCalls` is 5. |
| DF4 | `saveLocation` answers in order: cancel, place, throw. An unscripted call throws and is counted. `saveLocationCalls` records all four suggested names in order. |
| DF5 | `write` records every call, including a failed one. `failNextWrite` fails only the next write. The recorded bytes are a copy (the caller's buffer is mutated afterwards). |
| DF6 | With `holdWrites`, a write completes only when the test completes it, with a value or with an error. Turning `holdWrites` off lets writes complete by themselves. `writesInPlace` defaults to true and holds what was passed. |

The real macOS and web implementations have no test, as the plan requires. The `jetplanFileName` rule is the part of the web implementation that can be tested on the VM, so it lives in the shared file and DF1 pins it.

## Mutants

Each mutant was applied by `cp` backup under `.../scratchpad/p12t4-`, then the mutation, then a run, then `cp` back. Every `diff` exited 0. They ran through `.../scratchpad/p12t4-mutants.py` with `CI=true flutter test test/document_files_test.dart` and were re-fired on the final committed tree. Line numbers are in `test/document_files_test.dart`.

| # | File | Mutation | Red test | Line |
|---|---|---|---|---|
| J1 | document_files.dart | no `trim()` | DF1 | 15 (`' \t '` → isNull) |
| J2 | document_files.dart | `endsWith(kJetplanExtension)` (no dot) | DF1 | 24 (`myjetplan`) |
| J3 | document_files.dart | always append | DF1 | 19 (`Kitchen.jetplan`) |
| J4 | document_files.dart | blank not a cancel | DF1 | 14 (`''` → isNull) |
| J5 | document_files.dart | extension written `'.jetplan'` | **survives: equivalent** | `XTypeGroup.extensions` strips a leading dot itself (`file_selector_platform_interface` 2.7.0 `_removeLeadingDots`). Recorded as equivalent; DF2 carries a comment saying so |
| J5b | document_files.dart | type group without `extensions` (any file) | DF2 | 32 |
| F1 | fake | `open` answers last in, first out | DF3 | 53 |
| F2 | fake | scripted bytes copied at call time, not at script time | DF3 | 54 |
| F3 | fake | unscripted `open` not counted | DF3 | 65 |
| F4 | fake | `saveLocation` not recorded | DF4 | 89 |
| F5 | fake | `saveLocation` answers last in, first out | DF4 | 78 |
| F6 | fake | a failed write not recorded | DF5 | 110 |
| F7 | fake | `failNextWrite` sticky (`.first`) | DF5 | 108 (the third write throws) |
| F8 | fake | recorded bytes not copied | DF5 | 113 |
| F9 | fake | `holdWrites` ignored | DF6 | 135 |
| F10 | fake | `writesInPlace` defaults to false | DF6 | 125 |
| F11 | fake | unscripted `saveLocation` not counted | DF4 | 88 |

**Probes that `flutter analyze` sees all three platform files and the web build compiles the web one.** Each probe was a backup, a mutation and a restore, with every restore `diff` exiting 0, and nothing was committed.
- **`flutter analyze` reads all three files.** I appended an unused private function to each of `_web`, `_io` and `_stub`. Analyze reported `unused_element` and `unused_local_variable` in all three: `lib/document_files_io.dart:60`, `lib/document_files_stub.dart:10` and `lib/document_files_web.dart:78`.
- **Nothing in `main.dart` reaches `document_files.dart` yet; Task 5 adds that import.** Without it, `flutter build web` does not compile these files. To prove the web side, I temporarily added `import 'document_files.dart'` to `main.dart` and made it call `createDocumentFiles(askName: …).writesInPlace` (restored afterwards, diff 0):
  - **With the valid code:** the build exited 0.
  - **Web mutant** (`<JSUint8Array>[bytes]` in place of `bytes.toJS`): the build exited 1 with `Error: A value of type 'Uint8List' can't be assigned to a variable of type 'JSUint8Array'` at `document_files_web.dart`. So the web build compiles the `_web` file.
  - **io mutant** (`flush: 1`): the web build exited 0 (`✓ Built build/web`), so `_io` is not compiled on the web. `flutter analyze` reported `error • The argument type 'int' can't be assigned to the parameter type 'bool' • lib/document_files_io.dart:54:53`.

## Gates (final tree, CI=true, PATH=/root/flutter/bin)

| Package | Command | Summary | Exit |
|---|---|---|---|
| engine | `dart test` | `+1106 -2: Some tests failed`. The two standing failures are "both text fractions default to zero…" and "the default document is the one Plan 2 measured…" | 1 (standing only, unchanged) |
| engine | `dart analyze` | No issues found! | 0 |
| engine | `dart format --set-exit-if-changed` | 159 files (0 changed) | 0 |
| render | `flutter test` | `+974 ~1 -7: Some tests failed`. The seven standing failures are text_ladder rungs 1–5 and text_lod_ladder rungs 1–2 | 1 (standing only, unchanged) |
| render | `flutter analyze` | No issues found! | 0 |
| render | `dart format …` | 178 files (0 changed) | 0 |
| app | `flutter test` | `+526: All tests passed` (520 + 6) | 0 |
| app | `flutter analyze` | No issues found! | 0 |
| app | `dart format …` | 112 files (0 changed) | 0 |
| app | `flutter build web --release` | `✓ Built build/web` (the log also says "Wasm dry run succeeded") | 0 |

Greps on `lib/`:
- `dart:io` appears only in `document_files_io.dart`.
- `package:web` appears only in `document_files_web.dart`.
- `cross_file` appears nowhere.

I reworded the comments so that these greps match imports only.

## Deviations and precisions (for the reviewer to accept or reject)

1. **Construction seam.** Each platform file exposes `createDocumentFiles({required DocumentNamePrompt askName})`. The plan names only the web constructor argument. The macOS version ignores `askName`, and the stub throws `UnsupportedError`.
2. **`jetplanFileName`** lives in the shared file, so it is pure and tested on the VM.
   - It also treats a **blank** name (white space only) as a cancel and trims surrounding white space. The spec only says an empty name is a cancel.
   - The suffix check is case-sensitive, so `Plan.JETPLAN` becomes `Plan.JETPLAN.jetplan`. This follows the spec's "lacks it" literally.
3. **Web `open` revokes the object URL** that `file_selector_web` creates for the picked file (`dom_helper.dart` `URL.createObjectURL(file)`, never revoked upstream), once the bytes are read. The spec does not mention this. It is the same concern as R-6.
4. **Web `write` revokes synchronously right after `click()`**, as the spec says, and the anchor is never attached to the DOM. Current browsers accept both. The human's web look should confirm that the download actually lands.
5. **The fake has more than P-5 lists:** `failNextWrite`, `scriptSaveLocationThrow`, `openCalls`, `saveLocationCalls`, `unscriptedCalls`. Tasks 5 and 8 need failed saves ("Save + failure", "failed … saves from dirty").
6. The test file is named `test/document_files_test.dart`, since the plan names none for the fake's test.
7. **`web: ^1.1.0`**, not a copy of `file_selector_web`'s `>=0.5.1 <2.0.0`. The reason is in the API section above.

## Found outside scope (reported, not fixed)

- **Transitive `cross_file`.** `file_selector` brings in `cross_file 0.3.5+5`, because `XFile` is its type, and it is in `pubspec.lock`. Task 9's "no `cross_file`" grep must mean no direct dependency or import. It cannot mean absence from the lock.
- **The Dart and Flutter floor is higher than `pubspec.yaml` declares.** `file_selector_web 0.9.5` requires Dart `^3.10.0` and Flutter `>=3.38.0`. The app's `pubspec.yaml` still declares `sdk: ^3.5.0` and `flutter: ">=3.24.0"`. The effective floor is now higher than what is declared.
- **First macOS build with a plugin.** `file_selector_macos` is the app's first macOS plugin, and `macos/` has no Podfile. The first `flutter build macos` or `flutter run -d macos` on a Mac will probably add CocoaPods or Swift Package Manager integration: a Podfile or package reference, plus changes to `Runner.xcodeproj/project.pbxproj` and `Flutter-*.xcconfig`. Those files should be committed when that happens. Linux cannot verify it. `GeneratedPluginRegistrant.swift` (git-ignored) already registers `FileSelectorPlugin`.
- **`flutter pub get` rewrote `packages/jet_cad/analysis_options.yaml`.** This is the known behaviour. The file is left modified in the worktree and not committed.
- **A possible later test.** A one-line check that `createDocumentFiles` resolves to `IoDocumentFiles` on the VM would pin the conditional export's order, which today only the web build and the human's look catch. The plan forbids tests of the real implementations, so I did not add it.
