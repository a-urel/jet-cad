## Global Constraints

- **Names.** The new package is `jet_cad_2d_plan` at `packages/jet_cad_2d_plan`, barrel `package:jet_cad_2d_plan/jet_cad_2d_plan.dart`. The contract is `jet_cad_2d_kit`. Dart type names carry no `2d` (`PlanController`, `PlanKit`). The plan library's own tools are `plan.select`, `plan.line`, `plan.polyline`, `plan.rectangle`, `plan.circle`, `plan.arc`, `plan.text`, `plan.symbol`. `plan` and `jetcad` are reserved kit ids.
- **Versions and environment.**
  - `jet_cad_2d_plan`: `version: 0.8.0`, `resolution: workspace`, `sdk: ^3.6.0`, `flutter: ">=3.44.0"`.
  - `jet_cad_2d_kit` stays at 0.1.0 and gains `jet_cad_2d_flutter: ^0.7.2`.
  - The engine's and the Flutter layer's versions are **not** bumped here. Their `CHANGELOG.md` gains an `## Unreleased` section naming E1-E4; the wave (sub-project 4) picks the numbers.
  - **Plan decision:** dependency floors stay `^0.7.2` in this branch; the wave raises them to the released numbers.
- **Dependencies.**
  - `jet_cad_2d_plan` depends on: the Flutter SDK, `jet_cad_2d`, `jet_cad_2d_flutter`, `jet_cad_2d_kit`, `meta`, `vector_math`, and whatever the ported code already uses (`printing`, `pdf`, …), with the same constraints as `jet_cad_floor_plan`'s pubspec.
  - Never `jet_cad_floor_plan` and never `jet_cad_restaurant_symbols`.
  - `jet_cad_2d_kit` never depends on `jet_cad_2d_plan` or a kit (A1; `tool/ci/check_kit_deps.dart` enforces it).
  - **`authoring.dart` stays pure Dart** (the kit's purity test).
- **The old packages are untouched** (A12). No change under `packages/jet_cad_floor_plan`, `packages/jet_cad_restaurant_symbols`, `packages/jet_cad_2d_gpu` or `apps/`.
  - `packages/jet_cad_2d` changes only in Tasks 1 and 2 (E1-E4).
  - `packages/jet_cad_2d_flutter` does not change.
  - Logic and tests from `jet_cad_floor_plan` are **ported by copying and adapting**, never imported.
- **Ported tests keep their assertions** (A12). A ported algorithm's ported test passes unchanged in its assertions. Fixtures, names and imports may change. A ported test whose assertion must change is a finding: stop and report it, never weaken it.
- **Non-negotiables (CLAUDE.md):**
  - the frame path allocates nothing per entity in steady state (Task 15 adds the plan library's paint-allocation test);
  - draw order is ascending handle value;
  - geometric decisions use `Tolerance`; stored-value comparisons are exact `==`.
- **`analysis_options.yaml`.** Never stage an existing one: `flutter pub get` rewrites three of them in this workspace. **Plan decision:** `packages/jet_cad_2d_plan/analysis_options.yaml` is created and committed **once**, in Task 6, by explicit path, as Task 1 of sub-project 1 did for `jet_cad_2d_kit` (the human allowed it once per new package: *"Bir kez commit edilsin"*).
- **Stage files by explicit path only.** Never `git add -A` or `git add .`. Run `git status --short` after every pub operation.
- **Never synthesize test output.** Quote what commands print; reviewers re-run every claim.
- **Mutations.**
  - Run them on committed files only, and revert each with `git checkout -- <file>`; then `git diff --quiet -- <file>` must exit 0.
  - **In every task, run the Commit step before the Mutation step.**
  - Never restore from a `/tmp` copy, and never `git checkout --` a file with uncommitted work.
- **Language and commits.** Code, comments and commit messages are in English. Every commit message ends with the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Never run `dart pub publish` without `--dry-run`, and never push, tag or merge.** The human does all of these.
- **Every task ends green.** Run the gates of every package the task touched:
  - `cd packages/<pkg> && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` (for `jet_cad_2d`: `dart test && dart analyze && dart format …`);
  - plus `cd tool/ci && dart test` when `tool/ci` or `.github/` changed.

  The packages' language version is 3.6, so `dart format` uses the short style: run `dart format .` before the gate. **Run the format gate locally, every time** (a missed format gate once broke CI on this project).
- **Known environmental failures.** The engine's local hash tests and the renderer's goldens fail on clean `main` on this machine as well. They are environmental: compare against `tool/ci/standing_failures.txt` and never "fix" them.
- **Testing bar (CLAUDE.md).**
  - Every behaviour or refusal test names the mutation that turns it red. Positive controls and fixture-sanity tests are exempt.
  - Each task has a Mutation step: apply each named mutation, run the named test, see it red, revert.
  - Fixtures sit off the origin, at non-zero rotations where geometry matters, with non-default attributes.
- **Session limit.** Worktree-guarded sessions refuse bash loops and `$VAR` pipelines: run commands one by one.

## Review Focus

1. **A plan that names a kit the host did not load, and is then saved.**
   - Expected: it opens, the kit's objects draw and are locked, and saving keeps the missing kit's manifest entry and its objects' components byte for byte.
   - Pinned in Task 10 (L-1).
2. **One broken object beside working ones.**
   - Expected: at most one edit is refused, once. Afterwards the working objects of every kit regenerate on edit; the broken one keeps its geometry.
   - Pinned in Task 11 (F-2).
3. **Two kits contributing types with different component types `T`, used together.**
   - Expected: register, edit through the panel, recolour and show fields without a Dart runtime type error.
   - Pinned in Task 8 (C-covariance) and Task 17 (P-two-types).
4. **`load` while a tool is part-way through a shape and a panel field holds an uncommitted value.**
   - Expected: no exception; the tool is cancelled; the field's value is neither committed into the new plan nor lost silently from the old one (it settles into the old plan before the swap, as today's `_settlePendingInput`).
   - Pinned in Task 8 (C-swap-mid-shape) and Task 17 (P-swap-pending).
5. **Symbol libraries that finish loading after the user has started drawing, one of them failing.**
   - Expected: the drawing continues; the gallery fills in; the failure is one diagnostic; no symbol of the failed library appears.
   - Pinned in Task 13 (S-late-fail).

---

## File structure

Paths are relative to the repository root.

```
packages/jet_cad_2d/lib/src/
  parametric/parametric_system.dart     E1 typeIds/typeIdOf; E2 isFrozen, probe (Tasks 1, 2)
  parametric/regeneration.dart          E2 frozen objects skipped; E3 PartialMutationError (Tasks 1, 2)
  core/partial_mutation_error.dart      E3 (Task 1)
  document/component.dart               E4 loadJson diagnostics (Task 1)
  codec/json_codec.dart                 E4 plumbing (Task 1)
packages/jet_cad_2d_kit/lib/src/kit/
  properties.dart                       PropertySpec family, PropertyField, PlanGate (Task 3)
  colour.dart                           ColourTarget (Task 3)
  plan_type.dart                        PlanType, PropertySectionBuilder (Task 4)
  plan_tool.dart                        PlanTool, PlanToolSettings (Task 4)
  plan_services.dart                    PlanServices, KitWords (Task 4)
  attachment.dart                       AttachmentProvider, AttachmentQuery, Attachment, AttachmentRegistry (Task 4)
  kit_diagnostic.dart                   KitDiagnostic, KitDiagnosticCode (Task 4)
  plan_kit.dart                         grows types, tools, attachments; validate (Task 4)
packages/jet_cad_2d_kit/lib/src/model/  symbol_component.dart retired (Task 5); kit_problem.dart codes (Task 4)
packages/jet_cad_2d_kit/lib/src/authoring/  catalog.dart retired; conformance.dart R3 (Task 5)
packages/jet_cad_2d_kit/lib/src/model/symbol_library.dart   rule 11 width test, R7 (Task 5)
docs/kits.md                            R5 and the code side (Task 5)
packages/jet_cad_2d_plan/
  pubspec.yaml, analysis_options.yaml, LICENSE, README.md, CHANGELOG.md     (Tasks 6, 20)
  lib/jet_cad_2d_plan.dart              the barrel (grows per task)
  lib/src/kits/kit_set.dart             validateKitSet, KitSet (Task 6)
  lib/src/file/                         manifest.dart, plan_file.dart, plan_format_exception.dart, semver.dart (Task 7)
  lib/src/controller/                   plan_controller.dart, plan_change.dart, services.dart, shared_cache.dart,
                                        grip_dispatch.dart, tool_settings_store.dart (Task 8)
  lib/src/l10n/  lib/src/theme/  lib/src/fonts/                              (Task 9)
  lib/src/kits/locks.dart               lock expander, LockSet, PlanLocked (Task 10)
  lib/src/kits/guard.dart               GuardedType, KitHookFailure, GuardedTool, DiagnosticsLog, probe flow (Task 11)
  lib/src/controller/permissions.dart   PlanPermissions, PlanGate enforcement (Task 12)
  lib/src/tools/                        generic tools, plan_select_gates.dart (Task 12); plan_symbol_tool.dart, move_resolver.dart (Task 14)
  lib/src/symbols/                      plan_symbol_loader.dart, gallery_model.dart (Task 13)
  lib/src/attach/                       attachment_registry.dart, attachment_painter.dart (Task 14)
  lib/src/canvas/plan_canvas.dart       (Task 15)
  lib/src/editor/plan_tool_palette.dart, lib/src/shortcuts/plan_shortcuts.dart  (Task 16)
  lib/src/panels/plan_property_panel.dart, property_fields.dart, symbol_section.dart, colour_row.dart (Task 17)
  lib/src/panels/plan_layer_panel.dart, plan_page_panel.dart, plan_symbol_gallery.dart (Tasks 18, 13)
  lib/src/export/                       registries, pdf_exporter.dart, png_exporter.dart, export_dialog.dart, print.dart (Task 19)
  lib/src/editor/plan_editor.dart, plan_editor_bar.dart (Task 20)
  example/main.dart                     (Task 20)
  test/support/test_kit.dart, throwing_kit.dart, harness.dart (Task 6, grown by later tasks)
.github/workflows/ci.yml                a jet_cad_2d_plan job and a publishable entry (Task 6)
```

## Shared interfaces

These are the names and signatures every task uses. A task's **Interfaces** block repeats the part it consumes or produces. If a task needs to change one of these, that is a plan defect: stop and report it.

```dart
// ---- engine (jet_cad_2d), Tasks 1-2 ----
// E1
Iterable<String> ParametricCatalog.typeIds;                       // registration order
String? ParametricCatalog.typeIdOf(CommandTarget target, Handle group); // null: not a live parametric object
// E2
ParametricSystem(DraftDocument document, ParametricCatalog catalog, {bool Function(Handle)? isFrozen});
Object? ParametricSystem.probe(Handle object);                    // first error of reach/references/generate, or null; mutates nothing
// E3
final class PartialMutationError extends StateError { PartialMutationError(String message); }
// E4
void ComponentRegistry.loadJson(Map<String, Object?> json, {List<Diagnostic>? diagnostics});
//   with a list: a throwing factory keeps the component raw (attachUnknown) and adds
//   Diagnostic(severity: error, code: 'component.unreadable', handles: [h], message: '<typeId>: <error>');
//   without one (null): today's throw, unchanged
DraftDocumentCodec.decode / decodeString(..., {bool keepUnreadableComponents = false});
//   opt-in (Task 1 ruling): true passes the codec's diagnostics list to loadJson. Default false keeps
//   SymbolLibrary.decode's rule errors and jet_cad_floor_plan's behaviour unchanged.
//   jet_cad_2d_plan's decodePlan (Task 7) passes true.
// E2 semantics (Task 2): a frozen object is a plain group (children directly editable; writing its
//   type's component refused; a cascade referrer refused with DanglingReferenceError on edit);
//   catalog.names/objectsOf/typeIdOf still report it. probe() runs every hook an edit can call
//   (reach, references, pageKey, place hooks, readBox, dissolves, generate dry run, diagnose);
//   returns null for a frozen object or a non-object handle.
// E3 sites: regeneration.dart (3 sites) and CompoundCommand.apply (commands.dart:1006).

// ---- contract (jet_cad_2d_kit), Tasks 3-5 ----
enum PlanGate { move, rotate, mirror, reshape, delete, changeLayer, recolor, editLayers, editPage }
sealed class PropertySpec<T> { String get id; bool Function(T)? get enabled; PlanGate? get gate; }
// LengthProperty, AngleProperty, NumberProperty, ChoiceProperty<T,V>, ToggleProperty,
// TextProperty, ValueDisplay (unit: ValueUnit {length, area, angle, none}), ActionProperty
abstract interface class PropertyField {        // erased, bound to one object or one tool's settings
  PropertySpec<Object?> get spec;               // read-only use: id, gate, kind
  String get wordId;
  bool get enabled;
  Object? get value;                            // the read value, already typed per kind
  Object? Function(Object? input)? get commit;  // null for ValueDisplay; returns the new component/settings value or throws ArgumentError when out of range
}
final class ColourTarget<T> { const ColourTarget({required String? Function(T) read, required T Function(T, String?) write}); }
typedef PropertySectionBuilder<T> = Widget Function(BuildContext, T value, void Function(T) commit, KitWords words);
final class PlanType<T extends Component> {
  const PlanType({required String id, required ComponentFactory<T> fromJson, required ParametricType<T> parametric,
    ObjectGripProvider Function(PlanServices)? grips, List<PropertySpec<T>> properties = const [],
    PropertySectionBuilder<T>? section, String Function(T)? title, ColourTarget<T>? colour, bool exported = true});
  String get id; bool get exported; bool get hasColour; bool get hasSection;
  void registerInto(ParametricCatalog catalog, {TypeGuard? guard});   // guard.wrap<T> keeps T (covariance)
  List<PropertyField> fieldsOf(CommandTarget target, Handle group);
  String titleWordOf(CommandTarget target, Handle group);         // 'type:<id>' unless title() says otherwise
  String? colourOf(CommandTarget target, Handle group);
  DraftCommand? recolour(CommandTarget target, Handle group, String? swatch);
  DraftCommand commitField(CommandTarget target, Handle group, PropertyField field, Object? input); // one SetComponentCommand<T>
  Widget? sectionFor(BuildContext context, CommandTarget target, Handle group, void Function(DraftCommand) execute, KitWords words);
  ObjectGripProvider? gripsFor(PlanServices services);
}
abstract interface class TypeGuard {                // implemented by the plan library (Task 11)
  ParametricType<T> wrap<T extends Component>(String kitId, String typeId, ParametricType<T> type);
}
final class PlanToolSettings<S extends Object> {
  const PlanToolSettings({required S initial, required List<PropertySpec<S>> specs});
  Object get initial; List<PropertyField> fieldsOf(Object value, void Function(Object) store, {required String toolId});
}
final class PlanTool {
  const PlanTool({required String id, required IconData icon, String? letter, Set<Capability> needs = const {},
    PlanToolSettings<Object>? settings, required Tool Function(PlanServices) create});
}
// Task 4 additions (verified by compiling): PropertySpec.bind (virtual, per kind) and ChoiceProperty.segmentOf;
//   PlanType's public fromJson, parametric, grips, properties; PlanKit.propertyIds; isCodeId; KitNamesWords.names;
//   AttachmentQuery requires mirrored and mayRotate (no defaults). Angles are radians in PropertyField;
//   degrees are the panel's (Task 17). commitField rebinds to the object's current value.
abstract interface class Disposable { void dispose(); }   // in plan_services.dart (Task 4); shared caches and providers implementing it are disposed with their document
abstract interface class KitWords { String word(String wordId); String? maybe(String wordId); Locale get locale; }
abstract interface class PlanServices {
  DraftDocument get document; SpatialIndex get index; CameraController get camera; bool get objectSnap;
  AttachmentRegistry get attachments; KitWords get words;
  S settingsOf<S extends Object>(String toolId);
  T shared<T extends Object>(T Function(PlanServices) create);
}
abstract interface class AttachmentProvider { String get kind; Attachment? attach(AttachmentQuery query); }
final class AttachmentQuery { /* footprint, current, pointer, capture, edgeCapture, mirrored, mayRotate, exclude, keep */ }
final class Attachment { /* transform, marker, token */ }
abstract interface class AttachmentRegistry { Attachment? attach(List<String> kinds, AttachmentQuery query); Set<String> get kinds; }
enum KitDiagnosticCode { hookFailed, rollbackFailed, damagedUnsavable, componentUnreadable, letterTaken,
  attachmentKindUnoffered, libraryUnreadable, libraryKitMismatch, symbolDuplicate, kitMissing, kitNewer }
final class KitDiagnostic { const KitDiagnostic({required String kitId, String? subject, required KitDiagnosticCode code, required String message, Object? error}); }
// PlanKit gains: types, tools, attachments (List<AttachmentProvider Function(PlanServices)>)
// KitProblemCode gains: duplicateKit, duplicateType, duplicateTool, reservedKitId, typeOutsideKit, toolOutsideKit, typePlaceConflict
// SymbolComponent and CatalogSymbol gain: bool retired (default false; absent in JSON reads false)

// ---- plan library (jet_cad_2d_plan), Tasks 6-20 ----
final class KitSet { List<PlanKit> get kits; PlanKit? kitOf(String id); /* load order */ }
KitSet validateKitSet(List<PlanKit> kits);                        // throws ArgumentError listing every problem
enum PlanFormatCode { noManifest, formatTooNew, schema, notJson, damagedUnsavable }
final class PlanFormatException implements FormatException { PlanFormatCode get code; }
final class PlanManifest { int format; Map<String, String> kits; }
final class PlanController extends ChangeNotifier { /* spec P2; Task 8 lists the members */ }
sealed class PlanChange {}  // PlanObjectAdded, PlanObjectChanged, PlanObjectRemoved, PlanReplaced
final class PlanPermissions { /* tools, flags, full, readOnly; Task 12 */ }
final class PlanLocked implements Exception {}
final class KitHookFailure implements Exception { String kitId; String typeId; String hook; Object error; }
enum PlanSymbolsState { loading, ready, failed }
// lib/src/panels/panel_focus.dart is created by Task 13 (ported from jet_cad_floor_plan/lib/src/panel_focus.dart);
//   Tasks 17 and 18 reuse it, never create another. placeSymbol (port of symbol_placer.dart) lands in Task 13.
// Host undo()/redo() are not gated: under PlanPermissions.readOnly they lift the engine permissions for that one call (Task 12).
abstract interface class PlanExporter { String get id; String get extension; String get mimeType; Future<Uint8List> export(PlanExportRequest r); }
abstract interface class PlanImporter { String get id; List<String> get extensions; Future<String> import(Uint8List bytes); }
final class PlanExport { Uint8List bytes; String name; String mimeType; }
abstract interface class PlanPageExporter implements PlanExporter {}   // marker: needs a page (Task 19)
// Task 19 also exports PlanExportAnswer and PlanExportDialog (the dialog's answer and hook);
// Task 20 exports PlanFileCallback and PlanEditor's four file-callback options.
// Controller internals used across tasks (@internal): toolController (never `tools`), selection, grips,
//   camera, page, snap, catalog; registerSettle/settlePendingInput (Task 8).
// The property panel's layer field is mounted by Task 18 (it ports the layer picker); Task 17 leaves
//   an @internal slot for it.
```

---

## Appendix: rulings made while planning (2026-10-14)

Each was made by the controller while seven writers drafted the tasks in parallel; the spec stays the authority.

- **E4 is opt-in.** `DraftDocumentCodec.decode`/`decodeString` take `keepUnreadableComponents` (default `false`), so `SymbolLibrary.decode`'s rule errors and `jet_cad_floor_plan` keep today's behaviour; `decodePlan` passes `true` (Task 1, Task 7).
- **E3 has four sites** (regeneration ×3, `CompoundCommand.apply`); E2's frozen object is a plain group (Task 2).
- **`Disposable`** is contract (`jet_cad_2d_kit`, Task 4): kits' caches and providers implement it.
- **`PlanToolSettings.fieldsOf(..., {required String toolId})`** builds `property:<tool id>.<id>` words (Task 4).
- **`PlanSwatch`**, the eight-colour palette, is contract (`jet_cad_2d_kit/lib/src/kit/swatch.dart`, Task 9): kits name swatches without depending on the plan library. A contract addition the spec implies (P3 colour) but does not name.
- **Every widget-side commit goes through `PlanController.execute(DraftCommand) -> bool`**, which turns every refusal (`PlanLocked`, `DanglingReferenceError`, `ArgumentError`, `KitHookFailure`) into `false` (Tasks 10-11, consumed by 15-19).
- **Names:** `toolController` (never `tools`); `panel_focus.dart` and `placeSymbol` in Task 13; the shortcut guard in Task 15; `DiagnosticsLog` at `lib/src/controller/diagnostics_log.dart`; `registries.dart` and `camera_bounds.dart` created by Task 8; the property panel's layer field filled by Task 18 through Task 17's slot.
- **Panel fields use the language's decimal separator** (spec P3 corrected at `c4cccac`); the plan's separator governs what is drawn.
- **NS7 kept (A14):** `PlanLocaleScope.push` reports the locale and `PlanStrings.of(context)`; a new plan's separator comes from those strings, so a host's own language class still sets it (Task 9).
- **Ported assertions may move, never weaken:** each moved assertion is listed in its task with its new owner (another task, 2b or sub-project 3).
- **Tool settings belong to the controller** and survive a document swap (today's shell kept them per document): a deliberate change, recorded in Task 8 and the results note.

