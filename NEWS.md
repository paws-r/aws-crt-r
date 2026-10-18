# awscrt 0.1.1

* x86_64 SIMD code is now enabled with compiler pragmas instead of `-m` flags (as ARM already was), so the build no longer uses non-portable compiler flags.

# awscrt 0.1.0

* Initial implementation: `crc32()`, `crc32c()`, `crc64nvme()` and their `_file()` variants, backed by vendored aws-checksums v1.0.1 and aws-c-common v1.0.3.
