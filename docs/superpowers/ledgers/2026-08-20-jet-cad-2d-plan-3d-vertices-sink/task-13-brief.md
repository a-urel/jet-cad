### Task 13: The web rows

The rows that can still change a decision. If CanvasKit's `drawVertices` is
faster than its `drawPath` at these counts, the web default flips and
`CanvasDrawSink` becomes a fallback with no default platform.

- [ ] **Step 1: Get the driver working before measuring anything**

```sh
which chromedriver || brew install chromedriver
chromedriver --port=4444 &
```

The invocation is `flutter drive ... -d chrome`, **not**
`flutter test --platform chrome`: the first drives the integration-test rig
these rows share with the desktop ones, the second runs widget tests and cannot
reach the frame-timing harness. Getting this wrong is how a web row comes back
empty and gets reported as "web is fine".

- [ ] **Step 2: One smoke run, and check `backend=`**

```sh
cd apps/dev_harness_2d
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart --profile -d chrome \
  --dart-define=TEXT=true --dart-define=ENTITIES=10000 \
  --dart-define=RIG=pan --dart-define=BACKEND=vertices 2>&1 \
  | grep -E "R2 |build |raster |backend="
```

Expected: `backend=vertices` — the override is honoured on web by design, and
if it reads `canvas` the clamp Task 1 forbade has crept back in.

**If the run hangs or produces no timing block, stop and report that.** A web
row that cannot be measured is a finding: it means the platform default stands
on the argument in the design document rather than on a number, and the plan
says so instead of inventing one.

- [ ] **Step 3: The rows**

```sh
for N in 10000 50000; do
  for B in canvas vertices; do
    for I in 1 2 3; do
      echo "### web R2 entities=$N backend=$B run=$I"
      flutter drive --driver=test_driver/integration_test.dart \
        --target=integration_test/frame_timing_test.dart --profile -d chrome \
        --dart-define=TEXT=true --dart-define=ENTITIES=$N \
        --dart-define=RIG=pan --dart-define=BACKEND=$B 2>&1 \
        | grep -E "R2 |build |raster |backend="
    done
  done
done
```

500,000 is deliberately not run on the web: the desktop rows take minutes each
there and CanvasKit is slower, so it would cost hours to confirm something the
50,000 row already indicates. Say that in the note rather than leaving a blank
cell.

- [ ] **Step 4: State the platform default with the number behind it**

Two outcomes, both acceptable, one of them written down:

- **CanvasKit's `drawVertices` is slower.** The default stands as the design
  document wrote it, now with a measurement instead of an argument.
- **It is faster by more than the spread.** The web default flips to
  `vertices`, `defaultRenderBackend()` becomes unconditional, and
  `CanvasDrawSink` stays as a fallback with no default platform. Change
  `render_backend.dart` in its own commit, with the numbers in the message.

- [ ] **Step 5: Kill chromedriver and clean up**

```sh
kill %1
cd /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/vertices-spike
git status --porcelain   # must be clean
```

---

