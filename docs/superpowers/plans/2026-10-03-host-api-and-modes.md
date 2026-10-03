# Plan 14b-2 — host API and the two modes

**Spec:** [2026-10-03-host-api-and-modes-design.md](../specs/2026-10-03-host-api-and-modes-design.md),
revision 2 (H1–H14, A-1 to A-3, M-14f and M-14b2-1 to -14). Approval as
recorded in the spec (the human travelling: no approval asked unless
needed; the umbrella's 14b-2 decisions approved).
**Branch:** `claude/exciting-pasteur-9m22jv` (spec at `8b4d303`).

## Global constraints

- `CLAUDE.md` non-negotiables. Engine and render packages **not edited**;
  allocation invariants untouched; no golden PNG change.
- `apps/floor_planner` behaves exactly as before; its tests change only in
  imports.
- A new app commits its initial `analysis_options.yaml` once; a pub-get
  rewrite is never committed.
- Every task ends with its packages' gates green (`flutter test`,
  `flutter analyze`, `dart format --output=none --set-exit-if-changed .`):
  planner, app, and from Task 5 the demo.

## Tasks

### Task 1 — the seams and the export helpers (H6, H8, R-5)

- `PlannerView`: `grips` and `textTool` optional; optional `fitRequests`
  (refit post-frame at the last size).
- `PlannerShell`: optional `selection` (host's, not disposed) and
  `fitRequests` (forwarded).
- `src/export/export_bytes.dart`: `exportPageOf`, `exportOmitOwners`,
  `exportBytes`, `exportPdfBytes`, `printPageFormat` moved from the app;
  the app keeps `exportFileKind`/`exportFileName`.
- Tests: a host selection survives a shell dispose (M-14b2-10); a fit
  request refits; the app suite unchanged.

### Task 2 — the controller (H1–H4, H11–H14)

- `src/host/floor_plan_types.dart`: `FloorPlanMode`, `FloorPlanTable`,
  `FloorPlanExport`.
- `src/host/floor_plan_controller.dart`: documents, modes, the service
  copy (own measurer, runtime, app components), dirty and `markSaved`
  (last `designJson` state), undo/redo on the active document, `tables`
  (lazy, keyed by identity and state id), `selectedTables`/`select`
  (visible, unlocked; survives switches), `fitToView`, `resetLayout`,
  the settle, the camera memory, `numberingWarnings`, the drop rule.
- Tests: M-14f, M-14b2-1 to -8, -12 to -15, widgets binding.

### Task 3 — the view and the service view (H5–H7, R-9)

- `src/host/service_view.dart`: `PlannerView` with an idle tool, its own
  systems on the copy (LIFO), a top bar (Undo, Redo, Export, Print),
  Undo/Redo chords.
- `src/host/floor_plan_view.dart`: the shell (design) or the service view
  (selection), keyed by the active document; Export and Print, guarded.
- Tests: the mode switch in widgets, Export in both modes (PNG bytes),
  M-14b2-11 (settle), M-12a (a dispatcher spy).

### Task 4 — the barrel (H9, R-10)

- `lib/jet_cad_floor_plan.dart` with `show` lists; a textual list test
  and a compile test through the barrel alone (M-14b2-9).

### Task 5 — the demo (H10, R-12, R-13)

- `apps/restaurant_demo` from `flutter create`, set up per R-12; Salon and
  Teras; the toggle with its discard question; select by number; the log;
  the numbering warnings. Widget tests drive the API end to end.

### Task 6 — the exit

- Every gate; `flutter build web` for both apps; a Chromium smoke of the
  demo; results note; STATUS; roadmap.
