# Task 3 review — content, families, the wall tag (spec D2, D9)

Reviewer: independent, detached worktree `.worktrees/plan-09c1-review-t3` at `a6ef0bc`.
Diff reviewed: `git diff 9414208..a6ef0bc` (8 files, +486 −91; all under `apps/floor_planner`).

## Verdict: **Needs fixes** (1 major, 1 minor, 3 notes)

The implementation is correct: the asset decodes to exactly what D9 asks for, and the 27 old symbols are unchanged apart from appended tags (independently verified, see below). The fixes are about tests. The refactor that moved five existing version-1 symbols into parametrised helpers is guarded only by the implementer's scratch differential, which is not committed. A mutant that changes `bed.wardrobe@1` survives the whole app suite.

## Findings

1. **major** — the "no existing shape changes" rule is not pinned for 26 of the 27 old symbols.
   `apps/floor_planner/lib/symbols/furniture_catalog.dart:233`, `_wardrobe`'s `for (var x = 600.0; x < w; x += 600)` changed to `x <= w` and regenerated. This adds a sixth leaf to `bed.wardrobe@1`, and its version stays 1. Result: **the whole app suite survives**, `+1066: All tests passed!` (exit 0, `mut_wardrobe_le_full.log`). The five touched symbol test files also survive (`+253: All tests passed!`). Of the five refactored old members, only `bed.double` is pinned, by 09a's `test/symbols/symbol_end_to_end_test.dart`: my pillow-gap mutant (`200 + pillow` → `210 + pillow`) survives the five symbol files but goes red there (`leaf 2 vertex 0: got [11664.99…,-6849.0], want [11665.0,-6839.0]`).
   Why it matters: spec D2 says `version` identifies a definition's geometry and reuse compares it, and Task 9's leaf-equal reuse (D10) depends on that. If a later catalog edit silently changed `bed.wardrobe@1`, `bed.single@1`, `kitchen.base.600@1` or `office.desk@1`, every pre-09c plan holding that symbol would get a `#2` copy on its next placement, and no test would go red. P-5 also says later tasks may regenerate.
   **Fix:** commit the pre-09c asset (`git show 9414208:apps/floor_planner/assets/library/furniture.jetlib`) as a test fixture. Task 11 needs "the real 27-symbol definitions" anyway. Then add a test in `furniture_library_test.dart`: for each of its 27 keys, the shipped entry's name, category, version, base point and leaves (kind, every `EntityRecord` field but handle/owner/geomIndex, coords, scalars) equal the fixture's, and its tags start with the fixture's tags. Owed red: `wardrobe_le` above, plus one on `_singleBed` / `_baseUnit` / `_desk`.

2. **minor** — R03d accepts the same family tag twice.
   `symbol_library.dart:162`, `families.length > 1` changed to `families.toSet().length > 1`. **Survives** `symbol_library_test.dart` + `furniture_library_test.dart` (`+201: All tests passed!`). Today a symbol tagged `['family:x', 'family:x']` is refused, which matches the spec's "at most one per symbol", but no test says so. **Fix:** add the duplicate case to the R03d refusal test, or record a ruling that a duplicate does not count. Then the mutant goes red or is recorded as equivalent by ruling.

3. **note** — only the box of a new member is pinned, not its inside. `_desk`'s `w - 400` changed to `w * 5 / 7` (identical for the 1400, so the old desk is unchanged) and regenerated. It **survives** furniture_library + symbol_box (`+170: All tests passed!`). The spec pins the box only (D9, W-16), so this is acceptable. Recording it so nobody reads the box literals as a drawing pin.

4. **note** — `bed.wardrobe.2400` has handles only between doors 1 and 2 (560/640). Doors 3 and 4 have none. This is a drawing choice, not a spec rule. Add it to the human's look list.

5. **note** — `againstWallTag` and `familyTagPrefix` (R-C3-3) are unused in `lib/` outside R03d. Tasks 6/7 and 09c-2 should read the tag through these constants, not through new literals.

## 1. Implementation against spec D2 / D9 and plan Task 3

