# Slice 4, Task 3: the select tool's gates and the canvas's `autofocus` (independent review)

- **Commit reviewed:** `e8a21a0` (parent `86115fa`), branch `claude/exciting-pasteur-9m22jv`.
- **Where:** my own clones, `/home/user/review-s4t3` (gates, at `e8a21a0`) and `/home/user/review-s4t3-mut` (mutants, probes and the P-1 differential; checked out at `86115fa` for the base trace only, then back at `e8a21a0`). Both are deleted at the end of the review. Nothing was edited, committed or pushed in `/home/user/jet-cad`; this file is the only one written there.
- **Scratch:** `/tmp/claude-0/-home-user/428cafca-0083-5012-a7ac-5456349e70a8/scratchpad/rv-s4t3/`:
  - `rv_probe_test.dart`: probes RV-1 to RV-7, the killers for the seven survivors (R-1). They analyze clean and are formatted, ready to fold into `test/select_gates_test.dart`. They import that file's helpers as `sg`.
  - `rv_p1_trace_test.dart`, with `trace_base.txt` and `trace_head.txt`: the P-1 differential.
  - `mut.py`, `mut_results.txt` and `mut_R-m*.log`: my 20 mutants against the task's suite. `mut_probe.py`, `probe_results.txt` and `probe_R-m*.log`: the seven survivors against the probes.
  - `impl_mut.py`, `impl_results.txt` and `impl/`: the implementer's 23 mutants, re-applied in my clone.
  - `gates.sh`, `gates.out`, and the per-package `*.json`, `*.test.log`, `*.cmp.log`, `*.analyze.log` and `*.format.log`.
- **Environment:** Flutter 3.47.6 at `/root/sdk/flutter/bin`, `CI=true`.

## Verdict

**Approve once R-1 lands and R-2 is ruled. R-3 and R-4 are small and can go in the same fix commit.**

- **The library is right.** Every select-tool path reads its gate where the plan says. The pick override covers each place the tool picks. With no gates, every path is today's: a 476-line behavioural trace is byte-identical at `86115fa` and `e8a21a0`.
- **The frame path gains no allocation.** Every gate is a getter read once per frame or per hit test.
- **R-1 (tests).** 7 of my 20 mutants survive the task's suite, so their behaviour is unpinned. Two of them guard exactly what Task 5's `tablesOnly` relies on: a band dropping a refused instance (a chair) and the finger pick. The probes in scratch kill all seven, one each.
- **R-2 (seam).** The S-16 ruling gave the controller a `deleteSelection()` that deletes "exactly as the select tool's idle Delete does". The select tool's delete is private, Task 3 is the plan's only render edit, and Task 6's *Builds* do not mention the method. This needs a ruling before Task 4 starts.

## What I verified, and how

### 1. Scope and P-1

- **Files.** `git show --stat e8a21a0`: seven files, all in `packages/jet_cad_2d_flutter`.
  - **Edited:** the barrel (one `export 'src/select_gates.dart'`), `grip_cache.dart`, `interaction_layer.dart`, `select_tool.dart` and `selection_overlay.dart`.
  - **New:** `select_gates.dart` and `test/select_gates_test.dart`.
  - **Untouched:** no existing test, no `analysis_options.yaml`, no engine file and no planner file.
- **Signatures.** Each is additive:
  - `SelectTool({this.moveResolver, this.gates})`;
  - `GripCache(…, {this.objects, this.gates})`;
  - `InteractionLayer({…, this.autofocus = true})`.

  The new members are additive too: `gates`, `autofocus`, `moveGripsLive`, `stretchGripsLive` and `gatesChanged`. Nothing in the repository extends or implements `GripCache`, `SelectTool` or `InteractionLayer` (grep), so a new member breaks nobody. `SelectGates` is a new name. No package imports the render barrel next to a clashing `SelectGates` (grep).
