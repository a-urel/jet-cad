# Task 2 review — the guards (S8)

Reviewer: independent. Target: `d399303` (parent `2b35b69`), branch
`claude/exciting-pasteur-9m22jv`. Worked in my own clones
(`/tmp/gpu-t2-review/repo` for gates and mutants,
`/tmp/gpu-t2-review/probe-repo` for the probe runs), both at `d399303`.
Flutter 3.47.6 (CI's pinned version). Nothing committed; the only file
written outside `/tmp` is this one.

## Verdict

**Approved with fixes.** S8 and M-G2 are implemented as the spec words
them, every gate is green, both probe acceptances reproduce, and every
mutant on `check_host_lock.dart` and on the name list / key-vs-text
semantics of `host_lock.dart` is killed. One minor fix is asked for (R-2,
a post-build assertion that passes silently when its input file is
missing); the rest are minor or nits to record or take at will.

## Findings

**R-1 (minor) — "the check dropped" is not killed by anything CI runs.**
Deleting line 24 of `host_probe.sh`
(`dart run "$ci/check_host_lock.dart" "$probe/pubspec.lock"`) leaves
`tool/ci` at `00:18 +48: All tests passed!` (observed), and the CI
`host-probe` job builds HEAD, which is post-split and green with or without
the line. The implementer's "red" for this M-G2 mutant was a manual probe at
`64100c0`, and it went red only through the post-build backstops, not the
lock check. Scenario: a later edit to the probe script drops or reorders the
line (e.g. puts it before `flutter pub get`, where `pubspec.lock` has just
been deleted by the clean step — that one would exit 2, so it is the
*deletion* that is silent). The practical exposure is small: any host graph
that resolves `jet_cad_2d_gpu` also resolves `flutter_scene`, whose hook the
`hooks_runner` assertion catches. Fix options: record it in the ledger as a
known CI-invisible mutant (killed only by a manual probe), or add a cheap
SC test that `host_probe.sh` runs `check_host_lock.dart` after
`flutter pub get` and before `flutter build web`.

**R-2 (minor, fix asked) — the `cad.shaderbundle` assertion passes when
`main.dart.js` is missing.** `grep -q 'cad.shaderbundle'
build/web/main.dart.js` sits in an `if` condition, where `set -e` does not
apply; grep's exit 2 (no such file) reads as "not found". Observed:

```
$ bash -c 'set -euo pipefail; if grep -q x /nonexistent/main.dart.js; then echo FOUND; fi; echo "continued, assertion passed silently"'
grep: /nonexistent/main.dart.js: No such file or directory
continued, assertion passed silently
exit=0
```

Scenario: a Flutter upgrade or a flag change (a wasm-first output layout, a
renamed entrypoint, `--base-href`/output-dir change) makes `flutter build
web` succeed without `build/web/main.dart.js`; the probe then prints one grep
error line and the green "no GPU renderer, no build hook" line, exit 0. Fix:
assert the file first (`[ -f build/web/main.dart.js ] || { echo ...; fail=1; }`)
or test grep's status explicitly (exit 0 → fail, 1 → ok, other → fail). The
same class of silent pass applies, by nature, to `.dart_tool/hooks_runner`
(a Flutter-internal directory name; if Flutter renames it the assertion
passes). That one is the POS's literal requirement, so keep it, but it is
worth a comment that the lock check is the primary guard.

**R-3 (nit) — the parser fails open on inputs pub never writes.** Run
against the committed `host_lock.dart` (results under "Edge cases"):
`packages: {flutter_scene: x}` (flow map with content) returns `[]`; a key
indented *less* than the first key (` flutter_scene:` after `  a:`) is
skipped as if it were a field. Neither is reachable from a `pubspec.lock`
pub wrote (pub writes block style at two spaces, `packages: {}` only when
empty), so no CI scenario fails open. If you want it closed: throw a
`FormatException` when anything but `{}` or a comment follows `packages:`,
and when `0 < depth < indent`. Related equivalent/surviving mutants: M11
(the `packages: {}` branch is dead code — the next line is at column 0 and
ends the loop anyway), M12 (unanchored `packages:`), M15 (indent fixed at 2),
M17 (unparseable key line skipped instead of thrown), M19 (greedy key),
M21 (blank lines not skipped — the fixtures have none). None matters for a
pub-written lock; deleting the dead `{}` branch is the only cleanup worth
taking.

**R-4 (nit) — no suffix look-alike.** The look-alikes kill text matching,
substring-of-key and prefix-of-key (`scene_x`) mutants, but a suffix match
(M08, `name.endsWith(f)`) survives: no key in the green lock ends in a
forbidden name. It fails closed (a real package such as `my_scene` would be
a false red, not a hole), so it does not threaten the guard. A third
look-alike such as `my_scene` (hosted, all zeros, like `scene_x`) would kill
it if exactness is to be pinned completely.

**R-5 (nit) — the probe needs the full SHA, and its usage line does not
say so.** The implementer found that a short SHA fails `pub get` (the nested
git dependencies resolve the full ref). CI passes `git rev-parse HEAD`, so
CI is unaffected; the usage comment `<commit sha>` could say "full".

Not findings (checked and fine):
- The clean step deletes only `$probe/build`, `$probe/.dart_tool` and
  `$probe/pubspec.lock`; `$probe` is absolute (`ci=$(cd … && pwd)`, and a
  failing command substitution in an assignment aborts under `set -e`, so
  it is never empty). It leaves `.flutter-plugins-dependencies`, which
  `pub get` rewrites. Confirmed by experiment: before the `64100c0` run I
  planted `host_probe/.dart_tool/hooks_runner/stale_marker` on top of the
  `2b35b69` build; afterwards there was no `build/` and no `hooks_runner`.
- `dart run "$ci/check_host_lock.dart"` from the probe's cwd works: the
  script imports only `dart:io` and a relative `lib/host_lock.dart`, and
  `dart run` did not re-resolve the probe (no pub output between `pub get`
  and the check's line in either run).
- After the runs, `git status --short` is clean; the generated
  `pubspec.yaml`, `pubspec.lock`, `.dart_tool/`, `build/` and
  `.flutter-plugins-dependencies` are all ignored by
  `tool/ci/host_probe/.gitignore` (shown as `!!` with `--ignored`).
- One red fixture per name is realised as five red locks generated from the
  green fixture (entries cut from the recorded pre-split lock;
  `jet_cad_2d_gpu` as a renamed git entry), with the names spelled in the
  test, not read from the list under test. That meets V-2's intent.

## Spec conformance (S8, M-G2, F-9/V-7, V-8)

| Spec item | Where | Status |
|---|---|---|
| `check_host_lock.dart` in `tool/ci`, exit 1 if any of the five names is a key under `packages:` | `check_host_lock.dart`, `lib/host_lock.dart` | Done; exit 2 for usage / missing file / not a lock is an addition, tested (SC12, SC13). |
| Keys exactly, not text | `lockPackages` | Done; killed text, substring and prefix mutants (M05–M07). |
| One red fixture per name | HL3 (5 cases) | Done (generated, see above). |
| Green fixture after the split with `scene_x`, `my_flutter_scene_tools` | `host_post_split.lock.txt` | Done; matches the 40 packages and versions my probe resolved at `2b35b69`, plus the two look-alikes. |
| Fixtures `*.lock.txt` (not git-ignored) | `tool/ci/test/fixtures/` | Done; `git check-ignore` exits 1 for both; both in `git ls-files`. |
| Probe: clean first | `host_probe.sh:19` | Done, verified by experiment. |
| Probe: check by absolute path after `pub get` | `host_probe.sh:24` | Done. |
| Probe: three post-build assertions | `host_probe.sh:26-41` | Done; see R-2. |
| ci.yml: analysis/format lists | `ci-tools` | Done (parsed with `yaml.safe_load`). |
| ci.yml: matrix gains `packages/jet_cad_2d_gpu` | `package` matrix | Done. |
| ci.yml: web job asserts no `assets/packages/flutter_scene` | `web` job | Done; `run: |` uses Actions' default `bash -e`, the `test` is the step's last command. |
| M-G2 script test by exit code, as SC1–SC8 | SC9–SC13 | Done. |
| M-G2 mutants: check dropped / each name / text matching | — | Each name and text matching killed by tests; check dropped only by a manual probe (R-1). |
| Probe acceptance, locally | — | Reproduced (below). |

Nothing extra beyond the exit-2 contract and the host-probe step's rename.

## Gate outputs observed (tool/ci, at `d399303`)

After `flutter pub get` at the workspace root (`Changed 134 dependencies!`);
`packages/jet_cad_2d_gpu/analysis_options.yaml` copied in from
`/home/user/jet-cad` (untracked at `d399303`).

```
$ dart test                      # tail
00:12 +47: test/scripts_test.dart: check_host_lock.dart SC13 bad arguments: exit 2
00:14 +48: All tests passed!
test-exit=0
$ dart analyze --fatal-infos lib test expect_failures.dart check_guide.dart check_host_lock.dart
Analyzing lib, test, expect_failures.dart, check_guide.dart, check_host_lock.dart...
No issues found!
analyze-exit=0
$ dart format --output=none --set-exit-if-changed lib test expect_failures.dart check_guide.dart check_host_lock.dart host_probe/lib
Formatted 11 files (0 changed) in 0.11 seconds.
format-exit=0
$ bash -n tool/ci/host_probe.sh
bash-n-exit=0
```
(shellcheck is not installed.)

## Probe acceptance

**At `2b35b69` (full SHA via `git rev-parse`), exit 0, `real 2m48.808s`.**
Output with the root warning and the `+ pkg` lines filtered:

```
Resolving dependencies...
Downloading packages...
Changed 40 dependencies!
2 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
/tmp/gpu-t2-review/probe-repo/tool/ci/host_probe/pubspec.lock: 40 packages, none of flutter_scene, flutter_gpu, flutter_gpu_shaders, scene, jet_cad_2d_gpu
Analyzing host_probe...
No issues found! (ran in 10.5s)
Compiling lib/main.dart for the Web...
Wasm dry run succeeded. ...
Expected to find fonts for (MaterialIcons, packages/cupertino_icons/CupertinoIcons), but found (MaterialIcons). ...
Font asset "MaterialIcons-Regular.otf" was tree-shaken, ...
Compiling lib/main.dart for the Web...                            141.1s
✓ Built build/web
host probe: no GPU renderer, no build hook; build/web is 42M
EXIT=0
```
Afterwards: `.dart_tool` = dartpad, flutter_build, package_config.json,
package_graph.json, version (no `hooks_runner`);
`build/web/assets/packages` = jet_cad_floor_plan, jet_cad_restaurant_symbols;
`grep -c cad.shaderbundle main.dart.js` = 0; `du -sh build/web` = 42M; 40
keys in the lock, the same names and versions as the green fixture minus its
two look-alikes (diffed).

**At `64100c0` (full SHA), exit 1 at the lock check, `real 0m7.231s`,**
over the previous run's `build/` plus a planted stale `hooks_runner`:

```
Changed 53 dependencies!
5 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
/tmp/gpu-t2-review/probe-repo/tool/ci/host_probe/pubspec.lock: a host must not resolve flutter_gpu
/tmp/gpu-t2-review/probe-repo/tool/ci/host_probe/pubspec.lock: a host must not resolve flutter_gpu_shaders
/tmp/gpu-t2-review/probe-repo/tool/ci/host_probe/pubspec.lock: a host must not resolve flutter_scene
/tmp/gpu-t2-review/probe-repo/tool/ci/host_probe/pubspec.lock: a host must not resolve scene
EXIT=1
```
The lock this run wrote is identical to `host_pre_split.lock.txt` except
the header comments and the four `url: "file://…"` lines (my clone's path
against `/home/user/jet-cad`): the fixture is authentic.

## ci.yml: the new matrix row, run as CI runs it

In `packages/jet_cad_2d_gpu` at `d399303`:

```
$ flutter test --file-reporter "json:…/gpu-tests.json" || true
00:08 +16: All tests passed!
$ dart run tool/ci/expect_failures.dart --package packages/jet_cad_2d_gpu --root packages/jet_cad_2d_gpu …/gpu-tests.json
packages/jet_cad_2d_gpu: 16 tests; the standing failures and skips, exactly
expect-exit=0
$ flutter analyze
No issues found! (ran in 9.7s)
$ dart format --output=none --set-exit-if-changed .
Formatted 9 files (0 changed) in 0.07 seconds.
```

`analysis_options.yaml`: at `d399303` the package's file is untracked, and
there is no `analysis_options.yaml` at `packages/` or at the root, so CI's
`flutter analyze` would have used the analyzer's defaults (no lints, no
strict modes). That cannot fail where the strict file passes; I checked:
with the file moved aside, `flutter analyze` → `No issues found! (ran in
10.4s)`, exit 0. It would only have been a weaker gate. Moot since
`e1ddf4e`, which commits the file: I fetched it and `cmp` confirms it is
byte-identical to `jet_cad_2d_flutter`'s and to the copy I used, so CI now
analyses with the real options.

## ci.yml: the web job's assertion, run as CI runs it

The implementer did not build the apps; I did, at `d399303`, in the
workspace clone, each as `flutter build web` followed by CI's
`test ! -e build/web/assets/packages/flutter_scene`. This was a harder
setting than CI's fresh checkout: the workspace's `.dart_tool/hooks_runner`
(with `flutter_scene/` and `shared/`) already existed, left by the
`jet_cad_2d_gpu` matrix-row test run just before.

| App | build | `test ! -e …/flutter_scene` | `build/web/assets/packages` | `cad.shaderbundle` in `main.dart.js` | `du -sh build/web` |
|---|---|---|---|---|---|
| restaurant_demo | exit 0 (`Compiling … 160.9s`, `✓ Built build/web`) | exit 0 | jet_cad_floor_plan, jet_cad_restaurant_symbols | 0 | 42M |
| floor_planner | exit 0 (`Compiling … 128.6s`, `✓ Built build/web`) | exit 0 | jet_cad_floor_plan, jet_cad_restaurant_symbols | 0 | 42M |

F-9 holds: neither app ships `flutter_scene`'s assets, even with a sibling's
hook output present in the workspace. I did not build the apps at
`64100c0` to see the assertion go red. `test ! -e` on a directory F-6
records as present there is not a construct that can be wrong in an
interesting way.

## Mutants

Harness: each mutant applied by exact single-occurrence string replacement
to the file in `tool/ci`, then `dart test -r expanded
test/host_lock_test.dart test/scripts_test.dart` (24 tests), then the file
restored from a scratch copy and `cmp`-checked ("restored" every time). After
all of them, `cmp` against the scratch copies and `git status --short` (only
the untracked options file) confirmed a clean tree. The probe-script mutant
ran the full `dart test`.

### `lib/host_lock.dart`

| # | Mutant | Result | Killed by |
|---|---|---|---|
| M01 | `'flutter_scene'` dropped from the list | red, +20 −4 | HL3 flutter_scene, HL4, SC9, SC10 |
| M02 | `'flutter_gpu'` dropped | red, +21 −3 | HL3 flutter_gpu, HL4, SC10 |
| M03 | `'flutter_gpu_shaders'` dropped | red, +21 −3 | HL3 flutter_gpu_shaders, HL4, SC10 |
| R1 | `'scene'` dropped | red, +20 −4 | HL3 scene, HL4, HL6, SC10 |
| M04 | `'jet_cad_2d_gpu'` dropped | red, +22 −2 | HL3 jet_cad_2d_gpu, SC11 |
| M05 | text matching (`lock.contains(name)`) | red, +14 −10 | HL1, all five HL3, HL4, HL5, HL6, SC9 |
| M06 | key *contains* a forbidden name | red, +15 −9 | HL1, all five HL3, HL5, HL6, SC9 (`my_flutter_scene_tools`) |
| M07 | key *starts with* a forbidden name | red, +15 −9 | HL1, all five HL3, HL5, HL6, SC9 (`scene_x`) |
| M08 | key *ends with* a forbidden name | **survived** | — (R-4; fails closed) |
| M09 | findings in list order, not lock order | red, +23 −1 | HL4 |
| M10 | no `packages:` → `[]` instead of throw | red, +22 −2 | HL7, SC12 |
| M11 | `packages: {}` branch removed | **survived** | — (equivalent: dead code, R-3) |
| M12 | `^packages:` unanchored | **survived** | — (R-3; no line before it contains `packages:`) |
| M13 | column-0 line `continue` instead of `break` | red, +15 −9 | HL1, HL3 ×5, HL4, HL5, SC9 |
| M14 | indent filter removed (fields read as keys) | red, +15 −9 | HL1, HL3 ×5, HL4, HL5, SC9 |
| M15 | indent fixed at 2 | **survived** | — (equivalent for pub's locks) |
| M16 | `depth != indent` → `depth < indent` | red, +15 −9 | HL1, HL3 ×5, HL4, HL5, SC9 |
| M17 | unparseable key line skipped, not thrown | **survived** | — (R-3; unreachable from pub) |
| M18 | double-quoted key not unquoted | red, +23 −1 | HL6 |
| M19 | key group greedy (`[^:]*`) | **survived** | — (only differs for `key :`, R-3) |
| M20 | stop after the first key | red, +13 −11 | HL1, HL3 ×5, HL4, HL6, SC9, SC10, SC11 |
| M21 | blank lines not skipped (end the map) | **survived** | — (pub writes none; R-3) |
| R2 | comment lines not skipped | **survived** | — (pub writes none inside the map; R-3) |

### `check_host_lock.dart`

| # | Mutant | Result | Killed by |
|---|---|---|---|
| C01 | findings → `exit(0)` | red, +22 −2 | SC10, SC11 |
| C02 | findings → `exit(2)` | red, +22 −2 | SC10, SC11 |
| C03 | not a lock → `exit(1)` | red, +23 −1 | SC12 |
| C04 | missing file → `exit(1)` | red, +23 −1 | SC12 |
| C05 | existence check removed (uncaught `FileSystemException`) | red, +23 −1 | SC12 |
| C06 | usage check `args.isEmpty` | red, +23 −1 | SC13 |
| C07 | usage check `args.length > 1` | red, +23 −1 | SC13 |
| C08 | usage → `exit(1)` | red, +23 −1 | SC13 |
| C09 | findings printed to stderr | red, +22 −2 | SC10, SC11 |
| C10 | only the first finding named | red, +23 −1 | SC10 |
| C11 | green line counts findings, not packages | red, +23 −1 | SC9 |
| C12 | `FormatException` not caught (`on StateError`) | red, +23 −1 | SC12 |
| C13 | green line removed | red, +23 −1 | SC9 |
| C14 | not a lock → `exit(0)` | red, +23 −1 | SC12 |

### `host_probe.sh`

| # | Mutant | Result | Killed by |
|---|---|---|---|
| P1 | the `check_host_lock.dart` line deleted | **survived** `dart test` (`00:18 +48: All tests passed!`) | only a manual probe at a pre-split SHA, via the post-build backstops (the implementer's run); R-1 |

## Edge cases run against the committed parser (no mutation)

A scratch script importing `lib/host_lock.dart` by `file://` URI:

```
CRLF pre: [flutter_gpu, flutter_gpu_shaders, flutter_scene, scene] n=53
CRLF green: []
tabs-indent: keys=[flutter_scene] forbidden=[flutter_scene]
second key deeper: keys=[a] forbidden=[]
second key shallower(1sp): keys=[a] forbidden=[]
first key at 4: keys=[a, flutter_scene] forbidden=[flutter_scene]
packages: # comment: keys=[a, flutter_scene] forbidden=[flutter_scene]
packages: {} # comment: keys=[] forbidden=[]
packages:{}: keys=[] forbidden=[]
packages: {flutter_scene: x} flow: keys=[] forbidden=[]
next top-level sdks with forbidden under it: keys=[a] forbidden=[]
col-0 comment inside map: keys=[a, flutter_scene] forbidden=[flutter_scene]
indented comment: keys=[a, flutter_scene] forbidden=[flutter_scene]
blank line inside map: keys=[a, flutter_scene] forbidden=[flutter_scene]
blank line w/ spaces: keys=[a, flutter_scene] forbidden=[flutter_scene]
single-quoted key: keys=[a, flutter_scene] forbidden=[flutter_scene]
key with trailing space: keys=[flutter_scene] forbidden=[flutter_scene]
packages last, no trailing newline: keys=[flutter_scene] forbidden=[flutter_scene]
packages_extra decoy: keys=[a] forbidden=[]
document start ---: keys=[flutter_scene] forbidden=[flutter_scene]
comment mentioning packages: before: keys=[flutter_scene] forbidden=[flutter_scene]
BOM: FormatException no top-level "packages:" key
uppercase key: keys=[Flutter_Scene] forbidden=[]
```

CRLF, tabs, a trailing comment on `packages:`, `sdks:` as the next key,
comments and blank lines inside the map, quoted keys and a missing final
newline all behave. "Second key deeper" is correct (a deeper line is a
field). The two fail-open rows (shallower key, flow map with content) are
invalid or never written by pub (R-3); a BOM fails closed (exit 2).

## Fixtures

- `tool/ci/test/fixtures/host_post_split.lock.txt` and
  `host_pre_split.lock.txt` are tracked (`git ls-files`) and not ignored
  (`git check-ignore -v` prints nothing, exit 1) despite `*.lock` in
  `.gitignore`. ASCII, LF only.
- The look-alikes put every forbidden name in the green lock as text and
  none as a key: `scene_x` (key and `name:` field: prefix of `scene`),
  `my_flutter_scene_tools` (key: substring of `flutter_scene`; `path:
  "vendor/flutter_gpu_shaders/jet_cad_2d_gpu"` holds `flutter_gpu`,
  `flutter_gpu_shaders` and `jet_cad_2d_gpu`; its `url` holds the text
  `description: name: flutter_scene`). They kill text matching (M05),
  substring (M06) and prefix (M07) matching on keys; they do not exercise a
  suffix (M08, R-4) or a forbidden name in key position at another depth —
  HL5 covers that one (a package field and a key under `sdks:`).

---

## Controller's disposition

R-1 to R-5 applied in `c0248b3`; mutants M1-M6 red (task-2-fixes.md).
