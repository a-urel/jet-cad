import Cocoa
import CoreVideo
import FlutterMacOS
import IOSurface

/// Wraps one IOSurface-backed CVPixelBuffer as a Flutter external texture.
///
/// Threading: Flutter's engine invokes `copyPixelBuffer()` from its raster
/// thread on every compositor frame, while `setSurface(_:)` is invoked from
/// whatever thread handles the plugin's method channel (the platform/main
/// thread). Those two calls race on `pixelBuffer` with no other synchronization
/// from the engine, so the `NSLock` is required — without it, a resize that
/// swaps in a new pixel buffer mid-composite could tear or crash.
final class JetCadTexture: NSObject, FlutterTexture {
  private let lock = NSLock()
  private var pixelBuffer: CVPixelBuffer?

  /// Publishes a new backing buffer. Safe to call from any thread; the next
  /// `copyPixelBuffer()` (raster thread) observes it under the lock.
  func setSurface(_ buffer: CVPixelBuffer) {
    lock.lock()
    pixelBuffer = buffer
    lock.unlock()
  }

  /// Called by the Flutter engine's raster thread on each composite. Returns
  /// a retained (+1) reference per the `FlutterTexture` contract; the engine
  /// releases it after use.
  func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    lock.lock()
    defer { lock.unlock() }
    guard let buffer = pixelBuffer else { return nil }
    return Unmanaged.passRetained(buffer)
  }
}

/// Registers Flutter external textures backed by IOSurfaces produced by the
/// native OCCT viewer, over the `jet_cad/texture` MethodChannel.
///
/// Channel contract (all methods invoked from Dart; see
/// `lib/src/viewport/texture_binding.dart` for the Dart-side wrapper):
///
/// | method              | arguments                              | result                       |
/// |----------------------|-----------------------------------------|------------------------------|
/// | `registerTexture`    | `{surfaceId: Int}`                      | `Int` texture id             |
/// | `updateSurface`      | `{textureId: Int, surfaceId: Int}`      | `nil`                        |
/// | `frameReady`         | `{textureId: Int}`                      | `nil`                        |
/// | `unregisterTexture`  | `{textureId: Int}`                      | `nil` (idempotent)           |
///
/// Every method validates its arguments and reports malformed or unknown ids
/// as a `FlutterError` (`code: "badArgs"` for shape/type/range problems,
/// `code: "surfaceNotFound"` when the IOSurface id doesn't resolve) rather
/// than trapping; `unregisterTexture` on an id that is already gone is a
/// silent no-op so dispose paths can call it unconditionally.
public class JetCadPlugin: NSObject, FlutterPlugin {
  private let registry: FlutterTextureRegistry
  private var textures: [Int64: JetCadTexture] = [:]

  init(registry: FlutterTextureRegistry) {
    self.registry = registry
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "jet_cad/texture", binaryMessenger: registrar.messenger)
    let instance = JetCadPlugin(registry: registrar.textures)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "registerTexture":
      guard let args = call.arguments as? [String: Any],
            let surfaceId = args["surfaceId"] as? Int,
            let ioSurfaceId = UInt32(exactly: surfaceId)
      else {
        // `UInt32(exactly:)` (rather than the trapping `UInt32(_:)`) so a
        // negative or oversized surfaceId reports a FlutterError instead of
        // crashing the process.
        result(FlutterError(
          code: "badArgs",
          message: "registerTexture needs a non-negative 32-bit surfaceId",
          details: nil))
        return
      }
      guard let buffer = Self.wrapSurface(ioSurfaceId) else {
        result(FlutterError(
          code: "surfaceNotFound",
          message: "IOSurface \(surfaceId) not found or not wrappable",
          details: nil))
        return
      }
      let texture = JetCadTexture()
      texture.setSurface(buffer)
      let textureId = registry.register(texture)
      textures[textureId] = texture
      result(textureId)

    case "updateSurface":
      guard let args = call.arguments as? [String: Any],
            let textureId = (args["textureId"] as? NSNumber)?.int64Value,
            let surfaceId = args["surfaceId"] as? Int,
            let ioSurfaceId = UInt32(exactly: surfaceId),
            let texture = textures[textureId]
      else {
        result(FlutterError(
          code: "badArgs",
          message: "updateSurface needs a registered textureId and a "
            + "non-negative 32-bit surfaceId",
          details: nil))
        return
      }
      guard let buffer = Self.wrapSurface(ioSurfaceId) else {
        result(FlutterError(
          code: "surfaceNotFound",
          message: "IOSurface \(surfaceId) not found or not wrappable",
          details: nil))
        return
      }
      texture.setSurface(buffer)
      registry.textureFrameAvailable(textureId)
      result(nil)

    case "frameReady":
      guard let args = call.arguments as? [String: Any],
            let textureId = (args["textureId"] as? NSNumber)?.int64Value
      else {
        result(FlutterError(
          code: "badArgs", message: "frameReady needs textureId", details: nil))
        return
      }
      registry.textureFrameAvailable(textureId)
      result(nil)

    case "unregisterTexture":
      guard let args = call.arguments as? [String: Any],
            let textureId = (args["textureId"] as? NSNumber)?.int64Value
      else {
        result(FlutterError(
          code: "badArgs", message: "unregisterTexture needs textureId",
          details: nil))
        return
      }
      if textures.removeValue(forKey: textureId) != nil {
        registry.unregisterTexture(textureId)
      }
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func wrapSurface(_ surfaceId: UInt32) -> CVPixelBuffer? {
    guard let surface = IOSurfaceLookup(surfaceId) else { return nil }
    // CoreVideo's C signature (CVPixelBufferRef * pixelBufferOut) lacks the
    // ownership annotations ClangImporter needs to bridge it directly to
    // `CVPixelBuffer?`; it imports the out-param as `Unmanaged<CVPixelBuffer>?`
    // instead. `takeRetainedValue()` matches the header's "new pixel buffer
    // returned here" contract (a +1 we now own).
    var unmanagedBuffer: Unmanaged<CVPixelBuffer>?
    let attrs: [CFString: Any] = [
      kCVPixelBufferMetalCompatibilityKey: true
    ]
    let status = CVPixelBufferCreateWithIOSurface(
      kCFAllocatorDefault, surface, attrs as CFDictionary, &unmanagedBuffer)
    guard status == kCVReturnSuccess, let unmanagedBuffer else { return nil }
    return unmanagedBuffer.takeRetainedValue()
  }
}
