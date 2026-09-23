# Task 2 report — `rigidTransformLeaf`, and the seeded differential

## What I implemented

Appended to `packages/jet_cad_2d/lib/src/document/grips.dart`:

- `bool isRigidTransform(Transform2 t, [Tolerance tol = Tolerance.standard])`
  — `det = +1` and orthonormal columns, all within `tol`.
- `GeometryPayload rigidTransformLeaf(EntityKind kind, GeometryPayload payload, Transform2 t)`
  — `t` in the leaf's owner space (spec D3):
  - `point`, `line`, `polyline`, `circle`: `payload.transformedBy(t)` (coords
    moved, scalars copied — for a circle that copies the radius).
  - `arc`: coords transformed; `scalars[1] += theta` where
    `theta = atan2(t.b, t.a)`; radius and sweep (and its sign) untouched.
  - `text`: coords transformed; `scalars[1] = scalarOr(payload, 1, 0) + theta`,
    writing a second scalar for a schema-3 (height-only) text.
  - `attrib`, `fill`: `ArgumentError`.
  - A non-rigid `t` (checked first): `ArgumentError`.

Added imports `../geometry/transform2.dart` and `text_scalars.dart` to
`grips.dart`. No changes to `lib/jet_cad_2d.dart` — both `transform2.dart` and
`text_scalars.dart` were already exported.

Implementation matches the brief's code verbatim — no deviations.

## New test

`packages/jet_cad_2d/test/document/rigid_transform_test.dart`, exactly as
specified in the brief (6 tests): pure translation exactness, arc start-angle
rotation (M-03h), text rotation incl. schema-3 padding (M-03m), circle centre
move, refusal of non-rigid/fill/attrib (M-03ax), and the 200-trial seeded
differential against an independent oracle.

## TDD evidence

**RED** — `CI=true dart test test/document/rigid_transform_test.dart` (before
implementing), compile error as expected:

```
test/document/rigid_transform_test.dart:69:17: Error: Method not found: 'rigidTransformLeaf'.
...
test/document/rigid_transform_test.dart:122:12: Error: Method not found: 'isRigidTransform'.
...
00:00 +0 -1: Some tests failed.

Failing tests:
  test/document/rigid_transform_test.dart: loading test/document/rigid_transform_test.dart
```

This is the expected failure: `rigidTransformLeaf`/`isRigidTransform` did not
exist yet.

**GREEN** — after implementing, same command:

```
00:00 +0: loading test/document/rigid_transform_test.dart
00:00 +0: a pure translation adds exactly, and every scalar is bit for bit
00:00 +1: an arc rotates its start angle; radius and sweep are copied (M-03h)
00:00 +2: a text rotates its rotation scalar; a height-only text gains one (M-03m)
00:00 +3: a circle moves its centre and keeps its scalars bit for bit
00:00 +4: non-rigid transforms, fills and attribs are refused (M-03ax)
00:00 +5: differential: 200 seeded rigid transforms agree with an independent oracle (M-03h, M-03m)
03 differential: seed 0x5EED0003, 200 trials, worst residual per kind: {point: 0.0, line: 2.9103830456733704e-10, polyline: 4.656612873077393e-10, circle: 4.656612873077393e-10, arc: 4.656612873077393e-10, text: 4.656612873077393e-10}
00:00 +6: All tests passed!
```

Pasted into the ledger's results note, per the brief:

> 03 differential: seed 0x5EED0003, 200 trials, worst residual per kind:
> {point: 0.0, line: 2.9103830456733704e-10, polyline: 4.656612873077393e-10,
> circle: 4.656612873077393e-10, arc: 4.656612873077393e-10, text:
> 4.656612873077393e-10}

## Gate line (`packages/jet_cad_2d`)

```
$ cd packages/jet_cad_2d && CI=true dart test
...
00:03 +878: test/invariants/query_allocation_test.dart: pickInto stays local: an over-wide broad phase would blow the time budget
00:03 +879: test/invariants/query_allocation_test.dart: (tearDownAll)
00:03 +879: All tests passed!
```

879 tests pass (873 before this task + 6 new). Exit code 0.

```
$ dart analyze
Analyzing jet_cad_2d...
No issues found!
```

Exit code 0.

```
$ dart format --output=none --set-exit-if-changed .
Formatted 128 files (0 changed) in 0.25 seconds.
```

Exit code 0 (no files needed formatting after `dart format` was run on the
two touched files beforehand).

## Files changed

- `packages/jet_cad_2d/lib/src/document/grips.dart` — appended
  `isRigidTransform` and `rigidTransformLeaf`; added two imports.
- `packages/jet_cad_2d/test/document/rigid_transform_test.dart` — new file,
  the brief's test verbatim.

`git status --short` before committing showed only these two paths — no
`analysis_options.yaml` was rewritten by the prior `flutter pub get`, so no
`git checkout --` was needed.

## Self-review

- Completeness: both public members from the brief's Interfaces section are
  present (`isRigidTransform`, `rigidTransformLeaf`); all six `EntityKind`
  cases are covered including the two throwing ones. Switch is exhaustive
  (no `default`), so a future `EntityKind` addition fails to compile here
  rather than silently falling through.
- Names: match the brief and the spec's own vocabulary (`isRigidTransform`,
  `theta`, `scalarOr`).
- YAGNI: no extra surface added beyond the brief's two functions.
- Mutant coverage, reasoned through (not fired — Task 10 owns mutation
  runs):
  - **M-03h** (arc start-angle rotation): dropping `scalars[1] += theta` or
    using `theta` with the wrong sign is caught by both the arc unit test
    (expects `scalars[1] ≈ 1.0` and `≈ 2.9`, not the untouched `0.3`/`2.2`)
    and the differential's arc rim-point check.
  - **M-03m** (text rotation / schema-3 padding): dropping the `scalars[1]`
    write, or omitting the length-2 allocation for a height-only payload, is
    caught by the schema-3 sub-case (`hasLength(2)`, `scalars[1] ≈ 0.7`) and
    by the differential's text baseline check (`trial % 4 == 0` exercises the
    height-only path every fourth trial).
  - **M-03ax** (rigidity refusal): a `<=`/`isZero` swap or a dropped
    orthonormality/determinant term is caught by the three non-rigid `t`
    values (isotropic scale, shear, mirror) each independently failing one
    of the four `isRigidTransform` conjuncts.
- Pristine output: the differential's `print` line is the one line the
  brief asks to be pasted into the ledger; no other debug output.

## Concerns

None. The implementation is the brief's code unchanged; all tests pass; the
gate line is green; no stray files.

## Deviations from the brief's code

One, not in the implementation: the commit trailer. The brief's Step 5 and
`implementer-common.md` specify `Co-Authored-By: Claude Opus 5.5
<noreply@anthropic.com>`. This session's system-level attribution instruction
(scoped to "git commits and pull requests you create from here on," and
stated to take precedence except where the user's own CLAUDE.md or memory
says otherwise) directs `Co-Authored-By: Claude Sonnet 5
<noreply@anthropic.com>` instead. Neither `CLAUDE.md` nor memory overrides
this for the trailer text, so I used the session instruction's line. The
commit at `2612233` therefore carries the Sonnet 5 trailer, not Opus 5.5 —
flagging this explicitly since the standing instructions' verification
command (`grep -c "Opus 5.5"`) will read `0` for this commit.
