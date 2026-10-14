# Pre-flight conflict scan: plan 2a (the plan library in design mode)

Plan: `docs/superpowers/plans/2026-10-14-plan-library-2a.md` (32 650 lines, 21 tasks; task spans: T1 255-1018, T2 1019-2090, T3 2091-3539, T4 3540-5768, T5 5769-7466, T6 7467-9363, T7 9364-10220, T8 10221-13275, T9 13276-14976, T10 14977-16252, T11 16253-18427, T12 18428-19844, T13 19845-21974, T14 21975-23625, T15 23626-24689, T16 24690-25944, T17 25945-27866, T18 27867-29165, T19 29166-30800, T20 30801-32400, T21 32401-32468).
Spec: `docs/superpowers/specs/2026-10-14-plan-library-design-mode-design.md` (rev. 3). All line numbers below are plan lines unless marked `spec:`.

**Method (read-only).** The plan was split per task and checked by script and by reading: every `**Files:**` block against the task's `git add` line(s); every backticked repo path a task names against what some task stages (or the tree holds); every relative and package import inside the plan's Dart blocks against the file it resolves to and the task that creates it; every test id/name declared against every mutation's target (`→ X red` and `--name`/`--plain-name`); per-task gate commands against packages touched; cross-task references (`Task N`) and shared staged files to form the pair list; then the controller/session wiring (Tasks 8, 10, 11, 12, 14, 15), the barrel (6-20), the Task 21 template and the Global Constraints were read in full. The reconciliation log's 31 name fixes, 8 file fixes, 2 id fixes and R-rulings were not redone; rows that rest on it say so.

**What the reconciliation missed, in one line:** it added `session.dart` to the Files and "Assumed" lists of Tasks 10, 11, 12, 14 but left their step code writing per-document state as controller fields with a "per-document dispose" — and Task 8 disposes a document's session one frame *after* the swap, so those steps dispose the *new* document's objects (F1), double-dispose tools (F2) and leave a second, ungated `plan.select` (F3).

