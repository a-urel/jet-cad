# Task 12 report (exit gate)

Commit fea46c30 docs: the kit contract's symbol side, results of record. Head at gate: b069a3f9.
Full transcripts (last lines of every gate, hand checks, mutation table, plan decisions, rulings, deferred minors, spec gaps) are in docs/superpowers/notes/2026-10-13-kit-contract-results.md.

- Package gate: flutter test `00:01 +225: All tests passed!`; analyze `No issues found! (ran in 2.3s)`; format `Formatted 47 files (0 changed)`.
- Tools: `cd tool/ci && dart test` `+106: All tests passed!`; check_kit_deps: `kit dependencies: 1 package(s) checked, none names the plan library or another kit`.
- jet_cad_2d: `+1289 -2` — exactly the 2 known generate_document_test failures; analyze/format clean.
- jet_cad_2d_flutter: `+1450 ~1 -5` — exactly the 5 known text-ladder golden failures; analyze/format clean.
- jet_cad_2d_gpu: `+20: All tests passed!`, analyze/format clean.
- Dry run: exit 0, `Package has 0 warnings.`; LICENSE cmp silent.
- Hand checks: tree clean; analysis_options only the kit's; old packages/apps diff empty; no dart:io import (only 15 comment lines say "no dart:io"); no Flutter in model/authoring; only the bundled_library.dart comment names jet_cad_2d_kit_; sample kit regenerates to committed bytes (diff exit 0).
