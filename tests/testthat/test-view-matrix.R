# view() of a matrix or array with an extent and CRS (#37). Polar first:
# EPSG:3031 throughout, lon/lat where the view CRS rule is the point.

ext31 <- c(-3e6, 3e6, -2e6, 2e6)

# The values column of an untiled raster layer's blob, as written.
raster_values <- function(v, i = 1L) {
  l <- v$scene$layers[[i]]
  as.data.frame(nanoarrow::read_nanoarrow(aobcore::scene_blobs(v$scene)[[l$values]]))$value
}

# Run view() and return what grid_temp_cog() wrote: the COG's structure and
# its cell values by band (the file itself is deleted once the page is
# written).
grid_temp_seen <- function(expr) {
  seen <- new.env()
  real <- grid_temp_cog
  local_mocked_bindings(grid_temp_cog = function(g, rgb) {
    cog <- real(g, rgb)
    seen$cog <- cog
    ds <- gdalraster::GDALRaster$new(cog$dsn)
    d <- ds$dim()
    seen$values <- lapply(seq_len(d[3]), function(b) ds$read(b, 0L, 0L, d[1], d[2], d[1], d[2]))
    seen$nodata <- ds$getNoDataValue(1L)
    ds$close()
    cog
  }, .env = parent.frame())
  seen$value <- force(expr)
  expect_false(file.exists(seen$cog$dsn))
  seen
}

test_that("a small matrix in EPSG:3031 is drawn untiled, in the page", {
  m <- matrix(seq_len(12), nrow = 3, ncol = 4, byrow = TRUE)
  v <- view(m, extent = ext31, crs = "EPSG:3031", file = html())
  expect_s3_class(v, "aob_view")
  expect_identical(v$scene$view$crs, "EPSG:3031")
  expect_identical(layer_kinds(v), "raster")
  l <- v$scene$layers[[1]]
  expect_identical(l$id, "m")
  expect_identical(l$label, "m")
  expect_identical(l$grid, list(crs = "EPSG:3031", extent = ext31, dim = c(4L, 3L)))
  expect_identical(l$values, "m_values")
  expect_identical(l$values_column, "value")
  expect_identical(l$palette, list(name = "viridis", range = c(1, 12)))
  expect_identical(v$scene$data$m_values, list(format = "arrow-ipc-stream", blob = "m_values"))
  expect_identical(raster_values(v), as.numeric(1:12))
  expect_equal(v$scene$view$extent, ext31)
  ## No COG, no tiles, not 0.5: a 0.1 raster layer (0.4 for the view's bounds).
  expect_length(tile_blobs(v), 0L)
  expect_null(v$scene$legends)
  expect_true(numeric_version(v$scene$version) < "0.5")
  expect_match(page_text(v), "data-aob-blob", fixed = TRUE)
  expect_output(print(v), "1 layer in EPSG:3031")
  expect_valid_scene(v)
  ## The CRS as a number, and a palette and range of the user's.
  v2 <- view(m, extent = ext31, crs = 3031, palette = "gray", range = c(0, 20), file = html())
  expect_identical(v2$scene$view$crs, "EPSG:3031")
  expect_identical(v2$scene$layers[[1]]$palette, list(name = "gray", range = c(0, 20)))
})

test_that("row 1 of the matrix is the top of the grid", {
  m <- matrix(0, nrow = 3, ncol = 4)
  m[1, 1] <- 7    # top-left
  m[3, 4] <- 9    # bottom-right
  m[1, 4] <- 5    # top-right
  v <- view(m, extent = ext31, crs = "EPSG:3031", file = html())
  vals <- raster_values(v)
  ## Row-major from the top: cell 1 is row 0 (ymax) column 0 (xmin).
  expect_identical(vals[1], 7)
  expect_identical(vals[4], 5)
  expect_identical(vals[12], 9)
  expect_identical(matrix(vals, nrow = 3, byrow = TRUE), m)
  ## The same through a temporary COG: the file's first row is the top.
  skip_if_no_terra()
  big <- matrix(0, nrow = 3, ncol = 600)
  big[1, 1] <- 7
  big[3, 600] <- 9
  seen <- grid_temp_seen(v2 <- view(big, extent = ext31, crs = "EPSG:3031", file = html()))
  expect_identical(layer_kinds(v2), "tiled_raster")
  expect_identical(seen$values[[1]][1], 7)
  expect_identical(seen$values[[1]][1800], 9)
  expect_identical(seen$cog$levels[[1]]$dim, c(600L, 3L))
  expect_equal(seen$cog$levels[[1]]$extent, ext31)
})

