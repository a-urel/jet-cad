# Task 1 review: the engine, node commands carry components (D-1 to D-4)

Base 5a0af462, head 90044db4. Reviewed from the diff package; the
named-risk checks outside the diff are listed at the end. No test or
mutant was re-run.

### Spec Compliance
- ❌ Issues found:
  - `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart:443-449`
    (`ParametricView.objectsOf`'s doc) is unchanged. The brief (Step 5,
    "`parametric_system.dart:386-392, 442-446, 598-604`") and spec D-8
    ("`ParametricView.paramsOf` and `objectsOf`") both name it. It still
    says that an object an edit "lost, re-parented or deleted is not listed
    although its component may still be attached". After D-1/D-4 that is
    true only of a re-parent whose re-add carries the snapshot. The
    implementer edited `dissolves`' doc (`:85-91`) in its place. That edit
    was also needed, since it named 06 D8's cleanup, but it does not
    substitute for this one. This gap is in the docs only, so it is listed
    as Minor below.
  - Everything else in the brief matches the diff:
    - `checkRestorable` and `restore` calling it (`component.dart:179-215`).
    - `AddNodeCommand` field, constructor, `capabilities` and apply order
      (`commands.dart:393-432`).
    - `RemoveNodeCommand`'s static `capabilities`, the snapshot read before
      `removeNode`, `detachAll` after it, and the inverse carrying `index`
      and `components` (`commands.dart:476-490`).
    - D-4: `_detachLayer` gone, the dissolve reduced to `_subtreeRemoval`,
      `cleanup` gone, early return on `seeds.isEmpty`, loop over `plan`
      (`regeneration.dart` hunks at 483, 553, 950-1006).
    - The seven re-pins, exactly as the brief words them.
    - N-1 to N-7 and S-1, verbatim except for the N-4 fixture fix below.
- ⚠️ Cannot verify from diff:
  - The gate summaries and the 16 mutant red lines. Each one in the report
    is plausible against the code; reasoning confirms M-5, M-9, M-10, M-14
    and M-16 in particular (see Strengths). The controller should
    spot-check one mutant if the ledger requires it.
  - CHANGELOG (spec D-8): not in Task 1's file list. `progress.md` assigns
    it to T3.

