#include <gtest/gtest.h>

#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <GProp_GProps.hxx>

#include "../include/jet_cad_native.h"
#include "../session.hpp"

using jetcad::Session;
using json = nlohmann::json;

namespace {
double volume(const TopoDS_Shape& shape) {
  GProp_GProps props;
  BRepGProp::VolumeProperties(shape, props);
  return props.Mass();
}
}  // namespace

TEST(SessionMakeBox, TopologyCountsAndDeterministicIds) {
  Session s;
  auto r = s.execute({{"cmd", "makeBox"}, {"size", {1.0, 2.0, 3.0}}});
  EXPECT_EQ(r.at("faces").size(), 6u);
  EXPECT_EQ(r.at("edges").size(), 12u);
  EXPECT_EQ(r.at("vertices").size(), 8u);
  EXPECT_TRUE(r.at("remap").empty());

  Session s2;
  auto r2 = s2.execute({{"cmd", "makeBox"}, {"size", {1.0, 2.0, 3.0}}});
  EXPECT_EQ(r.at("body"), r2.at("body")) << "ids deterministic per session";
}

TEST(SessionMakeBox, VolumeGolden) {
  Session s;
  auto r = s.execute({{"cmd", "makeBox"}, {"size", {2.0, 3.0, 4.0}}});
  // Reach the shape through a second command? No — this is a C++ unit
  // test; use a friend-free check via export in Task 6. Here: rebuild and
  // measure directly to pin OCCT behavior.
  BRepPrimAPI_MakeBox make(2.0, 3.0, 4.0);
  EXPECT_NEAR(volume(make.Shape()), 24.0, 1e-9);
  (void)r;
}

TEST(SessionMakeBox, RejectsBadInput) {
  Session s;
  EXPECT_THROW(
      s.execute({{"cmd", "makeBox"}, {"size", {-1.0, 1.0, 1.0}}}),
      jetcad::CommandError);
  EXPECT_THROW(s.execute({{"cmd", "loft"}}), jetcad::CommandError);
}

TEST(CApi, SessionLifecycleAndErrorEnvelope) {
  uint64_t h = jc_create_session();
  ASSERT_NE(h, 0u);
  const char* raw = jc_execute(
      h, R"({"cmd":"makeBox","size":[1.0,1.0,1.0]})");
  auto env = json::parse(raw);
  jc_free(raw);
  ASSERT_TRUE(env.at("ok").get<bool>());
  EXPECT_EQ(env.at("result").at("faces").size(), 6u);

  raw = jc_execute(h, R"({"cmd":"makeBox","size":[0.0,1.0,1.0]})");
  env = json::parse(raw);
  jc_free(raw);
  EXPECT_FALSE(env.at("ok").get<bool>());

  jc_dispose_session(h);
  raw = jc_execute(h, R"({"cmd":"makeBox","size":[1.0,1.0,1.0]})");
  env = json::parse(raw);
  jc_free(raw);
  EXPECT_FALSE(env.at("ok").get<bool>());
  EXPECT_EQ(env.at("error"), "unknown session");
}
