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
