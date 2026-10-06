# Arrow streams, Arrow tables, DuckDB results and GDALVector$fetch() output
# as inputs (allboa/design decision 0011, aobview#40). A stream is read
# once into a data frame of its rows; the geometry column is found by
# GeoArrow extension type, else named by `geometry`, and its CRS read from
# the metadata, else given by `crs`.

## Two Antarctic stations as a geoarrow vector in lon/lat, with attributes.
stations <- function() {
  df <- data.frame(base = c("Casey", "Davis"), staff = c(70, 80))
  df$geom <- geoarrow::as_geoarrow_vctr(
    wk::xy(c(110.53, 77.97), c(-66.28, -68.58), crs = "OGC:CRS84"))
  df
}

## A stream of the rows of df, one batch per row.
batched_stream <- function(df) {
  batches <- lapply(seq_len(nrow(df)), function(i) {
    nanoarrow::as_nanoarrow_array(df[i, , drop = FALSE])
  })
  nanoarrow::basic_array_stream(batches)
}

## WKB of a point, as the raw bytes a binary column holds.
point_wkb <- function(x, y) unclass(wk::as_wkb(wk::xy(x, y)))[[1]]

ccamlr_layer <- function() {
  skip_if_not_installed("gdalraster")
  ok <- !inherits(try(gdalraster::srs_to_wkt("EPSG:3031"), silent = TRUE), "try-error")
  skip_if_not(ok, "gdalraster cannot resolve EPSG:3031 (PROJ database not found)")
  methods::new(gdalraster::GDALVector,
               system.file("extdata", "ccamlr_statistical_areas.geojson", package = "aobview"))
}

test_that("a nanoarrow stream of several batches is read once, CRS from its metadata", {
  df <- stations()
  s <- batched_stream(df)
  expect_true(is_stream_input(s))
  v <- view(s, zcol = "base", file = html())
  expect_identical(v$scene$view$crs, "EPSG:3031")
  expect_identical(layer_kinds(v), "point")
  expect_identical(blob_names(v, "s"), c("base", "staff", "geometry", "color"))
  expect_identical(blob_df(v, "s")$staff, c(70, 80))
  expect_length(v$scene$legends, 1L)
  ## The view keeps the rows the stream was read into, geometry as wkb in
  ## the stream's CRS.
  src <- v$sources[[1]]$object
  expect_s3_class(src, "data.frame")
  expect_identical(names(src), c("base", "staff", "geom"))
  expect_s3_class(src$geom, "wk_wkb")
  expect_identical(crs_code(wk::wk_crs(src$geom)), "OGC:CRS84")
  expect_identical(v$sources[[1]]$layers$s, 1:2)
  ## Read once: the stream has nothing left.
  expect_error(view(s, file = html()), "has no rows")
  ## view_crs() of a stream reads it too.
  expect_identical(view_crs(batched_stream(df)), "EPSG:3031")
})

test_that("the geometry column is named with `geometry`, and no CRS needs `crs`", {
  df <- data.frame(name = c("a", "b"), wkb = I(list(point_wkb(0, -2e6), point_wkb(1e5, -2e6))))
  s <- nanoarrow::as_nanoarrow_array_stream(df)
  expect_identical(s$get_schema()$children$wkb$format, "z")
  expect_error(view(nanoarrow::as_nanoarrow_array_stream(df), file = html()),
               "no column with a GeoArrow extension type")
  expect_error(view(nanoarrow::as_nanoarrow_array_stream(df), geometry = "wkb", file = html()),
               "no CRS in its GeoArrow metadata")
  expect_error(view(nanoarrow::as_nanoarrow_array_stream(df), geometry = "nope", file = html()),
               "`geometry` must name a column")
  expect_error(view(nanoarrow::as_nanoarrow_array_stream(df), geometry = "name", file = html()),
               "\"name\" of `x` is not WKT text")
  expect_error(view(nanoarrow::as_nanoarrow_array_stream(data.frame(n = 1)), geometry = "n",
                    file = html()), "\"n\" of `x` is not geometry")
  v <- view(s, geometry = "wkb", crs = 3031, popup = "name", file = html())
  expect_identical(v$scene$view$crs, "EPSG:3031")
  expect_equal(wk::wk_coords(blob_geometry(v, "s"))$x, c(0, 1e5))
  expect_identical(crs_code(wk::wk_crs(v$sources[[1]]$object$wkb)), "EPSG:3031")
  ## WKT text, and a misspelled argument.
  wkt <- data.frame(name = "a", geom = "POINT (0 -2e6)")
  v2 <- view(nanoarrow::as_nanoarrow_array_stream(wkt), geometry = "geom", crs = "EPSG:3031",
             file = html())
  expect_identical(layer_kinds(v2), "point")
  expect_error(view(nanoarrow::as_nanoarrow_array_stream(wkt), geometry = "geom",
                    crs = "EPSG:3031", fil = html()), "does not use `fil`")
  ## A stream that is not of rows.
  ints <- nanoarrow::as_nanoarrow_array_stream(nanoarrow::as_nanoarrow_array(1:3))
  expect_error(view(ints, file = html()), "not of rows")
})

