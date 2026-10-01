# Task 6c brief — owed test-only follow-up (m-T5-1, m-T5-2)

Work ONLY in /home/user/jet-cad/.claude/worktrees/plan-09 (branch plan-09/symbol-library-core, HEAD 22bc83d). Read CLAUDE.md, the Task 5 review
(.superpowers/sdd/symbol-library-core/task-5-review.md, findings 1 and 2), apps/floor_planner/lib/symbols/furniture_catalog.dart and
apps/floor_planner/test/symbols/furniture_library_test.dart. Add TEST-ONLY cases (no lib change, no asset regeneration):
 (1) m-T5-1: every symbol's outline shape intended to be closed is closed. Decide the rule honestly from the catalog: for every leaf of kind polyline, read the payload/record
     closedness flag the codec uses (see drafting.dart polylinePayload / how closed is encoded) and assert closedness against an EXPLICIT per-key expectation table of which symbols have which
     polylines open (derive it from the catalog; it is a deliberate table, not a tautology): at minimum assert that each symbol has at least one closed polyline OR a circle as its outline, and that the
     rectangle-built outlines (_rect) are closed. Show the mutant "every rectangle polyline open (closed: false) + regenerated asset" turns it red (regenerate with dart run tool/generate_furniture_library.dart
     from apps/floor_planner, run the test, then RESTORE the catalog from your backup with cp and regenerate again; git status must show the asset unchanged).
 (2) m-T5-2: a table in the test pinning each of the 25 keys to its category (written out literally in the test, not derived from the catalog), and the mutant "bed.single category -> Kitchen + regenerated asset" turns it red.
Environment: export PATH=/root/flutter/bin:$PATH ; CI=true on test commands. Scratch prefix: /tmp/claude-0/-home-user-jet-cad/436a473c-2fd9-5dea-b1ee-ba84afc1ba81/scratchpad/t6c/ . cp backup / mutate ONE thing / run the test FILE in the foreground / cp back / diff exit 0. NEVER git checkout -- a .dart file or the asset.
Never commit analysis_options.yaml (stage by explicit path). Real output only. Commit trailers:
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01M4zdYkH7yTFAU2aCUA8bdQ
Do not push. Gates: app (776 + new), analyze, format; engine and render need not be re-run (test-only app change: say so). Write the report early to
/home/user/jet-cad/.claude/worktrees/plan-09/.superpowers/sdd/symbol-library-core/task-6c-report.md (commit SHA, what each test pins, mutant outputs, final git status) and reply with a short summary.