Counts: **154 pair rows** (153 pairs from shared staged files or cross-references, plus 14–15 through Task 15's prose-staged `plan_controller.dart`), **21 task rows**, **13 findings** (3 high, 4 medium, 6 low) plus 2 informational notes.

## 1. Pairs of tasks that share a file or an interface

`B` = the barrel `packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart`. "Different members" means both edit the same file in disjoint members (checked by member definitions per task). Rows marked "reconcile row N" rest on the reconciliation log's Step 1 table and were spot-checked, not re-derived.

| Tasks | Shared file / interface | Produces → consumes (name, signature, file, plan lines) | Finding |
|---|---|---|---|
| 1–2 | engine `parametric_system.dart`, `regeneration.dart`, `CHANGELOG.md` | T1 E1 `typeIds`/`typeIdOf` + E3 sites → T2 extends the `typeIdOf` doc (1035), appends a bullet under T1's `## Unreleased` (2015) | OK. T2 notes T1 shifts line numbers and locates sites by quoted code (1029) |
| 1–7 | E4 `DraftDocumentCodec.decode(…, keepUnreadableComponents)` | T1 Produces (276) → T7 `decodePlan` passes `true` (10060) | OK (R-c); M-PF-unreadable pins it (10204) |
| 1–8 | E1 `ParametricCatalog.typeIdOf` | T1 (273) → T8 `GripDispatch`/`typeOf` (11768, 12707) | OK |
| 1–10 | E3 `PartialMutationError` | T1 (274) → T10 consumes (14988, 16248) | OK |
| 1–11 | E3 sites, E4 diagnostic shape | T1 (274-275) → T11 F-6/F-7 via `_undoInner` (18418), `reportUnreadable` | OK |
| 1–18 | E1 `typeIdOf` | T1 → T18 layer picker `isObject` (28879), LP tests (28426) | OK |
| 1–21 | E1/E3/E4 tests | T1 → T21 coverage rows E1/E3/E4, engine-commit check (32446) | OK |
| 2–8 | E2 `ParametricSystem(…, {isFrozen})` | T2 (1037) → T8 session `isFrozen: frozen.contains` (12259) | OK |
| 2–10 | E2 frozen = plain group | T2 (1040-1045) → T10 L-8 (16249) | OK |
| 2–11 | E2 `probe`, `isFrozen` | T2 (1038, 1047) → T11 `FailureBoundary.probeType/probeLoaded` (18417) | OK |
| 2–21 | E2 tests | T2 → T21 coverage row E2 | OK |
| 3–4 | kit barrel, kit CHANGELOG; specs | T3 `PropertySpec.bind`, `PropertyField`, `ColourTarget`, `code_fixtures.dart` (2105-2116) → T4 (3551); T4 barrel diff keeps T3 lines (5285-5294) | OK |
| 3–5 | kit CHANGELOG; specs | T3 specs/`ColourTarget` → T5 `cafe_code.dart` (5779) | OK |
| 3–6 | specs, `PlanGate`, `ValueUnit` | T3 → T6 test kit uses all eight kinds (7516) | OK |
| 3–8 | `PropertyField` | T3 → T8 tool-settings fields (10229) | OK |
| 3–9 | kit barrel | T3 exports (3140-3145) → T9 adds `swatch.dart` export (13434) | OK (sequential append) |
| 3–12 | `PlanGate` | T3 (2103) → T12 `PlanPermissions.allows(PlanGate)` (18443) | OK |
| 3–17 | eight spec kinds, `PropertyField`, `ColourTarget` | T3 (2105-2116) → T17 panel (25962); radians in field, degrees in panel (2805) | OK |
| 3–21 | purity rule | T3 → T21 purity grep (32449) | OK |
| 4–5 | kit CHANGELOG; `PlanKit.types/tools/propertyIds`, `isCodeId` | T4 (3566-3568) → T5 `conformance` R3 (5779) | OK |
| 4–6 | contract API | T4 Produces (3556-3568) → T6 test kits + `validateKitSet` (7516) | OK |
| 4–7 | `KitDiagnostic`, `kitMissing`/`kitNewer` | T4 (3565) → T7 `checkManifest` (9372) | OK |
| 4–8 | `PlanType`, `PlanToolSettings.fieldsOf(…, toolId:)`, `PlanServices`, `KitNamesWords`, `Disposable` | T4 → T8 (10229) | OK (R-d, R-e) |
| 4–9 | kit barrel; `PlanTool`, `KitWords` | T4 → T9 (13306, 14967); T9 appends `swatch.dart` export | OK |
| 4–10 | `PlanType`/`PlanTool`/`PlanKit` ctors | T4 → T10 box/ring kits (16247) | OK |
| 4–11 | `TypeGuard`, `registerInto(guard:)`, `AttachmentQuery` (required `mirrored`/`mayRotate`) | T4 (3557, 3564) → T11 (18416) | OK (reconcile row 52) |
| 4–12 | `PlanTool.needs` | T4 (3560) → T12 `_toolNeeds` (19835) | OK |
| 4–13 | `KitDiagnosticCode.library*`, `symbolDuplicate` | T4 (3565) → T13 loader (21966) | OK |
| 4–14 | attachment types, `PlanKit.attachments`, `Disposable` | T4 (3564, 3566) → T14 (21992, 23614) | OK |
| 4–16 | `PlanTool.letter`, `letterTaken` | T4 → T16 letter rule (24707); T4 has no letter check (25941) | OK |
| 4–17 | `PlanType` field/section API | T4 (3558-3559) → T17 (25963) | OK |
| 4–18 | `PlanKit`, `PlanType` | T4 → T18 mark kit (27886) | OK |
| 4–19 | `PlanType.exported` | T4 (3558) → T19 `omittedOf` (29185) | OK |
| 4–21 | contract | T4 → T21 check_kit_deps (32427) | OK |
| 5–9 | none | reference at 14378 is to a member list, not a T5 product | OK (no shared interface) |
| 5–13 | `SymbolComponent.retired`, `CatalogSymbol.retired` | T5 (5781) → T13 gallery hides retired (21967) | OK |
| 5–21 | sample kit bytes | T5 → T21 regen check (32453) | OK |
| 6–7 | barrel `lib/jet_cad_2d_plan.dart`, `test/support/harness.dart` | T6 `KitSet`, test-kit API, harness (7518-7523) → T7 consumes (9372), adds `planText` (9386); T7 rewrites barrel keeping `kit_set.dart` (10159-10170) | OK |
| 6–8 | barrel `lib/jet_cad_2d_plan.dart`, harness | T6 `KitSet`/`KitSetError` → T8 factory (10229); T8 adds `controllerFor` etc. (10246) | OK |
| 6–9 | barrel `lib/jet_cad_2d_plan.dart`, plan `pubspec.yaml` | T6 leaves `flutter_localizations` to T9 (7567) → T9 adds it (13289) | OK |
| 6–10 | barrel `lib/jet_cad_2d_plan.dart`; `KitSet.kitOf` | T6 → T10 `LockSet.scan` loaded predicate (16186), kits validate (16246) | OK |
| 6–11 | barrel `lib/jet_cad_2d_plan.dart`; throwing kit | T6 throwing kit/CI dry run (7527) → T11 failure tests | OK |
| 6–12 | barrel `lib/jet_cad_2d_plan.dart` | — | OK: each adds its own sorted export lines; no line added by both |
| 6–13 | barrel `lib/jet_cad_2d_plan.dart`; `KitSet.kits` | T6 → T13 loader over `kits.kits` (21968) | OK |
| 6–15 | barrel `lib/jet_cad_2d_plan.dart`; pubspec | T6 leaves dev deps to later (7567) → T15 adds none | OK |
| 6–16 | barrel `lib/jet_cad_2d_plan.dart`; `KitSet.kitOf` | T6 → T16 `planToolEntries` (25932) | OK |
| 6–17 | barrel `lib/jet_cad_2d_plan.dart` | — | OK: each adds its own sorted export lines; no line added by both |
| 6–18 | barrel `lib/jet_cad_2d_plan.dart` | T6 barrel order → T18 adds two lines (29097) | OK: each adds its own sorted export lines; no line added by both |
| 6–19 | barrel `lib/jet_cad_2d_plan.dart`, plan `pubspec.yaml` | T6 leaves `pdf`/`printing` to T19 (7567) → T19 Step 0 (29222); `unawaited_futures` lint (30793) | OK |
| 6–20 | barrel `lib/jet_cad_2d_plan.dart`, `README.md`, `CHANGELOG.md` | T6 creates README/CHANGELOG (7595); T6 exports `KitSetError`, `reservedKitIds` via `kit_set.dart` (7520-7521, 7621) → T20 rewrites barrel with `show` lists to ED-9's set (32226), which lacks both (31260) | **CONFLICT → F6** |
| 6–21 | `analysis_options.yaml` committed once; CI matrix | T6 (9333) → T21 Step 1 (32415), tool/ci (32425) | OK |
| 7–8 | barrel `lib/jet_cad_2d_plan.dart`, harness; `decodePlan`, `encodePlan`, `manifestOf`, `usedKits`, `checkManifest` | T7 (9374-9386) → T8 `_readManifest` (12733-12745), `save` (12634) | OK |
| 7–9 | barrel `lib/jet_cad_2d_plan.dart` | — | OK: each adds its own sorted export lines; no line added by both |
| 7–10 | barrel `lib/jet_cad_2d_plan.dart`; manifest keeps a missing kit | T7 → T10 L-1 (16245) | OK |
| 7–11 | barrel `lib/jet_cad_2d_plan.dart`; `decodePlan(diagnostics:)`, `damagedUnsavable` | T7 (9382, 9766) → T11 (16267, 18415) | OK |
| 7–12 | barrel `lib/jet_cad_2d_plan.dart` | — | OK: each adds its own sorted export lines; no line added by both |
| 7–13 | barrel `lib/jet_cad_2d_plan.dart` | — | OK: each adds its own sorted export lines; no line added by both |
| 7–15 | barrel `lib/jet_cad_2d_plan.dart`; `ensureManifest` | T7 (9384) → T15 canvas fixture (23647, 23718) | OK |
| 7–16 | barrel `lib/jet_cad_2d_plan.dart` | reference at 25672 is to another plan's task | OK: each adds its own sorted export lines; no line added by both |
| 7–17 | barrel `lib/jet_cad_2d_plan.dart` | — | OK: each adds its own sorted export lines; no line added by both |
| 7–18 | barrel `lib/jet_cad_2d_plan.dart` | — | OK: each adds its own sorted export lines; no line added by both |
| 7–19 | barrel `lib/jet_cad_2d_plan.dart`; `ensureManifest`, `PlanFormatException` | T7 → T19 import flow (29185, 30788) | OK |
| 7–20 | barrel `lib/jet_cad_2d_plan.dart` | T7 exports `ManifestCheck`, `checkManifest`, `kPlanFormat`, `manifestOf`, `manifestToWrite`, `usedKits` (10159-10167) and plan_file.dart's `decodePlan`, `encodePlan`, `ensureManifest` (10168; 9382-9384) → ED-9 set (31261) lists only `PlanFormatException`, `PlanFormatCode`, `PlanManifest` | **CONFLICT → F6** |
| 7–21 | PF tests | T7 → T21 coverage row P4 file | OK |
| 8–9 | barrel `lib/jet_cad_2d_plan.dart`, `new_plan.dart`, `plan_controller.dart`; `locale`, `reportLocale` | T8 `ValueListenable<Locale> locale` + `@internal reportLocale(Locale)` (10239-10240), `decimalSeparatorFor` → T9 `push` reports (13305), adds `{PlanStrings? strings}` (13292, 14890) | OK (reconcile rows 28, 44, 139) |
| 8–10 | barrel `lib/jet_cad_2d_plan.dart`, `plan_controller.dart`, `session.dart` | T8 builds views in `DocumentSession` ctor (12232-12261), disposes it one frame after a swap (`_drop`, 12777-12784) → T10 Step 5 writes `_locks`/`_lockExpander`/`_lockGates` as controller `late` fields with "per-document teardown" disposal (16151-16154, 16195) and scans locks "after install" though the GripCache built earlier needs them (16185-16194) | **CONFLICT → F1, F4** |
| 8–11 | barrel `lib/jet_cad_2d_plan.dart`, `diagnostics_log.dart`, `plan_controller.dart`, `session.dart` | T8 `DiagnosticsLog` (`report`, `reportAll`, `clearPlanScoped`, 11658-11693) → T11 merged class keeps them, adds dedupe (18092-18182); T8 session/`_open` → T11 `_boundary` controller field (18263) per document | DiagnosticsLog OK; `_boundary` → **F1** |
| 8–12 | barrel `lib/jet_cad_2d_plan.dart`, `plan_controller.dart`, `session.dart` | T8 session owns `select` (12276), map `_entries`/`addTool` (12286-12294), deferred dispose → T12 Step 10 controller-level `_gates`/`_generic` (19679-19680), "initial tool is `_generic.select`" (19696), `_generic.dispose()` (19697) | **CONFLICT → F1, F2, F3** |
| 8–13 | barrel `lib/jet_cad_2d_plan.dart`, `plan_controller.dart` | T8 `thumbnails`, `_ownsThumbnails`, `_symbolsState` ready (12563-12566, 12595) → T13 adds loader, `symbols` param only (21969) | OK (reconcile rows 40, 108-110) |
| 8–14 | `plan_controller.dart`, `session.dart`; `servicesOf`, `DocumentSession.attachments` | T8 `attachments = NoAttachments` on session (12282), `disposeKitProducts` reserved for attachment providers (12328) → T14 controller `late _attachments`/`_symbolTool` (23512-23513), disposed "per-document" after the ToolController (23542) | **CONFLICT → F1, F2** |
| 8–15 | barrel `lib/jet_cad_2d_plan.dart`; camera plumbing, `snappingAllowed`, `snap` | T8 Produces (10238-10240), `_userSnap` (12585) → T15 (24679); T15 adds `textTool` to `plan_controller.dart` (24144) | OK (depends on F1 for `_generic`) |
| 8–16 | barrel `lib/jet_cad_2d_plan.dart`, `plan_controller.dart`; `kits`, `diagnosticsLog`, `snappingAllowed` | T8 → T16 (25933, 25390) | OK |
| 8–17 | barrel `lib/jet_cad_2d_plan.dart`; `registerSettle`, `toolSettings`, `kits`, `diagnosticsLog` | T8 (10240, 11829) → T17 (27853) | OK (reconcile rows 29, 91-93) |
| 8–18 | barrel `lib/jet_cad_2d_plan.dart`; `catalog`, `registerSettle`, `settlePendingInput` | T8 → T18 (29151); `panelShows` sent to T20 (10266) | OK |
| 8–19 | barrel `lib/jet_cad_2d_plan.dart`, `plan_controller.dart`, `registries.dart`, `plan_controller_test.dart` | T8 `PlanExporter`/`PlanImporter`/`const PlanExportRequest` (11518-11553), `exporters` stored (12512) → T19 replaces `registries.dart` body (29886), edits C13 (30488) | OK (R-k; C13 change listed). Files omission → **F9** |
| 8–20 | barrel `lib/jet_cad_2d_plan.dart`; NS2 + `panelShows` hand-off | T8 (10266) → T20 `editor_separator_test.dart` (30813); T8 exports `kPlanMinScale`, `kPlanMaxScale` (13179), `kPlanThumbnailCapacity` (via `plan_controller.dart`, 13187) → missing from ED-9 (31263) | hand-off OK; barrel **F6** |
| 8–21 | controller tests | T8 → T21 coverage rows P1/P2 | OK |
| 9–10 | barrel `lib/jet_cad_2d_plan.dart`, `plan_controller.dart` | different members (`reportLocale` vs locks) | OK |
| 9–11 | barrel `lib/jet_cad_2d_plan.dart`, `plan_controller.dart`; `sectionFailed` | T9 (13323) → T11 `KitSectionBoundary` (18419) | OK |
| 9–12 | barrel `lib/jet_cad_2d_plan.dart`, `plan_controller.dart` | different members | OK |
| 9–13 | barrel `lib/jet_cad_2d_plan.dart`, `plan_controller.dart`; `PlanStrings` gallery words, `searchFold` | T9 `lib/src/l10n/strings.dart`, `search_fold.dart` (13281, 13317) → T13 imports, does not re-port SF (19850) | OK (reconcile rows 53, 69-70) |
| 9–14 | `plan_controller.dart` | different members | OK |
| 9–15 | barrel `lib/jet_cad_2d_plan.dart`; `PlanStrings.lockedHint`, `PlanLocaleScope`, `PlanTheme.of`, `planPaperPaletteFor`; `plan_controller.dart` (T15 prose) | T9 (13316-13323) → T15 (24680) | OK |
| 9–16 | barrel `lib/jet_cad_2d_plan.dart`, `plan_controller.dart`; tool words | T9 → T16 (25934) | OK |
| 9–17 | barrel `lib/jet_cad_2d_plan.dart`; `PlanSwatch`, panel number helpers, words | T9 (13309, 13316) → T17 (25964) | OK (R-h, R-i) |
| 9–18 | barrel `lib/jet_cad_2d_plan.dart`, `strings*.dart` ×4, `value_words_test.dart` | T9 creates words + `expectWorded` (13493) → T18 appends `lockedNoLayer` + LP-W (28547-28554) | OK (append) |
| 9–19 | barrel `lib/jet_cad_2d_plan.dart`, `plan_controller.dart`, `pubspec.yaml`; `kPlanFontAsset`, export words | T9 (13322) → T19 (30790) | OK |
| 9–20 | barrel `lib/jet_cad_2d_plan.dart`, `strings*.dart` ×4, `value_words_test.dart`; `PlanThemeScope` | T9 → T20 adds 4 words + ED-W after LP-W (31417-31435); `RecordingPlanStrings` created by T20 (30811) | OK (reconcile rows 54, 121). Files omission → **F9** |
| 9–21 | fonts in publish file list | T9 → T21 (32441) | OK |
| 10–11 | barrel `lib/jet_cad_2d_plan.dart`, `plan_controller.dart`, `session.dart`, `locks.dart` | T10 `LockExpander._expand`, `_LockCheck`, `lockBroken` (14995-14996) → T11 replaces `_expand`/`apply`, adds hooks (18189-18212), `_damage` uses `_locks` (18298) | `locks.dart` OK; per-document fields **F1** |
| 10–12 | barrel `lib/jet_cad_2d_plan.dart`, `plan_controller.dart`, `session.dart`; select gates | T10 `LockGates` (16085-16135) wired to GripCache and select (16193-16194) → T12 `PlanSelectGates` re-implements the same scan (19451-19514), replaces the gates (19686), leaves `_lockGates` built/disposed | **CONFLICT → F5** (and F1) |
| 10–13 | barrel `lib/jet_cad_2d_plan.dart`, `plan_controller.dart` | different members | OK |
| 10–14 | `plan_controller.dart`, `session.dart` | both add per-document controller fields | **F1** (same pattern) |
| 10–15 | barrel `lib/jet_cad_2d_plan.dart`; `locked` | T10 → T15 (23648) | OK |
| 10–16 | barrel `lib/jet_cad_2d_plan.dart`, `plan_controller.dart` | different members | OK |
| 10–17 | barrel `lib/jet_cad_2d_plan.dart`; `locked`, `isLocked`; `box_kit.dart` vs `panel_kits.dart` | T10 (14994) → T17 (27854); T17 fixture renamed to avoid T10's file (25954) | OK (reconcile row 55) |
| 10–18 | barrel `lib/jet_cad_2d_plan.dart`; `isLocked`, `lockBroken` | T10 → T18 (29153) | OK |
| 10–19 | barrel `lib/jet_cad_2d_plan.dart`, `plan_controller.dart` | different members | OK |
| 10–20 | barrel `lib/jet_cad_2d_plan.dart` | T10 exports `PlanLocked` → ED-9 has it (31271) | OK: each adds its own sorted export lines; no line added by both |
| 10–21 | Review Focus 1 test | T10 pins it as `L-1` (15494) → T21 coverage row names `L-round-trip` (32572) | **CONFLICT → F7** |
| 11–12 | barrel `lib/jet_cad_2d_plan.dart`, `plan_controller.dart`, `session.dart`; `GuardedTool` wraps every tool | T11 wraps map tools; `GuardedTool.dispose` disposes `inner` (17781-17784) → T12 relies on it (19841) and also disposes `_generic` itself (19697) | **CONFLICT → F2** |
| 11–13 | barrel `lib/jet_cad_2d_plan.dart`, `plan_controller.dart`; `_diagnostics.add` | T11 `add` (18127) → T13 `_loadSymbols` (21969) | OK |
| 11–14 | `plan_controller.dart`, `session.dart`; `guardAttachment(…, report)`, GuardedTool | T11 (16274) → T14 `_ask` (21995); T14 `_symbolTool.dispose()` on a wrapped tool (23542) | `guardAttachment` OK; **F2** |
| 11–15 | barrel `lib/jet_cad_2d_plan.dart`; `lockHint`, `GuardedTool.inner` | T11 (16273) → T15 (24681) | OK |
| 11–16 | barrel `lib/jet_cad_2d_plan.dart`, `plan_controller.dart`; `isToolDisabled`, dedupe | T11 → T16 (25390, 25935) | OK |
| 11–17 | barrel `lib/jet_cad_2d_plan.dart`; `execute` → bool, `KitSectionBoundary` | T11 (16273, 16275) → T17 (27855) | OK (R-b; reconcile rows 48, 94) |
| 11–18 | barrel `lib/jet_cad_2d_plan.dart`; `execute` → bool | T11 → T18 (29154) | OK (R-b) |
| 11–19 | barrel `lib/jet_cad_2d_plan.dart`, `plan_controller.dart` | different members | OK |
| 11–20 | barrel `lib/jet_cad_2d_plan.dart`; `ValueListenable<bool> damaged` | T11 (16273) → T20 bar (32387) | OK |
| 11–21 | Review Focus 2 test; allocation | T11 pins `F-2` (16649) → T21 row names `F-neighbour` (32573); T21 checks `query_allocation_test` (32434) | **CONFLICT → F7** |
| 12–13 | barrel `lib/jet_cad_2d_plan.dart`, `plan_controller.dart`; `permissions`, `PlanToolIds`, `tool_events.dart` | T12 (18454-18456, 18437) → T13 (21971) | OK |
| 12–14 | `plan_controller.dart`, `session.dart`; `buildGenericTools(moveResolver:)`, `registerToolNeeds` | T12 (18455-18456) → T14 Step 13.3 (23521) | names OK; **F1, F2** |
| 12–15 | barrel `lib/jet_cad_2d_plan.dart`; `_generic.byId`, `toolController` | T12 controller field `_generic` (19680) → T15 `textTool => _generic.byId[...]` (24150) | OK as written; must follow the F1 ruling (`_session.generic`) |
| 12–16 | barrel `lib/jet_cad_2d_plan.dart`, `plan_controller.dart`; `selectGates.idleKeys`, `fill`, `needsOf`, `genericTools` | T12 (19715-19722, 19475) → T16 (25936) | OK |
| 12–17 | barrel `lib/jet_cad_2d_plan.dart`; `PlanPermissions` | T12 → T17 (27856) | OK |
| 12–18 | barrel `lib/jet_cad_2d_plan.dart`; `editLayers`, `editPage`, `changeLayer` | T12 → T18 (29155) | OK |
| 12–19 | barrel `lib/jet_cad_2d_plan.dart`, `plan_controller.dart`; `export`, `print` | T12 → T19 (30791) | OK |
| 12–20 | barrel `lib/jet_cad_2d_plan.dart`; `readOnly`, `allowsTool`, editor-options cases sent to T20 | T12 (18470) → T20 `editor_options_test.dart` (31324-31326) | OK |
| 12–21 | PM tests | T12 → T21 coverage | OK |
| 13–14 | `plan_controller.dart`, `plan_symbol_gallery_test.dart`; `placeSymbol`, `armedSymbol`, fixtures | T13 (19870-19875) → T14 (21993, 23618); T14 appends the highlight test (21986) | OK |
| 13–15 | barrel `lib/jet_cad_2d_plan.dart`; gallery field guard order | T13 field stops keys itself (24686) | OK (R-l) |
| 13–16 | barrel `lib/jet_cad_2d_plan.dart`, `plan_controller.dart` | gallery not re-wrapped (25941) | OK |
| 13–17 | barrel `lib/jet_cad_2d_plan.dart`; `PanelFieldFocusNode`, `placeSymbol`, `definitionForEntry`, SS9 hand-off | T13 creates `panel_focus.dart` (19854) → T17 imports (25965); SS9 ported in T13 (19896) | OK |
| 13–18 | barrel `lib/jet_cad_2d_plan.dart`; `PanelFieldFocusNode` | T13 → T18 (29157) | OK |
| 13–19 | barrel `lib/jet_cad_2d_plan.dart`, `plan_controller.dart` | different members | OK |
| 13–20 | barrel `lib/jet_cad_2d_plan.dart`; `PlanSymbolGallery(filter:, query:)` | T13 (19873) → T20 (30820); ED-9 lists T13 names (31273) | OK |
| 13–21 | S-late-fail | T13 `S-10 S-late-fail` (20781) → T21 row `S-late-fail` | OK (grep finds it) |
| 14–15 | `plan_controller.dart` (T15 by prose) | different members | OK |
| 14–16 | `plan_controller.dart` | different members | OK |
| 14–17 | `symbol_box.dart` | T14 (22002) → T17 (25966, 27858) | OK |
| 14–19 | `plan_controller.dart` | different members | OK |
| 14–20 | none exported | T14 exports nothing (21997); ED-9 has no T14 row | OK |
| 14–21 | AT tests | T14 → T21 coverage | OK |
| 15–16 | barrel `lib/jet_cad_2d_plan.dart`, `plan_shortcut_guard.dart`; `PlanCanvas`, guard, chords, `canvas_fixture.dart`, `textTool` | T15 (23650-23654) → T16 widens `planLetterKeys` (24696), exports `PlanShortcutGuard` (25839) | OK (R-l) |
| 15–17 | barrel `lib/jet_cad_2d_plan.dart`; `PlanCanvas`, `PlanShortcutGuard`, `canvas_fixture.dart` | T15 → T17 (25967) | OK |
| 15–18 | barrel `lib/jet_cad_2d_plan.dart`; guard, chords, `canvas_fixture.dart` (`pumpThemed`, `blueprint`) | T15 (port of `palette_fixture.dart`) → T18 (29156) | OK |
| 15–19 | barrel `lib/jet_cad_2d_plan.dart`; theme canvas test hand-off | T9→T15 `theme_canvas_test.dart` (24607) | OK |
| 15–20 | barrel `lib/jet_cad_2d_plan.dart`; `PlanCanvas(...)`, chords, `PlanTextKeys` | T15 (23650-23654) → T20 (30819); ED-9 has `PlanCanvas`, `kLockHintDuration` | OK |
| 15–21 | CV-alloc invariant | T15 → T21 (32452) | OK |
| 16–17 | barrel `lib/jet_cad_2d_plan.dart`; `stamp_kit.dart`, `design_harness.dart`, `planToolEntries` | T16 (24699) → T17 (25967, 27859) | OK |
| 16–18 | barrel `lib/jet_cad_2d_plan.dart`; letters in use, design harness | T16 → T18 (28531, 29156) | OK |
| 16–19 | barrel `lib/jet_cad_2d_plan.dart`, `plan_controller.dart` | different members | OK |
| 16–20 | barrel `lib/jet_cad_2d_plan.dart`; `PlanToolPalette`, `PlanShortcuts`, `planToolLabel` | T16 (24713-24716) → T20 (32389); T16 exports `PlanShortcutGuard` (24715, 25839) → absent from ED-9 (31276) | names OK; barrel **F6** |
| 16–21 | KB tests | T16 → T21 coverage | OK |
| 17–18 | barrel `lib/jet_cad_2d_plan.dart`, `plan_property_panel.dart`, `colour_row_test.dart`; slot `propertyPanelLayerField`; SE13/15/16, CP1 hand-offs | T17 slot null (25971), CP1 assertion moved (27794) → T18 fills slot (28937-28942), restores CP1 (28945), ports SE13/15/16 (28531) | OK (R-g, R-m) |
| 17–19 | barrel `lib/jet_cad_2d_plan.dart` | — | OK: each adds its own sorted export lines; no line added by both |
| 17–20 | barrel `lib/jet_cad_2d_plan.dart`; `PlanPropertyPanel` | T17 (25970) → T20 (32390) | OK |
| 17–21 | P tests | T17 → T21 coverage | OK |
| 18–19 | barrel `lib/jet_cad_2d_plan.dart`; `mark_kit.dart`, `layer_plan.dart` | T18 (27878-27879) → T19 (29189, 30792) | OK |
| 18–20 | barrel `lib/jet_cad_2d_plan.dart`, `strings*.dart` ×4, `value_words_test.dart`; panels, `mark_kit.dart` | T18 → T20 (30821); ED-W placed after LP-W (31428) | OK |
| 18–21 | LP tests | T18 → T21 coverage | OK |
| 19–20 | barrel `lib/jet_cad_2d_plan.dart`; `EditorPageFlows`, `PlanExportDialog`, `PagePrinter`, `flows_bar.dart` | T19 (29203-29208, 29354) → T20 (30821); ED-9 T19 names match T19 show list (30729-30740) | OK |
| 19–21 | publish file list (font for PDF) | T19 → T21 (32441) | OK |
| 20–21 | example, README, CHANGELOG; ED tests | T20 → T21 dry run (32441-32442) | OK |

## 2. Each task against itself

| Task | Tests ↔ code (names, signatures, imports) | Files created/modified ↔ staged | Mutations ↔ tests | Gates ↔ packages touched | Finding |
|---|---|---|---|---|---|
| 1 | 3 test files, 10 tests (E1-*, E3-*, E4-1…6) name exactly the Step 5-9 members (`typeIds`, `typeIdOf`, `PartialMutationError`, `loadJson(diagnostics:)`, `keepUnreadableComponents`); imports resolve | Files (257-260) = `git add` (977) | 18, all targets exist | engine gate (959-963) + kit, flutter, gpu, floor_plan, restaurant_symbols unchanged (965-970) | OK |
| 2 | `frozen_test`, `probe_test`, `frozen_clients.dart`; `isFrozen`, `probe` match Produces (1037-1038) | Files (1021-1024) = `git add` (2044) | 18; `E2-P2 … <hook>` rows run by full name (2087) | engine gate + allocation (2027-2032), floor_plan/flutter/kit (2034-2037) | OK (gpu/restaurant_symbols not re-run here; T21 runs gpu — info) |
| 3 | 22 tests; specs and `ColourTarget` match Produces (2103-2116); purity P9 | Files (2093-2096) = `git add` (3166) | `--plain-name` targets all resolve | kit gate | OK |
| 4 | 27 tests; `PlanType`/`PlanTool`/`PlanServices`/attachment/diagnostic match Produces (3556-3568) | Files (3542-3545) = `git add` (5315); `pub get` + `git status` (3587) | all resolve | kit gate + `check_kit_deps` (5310) | OK |
| 5 | 18 tests; helper-built names (`outline('R7-1 …')`, `loads(…)`) back `C7 `, `F0 `, `R7-1…3 `, `V11c ` targets | Files (5771-5774) = `git add` (7136) | all resolve | kit gate | OK — V11c/d/e (own tests, not ported) changed under a stated plan decision (5790) |
| 6 | 12 tests; `KitSet`, `validateKitSet`, `KitSetError`, `reservedKitIds` | Files (7508-7513) = `git add` (9333); `analysis_options.yaml` staged once by path | 9, resolve | plan gate + `tool/ci` (CI changed) + publish dry run (9349) | OK |
| 7 | 10 tests (`PF-*`); `decodePlan` passes `keepUnreadableComponents: true` (10060) | Files (9366-9369) = `git add` (10182) | 17, resolve (M-PF-unreadable 10204) | plan gate | OK |
| 8 | 29 named tests; Produces (10230-10246) match code (`_userSnap` 12585, `DiagnosticsLog` 11658) | Files (10223-10226) = `git add` (13199) | 50; unresolved tokens are expected-error types, not ids | plan gate | OK |
| 9 | 38 tests incl. NS7a/NS7 (13297); `reportLocale(…, {strings})` (14890) | Files (13278-13299) = `git add` (14919) | 24, resolve (M-NS7 14943) | kit + plan gates | OK; kit CHANGELOG not updated → F13 |
| 10 | 10 tests; `LockSet`/`LockExpander`/`LockGates` match Produces (14993-14996) | Files (14979-14982) = `git add` (16204) | 16; M-L6e/M-L6f name `session.dart` (16231-16232) | plan gate | **Inconsistent**: Step 5 (16167-16195) puts `_locks`, `_lockExpander`, `_lockGates` on the controller and disposes them in "Task 8's per-document teardown"; its own mutations and "Assumed" (16243) put them in `session.dart`; lock scan ordered after `install()` though the GripCache built before it needs `_locks` → F1, F4 |
| 11 | 33 tests (F-1…F-9, guard tests); `execute` → bool (18273), merged `DiagnosticsLog` (18092-18182) | Files (16255-16258) = `git add` (18362) | 27, resolve | plan gate + engine allocation (18355) | `_boundary` controller field (18263) vs "Assumed" session note (18413) → F1 |
| 12 | 20 tests; `PlanPermissions`, `PlanSelectGates`, `GenericToolSet` match Produces (18449-18456) | Files list `session.dart` (18434) but Step 10 edits only `plan_controller.dart` (19664) | 17, resolve | plan gate | **Inconsistent** Files vs Step 10; → F1, F2, F3, F5 |
| 13 | 36 tests; loader/gallery names match Produces (19870-19875); imports resolve | Files (19847-19859) = `git add` (21924) | 19, resolve | plan gate | S-13 has no `expect` → F12; ported literals change → F11 |
| 14 | 24 tests; registry/tool/resolver signatures match Produces (21998-22002) | Files (21977-21986) = `git add` (23574) | 18, resolve (M-AT14 names `plan_controller.dart`, 23606) | plan gate | self-consistent; cross-task F1, F2 |
| 15 | 8 new tests + ported files; `textTool` (24150), `PlanCanvas` options | Files list `plan_controller.dart` (23634); bash `git add` (24636) omits it, prose adds it (24639) | 13, resolve (`M-DT-12` is a ported test's name) | plan gate | → F9 |
| 16 | 10 tests (KB-1…10); `PlanToolPalette`, `PlanShortcuts` match Produces (24713-24716) | Files (24692-24701) = `git add` (25890) | 18, resolve (`A4`, `A8` are ported names) | plan gate | OK |
| 17 | 9 tests + ported; slot `propertyPanelLayerField` declared (25971) | Files (25947-25956) = `git add` (27812) | 19, resolve (SE11, CP3/4, HR1, SS1/7 ported names) | plan gate | OK |
| 18 | 9 tests (LP-1…8, LP-W) + ported; fills slot (28939-28942) | Files (27869-27882) = `git add` (29111) | 13, resolve (M-LP-slot → CP1 restored at 28945) | plan gate | OK |
| 19 | 9 tests (X-1…9) + ported; registries body replaced (29886) | Files (29168-29181) omit `test/controller/plan_controller_test.dart`, edited in Step 8.5 (30488) and staged (30751) | 14, resolve | plan gate | → F9 |
| 20 | 12 tests (ED-1…9b, ED-W, ED-README); ED-9 set (31257-31287) contradicts its own plan decision (30842) | Files (30803-30814) omit `test/l10n/value_words_test.dart` (ED-W, 31428; staged 32351) | 14, resolve | plan gate | → F6, F9 |
| 21 | no code; template coverage rows name `L-round-trip`, `F-neighbour` (32572-32573) | Files (32403-32405) = `git add` | none (no code) | every package + tool/ci + check scripts + dry runs (32417-32443) | → F7 |

## 3. What a reviewer would treat as a defect if the plan is followed as written

1. **A double dispose that asserts** (F2): generic tools and `plan.symbol` are disposed by the session's map (`DocumentSession.dispose`, 12357-12359, through `GuardedTool.dispose` → `inner.dispose()`, 17781-17784) and again by `_generic.dispose()` (19697, `GenericToolSet.dispose` 19636-19640) / `_symbolTool.dispose()` (23542). `Tool` extends `ChangeNotifier` (`jet_cad_2d_flutter/lib/src/tool.dart`), whose second `dispose` fails a debug assertion: every swap test after Task 12 would go red.
2. **Verbatim duplicated logic** (F5): `PlanSelectGates._recompute` (19477-19496) is `LockGates._recompute` (16103-16120) line for line, and `LockGates` stays in `locks.dart` wired to nothing after Task 12.
3. **Dead, mis-timed per-document state** (F1): controller-level `late` fields disposed in the deferred session teardown dispose the live document's lock expander, gates, registry and tools one frame after `load`/`newPlan` and leak the old ones; spec P1 "Lifetimes" (spec:194-200) requires the previous document's attachment providers to be disposed *before* the factories run again.
4. **A second, ungated `plan.select`** (F3): Task 8's session keeps its own `SelectTool()` as `plan.select` (12257, 12276); Task 12 adds `_generic.select` without removing it, and `toolById` returns the first (12313-12318) — Escape/V would arm a select tool that ignores permissions and locks (spec P2 "Permissions": select gates are the enforcement point).
5. **A test that is red as written** (F6): ED-9 omits 15 names Tasks 6, 7, 8 and 16 export.
6. **A test that asserts nothing explicit** (F12): S-13 (20883-20895).
7. **A ported test whose expected values change without a departure line** (F11): Task 13's gallery-model ports (`chair.wingback@1` → `fixture.chair.wingback@1`, 20504-20510 vs `jet_cad_floor_plan/test/symbols/symbol_search_test.dart:174-182`) under "assertions unchanged" (19887).
8. **Global Constraints contradict each other** (F8): line 24 has the Flutter layer's CHANGELOG gain `## Unreleased`; line 33 and T21 Step 6 (32451) say `jet_cad_2d_flutter` does not change.

Checked and clean: no `git add -A`/`git add .`/`commit -a` anywhere; the only staged `analysis_options.yaml` is Task 6's new one, by path (9333), and T21 verifies it is the only one (32415); no task creates or modifies a file under `packages/jet_cad_2d_flutter`, `jet_cad_floor_plan`, `jet_cad_restaurant_symbols`, `jet_cad_2d_gpu` or `apps/` (only gate runs there); `packages/jet_cad_2d` is staged only by Tasks 1-2; every task runs Commit before Mutation; no `/tmp` restore or stash; every `pub get` is followed by `git status --short` (3587, 13486, 29222); `pubspec.lock` is git-ignored, so dependency additions leave the tree clean. Ported-assertion moves that *are* listed: NS3, `panelShows`, NS2 (10266), CP1 `layer-picker` (27794 → 28945), SE13/15/16 (→ 28531), C13 (a Task 8 test, not ported, 30488), V11c-e (own tests, 5790).

## 4. Findings and proposed rulings (spec is the authority; smallest change)

**F1 (high) — per-document state on the controller, disposed in the deferred session teardown.** Task 8 builds every view in the `DocumentSession` constructor (12232-12261) and disposes the old session one frame after a swap (`_replace` → `_drop`, 12751-12784). Tasks 10 (16151-16154, 16186-16195), 11 (`_boundary`, 18263, 18313), 12 (`_gates`, `_generic`, 19679-19697) and 14 (`_attachments`, `_symbolTool`, 23512-23542) declare controller `late` fields, reassign them in the next `_open`, and dispose them "in the per-document dispose". The reconciliation only appended `session.dart` to Files and an "Assumed" note (16243, 18413). Consequences: the live document's expander/gates/registry/tools are disposed after one frame, the old ones leak; Task 14's attachment providers are disposed after the new ones are made, against spec P1 "Lifetimes" step 2 (spec:194-200) and Task 8's own comment (12328-12329).
*Ruling:* these are `DocumentSession` members (`locks`, `lockExpander`, `boundary`, `gates`, `generic`, `attachments`, `symbolTool`), built in the session constructor in the order the steps give and disposed in `DocumentSession.dispose()`; the attachment registry is disposed in `disposeKitProducts()` (spec P1 step 2). The controller reads them through `_session`; `locked` (the notifier), `_permissions`, `_fill`, `_toolNeeds`, `_disabledTools`, `lockHint`, `_damaged` stay controller-level. Edit T10 Step 5, T11 Step 5.4, T12 Step 10.3, T14 Step 13.1-13.4 accordingly; T15 Step 5 becomes `_session.generic.byId[PlanToolIds.text]`; M-AT14 (23606) names `session.dart`.

**F2 (high) — tools disposed twice.** See §3.1. *Ruling:* the session's tool map owns every tool it holds (spec P1: tools disposed with their document). Delete `_generic.dispose()` from T12 (19697) and `GenericToolSet.dispose` (19636-19640) or never call it; delete `_symbolTool.dispose()` from T14 Step 13.4 (23542). M-AT14 keeps its target (`_attachments.dispose()`).

**F3 (high) — two `plan.select` tools.** See §3.4. Task 10's "the `plan.select` `SelectTool` gets `gates: _lockGates`" (16194) and Task 8's `_replace` (`old.tools.activate(old.select)`, 12755) also address the session's own select. *Ruling:* from Task 12 on, the session has one select: `DocumentSession` takes the gates and the generic set (or a builder) in its constructor, `select` is `generic.select`, the `_entries` row for `plan.select` is the generic one (wrapped per Task 11), `ToolController(initial:)` and `_replace` use it. State this in T12 Step 10.3.

**F4 (medium) — Task 10's build order cannot run against Task 8's constructor.** T10 Step 5.2 (16185-16194) scans the `LockSet` "right after `ParametricSystem.install()`" but hands it to the GripCache (`LockedGrips(_locks, dispatch)`), which Task 8 builds earlier (12247); Task 8 installs the system last on purpose (12258). Literal execution: `LateInitializationError`. *Ruling:* `LockSet.scan` first (it only reads the document), then selection → `LockGates` → outlines → GripCache with `LockedGrips`, then `install()`, then `LockExpander(...)..install()` (it stacks after the system, spec P2 "It owns").

**F5 (medium) — `PlanSelectGates` duplicates `LockGates`; `LockGates` is left dead.** 16085-16135 vs 19451-19514; T12 replaces the gates (19686) but leaves T10's `_lockGates` build and dispose (16193, 16195). *Ruling:* make `LockGates` a `base class`; `PlanSelectGates extends LockGates` and overrides `move/rotate/reshape/delete` as `_permissions().x && super.x`; T12 removes `_lockGates` from the build/teardown (the session's `gates` is the `PlanSelectGates`). L-10 and PM-* stay; M-PM9b retargets `LockGates.move` (still turns PM-9 red).

**F6 (medium) — ED-9's expected barrel set is red as written.** ED-9 (31257-31287) lacks `KitSetError`, `reservedKitIds` (T6, 7520-7521, exported via `kit_set.dart` 7621/10170); `ManifestCheck`, `checkManifest`, `kPlanFormat`, `manifestOf`, `manifestToWrite`, `usedKits` (T7 show list 10159-10167) and `decodePlan`, `encodePlan`, `ensureManifest` (T7 `plan_file.dart` 10168, Produces 9382-9384); `kPlanMinScale`, `kPlanMaxScale` (T8 13179), `kPlanThumbnailCapacity` (T8 `plan_controller.dart` exported whole, 13187; 10244); `PlanShortcutGuard` (T16 24715, 25839). T20's own plan decision (30842) says the earlier block wins. *Ruling:* add these 15 names to ED-9 now and list them in T20 Step 7's show lists; no export is dropped (spec P7 maps today's public host API; nothing in the spec forbids them).

