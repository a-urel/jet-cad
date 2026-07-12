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
      jetcad::b64decodeBytes(result.at("rgbaBase64").get<std::string>());
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
