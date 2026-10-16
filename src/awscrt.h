#ifndef AWSCRT_H
#define AWSCRT_H

#include <Rinternals.h>

SEXP awscrt_crc32(SEXP x, SEXP previous, SEXP software, SEXP raw);
SEXP awscrt_crc32c(SEXP x, SEXP previous, SEXP software, SEXP raw);
SEXP awscrt_crc64nvme(SEXP x, SEXP previous, SEXP software, SEXP raw);
SEXP awscrt_cpu_features(void);

#endif
