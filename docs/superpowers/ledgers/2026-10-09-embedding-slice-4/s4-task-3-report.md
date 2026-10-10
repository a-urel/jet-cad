# Slice 4, Task 3: the select tool's gates and the canvas's `autofocus` (implementer's report)

- **Branch:** `claude/exciting-pasteur-9m22jv`, from `86115fa` (Task 2).
- **Commit:** `e8a21a0`. Pushed as `86115fa..e8a21a0`.
- **Environment:** Flutter 3.47.6 at `/root/sdk/flutter/bin`, `CI=true`. Scratch files, the mutant runner and its logs are in `/tmp/claude-0/-home-user/428cafca-0083-5012-a7ac-5456349e70a8/scratchpad/s4t3-impl/`:
  - `mut.py`, the runner, and `mut_*.log`, one log per mutant;
  - `gates.sh` and `gates.out`, the gate run, with the per-package `*.json`, `*.test.log`, `*.cmp.log`, `*.analyze.log` and `*.format.log`.
- **`analysis_options.yaml`:** none touched or committed. Before the commit, `git status` showed only the seven task files. After it, the tree was clean.
- **Scope:** `jet_cad_2d_flutter` only. Nothing of Tasks 4 to 7. The engine is not edited. No existing test, fixture, golden, counter or allocation test is edited.

## Files

| File | What |
|---|---|
| `lib/src/select_gates.dart` (new, exported by the barrel) | `class SelectGates` with a `const` constructor and `static const all`. Every member allows by default:<br>- `restrictsPick` (false), and `pick(ToolPointerEvent, ToolContext)` (null). With `restrictsPick`, `pick` is the tool's whole pick for presses and hovers (S-15).<br>- `bandAccepts(DraftDocument, SelectionKey)` (true).<br>- `move`, `rotate`, `reshape`, `delete`, `idleKeys` (true).<br>The class is non-final so an application overrides it. It is documented as read live, never captured. |
| `lib/src/select_tool.dart` | `SelectTool({this.moveResolver, this.gates})`:<br>- `_pick` defers to `gates.pick` while `restrictsPick`. Presses (including touch) and hovers go through `_pick`.<br>- The move cursor also needs `move`.<br>- `_beginDrag` checks the gate first. A body or move-role grip drag needs `move`, another grip `reshape`, the rotation grip `rotate`. A closed gate sets `_clickOnly`, the same path as a refused permission.<br>- **At the up**, the drag's gate (from `_dragKind`) is read again. A closed gate means `cancel(ctx)` and no command (S-9h). A selection change made at the drag's start stands, as with Escape.<br>- `_bandKeys` keeps only the keys `bandAccepts` accepts, asked once per band at release.<br>- Idle Escape is `ignored` without `idleKeys`. Idle Delete and Backspace are `ignored` without `idleKeys && delete`.<br>- A drag's keys are unchanged. Escape in the pressed phase (not idle) is unchanged.<br>With `gates == null`, every branch is today's. |
| `lib/src/grip_cache.dart` | `GripCache(…, {this.objects, this.gates})`:<br>- `hitTest` skips a grip whose role's gate is closed (`move` for `GripRole.move`, `reshape` for the others). The gates are read once per call.<br>- `rotatable` also needs `rotate`.<br>- New getters `moveGripsLive` and `stretchGripsLive` (each is `leafGripsLive` plus its gate).<br>- `gatesChanged()` resets `hot` and notifies. It rebuilds nothing; the grip list stays listed. |
| `lib/src/selection_overlay.dart` | `_paintGrips` reads `moveGripsLive` and `stretchGripsLive` once per frame. A closed role's points are neither projected nor drawn. Its buffer is still sized by the role's count, so toggling the gate reallocates nothing. The hot grip is drawn only while its role is live. |
| `lib/src/interaction_layer.dart` | `InteractionLayer({…, this.autofocus = true})`, passed to its `Focus`. The pointer-down focus requests are unchanged. |
| `test/select_gates_test.dart` (new, 16 tests) | Described below. |

## Tests

