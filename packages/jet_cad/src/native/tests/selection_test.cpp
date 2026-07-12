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