- **No gates means today's behaviour, by reading.** With `gates == null`:
  - `_pick`, `_hoverAt` (`?? true`), the `_beginDrag` pre-switch and the up's re-read all yield `true`. The pre-switch has no side effect, and `_pressRef!` is non-null whenever `_class == grip`: `_classify` and `_reset` set the two together.
  - `_bandKeys` returns the same list. Every key branch is guarded by `g != null`.
  - `hitTest` is unchanged apart from the rename of `g` to `grip`. `rotatable` reads `?? true`.
  - In the overlay, `moveLive` and `stretchLive` equal `leafGripsLive`. That is true inside the `if`, so the `continue` and the hot-role clause never fire.
  - `Focus(autofocus: widget.autofocus)` defaults to true.
- **No gates means today's behaviour, by differential.** `rv_p1_trace_test.dart` drives one script through a default `GripRig` (`SelectTool()`, no gates) under a rotated, non-uniform camera. The script runs:
  - mouse hovers and presses, and finger presses (touch kind, 24 px reach, so the 14t grip and rotation-grip arbitration runs), each followed by a drag and a click, at 10 points (line body, line end, arc centre, circle centre and quadrant, both instances, group, empty, line end 2) under 4 selections;
  - for each selection that has one, the rotation grip: hover, drag and Escape, then a drag that commits;
  - window and crossing bands;
  - idle Escape, Delete and Backspace, and Delete and Escape while pressed.

  Each step records the phase, press class, drag kind, cursor, hot grip, hover, selection, undo depth, `rotatable`, a hash of the codec encoding, and every overlay canvas call with its arguments and colour. The trace is 476 lines with 6 reshape, 60 move, 6 rotate and 16 band drag steps, 20 grip presses and 20 hot-grip states. It is **byte-identical** at `86115fa` and `e8a21a0` (`cmp`).
- **Existing suites unedited and green.** All of the plan's *Unedited and green* list passed in the full runs below. Among them: `select_tool_test` (21), `select_tool_drag_test` (29), `select_tool_touch_test` (5), `interaction_layer_touch_test` (20) and `selection_overlay_grips_test` (11), all successes in my render JSON.

### 2. Each gate, on every select-tool path

| Path | Where | Gate read | Verdict |
|---|---|---|---|
| Body drag (selected or not; wall attach rides it) | `_beginDrag` pre-switch | `move`, at the slop; the press stays a click (`_clickOnly`) | correct |
| Centre grip | `_beginDrag`: `GripRole.move` → `DragKind.move` | `move` (S-9a) | correct. Only a circle and an arc have one (`leafGrips`, `grips.dart:77, :95`); every planner object provider gives `stretch` grips only (grep `Grip(GripRole` in `jet_cad_floor_plan/lib`) |
| Stretch, radius and object grips | same | `reshape` | correct |
| Rotation grip | same, plus `rotatable` | `rotate`: the cache hides and un-hits it, and the tool refuses it | correct; the finger path reads it through `rotationGripDistance` → `rotatable` |
| The up (S-9h) | `onPointerUp`, dragging, not a band | `_gateOpen(_dragKind)`; a closed gate means `cancel`, no command, the selection change kept | correct; a centre grip's `_dragKind` is `move`, so it re-reads `move` (pinned only by RV-1, see R-1) |
| Band, window and crossing | `_bandKeys`, at release | `bandAccepts` per key, after the instances join | correct; the band itself has no edit gate (right: selecting is no edit; pinned only by RV-7) |
| Idle Escape | `onKey` | `idleKeys` | correct; Escape while pressed stays `handled` (finding 3) |
| Idle Delete and Backspace | `onKey` | `idleKeys && delete` | correct |
| Keys during a gesture | `onKey`'s first two branches | none (S-16) | unchanged |
| Pick: press, hover and cursor | `_pick` ← `_classify` (mouse and finger) and `_hoverAt`; the move cursor derives from the hover's key | `restrictsPick` then `pick(e, ctx)` | complete: `SelectTool` has no double-click or other pick (grep `pickInto` and `DoubleTap`); the event carries `isTouch` and `reachRadiusWorld` for S-15's finger reach |
| Grip hover, hot grip and cursor | `_hoverAt` → `hitTest` / `hitsRotationGrip` | through the cache's gates | correct with the shell's wiring (one object on both; `planner_shell.dart:339, :541` build both, so Task 5 can) |
| A gate closing mid-hover | overlay: a hot grip drawn only while its role is live; `gatesChanged()` resets `hot` and repaints | per frame | correct; the tool's cursor stays stale until the next move (R-4) |
| Touch hold-back | `touchPress` is still `press`; the gates sit downstream of the routed down | — | unchanged (trace above) |