**F7 (medium) — Task 21 names test ids that no task defines.** Coverage rows `L-round-trip` and `F-neighbour` (32572-32573); the Review Focus pins are `L-1` (15494) and `F-2` (16649). Step 7's grep would write `missing` and raise findings against Tasks 10 and 11. *Ruling:* replace with `L-1` and `F-2`.

**F8 (low) — Global Constraints contradict on the Flutter layer's CHANGELOG.** Line 24 vs line 33 and T21 (32451); spec E: "The Flutter layer needs no change." *Ruling:* line 24 → "The engine's `CHANGELOG.md` gains an `## Unreleased` section naming E1-E4."

**F9 (low) — Files blocks that miss a staged file.** T19 Files (29168-29181) omit `test/controller/plan_controller_test.dart` (edited 30488, staged 30751); T20 Files (30803-30814) omit `test/l10n/value_words_test.dart` (ED-W, 31428; staged 32351); T15's bash `git add` (24636) omits `plan_controller.dart`, added only in prose (24639). *Ruling:* add each to its Files block; put T15's path inside the `git add` line.

**F10 (low) — the File structure block is stale.** 110-123: controller list lacks `session.dart`, `diagnostics_log.dart`, `new_plan.dart`, `camera_bounds.dart`; `guard.dart` is said to hold `DiagnosticsLog` (114; it is `controller/diagnostics_log.dart`, R-j); panels name `property_fields.dart` (121), which no task creates; export names `pdf_exporter.dart`, `png_exporter.dart`, `print.dart` (123) where T19 creates `builtin_exporters.dart`, `page_printer.dart`, `page_flows.dart`, `editor_page_flows.dart`, `export_font.dart`; Shared interfaces call `camera` `@internal` (244) while T8 makes it public (10238). *Ruling:* regenerate the block from the tasks' Files lists (the tasks win; spec "Package layout" is directory-level only).

