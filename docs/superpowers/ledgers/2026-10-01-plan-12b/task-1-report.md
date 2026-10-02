# Task 1 report — the header, the target, schema 7

Implementer: fresh agent. Base HEAD 9ee2e60. Scratch: .../scratchpad/l1/.

## Standing engine failures, BEFORE (HEAD 9ee2e60, Linux)

`CI=true dart test test/testing/generate_document_test.dart`:
```
00:00 +1 -1: the default document is the one Plan 2 measured, byte for byte [E]
  Expected: <1593811103237081036>
    Actual: <7763566604490466414>
  test/testing/generate_document_test.dart 59:5  main.<fn>
00:00 +11 -2: both text fractions default to zero and change nothing [E]
  Expected: <1593811103237081036>
    Actual: <7763566604490466414>
  test/testing/generate_document_test.dart 240:5  main.<fn>
00:01 +16 -2: Some tests failed.
```

## Finding: P-7's fingerprint re-baseline cannot be done in this container

The two standing failures ARE the two fingerprint tests P-7 asks to
re-baseline. Their pinned values are macOS values (Ruling 07-7, walls spike
finding 7: a hash of trig-dependent output; Linux libm differs). A Linux
container cannot compute the macOS value after the schema bump (FNV over the
whole string; the suffix is trig-dependent). See "Decisions" below for what
was done.

## Commit

`a6cd4bb feat(engine): the current layer in the header, schema 7`

Files: engine lib `header.dart`, `command.dart`, `draft_document.dart`
(`@override` on header), `tables.dart` (`LayerRecord.copyWith`),
`layer_commands.dart` (new), `json_codec.dart` (`_loadHeader`),
`schema_version.dart`, `jet_cad_2d.dart` (export); engine tests
`layer_header_test.dart` (new, 17 tests), `command_test.dart`,
`commands_test.dart` (fakes), `header_test.dart` (key order),
`json_codec_test.dart`, `instance_style_codec_test.dart`,
`generate_document_test.dart` (comment only); app
`assets/library/furniture.jetlib` (regenerated).

## Gates (after the change, at a6cd4bb's tree)

- engine: `00:18 +1138 -2: Some tests failed.` (1121 + 17 new); failing =
  the same two: `the default document is the one Plan 2 measured, byte for
  byte`, `both text fractions default to zero and change nothing`, now
  `Expected: <1593811103237081036> Actual: <-565808937189420354>`.
  `dart analyze`: `No issues found!`; format exit 0.
- render: `01:04 +1154 ~1 -7: Some tests failed.` (the text_ladder goldens,
  rungs 1-4 shown, "... and 3 more"); `flutter analyze`: `No issues found!
  (ran in 7.6s)`; format exit 0.
- app: `03:12 +934: All tests passed!`; `No issues found! (ran in 7.0s)`;
  format exit 0. (First run: `03:21 +933 -1` — the furniture asset, see
  below.)
- dev_harness_2d: `No issues found! (ran in 1.9s)`.

## Standing engine failures, AFTER

Same two names, same lines (59, 240), actual value moved from
7763566604490466414 to -565808937189420354 (the header key and the version
enter the hashed string). Count exactly 2.

## Decisions / what the plan got wrong

1. **P-7's fingerprint re-baseline is impossible here.** The two "standing"
   engine failures are exactly the two fingerprint tests P-7 asks to
   re-baseline; their constants are macOS values (Ruling 07-7). Re-baselining
   to the Linux value would turn them green on Linux and red on macOS (and
   change the standing count P-7 says must stay 2). Closest thing in bounds:
   the constants are left, both sites get a comment naming the header key
   and the version and saying the re-baseline is **owed on macOS** (the
   human's machine). After this commit the two tests fail on macOS too until
   that is done. Flag for the controller/human.
2. **Missed by spec/plan: `apps/floor_planner/assets/library/furniture.jetlib`**
   is a committed codec output pinned byte-for-byte by
   `test/symbols/furniture_library_test.dart` ("the committed bytes equal
   the built library"). Regenerated with `dart run
   tool/generate_furniture_library.dart`; verified by script that the new
   bytes equal the old with exactly `"schemaVersion":6` -> 7 and
   `"currentLayer":1,` inserted after `"globalLinetypeScale":1.0,`
   (`only version+currentLayer changed: True 44212 44229`).
3. `test/document/header_test.dart`'s key-order pin gained `currentLayer`
   (not listed in P-7; a direct consequence of D3's key order).
4. `instance_style_codec_test.dart`'s `v5Document()` now also strips
   `header.currentLayer`, so the derived "v5" file stays exactly what a v5
   writer wrote (its own doc comment's contract).
5. `drawingLayer` treats a locked stored layer as usable (decision 7: the
   current layer may be locked). Tested.
6. Open point, not acted on: a dangling stored `currentLayer` does not raise
   the handle seed on load, so a later new layer could be issued that very
   handle and silently become current. The spec says the stored value
   round-trips and is diagnosed (Task 2's warning); left as is.
7. `kMaxLayerNameLength` and `kForbiddenLayerNameCharacters` are public
   constants in `layer_commands.dart` (exported), so the panel can reuse them.

## Mutants (all in `packages/jet_cad_2d`, test file `test/document/layer_header_test.dart`, foreground, cp backup / restore, diff 0 each; script `scratchpad/l1/mut.sh`)

| id | site | mutation | result (real line) |
|---|---|---|---|
| M-LP-12 | `lib/src/codec/json_codec.dart` `_loadHeader` | drop `..currentLayer = header.currentLayer` | RED: `a non-zero current layer round-trips: save, load and save is byte-identical [E]` (+3 more red) |
| M-LP-13 | `lib/src/codec/schema_version.dart` | `kSchemaVersion = 6` | RED: `this build writes schema 7, reads 7, and refuses the next one [E]` / `+16 -1: Some tests failed.` (also caught live once: my first schema edit silently failed to apply and this test was the one red) |
| M-LP-21 | `layer_commands.dart` `drawingLayer` | `return stored;` | RED: `a dangling stored current layer round-trips exactly and draws on layer 0 [E]`, `a hidden stored current layer ... (S-5) [E]`, `falls back to layer 0 when the stored layer is removed [E]` |
| M-LP-T1a | `layerNameError` empty | delete the empty check | RED: `refuses the empty name [E]` |
| M-LP-T1b | untrimmed | `if (false)` | RED: `refuses an untrimmed name, either end [E]` |
| M-LP-T1c | length | `if (false)` | RED: `allows 255 UTF-16 units and refuses 256 [E]` |
| M-LP-T1c2 | length boundary | `>` -> `>=` | RED: `allows 255 UTF-16 units and refuses 256 [E]` |
| M-LP-T1d | forbidden chars | `if (false)` in the loop | RED: `refuses every DXF-forbidden character, alone and inside a name [E]` |
| M-LP-T1d2 | forbidden set | drop the backtick from the constant | RED: same test `[E]` |
| M-LP-T1e | duplicate | guard made unreachable (`&& name.isEmpty`; a first `if (false)` form did not compile — null promotion — and is not counted) | RED: `refuses another layer's name under toLowerCase() [E]` |
| M-LP-T1f | self exclusion | `existing != null` only | RED: `excludes self: a case-only rename, or no change, is valid [E]` |

11 fired, 11 red, 0 equivalent. Tree clean after (`git status --short` empty).
