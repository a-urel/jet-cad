# Task 6 fix round 1 re-review

Verdict: all addressed. No new findings.

- Important (EX12 chordHandled): addressed. app_rig.dart `chordHandled` is identical to floor_planner/test/support/export_flat.dart:188; EX12 asserts isTrue for Cmd/Ctrl+P and +E plus the effect checks. Mutation run by me: removed the `kFileChords` consume in lib/main.dart; EX12 red for both Cmd and Ctrl (failure at export_flow_test.dart:307, the chordHandled expectation); `git checkout -- lib/main.dart`, `git diff --quiet` printed CLEAN.
- Minor 1 (EX1-open/PR1-open text): addressed. Text runs now equal the plan's live TEXT entities (liveTexts reads the document, apart from the exporter), stronger than the old [labelText]; expectInsideSheet checks every vertex. Dropped fontLoads==1, instance colour/lineweight/placement, separator: the `// Decided:` premise holds (sample_flat.dart has no block instance with overrides; app injects no font cache); cited covering tests exist (jet_cad_2d_flutter test/export/export_pdf_test.dart, page_flows_test.dart PF13, separator_export_test.dart).
- Minor 2 (EF12): addressed, bytes compared with the vendored golden font.
- Minor 3 (cosmetics): addressed (import order; comments wrapped).
