#include "gl_context.hpp"

#ifdef __APPLE__

#define GL_SILENCE_DEPRECATION 1

#include <CoreFoundation/CoreFoundation.h>
#include <IOSurface/IOSurface.h>
#include <OpenGL/OpenGL.h>
#include <OpenGL/gl3.h>
#include <OpenGL/CGLIOSurface.h>
// NSOpenGLContext: OCCT's Aspect_RenderingContext is NSOpenGLContext* on
// desktop macOS (Aspect_RenderingContext.hxx), and OCCT calls Cocoa methods
// on it directly. GL_SILENCE_DEPRECATION (above) also silences AppKit's
// NSOpenGLContext deprecation warnings (see NSOpenGL.h's NS_OPENGL_*_DEPRECATED
// macros), matching OCCT's own Cocoa glue (OpenGl_Context_1.mm).
#include <Cocoa/Cocoa.h>

#include <stdexcept>
#include <string>

namespace jetcad {
namespace {

class CglContext final : public GlContext {
 public:
  CglContext() {
    // NOT requesting kCGLPFAOpenGLProfile/kCGLOGLPVersion_3_2_Core (Plan 3
    // Task 3 finding): OCCT's macOS Cocoa glue (OpenGl_Window_1.mm) hardcodes
    // isCoreProfile=false whenever an external rendering context is supplied
    // to V3d_View::SetWindow, and OpenGl_Context::init() unconditionally
    // queries the legacy-only GL_MAX_CLIP_PLANES enum on desktop GL — illegal
    // in a real Core Profile context, which is silently tolerated as a
    // "sticky" GL_INVALID_ENUM by most native drivers but corrupts later,
    // unrelated calls (texture/VBO creation, all failing with
    // GL_INVALID_OPERATION) under macOS's OpenGL-on-Metal translation layer
    // used on this hardware ("4.1 Metal - 90.5", confirmed via a standalone
    // repro). Omitting the profile attribute yields CGL's default Legacy
    // (2.1) profile, where GL_MAX_CLIP_PLANES is valid — confirmed via the
    // same repro (GL_MAX_CLIP_PLANES=6, no error) — and which also matches
    // what OCCT's external-context code path already assumes, so there is no
    // profile mismatch. OCCT's shader/VBO/FBO rendering (GLSL, ARB_vertex_
    // buffer_object, ARB_framebuffer_object) all predate GL 3.2 core and are
    // available as extensions under this Legacy/Metal-backed 2.1 context.
    CGLPixelFormatAttribute attrs[] = {
        kCGLPFAColorSize, (CGLPixelFormatAttribute)24,
        kCGLPFAAlphaSize, (CGLPixelFormatAttribute)8,
        kCGLPFADepthSize, (CGLPixelFormatAttribute)24,
        kCGLPFAAccelerated,
        (CGLPixelFormatAttribute)0,
    };
    CGLPixelFormatObj pixelFormat = nullptr;
    GLint virtualScreens = 0;
    CGLError err = CGLChoosePixelFormat(attrs, &pixelFormat, &virtualScreens);
    if (err != kCGLNoError || pixelFormat == nullptr) {
      throw std::runtime_error("CGLChoosePixelFormat failed: " +
                               std::string(CGLErrorString(err)));
    }
    err = CGLCreateContext(pixelFormat, nullptr, &context_);
    CGLDestroyPixelFormat(pixelFormat);
    if (err != kCGLNoError || context_ == nullptr) {
      throw std::runtime_error("CGLCreateContext failed: " +
                               std::string(CGLErrorString(err)));
    }
    // Wrap the SAME CGL context in an NSOpenGLContext: OCCT's
    // Aspect_RenderingContext is NSOpenGLContext* on desktop macOS and it
    // invokes Objective-C methods on it (-makeCurrentContext, -flushBuffer);
    // a raw CGLContextObj reinterpreted as that type would crash. Per Apple
    // docs -initWithCGLContextObj: adopts the given context as-is (it does
    // not create a new/shared one), so all GL objects (textures, FBOs)
    // created via our own raw CGL calls remain valid through this wrapper.
    nsContext_ = [[NSOpenGLContext alloc] initWithCGLContextObj:context_];
    if (nsContext_ == nil) {
      CGLDestroyContext(context_);
      context_ = nullptr;
      throw std::runtime_error(
          "NSOpenGLContext initWithCGLContextObj failed");
    }
    makeCurrent();
  }

  ~CglContext() override {
    if (context_ != nullptr) {
      CGLSetCurrentContext(context_);
      destroySurfaceFramebuffer();
      if (nsContext_ != nil) {
        [NSOpenGLContext clearCurrentContext];
        [nsContext_ release];
        nsContext_ = nil;
      } else {
        CGLSetCurrentContext(nullptr);
      }
      CGLDestroyContext(context_);
    }
  }

