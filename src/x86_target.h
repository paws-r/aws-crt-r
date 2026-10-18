/* Enables the x86_64 SIMD features used by the vendored intrinsics code. The
 * runtime CPU dispatch (aws_cpu_has_feature) keeps these paths from running on
 * hardware that lacks them, so each file must enable only the features its
 * dispatch condition checks: the compiler may use any enabled feature anywhere
 * in the file.
 *
 * Define AWSCRT_X86_AVX512 before including this header for the AVX-512 files;
 * otherwise only AVX2 + PCLMUL are enabled. Include the system headers first so
 * the pragma only affects the vendored code. */
#include <emmintrin.h>
#include <immintrin.h>
#include <smmintrin.h>
#include <wmmintrin.h>

#if defined(AWSCRT_X86_AVX512)
#    if defined(__clang__)
#        pragma clang attribute push(__attribute__((target("avx512f,avx512vl,vpclmulqdq,pclmul,avx2,avx,sse4.2"))), apply_to = function)
#    elif defined(__GNUC__)
#        pragma GCC push_options
#        pragma GCC target("avx512f,avx512vl,vpclmulqdq,pclmul,avx2,avx,sse4.2")
#    endif
#else
#    if defined(__clang__)
#        pragma clang attribute push(__attribute__((target("pclmul,avx2,avx,sse4.2"))), apply_to = function)
#    elif defined(__GNUC__)
#        pragma GCC push_options
#        pragma GCC target("pclmul,avx2,avx,sse4.2")
#    endif
#endif
