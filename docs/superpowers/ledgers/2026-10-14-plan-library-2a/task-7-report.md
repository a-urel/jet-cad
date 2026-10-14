# Task 7 report: the plan file (manifest, load, save, versions)

Status: DONE
Commit: `6df8967a feat(plan): the plan file: manifest, load, save and versions` (on BASE aeb5e610)

## Implemented

- `lib/src/file/plan_format_exception.dart`: `PlanFormatCode { noManifest, formatTooNew, schema, notJson, damagedUnsavable }`; `PlanFormatException implements FormatException` (`code`, `message`, `source` null, `offset` null, `toString()` = `PlanFormatException(<code>): <message>`).
- `lib/src/file/semver.dart` (internal, not exported): `SemVer` (semver 2.0.0 precedence, build metadata ignored, overflow -> null) and `isNewerVersion` (null when either side does not parse).
- `lib/src/file/manifest.dart`: `kPlanFormat = 1`, `PlanManifest` (value equality), `manifestOf`, `usedKits` / internal `usedKitsIn`, `manifestToWrite`, `ManifestCheck` + `checkManifest`.
- `lib/src/file/plan_file.dart`: `decodePlan` (raw-JSON manifest check first: notJson, noManifest, schema, formatTooNew; then the engine decode with `keepUnreadableComponents: true` and the caller's `diagnostics`, any engine error -> `schema`), `encodePlan` (never mutates the document; replaces the root's manifest entry in the encoded components map and re-sorts type ids and the manifest's handles as `ComponentRegistry.toJson` does), `ensureManifest`.
- Barrel exports as the brief lists (`usedKitsIn` and `semver.dart` internal).
- `test/support/harness.dart`: `planText` (and the barrel import).
- Tests: `test/file/semver_test.dart` (PF-7, PF-7u), `test/file/manifest_test.dart` (PF-3, PF-4, PF-5, PF-8), `test/file/plan_file_test.dart` (PF-1, PF-unreadable, PF-6, PF-9, PF-10).

## TDD evidence

RED (Step 2), `flutter test test/file` before any lib code — all three files failed to load; compile errors (counted with `grep Error: | sort | uniq -c`):

```
   4 'PlanFormatCode' isn't a type.
   2 'PlanFormatException' isn't a type.
   2 Couldn't find constructor 'PlanFormatException'.
  16 Couldn't find constructor 'PlanManifest'.
   2 Error when reading 'lib/src/file/semver.dart': No such file or directory
   6 Method not found: 'checkManifest'.
   2 Method not found: 'decodePlan'.
  12 Method not found: 'encodePlan'.
   6 Method not found: 'ensureManifest'.
  10 Method not found: 'isNewerVersion'.
   2 Method not found: 'manifestOf'.
   6 Method not found: 'manifestToWrite'.
   6 Method not found: 'usedKits'.
   2 Required named parameter 'label' must be provided.
  10 Undefined name 'SemVer'.
  ...
00:00 +0 -3: Some tests failed.
```

The `label` error was the brief's test code (see Deviations), fixed before GREEN.

GREEN (Step 7), `flutter test test/file test/kits`:

```
00:00 +11: .../test/kits/kit_set_test.dart: KS1 ...
...
00:00 +25: All tests passed!
```

(11 new tests: PF-1, PF-unreadable, PF-6, PF-9, PF-10, PF-3, PF-4, PF-5, PF-8, PF-7, PF-7u; 14 existing.)

## Mutations (after the commit; each applied to the committed file, the named test run with `flutter test <file> --plain-name '<id> '`, then `git checkout -- <file>` and `git diff --quiet -- <file>` printed `reverted-clean`)

| Mutation | File | Test | Red line (quoted) |
|---|---|---|---|
| M-PF-1a: delete `_checkManifest(json);` | plan_file.dart | PF-1 | `Expected: throws (... code: PlanFormatCode.noManifest)` / `Which: threw PlanFormatException:<PlanFormatException(schema): not a plan: SchemaVersionError: document has no schemaVersion>` |
| M-PF-1b: `format > kPlanFormat + 1` | plan_file.dart | PF-1 | `Expected: throws (... PlanFormatCode.formatTooNew)` / `Which: returned <Instance of 'DraftDocument'>` |
| M-PF-1c: `} on PlanFormatException { rethrow; }` | plan_file.dart | PF-1 | `Which: threw SchemaVersionError:<SchemaVersionError: unsupported schemaVersion 9999 (this build writes 10)>` |
| M-PF-unreadable: drop `keepUnreadableComponents: true` | plan_file.dart | PF-unreadable | `PlanFormatException(schema): not a plan: type 'String' is not a subtype of type 'num' in type cast` |
| M-PF-6: `json['components'] = components;` | plan_file.dart | PF-6 | `Which: at location [3] is 'jetcad.page' instead of 'jetcad.manifest'` |
| M-PF-10a: `String ensureManifest(String text) => text;` | plan_file.dart | PF-10 | `PlanFormatException(noManifest): the plan carries no jetcad.manifest on its root` |
| M-PF-10b: delete the early `return text` when the root has a manifest | plan_file.dart | PF-10 | `Expected: same instance as '{"schemaVersion":10,...` / `Actual: '{"schemaVersion":10,...` |
| M-PF-3a: delete the `jetcad.symbol` key block | manifest.dart | PF-3 | `Actual: Set:['disc', 'test']` / `Which: does not contain 'cafe'` |
| M-PF-3b: `if (isKitId(kit)) used.add(kit);` | manifest.dart | PF-3 | `Actual: Set:['cafe', 'disc', 'jetcad', 'test']` / `Which: larger than expected` |
| M-PF-4: delete the `else if (read?.kits[id] case final version?)` branch | manifest.dart | PF-4 | `Expected: PlanManifest(1, {gone: 2.0.0, old: 1.0.0, test: 1.2.0})` / `Actual: PlanManifest(1, {test: 1.2.0})` |
| M-PF-4 (same) | manifest.dart | PF-9 | `Which: at location ['kits'] is {'disc': '0.4.0', 'test': '1.2.0'} which has different length and is missing map key 'gone'` |
| M-PF-5: drop `if (used.contains(id))` | manifest.dart | PF-5 | `Expected: PlanManifest(1, {test: 1.2.0})` / `Actual: PlanManifest(1, {disc: 0.4.0, test: 1.2.0})` |
| M-PF-8a: `!= false` | manifest.dart | PF-8 | `Expected: empty` / `Actual: [` / reason `1.x over 1.2.0` |
| M-PF-8b: `SplayTreeSet<String>.of(manifest.kits.keys)` | manifest.dart | PF-8 | `Expected: Set:['gone', 'lost']` / `Actual: Set:['gone']` / `Which: does not contain 'lost'` |
| M-PF-7a: `_compareIdentifier` returns `a.compareTo(b)` | semver.dart | PF-7 | `Expected: <-1>` / `Actual: <1>` / `1.0.0-beta.2 vs 1.0.0-beta.11` |
| M-PF-7b: release/pre-release signs swapped | semver.dart | PF-7 | `Expected: <-1>` / `Actual: <1>` / `1.0.0-alpha vs 1.0.0` |
| M-PF-7c: minor compared as text | semver.dart | PF-7 | `Expected: <-1>` / `Actual: <1>` / `1.2.0 vs 1.10.0` |
| M-PF-7u: trailing `$` dropped from `_semver` | semver.dart | PF-7u | `Expected: null` / `Actual: <Instance of 'SemVer'>` / reason `1.2.3-` |

All 17 named mutations red. After the last revert: `git status --short` empty, `git diff --quiet` -> `tree-clean`.

Mechanics of two mutations (the mutated code must compile): M-PF-10a kept the original body as an unused `_ensureManifest` (so `_object` stays used); M-PF-7a inserted an early `return a.compareTo(b);` at the top of `_compareIdentifier`.

## Gate (packages/jet_cad_2d_plan), after the commit and after the mutations

```
flutter test        -> 00:00 +25: All tests passed!
flutter analyze     -> No issues found! (ran in 2.6s)
dart format --output=none --set-exit-if-changed . -> Formatted 14 files (0 changed) in 0.03 seconds.  (exit 0)
```

`git status --short` after the pub operations the test runs triggered: only my files; no analysis_options.yaml touched.

## Files

- /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2a/packages/jet_cad_2d_plan/lib/src/file/plan_format_exception.dart (new)
- /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2a/packages/jet_cad_2d_plan/lib/src/file/semver.dart (new)
- /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2a/packages/jet_cad_2d_plan/lib/src/file/manifest.dart (new)
- /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2a/packages/jet_cad_2d_plan/lib/src/file/plan_file.dart (new)
- /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2a/packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart (exports)
- /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2a/packages/jet_cad_2d_plan/test/support/harness.dart (`planText`, barrel import)
- /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2a/packages/jet_cad_2d_plan/test/file/semver_test.dart, manifest_test.dart, plan_file_test.dart (new)

## Deviations from the brief

1. **PF-3 test: `CompoundCommand` needs `label:`.** The engine's constructor is `CompoundCommand(List<DraftCommand> children, {required this.label})` (commands.dart:973); the brief's call had none and did not compile. Added `label: 'Add a symbol'`. No assertion changed.
2. **A doc comment on `checkManifest`** (the brief had none on the function, only on `ManifestCheck`). Documentation only.
3. **`dart format` reflowed** the brief's code in the lib and test files (the brief's lines exceed 80 columns). Formatting only.

