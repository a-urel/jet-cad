# Task 8 fix — five-deletion matrix, run by the CONTROLLER, 2026-08-21T17:21:59Z

The fix agent applied the fixture change and stalled on the 600s watchdog
before running the matrix. Work was intact on disk; the controller ran it.
Each deletion below is ONE shell invocation: delete, test, restore.

A FIRST controller attempt was discarded: it used a shell array indexed
from 0, and this shell is zsh, where arrays are 1-based. The first
iteration deleted a block chosen by an empty name and every later verdict
was shifted by one. Recorded because it read as five plausible results.

For each deletion the transcript records BOTH the test that failed AND
how many of the five fill tests failed in total — which must be exactly 1.
That second number is the property the review finding was about.

## control before deleting anything
```
00:00 +16: an inverted pair is reported and nothing is changed
00:00 +17: All tests passed!
```

## deleted: fillBoundaryMissing
```

Failing tests:
  test/document/validate_test.dart: a fill naming nothing is reported

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```
failing tests: a fill naming nothing is reported;;Consider enabling the flag chain-stack-traces to receive more detailed exceptions.;For example, 'dart test --chain-stack-traces'.;
fill tests failing: 1 (must be exactly 1)
expected: a fill naming nothing is reported

## deleted: fillBoundaryNotFillable
```

Failing tests:
  test/document/validate_test.dart: a fill on a text entity is reported as not fillable

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```
failing tests: a fill on a text entity is reported as not fillable;;Consider enabling the flag chain-stack-traces to receive more detailed exceptions.;For example, 'dart test --chain-stack-traces'.;
fill tests failing: 1 (must be exactly 1)
expected: a fill on a text entity is reported as not fillable

## deleted: fillBoundaryNotClosed
```

Failing tests:
  test/document/validate_test.dart: a fill on an open polyline is reported as not closed

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```
failing tests: a fill on an open polyline is reported as not closed;;Consider enabling the flag chain-stack-traces to receive more detailed exceptions.;For example, 'dart test --chain-stack-traces'.;
fill tests failing: 1 (must be exactly 1)
expected: a fill on an open polyline is reported as not closed

## deleted: fillBoundaryForeignOwner
```

Failing tests:
  test/document/validate_test.dart: a fill in a different owner than its boundary is reported

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```
failing tests: a fill in a different owner than its boundary is reported;;Consider enabling the flag chain-stack-traces to receive more detailed exceptions.;For example, 'dart test --chain-stack-traces'.;
fill tests failing: 1 (must be exactly 1)
expected: a fill in a different owner than its boundary is reported

## deleted: fillDrawOrderInverted
```

Failing tests:
  test/document/validate_test.dart: an inverted pair is reported and nothing is changed

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```
failing tests: an inverted pair is reported and nothing is changed;;Consider enabling the flag chain-stack-traces to receive more detailed exceptions.;For example, 'dart test --chain-stack-traces'.;
fill tests failing: 1 (must be exactly 1)
expected: an inverted pair is reported and nothing is changed

## control after restoring
```
00:00 +16: an inverted pair is reported and nothing is changed
00:00 +17: All tests passed!
```
