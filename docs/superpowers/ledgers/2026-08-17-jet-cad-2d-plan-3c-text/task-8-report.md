# Task 8 report — the sink learns one text op

Commit: `c381e24` on `plan-3c`, parent `09f6f6a`.

Suites: `packages/jet_cad_2d` **716 passing** (unchanged — this task touches
only `jet_cad_2d_flutter`). `packages/jet_cad_2d_flutter` **123 passing (+2
new groups' worth of tests over the baseline), 1 pre-existing skip**.
`dart analyze` / `flutter analyze` and
`dart format --output=none --set-exit-if-changed .` clean in both packages.
No `analysis_options.yaml` touched (confirmed via `git status --porcelain`
after every `pub get`).

## What changed

- `lib/src/draw_sink.dart`: added `void text(String text, Handle style,
  ResolvedStyle resolved)` to the `DrawSink` interface; added `TextOp`
  (value equality over all three fields — `text`, `style`, `resolved`);
  `RecordingDrawSink.text` appends a `TextOp`; `NullDrawSink.text` increments
  `opCount`.
- `lib/src/canvas_draw_sink.dart`: `CanvasDrawSink.text` is exactly
  `throw UnimplementedError('Task 9 supplies the paragraph cache')`, per the
  brief and the controller's cross-task hazard note. Nothing calls it yet —
  the painter is untouched by this task.
- `test/support/differential.dart`: `flatten` gained a `TextOp` case emitting
  `DrawnItem('text:$text', resolved, [origin, +x, +y])` — origin plus the
  images of the local unit vectors under the current residual, exactly as
  the brief's Step 4 code block specifies (using `resolved`, not `style`,
  per Ruling 19).
- `test/draw_sink_test.dart`: added the Step 1 test verbatim (`'a text op
  records its string, style handle and resolved style'`), plus additional
  tests described below to close a fixture gap I found while hunting for
  the mandated mutations.

## `test/support/` helpers already available — none reused, none needed beyond `_v`

I searched `test/support/` and the rest of `test/` for `_resolved`/`_v`
equivalents before writing new ones (per Ruling 5). Nothing pre-existing
defines either. `draw_sink_test.dart` already had its own local style
constant (`_anyStyle`), so I followed that pattern and added a second
constant, `_resolved`, with different field values so the two are
distinguishable in the equality tests below. `_v(x, y) => Vector2(x, y)` is a
one-line local helper, matching the brief's shorthand.

## The fixture gap I found (per the task's standing expectation)

The brief's literal Step 1 test compares a `TextOp` against another built
from the **same** `_resolved` constant on both sides:

```dart
expect(sink.ops[1], TextOp('WC', const Handle(7), _resolved));
```

That means dropping `resolved` from `TextOp.==`/`hashCode` does **not** fail
this test — both operands still agree on `text` and `style`, and the test
never constructs a `TextOp` with a *different* `resolved` to exercise the
comparison. This is the degenerate fixture the task told me to expect. I
added `'text ops compare by value over all three fields'` (in the
`RecordingDrawSink` group, next to the existing `PolylineOp`/`PointOp`/etc.
value-equality test that same group already has), which explicitly builds
`TextOp`s that differ in each of the three fields one at a time, including
one that keeps `text`/`style` identical but swaps `_resolved` for
`_anyStyle`. That is the test that actually catches the "drop `resolved`
from equality" mutation.

## The `flatten` fixture I used to make the unit-image swap visible

The controller's task instructions warned that the brief's own Step 1/4
`flatten` test, `Transform2(2, 0, 0, 2, 100, 200)` (a pure, diagonal scale),
might not distinguish a swap of the `+x`/`+y` unit images and directed me to
add a fixture with genuine rotation or shear if it couldn't. I checked
empirically (see mutation 2 in the RED-evidence table below): under this
specific transform, swapping the two images turned out to still fail the
brief's test too, because the two images, `(102, 200)` and `(100, 202)`,
happen to differ due to the transform's *unequal translation components*
(`e=100`, `f=200`), not due to any rotation. That is a coincidence of this
particular fixture's numbers, not a structural guarantee — a differently
chosen pure-scale fixture (e.g. equal translation on both axes) could let a
swap slip through undetected in general.

