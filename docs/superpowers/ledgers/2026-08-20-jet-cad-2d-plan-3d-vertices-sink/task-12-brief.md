### Task 12: The desktop rows

**Files:**
- Create: nothing. Task 14 writes the note; this task produces the readings and
  pastes the raw transcripts into the task report.

- [ ] **Step 1: Check the machine before anything else**

```sh
pmset -g | grep lowpowermode
```

Expected: `lowpowermode         0`. **If it reads 1, stop and say so** — Plan
3c's entire results note is contaminated because nobody checked, and the
re-measurement showed a uniform ~24% on both raster and build. Check it again
after the last run and record both readings.

- [ ] **Step 2: Run R2 on both backends at all three corpus sizes**

Three consecutive runs per cell, so the median and the spread are both real.
Nine cells means eighteen runs; the 500,000 rows take minutes each.

```sh
cd apps/dev_harness_2d
for N in 10000 50000 500000; do
  for B in canvas vertices; do
    for I in 1 2 3; do
      echo "### R2 entities=$N backend=$B run=$I"
      flutter drive --driver=test_driver/integration_test.dart \
        --target=integration_test/frame_timing_test.dart --profile -d macos \
        --dart-define=TEXT=true --dart-define=ENTITIES=$N \
        --dart-define=RIG=pan --dart-define=BACKEND=$B 2>&1 \
        | grep -E "R2 |build |raster |screenSpace|dashSpans|backend=|text:"
    done
  done
done
```

**Read `backend=` in every block.** If it does not match the define, the run is
void — that is Plan 3c's `TEXT` bug in a new place, and it printed entirely
plausible numbers for a whole session.

- [ ] **Step 3: Run R4a and R4b at 50,000 on both backends**

```sh
for B in canvas vertices; do
  for RIG in leaf instance; do
    for I in 1 2 3; do
      echo "### $RIG backend=$B run=$I"
      flutter drive --driver=test_driver/integration_test.dart \
        --target=integration_test/frame_timing_test.dart --profile -d macos \
        --dart-define=TEXT=true --dart-define=ENTITIES=50000 \
        --dart-define=RIG=$RIG --dart-define=BACKEND=$B 2>&1 \
        | grep -E "R4|build |raster |command |backend="
    done
  done
done
```

- [ ] **Step 4: Record peak buffer bytes**

`_reserve` doubles and never gives capacity back — that is the property that
makes a steady-state frame allocation-free, and it means one zoom-out at
500,000 entities pins the peak for the life of the widget. Read
`debugCapacityVertices` after the 500,000 whole-drawing frame and record
`capacity * (8 + 4)` bytes. The number exists so nobody is surprised by it
later.

- [ ] **Step 5: Clean up**

```sh
cd /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/vertices-spike
git checkout -- apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj
git status --porcelain   # must be clean
pmset -g | grep lowpowermode
```

- [ ] **Step 6: Paste every raw transcript into the task report**

Not a summary. The medians go in the note; the transcripts go in the report, so
a reviewer can recompute them. **Never retype a number** — copy it.

---

