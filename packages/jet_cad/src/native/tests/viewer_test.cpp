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
      jetcad::b64decodeBytes(result.at("rgbaBase64").get<std::string>());
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

TEST(ViewerTest, FittedBoxFacesAreLitDifferently) {
  uint64_t s = jc_create_session();
  initViewer(s, 128);
  makeBox(s, 50, 50, 50);
  execOk(s, {{"cmd", "cameraFit"}});
  execOk(s, {{"cmd", "renderFrame"}});
  std::vector<uint8_t> rgba = readAll(s, 128);
  // The default V3d camera shows the cube corner-on: in bottom-up GL rows
  // the top face fills the upper region and the side faces the lower
  // region. Both sample points sit well inside the fitted silhouette
  // (measured from the rendered output). Differently-angled faces under
  // the default lights MUST differ in brightness; an unlit flat fill
  // renders them identical.
  auto sideFace = pixelAt(rgba, 128, 40, 48);  // lower-left side face
  auto topFace = pixelAt(rgba, 128, 64, 96);   // top face
  std::array<uint8_t, 3> sideRgb = {sideFace[0], sideFace[1], sideFace[2]};
  std::array<uint8_t, 3> topRgb = {topFace[0], topFace[1], topFace[2]};
  EXPECT_NE(sideRgb, topRgb)
      << "two differently-angled faces must be lit differently";
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
  // saveSnapshot's real result shape is {"dataB64": ...}, and restoreSession
  // parses cmd.at("dataB64") directly (see session.cpp) — no nested
  // "snapshot" wrapper.
  execOk(b, {{"cmd", "restoreSession"}, {"dataB64", snapshot.at("dataB64")}});
  execOk(b, {{"cmd", "cameraFit"}});
  execOk(b, {{"cmd", "renderFrame"}});
  auto restored = centerPixel(b, 128);
  EXPECT_NE(background, restored)
      << "restoreSession must re-display restored bodies";
  jc_dispose_session(b);
}

}  // namespace
