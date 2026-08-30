### Task 1: The harness GPU arm moves out of `main.dart`

**Files:**
- Create: `apps/dev_harness_2d/lib/gpu_arm.dart`
- Modify: `apps/dev_harness_2d/lib/main.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: nothing other tasks depend on. This task exists on its own.

`STATUS.md`'s "Resume here" records this as owed and says where it came from:
Plan A's whole-branch review called the inlined arm *"a real inconsistency with
zero correctness content"* and said to move it **as a standalone commit at the
start of Plan B**. The same app keeps the widget spike's arm in sibling files
(`widget_arm.dart`, `widget_arm_rig.dart`), so `main.dart` carrying 534 lines of
GPU arm is the odd one out.

**This is a pure move. No behaviour changes, and the review of this task is
exactly that claim.**

- [ ] **Step 1: Find the arm's boundaries**

```bash
cd apps/dev_harness_2d
grep -n 'RUN_GPU_SPIKE\|GSPIKE\|GeometryCollector\|ResidentGeometry\|GpuDrawBackend' lib/main.dart
wc -l lib/main.dart
```

Record the line ranges in the report. The arm is everything reachable only from
the `RUN_GPU_SPIKE` entry point plus the types above; the camera script, the
corpus builder (`spikeDocument()`) and the frame-timing log are **shared** with
the other arms and stay in `main.dart`.

- [ ] **Step 2: Capture the before-picture**

```bash
cd apps/dev_harness_2d && flutter test --concurrency=1 2>&1 | tail -5
```

Paste the count and exit code into the report. It must be identical after the
move.

- [ ] **Step 3: Move the arm**

Create `lib/gpu_arm.dart` with the moved declarations and the imports they
need. In `lib/main.dart`, delete them and add `import 'gpu_arm.dart';`.

Anything the arm needs from `main.dart` (the corpus builder, the camera script,
the timing log) is imported the other way, exactly as `widget_arm.dart` already
does — read that file first and match its import direction rather than
inventing one. If a private (`_`-prefixed) declaration in `main.dart` is needed
by the moved code, rename it without the underscore rather than duplicating it,
and say so in the report.

- [ ] **Step 4: Prove it is a move, not a rewrite**

```bash
cd /Users/ahmeturel/Projects/oss/jet-cad
git diff --stat
```

Insertions into `gpu_arm.dart` and deletions from `main.dart` should be within
a few lines of each other. A large asymmetry means something was rewritten;
report it explicitly if so, with what and why.

- [ ] **Step 5: Gate**

```bash
cd apps/dev_harness_2d && flutter test --concurrency=1 && flutter analyze && dart format --output=none --set-exit-if-changed .
echo "exit=$?"
cd ../../packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
echo "exit=$?"
```

- [ ] **Step 6: Commit**

```bash
git add apps/dev_harness_2d/lib/gpu_arm.dart apps/dev_harness_2d/lib/main.dart
git commit -m "refactor(harness): the GPU arm moves out of main.dart into its own file"
```

---

