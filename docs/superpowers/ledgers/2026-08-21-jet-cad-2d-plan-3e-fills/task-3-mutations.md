# Task 3 mutation transcripts — run by the CONTROLLER, 2026-08-21T15:34:54Z

Why the controller ran these: four implementer runs died on a 600s stream
watchdog. Three died on a mid-session Flutter 3.47.0 -> 3.47.1 upgrade that
blocked every `flutter` call on a Dart SDK re-download; the fourth died
fighting a `trap ... EXIT` spread across two Bash calls, which fires before
the test runs and so measures nothing.

TWO earlier controller attempts were discarded, and both failures are worth
recording because both produced confident wrong answers:

  1. The stalled agent had left the TEST file half-mutated (bare ints where
     `const Handle(n)` belongs). Every run failed to LOAD, so all three
     mutants read KILLED when nothing had been measured. The test file was
     restored by hand and re-verified 6/6 green before the runs below.
  2. The compile-error guard added after (1) matched `dart test`'s own
     `loading test/...` PROGRESS line, so all three then read INVALID. The
     guard now keys on 'Failed to load' and on a compiler 'Error:' line.

A verdict is only KILLED below if the suite ran and a NAMED test failed.

## control before mutating
```
00:00 +5: the index survives a purge because handles do
00:00 +6: All tests passed!
```

## T3a — trianglesFor returns a defensive copy instead of the stored list
```
00:00 +4 -1: the index survives a purge because handles do
00:00 +5 -1: Some tests failed.

Failing tests:
  test/document/fill_index_test.dart: a hit returns the stored list itself, not a copy

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```
VERDICT: KILLED — a hit returns the stored list itself, not a copy

## T3b — dropBoundary forgets the links naming the boundary
```
00:00 +4 -1: the index survives a purge because handles do
00:00 +5 -1: Some tests failed.

Failing tests:
  test/document/fill_index_test.dart: dropBoundary removes the triangles and every link naming it

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```
VERDICT: KILLED — dropBoundary removes the triangles and every link naming it

## T3c — fillsOf returns insertion order instead of handle order
```
00:00 +4 -1: the index survives a purge because handles do
00:00 +5 -1: Some tests failed.

Failing tests:
  test/document/fill_index_test.dart: fillsOf returns every fill naming a boundary, in handle order

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```
VERDICT: KILLED — fillsOf returns every fill naming a boundary, in handle order

## control after restoring
```
00:00 +5: the index survives a purge because handles do
00:00 +6: All tests passed!
```

## KEYING MUTANT — the cache keyed by `geomIndex` instead of `Handle`

Hand-run, not a one-line edit: `_triangles` becomes `Map<int, Int32List>`,
`trianglesFor` and `putTriangles` take an `int`, and every call site in the
test file passes a geomIndex. This is the design decision the whole task
exists to defend, so it is the transcript that matters most.

```
  package:matcher                          expect
  test/document/fill_index_test.dart 88:5  main.<fn>
  
00:00 +5 -1: Some tests failed.

Failing tests:
  test/document/fill_index_test.dart: the index survives a purge because handles do

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```
VERDICT: KILLED — the index survives a purge because handles do

## control after restoring the keying mutant
```
00:00 +5: the index survives a purge because handles do
00:00 +6: All tests passed!
```
