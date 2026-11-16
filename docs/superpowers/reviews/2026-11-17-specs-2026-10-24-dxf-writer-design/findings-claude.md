F1 [major] Containers and transforms
claim: A `GroupNode`'s transform is baked into its leaves and a group with a component or `exportAsDxfGroup` becomes a DXF GROUP; "my call", with the anonymous-block alternative rejected.
evidence: `docs/superpowers/specs/2026-07-27-jet-cad-2d-architecture-design.md` ("GroupNode maps to an anonymous block, not to DXF GROUP"; designer groups export as anonymous blocks, declared in diagnostics) and the `GroupNode` doc comment in `packages/jet_cad_2d/lib/src/document/node.dart` say the opposite; the spec never states it supersedes that decision.
fix: Record explicitly that this spec supersedes the architecture spec's GroupNode-to-anonymous-block rule and the `GroupNode` doc comment, and say what `exportAsDxfGroup` now means for a group that already carries a component.

F2 [major] Semantics: the JETCAD data
claim: A GroupNode's `node` record (handle, parent, transform, visible, child order) lives in the GROUP's extension dictionary, so draw order and nesting are restorable; G4 writes "the scene tree's shape".
evidence: Per the same document's "DXF GROUP objects" rule only groups with a component or `exportAsDxfGroup` get a GROUP; `GroupNode` in `node.dart` allows a group with neither, and such a group then has no DXF object to hold its record, so its transform and children are lost.
fix: Name where a component-less, non-GROUP GroupNode's `node` record is written (for example in the document-level XRECORD keyed by handle), or write every GroupNode as a GROUP.

F3 [minor] Handles
claim: Records DXF needs get handles "minted above the document's highest handle", and the H2 test asserts a DXF with an omitted object equals byte-for-byte the DXF of the plan with that object deleted.
evidence: `HandleSeed.raiseTo` in `packages/jet_cad_2d/lib/src/core/handle.dart` never moves backward, so after a deletion the seed stays above the deleted handles while the highest handle written drops; the spec does not say whether "highest handle" is the seed or the highest handle written, and the two give different minted handles and different bytes.
fix: Define "highest handle" as the highest handle actually written (not the seed) so the omitted-versus-deleted byte comparison can hold, or drop byte equality for DXF in the H2 test.

F4 [minor] Entity style columns
claim: Transparency is code 440 and "the engine's 0–255 maps onto DXF's alpha encoding", pinned by a test at 0, 255 and a middle value.
evidence: `InstanceNode.transparency` in `node.dart` and `EntityRecord.transparency` also hold `kByBlock` (−2) and `kByLayer` (−1) sentinels defined in `packages/jet_cad_2d/lib/src/document/style.dart`; the spec maps neither.
fix: State that BYLAYER transparency omits code 440 and BYBLOCK writes DXF's by-block value, and add both to the pinned test.

F5 [minor] Handles
claim: A collision between an `OriginComponent` id and any other handle is resolved by minting a fresh handle and reporting a `Diagnostic`.
evidence: `packages/jet_cad_2d/lib/src/document/origin_component.dart` says the original id is kept because renumbering "silently breaks references inside preserved raw data"; the spec does not say which of the two colliding records is renumbered, and renumbering the origin record breaks exactly those references.
fix: Rule that the engine-minted record, never the origin-id record, takes the fresh handle, and that two origin ids colliding is a reported error.

F6 [minor] Tables
claim: A TTF text style "is written by font file name plus the family as the `ACAD` 1071 XDATA".
evidence: `TextStyleRecord` in `packages/jet_cad_2d/lib/src/document/tables.dart` has `fontFamily`, `widthFactor`, `obliqueAngle`, `fixedHeight`, `isShx`, `shxFileName` and no font file name for a TTF face.
fix: Say how the file name is derived from `fontFamily` (a fixed map, the family itself, or a `Diagnostic`) since the engine stores none.

F7 [minor] Version and header
claim: `$EXTMIN`/`$EXTMAX` come from `importedExtents` when set, otherwise the computed extents.
evidence: `DocumentHeader.importedExtents` in `packages/jet_cad_2d/lib/src/document/header.dart` is documented as "not the document's working extents", preserved verbatim from an import; a document imported, then edited and exported would write stale extents.
fix: Write the computed extents always, or only prefer `importedExtents` when the document is unchanged since import, and say which.

F8 [hunch] The plan library
claim: The shared H2 test compares each exporter's output over a plan with an `exported: false` object against the same plan with that object deleted.
evidence: not checked whether deleting a parametric object regenerates its neighbours (walls, rooms) and so changes the drawing; also no kit in `packages/*/lib` sets `exported: false` today (`PlanType.exported` in `packages/jet_cad_2d_kit/lib/src/kit/plan_type.dart` defaults to true), so the fixture needs a test type.
fix: Name the test type the fixture uses and require it to have no regeneration neighbours, or compare against a plan where the object was never created.

F9 [minor] Semantics: the JETCAD data
claim: A GroupNode's record carries handle, parent, transform, `visible` and child order so a reader restores the tree.
evidence: `GroupNode` in `node.dart` also persists `exportAsDxfGroup`, which the record omits; since a group with a component is also written as a GROUP, a reader cannot tell the flag's value from the file.
fix: Add `exportAsDxfGroup` to the group's `node` record.

VERDICT: revise — two unresolved conflicts with the architecture spec and the tree record; the rest are small decisions.
