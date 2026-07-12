#pragma once
#include <cstdint>
#include <stdexcept>
#include <string>

namespace jetcad {

inline const char* kB64Chars =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

inline std::string b64encode(const std::string& in) {
  std::string out;
  out.reserve(((in.size() + 2) / 3) * 4);
  size_t i = 0;
  while (i + 2 < in.size()) {
    uint32_t n = (uint8_t)in[i] << 16 | (uint8_t)in[i + 1] << 8 |
                 (uint8_t)in[i + 2];
    out += kB64Chars[n >> 18];
    out += kB64Chars[(n >> 12) & 63];
    out += kB64Chars[(n >> 6) & 63];
    out += kB64Chars[n & 63];
    i += 3;
  }
  if (i + 1 == in.size()) {
    uint32_t n = (uint8_t)in[i] << 16;
    out += kB64Chars[n >> 18];
    out += kB64Chars[(n >> 12) & 63];
    out += "==";
  } else if (i + 2 == in.size()) {
    uint32_t n = (uint8_t)in[i] << 16 | (uint8_t)in[i + 1] << 8;
    out += kB64Chars[n >> 18];
    out += kB64Chars[(n >> 12) & 63];
    out += kB64Chars[(n >> 6) & 63];
    out += '=';
  }
  return out;
}

inline std::string b64decode(const std::string& in) {
  auto val = [](char c) -> int {
    if (c >= 'A' && c <= 'Z') return c - 'A';
    if (c >= 'a' && c <= 'z') return c - 'a' + 26;
    if (c >= '0' && c <= '9') return c - '0' + 52;
    if (c == '+') return 62;
    if (c == '/') return 63;
    return -1;
  };
  if (in.size() % 4 != 0) throw std::runtime_error("bad base64 length");
  std::string out;
  out.reserve(in.size() / 4 * 3);
  for (size_t i = 0; i < in.size(); i += 4) {
    int a = val(in[i]), b = val(in[i + 1]);
    if (a < 0 || b < 0) throw std::runtime_error("bad base64 char");
    out += (char)((a << 2) | (b >> 4));
    if (in[i + 2] != '=') {
      int c = val(in[i + 2]);
      if (c < 0) throw std::runtime_error("bad base64 char");
      out += (char)(((b & 15) << 4) | (c >> 2));
      if (in[i + 3] != '=') {
        int d = val(in[i + 3]);
        if (d < 0) throw std::runtime_error("bad base64 char");
        out += (char)(((c & 3) << 6) | d);
      }
    }
  }
  return out;
}

}  // namespace jetcad
