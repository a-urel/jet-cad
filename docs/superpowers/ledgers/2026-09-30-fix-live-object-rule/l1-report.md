# L1 report — the engine answers "which registration names this object"

**Commit:** `e0a56d0` on `fix/live-object-rule` (not pushed).
Files: `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`,
`packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`,
`packages/jet_cad_2d/test/parametric/live_object_rule_test.dart` (new),
`docs/superpowers/specs/2026-09-24-parametric-layer-design.md` (D5 amendment).

## The private rule
`_naming(t, types, h) -> _Registration<Component>?` in `regeneration.dart`:
null unless `t.tree[h]` is a `GroupNode` whose parent is the root; else the
**last** registration (walks `types` from the end) whose component `h`
carries; null if none. O(types).
- `_isObject` is now `_naming(...) != null`.
- `_survey`: for each registration `r` and each holder `h`,
  `identical(_naming(t, types, h), r)` → `found[h] = r`, else
  `stray[(h, r)]`. Behaviour identical to before: previously the later `r`
  overwrote `found[h]` and pushed the earlier into `stray`; now the earlier
  goes to `stray` directly. Same final `found` and same `stray` key set;
  only `stray`'s insertion order changes, and `stray` is only ever looked up
  by key (`_heldBefore`), never iterated; `found` is sorted before use. Two
  registrations of the same `T` are distinct objects, so the later still
  names and the earlier is stray, as before. Engine suite unchanged
  (1,090 + 2 standing before; 1,095 + 2 standing after = +5 new tests).

## The public API (`ParametricCatalog`)
- `bool names<T extends Component>(CommandTarget t, Handle h)` =
  `_naming(t, _types, h)?.isFor<T>() ?? false`.
- `List<Handle> objectsOf<T extends Component>(CommandTarget t)` = holders
  from `t.components.withComponent<T>()` filtered by `names<T>`; fresh list.
- Doc comments state it is the engine's own rule (D5), the one the survey
  uses, and that a client asking "is this a live `T`" must ask here.
- **Matching:** `_Registration.isFor<U>() => U == T` — the registered type
  argument compared as a `Type`. Exact: `names<Component>` and
  `names<RectParams>` (a shared interface of registered types) are false;
  a subtype of a registered type is not that type; an unregistered `T` is
  false. Rejected `r is _Registration<T>` / `r.type is ParametricType<T>`:
  Dart generics are covariant, so both accept every supertype
  (`names<Component>` true for everything) — mutant M-L1g pins this.
- **Registered twice:** `register` appends unconditionally;
  `registerInto` skips a type already in the store (Ruling 06-13), so the
  second `typeId`/factory is ignored by the store. Both registrations `has`
  the same component; the later names the object and it `isFor<T>`, so
  `names<T>` is true either way. No check added (no path found where the
  answer is wrong).
- **Cost:** `names` O(registered types); `objectsOf` O(k · types) for k
  holders, plus the store's own sort. No frame path calls either today (the
  app's callers run on edits, grip-cache rebuilds, tool events and the band
  cache's rebuild). No caches added.
- **Export:** `lib/jet_cad_2d.dart:59` already exports
  `parametric_system.dart`; nothing else needed (the new test imports only
  `package:jet_cad_2d/jet_cad_2d.dart`).

## Tests (`test/parametric/live_object_rule_test.dart`)
Two local catalogs of five types (SoftRect, Hinge, Post, Caption, Whisker)
and the swap (SoftRect, Caption, Post, Hinge, Whisker): the pair is never
first or last. Three handles burnt before each fixture; every group rotated
and off the origin (`onA`).
- **LO1** one type (Caption): `names<Caption>` true, the four other
  registered types false; `objectsOf<Caption>` = [h], others empty.
- **LO2** Hinge + Caption on one root-level group, through the dispatcher,
  in both catalogs: the later registration names (query, `objectsOf`,
  `system.catalog`), and the survey agrees — the children generated are
  `[text]` (Caption) or `[line, arc]` (Hinge); `drift()` empty. Order flips
  both answers.
