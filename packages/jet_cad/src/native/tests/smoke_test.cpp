#include <gtest/gtest.h>
#include <nlohmann/json.hpp>

#include "../b64.hpp"
#include "../include/jet_cad_native.h"

using json = nlohmann::json;

TEST(Smoke, VersionReportsOcct) {
  const char* raw = jc_version();
  ASSERT_NE(raw, nullptr);
  auto v = json::parse(raw);
  jc_free(raw);
  EXPECT_EQ(v.at("kernelVersion"), "jet_cad_native 0.1.0");
  EXPECT_FALSE(v.at("occtVersion").get<std::string>().empty());
}

TEST(Smoke, ExecuteReturnsEnvelope) {
  const char* raw = jc_execute(0, "{}");
  ASSERT_NE(raw, nullptr);
  auto env = json::parse(raw);
  jc_free(raw);
  EXPECT_FALSE(env.at("ok").get<bool>());
}

TEST(Base64, RoundTripAndPaddingEdges) {
  using jetcad::b64decode;
  using jetcad::b64encode;
  for (const std::string s : {std::string(""), std::string("a"),
                              std::string("ab"), std::string("abc"),
                              std::string("hello world"),
                              std::string("\x00\xff\x10", 3)}) {
    EXPECT_EQ(b64decode(b64encode(s)), s);
  }
  EXPECT_THROW(b64decode("AB=C"), std::runtime_error);
  EXPECT_THROW(b64decode("A"), std::runtime_error);
  EXPECT_THROW(b64decode("!!!!"), std::runtime_error);
  // Mid-stream padding regression pins (reviewer carry-over from Task 2):
  // '=' must only appear in the final 4-char group.
  EXPECT_THROW(b64decode("AB==AAAA"), std::runtime_error);
  EXPECT_THROW(b64decode("ABC=AAAA"), std::runtime_error);
}
