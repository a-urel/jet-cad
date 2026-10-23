# SDD ledger — plan: docs/superpowers/plans/2026-10-23-plan-shadcn-chrome.md

Spec: docs/superpowers/specs/2026-10-23-plan-shadcn-chrome-design.md (rev 2, approved).
Branch: claude/shadcn-ui-75d8dc. Start: 6fdd93d8.
Review mode: the human's rule (2026-10-16, still binding): no reviewer subagents; the controller self-reviews each task (reads the diff, runs a named mutation, re-runs gates). Implementers: Sonnet.

## Preflight scan

| Pair / task | Shared | Finding |
|---|---|---|
| T2 → T3 | `PlanShadScope`, `planShadThemeOf` | T3 parts mount under T2 scope; consistent |
| T3 → T4 | `PlanWordsCarrier` | T4 collectors import `src/chrome/words_carrier.dart`; integration tests importing `src` — check at T4 |
| T3 → T5..T10 | parts | signatures fixed in T3 Interfaces; later tasks consume only |
| T2 ↔ T5/T9 | `PlanHostSlot` wrap in plan_editor / service view | T2 wraps slots, T5/T9 migrate the same files: T5/T9 must keep the wraps |
| T5 ↔ T8 | plan_editor uses PlanSymbolGallery | T8 keeps signature; no conflict |
| T7 ↔ T9 | canvas-owned reads | both keep their reads Material; T11 KM1 lists them |
| T10 ↔ T2 | `PlanShadScope(data:)` | T2 defines `data`; consistent |
| T11 ↔ T5..T10 | icons | KM2 needs all `Icons.` gone from plan lib: T5..T10 each convert icons in their files; remaining ones (if any file not owned by T5..T10) T11 converts |
| T12 ↔ T3 | demo tests find parts | fine |
| T1 self | sdk ^3.11.0 also for kit_architecture? | T11 adds lucide to kit; lucide 3.1.25 sdk floor — check at T11 |
| T6 self | PP7 phone drawer select | consistent with Review Focus 5 |
| each task | tests vs code | consistent on read |

Ruling: T2 Step 4 allows "default text style" ruling for tests failing only from DefaultTextStyle — such tests change only text-style expectations, logged per test — cost if wrong: a style assertion weakened; mitigated by the ruling log.
Ruling: icons in files outside T5..T10's lists go to T11 — cost: none.