test_that("a logical matrix draws as 0 and 1, with NA as no data", {
  m <- matrix(c(TRUE, FALSE, NA, TRUE, TRUE, FALSE), nrow = 2, byrow = TRUE)
  v <- view(m, extent = c(0, 3e5, 0, 2e5), crs = "EPSG:3031", palette = "gray", file = html())
  expect_identical(layer_kinds(v), "raster")
  expect_identical(v$scene$layers[[1]]$palette, list(name = "gray", range = c(0, 1)))
  expect_identical(raster_values(v), c(1, 0, NA, 1, 1, 0))
  expect_valid_scene(v)
  ## A constant matrix gets a range it can key.
  v2 <- view(matrix(4, 2, 2), extent = c(0, 3e5, 0, 2e5), crs = "EPSG:3031", file = html())
  expect_identical(v2$scene$layers[[1]]$palette$range, c(3.5, 4.5))
})

test_that("a 3-band array draws as a colour image through a temporary COG", {
  skip_if_no_terra()
  img <- array(0, c(10, 20, 3))
  img[, , 1] <- 255
  img[, , 2] <- 100
  img[, , 3] <- matrix(rep(0:19 * 10, each = 10), 10, 20)
  seen <- grid_temp_seen(v <- view(img, extent = ext31, crs = "EPSG:3031", file = html()))
  expect_identical(layer_kinds(v), "tiled_raster")
  l <- v$scene$layers[[1]]
  expect_identical(l$id, "img")
  expect_identical(l$rgb, list(bands = 1:3))
  expect_null(l$palette)
  expect_true(numeric_version(v$scene$version) >= "0.3")
  expect_identical(v$scene$data$img$format, "cog")
  expect_match(v$scene$data$img$url, "^view-.*[.]tif$")
  expect_gt(length(tile_blobs(v)), 0L)
  expect_identical(seen$cog$levels[[1]]$encoding$dtype, "uint8")
  expect_identical(seen$cog$samples_per_pixel, 3L)
  expect_equal(seen$values[[1]][1:3], c(255, 255, 255))
  expect_equal(seen$values[[3]][1:3], c(0, 10, 20))
  ## No legend for a colour image.
  expect_null(v$scene$legends)
  expect_valid_scene(v)
  ## A missing cell becomes transparent: an alpha band is added.
  img[2, 3, 1] <- NA
  seen <- grid_temp_seen(v2 <- view(img, extent = ext31, crs = "EPSG:3031", file = html()))
  expect_identical(v2$scene$layers[[1]]$rgb, list(bands = 1:3, alpha = 4L))
  expect_identical(seen$cog$samples_per_pixel, 4L)
  i <- (2 - 1) * 20 + 3
  expect_equal(vapply(seen$values, function(b) as.numeric(b[i]), 0), c(0, 100, 20, 0))
  expect_equal(vapply(seen$values, function(b) as.numeric(b[1L]), 0), c(255, 100, 0, 255))
  ## Four bands: the fourth is alpha.
  rgba <- array(c(img[, , 1:3], matrix(128, 10, 20)), c(10, 20, 4))
  rgba[2, 3, 1] <- 0
  v3 <- view(rgba, extent = ext31, crs = "EPSG:3031", file = html())
  expect_identical(v3$scene$layers[[1]]$rgb, list(bands = 1:3, alpha = 4L))
  ## Values beyond Byte: Float32 with a range.
  seen <- grid_temp_seen(v4 <- view(img * 2.5, extent = ext31, crs = "EPSG:3031", file = html()))
  expect_identical(seen$cog$levels[[1]]$encoding$dtype, "float32")
  expect_length(v4$scene$layers[[1]]$rgb$range, 2L)
  ## A one-band array is the matrix.
  v5 <- view(img[, , 3, drop = FALSE], extent = ext31, crs = "EPSG:3031", file = html())
  expect_identical(layer_kinds(v5), "raster")
  expect_identical(v5$scene$layers[[1]]$grid$dim, c(20L, 10L))
  expect_error(view(img, extent = ext31, crs = "EPSG:3031", palette = "gray", file = html()),
               "colour image")
})

