test_that("view() draws points, lines and polygons as one layer each", {
  skip_if_not_installed("sf")
  pts <- lonlat(list(sf::st_point(c(0, -70)), sf::st_point(c(100, -66))))
  lns <- lonlat(list(sf::st_linestring(rbind(c(0, -60), c(90, -60)))))
  pol <- sf::st_sf(a = 1, geometry = lonlat(list(ring(-40, 40, -80, -70))))
  for (case in list(list(pts, "point"), list(lns, "path"), list(pol, "polygon"))) {
    v <- view(case[[1]], file = tempfile(fileext = ".html"))
    expect_s3_class(v, "aob_view")
    expect_identical(layer_kinds(v), case[[2]])
    expect_identical(v$scene$view$crs, "EPSG:3031")
    expect_true(file.exists(v$file))
    expect_match(paste(readLines(v$file, warn = FALSE), collapse = "\n"), "data-aob-blob", fixed = TRUE)
  }
})

test_that("multi geometries draw with their single-kind layer", {
  skip_if_not_installed("sf")
  mp <- lonlat(list(sf::st_multipolygon(list(unclass(ring(0, 10, -80, -70)),
                                             unclass(ring(20, 30, -80, -70))))))
  v <- view(mp, file = tempfile(fileext = ".html"))
  expect_identical(layer_kinds(v), "polygon")
  expect_identical(v$scene$data[[1]]$geometry$encoding, "geoarrow.multipolygon")
})

test_that("mixed geometry and collections are split by kind, polygons at the bottom", {
  skip_if_not_installed("sf")
  m <- lonlat(list(
    sf::st_point(c(0, -70)),
    sf::st_linestring(rbind(c(0, -60), c(90, -60))),
    ring(-40, 40, -80, -70),
    sf::st_geometrycollection(list(sf::st_point(c(10, -75)), ring(50, 60, -80, -75)))
  ))
  v <- view(m, file = tempfile(fileext = ".html"))
  expect_identical(layer_kinds(v), c("polygon", "path", "point"))
  expect_identical(vapply(v$scene$layers, function(l) l$id, ""), c("m_polygon", "m_path", "m_point"))
  expect_length(blob_geometry(v, "m_polygon"), 2L)
  expect_length(blob_geometry(v, "m_point"), 2L)
})

test_that("geometry that cannot be transformed is left out with a warning", {
  skip_if_not_installed("sf")
  ## The South Pole is the antipode of North Pole Lambert azimuthal equal
  ## area's centre, so PROJ cannot transform it; 60N can be.
  x <- sf::st_sfc(sf::st_point(c(0, -90)), sf::st_point(c(0, 60)), crs = "OGC:CRS84")
  res <- sf::st_transform(x, "ESRI:102017")
  skip_if(!any(sf::st_is_empty(res)) || all(sf::st_is_empty(res)))
  expect_warning(v <- view(x, crs = "ESRI:102017", file = tempfile(fileext = ".html")),
                 "1 of 2 geometries")
  expect_length(blob_geometry(v, "x"), 1L)
})

test_that("unsupported and empty geometry is refused or dropped", {
  skip_if_not_installed("sf")
  e <- lonlat(list(sf::st_point(), sf::st_point(c(0, -70))))
  v <- view(e, file = tempfile(fileext = ".html"))
  expect_length(blob_geometry(v, "e"), 1L)
  expect_error(view(lonlat(list(sf::st_point())), file = tempfile()), "empty")
  expect_error(view(1:3), "no method")
})

test_that("coordinates arrive in the view CRS", {
  skip_if_not_installed("sf")
  x <- lonlat(list(sf::st_point(c(0, -71))))
  v <- view(x, file = tempfile(fileext = ".html"))
  xy <- wk::wk_coords(blob_geometry(v, "x"))
  expected <- sf::st_coordinates(sf::st_transform(x, "EPSG:3031"))
  expect_equal(c(xy$x, xy$y), unname(expected[1, 1:2]), tolerance = 1e-6)
})

