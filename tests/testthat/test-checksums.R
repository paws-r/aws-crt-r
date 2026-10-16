# Expected values for the fixed inputs below come from Python's awscrt:
#   n = awscrt.checksums.crc32c(data); n.to_bytes(4, "big").hex()
# (8 bytes for crc64nvme).
vectors <- list(
  empty = list(
    x = raw(),
    crc32 = "00000000",
    crc32c = "00000000",
    crc64nvme = "0000000000000000"
  ),
  a = list(
    x = charToRaw("a"),
    crc32 = "e8b7be43",
    crc32c = "c1d04330",
    crc64nvme = "8c2f8445b4cbfc3c"
  ),
  hello = list(
    x = charToRaw("hello world"),
    crc32 = "0d4a1185",
    crc32c = "c99465aa",
    crc64nvme = "8d29d5c3f6ea8ebe"
  ),
  check = list(
    x = charToRaw("123456789"),
    crc32 = "cbf43926",
    crc32c = "e3069283",
    crc64nvme = "ae8b14860a799888"
  ),
  zeros64 = list(
    x = raw(64),
    crc32 = "758d6336",
    crc32c = "03c8eb67",
    crc64nvme = "3645476059d9ead6"
  ),
  seq1000 = list(
    x = as.raw((seq_len(1000) - 1L) %% 256L),
    crc32 = "74e3fb41",
    crc32c = "1a318e30",
    crc64nvme = "60afad17781dc9c7"
  ),
  seq100000 = list(
    x = as.raw(((seq_len(100000) - 1L) * 7L + 3L) %% 256L),
    crc32 = "f730caa8",
    crc32c = "96f31dc6",
    crc64nvme = "15aab1273fadf101"
  )
)

algorithms <- list(crc32 = crc32, crc32c = crc32c, crc64nvme = crc64nvme)
widths <- c(crc32 = 4L, crc32c = 4L, crc64nvme = 8L)

# Run each test on both the dispatched (hardware where available) and the
# forced-software code paths.
for (software in c(FALSE, TRUE)) {
  label <- if (software) "software" else "default"

  test_that(paste("matches Python awscrt on fixed inputs:", label), {
    withr_options <- options(awscrt.force_software = software)
    on.exit(options(withr_options))
    for (v in names(vectors)) {
      for (alg in names(algorithms)) {
        info <- paste(alg, v)
        expect_identical(
          algorithms[[alg]](vectors[[v]]$x),
          vectors[[v]][[alg]],
          info = info
        )
        out <- algorithms[[alg]](vectors[[v]]$x, raw = TRUE)
        expect_type(out, "raw")
        expect_length(out, widths[[alg]])
        expect_identical(
          paste(out, collapse = ""),
          vectors[[v]][[alg]],
          info = info
        )
      }
    }
  })

  test_that(paste("incremental equals one-shot:", label), {
    withr_options <- options(awscrt.force_software = software)
    on.exit(options(withr_options))
    set.seed(1)
    buf <- as.raw(sample(0:255, 5000, replace = TRUE))
    for (alg in names(algorithms)) {
      fn <- algorithms[[alg]]
      whole <- fn(buf, raw = TRUE)
      for (i in 1:20) {
        cut <- sample(0:length(buf), 1)
        first <- buf[seq_len(cut)]
        rest <- buf[seq_len(length(buf) - cut) + cut]
        expect_identical(
          fn(rest, fn(first, raw = TRUE), raw = TRUE),
          whole,
          info = alg
        )
      }
      # three-way split
      expect_identical(
        fn(
          buf[4001:5000],
          fn(buf[1001:4000], fn(buf[1:1000], raw = TRUE), raw = TRUE),
          raw = TRUE
        ),
        whole
      )
    }
  })
}

test_that("hardware and software paths agree on random buffers", {
  set.seed(2)
  for (n in c(0, 1, 7, 8, 15, 16, 63, 64, 65, 255, 256, 1023, 4096, 65537)) {
    buf <- as.raw(sample(0:255, n, replace = TRUE))
    for (alg in names(algorithms)) {
      options(awscrt.force_software = FALSE)
      hw <- algorithms[[alg]](buf, raw = TRUE)
      options(awscrt.force_software = TRUE)
      sw <- algorithms[[alg]](buf, raw = TRUE)
      options(awscrt.force_software = FALSE)
      expect_identical(hw, sw, info = paste(alg, n))
    }
  }
})

