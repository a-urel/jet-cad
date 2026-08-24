## Task 11: The harness, and the tile-size sweep

**Files:**
- Modify: `apps/dev_harness_2d/lib/main.dart`, `apps/dev_harness_2d/lib/measurement_rig.dart`

- [ ] **Step 1: Add the defines**

`TILES` (`off`/`on`) and `TILE_PX` (int, default `kTileDevicePixels`) and `TILE_BAKE` (int, default `kTilesBakedPerFrame`). All three follow `kBackend`'s rule: a `String.fromEnvironment` for the flag, and **throw on an unrecognised value rather than falling back**, because a run that silently took the control arm would publish the baseline twice and call one of them a measurement.

- [ ] **Step 2: Print the tile counters**

In `printInvariants`, add `tiles=`, `bakes=`, `blits=`, `carryOverBlits=`, `liveDraws=`, `evictions=` and `tileBytes=`. `report()` already prints `totalSpan` on `main` at `2218eab`; **criteria 10 and 11 read that column and not `rasterDuration`**, because Probe D rasterised 217,758 triangles per frame while `rasterDuration` read 0.87 ms.

- [ ] **Step 3: Run the sweep**

Machine state first, and it is not optional:

```sh
pmset -g | grep -i lowpowermode     # must read 0
pmset -g ps | head -2               # must read AC Power
```

Then, at `ENTITIES=500000`, `BACKEND=vertices`, `RIG=pan`, `TEXT=true`, for `TILE_PX` in {128, 256, 512} — **1024 is excluded before the sweep starts**: its 80.0 MiB visible set leaves no room under the 96 MiB cap for the 29.3 MiB carry-over.

Report **three** columns, not one:

| column | why it is not optional |
|---|---|
| blit cost per frame | what Probe D measured for a single viewport-sized blit (0.97 ms of raster) |
| **bake cost per tile** | criterion 11 is a pan frame, and a pan frame's cost is the strip it bakes |
| **measured overdraw factor** | `kScreenClipInflate` is 32 *logical* pixels, so a 128 px tile at `dpr` 2 culls against a 128×128 logical rect and bakes 4.00× its own area |

**Bake cost moves opposite to blit cost as the tile size changes.** A sweep reading blit cost alone would recommend the smallest tile and lose criterion 11.

- [ ] **Step 4: Decide, and record the decision**

Pick `kTileDevicePixels` from the table and write the three columns into the results note in Task 13. If the overdraw column justifies a tile-specific `kTileClipInflate`, name it there with the measurement behind it. **This plan does not guess that constant in advance.**

- [ ] **Step 5: Commit**

```sh
git add apps/dev_harness_2d/lib
git commit -m "feat: TILES, TILE_PX and TILE_BAKE, and the sweep reads three columns

Memory wants small tiles and bake cost wants large ones. kScreenClipInflate is
32 logical pixels and inflates whatever rect the painter culls against, so a
128 px tile at dpr 2 bakes four times its own area while costing the least
memory. A sweep that read blit cost alone would recommend it and lose criterion
11, whose cost is the strip a pan frame bakes.

The defines throw on an unrecognised value, as kBackend does: a run that
silently took the control arm would publish the baseline twice."
```

---

