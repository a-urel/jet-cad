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

// Returns the RGBA quad at the center of a `size` x `size` viewer surface.
inline std::array<uint8_t, 4> centerPixel(uint64_t session, int size) {
  json result = execOk(session, {{"cmd", "debugReadPixels"},
                                 {"x", size / 2},
                                 {"y", size / 2},
                                 {"width", 1},
                                 {"height", 1}});
  std::vector<uint8_t> rgba =
      jetcad::b64decodeBytes(result.at("rgbaBase64").get<std::string>());
  return {rgba[0], rgba[1], rgba[2], rgba[3]};
}

// Initializes a `size` x `size` viewer on `session` and asserts it succeeded.
inline void initViewer(uint64_t session, int size) {
  json result = execOk(session, {{"cmd", "initViewer"},
                                 {"width", size},
                                 {"height", size},
                                 {"pixelRatio", 1.0}});
  EXPECT_GT(result.at("surfaceId").get<uint32_t>(), 0u);
}

// Real makeBox parameter shape: {"size":[x,y,z]} (see session.cpp).
inline json makeBox(uint64_t session, double x, double y, double z) {
  return execOk(session, {{"cmd", "makeBox"}, {"size", {x, y, z}}});
}

// Reads the full `size` x `size` surface as bottom-up RGBA bytes.
inline std::vector<uint8_t> readAll(uint64_t session, int size) {
  json result = execOk(session, {{"cmd", "debugReadPixels"},
                                 {"x", 0},
                                 {"y", 0},
                                 {"width", size},
                                 {"height", size}});
  return jetcad::b64decodeBytes(result.at("rgbaBase64").get<std::string>());
}

}  // namespace jetcad::test