test_that("a large matrix takes the COG route", {
  skip_if_no_terra()
  skip_on_cran()
  n <- untiled_max() + 1L
  m <- matrix(seq_len(n * 40) %% 97, nrow = 40, ncol = n)
  m[5, 5] <- NA
  seen <- grid_temp_seen(v <- view(m, extent = ext31, crs = "EPSG:3031", file = html()))
  expect_identical(layer_kinds(v), "tiled_raster")
  l <- v$scene$layers[[1]]
  expect_identical(l$plan$crs, "EPSG:3031")
  expect_identical(l$palette, list(name = "viridis", range = c(0, 96)))
  expect_identical(v$scene$data$m$format, "cog")
  expect_match(v$scene$data$m$url, "^view-.*[.]tif$")
  expect_gt(length(tile_blobs(v)), 0L)
  expect_identical(seen$cog$levels[[1]]$dim, c(n, 40L))
  expect_identical(seen$cog$levels[[1]]$encoding$dtype, "float32")
  expect_true(is.na(seen$values[[1]][(5 - 1) * n + 5]))
  expect_equal(seen$nodata, float_nodata)
  expect_equal(v$scene$view$extent, ext31)
  expect_valid_scene(v)
  ## The tile plan's arguments pass through: too few tiles drops a level.
  expect_warning(v2 <- view(m, extent = ext31, crs = "EPSG:3031", max_tiles = 2, file = html()),
                 "max_tiles")
  expect_lt(length(tile_blobs(v2)), length(tile_blobs(v)))
  expect_error(view(m, extent = ext31, crs = "EPSG:3031", nonsense = 1, file = html()),
               "nonsense")
  ## Exactly the threshold is still untiled.
  m2 <- matrix(1, nrow = untiled_max(), ncol = 2)
  expect_identical(layer_kinds(view(m2, extent = ext31, crs = "EPSG:3031", file = html())),
                   "raster")
})

test_that("a lon/lat matrix south of 40S is drawn in EPSG:3031, tiled", {
  skip_if_no_terra()
  m <- matrix(seq_len(72 * 20), nrow = 20, ncol = 72)
  e <- c(-180, 180, -90, -40)
  expect_identical(view_crs(m, extent = e, crs = "OGC:CRS84"), "EPSG:3031")
  expect_identical(view_crs(m, extent = c(-180, 180, -30, 30), crs = "OGC:CRS84"), "OGC:CRS84")
  expect_identical(view_crs(m, extent = ext31, crs = "EPSG:3031"), "EPSG:3031")
  v <- view(m, extent = e, crs = "OGC:CRS84", palette = "ocean", file = html())
  expect_identical(v$scene$view$crs, "EPSG:3031")
  expect_identical(layer_kinds(v), "tiled_raster")
  expect_identical(v$scene$layers[[1]]$palette$name, "ocean")
  expect_identical(v$scene$layers[[1]]$plan$crs, "EPSG:3031")
  ## The meshes are projected: the initial view is metres around the pole.
  ext <- v$scene$view$extent
  expect_true(ext[1] < 0 && ext[2] > 0 && ext[3] < 0 && ext[4] > 0)
  expect_gt(ext[2], 1e6)
  ## The same grid, flat in its own CRS, is untiled.
  v2 <- view(m, extent = c(-180, 180, -30, 30), crs = "OGC:CRS84", file = html())
  expect_identical(v2$scene$view$crs, "OGC:CRS84")
  expect_identical(layer_kinds(v2), "raster")
})

