# Task 13 review (23621eb9..953356d8)

Reviewer: task reviewer (spec + quality). I read the diff file in passes: the controller and the gallery, then the model, loader, placer and thumbnail, then the controller, gallery and fixture tests, then the model, loader and placer tests. Nothing was re-run except the focused read-only checks listed under "Checks run".

### Spec Compliance

- ✅ **Spec compliant.** Every file the brief lists has its hunk:
  - `plan_symbol.dart`, `plan_symbol_loader.dart`, `gallery_model.dart`, `symbol_placer.dart`, `thumbnail_document.dart`, `panels/panel_focus.dart` and `panels/plan_symbol_gallery.dart`;
  - `plan_controller.dart` and the barrel;
  - `test/support/symbol_fixtures.dart` and the five test files;
  - plus `permissions_controller_test.dart`, for the carried-in ruling.
- Spec P2 "Symbol libraries":
  - **Asynchronous load.** It starts last in the constructor (`plan_controller.dart`, diff 163-164).
  - **Per-source identity cache, a failed read evicted.** `plan_symbol_loader.dart` `library()`, diff 986-996.
  - **States.** `loading` until every source settles. `failed` only when there are sources and all failed. Otherwise `ready` (diff 1047-1049).
  - **Diagnostics.** An unreadable library is skipped with `libraryUnreadable`. A library under another kit is refused with `libraryKitMismatch`. A later `key@N` is dropped with `symbolDuplicate` (diff 1008-1046).
  - **Editing during the load.** S-10, S-late-fail (Review Focus 5), asserts exactly the Review Focus 5 expectation:
    - the line survives, and stateId and undoDepth are unchanged;
    - `plan.select` stays active and a second line draws;
    - exactly one diagnostic;
    - no symbol of the failed kit.
  - **Disposal.** A given loader and cache are never disposed; owned ones are (`plan_controller.dart:1135-1136` hunk, S-11).
- The gallery:
  - hides retired symbols (R2; `gallery_model.dart`, diff 869);
  - shows names through `KitNames` with the English fallback. The spec's "Words" section says a kit's words come from `KitNames`, and the brief's `PlanSymbolWords` design follows it;
  - searches the shown and stored names, the categories and the tags, folded;
  - takes an optional `filter`.
- **R-f.** `panel_focus.dart` is a verbatim copy plus one source line (checked with `diff` against `jet_cad_floor_plan/lib/src/panel_focus.dart`).
- **R-b.** `execute` now catches `PermissionDeniedError` (`plan_controller.dart:469`). S-PD pins it under readOnly: false, the encoded document byte-identical, the undo depth unchanged.
- **The F-1 ruling.** The mixed-case tag test is retired, with a comment naming the source lines and K2 (`gallery_model_test.dart`, diff 2572-2577). SF-Q keeps the query-side intent, names M-SFQ, and leaves no `skip:`.
- **`PlanLocaleScope.push`.** It is called from `didChangeDependencies` and on a controller swap (`plan_symbol_gallery.dart`, diff 497-510). S-18 pins it with two mutants.
- **Ported assertions.** I checked them unchanged:
  - **The placer test.** A whitespace-insensitive diff against `jet_cad_floor_plan/test/symbols/symbol_placer_test.dart`, with the `fixture.` key prefix applied, shows only the brief's listed adaptations:
    - imports, and `registerKitComponents`;
    - `e.symbol.*` fields and the `SymbolEntry(symbol:, unit:)` constructions;
    - `var` → `final`, and `.cast<Map<String, Object?>>()`;
    - the added SS9 and SP-1.
  - **The panel test.** Its expectations match `symbol_panel_test.dart:230-502, 534-637` line for line. The one change: `h.selected` became `armedSymbol.value`, and `> 20` became `> 5`, as the brief directs.
- ⚠️ **Cannot verify from diff:**
  - The gate results (`+293`, analyze clean, format exit 0) and the 33 mutation red lines are the implementer's quotes. I did not re-run them, per the review rules.
  - The controller should confirm the full suite on HEAD if it has not.

### Strengths

- The loader is small and correct. In `library()`, the eviction listener is attached before `load` awaits, so a failed read is never unhandled. It is only removed while it is still the kept future (`identical`), so a later successful read is never evicted.
- `_loadSymbols` guards with both `_disposed` and a run counter. S-13 runs inside `runZonedGuarded`, so M-S13 surfaces as a caught assertion instead of a flaky crash.
- **S-12 is stronger than the brief's version.** The implementer found that M-S12 survived the brief's `reads == 2`, because the cache hides a second load. They added the synchronous `state == ready` check and `same(symbols)`, which is exactly the mutation-first discipline CLAUDE.md asks for.
- **SP-1 covers the placer adaptations the brief described but did not test:**
  - the whole `SymbolComponent`, with `attachTo` and `retired`;
  - the `UnitComponent` copy;
  - no reuse of a unit-less definition.

  Its three mutants are recorded.
