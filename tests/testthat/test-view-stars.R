# view() of stars objects and proxies (#38). Polar first: EPSG:3031
# throughout, lon/lat where the view CRS rule is the point. A proxy over a
# file routes as a SpatRaster read from it does; an in-memory object as a
# matrix with an extent and CRS does.

# A regular stars object in EPSG:3031 over `ext31` (test-view-matrix.R),
# nx by ny cells with the values given (x first, as stars stores them).
stars_3031 <- function(nx, ny, values) {
  bb <- sf::st_bbox(c(xmin = ext31[1], xmax = ext31[2], ymin = ext31[3], ymax = ext31[4]),
                    crs = sf::st_crs(3031))
  stars::st_as_stars(bb, nx = nx, ny = ny, values = values)
}

test_that("a small stars object in EPSG:3031 is drawn untiled, with its values and orientation", {
  skip_if_not_installed("stars")
  ## 4 columns by 3 rows: x[[1]][i, j] is column i, row j from the top.
  s <- stars_3031(4, 3, 0)
  s[[1]][1, 1] <- 7    # top-left
  s[[1]][4, 3] <- 9    # bottom-right
  s[[1]][4, 1] <- 5    # top-right
  expect_identical(view_crs(s), "EPSG:3031")
  v <- view(s, file = html())
  expect_s3_class(v, "aob_view")
  expect_identical(v$scene$view$crs, "EPSG:3031")
  expect_identical(layer_kinds(v), "raster")
  l <- v$scene$layers[[1]]
  expect_identical(l$id, "s")
  expect_identical(l$grid, list(crs = "EPSG:3031", extent = ext31, dim = c(4L, 3L)))
  expect_identical(l$palette, list(name = "viridis", range = c(0, 9)))
  vals <- raster_values(v)
  ## Row-major from the top: cell 1 is row 0 (ymax) column 0 (xmin).
  expect_identical(vals[1], 7)
  expect_identical(vals[4], 5)
  expect_identical(vals[12], 9)
  expect_identical(matrix(vals, nrow = 3, byrow = TRUE), t(s[[1]]))
  expect_equal(v$scene$view$extent, ext31)
  expect_length(tile_blobs(v), 0L)
  expect_true(numeric_version(v$scene$version) < "0.5")
  expect_output(print(v), "1 layer in EPSG:3031")
  expect_valid_scene(v)
  ## The same cells with y running upwards (a positive delta): the matrix
  ## route still gets row 1 at the top.
  ## (st_dimensions() takes a vector as the cells' starting edges.)
  up <- stars::st_as_stars(list(v = s[[1]][, 3:1]),
                           dimensions = stars::st_dimensions(x = seq(-3e6, by = 1.5e6, length.out = 4),
                                                             y = seq(-2e6, by = 4e6 / 3, length.out = 3)))
  up <- sf::st_set_crs(up, 3031)
  expect_identical(unclass(stars::st_dimensions(up)$y)$delta > 0, TRUE)
  v2 <- view(up, file = html())
  expect_identical(raster_values(v2), vals)
  expect_equal(v2$scene$layers[[1]]$grid$extent, ext31)
  ## A palette and range of the user's, and no legend, which makes the
  ## scene 0.5.
  v3 <- view(s, palette = "gray", range = c(0, 20), legend = FALSE, file = html())
  expect_identical(v3$scene$layers[[1]]$palette, list(name = "gray", range = c(0, 20)))
  expect_identical(v3$scene$version, "0.5")
  expect_null(v3$scene$legends)
})

