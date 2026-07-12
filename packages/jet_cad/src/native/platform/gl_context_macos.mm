#include "gl_context.hpp"

#ifdef __APPLE__

#define GL_SILENCE_DEPRECATION 1

#include <CoreFoundation/CoreFoundation.h>
#include <IOSurface/IOSurface.h>
#include <OpenGL/OpenGL.h>
#include <OpenGL/gl3.h>
#include <OpenGL/CGLIOSurface.h>

#include <stdexcept>
#include <string>

namespace jetcad {
namespace {

class CglContext final : public GlContext {
 public:
  CglContext() {
    CGLPixelFormatAttribute attrs[] = {
        kCGLPFAOpenGLProfile,
        (CGLPixelFormatAttribute)kCGLOGLPVersion_3_2_Core,
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
    makeCurrent();
  }

  ~CglContext() override {
    if (context_ != nullptr) {
      CGLSetCurrentContext(context_);
      destroySurfaceFramebuffer();
      CGLSetCurrentContext(nullptr);
      CGLDestroyContext(context_);
    }
  }

  void makeCurrent() override {
    if (CGLSetCurrentContext(context_) != kCGLNoError) {
      throw std::runtime_error("CGLSetCurrentContext failed");
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

  void* nativeContext() override { return context_; }

  void flush() override { glFlush(); }

  std::vector<uint8_t> readPixels(int x, int y, int w, int h) override {
    makeCurrent();
    bindSurfaceFramebuffer();
    std::vector<uint8_t> rgba(static_cast<size_t>(w) * h * 4);
    glPixelStorei(GL_PACK_ALIGNMENT, 1);
    glReadPixels(x, y, w, h, GL_RGBA, GL_UNSIGNED_BYTE, rgba.data());
    return rgba;
  }

  void renderTestPattern() override {
    makeCurrent();
    bindSurfaceFramebuffer();
    glViewport(0, 0, width_, height_);
    glEnable(GL_SCISSOR_TEST);
    const int hw = width_ / 2;
    const int hh = height_ / 2;
    auto clearRect = [&](int x, int y, int w, int h, float r, float g,
                         float b) {
      glScissor(x, y, w, h);
      glClearColor(r, g, b, 1.0f);
      glClear(GL_COLOR_BUFFER_BIT);
    };
    // GL origin is bottom-left.
    clearRect(0, 0, hw, hh, 0.f, 0.f, 1.f);        // bottom-left: blue
    clearRect(hw, 0, hw, hh, 1.f, 1.f, 1.f);       // bottom-right: white
    clearRect(0, hh, hw, hh, 1.f, 0.f, 0.f);       // top-left: red
    clearRect(hw, hh, hw, hh, 0.f, 1.f, 0.f);      // top-right: green
    glDisable(GL_SCISSOR_TEST);
    flush();
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