- The fixtures are non-degenerate. Base points are off-origin and fractional (`980.5, 640.25`), and the placements use non-zero turns and mirroring (`quarterTurns: 1, mirrored: true` at `5120.5, -2210.75`). S-2 tells the two duplicate sources apart by base point (400.5 vs 300.5).
- F-1 was escalated rather than weakened. The implementer stopped, reported, and skipped with a reason. The ruling's replacement (SF-Q) is mutation-backed.

### Issues

#### Critical (Must Fix)

None.

#### Important (Should Fix)

None.

#### Minor (Nice to Have)

1. **Stale library diagnostics after a successful retry.** `plan_controller.dart:924-951`.
   - `_loadSymbols` only adds diagnostics. After `failed` → `retrySymbols()` → `ready`, the first load's `libraryUnreadable` entries stay in `diagnostics`. `DiagnosticsLog` deduplicates and offers only `clearPlanScoped()`.
   - Task 20's bar would then show a failure that has been cured.
   - The implementer flagged this as a concern. It needs a controller ruling, either:
     - drop this kit set's library diagnostics before a new load's are added; or
     - record it as accepted.
2. **S-15's name claims more than it tests.** `test/panels/plan_symbol_gallery_test.dart:532`.
   - The name says "a tap outside it arms nothing", but the test never taps.
   - `_onSelect`'s filter guard (`plan_symbol_gallery.dart:162`, `if (widget.filter case final f? when !f(s)) return;`) is untested, so a mutant deleting it survives. A filtered-out cell is never rendered, so the guard is defensive and probably unreachable from a tap.
   - This is plan-mandated: the brief's text is verbatim. Either rename the test, or drive `onSelect` directly through the `SymbolGallery` widget (`gallery(tester).onSelect('demo.bed.double@1')`) and assert `armedSymbol` stays null.
3. **Tests without a named mutation**, against Global Constraints "every behaviour or refusal test names the mutation":
   - `plan_symbol_loader_test.dart:25` (S-1, the kit and source order), `:78` (S-3) and `:192` (S-8, a refusal);
   - `gallery_model_test.dart:231` (GM-1), `:311` (GM-8) and `:324` (GM-9).

   All are the brief's verbatim text (plan-mandated). Natural mutants exist for each, for example:
   - S-1: iterate `kits.kits.reversed`;
   - S-8: drop `load`'s `_disposed` check;
   - GM-9: `groupIdOf` using the shown category.
4. **No test pins reuse of a definition whose unit is equal but a different instance.** `symbol_placer.dart:97`, `doc.components.get<UnitComponent>(h) == entry.unit`.
   - `UnitComponent` has value `==` (`jet_cad_2d_kit/lib/src/model/unit_component.dart:80`), so the code is right.
   - But a mutant `==` → `identical(...)` would survive every test. SP-1 reuses only the same instance, and the ported reload tests are unit-less.
   - A reload-then-place case with `unitEntry()` would pin it. 2b's units make this matter.

### Checks run (named risks)

- **Do the panel_focus and placer ports drift from their sources?** No. I ran `diff` against `jet_cad_floor_plan/lib/src/panel_focus.dart`: one added header line. The placer's lines 18-78 and 239-283 diff empty, modulo a one-line offset.
- **Do the ported test assertions drift?** No. I ran a whitespace-normalised diff of `symbol_placer_test.dart` against the source, and compared the `expect` lines of `symbol_panel_test.dart` with the source: only the listed adaptations.
- **Could `PlanLocaleScope.push` notify during a build?** No. `locale_scope.dart` defers the report to a post-frame callback and checks `mounted`.
- **Could a `PermissionDeniedError` leave a partial mutation behind `execute`?** No. `UndoController._require` (`jet_cad_2d/lib/src/document/undo.dart:287-293`) checks every capability before `apply`, so `execute` returns false with nothing applied.
- **Does `UnitComponent` have value equality?** Yes (`unit_component.dart:80`).
- **What scope does `DiagnosticsLog` give?** It deduplicates, and only `clearPlanScoped()` clears (`diagnostics_log.dart:65, 85`). This is the basis of Minor 1.
- **Do the commit trailers match?** All four commits carry `Co-Authored-By: Claude Opus 5.5`.
- **Did the change stay inside its package?** Yes: no file outside `packages/jet_cad_2d_plan`, and no `analysis_options.yaml`.

### Assessment

**Task quality:** Approved

**Reasoning:**
- The loader, the model, the gallery and the controller wiring match the brief and spec P2. The rulings R-b, R-f and F-1 and the S-18 locale push are carried in.
- Review Focus 5 is pinned exactly.
- The ported assertions are verifiably unchanged, and the implementer strengthened S-12 and added SP-1 where the brief's tests let mutants survive.
- The remaining items are coverage polish and a diagnostics-lifetime ruling for the controller.
