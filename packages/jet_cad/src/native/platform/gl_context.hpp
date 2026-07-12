#pragma once

#include <cstdint>
#include <memory>
#include <vector>

namespace jetcad {

// Platform-owned GL context + IOSurface-backed offscreen framebuffer.
//
// This is the ONLY file family that may touch platform windowing/graphics
// APIs (CGL/IOSurface today, ANGLE/EGL later). Everything else in the shim
// talks to this interface, so swapping macOS to ANGLE is a contained change.
class GlContext {
 public:
  virtual ~GlContext() = default;

  // Creates the platform context. Throws std::runtime_error if the platform
  // has no implementation or context creation fails.
  static std::unique_ptr<GlContext> create();

  // Makes the context current on the calling thread. Call at the start of
  // every command that touches GL — commands are serialized per session but
  // thread identity is not guaranteed across calls.
  virtual void makeCurrent() = 0;

  // (Re)allocates the IOSurface, its color texture, the FBO and a
  // depth-stencil attachment at the given pixel size. Destroys any previous
  // allocation. Returns the global IOSurfaceID that other processes /
  // frameworks can look up.
  virtual uint32_t createSurfaceFramebuffer(int widthPx, int heightPx) = 0;

  // Binds the surface FBO as GL_FRAMEBUFFER.
  virtual void bindSurfaceFramebuffer() = 0;

  virtual unsigned framebufferId() const = 0;
  virtual uint32_t surfaceId() const = 0;
  virtual int width() const = 0;
  virtual int height() const = 0;

  // The native context handle (CGLContextObj on macOS), passed to OCCT as
  // Aspect_RenderingContext. Opaque to callers.
  virtual void* nativeContext() = 0;

  // Flushes GL work so IOSurface consumers (Metal/CoreVideo) observe it.
  virtual void flush() = 0;

  // Reads RGBA pixels from the surface FBO; rows are bottom-up exactly as
  // glReadPixels returns them.
  virtual std::vector<uint8_t> readPixels(int x, int y, int w, int h) = 0;

  // Spike helper, removed with the spike (Plan 3 Task 3): fills the surface
  // FBO with an orientation-asymmetric quadrant test pattern.
  virtual void renderTestPattern() = 0;
};

}  // namespace jetcad
