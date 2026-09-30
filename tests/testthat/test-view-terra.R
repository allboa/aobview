test_that("a projected SpatRaster from a local COG is drawn in its own CRS from that COG", {
  skip_if_no_terra()
  r <- terra::rast(extdata("polar_3031.tif"))
  v <- view(r, file = html())
  expect_s3_class(v, "aob_view")
  expect_identical(v$scene$view$crs, "EPSG:3031")
  expect_identical(layer_kinds(v), "tiled_raster")
  l <- v$scene$layers[[1]]
  expect_identical(l$id, "r")
  expect_identical(l$plan$crs, "EPSG:3031")
  expect_identical(l$palette$name, "viridis")
  ## The source COG itself, embedded (a local file), referenced by its name.
  expect_identical(v$scene$data$r, list(format = "cog", url = "polar_3031.tif"))
  expect_gt(length(tile_blobs(v)), 0L)
  expect_equal(v$scene$view$extent, c(-6400000, 6400000, -6400000, 6400000))
  expect_match(page_text(v), "data-aob-blob", fixed = TRUE)
  expect_output(print(v), "1 layer in EPSG:3031")
})

test_that("a projected in-memory SpatRaster keeps its CRS", {
  skip_if_no_terra()
  m <- terra::rast(ncols = 40, nrows = 30, xmin = 4e5, xmax = 6e5, ymin = 5.2e6, ymax = 5.35e6,
                   crs = "EPSG:32755", vals = seq_len(1200))
  v <- view(m, file = html())
  expect_identical(v$scene$view$crs, "EPSG:32755")
  expect_identical(v$scene$layers[[1]]$palette$range, c(1, 1200))
  expect_equal(v$scene$view$extent, c(4e5, 6e5, 5.2e6, 5.35e6))
})

test_that("a lon/lat SpatRaster over the South Pole is drawn in EPSG:3031", {
  skip_if_no_terra()
  l <- terra::rast(extdata("polar_lonlat.tif"))
  expect_identical(view_crs(l), "EPSG:3031")
  v <- view(l, palette = "ocean", file = html())
  expect_identical(v$scene$view$crs, "EPSG:3031")
  lay <- v$scene$layers[[1]]
  expect_identical(lay$plan$crs, "EPSG:3031")
  expect_identical(lay$palette$name, "ocean")
  expect_identical(v$scene$data$l$url, "polar_lonlat.tif")
  ## Meshes are projected: the view is polar stereographic metres around the pole.
  e <- v$scene$view$extent
  expect_true(e[1] < 0 && e[2] > 0 && e[3] < 0 && e[4] > 0)
  expect_gt(e[2], 1e6)
})

test_that("an in-memory SpatRaster is written to a temporary COG and embedded", {
  skip_if_no_terra()
  m <- terra::rast(ncols = 72, nrows = 20, xmin = -180, xmax = 180, ymin = -90, ymax = -40,
                   crs = "OGC:CRS84", vals = seq_len(1440))
  v <- view(m, file = html())
  expect_identical(v$scene$view$crs, "EPSG:3031")
  ref <- v$scene$data$m
  expect_identical(ref$format, "cog")
  ## A name relative to the page, not a file:// URL: the tiles are in the page.
  expect_match(ref$url, "^view-.*[.]tif$")
  expect_gt(length(tile_blobs(v)), 0L)
  expect_true(all(startsWith(tile_blobs(v), "m@")))
  expect_identical(v$scene$layers[[1]]$palette$range, c(1, 1440))
  expect_match(page_text(v), "data-aob-blob", fixed = TRUE)
})

test_that("a computed, cropped or windowed SpatRaster is not taken from its file", {
  skip_if_no_terra()
  r <- terra::rast(extdata("polar_3031.tif"))
  w <- r
  terra::window(w) <- terra::ext(r) / 2
  expect_null(raster_cog_source(w))
  expect_null(raster_cog_source(r * 2))
  expect_null(raster_cog_source(terra::crop(r, terra::ext(r) / 2)))
  s <- raster_cog_source(r)
  expect_identical(s$bands, 1L)
  expect_identical(s$cog$band, 1L)
  v <- view(w, file = html())
  expect_match(v$scene$data$w$url, "^view-")
  expect_equal(v$scene$view$extent, c(-3200000, 3200000, -3200000, 3200000))
})

