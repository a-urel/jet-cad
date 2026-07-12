#pragma once

#include <gtest/gtest.h>

#include <nlohmann/json.hpp>

#include <array>
#include <cstdint>
#include <string>
#include <vector>

#include "../include/jet_cad_native.h"
#include "../b64.hpp"

namespace jetcad::test {

using json = nlohmann::json;

inline json exec(uint64_t session, const json& cmd) {
  const char* raw = jc_execute(session, cmd.dump().c_str());
  json envelope = json::parse(raw);
  jc_free(raw);
  return envelope;
}

inline json execOk(uint64_t session, const json& cmd) {
  json envelope = exec(session, cmd);
  EXPECT_TRUE(envelope.at("ok").get<bool>()) << envelope.dump();
  return envelope.at("result");
}

// Returns the RGBA quad at pixel (x, y) with rows bottom-up (GL order).
inline std::array<uint8_t, 4> pixelAt(const std::vector<uint8_t>& rgba,
                                      int width, int x, int y) {
  const size_t offset = (static_cast<size_t>(y) * width + x) * 4;
  return {rgba[offset], rgba[offset + 1], rgba[offset + 2], rgba[offset + 3]};
}

}  // namespace jetcad::test
