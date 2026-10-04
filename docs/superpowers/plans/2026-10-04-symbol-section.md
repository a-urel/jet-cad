# Plan 09c-2 — the Symbol section and the wall-aware move

**Spec:** [2026-10-02-wall-aware-symbols-design.md](../specs/2026-10-02-wall-aware-symbols-design.md),
revision 5 with its spot check (V-1..V-9): D7, D8, and every revision-5
amendment. Approved by the human at revision 4 ("yaz", 2026-10-02);
revision 5 reconciles 09c-2 with the restaurant embedding (14), on the
human's "Devam et, 09c-2'yi başlat" (2026-10-04).
**Branch:** `claude/exciting-pasteur-9m22jv`, restarted from `main` at
`f2c4875` (09c-1 merged at `cf463d8`).

## Global constraints

- `CLAUDE.md` non-negotiables; the two allocation invariants and the
  goldens untouched; no schema change.
- Every task ends with the engine, render, planner, app and demo gates
  green (render: the 7 standing text-ladder failures and 1 skip; engine:
  the 2 standing).
- Without a resolver, or when it answers null, a move is today's bit for
  bit (D8).

## Tasks

### Task 1 — the engine command and the render caches (D7, W-13)

`SetInstanceDefinitionCommand` in `jet_cad_2d` (structure; refuses a
missing node, a non-instance, a missing definition; a cycle through
`replaceNode`'s guard; inverse restores). Tests:
`test/document/instance_definition_test.dart` (the index and the extents
follow, refusals, structure), `jet_cad_2d_flutter/test/
instance_definition_caches_test.dart` (the outline and the painter
follow the change, undo, redo and a later leaf edit). Mutants M-09c-w,
-bc.

### Task 2 — the render seam (D8, R5-5, V-2)

`MoveResolver`; `SelectTool({moveResolver})` asked in `_retarget` for a
body drag that began with exactly one selected key, captured one node
and has Shift up; `GripDrag.singleNode`, `moveToTransform` (the preview's
delta, the marker as target), `moveTo` clears `T'`, `command` commits
`T'` verbatim and is a no-op only when it equals the transform exactly;
`drawSnapMarker` draws `nearest` as the hourglass. Tests:
`test/select_tool_move_resolver_test.dart`, `snap_marker_test.dart`.
Mutants M-09c-aa, -ad, -ae, -ao, -av, -aw, -ax, -z, the marker.

### Task 3 — the Symbol section (D7, R5-2..R5-4, R5-7, V-1, V-3..V-7)

`lib/src/symbols/symbol_section.dart`: name, size, Rotation (compose
about the insertion point; exact table at quarter turns), Mirror (about
the box's centre `x`), the Size menu (family per V-5, servable rules per
V-4, back-left anchor, one `Change size` compound through the factored
reuse-or-copy, V-7). `SelectionPanel` takes the loader (V-3), shows the
section above the Table section; a table's Rotation and Mirror follow
`_rotatable` (V-1). The planner's ghost uses `drawSnapMarker(nearest)`.
Tests in the planner package; mutants M-09c-u, -v, -x, -y, -al, -be,
-bf, -bg, -bh, -bi.

### Task 4 — the wall-aware move (D8)

`lib/src/symbols/symbol_move.dart`: the resolver (tag, F3, library
ready, orthonormal, the plain-moved back-centre, the neighbours less
itself); the shell's `SelectTool` built with it over its `WallFaces`.
Tests; mutants M-09c-am, -an, -az, -ab.

### Task 5 — the end-to-end test and the exit

App test: a symbol moved along a wall and to another wall, its size
changed, rotated and mirrored, undo four times, redo, save and load
byte-equal. Gates, both web builds, `dev_harness_2d` analyze, a Chromium
smoke of the Symbol section, results note, STATUS, roadmap.