test_that("a SpatRaster backed by a COG URL is referenced by URL, not embedded", {
  skip_if_no_terra()
  skip_on_cran()
  url <- paste0("https://raw.githubusercontent.com/allboa/aobcore/",
                "5ecd9b0c5a877491d1da534a0454f52650d346d1/inst/extdata/polar_3031.tif")
  for (src in c(paste0("/vsicurl/", url), url)) {
    u <- tryCatch(suppressWarnings(terra::rast(src)), error = function(e) NULL)
    skip_if(is.null(u), "the COG URL is not reachable")
    v <- view(u, file = html())
    expect_identical(v$scene$data$u, list(format = "cog", url = url))
    expect_length(tile_blobs(v), 0L)
    expect_identical(names(aobcore::scene_blobs(v$scene)), c("u_vertices", "u_indices"))
  }
})

test_that("a terra source maps to the dsn aobcore reads", {
  expect_identical(raster_dsn("/vsicurl/https://example.org/a.tif"),
                   "/vsicurl/https://example.org/a.tif")
  expect_identical(raster_dsn("https://example.org/a.tif"), "https://example.org/a.tif")
  expect_identical(raster_dsn("/data/a.tif"), "/data/a.tif")
  expect_identical(raster_dsn("C:/data/a.tif"), "C:/data/a.tif")
  expect_identical(raster_dsn("NETCDF:\"a.nc\":sst"), NA_character_)
})

test_that("a 3-band Byte RGB SpatRaster draws as a colour image", {
  skip_if_no_terra()
  set.seed(1)
  x <- terra::rast(nrows = 50, ncols = 50, nlyrs = 3, xmin = -2e6, xmax = 2e6, ymin = -2e6,
                   ymax = 2e6, crs = "EPSG:3031", vals = sample(0:255, 7500, TRUE))
  ## Without a colour interpretation it is three layers of numbers.
  v0 <- view(x, file = html())
  expect_false(is.null(v0$scene$layers[[1]]$palette))
  terra::RGB(x) <- 1:3
  v <- view(x, file = html())
  l <- v$scene$layers[[1]]
  expect_true(numeric_version(v$scene$version) >= "0.3")
  expect_identical(l$rgb, list(bands = 1:3))
  expect_null(l$palette)
  expect_gt(length(tile_blobs(v)), 0L)
  expect_identical(v$scene$data$x$format, "cog")
  ## layer or palette chooses one band; rgb = FALSE too.
  expect_false(is.null(view(x, layer = 2, file = html())$scene$layers[[1]]$palette))
  expect_false(is.null(view(x, rgb = FALSE, file = html())$scene$layers[[1]]$palette))
})

test_that("RGB layers in another order are drawn red, green, blue", {
  skip_if_no_terra()
  x <- terra::rast(nrows = 10, ncols = 10, nlyrs = 3, xmin = -1e6, xmax = 1e6, ymin = -1e6,
                   ymax = 1e6, crs = "EPSG:3031",
                   vals = c(rep(0, 100), rep(100, 100), rep(255, 100)))
  terra::RGB(x) <- c(3, 2, 1)
  vals <- temp_cog_values(v <- view(x, file = html()))
  expect_equal(unname(vals[1, ]), c(255, 100, 0))
  expect_identical(v$scene$layers[[1]]$rgb, list(bands = 1:3))
})

test_that("an RGBA COG file draws in colour with its alpha band", {
  skip_if_no_terra()
  g <- terra::rast(extdata("polar_rgba.tif"))
  v <- view(g, file = html())
  expect_identical(v$scene$layers[[1]]$rgb, list(bands = 1:3, alpha = 4L))
  expect_identical(v$scene$data$g$url, "polar_rgba.tif")
  ## One band of it through a palette, from the same file.
  v2 <- view(g, layer = 2, file = html())
  expect_identical(v2$scene$layers[[1]]$plan$levels[[1]]$encoding$band, 2L)
  expect_identical(v2$scene$data$g$url, "polar_rgba.tif")
})

