### Task 3: The file layer and the app's words

**Files:**
- Create (copy from `apps/floor_planner/lib`): `document_files.dart`,
  `document_files_io.dart`, `document_files_web.dart`,
  `document_files_stub.dart`, `exit_guard.dart`, `exit_guard_web.dart`,
  `exit_guard_stub.dart`, `app_strings.dart`
- Create: `test/support/app_fakes.dart` (the old tests' in-memory
  `DocumentFiles` and `ExitGuard` fakes, moved from wherever the old tests
  define them: `apps/floor_planner/test/support/` and file-local helpers)
- Create (port): `test/document_files_test.dart`,
  `test/document_files_kind_test.dart`,
  `test/document_files_sources_test.dart`, `test/app_words_test.dart`

**Interfaces:**
- Produces (unchanged from the old app): `DocumentFiles`, `FileKind`
  (`jetplan`, `pdf`, `png`; `.extension`, `.label`, `.mimeType`),
  `kJetplanExtension`, `DocumentNamePrompt`, `FileTypeLabel`,
  `englishFileTypeLabel`, `createDocumentFiles({required DocumentNamePrompt
  askName, required FileTypeLabel typeLabel})`, `ExitGuard`,
  `createExitGuard()`, `AppStrings.of(context)`.
- `AppStrings` changes: drop `printFailed`; add `String get pageFlowFailed`
  — en "The page could not be exported or printed", de "Die Seite konnte
  nicht exportiert oder gedruckt werden", tr "Sayfa dışa aktarılamadı ya da
  yazdırılamadı". Every other word is the old app's.
- `AppStrings`' localization delegate (if the old app had one) is added to
  `MaterialApp.localizationsDelegates` in `main.dart` beside
  `planLocalizationsDelegates`.

- [ ] **Step 1:** Copy the files. Replace each `jet_cad_floor_plan` import
  with what the file actually uses: `FloorPlanStrings.cancel` →
  `PlanStrings.of(context)`'s cancel word if it has one (grep
  `packages/jet_cad_2d_plan/lib/src/l10n/strings.dart`), else an
  `AppStrings.cancel` word (en Cancel, de Abbrechen, tr İptal). N1 stays
  green.

- [ ] **Step 2: Port the four test files** per the audit's sections
  "document_files_test.dart", "document_files_kind_test.dart",
  "document_files_sources_test.dart", "app_words_test.dart": every row is
  PORT. Copy each case; change only imports and the app type
  (`FloorPlannerApp` → `ArchitectureDemoApp`). An `app_words_test` case
  that reads `printFailed` reads `pageFlowFailed` and its three words
  above; it keeps every other assertion (the de/tr words differ from en,
  no word empty, the file type labels).

- [ ] **Step 3: New case AW-pageflow:** `pageFlowFailed` in en/de/tr equals
  the three strings above. Mutation: the de word returns the en one.

- [ ] **Step 4:** Gates. Run each ported file once against a deliberate
  break of the code it covers (for example `FileKind.png.extension`
  returning `'jpg'`) and list the mutations and their red tests in the
  report. Revert each.

- [ ] **Step 5: Commit** `feat(demo): the file layer and the app's words, ported with their tests`.

---

