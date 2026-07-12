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

  // Native rendering context handle for OCCT's Aspect_RenderingContext.
  // NOT simply the raw CGLContextObj on macOS: Aspect_RenderingContext.hxx
  // typedefs this to NSOpenGLContext* on desktop macOS, and OCCT calls
  // Objective-C methods on it directly (-makeCurrentContext, -flushBuffer —
  // confirmed against OCCT 7.9.3's OpenGl_Context_1.mm), so handing it a
  // raw CGLContextObj would crash. Implementations must return a real
  // NSOpenGLContext* wrapping the same underlying CGL context used
  // elsewhere in this interface, so GL objects created on one side (e.g.
  // the surface FBO) are visible to callers using the other. Opaque to
  // callers other than the OCCT viewer wiring.
  virtual void* nativeContext() = 0;

  // Flushes GL work so IOSurface consumers (Metal/CoreVideo) observe it.
  virtual void flush() = 0;

  // Drains the GL error queue (glGetError until GL_NO_ERROR). OpenGL
  // errors are sticky: an illegal call anywhere earlier stays pending
  // until read, and whoever polls glGetError() next gets blamed for it.
  // Call before handing control to code that self-checks its GL calls
  // (OCCT's viewer does after buffer/texture creation).
  virtual void drainErrors() = 0;

  // Reads RGBA pixels from the surface FBO; rows are bottom-up exactly as
  // glReadPixels returns them.
  virtual std::vector<uint8_t> readPixels(int x, int y, int w, int h) = 0;
};

}  // namespace jetcad
