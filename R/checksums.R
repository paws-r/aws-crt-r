#' CRC checksums
#'
#' Compute CRC32, CRC32C (Castagnoli) and CRC64NVME checksums with the
#' `aws-checksums` library from the AWS Common Runtime.
#'
#' Hardware instructions are used when the CPU supports them (SSE4.2,
#' PCLMULQDQ and AVX-512 on x86-64, CRC and PMULL on arm64), otherwise a
#' portable software implementation is used.
#'
#' @param x A raw vector, or a single string (converted to UTF-8 bytes).
#' @param previous `NULL` (start a new checksum) or the raw checksum returned
#'   by a previous call with `raw = TRUE`.
#' @param raw If `FALSE` (the default), return the checksum as a hexadecimal
#'   string. If `TRUE`, return it as a big-endian raw vector.
#' @return A hexadecimal string, or with `raw = TRUE` a big-endian raw vector
#'   (length 4 or 8).
#' @examples
#' crc32c("123456789")
#' crc64nvme("123456789")
#' crc32c("123456789", raw = TRUE)
#'
#' # Incremental
#' part1 <- crc32(charToRaw("1234"), raw = TRUE)
#' identical(crc32(charToRaw("56789"), part1), crc32("123456789"))
#' @name checksums
NULL

use_software <- function() isTRUE(getOption("awscrt.force_software", FALSE))

as_input <- function(x, call = parent.frame()) {
  if (is.raw(x)) {
    return(x)
  }
  if (is.character(x) && length(x) == 1L && !is.na(x)) {
    return(charToRaw(enc2utf8(x)))
  }
  stop("`x` must be a raw vector or a single string", call. = FALSE)
}

check_previous <- function(previous, width) {
  if (!is.null(previous) && !(is.raw(previous) && length(previous) == width)) {
    stop(
      sprintf("`previous` must be NULL or a raw vector of length %d", width),
      call. = FALSE
    )
  }
}

#' @rdname checksums
#' @export
crc32 <- function(x, previous = NULL, raw = FALSE) {
  check_previous(previous, 4L)
  .Call(awscrt_crc32, as_input(x), previous, use_software(), raw)
}

#' @rdname checksums
#' @export
crc32c <- function(x, previous = NULL, raw = FALSE) {
  check_previous(previous, 4L)
  .Call(awscrt_crc32c, as_input(x), previous, use_software(), raw)
}

#' @rdname checksums
#' @export
crc64nvme <- function(x, previous = NULL, raw = FALSE) {
  check_previous(previous, 8L)
  .Call(awscrt_crc64nvme, as_input(x), previous, use_software(), raw)
}

#' CRC checksums of a file
#'
#' Like [crc32()], [crc32c()] and [crc64nvme()] but reading the file in chunks,
#' so files larger than memory can be checksummed.
#'
#' @inheritParams checksums
#' @param path Path to a file.
#' @param chunk_size Number of bytes to read at a time. Default chunk size (1 MiB)
#' @return A hexadecimal string, or with `raw = TRUE` a big-endian raw vector,
#'   see [checksums].
#' @examples
#' f <- tempfile()
#' writeLines("hello", f)
#' crc32c_file(f)
#' unlink(f)
#' @name checksums-file
NULL

crc_file <- function(fn, path, previous, raw, chunk_size) {
  if (!(is.character(path) && length(path) == 1L && !is.na(path))) {
    stop("`path` must be a single string", call. = FALSE)
  }
  if (
    !(is.numeric(chunk_size) &&
      length(chunk_size) == 1L &&
      !is.na(chunk_size) &&
      chunk_size >= 1)
  ) {
    stop("`chunk_size` must be a positive number", call. = FALSE)
  }
  con <- file(path, "rb")
  on.exit(close(con))
  crc <- previous
  chunk <- readBin(con, "raw", n = chunk_size)
  repeat {
    nxt <- readBin(con, "raw", n = chunk_size)
    if (length(nxt) == 0L) {
      break
    }
    crc <- fn(chunk, crc, raw = TRUE)
    chunk <- nxt
  }
  # only the last chunk is formatted as requested; earlier ones are chained raw
  fn(chunk, crc, raw = raw)
}

#' @rdname checksums-file
#' @export
crc32_file <- function(
  path,
  previous = NULL,
  raw = FALSE,
  chunk_size = 1048576L
) {
  check_previous(previous, 4L)
  crc_file(crc32, path, previous, raw, chunk_size)
}

#' @rdname checksums-file
#' @export
crc32c_file <- function(
  path,
  previous = NULL,
  raw = FALSE,
  chunk_size = 1048576L
) {
  check_previous(previous, 4L)
  crc_file(crc32c, path, previous, raw, chunk_size)
}

#' @rdname checksums-file
#' @export
crc64nvme_file <- function(
  path,
  previous = NULL,
  raw = FALSE,
  chunk_size = 1048576L
) {
  check_previous(previous, 8L)
  crc_file(crc64nvme, path, previous, raw, chunk_size)
}

#' CPU features used for hardware acceleration
#'
#' @return A named logical vector of the CPU features detected at runtime by
#'   the AWS Common Runtime. Features that do not apply to the current
#'   architecture are `FALSE`.
#' @examples
#' cpu_features()
#' @export
cpu_features <- function() {
  .Call(awscrt_cpu_features)
}
