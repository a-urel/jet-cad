# Task 4 report: a v5 document resolves bit-identically under a v6 build

## Step 1 — test added

Appended the `a v5 document resolves bit-identically under a v6 build` group
to `packages/jet_cad_2d/test/codec/instance_style_codec_test.dart`, verbatim
per the brief. The target file did not already carry the `dart:typed_data`
and `vector_math_64` imports the brief's interface note claimed — checked
with `grep -n "^import"` before editing, confirmed against the same pattern
in `test/index/query_filter_test.dart` (`import 'dart:typed_data';` +
`import 'package:vector_math/vector_math_64.dart' hide Aabb2;`) — so both
were added; the fixture code (`Float64List`, `Vector2.zero()`) needs them.

`dart format` reflowed one line (the `contextFor` call at what is now line
160-161) after the append; applied and re-verified, no other change.

## Step 2 — run it (expected: PASS on first run)

```
$ cd packages/jet_cad_2d && CI=true dart test test/codec/instance_style_codec_test.dart
00:00 +0: loading test/codec/instance_style_codec_test.dart
00:00 +0: an instance round-trips all four style fields at non-default values
00:00 +1: the four fields are absent-tolerant and default to the no-op values
00:00 +2: two instances differing only in linetypeScale are not equal
00:00 +3: the schema this build writes is 6
00:00 +4: a v5 document resolves bit-identically under a v6 build every field of the resolved style matches the pre-3f.1 answer
00:00 +5: a v5 document resolves bit-identically under a v6 build a v6 build refuses nothing it wrote and everything from the future
00:00 +6: All tests passed!
```

Both new tests passed on the first run, as expected — this is a regression
guard, not a red-green cycle. No finding against Tasks 1-3.

## Step 3 — fire M10, resolution consequence

Found the target in `lib/src/document/node.dart` (lines 279-281 before edit):

```dart
        linetype: json['linetype'] == null
            ? ReservedHandles.byBlockLinetype
            : Handle.fromJson(json['linetype']),
```

```
$ cp lib/src/document/node.dart /tmp/node.dart.bak
```

Edit applied — `ReservedHandles.byBlockLinetype` → `ReservedHandles.byLayerLinetype`:

```dart
        linetype: json['linetype'] == null
            ? ReservedHandles.byLayerLinetype
            : Handle.fromJson(json['linetype']),
```

```
$ CI=true dart test test/codec/instance_style_codec_test.dart
00:00 +0: loading test/codec/instance_style_codec_test.dart
00:00 +0: an instance round-trips all four style fields at non-default values
00:00 +1: the four fields are absent-tolerant and default to the no-op values
00:00 +1 -1: the four fields are absent-tolerant and default to the no-op values [E]
  Expected: <3>
    Actual: <2>

  package:matcher                                 expect
  test/codec/instance_style_codec_test.dart 64:5  main.<fn>

00:00 +1 -1: two instances differing only in linetypeScale are not equal
00:00 +2 -1: the schema this build writes is 6
00:00 +3 -1: a v5 document resolves bit-identically under a v6 build every field of the resolved style matches the pre-3f.1 answer
00:00 +3 -2: a v5 document resolves bit-identically under a v6 build every field of the resolved style matches the pre-3f.1 answer [E]
  Expected: <4>
    Actual: <71>

  package:matcher                                  expect
  test/codec/instance_style_codec_test.dart 177:7  main.<fn>.<fn>

00:00 +3 -2: a v5 document resolves bit-identically under a v6 build a v6 build refuses nothing it wrote and everything from the future
00:00 +4 -2: Some tests failed.

Failing tests:
  test/codec/instance_style_codec_test.dart: a v5 document resolves bit-identically under a v6 build every field of the resolved style matches the pre-3f.1 answer
  test/codec/instance_style_codec_test.dart: the four fields are absent-tolerant and default to the no-op values

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

M10 was killed as predicted: `every field of the resolved style matches the
pre-3f.1 answer` went red on `expect(style.linetype,
ReservedHandles.continuousLinetype)`, printed as `Expected: <4> Actual:
<71>` — `ReservedHandles.continuousLinetype` is handle value 4;
`Handle(71)` is the STRUCT layer's linetype, exactly the value the brief
named. (Task 1's own no-op test also died on the same mutant, as a bonus —
`Expected: <3> Actual: <2>`, i.e. `ReservedHandles.byBlockLinetype` vs
`ReservedHandles.byLayerLinetype` by their raw handle values.)

Restored from the backup:

```
$ cp /tmp/node.dart.bak packages/jet_cad_2d/lib/src/document/node.dart
$ git diff packages/jet_cad_2d/lib/src/document/node.dart
(no output — clean)
```

Re-ran the suite to confirm the restore:

```
$ CI=true dart test test/codec/instance_style_codec_test.dart
00:00 +0: loading test/codec/instance_style_codec_test.dart
00:00 +0: an instance round-trips all four style fields at non-default values
00:00 +1: the four fields are absent-tolerant and default to the no-op values
00:00 +2: two instances differing only in linetypeScale are not equal
00:00 +3: the schema this build writes is 6
00:00 +4: a v5 document resolves bit-identically under a v6 build every field of the resolved style matches the pre-3f.1 answer
00:00 +5: a v5 document resolves bit-identically under a v6 build a v6 build refuses nothing it wrote and everything from the future
00:00 +6: All tests passed!
```

## Full green gate — jet_cad_2d

```
$ CI=true dart test
...
00:03 +793: All tests passed!
```

(793 tests, all green; tail of the transcript, full output too long to
paste — final line shown, no failures reported.)

```
$ dart analyze
Analyzing jet_cad_2d...
No issues found!
```

```
$ dart format --output=none --set-exit-if-changed .
Changed test/codec/instance_style_codec_test.dart
Formatted 112 files (1 changed) in 0.19 seconds.
```

Applied the format fix (`dart format test/codec/instance_style_codec_test.dart`
— reflowed one line, the `contextFor` call, no semantic change), then
re-verified all three commands green:

```
$ CI=true dart test test/codec/instance_style_codec_test.dart
... 6 tests, All tests passed!

$ dart analyze
Analyzing jet_cad_2d...
No issues found!

$ dart format --output=none --set-exit-if-changed .
Formatted 112 files (0 changed) in 0.20 seconds.
```

## Step 4 — golden gate (jet_cad_2d_flutter)

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test
...
00:04 +299: All tests passed!
```

(299 tests, all green — tail pasted above during the session; full
transcript too long to repeat here in full, but every reported line was
`+N` and the terminal line was `All tests passed!`, no `-N` failures.)

```
$ git status --short packages/jet_cad_2d_flutter/test/golden
(no output)
```

No golden PNG regenerated or modified.

## Step 5 — commit

```
$ git add packages/jet_cad_2d/test/codec/instance_style_codec_test.dart
$ git commit -m "test: a v5 document resolves bit-identically under v6 ..."
[main 03bc025] test: a v5 document resolves bit-identically under v6
 1 file changed, 117 insertions(+)
```

Commit SHA: `03bc025ce46ccfd7a9bb9b4be1b70ad04942b6d9`

`git status --short` before commit showed only the one intended file
modified; no `analysis_options.yaml` drift observed or committed.

## Outcome

DONE. Both new tests passed on first run (Tasks 1-3's defaults confirmed as
true no-ops). M10 was killed by the resolution-consequence test exactly as
predicted (`Handle(71)` instead of `continuousLinetype`). Full green gate in
both packages; no golden moved.