test_that("a stream joins a list and a view, taking the view's CRS when it has none", {
  df <- stations()
  coast <- wk::wkt("LINESTRING (0 -60, 90 -60)", crs = "OGC:CRS84")
  v <- view(list(coast = coast, bases = batched_stream(df)), file = html())
  expect_identical(v$scene$view$crs, "EPSG:3031")
  expect_identical(layer_kinds(v), c("path", "point"))
  expect_s3_class(v$sources[[2]]$object, "data.frame")
  expect_identical(blob_df(v, "bases")$base, c("Casey", "Davis"))
  ## No CRS in the metadata: the list's `crs`, else an error naming the
  ## element; in view_add(), the view's CRS.
  nocrs <- data.frame(name = "a", geom = geoarrow::as_geoarrow_vctr(wk::xy(0, -2e6)))
  expect_error(view(list(coast, nanoarrow::as_nanoarrow_array_stream(nocrs)), file = html()),
               "List element 2 .*no CRS in its GeoArrow metadata")
  v2 <- view(list(coast = coast, pts = nanoarrow::as_nanoarrow_array_stream(nocrs)),
             crs = "EPSG:3031", file = html())
  expect_equal(wk::wk_coords(blob_geometry(v2, "pts"))$y, -2e6)
  wkb <- data.frame(name = "a", wkb = I(list(point_wkb(0, -2e6))))
  expect_error(view(list(coast, nanoarrow::as_nanoarrow_array_stream(wkb)), file = html()),
               "List element 2 .*no column with a GeoArrow")
  v3 <- view_add(view(coast, file = html()), nanoarrow::as_nanoarrow_array_stream(wkb),
                 geometry = "wkb", name = "pts", file = html())
  expect_identical(layer_kinds(v3), c("path", "point"))
  expect_equal(wk::wk_coords(blob_geometry(v3, "pts"))$y, -2e6)
  expect_identical(view_crs(list(coast, batched_stream(df))), "EPSG:3031")
})

test_that("an arrow Table and a RecordBatchReader are viewed through their streams", {
  skip_if_not_installed("arrow")
  df <- stations()
  tb <- arrow::as_arrow_table(df)
  expect_true(is_stream_input(tb))
  expect_false(is_stream_input(df))
  expect_false(is_stream_input(df$geom))
  v <- view(tb, popup = "base", file = html())
  expect_identical(v$scene$view$crs, "EPSG:3031")
  expect_identical(blob_names(v, "tb"), c("base", "geometry"))
  expect_identical(v$sources[[1]]$name, "tb")
  expect_s3_class(v$sources[[1]]$object, "data.frame")
  rdr <- arrow::as_record_batch_reader(arrow::as_arrow_table(df))
  v2 <- view_add(v, rdr, fill = c(220L, 60L, 40L, 255L), file = html())
  expect_identical(layer_kinds(v2), c("point", "point"))
  expect_identical(v2$scene$layers[[2]]$fill, c(220L, 60L, 40L, 255L))
  expect_identical(v2$sources[[2]]$name, "rdr")
  ## A binary WKB column with no GeoArrow type: named, in `crs`.
  tb2 <- arrow::arrow_table(name = c("a", "b"),
                            geom = arrow::Array$create(list(point_wkb(0, -2e6),
                                                            point_wkb(1e5, -2e6)),
                                                       type = arrow::binary()))
  v3 <- view(tb2, geometry = "geom", crs = "EPSG:3031", file = html())
  expect_equal(wk::wk_coords(blob_geometry(v3, "tb2"))$x, c(0, 1e5))
  expect_error(view(tb2, file = html()), "`geometry =`")
  ## A Table streams afresh each time.
  v4 <- view(list(a = tb, b = tb), file = html())
  expect_identical(layer_kinds(v4), c("point", "point"))
})

test_that("a duckdb result fetched as Arrow is viewed, a blob column as WKB", {
  skip_if_not_installed("duckdb")
  skip_if_not_installed("DBI")
  skip_if_not_installed("arrow")
  con <- DBI::dbConnect(duckdb::duckdb(shared_home = FALSE))
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  hex <- vapply(list(point_wkb(110.53, -66.28), point_wkb(77.97, -68.58)),
                function(b) paste(format(b), collapse = ""), "")
  sql <- sprintf("SELECT name, staff, from_hex(hex) AS geom FROM (VALUES ('Casey', 70, '%s'), ('Davis', 80, '%s')) t(name, staff, hex)",
                 hex[1], hex[2])
  res <- DBI::dbSendQuery(con, sql, arrow = TRUE)
  tb <- duckdb::duckdb_fetch_arrow(res)
  DBI::dbClearResult(res)
  expect_true(is_stream_input(tb))
  v <- view(tb, geometry = "geom", crs = "OGC:CRS84", zcol = "staff", file = html())
  expect_identical(v$scene$view$crs, "OGC:CRS84")
  expect_identical(blob_names(v, "tb"), c("name", "staff", "geometry", "color"))
  expect_equal(wk::wk_coords(blob_geometry(v, "tb"))$x, c(110.53, 77.97))
  src <- v$sources[[1]]$object
  expect_identical(src$name, c("Casey", "Davis"))
  expect_s3_class(src$geom, "wk_wkb")
  ## A record batch reader, added to a view: in the view's CRS.
  res <- DBI::dbSendQuery(con, sql, arrow = TRUE)
  rdr <- duckdb::duckdb_fetch_record_batch(res)
  v2 <- view_add(v, rdr, geometry = "geom", popup = FALSE, file = html())
  DBI::dbClearResult(res)
  expect_identical(layer_kinds(v2), c("point", "point"))
  expect_identical(v2$sources[[2]]$layers$rdr, 1:2)
})