**Setup.** The tests use `test/select_gates_test.dart`, built on `support/grip_fixture.dart`'s `gripScene()` with the selection fixture's helpers:
- The scene has a line, two arcs, a rotated root group and two turned instances, near x = 7000, y = 3000.
- The camera is `skewCamera()`, the rotated, non-uniform camera of `selection_overlay_test.dart:413`: rotation 0.3 rad, scale 1.5 / −3.6, panned. It asserts `|b − c| > 0.5`.
- `TestGates` has mutable fields.
- A local `GatedRig` copies `GripRig`'s wiring, with separate gates for the tool and the cache. The existing fixture is not edited, because `GripRig` builds its own `SelectTool()`.
- Gate killers run under two wirings: **both** (the shell's, one object on the tool and the cache) and **toolOnly** (the tool's own gate, with an ungated cache that still offers the grip).

**Plain tests:**
- **The barrel exports `SelectGates`, and `all` is every gate open.**
- **`SelectGates.all` and no gates, byte for byte.** One run each, on fresh scenes. The run covers a window band, a body move, a centre-grip move, a reshape, a rotate, Escape and Delete. The output compares undo depth, the selection and the `DraftDocumentCodec` encoding after each step; there are 5 commands, so the run is not vacuous.
- **A gate change is read at the next press and hit test, with nothing rebuilt or notified.** It checks `reshape` through `hitTest` and `move` through a body drag. It counts the grip cache's notifications: 0.
- **`gatesChanged`** resets `hot`, notifies once, and leaves `grips` the same list.

**T3-a to T3-j:**
- **T3-a.** Window and crossing bands over the whole scene, with a gate that accepts the instances only, select exactly the two instance keys. With every gate open, the band covers the line, the arc, the group and both instances.
- **T3-b.** The control: the topmost hit is the line, for both a hover and a click. With an override answering instance B, the hover sets B and the press selects B. With an override answering null, the press selects nothing and the hover sets nothing.
- **T3-c.** Under `move: false`:
  - the arc's centre grip is not hit and not drawn (no `gripMove` points), while its stretch grips stay;
  - a centre-grip drag starts no move, and nothing is executed;
  - a body hover shows no move cursor;
  - a body drag stays a click, and the document is byte-identical.

  Under `move: true`, both drags move it, in both wirings. `dragKind` is checked before the up, because the up's re-read would otherwise hide a drag that started (Finding 2).
- **T3-d.** Under `rotate: false` there is no `drawCircle` and `rotatable` is false. The press class is not `rotationGrip`, the drag does not start a rotate (checked before the up) and nothing is executed. Both wirings are run, with `rotate: true` as the control.
- **T3-e.** Under `reshape: false`:
  - there are no `drawRawPoints` in the stretch colour, and the arc's centre grip is still drawn under `move`;
  - a hot stretch grip is not drawn;
  - `hitTest` at the line's end is -1;
  - a drag from the end is never `DragKind.reshape`, and the line's length is unchanged. It is a move in the both wiring and a click in the toolOnly one.
- **T3-f.** Under `delete: false`, Delete and Backspace each return `ignored` and remove nothing (the line and instance A survive). Under `delete: true` both are removed.
- **T3-g.** Under `idleKeys: false`, a drag's Escape is `handled` and cancels the drag. Idle Escape and Delete are `ignored`, and the selection and the document are kept. The control is `idleKeys: true`.
- **T3-h.** For each of move (body), reshape (end grip) and rotate, the gate is open at the slop and closed before the up. The result is no command, the codec encoding equal, the tool idle and the selection kept. When the gate stays open, there is one command.
- **T3-i.** A `MaterialApp` with a `Column` holding the `InteractionLayer` first and a `TextField(autofocus: true)` second, built in that order:
  - with `autofocus: true` the layer has the primary focus (the control that pins the layout as able to go red);
  - with `false` the field has it;
  - in both, a tap on the layer takes the focus, because the pointer-down request is unchanged.
- **T3-j.** One painter is used for five frames, toggling `reshape` false/true/false/true and panning the camera each frame:
  - every open frame draws the **same** `Float32List` object, filled with the current camera's projection;
  - a closed frame draws no stretch points, but still draws the centre grip;
  - after the first closed frame the buffer still holds the last open frame's points, so it was not filled.

  `selection_overlay_grips_test.dart:185` and `paint_allocation_test` are untouched.

## Mutants

