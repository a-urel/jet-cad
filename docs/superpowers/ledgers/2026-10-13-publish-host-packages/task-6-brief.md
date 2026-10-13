### Task 6: The probe and the host guide on pub.dev (D6, D8, D9)

**Files:**
- Modify: `tool/ci/host_probe/pubspec.yaml.in`, `tool/ci/host_probe.sh`, `tool/ci/host_probe/lib/main.dart`, `tool/ci/host_probe/.gitignore`, `docs/host-guide.md` (§1 and a new subsection after §1's text, "The restaurant symbols"), `tool/ci/test/guide_test.dart`, `tool/ci/test/scripts_test.dart` (SC14)
- Create: `tool/ci/package_root.dart`, its test case in `scripts_test.dart`

**Interfaces:**
- Consumes: Task 5's `check_host_lock.dart ... --ref <sha>`.
- Produces: `dart run tool/ci/package_root.dart <probe dir> <package>` prints the absolute directory of `<package>` from `<probe dir>/.dart_tool/package_config.json` (its `rootUri`, resolved against the config file), exit 2 with a message when the package is absent.

- [ ] **Step 1: `package_root.dart`, test first**

Add to `scripts_test.dart`:

```dart
  test('SC17 package_root.dart prints a package\'s root from a config',
      () async {
    final dir = Directory.systemTemp.createTempSync('package_root');
    addTearDown(() => dir.deleteSync(recursive: true));
    Directory('${dir.path}/.dart_tool').createSync();
    File('${dir.path}/.dart_tool/package_config.json').writeAsStringSync(
        '{"configVersion":2,"packages":[{"name":"a","rootUri":"../x/a",'
        '"packageUri":"lib/"},{"name":"b","rootUri":"file:///abs/b",'
        '"packageUri":"lib/"}]}');
    final a = await Process.run('dart', ['run', 'package_root.dart', dir.path, 'a']);
    expect(a.exitCode, 0);
    // `../x/a` resolves against `.dart_tool/`, so the root is `<dir>/x/a`.
    expect((a.stdout as String).trim(), endsWith('/x/a'));
    expect(Directory((a.stdout as String).trim()).parent.parent.path,
        Directory(dir.path).resolveSymbolicLinksSync());
    final b = await Process.run('dart', ['run', 'package_root.dart', dir.path, 'b']);
    expect((b.stdout as String).trim(), '/abs/b');
    final none = await Process.run('dart', ['run', 'package_root.dart', dir.path, 'c']);
    expect(none.exitCode, 2);
  });
```

Run it — FAIL (no script). Write `tool/ci/package_root.dart`:

```dart
// Prints a package's root directory from a resolved project's
// .dart_tool/package_config.json (publishing spec D6): host_probe.sh
// copies the restaurant library from the package pub resolved.
//
//   dart run tool/ci/package_root.dart <project dir> <package>
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln('usage: package_root.dart <project dir> <package>');
    exit(2);
  }
  final config = File('${args[0]}/.dart_tool/package_config.json');
  final json = jsonDecode(config.readAsStringSync()) as Map<String, Object?>;
  for (final p in (json['packages'] as List).cast<Map<String, Object?>>()) {
    if (p['name'] != args[1]) continue;
    final root = config.uri.resolve(p['rootUri'] as String);
    stdout.writeln(root.toFilePath().replaceAll(RegExp(r'/$'), ''));
    return;
  }
  stderr.writeln('${config.path}: no package ${args[1]}');
  exit(2);
}
```

Note the relative `rootUri` resolves against the config file's URI (`.dart_tool/`), so `../x/a` is `<dir>/x/a`. Run SC17 — PASS. Add `package_root.dart` to the analyze and format file lists in `.github/workflows/ci.yml`'s `ci-tools` job and in Task 5 Step 4's command.

- [ ] **Step 2: The template**

`tool/ci/host_probe/pubspec.yaml.in`: header comment rewritten (*"The probe's pubspec … The dependency line a host writes (docs/host-guide.md §1), from pub.dev; the overrides take the four repository packages from git at the commit under test, and check_host_lock.dart --ref proves they did (publishing spec D6)."*). `environment: sdk: ^3.6.0`. Then:

```yaml
dependencies:
  flutter:
    sdk: flutter
  jet_cad_floor_plan: ^0.7.1

flutter:
  uses-material-design: true
  fonts:
    - family: Roboto
      fonts:
        - asset: packages/jet_cad_floor_plan/fonts/Roboto-Regular.ttf
  assets:
    - assets/restaurant.jetlib

dependency_overrides:
  jet_cad_2d:
    git:
      url: @URL@
      path: packages/jet_cad_2d
      ref: @REF@
  jet_cad_2d_flutter:
    git:
      url: @URL@
      path: packages/jet_cad_2d_flutter
      ref: @REF@
  jet_cad_floor_plan:
    git:
      url: @URL@
      path: packages/jet_cad_floor_plan
      ref: @REF@
  jet_cad_restaurant_symbols:
    git:
      url: @URL@
      path: packages/jet_cad_restaurant_symbols
      ref: @REF@
```

(No `dependencies:` entry for the restaurant package: the override puts it in the graph, F-11, so the released `main.dart` files that import it still analyse.)

- [ ] **Step 3: `host_probe.sh`**

- The clean line becomes (Review Focus 4: a copy left by an earlier run must not mask a copy step that no longer runs):

```bash
rm -rf "$probe/build" "$probe/.dart_tool" "$probe/pubspec.lock" \
  "$probe/assets/restaurant.jetlib" "$probe/lib/restaurant_names.dart"
```

- The lock check becomes `dart run "$ci/check_host_lock.dart" "$probe/pubspec.lock" --ref "$ref"`.
- After the lock check, before `flutter analyze`:

```bash
# Publishing spec D9: the probe carries the restaurant library as a host
# does, copied from the package pub resolved at this commit, its names'
# import pointed at the planner's barrel.
symbols=$(dart run "$ci/package_root.dart" "$probe" jet_cad_restaurant_symbols)
mkdir -p "$probe/assets"
cp "$symbols/assets/restaurant.jetlib" "$probe/assets/restaurant.jetlib"
sed 's#package:jet_cad_floor_plan/symbol_sources.dart#package:jet_cad_floor_plan/jet_cad_floor_plan.dart#' \
  "$symbols/lib/src/names.dart" > "$probe/lib/restaurant_names.dart"
```

The script has already done `cd "$probe"` by then; the paths above are absolute, so the block works from anywhere. Update the script's header comment: the probe resolves from pub.dev with overrides; the restaurant symbols are copied.

`tool/ci/host_probe/.gitignore`: add `/assets/restaurant.jetlib` and `/lib/restaurant_names.dart` with a comment *"Copied by tool/ci/host_probe.sh from the commit under test (publishing spec D9)."*

`scripts_test.dart` SC14: the expected clean line and lock-check line become the two above; add `final copy = at(r'symbols=$(dart run "$ci/package_root.dart" "$probe" jet_cad_restaurant_symbols)');` and expect `check < copy && copy < analyze`.

- [ ] **Step 4: The probe's `main.dart`**

- Remove `import 'package:jet_cad_restaurant_symbols/jet_cad_restaurant_symbols.dart';`; add `import 'dart:typed_data';` and `import 'restaurant_names.dart';`; add `rootBundle` to the `package:flutter/services.dart` `show` list.
- Add, at the top level (this exact text goes into the guide, Step 5):

```dart
/// The restaurant library, from this app's own assets (host guide, "The
/// restaurant symbols").
Future<Uint8List> readRestaurantLibrary() async {
  final data = await rootBundle.load('assets/restaurant.jetlib');
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

const SymbolLibrarySource restaurantSource = SymbolLibrarySource(
    name: 'restaurant',
    read: readRestaurantLibrary,
    names: restaurantSymbolNames);
```

- The loader: `sources: const [furnitureSymbolSource, restaurantSource],`.
- The header comment: the probe depends on the planner from pub.dev (overridden to the commit under test) and carries the restaurant library as a host does.

- [ ] **Step 5: The host guide**

§1 "The dependency" becomes:

- Opening: *"Add the planner from pub.dev, with `dart pub add jet_cad_floor_plan` or in your pubspec:"* and the YAML block

```yaml
dependencies:
  flutter:
    sdk: flutter
  jet_cad_floor_plan: ^0.7.1
```

  Then: *"The engine (`jet_cad_2d`) and the renderer (`jet_cad_2d_flutter`) come with it, from pub.dev. Import only the planner's barrel, `package:jet_cad_floor_plan/jet_cad_floor_plan.dart`. Anything under `src/` is not API."* Keep the Flutter-floor paragraph (3.44 or later; built and tested with 3.47.6; no build hook, no GPU renderer).
- Removed: the git YAML block, the SHA, *"Why a SHA and not the tag"*, the paragraph on the restaurant package at the tag, and the engine-on-pub.dev sentence added at `1dc167d`.

New subsection, at the end of §1, *"### The restaurant symbols"*, as spec D9: the three steps, with the YAML fragment

```yaml
  assets:
    - assets/restaurant.jetlib
```

(shown exactly so, indented: it is matched by containment after §2's `fonts:` in the probe's template) and the Dart block of Step 4 (the `readRestaurantLibrary` / `restaurantSource` text, verbatim). Then the loader line as the guide's later Dart block shows it (§4's `SymbolLibraryLoader(sources: const [furnitureSymbolSource, restaurantSource])` — change that existing block where it says `restaurantSymbolSource`). Then the two rules: never load the copy with the package's `restaurantSymbolSource`; saved plans do not depend on the library. And where the files come from: the tag `jet_cad_floor_plan-vX.Y.Z` of the planner release you depend on, `packages/jet_cad_restaurant_symbols/assets/restaurant.jetlib` and `packages/jet_cad_restaurant_symbols/lib/src/names.dart` (its import changed to the planner's barrel).

