# Plan 3: Interactive Viewport Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A `JetCadViewport` widget + `ViewportController` that displays real OCCT geometry on macOS — AIS/V3d rendering offscreen into an IOSurface-backed GL framebuffer, composited by Flutter as an external texture — with orbit/pan/zoom/fit navigation, click pick/selection, and damage-driven redraw.

**Architecture:** Plan 3 of 5 for `docs/superpowers/specs/2026-07-12-jet-cad-architecture-design.md`. The C++ `Session` gains an optional `Viewer` (created only for texture sessions): `V3d_Viewer` + `AIS_InteractiveContext` + one `V3d_View` rendering into an FBO whose color attachment is an IOSurface-backed texture, via a CGL context owned by an isolated platform module (`src/native/platform/`) so ANGLE swap-in stays cheap. The Flutter macOS plugin wraps the IOSurface in a `CVPixelBuffer` and registers a `FlutterTexture`; Dart triggers recomposite with `textureFrameAvailable` after each damage render. All viewer commands flow through the existing 5-symbol C ABI as JSON (`jc_execute`) — no new C symbols. The Dart `KernelBridge` grows typed viewer/pick/selection methods (additive; interface explicitly not frozen), implemented by `FakeKernelBridge`, `FfiKernelBridge`, and covered by the shared contract suite. `FfiKernelBridge` moves from per-command `Isolate.run`+dlopen to one long-lived worker isolate per bridge (render-rate prerequisite + GL thread affinity). `SelectionChanged` is a `ViewportController` stream event, never a `DocChange`.

**Tech Stack:** OCCT 7.9.3 via Homebrew (new toolkits: TKOpenGl, TKV3d, TKService), CGL + IOSurface + CoreVideo (macOS frameworks), Swift `FlutterMacOS` plugin, Dart `Isolate.spawn` worker, existing CMake/gtest/nlohmann-json/flutter_test stack from Plans 1–2.

> **Plan authority:** authoritative for sequencing and interface contracts, not exact code. OCCT viewer APIs (`Aspect_NeutralWindow`, `OpenGl_FrameBuffer::InitWrapper`, `V3d_View::SetWindow(window, context)`, selection iteration) and FlutterMacOS Swift APIs vary in exact signatures across versions — the implementer adjusts to satisfy the compiler and records the adjustment in their report. Task 1 (spike) exists precisely to pin the risky facts (pixel format, Y-orientation, flush semantics); later tasks consume its recorded findings from the ledger.

## Global Constraints

- **Definition of Done — Dart-touching tasks:** `flutter analyze` clean; full `flutter test` green in BOTH states (native lib present and absent — guarded tests must skip via `markTestSkipped`); `dart format lib test` produces no diff; no TODO comments; real transcripts only (synthesized test output is a firing offense).
- **Definition of Done — native tasks:** `packages/jet_cad/tool/build_native.sh` exits 0 with all ctest green (real transcript), no new warnings from our files at default warning level, and the full Dart suite still green in both states.
- Hard rule unchanged: nothing above `KernelBridge` imports `dart:ffi`. All platform GL code lives in `src/native/platform/`; the rest of the C++ shim stays platform-neutral.
- Selection is transient view state: `SelectionChanged` is emitted by `ViewportController`'s own stream; it never enters `DocChange`, the operation list, or undo.
- **Damage-driven redraw only:** render on command completion (via `doc.changes`), camera change, selection change, or resize — never per-vsync, no `Ticker`.
- Resize + `devicePixelRatio` changes reallocate the IOSurface, debounced (100 ms).
- macOS only in this plan; Windows/Linux/mobile/web texture paths are out of scope. Existing linux/windows toy scaffolding is left untouched.
- Package stays headless-first: `jet_cad` exports viewport widget + controller only, no toolbars/panels. `apps/dev_harness` is a git-tracked throwaway dev app, never part of the package's public surface.
- Every new `KernelBridge` method is implemented in `FakeKernelBridge` AND covered in `test/kernel/bridge_contract.dart` (runs against both fake and FFI).
- Kernel ids stay session-scoped monotonic strings (`b1`, `f2`, `e3`, `v4`) — pick/selection reuse them; kind is derivable from the prefix.
- Viewer JSON commands on a session without an initialized viewer fail with the error envelope (surfacing as `KernelException`), for the fake too.
- Commit style: conventional commits, one commit per plan step that says commit, each ending with the trailer `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- Execution ledger: append per-task status to `.superpowers/sdd/progress.md` under a `== Plan 3 ==` heading, including spike findings (orientation, pixel format, flush).

---

### Task 1: Spike — CGL → IOSurface → CVPixelBuffer → FlutterTexture vertical slice

The riskiest plumbing, isolated from OCCT entirely: prove that pixels drawn by raw GL into an IOSurface-backed FBO inside the native shim appear inside a Flutter widget on screen. Pin three facts for later tasks: (1) pixel format that works end-to-end (expected: BGRA IOSurface + `GL_BGRA`/`GL_UNSIGNED_INT_8_8_8_8_REV` texture image), (2) vertical orientation (expected: GL bottom-up rows → widget needs a Y-flip), (3) flush call needed for cross-API coherency (expected: `glFlush()` after render).

**Files:**
- Create: `packages/jet_cad/src/native/platform/gl_context.hpp`
- Create: `packages/jet_cad/src/native/platform/gl_context_macos.mm`
- Modify: `packages/jet_cad/src/native/CMakeLists.txt`
- Modify: `packages/jet_cad/src/native/session.hpp`
- Modify: `packages/jet_cad/src/native/session.cpp`
- Create: `packages/jet_cad/src/native/tests/support.hpp` (shared test helpers)
- Create: `packages/jet_cad/src/native/tests/texture_spike_test.cpp`
- Create: `packages/jet_cad/macos/Classes/JetCadPlugin.swift`
- Modify: `packages/jet_cad/pubspec.yaml` (macos: `pluginClass: JetCadPlugin`)
- Modify: `packages/jet_cad/lib/src/kernel/ffi/ffi_kernel_bridge.dart` (`debugExecute` hook)
- Modify: `packages/jet_cad/lib/src/kernel/ffi_kernel_bridge_unsupported.dart` (`debugExecute` stub)
- Create: `apps/dev_harness/` (via `flutter create`, then edited)
- Modify: `pubspec.yaml` (repo root — workspace member)
- Create: `packages/jet_cad/tool/run_harness.sh`
- Test: `packages/jet_cad/test/kernel_ffi/debug_execute_test.dart` (new)

**Interfaces:**
- Consumes: existing 5-symbol C ABI, `Session::execute` dispatch, `FfiKernelBridge`.
- Produces (later tasks rely on these):
  - C++ `jetcad::GlContext` (platform interface, `platform/gl_context.hpp`):
    - `static std::unique_ptr<GlContext> create();` — throws `std::runtime_error` on unsupported platform/context failure.
    - `void makeCurrent();`
    - `uint32_t createSurfaceFramebuffer(int widthPx, int heightPx);` — (re)allocates the IOSurface + FBO + depth attachment, returns the global `IOSurfaceID`; destroys any previous surface/FBO.
    - `void bindSurfaceFramebuffer();` — `glBindFramebuffer` on the surface FBO.
    - `unsigned framebufferId() const;` / `uint32_t surfaceId() const;`
    - `void* nativeContext();` — the `CGLContextObj`, opaque to callers.
    - `void flush();` — coherency flush after rendering (spike pins glFlush vs glFinish).
    - `std::vector<uint8_t> readPixels(int x, int y, int w, int h);` — RGBA, rows bottom-up as `glReadPixels` returns them.
  - Spike-only JSON commands (Task 3 REMOVES `debugInitTexture`/`debugRenderTestPattern` and re-homes `debugReadPixels` onto the real viewer):
    - `{"cmd":"debugInitTexture","width":W,"height":H}` → `{"surfaceId":N}`
    - `{"cmd":"debugRenderTestPattern"}` → `{}` — quadrants: bottom-left blue, bottom-right white, top-left red, top-right green in GL coordinates (asymmetric on both axes → orientation is provable).
    - `{"cmd":"debugReadPixels","x":X,"y":Y,"width":W,"height":H}` → `{"width":W,"height":H,"rgbaBase64":"..."}` (rows bottom-up).
  - Dart `FfiKernelBridge.debugExecute(SessionHandle session, Map<String, Object?> command) → Future<Map<String, Object?>>` — raw command hook for dev harness + FFI tests; doc-commented dev/test-only; throws like every other command (queued per session). Stub variant throws `UnsupportedError`.
  - MethodChannel `jet_cad/texture` (Swift side; Dart wrapper arrives in Task 7):
    - `registerTexture {surfaceId: int} → int textureId`
    - `updateSurface {textureId: int, surfaceId: int} → null` (re-wraps after IOSurface reallocation)
    - `frameReady {textureId: int} → null` (calls `textureFrameAvailable`)
    - `unregisterTexture {textureId: int} → null` (idempotent)
  - `apps/dev_harness` app + `tool/run_harness.sh` (builds native lib, exports `JET_CAD_NATIVE_LIB`, runs the app on macOS).

- [ ] **Step 1: Declare the platform GL interface**

`packages/jet_cad/src/native/platform/gl_context.hpp`:

```cpp
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
};

}  // namespace jetcad
```

- [ ] **Step 2: Implement the macOS CGL + IOSurface context**

`packages/jet_cad/src/native/platform/gl_context_macos.mm`:

```objc
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
```

Note the non-Apple branch still compiles (throws at runtime) so the file can be added unconditionally on Apple and skipped elsewhere — CMake only compiles it on APPLE anyway; the `#ifdef` is belt-and-braces.

- [ ] **Step 3: Wire the platform module into CMake**

