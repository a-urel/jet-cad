# Task 8 review: PlanController core (6df8967a..551985c8)

### Spec Compliance

- ✅ Spec compliant. The diff holds every file the brief names (10 under `lib/src/controller/`, `symbols/plan_symbols_state.dart`, `export/registries.dart`, the barrel, the harness, six test files), and nothing outside `packages/jet_cad_2d_plan` (diff stat, 20 files).
  - Check run: I extracted every `Create \`...dart\`` block from the brief and compared it with the committed file, ignoring whitespace and trailing commas. All 10 controller files, `plan_symbols_state.dart`, `registries.dart`, and four of the six test files (`locale_separator`, `camera`, `covariance`, `plan_change`) match the brief exactly. A token diff of the other two (`plan_controller_test.dart`, `lifetimes_test.dart`) shows only insertions: C14, the C-svc commit block and the C-grips preview block. No brief assertion was changed or removed, which matches report deviations 1 and 2.
  - P1 lifetimes. The swap order in `_replace` (diff 902-923) is:
    1. `old.tools.activate(old.select)`, which cancels the tool (`tool.dart:169-180`: `_active.cancel(context)`);
    2. the tracker flush;
    3. `disposeKitProducts`: kit tools, then `dispatch.close()`, then the grip providers, then `shared.dispose()` (session.dart, diff 1552-1563);
    4. `_open`, which runs the factories over the new session after `_session` is reassigned (diff 873-874).
    C-life1 pins this order through `KitLog` (`tool-1, grips-1, cache-1, cache+2, tool+2, grips+2`).
  - P1 shared. Keyed by `(kitId, T)` (shared_cache.dart, diff 1614). Disposables are disposed last-made-first with the document (diff 1630-1637). A create that asks for itself throws `StateError` (diff 1617-1619). C-life2 covers all three.
  - P2:
    - `save` encodes the one design document through `encodePlan` (diff 787-792).
    - `PlanFormatException` reaches the caller as thrown, with no re-wrap (diff 815-818).
    - A refused load returns before `_replace`, so the document, `diagnostics`, `loadDiagnostics` and `missingKits` are untouched. C3 and the added C14 pin this, C14 by identity.
  - Review Focus 3. C-covariance builds two kits with different `T` and drives `registerInto`, `gripsFor`, `fieldsOf`, `commitField`, `recolour` and `colourOf` through `PlanType<Component>`. `ToolSettingsStore` holds `PlanToolSettings<Object>`, whose `fieldsOf` takes `Object`, so no covariant parameter is exposed.
  - Review Focus 4. `load` settles first (diff 806), then `_replace` cancels the tool. C-swap-mid-shape asserts all of it: 2750 in the old plan, 1800 in the new one, `isMidShape` false, `activeTool == plan.select`, `tool-1` in the log.
  - Task 7 carry. `_open` calls `_readManifest`, which runs `checkManifest(manifestOf(d), usedKits(d), kits)` and reports into the log (diff 880-896). That covers the constructor's json and every load. Each `decodePlan` call gets a fresh `<Diagnostic>[]` (diff 631, 808).
  - CLAUDE.md:
    - Change reports are sorted by `Handle.value` (diff 382, 395-396).
    - The scale bound uses `Tolerance.standard` (diff 91-97).
    - Nothing is allocated per mutation while nothing listens: `_note` returns first (diff 484). C-ch4 counts this with `debugChangeScans`.
    - No `analysis_options.yaml` is in the diff.
- ⚠️ Cannot verify from diff:
  - The report's runs: 64 tests, `flutter analyze` clean, format clean, and every mutation red. I did not re-run any of them. The controller may want to spot-check M-C-swap-b and M-C-life1.
  - That `git diff main` stays empty for `jet_cad_2d_flutter` and the engine. This commit touches neither, but the claim spans the branch.

### Strengths