test_that("crs = overrides the default, in any form sf and aobcore read", {
  skip_if_not_installed("sf")
  x <- lonlat(list(ring(-40, 40, -80, -70)))
  expect_identical(view(x, crs = 3413, file = tempfile(fileext = ".html"))$scene$view$crs, "EPSG:3413")
  nc <- sf::st_read(system.file("shape", "nc.shp", package = "sf"), quiet = TRUE)
  ## NAD27 / UTM 17N: the same datum as nc, so PROJ needs no datum grid.
  v <- view(nc, crs = "EPSG:26717", file = tempfile(fileext = ".html"))
  expect_identical(v$scene$view$crs, "EPSG:26717")
  expect_gt(min(wk::wk_coords(blob_geometry(v, "nc"))$x), 1e5)
})

test_that("a projected view keeps the data untransformed", {
  skip_if_not_installed("sf")
  x <- sf::st_sfc(sf::st_linestring(rbind(c(0, 0), c(1e6, 1e6))), crs = "EPSG:3031")
  v <- view(x, file = tempfile(fileext = ".html"))
  expect_identical(wk::wk_coords(blob_geometry(v, "x"))$x, c(0, 1e6))
})

test_that("lon/lat edges are densified before a change of CRS", {
  skip_if_not_installed("sf")
  x <- lonlat(list(sf::st_linestring(rbind(c(0, -60), c(90, -60)))))
  n <- function(v) nrow(wk::wk_coords(blob_geometry(v, "x")))
  expect_identical(n(view(x, file = tempfile(fileext = ".html"))), 361L)
  expect_identical(n(view(x, densify = FALSE, file = tempfile(fileext = ".html"))), 2L)
  expect_identical(n(view(x, densify = 45, file = tempfile(fileext = ".html"))), 3L)
  ## No change of CRS, nothing to densify.
  expect_identical(n(view(x, crs = "OGC:CRS84", file = tempfile(fileext = ".html"))), 2L)
  expect_error(view(x, densify = -1, file = tempfile()), "densify")
})

test_that("styles default by kind and can be overridden", {
  skip_if_not_installed("sf")
  x <- lonlat(list(sf::st_linestring(rbind(c(0, -60), c(90, -60)))))
  v <- view(x, fill = c(1, 2, 3, 4), stroke = c(10, 20, 30, 255), stroke_width_px = 3,
            radius_px = 9, file = tempfile(fileext = ".html"))
  l <- v$scene$layers[[1]]
  expect_null(l$fill)
  expect_null(l$radius_px)
  expect_identical(l$stroke, c(10L, 20L, 30L, 255L))
  expect_identical(l$stroke_width_px, 3)
  p <- view(lonlat(list(sf::st_point(c(0, -70)))), radius_px = 9,
            file = tempfile(fileext = ".html"))$scene$layers[[1]]
  expect_identical(p$radius_px, 9)
  expect_identical(p$fill, c(51L, 102L, 204L, 220L))
})

test_that("names become valid layer ids and the page title", {
  skip_if_not_installed("sf")
  x <- lonlat(list(sf::st_point(c(0, -70))))
  v <- view(x, name = "2 stations!", file = tempfile(fileext = ".html"))
  expect_identical(v$scene$layers[[1]]$id, "x2_stations_")
  expect_identical(v$scene$layers[[1]]$label, "2 stations!")
  expect_match(paste(readLines(v$file, warn = FALSE), collapse = ""), "<title>2 stations!</title>",
               fixed = TRUE)
  v2 <- view(sf::st_sf(geometry = x), file = tempfile(fileext = ".html"))
  expect_identical(v2$scene$layers[[1]]$id, "sf_st_sf_geometry_x_")
})

test_that("print shows the view and does not open it when not interactive", {
  skip_if_not_installed("sf")
  x <- lonlat(list(sf::st_point(c(0, -70))))
  v <- view(x, file = tempfile(fileext = ".html"))
  expect_output(print(v), "1 layer in EPSG:3031")
})