- **Independent differential.** My own Python script (`review3/diff.py`) decodes the raw JSON of the asset at `9414208` and at `a6ef0bc`, not through the app's loader. Output: `old 27 new 41`, `mismatches 0`. For each old key it compared the definition name, base point, children, xref fields, and every leaf (record fields but handle/owner, coords, scalars) in ascending-handle order. It also compared the component's key, name, category and version; tags must equal the old tags plus an appended suffix of `against-wall` / `family:` only. Also: `old order preserved: True`; `schemaVersion`, `header`, `tables`, `nodes` and `rawData` equal; one distinct leaf style across all 41 symbols; definition and leaf handles ascend in catalog order. This confirms the implementer's claim.
- **Appended tags per old key:** they match D9's against-wall list and its family table exactly. Not tagged: the dining tables, chairs and bench, the island, the armchair, the coffee table and the office chair. Order is plain tags, then `against-wall`, then `family:`.
- **The 14 new symbols, decoded from the asset:** names exactly per the plan; categories are Kitchen for base units, dishwasher and washer, Bed Room for beds and wardrobes, Living Room for `sofa.two`, Office for desks; version 1; every front on `y = 0`; base points `(W/2, 0)`, or `(W/2, 1000)` for beds, so all are off the origin.
- **The 14 box literals in `symbol_box_test.dart`, re-derived by hand from the helpers** (and checked against the decoded asset):
  - base.300/400/800 → `(0, W, 0, 600)`; the knob `(W/2, 20) r10` spans `y` 10–30 and stays inside.
  - dishwasher `(0, 600, 0, 600)`, lines only.
  - washer `(0, 600, 0, 600)`: the circle `(300, 330) r220` spans `x` 80–520 and `y` 110–550, inside.
  - double 1400 / 1800 `(0, W, 0, 2000)`: pillows `(W−300)/2` = 550 / 750 wide at `x` 100 and 200 + pillow, so the right pillow ends at `W − 100`.
  - single 800 / 1000 `(0, W, 0, 2000)`: pillow at 120 to `W − 120`.
  - wardrobe 1200 / 2400 `(0, W, 0, 600)`; the 2400 has divisions at 600, 1200 and 1800.
  - sofa.two `(0, 1500, 0, 900)`.
  - desk 1200 / 1600 `(0, W, 0, 700)`: drawer block at 800 / 1200.

  All 14 are correct.
