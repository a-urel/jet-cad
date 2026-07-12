#include "viewer.hpp"

#include <Aspect_DisplayConnection.hxx>
#include <Graphic3d_Camera.hxx>
#include <Graphic3d_CView.hxx>
#include <OpenGl_Context.hxx>
#include <OpenGl_FrameBuffer.hxx>
#include <Quantity_Color.hxx>
#include <V3d_AmbientLight.hxx>
#include <V3d_DirectionalLight.hxx>
#include <gp_Dir.hxx>

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
  // On native macOS (no HAVE_EGL/HAVE_XLIB) InitContext() only clears prior
  // state and marks the driver initialized — it does not itself create/bind
  // any GL context (confirmed against OCCT 7.9.3 source: the EGL branch that
  // does real work is compiled out on Cocoa). The real context wiring for
  // this driver happens per-view below, via SetWindow's external context.
  // Kept for parity with other platforms and to mirror the brief's sample.
  if (!driver_->InitContext()) {
    throw CommandError("OpenGl_GraphicDriver::InitContext failed");
  }

  viewer_ = new V3d_Viewer(driver_);
  // NOT SetDefaultLights(): that installs a HEADLIGHT (confirmed in OCCT
  // 7.9.3 V3d_Viewer.cxx — SetHeadlight(true)), i.e. a directional light
  // aligned with the camera view axis. The default V3d camera looks down
  // the cube's body diagonal, and all three visible faces of an
  // axis-aligned box make EQUAL angles with that diagonal — a headlight
  // therefore lights all three faces identically and the box renders as a
  // uniform flat fill (measured: every silhouette pixel identical). Use a
  // fixed world-space directional light instead, with distinct |x|,|y|,|z|
  // components so any axis-aligned face trio gets distinct diffuse terms
  // (all positive against the default view's +X/-Y/+Z faces, so no face
  // goes ambient-black), plus ambient fill.
  Handle(V3d_DirectionalLight) sun =
      new V3d_DirectionalLight(gp_Dir(-0.3, 0.5, -0.81), Quantity_NOC_WHITE);
  Handle(V3d_AmbientLight) ambient = new V3d_AmbientLight(Quantity_NOC_WHITE);
  viewer_->AddLight(sun);
  viewer_->AddLight(ambient);
  viewer_->SetLightOn();

  view_ = viewer_->CreateView();
  // OpenGl_View defaults myTransientDrawToFront = true (an optimization
  // that draws "immediate mode" content like selection highlights straight
  // to the front buffer and caches the rest in an internal sRGB blit FBO).
  // That internal FBO ("fbo0_main") failed to allocate in this offscreen
  // context (GL_INVALID_OPERATION creating a GL_SRGB8_ALPHA8 2D texture —
  // logged via OCCT's Messenger as "Main FBO ... initialization has
  // failed" on every frame). Per Graphic3d_CView::
  // SetImmediateModeDrawToFront's own doc comment, FALSE is "especially
  // useful for view dump because the dump image is read from the back
  // buffer" — exactly this offscreen readPixels() use case — and disabling
  // it removes the internal FBO's trigger condition entirely
  // (OpenGl_View::Render), so drawing goes straight into our SetFBO() below.
  view_->View()->SetImmediateModeDrawToFront(false);
  window_ = new Aspect_NeutralWindow();
  window_->SetSize(widthPx, heightPx);
  // V3d_View::CreateView() leaves myImmediateUpdate = Standard_True, and
  // SetWindow() redraws immediately when that flag is set (OCCT 7.9.3
  // V3d_View.cxx). Disable it BEFORE SetWindow so that premature Redraw
  // can't fire before bindViewToSurface() below has wrapped our FBO — the
  // brief's snippet sets this after SetWindow, which races the first frame.
  view_->SetImmediateUpdate(false);
  view_->SetWindow(window_, (Aspect_RenderingContext)gl_->nativeContext());
  view_->SetBackgroundColor(
      Quantity_Color(0.12, 0.12, 0.14, Quantity_TOC_sRGB));
  view_->Camera()->SetProjectionType(Graphic3d_Camera::Projection_Perspective);
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
  // InitWrapper() derives its viewport size from whatever GL_VIEWPORT
  // happens to be bound at call time (OCCT 7.9.3 OpenGl_FrameBuffer.cxx) —
  // meaningless here since this context has no real window/drawable ever
  // sized via glViewport. Override with the surface's real pixel size so
  // OpenGl_FrameBuffer::SetupViewport() (called from the view's redraw
  // path) sets a non-degenerate viewport instead of (0,0).
  fbo->ChangeViewport(gl_->width(), gl_->height());
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
  // Drain stale GL errors before handing control to OCCT. GL errors are
  // sticky (pending until glGetError() reads them) and OCCT 7.9.3's own
  // init/probe code leaves illegal-enum errors queued (e.g. its
  // unconditional GL_MAX_CLIP_PLANES query, illegal in Core Profile).
  // OCCT self-checks its uploads during Redraw with glGetError(); with a
  // stale error pending it misattributes the failure and silently discards
  // freshly-built VBOs ("VBO creation for Primitive Array has failed ...
  // Out of memory?"), degrading rendering. Draining here — measured as the
  // single sufficient point; constructor-time drains were neither needed
  // nor enough on their own — guarantees Redraw starts with a clean error
  // queue. See gl_context_macos.mm's pixel-format note for the Core
  // Profile half of this story.
  gl_->drainErrors();
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
