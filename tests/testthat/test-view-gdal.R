test_that("cog_tiles() counts a temporary COG's tiles with its overviews", {
  expect_equal(cog_tiles(512, 512), 1)
  expect_equal(cog_tiles(513, 512), 2 + 1)
  expect_equal(cog_tiles(8192, 8192), 256 + 64 + 16 + 4 + 1)
  expect_equal(cog_tiles(1024, 256), 2 + 1)
})

test_that("a huge virtual grid (VRT) is read through GDAL, only as much as the plan draws", {
  skip_if_no_terra()
  vrt <- huge_vrt(small_merc_tif())
  r <- terra::rast(vrt)
  ## A planetary grid: 2^48 cells, which terra would write whole to a COG
  ## (raster_temp_cog()), far more tiles than any plan draws.
  expect_equal(terra::ncell(r), 2^48)
  expect_null(raster_cog_source(r))
  expect_gt(cog_tiles(2^24, 2^24), 1024)
  t0 <- Sys.time()
  seen <- gdal_temp_seen(
    expect_message(v <- view(r, max_tiles = 64, file = html()),
                   "read through GDAL from a dataset of 16777216 x 16777216 cells")
  )
  expect_lt(as.numeric(Sys.time() - t0, units = "secs"), 60)
  ## The finest reduction whose COG fits 64 tiles: 2048 x 2048 (16 + 4 + 1
  ## tiles), not the full grid.
  expect_equal(seen$gs$factor, 2^13)
  expect_equal(seen$dim, c(2048, 2048))
  expect_lt(seen$bytes, 4 * 2^20)
  expect_lte(cog_tiles(seen$dim[1], seen$dim[2]), 64)
  ## Every planned level is drawn (no level is left out for the budget).
  expect_length(v$scene$layers[[1]]$plan$levels, 3)
  ## The cells are the source's, through GDAL: the small file's ramp.
  expect_equal(range(seen$values), c(1, 250))
  expect_true(file.exists(v$file))
})

test_that("with `extent`, only that part of the grid is read, in more detail", {
  skip_if_no_terra()
  r <- terra::rast(huge_vrt(small_merc_tif()))
  ## One sixteenth of the square on a side (an east-west strip of the
  ## south-west quadrant), in the dataset's own CRS.
  ext <- c(-merc, -merc + merc / 8, -merc, -merc + merc / 16)
  gs <- raster_gdal_source(r, "EPSG:3857", list(extent = ext, max_tiles = 64))
  expect_equal(gs$window, c(0, 2^24 - 2^19, 2^20, 2^19))
  expect_equal(gs$factor, 2^8)
  expect_equal(gs$size, c(4096, 2048))
  ## In another view CRS the extent is transformed to the dataset's.
  ll <- raster_gdal_source(r, "EPSG:4326", list(extent = c(100, 160, -50, -10),
                                                max_tiles = 64))
  expect_true(all(ll$window[3:4] < 2^24 / 4))
  expect_true(all(ll$size <= 4096))
  seen <- gdal_temp_seen(expect_message(
    v <- view(r, extent = ext, max_tiles = 64, file = html()),
    "over 1048576 x 524288 cells .*A smaller `extent`"
  ))
  expect_equal(seen$dim, c(4096, 2048))
  ## A plan for one view reads no finer than its pixel needs.
  one <- raster_gdal_source(r, "EPSG:3857", list(extent = ext, units_per_pixel = 20000,
                                                 max_tiles = 64))
  expect_equal(one$factor, 2^13)
  expect_lte(2 * merc / 2^24 * one$factor, 20000)
  ## An extent that misses the grid reads the whole grid, and the message
  ## does not suggest passing `extent`.
  miss <- c(3e7, 3.1e7, 3e7, 3.1e7)
  gs <- raster_gdal_source(r, "EPSG:3857", list(extent = miss, max_tiles = 16))
  expect_equal(gs$window, c(0, 0, 2^24, 2^24))
  expect_message(cog <- gdal_temp_cog(gs, 1L, rgb = FALSE, name = "r"),
                 "\\(1024 x 1024\\): .* can draw\\. A larger `max_tiles` shows more detail")
  unlink(cog$dsn)
})

