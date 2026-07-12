#ifndef JET_CAD_NATIVE_H
#define JET_CAD_NATIVE_H

#include <stdint.h>

#if defined(_WIN32)
#define JC_EXPORT __declspec(dllexport)
#else
#define JC_EXPORT __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

/* Creates a kernel session; returns an opaque non-zero handle. */
JC_EXPORT uint64_t jc_create_session(void);

/* Disposes a session. Unknown handles are a silent no-op. */
JC_EXPORT void jc_dispose_session(uint64_t session);

/*
 * Executes one JSON command against a session. Returns a malloc'd UTF-8
 * JSON envelope: {"ok":true,"result":...} or {"ok":false,"error":"..."}.
 * Never throws / crashes across this boundary. Free with jc_free.
 */
JC_EXPORT const char* jc_execute(uint64_t session, const char* command_json);

/* Returns malloc'd {"kernelVersion":...,"occtVersion":...}. Free with jc_free. */
JC_EXPORT const char* jc_version(void);

JC_EXPORT void jc_free(const char* ptr);

#ifdef __cplusplus
}
#endif

#endif /* JET_CAD_NATIVE_H */
