# Task 1 review (independent) — d4e85f6, review worktree plan-09b-review

Status: in progress
- Diff eb50a53..d4e85f6: 2 new files only (symbol_search.dart 50 lines, symbol_search_test.dart 210 lines). Confirmed.
- App gate (real): flutter test `03:03 +801: All tests passed!`; analyze `No issues found!`; format `Formatted 142 files (0 changed)`, exit 0.
- Purity: symbol_search.dart imports only symbol_library.dart (which imports dart:convert, dart:typed_data, jet_cad_2d, catalog, symbol_component; no Flutter).
- M-09l (L49 false&&): RED, -5 (tag alone Expected ['sofa.three@1'] Actual []). restored diff=0
- M-09s every->any (L36): RED, -6 (Expected ['dining.chair@1'] Actual [ ...]). restored diff=0
- M-09s category ignored (L50): RED, -2 (category alone; different fields Expected ['sofa.three@1'] Actual []). restored diff=0
- extra query not lower-cased (L25): RED -1 (upper case). restored diff=0
- extra category order by first match (L33): RED -1 (Expected ['Study','Lounge'] Actual ['Lounge','Study']). restored diff=0
- HUNT name contains->startsWith (L48): SURVIVED, `+11: All tests passed!`. restored diff=0  -> finding
- HUNT tag startsWith (L49): SURVIVED +11. restored diff=0
- HUNT category startsWith (L50): SURVIVED +11. restored diff=0
- HUNT key instead of name (L48): SURVIVED +11. restored diff=0
- HUNT tag case-sensitive (L49 tag.contains): SURVIVED +11 (every asset tag is lower case: degenerate fixture). restored diff=0
- HUNT reversed within group (L41): RED -4. restored diff=0
- Asset check: name-only mid-word term 'seats' (4 dining tables; not in key/tags), category-only mid term 'room' (all categories with Room/Bathroom), tag-only mid term 'top' (worktop) exist.
- HUNT key also searched (L50 `|| e.key.contains(term)`): SURVIVED +11. restored diff=0
- Final `git status --short`: empty (analysis_options.yaml not rewritten this time); HEAD d4e85f6.

## Verdict: Needs fixes (test-only; the implementation is correct against D3)
1. MAJOR test:80,87-90,101 — substring semantics untested: name/tag/category contains->startsWith all survive. Every single-field term is a prefix ('three', 'couch', 'closet', 'living'). Fix: add mid-word terms from the asset: 'seats' (name only, 4 dining tables), 'top' (tag 'worktop' only), 'room' (category only, includes 'Bathroom'), each through hitsOnly.
2. MAJOR test:35-39,80 — hitsOnly ignores the key, so 'three' also hits key 'sofa.three'; "match on key instead of name" (L48) and "key also searched" (L50) survive. Fix: add 'key' to fieldsHit, and a term that hits only the key (e.g. 'rect' — check: hits name 'Rectangular' too; use the hand-built fixture instead) asserting no match.
3. MINOR test:57-71,200 — tags compared case-sensitively survives: every asset/fixture tag is lower case (degenerate fixture). Fix: a hand-built entry with a mixed-case tag (e.g. 'Reading') found by 'reading'/'READING'.
- Deviations accepted: three-entry hand fixture is necessary (two symbols cannot put a category's failing first symbol before another category); category order = SymbolLibrary.categories (first appearance over all entries) matches D3 "library's category order".
- hitsOnly self-checks are real (expect on field-set difference, computed independently), but blind to the key (finding 2).

## Re-review (1b) — 7bed823 (parent 674f717)
- Diff: only apps/floor_planner/test/symbols/symbol_search_test.dart (+89 -16). Self-checks read: 'key' added to fieldsHit; seats/top/room each through hitsOnly plus an in-test `startsWith` is false check; 'wing' through hitsOnly(entries,'wing','key'); 'Reading' tag checked in-test.
- Gate (real): `03:02 +819: All tests passed!`; `No issues found!`; `Formatted 145 files (0 changed)` fmt=0.
- Mutants re-fired (scratchpad/rb1b, restored diff=0 each):
  - name startsWith (L48): RED "a term inside the name" (Expected [ ... Actual [])
  - tag startsWith (L49): RED "a term inside a tag" (Expected ['kitchen.island@1'] Actual [])
  - category startsWith (L50): RED "a term inside the category"
  - key instead of name (L48): RED -3 incl. "a term in the key alone finds nothing" (Expected empty Actual [ ...)
  - key also searched (L50): RED "a term in the key alone finds nothing"
  - tags case-sensitive (L49): RED "a mixed-case tag is found in any case" (Expected ['chair.wingback@1'] Actual [])
- Self-checks honest: seats/top/room/wing/reading each pass through hitsOnly (key now a field) and an in-test startsWith/contains check, on the real asset or the hand fixture.
- git status --short: empty.
### Verdict (1b): Approved
