F1 [major] Semantics: the JETCAD data
claim: Group and instance metadata suffice to restore the scene tree after group transforms are baked.
evidence: In document/node.dart, GroupNode.children contains nodes only; EntityRecord.owner in store/entity_store.dart is authoritative leaf membership. The specified metadata omits leaf owners, and component-free groups without exportAsDxfGroup receive no GROUP to carry their records.
fix: Define metadata for every node and every leaf’s original owner, including a storage location for groups without DXF GROUP objects.
F2 [major] Containers and transforms
claim: Sheared instances are exploded while engine records retain their own handles.
evidence: InstanceNode.definition in document/node.dart permits multiple placements of one definition; exploding two placements duplicates the same definition-leaf handles, conflicting with Handles and the uniqueness gate.
fix: Specify fresh handles for exploded occurrences and metadata mapping each occurrence to its original instance and definition leaf.
F3 [major] Containers and transforms
claim: Exploding a sheared instance preserves the drawing, with the instance’s style fields placed on its INSERT.
evidence: The exploded case has no INSERT; DocumentStyleResolver.contextFor and styleFor resolve BYBLOCK properties, layer-0 substitution, and multiplicative linetype scales through that missing instance.
fix: Require exploded leaves to receive the effective styles and layers of their original instance chain, while preserving original values in metadata.
F4 [major] The plan library
claim: Passing omitted objects through the exporters enforces subtree exclusion consistently for PDF, PNG, and DXF.
evidence: export/builtin_exporters.dart passes request.omitted directly to existing render exporters; reference_walk.dart explicitly visits omitted groups’ children, and test/export/omit_owners_test.dart requires their nested leaves and instances to remain drawn.
fix: Include changes to PDF and PNG omission semantics and their existing tests so omitted subtrees disappear in every format.
F5 [major] The plan library
claim: DXF bytes with an omitted object must equal bytes after deleting that object.
evidence: Version and header requires document-computed extents, while Handles allocates synthetic handles above the document’s highest handle; DraftDocument.extents includes existing geometry, so an omitted distant object or highest handle changes output relative to deletion.
fix: Define a filtered export view used consistently for extents, handle allocation, tree metadata, and definition reachability.
F6 [major] Version and header
claim: Computed document extents can be emitted while retaining codec-like byte determinism.
evidence: DocumentHeader.importedExtents documents why working extents are excluded from persistence: text bounds depend on fonts and platform; document/extents.dart uses TextMeasurer, and text_metrics.dart supplies measurers with different results for identical stored content.
fix: Specify deterministic export bounds independent of runtime text metrics, or explicitly narrow the determinism guarantee and test its limits.
F7 [major] Entities
claim: TEXT preserves TextJustifyH/V and supplies a second alignment point where required.
evidence: TextLayout.resolve in document/text_geometry.dart explicitly downgrades aligned and fit to left because GeometryPayload lacks their required second alignment point.
fix: Specify the aligned/fit fallback and diagnostic, and define how original justification survives in metadata.
F8 [major] Entity style columns
claim: Transparency is mapped from the engine’s 0–255 range into code 440.
evidence: EntityRecord.transparency also accepts kByLayer and kByBlock; InstanceNode.transparency defaults to kByBlock, and DocumentStyleResolver resolves both sentinels separately from concrete transparency.
fix: Define mappings and tests for inherited transparency on entities and INSERTs as well as concrete alpha values.
F9 [major] Semantics: the JETCAD data
claim: The document record carries enough manifest information to identify every kit used by the exported plan.
evidence: newPlanDocument attaches no manifest; encodePlan constructs the current manifest without modifying the document, while PlanPageFlows._copyOf uses DraftDocumentCodec directly, leaving export requests with an absent or stale manifest.
fix: Have the plan export flow supply a freshly computed manifest before invoking the engine-only writer.
F10 [major] Draw order
claim: Ascending entity file order preserves screen stacking without a sort table.
evidence: reference_walk.dart sorts instance-owned ATTRIB leaves independently among enclosing-container items, whereas Entities requires ATTRIB records immediately after INSERT; an overlapping ordinary leaf whose handle falls between INSERT and ATTRIB produces incompatible orders.
fix: Decide how attribute stacking is preserved or declared lossy, and add an overlapping fixture that exposes the ordering conflict.
VERDICT: revise — Tree restoration, exploded instances, omission, manifests, and attribute ordering need explicit decisions before implementation.
