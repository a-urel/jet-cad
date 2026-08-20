# Task 0 report: text columns on the store and the record

## What I implemented

In `packages/jet_cad_2d/lib/src/store/entity_store.dart`:

- `EntityRecord`: four new final fields (`text`, `tag`, `textStyle`, `textAttrs`) with
  defaults (`''`, `''`, `ReservedHandles.standardTextStyle`, `0`), added to the constructor,
  `copyWith`, `operator ==`, and `hashCode`. `toJson`/`fromJson` were **not** touched — the
  brief and the plan reserve the codec for Task 1, and the "record json emits keys in a
  stable order" test still expects exactly the original ten keys.
- `EntityStore`: four new columns — `List<String> _text`, `List<String> _tag`,
  `Uint32List _textStyle`, `Uint16List _textAttrs` — extended through `_write`, `read`,
  `_ensureCapacity` (matching the file's `..setAll(0, _column)` shape), `purge` (all four
  copied alongside the existing columns), and `clear` (string lists refilled with `''`;
  the two numeric text columns are left alone, same as every other numeric column).
- `remove(int slot)`: clears `_text[slot]` and `_tag[slot]` to `''` before freeing the slot,
  with a comment explaining why strings need this and numbers don't (a stale numeric
  column entry is harmless; a stale string reference keeps the whole document's text alive
  after deletion).
- New accessors: `textAt`, `tagAt`, `textStyleAt`, `textAttrsAt`, plus
  `@visibleForTesting` debug readers `debugRawTextAt`/`debugRawTagAt` that read the column
  without going through `read`'s liveness path, used by the test to assert `remove`
  actually released the string.

## Deviation from the brief (flagged, not silently made)

The brief's Step 1 test snippet constructs the text record with
`owner: ReservedHandles.root`. That identifier does not exist anywhere in this codebase —
`ReservedHandles` (`lib/src/document/style.dart`) only defines `layerZero`,
`byLayerLinetype`, `byBlockLinetype`, `continuousLinetype`, `standardTextStyle`, and
`firstFree`; a document's root node handle is allocated dynamically
(`DraftDocument.empty` calls `seed.next()` for it), not reserved. I substituted
`const Handle(100)` — the same arbitrary owner value `lineRecord`'s default already uses
in this test file — since `EntityStore` unit tests don't validate `owner` against a real
document tree. Everything else in the brief's snippets was used verbatim.

## Tested and results

### RED

Command: `cd packages/jet_cad_2d && dart test test/store/entity_store_test.dart`

Failed at compile time with exactly the expected shape — `EntityRecord` had no `text`
parameter and `EntityStore` had no `textAt`/`tagAt`/`textStyleAt`/`textAttrsAt`/
`debugRawTextAt`/`debugRawTagAt`:

```
test/store/entity_store_test.dart:188:7: Error: No named parameter with the name 'text'.
  lib/src/store/entity_store.dart:53:9: Context: Found this candidate, but the arguments don't match.
test/store/entity_store_test.dart:194:18: Error: The method 'textAt' isn't defined for the type 'EntityStore'.
... (tagAt, textStyleAt, textAttrsAt, EntityRecord.text getter, debugRawTextAt, debugRawTagAt — same shape)
00:00 +0 -1: Some tests failed.
```

This is the right failure: nothing about the implementation ran, the test file simply
didn't compile against the old `EntityRecord`/`EntityStore` surface.

### GREEN

Command: `cd packages/jet_cad_2d && dart test test/store/`
Result: `+34: All tests passed!` (all prior store tests plus the two new ones).

Command: `cd packages/jet_cad_2d && dart test`
Result: `+669: All tests passed!` — full engine suite, confirming the four new fields'
defaults keep every existing record construction (which never names `text`/`tag`/
`textStyle`/`textAttrs`) valid, and nothing downstream broke.

Command: `dart analyze` → `No issues found!`
Command: `dart format --output=none --set-exit-if-changed .` → `Formatted 97 files (0 changed)`

`git status --porcelain` confirmed `analysis_options.yaml` was not touched by any of the
above, so nothing needed a `git checkout --`.

## Files changed

- `packages/jet_cad_2d/lib/src/store/entity_store.dart`
- `packages/jet_cad_2d/test/store/entity_store_test.dart`

Commit: `c3eccba feat(jet_cad_2d): store text content, tag, style and packed attributes`

## Self-review findings

- Confirmed both new tests are load-bearing, not vacuous: the round-trip test fails
  without `_write` setting the four columns and fails without `remove` clearing
  `_text`/`_tag`; the purge test specifically fails if the copy loop omits `_text` (traced
  through: without the copy, `remap[b]`'s slot inherits whatever `remove(a)` already wrote
  there — `''` — rather than `'B'`).
- `purge` deliberately does **not** clear the *source* slot's string after a live-slot
  relocation (`_text[to] = _text[old]` without zeroing `_text[old]`). This mirrors how the
  existing numeric columns behave in the same loop and is safe: when `to != old` for a live
  slot, the string is still reachable through the entity at its new slot, so nothing is kept
  alive that wasn't already alive. The memory-release guarantee is specifically about
  *removed* slots, which `remove()` already clears before `purge` ever runs.
  `EntityFlags`, `kByLayer`, `kLineweightDefault` etc. all pre-existed; no new public API
  beyond what the brief specifies.
- `Object.hash` now takes 15 positional arguments (11 original + 4 new); Dart's
  `Object.hash` supports up to 20, and `dart analyze`/`dart test` both confirm this
  compiles and behaves correctly.
- No accidental edits outside the two intended files (`git status --porcelain` showed only
  those two both before and after commit).
- Did not touch `toJson`/`fromJson`, rendering, geometry, or the codec, per the task's
  explicit boundary.

## Concerns

- The `ReservedHandles.root` substitution above is worth a second pair of eyes from
  whoever owns the Plan 3c brief, in case `root` was meant to be added as a genuine new
  reserved handle in a task I haven't seen yet (Task 1+) rather than being a slip in the
  brief. As implemented, `EntityStore`'s tests don't depend on it either way.
