### Task 10: The host guide and its checks

**Files:** `docs/host-guide.md` (rewritten), `tool/ci/host_probe/**`,
`tool/ci/check_guide.dart` (if its paths/rules change),
`tool/ci/test/*` for the guide check.

- [ ] Rewrite per spec R4 (sections listed there), every code block
  compiled by the probe; the POS example uses `restaurantKit`, service
  mode, statuses, groups (with Review Focus 2's warning and snippet),
  host data, events; H1-H3 shown; "From `jet_cad_floor_plan`" maps every
  old barrel name (parity companion §2) to its new name or its decision-7
  drop.
- [ ] The probe builds against the new packages from outside the
  workspace (as today's does for the old); `check_guide` green; a
  mutation: a guide snippet edited without the probe → red.
- [ ] Commit `docs: the host guide for jet_cad_2d_plan and the kits; its probe and check`.

