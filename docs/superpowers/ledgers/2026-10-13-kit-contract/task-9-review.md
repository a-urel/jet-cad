# Task 9 review: geometry snapshot, conformance, sample kit (K7) — 21d14ff0..b4e973a0

### Spec Compliance

- ✅ Spec compliant. All six committed source/test files match the brief's code blocks token for token, once whitespace is ignored (checked by stripping whitespace and running `cmp` on `git show b4e973a0:<file>` against each brief block. Only `conformance_test.dart` differed, and only in `dart format` line breaks). `lib/authoring.dart` adds the two exports in alphabetical order (diff L18-L20). K7 checks 1-6 are all present (conformance.dart: bytes L88, kit/validate L92-L103, keys-under-kit and lower-case L110-L135, snapshot L139-L173, words L177-L222). Category word ids use `KitNames.categoryWord(catalog.kit, s.category)` = `category:<kit>/<English>` (conformance.dart L190, sample_kit.dart words). Each word is compared with the English of the key's newest version (conformance.dart L183-L188).
- ✅ Every field of the catalog's geometry is in the snapshot. Named risk: a field the snapshot leaves out would let a geometry change pass. I checked this against `lib/src/authoring/catalog.dart`: `CatalogShape` is `sealed`, and every field of Line, Polyline (points, closed), Circle and Arc (center, radius, start, sweep), and of `CatalogUnit` (kind, capacity, labelling) and `base` is in `_entry`/`_shape` (snapshot.dart L18-L54). The fields that are left out (name, category, tags, attachTo, family) are not geometry, and spec K7 item 4 covers only base, shapes and unit.
- ✅ The commit trailer is exact. Nothing changed under packages/jet_cad_2d, jet_cad_2d_flutter or apps, and no `analysis_options.yaml` changed (`git diff --stat` over those paths is empty).
- ⚠️ I did not re-run the generator to check that it is idempotent, because this review is read-only. F0 is indirect evidence: it needs the committed bytes to equal `encodeLibrary(sampleCatalog)` and the parsed snapshot to equal `geometrySnapshot(sampleCatalog)`.

### Named risk: can a changed geometry of a committed key@N pass silently?

No, on the paths I traced:
- `now != was` (conformance.dart L157) compares exact strings.
- Dart's shortest round-trip `double.toString` gives each double one text, so `_number`'s -0.0 → 0.0 is the only time two different values give the same text.
- `updateSnapshot` = `{...current, ...committed}` keeps the committed entries (N7 pins this).
- The committed `sample_snapshot.json` is sorted, one entry per line, and has no `-0.0`.
- The early returns (the catalog checks, `catalogInvalid`) always return a non-empty list.

Wherever the parsed text is not canonical, the result is a loud failure, not a silent pass (Minor 2).

### Strengths

- `updateSnapshot` is the spec's merge, and N7 kills the spec's own mutation. N1 pins the key order of the canonical text, including `closed`, unit and arc fields. N2 pins -0.0.
- The failing kits change one thing each and regenerate what a generator would. F5's moved vertex is off the origin and the message names `1351.0`. F7 and F19 hold one key at two versions.
- F11 adds an English word on purpose, so the fallback mutation (M-F11) gets caught.
- The sample kit is off the origin, rotates chairs at ±π/2, and covers every shape kind, both unit kinds and labellings, attachTo and family.

### Issues

#### Critical (Must Fix)
None.

#### Important (Should Fix)
1. **F19's fixture always puts the newest version last in catalog order, so a "last version wins" bug survives** (conformance_test.dart F19, about L322-L337; conformance.dart L183-L188). If the English were taken from whichever version comes last in the catalog (e.g. `if (true)`, or a plain `{for s in symbols: symbolWord(s.key): s.name}`), F19 would stay green. v2 is appended after v1 there, and F7's v2 has the same name as v1. Only the named M-F19 (first version wins) is caught. This is Review Focus 5, and it is the degenerate-fixture pattern CLAUDE.md warns about. The code itself is correct, and K3 does not require versions in order. Fix: add a case that puts `copyOf(stool, version: 2, name: 'High bar stool')` before the sample symbols, regenerates through `generated(...)`, and makes the same two assertions.

#### Minor (Nice to Have)
2. **`parseSnapshot` normalises only whitespace, but its doc says the entries are "re-encoded canonically"** (snapshot.dart L60-L74). Key order, `1` vs `1.0`, and `-0.0` come through from the file unchanged. A committed file reformatted by a tool (keys reordered, `1.0` written as `1`) would turn every entry into a false `snapshotChanged`. That fails closed, so it is safe, but N5's title ("not the file layout") claims more than the code does. Fix: soften the doc, or canonicalise the parsed value recursively.
3. **The arc's `start` and `sweep` pass through `_number`, but no test pins this** (snapshot.dart L50-L51). The mutation `'start': start` survives, since N2 only uses -0.0 in `base` and `center`. Add an arc with `start: -0.0`.
4. **No test pins `encodeSnapshot`'s `..sort()`** (snapshot.dart L79). Every test passes a `SplayTreeMap` in, so dropping the sort survives. Pass an unsorted plain map in N4.
5. **No end-to-end test runs the generator path for a moved committed vertex.** F5 uses the committed snapshot directly, not `generated(moved).snapshot`. N7 together with F5 covers it, but one assertion that `generated(moved)` still gives `snapshotChanged` would pin the whole workflow the spec describes.
6. **`catch (e)` around `encodeLibrary` also catches `Error`s** (conformance.dart L82). A builder bug would then be reported as `catalogInvalid`. It is still non-empty and the message carries `e`, so this is acceptable.

### Assessment

**Task quality:** Approved (with Important 1 recommended before merge; cheap to add)

**Reasoning:** The implementation matches the brief and spec K7 exactly. On every path I traced, a changed committed key@N fails loudly. The one real gap is a degenerate catalog order in the newest-version word test.
