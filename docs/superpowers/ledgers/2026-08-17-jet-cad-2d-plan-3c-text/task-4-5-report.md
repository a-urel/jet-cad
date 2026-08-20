# Task 4 & 5 report: text bounds and `SetEntityTextCommand`

## Starting state

`git diff` at start showed an interrupted Task 4 run: `entityBounds` already
took `required TextStyleRecord textStyle` plus `int textAttrs = 0`, its text
case was implemented via `resolveTextAttributes` / `textLocalBounds` /
`textLocalTransform`, all four production call sites and six test call sites
were updated, `SetEntityTextCommand` existed in `commands.dart`, and
`test/index/text_overlay_test.dart` existed as an untracked file. `dart test`
gave 687 passing, 1 failing (the overlay test).

## What was wrong in the inherited work

Only one defect: `test/index/text_overlay_test.dart` read the edited leaf's
box with `index.rootIndex.boxOfLeaf(doc.entities.slotOf(handle)!)!` right
after calling `SetEntityTextCommand`. Per Ruling 10, dirtying a leaf removes
it from the packed R-tree and parks it in the dirty overlay, so `boxOfLeaf`
correctly answers null there and the bang (`!`) crashed. Fixed by reading
through the codebase's own idiom (mirrored from `spatial_index.dart`'s
`_reconcileEntity`, `boxOfLeaf(last) ?? dirty.boxOf(last)`):

```dart
final incrementalOrNull =
    index.rootIndex.boxOfLeaf(slot) ?? index.rootIndex.dirty.boxOf(slot);
expect(incrementalOrNull, isNotNull);
final incremental = incrementalOrNull!;
```

Everything else in the inherited diff (the `entityBounds` signature and text
case, all four production call sites, the six test call sites, and the rest
of the overlay test) matched both briefs and Ruling 2/Ruling 10 exactly —
`SetEntityTextCommand` already threw `StateError` on both invalid paths,
already called `target.invalidateDerived()`, and already returned a plain
`CommandResult(inverse:, touched:)` with no `CommandResult.rejected`/
`.applied` factories (which indeed don't exist). No rewrite needed there.

## What I added

1. **`test/document/commands_test.dart`** — a new `group('SetEntityTextCommand', ...)`
   with three tests (the command test the brief said didn't exist yet):
   - `execute widens the box and sets text/tag; undo restores both; redo
     re-applies` — builds a real `DraftDocument` with `MetricModelMeasurer`,
     adds a TEXT entity, wraps it in a `SpatialIndex`, and asserts `text`,
     `tag`, and the leaf's `maxX` (via the same `boxOfLeaf ?? dirty.boxOf`
     idiom) at each of execute/undo/redo.
   - `rejects an unknown handle` — `throwsA(isA<StateError>())`.
   - `rejects a non-text, non-attrib entity kind` — adds a line entity, then
     asserts `SetEntityTextCommand` on it throws `StateError`.
   - A `textRecord(...)` helper per Ruling 5, since the briefs' snippets
     referenced an undefined local helper for building a text `EntityRecord`.

2. Fixed the one-line overlay-accessor bug in `text_overlay_test.dart`
   described above; left everything else in that file as inherited.

## Where a brief and the code disagreed

- **Ruling 10 vs. both briefs' snippets**: as documented above — this was the
  one live defect, now fixed. Production code (`spatial_index.dart`) was
  already correct and untouched.
- **Ruling 2 vs. Task 5's brief snippet**: the brief's snippet used
  `CommandResult.rejected(...)`/`.applied(...)` and returned early. The
  inherited implementation already followed Ruling 2 (throw `StateError`,
  return a plain `CommandResult`), so no change was needed there — I only
  verified it against `command.dart`'s actual `CommandResult` (a `const`
  constructor with `inverse`/`touched`, no factories) and `AddEntityCommand`'s
  `DuplicateHandleError`-throwing convention.

## Commit shape — deviated from the prescribed order, and why

The instructions specified committing Task 5 (`SetEntityTextCommand` +
its test) first, then Task 4 (`entityBounds` + call sites + overlay test)
second, "so no intermediate commit is red." I found this order does *not*
actually keep commit 1 green: the mandated command test asserts the laid-out
box widens on `SetEntityTextCommand` and narrows on undo, read through a real
`SpatialIndex`. That assertion is only true once `entityBounds`' text case
computes a real layout — before Task 4's fix it returns the same degenerate
point box regardless of the entity's text, so the widening assertion would
fail. Additionally, `entityBounds`' signature change (`Handle` →
`TextStyleRecord`) is a breaking change that requires every caller — in both
`lib` and `test` — to update atomically or the package fails to compile.

