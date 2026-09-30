layer_ids <- function(v) vapply(v$scene$layers, function(l) l$id, "")
layer_labels <- function(v) vapply(v$scene$layers, function(l) l$label, "")

## Lon/lat test layers south of 40S: a polygon and a line.
land <- function() sf::st_sf(a = 1, geometry = lonlat(list(ring(-40, 40, -80, -70))))
track <- function() lonlat(list(sf::st_linestring(rbind(c(0, -60), c(90, -60)))))

test_that("a list of sf layers and a SpatRaster draws in one page, in list order", {
  skip_if_no_terra()
  skip_if_not_installed("sf")
  sst <- terra::rast(extdata("polar_3031.tif"))
  polys <- land()
  lines <- track()
  v <- view(list(sst = sst, land = polys, track = lines), file = html())
  expect_s3_class(v, "aob_view")
  expect_identical(v$scene$view$crs, "EPSG:3031")
  expect_identical(layer_kinds(v), c("tiled_raster", "polygon", "path"))
  expect_identical(layer_ids(v), c("sst", "land", "track"))
  expect_identical(layer_labels(v), c("sst", "land", "track"))
  ## One page with every layer's data, titled by the labels.
  page <- page_text(v)
  expect_match(page, "<title>sst, land, track</title>", fixed = TRUE)
  expect_true(all(c("sst", "sst_vertices", "sst_indices", "land", "track") %in%
                    names(v$scene$data)))
  expect_gt(length(tile_blobs(v)), 0L)
  ## The lon/lat vectors arrive in EPSG:3031.
  xy <- wk::wk_coords(blob_geometry(v, "track"))
  expect_true(all(abs(xy$x) < 4e6 & abs(xy$y) < 4e6))
  ## The version is the highest any part needs: 0.4 with the view's bounds
  ## (the domain), else 0.2 for the tiled raster.
  expect_identical(v$scene$version, aobcore::scene_spec_version(v$scene))
  if (!is.null(v$scene$view$bounds)) expect_identical(v$scene$version, "0.4")
  expect_output(print(v), "3 layers in EPSG:3031")
})

test_that("adding to a view gives the same scene as the list form", {
  skip_if_not_installed("sf")
  polys <- land()
  lines <- track()
  a <- view(list(polys = polys, lines = lines), file = html())
  b <- view_add(view(polys, file = html()), lines, file = html())
  expect_identical(b$scene, a$scene)
  expect_identical(b$name, a$name)
  expect_identical(b$extents, a$extents)
  ## The first view's page is untouched.
  v1 <- view(polys, file = html())
  before <- page_text(v1)
  v2 <- view_add(v1, lines, stroke = c(200, 40, 40, 255), name = "ship track")
  expect_identical(page_text(v1), before)
  expect_false(identical(v2$file, v1$file))
  expect_identical(layer_ids(v2), c("polys", "ship_track"))
  expect_identical(v2$scene$layers[[2]]$stroke, c(200L, 40L, 40L, 255L))
  expect_identical(v2$name, "polys, ship track")
  ## A list can be added too.
  v3 <- view_add(view(polys, file = html()), list(lines = lines), file = html())
  expect_identical(v3$scene, a$scene)
})

test_that("adding a raster gives the same scene as the list form", {
  skip_if_no_terra()
  skip_if_not_installed("sf")
  sst <- terra::rast(extdata("polar_3031.tif"))
  polys <- land()
  a <- view(list(sst = sst, polys = polys), file = html())
  b <- view_add(view(sst, file = html()), polys, file = html())
  expect_identical(b$scene, a$scene)
  c2 <- view_add(view(polys, file = html()), sst, palette = "ocean", file = html())
  expect_identical(layer_kinds(c2), c("polygon", "tiled_raster"))
  expect_identical(c2$scene$layers[[2]]$palette$name, "ocean")
  expect_identical(c2$scene$version, aobcore::scene_spec_version(c2$scene))
})