test_that("SpatRaster arguments are checked", {
  skip_if_no_terra()
  m <- terra::rast(ncols = 4, nrows = 4, xmin = 0, xmax = 4, ymin = -80, ymax = -76,
                   crs = "OGC:CRS84", vals = 1:16)
  expect_error(view(m, layer = 3, file = html()), "layer")
  expect_error(view(m, layer = "nope", file = html()), "no layer")
  expect_error(view(m, rgb = TRUE, file = html()), "3 or 4 layers")
  expect_error(view(m, rgb = "yes", file = html()), "`rgb`")
  expect_error(view(terra::rast(ncols = 4, nrows = 4), file = html()), "no values")
  n <- terra::rast(ncols = 4, nrows = 4, vals = 1:16, crs = "")
  expect_error(view(n, file = html()), "no CRS")
  v <- view(m, crs = "EPSG:3976", palette = "gray", range = c(0, 20), file = html())
  expect_identical(v$scene$view$crs, "EPSG:3976")
  expect_identical(v$scene$layers[[1]]$palette, list(name = "gray", range = c(0, 20)))
})

test_that("view() draws a SpatVector through the sf path", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  p <- terra::vect(c("POLYGON ((-40 -80, 40 -80, 40 -70, -40 -70, -40 -80))",
                     "POLYGON ((100 -75, 120 -75, 120 -65, 100 -65, 100 -75))"),
                   crs = "OGC:CRS84")
  expect_identical(view_crs(p), "EPSG:3031")
  v <- view(p, file = html())
  expect_identical(layer_kinds(v), "polygon")
  expect_identical(v$scene$view$crs, "EPSG:3031")
  expect_length(blob_geometry(v, "p"), 2L)
  pts <- terra::vect(cbind(c(110.53, 77.97), c(-66.28, -68.58)), crs = "OGC:CRS84")
  expect_identical(layer_kinds(view(pts, file = html())), "point")
  lux <- terra::vect(system.file("ex", "lux.shp", package = "terra"))
  expect_identical(view(lux, file = html())$scene$view$crs, "EPSG:4326")
})

test_that("view_crs() of terra data follows the same rule as sf", {
  skip_if_not_installed("terra")
  expect_identical(view_crs(terra::rast(extdata("polar_3031.tif"))), "EPSG:3031")
  north <- terra::rast(ncols = 10, nrows = 10, xmin = -180, xmax = 180, ymin = 60, ymax = 90,
                       crs = "OGC:CRS84")
  expect_identical(view_crs(north), "EPSG:3413")
  mid <- terra::rast(ncols = 10, nrows = 10, xmin = 0, xmax = 10, ymin = 40, ymax = 50,
                     crs = "EPSG:4326")
  expect_identical(view_crs(mid), "EPSG:4326")
  laea <- terra::rast(ncols = 10, nrows = 10, xmin = -1e6, xmax = 1e6, ymin = -1e6, ymax = 1e6,
                      crs = "+proj=laea +lat_0=-90 +datum=WGS84")
  expect_match(view_crs(laea), "LAEA|Lambert|laea", ignore.case = TRUE)
})

test_that("missing cells of an RGB SpatRaster become transparent, and white stays white", {
  skip_if_no_terra()
  x <- terra::rast(nrows = 10, ncols = 10, nlyrs = 3, xmin = -1e6, xmax = 1e6, ymin = -1e6,
                   ymax = 1e6, crs = "EPSG:3031", vals = 255)
  terra::RGB(x) <- 1:3
  v <- view(x, file = html())
  expect_identical(v$scene$layers[[1]]$rgb, list(bands = 1:3))
  vals <- rep(255, 300)
  vals[101] <- NA
  x <- terra::rast(x, vals = vals)
  terra::RGB(x) <- 1:3
  vals <- temp_cog_values(v <- view(x, file = html()))
  expect_identical(v$scene$layers[[1]]$rgb, list(bands = 1:3, alpha = 4L))
  expect_equal(unname(vals[1, ]), c(255, 0, 255, 0))
  expect_equal(unname(vals[2, ]), c(255, 255, 255, 255))
})