Search the guide for every other mention of `jet_cad_restaurant_symbols`, `restaurantSymbolSource`, `git`, `SHA` and `0fa649e` and bring each in line; check `tool/ci/check_guide.dart` reads only §-blocks the probe has.

- [ ] **Step 6: `guide_test.dart`**

- GD1: `expect(fencedBlocks(guide, 'yaml'), hasLength(3), reason: 'premise: §1\'s dependency, §2\'s fonts, the symbols\' asset');`
- GD3 becomes:

```dart
  test('GD3 a pubspec line the probe does not have is named', () {
    final moved = guide.replaceFirst(
        'jet_cad_floor_plan: ^0.7.1', 'jet_cad_floor_plan: ^0.7.2');
    expect(moved, isNot(guide), reason: 'premise');
    expect(
        missingBlocks(moved, dart: dart, yaml: yaml), ['yaml: dependencies:']);
  });
```

- GD4 becomes:

```dart
  test('GD4 the symbols\' asset line is the probe\'s', () {
    final moved = guide.replaceFirst(
        '    - assets/restaurant.jetlib', '    - assets/symbols.jetlib');
    expect(moved, isNot(guide), reason: 'premise');
    expect(missingBlocks(moved, dart: dart, yaml: yaml), ['yaml: assets:']);
  });
```

