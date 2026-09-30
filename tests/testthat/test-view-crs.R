test_that("a projected CRS is kept", {
  skip_if_not_installed("sf")
  x <- sf::st_sfc(sf::st_point(c(1e6, 2e6)), crs = "EPSG:3031")
  expect_identical(view_crs(x), "EPSG:3031")
  y <- sf::st_sfc(sf::st_point(c(5e5, 4e6)), crs = "EPSG:32617")
  expect_identical(view_crs(y), "EPSG:32617")
})

test_that("lon/lat data south of 40S is viewed in EPSG:3031", {
  skip_if_not_installed("sf")
  expect_identical(view_crs(lonlat(ring(-180, 180, -90, -60))), "EPSG:3031")
  expect_identical(view_crs(lonlat(ring(60, 80, -55, -40))), "EPSG:3031")
  coast <- sf::read_sf(system.file("extdata", "coastline_south_40s.geojson", package = "aobcore"))
  expect_identical(view_crs(coast), "EPSG:3031")
})

test_that("lon/lat data north of 60N is viewed in EPSG:3413", {
  skip_if_not_installed("sf")
  expect_identical(view_crs(lonlat(ring(-180, 180, 60, 90))), "EPSG:3413")
})

test_that("other lon/lat data keeps its own CRS", {
  skip_if_not_installed("sf")
  expect_identical(view_crs(lonlat(ring(-180, 180, -90, -30))), "OGC:CRS84")
  expect_identical(view_crs(lonlat(ring(0, 10, 45, 59))), "OGC:CRS84")
  nc <- sf::read_sf(system.file("shape", "nc.shp", package = "sf"))
  expect_identical(view_crs(nc), "EPSG:4267")
})

test_that("data with no CRS is an error that says how to set one", {
  skip_if_not_installed("sf")
  x <- sf::st_sfc(sf::st_point(c(0, 0)))
  expect_error(view_crs(x), "st_set_crs")
  expect_error(view(x, file = tempfile(fileext = ".html")), "st_set_crs")
})

test_that("a CRS with no code is passed on as the sf crs", {
  skip_if_not_installed("sf")
  x <- sf::st_sfc(sf::st_point(c(0, 0)), crs = "+proj=laea +lat_0=-90 +datum=WGS84")
  expect_s3_class(view_crs(x), "crs")
})