`packages/jet_cad/src/native/CMakeLists.txt` — add after the existing `add_library(jet_cad_native SHARED api.cpp session.cpp)` block (adjust to the file's actual layout; keep existing OCCT toolkit list untouched in this task):

```cmake
if(APPLE)
  enable_language(OBJCXX)
  target_sources(jet_cad_native PRIVATE platform/gl_context_macos.mm)
  target_link_libraries(jet_cad_native PRIVATE
    "-framework CoreFoundation"
    "-framework IOSurface"
    "-framework OpenGL")
endif()
```

- [ ] **Step 4: Write the shared test helpers + failing gtest for the spike commands**

`packages/jet_cad/src/native/tests/support.hpp` (shared by all viewer-era test files; Tasks 3–5 extend it):

```cpp
#pragma once

#include <gtest/gtest.h>

#include <nlohmann/json.hpp>

#include <array>
#include <cstdint>
#include <string>
#include <vector>

#include "../include/jet_cad_native.h"
#include "../b64.hpp"

namespace jetcad::test {

using json = nlohmann::json;

inline json exec(uint64_t session, const json& cmd) {
  const char* raw = jc_execute(session, cmd.dump().c_str());
  json envelope = json::parse(raw);
  jc_free(raw);
  return envelope;
}

inline json execOk(uint64_t session, const json& cmd) {
  json envelope = exec(session, cmd);
  EXPECT_TRUE(envelope.at("ok").get<bool>()) << envelope.dump();
  return envelope.at("result");
}

// Returns the RGBA quad at pixel (x, y) with rows bottom-up (GL order).
inline std::array<uint8_t, 4> pixelAt(const std::vector<uint8_t>& rgba,
                                      int width, int x, int y) {
  const size_t offset = (static_cast<size_t>(y) * width + x) * 4;
  return {rgba[offset], rgba[offset + 1], rgba[offset + 2], rgba[offset + 3]};
}

}  // namespace jetcad::test
```

`packages/jet_cad/src/native/tests/texture_spike_test.cpp`:

```cpp
#include "support.hpp"

namespace {

using jetcad::test::exec;
using jetcad::test::execOk;
using jetcad::test::pixelAt;
using json = nlohmann::json;

TEST(TextureSpikeTest, InitTextureReturnsSurfaceId) {
  uint64_t s = jc_create_session();
  json result =
      execOk(s, {{"cmd", "debugInitTexture"}, {"width", 64}, {"height", 64}});
  EXPECT_GT(result.at("surfaceId").get<uint32_t>(), 0u);
  jc_dispose_session(s);
}

TEST(TextureSpikeTest, TestPatternQuadrantsLandWhereExpected) {
  uint64_t s = jc_create_session();
  execOk(s, {{"cmd", "debugInitTexture"}, {"width", 64}, {"height", 64}});
  execOk(s, {{"cmd", "debugRenderTestPattern"}});
  json result = execOk(s, {{"cmd", "debugReadPixels"},
                           {"x", 0},
                           {"y", 0},
                           {"width", 64},
                           {"height", 64}});
  std::vector<uint8_t> rgba =
      jetcad::b64decode(result.at("rgbaBase64").get<std::string>());
  ASSERT_EQ(rgba.size(), 64u * 64u * 4u);
  // GL rows are bottom-up: y=16 is the BOTTOM half, y=48 the TOP half.
  auto bottomLeft = pixelAt(rgba, 64, 16, 16);
  auto bottomRight = pixelAt(rgba, 64, 48, 16);
  auto topLeft = pixelAt(rgba, 64, 16, 48);
  auto topRight = pixelAt(rgba, 64, 48, 48);
  EXPECT_EQ(bottomLeft[2], 255) << "bottom-left should be blue";
  EXPECT_EQ(bottomLeft[0], 0);
  EXPECT_EQ(bottomRight[0], 255) << "bottom-right should be white";
  EXPECT_EQ(bottomRight[1], 255);
  EXPECT_EQ(bottomRight[2], 255);
  EXPECT_EQ(topLeft[0], 255) << "top-left should be red";
  EXPECT_EQ(topLeft[1], 0);
  EXPECT_EQ(topRight[1], 255) << "top-right should be green";
  EXPECT_EQ(topRight[0], 0);
  jc_dispose_session(s);
}

TEST(TextureSpikeTest, DebugCommandsWithoutInitFail) {
  uint64_t s = jc_create_session();
  json envelope = exec(s, {{"cmd", "debugRenderTestPattern"}});
  EXPECT_FALSE(envelope.at("ok").get<bool>());
  jc_dispose_session(s);
}

}  // namespace
```

Register it in `packages/jet_cad/src/native/CMakeLists.txt` by adding `tests/texture_spike_test.cpp` to the existing `add_executable(jet_cad_native_tests ...)` source list. If the test target compiles the library sources directly rather than linking the shared lib, also add `platform/gl_context_macos.mm` there under the same `if(APPLE)` guard.

- [ ] **Step 5: Run the gtest to verify it fails**

```bash
cd packages/jet_cad && tool/build_native.sh
```

Expected: build FAILS (unknown commands `debugInitTexture` etc. are dispatched to `CommandError`, so the two positive tests fail; if the build itself fails first on the new test file, that also counts as the red state).

- [ ] **Step 6: Implement the spike commands in Session**

`packages/jet_cad/src/native/session.hpp` — add to the private section of `Session` (plus the include):

```cpp
#include "platform/gl_context.hpp"
```

```cpp
  json cmdDebugInitTexture(const json& cmd);
  json cmdDebugRenderTestPattern();
  json cmdDebugReadPixels(const json& cmd);

  // Spike-only GL context; replaced by the Viewer in Plan 3 Task 3.
  std::unique_ptr<GlContext> spikeGl_;
```

`packages/jet_cad/src/native/session.cpp` — add the dispatch branches inside `Session::execute` (before the unknown-command throw):

```cpp
  if (name == "debugInitTexture") return cmdDebugInitTexture(cmd);
  if (name == "debugRenderTestPattern") return cmdDebugRenderTestPattern();
  if (name == "debugReadPixels") return cmdDebugReadPixels(cmd);
```

and the handlers (GL calls go through the platform module only — no GL includes in session.cpp; the test pattern uses scissored clears, which need no shaders):

```cpp
json Session::cmdDebugInitTexture(const json& cmd) {
  if (spikeGl_) throw CommandError("texture already initialized");
  const int width = cmd.at("width").get<int>();
  const int height = cmd.at("height").get<int>();
  try {
    spikeGl_ = GlContext::create();
    const uint32_t surfaceId = spikeGl_->createSurfaceFramebuffer(width, height);
    return json{{"surfaceId", surfaceId}};
  } catch (const std::runtime_error& e) {
    spikeGl_.reset();
    throw CommandError(e.what());
  }
}

json Session::cmdDebugRenderTestPattern() {
  if (!spikeGl_) throw CommandError("texture not initialized");
  spikeGl_->renderTestPattern();
  return json::object();
}

json Session::cmdDebugReadPixels(const json& cmd) {
  if (!spikeGl_) throw CommandError("texture not initialized");
  const int x = cmd.at("x").get<int>();
  const int y = cmd.at("y").get<int>();
  const int w = cmd.at("width").get<int>();
  const int h = cmd.at("height").get<int>();
  if (w <= 0 || h <= 0 || x < 0 || y < 0 || x + w > spikeGl_->width() ||
      y + h > spikeGl_->height()) {
    throw CommandError("readPixels rectangle out of bounds");
  }
  std::vector<uint8_t> rgba = spikeGl_->readPixels(x, y, w, h);
  return json{{"width", w}, {"height", h}, {"rgbaBase64", b64encode(rgba)}};
}
```

Add `renderTestPattern()` to the `GlContext` interface (pure virtual, doc: "spike helper, removed with the spike") and implement it in `gl_context_macos.mm`:

```cpp
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
```

Adjust the base64 helper call to whatever `b64.hpp` actually exposes (`b64encode` over `std::vector<uint8_t>` or a string overload — check the header and adapt; add a byte-vector overload there if only strings are supported, with a matching unit assertion in the spike test).

- [ ] **Step 7: Run the gtest to verify it passes**

```bash
cd packages/jet_cad && tool/build_native.sh
```

Expected: exit 0, all previous 18 tests + 3 new `TextureSpikeTest.*` green (count from real ctest output).

- [ ] **Step 8: Add `debugExecute` to the FFI bridge (test-first)**

`packages/jet_cad/test/kernel_ffi/debug_execute_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad/jet_cad.dart';

void main() {
  final libPath = FfiKernelBridge.locateLibrary();
  if (libPath == null) {
    test('SKIPPED: native library not built (tool/build_native.sh)', () {
      markTestSkipped('native library not built');
    });
    return;
  }

  test('debugExecute round-trips a raw command', () async {
    final bridge = FfiKernelBridge(libPath);
    final session = await bridge.createSession(const HeadlessTarget());
    final result = await bridge.debugExecute(
      session,
      {'cmd': 'debugInitTexture', 'width': 32, 'height': 32},
    );
    expect(result['surfaceId'], isA<int>());
    expect(result['surfaceId'], greaterThan(0));
    await bridge.disposeSession(session);
  });

  test('debugExecute surfaces command errors as KernelException', () async {
    final bridge = FfiKernelBridge(libPath);
    final session = await bridge.createSession(const HeadlessTarget());
    await expectLater(
      bridge.debugExecute(session, {'cmd': 'noSuchCommand'}),
      throwsA(isA<KernelException>()),
    );
    await bridge.disposeSession(session);
  });
}
```

Run: `cd packages/jet_cad && flutter test test/kernel_ffi/debug_execute_test.dart`
Expected: FAIL — `debugExecute` is not defined.

`packages/jet_cad/lib/src/kernel/ffi/ffi_kernel_bridge.dart` — add a public method that reuses the existing per-session queued `_run` path (match the actual `_run` signature in the file; it already decodes the envelope and throws `KernelException` on `ok != true`):

```dart
  /// Runs a raw JSON command against [session].
  ///
  /// Dev-harness and test hook only: production callers use the typed
  /// [KernelBridge] methods. Queued per session like every other command.
  Future<Map<String, Object?>> debugExecute(
      SessionHandle session, Map<String, Object?> command) async {
    final result = await _run(session, command);
    return (result as Map?)?.cast<String, Object?>() ?? const {};
  }
```

`packages/jet_cad/lib/src/kernel/ffi_kernel_bridge_unsupported.dart` — mirror the public surface:

```dart
  Future<Map<String, Object?>> debugExecute(
          SessionHandle session, Map<String, Object?> command) =>
      _unsupported();
```

Run: `cd packages/jet_cad && flutter test test/kernel_ffi/debug_execute_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 9: Write the minimal Swift texture plugin**

`packages/jet_cad/macos/Classes/JetCadPlugin.swift`:

```swift
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
```

API-adjust notes for the implementer: on FlutterMacOS, `registrar.messenger` and `registrar.textures` are properties (not methods); if the compiler disagrees, follow its fixit. `IOSurfaceLookup` returns `IOSurfaceRef` (CoreFoundation type, memory-managed by Swift). Method-channel ints arrive as `Int`/`NSNumber` — the `NSNumber` casts above are deliberate for 64-bit texture ids.

- [ ] **Step 10: Register the plugin class in pubspec**

`packages/jet_cad/pubspec.yaml` — change the macos plugin entry (leave linux/windows as `ffiPlugin: true`):

```yaml
      macos:
        pluginClass: JetCadPlugin
```

The podspec already globs `Classes/**/*` so the Swift file is picked up; `s.dependency 'FlutterMacOS'` and `s.swift_version` are already present. Leave `Classes/jet_cad.c` (toy scaffold) in place for now — Task 7 deletes it.

- [ ] **Step 11: Verify the package still analyzes and tests green**

```bash
cd packages/jet_cad && flutter analyze && flutter test && dart format lib test
```

Expected: analyze clean; full suite green (81 + 2 new debugExecute tests with lib present); format no diff. Also run once with the guard exercised:

```bash
cd packages/jet_cad && mv build/native build/native.bak && flutter test && mv build/native.bak build/native
```

Expected: FFI files report skips (now including debug_execute_test), everything else green.

- [ ] **Step 12: Commit the native + plugin spike core**

```bash
git add packages/jet_cad/src/native packages/jet_cad/macos packages/jet_cad/pubspec.yaml packages/jet_cad/lib packages/jet_cad/test
git commit -m "feat: CGL/IOSurface offscreen framebuffer spike + texture plugin

New platform module src/native/platform (GlContext interface + CGL/
IOSurface impl) isolated per spec so ANGLE swap-in stays contained.
Spike-only debug commands (debugInitTexture/debugRenderTestPattern/
debugReadPixels) prove the path with an orientation-asymmetric test
pattern; gtest asserts quadrant colors through the C ABI. Minimal
JetCadPlugin registers IOSurface-backed CVPixelBuffers as Flutter
external textures over the jet_cad/texture channel. FfiKernelBridge
gains a queued debugExecute dev/test hook.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

- [ ] **Step 13: Scaffold the dev harness app**

```bash
cd /Users/ahmeturel/Projects/oss/jet-cad
flutter create --template=app --platforms=macos --org dev.jetcad --project-name jet_cad_dev_harness apps/dev_harness
rm apps/dev_harness/test/widget_test.dart
```

Root `pubspec.yaml` — add the workspace member:

```yaml
workspace:
  - packages/jet_cad
  - apps/dev_harness
```

`apps/dev_harness/pubspec.yaml` — replace the generated dependencies section:

```yaml
name: jet_cad_dev_harness
description: Throwaway dev harness for manual jet_cad viewport verification.
publish_to: none
version: 0.0.1
resolution: workspace

environment:
  sdk: ^3.5.0
  flutter: ">=3.24.0"

dependencies:
  flutter:
    sdk: flutter
  jet_cad:
    path: ../../packages/jet_cad

flutter:
  uses-material-design: true
```

Disable the app sandbox so the harness may dlopen the dev-built dylib outside its container — `apps/dev_harness/macos/Runner/DebugProfile.entitlements`, set:

```xml
	<key>com.apple.security.app-sandbox</key>
	<false/>
```

(Leave `Release.entitlements` alone; the harness only ever runs in debug.)

- [ ] **Step 14: Write the spike harness UI**

`apps/dev_harness/lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jet_cad/jet_cad.dart';

/// Spike harness: proves shim-rendered IOSurface pixels composite in Flutter.
///
/// Expected on screen (after the flipY wrapper): red top-left, green
/// top-right, blue bottom-left, white bottom-right. If the quadrants land
/// elsewhere, the orientation finding in the plan/ledger must be corrected.
void main() {
  runApp(const MaterialApp(home: SpikePage()));
}

class SpikePage extends StatefulWidget {
  const SpikePage({super.key});

  @override
  State<SpikePage> createState() => _SpikePageState();
}

class _SpikePageState extends State<SpikePage> {
  static const _channel = MethodChannel('jet_cad/texture');

  FfiKernelBridge? _bridge;
  SessionHandle? _session;
  int? _textureId;
  String _status = 'starting…';

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final libPath = FfiKernelBridge.locateLibrary();
      if (libPath == null) {
        setState(() => _status =
            'native lib not found — run tool/run_harness.sh from repo root');
        return;
      }
      final bridge = FfiKernelBridge(libPath);
      final session = await bridge.createSession(const HeadlessTarget());
      final init = await bridge.debugExecute(
          session, {'cmd': 'debugInitTexture', 'width': 512, 'height': 512});
      final surfaceId = init['surfaceId'] as int;
      final textureId = await _channel
          .invokeMethod<int>('registerTexture', {'surfaceId': surfaceId});
      await bridge.debugExecute(session, {'cmd': 'debugRenderTestPattern'});
      await _channel.invokeMethod<void>('frameReady', {'textureId': textureId});
      setState(() {
        _bridge = bridge;
        _session = session;
        _textureId = textureId;
        _status = 'texture $textureId on IOSurface $surfaceId';
      });
    } catch (e) {
      setState(() => _status = 'FAILED: $e');
    }
  }

  @override
  void dispose() {
    final session = _session;
    if (session != null) {
      _bridge?.disposeSession(session);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('jet_cad spike — $_status')),
      body: Center(
        child: _textureId == null
            ? const CircularProgressIndicator()
            : SizedBox(
                width: 512,
                height: 512,
                // GL rows are bottom-up; flip so GL "top" renders at the top.
                child: Transform.flip(
                  flipY: true,
                  child: Texture(textureId: _textureId!),
                ),
              ),
      ),
    );
  }
}
```

- [ ] **Step 15: Add the harness runner script**

`packages/jet_cad/tool/run_harness.sh`:

```bash
#!/usr/bin/env bash
# Builds the native shim, then runs the dev harness with the dylib path
# exported. Run from anywhere; paths are resolved from this script.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pkg_dir="$(dirname "$script_dir")"
repo_dir="$(cd "$pkg_dir/../.." && pwd)"

"$script_dir/build_native.sh"

export JET_CAD_NATIVE_LIB="$pkg_dir/build/native/libjet_cad_native.dylib"
cd "$repo_dir/apps/dev_harness"
flutter run -d macos "$@"
```

```bash
chmod +x packages/jet_cad/tool/run_harness.sh
```

- [ ] **Step 16: Manual spike verification — pixels on screen**

```bash
packages/jet_cad/tool/run_harness.sh
```

While the app runs, capture and inspect a screenshot (the executor inspects the PNG; a human confirms at review):

```bash
sleep 8 && screencapture -x /tmp/jet_cad_spike.png
```

Verify: the 512×512 square shows red top-left, green top-right, blue bottom-left, white bottom-right — sharp quadrant edges, no smearing, no channel swap (red must be red, not blue: BGRA/RGBA mixups show up exactly here). Record in the ledger: (a) confirmed pixel format config, (b) confirmed orientation + the `flipY: true` requirement, (c) whether `glFlush` sufficed or `glFinish` was needed (tearing/partial pattern ⇒ upgrade to `glFinish` and retest), (d) any API signature adjustments made.

- [ ] **Step 17: Full verification + commit the harness**

```bash
cd packages/jet_cad && flutter analyze && flutter test && dart format lib test
cd ../../apps/dev_harness && flutter analyze
```

Expected: all clean/green.

```bash
git add apps/dev_harness pubspec.yaml packages/jet_cad/tool/run_harness.sh
git commit -m "feat: dev harness app proving IOSurface texture composition

Throwaway macOS-only harness (workspace member, never part of the
package surface): registers the spike test-pattern surface as a Flutter
texture and displays it flipY-wrapped. App sandbox disabled in debug so
the dev-built dylib loads. tool/run_harness.sh builds the shim and runs
the app with JET_CAD_NATIVE_LIB exported.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Dart carry-overs — long-lived worker isolate, dispose-join, fillet contract tightening

Plan 2's review carry-overs, folded in before any render-rate traffic exists. Per-command `Isolate.run` + `DynamicLibrary.open` is too slow for camera-move command rates and gives no thread-affinity guarantee for the GL context; one long-lived worker isolate per bridge fixes both (the CGL context is created and used on the worker's single thread; native code still defensively re-makes-current per command).

**Files:**
- Create: `packages/jet_cad/lib/src/kernel/ffi/ffi_worker.dart`
- Modify: `packages/jet_cad/lib/src/kernel/ffi/ffi_kernel_bridge.dart`
- Modify: `packages/jet_cad/lib/src/kernel/ffi_kernel_bridge_unsupported.dart` (`shutdown` stub)
- Modify: `packages/jet_cad/test/kernel/bridge_contract.dart`
- Test: `packages/jet_cad/test/kernel_ffi/ffi_worker_test.dart` (new)

**Interfaces:**
- Consumes: `NativeBindings` (`lib/src/kernel/ffi/native_bindings.dart`) — blocking `createSession()`, `disposeSession(int)`, `execute(int, String) → String`, `version() → String` (adjust op wiring to the actual method names in that file).
- Produces:
  - `FfiWorker` (internal to `lib/src/kernel/ffi/`):
    - `static Future<FfiWorker> spawn(String libraryPath)` — spawns the isolate, dlopens once inside it.
    - `Future<Object?> request(String op, int session, String? payload)` — ops: `'createSession'` (returns int), `'disposeSession'`, `'execute'` (payload = command JSON, returns envelope String), `'version'` (returns String). Errors marshal back and rethrow as `KernelException` (when the worker caught one) or `StateError` otherwise.
    - `Future<void> shutdown()` — stops the worker; subsequent `request` throws `StateError`. Idempotent.
  - `FfiKernelBridge` changes:
    - All commands route through one lazily-spawned `FfiWorker`; per-session one-command-in-flight queueing (`_queues`) unchanged.
    - `disposeSession` joins: a second call while a dispose is in flight returns the SAME future (both callers observe completion); after completion it stays a no-op. (Carry-over fix.)
    - `Future<void> shutdown()` — public, FFI-specific (not on `KernelBridge`): awaits per-session queues, shuts the worker down. Commands after shutdown throw `StateError`. Mirrored throwing stub in the unsupported variant.
  - Contract additions (both fake + FFI): fillet mints non-empty `edges` and `vertices`; concurrent double-`disposeSession` completes without error.

- [ ] **Step 1: Write the failing contract + worker tests**

Append to `packages/jet_cad/test/kernel/bridge_contract.dart` inside `runKernelBridgeContract` (match the suite's existing helper style for creating a box and grabbing edge ids):

```dart
  test('contract: fillet mints non-empty edges and vertices', () async {
    final box = await bridge.makeBox(session, const Vec3(10, 10, 10));
    final result =
        await bridge.fillet(session, [box.edges.first], 1.0);
    expect(result.edges, isNotEmpty,
        reason: 'fillet creates new arc edges on the rounded surface');
    expect(result.vertices, isNotEmpty,
        reason: 'fillet creates new vertices on the rounded surface');
  });

  test('contract: concurrent disposeSession calls both complete', () async {
    final s = await bridge.createSession(const HeadlessTarget());
    final first = bridge.disposeSession(s);
    final second = bridge.disposeSession(s);
    await Future.wait([first, second]);
    await expectLater(
      bridge.makeBox(s, const Vec3(1, 1, 1)),
      throwsA(anyOf(isA<KernelException>(), isA<StateError>())),
    );
  });
```

If `FakeKernelBridge.disposeSession` currently throws on an already-disposed session, make it idempotent (matching the FFI bridge) — the contract case above must pass against BOTH implementations.

`packages/jet_cad/test/kernel_ffi/ffi_worker_test.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad/jet_cad.dart';

void main() {
  final libPath = FfiKernelBridge.locateLibrary();
  if (libPath == null) {
    test('SKIPPED: native library not built (tool/build_native.sh)', () {
      markTestSkipped('native library not built');
    });
    return;
  }

  test('bridge survives a burst of sequential commands', () async {
    final bridge = FfiKernelBridge(libPath);
    final session = await bridge.createSession(const HeadlessTarget());
    final stopwatch = Stopwatch()..start();
    for (var i = 0; i < 50; i++) {
      await bridge.makeBox(session, const Vec3(1, 1, 1));
    }
    stopwatch.stop();
    // Not a perf assertion — just a visibility line in the transcript to
    // compare against the old Isolate.run path.
    debugPrint('50 makeBox commands: ${stopwatch.elapsedMilliseconds} ms');
    await bridge.disposeSession(session);
    await bridge.shutdown();
  });

  test('commands after shutdown throw StateError', () async {
    final bridge = FfiKernelBridge(libPath);
    final session = await bridge.createSession(const HeadlessTarget());
    await bridge.disposeSession(session);
    await bridge.shutdown();
    await expectLater(
      bridge.createSession(const HeadlessTarget()),
      throwsA(isA<StateError>()),
    );
  });

  test('shutdown is idempotent', () async {
    final bridge = FfiKernelBridge(libPath);
    final session = await bridge.createSession(const HeadlessTarget());
    await bridge.disposeSession(session);
    await bridge.shutdown();
    await bridge.shutdown();
  });

  test('parallel sessions on one worker stay isolated', () async {
    final bridge = FfiKernelBridge(libPath);
    final a = await bridge.createSession(const HeadlessTarget());
    final b = await bridge.createSession(const HeadlessTarget());
    final boxA = await bridge.makeBox(a, const Vec3(1, 1, 1));
    await expectLater(
      bridge.exportStep(b, [boxA.body]),
      throwsA(isA<KernelException>()),
      reason: 'body ids are session-scoped',
    );
    await bridge.disposeSession(a);
    await bridge.disposeSession(b);
    await bridge.shutdown();
  });
}
```

Run: `cd packages/jet_cad && flutter test test/kernel_ffi/ffi_worker_test.dart test/kernel/fake_bridge_contract_test.dart`
Expected: FAIL — `shutdown` undefined; contract fillet case may already pass (both impls were fixed in Plan 2's final review — if it passes immediately, note that in the report; the case still pins the contract).

- [ ] **Step 2: Implement the worker isolate**

`packages/jet_cad/lib/src/kernel/ffi/ffi_worker.dart`:

```dart
import 'dart:async';
import 'dart:isolate';

import '../kernel_types.dart';
import 'native_bindings.dart';

/// Request: (id, op, session, payload). Reply: (id, ok, value, errorType,
/// errorMessage). All fields are sendable primitives.
typedef _Request = (int, String, int, String?);
typedef _Reply = (int, bool, Object?, String?, String?);

/// One long-lived worker isolate owning a single dlopen'd [NativeBindings].
///
/// Every native call for a bridge runs on this isolate's thread, giving the
/// GL context a stable home thread (native code still re-makes-current per
/// command defensively). Replaces the per-command Isolate.run + dlopen from
/// Plan 2, which was too slow for render-rate command traffic.
class FfiWorker {
  FfiWorker._(this._isolate, this._commands, this._replies);

  final Isolate _isolate;
  final SendPort _commands;
  final ReceivePort _replies;
  final Map<int, Completer<Object?>> _pending = {};
  int _nextId = 0;
  bool _shutdown = false;

  static Future<FfiWorker> spawn(String libraryPath) async {
    final ready = ReceivePort();
    final replies = ReceivePort();
    final isolate = await Isolate.spawn(
      _workerMain,
      (ready.sendPort, replies.sendPort, libraryPath),
      debugName: 'jet_cad_ffi_worker',
    );
    final commands = await ready.first as SendPort;
    ready.close();
    final worker = FfiWorker._(isolate, commands, replies);
    replies.listen(worker._onReply);
    return worker;
  }

  Future<Object?> request(String op, int session, String? payload) {
    if (_shutdown) {
      throw StateError('FfiKernelBridge is shut down');
    }
    final id = _nextId++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    _commands.send((id, op, session, payload));
    return completer.future;
  }

  Future<void> shutdown() async {
    if (_shutdown) return;
    _shutdown = true;
    await Future.wait(_pending.values.map((c) => c.future.catchError((_) {})));
    _commands.send(null);
    _replies.close();
    _isolate.kill(priority: Isolate.beforeNextEvent);
  }

  void _onReply(Object? message) {
    final (id, ok, value, errorType, errorMessage) = message as _Reply;
    final completer = _pending.remove(id);
    if (completer == null) return;
    if (ok) {
      completer.complete(value);
    } else if (errorType == 'KernelException') {
      completer.completeError(KernelException(errorMessage ?? 'kernel error'));
    } else {
      completer.completeError(
          StateError('native worker failure ($errorType): $errorMessage'));
    }
  }

  static void _workerMain((SendPort, SendPort, String) args) {
    final (readyPort, replyPort, libraryPath) = args;
    final bindings = NativeBindings(libraryPath);
    final commands = ReceivePort();
    readyPort.send(commands.sendPort);
    commands.listen((Object? message) {
      if (message == null) {
        commands.close();
        return;
      }
      final (id, op, session, payload) = message as _Request;
      try {
        final Object? value = switch (op) {
          'createSession' => bindings.createSession(),
          'disposeSession' => _void(() => bindings.disposeSession(session)),
          'execute' => bindings.execute(session, payload!),
          'version' => bindings.version(),
          _ => throw StateError('unknown worker op: $op'),
        };
        replyPort.send((id, true, value, null, null));
      } on KernelException catch (e) {
        replyPort.send((id, false, null, 'KernelException', e.message));
      } catch (e) {
        replyPort.send((id, false, null, e.runtimeType.toString(), '$e'));
      }
    });
  }

  static Object? _void(void Function() fn) {
    fn();
    return null;
  }
}
```

Adjust the four `bindings.*` calls to the real method names/signatures in `native_bindings.dart` (they are the same lookups the old `Isolate.run` closures used).

- [ ] **Step 3: Rewire FfiKernelBridge onto the worker**

`packages/jet_cad/lib/src/kernel/ffi/ffi_kernel_bridge.dart` — replace the `Isolate.run` transport while keeping the public surface, per-session `_queues` chaining, `_disposing` guard, and all typed command builders exactly as they are. The changed core:

```dart
  Future<FfiWorker>? _workerFuture;
  final Map<int, Future<void>> _disposals = {};
  bool _shutdownRequested = false;

  Future<FfiWorker> _worker() {
    if (_shutdownRequested) {
      throw StateError('FfiKernelBridge is shut down');
    }
    return _workerFuture ??= FfiWorker.spawn(libraryPath);
  }

  @override
  Future<SessionHandle> createSession(RenderTarget target) async {
    final worker = await _worker();
    final handle = await worker.request('createSession', 0, null) as int;
    return SessionHandle(handle);
  }

  @override
  Future<void> disposeSession(SessionHandle session) {
    // Joining semantics (Plan 2 carry-over): a dispose in flight is THE
    // dispose — every caller awaits the same future; afterwards it is a
    // completed no-op.
    final existing = _disposals[session.value];
    if (existing != null) return existing;
    if (_disposing.contains(session.value)) return Future.value();
    final future = _disposeImpl(session);
    _disposals[session.value] = future;
    return future;
  }

  Future<void> _disposeImpl(SessionHandle session) async {
    _disposing.add(session.value);
    await (_queues[session.value] ?? Future.value()).catchError((_) {});
    final worker = await _worker();
    await worker.request('disposeSession', session.value, null);
    _queues.remove(session.value);
  }

  /// Shuts down the worker isolate. FFI-specific lifecycle (not part of
  /// [KernelBridge]): dispose sessions first; any command after shutdown
  /// throws [StateError]. Idempotent.
  Future<void> shutdown() async {
    if (_shutdownRequested) return;
    _shutdownRequested = true;
    final workerFuture = _workerFuture;
    if (workerFuture == null) return;
    final worker = await workerFuture;
    await Future.wait(
        _queues.values.map((f) => f.catchError((_) {})).toList());
    await worker.shutdown();
  }
```

and inside the existing `_run` (keep its envelope decoding + `KernelException` mapping verbatim), replace the `Isolate.run` call with:

```dart
    final worker = await _worker();
    final raw = await worker.request('execute', session.value, jsonEncode(command)) as String;
```

`versionInfo()` similarly routes `'version'` through the worker. Remove the now-unused top-level `_executeInIsolate` helper and the `dart:isolate` import if nothing else uses it.

`packages/jet_cad/lib/src/kernel/ffi_kernel_bridge_unsupported.dart` — mirror:

```dart
  Future<void> shutdown() => _unsupported();
```

- [ ] **Step 4: Run the full suite**

```bash
cd packages/jet_cad && flutter analyze && flutter test && dart format lib test
```

Expected: analyze clean, ALL tests green (the whole FFI lane now exercises the worker path — any old test that breaks is a regression to fix, not skip), format no diff. Then the lib-absent state:

```bash
cd packages/jet_cad && mv build/native build/native.bak && flutter test && mv build/native.bak build/native
```

Expected: guarded skips, everything else green.

- [ ] **Step 5: Commit**

```bash
git add packages/jet_cad/lib packages/jet_cad/test
git commit -m "feat: long-lived FFI worker isolate + dispose-join + fillet contract

Replaces per-command Isolate.run + dlopen with one worker isolate per
bridge (dlopen once, stable thread for the upcoming GL context; Plan 2
carry-over — the old path was too slow for render-rate traffic).
disposeSession now returns the in-flight dispose future to concurrent
callers. New public FfiKernelBridge.shutdown() tears the worker down;
commands after shutdown throw StateError. Contract suite pins fillet
minting non-empty edges/vertices and concurrent-dispose joining, run
against both fake and FFI bridges.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Native viewer core — V3d/AIS offscreen rendering into the IOSurface framebuffer

The real OCCT viewer replaces the spike's raw-GL debris. `Session` gains an optional `Viewer` created by `initViewer`; every mutating command auto-syncs the AIS display list; `renderFrame` is the only draw trigger (damage-driven — the shim never renders on its own). `fitAll` lands here (not Task 4) because no render test can see a box without framing it first.

**Files:**
- Create: `packages/jet_cad/src/native/viewer.hpp`
- Create: `packages/jet_cad/src/native/viewer.cpp`
- Modify: `packages/jet_cad/src/native/session.hpp` (viewer member; remove `spikeGl_`)
- Modify: `packages/jet_cad/src/native/session.cpp` (new dispatch, auto-sync hook; remove spike handlers)
- Modify: `packages/jet_cad/src/native/platform/gl_context.hpp` + `gl_context_macos.mm` (remove `renderTestPattern`)
- Modify: `packages/jet_cad/src/native/CMakeLists.txt` (viewer.cpp + TKOpenGl TKV3d TKService)
- Delete: `packages/jet_cad/src/native/tests/texture_spike_test.cpp`
- Create: `packages/jet_cad/src/native/tests/viewer_test.cpp`
- Modify: `apps/dev_harness/lib/main.dart` (spike pattern → real viewer render)

**Interfaces:**
- Consumes: `GlContext` (Task 1), `Session`/`Body` registry, spike findings from the ledger.
- Produces:
  - C++ `jetcad::Viewer` (`viewer.hpp`):
    - `Viewer(int widthPx, int heightPx, double pixelRatio);` — creates GlContext + surface FBO + OCCT driver/viewer/view/AIS context; throws `CommandError` on failure.
    - `uint32_t surfaceId() const;`
    - `void syncBodies(const std::map<std::string, Body>& bodies);` — diffs AIS display list against the registry (add / replace-on-`!IsSame` / remove). Never draws.
    - `void render();` — make-current, redraw into the surface FBO, coherency flush. The ONLY draw call in the shim.
    - `void fitAll();`
    - `std::vector<uint8_t> readPixels(int x, int y, int w, int h);`
  - JSON commands (all fail with the error envelope when the viewer is missing/already present, as noted):
    - `{"cmd":"initViewer","width":W,"height":H,"pixelRatio":R}` → `{"surfaceId":N}` — errors if already initialized; displays any existing bodies immediately.
    - `{"cmd":"renderFrame"}` → `{}`
    - `{"cmd":"cameraFit"}` → `{}`
    - `{"cmd":"debugReadPixels", ...}` → unchanged shape, now reads the viewer's surface (errors without a viewer).
  - Auto-sync contract: after every successful mutating command (`makeBox`, `extrude`, `boolean`, `fillet`, `transform`, `importStep`, `restoreBodies`, `deleteBodies`, `restoreSession`) with an active viewer, the AIS display list matches `bodies_`. Later tasks (pick/selection) rely on this.

- [ ] **Step 1: Write the failing viewer gtests**

Extend `packages/jet_cad/src/native/tests/support.hpp` with viewer helpers (inside `namespace jetcad::test`):

```cpp
inline std::array<uint8_t, 4> centerPixel(uint64_t session, int size) {
  json result = execOk(session, {{"cmd", "debugReadPixels"},
                                 {"x", size / 2},
                                 {"y", size / 2},
                                 {"width", 1},
                                 {"height", 1}});
  std::vector<uint8_t> rgba =
      jetcad::b64decode(result.at("rgbaBase64").get<std::string>());
  return {rgba[0], rgba[1], rgba[2], rgba[3]};
}

inline void initViewer(uint64_t session, int size) {
  json result = execOk(session, {{"cmd", "initViewer"},
                                 {"width", size},
                                 {"height", size},
                                 {"pixelRatio", 1.0}});
  EXPECT_GT(result.at("surfaceId").get<uint32_t>(), 0u);
}

inline json makeBox(uint64_t session, double x, double y, double z) {
  return execOk(session,
                {{"cmd", "makeBox"}, {"x", x}, {"y", y}, {"z", z}});
}

inline std::vector<uint8_t> readAll(uint64_t session, int size) {
  json result = execOk(session, {{"cmd", "debugReadPixels"},
                                 {"x", 0},
                                 {"y", 0},
                                 {"width", size},
                                 {"height", size}});
  return jetcad::b64decode(result.at("rgbaBase64").get<std::string>());
}
```

`packages/jet_cad/src/native/tests/viewer_test.cpp`:

```cpp
#include "support.hpp"

namespace {

using namespace jetcad::test;
using json = nlohmann::json;

TEST(ViewerTest, InitViewerTwiceFails) {
  uint64_t s = jc_create_session();
  initViewer(s, 64);
  json envelope = exec(s, {{"cmd", "initViewer"},
                           {"width", 64},
                           {"height", 64},
                           {"pixelRatio", 1.0}});
  EXPECT_FALSE(envelope.at("ok").get<bool>());
  jc_dispose_session(s);
}

TEST(ViewerTest, ViewerCommandsWithoutInitFail) {
  uint64_t s = jc_create_session();
  EXPECT_FALSE(exec(s, {{"cmd", "renderFrame"}}).at("ok").get<bool>());
  EXPECT_FALSE(exec(s, {{"cmd", "cameraFit"}}).at("ok").get<bool>());
  EXPECT_FALSE(exec(s, {{"cmd", "debugReadPixels"},
                        {"x", 0},
                        {"y", 0},
                        {"width", 1},
                        {"height", 1}})
                   .at("ok")
                   .get<bool>());
  jc_dispose_session(s);
}

TEST(ViewerTest, EmptySceneRendersUniformBackground) {
  uint64_t s = jc_create_session();
  initViewer(s, 64);
  execOk(s, {{"cmd", "renderFrame"}});
  json result = execOk(s, {{"cmd", "debugReadPixels"},
                           {"x", 0},
                           {"y", 0},
                           {"width", 64},
                           {"height", 64}});
  std::vector<uint8_t> rgba =
      jetcad::b64decode(result.at("rgbaBase64").get<std::string>());
  auto corner = pixelAt(rgba, 64, 1, 1);
  auto center = pixelAt(rgba, 64, 32, 32);
  EXPECT_EQ(corner, center) << "empty scene must be uniform background";
  jc_dispose_session(s);
}

TEST(ViewerTest, DisplayedBoxChangesCenterPixels) {
  uint64_t s = jc_create_session();
  initViewer(s, 128);
  execOk(s, {{"cmd", "renderFrame"}});
  auto background = centerPixel(s, 128);
  makeBox(s, 50, 50, 50);
  execOk(s, {{"cmd", "cameraFit"}});
  execOk(s, {{"cmd", "renderFrame"}});
  auto withBox = centerPixel(s, 128);
  EXPECT_NE(background, withBox) << "a fitted box must cover the view center";
  jc_dispose_session(s);
}

TEST(ViewerTest, DeleteRemovesBodyFromDisplay) {
  uint64_t s = jc_create_session();
  initViewer(s, 128);
  json box = makeBox(s, 50, 50, 50);
  std::string bodyId = box.at("body").get<std::string>();
  execOk(s, {{"cmd", "cameraFit"}});
  execOk(s, {{"cmd", "renderFrame"}});
  auto withBox = centerPixel(s, 128);
  execOk(s, {{"cmd", "deleteBodies"}, {"bodies", json::array({bodyId})}});
  execOk(s, {{"cmd", "renderFrame"}});
  auto after = centerPixel(s, 128);
  EXPECT_NE(withBox, after) << "deleted body must disappear";
  jc_dispose_session(s);
}

TEST(ViewerTest, RestoreSessionRedisplaysBodies) {
  uint64_t a = jc_create_session();
  makeBox(a, 50, 50, 50);
  json snapshot = execOk(a, {{"cmd", "saveSnapshot"}});
  jc_dispose_session(a);

  uint64_t b = jc_create_session();
  initViewer(b, 128);
  execOk(b, {{"cmd", "renderFrame"}});
  auto background = centerPixel(b, 128);
  execOk(b, {{"cmd", "restoreSession"}, {"snapshot", snapshot}});
  execOk(b, {{"cmd", "cameraFit"}});
  execOk(b, {{"cmd", "renderFrame"}});
  auto restored = centerPixel(b, 128);
  EXPECT_NE(background, restored)
      << "restoreSession must re-display restored bodies";
  jc_dispose_session(b);
}

}  // namespace
```

Adjust `makeBox`/`saveSnapshot`/`restoreSession` JSON parameter shapes to what the existing handlers in `session.cpp` actually parse (the existing native tests show the real shapes — e.g. the snapshot payload field name).

CMake: add `tests/viewer_test.cpp` to the test executable sources; remove `tests/texture_spike_test.cpp`.

- [ ] **Step 2: Run to verify failure**

```bash
cd packages/jet_cad && tool/build_native.sh
```

Expected: FAIL (unknown command `initViewer`).

- [ ] **Step 3: Add the OCCT viewer toolkits + viewer.cpp to CMake**

`packages/jet_cad/src/native/CMakeLists.txt` — append to the existing OCCT toolkit list:

```cmake
  TKService
  TKV3d
  TKOpenGl
```

and add `viewer.cpp` to the library sources. If configure fails on a toolkit name, run `ls $(brew --prefix opencascade)/lib | grep -iE 'opengl|v3d|service'` and adjust to what 7.9.3 ships (record the adjustment).

- [ ] **Step 4: Implement the Viewer**

`packages/jet_cad/src/native/viewer.hpp`:

```cpp
#pragma once

#include <cstdint>
#include <map>
#include <memory>
#include <string>
#include <vector>

#include <AIS_InteractiveContext.hxx>
#include <AIS_Shape.hxx>
#include <Aspect_NeutralWindow.hxx>
#include <OpenGl_GraphicDriver.hxx>
#include <TopoDS_Shape.hxx>
#include <V3d_View.hxx>
#include <V3d_Viewer.hxx>

#include "platform/gl_context.hpp"

namespace jetcad {

struct Body;  // session.hpp

// OCCT V3d/AIS viewer rendering offscreen into the platform GlContext's
// IOSurface-backed framebuffer. Owned by Session; created only for texture
// sessions. Never draws on its own — Session::execute calls syncBodies after
// mutating commands, and render() runs only on an explicit renderFrame.
class Viewer {
 public:
  Viewer(int widthPx, int heightPx, double pixelRatio);

  uint32_t surfaceId() const { return gl_->surfaceId(); }
  int width() const { return gl_->width(); }
  int height() const { return gl_->height(); }

  void syncBodies(const std::map<std::string, Body>& bodies);
  void render();
  void fitAll();
  std::vector<uint8_t> readPixels(int x, int y, int w, int h);

 private:
  void bindViewToSurface();

  struct Displayed {
    Handle(AIS_Shape) ais;
    TopoDS_Shape shape;
  };

  std::unique_ptr<GlContext> gl_;
  Handle(OpenGl_GraphicDriver) driver_;
  Handle(V3d_Viewer) viewer_;
  Handle(V3d_View) view_;
  Handle(Aspect_NeutralWindow) window_;
  Handle(AIS_InteractiveContext) context_;
  std::map<std::string, Displayed> displayed_;
  double pixelRatio_ = 1.0;
};

}  // namespace jetcad
```

`packages/jet_cad/src/native/viewer.cpp`:

```cpp
#include "viewer.hpp"

#include <Aspect_DisplayConnection.hxx>
#include <Graphic3d_Camera.hxx>
#include <OpenGl_Context.hxx>
#include <OpenGl_FrameBuffer.hxx>
#include <Quantity_Color.hxx>

#include <stdexcept>

#include "session.hpp"

namespace jetcad {

Viewer::Viewer(int widthPx, int heightPx, double pixelRatio)
    : pixelRatio_(pixelRatio) {
  try {
    gl_ = GlContext::create();
    gl_->makeCurrent();
    gl_->createSurfaceFramebuffer(widthPx, heightPx);
  } catch (const std::runtime_error& e) {
    throw CommandError(e.what());
  }

  Handle(Aspect_DisplayConnection) display = new Aspect_DisplayConnection();
  driver_ = new OpenGl_GraphicDriver(display, /*theToInitialize*/ false);
  driver_->ChangeOptions().buffersNoSwap = true;
  driver_->ChangeOptions().buffersOpaqueAlpha = true;
  driver_->ChangeOptions().useSystemBuffer = false;
  if (!driver_->InitContext()) {
    throw CommandError("OpenGl_GraphicDriver::InitContext failed");
  }

  viewer_ = new V3d_Viewer(driver_);
  viewer_->SetDefaultLights();
  viewer_->SetLightOn();

  view_ = viewer_->CreateView();
  window_ = new Aspect_NeutralWindow();
  window_->SetSize(widthPx, heightPx);
  view_->SetWindow(window_, (Aspect_RenderingContext)gl_->nativeContext());
  view_->SetBackgroundColor(
      Quantity_Color(0.12, 0.12, 0.14, Quantity_TOC_sRGB));
  view_->Camera()->SetProjectionType(Graphic3d_Camera::Projection_Perspective);
  view_->SetImmediateUpdate(false);
  bindViewToSurface();

  context_ = new AIS_InteractiveContext(viewer_);
  context_->SetDisplayMode(AIS_Shaded, false);
}

void Viewer::bindViewToSurface() {
  gl_->makeCurrent();
  gl_->bindSurfaceFramebuffer();
  Handle(OpenGl_Context) glCtx = driver_->GetSharedContext();
  if (glCtx.IsNull()) {
    throw CommandError("no shared OpenGl_Context");
  }
  Handle(OpenGl_FrameBuffer) fbo = new OpenGl_FrameBuffer();
  if (!fbo->InitWrapper(glCtx)) {
    throw CommandError("OpenGl_FrameBuffer::InitWrapper failed");
  }
  view_->View()->SetFBO(fbo);
}

void Viewer::syncBodies(const std::map<std::string, Body>& bodies) {
  gl_->makeCurrent();
  for (const auto& [id, body] : bodies) {
    auto it = displayed_.find(id);
    if (it == displayed_.end()) {
      Handle(AIS_Shape) ais = new AIS_Shape(body.shape);
      context_->Display(ais, AIS_Shaded, /*selection mode*/ 0,
                        /*update viewer*/ false);
      displayed_.emplace(id, Displayed{ais, body.shape});
    } else if (!it->second.shape.IsSame(body.shape)) {
      it->second.ais->SetShape(body.shape);
      context_->Redisplay(it->second.ais, false);
      it->second.shape = body.shape;
    }
  }
  for (auto it = displayed_.begin(); it != displayed_.end();) {
    if (bodies.find(it->first) == bodies.end()) {
      context_->Remove(it->second.ais, false);
      it = displayed_.erase(it);
    } else {
      ++it;
    }
  }
}

void Viewer::render() {
  gl_->makeCurrent();
  view_->Invalidate();
  view_->Redraw();
  gl_->flush();
}

void Viewer::fitAll() {
  gl_->makeCurrent();
  view_->FitAll(0.01, false);
  view_->ZFitAll();
}

std::vector<uint8_t> Viewer::readPixels(int x, int y, int w, int h) {
  return gl_->readPixels(x, y, w, h);
}

}  // namespace jetcad
```

API-adjust notes: `V3d_View::SetWindow(theWindow, theContext)` wrapping an external context + `Aspect_NeutralWindow` is OCCT's documented offscreen-embedding pattern (its Emscripten sample uses it). If 7.9.3 wants `window_->SetVirtual(true)` or a `view_->MustBeResized()` after SetWindow, add it. If `OpenGl_FrameBuffer::InitWrapper` has different arity, wrap the currently-bound FBO per its header docs. Record every adjustment in the report.

- [ ] **Step 5: Wire the Session**

`packages/jet_cad/src/native/session.hpp` — replace the spike members with:

```cpp
#include "viewer.hpp"
```

```cpp
  json cmdInitViewer(const json& cmd);
  json cmdRenderFrame();
  json cmdCameraFit();
  json cmdDebugReadPixels(const json& cmd);
  Viewer& requireViewer();

  std::unique_ptr<Viewer> viewer_;
```

(`viewer.hpp` only forward-declares `Body` and includes `session.hpp` from viewer.cpp, so there is no include cycle.)

`packages/jet_cad/src/native/session.cpp` — remove the three spike handlers/branches; rework `Session::execute` so mutating commands auto-sync with ONE hook:

```cpp
json Session::execute(const json& cmd) {
  const std::string name = cmd.at("cmd").get<std::string>();

  static const std::set<std::string> kMutating = {
      "makeBox",       "extrude",      "boolean",
      "fillet",        "transform",    "importStep",
      "restoreBodies", "deleteBodies", "restoreSession",
  };

  json result;
  if (name == "makeBox") result = cmdMakeBox(cmd);
  // ... existing chain, converted from `return handler(...)` to
  //     `result = handler(...)` ...
  else if (name == "initViewer") result = cmdInitViewer(cmd);
  else if (name == "renderFrame") result = cmdRenderFrame();
  else if (name == "cameraFit") result = cmdCameraFit();
  else if (name == "debugReadPixels") result = cmdDebugReadPixels(cmd);
  else throw CommandError("unknown command: " + name);

  if (viewer_ && kMutating.count(name) > 0) {
    viewer_->syncBodies(bodies_);
  }
  return result;
}
```

New handlers:

```cpp
json Session::cmdInitViewer(const json& cmd) {
  if (viewer_) throw CommandError("viewer already initialized");
  const int width = cmd.at("width").get<int>();
  const int height = cmd.at("height").get<int>();
  const double pixelRatio = cmd.at("pixelRatio").get<double>();
  if (width <= 0 || height <= 0) {
    throw CommandError("viewer size must be positive");
  }
  viewer_ = std::make_unique<Viewer>(width, height, pixelRatio);
  viewer_->syncBodies(bodies_);
  return json{{"surfaceId", viewer_->surfaceId()}};
}

json Session::cmdRenderFrame() {
  requireViewer().render();
  return json::object();
}

json Session::cmdCameraFit() {
  requireViewer().fitAll();
  return json::object();
}

json Session::cmdDebugReadPixels(const json& cmd) {
  Viewer& viewer = requireViewer();
  const int x = cmd.at("x").get<int>();
  const int y = cmd.at("y").get<int>();
  const int w = cmd.at("width").get<int>();
  const int h = cmd.at("height").get<int>();
  if (w <= 0 || h <= 0 || x < 0 || y < 0 || x + w > viewer.width() ||
      y + h > viewer.height()) {
    throw CommandError("readPixels rectangle out of bounds");
  }
  return json{{"width", w},
              {"height", h},
              {"rgbaBase64", b64encode(viewer.readPixels(x, y, w, h))}};
}

Viewer& Session::requireViewer() {
  if (!viewer_) throw CommandError("viewer not initialized");
  return *viewer_;
}
```

Remove `renderTestPattern` from `gl_context.hpp` and `gl_context_macos.mm`.

- [ ] **Step 6: Run the native suite to verify green**

```bash
cd packages/jet_cad && tool/build_native.sh
```

Expected: exit 0; 18 original + 6 `ViewerTest.*` green, spike tests gone (count from real ctest output).

- [ ] **Step 7: Update the harness to render real geometry**

`apps/dev_harness/lib/main.dart` — in `_start()`, replace the spike init/pattern block with:

```dart
      final init = await bridge.debugExecute(session, {
        'cmd': 'initViewer',
        'width': 512,
        'height': 512,
        'pixelRatio': 1.0,
      });
      final surfaceId = init['surfaceId'] as int;
      final textureId = await _channel
          .invokeMethod<int>('registerTexture', {'surfaceId': surfaceId});
      await bridge.debugExecute(
          session, {'cmd': 'makeBox', 'x': 50.0, 'y': 50.0, 'z': 50.0});
      await bridge.debugExecute(session, {'cmd': 'cameraFit'});
      await bridge.debugExecute(session, {'cmd': 'renderFrame'});
      await _channel.invokeMethod<void>('frameReady', {'textureId': textureId});
```

(Match makeBox keys to the real handler, same as the gtest.) Run `packages/jet_cad/tool/run_harness.sh`, screenshot per Task 1 Step 16, verify a shaded box inside the Flutter window; note lighting/orientation vs spike findings in the ledger.

- [ ] **Step 8: Full verification + commit**

```bash
cd packages/jet_cad && flutter analyze && flutter test && dart format lib test
cd ../../apps/dev_harness && flutter analyze
```

Expected: all clean/green (Dart suite untouched but proven).

```bash
git add packages/jet_cad/src/native apps/dev_harness
git commit -m "feat: OCCT V3d/AIS viewer rendering offscreen into IOSurface FBO

Session gains an optional Viewer (initViewer command; texture sessions
only): OpenGl_GraphicDriver wrapping the platform CGL context via
Aspect_NeutralWindow, view FBO bound to the IOSurface framebuffer via
OpenGl_FrameBuffer::InitWrapper. Display list auto-syncs to the body
registry after every mutating command (add/replace/remove diff via
TopoDS_Shape::IsSame); renderFrame is the only draw trigger
(damage-driven); cameraFit frames the scene. debugReadPixels re-homed
onto the viewer; spike commands/test pattern removed. Links
TKService/TKV3d/TKOpenGl.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Native camera navigation + viewport resize

Gesture-shaped camera commands (OCCT's `StartRotation`/`Rotation` pair maps 1:1 onto drag gestures) and IOSurface reallocation on resize.

**Files:**
- Modify: `packages/jet_cad/src/native/viewer.hpp` / `viewer.cpp`
- Modify: `packages/jet_cad/src/native/session.hpp` / `session.cpp`
- Create: `packages/jet_cad/src/native/tests/camera_test.cpp`
- Modify: `packages/jet_cad/src/native/CMakeLists.txt` (test source)

**Interfaces:**
- Consumes: `Viewer` (Task 3).
- Produces JSON commands (viewer required; error envelope otherwise):
  - `{"cmd":"cameraOrbitStart","x":X,"y":Y}` → `{}` — X/Y in physical framebuffer pixels, origin top-left (OCCT view convention).
  - `{"cmd":"cameraOrbit","x":X,"y":Y}` → `{}` — continues the rotation from the last orbitStart.
  - `{"cmd":"cameraPan","dx":DX,"dy":DY}` → `{}` — pixel deltas.
  - `{"cmd":"cameraZoom","factor":F}` → `{}` — F > 1 zooms in, 0 < F < 1 zooms out; F ≤ 0 errors.
  - `{"cmd":"resizeViewport","width":W,"height":H,"pixelRatio":R}` → `{"surfaceId":N}` — reallocates the IOSurface (NEW surface id every call), resizes window/view/FBO wrap.
  - Viewer C++ additions: `void orbitStart(double x, double y); void orbit(double x, double y); void pan(double dx, double dy); void zoom(double factor); uint32_t resize(int widthPx, int heightPx, double pixelRatio);`
- Camera state (position/orientation) is deliberately NOT serialized — view state, not document state.

- [ ] **Step 1: Write the failing camera gtests**

`packages/jet_cad/src/native/tests/camera_test.cpp` (helpers come from `support.hpp`):

```cpp
#include "support.hpp"

namespace {

using namespace jetcad::test;
using json = nlohmann::json;

TEST(CameraTest, OrbitChangesTheImage) {
  uint64_t s = jc_create_session();
  initViewer(s, 128);
  makeBox(s, 50, 30, 20);
  execOk(s, {{"cmd", "cameraFit"}});
  execOk(s, {{"cmd", "renderFrame"}});
  auto before = readAll(s, 128);
  execOk(s, {{"cmd", "cameraOrbitStart"}, {"x", 64}, {"y", 64}});
  execOk(s, {{"cmd", "cameraOrbit"}, {"x", 96}, {"y", 80}});
  execOk(s, {{"cmd", "renderFrame"}});
  auto after = readAll(s, 128);
  EXPECT_NE(before, after) << "orbit must change the rendered image";
  jc_dispose_session(s);
}

TEST(CameraTest, PanShiftsTheImage) {
  uint64_t s = jc_create_session();
  initViewer(s, 128);
  makeBox(s, 50, 30, 20);
  execOk(s, {{"cmd", "cameraFit"}});
  execOk(s, {{"cmd", "renderFrame"}});
  auto before = readAll(s, 128);
  execOk(s, {{"cmd", "cameraPan"}, {"dx", 30}, {"dy", 0}});
  execOk(s, {{"cmd", "renderFrame"}});
  auto after = readAll(s, 128);
  EXPECT_NE(before, after) << "pan must change the rendered image";
  jc_dispose_session(s);
}

TEST(CameraTest, ZoomOutShrinksBoxCoverage) {
  uint64_t s = jc_create_session();
  initViewer(s, 128);
  makeBox(s, 50, 50, 50);
  execOk(s, {{"cmd", "cameraFit"}});
  execOk(s, {{"cmd", "renderFrame"}});
  auto fittedCorner = pixelAt(readAll(s, 128), 128, 4, 4);
  execOk(s, {{"cmd", "cameraZoom"}, {"factor", 0.25}});
  execOk(s, {{"cmd", "renderFrame"}});
  auto zoomedCenter = centerPixel(s, 128);
  auto zoomedCorner = pixelAt(readAll(s, 128), 128, 4, 4);
  // After zooming far out the corner must be background while the center
  // still shows the (now small) box.
  EXPECT_EQ(fittedCorner, zoomedCorner)
      << "corners are background in both fitted and zoomed-out views";
  EXPECT_NE(zoomedCenter, zoomedCorner)
      << "box still covers the center after zoom-out";
  jc_dispose_session(s);
}

TEST(CameraTest, ZoomFactorMustBePositive) {
  uint64_t s = jc_create_session();
  initViewer(s, 64);
  EXPECT_FALSE(
      exec(s, {{"cmd", "cameraZoom"}, {"factor", 0.0}}).at("ok").get<bool>());
  EXPECT_FALSE(
      exec(s, {{"cmd", "cameraZoom"}, {"factor", -2.0}}).at("ok").get<bool>());
  jc_dispose_session(s);
}

TEST(CameraTest, ResizeReturnsFreshSurfaceAndDimensions) {
  uint64_t s = jc_create_session();
  json init = execOk(s, {{"cmd", "initViewer"},
                         {"width", 64},
                         {"height", 64},
                         {"pixelRatio", 1.0}});
  uint32_t firstSurface = init.at("surfaceId").get<uint32_t>();
  json resized = execOk(s, {{"cmd", "resizeViewport"},
                            {"width", 200},
                            {"height", 100},
                            {"pixelRatio", 2.0}});
  uint32_t secondSurface = resized.at("surfaceId").get<uint32_t>();
  EXPECT_NE(firstSurface, secondSurface)
      << "resize reallocates the IOSurface";
  execOk(s, {{"cmd", "renderFrame"}});
  json pixels = execOk(s, {{"cmd", "debugReadPixels"},
                           {"x", 0},
                           {"y", 0},
                           {"width", 200},
                           {"height", 100}});
  EXPECT_EQ(pixels.at("width").get<int>(), 200);
  jc_dispose_session(s);
}

TEST(CameraTest, CameraCommandsWithoutViewerFail) {
  uint64_t s = jc_create_session();
  EXPECT_FALSE(exec(s, {{"cmd", "cameraOrbitStart"}, {"x", 0}, {"y", 0}})
                   .at("ok").get<bool>());
  EXPECT_FALSE(exec(s, {{"cmd", "cameraPan"}, {"dx", 1}, {"dy", 1}})
                   .at("ok").get<bool>());
  EXPECT_FALSE(exec(s, {{"cmd", "resizeViewport"},
                        {"width", 32},
                        {"height", 32},
                        {"pixelRatio", 1.0}})
                   .at("ok").get<bool>());
  jc_dispose_session(s);
}

}  // namespace
```

Add `tests/camera_test.cpp` to CMake. Run `tool/build_native.sh` — expected: FAIL (unknown commands).

- [ ] **Step 2: Implement camera + resize on the Viewer**

`viewer.hpp` — public additions:

```cpp
  void orbitStart(double x, double y);
  void orbit(double x, double y);
  void pan(double dx, double dy);
  void zoom(double factor);
  uint32_t resize(int widthPx, int heightPx, double pixelRatio);
```

`viewer.cpp`:

```cpp
void Viewer::orbitStart(double x, double y) {
  gl_->makeCurrent();
  view_->StartRotation(static_cast<int>(x), static_cast<int>(y));
}

void Viewer::orbit(double x, double y) {
  gl_->makeCurrent();
  view_->Rotation(static_cast<int>(x), static_cast<int>(y));
}

void Viewer::pan(double dx, double dy) {
  gl_->makeCurrent();
  // OCCT pans in view coordinates: +Y up, while our deltas arrive in
  // screen coordinates (+Y down) — hence the sign flip.
  view_->Pan(static_cast<int>(dx), static_cast<int>(-dy));
}

void Viewer::zoom(double factor) {
  if (factor <= 0.0) throw CommandError("zoom factor must be positive");
  gl_->makeCurrent();
  view_->SetZoom(factor);
}

uint32_t Viewer::resize(int widthPx, int heightPx, double pixelRatio) {
  gl_->makeCurrent();
  const uint32_t surfaceId =
      gl_->createSurfaceFramebuffer(widthPx, heightPx);
  window_->SetSize(widthPx, heightPx);
  view_->MustBeResized();
  bindViewToSurface();
  pixelRatio_ = pixelRatio;
  return surfaceId;
}
```

API-adjust notes: `V3d_View::Pan(Dx, Dy, aZoomFactor=1, theToStart=true)` and `SetZoom(Coef, Start=true)` — match the 7.9.3 signatures; if the pan sign flip turns out wrong in the Task 9 manual check, flip it there and note it. `Rotation`/`StartRotation` take ints (pixel coords, origin top-left).

Session dispatch additions (inside the non-mutating section of `execute`; none of these sync bodies):

```cpp
  else if (name == "cameraOrbitStart") {
    requireViewer().orbitStart(cmd.at("x").get<double>(),
                               cmd.at("y").get<double>());
    result = json::object();
  } else if (name == "cameraOrbit") {
    requireViewer().orbit(cmd.at("x").get<double>(),
                          cmd.at("y").get<double>());
    result = json::object();
  } else if (name == "cameraPan") {
    requireViewer().pan(cmd.at("dx").get<double>(),
                        cmd.at("dy").get<double>());
    result = json::object();
  } else if (name == "cameraZoom") {
    requireViewer().zoom(cmd.at("factor").get<double>());
    result = json::object();
  } else if (name == "resizeViewport") {
    const int w = cmd.at("width").get<int>();
    const int h = cmd.at("height").get<int>();
    if (w <= 0 || h <= 0) throw CommandError("viewport size must be positive");
    result = json{{"surfaceId",
                   requireViewer().resize(w, h,
                                          cmd.at("pixelRatio").get<double>())}};
  }
```

- [ ] **Step 3: Run the native suite green**

```bash
cd packages/jet_cad && tool/build_native.sh
```

Expected: exit 0, previous tests + 6 `CameraTest.*` green.

- [ ] **Step 4: Full Dart verification + commit**

```bash
cd packages/jet_cad && flutter analyze && flutter test && dart format lib test
```

```bash
git add packages/jet_cad/src/native
git commit -m "feat: native camera navigation and viewport resize

cameraOrbitStart/cameraOrbit map OCCT's StartRotation/Rotation pair
onto drag gestures; cameraPan/cameraZoom wrap Pan/SetZoom (zoom factor
must be positive); resizeViewport reallocates the IOSurface framebuffer
(fresh surface id every call), resizes the neutral window and re-wraps
the view FBO. Camera state is view state — never serialized. Pixel-diff
gtests cover orbit/pan/zoom effects, resize reallocation and
missing-viewer errors.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Native pick + selection highlight

AIS subshape picking: filter-driven selection modes, detected owner mapped back to session ids via `TopoDS_Shape::IsSame` against the body's id-ordered subshape lists. Programmatic selection drives AIS's native highlight, which shows up on the next `renderFrame`.

**Files:**
- Modify: `packages/jet_cad/src/native/viewer.hpp` / `viewer.cpp`
- Modify: `packages/jet_cad/src/native/session.hpp` / `session.cpp`
- Create: `packages/jet_cad/src/native/tests/selection_test.cpp`
- Modify: `packages/jet_cad/src/native/CMakeLists.txt` (test source)

**Interfaces:**
- Consumes: `Viewer` display list (Task 3) — pick/selection operate on displayed AIS shapes only.
- Produces JSON commands:
  - `{"cmd":"pick","x":X,"y":Y,"filter":"body"|"face"|"edge"|"vertex"}` → `{"hit":null}` or `{"hit":{"entity":"f3","body":"b1"}}` — X/Y physical framebuffer px, origin top-left. `"body"` filter returns `entity == body id`. Unknown filter errors.
  - `{"cmd":"setSelection","ids":["b1","f2",...]}` → `{}` — replaces the whole selection; empty list clears. Unknown id errors (nothing partially applied — validate all ids first). Selected entities render highlighted on the next renderFrame.
  - Viewer C++ additions:
    - `struct PickHit { std::string entity; std::string body; };`
    - `std::optional<PickHit> pick(double x, double y, const std::string& filter, const std::map<std::string, Body>& bodies);`
    - `void setSelection(const std::vector<std::string>& ids, const std::map<std::string, Body>& bodies);`
- Id-kind convention (used to resolve selection modes): prefix `b` = body, `f` = face, `e` = edge, `v` = vertex (established in Plan 2, contractual here).

- [ ] **Step 1: Write the failing selection gtests**

`packages/jet_cad/src/native/tests/selection_test.cpp` (helpers from `support.hpp`):

```cpp
#include "support.hpp"

#include <algorithm>

namespace {

using namespace jetcad::test;
using json = nlohmann::json;

json pick(uint64_t s, int x, int y, const std::string& filter) {
  return execOk(
      s, {{"cmd", "pick"}, {"x", x}, {"y", y}, {"filter", filter}});
}

TEST(SelectionTest, PickBodyAtCenterHitsTheBox) {
  uint64_t s = jc_create_session();
  initViewer(s, 128);
  json box = makeBox(s, 50, 50, 50);
  std::string bodyId = box.at("body").get<std::string>();
  execOk(s, {{"cmd", "cameraFit"}});
  execOk(s, {{"cmd", "renderFrame"}});
  json hit = pick(s, 64, 64, "body").at("hit");
  ASSERT_FALSE(hit.is_null());
  EXPECT_EQ(hit.at("entity").get<std::string>(), bodyId);
  EXPECT_EQ(hit.at("body").get<std::string>(), bodyId);
  jc_dispose_session(s);
}

TEST(SelectionTest, PickFaceAtCenterReturnsAFaceOfTheBox) {
  uint64_t s = jc_create_session();
  initViewer(s, 128);
  json box = makeBox(s, 50, 50, 50);
  std::string bodyId = box.at("body").get<std::string>();
  std::vector<std::string> faces =
      box.at("faces").get<std::vector<std::string>>();
  execOk(s, {{"cmd", "cameraFit"}});
  execOk(s, {{"cmd", "renderFrame"}});
  json hit = pick(s, 64, 64, "face").at("hit");
  ASSERT_FALSE(hit.is_null());
  EXPECT_EQ(hit.at("body").get<std::string>(), bodyId);
  EXPECT_NE(std::find(faces.begin(), faces.end(),
                      hit.at("entity").get<std::string>()),
            faces.end())
      << "picked face id must be one of the box's face ids";
  jc_dispose_session(s);
}

TEST(SelectionTest, PickEmptySpaceReturnsNull) {
  uint64_t s = jc_create_session();
  initViewer(s, 128);
  makeBox(s, 50, 50, 50);
  execOk(s, {{"cmd", "cameraFit"}});
  execOk(s, {{"cmd", "cameraZoom"}, {"factor", 0.2}});
  execOk(s, {{"cmd", "renderFrame"}});
  json hit = pick(s, 2, 2, "body").at("hit");
  EXPECT_TRUE(hit.is_null());
  jc_dispose_session(s);
}

TEST(SelectionTest, PickWithUnknownFilterFails) {
  uint64_t s = jc_create_session();
  initViewer(s, 64);
  EXPECT_FALSE(exec(s, {{"cmd", "pick"},
                        {"x", 1},
                        {"y", 1},
                        {"filter", "wireframe"}})
                   .at("ok").get<bool>());
  jc_dispose_session(s);
}

TEST(SelectionTest, SetSelectionHighlightChangesPixels) {
  uint64_t s = jc_create_session();
  initViewer(s, 128);
  json box = makeBox(s, 50, 50, 50);
  std::string bodyId = box.at("body").get<std::string>();
  execOk(s, {{"cmd", "cameraFit"}});
  execOk(s, {{"cmd", "renderFrame"}});
  auto before = readAll(s, 128);
  execOk(s, {{"cmd", "setSelection"}, {"ids", json::array({bodyId})}});
  execOk(s, {{"cmd", "renderFrame"}});
  auto highlighted = readAll(s, 128);
  EXPECT_NE(before, highlighted) << "selection highlight must be visible";
  execOk(s, {{"cmd", "setSelection"}, {"ids", json::array()}});
  execOk(s, {{"cmd", "renderFrame"}});
  auto cleared = readAll(s, 128);
  EXPECT_EQ(before, cleared) << "clearing selection restores the image";
  jc_dispose_session(s);
}

TEST(SelectionTest, SetSelectionUnknownIdFailsAtomically) {
  uint64_t s = jc_create_session();
  initViewer(s, 128);
  json box = makeBox(s, 50, 50, 50);
  std::string bodyId = box.at("body").get<std::string>();
  execOk(s, {{"cmd", "cameraFit"}});
  execOk(s, {{"cmd", "renderFrame"}});
  auto before = readAll(s, 128);
  EXPECT_FALSE(exec(s, {{"cmd", "setSelection"},
                        {"ids", json::array({bodyId, "b999"})}})
                   .at("ok").get<bool>());
  execOk(s, {{"cmd", "renderFrame"}});
  EXPECT_EQ(before, readAll(s, 128))
      << "failed setSelection must not partially highlight";
  jc_dispose_session(s);
}

TEST(SelectionTest, PickWithoutViewerFails) {
  uint64_t s = jc_create_session();
  EXPECT_FALSE(exec(s, {{"cmd", "pick"},
                        {"x", 0}, {"y", 0}, {"filter", "body"}})
                   .at("ok").get<bool>());
  EXPECT_FALSE(exec(s, {{"cmd", "setSelection"}, {"ids", json::array()}})
                   .at("ok").get<bool>());
  jc_dispose_session(s);
}

}  // namespace
```

Add to CMake; run `tool/build_native.sh` — expected FAIL (unknown command `pick`).

- [ ] **Step 2: Implement pick/setSelection on the Viewer**

`viewer.hpp` — additions (plus `#include <optional>`):

```cpp
  struct PickHit {
    std::string entity;
    std::string body;
  };

  std::optional<PickHit> pick(double x, double y, const std::string& filter,
                              const std::map<std::string, Body>& bodies);
  void setSelection(const std::vector<std::string>& ids,
                    const std::map<std::string, Body>& bodies);

 private:
  void activateSelectionMode(int mode);
  std::string bodyIdOfAis(const Handle(AIS_InteractiveObject)& object) const;

  int activeMode_ = 0;
```

`viewer.cpp` — additions (includes: `SelectMgr_EntityOwner.hxx`, `StdSelect_BRepOwner.hxx`, `TopAbs_ShapeEnum.hxx`):

```cpp
namespace {

int selectionModeFor(const std::string& filter) {
  if (filter == "body") return 0;  // whole-shape mode
  if (filter == "face") return AIS_Shape::SelectionMode(TopAbs_FACE);
  if (filter == "edge") return AIS_Shape::SelectionMode(TopAbs_EDGE);
  if (filter == "vertex") return AIS_Shape::SelectionMode(TopAbs_VERTEX);
  throw CommandError("unknown pick filter: " + filter);
}

int selectionModeForId(const std::string& id) {
  if (id.empty()) throw CommandError("empty entity id");
  switch (id[0]) {
    case 'b': return 0;
    case 'f': return AIS_Shape::SelectionMode(TopAbs_FACE);
    case 'e': return AIS_Shape::SelectionMode(TopAbs_EDGE);
    case 'v': return AIS_Shape::SelectionMode(TopAbs_VERTEX);
    default: throw CommandError("unrecognized entity id: " + id);
  }
}

}  // namespace

void Viewer::activateSelectionMode(int mode) {
  if (mode == activeMode_) return;
  for (auto& [id, displayed] : displayed_) {
    context_->Deactivate(displayed.ais);
    context_->Activate(displayed.ais, mode);
  }
  activeMode_ = mode;
}

std::string Viewer::bodyIdOfAis(
    const Handle(AIS_InteractiveObject)& object) const {
  for (const auto& [id, displayed] : displayed_) {
    if (displayed.ais == object) return id;
  }
  throw CommandError("detected object is not a tracked body");
}

std::optional<Viewer::PickHit> Viewer::pick(
    double x, double y, const std::string& filter,
    const std::map<std::string, Body>& bodies) {
  gl_->makeCurrent();
  activateSelectionMode(selectionModeFor(filter));
  context_->MoveTo(static_cast<int>(x), static_cast<int>(y), view_,
                   /*theToRedrawOnUpdate*/ false);
  if (!context_->HasDetected()) return std::nullopt;

  Handle(SelectMgr_EntityOwner) owner = context_->DetectedOwner();
  Handle(AIS_InteractiveObject) object =
      Handle(AIS_InteractiveObject)::DownCast(owner->Selectable());
  const std::string bodyId = bodyIdOfAis(object);
  if (filter == "body") return PickHit{bodyId, bodyId};

  Handle(StdSelect_BRepOwner) brepOwner =
      Handle(StdSelect_BRepOwner)::DownCast(owner);
  if (brepOwner.IsNull() || !brepOwner->HasShape()) {
    return PickHit{bodyId, bodyId};  // degraded: no subshape info
  }
  const TopoDS_Shape& sub = brepOwner->Shape();
  const Body& body = bodies.at(bodyId);
  const auto* list = filter == "face"   ? &body.faces
                     : filter == "edge" ? &body.edges
                                        : &body.vertices;
  for (const auto& [subId, shape] : *list) {
    if (shape.IsSame(sub)) return PickHit{subId, bodyId};
  }
  // Detected subshape missing from the id map would be a lineage bug —
  // surface it instead of guessing.
  throw CommandError("picked subshape has no session id (lineage bug)");
}

void Viewer::setSelection(const std::vector<std::string>& ids,
                          const std::map<std::string, Body>& bodies) {
  gl_->makeCurrent();

  // Resolve everything first: unknown ids must not partially apply.
  struct Target {
    std::string bodyId;
    TopoDS_Shape shape;
    int mode;
  };
  std::vector<Target> targets;
  targets.reserve(ids.size());
  for (const auto& id : ids) {
    const int mode = selectionModeForId(id);
    if (mode == 0) {
      auto it = bodies.find(id);
      if (it == bodies.end()) throw CommandError("unknown body id: " + id);
      targets.push_back({id, it->second.shape, 0});
      continue;
    }
    bool found = false;
    for (const auto& [bodyId, body] : bodies) {
      const auto* list = id[0] == 'f'   ? &body.faces
                         : id[0] == 'e' ? &body.edges
                                        : &body.vertices;
      for (const auto& [subId, shape] : *list) {
        if (subId == id) {
          targets.push_back({bodyId, shape, mode});
          found = true;
          break;
        }
      }
      if (found) break;
    }
    if (!found) throw CommandError("unknown entity id: " + id);
  }

  context_->ClearSelected(false);
  for (const auto& target : targets) {
    auto& displayed = displayed_.at(target.bodyId);
    // Activating the mode (re)computes the selection owners for it.
    activateSelectionMode(target.mode);
    bool selected = false;
    for (const Handle(SelectMgr_Selection)& selection :
         displayed.ais->Selections()) {
      if (selection->Mode() != target.mode) continue;
      for (NCollection_Vector<Handle(SelectMgr_SelectionEntity)>::Iterator
               entityIt(selection->Entities());
           entityIt.More(); entityIt.Next()) {
        Handle(SelectMgr_EntityOwner) owner =
            entityIt.Value()->BaseSensitive()->OwnerId();
        Handle(StdSelect_BRepOwner) brepOwner =
            Handle(StdSelect_BRepOwner)::DownCast(owner);
        if (brepOwner.IsNull() || !brepOwner->HasShape()) continue;
        if (brepOwner->Shape().IsSame(target.shape)) {
          context_->AddOrRemoveSelected(owner, false);
          selected = true;
          break;
        }
      }
      if (selected) break;
    }
    if (!selected) {
      context_->ClearSelected(false);
      throw CommandError("no selectable owner for id: " + target.bodyId);
    }
  }
}
```

API-adjust notes: the `Selections()` iteration API differs across OCCT versions (`SelectMgr_SequenceOfSelection` vs entity iterators) — follow the 7.9.3 headers; the intent is: for the given mode, find the `StdSelect_BRepOwner` whose shape `IsSame` the target, then `AddOrRemoveSelected`. If owners are only computed lazily on `Activate`, keep the `activateSelectionMode` call before searching (as written). Selected-owner highlight renders on the next `Redraw` automatically.

Session dispatch (non-mutating):

```cpp
  else if (name == "pick") {
    auto hit = requireViewer().pick(cmd.at("x").get<double>(),
                                    cmd.at("y").get<double>(),
                                    cmd.at("filter").get<std::string>(),
                                    bodies_);
    result = hit.has_value()
                 ? json{{"hit", {{"entity", hit->entity}, {"body", hit->body}}}}
                 : json{{"hit", nullptr}};
  } else if (name == "setSelection") {
    requireViewer().setSelection(
        cmd.at("ids").get<std::vector<std::string>>(), bodies_);
    result = json::object();
  }
```

- [ ] **Step 3: Run the native suite green**

```bash
cd packages/jet_cad && tool/build_native.sh
```

Expected: exit 0, previous + 7 `SelectionTest.*` green.

- [ ] **Step 4 (opportunistic, carry-over): probe for a 1:N fillet split-face fixture**

Plan 2 deferred a 1:N fillet remap test because a plain box fillet cannot produce one. Selection work now has fused fixtures available: fuse two boxes (`makeBox` ×2 + `boolean` fuse), fillet the concave junction edge, and inspect the remap for any old face id mapping to >1 new ids. Timebox ~30 min. If a 1:N mapping appears, add a gtest pinning it (name: `ModelingTest.FilletSplitsAdjacentFaceOneToMany` in `modeling_test.cpp`); if not, record in the ledger why (e.g. junction edge not filletable / remap stays 1:1) and move on. Do not force it.

- [ ] **Step 5: Full verification + commit**

```bash
cd packages/jet_cad && tool/build_native.sh
cd packages/jet_cad && flutter analyze && flutter test && dart format lib test
```

```bash
git add packages/jet_cad/src/native
git commit -m "feat: native pick and selection highlight

pick activates the AIS selection mode for the filter (whole-shape/
face/edge/vertex), MoveTo-detects at framebuffer coords and maps the
detected StdSelect_BRepOwner shape back to session ids via IsSame over
the body's id-ordered subshape lists; unmapped subshapes surface as a
lineage error rather than a guess. setSelection resolves all ids before
touching AIS state (atomic on unknown ids), then AddOrRemoveSelected on
matching owners — highlight appears on the next damage render.
Pixel-diff gtests cover hit/miss/filter/highlight/atomicity.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: Dart bridge growth — TextureTarget, viewer/pick/selection methods, fake + contract + FFI wiring

The additive `KernelBridge` evolution the spec allows: typed viewer methods over the JSON commands from Tasks 3–5, `TextureTarget` alongside `HeadlessTarget`, `CadDocument` able to create texture sessions. Every method lands in the fake AND the contract suite (kickoff rule).

**Files:**
- Modify: `packages/jet_cad/lib/src/kernel/kernel_types.dart`
- Modify: `packages/jet_cad/lib/src/kernel/kernel_bridge.dart`
- Modify: `packages/jet_cad/lib/src/kernel/fake_kernel_bridge.dart`
- Modify: `packages/jet_cad/lib/src/kernel/ffi/ffi_kernel_bridge.dart`
- Modify: `packages/jet_cad/lib/src/kernel/ffi_kernel_bridge_unsupported.dart`
- Modify: `packages/jet_cad/lib/src/document/cad_document.dart`
- Modify: `packages/jet_cad/test/kernel/bridge_contract.dart`
- Modify: `packages/jet_cad/test/kernel/fake_kernel_bridge_test.dart`
- Modify: `packages/jet_cad/test/kernel/kernel_types_test.dart`
- Modify: `packages/jet_cad/test/document/cad_document_test.dart`
- Test: `packages/jet_cad/test/kernel_ffi/ffi_viewport_test.dart` (new)

**Interfaces:**
- Consumes: JSON commands from Tasks 3–5; `FfiWorker` transport (Task 2).
- Produces (Tasks 7–9 rely on these EXACT signatures):

```dart
// kernel_types.dart
final class TextureTarget extends RenderTarget {
  const TextureTarget();
}

enum PickFilter { body, face, edge, vertex }

class PickResult {
  final EntityId entity;
  final BodyId body;
  const PickResult({required this.entity, required this.body});
  // + ==, hashCode, toString, fromJson/toJson
}

// KernelBridge additions (all async, all throw KernelException on a
// headless/unknown session or kernel-side failure):
Future<int> resizeViewport(SessionHandle session, int widthPx, int heightPx, double pixelRatio); // returns IOSurface id
Future<void> renderFrame(SessionHandle session);
Future<void> orbitStart(SessionHandle session, double xPx, double yPx);
Future<void> orbit(SessionHandle session, double xPx, double yPx);
Future<void> pan(SessionHandle session, double dxPx, double dyPx);
Future<void> zoom(SessionHandle session, double factor);
Future<void> fitAll(SessionHandle session);
Future<PickResult?> pick(SessionHandle session, double xPx, double yPx, PickFilter filter);
Future<void> setSelection(SessionHandle session, List<EntityId> ids);
```

  - Coordinate contract: all bridge viewer coordinates are PHYSICAL pixels, origin top-left. Logical→physical conversion (×devicePixelRatio) is the `ViewportController`'s job (Task 8), not the bridge's.
  - `FfiKernelBridge.createSession(TextureTarget())` → `jc_create_session` + `initViewer` at a placeholder 32×32/1.0 (real dimensions arrive with the first `resizeViewport`, which callers must issue before the first render — the controller always does).
  - `FakeKernelBridge` observability for widget tests (Task 8 relies on these):
    - `int renderFrameCount` — total renderFrame calls.
    - `List<String> cameraLog` — entries like `'orbitStart 10.0 20.0'`, `'orbit 12.0 22.0'`, `'pan 5.0 -3.0'`, `'zoom 1.1'`, `'fitAll'`.
    - `List<(int, int, double)> viewportSizes` — every resizeViewport call.
    - `PickResult? nextPickResult` — returned by `pick` when the session has bodies; `pick` returns null when the session has no bodies (mirrors empty-scene contract) or when unset.
    - `List<List<String>> selectionLog` — every setSelection ids list (as raw strings).
  - Fake behavior: viewer methods on a `HeadlessTarget` session throw `KernelException('viewer not initialized')`; `resizeViewport` returns a fresh surface id (monotonic counter) per call; `setSelection` validates every id exists in the session (atomic — throws before recording anything).
  - `CadDocument` changes:
    - `static Future<CadDocument> create(KernelBridge bridge, {RenderTarget target = const HeadlessTarget()})`
    - `static Future<CadDocument> load(Map<String, Object?> json, KernelBridge bridge, {RenderTarget target = const HeadlessTarget()})`
    - `SessionHandle get session` and `KernelBridge get bridge` — doc-commented "for viewport wiring; commands that mutate geometry must keep flowing through the document".

- [ ] **Step 1: Write the failing type + contract + fake tests**

Append to `packages/jet_cad/test/kernel/kernel_types_test.dart`:

```dart
  test('PickResult JSON round-trips and equates', () {
    const result = PickResult(entity: EntityId('f3'), body: BodyId('b1'));
    final restored = PickResult.fromJson(result.toJson());
    expect(restored, result);
    expect(restored.hashCode, result.hashCode);
    expect(restored.entity, const EntityId('f3'));
    expect(restored.body, const BodyId('b1'));
  });

  test('TextureTarget is a RenderTarget', () {
    expect(const TextureTarget(), isA<RenderTarget>());
  });
```

Append to `runKernelBridgeContract` in `packages/jet_cad/test/kernel/bridge_contract.dart` (note: the existing `setUp` creates a headless session; these cases create their own texture session and dispose it):

```dart
  test('contract: viewer methods on a headless session throw', () async {
    await expectLater(bridge.renderFrame(session), throwsA(isA<KernelException>()));
    await expectLater(bridge.fitAll(session), throwsA(isA<KernelException>()));
    await expectLater(bridge.resizeViewport(session, 64, 64, 1.0),
        throwsA(isA<KernelException>()));
    await expectLater(bridge.orbitStart(session, 0, 0), throwsA(isA<KernelException>()));
    await expectLater(bridge.pan(session, 1, 1), throwsA(isA<KernelException>()));
    await expectLater(bridge.zoom(session, 2), throwsA(isA<KernelException>()));
    await expectLater(bridge.pick(session, 0, 0, PickFilter.body),
        throwsA(isA<KernelException>()));
    await expectLater(bridge.setSelection(session, const []),
        throwsA(isA<KernelException>()));
  });

  test('contract: texture session renders, resizes, and picks empty scene',
      () async {
    final s = await bridge.createSession(const TextureTarget());
    try {
      final surfaceId = await bridge.resizeViewport(s, 128, 128, 1.0);
      expect(surfaceId, greaterThan(0));
      await bridge.renderFrame(s);
      final resized = await bridge.resizeViewport(s, 256, 128, 2.0);
      expect(resized, isNot(surfaceId),
          reason: 'resize reallocates the surface');
      await bridge.renderFrame(s);
      expect(await bridge.pick(s, 64, 64, PickFilter.body), isNull,
          reason: 'empty scene picks nothing');
    } finally {
      await bridge.disposeSession(s);
    }
  });

  test('contract: camera commands accept a fitted scene', () async {
    final s = await bridge.createSession(const TextureTarget());
    try {
      await bridge.resizeViewport(s, 128, 128, 1.0);
      await bridge.makeBox(s, const Vec3(10, 10, 10));
      await bridge.fitAll(s);
      await bridge.orbitStart(s, 64, 64);
      await bridge.orbit(s, 80, 70);
      await bridge.pan(s, 5, -5);
      await bridge.zoom(s, 1.25);
      await bridge.renderFrame(s);
    } finally {
      await bridge.disposeSession(s);
    }
  });

  test('contract: setSelection validates ids atomically', () async {
    final s = await bridge.createSession(const TextureTarget());
    try {
      await bridge.resizeViewport(s, 128, 128, 1.0);
      final box = await bridge.makeBox(s, const Vec3(10, 10, 10));
      await bridge.setSelection(s, [box.body]);
      await bridge.setSelection(s, const []);
      await expectLater(
        bridge.setSelection(s, [box.body, const EntityId('zz-unknown')]),
        throwsA(isA<KernelException>()),
      );
    } finally {
      await bridge.disposeSession(s);
    }
  });
```

Append to `packages/jet_cad/test/kernel/fake_kernel_bridge_test.dart`:

```dart
  test('fake exposes viewer observability for widget tests', () async {
    final fake = FakeKernelBridge();
    final s = await fake.createSession(const TextureTarget());
    await fake.resizeViewport(s, 100, 50, 2.0);
    await fake.renderFrame(s);
    await fake.orbitStart(s, 1, 2);
    await fake.orbit(s, 3, 4);
    await fake.fitAll(s);
    expect(fake.renderFrameCount, 1);
    expect(fake.viewportSizes, [(100, 50, 2.0)]);
    expect(fake.cameraLog,
        ['orbitStart 1.0 2.0', 'orbit 3.0 4.0', 'fitAll']);

    expect(await fake.pick(s, 5, 5, PickFilter.body), isNull,
        reason: 'no bodies yet');
    final box = await fake.makeBox(s, const Vec3(1, 1, 1));
    fake.nextPickResult = PickResult(entity: box.body, body: box.body);
    final hit = await fake.pick(s, 5, 5, PickFilter.body);
    expect(hit?.body, box.body);

    await fake.setSelection(s, [box.body]);
    expect(fake.selectionLog.last, [box.body.value]);
    await fake.disposeSession(s);
  });
```

(If `BodyId`/`EntityId` expose their raw string differently than `.value`, match the actual accessor from `entity.dart`.)

Run: `cd packages/jet_cad && flutter test test/kernel`
Expected: FAIL — types/methods undefined.

- [ ] **Step 2: Add the types**

`packages/jet_cad/lib/src/kernel/kernel_types.dart`:

```dart
/// Render target for sessions that composite into a platform texture.
///
/// Dimensions are not part of the target: the first
/// [KernelBridge.resizeViewport] call establishes the real surface size
/// (layout is not known at session-creation time).
final class TextureTarget extends RenderTarget {
  const TextureTarget();
}

/// What a [KernelBridge.pick] may hit.
enum PickFilter { body, face, edge, vertex }

/// A successful pick: the picked entity and the body that owns it.
///
/// For [PickFilter.body] picks, [entity] equals [body].
class PickResult {
  final EntityId entity;
  final BodyId body;

  const PickResult({required this.entity, required this.body});

  factory PickResult.fromJson(Map<String, Object?> json) => PickResult(
        entity: EntityId(json['entity']! as String),
        body: BodyId(json['body']! as String),
      );

  Map<String, Object?> toJson() =>
      {'entity': entity.value, 'body': body.value};

  @override
  bool operator ==(Object other) =>
      other is PickResult && other.entity == entity && other.body == body;

  @override
  int get hashCode => Object.hash(entity, body);

  @override
  String toString() => 'PickResult(${entity.value} of ${body.value})';
}
```

(Adapt the `EntityId`/`BodyId` constructors/accessors to `entity.dart`'s actual shape.)

- [ ] **Step 3: Grow the KernelBridge interface**

`packages/jet_cad/lib/src/kernel/kernel_bridge.dart` — append with doc comments; all coordinates physical pixels, origin top-left:

```dart
  /// Resizes the viewport framebuffer to physical [widthPx]×[heightPx] and
  /// records [pixelRatio]. Reallocates the platform surface — returns the NEW
  /// surface id; the compositor-side texture must be re-wrapped after this.
  Future<int> resizeViewport(
      SessionHandle session, int widthPx, int heightPx, double pixelRatio);

  /// Draws one frame into the viewport surface. The only draw trigger —
  /// callers own damage tracking (render after command/camera/selection
  /// changes, never per-vsync).
  Future<void> renderFrame(SessionHandle session);

  /// Anchors an orbit gesture at physical pixel ([xPx], [yPx]).
  Future<void> orbitStart(SessionHandle session, double xPx, double yPx);

  /// Continues the orbit anchored by [orbitStart] to ([xPx], [yPx]).
  Future<void> orbit(SessionHandle session, double xPx, double yPx);

  /// Pans the camera by ([dxPx], [dyPx]) physical pixels (+y = down).
  Future<void> pan(SessionHandle session, double dxPx, double dyPx);

  /// Scales the view by [factor] (> 1 zooms in). Throws on factor <= 0.
  Future<void> zoom(SessionHandle session, double factor);

  /// Frames all displayed bodies.
  Future<void> fitAll(SessionHandle session);

  /// Picks the topmost entity matching [filter] at ([xPx], [yPx]).
  /// Returns null when nothing is hit.
  Future<PickResult?> pick(
      SessionHandle session, double xPx, double yPx, PickFilter filter);

  /// Replaces the highlighted selection (empty list clears). Atomic: an
  /// unknown id throws and leaves the previous selection untouched.
  /// Selection is view state — never part of the document or undo.
  Future<void> setSelection(SessionHandle session, List<EntityId> ids);
```

- [ ] **Step 4: Implement the fake**

`packages/jet_cad/lib/src/kernel/fake_kernel_bridge.dart` — new state + methods (follow the file's existing `_requireSession` helper conventions):

```dart
  /// Viewer observability for widget/controller tests.
  int renderFrameCount = 0;
  final List<String> cameraLog = [];
  final List<(int, int, double)> viewportSizes = [];
  final List<List<String>> selectionLog = [];

  /// Returned by [pick] when the session has bodies. Tests set this to
  /// script hits; null means "miss".
  PickResult? nextPickResult;

  final Set<int> _textureSessions = {};
  int _surfaceCounter = 0;
```

`createSession` records texture sessions:

```dart
    if (target is TextureTarget) {
      _textureSessions.add(handle.value);
    }
```

(and `disposeSession` removes from `_textureSessions`.) Viewer methods:

```dart
  void _requireViewer(SessionHandle session) {
    _requireSession(session);
    if (!_textureSessions.contains(session.value)) {
      throw const KernelException('viewer not initialized');
    }
  }

  @override
  Future<int> resizeViewport(SessionHandle session, int widthPx, int heightPx,
      double pixelRatio) async {
    _requireViewer(session);
    if (widthPx <= 0 || heightPx <= 0) {
      throw const KernelException('viewport size must be positive');
    }
    viewportSizes.add((widthPx, heightPx, pixelRatio));
    return ++_surfaceCounter;
  }

  @override
  Future<void> renderFrame(SessionHandle session) async {
    _requireViewer(session);
    renderFrameCount++;
  }

  @override
  Future<void> orbitStart(SessionHandle session, double xPx, double yPx) async {
    _requireViewer(session);
    cameraLog.add('orbitStart $xPx $yPx');
  }

  @override
  Future<void> orbit(SessionHandle session, double xPx, double yPx) async {
    _requireViewer(session);
    cameraLog.add('orbit $xPx $yPx');
  }

  @override
  Future<void> pan(SessionHandle session, double dxPx, double dyPx) async {
    _requireViewer(session);
    cameraLog.add('pan $dxPx $dyPx');
  }

  @override
  Future<void> zoom(SessionHandle session, double factor) async {
    _requireViewer(session);
    if (factor <= 0) {
      throw const KernelException('zoom factor must be positive');
    }
    cameraLog.add('zoom $factor');
  }

  @override
  Future<void> fitAll(SessionHandle session) async {
    _requireViewer(session);
    cameraLog.add('fitAll');
  }

  @override
  Future<PickResult?> pick(SessionHandle session, double xPx, double yPx,
      PickFilter filter) async {
    _requireViewer(session);
    if (_sessions[session.value]!.isEmpty) return null;
    return nextPickResult;
  }

  @override
  Future<void> setSelection(SessionHandle session, List<EntityId> ids) async {
    _requireViewer(session);
    final bodies = _sessions[session.value]!;
    for (final id in ids) {
      final known = bodies.containsKey(id.value) ||
          bodies.values.any((b) => b.subshapes.contains(id.value));
      if (!known) {
        throw KernelException('unknown entity id: ${id.value}');
      }
    }
    selectionLog.add([for (final id in ids) id.value]);
  }
```

(Match `_sessions`/`_FakeBody.subshapes` access to the file's actual internals.)

- [ ] **Step 5: Wire the FFI bridge + stub**

`packages/jet_cad/lib/src/kernel/ffi/ffi_kernel_bridge.dart`:

```dart
  @override
  Future<SessionHandle> createSession(RenderTarget target) async {
    final worker = await _worker();
    final handle = await worker.request('createSession', 0, null) as int;
    final session = SessionHandle(handle);
    if (target is TextureTarget) {
      // Real dimensions arrive with the first resizeViewport (layout-time);
      // 32x32 placeholder keeps initViewer's size check honest.
      await _run(session, {
        'cmd': 'initViewer',
        'width': 32,
        'height': 32,
        'pixelRatio': 1.0,
      });
    }
    return session;
  }

  @override
  Future<int> resizeViewport(SessionHandle session, int widthPx, int heightPx,
      double pixelRatio) async {
    final result = await _run(session, {
      'cmd': 'resizeViewport',
      'width': widthPx,
      'height': heightPx,
      'pixelRatio': pixelRatio,
    });
    return (result as Map)['surfaceId'] as int;
  }

  @override
  Future<void> renderFrame(SessionHandle session) =>
      _runVoid(session, {'cmd': 'renderFrame'});

  @override
  Future<void> orbitStart(SessionHandle session, double xPx, double yPx) =>
      _runVoid(session, {'cmd': 'cameraOrbitStart', 'x': xPx, 'y': yPx});

  @override
  Future<void> orbit(SessionHandle session, double xPx, double yPx) =>
      _runVoid(session, {'cmd': 'cameraOrbit', 'x': xPx, 'y': yPx});

  @override
  Future<void> pan(SessionHandle session, double dxPx, double dyPx) =>
      _runVoid(session, {'cmd': 'cameraPan', 'dx': dxPx, 'dy': dyPx});

  @override
  Future<void> zoom(SessionHandle session, double factor) =>
      _runVoid(session, {'cmd': 'cameraZoom', 'factor': factor});

  @override
  Future<void> fitAll(SessionHandle session) =>
      _runVoid(session, {'cmd': 'cameraFit'});

  @override
  Future<PickResult?> pick(SessionHandle session, double xPx, double yPx,
      PickFilter filter) async {
    final result = await _run(session, {
      'cmd': 'pick',
      'x': xPx,
      'y': yPx,
      'filter': filter.name,
    });
    final hit = (result as Map)['hit'];
    if (hit == null) return null;
    return PickResult.fromJson((hit as Map).cast<String, Object?>());
  }

  @override
  Future<void> setSelection(SessionHandle session, List<EntityId> ids) =>
      _runVoid(session, {
        'cmd': 'setSelection',
        'ids': [for (final id in ids) id.value],
      });
```

Add a tiny `Future<void> _runVoid(...)` helper (awaits `_run`, discards result) if the file doesn't already have one. `ffi_kernel_bridge_unsupported.dart`: add all nine methods, each `=> _unsupported();` with matching signatures.

- [ ] **Step 6: CadDocument target + getters**

`packages/jet_cad/lib/src/document/cad_document.dart`:

```dart
  static Future<CadDocument> create(KernelBridge bridge,
      {RenderTarget target = const HeadlessTarget()}) async {
    final session = await bridge.createSession(target);
    ...
```

same optional `target` on `load` (both replace the hardcoded `const HeadlessTarget()` argument), plus:

```dart
  /// The kernel session this document owns. For viewport wiring
  /// (camera/pick/selection); geometry mutations must keep flowing through
  /// the document's own methods so the op log stays authoritative.
  SessionHandle get session => _session;

  /// The bridge this document talks to. Same caveat as [session].
  KernelBridge get bridge => _bridge;
```

Append to `packages/jet_cad/test/document/cad_document_test.dart`:

```dart
  test('create passes the render target through to the bridge', () async {
    final fake = FakeKernelBridge();
    final doc = await CadDocument.create(fake, target: const TextureTarget());
    await fake.renderFrame(doc.session);
    expect(fake.renderFrameCount, 1,
        reason: 'session must be a texture session');
    expect(doc.bridge, same(fake));
    doc.dispose();
  });
```

- [ ] **Step 7: Real-kernel viewport integration tests**

`packages/jet_cad/test/kernel_ffi/ffi_viewport_test.dart` (guarded like every FFI file):

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad/jet_cad.dart';

void main() {
  final libPath = FfiKernelBridge.locateLibrary();
  if (libPath == null) {
    test('SKIPPED: native library not built (tool/build_native.sh)', () {
      markTestSkipped('native library not built');
    });
    return;
  }

  late FfiKernelBridge bridge;
  late SessionHandle session;

  setUp(() async {
    bridge = FfiKernelBridge(libPath);
    session = await bridge.createSession(const TextureTarget());
    await bridge.resizeViewport(session, 128, 128, 1.0);
  });

  tearDown(() async {
    await bridge.disposeSession(session);
    await bridge.shutdown();
  });

  Future<List<int>> centerPixel() async {
    final result = await bridge.debugExecute(session, {
      'cmd': 'debugReadPixels',
      'x': 64,
      'y': 64,
      'width': 1,
      'height': 1,
    });
    return base64Decode(result['rgbaBase64'] as String);
  }

  test('fitted box covers the view center', () async {
    await bridge.renderFrame(session);
    final background = await centerPixel();
    await bridge.makeBox(session, const Vec3(50, 50, 50));
    await bridge.fitAll(session);
    await bridge.renderFrame(session);
    expect(await centerPixel(), isNot(background));
  });

  test('pick at center hits the box body and one of its faces', () async {
    final box = await bridge.makeBox(session, const Vec3(50, 50, 50));
    await bridge.fitAll(session);
    await bridge.renderFrame(session);
    final bodyHit = await bridge.pick(session, 64, 64, PickFilter.body);
    expect(bodyHit?.body, box.body);
    expect(bodyHit?.entity, box.body);
    final faceHit = await bridge.pick(session, 64, 64, PickFilter.face);
    expect(faceHit?.body, box.body);
    expect(box.faces, contains(faceHit?.entity));
  });

  test('selection highlight changes rendered pixels', () async {
    final box = await bridge.makeBox(session, const Vec3(50, 50, 50));
    await bridge.fitAll(session);
    await bridge.renderFrame(session);
    final before = await centerPixel();
    await bridge.setSelection(session, [box.body]);
    await bridge.renderFrame(session);
    expect(await centerPixel(), isNot(before),
        reason: 'highlight must be visible at the box center');
  });
}
```

(If `EntityId`/`FaceId` comparisons need unwrapping for `contains`, adapt to the id types' equality from `entity.dart`.)

- [ ] **Step 8: Run everything**

```bash
cd packages/jet_cad && flutter analyze && flutter test && dart format lib test
cd packages/jet_cad && mv build/native build/native.bak && flutter test && mv build/native.bak build/native
```

Expected: analyze clean; full suite green with lib (contract cases now run the viewer path against BOTH bridges); guarded skips + green without lib; format no diff.

- [ ] **Step 9: Commit**

```bash
git add packages/jet_cad/lib packages/jet_cad/test
git commit -m "feat: typed viewer/pick/selection bridge API with TextureTarget

KernelBridge grows resizeViewport/renderFrame/orbitStart/orbit/pan/
zoom/fitAll/pick/setSelection (additive; interface not frozen). All
coordinates are physical pixels, origin top-left — logical conversion
is the controller's job. TextureTarget joins the sealed RenderTarget;
FFI createSession runs initViewer at a 32x32 placeholder until the
first layout-driven resizeViewport. FakeKernelBridge implements every
method with widget-test observability (renderFrameCount, cameraLog,
viewportSizes, selectionLog, scriptable nextPickResult); contract suite
covers headless-rejection, resize surface reallocation, empty-scene
pick, camera acceptance and atomic setSelection against both bridges.
CadDocument.create/load take a RenderTarget and expose session/bridge
for viewport wiring.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: TextureBinding channel wrapper + macOS plugin hardening

Dart-side wrapper over the `jet_cad/texture` MethodChannel (instance methods so tests and the controller can fake it), plus plugin cleanup: the toy `plugin_ffi` C scaffold dies on macOS, the Swift plugin gets doc comments and defensive lifecycle behavior. The Swift plugin from Task 1 already implements all four methods — this task pins its behavior from the Dart side and removes the scaffold debris.

**Files:**
- Create: `packages/jet_cad/lib/src/viewport/texture_binding.dart`
- Delete: `packages/jet_cad/macos/Classes/jet_cad.c` (toy `#include "../../src/jet_cad.c"` forwarder; linux/windows keep their toy scaffold untouched until their plans)
- Modify: `packages/jet_cad/macos/Classes/JetCadPlugin.swift` (doc comments; verify guard-path completeness)
- Test: `packages/jet_cad/test/viewport/texture_binding_test.dart` (new)

**Interfaces:**
- Consumes: MethodChannel contract from Task 1 (`registerTexture`/`updateSurface`/`frameReady`/`unregisterTexture`).
- Produces (Task 8 consumes):

```dart
/// Talks to the platform texture registry over the jet_cad/texture channel.
/// Instance-based so tests and controllers can substitute a fake.
class TextureBinding {
  const TextureBinding();
  Future<int> registerTexture(int surfaceId);
  Future<void> updateSurface(int textureId, int surfaceId);
  Future<void> frameReady(int textureId);
  Future<void> unregisterTexture(int textureId);
}
```

- Errors: platform-side failures arrive as `PlatformException` and are NOT swallowed here — the controller decides. A null result from `registerTexture` throws `StateError` (protocol violation).
- NOT exported from `jet_cad.dart` — internal plumbing; the public surface is the widget + controller (Task 8).

- [ ] **Step 1: Write the failing binding tests**

`packages/jet_cad/test/viewport/texture_binding_test.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad/src/viewport/texture_binding.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('jet_cad/texture');
  final calls = <MethodCall>[];
  Object? Function(MethodCall call)? handler;

  setUp(() {
    calls.clear();
    handler = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return handler?.call(call);
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('registerTexture sends surfaceId and returns textureId', () async {
    handler = (_) => 42;
    const binding = TextureBinding();
    expect(await binding.registerTexture(7), 42);
    expect(calls.single.method, 'registerTexture');
    expect(calls.single.arguments, {'surfaceId': 7});
  });

  test('registerTexture throws StateError on null result', () async {
    const binding = TextureBinding();
    await expectLater(binding.registerTexture(7), throwsStateError);
  });

  test('updateSurface, frameReady, unregisterTexture send exact payloads',
      () async {
    const binding = TextureBinding();
    await binding.updateSurface(42, 9);
    await binding.frameReady(42);
    await binding.unregisterTexture(42);
    expect(calls.map((c) => c.method).toList(),
        ['updateSurface', 'frameReady', 'unregisterTexture']);
    expect(calls[0].arguments, {'textureId': 42, 'surfaceId': 9});
    expect(calls[1].arguments, {'textureId': 42});
    expect(calls[2].arguments, {'textureId': 42});
  });

  test('PlatformException propagates untouched', () async {
    handler = (_) => throw PlatformException(code: 'surfaceNotFound');
    const binding = TextureBinding();
    await expectLater(
      binding.registerTexture(999),
      throwsA(isA<PlatformException>()
          .having((e) => e.code, 'code', 'surfaceNotFound')),
    );
  });
}
```

Run: `cd packages/jet_cad && flutter test test/viewport`
Expected: FAIL — file does not exist.

- [ ] **Step 2: Implement TextureBinding**

`packages/jet_cad/lib/src/viewport/texture_binding.dart`:

```dart
import 'package:flutter/services.dart';

/// Bridges IOSurface ids from the kernel to Flutter external texture ids via
/// the macOS plugin's `jet_cad/texture` MethodChannel.
///
/// Internal plumbing for [ViewportController]; not exported by the package.
/// Instance-based (const) so tests substitute a subclass fake.
class TextureBinding {
  const TextureBinding();

  static const MethodChannel _channel = MethodChannel('jet_cad/texture');

  /// Wraps the IOSurface [surfaceId] in a CVPixelBuffer and registers it as
  /// a Flutter external texture. Returns the texture id for [Texture].
  Future<int> registerTexture(int surfaceId) async {
    final textureId = await _channel
        .invokeMethod<int>('registerTexture', {'surfaceId': surfaceId});
    if (textureId == null) {
      throw StateError('registerTexture returned null texture id');
    }
    return textureId;
  }

  /// Re-wraps [textureId] onto a new IOSurface after a resize reallocation.
  Future<void> updateSurface(int textureId, int surfaceId) =>
      _channel.invokeMethod<void>('updateSurface',
          {'textureId': textureId, 'surfaceId': surfaceId});

  /// Tells the compositor a new frame is in the surface (damage signal).
  Future<void> frameReady(int textureId) =>
      _channel.invokeMethod<void>('frameReady', {'textureId': textureId});

  /// Unregisters the texture. Safe to call once during dispose; the platform
  /// side treats unknown ids as a no-op.
  Future<void> unregisterTexture(int textureId) =>
      _channel.invokeMethod<void>('unregisterTexture', {'textureId': textureId});
}
```

Run: `cd packages/jet_cad && flutter test test/viewport`
Expected: PASS (4 tests).

- [ ] **Step 3: Delete the macOS toy scaffold + harden the Swift plugin**

```bash
git rm packages/jet_cad/macos/Classes/jet_cad.c
```

Then confirm the harness still builds (the pod now compiles only the Swift plugin; the toy `src/jet_cad.c`/`src/jet_cad.h` stay for linux/windows CMake until those plans):

```bash
packages/jet_cad/tool/run_harness.sh
```

Expected: app builds, box still renders (screenshot check per Task 1 Step 16). If CocoaPods complains about an empty compilation unit or the podspec needs `s.source_files` narrowed to `Classes/**/*.swift`, make that podspec adjustment and record it.

`JetCadPlugin.swift`: add class-level doc comments (channel contract, threading note: `copyPixelBuffer` may be called from the raster thread — hence the `NSLock`), and verify every method guards bad args with a `FlutterError` (added in Task 1; extend if review finds gaps).

- [ ] **Step 4: Full verification + commit**

```bash
cd packages/jet_cad && flutter analyze && flutter test && dart format lib test
cd ../../apps/dev_harness && flutter analyze
```

```bash
git add -A packages/jet_cad/macos packages/jet_cad/lib packages/jet_cad/test
git commit -m "feat: TextureBinding channel wrapper; drop macOS toy scaffold

TextureBinding wraps the jet_cad/texture MethodChannel with instance
methods (const-constructible, fakeable in widget tests): register/
updateSurface/frameReady/unregister. PlatformExceptions propagate to
the caller; a null registerTexture result is a protocol violation
(StateError). Not exported — internal to the viewport layer. The toy
plugin_ffi C forwarder is gone from the macOS pod (Swift plugin only);
linux/windows scaffolds untouched until their plans.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: ViewportController + JetCadViewport widget

The public viewport surface. Controller owns: texture lifecycle (attach → register, resize → debounce → reallocate → re-wrap), damage-driven render coalescing, gesture→camera translation (logical→physical px), pick/selection with its own `SelectionChanged` stream. Widget owns: layout tracking, pointer→gesture mapping, the flipped `Texture`. Everything tests against `FakeKernelBridge` + a fake `TextureBinding` — no native code involved.

**Files:**
- Create: `packages/jet_cad/lib/src/viewport/viewport_controller.dart`
- Create: `packages/jet_cad/lib/src/viewport/jet_cad_viewport.dart`
- Modify: `packages/jet_cad/lib/jet_cad.dart` (exports)
- Modify: `packages/jet_cad/test/public_api_test.dart`
- Test: `packages/jet_cad/test/viewport/fake_binding.dart` (new — shared fake)
- Test: `packages/jet_cad/test/viewport/viewport_controller_test.dart` (new)
- Test: `packages/jet_cad/test/viewport/jet_cad_viewport_test.dart` (new)

**Interfaces:**
- Consumes: `KernelBridge` viewer methods + `CadDocument.session/bridge/changes` (Task 6), `TextureBinding` (Task 7), spike orientation finding (Task 1).
- Produces (public API, exported):

```dart
/// Selection event on ViewportController.selectionChanges.
class SelectionChanged {
  final Set<EntityId> selection;
  const SelectionChanged(this.selection);
}

class ViewportController extends ChangeNotifier {
  ViewportController({required CadDocument document, TextureBinding binding});
  CadDocument get document;
  int? get textureId;               // null until attached; notifyListeners on change
  Set<EntityId> get selection;      // unmodifiable copy
  Stream<SelectionChanged> get selectionChanges;  // broadcast
  void handleLayout(Size logicalSize, double devicePixelRatio); // widget calls every layout
  Future<void> requestRender();     // coalescing damage render
  Future<void> orbitStart(Offset logicalPos);
  Future<void> orbitTo(Offset logicalPos);
  Future<void> panBy(Offset logicalDelta);
  Future<void> zoomBy(double factor);
  Future<void> fitAll();
  Future<void> selectAt(Offset logicalPos, {PickFilter filter = PickFilter.body});
  Future<void> setSelection(Set<EntityId> ids);
  @override void dispose();         // does NOT dispose the document
}

class JetCadViewport extends StatefulWidget {
  const JetCadViewport({super.key, required this.controller});
  final ViewportController controller;
}
```

- Behavioral contract (tests pin all of these):
  - First `handleLayout` attaches: `resizeViewport` (physical px = logical × dpr, rounded) → `registerTexture` → initial `fitAll` + render. Later layout changes debounce 100 ms, then `resizeViewport` → `updateSurface` → render.
  - Every render = `bridge.renderFrame` then `binding.frameReady`. Coalescing: renders requested while one is in flight collapse into a single trailing render.
  - `document.changes` subscription → `requestRender` (damage-driven). No timers except the resize debounce, no tickers.
  - Camera methods convert logical→physical (×dpr) and render after; `selectAt` picks, updates `selection`, calls `bridge.setSelection`, renders, emits `SelectionChanged` (emits even when the selection becomes empty).
  - Gestures (widget): primary-button drag = orbit; secondary-button drag = pan; scroll wheel = zoom (`exp(-scrollDelta.dy / 200)`); primary click without drag (≤ 4 px slop) = `selectAt`.
  - `dispose()`: cancels subscription/timer, `unregisterTexture`, closes the stream. Errors during best-effort teardown are swallowed.
  - Widget shows a background `ColoredBox` until `textureId` is available, then `Transform.flip(flipY: true, child: Texture(...))` (per spike finding).

- [ ] **Step 1: Write the failing controller tests**

`packages/jet_cad/test/viewport/fake_binding.dart` (shared by both viewport test files):

```dart
import 'package:jet_cad/src/viewport/texture_binding.dart';

/// Records channel traffic instead of touching a real platform channel.
class FakeBinding extends TextureBinding {
  FakeBinding();
  final List<String> log = [];
  int nextTextureId = 7;

  @override
  Future<int> registerTexture(int surfaceId) async {
    log.add('register $surfaceId');
    return nextTextureId;
  }

  @override
  Future<void> updateSurface(int textureId, int surfaceId) async {
    log.add('update $textureId $surfaceId');
  }

  @override
  Future<void> frameReady(int textureId) async {
    log.add('frame $textureId');
  }

  @override
  Future<void> unregisterTexture(int textureId) async {
    log.add('unregister $textureId');
  }
}
```

`packages/jet_cad/test/viewport/viewport_controller_test.dart`:

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad/jet_cad.dart';

import 'fake_binding.dart';

void main() {
  late FakeKernelBridge fake;
  late CadDocument doc;
  late FakeBinding binding;
  late ViewportController controller;

  setUp(() async {
    fake = FakeKernelBridge();
    doc = await CadDocument.create(fake, target: const TextureTarget());
    binding = FakeBinding();
    controller = ViewportController(document: doc, binding: binding);
  });

  tearDown(() {
    controller.dispose();
    doc.dispose();
  });

  testWidgets('first layout attaches: resize, register, fit, render',
      (tester) async {
    controller.handleLayout(const Size(200, 100), 2.0);
    await tester.pumpAndSettle();
    expect(fake.viewportSizes, [(400, 200, 2.0)],
        reason: 'physical px = logical × dpr');
    expect(binding.log.first, 'register 1');
    expect(controller.textureId, 7);
    expect(fake.cameraLog, contains('fitAll'));
    expect(fake.renderFrameCount, 1);
    expect(binding.log, contains('frame 7'));
  });

  testWidgets('same-size layouts do not resize again', (tester) async {
    controller.handleLayout(const Size(200, 100), 2.0);
    await tester.pumpAndSettle();
    controller.handleLayout(const Size(200, 100), 2.0);
    await tester.pump(const Duration(milliseconds: 200));
    expect(fake.viewportSizes.length, 1);
  });

  testWidgets('layout changes debounce into one resize + update + render',
      (tester) async {
    controller.handleLayout(const Size(200, 100), 2.0);
    await tester.pumpAndSettle();
    controller.handleLayout(const Size(210, 100), 2.0);
    await tester.pump(const Duration(milliseconds: 30));
    controller.handleLayout(const Size(300, 150), 2.0);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
    expect(fake.viewportSizes, [(400, 200, 2.0), (600, 300, 2.0)],
        reason: 'intermediate 210 width never reaches the bridge');
    expect(binding.log, contains('update 7 2'));
    expect(fake.renderFrameCount, 2);
  });

  testWidgets('document changes trigger damage renders', (tester) async {
    controller.handleLayout(const Size(100, 100), 1.0);
    await tester.pumpAndSettle();
    final before = fake.renderFrameCount;
    await doc.makeBox(const Vec3(1, 1, 1));
    await tester.pumpAndSettle();
    expect(fake.renderFrameCount, greaterThan(before));
  });

  testWidgets('idle time renders nothing (no vsync loop)', (tester) async {
    controller.handleLayout(const Size(100, 100), 1.0);
    await tester.pumpAndSettle();
    final settled = fake.renderFrameCount;
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(fake.renderFrameCount, settled,
        reason: 'damage-driven: no renders without damage');
  });

  testWidgets('concurrent render requests coalesce', (tester) async {
    controller.handleLayout(const Size(100, 100), 1.0);
    await tester.pumpAndSettle();
    final before = fake.renderFrameCount;
    unawaited(controller.requestRender());
    unawaited(controller.requestRender());
    unawaited(controller.requestRender());
    await tester.pumpAndSettle();
    expect(fake.renderFrameCount - before, lessThanOrEqualTo(2),
        reason: 'requests while rendering collapse into one trailing render');
  });

  testWidgets('camera methods convert logical to physical px', (tester) async {
    controller.handleLayout(const Size(200, 100), 2.0);
    await tester.pumpAndSettle();
    await controller.orbitStart(const Offset(10, 20));
    await controller.orbitTo(const Offset(15, 25));
    await controller.panBy(const Offset(5, -3));
    await controller.zoomBy(1.5);
    await tester.pumpAndSettle();
    expect(
        fake.cameraLog,
        containsAllInOrder([
          'orbitStart 20.0 40.0',
          'orbit 30.0 50.0',
          'pan 10.0 -6.0',
          'zoom 1.5',
        ]));
  });

  testWidgets('selectAt picks, highlights, emits SelectionChanged',
      (tester) async {
    controller.handleLayout(const Size(100, 100), 1.0);
    await tester.pumpAndSettle();
    final box = await doc.makeBox(const Vec3(1, 1, 1));
    final bodyId = box.outputs.whereType<BodyId>().first;
    fake.nextPickResult = PickResult(entity: bodyId, body: bodyId);
    final events = <SelectionChanged>[];
    final sub = controller.selectionChanges.listen(events.add);

    await controller.selectAt(const Offset(50, 50));
    await tester.pumpAndSettle();
    expect(controller.selection, {bodyId});
    expect(fake.selectionLog.last, [bodyId.value]);
    expect(events.single.selection, {bodyId});

    fake.nextPickResult = null;
    await controller.selectAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(controller.selection, isEmpty);
    expect(fake.selectionLog.last, isEmpty);
    expect(events.last.selection, isEmpty);
    await sub.cancel();
  });

  testWidgets('dispose unregisters the texture and stops reacting',
      (tester) async {
    controller.handleLayout(const Size(100, 100), 1.0);
    await tester.pumpAndSettle();
    controller.dispose();
    await tester.pumpAndSettle();
    expect(binding.log, contains('unregister 7'));
    final count = fake.renderFrameCount;
    await doc.makeBox(const Vec3(1, 1, 1));
    await tester.pumpAndSettle();
    expect(fake.renderFrameCount, count, reason: 'no renders after dispose');
  });
}
```

(Adjust `box.outputs.whereType<BodyId>().first` to however `CadDocument.makeBox`'s return exposes the created body id — check the document API from Plan 1 and use its real accessor. Re-registering `tearDown`'s double-dispose: `ViewportController.dispose` must be idempotent because the last test disposes manually.)

Run: `cd packages/jet_cad && flutter test test/viewport`
Expected: FAIL — `ViewportController` undefined.

- [ ] **Step 2: Implement the controller**

`packages/jet_cad/lib/src/viewport/viewport_controller.dart`:

```dart
import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../document/cad_document.dart';
import '../document/entity.dart';
import '../kernel/kernel_types.dart';
import 'texture_binding.dart';

/// Emitted on [ViewportController.selectionChanges] whenever the selection
/// set changes. Selection is view state: it never appears in the document's
/// change stream, operation list, or undo history.
class SelectionChanged {
  final Set<EntityId> selection;
  const SelectionChanged(this.selection);
}

/// Drives one viewport for one [CadDocument]: texture lifecycle, camera,
/// pick/selection, and damage-driven rendering.
///
/// Damage model: a frame is drawn only on document changes, camera changes,
/// selection changes, or resize — never per-vsync. [textureId] flips from
/// null once the platform texture is registered ([notifyListeners]).
class ViewportController extends ChangeNotifier {
  ViewportController({
    required this.document,
    TextureBinding binding = const TextureBinding(),
  }) : _binding = binding {
    _docSubscription = document.changes.listen((_) => requestRender());
  }

  static const Duration _resizeDebounce = Duration(milliseconds: 100);

  final CadDocument document;
  final TextureBinding _binding;

  final StreamController<SelectionChanged> _selectionController =
      StreamController.broadcast();
  StreamSubscription<void>? _docSubscription;

  int? _textureId;
  Set<EntityId> _selection = const {};
  Size? _appliedLogicalSize;
  double _dpr = 1.0;
  Size? _pendingLogicalSize;
  double _pendingDpr = 1.0;
  Timer? _resizeTimer;
  bool _attaching = false;
  bool _rendering = false;
  bool _renderQueued = false;
  bool _disposed = false;

  int? get textureId => _textureId;
  Set<EntityId> get selection => Set.unmodifiable(_selection);
  Stream<SelectionChanged> get selectionChanges => _selectionController.stream;

  /// Called by the widget on every layout. First call attaches (register +
  /// fit + render); later size/dpr changes debounce into a reallocation.
  void handleLayout(Size logicalSize, double devicePixelRatio) {
    if (_disposed || logicalSize.isEmpty) return;
    if (_textureId == null) {
      if (_attaching) return;
      _attaching = true;
      unawaited(_attach(logicalSize, devicePixelRatio));
      return;
    }
    if (logicalSize == _appliedLogicalSize && devicePixelRatio == _dpr) {
      return;
    }
    _pendingLogicalSize = logicalSize;
    _pendingDpr = devicePixelRatio;
    _resizeTimer?.cancel();
    _resizeTimer = Timer(_resizeDebounce, () => unawaited(_applyResize()));
  }

  Future<void> _attach(Size logicalSize, double devicePixelRatio) async {
    try {
      _dpr = devicePixelRatio;
      _appliedLogicalSize = logicalSize;
      final surfaceId = await document.bridge.resizeViewport(
        document.session,
        (logicalSize.width * devicePixelRatio).round(),
        (logicalSize.height * devicePixelRatio).round(),
        devicePixelRatio,
      );
      final textureId = await _binding.registerTexture(surfaceId);
      if (_disposed) {
        await _binding.unregisterTexture(textureId);
        return;
      }
      _textureId = textureId;
      await document.bridge.fitAll(document.session);
      await requestRender();
      notifyListeners();
    } finally {
      _attaching = false;
    }
  }

  Future<void> _applyResize() async {
    final logicalSize = _pendingLogicalSize;
    final textureId = _textureId;
    if (_disposed || logicalSize == null || textureId == null) return;
    _appliedLogicalSize = logicalSize;
    _dpr = _pendingDpr;
    final surfaceId = await document.bridge.resizeViewport(
      document.session,
      (logicalSize.width * _dpr).round(),
      (logicalSize.height * _dpr).round(),
      _dpr,
    );
    if (_disposed) return;
    await _binding.updateSurface(textureId, surfaceId);
    await requestRender();
  }

  /// Renders one frame and signals the compositor. Coalescing: calls that
  /// arrive while a render is in flight fold into a single trailing render.
  Future<void> requestRender() async {
    if (_disposed || _textureId == null) return;
    if (_rendering) {
      _renderQueued = true;
      return;
    }
    _rendering = true;
    try {
      do {
        _renderQueued = false;
        await document.bridge.renderFrame(document.session);
        final textureId = _textureId;
        if (textureId != null) {
          await _binding.frameReady(textureId);
        }
      } while (_renderQueued && !_disposed);
    } finally {
      _rendering = false;
    }
  }

  Offset _physical(Offset logical) => logical * _dpr;

  Future<void> orbitStart(Offset logicalPos) async {
    if (_disposed) return;
    final p = _physical(logicalPos);
    await document.bridge.orbitStart(document.session, p.dx, p.dy);
  }

  Future<void> orbitTo(Offset logicalPos) async {
    if (_disposed) return;
    final p = _physical(logicalPos);
    await document.bridge.orbit(document.session, p.dx, p.dy);
    await requestRender();
  }

  Future<void> panBy(Offset logicalDelta) async {
    if (_disposed) return;
    final d = _physical(logicalDelta);
    await document.bridge.pan(document.session, d.dx, d.dy);
    await requestRender();
  }

  Future<void> zoomBy(double factor) async {
    if (_disposed) return;
    await document.bridge.zoom(document.session, factor);
    await requestRender();
  }

  Future<void> fitAll() async {
    if (_disposed) return;
    await document.bridge.fitAll(document.session);
    await requestRender();
  }

  /// Picks at [logicalPos]; a hit selects that entity, a miss clears the
  /// selection. Emits [SelectionChanged] on every call (CAD idiom: clicking
  /// empty space deselects, and listeners want to know).
  Future<void> selectAt(Offset logicalPos,
      {PickFilter filter = PickFilter.body}) async {
    if (_disposed) return;
    final p = _physical(logicalPos);
    final hit =
        await document.bridge.pick(document.session, p.dx, p.dy, filter);
    await setSelection({if (hit != null) hit.entity});
  }

  /// Replaces the selection and highlights it. Selection never touches the
  /// document: no DocChange, no undo entry.
  Future<void> setSelection(Set<EntityId> ids) async {
    if (_disposed) return;
    _selection = Set.of(ids);
    await document.bridge
        .setSelection(document.session, _selection.toList());
    await requestRender();
    _selectionController.add(SelectionChanged(selection));
  }

  /// Releases viewport resources. The document is NOT disposed — the caller
  /// owns it. Idempotent.
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _resizeTimer?.cancel();
    _docSubscription?.cancel();
    _docSubscription = null;
    final textureId = _textureId;
    _textureId = null;
    if (textureId != null) {
      // Best-effort platform cleanup; failures have nowhere to go.
      unawaited(_binding
          .unregisterTexture(textureId)
          .catchError((Object _) {}));
    }
    _selectionController.close();
    super.dispose();
  }
}
```

Run: `cd packages/jet_cad && flutter test test/viewport/viewport_controller_test.dart`
Expected: PASS (10 tests).

- [ ] **Step 3: Write the failing widget tests**

`packages/jet_cad/test/viewport/jet_cad_viewport_test.dart` (imports the shared `FakeBinding` from Step 1):

```dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad/jet_cad.dart';

import 'fake_binding.dart';

void main() {
  late FakeKernelBridge fake;
  late CadDocument doc;
  late FakeBinding binding;
  late ViewportController controller;

  setUp(() async {
    fake = FakeKernelBridge();
    doc = await CadDocument.create(fake, target: const TextureTarget());
    binding = FakeBinding();
    controller = ViewportController(document: doc, binding: binding);
  });

  tearDown(() {
    controller.dispose();
    doc.dispose();
  });

  Future<void> pumpViewport(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 1.0),
          // Center gives the SizedBox loose constraints — without it the
          // box is forced to the test screen size and the layout assertion
          // would see 800x600 instead of 400x300.
          child: Center(
            child: SizedBox(
              width: 400,
              height: 300,
              child: JetCadViewport(controller: controller),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows placeholder, then the flipped texture', (tester) async {
    await pumpViewport(tester);
    expect(controller.textureId, isNotNull);
    final texture = tester.widget<Texture>(find.byType(Texture));
    expect(texture.textureId, controller.textureId);
    expect(
      find.ancestor(of: find.byType(Texture), matching: find.byType(Transform)),
      findsWidgets,
      reason: 'GL rows are bottom-up — texture renders inside a flip',
    );
  });

  testWidgets('layout attach used the widget size', (tester) async {
    await pumpViewport(tester);
    // MediaQuery pins dpr to 1.0, so physical == logical.
    expect(fake.viewportSizes.single, (400, 300, 1.0));
  });

  testWidgets('primary drag orbits', (tester) async {
    await pumpViewport(tester);
    final before = fake.renderFrameCount;
    final gesture = await tester.startGesture(
        tester.getCenter(find.byType(JetCadViewport)),
        kind: PointerDeviceKind.mouse);
    await gesture.moveBy(const Offset(30, 10));
    await gesture.moveBy(const Offset(30, 10));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(fake.cameraLog.where((e) => e.startsWith('orbitStart')), isNotEmpty);
    expect(fake.cameraLog.where((e) => e.startsWith('orbit ')), isNotEmpty);
    expect(fake.renderFrameCount, greaterThan(before));
    expect(fake.selectionLog, isEmpty, reason: 'a drag is not a click');
  });

  testWidgets('secondary drag pans', (tester) async {
    await pumpViewport(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(JetCadViewport)),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.moveBy(const Offset(25, -5));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(fake.cameraLog.where((e) => e.startsWith('pan')), isNotEmpty);
  });

  testWidgets('scroll wheel zooms', (tester) async {
    await pumpViewport(tester);
    final center = tester.getCenter(find.byType(JetCadViewport));
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(center));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -120)));
    await tester.pumpAndSettle();
    expect(fake.cameraLog.where((e) => e.startsWith('zoom')), isNotEmpty);
  });

  testWidgets('click without drag selects', (tester) async {
    await pumpViewport(tester);
    final box = await doc.makeBox(const Vec3(1, 1, 1));
    final bodyId = box.outputs.whereType<BodyId>().first;
    fake.nextPickResult = PickResult(entity: bodyId, body: bodyId);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(JetCadViewport));
    await tester.pumpAndSettle();
    expect(controller.selection, {bodyId});
    expect(fake.selectionLog.last, [bodyId.value]);
  });

  testWidgets('idle frames trigger no renders', (tester) async {
    await pumpViewport(tester);
    final settled = fake.renderFrameCount;
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(fake.renderFrameCount, settled);
  });
}
```

(Same `outputs.whereType<BodyId>()` adjustment as the controller tests.)

Run: expected FAIL — `JetCadViewport` undefined.

- [ ] **Step 4: Implement the widget**

`packages/jet_cad/lib/src/viewport/jet_cad_viewport.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'viewport_controller.dart';

/// Composites the OCCT-rendered texture and translates pointer input into
/// [ViewportController] camera/selection calls.
///
/// Navigation (desktop CAD defaults, v1): primary drag orbits, secondary
/// drag pans, scroll wheel zooms, primary click (≤ 4 px slop) picks.
/// No toolbars, no styling opinions — hosts build their own UI around it.
class JetCadViewport extends StatefulWidget {
  const JetCadViewport({super.key, required this.controller});

  final ViewportController controller;

  @override
  State<JetCadViewport> createState() => _JetCadViewportState();
}

class _JetCadViewportState extends State<JetCadViewport> {
  static const double _tapSlop = 4.0;
  static const double _zoomPerScrollUnit = 200.0;

  Offset? _downPosition;
  int _downButtons = 0;
  Offset _lastPosition = Offset.zero;
  bool _dragging = false;

  void _onPointerDown(PointerDownEvent event) {
    _downPosition = event.localPosition;
    _downButtons = event.buttons;
    _lastPosition = event.localPosition;
    _dragging = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    final down = _downPosition;
    if (down == null) return;
    if (!_dragging) {
      if ((event.localPosition - down).distance <= _tapSlop) return;
      _dragging = true;
      if (_downButtons & kPrimaryMouseButton != 0) {
        widget.controller.orbitStart(down);
      }
    }
    if (_downButtons & kPrimaryMouseButton != 0) {
      widget.controller.orbitTo(event.localPosition);
    } else if (_downButtons & kSecondaryMouseButton != 0) {
      widget.controller.panBy(event.localPosition - _lastPosition);
    }
    _lastPosition = event.localPosition;
  }

  void _onPointerUp(PointerUpEvent event) {
    final down = _downPosition;
    _downPosition = null;
    if (down == null || _dragging) return;
    if (_downButtons & kPrimaryMouseButton != 0) {
      widget.controller.selectAt(event.localPosition);
    }
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      widget.controller
          .zoomBy(math.exp(-event.scrollDelta.dy / _zoomPerScrollUnit));
    }
  }

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        widget.controller
            .handleLayout(constraints.biggest, devicePixelRatio);
        return Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerSignal: _onPointerSignal,
          behavior: HitTestBehavior.opaque,
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) {
              final textureId = widget.controller.textureId;
              if (textureId == null) {
                return const ColoredBox(color: Color(0xFF1E1E24));
              }
              // GL framebuffer rows are bottom-up (spike finding) — flip so
              // the scene's up is the screen's up.
              return Transform.flip(
                flipY: true,
                child: Texture(textureId: textureId),
              );
            },
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 5: Export the public surface**

`packages/jet_cad/lib/jet_cad.dart`:

```dart
export 'src/viewport/jet_cad_viewport.dart' show JetCadViewport;
export 'src/viewport/viewport_controller.dart'
    show SelectionChanged, ViewportController;
```

Append to `packages/jet_cad/test/public_api_test.dart` (match its existing assertion style):

```dart
  // Viewport surface (Plan 3): widget + controller + selection event only —
  // TextureBinding stays internal.
  expect(JetCadViewport, isNotNull);
  expect(ViewportController, isNotNull);
  expect(SelectionChanged, isNotNull);
```

- [ ] **Step 6: Run everything**

```bash
cd packages/jet_cad && flutter analyze && flutter test && dart format lib test
cd packages/jet_cad && mv build/native build/native.bak && flutter test && mv build/native.bak build/native
```

Expected: analyze clean; full suite green in both states; format no diff.

- [ ] **Step 7: Commit**

```bash
git add packages/jet_cad/lib packages/jet_cad/test
git commit -m "feat: JetCadViewport widget and ViewportController

ViewportController owns the texture lifecycle (layout-driven attach,
100ms-debounced resize with surface re-wrap), coalescing damage renders
(document changes / camera / selection / resize — no vsync loop, no
tickers), logical→physical coordinate conversion, and pick/selection
with its own SelectionChanged broadcast stream (selection never touches
the document or undo, per spec). JetCadViewport maps primary drag to
orbit, secondary drag to pan, scroll to zoom, slop-bounded click to
pick, and composites the texture behind a flipY transform (GL rows are
bottom-up, spike finding). Widget/controller tests run entirely on
FakeKernelBridge + a fake TextureBinding.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 9: Real dev harness, end-to-end manual verification, polish

The harness graduates from spike debris to a minimal public-API-only exerciser; the branch gets its docs, version bump, and a full-DoD sweep. This is also where a human confirms interactively what pixel tests cannot: gesture feel, resize crispness, highlight visibility.

**Files:**
- Modify: `apps/dev_harness/lib/main.dart` (public API only — no `debugExecute`, no raw channel)
- Modify: `packages/jet_cad/README.md` (viewport quickstart)
- Modify: `packages/jet_cad/CHANGELOG.md` + `packages/jet_cad/pubspec.yaml` (0.3.0)
- Audit: no spike leftovers, no TODOs

**Interfaces:**
- Consumes: the full Task 6–8 public API (`CadDocument`, `TextureTarget`, `JetCadViewport`, `ViewportController`, `SelectionChanged`).
- Produces: nothing new — this task ends the plan.

- [ ] **Step 1: Rewrite the harness against the public API only**

`apps/dev_harness/lib/main.dart` (complete replacement):

```dart
import 'package:flutter/material.dart';
import 'package:jet_cad/jet_cad.dart';

/// Dev harness: manual verification of the jet_cad viewport.
/// Public package API only — if something here needs an import from
/// package:jet_cad/src/..., the package surface is wrong.
void main() {
  runApp(const MaterialApp(home: HarnessPage()));
}

class HarnessPage extends StatefulWidget {
  const HarnessPage({super.key});

  @override
  State<HarnessPage> createState() => _HarnessPageState();
}

class _HarnessPageState extends State<HarnessPage> {
  CadDocument? _doc;
  ViewportController? _controller;
  String _status = 'starting…';
  Set<EntityId> _selection = const {};

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final libPath = FfiKernelBridge.locateLibrary();
      if (libPath == null) {
        setState(() => _status =
            'native lib not found — run packages/jet_cad/tool/run_harness.sh');
        return;
      }
      final bridge = FfiKernelBridge(libPath);
      final doc =
          await CadDocument.create(bridge, target: const TextureTarget());
      final controller = ViewportController(document: doc);
      controller.selectionChanges
          .listen((event) => setState(() => _selection = event.selection));
      setState(() {
        _doc = doc;
        _controller = controller;
        _status = 'ready';
      });
    } catch (e) {
      setState(() => _status = 'FAILED: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _doc?.dispose();
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
      setState(() => _status = 'ready');
    } catch (e) {
      setState(() => _status = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    final controller = _controller;
    final selection = _selection.map((e) => e.value).join(', ');
    return Scaffold(
      appBar: AppBar(title: Text('jet_cad harness — $_status')),
      body: doc == null || controller == null
          ? Center(child: Text(_status))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      FilledButton(
                        onPressed: () => _guard(() async {
                          await doc.makeBox(const Vec3(40, 30, 20));
                          await controller.fitAll();
                        }),
                        child: const Text('Add box'),
                      ),
                      FilledButton(
                        onPressed: () => _guard(doc.undo),
                        child: const Text('Undo'),
                      ),
                      FilledButton(
                        onPressed: () => _guard(doc.redo),
                        child: const Text('Redo'),
                      ),
                      FilledButton(
                        onPressed: () => _guard(controller.fitAll),
                        child: const Text('Fit'),
                      ),
                      Text('selection: ${selection.isEmpty ? '—' : selection}'),
                    ],
                  ),
                ),
                Expanded(child: JetCadViewport(controller: controller)),
              ],
            ),
    );
  }
}
```

(Adjust `doc.makeBox` signature/`undo`/`redo` names and the `EntityId.value` accessor to the real document API. If `undo`/`redo` throw when empty, keep the `_guard` wrapper as written — errors just land in the status line.)

- [ ] **Step 2: Analyze + run the harness**

```bash
cd apps/dev_harness && flutter analyze
packages/jet_cad/tool/run_harness.sh
```

Expected: analyze clean; app launches with an empty (background-only) viewport.

- [ ] **Step 3: Manual E2E checklist (human-verified)**

The executor drives the app and captures screenshots (`screencapture -x /tmp/jet_cad_e2e_<n>.png` + inspect); the human partner confirms the interactive feel at review. Every line below must be checked:

1. **Add box** → shaded box appears, correctly oriented (not upside-down: verify a lit top face, matching the spike orientation finding).
2. **Orbit** (left-drag) → box rotates smoothly with the drag direction; no tearing or stale frames (flush finding).
3. **Pan** (right-drag) → scene follows the pointer direction (if inverted, flip the sign in `Viewer::pan` and re-run native tests — this is the adjustment note from Task 4).
4. **Zoom** (scroll) → zooms around the view; scroll up zooms in.
5. **Fit** → box fills the view with margin.
6. **Click box** → selection readout shows the body id; highlight visibly renders on the box.
7. **Click empty space** → selection clears (readout `—`, highlight gone).
8. **Resize window** (drag corner continuously) → viewport follows; after the debounce the image is crisp (no stretched blur), aspect correct, no crash from mid-resize renders.
9. **Undo / Redo** → box disappears/reappears in the viewport (damage render on doc change).
10. **Idle** → with the app untouched, Activity Monitor shows the process near-0% GPU/CPU (damage-driven idle).

Record the checklist outcome (with screenshot paths) in the ledger. Any failure is a bug to fix in the owning task's code before proceeding — not a note.

- [ ] **Step 4: Spike-debris + TODO audit**

```bash
grep -rn "debugInitTexture\|debugRenderTestPattern\|renderTestPattern" packages/jet_cad apps/dev_harness && echo "DEBRIS FOUND" || echo "clean"
grep -rn "TODO" packages/jet_cad/lib packages/jet_cad/src packages/jet_cad/test packages/jet_cad/macos apps/dev_harness/lib && echo "TODOS FOUND" || echo "clean"
```

Expected: both `clean` (plan docs excluded). `debugReadPixels` and `debugExecute` stay — they are documented test hooks, not debris.

- [ ] **Step 5: README + CHANGELOG + version**

`packages/jet_cad/README.md` — add a Viewport section after the existing kernel/document content (match the README's current tone; update any stale claims about "headless only"):

```markdown
## Viewport (macOS)

```dart
final bridge = FfiKernelBridge.auto();
final doc = await CadDocument.create(bridge, target: const TextureTarget());
final controller = ViewportController(document: doc);

// In your widget tree:
JetCadViewport(controller: controller)

// Navigation: left-drag orbit, right-drag pan, scroll zoom.
controller.selectionChanges.listen((e) => print('selected: ${e.selection}'));
await doc.makeBox(const Vec3(40, 30, 20));
await controller.fitAll();
```

Rendering is damage-driven (frames draw only on document/camera/selection
changes) via OCCT's AIS/V3d viewer composited as a Flutter external texture
(IOSurface). macOS only for now; Windows/Linux follow the same
`KernelBridge` contract in later milestones. Selection is view state — it
never enters the document or undo history.
```

`packages/jet_cad/CHANGELOG.md` — new top entry:

```markdown
## 0.3.0

- `JetCadViewport` widget + `ViewportController`: OCCT AIS/V3d offscreen
  rendering composited as a Flutter external texture on macOS (CGL →
  IOSurface → CVPixelBuffer), damage-driven redraw, debounced resize.
- Navigation: orbit / pan / zoom / fit. Click pick with body/face/edge/
  vertex filters; selection highlight; `SelectionChanged` stream on the
  controller (selection is view state — never in the document or undo).
- `KernelBridge` grows viewer methods (`resizeViewport`, `renderFrame`,
  camera, `pick`, `setSelection`) + `TextureTarget`; implemented by fake
  and FFI bridges, covered by the shared contract suite.
- `FfiKernelBridge` now runs on one long-lived worker isolate per bridge
  (was: Isolate.run + dlopen per command); new `shutdown()`. Concurrent
  `disposeSession` calls join the in-flight dispose.
- `CadDocument.create/load` accept a `RenderTarget`; documents expose
  `session`/`bridge` for viewport wiring.
```

`packages/jet_cad/pubspec.yaml`: `version: 0.3.0`.

- [ ] **Step 6: Full Definition-of-Done sweep**

```bash
cd packages/jet_cad && tool/build_native.sh
cd packages/jet_cad && flutter analyze && flutter test && dart format lib test
cd packages/jet_cad && mv build/native build/native.bak && flutter test && mv build/native.bak build/native
cd apps/dev_harness && flutter analyze
git status --short
```

Expected: native build + all ctest green; analyze clean everywhere; Dart suite green in both states with real counts reported; format no diff; working tree contains only intended changes.

- [ ] **Step 7: Commit**

```bash
git add apps/dev_harness packages/jet_cad/README.md packages/jet_cad/CHANGELOG.md packages/jet_cad/pubspec.yaml
git commit -m "docs: viewport quickstart, 0.3.0 changelog; harness on public API

Dev harness now exercises the package exclusively through its public
surface (CadDocument + TextureTarget + JetCadViewport +
ViewportController) — box/undo/redo/fit buttons and a selection
readout. Manual E2E checklist (orbit/pan/zoom/fit/pick/resize/undo/
idle-GPU) recorded in the ledger. README documents the macOS viewport
and damage-driven rendering; version bumped to 0.3.0.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Execution notes

- **Branch:** `feat/plan-3-viewport` off `main`. Never commit to main; local main is ahead of origin — do not push anything unless the human partner says so.
- **Ledger:** continue `.superpowers/sdd/progress.md` (`== Plan 3: interactive viewport (branch feat/plan-3-viewport, base <sha>) ==`), one entry per task: commit range, review outcome, deferred minors, and the Task 1 spike findings + Task 9 checklist outcome.
- **Reviews:** fresh subagent per task, per-task reviewer verifying claims against real transcripts (synthesized output is a firing offense), final whole-branch review on the most capable model with fix loops until approved.
- **Known-gotcha reminders for implementers** (from Plan 2, do not rediscover): gtest discovery needs `DISCOVERY_TIMEOUT 60` (already set); STEP toolkits are `TKDESTEP` on 7.8+ (CMake branch exists); `gp_Trsf::SetValues` silently orthogonalizes; BRepTools ASCII round-trip preserves TopExp enumeration order.
- **Deferred to later plans:** binary distribution of the dylib + plugin (Plan 5); Windows/Linux texture paths; demo app (Plan 4); TSan lane; binary BREP snapshots.
- **Documented deviation (spec evolution rule):** the spec's interaction sketch mentions hover → pick; v1 ships click-pick only. Hover pre-highlight means a render per mouse-move, which fights the damage-driven battery goal — it needs native dynamic-highlight batching, deferred to the demo-app phase (Plan 4) where the UX can be evaluated.