test_that("a huge colour image takes its alpha from the dataset's mask, not a cell scan", {
  skip_if_no_terra()
  src <- small_merc_tif(3L, nodata = 0)
  r <- terra::rast(huge_vrt(src, 3L, interp = c("Red", "Green", "Blue"), nodata = 0))
  seen <- gdal_temp_seen(expect_message(v <- view(r, max_tiles = 16, file = html()),
                                        "read through GDAL"))
  expect_identical(v$scene$layers[[1]]$rgb, list(bands = 1:3, alpha = 4L))
  expect_equal(seen$cog$samples_per_pixel, 4L)
  alpha <- seen$values[, 4]
  ## The no-data corner (a sixteenth of the image) is transparent.
  expect_equal(mean(alpha == 0), 1 / 16, tolerance = 0.01)
  expect_true(all(alpha %in% c(0, 255)))
})

test_that("a dataset whose full grid fits the plan is written by terra as before", {
  skip_if_no_terra()
  r <- terra::rast(huge_vrt(small_merc_tif(), n = 4096))
  expect_null(raster_gdal_source(r, "EPSG:3857", list()))
  ## ... unless `max_tiles` says it is too big to draw whole.
  expect_false(is.null(raster_gdal_source(r, "EPSG:3857", list(max_tiles = 16))))
  ## A changed raster is not its dataset, so it is not read through GDAL.
  expect_null(raster_gdal_source(r * 2, "EPSG:3857", list(max_tiles = 16)))
  expect_null(raster_gdal_source(terra::crop(r, terra::ext(r) / 2), "EPSG:3857",
                                 list(max_tiles = 16)))
  big <- terra::rast(huge_vrt(small_merc_tif()))
  terra::NAflag(big) <- 7
  expect_null(raster_gdal_source(big, "EPSG:3857", list()))
})

test_that("a tile service (GDAL WMS, TMS minidriver) is read through GDAL from a local server", {
  skip_on_cran()
  skip_if_no_terra()
  skip_if_not_installed("httpuv")
  skip_if(!nrow(gdalraster::gdal_formats("WMS")), "GDAL has no WMS driver")
  dir <- xyz_tiles()
  ## Static files are served on httpuv's own thread, so GDAL's requests are
  ## answered while R waits for them; a missing tile is a 404.
  port <- httpuv::randomPort()
  srv <- httpuv::startServer("127.0.0.1", port, list(
    call = function(req) list(status = 404L, headers = list(), body = ""),
    staticPaths = list("/" = httpuv::staticPath(dir, indexhtml = FALSE, fallthrough = FALSE))
  ))
  on.exit(srv$stop(), add = TRUE)
  r <- terra::rast(tms_xml(paste0("http://127.0.0.1:", port)))
  expect_equal(terra::ncol(r), 2^26)
  t0 <- Sys.time()
  seen <- gdal_temp_seen(
    expect_message(v <- view(r, max_tiles = 16, file = html()), "read through GDAL")
  )
  expect_lt(as.numeric(Sys.time() - t0, units = "secs"), 60)
  ## 1024 x 1024 cells (4 + 1 tiles): zoom 2, 16 tile requests.
  expect_equal(seen$dim, c(1024, 1024))
  expect_identical(v$scene$layers[[1]]$rgb, list(bands = 1:3))
  blue <- matrix(seen$values[, 3], 1024, byrow = TRUE)
  ## Zoom 2's tiles (blue 250), and the missing one (south-east) is empty.
  expect_equal(blue[100, 100], 250)
  expect_equal(blue[1000, 1000], 0)
  expect_equal(mean(blue == 0), 1 / 16)
})
