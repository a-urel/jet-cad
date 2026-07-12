import Cocoa
import CoreVideo
import FlutterMacOS
import IOSurface

/// Wraps one IOSurface-backed CVPixelBuffer as a Flutter external texture.
final class JetCadTexture: NSObject, FlutterTexture {
  private let lock = NSLock()
  private var pixelBuffer: CVPixelBuffer?

  func setSurface(_ buffer: CVPixelBuffer) {
    lock.lock()
    pixelBuffer = buffer
    lock.unlock()
  }

  func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    lock.lock()
    defer { lock.unlock() }
    guard let buffer = pixelBuffer else { return nil }
    return Unmanaged.passRetained(buffer)
  }
}

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
            let surfaceId = args["surfaceId"] as? Int
      else {
        result(FlutterError(
          code: "badArgs", message: "registerTexture needs surfaceId",
          details: nil))
        return
      }
      guard let buffer = Self.wrapSurface(UInt32(surfaceId)) else {
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
            let texture = textures[textureId]
      else {
        result(FlutterError(
          code: "badArgs",
          message: "updateSurface needs a registered textureId and surfaceId",
          details: nil))
        return
      }
      guard let buffer = Self.wrapSurface(UInt32(surfaceId)) else {
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
    var buffer: CVPixelBuffer?
    let attrs: [CFString: Any] = [
      kCVPixelBufferMetalCompatibilityKey: true
    ]
    let status = CVPixelBufferCreateWithIOSurface(
      kCFAllocatorDefault, surface, attrs as CFDictionary, &buffer)
    return status == kCVReturnSuccess ? buffer : nil
  }
}