test_that("a stars_proxy over a COG gives the SpatRaster's layer, from that file", {
  skip_if_not_installed("stars")
  skip_if_no_gdalraster()
  f <- extdata("polar_3031.tif")
  p <- stars::read_stars(f, proxy = TRUE)
  expect_identical(view_crs(p), "EPSG:3031")
  v <- view(p, name = "r", file = html())
  expect_identical(v$scene$view$crs, "EPSG:3031")
  expect_identical(layer_kinds(v), "tiled_raster")
  ## The source COG itself, embedded (a local file), referenced by its name.
  expect_identical(v$scene$data$r, list(format = "cog", url = "polar_3031.tif"))
  expect_gt(length(tile_blobs(v)), 0L)
  expect_equal(v$scene$view$extent, c(-6400000, 6400000, -6400000, 6400000))
  expect_valid_scene(v)
  ## Its arguments go to the plan, and a misspelled one is an error.
  expect_warning(v2 <- view(p, name = "r", max_tiles = 2, file = html()), "max_tiles")
  expect_lt(length(tile_blobs(v2)), length(tile_blobs(v)))
  expect_error(view(p, max_tile = 4, file = html()), "does not use `max_tile`")
  ## A COG whose CRS has no EPSG code is still referenced, not read.
  g <- tempfile(fileext = ".tif")
  on.exit(unlink(g), add = TRUE)
  gdalraster::translate(f, g, c("-of", "COG", "-a_srs",
                                "+proj=stere +lat_0=-90 +lat_ts=-70 +lon_0=10 +datum=WGS84 +units=m"),
                        quiet = TRUE)
  vg <- view(stars::read_stars(g, proxy = TRUE), name = "g", file = html())
  expect_identical(layer_kinds(vg), "tiled_raster")
  expect_identical(vg$scene$data$g$url, basename(g))
  ## The same scene as the SpatRaster read from the file.
  skip_if_no_terra()
  b <- view(terra::rast(f), name = "r", file = html())
  expect_identical(v$scene$data, b$scene$data)
  expect_identical(v$scene$layers, b$scene$layers)
  expect_identical(v$scene$view$extent, b$scene$view$extent)
})

test_that("a proxy sliced to one band draws that band; a colour COG draws in colour", {
  skip_if_not_installed("stars")
  skip_if_no_gdalraster()
  g <- stars::read_stars(extdata("polar_rgba.tif"), proxy = TRUE)
  v <- view(g, file = html())
  expect_identical(v$scene$layers[[1]]$rgb, list(bands = 1:3, alpha = 4L))
  expect_identical(v$scene$data$g$url, "polar_rgba.tif")
  ## Band 2 through a palette, from the same file: by `layer` or by slicing.
  v2 <- view(g, layer = 2, file = html())
  expect_identical(v2$scene$layers[[1]]$plan$levels[[1]]$encoding$band, 2L)
  expect_identical(v2$scene$data$g$url, "polar_rgba.tif")
  g2 <- g[, , , 2]
  v3 <- view(g2, name = "g", file = html())
  expect_identical(v3$scene$layers, v2$scene$layers)
  expect_error(view(g, layer = 5, file = html()), "from 1 to 4")
  expect_error(view(g, layer = "nope", file = html()), "no \"band\" slice")
})

test_that("a proxy over a raster that is not a COG goes to a temporary COG through GDAL", {
  skip_if_not_installed("stars")
  skip_if_no_gdalraster()
  skip_if_no_terra()
  f <- small_merc_tif()
  p <- stars::read_stars(f, proxy = TRUE)
  expect_identical(view_crs(p), "EPSG:3857")
  seen <- gdal_temp_seen(v <- view(p, name = "merc", file = html()))
  expect_identical(layer_kinds(v), "tiled_raster")
  expect_identical(v$scene$view$crs, "EPSG:3857")
  expect_match(v$scene$data$merc$url, "^view-.*[.]tif$")
  expect_equal(seen$dim, c(256, 256))
  expect_equal(range(seen$values), c(1, 250))
})

test_that("a cropped or computed proxy is read into memory and drawn from there", {
  skip_if_not_installed("stars")
  skip_if_no_gdalraster()
  p <- stars::read_stars(extdata("polar_3031.tif"), proxy = TRUE)
  expect_null(proxy_source(p * 2, NULL))
  expect_null(proxy_source(p[, 1:100, 1:100], NULL))
  expect_false(is.null(proxy_source(p, NULL)))
  ## Georeferencing changed on the proxy: not the file's, so read.
  d <- stars::st_dimensions(p)
  d$x$offset <- 0
  moved <- p
  attr(moved, "dimensions") <- d
  expect_null(proxy_source(moved, NULL))
  ## A crop in the view CRS, 100 x 100: untiled from memory, its extent the
  ## crop's.
  v <- view(p[, 1:100, 1:100], name = "crop", file = html())
  expect_identical(layer_kinds(v), "raster")
  expect_identical(v$scene$layers[[1]]$grid$dim, c(100L, 100L))
  expect_equal(v$scene$layers[[1]]$grid$extent, c(-6400000, -3200000, 3200000, 6400000))
  expect_identical(raster_values(v)[1:3], as.numeric(stars::st_as_stars(p)[[1]][1:3, 1]))
})

