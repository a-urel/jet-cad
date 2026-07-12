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

#include <SelectMgr_EntityOwner.hxx>
#include <SelectMgr_IndexedMapOfOwner.hxx>
#include <StdSelect_BRepOwner.hxx>
#include <TopAbs_ShapeEnum.hxx>

#include <set>
#include <stdexcept>

#include "session.hpp"

namespace jetcad {

namespace {

// Maps a pick "filter" JSON string to the AIS_Shape selection mode that
// exposes the matching subshape kind. Mode 0 is AIS_Shape's whole-shape
// ("neutral point") selection mode.
int selectionModeFor(const std::string& filter) {
  if (filter == "body") return 0;
  if (filter == "face") return AIS_Shape::SelectionMode(TopAbs_FACE);
  if (filter == "edge") return AIS_Shape::SelectionMode(TopAbs_EDGE);
  if (filter == "vertex") return AIS_Shape::SelectionMode(TopAbs_VERTEX);
  throw CommandError("unknown pick filter: " + filter);
}

// Maps a session entity id's kind prefix (contractual: b/f/e/v) to the
// selection mode that would have produced an owner for it.
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
      // Newly displayed shapes join with whatever selection mode is
      // currently active session-wide, not a hardcoded 0 — otherwise a body
      // added after a pick/setSelection call switched activeMode_ (e.g. to
      // "face") would silently be unselectable in that mode until the next
      // mode switch flips it back.
      context_->Display(ais, AIS_Shaded, /*selection mode*/ activeMode_,
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
  // OCCT pans in view coordinates (+Y up); our deltas arrive in physical
  // framebuffer/screen coordinates (+Y down, origin top-left) — hence the
  // sign flip so a positive dy (drag toward the bottom of the screen) pans
  // the view content the same direction the gesture moved it on screen.
  view_->Pan(static_cast<int>(dx), static_cast<int>(-dy));
}

void Viewer::zoom(double factor) {
  if (factor <= 0.0) throw CommandError("zoom factor must be positive");
  gl_->makeCurrent();
  view_->SetZoom(factor);
}

uint32_t Viewer::resize(int widthPx, int heightPx, double pixelRatio) {
  gl_->makeCurrent();
  const uint32_t surfaceId = gl_->createSurfaceFramebuffer(widthPx, heightPx);
  window_->SetSize(widthPx, heightPx);
  view_->MustBeResized();
  bindViewToSurface();
  pixelRatio_ = pixelRatio;
  return surfaceId;
}

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
  // theToRedrawOnUpdate=false: dynamic-highlight redraw is irrelevant here
  // (this is an offscreen headless probe, not an interactive cursor move),
  // and render() is the only place that ever draws.
  context_->MoveTo(static_cast<int>(x), static_cast<int>(y), view_,
                   /*theToRedrawOnUpdate*/ false);
  if (!context_->HasDetected()) return std::nullopt;

  Handle(SelectMgr_EntityOwner) owner = context_->DetectedOwner();
  Handle(AIS_InteractiveObject) object =
      Handle(AIS_InteractiveObject)::DownCast(owner->Selectable());
  const std::string bodyId = bodyIdOfAis(object);
  if (filter == "body") return PickHit{bodyId, bodyId};

  // Subshape filters must resolve to a session id or throw — never guess by
  // falling back to a body-level hit; an unmapped detected subshape is a
  // lineage bug (the AIS display list should always mirror bodies_).
  Handle(StdSelect_BRepOwner) brepOwner =
      Handle(StdSelect_BRepOwner)::DownCast(owner);
  if (brepOwner.IsNull() || !brepOwner->HasShape()) {
    throw CommandError(
        "picked subshape has no owner shape (lineage bug)");
  }
  const TopoDS_Shape& sub = brepOwner->Shape();
  const Body& body = bodies.at(bodyId);
  const auto* list = filter == "face"   ? &body.faces
                     : filter == "edge" ? &body.edges
                                        : &body.vertices;
  for (const auto& [subId, shape] : *list) {
    if (shape.IsSame(sub)) return PickHit{subId, bodyId};
  }
  throw CommandError("picked subshape has no session id (lineage bug)");
}

void Viewer::setSelection(const std::vector<std::string>& ids,
                          const std::map<std::string, Body>& bodies) {
  gl_->makeCurrent();

  // Resolve every id to its owning body + target shape + selection mode
  // FIRST: an unknown id must not partially apply the selection. ALL
  // validation (including the displayed_ membership checks) lives in this
  // loop so nothing below it can throw after ClearSelected has already
  // wiped the previous selection.
  struct Target {
    std::string id;  // as given, for error messages
    std::string bodyId;
    TopoDS_Shape shape;
    int mode;
  };
  std::vector<Target> targets;
  targets.reserve(ids.size());
  std::set<std::string> seen;
  for (const auto& id : ids) {
    const int mode = selectionModeForId(id);
    // Dedupe, keeping first-occurrence order: AddOrRemoveSelected is a
    // TOGGLE (per OCCT docs), so applying a repeated id twice would select
    // then immediately deselect it — the duplicate must simply be dropped
    // for "replace the selection with these ids" semantics to hold.
    if (!seen.insert(id).second) continue;
    if (mode == 0) {
      auto it = bodies.find(id);
      if (it == bodies.end() || displayed_.find(id) == displayed_.end()) {
        throw CommandError("unknown body id: " + id);
      }
      targets.push_back({id, id, it->second.shape, 0});
      continue;
    }
    bool found = false;
    for (const auto& [bodyId, body] : bodies) {
      const auto* list = id[0] == 'f'   ? &body.faces
                         : id[0] == 'e' ? &body.edges
                                        : &body.vertices;
      for (const auto& [subId, shape] : *list) {
        if (subId == id) {
          if (displayed_.find(bodyId) == displayed_.end()) {
            // Resolved against `bodies` but its body isn't displayed — the
            // AIS list should always mirror bodies_ (syncBodies runs after
            // every mutating command), so this would be a lineage bug.
            throw CommandError("body not displayed: " + bodyId);
          }
          targets.push_back({id, bodyId, shape, mode});
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
    // Activating (re)computes/attaches this mode's selection owners on
    // every displayed object, matching the mode we're about to search.
    activateSelectionMode(target.mode);

    Handle(SelectMgr_IndexedMapOfOwner) owners =
        new SelectMgr_IndexedMapOfOwner();
    context_->EntityOwners(owners, displayed_.at(target.bodyId).ais,
                           target.mode);

    bool selected = false;
    if (target.mode == 0) {
      // Whole-shape mode: there is exactly one owner for the object; no
      // subshape IsSame match is meaningful (or needed).
      if (owners->Extent() >= 1) {
        context_->AddOrRemoveSelected(owners->FindKey(1), false);
        selected = true;
      }
    } else {
      for (int i = 1; i <= owners->Extent(); ++i) {
        Handle(StdSelect_BRepOwner) brepOwner =
            Handle(StdSelect_BRepOwner)::DownCast(owners->FindKey(i));
        if (!brepOwner.IsNull() && brepOwner->HasShape() &&
            brepOwner->Shape().IsSame(target.shape)) {
          context_->AddOrRemoveSelected(owners->FindKey(i), false);
          selected = true;
          break;
        }
      }
    }
    if (!selected) {
      context_->ClearSelected(false);
      throw CommandError("no selectable owner for id: " + target.id);
    }
  }
}

}  // namespace jetcad
