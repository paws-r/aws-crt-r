#include <stdbool.h>

#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

#include <aws/checksums/private/crc_util.h>

#include "awscrt.h"

/* Dispatch state that upstream defines in source/checksums.c. That file also
 * initialises aws-c-common's logging, error tables and xxhash, none of which
 * the CRC code needs, so it is not built; we provide the state and run the
 * (idempotent) resolvers ourselves. */
bool s_detection_performed = false;
bool s_detected_sse42 = false;
bool s_detected_avx512 = false;
bool s_detected_clmul = false;
bool s_detected_vpclmulqdq = false;

/* R's attribute_visible is only defined when Rconfig.h sets
 * HAVE_VISIBILITY_ATTRIBUTE, which older R builds do not. Under
 * -fvisibility=hidden the init function would then be hidden and R would never
 * register the routines, so use the compiler attribute directly. */
#if defined(__GNUC__) || defined(__clang__)
#  define AWSCRT_EXPORT __attribute__((visibility("default")))
#else
#  define AWSCRT_EXPORT
#endif

static const R_CallMethodDef call_methods[] = {
  {"awscrt_crc32", (DL_FUNC)&awscrt_crc32, 4},
  {"awscrt_crc32c", (DL_FUNC)&awscrt_crc32c, 4},
  {"awscrt_crc64nvme", (DL_FUNC)&awscrt_crc64nvme, 4},
  {"awscrt_cpu_features", (DL_FUNC)&awscrt_cpu_features, 0},
  {NULL, NULL, 0}
};

AWSCRT_EXPORT void R_init_awscrt(DllInfo *dll) {
  aws_checksums_init_detection_cache();
  aws_checksums_crc32_init();
  aws_checksums_crc64_init();

  R_registerRoutines(dll, NULL, call_methods, NULL, NULL);
  R_useDynamicSymbols(dll, FALSE);
  R_forceSymbols(dll, TRUE);
}