test_that("a lon/lat stars object south of 40S is drawn in EPSG:3031, tiled", {
  skip_if_not_installed("stars")
  skip_if_no_gdalraster()
  bb <- sf::st_bbox(c(xmin = -180, xmax = 180, ymin = -90, ymax = -40),
                    crs = sf::st_crs("OGC:CRS84"))
  s <- stars::st_as_stars(bb, nx = 72, ny = 20, values = seq_len(1440))
  expect_identical(view_crs(s), "EPSG:3031")
  seen <- grid_temp_seen(v <- view(s, palette = "ocean", file = html()))
  expect_identical(v$scene$view$crs, "EPSG:3031")
  expect_identical(layer_kinds(v), "tiled_raster")
  expect_identical(v$scene$layers[[1]]$palette, list(name = "ocean", range = c(1, 1440)))
  expect_identical(v$scene$layers[[1]]$plan$crs, "EPSG:3031")
  expect_identical(seen$cog$levels[[1]]$dim, c(72L, 20L))
  ## The file's first row is the grid's top (y offset -40, delta negative).
  expect_identical(seen$values[[1]][1:3], c(1, 2, 3))
  ## The meshes are projected: the initial view is metres around the pole.
  ext <- v$scene$view$extent
  expect_true(ext[1] < 0 && ext[2] > 0 && ext[3] < 0 && ext[4] > 0)
  expect_gt(ext[2], 1e6)
  ## The same grid between 30S and 30N is flat in its own CRS, untiled.
  mid <- stars::st_as_stars(sf::st_bbox(c(xmin = -180, xmax = 180, ymin = -30, ymax = 30),
                                        crs = sf::st_crs("OGC:CRS84")),
                            nx = 72, ny = 20, values = seq_len(1440))
  expect_identical(view_crs(mid), "OGC:CRS84")
  expect_identical(layer_kinds(view(mid, file = html())), "raster")
})

test_that("layer picks an attribute, or a slice of the dimension beyond x and y", {
  skip_if_not_installed("stars")
  s <- stars_3031(4, 3, seq_len(12))
  s$b <- s[[1]] * 2
  expect_identical(names(s), c("values", "b"))
  expect_identical(raster_values(view(s, file = html()))[1], 1)
  expect_identical(raster_values(view(s, layer = "b", file = html()))[1], 2)
  expect_identical(raster_values(view(s, layer = 2, file = html()))[1], 2)
  expect_error(view(s, layer = "c", file = html()), "no attribute \"c\"")
  expect_error(view(s, layer = 3, file = html()), "attribute name or number from 1 to 2")
  ## One attribute with a band dimension.
  one <- stars_3031(4, 3, seq_len(12))
  bands <- c(one, one * 10, along = "band")
  expect_identical(dim(bands), c(x = 4L, y = 3L, band = 2L))
  expect_identical(raster_values(view(bands, file = html()))[1], 1)
  expect_identical(raster_values(view(bands, layer = 2, file = html()))[1], 10)
  expect_error(view(bands, layer = 3, file = html()), "\"band\" slice name or number from 1 to 2")
  ## By the dimension's values: a time slice by its date.
  days <- c(one, one * 10, along = list(time = as.Date(c("2020-01-01", "2020-01-02"))))
  expect_identical(raster_values(view(days, layer = "2020-01-02", file = html()))[1], 10)
  ## One attribute, nothing beyond x and y: `layer` beyond 1 is an error.
  expect_identical(layer_kinds(view(one, layer = 1, file = html())), "raster")
  expect_error(view(one, layer = 2, file = html()), "picks nothing")
  ## Two dimensions beyond x and y: slice first (stars keeps the sliced
  ## dimensions, one element each, which need no picking).
  two <- c(bands, bands, along = list(time = as.Date(c("2020-01-01", "2020-01-02"))))
  expect_error(view(two, file = html()), "Slice it first")
  expect_identical(dim(two[, , , 1, 2]), c(x = 4L, y = 3L, band = 1L, time = 1L))
  expect_identical(raster_values(view(two[, , , 2, 2], file = html()))[1], 10)
  expect_identical(raster_values(view(two[, , , 2, ], layer = 2, file = html()))[1], 10)
})

