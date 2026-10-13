# PR #11 fixes: scoped re-review (344a4170..ec365c03)

### Finding Verdicts

- **PR1: rule 15's zero-length polyline check is O(n²) and allocates on untrusted bytes.** ADDRESSED. symbol_library.dart `_allWithinTolerance` is now a single pass over `p.coords` with no `Vector2` (diff lines 215-226). `c[0]`/`c[1]` are safe because the even-count check, the finiteness check and `pointCount < 2` all run before it (symbol_library.dart:413-442). `isDegenerateSegment` is still used by the line case (:436), so its import is still needed. The refusal message and docs/kits.md:41 now describe the box, and the spec amendment ec365c03 matches. V15ae runs 200k points with a 5 s stopwatch. The fix measured about 40 ms and the pairwise mutation 36 s, so the margin is roughly 125x and the bound still tells the two apart. `bytesOfJson` runs before the stopwatch starts. The bound is not flaky on a slow runner. V15af and V15ag cover the end of the loop and the `&&`. Each has a named mutation, and the mutation outputs are quoted.
- **PR2: kitDepsProblems' unguarded loadYaml crashes on a malformed pubspec.** ADDRESSED. kit_deps.dart:97-103 catches `YamlException` and adds `<dir>: pubspec.yaml is not readable YAML: <msg>`, then continues. The script still passes a null-name pubspec through (check_kit_deps.dart:30-33). D17 (unit) and D18 (script) cover it, and M-D17a, M-D17b and M-D18 are named. The `dir` field is new on `PackageSource`. Its only callers are the script and the test.
- **PR3: CatalogArc doc says every arc is counter-clockwise.** ADDRESSED. catalog.dart:39-41 and docs/kits.md:64-66 now say the sweep is signed (positive counter-clockwise, negative clockwise, radians). This is doc only.
- **PR4: regex directive parsing misses `import/*c*/'package:...'`.** ADDRESSED. import_walker.dart and kit_deps.dart now read directives with `parseString(...).unit.directives`: the namespace URI, every configuration URI and the part URI. P6, P7, P8 and P5, and D19, D20, D8 and D5 cover it, with mutations named and quoted. In jet_cad_2d_kit, `analyzer: ^13.3.0` appears only under dev_dependencies (pubspec.yaml:29). `grep analyzer packages/jet_cad_2d_kit/lib` finds nothing. It is a dependency of tool/ci (publish_to: none). 13.3.0 matches the version the workspace lock already resolved (pubspec.lock:12-19, previously transitive).

### New Breakage in the Fix Diff

- **Important (CI timing risk, not observed): tool/ci/test/kit_deps_test.dart:303-337, "the script" group.** Every `check()` call now cold-compiles analyzer through `dart run check_kit_deps.dart`. I measured 5.05 s and 5.07 s per run on a 12-core Mac (user time 8 s). D11 calls `check` twice, so it takes about 10 s locally, against the default 30 s per-test timeout. A 4-vCPU ubuntu-latest runner, with other tool/ci test files running at the same time, could plausibly take 2-3x as long, which puts D11 near the limit. Cheap fix: `timeout: Timeout.factor(4)` on the group, or compile the script once in `setUpAll` (`dart compile kernel`/`exe`) and run that. The CI step `dart run tool/ci/check_kit_deps.dart` also pays about 5 s, which is acceptable.
- **Minor: analyzer 13.3.0 needs `sdk: ^3.11.0`, while jet_cad_2d_kit declares `sdk: ^3.6.0`.** It is a dev-only dependency, publish reports 0 warnings and the flutter >=3.44 floor implies the newer SDK, so there is no consumer impact.

### Out-of-Scope Observations

None.

### Verdict

**Fix round:** All findings are addressed. The one Important item is a CI timing risk the fix introduced (the script-test timeout margin), not a correctness defect. It costs one line to fix before pushing, or it can be accepted if the first CI run shows D11 well under 30 s.
