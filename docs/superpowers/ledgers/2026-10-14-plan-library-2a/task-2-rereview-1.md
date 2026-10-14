### Finding Verdicts

- **probe blamed a place reader for a contributor's placeBox error** — ADDRESSED. parametric_system.dart (probe, new block after the first `_survey`) asks every other live place contributor's `view.placeBoxOf` in a try, adds a thrower to `broken`, and re-surveys with `isolated()`. The probed object is skipped (`h == object`), so a contributor probed itself still returns its own error. E2-P6 (probe_test.dart, end) pins: probe(hS) null, scopeSights['S'] == [hQ], generate S ran, probe(hQ) null, probe(hP) == HookFailure('placeBox P'), document/stateId unchanged. The report shows M-E2p-placeiso turning E2-P1 and E2-P6 red, and the resurvey-only mutation turning E2-P6 red.

### E2-P1 change
Follows from the ruling and is stricter, not weaker: it now pins the extra calls and their order ('placeBox P', 'placeBox Q' first), and beyondSurvey still filters only reach/references. The list is otherwise unchanged. It is red under the mutation.

### New Breakage in the Fix Diff
None Critical/Important.
- Minor: the isolation is one pass, not a fixpoint (the implementer's own concern). Removing a thrower could make a later contributor's placeBox throw, which would still be blamed on the probed object.
- Minor: the doc says a healthy contributor's placeBox "runs once", but after a re-survey the new view re-asks it (twice in that rare case). The E2-P6 tests do not pin the count.

### Out-of-Scope Observations
None.

### Verdict
**Fix round:** All findings addressed, no new Critical/Important breakage.
