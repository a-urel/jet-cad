# Task 7 report — the corpus grows two text sources

Commit: `2f18a02` on `plan-3c`, parent `3515a72`.

Suites: `packages/jet_cad_2d` **715 passing** (710 at `3515a72`; +5 new tests
in `generate_document_test.dart`). `packages/jet_cad_2d_flutter` **123
passing, 1 skip** (unchanged). `dart analyze` and
`dart format --output=none --set-exit-if-changed .` clean in both packages.
No `analysis_options.yaml` touched.

## What changed and why

`generate_document.dart` gains two off-by-default parameters,
`labelFraction` and `attributedInstanceFraction`, both drawing from `extra`
(`math.Random(0x5EEDED)`) — the same second stream every existing extension
already shares.

### `labelFraction` — repeating room labels, out of the root budget

`_kLabelVocabulary` is the 20-word list from the brief, copied verbatim and
in order. When `labelFraction > 0`:

- `labelCount = min(rootEntityCount, round(rootEntityCount * labelFraction))`.
- The pre-existing plain floor texts (`_addFloorText`, always `text: ''`)
  are **replaced entirely**, not supplemented: `textCount` becomes `0`
  whenever `labelFraction > 0`, and `remaining` (the line/polyline/circle/arc
  budget) is computed against `rootEntityCount - textCount - labelCount`
  instead of the old `rootEntityCount - textCount`. At `labelFraction == 0`
  this reduces to exactly the original formula.
- `_addLabelText` draws the floor position from the **primary** stream
  (`random`, matching every other floor entity) and the vocabulary word from
  `extra` via `extra.nextInt(_kLabelVocabulary.length)`.

**Why replace rather than add:** the brief's own test collects
`doc.entities.textAt(slot)` across *every* `EntityKind.text` entity into one
`Set<String>` and asserts its size is `<= 20`. The pre-existing
`_addFloorText` entities carry `text: ''` (they predate Task 7 and are out of
this task's scope to change independently — touching their content would
also perturb the pinned default fingerprint). If labels were additive on top
of those, the set would contain `''` plus up to 20 vocabulary words — 21
distinct values, failing the literal test as given. Replacing the blank
floor-text allocation with the label allocation when `labelFraction > 0`
is the only shape that keeps the uniqueness bound honest, and it also reads
as the more natural interpretation of "labels ... out of the root budget."
This is the one place the brief and the code disagreed; documented in the
code as well as here.

### `attributedInstanceFraction` — additive, instance-local ATTRIBs

Uses the same "due" accumulator pattern as `mirroredFraction`/
`nonUniformFraction` (a quota, not a coin flip — the existing comment in the
instances loop already explains why: a coin flip is a property of the seed,
not of the requested fraction). For `instanceCount: 100`,
`attributedInstanceFraction: 0.5`, the accumulator fires on every other
iteration, landing exactly 50 — matching the brief's exact (not
approximate) expectation.

Each chosen instance gets one `EntityKind.attrib` leaf via
`_addInstanceAttribute`, owned by the just-created `InstanceNode`'s handle
(captured in a local, `instanceHandle`, since the loop previously called
`doc.handleSeed.next()` inline). Local coordinates are drawn from `extra`
(`±100` on x, `±50` on y — symbol scale, matching `_addSymbolEntity`'s own
`±500`), and the tag value is `'ATTR${ordinal.toString().padLeft(5, '0')}'`
where `ordinal` is the instance loop index `i` — unique per call without
needing a further draw for uniqueness. `container_index.dart:194-208`
transforms every leaf a container owns by that container's composed
transform, so instance-local coordinates here (not world) are what makes
the attribute land at the instance's actual placement rather than being
double-transformed.

### Shared-stream coupling — documented, not just implemented

Added a paragraph to `generateDocument`'s doc comment and to each of the two
new parameters' own doc comments: both draw from `extra`, there is one such
stream, turning one on shifts every draw the other would make, so a fixture
names both together or neither. The test file's new section carries a
matching comment. No test in this task names both fractions on the same
document.

## Guaranteeing zero draws from `extra` while a fraction is off

- `labelCount` is computed as `labelFraction > 0 ? ... : 0`; the label loop
  is `for (var i = 0; i < labelCount; i++)`, so at `labelCount == 0` the body
  — the only place `_addLabelText` calls `extra` — never executes.
- `attributedDue` starts at `0.0` and only accumulates
  `attributedInstanceFraction`; at `0` it never reaches `1.0`, so the
  `if (attributedDue >= 1.0)` guard around `_addInstanceAttribute` (the only
  caller of `extra` for this extension) never fires.
- Both loops/guards are structurally identical in shape to the existing
  `mirroredFraction`/`nonUniformFraction`/`dashedFraction`/`byBlockFraction`
  guards already in the file, which the pre-existing fingerprint test already
  covers for their own defaults.

## RED evidence for all four required mutations