### 3. Frame path

- **The overlay** reads `moveGripsLive` and `stretchGripsLive` once per frame:
  - Each is `leafGripsLive` (`DraftPermissions.allows`, a `switch` over `bool` fields) plus one virtual getter. There is no allocation per entity or per frame.
  - A closed role's points are skipped and its buffer is not reallocated. The buffers are still sized by role count, as before. `drawRawPoints` keeps its `s > 0` and `mv > 0` guards, so a closed role never draws a stale buffer (my R-m16 is red).
- **`hitTest`** reads the gates once per call, at gesture rate.
- **`_bandKeys`** allocates its filtered list once per band, at release, and only with gates.
- **The allocation invariants** were green: `paint_allocation_test` (3/3 in the render run) and `query_allocation_test` (6/6 in the engine run). Neither exercises the selection overlay. The overlay's reuse is pinned by `selection_overlay_grips_test:185` (green, unedited), by T3-j for the stretch role, and by RV-2 for the centre role (R-1).
- **`SelectGates`' doc** requires host getters to be cheap and allocation-free. That is right, because the overlay calls them per frame.

### 4. Gates (rerun by me, real counts)

| Package | Tests through the standing comparison | Analyze | Format |
|---|---|---|---|
| `packages/jet_cad_2d_flutter` | 1405: 1397 passed, 7 errors (the 7 standing text-ladder goldens), 1 skip; "the standing failures and skips, exactly" | No issues | 0 changed |
| `packages/jet_cad_2d_gpu` | 20 passed; exactly | No issues | 0 changed |
| `packages/jet_cad_floor_plan` (`--enable-vmservice`) | 1742 passed, none skipped (PA1 to PA3 ran and passed); exactly | No issues | 0 changed (267 files) |
| `apps/restaurant_demo` | 60 passed; exactly | No issues | 0 changed |
| `apps/floor_planner` | 212 passed; exactly | No issues | 0 changed |
| `packages/jet_cad_2d` | 1258: 1256 passed, 2 failures (the 2 standing); exactly | `--fatal-infos`: no issues | 0 changed |

These match the report's counts. The new suite has **15** tests, not 16 (R-3).

### 5. Mutants

**The implementer's 23**, re-applied in my clone with the report's own patterns. Each is red under its named killer (`--plain-name`), and each failure is the expected assertion, spot-checked (T3-a: a larger set; T3-h: undo 1, expected 0; T3-j1: `identical` false; T3-c1: `dragKind` true, expected false):
T3-a; T3-b1 and T3-b2; T3-c1 to T3-c5; T3-d1 and T3-d2; T3-e1 to T3-e4; T3-f; T3-g1 and T3-g2; T3-h; T3-i; T3-j1 and T3-j2; P-1; P-2.

**Mine (20)**, each run against the full `test/select_gates_test.dart`. Each file was restored and checked with `cmp`, and the clone was clean afterwards.

| # | Mutant | Task suite | Killed by probe |
|---|---|---|---|
| R-m1 | the up's re-read reads `reshape` for any grip press, so a centre-grip move whose `move` closed commits | **survived** | RV-1 |
| R-m2 | a closed move role's buffer reallocated each frame | **survived** | RV-2 |
| R-m3 | `hitTest` reads `move` for the stretch role | red (T3-e, gate change) | |
| R-m4 | `rotatable` reads `move` | red (T3-d) | |
| R-m5 | band filter applied to the window band only | red (T3-a) | |
| R-m6 | idle Escape reads `delete` | red (T3-g) | |
| R-m7 | S-9h for a reshape only | red (T3-h) | |
| R-m8 | the pick override skipped for a finger | **survived** | RV-3 |
| R-m9 | `gatesChanged` does not notify | red | |
| R-m10 | a hot centre grip drawn under `move: false` | **survived** | RV-6 |
| R-m11 | a closed gate turns the press into a band, not a click | red (T3-c) | |
| R-m12 | a finger's (24 px) grip hit test ignores the gates | **survived** | RV-4 |
| R-m13 | the move cursor reads `rotate` | red (T3-c) | |
| R-m14 | the band filter skips the instance keys | **survived** | RV-5 |
| R-m15 | Delete needs `idleKeys \|\| delete` | red (T3-f, T3-g) | |
| R-m16 | a closed stretch role still draws its stale buffer (`s >= 0`) | red (T3-e, T3-j) | |
| R-m17 | `restrictsPick` captured at the first pick | red (T3-b) | |
| R-m18 | the overlay's two role gates swapped | red | |
| R-m19 | `autofocus` forced true | red (T3-i) | |
| R-m20 | a band refused at release under `move: false` (no band in `readOnly`) | **survived** | RV-7 |