Each mutant was applied by `mut.py`, its killer was run (`--plain-name`) and seen red, and the file was restored from a copy and checked equal with `cmp`. The killer is named by its test-name tag.

| Mutant | Applied as | Killer | Seen red at |
|---|---|---|---|
| **T3-a** | `bandAccepts(...) \|\| true` | T3-a | expected `{instA, instB}`, got every key |
| **T3-b** (presses only) | override only when `_phase != idle` | T3-b | "the hover" |
| **T3-b** (hovers only) | override only when `_phase == idle` | T3-b | "the press" |
| **T3-c** (tool: centre grip reads `reshape`) | grip gate always `DragKind.reshape` | T3-c | "toolOnly, move false: the centre grip starts a move" |
| T3-c (cache: centre grip hit regardless) | `hitTest` move role → `true` | T3-c | "the centre grip is hit only under move" |
| T3-c (overlay draws a closed centre role) | `moveLive = leafGripsLive` | T3-c | "the centre grip is drawn only under move" |
| T3-c (tool: body drag ignores `move`) | body gate → `true` | T3-c | the body's `dragKind`: expected null, got `move` |
| T3-c (move cursor ignores `move`) | the `gates?.move` clause removed | T3-c | "both, move false: the move cursor" |
| **T3-d** (`rotatable` ignores `rotate`) | the clause removed | T3-d | "the disc": 1 `drawCircle`, expected 0 |
| T3-d (tool: rotation grip ignores `rotate`) | rotation gate → `true` | T3-d | "toolOnly, rotate false: the drag kind" |
| **T3-e** (overlay draws stretch) | `stretchLive = leafGripsLive` | T3-e | "the stretch grips": 1 call, expected 0 |
| T3-e (cache hits stretch) | `hitTest` `stretchLive = … \|\| true` | T3-e | "the end grip is hit only under reshape" |
| T3-e (tool: grip gate always `move`) | grip gate → `DragKind.move` | T3-e | "toolOnly, reshape false: the drag kind" |
| T3-e (hot grip of a closed role drawn) | hot-role clause → `true` | T3-e | "the hot stretch grip" |
| **T3-f** | Delete needs `idleKeys` only | T3-f | "delete false, backspace false": `handled`, expected `ignored` |
| **T3-g** (Escape) | the idle Escape gate removed | T3-g | Escape: `handled`, expected `ignored` |
| T3-g (Delete) | Delete needs `delete` only | T3-g | Delete: `handled`, expected `ignored` |
| **T3-h** | the up's re-read removed (`if (_dragKind == null)`) | T3-h | "DragKind.move, closed true": one command |
| **T3-i** | `autofocus: true` hard-coded | T3-i (`autofocus: false`) | `field.hasPrimaryFocus` false |
| **T3-j** (reallocated) | the buffer is reallocated while the role is closed | T3-j | "frame 1: the same buffer, not a new one" |
| T3-j (filled) | the closed role is projected, drawn only while live | T3-j | "a closed role is not projected …" |
| P-1 (the default `move` is false) | `SelectGates.move => false` | "SelectGates.all and no gates are byte for byte …" | 3 commands, expected 5 |
| P-2 (`gatesChanged` keeps `hot`) | the `hot = -1` line removed | "gatesChanged resets the hot grip …" | `hot`: expected -1, got 1 |

The first round of `mut.py` had three mistakes. None is in the table above:
- The first form of T3-a did not compile; it is now `bandAccepts(...) || true`.
- Two patterns were stale after formatting and did not apply (T3-c tool, T3-e tool).
- P-2 had no killer yet, so I added the `gatesChanged` test.

The runner now reports a compile error as such, and every row above was re-run.

## Gates (all run after the last edit, through `gates.sh`)

| Package | Test (standing comparison) | Analyze | Format |
|---|---|---|---|
| `packages/jet_cad_2d_flutter` | 1405 tests; "the standing failures and skips, exactly" (the runner exits 1 on the 7 standing text-ladder goldens, as on base) | No issues | 0 changed |
| `packages/jet_cad_2d_gpu` | 20 tests; exactly | No issues | 0 changed |
| `packages/jet_cad_floor_plan` (`--enable-vmservice`) | 1742 tests; exactly (PA1 to PA3 ran and passed, none skipped) | No issues | 0 changed |
| `apps/restaurant_demo` | 60 tests; exactly | No issues | 0 changed |
| `apps/floor_planner` | 212 tests; exactly | No issues | 0 changed |
| `packages/jet_cad_2d` | 1258 tests; exactly (the 2 standing failures) | `--fatal-infos`: no issues | 0 changed |