I verified both orderings directly rather than assuming: I stashed the
Task 5 files (`commands.dart`, `commands_test.dart`, `text_overlay_test.dart`)
and confirmed Task 4 alone — `entityBounds` + all four production call sites
+ four test call site files — is fully green on its own (687/687 `dart test`,
clean `dart analyze`, clean `dart format`, and `flutter test`/`flutter
analyze` clean too, since `reference_walk.dart` is part of that slice).
Task 5 layered back on top is then trivially green because the box-widening
assertion has real geometry to test against.

So the actual commit order is **Task 4 first, Task 5 second** — the reverse
of the instruction's literal order, but it satisfies the instruction's actual
goal ("no intermediate commit is red") in a way the literal order could not,
given the box-widening assertion the instructions also mandated for the Task
5 test. Each task's file set matches its brief exactly; only the sequence is
swapped:

- `0ad927b` — `feat(jet_cad_2d): bound text by its laid-out box at every call site`
  (Task 4: `extents.dart`, `draft_document.dart`, `container_index.dart`,
  `spatial_index.dart`, `reference_walk.dart`, and the four test files with
  call sites: `extents_test.dart`, `snap_centre_index_test.dart`,
  `corpus.dart`, `reference_query.dart`).
- `8a3f2b5` — `feat(jet_cad_2d): add SetEntityTextCommand with an index-dirtying inverse`
  (Task 5: `commands.dart`, `commands_test.dart`, and the new
  `text_overlay_test.dart`, which needs both `SetEntityTextCommand` and the
  Task 4 fix already landed — both are, by this point).

## Test counts