**Result:** 13 red and 7 survived. In `rv_probe_test.dart`, all seven probes pass on `e8a21a0`, and each survivor is red under exactly the probe named (`probe_results.txt`, `probe_R-m*.log`).

## Findings

### R-1 (medium): seven gate behaviours are unpinned; two of them are Task 5's `tablesOnly`

The code is right in all seven cases; the task's suite does not hold them:

- **R-m14:** T3-a's gate accepts the instances only, so a band that never asks `bandAccepts` about an instance still passes. Under Task 5's `selectTablesOnly`, a chair is an instance the gate must refuse.
- **R-m8 and R-m12:** every T3 test is a mouse test. S-15 needs the override and the gated grip hit test on a finger's press and hover, with its 24 px reach.
- **R-m1:** T3-h re-reads the gate for a body, an end grip and the rotation grip, never for the centre grip. The centre grip is the one press whose gate (`move`) differs from its press class (`grip`).
- **R-m2 and R-m10:** T3-j and T3-e cover the stretch role only. Nothing covers the centre role's buffer or its hot grip.
- **R-m20:** no test runs a band under closed edit gates. `readOnly` must still select by band.

**Fix:** fold RV-1 to RV-7 from `rv_probe_test.dart` (scratch) into `test/select_gates_test.dart`, or equivalents that hold the same seven mutants red. They use the file's own helpers (`TestGates`, `gatedRig`, `rawPoints`) and a `finger()` event builder with `PointerDeviceKind.touch` and a 24 px reach. Each is red under its mutant and green on `e8a21a0`.

### R-2 (medium; a plan gap, for the controller): no seam for S-16's `deleteSelection()`

- **What the ruling and the spec say.** The S-16 ruling (plan, *Spec points to settle*) and spec C-3 (`:701-705`) give the controller `bool deleteSelection()`. It deletes the editor's selection "exactly as the select tool's idle Delete does (one undo step, the same compound, the table-data expander)" and assigns it to Task 6 with killers.
- **Why nothing can call it.** The delete is `SelectTool._deleteSelection`: private, about 120 lines of group, instance and fill cascade plus a permission preflight. Only Task 3 may edit `jet_cad_2d_flutter` (Global constraints). Task 3 adds no public entry, and Task 6's *Builds* do not mention `deleteSelection` at all.
- **The workarounds Task 6 would face.** Either:
  - copy the cascade into the planner, which risks drift from "exactly"; or
  - flip a shell-gates flag open and feed `_select.onKey` a synthetic Delete `KeyDownEvent`. This works, because the gates are read live, but it is a hack: `onKey` answers `handled` even when every key was refused, so `true`/`false` would have to be inferred from the undo depth.

**Fix (recommended):** a small additive render seam in this task's fix commit, before Task 4 starts:

```dart
/// Deletes the selection as the idle Delete key does: one command, or none.
/// Idle only; not gated by `idleKeys` (a command is not a key), gated by `delete`.
/// Answers whether a command was executed.
bool deleteSelection(ToolContext ctx)
```

- **Wiring:** `onKey`'s idle Delete and Backspace call it.
- **Killers:**
  - under `idleKeys: false` the key deletes nothing while `deleteSelection(ctx)` deletes one compound, and one undo restores the codec encoding;
  - under `delete: false` it answers false and leaves the document unchanged;
  - mid-press and mid-drag it answers false.
- **Task 6:** its *Builds* gains the controller method over it.

