#include <limits.h>
#include <stdint.h>

#include <R.h>
#include <Rinternals.h>

#include <aws/checksums/crc.h>
#include <aws/checksums/private/crc32_priv.h>
#include <aws/checksums/private/crc64_priv.h>
#include <aws/common/cpuid.h>

#include "awscrt.h"

/* Checksums are accepted as big-endian raw vectors and returned either as raw
 * vectors or as lower-case hex strings. */

static uint64_t be_to_u64(SEXP raw, int width) {
  const Rbyte *p = RAW(raw);
  uint64_t v = 0;
  for (int i = 0; i < width; i++) {
    v = (v << 8) | p[i];
  }
  return v;
}

static SEXP u64_to_be(uint64_t v, int width) {
  SEXP out = PROTECT(Rf_allocVector(RAWSXP, width));
  Rbyte *p = RAW(out);
  for (int i = width - 1; i >= 0; i--) {
    p[i] = (Rbyte)(v & 0xff);
    v >>= 8;
  }
  UNPROTECT(1);
  return out;
}

static SEXP u64_to_hex(uint64_t v, int width) {
  static const char digits[] = "0123456789abcdef";
  char buf[17];
  for (int i = 2 * width - 1; i >= 0; i--) {
    buf[i] = digits[v & 0xf];
    v >>= 4;
  }
  buf[2 * width] = '\0';
  return Rf_ScalarString(Rf_mkChar(buf));
}

static SEXP checksum_result(uint64_t v, int width, SEXP raw) {
  if (TYPEOF(raw) != LGLSXP || XLENGTH(raw) != 1 || LOGICAL(raw)[0] == NA_LOGICAL) {
    Rf_error("`raw` must be TRUE or FALSE");
  }
  return LOGICAL(raw)[0] ? u64_to_be(v, width) : u64_to_hex(v, width);
}

static uint64_t read_previous(SEXP previous, int width) {
  if (previous == R_NilValue) {
    return 0;
  }
  if (TYPEOF(previous) != RAWSXP || XLENGTH(previous) != width) {
    Rf_error("`previous` must be NULL or a raw vector of length %d", width);
  }
  return be_to_u64(previous, width);
}

static int flag_software(SEXP software) {
  if (TYPEOF(software) != LGLSXP || XLENGTH(software) != 1 || LOGICAL(software)[0] == NA_LOGICAL) {
    Rf_error("`software` must be TRUE or FALSE");
  }
  return LOGICAL(software)[0];
}

static void check_input(SEXP x) {
  if (TYPEOF(x) != RAWSXP) {
    Rf_error("`x` must be a raw vector");
  }
}

/* The explicitly-software path bypasses runtime dispatch. These take `int`
 * lengths, so feed them at most INT_MAX bytes at a time. */
#define SOFTWARE_LOOP(T, fn, buf, len, crc)           \
  do {                                                \
    const uint8_t *p_ = (buf);                        \
    size_t n_ = (len);                                \
    while (n_ > (size_t)INT_MAX) {                    \
      crc = (T)fn(p_, INT_MAX, crc);                  \
      p_ += INT_MAX;                                  \
      n_ -= (size_t)INT_MAX;                          \
    }                                                 \
    crc = (T)fn(p_, (int)n_, crc);                    \
  } while (0)

SEXP awscrt_crc32(SEXP x, SEXP previous, SEXP software, SEXP raw) {
  check_input(x);
  uint32_t crc = (uint32_t)read_previous(previous, 4);
  const uint8_t *buf = (const uint8_t *)RAW(x);
  size_t len = (size_t)XLENGTH(x);
  if (flag_software(software)) {
    SOFTWARE_LOOP(uint32_t, aws_checksums_crc32_sw, buf, len, crc);
  } else {
    crc = aws_checksums_crc32_ex(buf, len, crc);
  }
  return checksum_result(crc, 4, raw);
}

SEXP awscrt_crc32c(SEXP x, SEXP previous, SEXP software, SEXP raw) {
  check_input(x);
  uint32_t crc = (uint32_t)read_previous(previous, 4);
  const uint8_t *buf = (const uint8_t *)RAW(x);
  size_t len = (size_t)XLENGTH(x);
  if (flag_software(software)) {
    SOFTWARE_LOOP(uint32_t, aws_checksums_crc32c_sw, buf, len, crc);
  } else {
    crc = aws_checksums_crc32c_ex(buf, len, crc);
  }
  return checksum_result(crc, 4, raw);
}

SEXP awscrt_crc64nvme(SEXP x, SEXP previous, SEXP software, SEXP raw) {
  check_input(x);
  uint64_t crc = read_previous(previous, 8);
  const uint8_t *buf = (const uint8_t *)RAW(x);
  size_t len = (size_t)XLENGTH(x);
  if (flag_software(software)) {
    SOFTWARE_LOOP(uint64_t, aws_checksums_crc64nvme_sw, buf, len, crc);
  } else {
    crc = aws_checksums_crc64nvme_ex(buf, len, crc);
  }
  return checksum_result(crc, 8, raw);
}

SEXP awscrt_cpu_features(void) {
  static const struct {
    const char *name;
    enum aws_cpu_feature_name feature;
  } features[] = {
    {"clmul", AWS_CPU_FEATURE_CLMUL},
    {"sse4.1", AWS_CPU_FEATURE_SSE_4_1},
    {"sse4.2", AWS_CPU_FEATURE_SSE_4_2},
    {"avx2", AWS_CPU_FEATURE_AVX2},
    {"avx512", AWS_CPU_FEATURE_AVX512},
    {"vpclmulqdq", AWS_CPU_FEATURE_VPCLMULQDQ},
    {"arm_crc", AWS_CPU_FEATURE_ARM_CRC},
    {"arm_pmull", AWS_CPU_FEATURE_ARM_PMULL},
    {"arm_crypto", AWS_CPU_FEATURE_ARM_CRYPTO},
  };
  const int n = (int)(sizeof(features) / sizeof(features[0]));
  SEXP out = PROTECT(Rf_allocVector(LGLSXP, n));
  SEXP names = PROTECT(Rf_allocVector(STRSXP, n));
  for (int i = 0; i < n; i++) {
    LOGICAL(out)[i] = aws_cpu_has_feature(features[i].feature) ? 1 : 0;
    SET_STRING_ELT(names, i, Rf_mkChar(features[i].name));
  }
  Rf_setAttrib(out, R_NamesSymbol, names);
  UNPROTECT(2);
  return out;
}