  void makeCurrent() override {
    // Routed through the NSOpenGLContext wrapper (not raw
    // CGLSetCurrentContext) so Cocoa's own "current context" bookkeeping
    // (+[NSOpenGLContext currentContext], consulted by some OCCT code
    // paths) stays consistent with what is actually current at the CGL
    // level.
    [nsContext_ makeCurrentContext];
    if (CGLGetCurrentContext() != context_) {
      throw std::runtime_error("NSOpenGLContext makeCurrentContext failed");
    }
  }

  uint32_t createSurfaceFramebuffer(int widthPx, int heightPx) override {
    if (widthPx <= 0 || heightPx <= 0) {
      throw std::runtime_error("surface size must be positive");
    }
    makeCurrent();
    destroySurfaceFramebuffer();

    const int kBytesPerElement = 4;
    CFMutableDictionaryRef props = CFDictionaryCreateMutable(
        kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks,
        &kCFTypeDictionaryValueCallBacks);
    auto setInt = [&props](CFStringRef key, int32_t value) {
      CFNumberRef num = CFNumberCreate(kCFAllocatorDefault,
                                       kCFNumberSInt32Type, &value);
      CFDictionarySetValue(props, key, num);
      CFRelease(num);
    };
    setInt(kIOSurfaceWidth, widthPx);
    setInt(kIOSurfaceHeight, heightPx);
    setInt(kIOSurfaceBytesPerElement, kBytesPerElement);
    setInt(kIOSurfacePixelFormat, (int32_t)'BGRA');
    surface_ = IOSurfaceCreate(props);
    CFRelease(props);
    if (surface_ == nullptr) {
      throw std::runtime_error("IOSurfaceCreate failed");
    }

    glGenTextures(1, &colorTexture_);
    glBindTexture(GL_TEXTURE_RECTANGLE, colorTexture_);
    CGLError err = CGLTexImageIOSurface2D(
        context_, GL_TEXTURE_RECTANGLE, GL_RGBA8, widthPx, heightPx, GL_BGRA,
        GL_UNSIGNED_INT_8_8_8_8_REV, surface_, 0);
    if (err != kCGLNoError) {
      throw std::runtime_error("CGLTexImageIOSurface2D failed: " +
                               std::string(CGLErrorString(err)));
    }
    glBindTexture(GL_TEXTURE_RECTANGLE, 0);

    glGenRenderbuffers(1, &depthStencil_);
    glBindRenderbuffer(GL_RENDERBUFFER, depthStencil_);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, widthPx,
                          heightPx);
    glBindRenderbuffer(GL_RENDERBUFFER, 0);

    glGenFramebuffers(1, &framebuffer_);
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer_);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                           GL_TEXTURE_RECTANGLE, colorTexture_, 0);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT,
                              GL_RENDERBUFFER, depthStencil_);
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
      throw std::runtime_error("surface framebuffer incomplete: " +
                               std::to_string(status));
    }
    width_ = widthPx;
    height_ = heightPx;
    return IOSurfaceGetID(surface_);
  }

  void bindSurfaceFramebuffer() override {
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer_);
  }

  unsigned framebufferId() const override { return framebuffer_; }

  uint32_t surfaceId() const override {
    return surface_ != nullptr ? IOSurfaceGetID(surface_) : 0;
  }

  int width() const override { return width_; }
  int height() const override { return height_; }

  void* nativeContext() override { return (void*)nsContext_; }

  void flush() override { glFlush(); }

  std::vector<uint8_t> readPixels(int x, int y, int w, int h) override {
    makeCurrent();
    bindSurfaceFramebuffer();
    std::vector<uint8_t> rgba(static_cast<size_t>(w) * h * 4);
    glPixelStorei(GL_PACK_ALIGNMENT, 1);
    glReadPixels(x, y, w, h, GL_RGBA, GL_UNSIGNED_BYTE, rgba.data());
    return rgba;
  }

 private:
  void destroySurfaceFramebuffer() {
    if (framebuffer_ != 0) {
      glDeleteFramebuffers(1, &framebuffer_);
      framebuffer_ = 0;
    }
    if (depthStencil_ != 0) {
      glDeleteRenderbuffers(1, &depthStencil_);
      depthStencil_ = 0;
    }
    if (colorTexture_ != 0) {
      glDeleteTextures(1, &colorTexture_);
      colorTexture_ = 0;
    }
    if (surface_ != nullptr) {
      CFRelease(surface_);
      surface_ = nullptr;
    }
    width_ = 0;
    height_ = 0;
  }

  CGLContextObj context_ = nullptr;
  NSOpenGLContext* nsContext_ = nil;
  IOSurfaceRef surface_ = nullptr;
  GLuint colorTexture_ = 0;
  GLuint depthStencil_ = 0;
  GLuint framebuffer_ = 0;
  int width_ = 0;
  int height_ = 0;
};

}  // namespace

std::unique_ptr<GlContext> GlContext::create() {
  return std::make_unique<CglContext>();
}

}  // namespace jetcad

#else  // !__APPLE__

namespace jetcad {
std::unique_ptr<GlContext> GlContext::create() {
  throw std::runtime_error("GlContext: no implementation for this platform");
}
}  // namespace jetcad

#endif
