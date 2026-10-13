### Task 5: The lock check proves the probe tests the commit (D6)

**Files:**
- Modify: `tool/ci/lib/host_lock.dart`, `tool/ci/check_host_lock.dart`, `tool/ci/test/host_lock_test.dart`, `tool/ci/test/scripts_test.dart`

**Interfaces:**
- Produces, in `package:jet_cad_ci/host_lock.dart`:
  - `const List<String> probedFromCommit = ['jet_cad_2d', 'jet_cad_2d_flutter', 'jet_cad_floor_plan', 'jet_cad_restaurant_symbols'];`
  - `Map<String, String> lockEntryFields(String lock, String name)` — the entry's `source` and `description`'s `resolved-ref` (keys `source`, `resolved-ref`), empty when the package is not in the lock; throws `FormatException` as `lockPackages` does.
  - `List<String> notFromCommit(String lock, String ref)` — one message per package of `probedFromCommit` that is missing, not `source: git`, or at another `resolved-ref`, in that list's order.
- `check_host_lock.dart <pubspec.lock> [--ref <sha>]`: with `--ref`, also fails (exit 1, each message printed) on `notFromCommit`; without it, behaves as today.

- [ ] **Step 1: Write the failing tests**

Append to `tool/ci/test/host_lock_test.dart` (the fixture `host_post_split.lock.txt` resolves the four packages from git at `2b35b69931d6acdb03c219a38c923a8fd3fdc50c`):

```dart
  group('HL-C the four packages come from the commit under test', () {
    const ref = '2b35b69931d6acdb03c219a38c923a8fd3fdc50c';

    test('HL-C1 the green lock: all four from git at the ref', () {
      expect(notFromCommit(green, ref), isEmpty);
      expect(lockEntryFields(green, 'jet_cad_2d'),
          {'source': 'git', 'resolved-ref': ref});
    });

    test('HL-C2 another ref: each of the four named', () {
      const other = '0000000000000000000000000000000000000000';
      expect(notFromCommit(green, other), hasLength(4));
      expect(notFromCommit(green, other).first, contains('jet_cad_2d'));
    });

    // The named mutant of spec D6: one override dropped, so pub took the
    // package from pub.dev.
    for (final name in [
      'jet_cad_2d',
      'jet_cad_2d_flutter',
      'jet_cad_floor_plan',
      'jet_cad_restaurant_symbols',
    ]) {
      test('HL-C3 $name hosted: named', () {
        final entry = entryOf(green, name);
        final hostedEntry = [
          '  $name:',
          '    dependency: transitive',
          '    description:',
          '      name: $name',
          '      sha256: "0000"',
          '      url: "https://pub.dev"',
          '    source: hosted',
          '    version: "0.7.1"',
        ].join('\n');
        final lock = green.replaceFirst(entry, hostedEntry);
        expect(lock, isNot(green), reason: 'premise');
        expect(notFromCommit(lock, ref), [contains(name)]);
      });
    }

    test('HL-C4 a package missing from the lock: named', () {
      final lock = green.replaceFirst(
          '${entryOf(green, 'jet_cad_restaurant_symbols')}\n', '');
      expect(notFromCommit(lock, ref), [contains('jet_cad_restaurant_symbols')]);
    });
  });
```

Add to `scripts_test.dart`, next to SC9–SC13, a case that runs the CLI with `--ref`:

```dart
    test('SC16 --ref: the green lock at its ref exits 0, at another exits 1',
        () async {
      const ref = '2b35b69931d6acdb03c219a38c923a8fd3fdc50c';
      final ok = await Process.run('dart', [
        'run', 'check_host_lock.dart',
        'test/fixtures/host_post_split.lock.txt', '--ref', ref,
      ]);
      expect(ok.exitCode, 0, reason: '${ok.stdout}${ok.stderr}');
      final bad = await Process.run('dart', [
        'run', 'check_host_lock.dart',
        'test/fixtures/host_post_split.lock.txt',
        '--ref', '0000000000000000000000000000000000000000',
      ]);
      expect(bad.exitCode, 1);
      expect(bad.stdout, contains('jet_cad_floor_plan'));
    });
```

