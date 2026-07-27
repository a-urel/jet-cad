/// A pure-Dart 2D CAD engine and document model.
///
/// This package has no Flutter dependency and performs no rendering. The
/// widget layer lives in `jet_cad_2d_flutter`; format adapters live in their
/// own packages and use only this package's public API.
library;

export 'src/core/diagnostic.dart';
export 'src/core/handle.dart';
export 'src/core/list_equality.dart';
export 'src/core/tolerance.dart';
export 'src/geometry/transform2.dart';
