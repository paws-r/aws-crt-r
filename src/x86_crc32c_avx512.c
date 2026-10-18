/* Builds the vendored x86_64 crc32c_sse42_avx512.c with the CPU features enabled
 * through pragmas instead of -m flags, which R CMD check flags as non-portable.
 * Only compiled when ./configure has verified the toolchain supports it. */
#define AWSCRT_X86_AVX512
#include "x86_target.h"
#include "aws-checksums/source/intel/intrin/crc32c_sse42_avx512.c"
#include "x86_target_end.h"