test_that("curvilinear and rectilinear grids and vector cubes are out of scope, with a message", {
  skip_if_not_installed("stars")
  skip_if_no_gdalraster()
  a <- array(seq_len(12), c(4, 3))
  lon <- matrix(rep(seq(-180, 180, length.out = 4), 3), 4, 3)
  lat <- matrix(rep(seq(-90, -60, length.out = 3), each = 4), 4, 3)
  curvi <- stars::st_as_stars(stars::st_as_stars(a), curvilinear = list(X1 = lon, X2 = lat),
                              crs = sf::st_crs(4326))
  expect_error(view(curvi, file = html()), "curvilinear.*decision 0010, item 5")
  expect_error(view_crs(curvi), "curvilinear")
  recti <- stars::st_as_stars(list(v = a),
                              dimensions = stars::st_dimensions(x = c(0, 1, 2, 4), y = c(0, 1, 3)))
  recti <- sf::st_set_crs(recti, 3031)
  expect_error(view(recti, file = html()), "rectilinear.*decision 0010, item 5")
  skip_if_not_installed("sf")
  nc <- sf::st_read(system.file("gpkg", "nc.gpkg", package = "sf"), quiet = TRUE)
  cube <- stars::st_as_stars(nc[1:3, "BIR74"])
  expect_error(view(cube, file = html()), "vector data cube.*decision 0010, item 5")
  expect_error(view(list(cube), file = html()), "vector data cube")
})

test_that("stars arguments are checked, and a misspelled one is an error", {
  skip_if_not_installed("stars")
  chr <- stars::st_as_stars(matrix(letters[1:12], 4, 3))
  sf::st_crs(chr) <- 3031
  expect_error(view(chr, file = html()), "draws numbers, logicals and factors")
  s <- stars_3031(4, 3, seq_len(12))
  expect_error(view(s, legend = "yes", file = html()), "TRUE or FALSE")
  expect_error(view(s, range = c(1, 1), file = html()), "`range`")
  expect_error(view(s, palette = c("a", "b"), file = html()), "`palette`")
  ## An untiled grid has no plan for `...` to go to.
  expect_error(view(s, max_tiles = 10, file = html()), "`max_tiles`")
  expect_error(view(s, pallete = "gray", file = html()), "`pallete`")
  ## No CRS.
  none <- stars::st_as_stars(matrix(seq_len(12), 3, 4))
  expect_error(view(none, file = html()), "no CRS")
  expect_error(view_crs(none), "no CRS")
  ## A view CRS of the user's.
  v <- view(s, crs = "EPSG:3976", file = html())
  expect_identical(v$scene$view$crs, "EPSG:3976")
  expect_error(view_add(view(s, file = html()), s, crs = "EPSG:3031", file = html()),
               "keeps the view's CRS")
})

test_that("a stars object goes in a list and is added to a view, like a SpatRaster", {
  skip_if_not_installed("stars")
  skip_if_no_gdalraster()
  s <- stars_3031(4, 3, seq_len(12))
  coast <- extdata("coastline_south_40s.geojson")
  v <- view(list(sst = s, coast = coast), file = html())
  expect_identical(v$scene$view$crs, "EPSG:3031")
  expect_identical(layer_kinds(v), c("raster", "path"))
  expect_identical(layer_ids(v$scene), c("sst", "coast"))
  p <- stars::read_stars(extdata("polar_3031.tif"), proxy = TRUE)
  v2 <- view_add(view(coast, file = html()), p, palette = "ice", file = html())
  expect_identical(layer_kinds(v2), c("path", "tiled_raster"))
  expect_identical(v2$scene$layers[[2]]$palette$name, "ice")
  expect_identical(v2$scene$data$p$url, "polar_3031.tif")
  ## Added to a view in another CRS, an in-memory object is tiled and
  ## reprojected.
  v3 <- view_add(view(coast, crs = "EPSG:3976", file = html()), s, file = html())
  expect_identical(layer_kinds(v3), c("path", "tiled_raster"))
  expect_identical(v3$scene$layers[[2]]$plan$crs, "EPSG:3976")
  expect_valid_scene(v3)
})

test_that("view() of stars data says when stars or gdalraster is missing", {
  skip_if_not_installed("stars")
  skip_if_no_gdalraster()
  s <- stars_3031(4, 3, seq_len(12))
  p <- stars::read_stars(extdata("polar_3031.tif"), proxy = TRUE)
  local({
    local_mocked_bindings(has_gdalraster = function() FALSE)
    expect_error(view(p, file = html()), "'gdalraster' package")
    ## An in-memory grid drawn untiled needs no gdalraster.
    expect_identical(layer_kinds(view(s, file = html())), "raster")
  })
  local({
    local_mocked_bindings(need_stars = function() stop("view() of stars data needs the 'stars' package.", call. = FALSE))
    expect_error(view(s, file = html()), "'stars' package")
  })
})
