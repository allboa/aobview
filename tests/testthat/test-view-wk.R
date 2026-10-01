# Vector input through wk (allboa/design decision 0008): bare geometry
# vectors and data frames with a geometry column, reprojected with PROJ.
# None of these tests needs sf.

test_that("a bare wk vector is viewed in its polar CRS, densified", {
  x <- wk::wkt("LINESTRING (0 -60, 90 -60)", crs = "OGC:CRS84")
  expect_identical(view_crs(x), "EPSG:3031")
  v <- view(x, file = html())
  expect_identical(v$scene$view$crs, "EPSG:3031")
  co <- wk::wk_coords(blob_geometry(v, "x"))
  expect_identical(nrow(co), 361L)
  ## Every vertex is on the 60S parallel: the same distance from the pole.
  r <- sqrt(co$x^2 + co$y^2)
  expect_equal(r, rep(r[1], length(r)), tolerance = 1e-9)
  expect_identical(v$sources[[1]]$object, x)
  expect_identical(nrow(wk::wk_coords(blob_geometry(view(x, densify = FALSE, file = html()), "x"))), 2L)
})

test_that("wkb, xy and rct inputs draw as their kinds", {
  pts <- wk::xy(c(110.53, 77.97), c(-66.28, -68.58), crs = "OGC:CRS84")
  expect_identical(layer_kinds(view(pts, file = html())), "point")
  box <- wk::rct(-1e6, -1e6, 1e6, 1e6, crs = "EPSG:3031")
  v <- view(box, file = html())
  expect_identical(layer_kinds(v), "polygon")
  expect_identical(v$scene$view$crs, "EPSG:3031")
  wkb <- wk::as_wkb(wk::wkt("MULTILINESTRING ((0 0, 1e5 1e5))", crs = "EPSG:3031"))
  expect_identical(layer_kinds(view(wkb, file = html())), "path")
})

test_that("a data frame's geometry column is found or named, the rest are attributes", {
  df <- data.frame(base = c("Casey", "Davis"), staff = c(70, 80))
  df$geom <- wk::xy(c(110.53, 77.97), c(-66.28, -68.58), crs = "OGC:CRS84")
  v <- view(df, zcol = "base", file = html())
  expect_identical(v$scene$view$crs, "EPSG:3031")
  expect_identical(blob_names(v, "df"), c("base", "staff", "geometry", "color"))
  expect_identical(blob_column(v, "df", "staff"), c(70, 80))
  expect_length(v$scene$legends, 1L)
  expect_identical(v$sources[[1]]$object, df)
  ## Two geometry columns: the first, or the one named.
  df$other <- wk::xy(c(0, 1e5), c(0, 1e5), crs = "EPSG:3031")
  expect_identical(view_crs(df), "EPSG:3031")
  v2 <- view(df, geometry = "other", popup = "base", file = html())
  expect_equal(wk::wk_coords(blob_geometry(v2, "df"))$x, c(0, 1e5))
  expect_error(view(df, geometry = "base", file = html()), "not geometry that wk can read")
  expect_error(view(df, geometry = "nope", file = html()), "must name a column")
  expect_error(view(df, popup = "geom", file = html()), "geometry column")
  expect_error(view(data.frame(a = 1), file = html()), "no geometry column")
})

test_that("geometry with no CRS, a grd and other classes are errors", {
  expect_error(view(wk::wkt("POINT (0 0)"), file = html()), "wk_set_crs")
  expect_error(view_crs(wk::wkt("POINT (0 0)")), "pass `crs`")
  expect_error(view(wk::wkt("POINT (0 0)"), crs = "EPSG:3031", file = html()),
               "before viewing it in EPSG:3031")
  expect_error(view(wk::grd(nx = 2, ny = 2), file = html()), "grd")
  expect_error(view(list(1:3), file = html()), "List element 1")
  expect_error(view(wk::wkt("POINT (0 0)", crs = "EPSG:3031"), geometry = "g", file = html()),
               "does not use")
})