Run: `cd tool/ci && dart test && dart run check_guide.dart` (from the repository root for `check_guide.dart`: `dart run tool/ci/check_guide.dart`) — Expected: all pass; *"all N code blocks are in the host probe"*.

- [ ] **Step 7: Commit, then run the probe and the released probes locally**

The probe resolves the commit by git, so commit first, with Step 8's command, then from the repository root:

```bash
rm -rf ~/.pub-cache/git/cache/jet-cad-*
tool/ci/host_probe.sh "file://$PWD" "$(git rev-parse HEAD)"
```

Expected: the lock check prints its two lines with no failure; "No issues found!"; "✓ Built build/web"; the final "host probe: no GPU renderer, no build hook" line. Then `tool/ci/old_host_probe.sh v0.3.0`, `v0.4.0`, `v0.5.1`, `v0.6.0` — each "No issues found!". Then `git status --short` — expected clean (the copied files and the written pubspec are ignored). (The pub git-cache trap: STATUS "Traps".)

Mutant **M-PR1** (Review Focus 3): in a copy of `pubspec.yaml.in`, delete the `jet_cad_2d_flutter:` override block; run `host_probe.sh` against the same commit: it must fail at the lock check naming `jet_cad_2d_flutter` (before 0.7.1 is on pub.dev the resolution itself may fail first — record which; either is red). Restore, `cmp`.

- [ ] **Step 8: The commit (made at the start of Step 7)**

```bash
git add tool/ci docs/host-guide.md .github/workflows/ci.yml
git commit -m "ci,docs: the host probe and the guide on pub.dev (D6, D8, D9)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

(Commit before Step 7's probe run; amend nothing afterwards: a fix is a new commit and the probe runs again.)

---