test_that("a matrix without an extent or CRS is an error, as are bad ones", {
  m <- matrix(1:4, 2)
  expect_error(view(m, file = html()), "needs `extent = c\\(xmin, xmax, ymin, ymax\\)`")
  expect_error(view(m, crs = "EPSG:3031", file = html()), "needs `extent")
  expect_error(view(m, extent = ext31, file = html()), "needs `crs`")
  expect_error(view(m, extent = ext31, crs = NULL, file = html()), "needs `crs`")
  expect_error(view(m, extent = c(0, 1), crs = "EPSG:3031", file = html()), "xmin < xmax")
  expect_error(view(m, extent = c(1, 0, 0, 1), crs = "EPSG:3031", file = html()), "xmin < xmax")
  expect_error(view(m, extent = c(0, 1, 0, NA), crs = "EPSG:3031", file = html()), "xmin < xmax")
  expect_error(view(m, extent = ext31, crs = "nonsense", file = html()), "nonsense")
  expect_error(view(matrix("a", 2, 2), extent = ext31, crs = "EPSG:3031", file = html()),
               "numeric or logical matrix")
  expect_error(view(array(1, c(2, 2, 2)), extent = ext31, crs = "EPSG:3031", file = html()),
               "3 or 4 bands")
  expect_error(view(array(1, c(2, 2, 2, 2)), extent = ext31, crs = "EPSG:3031", file = html()),
               "2 dimensions")
  expect_error(view(matrix(NA_real_, 2, 2), extent = ext31, crs = "EPSG:3031", file = html()),
               "every cell is missing")
  expect_error(view(m, extent = ext31, crs = "EPSG:3031", legend = "yes", file = html()),
               "TRUE or FALSE")
  expect_error(view(m, extent = ext31, crs = "EPSG:3031", range = c(1, 1), file = html()),
               "`range`")
  expect_error(view(m, extent = ext31, crs = "EPSG:3031", palette = c("a", "b"), file = html()),
               "`palette`")
  ## An untiled matrix has no plan for `...` to go to.
  expect_error(view(m, extent = ext31, crs = "EPSG:3031", max_tiles = 10, file = html()),
               "`max_tiles`")
  expect_error(view(list(m = m), file = html()), "view_add")
})

test_that("a matrix is added to a view with its own crs, and keyed by a ramp in a 0.5 scene", {
  m <- matrix(seq_len(12), 3, 4)
  ## Two polygons in EPSG:3031 coloured by a number: a 0.5 scene (a legend).
  pols <- data.frame(num = c(1, 2))
  pols$geom <- wk::wkt(c("POLYGON ((0 0, 1e6 0, 0 1e6, 0 0))",
                         "POLYGON ((-1e6 0, 0 0, 0 -1e6, -1e6 0))"), crs = "EPSG:3031")
  v <- view(pols, zcol = "num", file = html())
  v2 <- view_add(v, m, extent = ext31, crs = "EPSG:3031", file = html())
  expect_identical(layer_kinds(v2), c("polygon", "raster"))
  expect_identical(v2$scene$version, "0.5")
  expect_identical(vapply(v2$scene$legends, function(l) l$layer, ""), c("pols", "m"))
  expect_identical(v2$scene$legends[[2]]$ramp, list(range = c(1, 12), palette = "viridis"))
  expect_valid_scene(v2)
  ## legend = FALSE: no ramp, which needs 0.5.
  v3 <- view(m, extent = ext31, crs = "EPSG:3031", legend = FALSE, file = html())
  expect_identical(v3$scene$version, "0.5")
  expect_null(v3$scene$legends)
  expect_valid_scene(v3)
  ## Added to a view in another CRS, the matrix is tiled and reprojected.
  skip_if_no_terra()
  v4 <- view_add(view(pols, crs = "EPSG:3976", file = html()), m, extent = ext31,
                 crs = "EPSG:3031", file = html())
  expect_identical(layer_kinds(v4), c("polygon", "tiled_raster"))
  expect_identical(v4$scene$view$crs, "EPSG:3976")
  expect_identical(v4$scene$layers[[2]]$plan$crs, "EPSG:3976")
  ## Ids stay unique when a matrix is named as a layer already is.
  v5 <- view_add(view(m, extent = ext31, crs = "EPSG:3031", file = html()), m, extent = ext31,
                 crs = "EPSG:3031", file = html())
  expect_identical(layer_ids(v5$scene), c("m", "m_2"))
  expect_identical(names(aobcore::scene_blobs(v5$scene)), c("m_values", "m_2_values"))
})
