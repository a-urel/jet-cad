### Task 10: The mutation log

**Files:**
- Create: `docs/superpowers/notes/plan-b-mutation-log.md`

**Interfaces:**
- Consumes: every mutation transcript from Tasks 3-9.
- Produces: the document of record the exit gate's mutation clause is scored
  against.

Every earlier task fired its mutations and pasted the transcripts into its
report. This task collects them, re-fires any that were not run against the
**full** suite, and writes them up.

- [ ] **Step 1: Build the table**

Open the log with a summary table naming every mutant, its verdict and the
gate that killed it — the shape `plan-3i-mutation-log.md` uses. The mutants
this plan pre-committed:

| id | mutation | expected gate |
|---|---|---|
| M-B1 | drop `_coveredArgb` from strokes | `geometry_collector_test.dart`, the sub-pixel alpha test |
| M-B2 | emit the join after its segment | `geometry_collector_test.dart`, the kind-sequence test |
| M-B3 | skip the seam join | the closed-run count test **and** the pixel differential's seam test |
| M-B4 | flatten circles in collection space | the ellipse test |
| M-B5 | expand the quad at collection scale | `instance_expander_test.dart`, the half-width test |
| M-B6 | always miter, never bevel | `instance_expander_test.dart`, the hairpin test |
| M-B7 | flip the join's outer side | the pixel differential |
| M-B8 | treat `point()` as a zero-length capped stroke | the point test **and** the pixel differential |
| M-B9 | sort the instance buffer by kind before upload | the collector differential's order assertions |
| M-B10 | emit joins as collector geometry at the collection width | see Step 2 |

**M-B9 and M-B10 have not been fired by any earlier task.** Fire them here.

- [ ] **Step 2: Fire the two outstanding mutants**

**M-B9** — in `GeometryCollector.data`, sort the records by kind before
returning them:

```dart
  Float32List get data {
    final flat = _buffer.sublist(0, _instances * kFloatsPerInstance);
    final records = List<int>.generate(_instances, (i) => i)
      ..sort((a, b) => flat[a * kFloatsPerInstance]
          .compareTo(flat[b * kFloatsPerInstance]));
    final out = Float32List(flat.length);
    for (var i = 0; i < records.length; i++) {
      out.setRange(i * kFloatsPerInstance, (i + 1) * kFloatsPerInstance, flat,
          records[i] * kFloatsPerInstance);
    }
    return out;
  }
```

This is the spec's *"give strokes, joins and fills separate draw calls"*
mutation reduced to the one buffer this plan has. Expected: red on the
collector differential's order assertions and on the kind-sequence tests.

**M-B10** — the spec's own wording: *"emit joins as collector geometry at the
collection width → miters distort."* Fire it in the expander, which is where
this plan's shader lives: replace the join branch's `halfWidth` with
`halfWidth * t.scaleMagnitude`, then run the pixel differential with the
comparison's transform set to something other than the identity. **If the
existing comparison runs at the identity, this mutant cannot die**, which is
itself the finding: add a scaled arm to `resident_pixel_differential_test.dart`
that runs the corpus under a 3x transform and asserts agreement there too, then
re-fire. Report which of the two happened.

- [ ] **Step 3: Write the log**

For each mutant: the exact edit, the command, the verbatim failure or the
statement that it survived, and — for survivors — a derivation of *why* it
survives, in the shape Plan 3i's M24 entry uses. **A survivor with a reason is
a result; a survivor without one is a gap.**

Include M-B1' from Task 9 Step 6 if it survived the pixel differential, with
its reason and its gate of record.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/notes/plan-b-mutation-log.md
git commit -m "docs: Plan B's mutation log, ten mutants and their verdicts"
```

---

