### Task 11: The exit gate (implementer part)

**Files:** the parity companion (a closing "Closed (4a)" column/section),
the test-audit companion ("Closed (4a)"),
`docs/superpowers/notes/2026-10-16-restaurant-kit-results.md`, the
umbrella and 3b specs' Amendments lines, `STATUS.md`.

- [ ] Close every parity row (HAVE/RENAMED with its test, R2 item,
  decision-7 drop) and every audit row, from the test files by grep, not
  memory; any open row is a defect.
- [ ] Run every gate fresh (R5) and transcribe; dry-runs of the kit and
  the plan library (0 warnings); `check_kit_deps`, `check_guide`, probe.
- [ ] Results note (gates, POS1 and its PNG, builds, rulings from the
  ledger, follow-ups, "For the human"); amendments; STATUS (4a done on
  the branch, not merged). Commit `docs: 4a parity and audit closed, results, amendments, STATUS`.
- [ ] (controller) Review the whole branch, one fix wave if needed,
  archive the ledger, tell the human the restaurant demo runs on the new
  packages, offer the merge menu.