**F11 (low) — ported expectations change with the fixture keys, without a departure line.** T13 gallery-model ports (20503-20540): expected ids and one query gain the `fixture.` kit prefix; only an in-file comment says so (20368); the port table claims "assertions unchanged" (19887). *Ruling:* add one departure line to T13's port table: "expected ids carry the kit prefix the kit format requires (a fixture key change, A12-allowed); no other literal changes."

**F12 (low) — S-13 has no explicit assertion.** 20883-20895 relies on an uncaught async debug assertion. *Ruling:* keep the test; after `settle()`, assert explicitly — e.g. collect errors with `runZonedGuarded` (or a `FlutterError.onError` hook) and `expect(errors, isEmpty)`; M-S13 still turns it red.

**F13 (low) — kit API grows without a CHANGELOG bullet.** T9 adds `PlanSwatch`/`planSwatchNamed` to `jet_cad_2d_kit`'s barrel (13309, 13434) while T3, T4, T5 each add a bullet. *Ruling:* T9 appends one bullet to `packages/jet_cad_2d_kit/CHANGELOG.md` and stages it (14919).

Informational (no change): I1 — T2's dependents run omits `jet_cad_2d_gpu` and `jet_cad_restaurant_symbols` (2034-2037), which T1 ran (968-970); T21 Step 4 runs gpu. I2 — T1 widens E3 from the spec's two sites to four (spec:711-714 vs 274; Appendix ruling): additive, consistent with the spec's intent.