test_that("mixed CRSs are reprojected to the first object's view CRS", {
  skip_if_not_installed("sf")
  ll <- track()
  p3031 <- sf::st_sfc(sf::st_linestring(rbind(c(0, 0), c(1e6, 1e6))), crs = "EPSG:3031")
  expected <- sf::st_coordinates(to_view_crs(ll, "EPSG:3031", NULL))
  for (v in list(view(list(ll = ll, p3031 = p3031), file = html()),
                 view(list(p3031 = p3031, ll = ll), file = html()),
                 view_add(view(p3031, file = html()), ll, file = html()))) {
    expect_identical(v$scene$view$crs, "EPSG:3031")
    expect_identical(wk::wk_coords(blob_geometry(v, "p3031"))$x, c(0, 1e6))
    xy <- wk::wk_coords(blob_geometry(v, "ll"))
    expect_equal(cbind(xy$x, xy$y), unname(expected[, 1:2]), tolerance = 1e-6)
  }
  ## A projected CRS anywhere in the list wins over the lon/lat rule; the
  ## first projected one when there are several.
  nc <- sf::st_read(system.file("shape", "nc.shp", package = "sf"), quiet = TRUE)
  utm <- sf::st_transform(nc[1:3, ], "EPSG:26717")
  expect_identical(view_crs(list(nc, utm)), "EPSG:26717")
  expect_identical(view_crs(list(p3031, utm)), "EPSG:3031")
  ## A given crs overrides the rule, and every layer is reprojected to it.
  v <- view(list(ll = ll, p3031 = p3031), crs = 3976, file = html())
  expect_identical(v$scene$view$crs, "EPSG:3976")
  ## view_add() keeps the view's CRS.
  v <- view_add(view(ll, crs = "EPSG:3976", file = html()), p3031, file = html())
  expect_identical(v$scene$view$crs, "EPSG:3976")
})

test_that("the lon/lat rule is applied once, to the combined extent", {
  skip_if_not_installed("sf")
  south <- lonlat(list(ring(0, 10, -80, -70)))
  far_south <- lonlat(list(ring(0, 10, -60, -50)))
  mid <- lonlat(list(ring(0, 10, -30, -20)))
  north <- lonlat(list(ring(0, 10, 70, 80)))
  expect_identical(view_crs(list(south, far_south)), "EPSG:3031")
  expect_identical(view_crs(list(south, mid)), "OGC:CRS84")
  expect_identical(view_crs(list(south, north)), "OGC:CRS84")
  expect_identical(view(list(south, mid), file = html())$scene$view$crs, "OGC:CRS84")
})

test_that("a SpatRaster and SpatVector mix with sf in the lon/lat rule", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  r <- terra::rast(ncols = 10, nrows = 10, xmin = -180, xmax = 180, ymin = -90, ymax = -50,
                   crs = "OGC:CRS84")
  p <- terra::vect("POLYGON ((0 -45, 10 -45, 10 -41, 0 -41, 0 -45))", crs = "OGC:CRS84")
  expect_identical(view_crs(list(r, p, land())), "EPSG:3031")
  expect_identical(view_crs(list(r, lonlat(list(ring(0, 10, -30, -20))))), "OGC:CRS84")
})

test_that("layer ids are unique and valid however the inputs are named", {
  skip_if_not_installed("sf")
  x <- track()
  m <- lonlat(list(sf::st_point(c(0, -70)), ring(-40, 40, -80, -70)))
  v <- view(list(a = x, a = x, "2 bad names!" = x, x, m = m, m_point = x), file = html())
  ids <- layer_ids(v)
  expect_identical(ids, c("a", "a_2", "x2_bad_names_", "x", "m_polygon", "m_point",
                          "m_point_2"))
  expect_false(anyDuplicated(ids) > 0L)
  expect_true(all(grepl("^[A-Za-z][A-Za-z0-9_.-]*$", ids)))
  expect_identical(layer_labels(v)[1:4], c("a", "a", "2 bad names!", "x"))
  ## Unnamed elements take their expression, else x[[i]].
  first <- x
  v2 <- view(list(first, track()), file = html())
  expect_identical(layer_labels(v2), c("first", "track()"))
  xs <- list(x, x)
  v3 <- view(xs, file = html())
  expect_identical(layer_labels(v3), c("xs[[1]]", "xs[[2]]"))
  expect_identical(layer_ids(v3), c("xs_1_", "xs_2_"))
})

