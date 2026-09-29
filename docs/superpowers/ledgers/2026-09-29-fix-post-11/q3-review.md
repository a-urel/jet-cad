# Q3 review: 47a7fcb (ParametricEdit refuses a parametric component off a live root-level group, post-11 (d))

Reviewer: independent. Worked in the detached worktree `.claude/worktrees/fix-post-11-review` at `47a7fcb`. Nothing committed or pushed. No `.dart` file was checked out: every mutant went cp to backup, mutate, run, cp back, `diff` (exit 0). The worktree ends clean apart from `packages/jet_cad/analysis_options.yaml`, which `flutter pub get` rewrote and which is not staged. All transcripts are in the scratchpad under the `q3r-` prefix.

## Verdict: **Approved**

I found no Important defect in the commit. There is one merge-order condition, which the ledger already rules on and which I confirmed with a probe: Q2's liveness filter for `wall_grips._endsAt` (item (e)) must land before merge. See I-1.

## 1. The guard is right and complete

I read `_written`, `_heldBefore`, `_Survey.stray`, `componentOrNull` and step 3 of `_run`.

**Why "wrote" is the right condition.** The rule is: a registered component that is non-null after `inner` and not `==` to the before-survey's value for that type on that handle. The literal "carries" rule would refuse two edits the specs allow:
- **Every delete.** Spec 06 D8's detach is planned after the guard.
- **Spec 08 D4's re-parent.** The object stops being one and keeps its component (CS7).

My M-Q3h re-fire below confirms both. The comparison is exact `==` on a stored value, which follows the non-negotiables. `_isObject` is evaluated on the tree after `inner`, which is the state D5 cares about.

**Probes.** File `q3r-probe_test.dart`, copied into `test/parametric/` to run, then removed; output in `q3r-probe-out.txt` and `q3r-probe-out7.txt`.

