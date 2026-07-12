#include <gtest/gtest.h>
#include <nlohmann/json.hpp>

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
