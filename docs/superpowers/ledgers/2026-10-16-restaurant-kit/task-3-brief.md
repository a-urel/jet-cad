### Task 3: Host gaps H1-H4

**Files:** `packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart` (export
`PlanToolIds`), `barrel_test.dart` (ED-9 name set), the controller's doc
comment on views; tests `test/host/tool_ids_test.dart` (H1),
`test/host/host_kit_test.dart` (H2: a test kit with one symbol loaded
beside another kit, placed from the gallery), `test/host/two_views_test.dart`
(H3), `test/service/view/user_camera_test.dart` (H4); CHANGELOG lines.

- [ ] Each: test red first (or a named mutation for behaviour that
  already holds), implement, gates. H3: mount two `PlanCanvas` on one
  controller; the last placed drives `camera`/`canvasRect`; unmount it;
  the first drives. Mutation: keep the first placed. H4: with
  `userCamera: false`, pinch, pan and wheel leave `camera` unchanged;
  `centerOn` moves it. Mutation: ignore the flag for the wheel.
- [ ] Commit `feat(plan): PlanToolIds public; host kits, two views and userCamera pinned`.

