# Task 11 report

Status: DONE_WITH_CONCERNS.

Commits: 0a7bb083 docs (guide 10.1 + probe), 744387b3 feat(restaurant_demo), 64a64199 docs CHANGELOGs, 8791fe80 test(integration) fix, 598b3e00 docs results + STATUS.

Gates: full per-gate last lines are in docs/superpowers/notes/2026-10-23-alignment-guides-results.md ("Gates"). All green except the standing failures (jet_cad_2d: 2 generate_document fingerprints; jet_cad_2d_flutter: 7 text ladder rungs). Plan +1754; integration +240 after the fix; restaurant_demo +114; architecture_demo +176; tool/ci +114; check_guide 38 blocks; host probe analyze clean and web build OK; pub publish --dry-run: 0 warnings for plan and flutter.

Fixes owed by the branch (found by the gate): jet_cad_2d_integration's own recording_plan_strings.dart copy lacked `alignmentGuides` (analyze error, two suites failed to load); four pinned-landing tests there (against_wall_rotate x3 via mountEditor(alignmentGuides: false), wall_attach_tool rig via toggle) landed aligned with guides on by default. No assertion changed.

Concerns: restaurant_demo's guideWidth 1.5 sits in the POS look's ambient PlanThemes (look_test pins the view theme), so the Standard look draws 1 px. Version numbers are an open question for the human.
