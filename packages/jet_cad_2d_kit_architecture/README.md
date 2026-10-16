# jet_cad_2d_kit_architecture

The architecture kit of jet_cad_2d plans: walls, doors, windows and gaps,
room separators, rooms, dimensions, boxes, a furniture library and the
attachment of furniture to wall faces, as one `PlanKit` on the kit contract
(`jet_cad_2d_kit`).

A host loads it into the plan library (`jet_cad_2d_plan`):
`PlanController(kits: [architectureKit])`. The kit itself depends on the
contract only, never on the plan library.

This README is a stub; the kit's first release brings the full one.
