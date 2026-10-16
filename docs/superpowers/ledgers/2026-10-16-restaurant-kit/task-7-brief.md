### Task 7: The demo's service features

**Files:** `lib/main.dart` (or split into `lib/area.dart`,
`lib/table_menu.dart`, `lib/statuses.dart` if the file passes ~800
lines); port `demo_test.dart`'s rows per the audit that cover: the
Design/Service toggle, editor profiles and permissions, selection and
find, the table menu, statuses (random), merge/split, POS id linking
(host data), zones and fade.

- [ ] Port per the audit; new: **AR-isolated** (Review Focus 3: a status,
  a selection and an undo in the Salon leave the Teras unchanged;
  mutation: share one controller) and **ST-caption-de/tr** (Review Focus
  4; mutation: no cut).
- [ ] Gates; commits `feat(restaurant_demo): service features on the new API`, `test(restaurant_demo): demo tests ported (service)`.