- **`_wardrobe` loop:** exact for 1200 (600), 1800 (600, 1200) and 2400 (600, 1200, 1800). The doubles are integral, so there is no accumulation issue. The 1800's leaves are byte-identical to `9414208` (differential).
- **R03d** (`symbol_library.dart:156-165`): checked per definition after R03c. `who` names `key@version`, and the message lists both tags. The prefix test is `startsWith('family:')`, so `family`, `families:x` and `my-family:y` are not family tags (positive-control test).
- **Search and panel assertion changes:** each one follows from R-C3-1 (the new members copy their family's plain tags: `couch` on `sofa.two`, `closet` on the wardrobes, `table` on the desks) or from the new Living Room / Bed Room members. None was weakened: exact lists are replaced by exact lists, the `hitsOnly` preconditions remain, `'couch closet'` is still empty, and the `bed`-only premise of `bedIds` still holds (the tests pass).
- **R-C3-1** accepted (a family's members are found together by its plain tags).
- **R-C3-2** accepted. Nothing depends on library handles across versions:
  - the gallery id and the thumbnail key are `symbolIdOf` = `key@version` (`symbol_panel.dart:33,139-142`);
  - the ghost path and the box are `Expando`s keyed per `SymbolEntry` object;
  - the placer finds a reusable definition by `SymbolComponent` key and version and copies leaves with fresh `handleSeed` handles (`symbol_placer.dart:73-121`), so saved documents never hold library handles.
- **R-C3-3** accepted (see note 5).
- **Allocation, draw order, permissions, undo:** not touched. Catalog data, the loader and tests only; leaf order within each symbol is ascending and unchanged for old symbols.

## 2. Gates (re-run by me, `export PATH=/root/flutter/bin:$PATH`, `CI=true`)

| Gate | Mine | Implementer |
|---|---|---|
| app `flutter test` | `06:53 +1066: All tests passed!` (exit 0) | 1067 / 1075, but measured in the shared worktree with Task 4's uncommitted tests; mine is the committed tree. 1066 = Task 2's 1015 + 51 (7 group tests + 28 placed + 14 plausible-size + 2 R03d) — consistent |
| app `flutter analyze` | `No issues found!` | same |
| app `dart format --set-exit-if-changed` | `Formatted 177 files (0 changed)`, exit 0 | 180 files (shared worktree incl. Task 4 files) |
| `flutter build web --release` | `✓ Built build/web`, exit 0 | same |
| asset = generator output | `dart run tool/generate_furniture_library.dart` → `wrote …: 62880 bytes`; `git diff --quiet -- assets` clean | 62880 bytes |
| engine / render | `git diff --stat 9414208..a6ef0bc -- packages` empty: unchanged, not re-run | same |

Other checks: the two allocation invariant tests are unedited (`git diff --stat 4d6b78f..a6ef0bc` over both `test/invariants` directories is empty). No `analysis_options.yaml` in the diff (pub get modified `packages/jet_cad/analysis_options.yaml` in my worktree; not committed). Purity: `symbol_box.dart`, `furniture_catalog.dart` and `build_library.dart` have no `package:flutter` and no `dart:ui` (the only hit is a comment). `wall_attach.dart` does not exist at this commit (Task 4). The pubspec is unchanged.

## 3. Mutants (re-fired by me: cp backup, mutate, regenerate where named, run, cp back, `diff` + `cmp` + `git diff --quiet -- lib assets` OK after each)

| Mutant | Change | Run | Result |
|---|---|---|---|
| **M-09c-ac** | `symbol_library.dart` `families.length > 1` → `> 2` | symbol_library_test | **red** `+52 -1`: "R03d a symbol with two family tags is refused" |
| **M-09c-ar** | `_baseUnit` depth `w == 800 ? 620 : 600`, regenerated | furniture_library + symbol_box | **red** `+167 -3`: box literal (800, 600), "share depth, front and back (W-16)", "box is its D9 W x D" |
| base point off centre | `_desk` `baseX: w == 1600 ? 801 : w / 2`, regenerated (a different site from the implementer's) | furniture_library | **red** `+147 -1`: "every base point lies on its box's centre x" (Expected 800.0) |
| against-wall dropped | `bath.tub` loses the tag, regenerated (a different symbol from the implementer's) | furniture_library | **red** `+146 -2`: "the against-wall set is D9's list exactly", "behaviour tags come last" |
| asset not regenerated | dishwasher loses `against-wall`, no regeneration | furniture_library | **red** `+147 -1`: "the committed bytes equal the built library" |
| own: wardrobe loop `x <= w` | adds a leaf to every wardrobe, including `bed.wardrobe@1`, regenerated | 5 symbol files; **whole app suite** | **SURVIVES** `+253` / `+1066: All tests passed!` → finding 1 |
| own: double-bed pillow gap `210 + pillow` | moves `bed.double@1`'s right pillow, regenerated | 5 symbol files; whole app suite | survives the 5 files (`+253`); **red** in the whole suite `+1065 -1` (`symbol_end_to_end_test.dart`, leaf 2 vertex 0) |
| own: R03d `families.toSet().length > 1` | a duplicate family tag accepted | symbol_library + furniture_library | **SURVIVES** `+201` → finding 2 |
| own: R03d skips the last tag | `&& tag != component.tags.last` | symbol_library + furniture_library | **red** `+200 -1`: R03d refusal (the test's second family tag is last) |
| own: desk drawer `w * 5 / 7` | new desks' interior only, regenerated | furniture_library + symbol_box | **SURVIVES** `+170` → note 3 (not owed by the spec) |

## 4. Degenerate fixtures (P-2)

These are catalog tests, so the attachment fixture rules (30°, groups) do not apply.
- The loop over every symbol places each one at `(12345, −6789)`, at turns 1 and 3, with turn 3 mirrored. It iterates `furnitureCatalog` (`furniture_library_test.dart:518`), so it covers the 14 new symbols without copying the loop.
- The R03d refusal uses the second definition (the nightstand), not the first.
- The base-point test is exact `==` on all 41 symbols.
- The family test compares `front` and `back` as well as `depth`, so a member shifted in `y` at equal depth goes red.
- The degenerate spot is the one in finding 1: the old members' interiors, which only the box pins.

Review worktree left in place at `.worktrees/plan-09c1-review-t3` (clean apart from pub get's `analysis_options.yaml` and the `build/web` output). Scratch: `review3/` (`diff.py`, `mut.sh`, `mut_*.log`, `app_test.log`, `web.log`).

## Re-review of 3b (7dbfc88)

Reviewer: the same independent reviewer. Worktree `.worktrees/plan-09c1-review-t3`, detached at `7dbfc88`. Diff reviewed: `git diff 7dbfc88~1..7dbfc88`, 3 files, +75:
- a new fixture,
- `furniture_library_test.dart`,
- `symbol_library_test.dart`.

`git diff --stat a6ef0bc..7dbfc88` over the catalog, the asset and the pubspec is empty: the intervening Task 4/5 commits do not touch Task 3's content.

### Verdict: **Approved**

Findings 1 (major) and 2 (minor) are fixed. Notes 3–5 stand as notes. 4 (the 2400 wardrobe's handles) belongs on the human's look list.

### What was checked
- **The fixture.**
  - `git show 4d6b78f:apps/floor_planner/assets/library/furniture.jetlib | cmp - apps/floor_planner/test/fixtures/furniture_pre_09c.jetlib`: exit 0. The same is true against `9414208`. So the fixture is the branch point's asset, byte for byte.
  - It lives under `test/fixtures/`, not `assets/`, and the pubspec is unchanged.
  - It decodes through the real `SymbolLibrary.decode`, so the loader's validation runs on it too.
- **The new group "the 27 symbols shipped before 09c"** checks, per key and exactly:
  - name, category and version;
  - base point x and y;
  - leaf count;
  - each leaf in ascending-handle order: `kind`, then `EntityRecord ==` after aligning only handle, owner and geomIndex, then `coords` and `scalars` with `orderedEquals`.

  `EntityRecord.==` (`entity_store.dart:189-205`) compares every field: layer, linetype, linetypeScale, color, lineweight, transparency, flags, text, tag, textStyle and textAttrs. Aligning three fields therefore leaves every style field under exact `==`, which matches the D10 field set.

  The tag test checks that the old tags form a prefix of the new ones. Task 3's "the behaviour tags come last" test already pins that the appended suffix is only `against-wall` and then `family:…`, so the two together close the tag side.
- **R03d.** The duplicate case is `['nightstand', 'family:x', 'against-wall', 'family:x']` on the second definition. It must be refused, with a message naming the key and `2 family tags ("family:x", "family:x")`. This adopts the ruling "a repeated family tag counts twice", which is consistent with the spec's "at most one per symbol".

### Gates (my runs at `7dbfc88`, `CI=true`)
| Gate | Result |
|---|---|
| app `flutter test` (full) | `09:54 +1087: All tests passed!`, exit 0. This includes the Task 4/5 commits; 3b adds 3 tests. |
| app `flutter analyze` | `No issues found!` |
| app `dart format --output=none --set-exit-if-changed .` | `Formatted 180 files (0 changed)`, exit 0 |
| web, engine, render | not re-run: 3b touches test files and a fixture only (no `lib/`, no `packages/`) |

The implementer's +1095 came from the shared worktree with other agents' uncommitted files. My count is the committed tree. I did not reproduce the implementer's transient "1 issue found"; my analyze is clean.

### Mutants
Same procedure as before:
1. `cp` backup of the catalog or `build_library.dart` and of the asset;
2. mutate (one-occurrence replace) and regenerate where marked;
3. run;
4. `cp` both back, then `diff`, `cmp` and `git diff --quiet -- lib assets` must all exit 0.

All passed the restore check, and the worktree was clean afterwards apart from pub get's `analysis_options.yaml`.

| Mutant | Change | Run | Result |
|---|---|---|---|
| wardrobe `x <= w` (my finding-1 survivor) | `_wardrobe` loop; regenerated, 63657 bytes | furniture_library_test | **red** `+150 -1`: "each keeps its name, category, version, base point and leaves" (`Expected: <6>`) |
| R03d `families.toSet().length > 1` (my finding-2 survivor) | `symbol_library.dart:161` | symbol_library_test | **red** `+52 -1`: "R03d a symbol with two family tags is refused" |
| own: an old member's scalar | `_baseUnit` knob radius `w == 600 ? 12 : 10` (only `kitchen.base.600@1`); regenerated | furniture_library_test | **red** `+150 -1`: same test, `kitchen.base.600 leaf 2`, `Expected: equals [10.0] ordered` |
| own: an old member's base point y | `_singleBed` `baseY: w == 900 ? 1001 : 1000` (only `bed.single@1`); regenerated | furniture_library_test | **red** `+150 -1`: same test, `Expected: <1000.0>` |
| own: a style field on a non-helper old symbol | `build_library.dart` `linetypeScale: s.key == 'bath.toilet' ? 2.0 : 1.0`; regenerated | furniture_library_test | **red** `+150 -1`: same test, `bath.toilet leaf 0: {… linetypeScale: 2.0 …}`. The loader accepted it, so the red comes from the record comparison, not from a refusal. |

Both earlier survivors are now red, and the three new mutants (a scalar, a base point y, a record style field) are red in the new test.
