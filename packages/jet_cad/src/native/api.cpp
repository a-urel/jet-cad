#include "include/jet_cad_native.h"

#include <cstdlib>
#include <cstring>
#include <string>

#include <Standard_Version.hxx>
#include <nlohmann/json.hpp>

using json = nlohmann::json;

namespace {

const char* mallocString(const std::string& s) {
  char* out = static_cast<char*>(std::malloc(s.size() + 1));
  std::memcpy(out, s.c_str(), s.size() + 1);
  return out;
}

const char* errorEnvelope(const std::string& message) {
  return mallocString(json{{"ok", false}, {"error", message}}.dump());
}

}  // namespace

extern "C" {

uint64_t jc_create_session(void) { return 0; /* Task 3 */ }

void jc_dispose_session(uint64_t) { /* Task 3 */ }

const char* jc_execute(uint64_t, const char*) {
  return errorEnvelope("no commands implemented yet");
}

const char* jc_version(void) {
  return mallocString(json{{"kernelVersion", "jet_cad_native 0.1.0"},
                           {"occtVersion", OCC_VERSION_COMPLETE}}
                          .dump());
}

void jc_free(const char* ptr) { std::free(const_cast<char*>(ptr)); }

}  // extern "C"
