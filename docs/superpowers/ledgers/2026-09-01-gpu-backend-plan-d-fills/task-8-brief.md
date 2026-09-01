### Task 8: Mutation testing

**Files:**
- Create: `docs/superpowers/notes/plan-d-mutation-log.md`

**Every mutation is fired, one at a time, from a `cp` backup, and restored
from that backup.** Never `git checkout --`.

| id | mutation | must fire |
|---|---|---|
| M-D1 | `fillPolygon` writes `_coveredArgb(style.argb, ...)` instead of `style.argb` | `geometry_collector_test.dart` — *a fill keeps its own colour on a hairline layer* |
| M-D2 | `fillCircle` writes `_coveredArgb(...)` | the same, extended to the fan |
| M-D3 | the shader's fill branch reads `half_width` (expand each corner outward) | `instance_expander_test.dart` — *a fill is not expanded by a half-width* |
| M-D4 | the fill branch folds `M` onto `p2` instead of `p1` | *one degenerate triangle* — the second triangle gains area |
| M-D5 | the point branch stays `else` and the fill branch is added before it | *a point is still a point* |
| M-D6 | `fillCircle` fans at `_flattenSteps(deviceRadius, theta) + 1` | *the same step count as its own outline* |
| M-D7 | `fillPolygon` walks the triangulation backwards | *in triangulation order* |
| M-D8 | `fillPolygon` drops zero-area triangles | *a degenerate triangle is written, not dropped* |
| M-D9 | the collector sorts the buffer by kind before `data` returns | `fill_order_test.dart` — *matches the reference in walk order and only there* |
| M-D10 | `writeFill` leaves `dashPeriod` unwritten | `instance_record_test.dart` — the garbage pre-fill survives |
| M-D11 | `writeFill` writes `halfWidth: 1` | *a fill record carries three corners, no width* |
| M-D12 | `fillCircle`'s fan starts at angle `2π/steps` rather than 0 | *the fan walks the rim in ascending angle* |

- [ ] **Step 1: Fire each mutation and record what died**

For each row:

```sh
cd packages/jet_cad_2d_flutter
cp lib/src/gpu/geometry_collector.dart /tmp/plan-d-backup.dart
# edit, then:
flutter test 2>&1 | tail -20
cp /tmp/plan-d-backup.dart lib/src/gpu/geometry_collector.dart
```

Paste the **actual failure line** for each — the test name and the
`Expected:`/`Actual:` pair — into the log. A mutation that does not fire is
recorded as a survivor with an explanation, not quietly dropped, and a
survivor that reveals a missing test gets the test written in this task.

- [ ] **Step 2: Write the log**

`docs/superpowers/notes/plan-d-mutation-log.md`, one section per mutation:
the diff applied, the command run, the output pasted verbatim, the verdict.

- [ ] **Step 3: Commit**

```sh
git add docs/superpowers/notes/plan-d-mutation-log.md
git commit -m "docs: Plan D's mutation log"
```

---