## Tasks
Task 1: dispatched (base 6fdd93d8)
Task 1: implementer DONE_WITH_CONCERNS, commit 8fe41293; controller ran M-AB (PlanEditor.debugShad → check reports "return type ShadThemeData (package shadcn_ui)").
Ruling: SDK floors stay (plan sdk ^3.6.0, dev_harness ^3.5.0), contrary to plan Task 1 — raising to ^3.11.0 flips dart format to the tall style (306/324 files, incl. the alignment-guides-owned canvas files) and adds 63 lints; shadcn_ui's own sdk >=3.11.0 is what binds hosts anyway; CHANGELOG notes "needs Dart 3.11 through shadcn_ui" — cost if wrong: pana/pub show a floor lower than real; a separate reformat task can raise it later.
Ruling: host probe's "no build hook" guard (GPU split spec S8) narrowed to allow exactly objective_c's hook (shadcn_ui → universal_image → extended_image_library → path_provider → path_provider_foundation → objective_c); every other hook, and every GPU package, still fails — cost if wrong: hosts run one native-assets hook the human had wanted none of; reverting means dropping shadcn_ui; monepro already runs it (it has shadcn_ui). Surfaced to the human 2026-10-23.
Ruling: shadcn_ui resolved at 0.57.3 (within ^0.57.1) — fine.
Task 1: fix round 1/1 (probe guard narrowed; commit 9efdfe4e; controller read diff). Probe web build 46M — compare to pre-shadcn at close.
Task 1: complete (commits 6fdd93d8..9efdfe4e, self-review clean)
Task 2: dispatched (base 9efdfe4e)
Task 2: implementer DONE_WITH_CONCERNS, commit c0cf8312; controller re-ran M-SC1 (SC2, SC4, SC6 red), tree clean.
Ruling: derived foregrounds below 4.5:1 swap to black/white (SC7, Material 2 hosts) — spec allowed tuning tokens — cost if wrong: a host's onX colour replaced where it had low contrast.
Ruling: HS1 per-slot cases pass with or without PlanHostSlot today because Scaffold/Material already sit above; kept as regressions for T5/T9 which may remove those surfaces; "HS1 PlanHostSlot alone" carries the mutation — cost: none.
Task 2: minor (deferred): a host ThemeData whose bodyMedium.fontFamily is null shows shadcn's Geist (spec wanted the host font).
Task 2: complete (commits 9efdfe4e..c0cf8312, self-review clean)
Task 3: dispatched (base c0cf8312)
Task 3: implementer DONE_WITH_CONCERNS, commit c90e8e89; controller re-ran M-CP4 (CP4 red), tree clean.
Ruling: read-only PlanTextField = ShadInput kept editable + formatter refusing edits + hidden cursor + TextInputType.none + copy/select-all toolbar (ShadInput.readOnly drops focusability) — cost if wrong: screen readers announce an editable field where today said read-only.
Ruling: PlanIconButton is a StatefulWidget (tooltip suppressed while its menu is open) — same constructor — cost: none.
Ruling: PlanMenuButton's Escape is a HardwareKeyboard handler registered only while open — cost if wrong: an Escape meant for another widget while a menu is open closes the menu instead.
Task 3: minor (deferred): read-only field semantics (no readOnly flag) — see ruling.
Task 3: complete (commits c0cf8312..c90e8e89, self-review clean)
Task 4: dispatched (base c90e8e89)
Task 4: implementer DONE_WITH_CONCERNS, commit 160ea980; controller removed the PlanWordsCarrier lines: LK1x tooltip + menu entry red; restored.
Task 4: minor (deferred): LK1x field error is a regression guard only (error text was already a Text).
Task 4: complete (commits c90e8e89..160ea980, self-review clean)
Task 5: dispatched (base 160ea980)
Task 5: implementer NEEDS_CONTEXT, commit 791b5598 (migration + rulings); 14 tests red (TF8, TF9, V10, integration CP1, 9 architecture_demo) — the old palette's never-finishing ink animation kept a frame scheduled; probe: after setUnitColour+pump1 nothing scheduled or dirty, a forced pump2 shows it. Root-cause debug dispatched (frame-debug-report.md).
Ruling: R-FRAME — tests that leaned on the old chrome's never-ending ticker (a frame always scheduled) flush the event loop with `await tester.idle()` before the pump that should show a document change, as the real event loop does before a frame; nextFrame keeps its hasScheduledFrame premise, which now actually checks the change's own frame (it passed vacuously before) — debug report frame-debug-report.md: product not stale, change schedules its own frame — cost if wrong: a test hides a real missing frame; mitigated: the premise is now a real check.
Task 5: fix round 1/5 (R-FRAME applied, 14 green; commit 2e0f1af5). fix round 2/5 (controller finding: raw ShadTooltip invisible to leak collectors → PlanTooltip part + SW5 + LK1x damaged; commit eef9171e). Controller mutation: a ShadTooltip reference in colour_row.dart → SW5 red.
Ruling: Scaffold stays in PlanEditor (layout; host slots keep a Material ancestor) — cost: none.
Ruling: PlanListRow and PlanSegmented wrap content in Flexible (ED6 overflow at 1.5x/2x text) — cost: none.
Task 5: minor (deferred): drawer scrim reads Material colorScheme.scrim (no shadcn scrim).
Task 5: minor (deferred): tool icons from generic_tools.dart still Material Icons → T11.
Task 5: complete (commits 160ea980..eef9171e, self-review clean)
Task 6: dispatched (base eef9171e)
Task 6: implementer DONE, commit e26343fc; controller mutation readOnly:false → PP2 red.
Ruling: PlanSelect gained key-per-option, expanded, focusNode, Escape-returns-focus (today's DropdownButton behaviour) — additive to Task 3's signature — cost: none.
Ruling: duplicate-label warning colour tertiary → mutedForeground (shadcn has no warning colour) — cost if wrong: the warning reads less loud.
Task 6: complete (commits eef9171e..e26343fc, self-review clean)
Task 7: dispatched (base e26343fc)
Task 7: implementer DONE_WITH_CONCERNS, commit 8228b6e8; DC9 red (open ShadSelect is not modal: Cmd+S writes).
Ruling: DC9 stays unchanged; the parts change — an open PlanSelect/PlanMenuButton consumes every key but its own navigation, as the Material route did (spec G5) — cost if wrong: a host expecting chords to pass through an open select.
Ruling: the custom paper size is PlanSelect's placeholder, not a disabled option — closed it reads "Custom" as before — cost: the open list no longer lists a disabled "Custom".
Task 7: minor (deferred): layer rows taller (shadcn input height).
Task 7: minor (deferred): EX8 (architecture_demo export_flow_test) failed once in a full run — watch at close.
Task 7: fix round 1 dispatched (DC9).
Task 7: fix round 1/5 (PlanModalKeys; commit 6c6946b2); controller mutation handled→ignored: CP12, CP13 red. EX8 green in 3 full runs.
Task 7: complete (commits e26343fc..6c6946b2, self-review clean)
Task 8: dispatched (base 6c6946b2)
Note: alignment-guides merged into local main at c5da0931 (handover: side-session-notes/.../alignment-guides-handover.md). After Task 8: sync this branch with main (merge), resolve bar overlap (PlanEditorAction.guides / PlanServiceAction.guides, _BarCommand.selected → PlanIconButton(selected:), service _button selected, PlanStrings.alignmentGuides, demo_theme.dart guide colours) in a dedicated integration step before Task 9.
Task 8: implementer DONE_WITH_CONCERNS, commit 18664a1b; controller mutation "taps ignore enabled" → GG4 red.
Ruling: plan_symbol_gallery_test's `gallery.foreground == 0x000000` read removed — the grid takes no foreground any more; GG6 checks the same ink (light/dark, selected or not) — cost if wrong: one ink case uncovered.
Task 8: minor (deferred): the search field lost its search glyph (PlanTextField takes a text prefix only).
Task 8: minor (deferred): PlanTextField has no textInputAction (soft keyboard key not "search").
Task 8: note: tool/screenshots setUpAll fails loading packages/shadcn_ui/fonts/Geist[wght].ttf (since Task 1) → Task 13.
Task 8: complete (commits 6c6946b2..18664a1b, self-review clean)
Integration step: sync with local main (alignment guides c5da0931) before Task 9.
Integration step: merged local main (alignment guides) at 6b026d8e (conflict: _Toolbar; guides button → _barButton(selected:), Icons.straighten → LucideIcons.ruler); format fix d480ba78. Gates: plan +1832 ~13, integration +240, restaurant +114, architecture +176, tool/ci +122, API boundary clean; jet_cad_2d_flutter only its 7 standing text-ladder failures.
Task 9: dispatched (base d480ba78)
Task 9: implementer DONE_WITH_CONCERNS, commit 99748dd5; 11 red (service_bar BC1×8, S-19: 48→40 px button edges; restaurant look_test DL1/DL2 bar colour premise surfaceContainer).
Ruling: R-BarGeometry — the bar contract is order + documented gaps; edges re-baselined from the measured button width, width pinned at 40 — cost if wrong: the 8 px narrower buttons were a contract.
Ruling: R-BarSurface — the bar paints the derived shadcn background (= seed surface) with a bottom border, not surfaceContainer — cost if wrong: hosts see a lighter service bar.
Task 9: fix round 1 dispatched.
Task 9: fix round 1/5 (R-BarGeometry, R-BarSurface; commit 6e6bb94e). Controller mutation serviceBarHeight ignored → SV2 red.
Task 9: complete (commits d480ba78..6e6bb94e, self-review clean)
Task 10: dispatched (base 6e6bb94e)
Task 10: implementer DONE, commit d463df42; controller mutation "outside tap does nothing" → EX5 red.
Ruling: the export dialog's outside tap is a full-page GestureDetector under the card (the scope's opaque mouse surface hides the route barrier) — cost: none seen.
Task 10: minor (deferred): the dialog barrier no longer dims (route default; today black54) — consider a black-at-0.54 barrier built without a colour literal.
Task 10: complete (commits 6e6bb94e..d463df42, self-review clean)
Task 11: dispatched (base d463df42)
Task 11: implementer DONE, commits e35fe6de, 704e7e30; controller mutation Divider in colour_row → KM1 red.
Ruling: CircularProgressIndicator (gallery loading) kept and allowlisted — shadcn 0.57 has no spinner — cost: one Material-looking spinner.
Ruling: the property/page/layer panels' transparent Material roots kept (host inspectors inside need a Material ancestor) — cost: none.
Task 11: complete (commits d463df42..704e7e30, self-review clean)
Task 12: dispatched (base 704e7e30)
Task 12: implementer DONE_WITH_CONCERNS, commit dcc59766; M-DL (wrap off) → DL1/DL2 red. Both demos build for macOS; restaurant POS1 integration test passed on the real binary. Visual check deferred to Task 13's regenerated screenshots.
Ruling: the POS look's ShadTheme text family is Roboto (the demo bundles it) — cost: none.
Task 12: minor (deferred): under POS the demo's own Material widgets (OwnServiceBar) read the app's seeded scheme now.
Task 12: complete (commits 704e7e30..dcc59766, self-review: diff read, mutation by implementer verified in report)
Task 13: dispatched (base dcc59766)
Task 13: implementer DONE, commits 6ddf99a9, 23b364b9; controller looked at plan_editor.png: shadcn chrome, no overflow; unchecked ShadCheckbox renders as a filled grey square (derived input/border mapping?) — open point for the human.
Task 13: complete (commits dcc59766..23b364b9, self-review clean)
Task 14: controller runs the close.
Task 14: complete (results note, ledger archived, STATUS)
