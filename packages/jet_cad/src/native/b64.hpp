#pragma once
#include <cstdint>
#include <stdexcept>
#include <string>
#include <vector>

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
    const bool last_group = (i + 4 == in.size());
    int a = val(in[i]), b = val(in[i + 1]);
    if (a < 0 || b < 0) throw std::runtime_error("bad base64 char");
    out += (char)((a << 2) | (b >> 4));
    if (in[i + 2] == '=') {
      // "xx==" is the only legal form once position 2 is padding, and
      // padding is only legal in the final group.
      if (in[i + 3] != '=' || !last_group)
        throw std::runtime_error("bad base64 padding");
    } else {
      int c = val(in[i + 2]);
      if (c < 0) throw std::runtime_error("bad base64 char");
      out += (char)(((b & 15) << 4) | (c >> 2));
      if (in[i + 3] == '=') {
        if (!last_group) throw std::runtime_error("bad base64 padding");
      } else {
        int d = val(in[i + 3]);
        if (d < 0) throw std::runtime_error("bad base64 char");
        out += (char)(((c & 3) << 6) | d);
      }
    }
  }
  return out;
}

// Byte-vector overload (true overload: distinct parameter type from the
// std::string version above, so this is not a return-type-only overload,
// which C++ disallows). Used by binary payloads such as raw RGBA pixels.
inline std::string b64encode(const std::vector<uint8_t>& in) {
  return b64encode(std::string(reinterpret_cast<const char*>(in.data()),
                               in.size()));
}

// Decodes into a byte vector. Named distinctly from b64decode (which
// returns std::string) because C++ cannot overload on return type alone
// when the parameter type is identical.
inline std::vector<uint8_t> b64decodeBytes(const std::string& in) {
  const std::string bytes = b64decode(in);
  return std::vector<uint8_t>(bytes.begin(), bytes.end());
}

}  // namespace jetcad
