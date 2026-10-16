### Task 6: The demo's new base and samples

**Files:** `apps/restaurant_demo/pubspec.yaml` (new deps, no old ones,
no `assets/plans`), delete `assets/plans/*.json` and `UPDATE_SAMPLES`;
`lib/samples/salon.dart`, `teras.dart`; `lib/main.dart` reduced to the
app shell (two areas, each a `PlanController(kits: [architectureKit,
restaurantKit], build: …)`, the area switch, `PlanTheme` look,
`demo_strings.dart` kept); `test/boundary_test.dart`;
`test/sample_plans_test.dart` (the audit's SPLIT row) and
`test/support/` (one rig and one unit finder for the whole demo's tests).

- [ ] Read the old `main.dart`, `demo_theme.dart`, `demo_strings.dart`
  and the two JSON plans; rebuild the Salon and Teras geometry as walls
  (`WallParams`), doors/windows where the old plans had them, and tables
  by key and transform, numbered in build order (Salon 1-3, 4-5, 6-7,
  8-11 as the audit says; Teras per its JSON). A test per sample: unit
  count, numbers, capacities, opens clean with nothing to undo.
  Mutation: two tables swapped in build order.
- [ ] Boundary test (mutation: an import of the old package).
- [ ] The shell pumps; both areas show their plans.
- [ ] Gates; commit `feat(restaurant_demo): the new base and the samples as builds`.

