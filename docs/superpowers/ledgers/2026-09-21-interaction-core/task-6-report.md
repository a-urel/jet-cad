# Task 6 report: `SelectTool` — keys and Delete

## What was implemented

`packages/jet_cad_2d_flutter/lib/src/select_tool.dart`:

- `onKey` now handles `KeyDownEvent` only (any other `KeyEvent` subtype —
  `KeyUpEvent`, `KeyRepeatEvent` — returns `ignored` immediately).
  - `LogicalKeyboardKey.escape`: cancels an in-progress band drag (phase
    `dragging`) or clears the selection when idle; either way returns
    `handled`.
  - `LogicalKeyboardKey.delete` / `.backspace`: a no-op (`ignored`) unless
    the tool is idle; otherwise calls `_deleteSelection` and returns
    `handled`.
- `_deleteSelection(ToolContext ctx)`: snapshots `doc.commands.permissions`
  once, sorts the current selection's keys ascending by `target.value`, and
  for each key builds its full command list (leaf entity ->
  `RemoveEntityCommand`; `InstanceNode` -> `RemoveNodeCommand`; `GroupNode`
  -> `_groupCascade`, computing `leavesByOwner()` lazily and only once for
  the whole Delete). A key that resolves to neither an entity nor a tree
  node (already dead) is skipped. The list is checked against
  `permissions.allows(c.capability)` for every command before any of them
  runs; a fully-permitted list is executed in order through `ctx.execute`
  and only then is the key removed from the selection via
  `ctx.selection.remove([key])` (synchronous — it does not wait for the
  document's async `changes` stream to prune the same key on its own). A
  list that fails the permission check is skipped whole: the object stays
  selected and untouched, and the loop moves to the next key.
- `_groupCascade(doc, group, byOwner)`: collects the group's own leaves
  (fills whose boundary is also a leaf of this same group are excluded, so
  `RemoveEntityCommand` on that boundary — which removes a single dependent
  fill in the same command — is never asked to remove the fill a second
  time), recurses into nested `GroupNode` children, appends a
  `RemoveNodeCommand` for each child `InstanceNode`, and finally appends the
  group's own `RemoveNodeCommand` last.

Both new methods and the filled-in `onKey` match the brief's pseudocode
essentially verbatim; imports gained `KeyDownEvent` and `LogicalKeyboardKey`
from `package:flutter/services.dart`. The class doc comment was updated to
drop the "Task 6's; `onKey` is a no-op here" note.

`packages/jet_cad_2d_flutter/test/select_tool_test.dart`: a new
`group('keys and delete')` with the seven tests from the brief (see below),
plus four small top-level helpers (`_deleteDown`/`_deleteUp`/
`_deleteRepeat`/`_escapeDown` building the `KeyDownEvent`/`KeyUpEvent`/
`KeyRepeatEvent` triples, and `_squareLoop()`, copied from
`region_command_test.dart`'s `squareLoop()` rather than imported from that
test file). Added imports: `dart:typed_data`, `KeyRepeatEvent`/`KeyUpEvent`
from `flutter/services.dart`, and `KeyEventResult` from
`flutter/widgets.dart`.

## Departures

- **Read-only and mixed-permission fixtures.** `addEntity`/`addInstance`
  always go through `doc.commands.execute(...)`, which is gated by
  `DraftPermissions` — so a document constructed directly with
  `DraftPermissions.readOnly` (or the geometry-only grant in test 7) cannot
  have its fixture built through the normal helpers without first allowing
  it. `doc.commands.permissions` is a **mutable** field on
  `CommandDispatcher` (not `final`), and `command_test.dart`'s own
  `'undo respects permissions too'` / `'a denied undo does not strand the
  entry...'` tests already establish the idiom of flipping
  `dispatcher.permissions = ...` mid-test. Both new tests do the same: seed
  the fixture under `DraftPermissions.all`, then set the permissions the
  test is actually about immediately before calling `onKey`. This is a
  local, obvious application of an existing pattern already in the test
  suite, not a new technique.
- Nothing else departs from the brief; the `onKey`/`_deleteSelection`/
  `_groupCascade` bodies are the brief's pseudocode unchanged.

## TDD evidence

**RED** — `CI=true flutter test test/select_tool_test.dart` with the seven
new tests added and `onKey` still the old `=> KeyEventResult.ignored;`
one-liner:

```
00:00 +10: keys and delete Escape when idle clears
00:00 +10 -1: keys and delete Escape when idle clears [E]
  Expected: KeyEventResult:<KeyEventResult.handled>
    Actual: KeyEventResult:<KeyEventResult.ignored>
...
00:00 +11 -2: keys and delete Delete removes a leaf and an instance through the log; undo restores geometry, not selection [E]
  Expected: KeyEventResult:<KeyEventResult.handled>
    Actual: KeyEventResult:<KeyEventResult.ignored>
...
00:00 +11 -3: keys and delete Delete cascades a group: leaves, child instance, nested group, then the group [E]
  Expected: KeyEventResult:<KeyEventResult.handled>
    Actual: KeyEventResult:<KeyEventResult.ignored>
...
00:00 +11 -4: keys and delete a region inside a group is deleted once: the boundary's command takes the fill [E]
  Expected: null
    Actual: <0>
...
00:00 +12 -5: keys and delete a refused object stays selected, a permitted one goes [E]
  Expected: KeyEventResult:<KeyEventResult.handled>
    Actual: KeyEventResult:<KeyEventResult.ignored>
...
00:00 +12 -5: Some tests failed.
```

Five of the seven new tests failed red (the other two — the up/repeat
no-op test and the read-only no-op test — pass trivially against the old
unconditional-`ignored` `onKey`, since "do nothing" is what it already did;
both are re-verified against the real implementation below and still
pass for the right reason, not vacuously).

**GREEN** — after implementing `onKey`/`_deleteSelection`/`_groupCascade`,
same command:

```
00:00 +10: keys and delete Escape when idle clears
00:00 +11: keys and delete a KeyUpEvent and a KeyRepeatEvent do nothing
00:00 +12: keys and delete Delete removes a leaf and an instance through the log; undo restores geometry, not selection
00:00 +13: keys and delete Delete cascades a group: leaves, child instance, nested group, then the group
00:00 +14: keys and delete a region inside a group is deleted once: the boundary's command takes the fill
00:00 +15: keys and delete a read-only document is selectable and Delete is a no-op
00:00 +16: keys and delete a refused object stays selected, a permitted one goes
00:00 +17: All tests passed!
```

All 17 tests in `select_tool_test.dart` (10 pre-existing + 7 new) pass.

## Gate line

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

`CI=true flutter test` (full suite): `00:11 +734 ~1 -5`. The five failures
are exactly the pre-existing goldens named in the task and nothing else:

```
Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```

`flutter analyze`: `No issues found! (ran in 1.7s)`.

`dart format --output=none --set-exit-if-changed .`: first run reported
`Changed test/select_tool_test.dart` (exit 1) — the file as I wrote it had
one line over the formatter's preferred wrapping; ran `dart format
test/select_tool_test.dart` to apply it, then re-ran
`--set-exit-if-changed .`, which reported `Formatted 130 files (0 changed)`
(exit 0).

Re-ran `CI=true flutter test test/select_tool_test.dart` after the
formatting pass to confirm the reformat didn't change behavior: still
`+17: All tests passed!`.

`git status --short` before staging showed only the two intended files
modified — no `analysis_options.yaml` rewritten by `flutter pub get`.

## Trailer check

`git log -1 --format=%B | grep -c "Fable 5.1"` → `1`.

## Files changed

- `packages/jet_cad_2d_flutter/lib/src/select_tool.dart`
- `packages/jet_cad_2d_flutter/test/select_tool_test.dart`

Commit: `24e09d8` — "feat(tools): Escape and Delete on SelectTool, with the
group cascade".

## Self-review

- Capability mapping double-checked against
  `packages/jet_cad_2d/lib/src/document/commands.dart`: `RemoveEntityCommand`
  -> `Capability.geometry`, `RemoveNodeCommand` -> `Capability.structure` —
  matches test 7's `DraftPermissions(transform: false, components: false,
  geometry: true, structure: false)` deleting the leaf and refusing the
  instance.
- `CommandDispatcher.execute` throwing `PermissionDeniedError` (verified at
  `undo.dart:195`, the `_require` helper) is exactly why the permission
  check runs as a preflight over the whole list before any `ctx.execute`
  call — a partially-executed, then-thrown list would leave the document
  half-mutated with no way to unwind it cleanly.
- `RemoveEntityCommand` on a boundary with exactly one dependent fill
  removes the fill in the same command (`commands.dart:162-201`) — checked
  test 5 against this directly: the boundary and fill are both owned by the
  test's group, `_groupCascade` puts the fill in `skip` because its
  boundary is a non-fill leaf of the same group, so only the boundary's own
  `RemoveEntityCommand` is queued and it takes the fill with it; no second,
  now-dangling `RemoveEntityCommand(fill)` is ever built.
- `SelectionController.remove` is idempotent on an already-pruned key (it
  checks `_keys.remove(k)`'s boolean return before deciding whether to
  notify), so the redundant work between the synchronous
  `ctx.selection.remove([key])` and the controller's own async
  `document.changes`-driven pruning is harmless — confirmed by reading
  `selection.dart` rather than assumed.
- Re-read the `_groupCascade` recursion against the M-02j fixture by hand:
  leaves of the outer group first, then the child instance's
  `RemoveNodeCommand`, then the nested group's own leaves before its own
  `RemoveNodeCommand`, then the outer group's `RemoveNodeCommand` last —
  matches "leaves, child instance, nested group, then the group" from the
  task title, and the test's assertions (all slots null, all three node
  handles null, `canUndo` true) confirm it end to end rather than just
  inspecting the command list.
- Confirmed via `flutter analyze` (no `unused_import`/`unused_element`,
  which are errors in this workspace) that the added imports
  (`KeyDownEvent`, `LogicalKeyboardKey` in the lib file;
  `KeyRepeatEvent`/`KeyUpEvent`/`KeyEventResult`/`dart:typed_data` in the
  test file) are all actually used.
- Did not run the `jet_cad_2d` (engine) package's own gate line — this task
  touches only `jet_cad_2d_flutter`, and no engine source or test file was
  modified.

## Concerns

- None. The implementation is the brief's pseudocode unmodified in
  substance; the only judgment calls were fixture-construction mechanics
  (documented above under Departures), not behavior.