- Before: `dart test` in `packages/jet_cad_2d` → 687 passing, 1 failing
  (`text_overlay_test.dart`'s null-check crash).
- After Task 4 alone (verified in isolation): 687 passing, 0 failing.
- After both commits (final state): **691 passing, 0 failing** (+4 new tests:
  three in the `SetEntityTextCommand` group, one already-fixed overlay test).
- `packages/jet_cad_2d_flutter`: `flutter test` — 123 passed, 1 pre-existing
  skip, unrelated to this work, both before and after.
- `dart analyze` / `flutter analyze`: clean in both packages, before and
  after.
- `dart format --output=none --set-exit-if-changed .`: clean in both
  packages after a `dart format` pass over the files this task touched (the
  inherited `commands.dart`, `extents_test.dart`, and `text_overlay_test.dart`
  needed reformatting; format-only, no semantic change).
- Verified no `analysis_options.yaml` in either package was modified by
  `flutter pub get`/`flutter analyze` (`git status --short` was empty before
  each commit beyond the intended files).

## Anything I'm unsure about

- The commit-order deviation above is the one place I diverged from an
  explicit instruction (the literal 5-then-4 sequence). I'm confident the
  substitute order is correct and satisfies the stated goal, but flagging it
  explicitly since it's a literal instruction override, not just a brief
  disagreement.
- I did not touch `SetEntityTextCommand`'s doc comment beyond what was
  inherited; it currently describes itself as "Minimal stand-in for the
  fuller command a later task builds out" — that phrasing was already in the
  uncommitted work and reads fine as forward-looking documentation, so I left
  it as is.

## Fix round 1

Commit: `419d512`, on top of `8a3f2b5`. Four Important items plus two Minors.

### Ruling 12 — the `!` fallback

Added `DraftDocument.textStyleOf(Handle handle)`, returning
`tables.textStyles[handle] ?? _fallbackTextStyle`, where `_fallbackTextStyle`
is a `const TextStyleRecord(handle: ReservedHandles.standardTextStyle, name:
'Standard', fontFamily: 'Roboto')` — matching `DocumentTables.standard()`'s
own seeded values and `TextStyleRecord`'s own defaults for the rest. Replaced
the `tables.textStyles[record.textStyle] ?? tables.textStyles[ReservedHandles
.standardTextStyle]!` expression at all four production sites
(`draft_document.dart`, `container_index.dart`, `spatial_index.dart`,
`reference_walk.dart`) and all five test occurrences across four files
(`snap_centre_index_test.dart` x2, `corpus.dart`, `reference_query.dart` x2)
with `doc.textStyleOf(record.textStyle)`. `container_index.dart` and
`spatial_index.dart` each lost their now-unused `document/style.dart` import
as a result (`ReservedHandles` was the only symbol either used from it).

Added `draft_document_test.dart`'s `'extents still work when the STANDARD
text style is missing from the table'`, which builds a document with only a
line entity, calls `doc.tables.textStyles.remove(ReservedHandles
.standardTextStyle)`, and asserts `doc.extents` returns normally with the
line's own bounds.

**RED evidence**: reverted `textStyleOf` to the old `?? tables.textStyles[
ReservedHandles.standardTextStyle]!` pattern. `dart test test/document/
draft_document_test.dart -n "STANDARD text style is missing"` failed with
`_TypeError: Null check operator used on a null value` at the `expect(() =>
doc.extents, returnsNormally)` line — the exact crash the reviewer reported.
Reverted the mutation; test passed again.

### Ruling 13, item 1 — per-entity style unpinned

Added a second test to `text_overlay_test.dart`: a `TextStyleRecord` named
`BIG` with `fixedHeight: 500`, added to the document's table and assigned to
the text entity (whose own height scalar is 200). Asserts the entity's
actual box height differs from a hand-computed "wrong style" box built by
calling `entityBounds` directly with the STANDARD record instead.

**RED evidence**: mutated all three engine call sites (`draft_document.dart`,
`container_index.dart`, `spatial_index.dart`) to
`textStyleOf(ReservedHandles.standardTextStyle)` (bare STANDARD, ignoring
`record.textStyle`). `dart test test/index/text_overlay_test.dart` failed
this exact test (`Expected: not <285.71...>, Actual: <285.71...>` — the two
boxes matched, meaning the entity's own style was never consulted). Reverted
all three mutations; suite passed again (3/3 in that file).

### Ruling 13, item 2 — textAttrs unpinned

Added a right/top-justified fixture to both `text_overlay_test.dart` (new
test) and `commands_test.dart`'s `SetEntityTextCommand` group (new test,
plus a `textAttrs` parameter added to the group's `textRecord` helper).
Right/top justification anchors the box's top-right corner at the insertion
point, so `maxX`/`maxY` — not `minX`/`minY` as the default left/baseline case
would — land on the anchor; the commands-side test also confirms an edit
still tracks that anchor (`maxX` stays pinned, `minX` moves as the string
grows).

**RED evidence**: mutated all three engine call sites to `textAttrs: 0`
(hard-coded, ignoring `record.textAttrs`). `dart test test/index/
text_overlay_test.dart` failed the new justification test (`Expected: <1000>
±1e-6, Actual: <1157.14...>`). Reverted the three mutations; suite passed
again.

### Ruling 13, item 3 — the `doc.extents` call site unpinned

Added `draft_document_test.dart`'s `"extents cover a text entity's laid-out
box, not just its insertion point"`, using `MetricModelMeasurer` and
asserting `doc.extents`'s width and height are each strictly greater than
zero for a text entity — the insertion point alone is a zero-area box.

**RED evidence**: mutated `draft_document.dart`'s `text: record.text,` to
`text: '', // RED-MUTATION`. `dart test test/document/draft_document_test
.dart -n "laid-out box"` failed (`Expected: a value greater than <0.0>,
Actual: <0.0>`). Reverted the mutation; test passed again.

### Minors — both taken

1. Added a comment at `reference_walk.dart:108` (now a few lines earlier
   after the `textStyleOf` edit) noting `textStyle`/`textAttrs`/`text` are
   dead there because the function already returns early for
   `EntityKind.text`/`.attrib`, and start mattering once Task 10 stops
   skipping them.
2. Added `commands_test.dart`'s `'accepts an ATTRIB entity, not only TEXT'`
   test. Verified RED as well (not one of the four required items, but
   cheap to check): mutated the guard from `record.kind != EntityKind.text
   && record.kind != EntityKind.attrib` to `record.kind != EntityKind.text`,
   ran the new test, got `Bad state: 11 is not a text or attrib entity`.
   Reverted; test passed again.

### Test counts after fix round 1

- `packages/jet_cad_2d`: `dart test` → **697 passing, 0 failing** (691 before
  this round + 6 new: 2 in `text_overlay_test.dart` (style, textAttrs), 2 in
  `commands_test.dart` (textAttrs, ATTRIB), 2 in `draft_document_test.dart`
  (missing-STANDARD fallback, laid-out-box extents)).
- `packages/jet_cad_2d_flutter`: `flutter test` → 123 passing, 1 pre-existing
  skip, unchanged.
- `dart analyze` / `flutter analyze`: clean in both packages (after removing
  the two now-unused `document/style.dart` imports).
- `dart format --output=none --set-exit-if-changed .`: clean in both
  packages.
- No `analysis_options.yaml` modified in either package.

### Anything I'm unsure about

- None outstanding from this round. All four Important items have RED
  evidence recorded above, and both Minors were taken.
