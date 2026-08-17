/// A pure-Dart 2D CAD engine and document model.
///
/// This package has no Flutter dependency and performs no rendering. The
/// widget layer lives in `jet_cad_2d_flutter`; format adapters live in their
/// own packages and use only this package's public API.
library;

export 'src/codec/json_codec.dart';
export 'src/codec/schema_version.dart';
export 'src/core/diagnostic.dart';
export 'src/core/handle.dart';
export 'src/core/list_equality.dart';
export 'src/core/tolerance.dart';
export 'src/document/command.dart';
export 'src/document/commands.dart';
export 'src/document/component.dart';
export 'src/document/doc_change.dart';
export 'src/document/draft_document.dart';
export 'src/document/extents.dart';
export 'src/document/header.dart';
export 'src/document/node.dart';
export 'src/document/origin_component.dart';
export 'src/document/raw_data.dart';
export 'src/document/resolved_style.dart';
export 'src/document/style.dart';
export 'src/document/style_context.dart';
export 'src/document/style_resolver.dart';
export 'src/document/tables.dart';
export 'src/document/text_scalars.dart';
export 'src/document/tree.dart';
export 'src/document/undo.dart';
export 'src/document/validate.dart';
export 'src/geometry/aabb2.dart';
export 'src/geometry/dasher.dart';
export 'src/geometry/distance.dart';
export 'src/geometry/primitives.dart';
export 'src/geometry/segment_clip.dart';
export 'src/geometry/transform2.dart';
export 'src/index/container_index.dart';
export 'src/index/convenience_queries.dart';
export 'src/index/dirty_list.dart';
export 'src/index/hit.dart';
export 'src/index/packed_rtree.dart';
export 'src/index/query_filter.dart';
export 'src/index/query_scratch.dart';
export 'src/index/snap.dart';
export 'src/index/spatial_index.dart';
export 'src/store/entity_store.dart';
export 'src/store/geometry_store.dart';
export 'src/store/slot_allocator.dart';