These passed in the JSON runs: `paint_allocation_test` (O(1) per flush), `query_allocation_test` (every steady-state case), `pick_allocation_test` PA1 to PA3, and the 16 new tests. The plan's unedited list ran green in the full suites, unedited:
- render: `select_tool*`, `grip_cache_test`, `grip_drag_test`, `object_grips_test`, `selection_overlay*`, `selection_theme_test`, `interaction_*`, `input_claim_test`, `tool_controller_test`, `draw/*`, `invariants/*` and `golden/*`;
- planner: `*_grips_test`, `symbols/*`, `touch_tools_test` and `layers/*`.

## Findings

1. **A line has no centre grip.** `leafGrips` gives a line and a polyline stretch grips only; only a circle and an arc have a `GripRole.move` grip. The plan's T3-c killer says "a drag of a line's centre grip". The killer uses the positive arc's centre grip (7050, 3200), off its body, and the line for the body drag.
2. **The up's re-read (S-9h) masks the slop gates in a command-only check.** A mutant that lets a body drag (or the rotation grip) start under a closed gate still executes nothing, because the up re-reads the same gate and cancels. My first T3-c and T3-d killers asserted only the command and the document, and these two mutants survived them. The killers now also assert `dragKind` after the slop and before the up, and both mutants are red. A reviewer holding killers to these mutants should expect that check.
3. **Pressed-phase Escape.** `idleKeys` gates only an idle Escape. An Escape while a press is held inside the slop is still `handled` without acting, as today. It is part of a gesture (S-16's "a gesture's own keys stay").
4. **Two independent gates objects.** `SelectTool.gates` and `GripCache.gates` are separate parameters, as the plan builds them. Task 5 must pass the same object to both, as the "both" wiring does. With only the tool gated, the cache still draws and hits a closed role's grips; the tool turns the press into a click.
5. **`gatesChanged()` is needed for a repaint.** The overlay reads the gates per frame, but a runtime gate change repaints only at the next notifying event. Task 5's runtime capability change should call `grips.gatesChanged()` (cheap: no rebuild).

## Fixes

- **Commit:** `ac485fd` (on `5c72a5e`), `fix(render): SelectTool.deleteSelection and the gates' killers (Slice 4, Task 3 review)`. Scratch: `/tmp/claude-0/-home-user/428cafca-0083-5012-a7ac-5456349e70a8/scratchpad/s4-fix123/t3/` (`mut.py`, `results.txt`, `mut_*.log`, `pristine/`).
- **Files:** `lib/src/select_tool.dart`, `lib/src/select_gates.dart`, `lib/src/grip_cache.dart`, `test/select_gates_test.dart` (the task's own file, extended), and the plan. No existing test edited; no `analysis_options.yaml`.

### R-1: the seven probes, folded

RV-1 to RV-7 are in `test/select_gates_test.dart` with the file's own helpers (`TestGates`, `gatedRig`, `rawPoints`) and a `finger()` event builder (`PointerDeviceKind.touch`, a 24 px reach). Each of the review's survivors was re-applied with the review's own pattern (`mut.py`, adapted from `rv-s4t3/mut_probe.py`), the whole file run, and the source restored and checked with `cmp`:

| Mutant | Red in |
|---|---|
| R-m1 (the up re-reads `reshape` for any grip press) | RV-1 (`Expected: <0>`) |
| R-m2 (a closed move role's buffer reallocated) | RV-2 |
| R-m8 (the pick override skipped for a finger) | RV-3 |
| R-m10 (a hot centre grip drawn under `move: false`) | RV-6 |
| R-m12 (a finger's grip hit test ignores the gates) | RV-4 (`Expected: <-1>`) |
| R-m14 (the band filter skips the instance keys) | RV-5 |
| R-m20 (a band refused under a closed `move`) | RV-7 |

### R-2: `SelectTool.deleteSelection`, as recommended

- `bool deleteSelection(ToolContext ctx)`: acts only while idle; gated by `gates.delete`, not by `idleKeys`; answers whether a command ran (`_deleteSelection` now answers it: false when nothing was executed, that is nothing selected or every key refused).
- The idle Delete and Backspace keep their own gate (`idleKeys && delete`) and then call `deleteSelection`, still answering `handled`. The key's behaviour is unchanged: every existing render test passed unedited.
- Killers (new): **D-1** the call and the key give the same encoding, selection and one undo step, and an undo of each gives the same document; **D-2** under `idleKeys: false` the key is `ignored` and deletes nothing while the call deletes one compound that one undo restores byte for byte, and under `delete: false` the call answers false with the document unchanged; **D-3** false mid-press, mid-drag (the drag goes on) and with nothing selected, true once idle again.

| Mutant | Red in |
|---|---|
| D-m1 the call without its idle check | D-3 |
| D-m2 the call ignores `delete` | D-2 |
| D-m3 the call also needs `idleKeys` | D-2 |
| D-m4 answers true when nothing was executed | D-3 |
| D-m5 answers false after a delete | D-1, D-2, D-3 |

- **Finding (engine, not changed):** an undo of a compound delete that removed several root nodes restores them in the reverse order of the root's children (`children: [30, 29, 25]` after the undo, `[25, 29, 30]` before), so the codec encoding differs after a delete of a group and instances and its undo; draw order is by handle, so nothing visible changes. D-1 therefore compares the call's undo with the key's undo, and D-2's byte-for-byte undo check uses two leaves. The key's path gives the same document (D-1 compares the two undos); the engine is not edited by this slice.

### R-3

The new suite had 15 tests (13 `test`s and one `testWidgets` run twice), not 16. It now has **25** (`00:01 +25: All tests passed!`).

### R-4: the docs

- `SelectGates.pick`: it answers a finger's reach too (`e.reachRadiusWorld` when the precise radius misses, spec 14t R-3).
- `SelectTool.gates` and `GripCache.gates`: a host passes the same object to both; with only the tool gated the cache still draws and hits a closed role's grips.
- `GripCache.gatesChanged`: the tool's cursor stays stale until the next pointer move.
- `SelectGates.delete` names `SelectTool.deleteSelection`.

### The plan

- T3-e reads "a band, a click or a body move, never a reshape", with the reason (with the shell's wiring the hidden end grip is not there; a selected line's end pressed under `reshape: false` is a body move).
- T3-c names the arc's centre grip (a line has none), as the review's ruling 1 said.
- Task 3's *Builds*, the global constraint naming Task 3's render edits, and Task 6's *Builds* name `deleteSelection`.

### Gates

- Right after the commit: render `flutter test` through the standing comparison: `packages/jet_cad_2d_flutter: 1415 tests; the standing failures and skips, exactly` (1405 + 10); `flutter analyze`: No issues found; format: 227 files, 0 changed.

### Final gates (at `834c832`, after the last fix commit; a fresh run after a container restart killed the first one; `gates.sh`, `gates.out` in the scratch directory)

| Package | Tests (standing comparison) | Analyze | Format |
|---|---|---|---|
| `packages/jet_cad_floor_plan` (`--enable-vmservice`) | `04:34 +1787: All tests passed!`; "1787 tests; the standing failures and skips, exactly" | No issues | 271 files, 0 changed |
| `apps/restaurant_demo` | `+60: All tests passed!` | No issues | 8 files, 0 changed |
| `apps/floor_planner` | `+212: All tests passed!` | No issues | 47 files, 0 changed |
| `packages/jet_cad_2d_gpu` | 20 tests; exactly | No issues | 10 files, 0 changed |
| `packages/jet_cad_2d` | exit 1 (the 2 standing); "1258 tests; the standing failures and skips, exactly" | `--fatal-infos`: No issues | 170 files, 0 changed |
| `packages/jet_cad_2d_flutter` | exit 1 (the 7 standing goldens); "1415 tests; the standing failures and skips, exactly" | No issues | 227 files, 0 changed |

`git status` clean afterwards; no `analysis_options.yaml` committed. Pushed as `5c72a5e..834c832`.