test_that("a raster given another NAflag than its file's is not taken from the file", {
  skip_if_no_terra()
  i <- terra::rast(ncols = 100, nrows = 100, xmin = 0, xmax = 1e5, ymin = -1e5, ymax = 0,
                   crs = "EPSG:3031", vals = rep(1:10, 1000))
  f <- tempfile(fileext = ".tif")
  terra::writeRaster(i, f, filetype = "COG", datatype = "INT2S", NAflag = -9999)
  j <- terra::rast(f)
  expect_false(is.null(raster_cog_source(j)))
  terra::NAflag(j) <- -9999
  expect_false(is.null(raster_cog_source(j)))
  terra::NAflag(j) <- 5
  expect_null(raster_cog_source(j))
  vals <- temp_cog_values(v <- view(j, file = html()))
  expect_match(v$scene$data$j$url, "^view-")
  expect_true(all(is.na(vals[i[] == 5])))
  expect_identical(v$scene$layers[[1]]$palette$range, c(1, 10))
})

test_that("terra::RGB() chooses the bands of a file-backed raster", {
  skip_if_no_terra()
  set.seed(2)
  x <- terra::rast(nrows = 50, ncols = 50, nlyrs = 3, xmin = -2e6, xmax = 2e6, ymin = -2e6,
                   ymax = 2e6, crs = "EPSG:3031", vals = sample(0:255, 7500, TRUE))
  f <- tempfile(fileext = ".tif")
  terra::writeRaster(x, f, filetype = "COG", datatype = "INT1U",
                     gdal = interleave_pixel())
  ## No colour interpretation in the file: a palette, until RGB() says so.
  y <- terra::rast(f)
  expect_false(is.null(view(y, file = html())$scene$layers[[1]]$palette))
  terra::RGB(y) <- 1:3
  v <- view(y, file = html())
  expect_identical(v$scene$layers[[1]]$rgb, list(bands = 1:3))
  expect_identical(v$scene$data$y$url, basename(f))
  terra::RGB(y) <- c(2, 3, 1)
  expect_identical(view(y, file = html())$scene$layers[[1]]$rgb, list(bands = c(2L, 3L, 1L)))
  ## RGB() overrides the file's own colour interpretation.
  z <- terra::rast(extdata("polar_rgba.tif"))
  terra::RGB(z) <- c(3, 2, 1, 4)
  v <- view(z, file = html())
  expect_identical(v$scene$layers[[1]]$rgb, list(bands = c(3L, 2L, 1L), alpha = 4L))
  expect_identical(v$scene$data$z$url, "polar_rgba.tif")
  ## Three layers named: the fourth stays alpha when the file says so.
  terra::RGB(z) <- c(3, 2, 1)
  expect_identical(view(z, file = html())$scene$layers[[1]]$rgb,
                   list(bands = c(3L, 2L, 1L), alpha = 4L))
})

test_that("a striped file, or a tiled one without overviews, is rewritten as a COG", {
  skip_if_no_terra()
  m <- terra::rast(ncols = 600, nrows = 600, xmin = -3e6, xmax = 3e6, ymin = -3e6, ymax = 3e6,
                   crs = "EPSG:3031", vals = seq_len(360000))
  striped <- tempfile(fileext = ".tif")
  terra::writeRaster(m, striped, gdal = "TILED=NO")
  s <- terra::rast(striped)
  expect_null(raster_cog_source(s))
  v <- view(s, file = html())
  expect_match(v$scene$data$s$url, "^view-")
  expect_gt(length(v$scene$layers[[1]]$plan$levels), 1L)
  tiled <- tempfile(fileext = ".tif")
  terra::writeRaster(m, tiled, gdal = c("TILED=YES", "BLOCKXSIZE=256", "BLOCKYSIZE=256"))
  expect_null(raster_cog_source(terra::rast(tiled)))
  ## An image that fits in one tile needs no overviews.
  small <- tempfile(fileext = ".tif")
  terra::writeRaster(terra::aggregate(m, 6), small,
                     gdal = c("TILED=YES", "BLOCKXSIZE=128", "BLOCKYSIZE=128"))
  expect_false(is.null(raster_cog_source(terra::rast(small))))
})

test_that("arguments a SpatVector does not use are an error", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  p <- terra::vect("POINT (0 -70)", crs = "OGC:CRS84")
  expect_error(view(p, palette = "ocean", file = html()), "`palette`")
})
