## File structure

```
packages/jet_cad_2d/lib/src/parametric/
  parametric_system.dart        + GeneratedInstance, GeneratedAttrib, GeneratedDefinitionError,
                                  ParametricType.instances, _Registration.instancesOf          (Task 1)
                                GeneratedGeometryError's doc                                    (Task 2)
  regeneration.dart             survey `instances`/`generated`/`leaves`, instance matching,
                                ATTRIB by tag                                                   (Task 1)
                                guard node branch, survey `nested`, no seed for component
                                writes, refused adds, dissolve removes instance-owned entities  (Task 2)
packages/jet_cad_2d/CHANGELOG.md                                                               (Tasks 1-2)
packages/jet_cad_2d/test/parametric/
  support/row_clients.dart      the test row and seat types (E5)                               (Task 1)
  cascade_test.dart             CS11: drift names P1 (Task 1); its adds come in as a loaded
                                file's (Task 2)                                                 (R-4)
docs/superpowers/specs/2026-09-26-rooms-design.md   the D12 amendment line                     (Task 2)

packages/jet_cad_2d_kit/lib/src/kit/
  symbols_state.dart            SymbolsState (moved from jet_cad_2d_plan)                       (Task 3)
  plan_services.dart            + symbolDefinition, symbolsState, SymbolDefinitionRef            (Task 3)
  unit_label.dart               kUnitLabelTag, the stamp, height and payload, unitLabelAttrib   (Task 3)
  host_words.dart               validateHostWords                                              (Task 3)
  properties.dart               + PlanGate.relabel                                             (Task 3)
  plan_kit.dart                 + the unit: namespace                                          (Task 3)
packages/jet_cad_2d_kit/lib/src/model/
  unit_component.dart           UnitLabelling.assigned's doc                                   (Task 3)
  kit_problem.dart              + KitProblemCode.unitKindWord                                  (Task 3)
  kit_names.dart                the word ids' doc                                              (Task 3)
packages/jet_cad_2d_kit/lib/src/authoring/
  conformance.dart (existing)   the unitKindWord check                                         (Task 3, R-2)
packages/jet_cad_2d_kit/lib/jet_cad_2d_kit.dart, CHANGELOG.md                                  (Task 3)
packages/jet_cad_2d_kit/test/support/placements.dart                                           (Task 3)

packages/jet_cad_2d_plan/lib/src/
  kits/guard.dart               + GuardedType.instances                                        (Task 1, R-1)
  controller/services.dart      two compile stubs (Task 3); KitServices.symbolDefinition /
                                symbolsState, ServicesHost's pending refs                      (Task 4)
  controller/permissions.dart   relabel (Task 3); selectUnitsOnly, serviceMove, serviceMerge,
                                unitsOnly, isUnitSymbol                                         (Task 8)
  controller/plan_controller.dart  words:, namesOf, SymbolsState, pending refs (Task 4);
                                unit components, unitIndex (Task 6); the symbol tool's index
                                (Task 7); the permissions setter (Task 8); the unit API and its
                                seams (Task 9); planStrings (Task 10); mode, the active members,
                                the seams re-pointed (Task 11); service state (Task 12); the
                                record (Task 13); the session's groups and moves (Task 14);
                                export/print opacity, documentUnits (Task 15); the canvas
                                origins across a switch, R-13 (Task 16)
  controller/session.dart       units (Task 6); the expander stack (Task 7); the gates (Task 8)
  controller/plan_camera.dart   PlanCamera                                                     (Task 9)
  symbols/plan_symbols_state.dart  deleted                                                     (Task 4)
  symbols/symbol_box.dart       servedTopOfEntry                                               (Task 4)
  symbols/plan_symbol_loader.dart, panels/plan_symbol_gallery.dart   SymbolsState              (Task 4)
  symbols/symbol_placer.dart    placeSymbol(units:): the placed unit's number                  (Task 7)
  tools/plan_symbol_tool.dart   units                                                          (Task 7)
  tools/plan_select_gates.dart  the design mapping, selectUnitsOnly                            (Task 8)
  panels/kit_lookup.dart, editor/plan_tool_palette.dart   the host's words first               (Task 4)
  panels/plan_property_panel.dart  the host's words (Task 4); the unit section (Task 10)
  panels/unit_section.dart      the unit section's model                                       (Task 10)
  panels/colour_row.dart        placed units as colour targets                                 (Task 10)
  units/unit_index.dart         UnitInfo, UnitIndex, UnitIndexCache                            (Task 6)
  units/unit_label.dart         the text rule, UnitLabelProblem, firstLeafOf, unitTopOfLeaves,
                                placedLabelTop(Of), unitLabelRecord, addUnitLabelCommand,
                                unitLabelOf                                                     (Task 6)
  units/unit_numbers.dart       nextUnitNumber                                                 (Task 6)
  units/unit_components.dart    UnitData (jetcad.unit_data), UnitColour (jetcad.unit_colour)    (Task 6)
  units/unit_problems.dart      UnitProblem codes, UnitLabelWarning and its three subtypes     (Task 6)
  units/unit_locks.dart         isLockedUnit, heldTypeOf                                       (Task 6)
  units/unit_label_system.dart  UnitLabelSystem                                                (Task 7)
  units/unit_rotate.dart        rotateUnitCommand                                              (Task 7)
  units/unit_detail.dart        PlanUnit, PlanUnitDetail, PlanUnitChange and its subtypes      (Task 9)
  units/unit_fit.dart           frameUnits                                                     (Task 9)
  units/unit_writes.dart        unitLabelCommand                                               (Task 9)
  units/unit_words.dart         unitKindWord                                                   (Task 10)
  l10n/strings.dart, strings_{en,de,tr}.dart   the unit and service words                      (Task 10)
  editor/unit_inspector.dart    UnitInspector                                                  (Task 10)
  editor/plan_editor.dart       unitInspectorBuilder (Task 10); the flows' opacity (Task 15);
                                the mode switch, the service options (Task 16)
  service/unit_picker.dart      UnitPicker, UnitTop, unitTopOf, UnitCandidate, PickCandidate    (Task 8, R-12)
  service/service_session.dart  PlanMode, serviceCopyOf, ServiceSession (Task 11); its
                                ServiceTool, picker and host (Task 14)
  service/service_state.dart    UnitStatus, UnitGroup, validateUnitGroups, the lookup          (Task 12)
  service/service_record.dart   the jet_cad.service format, ServiceRestore, the strict match   (Task 13)
  service/service_tool.dart     ServiceTool, ServiceHost, the records, PlanLongPress,
                                PlanFloorDrag                                                   (Task 14)
  service/paint/                UnitStatusPainter, UnitGroupPainter, UnitFocusPainter          (Task 15)
  theme/plan_theme.dart         + the thirteen fields, kUnitColourOpacity                      (Task 15, R-22)
  export/page_flows.dart        the copy registers the unit components (Task 6); the opacity
                                and the fills (Task 15)
  export/registries.dart        PlanExportRequest.unitColourOpacity                            (Task 15)
  export/builtin_exporters.dart, export/unit_colour_underlay.dart   the fills                  (Task 15)
  export/editor_page_flows.dart the view's opacity (Task 15); the active document, the gates
                                in design only (Task 16)
  canvas/plan_canvas.dart       the design's unit colours (Task 15); unitOverlays (Task 16)
  canvas/plan_canvas_view.dart  tableOverlays → unitOverlays                                   (Task 15)
  service/view/                 PlanServiceView, PlanServiceBar, unit overlays                 (Task 16)
packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart   the barrel                (Tasks 4, 8, 9, 11, 12, 13, 16)
packages/jet_cad_2d_plan/example/main.dart, README.md, CHANGELOG.md                            (Task 16)
.github/workflows/ci.yml (the plan library's --enable-vmservice), tool/ci/test/scripts_test.dart (Task 14, R-18)

packages/jet_cad_2d_plan/test/support/   one owner per helper; later tasks append or import (R-19)
  box_kit.dart (2a)             the square's switchable instances                              (Task 4)
  test_kit.dart (2a)            test.table, test.seat, test.row, the booth, unitKit()          (Task 5)
  service_fixture.dart          serviceFixture(), testEntry, addRow, rowsOf, seatsOf,
                                unitLabelsOf, labelPlacedUnit, expectUprightLabel              (Task 5)
  harness.dart (2a)             registerPlanComponents registers the unit components           (Task 6)
  unit_fixtures.dart            the table fixture over fxKit() (Task 6); the picker's helpers
                                (Task 8); numberedRowOfTables, copyForService (Task 14)
  unit_editor_fixture.dart      the editor fixture, the embedding table                        (Task 8)
  unit_embedding_fixture.dart   the embedding fixture                                          (Task 9)
  recording_plan_strings.dart (2a)  the new words recorded                                     (Task 10)
  service_plans.dart            servicePlanText, placeDef, hall, … (Task 11; Tasks 12-13 extend)
  service_rig.dart              the hall, the tool rig                                         (Task 14)
  service_paint.dart            ServicePaintLayers (painter-level tests only, R-15)            (Task 15)
  unit_zone_fixture.dart        the zone fixture                                               (Task 15)
  service_fixtures.dart         pagePlan, toolbarPlanJson; re-exports the two fixtures         (Task 16)
  service_host.dart             serviceController, rowsController, pumpService                 (Task 16)
packages/jet_cad_2d_plan/test/invariants/vm_allocation_meter.dart   copied                     (Task 14)
```

