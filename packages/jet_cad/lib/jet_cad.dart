/// A headless-first CAD engine and viewport for Flutter, backed by OCCT.
///
/// v1 surface: pure-Dart document model over an abstract kernel bridge.
/// The FFI/OCCT backend and the viewport widget arrive in later milestones.
library;

export 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;

export 'src/document/cad_document.dart' show CadDocument;
export 'src/document/codec.dart' show CadDocumentCodec;
export 'src/document/doc_change.dart';
export 'src/document/entity.dart';
export 'src/document/operation.dart';
export 'src/kernel/fake_kernel_bridge.dart' show FakeKernelBridge;
export 'src/kernel/ffi_kernel_bridge_export.dart' show FfiKernelBridge;
export 'src/kernel/kernel_bridge.dart' show KernelBridge;
export 'src/kernel/kernel_types.dart';
export 'src/viewport/jet_cad_viewport.dart' show JetCadViewport;
export 'src/viewport/viewport_controller.dart'
    show SelectionChanged, ViewportController;