If the controller prefers to keep the render package closed, rule the alternative explicitly in Task 6's brief instead.

### R-3 (low): the report miscounts the new tests

The report says `test/select_gates_test.dart` has "16 tests" and that "the 16 new tests" passed. The file has 13 `test`s and one `testWidgets` run twice, so **15**:
- the file run ends `+15: All tests passed!`;
- my render JSON holds 15 tests from that suite.

**Fix:** correct the report.

### R-4 (low; doc, for Task 5)

1. **`SelectGates.pick`** says it "answers the whole pick" but not that this includes a finger's reach. **Fix:** add one sentence: for a touch (`e.isTouch`) it answers within `e.reachRadiusWorld` when the precise radius misses, as the tool's own pick does (spec 14t R-3).
2. **Two separate parameters.** `SelectTool.gates` and `GripCache.gates` are independent. With only the tool gated, the cache still draws and hits a closed role's grips, shows the `precise` or `grab` cursor and sets the hot grip; only the drag is refused. **Fix:** in both docs, say that a host passes the same object to both (finding 4).
3. **A stale cursor.** `gatesChanged()` repaints the overlay, but the tool's cursor is not recomputed until the next pointer move: `precise` over a now-hidden grip, `move` over a body under a now-closed `move`, `grab` over a hidden rotation grip. This is cosmetic. **Fix:** document it on `gatesChanged`. Task 5 may accept it.

### Note (no change asked): T3-e's wording

The plan's T3-e killer says a drag from a hidden end grip "is a band or a click, never a reshape". With the shell's wiring, the press falls through to the line's body, which is selected, so under `move: true` it is a **move**. The test asserts "never a reshape" and the report says so. This is right: the grip is not there; the body under it is. Under `full.copyWith(reshape: false)` in Task 5, a press on a wall's end moves the wall. **Ruled acceptable;** the plan's wording should read "a band, a click or a body move".

## Rulings on the implementer's findings

1. **"A line has no centre grip": confirmed.**
   - `leafGrips` (`jet_cad_2d` `grips.dart:59-108`) gives a line and a polyline stretch grips only. Only a circle and an arc have a `GripRole.move` grip, and no planner object provider gives one.
   - The killer's use of the positive arc's centre (7050, 3200), off its body, is correct. The plan's T3-c should read "an arc's centre grip".
2. **"S-9h masks the slop gates in a command-only check": confirmed, and handled correctly.**
   - Asserting `dragKind` after the slop and before the up is necessary, not optional.
   - T3-c4 and T3-d2 are red in my re-run only because of it.
   - The same masking is why R-m1 needs a killer that closes the gate *after* the slop (RV-1).
3. **"Pressed-phase Escape": confirmed and accepted.**
   - `onKey` gates only an idle Escape. A press held inside the slop still answers `handled` and does nothing, as at `86115fa` (my trace records `pressed esc handled` and `pressed del ignored` at both commits).
   - It is a gesture's key under S-16.
4. **"Two independent gates objects": confirmed and accepted.**
   - Both are built in `planner_shell.dart` (`:339` `_select`, `:541` `_grips`), so Task 5 can pass one object.
   - Doc fix in R-4.2. Task 5's brief should name it.
5. **"`gatesChanged()` is needed for a repaint": confirmed and accepted.**
   - The overlay reads the gates per frame but repaints only on a notification.
   - Task 5's runtime capability change must call `grips.gatesChanged()`.
   - It does not refresh the tool's cursor (R-4.3).

## Does the seam serve Tasks 4 to 6?

- **Task 5:** yes. The plan's internal `SelectGates` subclass:
  - reads `widget.capabilities` live;
  - is a `pick` over the `TablePicker`, with the finger reach from `e`;
  - answers `bandAccepts` with the table check;
  - maps the flags straight onto `move`, `rotate`, `reshape` and `delete`.

  Every one of those maps onto a member here. `gatesChanged()` covers the runtime change.
- **Task 6:** yes for `idleKeys` (`shortcuts: false`) and `InteractionLayer.autofocus` (through `PlannerView.autofocus`); not yet for `deleteSelection()` (R-2).
- **Task 4:** touches no render seam.