test_that("a raster's data ids stay clear of other layers' ids", {
  skip_if_no_terra()
  skip_if_not_installed("sf")
  sst <- terra::rast(extdata("polar_3031.tif"))
  ## "sst" would name data "sst_vertices", already a layer's data id.
  v <- view(list(sst_vertices = track(), sst = sst, sst = sst), file = html())
  expect_identical(layer_ids(v), c("sst_vertices", "sst_2", "sst_3"))
  expect_false(anyDuplicated(names(v$scene$data)) > 0L)
})

test_that("the initial view is the layers' extent clipped to the view's domain", {
  skip_if_not_installed("sf")
  skip_if_not_installed("gdalraster")
  ok <- !inherits(try(gdalraster::srs_to_wkt("EPSG:3031"), silent = TRUE), "try-error")
  skip_if_not(ok, "gdalraster cannot resolve EPSG:3031")
  a <- sf::st_sfc(sf::st_point(c(-1e6, -2e6)), crs = "EPSG:3031")
  b <- sf::st_sfc(sf::st_point(c(3e6, 1e6)), crs = "EPSG:3031")
  v <- view(list(a = a, b = b), file = html())
  expect_equal(v$scene$view$extent, c(-1e6, 3e6, -2e6, 1e6))
  ## A point at 80N lies far outside EPSG:3031's domain: the view is
  ## clipped to the bounds, not stretched to 1e13 m.
  far <- lonlat(list(sf::st_point(c(0, 80))))
  v2 <- view(list(a = a, far = far), file = html())
  bounds <- v2$scene$view$bounds
  expect_length(bounds, 4L)
  e <- v2$scene$view$extent
  expect_true(e[1] >= bounds[1] && e[2] <= bounds[2] && e[3] >= bounds[3] && e[4] <= bounds[4])
  expect_identical(v2$scene$version, "0.4")
})

test_that("without a domain the version is the lowest the layers need", {
  skip_if_not_installed("sf")
  old <- options(aobcore.domain = FALSE)
  on.exit(options(old), add = TRUE)
  v <- view(list(a = land(), b = track()), file = html())
  expect_null(v$scene$view$bounds)
  expect_identical(v$scene$version, "0.1")
  skip_if_no_terra()
  sst <- terra::rast(extdata("polar_3031.tif"))
  expect_identical(view_add(v, sst, file = html())$scene$version, "0.2")
  rgba <- terra::rast(extdata("polar_rgba.tif"))
  expect_identical(view(list(a = land(), rgba = rgba), file = html())$scene$version, "0.3")
})

test_that("list and add arguments are checked", {
  skip_if_not_installed("sf")
  x <- track()
  expect_error(view(list(), file = html()), "nothing to view")
  expect_error(view(list(x, 1:3), file = html()), "List element 2")
  expect_error(view(list(x, sf::st_sfc(sf::st_point(c(0, 0)))), file = html()),
               "List element 2 .*no CRS")
  expect_error(view(list(x), fill = c(1, 2, 3, 4), file = html()), "`fill`")
  expect_error(view_add(list(), x), "`v` must be a view")
  v <- view(x, file = html())
  expect_error(view_add(v, x, fil = c(1, 2, 3, 4)), "`fil`")
  expect_error(view_add(v, 1:3), "no method")
})
