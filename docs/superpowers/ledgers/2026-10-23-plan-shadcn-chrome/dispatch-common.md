# Common context for every implementer of this plan

Repo: jet-cad, a Flutter pub-workspace monorepo. Worktree:
/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/shadcn-ui-75d8dc
(branch claude/shadcn-ui-75d8dc). Never touch the main checkout.

The work: move `packages/jet_cad_2d_plan`'s chrome from Material to
`shadcn_ui` (resolved 0.57.3; source ~/.pub-cache/hosted/pub.dev/shadcn_ui-0.57.3).
Spec: docs/superpowers/specs/2026-10-23-plan-shadcn-chrome-design.md.
Global constraints: .superpowers/sdd/2026-10-23-plan-shadcn-chrome/global.md.
Rulings so far (format to follow): .superpowers/sdd/2026-10-23-plan-shadcn-chrome/rulings.md.

## What exists (read the sources for exact signatures)
- `lib/src/chrome/shad_scope.dart`: `PlanShadScope`, `planShadThemeOf(context)`, `planShadThemeFrom(ThemeData)`.
- `lib/src/chrome/host_slot.dart`: `PlanHostSlot` (transparent Material for host widgets).
- Parts, all `PlanWordsCarrier`: `icon_button.dart` (`PlanIconButton`, `PlanTooltip`), `text_field.dart`
  (`PlanTextField`, `PlanReadOnlyField`, `planTextContextMenu`), `select.dart` (`PlanSelect`, `PlanOption`),
  `segmented.dart` (`PlanSegmented`, `PlanSegment`), `menu_button.dart` (`PlanMenuButton`, `PlanMenuEntry`),
  `rows.dart` (`PlanCheckRow`, `PlanSwitchRow`, `PlanListRow`). Tests: test/chrome/.
- Guards: test/l10n/shadcn_words_test.dart (SW1 ShadInput only in text_field.dart; SW4 kAllowedShad list —
  add a new shadcn identifier there, an unused one is red; SW5 ShadTooltip only under lib/src/chrome/ — use
  `PlanTooltip` for any tooltip); `dart run tool/ci/check_api_boundary.dart` (no Shad type in public API);
  test/invariants/theme_colours_test.dart (no colour literals in lib).
- Leak tests LK1/LK2 read Text, Material Tooltip and every PlanWordsCarrier; they must stay green unchanged.

## Rules for every task
- SDK floor stays ^3.6.0; keep the current dart format style.
- Do not touch `lib/src/canvas/**`, `tools/move_resolver.dart`, `service/service_tool.dart`, package `jet_cad_2d_flutter`.
- Canvas-owned `Theme.of` reads (canvas background, paper, brightness, layer swatch ink, every PlanTheme read) stay Material. Chrome colours/text come from `planShadThemeOf(context)` / `ShadTheme.of(context)`.
- Keep every `PlanHostSlot` wrap.
- `Icons.*` → `LucideIcons.*` (`package:lucide_icons_flutter/lucide_icons.dart`) in every file you migrate; record pairs.
- Keys keep their values; a key on a Material widget moves onto the part that replaced it.
- Rulings: an existing test may change ONLY when it fails because a widget type changed: rewrite its finder/read to the
  part, anchored on the same key, checking the same thing; append `R-<Mapping>: file:line — old → new — why same` to
  rulings.md. R-FRAME (already ruled): if a test waits for a document change, `await tester.idle()` before the pump that
  shows it, never extra pumps. Any other failing behaviour test: STOP, report NEEDS_CONTEXT, do not change it.
- Write the brief's new tests first, run them red (paste), then implement. Run each named mutation, paste its red, revert.
- Never commit analysis_options.yaml (`git status --short` before every commit). Never synthesize output.
  Trailer `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. No merge/push/tag/publish. No subagents.
  Shell command refused → retry simpler or report. Unclear → NEEDS_CONTEXT.

## Gates before the final commit
- `cd packages/jet_cad_2d_plan && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .`
- `cd packages/jet_cad_2d_integration && flutter test`
- `cd apps/restaurant_demo && flutter test`; `cd apps/architecture_demo && flutter test`
- `cd tool/ci && dart test`; `dart run tool/ci/check_api_boundary.dart` (repo root)

## Report
Full report to `.superpowers/sdd/2026-10-23-plan-shadcn-chrome/task-N-report.md`: commits, red output, gates' real
last lines, each mutation's red line, rulings added, icon pairs, choices made, concerns.
Return only: status, commit SHAs, one-line test summary, concerns.
