### Task 5: O3 page-flow signal, O4 same-frame re-word

**Files:** `plan_controller.dart` (public `ValueListenable<bool>
pageFlowBusy`), its tests; `apps/architecture_demo/lib/busy_wrappers.dart`
and `document_host.dart` (busy follows `pageFlowBusy`), its
`test/export/busy_test.dart` (N6-gap → N6-closed); the notice re-word
path and the 3a test pinning the lag.

- [ ] **O3:** `pageFlowBusy` is true from an export's or print's start
  (dialog included) to its end, error or cancel included; tests for each
  path; mutation: clear it before `onExport`. The architecture demo's
  busy covers the gap: N6-closed asserts New does nothing between the
  dialog closing and the write. Mutation: the demo ignores the signal.
- [ ] **O4:** find the 3a test that pins the one-frame lag (grep
  "re-word" / "one frame" in `jet_cad_2d_plan/test` and the kit's
  tests), flip it to same-frame, and make the notice re-word in the
  locale change's frame. Mutation: defer it again.
- [ ] Gates (plan, integration, architecture_demo). Commit `feat(plan): pageFlowBusy; tool notices re-word in the same frame`.

