/* Builds the vendored ARMv8 CRC/PMULL sources with the CPU features enabled
 * through pragmas instead of -march=, which R CMD check flags as non-portable.
 * Only compiled when ./configure has verified the toolchain supports it. */
/* Include the system headers first so the pragma below only affects the vendored code. */
#include <arm_acle.h>
#include <arm_neon.h>

#if defined(__clang__)
#    pragma clang attribute push(__attribute__((target("crc,crypto"))), apply_to = function)
#elif defined(__GNUC__)
#    pragma GCC push_options
#    pragma GCC target("+crc+crypto")
#endif

#include "aws-checksums/source/arm/crc32c_arm.c"
#include "aws-checksums/source/arm/crc64_arm.c"

#if defined(__clang__)
#    pragma clang attribute pop
#elif defined(__GNUC__)
#    pragma GCC pop_options
#endif
