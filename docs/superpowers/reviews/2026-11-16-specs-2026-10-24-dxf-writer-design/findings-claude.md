F1 [major] The plan library — H2 enforced by test
claim: Each exporter's output for a plan with an `exported: false` object equals, byte for byte (PNG and DXF), the output of the same plan with that object deleted.
evidence: `PlanPageFlows.omittedOf` in packages/jet_cad_2d_plan/lib/src/export/page_flows.dart returns group handles only and leaves the geometry in the copy; `DraftDocument.extents` is computed over every entity, so the spec's own "$EXTMIN/$EXTMAX: the document's computed extents", the parent's JETCAD `node` child-order list (which still names the omitted child) and "handles minted above the document's highest handle" all differ between the two documents; deleting a parametric object may also regenerate neighbours.
fix: State that extents, child-order lists and the minting base are computed over what is written, and pick a fixture whose deletion regenerates nothing, or replace byte equality for DXF with a structural comparison.

F2 [major] Containers and transforms — DXF GROUP objects / Semantics — The document
claim: Every `GroupNode` that carries a component is written as a DXF GROUP of every leaf and INSERT beneath it; the document XRECORD holds "anything document-level the plan's text carries (its manifest)".
evidence: `DocumentTree` (packages/jet_cad_2d/lib/src/document/tree.dart) requires a `GroupNode` root, and the plan attaches `ManifestComponent` and `PageComponent` to `document.rootHandle` (manifest.dart, builtin_exporters.dart), so the root is a component-carrying group with no DXF object to own its XRECORD; the writer may not know what a manifest is (H5).
fix: Exclude the root from the GROUP rule and define that the root handle's components go into the document XRECORD generically, without naming the manifest.

F3 [major] Handles
claim: A record is written under its own handle, or under its `OriginComponent` id when `source == dxf`; the JETCAD `node` record carries "its handle, parent ... and child order", and a reader restores the tree "from these plus the handles".
evidence: `OriginComponent.id` is a free string; `GroupNode.children`, `InstanceNode.definition` and the fill payload's boundary handle (`AddRegionCommand.apply`) are all engine handles; nothing says whether pointers in JETCAD JSON and in DXF codes 330/340 are engine handles or written ids.
fix: State that every pointer written, including the JETCAD JSON, is in written-handle space and that a reader maps written ids back to engine handles.

F4 [major] Entity style columns — Transparency
claim: "The engine's 0–255 maps onto DXF's alpha encoding"; a test pins 0, 255 and a middle value.
evidence: `EntityStore._transparency` is an `Int16List` because "transparency may itself be BYLAYER or BYBLOCK" (entity_store.dart), and `InstanceNode.transparency` defaults to `kByBlock` (-2); `LayerRecord.transparency` is an int too.
fix: Define the mapping for `kByLayer` (code 440 absent) and `kByBlock` (DXF's BYBLOCK alpha value) on entities, INSERTs and layers, and add a "BYBLOCK transparency written as 0" mutation.

F5 [minor] Containers and transforms — GroupNode
claim: Groups are baked into their leaves and written as DXF GROUPs, never as anonymous blocks (*my call*).
evidence: The engine's own `GroupNode` doc comment in packages/jet_cad_2d/lib/src/document/node.dart says it "Exports as an anonymous block rather than a DXF GROUP, because GROUP is a flat handle list that can represent neither nesting nor a transform."
fix: Record that this spec supersedes the `GroupNode` doc comment and that the plan rewrites it.

F6 [minor] Containers and transforms — InstanceNode
claim: An instance with shear is written exploded, its definition's leaves transformed into the parent's space.
evidence: `InstanceNode` owns ATTRIB entities (node.dart doc comment) and a `Definition` may contain nested `InstanceNode`s; the spec says nothing about the exploded instance's ATTRIBs, nested INSERTs, or whether a BLOCK is still written when every instance of it is exploded (it interacts with "a definition used only by omitted instances is not written").
fix: Define the exploded case for ATTRIBs and nested instances, and say whether the definition's BLOCK is still emitted.

F7 [minor] Tables — TextStyleRecord
claim: A TTF family is written "by font file name plus the family as the ACAD 1071 XDATA".
evidence: `TextStyleRecord` in packages/jet_cad_2d/lib/src/document/tables.dart has `fontFamily`, `isShx` and `shxFileName` only; no font file name exists for a TTF style.
fix: Say how the file name in code 3 is derived from `fontFamily` (or that it is left empty and only the XDATA names the family).

F8 [minor] The plan library
claim: `jet_cad_2d_plan` gains a dependency on `jet_cad_2d_dxf`, a public field and a result field; "both are additions, not breaking changes".
evidence: packages/jet_cad_2d_plan/pubspec.yaml is at 1.0.2 (the spec predates the 1.0 release); `PlanExportRequest`'s constructor in registries.dart takes required named parameters, so a new reporting channel is non-breaking only if optional; no version bump is named.
fix: Name the plan library's version (a minor bump) and require that the new request member be optional with a default.

F9 [minor] Entity style columns — Hidden nodes
claim: A leaf under a node with `visible == false` is written invisible.
evidence: `InstanceNode.visible` exists (node.dart), but the spec does not say whether an invisible instance's INSERT carries code 60, whether its definition's leaves do, or whether invisible leaves still join their GROUP.
fix: State that an invisible `InstanceNode` writes code 60 on the INSERT only and that invisibility does not change GROUP membership.

F10 [minor] Verification — H2 enforced by test
claim: "A new built-in exporter joins the test's list."
evidence: `PlanPageFlows.checkRegistry` and the built-ins in builtin_exporters.dart are a hand-written pair; a test over a hand-written list cannot catch an exporter that was not added to it.
fix: Have the test enumerate the plan library's default exporter list itself, so a new built-in is covered without an edit.

F11 [hunch] Version and header
claim: AC1027 (R2013) "is the oldest version that is UTF-8 throughout" and carries true colour, transparency and lineweight natively.
evidence: not checked (external fact, nothing in the repository pins DXF version history); my recollection is that UTF-8 arrived with R2007/AC1021 and true colour and transparency with R2004/AC1018, which does not change the choice of AC1027 but makes its stated reason wrong.
fix: Restate the reason for R2013 (every current reader and AutoCAD since 2013 opens it) without the "oldest UTF-8" claim.

VERDICT: revise — the H2 byte-equality test, the root group and the handle space need decisions before a plan can be cut.
