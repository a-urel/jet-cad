# L1 review — independent review of e0a56d0

**Verdict: Approved.** No Important findings. Three minor ones, none blocking.

Reviewed in the detached worktree `fix-live-object-rule-review` (HEAD `e0a56d0`).
Every mutation: `cp` backup to `…/scratchpad/l1r-backup-*.dart`, mutate, run,
`cp` back, `diff` exit 0 (all runs below printed `restore diff 0`). At the end,
all three backups `diff`-equal to the files, `git status --short` empty, and
`git diff --stat HEAD` empty. No commit, no push. The only file written outside
the scratch prefix is this one.

## 1. No engine behaviour change: verified by a differential test and by reading

**Reading.** At 019aedb, `found[h]` was the last `r` in `types` order with
`h ∈ r.handles(t)` and `_isObject(h)`, and every earlier such `r` was moved into
`stray[(h, r)]`. Non-objects went to `stray[(h, r)]`. `_naming` picks the last
`r` with `r.has(t, h)`. `has` (`get<T>(h) != null`) and `handles`
(`withComponent<T>()`) read the same exact-`Type`-keyed store
(`component.dart:105,109`), so the two are equivalent. The result is the same
`found` and the same `stray` keys and values. Only `stray`'s insertion order
differs. A type registered twice gives two distinct `_Registration` objects:
the later is `identical` to `_naming`'s answer and the earlier becomes stray,
the same as before.

**`stray` is never iterated.** Grep of `lib/` for `stray`: the constructor
(`regeneration.dart:79`), the field (`:135`), the write (`:228`), the return
(`:293`) and one keyed lookup (`:646`, `s.stray[(h, r)]`). There is no other
reader.

**Differential (my own).** I inserted the 019aedb survey verbatim into
`_survey`. It recomputed `found2`/`stray2` beside the new ones and threw
`StateError('DIFFERENTIAL survey mismatch')` on any difference: the key sets,
and `identical` values for both maps.
- Full engine suite with the guard on: `+1095 -2`, and the only two failures
  are the standing `generate_document_test.dart` pair. No `DIFFERENTIAL` line
  appeared. 6 surveys in the suite had a shadowed holder (CS12, MP7–MP9, LO1/LO2
  by context) and 64 had a non-empty `stray`.
- My scratch test R1 ran with the guard on. Its catalog registers Caption
  **twice** (1st and 5th), plus SoftRect, Hinge, Post and Whisker. The document
  has groups carrying one type, two types (Hinge+Caption) and three types
  (Hinge+Post+SoftRect), plus a SoftRect-object parent with a nested group.
  Hinge+Caption strays sit on a nested group, a root-level instance, a leaf, a
  deleted group and a never-allocated handle. The test ran edits, undo/redo,
  `drift()` and `diagnostics()`, with 21 shadowed surveys. It passed with no
  mismatch. Its `names`/`objectsOf` asserts held too: `names<Caption>` was true
  on both Caption objects with Caption registered twice, `names<Post>` true on
  the 3-type group, `names<SoftRect>`/`names<Hinge>`/`names<RectParams>` false
  there, and every stray holder false.
- The guard is live: I flipped `_naming` to first→last with the guard on and
  both LO2 and R1 threw `DIFFERENTIAL survey mismatch` (`+4 -2`).
- The scratch test was moved out of the tree (`…/l1r-zz_scratch_test.dart`) and
  the guard was reverted (diff 0) before the gates.

**Suites.** The commit touches no existing test file (`git show --stat`: one
new test file). Engine `+1095 -2` = 1,090 + the 5 new LO tests. Render
`+940 ~1 -7` and app `+503` are unchanged.

## 2. The public query is the engine's rule exactly

- `names<T>` = `_naming(t, _types, h)?.isFor<T>() ?? false`. `objectsOf<T>`
  filters `withComponent<T>()` by `names<T>`. Both go through the same private
  `_naming` that `_isObject` and `_survey` use.
- `isFor<U>() => U == T`. For every concrete registered type the app will ask
  about, `U == T` holds exactly when that registration names the object.
  `names<Component>`, `names<RectParams>` (a shared interface), an unregistered
  `Memo` and a subtype (a different `Type`) are all false. These are pinned in
  LO4 and in my R1 (`RectParams` on a Post-named group). The report's rejection
  of `is _Registration<U>` is correct: M-L1g below turns `names<RectParams>`
  true.
- **Registered twice:** `register` appends unconditionally. `registerInto`
  skips a type already in the store (`parametric_system.dart:760`). Both
  registrations `isFor<T>`, so whichever is later names the object and the
  answer is `T`. Confirmed in R1.
- Export: `names`/`objectsOf` compile from `package:jet_cad_2d/jet_cad_2d.dart`
  (the LO test imports only that).

## 3. Tests are non-degenerate; mutants re-fired

The fixtures are rotated and off the origin (`onA` on top of `atA`), three
handles are burnt, and the pair under test is neither first nor last
registered. LO2 has a second catalog with the opposite order. LO2's survey
check reads the generated entity kinds, and M-L1h shows that check stands on
its own.

