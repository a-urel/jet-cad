#include <gtest/gtest.h>

#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>

#include "../b64.hpp"
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

TEST(Snapshots, CorruptRestoreSessionLeavesStateIntact) {
  // Build a two-body payload whose SECOND entry has corrupt BREP. The donor
  // makes three boxes and deletes the first so its surviving body ids sit
  // past the target session's ids: ids are deterministic per session, so
  // without the shift the donor's valid first entry would collide with the
  // target's box id and a partial (non-atomic) restore could masquerade as
  // intact state.
  Session donor;
  auto d0 = box(donor, 1, 1, 1);
  box(donor, 1, 1, 1);
  box(donor, 2, 2, 2);
  donor.execute({{"cmd", "deleteBodies"}, {"bodies", {d0.at("body")}}});
  auto save = donor.execute({{"cmd", "saveSnapshot"}});
  auto snapshot =
      json::parse(jetcad::b64decode(save.at("dataB64").get<std::string>()));
  ASSERT_EQ(snapshot.at("bodies").size(), 2u);
  snapshot["bodies"][1]["brepB64"] = "AAAA";  // valid base64, corrupt BREP
  const std::string corrupt = jetcad::b64encode(snapshot.dump());

  Session s;
  auto a = box(s, 3, 4, 5);
  const std::string bodyId = a.at("body");
  EXPECT_THROW(s.execute({{"cmd", "restoreSession"}, {"dataB64", corrupt}}),
               jetcad::CommandError);
  // All-or-nothing: the pre-restore body must survive a failed restore.
  auto step = s.execute({{"cmd", "exportStep"}, {"bodies", {bodyId}}});
  EXPECT_FALSE(step.at("dataB64").get<std::string>().empty());
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