All four were applied to the file, run against a **named** test, observed
failing, then reverted (confirmed via `git diff` showing a clean file
afterward).

| # | mutation | applied as | result |
|---|---|---|---|
| 1 | draw from `extra` even when `labelFraction == 0` | forced the label loop to run at least once regardless of `labelCount` (`for (var i = 0; i < math.max(1, labelCount); i++)`) | `both text fractions default to zero and change nothing` **FAILED**: expected `-4223683079839955300`, got `6274853700285394596` |
| 2 | write attribute coordinates in world space instead of instance-local | `_addInstanceAttribute`'s `x`/`y` became `kDefaultOriginX + extra.nextDouble()*kFloorWidth` / `kOriginY + extra.nextDouble()*kFloorHeight` (world-scale, as DXF would store an already-placed ATTRIB) | `attributedInstanceFraction places attributes in the instance's local space, not world space` **FAILED**: `local.x.abs()` was `4522301.08`, not `<= 100.0` |
| 3 | make labels additive instead of coming out of the root budget | `remaining = rootEntityCount - textCount` (dropped `- labelCount`) | `labelFraction does not change the total leaf count` **FAILED**: expected `2000`, got `2084` |
| 4 | give every chosen instance the same attribute string | `text: 'ATTR'` (dropped the `ordinal` suffix) | `attributedInstanceFraction gives each chosen instance a unique attrib` **FAILED**: expected `50` unique values, got `1` |

### A note on mutation 1's literal form

A truly literal reading of "draw from `extra` even when `labelFraction == 0`"
— a bare `extra.nextDouble();` inserted unconditionally, its result discarded
— does **not** move the fingerprint. I tried this first and confirmed it
empirically: at full defaults, no other consumer of `extra` exists
downstream (every other extension is also off), so nothing ever reads the
state that draw perturbed, and `Random`'s internal state has no effect on
document content unless a *subsequent* read of it is consumed into something
that gets written to the document (a handle, a coordinate, a table entry).
This is a real property of the architecture, not a gap in the test: a
discarded draw is provably invisible. The realistic version of "draws from
`extra` when off" — the one an actual coding mistake would produce — is a
gate that fails to gate, i.e. the loop or branch that *uses* `extra` runs
anyway (mutation 1 as I ultimately applied it, above). That is what the
fingerprint test is actually a defense against, and it does catch it.

## Fingerprint values asserted

Both values are copied unchanged from the currently-committed
`generate_document_test.dart` at `3515a72` / re-baselined in `7f85226`:

- `generateDocument(2000, definitionCount: 20)` → `-4223683079839955300`
- `generateDocument(20000, definitionCount: 20)` → `-1538364231202837705`

Confirmed via `git diff` that the existing "the default document is the one
Plan 2 measured, byte for byte" test was **not** edited — only new tests
were appended — and both fixed points still pass after the full
implementation. The new
"both text fractions default to zero and change nothing" test asserts the
identical two values as an independent, task-7-scoped guard per Ruling 16
(so a reviewer can see the requirement is what actually gates this task,
not just inherited from an earlier one).

## Where the brief and the code disagreed

- **The Step 1 test's placeholder fingerprint** (`<the Task 1 value>`) —
  resolved per the controller's ruling 16: both fractions default to zero
  and change nothing, asserted against the two values already pinned in the
  committed test file (`-4223683079839955300`, `-1538364231202837705`), not
  a new value.
- **Label additivity vs. replacement** — see "What changed and why" above.
  The brief says labels "come out of the root entity budget" but is silent
  on what happens to the pre-existing blank floor texts; I read "out of the
  root budget" as also covering that overlap, since the alternative breaks
  the brief's own uniqueness test.
- **Ruling 12 (`textStyleOf`)** — not applicable here in the end: the
  generator only ever writes `EntityRecord.textStyle` as a handle (which
  defaults correctly to `ReservedHandles.standardTextStyle` via
  `EntityRecord`'s own constructor default) and never resolves a
  `TextStyleRecord`, so there was no call site where `tables.textStyles[...]!`
  could have been written. Noted in case a reviewer expected to see
  `textStyleOf` used somewhere in this file.
- **`MetricModelMeasurer()` losing `const`** — not used in this task; the
  generator and its tests never construct a `TextMeasurer` (they build a
  plain `DraftDocument.empty()`, which defaults to `InsertionPointMeasurer`),
  and the new tests verify stored coordinates/strings directly rather than
  laid-out glyph geometry, so no `TextStyleRecord`/`TextMeasurer` resolution
  was needed anywhere in this task's tests.

## What I'm unsure about

1. **The local-coordinate magnitude (`±100`/`±50`) is my own choice**, not
   specified by the brief. It is symbol-scale (matching `_addSymbolEntity`'s
   own `±500` for genuinely local symbol geometry) and is what the new
   "not world space" test pins against; a reviewer might want a different
   magnitude or a documented rationale beyond "plausible tag offset."
2. **The tag field** (`'REF'`, DXF ATTRIB tag, distinct from the displayed
   `text` value) is a fixed constant across every attribute in a document.
   Nothing in the brief or the existing tests requires it to vary, and no
   test in this task checks it, so it is unverified beyond "present and
   non-empty."
3. **Zeroing `textCount` whenever `labelFraction > 0`, even for a very small
   fraction**, means a document with e.g. `labelFraction: 0.001` has *no*
   blank floor texts at all rather than "mostly blank floor texts, a few
   labels." I judged this the simpler, more predictable contract, but it is
   a discontinuity at `labelFraction == 0` vs. `labelFraction > 0` (rather
   than a smooth interpolation) that a reviewer may want called out
   explicitly or reconsidered.

---

# Fix round 1

Commit: (see final message), parent `2f18a02`. Implementation is unchanged —
the reviewer confirmed it correct and all self-raised concerns resolved in
my favour. This round tightens five test assertions only, per the
reviewer's own six mutations (five survived, one — the root-budget-contract
one, #4 below — already failed against the original `greaterThan(50)`/`84`
combination once tightened for #1, so no separate new test was needed for
it).

Suites: `packages/jet_cad_2d` **716 passing** (715 before this round; +1 new
test, `labelFraction is not capped by the old floor-text ceiling at a larger
corpus`). `packages/jet_cad_2d_flutter` **123 passing, 1 skip** (unchanged).
`dart analyze` and `dart format --output=none --set-exit-if-changed .` clean
in both packages. No `analysis_options.yaml` touched. Only
`test/testing/generate_document_test.dart` changed —
`generate_document.dart` itself is byte-identical to `2f18a02` (`git diff`
against it is empty after every mutation below was reverted).

## The five fixes

1. **`labels.length` tightened from `lessThanOrEqualTo(20)` to `20`**, in
   `labelFraction produces repeating strings out of the root budget`. Also
   tightened `count` from `greaterThan(50)` to the exact `84` in the same
   test (this doubles as the fix for #4 below).
2. **Height assertions added** in both existing per-slot loops:
   `expect(scalars[0], greaterThan(0))` for the text-kind loop in
   `labelFraction produces repeating strings out of the root budget`, and
   for the attrib-kind loop in
   `attributedInstanceFraction gives each chosen instance a unique attrib`.
3. **New test**, `labelFraction is not capped by the old floor-text ceiling
   at a larger corpus`: asserts the exact label count at both `entityCount:
   2000` (`84`) and `entityCount: 20000` (`984`) with the same
   `labelFraction: 0.05`.
4. **`count` tightened from `greaterThan(50)` to `84`** (same edit as #1) —
   this is what catches `rootEntityCount * labelFraction` becoming
   `entityCount * labelFraction` (84 → 100), which the old `greaterThan(50)`
   bound let through.
5. **Tag assertion added**: `expect(doc.entities.tagAt(slot), isNotEmpty)`
   in the same attrib-kind loop as #2.

## RED evidence

Each mutation was applied to `generate_document.dart`, run against the named
test, confirmed failing, then reverted (`git diff` against `2f18a02` empty
afterward).

| # | mutation | applied as | test | result |
|---|---|---|---|---|
| 1 | `_kLabelVocabulary[extra.nextInt(...)]` → `_kLabelVocabulary[0]` | dropped the draw, always index 0 | `labelFraction produces repeating strings out of the root budget` | **FAILED**: expected `20` distinct labels, got `1` |
| 2a | zero the label height | `_addLabelText`'s `scalars: [100.0 + random.nextDouble()*200.0]` → `scalars: [0.0]` | `labelFraction produces repeating strings out of the root budget` | **FAILED**: expected a value `greaterThan(0)`, got `0.0` |
| 2b | zero the attribute height | `_addInstanceAttribute`'s `scalars: [80.0]` → `scalars: [0.0]` | `attributedInstanceFraction gives each chosen instance a unique attrib` | **FAILED**: expected a value `greaterThan(0)`, got `0.0` |
| 3 | reintroduce the old floor-text ceiling | `labelCount`'s `math.min(rootEntityCount, ...)` → `math.min(300, ...)` | `labelFraction is not capped by the old floor-text ceiling at a larger corpus` | **FAILED**: expected `984` (20000 case), got `300` |
| 4 | fraction of `entityCount` instead of the root budget | `(rootEntityCount * labelFraction).round()` → `(entityCount * labelFraction).round()` | `labelFraction produces repeating strings out of the root budget` | **FAILED**: expected `84`, got `100` |
| 5 | drop the ATTRIB tag | `_addInstanceAttribute`'s `tag: 'REF'` → `tag: ''` | `attributedInstanceFraction gives each chosen instance a unique attrib` | **FAILED**: expected non-empty, got `''` |

All five confirmed RED, then reverted; `dart test` returns to 716/716 green
after each revert, and the final state matches this section's diff exactly
(test file only).
