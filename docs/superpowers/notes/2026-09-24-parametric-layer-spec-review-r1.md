# Parametric layer spec: review of revision 1

**Spec:** `docs/superpowers/specs/2026-09-24-parametric-layer-design.md`,
revision 1 (`dd0251e`).

**Reviewers:** two, independent, both read-only against the tree on
2026-09-24.

- **Codex CLI** (`gpt-5.5`): 9 findings.
- **Copilot CLI:** 14 findings.

Every finding was re-checked against the tree before its ruling. Revision 2
applies every ruling. No finding was rejected. Two were accepted with a
narrower fix than the one proposed; each says so.

## Blockers

| # | Source | Finding | Ruling |
|---|---|---|---|
| B1 | Codex 1 | The D2 fast path returns the bare command while the document has no parametric component, so the **first** box's creation is never wrapped and never generates. | **Accepted.** The fast path applies only when the document has no parametric component **and** the command, recursing into compounds, contains no `SetComponentCommand` whose value type is parametric. |
| B2 | Codex 2, Copilot 3 | D4 applies the cleanup, then the plan. On a plan failure it undid only `r`, so a detached component stayed detached. A failing rollback nested in a failing plan was not specified. | **Accepted.** The cleanup detaches and the regeneration are **one** `CompoundCommand`, which rolls itself back. The failure paths: <ul><li>the compound's rollback succeeds: apply `r.inverse`, rethrow;</li><li>the compound throws its own "partially mutated" `StateError`: rethrow it, and do not layer `r.inverse` on top;</li><li>`r.inverse` throws: throw a `StateError` naming both failures, the same escalation `CompoundCommand` uses (`commands.dart:776-788`).</li></ul> |
| B3 | Codex 3, Copilot 9 | Planning called `handleSeed.next()`. The seed never goes backwards, so a failed plan burned handles, and the codec writes the seed. | **Accepted, narrower.** Planning **reserves** handles as `current+1, current+2, …` without advancing the seed. `AddEntityCommand.apply` raises it when a reserved add actually applies. The D6 guard runs before planning, so a refused edit reserves nothing. What is left, and documented: a plan that throws *after* an add applied leaves the seed raised. Every engine `CompoundCommand` rollback does the same today. |
| B4 | Copilot 1 | D9 makes `ParametricEdit.capability` depend on whether `apply` has run: a stateful command, unlike every other command. | **Accepted, narrower.** Moving `capability` onto `CommandResult` would touch every command. Instead `ParametricEdit` is **single-use**: <ul><li>the expander creates one per `execute`;</li><li>the dispatcher reads `capability` once, after `apply`, as it does today (`undo.dart:113-119`);</li><li>history never stores it, only its inverse;</li><li>a second `apply` throws `StateError`.</li></ul> Tested. |

## Important

| # | Source | Finding | Ruling |
|---|---|---|---|
| I1 | Codex 4, Copilot 4 | `PlacementTool.commit` prechecks only `geometry` (`placement_tool.dart:219`). A box needs `structure`, `components` and `geometry`. | **Accepted.** `commit` gains an optional `Set<Capability> needs`, default `{geometry}`, so 05's tools are unchanged. The Box tool passes `{structure, components, geometry}`. The render layer therefore changes by that one parameter. |
| I2 | Codex 5 | Typed components come back only if `registerComponents` runs before `loadJson`. | **Accepted.** `ParametricSystem.registerComponents(ComponentRegistry)` is the function every decode passes. The app has no open path yet, so the round-trip tests decode with it. |
| I3 | Codex 6, Copilot 2 | "Install before `startupPlan`" contradicts "startup plan unchanged": `startupPlan` builds and fills the document itself. | **Accepted, the weaker true guarantee.** The system is installed right after `startupPlan` returns. The sample plan holds no parametric object; the app test asserts that (`diagnostics()` and `drift()` empty, no `BoxParams`). |
| I4 | Codex 7 | M-06f cannot be *killed*: regenerate-on-load is a no-op. | **Accepted.** M-06f is recorded as a **probe**. A new test pins the load decision instead: it saves a file whose geometry is deliberately stale and checks that load keeps it byte for byte, while `drift()` reports the handle. |
| I5 | Codex 8, Copilot 10 | M-06b needs both sorts removed, so nothing proves the planner's own sort. Moving several boxes in one compound was untested. | **Accepted.** New **M-06b′**: remove only the planner's sort. It is killed by moving two boxes in one compound, in both child orders (`[B, A]` and `[A, B]`), with each gaining children. The bytes must be identical. |
| I6 | Copilot 5 | Nothing stops an `execute` from inside a `ParametricEdit.apply`, from a client's `generate` or a test. | **Accepted.** While a `ParametricEdit` is applying, the expander throws `StateError`, and so does any other re-entry. Tested. |
| I7 | Copilot 6 | Translation-only fixtures satisfy "non-identity"; a transposed local transform would survive. | **Accepted.** Relational fixtures must be **rotated**. New **M-06o**: use the forward transform for `toLocal` in place of its inverse. It is killed by the rotated pair. |
| I8 | Copilot 7 | Undo of a delete under runtime was unaddressed. | **Accepted as a clarification.** Delete needs `structure` and `geometry`, which runtime denies, so it is refused at `_require`. The inverse carries the wrapper's own capability set, so a permitted delete's undo needs exactly what the delete needed. D7 now says so. **`ParametricReplay`'s own inverse is a `ParametricReplay` with the same set**, which a redo under runtime needs; M-06i now also covers redo. |
| I9 | Copilot 8 | Raw byte identity depends on regeneration preferring `SetEntityGeometryCommand` over remove-and-add, which keeps slots. | **Accepted.** D11 says it. New **M-06p**: a changed payload becomes remove plus add. It is killed by the "same state plus same edit" byte test, where a child's slot otherwise stays put. |

## Minor

| # | Source | Finding | Ruling |
|---|---|---|---|
| m1 | Codex 9 | The codec path was ambiguous. | **Fixed:** `lib/src/codec/json_codec.dart`. |
| m2 | Copilot 11 | The cleanup (D4 step 4) reads as delete-only. | **Accepted:** it is unconditional; D8 is one case of it. |
| m3 | Copilot 12 | Per-axis AABB `reach` is a placeholder. | **Accepted:** recorded for 07 in Open questions. |
| m4 | Copilot 13 | `Generated` permits `fill`, which `SetEntityGeometryCommand` rejects. | **Accepted:** `Generated` throws `ArgumentError` for `fill`. Regions are out of scope. |
| m5 | Copilot 14 | How callers treat the new `GeneratedGeometryError` was unsaid. | **Accepted:** it propagates like `PermissionDeniedError`. The UI never offers the edit, so nothing catches it. |