- **LO3** nested group, root-level `InstanceNode`, leaf, deleted object's
  handle, never-allocated handle, each carrying a Caption written straight
  into the store (`components.attach`, as fix/post-11's fixtures do): all
  five types false for each; `objectsOf<Caption>` = only the live one.
- **LO4** exactness: `names<RectParams>`, `names<Component>` false on a
  live SoftRect; a doc-only `Memo` component (never in a catalog) false
  alone and beside a SoftRect; `objectsOf<Memo>` empty.
- **LO5** created in order h3, h1, h2 → `objectsOf` = [h1, h2, h3].

## Mutants (each: cp backup to `…/scratchpad/l1-backup-*.dart`, mutate, run, cp back, `diff` exit 0 — all eight diffs exited 0)
| Mutant | Change | Red |
|---|---|---|
| M-L1a | `names` = `t.components.get<T>(h) != null` | LO2 :127, LO3 :207, LO4 :235 |
| M-L1b | `names` walks registrations first→last (public query only) | LO2 :127 |
| M-L1c | `_naming` walks first→last (survey + query), **full engine suite** | only LO2 :127 (1,094 pass, 2 standing, no pre-existing test red) |
| M-L1d | parent check dropped | LO3 :207 (handle 0x16, the nested group) |
| M-L1e | `node is! GroupNode` → `node == null` | LO3 :207 (handle 0x18, the instance) |
| M-L1f | see below: `ComponentStore.handles` drops its sort | LO5 :256 |
| M-L1g | `isFor` = `this is _Registration<U>` | LO4 :233 (`names<Component>`) |
| M-L1h (own) | `_survey` names by the **first** registration, query untouched, **full engine suite** | only LO2 :145 (the generated kinds: `[line, arc]` instead of `[text]`) |

M-L1h exists because M-L1c's first red is the query assertion; M-L1h shows
the survey assertion is load-bearing on its own.

## Deviations
1. **`objectsOf` has no sort of its own.** `ComponentRegistry.withComponent`
   is ascending by contract (`ComponentStore.handles` sorts, "so query
   results are stably ordered") and a filter keeps order, so the brief's
   M-L1f ("objectsOf unsorted") is the shipped code and an equivalent
   mutant; with a redundant sort, no mutant could have reached the order
   through this API. LO5 instead pins the order end to end, killing the
   store's sort being dropped (M-L1f as fired). Doc comment says so.
2. **Spec wording.** The brief's D5 text said the earlier component is "a
   stray the diagnostics report". It is not reported: `diagnostics()`'s
   `parametric.misplaced` pass reads only non-objects (`!_isObject`), and a
   shadowed holder is an object. The amendment states what is true (kept
   in the survey's `stray`, not regenerated, not reported today) rather
   than change engine behaviour, which the brief forbids.

## Gates (`CI=true`, PATH=/root/flutter/bin)
- engine: `dart test` exit 1 — `+1095 -2`, the two failures are the
  standing `test/testing/generate_document_test.dart` pair; `dart analyze`
  exit 0 "No issues found!"; `dart format` exit 0 (158 files, 0 changed).
- render: `flutter test` exit 1 — `+940 ~1 -7`, the seven standing
  (`text_ladder` rungs 1–5, `text_lod_ladder` rungs 1–2); `flutter analyze`
  exit 0; `dart format` exit 0 (177 files, 0 changed).
- app: `flutter test` exit 0 — `+503: All tests passed!`; `flutter analyze`
  exit 0; `dart format` exit 0 (103 files, 0 changed).
- `dart pub get` was needed once in the worktree (packages unresolved); it
  changed no tracked file; `analysis_options.yaml` not committed.

## Found outside scope (reported, not fixed)
- **No pre-existing engine test pinned the shadowing rule.** M-L1c and
  M-L1h (survey named by the first registration) pass all 1,090 prior
  engine tests; only the new LO2 catches them.
- **`ParametricView.objectsOf<U>` matches by `is`, not exactly:**
  `view.objectsOf<Component>()` lists every object and `objectsOf<RectParams>`
  lists every rect-like object, whereas `catalog.objectsOf<U>` is exact. Same
  name, different semantics for a supertype; identical for a concrete
  registered type. Worth a line in L2 or a later note.
- **Shadowed components are not in `diagnostics()`** (see deviation 2); a
  file's shadowed `WallParams` is silent.
- Still open (from fix/post-11's list, not touched): 06 D8's cleanup
  detaches only the naming registration's component on delete.
