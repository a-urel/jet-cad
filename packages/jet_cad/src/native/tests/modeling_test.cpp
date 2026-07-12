#include <gtest/gtest.h>

#include "../session.hpp"

using jetcad::Session;
using json = nlohmann::json;

namespace {
json box(Session& s, double x, double y, double z) {
  return s.execute({{"cmd", "makeBox"}, {"size", {x, y, z}}});
}
}  // namespace

TEST(Extrude, CreatesNewBodyLeavesSourceIntact) {
  Session s;
  auto a = box(s, 2, 3, 1);
  auto r = s.execute({{"cmd", "extrude"},
                      {"face", a.at("faces")[0]},
                      {"depth", 5.0}});
  EXPECT_NE(r.at("body"), a.at("body"));
  EXPECT_EQ(r.at("faces").size(), 6u);
  // Source still usable.
  auto r2 = s.execute({{"cmd", "extrude"},
                       {"face", a.at("faces")[1]},
                       {"depth", 1.0}});
  EXPECT_FALSE(r2.at("body").get<std::string>().empty());
  EXPECT_THROW(
      s.execute({{"cmd", "extrude"}, {"face", "nope"}, {"depth", 1.0}}),
      jetcad::CommandError);
}

TEST(Fillet, KeepsBodyIdMapsEdgeToGeneratedFace) {
  Session s;
  auto a = box(s, 10, 10, 10);
  std::string edge = a.at("edges")[0];
  auto r = s.execute(
      {{"cmd", "fillet"}, {"edges", {edge}}, {"radius", 1.0}});
  EXPECT_EQ(r.at("body"), a.at("body"));
  ASSERT_TRUE(r.at("remap").contains(edge));
  EXPECT_GE(r.at("remap").at(edge).size(), 1u)
      << "filleted edge maps to generated face(s)";
  EXPECT_GE(r.at("faces").size(), 1u) << "at least the new fillet face";
  EXPECT_THROW(s.execute({{"cmd", "fillet"},
                          {"edges", {edge}},
                          {"radius", 1.0}}),
               jetcad::CommandError)
      << "consumed edge id no longer valid";
  EXPECT_THROW(s.execute({{"cmd", "fillet"},
                          {"edges", json::array()},
                          {"radius", 1.0}}),
               jetcad::CommandError);
}

TEST(Fillet, TooLargeRadiusFailsCleanly) {
  Session s;
  auto a = box(s, 1, 1, 1);
  EXPECT_THROW(s.execute({{"cmd", "fillet"},
                          {"edges", {a.at("edges")[0]}},
                          {"radius", 100.0}}),
               jetcad::CommandError);
  // Body must still exist untouched after the failure.
  auto r = s.execute({{"cmd", "fillet"},
                      {"edges", {a.at("edges")[1]}},
                      {"radius", 0.1}});
  EXPECT_EQ(r.at("body"), a.at("body"));
}

TEST(Transform, PreservesIdsRejectsScale) {
  Session s;
  auto a = box(s, 1, 1, 1);
  // Column-major translation by (5,0,0).
  json m = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 5, 0, 0, 1};
  auto r = s.execute(
      {{"cmd", "transform"}, {"bodies", {a.at("body")}}, {"matrix", m}});
  EXPECT_TRUE(r.empty());
  // Ids still valid: fillet an edge of the moved body.
  auto f = s.execute({{"cmd", "fillet"},
                      {"edges", {a.at("edges")[0]}},
                      {"radius", 0.1}});
  EXPECT_EQ(f.at("body"), a.at("body"));
  // Non-rigid rejected.
  json scale = {2, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1};
  EXPECT_THROW(s.execute({{"cmd", "transform"},
                          {"bodies", {a.at("body")}},
                          {"matrix", scale}}),
               jetcad::CommandError);
}