## Applied (2026-10-14, controller accepted F1-F13)

Edits made in place to `docs/superpowers/plans/2026-10-14-plan-library-2a.md` (uncommitted; the plan is now 32 768 lines). Line ranges below are the **new** plan lines; the line numbers in §1-§4 above refer to the plan before these edits.

- **F8** — Global Constraints, line 24: only the engine's `CHANGELOG.md` gains `## Unreleased`; the Flutter layer's is untouched.
- **F10** — File structure block regenerated from the tasks' Files lists, lines 81-165 (engine, kit, root, CI, every `jet_cad_2d_plan` lib file per task incl. `session.dart`, `diagnostics_log.dart`, `new_plan.dart`, `camera_bounds.dart`, the Task 19 export files and test support; `property_fields.dart`, `pdf_exporter.dart`, `png_exporter.dart`, `print.dart` removed). Shared interfaces, lines 280-288: `camera` is public; a new paragraph says per-document state lives in `DocumentSession` (the session members each task adds, `disposeKitProducts` for kit products, the map owns its tools).
- **F1 + F4, Task 10** — Step 5 rewritten, lines 16193-16280: `DocumentSession` gains `locks`, `lockExpander`, `lockGates` and constructor parameters `kitLoaded`, `locked`; build order is `LockSet.scan` first → selection → `LockGates` → outlines → `GripCache(objects: LockedGrips(locks, dispatch), gates: lockGates)` → `select = SelectTool(gates: lockGates)` → tools → `install()` → `LockExpander(...)..install()`; `select` becomes `late final`; `lockGates`/`lockExpander` disposed in `DocumentSession.dispose()`; the controller keeps only `_locked`, `locked`, `isLocked`/`lockBroken` via `_session.locks`, `_open` sets `_locked.value`. Files description at 15031; Assumed note at 16327; test comments at 15578 (M-L1c) and 15716 (M-L6e). Mutations retargeted: M-L1c (16307, `_open`), M-L6e (16315, `locks`), M-L6f (16316, `select = SelectTool(gates: lockGates)` → `SelectTool()`), M-L7 (16317, `_session.locks`).
- **F1 + F2 + F3 (guard side), Task 11** — Step 5 title at 18325; `_boundary` controller field removed; `_damage` uses `_session.locks` (18380); item 4 rewritten at 18387-18431: session constructor gains `log`, `guard`; `GripCache` objects `LockedGrips(locks, GuardedGrips(...))`; select entry guarded and the `ToolController` starts on it; `addTool` and `runKitFactories(kits, services, disabled)` guard every tool and grip factory; `late final FailureBoundary boundary` is a session member set in `_open`; `_guardTool` on the controller; `_replace` activates `old.toolById(planSelectToolId)!`; "nothing else disposes a tool". Mutations retargeted: M-F2, M-F4, M-F5, M-F6a (18490-18498, `session.boundary`), M-F8 (18501, `session.dart` `runKitFactories`). Assumed note 18518.
- **F5, Tasks 10 + 12** — `LockGates` is a `base class` (Produces 15046, code 16135, plan decision 15057). Task 12 Step 8 rewritten, lines 19535-19581: `PlanSelectGates extends LockGates` with the four getters `_permissions().x && super.x`, no copied scan. Plan decision at 18573. Mutations: M-PM8 (19895, `delete` → `super.delete`), M-PM9a → `locks.dart` `LockGates` ctor, M-PM9b (`move` → `_permissions().move`), M-PM10 (19897, `locks.dart` chain loop); test comment 19014.
- **F1 + F2 + F3, Task 12** — Step 10 retitled (19728); item 3 rewritten, lines 19740-19772: session `gates` (a `PlanSelectGates`, replacing Task 10's `lockGates`) and `generic`; `select = generic.select` (the session's only `plan.select`); the other generic tools added via `addTool` before kit tools; `gates.dispose()` in `dispose()`; **no** `generic.dispose()` (kept only for a set no session holds, the Step 4 unit test); `_open` sets the draft permissions, passes `permissions`/`fill`, registers needs. `_session.select` / `_session.gates` in the setter, getters and `deleteSelection` (19814, 19828, 19859). Assumed note 19914.
- **F1 + F2, Task 14** — Files description at 22068; Step 13 rewritten, lines 23590-23643: session gains `symbolTool`, `runAttachmentFactories(...)`, `addSymbolTool(...)`, constructor `moveResolver`, and disposes the registry in `disposeKitProducts()` (spec P1 step 2; matches AT-14, which expects the old providers disposed right after `newPlan()` with no frame); the controller keeps only `_moveResolver` (reads `_session.attachments`); no `_symbolTool.dispose()`. `_session.symbolTool.gatesChanged()` (23645), `_session.attachments.kinds` (23653). Mutations: M-AT14 (23707, `session.dart` `disposeKitProducts`), M-AT17b (wording), M-AT18 (23710, `_open`'s `DocumentSession(...)` call). Assumed note 23716.
- **F1, Task 15** — `textTool => _session.generic.byId[...]` (24245-24251); Assumed note 24778.
- **F9** — Task 15's `git add` now includes `plan_controller.dart` and the prose was removed (24737); Task 19 Files gain `test/controller/plan_controller_test.dart` (29278); Task 20 Files gain `test/l10n/value_words_test.dart` (30912).
- **F6, Task 20** — ED-9's set gains `KitSetError`, `reservedKitIds`, `ManifestCheck`, `checkManifest`, `kPlanFormat`, `manifestOf`, `manifestToWrite`, `usedKits`, `decodePlan`, `encodePlan`, `ensureManifest`, `kPlanMinScale`, `kPlanMaxScale`, `kPlanThumbnailCapacity`, `PlanShortcutGuard` (31357-31381). Step 7 gives explicit `show` lists for `plan_controller.dart`, `plan_file.dart`, `plan_format_exception.dart`, `kit_set.dart` and keeps Tasks 7, 8, 16's existing ones (32338-32350).
- **F7, Task 21** — coverage rows use `L-1` and `F-2` (32689-32690).
- **F11, Task 13** — a departure line under the port table (19974): the fixture keys gain the kit prefix, so the expected ids and one query follow; every matcher is the source's.
- **F12, Task 13** — S-13 runs inside `runZonedGuarded`, collects errors and asserts `expect(errors, isEmpty)` (20960-20979); M-S13 text updated (22036).
- **F13, Task 9** — a kit `CHANGELOG.md` bullet for `PlanSwatch`/`planSwatchNamed` after the barrel export (13480-13485); Files (13331) and `git add` (14969) include the file.

Unchanged on purpose: Task 8's own code and its mutation M-C-swap-c (`old.tools.activate(old.select)`, valid at Task 8); Task 11 changes that line later (18431). `GenericToolSet.dispose` remains (the Step 4 unit test owns a standalone set).
