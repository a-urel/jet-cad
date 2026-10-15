/// The architecture kit of jet_cad_2d plans (sub-project 3a): walls,
/// openings, room separators, rooms, dimensions, boxes, a furniture library
/// and wall attachment, as one `PlanKit` a host passes to the plan library,
/// `PlanController(kits: [architectureKit])`. The parameter classes and the
/// type ids let a host build a plan in code.
library;

export 'src/box/box.dart' show BoxParams;
export 'src/ids.dart' show ArchitectureTools, ArchitectureTypes;
export 'src/kit.dart' show architectureKit;
export 'src/wall/wall.dart' show Justification, WallParams;
export 'src/opening/opening.dart'
    show HingeEnd, OpeningKind, OpeningParams, SwingSide;
export 'src/separator/separator.dart' show SeparatorParams;
