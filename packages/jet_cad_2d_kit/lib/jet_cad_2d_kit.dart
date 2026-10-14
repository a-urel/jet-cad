/// The kit contract of jet_cad_2d plans: the components a plan stores, the
/// `.jetlib` symbol library format, a kit's words, its symbol sources, its
/// code side (parametric types, tools, property specs, colour targets,
/// attachment providers, the services a plan gives them, diagnostics) and
/// its `PlanKit` descriptor.
///
/// A Flutter library: it reads bundled assets and builds on the Flutter
/// layer's tools and grips. The model it exports is pure Dart and is shared
/// with `package:jet_cad_2d_kit/authoring.dart`.
library;

export 'src/kit/attachment.dart';
export 'src/kit/bundled_library.dart';
export 'src/kit/colour.dart';
export 'src/kit/host_words.dart';
export 'src/kit/kit_diagnostic.dart';
export 'src/kit/plan_kit.dart';
export 'src/kit/plan_services.dart';
export 'src/kit/plan_tool.dart';
export 'src/kit/plan_type.dart';
export 'src/kit/properties.dart';
export 'src/kit/swatch.dart';
export 'src/kit/symbol_library_source.dart';
export 'src/kit/symbols_state.dart';
export 'src/kit/unit_label.dart';
export 'src/model/model.dart';
