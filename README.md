<!-- badges: start -->
[![R-CMD-check](https://github.com/paws-r/aws-crt-r/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/paws-r/aws-crt-r/actions/workflows/R-CMD-check.yaml)
[![Codecov test coverage](https://codecov.io/gh/paws-r/aws-crt-r/graph/badge.svg)](https://app.codecov.io/gh/paws-r/aws-crt-r)
[![R-universe version](https://paws-r.r-universe.dev/awscrt/badges/version)](https://paws-r.r-universe.dev/awscrt)
<!-- badges: end -->

# awscrt

R bindings to the CRC routines of the [AWS Common Runtime](https://github.com/awslabs/aws-crt-python):
**CRC32, CRC32C and CRC64NVME**, hardware-accelerated where the CPU allows it, with a
portable software fallback. Output is byte-for-byte what Python's `awscrt.checksums`
produces (as big-endian bytes), which is what S3 flexible checksums use.

Only `aws-checksums` (and the small part of `aws-c-common` it needs) is vendored. There is
no HTTP, TLS, event loop or threading, and nothing is downloaded at install time.

```r
library(awscrt)

crc32c("123456789")               # "e3069283"
crc64nvme("123456789")            # "ae8b14860a799888"
crc32c("123456789", raw = TRUE)   # raw vector, big-endian: e3 06 92 83

# Incremental hashing: pass the previous (raw) result back in
a <- crc32c(charToRaw("1234"), raw = TRUE)
identical(crc32c(charToRaw("56789"), a), crc32c("123456789"))

crc32c_file("big.bin")            # chunked read, constant memory
cpu_features()                    # what the runtime dispatch can use
```

Results are hexadecimal strings by default, because a 64-bit CRC does not fit in an R
double. Use `raw = TRUE` for the big-endian raw vector, which is also the form `previous`
expects.
Base64-encoding for HTTP headers is left to the caller.

## Build notes

`./configure` probes the compiler for SSE4.2 / PCLMULQDQ / AVX-512 (x86-64) or CRC / PMULL
(arm64), writes `src/generated/aws/common/config.h` and `src/Makevars`, and applies the SIMD
flags only to the files that need them. CPU support is still checked at run time. Windows
(MinGW) always uses the software path, as upstream does. To force a software-only build:

```sh
R CMD INSTALL --configure-vars='AWSCRT_SOFTWARE_ONLY=1' .
```

At run time `options(awscrt.force_software = TRUE)` bypasses hardware dispatch.

Refresh the vendored sources with `tools/update-vendor.sh`.