### Strengths
- The production change is small and is exactly the spec's D-1 sequence.
  - `AddNodeCommand.apply` (`commands.dart:418-422`) makes every check
    (duplicate, `checkRestorable`, then `addNode`'s cycle and index checks)
    before the first write. No compensating rollback is needed, so the
    M-14 dangling-entry hazard the spec rejects cannot arise.
  - `RemoveNodeCommand.apply` (`commands.dart:481-484`) reads the snapshot
    before both mutations.
- `restore` is simpler after the split (`component.dart:206-215`) and
  behaves the same: the check still runs first, and the writes follow
  snapshot order.
- D-4 is a clean deletion. `lost` keeps seeding the closure, and the early
  return stays equivalent because `lost ⊆ seeds` (`regeneration.dart:950-981`).
  The removal of the now-unused `object_layer.dart` import is correctly
  explained in the report.
- The N-4 deviation is sound, with no assertion weakened. The encoding
  includes `handleSeed`, so the brief's `before = enc(doc)` taken before
  `handleSeed.next()` would fail against a correct implementation. Moving
  `next()` above it, with a comment, is the minimal fix
  (`node_components_test.dart`, the diff's lines 860 and 931).
- The report is honest about M-5. N-6 cannot kill it, because the bare
  branch's undo reverses the unknown order and the carrying branch's
  restore reverses it back. The report names N-2 and N-5 as the real
  killers.
- The fixtures meet the constraint on the points that matter for
  detection:
  - The removed node is the third handle allocated, under a turned group
    40 m off the origin, at index 0 of three children.
  - It carries two registered components and two unknown payloads, both
    out of type-id order.
  - N-4's unmapped case puts the mapped type first, so M-16 is
    distinguishable.
- PG1 gained a real negative: no `SetComponentCommand<Gauge>` in the
  inverse (`page_test.dart:231-234`). Without it, `restoredBy` alone would
  stay green under M-12.

### Issues
#### Critical (Must Fix)
None.

#### Important (Should Fix)
None.

#### Minor (Nice to Have)
1. **`objectsOf`'s doc is stale**
   (`parametric_system.dart:445-447`, at the base as `:442-446`).
   - What: see Spec Compliance; the brief and spec D-8 both name this doc.
   - Why it matters: this is client-facing API documentation. It tells a
     type author that a deleted object's component may still be attached,
     which is no longer the case.
   - Fix: say that a lost or deleted object no longer has its component
     (its removal took it, node-components D-4), and that a re-parented
     one keeps it only when the re-add carries the snapshot. Use the same
     wording as `paramsOf` at `:386-392`.
2. **Stale wording in DV1** (`dissolve_test.dart:146-148`, and the comment
   in the diff's context above `ruled`, near `:309`).
   - What: the title still says the component is "detached in the edit"
     and that "the cleanup are untouched". The cleanup no longer exists.
     The context comment "the removals need geometry and structure, the
     detach components" names a detach the dissolve no longer plans. The
     report flags the title. The brief's "wording kept but for what the
     spec changes" covers both edits.
   - Why it matters: the test name now describes a mechanism that the same
     test pins as absent.
   - Fix: retitle, for example "...its component taken with its node...;
     the guard is untouched...". Reword the comment to "the removals need
     geometry, structure and components".
3. **`_Registration.detach` is dead in lib** (`parametric_system.dart:791`).
   - What: after D-4 nothing in `packages/*/lib` calls it (grep for
     `.detach(`). It is kept only as a mutant template.
   - Why it matters: dead API invites a future planner to reintroduce
     no-op detaches.
   - Fix: delete it in this task, or record it for T3. The mutants can
     inline `SetComponentCommand<T>(h, null)`.
4. **Same-type collision across documents: spec-level, not a code defect**
   (`component.dart:186` versus `:209` and `:41`).
   - What: `checkRestorable` checks only that the type id maps to some
     store. A snapshot from another document whose type id maps to a
     different Dart class passes the check. `ComponentStore<T>.set` then
     throws a covariance `TypeError` inside `restore`, after
     `tree.addNode` has written (`commands.dart:421-422`). That breaks
     I-3 ("restore ... can no longer throw", spec D-1 step 4).
   - Why it matters: the scenario is only reachable when two registries
     bind the same id to different classes. The code follows the spec
     verbatim, and `RemoveDefinitionCommand` had the same gap before. This
     comes from reading Dart's covariant-parameter check, not from a run.
   - Fix (optional, spec owner's call): have `checkRestorable` also check
     that the store accepts the value, or record the case under the
     spec's Risks.
5. **Fixture nuance, plan-mandated, no surviving mutant identified.**
   - What: in `scene()`, the sibling carries the same `ObjectLayer(kLayer)`
     and the same `earlier()` payload as the node. Only `Mark` differs.
     S-1 gives all three handles one registered type (`ObjectLayer`, the
     same value) and an identical `a.earlier` payload. Only `z.later`
     differs, by `h.value`.
   - Why it matters: the constraint asks for "the same types with other
     values". No named or obvious mutant (wrong-handle snapshot, wrong-
     handle restore) survives, because `Mark` and `z.later` differ. So
     this is noted, not blocking.
6. **Cosmetic: a broken reflow in the PG1 comment**
   (`page_test.dart:216-218`). "Planned on a / copy through the / expander"
   should be reflowed into full lines.

### Assessment
**Task quality:** Approved
**Reasoning:** The engine change is spec D-1 to D-4 exactly. Every refusal
comes before the first write, the re-pins are the seven named, and the
tests are non-degenerate with each named mutant plausibly killed. The only
spec gap is one doc paragraph the brief named (`objectsOf`), which should
be fixed before the branch closes; nothing in the behaviour needs a change.

#### Named-risk checks made outside the diff
- **A lib re-parent (remove-then-add) that would now silently drop
  components.** Grepped `AddNodeCommand(` and `RemoveNodeCommand(` in
  `packages/*/lib` and `apps/*/lib`. Every `AddNodeCommand` is on a fresh
  handle (the parametric tools, `startup_plan`, `symbol_placer`,
  `generate_document`). The `RemoveNodeCommand` sites are the select tool
  and `_subtreeRemoval`. No re-parent was found in lib, which matches the
  spec's D-5.
- **Stale "cleanup" docs left in lib.** A grep for `06 D8`, `D8's cleanup`,
  `_detachLayer`, `survives a delete` and `keeps its component until` in
  `packages/*/lib` found nothing. That led to reading `objectsOf`, which
  turned up Minor 1.
- **`ComponentSnapshot.isEmpty` covering unknown-only snapshots** (it
  drives `AddNodeCommand.capabilities`). `component.dart:86` defines it as
  `components.isEmpty && unknown.isEmpty`, which is correct.
- **`restore` throwing after `addNode`.** Read `ComponentStore.set`
  (`component.dart:41`) and `_typeOf` (`:100`, `:113`), which led to
  Minor 4.
