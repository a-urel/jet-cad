## 0.1.0 (unreleased)

The architecture kit of jet_cad_2d plans (sub-project 3a).

- `architectureKit`: the kit's descriptor (id `architecture`), its type and
  tool ids (`ArchitectureTypes`, `ArchitectureTools`), its words in
  English, German and Turkish, and its `prepare`, which gives a plan the
  plan library makes the separators' DASHED linetype.
- The box (`architecture.box`, `BoxParams`): a rectangle whose outline
  loses what lies inside an overlapping box; its width and height in the
  property panel; the Box tool (B).
- The wall (`architecture.wall`, `WallParams`, `Justification`): mitred
  joints, Ts and nodes; its two end grips, which move joined ends too; its
  thickness and justification in the property panel; the Wall tool (W),
  whose settings the panel edits while it is active.
- The room separator (`architecture.separator`, `SeparatorParams`): drawn
  DASHED, an input to rooms, left out of PDF and PNG exports; its two end
  grips and the Separator tool (S) trim an end to the wall face it enters.