## Shared interfaces

These are the names and signatures every task uses. A task's **Interfaces** block repeats the part it consumes or produces. If a task needs to change one of these, that is a plan defect: write it in `#### Interface problem` and stop.

```dart
// ---- engine (jet_cad_2d), Tasks 1-2 (spec S1) ----
final class GeneratedAttrib {
  GeneratedAttrib(this.tag, this.text, this.payload, {this.textAttrs = 0}); // ArgumentError: empty tag
  final String tag;
  final String text;
  final GeometryPayload payload;   // the instance's local (definition) space
  final int textAttrs;
}
final class GeneratedInstance {
  GeneratedInstance(this.definition, this.transform,
      {List<GeneratedAttrib> attributes = const []});  // ArgumentError: two attributes, one tag
  final Handle definition;
  final Transform2 transform;      // the object's group's local space
  final List<GeneratedAttrib> attributes;  // unmodifiable
}
final class GeneratedDefinitionError implements Exception {
  const GeneratedDefinitionError(this.object, this.definition);
  final Handle object;
  final Handle definition;
}
// on ParametricType<T>, beside generate:
List<GeneratedInstance> instances(ParametricView view, Handle self) => const [];
// planner: survey `instances` (object -> generated InstanceNodes ascending, with their Node values);
// matching by position, ATTRIBs by tag (lowest handle wins; SetEntityTextCommand passes the ATTRIB's own tag);
// GeneratedDefinitionError thrown by _plan (probe returns it, drift throws it; not in _isRefusal).
// Every instance command of a plan runs through _run's loop, so CommandResult.touched names each seat
// and label a regeneration adds, changes or removes (Task 7's label system reads it).
// jet_cad_2d_plan, Task 1 (R-1): GuardedType.instances (a throw becomes KitHookFailure naming 'instances').
// guard (Task 2): entity branch unchanged; node branch by InstanceNode.==; a components-only write on a
// generated instance passes and seeds nothing; any node or entity added into a live object refused.

// ---- contract (jet_cad_2d_kit), Task 3 (spec S2, S4) ----
enum SymbolsState { loading, ready, failed }                       // moved from jet_cad_2d_plan
final class SymbolDefinitionRef {
  const SymbolDefinitionRef({required this.handle, required this.add,
      required this.basePoint, required this.top});
  final Handle handle;
  final DraftCommand? add;          // one CompoundCommand, or null when the document holds it
  final Vector2 basePoint;
  final Aabb2 top;                  // first leaf's box if a closed polyline or circle, else the definition's box
}
// PlanServices gains:
SymbolDefinitionRef? symbolDefinition(String key);                 // key: 'kit.kind.variant@N'
ValueListenable<SymbolsState> get symbolsState;
// unit_label.dart:
const String kUnitLabelTag = 'UNIT';
const double kUnitLabelMaxHeight = 200;
const double kUnitLabelTopShare = 0.4;
final int kUnitLabelTextAttrs;                                       // centre/middle, override width factor
double unitLabelHeight(Aabb2 top);                                   // min(200, 0.4 * min side); empty -> 200
({double rotation, double widthFactor}) unitLabelStamp(Transform2 instanceToWorld); // today's tableLabelStamp
GeometryPayload unitLabelPayload(
    {required Vector2 anchor, required double height, required Transform2 instanceToWorld});
GeneratedAttrib unitLabelAttrib(String text,
    {required Transform2 instanceToWorld, required Vector2 anchor, required Aabb2 top});
// host_words.dart:
List<KitProblem> validateHostWords(KitNames words);
// properties.dart: PlanGate gains `relabel` (last value).
// kit_problem.dart: KitProblemCode gains `unitKindWord` (last value).
// PlanKit.validate: 'unit:<kit id>/<kind>' checked in the slash branch (the part before '/' is the kit id).
// conformance(): every UnitComponent.kind in the kit's libraries outside UnitKinds needs an English
//   'unit:<kit id>/<kind>' word, else KitProblemCode.unitKindWord.

// ---- plan library (jet_cad_2d_plan) ----
// Task 3 (compile only): PlanPermissions.relabel (default true, false in readOnly) and its allows arm;
//   KitServices.symbolDefinition / symbolsState as UnimplementedError stubs Task 4 replaces.
// Task 4: plumbing
//   The PB-guard tests of Task 1's GuardedType.instances.
//   KitServices.symbolDefinition / symbolsState; pending refs by key, kept per controller (through
//   ServicesHost), until the document holds the definition, the next PlanController.execute, or a
//   document swap.
//   PlanController({..., KitNames words = KitNames.empty}): ArgumentError naming validateHostWords' first
//   problem; each kit's KitNamesWords reads words.merge(kit.names).
//   PlanController.symbolsState: ValueListenable<SymbolsState> (the kit's enum; plan_symbols_state.dart deleted).
//   @internal KitNames? PlanController.namesOf(String kitId): a loaded kit's words, the host's first.
//   Aabb2 servedTopOfEntry(SymbolEntry entry) (symbols/symbol_box.dart; SymbolDefinitionRef.top).

// Task 6: units/
final class UnitInfo {
  final Handle instance;
  final Handle definition;
  final Handle? owner;              // the generating object; null when placed
  final String? ownerType;          // its type id (or the missing kit's component type id); null when placed
  final Handle? label;              // the lowest-handle UNIT ATTRIB
  final String? text;               // trimmed; null = unlabelled (no label or empty)
  final String kind;
  final int capacity;
  final UnitLabelling labelling;
  final String? symbolKey;
  final bool locked;                // isLockedUnit
  final bool visible;               // the unit's layer shown
  final Transform2 toWorld;         // root group × instance for a generated unit
  final Aabb2 top;                  // definition space, today's served top (or the definition's box)
  final Aabb2 box;                  // definition space, the symbol box
  bool get generated => owner != null;
}
final class UnitIndex {
  factory UnitIndex.of(CommandTarget document,
      {required ParametricCatalog catalog, required LockSet locks});
  List<UnitInfo> get units;                       // ascending by instance handle, served or not
  UnitInfo? operator [](Handle instance);
  List<UnitInfo> withLabel(String label);         // trimmed label; ascending
  List<Handle> get nested;                        // unit.nested instances
  List<Diagnostic> diagnostics();                 // the engine's Diagnostic, UnitProblem codes (R-8)
  List<UnitLabelWarning> warnings();              // DuplicateLabel (first-appearance order), Unlabelled, BadLabel
}
final class UnitIndexCache {                      // one per session; rebuilds on stateId, layers' revision, locked
  UnitIndexCache(DraftDocument document,
      {required ParametricCatalog catalog, required LockSet locks,
       required ValueListenable<Set<Handle>> locked});
  UnitIndex get current;
  void dispose();
}
bool isLockedUnit(CommandTarget document, LockSet locks, Handle instance); // locked layer or locks.covers
enum UnitLabelProblem { length, control }                                   // today's TableNumberProblem
const int kUnitLabelMaxLength = 8;
UnitLabelProblem? unitLabelProblem(String raw);
String nextUnitNumber(UnitIndex index);
abstract final class UnitProblem {                // diagnostic codes
  static const duplicateLabel = 'unit.duplicate_label', unlabelled = 'unit.unlabelled',
      badLabel = 'unit.bad_label', extraLabel = 'unit.extra_label', nested = 'unit.nested',
      invalidData = 'unit.invalid_data', invalidColour = 'unit.invalid_colour';
}
sealed class UnitLabelWarning {}
final class DuplicateLabel extends UnitLabelWarning { final String label; final int count; }
final class Unlabelled extends UnitLabelWarning { final String kind; final int capacity; final String? symbolKey; }
final class BadLabel extends UnitLabelWarning { final String label; final UnitLabelProblem problem; }
final class UnitData implements Component { static const componentTypeId = 'jetcad.unit_data'; /* today's limits */ }
final class UnitColour implements Component { static const componentTypeId = 'jetcad.unit_colour'; final String? name; PlanSwatch? get swatch; }
void registerUnitComponents(ComponentRegistry registry);
String? unitDataProblem(Map<String, String> data);                           // today's tableDataProblem
// unit_label.dart, for Tasks 7-9 (R-20, R-21):
({EntityKind kind, GeometryPayload payload})? firstLeafOf(CommandTarget target, Handle owner,
    [Map<Handle, List<int>>? leavesByOwner]);                                // today's, table_label.dart:155-181
Aabb2 unitTopOfLeaves(List<(EntityKind, GeometryPayload)> leaves);          // spec S2's top (UnitInfo.top)
Aabb2 placedLabelTop(List<(EntityKind, GeometryPayload)> leaves);           // a placed label's height box:
Aabb2 placedLabelTopOf(CommandTarget target, Handle definition);            //   first leaf circle/polyline, else empty
EntityRecord unitLabelRecord({required Handle handle, required Handle instance, required String text});
AddEntityCommand addUnitLabelCommand(DraftDocument doc, {required Handle instance,
    required Handle definition, required Transform2 placement, required String text});
Handle? unitLabelOf(CommandTarget target, Handle instance);
// DocumentSession.units (UnitIndexCache); PlanController: @internal UnitIndex get unitIndex (R-10: lands
//   here, the design's; Task 11 re-points it at the active document).

// Task 7
final class UnitLabelSystem { UnitLabelSystem(DraftDocument document); void install(); void dispose(); }
// expander stack per document: parametric system -> UnitLabelSystem -> LockExpander.
DraftCommand? rotateUnitCommand(DraftDocument doc, Handle instance, int quarterTurns);
// placer: placeSymbol(…, {UnitIndex? units}): with an index, a placed `numbered` unit gets
//   nextUnitNumber(units) as a UNIT ATTRIB in the same command; without one, no label.
//   PlanSymbolTool(…, {UnitIndex Function()? units}); DocumentSession.labels (UnitLabelSystem).

// Task 8: PlanPermissions gains selectUnitsOnly (false), serviceMove (true), serviceMerge (true);
//   static const unitsOnly; bool isUnitSymbol(PlanSymbol symbol).
//   PlanSelectGates: in design, restrictsPick true and pick maps a key under a parametric or lock-set
//   object to that object; bandAccepts refuses such keys; selectUnitsOnly restricts both to placed units.
// Task 8 (R-12): service/unit_picker.dart
class UnitPicker {
  UnitPicker(DraftDocument document, UnitIndexCache units,
      {bool skipLocked = false, bool placedOnly = false,
       @visibleForTesting Map<Handle, List<int>> Function()? leavesByOwner,
       @visibleForTesting Transform2 Function(Transform2 transform)? invert});
  final DraftDocument document; final UnitIndexCache units;
  static const Tolerance tolerance;
  UnitInfo? pick(Vector2 world, {double reach = 0});   // top, box, touch reach; allocation-free
  List<PickCandidate> get candidates;
  static List<UnitCandidate> candidatesOf(DraftDocument document, UnitIndex index,
      {required Map<Handle, Aabb2> boxes, required Map<Handle, List<int>> Function() leaves});
}
// sealed class UnitTop (PolygonTop, CircleTop); UnitTop? unitTopOf(DraftDocument doc, Handle definition,
//   [Map<Handle, List<int>>? leavesByOwner]); final class UnitCandidate (unit, transform, box, corners,
//   locked, worldBounds); final class PickCandidate (unit, inverse, top, box, locked, scale).

// Task 9: the unit API (design and service both, on the active document)
final class PlanUnit { final String? label; final String kind; final int capacity;
  final String? symbolKey; final bool visible; final String? generatedBy; }
final class PlanUnitDetail { final PlanUnit unit; final Offset? center; final Size? size;
  final double rotation; final bool mirrored; final List<Offset> corners; final String layer;
  final bool locked; final Map<String, String> data; final PlanSwatch? colour; }
sealed class PlanUnitChange {}
final class PlanUnitAdded extends PlanUnitChange { final PlanUnitDetail unit; }
final class PlanUnitRemoved extends PlanUnitChange { final PlanUnitDetail unit; }
final class PlanUnitChanged extends PlanUnitChange { final PlanUnitDetail before, after; }
final class PlanUnitsReplaced extends PlanUnitChange {}
final class PlanCamera { double get scale; Offset worldToCanvas(Offset w); Offset canvasToWorld(Offset c);
  Rect visibleWorld(Size canvas); }
// PlanController:
//   List<PlanUnit> get units; List<PlanUnitDetail> get unitDetails; String? unitAt(Offset canvasPoint,
//   {PointerDeviceKind kind = PointerDeviceKind.mouse}); void select(Set<String> labels);
//   bool fitToUnits(Set<String> labels); List<UnitLabelWarning> get labelWarnings;
//   bool setUnitData(String label, Map<String, String> data); bool setUnitsData(Map<String, Map<String, String>>);
//   bool setUnitColour(String label, PlanSwatch? colour); bool setUnitsColour(Map<String, PlanSwatch?>);
//   bool setUnitLabel(String label, String next); bool setUnitsLabel(Map<String, String>);
//   Stream<PlanUnitChange> get unitChanges; ValueListenable<int> get revision;
//   ValueListenable<PlanCamera> get cameraValue; Offset? worldToGlobal(Offset); Offset? globalToWorld(Offset);
//   ValueListenable<Set<String>> get editorSelectedUnits;
//   @internal List<Handle> get unitDetailInstances (index for index with unitDetails).
//   Private seams Task 11 re-points: UnitIndexCache get _activeUnits, DraftDocument get _activeDocument,
//   SelectionController get _activeSelection, bool get _inDesign, void _requireDesign(String who),
//   Set<String> _expandLabels(Set<String>) (Task 12 fills it), ValueNotifier<Set<String>> _selectedUnits.
// units/unit_writes.dart: DraftCommand? unitLabelCommand(DraftDocument doc, UnitInfo unit, String text).

// Task 10: PlanStrings gains merge, split, number, label, capacity, rotateLeft, rotateRight,
//   String labelProblem(UnitLabelProblem), String labelUsed(String label),
//   String labelWarning(UnitLabelWarning), String? unitKind(String kind) (table, seat; null otherwise).
//   String unitKindWord(PlanController c, UnitInfo unit): kit word, else PlanStrings, else the kind.
//   PlanEditor(unitInspectorBuilder: Widget? Function(BuildContext, PlanUnitDetail)?).
//   @internal PlanStrings get planStrings (the words the widgets last reported, else the locale's).

// Task 11
enum PlanMode { design, service }
final class ServiceSession { /* document, measurer, parametric, labels, lockExpander, boundary, index,
  page, selection, outlines, toolContext, tool, tools, units (UnitIndexCache), history, onSelection,
  canUndo, canRedo; detach(), dispose(). Its tool is a private idle placeholder until Task 14 (R-17). */ }
DraftDocument serviceCopyOf(DraftDocument design,
    {required void Function(ComponentRegistry) register, required TextMeasurer measurer});
// PlanController: ValueListenable<PlanMode> get mode; void setMode(PlanMode next);
//   DraftDocument get activeDocument; SelectionController get activeSelection;
//   @internal ServiceSession? get serviceSession;
//   ValueListenable<Set<String>> get selectedUnits (listed under Task 12; lands here over Task 9's seam).
//   execute() and deleteSelection() answer false in service; a design write throws
//   StateError('<member> needs the design mode (P-5)') there.
//   undo/redo/canUndo/canRedo/export/print act on the active document.

// Task 12
final class UnitStatus { UnitStatus({required Color color, String? caption}); static const int maxCaption = 12;
  final Color color; final String? caption; }
final class UnitGroup { UnitGroup({required Set<String> members, String? label}); static const int maxLabel = 24;
  final Set<String> members; final String? label; }
Map<String, UnitGroup> validateUnitGroups(Map<String, UnitGroup> groups); // ArgumentError as today
// PlanController: unitStatuses/setUnitStatus, unitGroups/setUnitGroups, groupStatuses/setGroupStatus,
//   unitFocus/setUnitFocus (ValueListenable<Set<String>?>), selectedUnits (Task 11's),
//   selectedGroup (ValueListenable<String?>), mergeCandidate (ValueListenable<Set<String>?>),
//   Set<String> selectableMembers(String groupId);
//   @internal UnitGroupLookup get groupLookup; @internal UnitStatus? statusOf(UnitInfo unit).
// Internal: GroupUnit({handle, label, visible, locked, generated}); UnitGroupLookup(groups, units)
//   (byLabel, groupOf, visibleMembers, selectableMembers, hasLockedVisibleMember,
//   hasGeneratedVisibleMember, splitGroup); Map<String, String> groupIdsByLabel(Map<String, UnitGroup>);
//   groupUnitsOf, mergeQualifies, unitLabelOrder, inLeadOrder, statusOfUnit.

// Task 13
const String kServiceFormat = 'jet_cad.service';
const int kServiceVersion = 1;
final class ServiceRestore { final List<String?> appliedMoves, droppedMoves;
  final List<String> appliedGroups, droppedGroups; }
// PlanController: String? serviceJson(); ServiceRestore restoreService(String json); void resetService();
//   bool get serviceEdited; Listenable get serviceChanges.

// Task 14 (service/service_tool.dart; R-17)
enum PlanLongPress { toggleSelection, contextMenu }
enum PlanFloorDrag { pan, band }
typedef ServiceCallbacks = ({void Function(String label)? onUnitTap, void Function()? onLayoutChanged,
    void Function(String groupId, String label)? onGroupTap,
    void Function(Set<String> labels)? onMergeRequested, void Function(String groupId)? onSplitRequested});
typedef ServiceOptions = ({PlanLongPress longPress,
    void Function(String label, Offset globalPosition)? onUnitContextMenu, PlanFloorDrag floorDrag});
typedef ServiceEvents<M> = ({void Function(List<M> moved)? onUnitsMoved,
    void Function(String label)? onUnitDoubleTap, void Function(Offset world)? onFloorTap,
    void Function(String? label)? onUnitHover});
// const kNoServiceCallbacks, kDefaultServiceOptions, kNoServiceEvents.
final class ServiceHost {
  const ServiceHost({ServiceCallbacks Function() callbacks, ServiceOptions Function() options,
      bool Function() userCamera, Offset Function(Offset local) toGlobal,
      ServiceEvents<Handle> Function() events, bool Function() idleKeys});   // each defaults to today's
  static const ServiceHost none;
}
String? contextSelect(UnitInfo hit, SelectionController selection, {Set<SelectionKey>? group});
class ServiceTool extends Tool { ServiceTool({required UnitPicker picker,
    required ValueListenable<Map<String, UnitGroup>> groups, required ServiceCallbacks Function() callbacks,
    ServiceOptions Function() options, bool Function() moves, bool Function() userCamera,
    Offset Function(Offset local) toGlobal, ServiceEvents<Handle> Function() events,
    bool Function() idleKeys});
  final UnitPicker picker; Set<SelectionKey>? groupKeysOf(UnitInfo hit);
  void secondaryClick(Vector2 world, Offset globalPosition, SelectionController selection); }
// ServiceSession (@internal): late final UnitPicker picker; ServiceHost host (settable, none by default);
//   late final ServiceTool tool; its constructor gains groups and moves (permissions.serviceMove).

// Task 15
const double kUnitColourOpacity = 0.35;     // theme/plan_theme.dart (R-22)
// PlanTheme's thirteen fields (spec S4 "Theme"); PlanExportRequest.unitColourOpacity (double, default
//   kUnitColourOpacity); PlanController.export(String exporterId, PlanExportChoice choice,
//   {String? name, double? unitColourOpacity}), print(PlanExportChoice choice, {PagePrinter? printer,
//   String? name, double? unitColourOpacity}): null is 0.35, outside [0, 1] or not finite an ArgumentError.
// PlanPageFlows.exportOnce/printOnce(…, {double unitColourOpacity = kUnitColourOpacity});
//   EditorPageFlows({…, double Function() unitColourOpacity}); @internal UnitIndexCache get documentUnits;
//   PlanCanvasView.unitOverlays (renamed from tableOverlays).
// service/paint/ (internal):
//   UnitStatusPainter({required DraftDocument document, required UnitIndexCache units,
//     required ValueListenable<ViewportTransform> camera, required ValueListenable<Map<String, UnitStatus>>
//     statuses, required ValueListenable<Map<String, UnitGroup>> unitGroups,
//     required ValueListenable<Map<String, UnitStatus>> groupStatuses, required ValueListenable<int> paper,
//     ValueListenable<PlanTheme?>? theme, bool Function()? darkCanvas, required Listenable repaint});
//   enum UnitGroupLayer { frames, chips }; UnitGroupPainter({required UnitGroupLayer layer,
//     required DraftDocument document, required UnitIndexCache units, required ValueListenable<ViewportTransform>
//     camera, required ValueListenable<Map<String, UnitGroup>> groups, required ValueListenable<int> paper,
//     ValueListenable<Set<String>?>? unitFocus, ValueListenable<PlanTheme?>? theme, required Listenable repaint});
//   UnitFocusPainter({required DraftDocument document, required UnitIndexCache units,
//     required ValueListenable<ViewportTransform> camera, required ValueListenable<Set<String>?> focus,
//     required ValueListenable<int> paper, ValueListenable<PlanTheme?>? theme, required Listenable repaint}).
// export/unit_colour_underlay.dart: unitColourUnderlay(UnitIndex, DraftDocument, double opacity,
//   {Set<Handle> omitted}); checkedUnitColourOpacity(double?); Expando unitFillsOf.

// Task 16
enum PlanServiceAction { undo, redo, merge, split, export, print }
final class PlanServiceBar { const PlanServiceBar({this.visible = true,
  this.actions = PlanServiceAction.values, this.leading = const [], this.trailing = const []}); }
final class PlanUnitOverlay { final PlanUnitDetail detail; final bool selected; final bool focused;
  final UnitStatus? status; final int detailLevel; }
typedef PlanUnitOverlayBuilder = Widget? Function(BuildContext, PlanUnitOverlay);
enum PlanOverlaySize { natural, box }
final class PlanOverlayLayout { /* today's FloorPlanOverlayLayout fields and validation */ }
final class PlanServiceView extends StatefulWidget { /* spec S4 "Widgets" and "Events"; Task 16's Produces */ }
// PlanEditor gains the same service options and PlanServiceBar serviceBar; PlanCanvas gains Widget? unitOverlays.
// Internal: const double kServiceBarHeight = 44; validatePlanServiceBar, validatePlanOverlayLayout,
//   overlayDetailLevel, UnitOverlayLayer, RenderPlanUnitOverlays; on PlanController (R-13 ported):
//   @internal canvasAssumed(PlanMode, Offset), canvasMeasured(PlanMode, Offset, {Offset? chrome}),
//   chromeMoved(Offset from, Offset to); @visibleForTesting Map<PlanMode, Offset> planCanvasSeeds.
```