Everything else compiled and passed as the brief wrote it: no change to a Shared interface or another task's contract.

## Self-review

- Spec rulings honoured: the manifest is checked on the raw JSON before the engine decodes (so format 2 is `formatTooNew` regardless of the components); `keepUnreadableComponents: true` with the caller's diagnostics list (R-c / E4), pinned by PF-unreadable and M-PF-unreadable; `encodePlan` does not mutate the document (it edits a copy of the encoded components map) and keeps `encode(decode(x)) == x` (PF-6, twice); a missing kit's entry is the one read (PF-4, PF-9); a loaded unused kit is dropped (PF-5); unparsed versions are never compared (PF-8, PF-7u).
- Fixtures are off the origin (slab at (2350, -1180) turned 0.4 rad, disc at (-3100, 2240), line (-500, 700)-(1800, 2400)), with non-default attributes (`finish: 'tiled'`, `swatch: 'red'`), kit versions that differ between plan and loaded kits.
- `decodePlan` catches every throw of the engine's decode (`catch (e)`, Errors included) and turns it into `schema`: intended, since a malformed field surfaces as a `TypeError` there.
- `usedKits` encodes the components map (`toJson`), an O(n) allocation: load/save path only, not the frame path.

## Concerns (minor, for the reviewer)

- PF-1 loops over its cases and stops at the first failing one, so under M-PF-1c only the `schemaVersion: 9999` case was observed red (the `entities: 7` case is the second it would hit); under M-PF-1a only `{}`.
- M-PF-6 turns PF-6 red at its premise line (`types` sorted), not at `y == x`: `planText` itself goes through `encodePlan`, so the unsorted map shows in `x` already. The brief predicted the red at the second save; the test is red either way.
- `ensureManifest` re-encodes an import through `jsonDecode`/`jsonEncode`, so number spellings normalise (e.g. `1e3` -> `1000.0`); harmless for an import, and a text with a manifest is returned as the same instance.
- `encodePlan` writes a manifest (`{"format":1,"kits":{}}`) on a plan whose document never had one (a new plan): the expected behaviour per the brief, noted since `manifestOf(d)` stays null in memory.
