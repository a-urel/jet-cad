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

  // Camera navigation — view state only, never synced/serialized.
  void orbitStart(double x, double y);
  void orbit(double x, double y);
  void pan(double dx, double dy);
  void zoom(double factor);
  // Reallocates the IOSurface at the new pixel size (fresh surface id every
  // call), resizes the neutral window/view and re-wraps the FBO. Returns the
  // new surface id.
  uint32_t resize(int widthPx, int heightPx, double pixelRatio);

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
