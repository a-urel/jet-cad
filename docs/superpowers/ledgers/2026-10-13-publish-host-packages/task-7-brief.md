### Task 7: Changelogs, STATUS and the results note (D4, D10, D11)

**Files:**
- Modify: `CHANGELOG.md`, `STATUS.md`
- Create: `docs/superpowers/notes/2026-10-13-publish-host-packages-results.md`

- [ ] **Step 1: The root CHANGELOG becomes an index**

Replace its preamble and its *Unreleased* section (both written at `1dc167d`) with:

```markdown
# Changelog

The packages are published on pub.dev, each with its own version, its own
CHANGELOG and its own git tags:

- [`jet_cad_2d`](packages/jet_cad_2d/CHANGELOG.md), the engine
  (`jet_cad_2d-vX.Y.Z`);
- [`jet_cad_2d_flutter`](packages/jet_cad_2d_flutter/CHANGELOG.md), the
  renderer (`jet_cad_2d_flutter-vX.Y.Z`);
- [`jet_cad_floor_plan`](packages/jet_cad_floor_plan/CHANGELOG.md), the
  planner a host depends on (`jet_cad_floor_plan-vX.Y.Z`).

A host depends on the planner from pub.dev (see
[docs/host-guide.md](docs/host-guide.md)). Up to 0.7.0 the packages were
released together, by git, under one version and one tag (`vX.Y.Z`); that
shared history follows, unchanged.
```

Keep every section from `## 0.7.0` down byte for byte (`git diff` shows only the head changed).

- [ ] **Step 2: STATUS**

- The ruling *"The engine's own version"*: rewrite to Decision 4 and D10 — every published package its own version, CHANGELOG and tag; the shared `vX.Y.Z` line ended at `v0.7.0`; `jet_cad_2d_gpu` and `jet_cad_restaurant_symbols` unpublished, untagged; D1's lower-bound rule at a dependent's release.
- The ruling *"The host packages go to pub.dev too"*: point at the spec and this plan; mark the order's second and third steps prepared on this branch.
- *In flight*: this branch, the spec, the plan, the record.
- *Resume here*: the human's checklist of D10, per package in order — `main` pushed and CI green; for a dependent, its lower bounds per D1 and pana's lower-bounds section green; `dart pub publish --dry-run`; `dart pub publish`; the tag (`jet_cad_2d_flutter-v0.7.1`, `jet_cad_floor_plan-v0.7.1`, on the merge commit); the version visible on pub.dev; after the planner, D7: resolve `tool/ci/host_probe` with its `dependency_overrides` block removed (a scratch copy of the template), `flutter analyze`, record the result.
- *Commands*: the dry run for each of the three packages.

- [ ] **Step 3: The results note**

`docs/superpowers/notes/2026-10-13-publish-host-packages-results.md`, in the engine note's shape (`2026-10-13-publish-jet-cad-2d.md`): the request and the rulings (quoted); what each task did and its commit; the dry runs (archive sizes, 0 warnings, exit codes, the Review Focus 1 grep); `dart doc` 6 → 0 and 23 → 0; pana for both packages (each section; the repository check's note); every mutant with its result (M-DL1, M-RX1, M-RX2, M-FX1, M-FX2, M-CI1, M-LK1, M-LK2, M-PR1); the probe and the four released probes; **D4's barrel audit**: for each package, the types in a public signature of a barrel export that the barrel does not export (a rough grep, labelled as such, as in the engine's note); the gates per package; D11's migration steps for the restaurant software; *Owed* (the human's checklist, D7, the CI run on the pushed branch).

- [ ] **Step 4: Full gate and commit**

Every gate of Task 1 Step 6 once more, and `dart pub publish --dry-run` for the three packages on the committed state.

```bash
git add CHANGELOG.md STATUS.md docs/superpowers/notes/2026-10-13-publish-host-packages-results.md
git commit -m "docs: the host packages' publication, recorded (D4, D10, D11)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Then the whole-branch independent review (an Opus subagent, no Codex) on `git diff main..HEAD`; its findings are applied as new commits and recorded in the results note.