| Probe | Edit | Result |
|---|---|---|
| PR5 | delete B (children and node) and write a **different** ClipRect (B's own type) on B, in one compound | refused `7D0`; canon unchanged |
| PR6 | delete B and write an `==` ClipRect (a new instance) on B | lands; the cleanup detaches it (store null, node gone); undo restores canon |
| PR7 | re-parent A under a root group (CS7 style), alone | lands; A keeps its ClipRect under `g` (08 D4) |
| PR7 | the same re-parent plus a new ClipRect on A | refused `3E8`; A is back at the root with its ClipRect |
| PR8a | add a nested group and a Hinge on it, in one compound | refused |
| PR8b | a Hinge on the root node | refused |
| PR9 | on a live Hinge object, write a new Hinge then delete it, in one compound | refused (see m4) |
| PR10 | a file's misplaced Hinge on a dead handle, written to a new value and then back (net `==`), in one compound | lands (a net no-op, correct) |
| PR10b | a ClipRect written on that same misplaced holder | refused |
| PR4a | a custom non-`SetComponentCommand` wrapper that writes a Hinge on a dead handle and reports `touched`, in a document with objects | refused |
| PR4b | the same wrapper, **under-reporting `touched`** (empty set) | **lands** (see m1) |
| PR2 | the same wrapper, reporting `touched`, in a document holding **no** parametric component | **lands**; `diagnostics()` then reports `parametric.misplaced` (see m1) |
| PR3 | a client executing `ParametricReplay(CompoundCommand([SetComponentCommand<Hinge>(dead, …)]))` on the same empty document | **lands** (see m1) |
| PR1 | a plain `SetComponentCommand<Hinge>` on a dead handle in the empty document | refused (`_setsParametric` wraps it) |

So through `execute`, a component written by a `SetComponentCommand<T>` or a compound of them is always caught, whatever the other children do. That was the defect in (d). The only ways around the guard are a client command that is not a `SetComponentCommand`, used on a document where D2's fast path skips wrapping, or one that breaks the `touched` contract. Both are pre-existing properties of 06 D2 and the command contract, not defects of this commit (m1).

## 2. Nothing legal is refused

**Every app `SetComponentCommand` site.** I grepped `packages/*/lib` and `apps/*/lib`. The only hits outside the engine's own are in `apps/floor_planner/lib`, and I checked each:
- **Tools.** Box, wall, separator, room, opening and dimension tools, plus `startup_plan`, all add `parent: doc.rootHandle` in the same compound.
- **Selection panel.** `selection_panel` checks `_isObject<T>` (root-level group) at every site, including `_setJustification` through `_wall` and `_flip` through `_selected`.
- **Object grips.** Wall, opening, room, separator and dimension grips all receive `group` from `grip_cache.dart` ~l.353, which offers object grips only for a root-level `GroupNode`.
- **`wall_grips._keptPut`.** Filters for liveness.
- **`page_panel`.** `PageComponent` is not registered as parametric.
- **Engine and render libs.** No other writer. Delete, the cascade (`_subtreeRemoval`) and D8's cleanup never attach.

**Undo and redo.** Neither goes through `_run`: `undo.dart` applies the popped inverse directly, and the expander is called only in `execute`. MP5 exercises delete, undo, redo, undo again. My re-fire of M-Q3e shows the naive guard failing exactly on that undo.

**The cascade's cleanup.** It runs after the guard and only detaches. Detaching is never refused: the `now == null` check skips it (MP4, and CS6, CS8 and G9 under M-Q3c).

**Loading a file with misplaced components and editing near them.** MP6 uses a real save and reload, so the loaded instance is not `identical` to the original. With misplaced components present it runs an unrelated move, a move of the holder line, an `==` rewrite and a removal of the nested group, and none is refused. N11 now adds a holder edit.

**The one reachable app refusal is (e):** see I-1.

## 3. Cost

- **Survey.** `_survey` is not on the frame path: its callers are `_run` (before and after), `drift()` and `diagnostics()`.
  - In the no-stray case, each object costs one extra `found[h]` lookup with a null pattern, and nothing is allocated per object.
  - Each survey allocates one empty `stray` map (two per edit).
  - A record and a map insertion are paid only per stray or shadowed component.
- **`_written`.** Per edit it allocates one `touched.toList()` and sorts it, O(k log k), then does O(k·types) typed-store lookups. `_heldBefore` builds a record key only when a non-null component sits on a non-object handle.
- **Allocation invariants.** `query_allocation_test` ran in the engine gate and `paint_allocation_test` in the render gate. Neither failed.

## 4. Tests

**MP1–MP9 are not degenerate.**
- They write `Hinge`, the 4th registration in `testCatalog()`. My M-R2 (check only `types.take(1)`) goes red on MP1, MP3, MP6 and MP8.
- The groups are rotated and off the origin.
- The handles cover a group that was live and then deleted, a handle never allocated (above the seed), a nested group, and a live root-level group as the control.
- MP1 checks bytes (`enc`), undo depth, the store and empty `diagnostics()`.
- MP6's re-write of an `==` value uses a loaded instance, and asserts it is not `identical`, so M-Q3i is killed.
- MP8 (a ClipRect object gets a new Hinge and is deleted in the same compound) kills both of my seam mutants:
  - M-R1b, which skips handles that were objects before;
  - M-R7, which stops at the first unchanged registration instead of checking the rest.

**The seven converted fixtures** (N11, DG2, OB1, EP6, HF9, OT1, RI1). I read each diff:
- **Nothing weakened.** Every assertion is unchanged. The only changes are that the stray is attached straight into the store and a node add is split out. N11 gains a holder edit plus an `==` check.
- **Direct attaches skip `invalidateDerived()` and emit no change event.** That could hide a stray from a derived cache. So I re-fired each fixture's original liveness mutant against the converted fixture, and all went red on the strays:

| Mutant | Change | Red |
|---|---|---|
| A1 = fr-X7 | `opening_geometry.dart` l.726, `wallsInDocument` without `_isLiveGroup` | HF9 |
| A2 | `room_inputs.dart` `liveObjectsOf` without the root-level filter | RI1 at l.211, "Actual: [18, 22, 26, 30, 34, 5100, 5200]" |
| A3 = rv8-noLive | `wall_grips._keptPut` without the liveness `continue` | EP6 at l.551 |
| A4 | `wall_bands.dart` l.130 `hostAt` liveness filter defeated | OT1 (liveness) |
| M-R8 | `diagnostics()` never emits `parametric.misplaced` | DG2, N11, MP4 |
| M-R9 | `_isObject` treats a nested group as an object | OB1 at l.110, plus CS7, LV2, MP1, MP3, MP4, MP6 |

So they still test what they tested: a file-style stray in the store.

**Spec 06's amendment (D5 pointer, D6 paragraph).** It is true for every edit the expander wraps. It overclaims slightly for the D2 fast path (m1), and it names mutants "M-Q3a–M-Q3l" although there is no M-Q3k and M-Q3f is equivalent (m2).

## 5. Mutants fired

All ran with `CI=true dart test test/parametric` (118 tests) unless noted. Every restore `diff` exited 0.

| Mutant | Change | Result |
|---|---|---|
| M-Q3a | `_written` returns null (the guard is gone) | red, `+114 -4`: MP1, MP3, MP6, MP8. Matches the report. |
| M-Q3e | Guard moved into `SetComponentCommand.apply`: non-null value, handle not a root-level group, Note/PageComponent exempt. `_written` disabled. Two files, both restored, diff 0. | red, `+98 -20`. MP5 fails on the **undo**: "Bad state: 7D9 is not a live root-level group" at `SetComponentCommand.apply` ← `CompoundCommand.apply` ×2 ← `ParametricReplay.apply` ← `CommandDispatcher.undo` ← `misplaced_test.dart 212`. Also G3, CS1–3, CS6, CS7, CS10–12, DV1, OB1, PG1, RG6, SV3 and MP1/3/4/6/8/9. My variant exempts non-parametric types, so it shows 20 red where the report shows 25. |
| M-Q3h | Value comparison dropped | red, `+90 -28`: MP5, MP6, MP8, MP9, N11, G3, G6, CS1–5, CS7, CS9–12, DR1, LV1, LV2, DV1, OB1, PG1, SD6, SD10, RF6, RG6, SV3. Matches the report. |
| M-Q3i | `identical` instead of `==` | red, `+117 -1`: MP6. Matches the report. |
| M-R1b (own) | Also skip handles that were objects **before** (`\|\| before.objects.containsKey(h)`) | red, `+117 -1`: MP8 at l.284 |
| M-R2 (own) | Only the first registration checked | red, `+114 -4`: MP1 at l.120, MP3, MP6, MP8 |
| M-R3 (own) | `_heldBefore` ignores the object snapshot (`stray` only) | red, `+92 -26`: MP5, MP8, MP9, G3, CS…, … |
| M-R7 (own) | `break` instead of `continue` on an unchanged registration | red, `+117 -1`: MP8 at l.284 |
| A1–A4, M-R8, M-R9 (own) | Fixture-conversion checks | red; see section 4. The app mutants ran with `CI=true flutter test test/<file>`. |

## 6. Gates (`export PATH=/root/flutter/bin:$PATH`, review worktree at 47a7fcb)

**Engine** (`packages/jet_cad_2d`): matches the branch point: 1,078 + 9 = 1,087, with the 2 standing failures.

| Command | Exit | Result |
|---|---|---|
| `CI=true dart test` | 1 | `+1087 -2`. The two failures are the standing `test/testing/generate_document_test.dart` pair ("both text fractions…", "the default document…"). |
| `dart analyze` | 0 | "No issues found!" |
| `dart format --set-exit-if-changed` | 0 | "0 changed" |

**Render** (`packages/jet_cad_2d_flutter`):

| Command | Exit | Result |
|---|---|---|
| `CI=true flutter test` | 1 | `+940 ~1 -7`. The seven failures are exactly `text ladder` rungs 1–5 and `text lod ladder` rungs 1–2. |
| `flutter analyze` | 0 | |
| `format` | 0 | "0 changed" |

**App** (`apps/floor_planner`):

| Command | Exit | Result |
|---|---|---|
| `CI=true flutter test` | 0 | `+491: All tests passed!` |
| `flutter analyze` | 0 | |
| `format` | 0 | "0 changed" |
| `flutter build web --release` | 0 | "✓ Built build/web" |

## Important

**I-1. The guard makes (e) user-visible. This is a merge-order condition, already ruled; it is not a defect of this commit.**
- **Reproduction.** A scratch app probe, run and then deleted: a wall `hA` from `plan(-2500,0)` to `plan(2500,0)`, and a file-style orphan `WallParams` on a node-less `Handle(5200)` whose start is `hA`'s world start. `WallGrips().drag(doc, hA, grip 0, plan(-2000,0))`, then `execute`.
- **Result:** `Bad state: "Move wall ends": floor_planner.wall written on 1450, which is not a live root-level group after the edit, would never be regenerated (spec 06 D5); the edit is refused`, and the undo depth is unchanged.
- **Where it surfaces.** `select_tool.dart` l.423–428 catches the throw only to drop the carry, then rethrows it, so a wall-end drag at such a joint throws out of pointer-up.
- **Action.** The ledger's ruling stands: Q2's `_endsAt` liveness filter, with a select-tool test using a file's orphan, must land before merge.

## Minor

**m1. The amendment's "An edit that writes one is refused" holds only for edits the expander wraps.** Two pre-existing gaps let a write through (probes PR2, PR3, PR4b):
- **06 D2's fast path.** It returns the command unwrapped when the document holds no parametric component and no `SetComponentCommand<T>` for a registered `T` is found (recursing into compounds). A client command that writes through some other class (PR2), or a directly executed public `ParametricReplay` (PR3), therefore lands a misplaced component on such a document. It equally skips generation for a live-group attach, so this is D2's own limit.
- **The `touched` contract.** A command that under-reports `touched` (PR4b) escapes the narrow guard. The wide form (M-Q3f) would catch it at O(components) per edit; the narrow form was a deliberate choice.
- **Suggestion (no code change):** one clause in the D6 amendment, e.g. "(an edit the expander wraps; D2's fast path and a command that under-reports `touched` are not covered)".

**m2. Mutant naming in the spec.** The spec says "mutants M-Q3a–M-Q3l", but there is no M-Q3k and M-Q3f survives as equivalent. List them explicitly, or say "M-Q3a–j, l (f equivalent)".

**m3. A stale comment, like the one fixed in `opening_end_drag_test`.** `apps/floor_planner/lib/parametric/wall_bands.dart` l.126–128 reads "a handle with no node, which no tool or file path makes". A file can make one. Q2 touches the app comments and can fix it.

**m4. Informational: write-then-delete is refused.** An edit that writes a new value on a live object and deletes it in the same compound is refused (PR9). That is consistent with "wrote" and harmless, since no app path does it. The docs' "a delete is never refused" is accurate only for a delete that writes nothing, which is how `_written`'s doc already phrases it.

**Out of scope (informational).** `DraftDocumentCodec.decode` loads components without raising the handle seed; only nodes, entities and tables raise it. So a hand-made file can carry a component on a handle above the seed (MP1's "never-allocated" case), and a later allocation can adopt it. The guard neither causes nor needs to close this.