- A clean, verbatim realisation of a detailed brief. The three additions go past the brief in useful ways:
  - C14 pins the Task 7 carry with two by-identity mutations.
  - C-svc now runs `SlabTool` end to end through `settingsOf`.
  - C-grips now covers the dispatch's `preview`.
- `PlanChangeTracker` is robust:
  - `_note` ignores a document it is no longer attached to (`identical(from, _document)`, diff 484).
  - `detach` restores `onAfterMutate` only when the hook is still its own (diff 448-450), so a later stacker such as Task 11's cannot be clobbered.
  - The stale microtask after a swap flushes harmlessly (empty `_touched`).
- Tests avoid degenerate fixtures: slabs placed off the origin and turned, a non-identity camera, and expectations computed by forward transforms. Every test except C-ch7 names its mutation inline.
- The report is candid about where a mutation went red by a different route than the brief predicted (M-C-life2b, M-C-ch5).

### Issues

#### Critical (Must Fix)

None.

#### Important (Should Fix)

None.

#### Minor (Nice to Have)

1. **`PlanController.dispose` breaks `disposeKitProducts`' own precondition.**
   - Where: plan_controller.dart, diff 1298-1303.
   - What: `disposeKitProducts` is documented "The active tool must be select already." (session.dart, diff 1551). `dispose` calls it without `session.tools.activate(session.select)` first.
   - Effect: with a kit tool active (C10 ends mid-shape), that tool is disposed while `ToolController` still holds it. It is never `cancel`led, and `ToolController.dispose` (`tool.dart:185-187`) then calls `removeListener` on a disposed notifier. Flutter tolerates that today, so nothing fails.
   - Fix: move `session.tools.removeListener(_onTools); session.tools.activate(session.select);` ahead of `disposeKitProducts`, as `_replace` does. The implementer raised this as Concern 1.
2. **A refused `load` still settles pending input into the current plan.**
   - Where: plan_controller.dart, diff 806 (settle before decode).
   - What: with a field pending, a `load` that throws commits that value, adds an undo step and dirties the plan. That stretches the doc comment's "changes nothing" (diff 803-804) and spec P2 (spec :290-291).
   - Why Minor: today's `FloorPlanController.load` does the same (`floor_plan_controller.dart:1192-1193`, `_settle?.call()` before `_decode`), so this is a faithful port of today's contract.
   - Possible fix: decode first, then settle, then `_replace`. That keeps Review Focus 4 (the settle still lands in the old plan before the swap) and makes a refused load inert.
   - Report inaccuracy: the report's self-review says "a refused load still settles; C11 expects exactly that". C11's load (plan_controller_test.dart, diff 2910) is a successful one. No test covers a settle on a refused load either way.
3. **A throwing kit factory during a swap leaves the controller half-swapped.**
   - Where: `_replace`, diff 908-910.
   - What: the old kit products are already disposed, and `_session` points at a partially built session. The old session is in neither `_dropped` nor `_session`, so it is never disposed.
   - Why Minor: this is Task 11's guard territory, and the implementer flagged it as Concern 2. Task 11's brief should name it explicitly, including the old session's disposal.
4. **No test pins that `decodePlan` gets a fresh list on every load.** M-C14b catches a load that forgets the list before decoding. It does not catch one controller-level buffer reused across loads (two successful loads with one unreadable component each would show two entries). Coverage only; the code is correct (diff 808).
5. **C-ch7 names no mutation inline.** The test (plan_change_test.dart, diff 2618-2635) is reddened only by M-C-ch5, which is commented in C-ch5. Plan-mandated (the brief's text). Add `// M-C-ch5` at its assertion for traceability.

### Assessment

**Task quality:** Approved

**Reasoning:** The library code is the brief's code verbatim. It meets P1 lifetimes, the `shared` cache rules, P2's load, save and diagnostics contract, and Review Focus 3 and 4, and tests that name their mutations pin each of these. The remaining items are a teardown-order inconsistency, a ported edge in refused-load semantics, and coverage polish.