test_that("GDALVector$fetch() output is viewed with the layer's SRS", {
  lyr <- ccamlr_layer()
  on.exit(lyr$close(), add = TRUE)
  x <- lyr$fetch(-1)
  expect_s3_class(x, "OGRFeatureSet")
  expect_type(x$geom, "list")
  expect_identical(view_crs(x), "EPSG:6932")
  rec <- vector_record(x)
  expect_s3_class(rec$geom, "wk_wkb")
  expect_identical(rec$geometry, "geom")
  expect_identical(names(rec$attrs), setdiff(names(x), "geom"))
  x$area <- paste0("Area ", substr(x$GAR_Long_Label, 1, 2))
  pop <- c("GAR_Name", "GAR_Long_Label", "GAR_Size")
  v <- view(x, crs = "EPSG:3031", zcol = "area", popup = pop, file = html())
  expect_identical(v$scene$version, "0.5")
  expect_identical(layer_kinds(v), "polygon")
  expect_identical(v$sources[[1]]$layers$x, 1:19)
  expect_identical(legend_labels(v$scene$legends[[1]]), c("Area 48", "Area 58", "Area 88"))
  expect_identical(blob_df(v, "x")$GAR_Name, x$GAR_Name)
  ## Rows as fetched.
  expect_s3_class(v$sources[[1]]$object, "OGRFeatureSet")
  expect_identical(x[2:3, ]$GAR_Name, x$GAR_Name[2:3])
  expect_error(view(x, geometry = "GAR_Name", file = html()),
               "must name a geometry column of `x`; it has \"geom\"")
  ## A set fetched as WKT, and one fetched without geometry.
  lyr$returnGeomAs <- "WKT"
  lyr$resetReading()
  w <- lyr$fetch(3)
  expect_type(w$geom, "character")
  v2 <- view(w, crs = "EPSG:3031", file = html())
  expect_identical(v2$sources[[1]]$layers$w, 1:3)
  lyr$returnGeomAs <- "NONE"
  lyr$resetReading()
  expect_error(view(lyr$fetch(3), file = html()), "fetched without geometry")
  ## A list with a feature set, and the layer's own Arrow stream, whose
  ## WKB column (ogc.wkb) has no CRS: the layer's SRS as `crs`.
  lyr$returnGeomAs <- "WKB"
  lyr$resetReading()
  v3 <- view(list(areas = lyr$fetch(2), coast = wk::wkt("LINESTRING (0 -60, 90 -60)", crs = "OGC:CRS84")),
             file = html())
  expect_identical(v3$scene$view$crs, "EPSG:6932")
  lyr$resetReading()
  v4 <- view(lyr$getArrowStream(), crs = lyr$getSpatialRef(), popup = "GAR_Name",
             name = "areas", file = html())
  expect_identical(v4$scene$view$crs, "EPSG:6932")
  expect_identical(blob_df(v4, "areas")$GAR_Name, x$GAR_Name)
  expect_identical(v4$sources[[1]]$layers[[1]], 1:19)
})

test_that("selected() on a stream gives the rows it was read into", {
  skip_if_no_httpuv()
  on.exit(aobcore::stop_scene_servers(), add = TRUE)
  df <- data.frame(id = 11:14, name = letters[1:4])
  df$geom <- geoarrow::as_geoarrow_vctr(
    wk::xy(c(0, 10, 20, 30), c(-70, -70, -70, -70), crs = "OGC:CRS84"))
  s <- batched_stream(df)
  v <- serve(s, crs = "EPSG:3031", popup = FALSE)
  skip_if_no_socket(v)
  expect_identical(v$sources[[1]]$name, "x")
  none <- selected(v)
  expect_s3_class(none, "data.frame")
  expect_identical(nrow(none), 0L)
  expect_identical(names(none), c("id", "name", "geom"))
  page <- page_connect(v)
  page_select(page, list(x = c(0, 2)), scene = v$serial, srv = v$server)
  sel <- selection(v)
  expect_identical(sel$source, c("x", "x"))
  expect_identical(sel$row, c(1L, 3L))
  rows <- selected(v)
  expect_s3_class(rows, "data.frame")
  expect_identical(rows$id, c(11L, 13L))
  expect_identical(rownames(rows), c("1", "3"))
  expect_s3_class(rows$geom, "wk_wkb")
  expect_identical(crs_code(wk::wk_crs(rows$geom)), "OGC:CRS84")
  page_close(page)
})