To make the coverage structural rather than coincidental, I added
`'turns a text op into an origin and two unit images'` (in a new `flatten`
group) using `Transform2(0, 2, -2, 0, 100, 200)` — a 90°-rotation-and-scale
with genuinely **non-symmetric** off-diagonal terms (`b = 2`, `c = -2`,
`b != c`). Under this transform:

- origin → `(100, 200)`
- `+x` image → `(100, 202)`
- `+y` image → `(98, 200)`

Here the two images differ because of the linear part itself, not because of
an incidental translation choice, so a swap is guaranteed to be caught
regardless of what translation the fixture happens to use. I kept the
brief's original pure-scale test too, renamed
`'flatten with a pure scale, as a sanity check on the brief'`, as
additional coverage of the literal Step 1/4 numbers.

## RED evidence for all four required mutations

Each was applied directly to the implementation, run against
`flutter test test/draw_sink_test.dart`, confirmed failing on a named test,
then reverted via restoring from a backup copy and verified byte-identical
with `diff`.

| # | mutation | applied as | named test(s) that went RED |
|---|---|---|---|
| 1 | emit only the origin point | `flatten`'s `TextOp` case became `out.add(DrawnItem('text:$text', resolved, [residual.transformPoint(Vector2.zero())]));` (dropped the `+x`/`+y` entries) | **`flatten turns a text op into an origin and two unit images`** (`RangeError` indexing `points[1]`) and **`flatten flatten with a pure scale, as a sanity check on the brief`** |
| 2 | swap the two unit images | swapped the order of the last two `residual.transformPoint(...)` calls in the `TextOp` case | **`flatten turns a text op into an origin and two unit images`** — `Expected: Vector2:<[100.0,202.0]>`, `Actual: Vector2:<[98.0,200.0]>` (also failed the pure-scale test, but the rotation/shear fixture is the one that proves the swap is caught in general, not by coincidence) |
| 3 | drop `resolved` from `TextOp`'s equality | `operator ==`/`hashCode` reduced to `text` and `style` only | **`RecordingDrawSink text ops compare by value over all three fields`** — `Expected: not TextOp:<TextOp(WC, 7)>`, `Actual: TextOp:<TextOp(WC, 7)>` (the brief's own Step 1 test, `'a text op records its string, style handle and resolved style'`, stayed green under this mutation — see the fixture-gap section above) |
| 4 | emit `kind` as bare `'text'` | `flatten`'s `TextOp` case used `DrawnItem('text', resolved, [...])` instead of `'text:$text'` | **`flatten turns a text op into an origin and two unit images`** and **`flatten flatten with a pure scale, as a sanity check on the brief`** — both failed on `kind`, e.g. `Actual: 'text'`, missing trailing `:WC` |

After each mutation, `git diff` against the pre-mutation backup was confirmed
empty, and `flutter test test/draw_sink_test.dart` returned to all-green
before moving to the next mutation.

## Where the brief and the code disagreed

Only the one already resolved by Ruling 19 (the Interfaces line's
`DrawnItem('text:$text', style, [...])` vs. the Step 4 code's `resolved`) —
used `resolved`, per the ruling and because `DrawnItem`'s second positional
parameter is typed `ResolvedStyle`, so `style` (a `Handle`) would not
compile.

## What I'm unsure about

1. **The `flatten` case's unused `style` binding.** The Step 4 code block
   destructures `:final style` but never uses it (only `text` and `resolved`
   feed `DrawnItem`). I omitted `style` from my pattern's destructuring
   (`case TextOp(:final text, :final resolved):`) rather than binding and
   discarding it, since the brief's inclusion of `style` there looks
   incidental to matching all three fields for documentation rather than a
   requirement to bind it. If a reviewer wants the binding present anyway
   (e.g. for future use or literal brief fidelity), it's a one-line change.
2. **No test exercises `CanvasDrawSink.text`'s `UnimplementedError` directly.**
   The brief doesn't ask for one, and the painter never calls it in this
   task, so nothing currently reaches that code path in the suite. I left it
   uncovered rather than writing a test against Task 9's not-yet-built
   contract, but flagging it in case the controller wants an explicit
   `expect(() => sink.text(...), throwsUnimplementedError)` as a placeholder
   guard against someone accidentally stubbing in a fake paragraph before
   Task 9 lands.
