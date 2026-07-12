#include "include/jet_cad_native.h"

#include <cstdlib>
#include <cstring>
#include <map>
#include <memory>
#include <mutex>
#include <string>

#include <Standard_Failure.hxx>
#include <Standard_Version.hxx>
#include <nlohmann/json.hpp>

#include "session.hpp"

using json = nlohmann::json;

namespace {

// Returns nullptr if allocation fails; jc_execute / jc_version propagate
// that nullptr to the caller (documented in jet_cad_native.h).
const char* mallocString(const std::string& s) {
  char* out = static_cast<char*>(std::malloc(s.size() + 1));
  if (out == nullptr) return nullptr;
  std::memcpy(out, s.c_str(), s.size() + 1);
  return out;
}

const char* errorEnvelope(const std::string& message) {
  return mallocString(json{{"ok", false}, {"error", message}}.dump());
}

struct SessionEntry {
  std::unique_ptr<jetcad::Session> session = std::make_unique<jetcad::Session>();
  std::mutex mutex;  // insurance; Dart already serializes per session
};

std::mutex g_registryMutex;
std::map<uint64_t, std::unique_ptr<SessionEntry>> g_sessions;
uint64_t g_nextHandle = 0;

}  // namespace

extern "C" {

uint64_t jc_create_session(void) {
  std::lock_guard<std::mutex> lock(g_registryMutex);
  uint64_t handle = ++g_nextHandle;
  g_sessions[handle] = std::make_unique<SessionEntry>();
  return handle;
}

void jc_dispose_session(uint64_t session) {
  std::lock_guard<std::mutex> lock(g_registryMutex);
  g_sessions.erase(session);
}

const char* jc_execute(uint64_t session, const char* command_json) {
  SessionEntry* entry = nullptr;
  {
    std::lock_guard<std::mutex> lock(g_registryMutex);
    auto it = g_sessions.find(session);
    if (it != g_sessions.end()) entry = it->second.get();
  }
  if (entry == nullptr) return errorEnvelope("unknown session");
  try {
    std::lock_guard<std::mutex> lock(entry->mutex);
    auto cmd = json::parse(command_json);
    auto result = entry->session->execute(cmd);
    return mallocString(json{{"ok", true}, {"result", result}}.dump());
  } catch (const Standard_Failure& e) {
    const char* msg = e.GetMessageString();
    return errorEnvelope(std::string("OCCT: ") + (msg ? msg : "failure"));
  } catch (const std::exception& e) {
    return errorEnvelope(e.what());
  } catch (...) {
    return errorEnvelope("unknown native error");
  }
}

const char* jc_version(void) {
  return mallocString(json{{"kernelVersion", "jet_cad_native 0.1.0"},
                           {"occtVersion", OCC_VERSION_COMPLETE}}
                          .dump());
}

void jc_free(const char* ptr) { std::free(const_cast<char*>(ptr)); }

}  // extern "C"
