#include <gtest/gtest.h>

#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>

#include "../session.hpp"

using jetcad::Session;
using json = nlohmann::json;

namespace {
json box(Session& s, double x, double y, double z) {
  return s.execute({{"cmd", "makeBox"}, {"size", {x, y, z}}});
}
}  // namespace

TEST(Snapshots, RestorePreservesIdsAndCounterNeverCollides) {
  Session s;
  auto a = box(s, 1, 2, 3);
  const std::string bodyId = a.at("body");
  auto snap = s.execute({{"cmd", "snapshotBodies"}, {"bodies", {bodyId}}});
  s.execute({{"cmd", "deleteBodies"}, {"bodies", {bodyId}}});
  EXPECT_THROW(s.execute({{"cmd", "exportStep"}, {"bodies", {bodyId}}}),
               jetcad::CommandError);
  s.execute({{"cmd", "restoreBodies"}, {"dataB64", snap.at("dataB64")}});
  auto step = s.execute({{"cmd", "exportStep"}, {"bodies", {bodyId}}});
  EXPECT_FALSE(step.at("dataB64").get<std::string>().empty());
  // Fresh ids after restore must not collide with restored ones.
  auto b = box(s, 1, 1, 1);
  EXPECT_NE(b.at("body"), bodyId);
}

TEST(Snapshots, SessionSaveRestoreRoundTrip) {
  Session s;
  auto a = box(s, 1, 1, 1);
  auto b = box(s, 2, 2, 2);
  auto save = s.execute({{"cmd", "saveSnapshot"}});
  Session fresh;
  fresh.execute({{"cmd", "restoreSession"}, {"dataB64", save.at("dataB64")}});
  auto step = fresh.execute(
      {{"cmd", "exportStep"},
       {"bodies", {a.at("body"), b.at("body")}}});
  EXPECT_FALSE(step.at("dataB64").get<std::string>().empty());
  auto c = box(fresh, 3, 3, 3);
  EXPECT_NE(c.at("body"), a.at("body"));
  EXPECT_NE(c.at("body"), b.at("body"));
}

TEST(Step, ExportImportRoundTrip) {
  Session s;
  auto a = box(s, 2, 3, 4);
  auto out = s.execute({{"cmd", "exportStep"}, {"bodies", {a.at("body")}}});
  Session other;
  auto imported = other.execute(
      {{"cmd", "importStep"}, {"dataB64", out.at("dataB64")}});
  ASSERT_GE(imported.at("bodies").size(), 1u);
  EXPECT_GE(imported.at("bodies")[0].at("faces").size(), 6u);
  EXPECT_THROW(other.execute({{"cmd", "importStep"},
                              {"dataB64", "aGVsbG8="}}),
               jetcad::CommandError)
      << "non-STEP payload rejected";
}
