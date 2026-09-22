# Task 3 report — The codec hook, and the two round-trip tests

## What I implemented

- Added an optional `void Function(ComponentRegistry registry)? registerComponents`
  parameter to `DraftDocumentCodec.decode` in
  `packages/jet_cad_2d/lib/src/codec/json_codec.dart`, called as
  `registerComponents?.call(doc.components);` immediately after
  `DraftDocument.empty(...)` and before any of the `_load*` calls (in
  particular before `doc.components.loadJson(...)`), with the comment the
  brief specifies verbatim (spec 04 D9 / M-04d).
- Added the same named parameter to `decodeString`, forwarded to `decode`.
- Added the import `../document/component.dart` to `json_codec.dart` (needed
  for the `ComponentRegistry` type in the new parameter's signature — it
  wasn't previously imported there).
- Wrote `packages/jet_cad_2d/test/codec/page_component_roundtrip_test.dart`
  with the three tests exactly as given in the brief, with one deliberate
  deviation: in the second test I did **not** write the `anyOf(returnsNormally,
  throwsA(anything))` placeholder and then swap it — I wrote
  `expect(back.components.get<PageComponent>(back.rootHandle), isNull);`
  directly, per the brief's own instruction that this is the known correct
  behavior (confirmed by reading `ComponentRegistry.get`: `_stores[T]?[handle]`
  — `_stores[PageComponent]` is null on a registry that never registered the
  type, so `get<PageComponent>` returns null via `?.`, no throw). I then ran
  the full test file and confirmed this assertion passes on the very first
  run (see GREEN output below), which is the "confirm by running it" the
  brief asks for — I did not first land the `anyOf` form and then edit it in
  a second commit.

## TDD evidence

### RED — before implementing the hook (only the test file existed)

Command: `CI=true dart test test/codec/page_component_roundtrip_test.dart`

```
00:00 +0: loading test/codec/page_component_roundtrip_test.dart
00:00 +0 -1: loading test/codec/page_component_roundtrip_test.dart [E]
  Failed to load "test/codec/page_component_roundtrip_test.dart":
  test/codec/page_component_roundtrip_test.dart:28:9: Error: No named parameter with the name 'registerComponents'.
          registerComponents: PageComponent.register);
          ^^^^^^^^^^^^^^^^^^
  lib/src/codec/json_codec.dart:146:24: Context: Found this candidate, but the arguments don't match.
    static DraftDocument decodeString(
                         ^^^^^^^^^^^^
  test/codec/page_component_roundtrip_test.dart:53:9: Error: No named parameter with the name 'registerComponents'.
          registerComponents: PageComponent.register);
          ^^^^^^^^^^^^^^^^^^
  lib/src/codec/json_codec.dart:92:24: Context: Found this candidate, but the arguments don't match.
    static DraftDocument decode(
                         ^^^^^^
00:00 +0 -1: Some tests failed.

Failing tests:
  test/codec/page_component_roundtrip_test.dart: loading test/codec/page_component_roundtrip_test.dart
```

Fails exactly as predicted: no named parameter `registerComponents`.

### GREEN — after implementing the hook

Command: `CI=true dart test test/codec/page_component_roundtrip_test.dart`

```
00:00 +0: loading test/codec/page_component_roundtrip_test.dart
00:00 +0: the page round-trips typed when the load registers it, and the bytes are stable
00:00 +1: without registration the bytes survive but the type does not — which is why the typed assertion above exists
00:00 +2: decode (the map form) takes the same hook
00:00 +3: All tests passed!
```

All three tests pass, including the `isNull` assertion in test 2 on the first
run — confirming the brief's claim about `get<T>` on an unregistered type.

## Gate line output (from `packages/jet_cad_2d`)

### `CI=true dart test` (full suite)

Tail of output:

```
00:02 +842: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +843: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:03 +844: test/invariants/query_allocation_test.dart: pickInto stays local: an over-wide broad phase would blow the time budget
00:03 +845: test/invariants/query_allocation_test.dart: (tearDownAll)
00:03 +845: All tests passed!
```

Exit code: 0. Counter: 845 (up from the 82-at-branch-point baseline stated in
constraints.md, reflecting tasks 1–2's own tests plus these 3).

### `dart analyze`

```
Analyzing jet_cad_2d...
No issues found!
```

Exit code: 0.

### `dart format --output=none --set-exit-if-changed .`

First run (before formatting my new test file) reported:

```
Changed test/codec/page_component_roundtrip_test.dart
Formatted 121 files (1 changed) in 0.22 seconds.
```

Exit code: 1. I ran `dart format test/codec/page_component_roundtrip_test.dart`
to apply the canonical formatting (multi-line arguments broken out), then
re-ran the full gate line:

```
00:03 +845: All tests passed!
```
Exit 0.

```
Analyzing jet_cad_2d...
No issues found!
```
Exit 0.

```
Formatted 121 files (0 changed) in 0.22 seconds.
```
Exit 0.

All three gate commands are green in the final state.

## Files changed

- `packages/jet_cad_2d/lib/src/codec/json_codec.dart` — added
  `registerComponents` parameter to `decode` and `decodeString`, the hook
  call, the import of `../document/component.dart`, and the placement
  comment.
- `packages/jet_cad_2d/test/codec/page_component_roundtrip_test.dart` — new
  file, three tests as specified.

No existing test file was modified.

## Self-review

**Completeness.**
- Three tests present, all green: typed round-trip + byte stability;
  unregistered load preserves bytes as unknown and `get<T>` is null; `decode`
  (map form) takes the same hook.
- Both entry points (`decode` and `decodeString`) take the
  `registerComponents` named parameter; `decodeString` forwards it unchanged.
- Hook placement: immediately after `DraftDocument.empty(...)`, before every
  `_load*` call including `doc.components.loadJson(...)` — matches the
  brief's Step 3 exactly, with the same comment text.

**Quality.** The added import (`../document/component.dart`) is the minimal
addition needed for the `ComponentRegistry` type to resolve in the new
parameter signature; nothing else in the diff touches unrelated code. Diff is
otherwise purely additive (two new parameters, one hook call, one comment,
one forwarded argument).

**Discipline.** `test/codec/json_codec_test.dart` (the existing codec test
file) was not touched — confirmed via `git status --short` and `git diff`,
which show only the new test file and the modified `json_codec.dart`. No
subagents were dispatched. No mutation sweep was run (none was asked for).

**Pristine output.** `git status --short` after the commit is empty (clean
working tree). No `analysis_options.yaml` file was touched by `pub get` or
`dart format` during this task, so nothing needed `git checkout --`.

## Concerns

None. The one deviation from the brief's literal Step 1 text (skipping the
`anyOf` placeholder and writing the confirmed `isNull` assertion directly) is
explicitly sanctioned by the brief's own parenthetical instruction and by the
orchestrator's task message, and is called out above and in the commit's
test file as delivered.

## Commit

`d182080` — `feat(codec): registerComponents hook on decode and decodeString`,
trailer `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>` (verified:
`git log -1 --format=%B | grep -c "Fable 5.1"` → `1`).
