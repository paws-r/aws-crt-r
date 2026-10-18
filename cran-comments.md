## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new release.

## Resubmission

* Removed the non-portable `-mavx`, `-mavx2`, `-mavx512f`, `-mavx512vl`,
  `-mpclmul`, `-msse4.2` and `-mvpclmulqdq` compiler flags. The x86_64 SIMD
  code is now compiled with `#pragma GCC target` / `#pragma clang attribute`
  (as the ARM code already was), and `./configure` probes with the same pragmas.
  The code is only reached after a runtime CPU feature check.
* Quoted technical terms in the DESCRIPTION. The remaining flagged words
  (CRC, CRC32, CRC32C, CRC64NVME, SSE4.2, PCLMULQDQ, AVX-512, ARMv8, PMULL,
  checksums) are correct technical terms.
