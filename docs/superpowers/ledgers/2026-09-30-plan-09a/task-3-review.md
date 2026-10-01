# Task 3 (f9e4c33) + 2b (5b9237f) review - independent

Verdict: Approved (one minor finding).

Gates (mine): app `03:46 +659: All tests passed!`, analyze No issues, format 0 changed; engine `00:24 +1121 -2` (standing); render `01:04 +974 ~1 -7` (standing). git status: only packages/jet_cad/analysis_options.yaml.

Loader read end to end (symbol_library.dart): every D5 rule has its own throw site (29 `throw SymbolLibraryError`): unreadable bytes (catch-all, line ~91), codec diagnostics (cycle repair), nested instance / group, component missing, duplicate (key,version), key/tag case (extra, from D3), non-empty children (hand-built JSON case R04), non-finite basePoint, leaf owner, text/fill/attrib, point, the style allow-list (layer 0; linetype 2/3/4 via ReservedHandles; text style; colour; lineweight; transparency; flags; linetypeScale finite), payload arity, coordinate finite/+-1e6, scalar finite, zero-length line, polyline <2 vertices, circle/arc radius <= linear tolerance, zero sweep. Entries follow tree.definitions order, leaves sorted by handle, categories first-appearance. A definition with zero leaves is accepted: spec D5 does not forbid it; judged fine. Pure Dart: imports only dart:convert, dart:typed_data, jet_cad_2d, catalog.dart and symbol_component.dart (catalog.dart imports no Flutter or dart:io; the tool files that do are not imported by it). The polyline "bulge" rule is replaced by "no scalars" (the codebase has no bulge); the implementer flagged it, spec should be amended.

Findings
1. MINOR symbol_library.dart (zero sweep, `p.scalars[2].abs() <= Tolerance.standard.angular`): mutant `== 0` stays green (`+46: All tests passed!`); no test uses a tiny non-zero sweep below the angular tolerance. Add one case.
No other finding. Messages name the handle (mutant dropping it from the no-component message: R01 red).

Mutant matrix (real lines, symbol_library_test.dart; every backup diff exit 0)
- DASHED(6) accepted: RED R13
- layer check off: RED R12
- colour check off: RED R15
- transparency check off: RED R17
- flags only bit 1 checked: RED R18b (unpickable)
- text style check off: RED R14
- duplicate (key,version) off: RED R02
- unreadable bytes: only FormatException caught: RED R00
- scalar arity ignored: RED R20c; coord arity ignored: RED R20
- scalar finite off: RED R22
- coordinate bound off: RED R21c, R21d
- entries reversed: RED L1; leaves unsorted: RED L1, L2
- categories not unique: RED L3
- message drops handle: RED R01
- children guard off: RED R04
- no-component guard off and leaf-owner guard off: did not compile (flow analysis), not counted; the implementer's continue-variants are not re-fired by me
- zero sweep exact-zero-only: GREEN (finding 1)
2b SC6: fromJson tolerating a missing tags / version / name, each alone: RED on exactly `SC6 fromJson refuses a map without "tags"` / `"version"` / `"name"` respectively.
