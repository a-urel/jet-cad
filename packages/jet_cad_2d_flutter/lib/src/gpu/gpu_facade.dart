/// The only file in this package that imports a GPU package.
///
/// **Why the import is off contract, and why it is confined here.**
/// `package:flutter_gpu` imports `dart:ffi` and `dart:nativewrappers` at
/// library level, so it cannot compile for the web. `flutter_scene` carries an
/// internal shim that re-exports it verbatim on native and falls back to its
/// own WebGL2 backend on web, selected by conditional export. That shim lives
/// under `lib/src/`, in a pre-1.0 package whose minor releases carry breaking
/// changes. Confining it to one file is what makes replacing it — with our own
/// conditional export over our own backend — an edit to this file rather than a
/// rewrite.
///
/// **Trigger for taking it in-house:** the first `flutter_scene` minor release
/// that breaks this file, or the first API the shim does not expose.
library;

// ignore: implementation_imports
import 'package:flutter_scene/src/gpu/gpu.dart' as gpu;

// ignore: implementation_imports
export 'package:flutter_scene/src/gpu/gpu.dart';

/// Builds a GPU context, or throws if the platform has none.
typedef GpuContextFactory = gpu.GpuContext Function();

GpuContextFactory? _override;
bool? _available;

/// **Test seam.** Replaces the platform probe; `null` restores it and clears
/// the cached answer.
///
/// Spec criterion 10 requires the fallback to be exercised deterministically,
/// and neither a missing `Info.plist` key nor absent hardware is a fixture a
/// suite can arrange.
void debugSetGpuFactory(GpuContextFactory? factory) {
  _override = factory;
  _available = null;
}

/// Whether this platform can serve the resident backend.
///
/// **Cached, and the cache is the point.** A platform without Flutter GPU must
/// answer once and then cost nothing; probing per frame would put a throwing
/// call on the frame path of exactly the devices that can least afford it.
bool gpuAvailable() {
  final cached = _available;
  if (cached != null) return cached;
  try {
    final factory = _override;
    if (factory != null) {
      factory();
    } else {
      // Touching the context is the probe: the getter throws on a platform
      // where Flutter GPU was not enabled.
      gpu.gpuContext.defaultColorFormat;
    }
    return _available = true;
  } catch (_) {
    return _available = false;
  }
}

/// **Test seam.** Pins [gpuAvailable]'s cached answer; `null` clears it so
/// the next call probes again.
///
/// [debugSetGpuFactory] can only make the answer `false` -- a factory that
/// throws -- because no test can construct a `gpu.GpuContext`. A widget test
/// that wants `DraftCanvas` to take the `residentGpu` path GPU-free (Ruling
/// F14) needs the answer `true`, and this is the only honest way to say it:
/// the path it enables still cannot upload, so such a test also injects a
/// `ResidentUploader` that never touches a GPU.
void debugSetGpuAvailable(bool? available) {
  _available = available;
}
