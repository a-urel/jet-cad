# Task 2 review: engine seam E2 (isFrozen, probe), 3d84a62c..40912bf7

### Spec Compliance

- ✅ Spec compliant. Every file the brief lists has its hunk: `regeneration.dart` (`_naming`/`_isObject` diff 286-308, `_survey` 352-371, `_Survey.stray` comment 330, `_refused` 389-405, `_written` 428-440, `_cascade` comment only 462-464, `_run` 486-528), `parametric_system.dart` (constructor and `_frozen` 72-98, `typeIdOf` comment 61-63, `drift` 121, `diagnostics` 143-161, `probe` 173-245), `CHANGELOG.md` 31-35, and the three test files.
- The library code is the brief's Steps 5-7 verbatim (read line by line against the brief).
- The three test files equal the brief's Steps 1-3 once whitespace and trailing commas are normalised. Checked with a token comparison of `git show 40912bf7:<file>` against the brief's code blocks: all three `True`.
- Touch-point table, checked against every call site (`grep '_naming(\|_isObject(\|_survey('` over `lib/`):
  - with the predicate: `_survey` ×4 (`regeneration.dart:969`, `:1004`; `parametric_system.dart:644`, `:694`), `_refused` `:688`, `_written` `:739`, and `probe` `:734`, `:742`;
  - without it: `_cascade` `:796`, `:800`, the misplaced pass `parametric_system.dart:682`, and the catalog `:531`, `:567`.
  Nothing is missed and nothing extra.
- Named risk: `_cascade` reads `_isObject` without the predicate, and the brief calls that mutant equivalent. Checked `_survey`'s `referrers` construction (`regeneration.dart` `_survey`, the `live` set filters by `objects.containsKey(x)`). Keys and values are before-survey live objects, so frozen ones are excluded. With a stable predicate, the equivalence holds.
- Named risk: undo across a change of the predicate. Checked `undo.dart:190`: only `execute` passes through the expander, and undo replays stored inverses raw. So a later freeze or unfreeze never re-guards history. No finding.
- ⚠️ Cannot verify from diff: the dependents' gate results (`jet_cad_floor_plan` +2008, `jet_cad_2d_flutter` +1450 -5 standing, `jet_cad_2d_kit` +253) and the 18 mutation outcomes are the implementer's claims. I re-ran neither. The controller should spot-check one mutation (for example M-E2p-iso) if it wants independent evidence.

### Strengths

- The exclusion sits at one point, the object rule (`_naming` `regeneration.dart:28`). Every survey-derived map (views, closure, trigger, `_plan`, `_checkDangling`) inherits it. `_run` reads the predicate once (`:966`), so the hot path allocates no closure.
- `probe` restores `_applying` in `finally`, so it is nested-safe. Non-objects and frozen handles exit before any hook runs (E2-P5 asserts that `hookCalls` is empty).
- The fixtures are not degenerate. Every object sits off the origin at a rotation (`atF`, `atN`, `atS`, `atP`, `atQ`). Each frozen test first shows the relation that the freeze then cuts, as a positive control (E2-1, E2-5, E2-6, E2-7, E2-3).
- The report is honest about M-E2p-catch: 7 of 9 rows red, not "every row" as the brief says. The implementer added M-E2p-self to show that the `reach N` and `references N` rows are pinned by the inner own-object return.

### Issues

#### Critical (Must Fix)

None.

#### Important (Should Fix)

1. **Plan-mandated: `probe` blames a place reader for a contributor's `placeBox` error.** This breaks the produced contract ("the first error any of *the object's* hooks throws") and the brief's isolation goal ("a broken neighbour's error is never reported as object's").
   - Where: `parametric_system.dart` `probe` (diff 206-218, 237).
   - Cause: the isolation pass pre-runs only `reach` and `references`. A reader's `generate` (or `dissolves` or `diagnose`) calls `view.placedIn`. That calls `placeBoxOf` for every live contributor (`parametric_system.dart:436-451`), which runs the contributor's `placeBox` inside `_plan`. The outer catch then returns that error as the reader's.
   - Verified with a focused scratch script (in the scratchpad, outside the repo, run with the workspace's `package_config.json`) on `frozenScene(places: true)`, with `failingHooks = {'placeBox P'}`:
     - `probe(S)` → `HookFailure(placeBox P)`;
     - `probe(Q)` → `null`;
     - `probe(P)` → `HookFailure(placeBox P)`.
   - Why it matters: Task 11 freezes what `probe` names. A healthy reader (a room scope) gets frozen alongside the broken contributor, and the host reports the wrong object.
   - Fix options, for the human to choose:
     - (a) In the isolation pass, build a provisional view and ask `placeBoxOf` of every live contributor. Add throwers to `broken`, then resurvey. This costs O(contributors) more `placeBox` calls per probe, still off the frame and edit paths. Add an E2-P3 row for `placeBox P` probed via S.
     - (b) Narrow the contract and doc comment to "reach/references isolation only", and have Task 11 attribute through its own per-type hook guard.

#### Minor (Nice to Have)

1. **Brief inaccuracy.** Step 12's M-E2p-catch expects "every row" of E2-P2 red, but `reach N` and `references N` stay green by construction: they return through `if (h == object) return error;` (diff 214). The implementer's M-E2p-self covers them. The plan text, or the archived ledger, should record M-E2p-self as the mutant for those two rows.
2. **Contract items with no test** (`frozen_test.dart`):
   - deleting a frozen object as an ordinary group edit;
   - an `orphan`-policy referrer of a frozen object regenerating as an orphan (the test clients have only `cascade`);
   - the catalog's `names`, `objectsOf` and `typeIdOf` still answering for a frozen object.

   The catalog case is structurally safe: the catalog cannot see the predicate, so a mutant there is impossible. The other two are coverage gaps.
3. **Duplicated walk** (`parametric_system.dart` `probe`, diff 207-209): the isolation loop re-implements the survey's object walk (`identical(_naming(...), r)`). Acceptable at this size. If option (a) above lands, consider a small `_liveObjects(t, types, frozen)` helper shared with `_survey`.

### Assessment

**Task quality:** Needs fixes

**Reasoning:** The code is the brief's, verbatim. It is correct for every touch point, the `_cascade` equivalence holds, and the tests are non-degenerate with named mutants. The one real defect is plan-mandated: `probe`'s isolation covers only `reach` and `references`. As a result it attributes a contributor's `placeBox` failure to the reader that reads it. That breaks the produced contract that Task 11 relies on. The human should choose between widening the isolation pass and narrowing the contract.
