# The root's transform is pinned to the identity

**Branch:** `fix/root-transform-identity`, cut from `main` at `c09b747`.
**Source:** row 1 of the
[grips and transform spec review](2026-09-23-grips-and-transform-spec-review-r1.md)
and that spec's Open questions.

## The inconsistency

The document root is a `GroupNode` and so carries a `transform`. Two readings
of it existed:

- **Ignored.** The canvas, the spatial index (`pickInto`/`snapInto` descend
  from `Transform2.identity()`; `container_index.dart` walks the same way) and
  the reference walk (`reference_walk.dart`) start from the identity and never
  read the root's transform.
- **Applied.** `OutlineCache` and `TileCache` place root-level groups and
  instances through `DocumentTree.accumulatedTransform`, which includes it.

Nothing wrote the root's transform, so the two readings agreed only because it
was the identity.

## The rule

**World is root space: the root's transform is the identity.** It is enforced
at the only two places a node transform can be written:

- `TransformNodeCommand` throws `StateError` on the root handle, after the
  missing-node check and before any write, so the dispatcher pushes no history.
- `validate()` reports a root whose transform is not a bit-exact identity as
  `ValidationCodes.rootTransformNotIdentity` (`tree.root_transform_not_identity`),
  the only way in being a file. Exact, not under `Tolerance`: it compares a
  stored value.

Making every walk apply the root's transform was rejected: it widens the index,
the canvas and the oracle for a transform nothing needs.

The one existing test that transformed the root,
`draft_document_test.dart`'s `runtime permissions forbid geometry but allow
transform`, tests permissions, not the root. It now moves a child group and
asserts the move landed, which it did not assert before.

## Mutants

Fired against the final tests; each source restored and `cmp`-checked after.

| id | mutation | killed by |
|---|---|---|
| M-R1 | the root refusal removed | `commands_test`: `Expected: throws <Instance of 'StateError'>` |
| M-R2 | the `validate` check removed | `validate_test`, the `[1, 0, 0, 1, 240, 190]` row |
| M-R3 | identity decided by `equals(identity, Tolerance.standard)` | `validate_test`, only the `[1, 0, 0, 1, 0, 1e-12]` row |
| M-R4 | only the translation checked (`e != 0 \|\| f != 0`) | `validate_test`, only the `[0, 1, -1, 0, 0, 0]` row |
| M-R5 | the refusal moved after `replaceNode` | `commands_test`: the root's `isIdentity` read `false` |

5 fired, 5 killed.

## Gate lines, `CI=true`

- `packages/jet_cad_2d`: **865** pass (862 + 3 new); analyze and format exit 0.
- `packages/jet_cad_2d_flutter`: **797 pass, 1 skip**, and the five standing
  `text_ladder_golden_test.dart` failures (rungs 1–5, canvas) and nothing
  else; analyze and format exit 0.
- `apps/dev_harness_2d`: **82**; analyze and format exit 0.
- `apps/floor_planner`: **21**; analyze and format exit 0.

`git status --short` showed no `analysis_options.yaml`. The app builds were not
run: nothing under `apps/` or the render layer changed.
