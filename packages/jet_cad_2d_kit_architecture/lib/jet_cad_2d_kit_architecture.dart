/// The architecture kit of jet_cad_2d plans (sub-project 3a): walls,
/// openings, room separators, rooms, dimensions, boxes, a furniture library
/// and wall attachment, as one `PlanKit` a host passes to the plan library,
/// `PlanController(kits: [architectureKit])`. The parameter classes and the
/// type ids let a host build a plan in code.
library;

export 'src/ids.dart' show ArchitectureTools, ArchitectureTypes;
export 'src/kit.dart' show architectureKit;