test_that("empty input returns `previous` (zero for the first call)", {
  for (alg in names(algorithms)) {
    fn <- algorithms[[alg]]
    expect_identical(fn(raw(), raw = TRUE), raw(widths[[alg]]))
    expect_identical(fn(raw()), strrep("0", 2L * widths[[alg]]))
    prev <- fn(charToRaw("abc"), raw = TRUE)
    expect_identical(fn(raw(), prev, raw = TRUE), prev)
  }
})

test_that("`previous = NULL` equals an explicit zero", {
  for (alg in names(algorithms)) {
    fn <- algorithms[[alg]]
    expect_identical(
      fn(charToRaw("abc"), raw(widths[[alg]]), raw = TRUE),
      fn(charToRaw("abc"), raw = TRUE)
    )
  }
})

test_that("single strings are hashed as UTF-8 bytes", {
  expect_identical(crc32c("123456789"), crc32c(charToRaw("123456789")))
  expect_identical(crc32("é"), crc32(as.raw(c(0xc3, 0xa9))))
  expect_identical(
    crc32c("123456789", raw = TRUE),
    crc32c(charToRaw("123456789"), raw = TRUE)
  )
})

test_that("bad input is rejected", {
  expect_error(crc32(1:3), "raw vector")
  expect_error(crc32(c("a", "b")), "raw vector")
  expect_error(crc32(NA_character_), "raw vector")
  expect_error(crc32(NULL), "raw vector")
  expect_error(crc32(raw(1), raw(8)), "length 4")
  expect_error(crc64nvme(raw(1), raw(4)), "length 8")
  expect_error(crc32c(raw(1), 1L), "length 4")
  # hex output is not accepted as `previous`
  expect_error(crc32(raw(1), crc32(raw(1))), "length 4")
})

test_that("file variants match in-memory results", {
  f <- tempfile()
  on.exit(unlink(f))
  set.seed(3)
  buf <- as.raw(sample(0:255, 100003, replace = TRUE))
  writeBin(buf, f)
  expect_identical(crc32_file(f), crc32(buf))
  expect_identical(crc32c_file(f, chunk_size = 1000L), crc32c(buf))
  expect_identical(crc64nvme_file(f, chunk_size = 4096L), crc64nvme(buf))
  expect_identical(
    crc64nvme_file(f, raw = TRUE, chunk_size = 4096L),
    crc64nvme(buf, raw = TRUE)
  )
  # chunk size larger than the file, and previous chaining
  expect_identical(crc32c_file(f, chunk_size = 10^7), crc32c(buf))
  head <- crc32c(buf[1:10], raw = TRUE)
  writeBin(buf[11:length(buf)], f)
  expect_identical(crc32c_file(f, previous = head), crc32c(buf))
  # empty file
  file.create(f)
  expect_identical(crc64nvme_file(f, raw = TRUE), raw(8))
  expect_identical(crc64nvme_file(f), strrep("0", 16L))
  expect_error(suppressWarnings(crc32_file(file.path(
    tempdir(),
    "does-not-exist"
  ))))
})

test_that("`raw` selects hex string or big-endian raw output", {
  expect_identical(crc32("123456789"), "cbf43926")
  expect_identical(
    crc32("123456789", raw = TRUE),
    as.raw(c(0xcb, 0xf4, 0x39, 0x26))
  )
  expect_identical(crc32("123456789", raw = FALSE), crc32("123456789"))
})

test_that("cpu_features returns a named logical vector", {
  f <- cpu_features()
  expect_type(f, "logical")
  expect_false(anyNA(f))
  expect_true(all(nzchar(names(f))))
})

test_that("large buffers are chunked safely", {
  skip_on_cran()
  skip_if(
    Sys.getenv("AWSCRT_LARGE_TESTS") != "true",
    "set AWSCRT_LARGE_TESTS=true to run"
  )
  # > INT_MAX bytes exercises the chunk loop in the C layer
  big <- raw(2^31 + 10)
  one <- crc32c(big)
  split <- crc32c(
    big[(2^30 + 1):length(big)],
    crc32c(big[1:2^30], raw = TRUE)
  )
  expect_identical(one, split)
})