test_that("a vertex PROJ cannot transform leaves its feature out", {
  x <- wk::wkt(c("LINESTRING (0 -70, 10 -70)", "LINESTRING (0 -70, 0 60)", "POINT (5 -80)"),
               crs = "OGC:CRS84")
  ortho <- "+proj=ortho +lat_0=-90 +lon_0=0"
  expect_warning(v <- view(x, crs = ortho, densify = FALSE, file = html()),
                 "1 of 3 geometries could not be transformed")
  expect_identical(v$sources[[1]]$layers$x_path, 1L)
  expect_identical(v$sources[[1]]$layers$x_point, 3L)
})

test_that("geometry collections are flattened in place, nested ones too", {
  x <- wk::wkt(c(
    "POINT (0 -70)",
    "GEOMETRYCOLLECTION (POINT (10 -70), GEOMETRYCOLLECTION (LINESTRING (0 -80, 10 -80)))",
    "GEOMETRYCOLLECTION EMPTY",
    "POINT (20 -70)"), crs = "OGC:CRS84")
  v <- view(x, file = html())
  m <- v$sources[[1]]$layers
  expect_identical(m$x_path, 2L)
  expect_identical(m$x_point, c(1L, 2L, 4L))
})

test_that("CRS facts come from PROJ", {
  expect_true(crs_is_lonlat("OGC:CRS84"))
  expect_true(crs_is_lonlat("EPSG:4326"))
  expect_true(crs_is_lonlat("+proj=longlat +datum=WGS84 +towgs84=0,0,0"))
  expect_false(crs_is_lonlat("EPSG:3031"))
  expect_false(crs_is_lonlat("EPSG:4978"))
  expect_identical(crs_code("EPSG:3031"), "EPSG:3031")
  expect_identical(crs_code(PROJ::proj_crs_text("EPSG:3413")), "EPSG:3413")
  expect_identical(crs_code(PROJ::proj_crs_text("OGC:CRS84")), "OGC:CRS84")
  expect_null(crs_code("+proj=laea +lat_0=-90 +datum=WGS84"))
  expect_true(same_crs("EPSG:3031", PROJ::proj_crs_text("EPSG:3031")))
  expect_false(same_crs("EPSG:3031", "EPSG:3413"))
  ## PROJ's proj_crs_text() crashes on these: they are caught first.
  expect_error(proj_wkt("not a crs"), "PROJ cannot read")
  expect_error(proj_wkt("EPSG:999999"), "PROJ cannot read")
  expect_error(proj_wkt(""), "PROJ cannot read")
  expect_error(view(wk::wkt("POINT (0 0)", crs = "+proj=foo"), file = html()),
               "PROJ cannot read")
})

test_that("a list mixes wk geometry, data frames and sf", {
  skip_if_not_installed("sf")
  a <- wk::wkt("LINESTRING (0 -60, 90 -60)", crs = "OGC:CRS84")
  b <- sf::st_sfc(sf::st_point(c(0, -2e6)), crs = "EPSG:3031")
  v <- view(list(a = a, b = b), file = html())
  expect_identical(v$scene$view$crs, "EPSG:3031")
  expect_identical(layer_kinds(v), c("path", "point"))
})

test_that("a SpatVector is read through terra's WKB, without sf", {
  skip_if_not_installed("terra")
  sv <- terra::vect(c("POINT (110.53 -66.28)", "POINT (77.97 -68.58)"), crs = "OGC:CRS84")
  sv$base <- c("Casey", "Davis")
  rec <- vector_record(sv)
  expect_s3_class(rec$geom, "wk_wkb")
  expect_identical(rec$attrs$base, c("Casey", "Davis"))
  v <- view(sv, popup = "base", file = html())
  expect_identical(blob_column(v, "sv", "base"), c("Casey", "Davis"))
  expect_s4_class(v$sources[[1]]$object, "SpatVector")
})