(Match the surrounding SC cases' working-directory and invocation style; if they call a helper, use it.)

Run: `cd tool/ci && dart test test/host_lock_test.dart test/scripts_test.dart` — Expected: HL-C and SC16 FAIL (undefined names / unknown flag).

- [ ] **Step 2: Implement**

In `tool/ci/lib/host_lock.dart`, add:

```dart
/// The packages the host probe must take from the commit under test, by
/// its `dependency_overrides` (publishing spec D6): once they are on
/// pub.dev, a dropped override would resolve silently from there.
const List<String> probedFromCommit = [
  'jet_cad_2d',
  'jet_cad_2d_flutter',
  'jet_cad_floor_plan',
  'jet_cad_restaurant_symbols',
];

/// The `source` and the description's `resolved-ref` of the package
/// [name]'s entry in [lock] (keys `source` and `resolved-ref`, each only
/// when present); empty when [lock] has no such package.
Map<String, String> lockEntryFields(String lock, String name) {
  if (!lockPackages(lock).contains(name)) return const {};
  final lines = lock.split('\n');
  final start = lines.indexWhere((l) => RegExp('^ +$name:\\s*\$').hasMatch(l));
  final indent = lines[start].length - lines[start].trimLeft().length;
  final fields = <String, String>{};
  for (final line in lines.skip(start + 1)) {
    final content = line.trimLeft();
    if (content.isEmpty) continue;
    final depth = line.length - content.length;
    if (depth <= indent) break;
    final m = RegExp(r'^(source|resolved-ref):\s*"?([^"\s]+)"?').firstMatch(content);
    if (m != null) fields[m[1]!] = m[2]!;
  }
  return fields;
}

/// One message per package of [probedFromCommit] that [lock] does not
/// resolve from git at [ref]: missing, another source, or another
/// resolved ref.
List<String> notFromCommit(String lock, String ref) => [
      for (final name in probedFromCommit)
        if (lockEntryFields(lock, name) case final f
            when f['source'] != 'git' || f['resolved-ref'] != ref)
          f.isEmpty
              ? '$name: not in the lock'
              : '$name: ${f['source']} at ${f['resolved-ref'] ?? 'no ref'}, '
                  'not git at $ref',
    ];
```

In `tool/ci/check_host_lock.dart`: accept `<pubspec.lock>` alone or `<pubspec.lock> --ref <sha>` (any other shape: the usage line, exit 2, as today); after the forbidden-package check, when `--ref` is given, print each `notFromCommit` message as `${file.path}: $message` and exit 1 if any. Update the usage text and the header comment (*"… and, with --ref, that the four repository packages came from git at that commit (publishing spec D6)"*).

- [ ] **Step 3: Run the tests; fire the mutants**

Run: `cd tool/ci && dart test` — Expected: all pass.

- **M-LK1**: in `notFromCommit`, drop the `f['source'] != 'git' ||` clause → HL-C3 FAILS for each name.
- **M-LK2**: drop the `|| f['resolved-ref'] != ref` clause → HL-C2 FAILS.

Each from a copy of `host_lock.dart`, restored, `cmp`.

- [ ] **Step 4: Format, analyze, commit**

Run: `cd tool/ci && dart analyze --fatal-infos lib test expect_failures.dart check_guide.dart check_host_lock.dart && dart format --output=none --set-exit-if-changed lib test expect_failures.dart check_guide.dart check_host_lock.dart host_probe/lib`

```bash
git add tool/ci/lib/host_lock.dart tool/ci/check_host_lock.dart tool/ci/test/host_lock_test.dart tool/ci/test/scripts_test.dart
git commit -m "ci: the lock check proves the probe took the commit under test (D6)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