| Mutant | Change | Run | Red (test, line) |
|---|---|---|---|
| M-L1a | `names` = `t.components.get<T>(h) != null` | LO file, `+2 -3` | LO2 :127, LO3 :207, LO4 :235 |
| M-L1b | `names` uses the **first** registration that `has` (public only) | LO file, `+4 -1` | LO2 :127 |
| M-L1c | `_naming` walks first→last | **full engine**, `+1094 -3` | LO2 :127 only (other two = standing generate_document :59/:240) |
| M-L1d | parent check dropped | LO file, `+4 -1` | LO3 :207 (handle 16 = nested) |
| M-L1e | `node is! GroupNode` → `node == null` | LO file, `+4 -1` | LO3 :207 (handle 18 = instance) |
| M-L1f | `ComponentStore.handles` drops its sort | LO file, `+4 -1` | LO5 :256 (`[23, 21, 22]`) |
| M-L1g | `isFor` = `this is _Registration<U>` | LO file, `+4 -1` | LO4 :233 |
| M-L1h | survey names by the first registration; query untouched | **full engine**, `+1094 -3` | LO2 :145 (`[line, arc]` for `[text]`) only, plus the standing pair |
| M-R2 (own) | `names` = "live object **and carries** `T`" (`_naming != null && any(isFor<T> && has)`) | LO file, `+4 -1` | LO2 :127 |
| M-R3 (own) | `objectsOf` filters by `_isObject`, not `names<T>` | LO file, `+3 -2` | LO2 :139, LO4 :239 |
| M-R5 (own) | `_naming` loop stops at `i > 0` (the first registration never names) | LO file, `+4 -1` | LO4 :224 (the SoftRect create is refused: "not a live root-level group") |

The report's claims match these runs, with one label slip (minor finding 1).
M-L1c and M-L1h confirm the report's out-of-scope finding: no test before this
commit pinned the shadowing rule.

## 4. Deviations: true statements of the code

- **objectsOf's order.** `ComponentStore.handles` sorts ascending
  (`component.dart:42-46`, "Ascending, so query results are stably ordered").
  `withComponent` returns it, and the filter preserves order. So the brief's
  M-L1f ("objectsOf unsorted") is an equivalent mutant of the shipped code. The
  store-sort mutant the report fired instead goes red in LO5 (verified above).
  The doc comment says this.
- **Spec D5 wording about diagnostics.** `diagnostics()`'s misplaced pass is
  `if (!_isObject(document, _types, h))` (`parametric_system.dart:610`). A
  shadowed holder is an object, so it is not reported. R1 confirms this: its
  3-type and 2-type groups produced no `parametric.misplaced` diagnostic.
  "Not read by `ParametricView.paramsOf`" is also true: `paramsOf` reads
  `_survey.params[h]` (`:384-387`), the naming registration's snapshot only.

## 5. Spec 06 D5 amendment

The amendment is accurate and in the style of the existing
`**Amended by fix/post-11:**` paragraphs. It states the rule, where the rule
lives, the exposed API, the exact matching, the cost and the killers. One
sentence is loose (minor finding 2).

## 6. Cost

`_survey` previously called `_isObject` (O(types)) per holder, and now calls
`_naming` (O(types)) per holder. The asymptotics are unchanged and the survey
runs on edits, not frames. `names`/`objectsOf` have no caller in the render
package or the app at this commit, so nothing new is on the frame path. The
allocation invariants pass inside the green suites.

## Findings

**Important:** none.

**Minor:**
1. *Report label.* M-L1g's row says "LO4 :233 (`names<Component>`)". Line 233
   is `names<RectParams>`. `names<Component>` is line 234, which is never
   reached because 233 fails first. The line number is right and the label is
   wrong. Cosmetic.
2. *Spec sentence.* "Only a file makes a shadowed object in the app." The
   engine itself does not refuse a second registered type on a live object:
   LO2 builds one with a single dispatcher compound, and MP9 does too. A grep
   of `apps/floor_planner/lib` supports the claim as an app statement, since
   every `SetComponentCommand<X>` there writes to a fresh group or re-writes
   the type it edits. But it reads as an engine guarantee. Suggested wording:
   "the engine admits one (it is not refused); the app's own tools never write
   one, so in the app only a file brings one in."
3. *Out of scope, pre-existing (reported, not fixed).* When a type is
   registered twice, `diagnostics()` reports each misplaced component of that
   type **twice**, once per registration. In R1 there were 15
   `parametric.misplaced` diagnostics for 10 stray components: Caption (×2
   registrations) × 5 holders + Hinge × 5. This is harmless for L1, but a
   `register` duplicate check (or dedup in the misplaced pass) is worth a note
   if double registration is ever reachable in the app.

## Gates (run by me in the review worktree, `CI=true`, PATH=/root/flutter/bin)

- engine: `dart test` exit 1, `+1095 -2`. The failures are the standing
  `test/testing/generate_document_test.dart` pair only. `dart analyze` exit 0,
  "No issues found!". `dart format` exit 0, 158 files (0 changed).
- render: `flutter test` exit 1, `+940 ~1 -7`. The failures are the seven
  standing ones (`text_ladder` rungs 1–5, `text_lod_ladder` rungs 1–2).
  `flutter analyze` exit 0. `dart format` exit 0, 177 files (0 changed).
- app: `flutter test` exit 0, `+503: All tests passed!`. `flutter analyze`
  exit 0. `dart format` exit 0, 103 files (0 changed).
- `git status --short` is empty at the end, with no tracked change from pub
  get.
