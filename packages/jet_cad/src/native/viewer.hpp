#pragma once

#include <cstdint>
#include <map>
#include <memory>
#include <optional>
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

  // Camera navigation — view state only, never synced/serialized.
  void orbitStart(double x, double y);
  void orbit(double x, double y);
  void pan(double dx, double dy);
  void zoom(double factor);
  // Reallocates the IOSurface at the new pixel size (fresh surface id every
  // call), resizes the neutral window/view and re-wraps the FBO. Returns the
  // new surface id.
  uint32_t resize(int widthPx, int heightPx, double pixelRatio);

  // Native pick + selection (Task 5). Neither draws — highlight/detection
  // changes become visible only on the next render().
  struct PickHit {
    std::string entity;
    std::string body;
  };

  // x/y are physical framebuffer pixels, origin top-left (matches
  // AIS_InteractiveContext::MoveTo's view-pixel convention). Returns
  // std::nullopt on a miss; throws CommandError for an unknown filter or if
  // a detected subshape can't be mapped back to a session id (lineage bug).
  std::optional<PickHit> pick(double x, double y, const std::string& filter,
                              const std::map<std::string, Body>& bodies);
  // Replaces the whole selection; empty ids clears it. Validates every id
  // before touching AIS state so an unknown id fails atomically.
  void setSelection(const std::vector<std::string>& ids,
                    const std::map<std::string, Body>& bodies);

 private:
  void bindViewToSurface();
  // Activates `mode` as the sole selection mode on every displayed object
  // (no-op if already active). Selection owners for a mode are (re)computed
  // by AIS_InteractiveContext::Activate, so this must run before any code
  // that inspects an object's owners for that mode.
  void activateSelectionMode(int mode);
  // Finds the body id whose displayed AIS_Shape IS `object`; throws
  // CommandError if `object` isn't one of ours (should not happen: only
  // tracked AIS_Shapes are ever displayed in this context).
  std::string bodyIdOfAis(const Handle(AIS_InteractiveObject)& object) const;

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
  // Selection mode currently activated on every displayed object; 0 (whole
  // shape) both by default and via syncBodies' initial Display() call.
  int activeMode_ = 0;
};

}  // namespace jetcad
