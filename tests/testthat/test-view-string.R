# A string as input (allboa/aobview#39): WKT text, or the path, URL or GDAL
# data source name of a raster or vector source, probed with gdalraster.

view_ids <- function(v) vapply(v$scene$layers, function(l) l$id, "")
view_labels <- function(v) vapply(v$scene$layers, function(l) l$label, "")

ccamlr_path <- function() {
  system.file("extdata", "ccamlr_statistical_areas.geojson", package = "aobview")
}

test_that("WKT text stays geometry, never probed, with its SRID as CRS", {
  local_mocked_bindings(probe_source = function(dsn, layer = NULL) stop("probed ", dsn))
  x <- "SRID=4326;LINESTRING (0 -60, 90 -60)"
  expect_identical(view_crs(x), "EPSG:3031")
  v <- view(x, file = html())
  expect_identical(v$scene$view$crs, "EPSG:3031")
  expect_identical(layer_kinds(v), "path")
  expect_identical(v$name, "x")
  ## Densified in lon/lat, as wk::wkt() input is.
  expect_identical(nrow(wk::wk_coords(blob_geometry(v, "x"))), 361L)
  expect_s3_class(v$sources[[1]]$object, "wk_wkt")
  expect_identical(wk::wk_crs(v$sources[[1]]$object), "EPSG:4326")
  ## The vector arguments apply.
  v2 <- view(x, stroke = c(200, 0, 0, 255), densify = FALSE, file = html())
  expect_identical(v2$scene$layers[[1]]$stroke, c(200L, 0L, 0L, 255L))
  expect_identical(nrow(wk::wk_coords(blob_geometry(v2, "x"))), 2L)
  expect_error(view(x, palette = "ocean", file = html()), "`palette`")
  expect_error(view(x, layer = 1, file = html()), "WKT text")
  ## Plain WKT has no CRS.
  expect_error(view("POINT (0 -70)", file = html()), "SRID")
  expect_error(view(c("POINT (0 -70)", "POINT (1 -70)"), file = html()), "one string")
  expect_error(view("", file = html()), "one string")
  ## A WKT string in a list, and added to a view.
  v3 <- view(list(x, "SRID=4326;POINT (0 -70)"), file = html())
  expect_identical(layer_kinds(v3), c("path", "point"))
  expect_identical(view_labels(v3), c("x", "SRID=4326;POINT (0 -70)"))
  v4 <- view_add(view(x, file = html()), "SRID=4326;POINT (0 -70)", file = html())
  expect_identical(layer_kinds(v4), c("path", "point"))
})

test_that("a string literal is named by its base name, its layer or its WKT text", {
  lit <- function(x, layer = NULL) string_name(x, x, layer)
  expect_identical(lit("https://example.org/data/polar_3031.tif"), "polar_3031")
  expect_identical(lit("/vsis3/bucket/sst.tif"), "sst")
  expect_identical(lit("C:/data/areas.gpkg"), "areas")
  expect_identical(lit("C:/data/areas.gpkg", layer = "roads"), "roads")
  expect_identical(lit("C:/data/areas.gpkg", layer = 2), "areas")
  expect_identical(lit("NETCDF:\"a.nc\":sst"), "NETCDF:\"a.nc\":sst")
  expect_identical(lit("SRID=4326;POINT (0 -70)"), "SRID=4326;POINT (0 -70)")
  expect_identical(nchar(lit(paste0("SRID=4326;LINESTRING (", strrep("0 0, ", 40), "1 1)"))), 60L)
  ## A variable is named by its expression, as any input is.
  expect_identical(string_name("a.tif", quote(f)), "f")
})

test_that("a string that looks like a path or URL is a data source, not WKT", {
  expect_true(looks_like_source("https://example.org/a.tif"))
  expect_true(looks_like_source("s3://bucket/a.parquet"))
  expect_true(looks_like_source("/vsis3/bucket/a.tif"))
  expect_true(looks_like_source(ccamlr_path()))
  expect_false(looks_like_source("POINT (0 -70)"))
  expect_false(looks_like_source("nonsense"))
  expect_false(looks_like_source("NETCDF:\"a.nc\":sst"))
})

test_that("a data source needs gdalraster, with a clear error; WKT text does not", {
  local_mocked_bindings(has_gdalraster = function() FALSE)
  expect_error(view(ccamlr_path(), file = html()), "'gdalraster' package")
  expect_error(view("https://example.org/a.tif", file = html()),
               "install.packages\\(\"gdalraster\"\\)")
  expect_error(view_crs("/vsis3/bucket/a.tif"), "'gdalraster' package")
  v <- view("SRID=4326;POINT (0 -70)", file = html())
  expect_identical(layer_kinds(v), "point")
})

test_that("a string that is neither WKT nor a source GDAL opens is an error", {
  skip_if_no_gdalraster()
  expect_error(view("nonsense", file = html()), "cannot open .* and wk cannot read it as WKT")
  expect_error(view("/no/such/file.tif", file = html()), "GDAL cannot open")
  ## A source GDAL opens but cannot draw.
  expect_error(view(ccamlr_path(), layer = "nope", file = html()),
               "\"ccamlr_statistical_areas\"")
  expect_error(view(ccamlr_path(), layer = 2, file = html()), "must name one layer")
})

test_that("a local COG path is drawn from that COG, as a SpatRaster read from it is", {
  skip_if_no_gdalraster()
  f <- extdata("polar_3031.tif")
  expect_identical(view_crs(f), "EPSG:3031")
  v <- view(f, file = html())
  expect_s3_class(v, "aob_view")
  expect_identical(v$scene$view$crs, "EPSG:3031")
  expect_identical(layer_kinds(v), "tiled_raster")
  expect_identical(v$name, "f")
  l <- v$scene$layers[[1]]
  expect_identical(l$palette$name, "viridis")
  ## The source COG itself, embedded (a local file), referenced by its name.
  expect_identical(v$scene$data$f, list(format = "cog", url = "polar_3031.tif"))
  expect_gt(length(tile_blobs(v)), 0L)
  expect_equal(v$scene$view$extent, c(-6400000, 6400000, -6400000, 6400000))
  expect_identical(v$scene$legends, NULL)
  v2 <- view(f, palette = "ocean", range = c(0, 1), legend = FALSE, name = "polar_3031",
             file = html())
  expect_identical(view_ids(v2), "polar_3031")
  expect_identical(v2$scene$layers[[1]]$palette$name, "ocean")
  expect_identical(v2$scene$layers[[1]]$palette$range, c(0, 1))
  expect_error(view(f, layer = 2, file = html()), "band number from 1 to 1")
  expect_error(view(f, rgb = TRUE, file = html()), "needs 3 or 4 bands")
  expect_error(view(f, zcol = "a", file = html()), "zcol")
})

test_that("a COG path gives the same layer as the SpatRaster read from it", {
  skip_if_no_terra()
  f <- extdata("polar_lonlat.tif")
  a <- view(f, name = "r", file = html())
  b <- view(terra::rast(f), name = "r", file = html())
  expect_identical(a$scene$view$crs, "EPSG:3031")
  expect_identical(a$scene$data, b$scene$data)
  expect_identical(a$scene$layers, b$scene$layers)
  expect_identical(a$scene$view$extent, b$scene$view$extent)
})

test_that("a COG URL is referenced by URL, not embedded", {
  skip_if_no_gdalraster()
  skip_on_cran()
  url <- paste0("https://raw.githubusercontent.com/allboa/aobcore/",
                "5ecd9b0c5a877491d1da534a0454f52650d346d1/inst/extdata/polar_3031.tif")
  reach <- tryCatch(aobcore::cog_info(url), error = function(e) NULL)
  skip_if(is.null(reach), "the COG URL is not reachable")
  for (src in c(url, paste0("/vsicurl/", url))) {
    v <- view(src, name = "polar_3031", file = html())
    expect_identical(v$scene$data$polar_3031, list(format = "cog", url = url))
    expect_length(tile_blobs(v), 0L)
    expect_identical(names(aobcore::scene_blobs(v$scene)),
                     c("polar_3031_vertices", "polar_3031_indices"))
    expect_equal(v$local_bytes, 0)
  }
})

test_that("a raster that is not a COG is read through GDAL into a temporary COG", {
  skip_if_no_gdalraster()
  skip_if_no_terra()
  ## A striped GeoTIFF of 256 x 256 cells: GDAL reads it whole, at full
  ## resolution, with nothing to say.
  f <- small_merc_tif()
  expect_false(cog_ready(aobcore::cog_info(f)))
  expect_identical(view_crs(f), "EPSG:3857")
  seen <- gdal_temp_seen(expect_silent(v <- view(f, name = "merc", file = html())))
  expect_identical(layer_kinds(v), "tiled_raster")
  expect_identical(v$scene$view$crs, "EPSG:3857")
  expect_match(v$scene$data$merc$url, "^view-.*[.]tif$")
  expect_equal(seen$gs$factor, 1)
  expect_equal(seen$dim, c(256, 256))
  expect_equal(range(seen$values), c(1, 250))
  expect_gt(length(tile_blobs(v)), 0L)
  ## An argument the plan does not take is an error before the temporary
  ## COG is written.
  local({
    local_mocked_bindings(gdal_temp_cog = function(...) stop("a temporary COG was written"))
    expect_error(view(f, zcol = "a", file = html()), "does not use `zcol`")
    expect_error(view(f, max_tile = 4, file = html()), "does not use `max_tile`")
  })
  ## A huge virtual grid (VRT) is reduced to what the plan draws, with a
  ## message, as for a SpatRaster.
  vrt <- huge_vrt(f)
  seen <- gdal_temp_seen(expect_message(v2 <- view(vrt, max_tiles = 64, file = html()),
                                        "read through GDAL from a dataset of 16777216"))
  expect_equal(seen$gs$factor, 2^13)
  expect_equal(seen$dim, c(2048, 2048))
  ## Band 2 of a 3-band file through the palette.
  f3 <- small_merc_tif(3L)
  seen <- gdal_temp_seen(v3 <- view(f3, layer = 2, file = html()))
  expect_identical(seen$gs$bands, 2L)
  expect_equal(range(seen$values), c(1, 250))
  expect_false(isTRUE(v3$scene$layers[[1]]$rgb))
})

test_that("a colour image by name draws its bands red, green, blue, with the mask as alpha", {
  skip_if_no_gdalraster()
  skip_if_no_terra()
  src <- small_merc_tif(3L, nodata = 0)
  r <- huge_vrt(src, 3L, n = 1024, interp = c("Red", "Green", "Blue"), nodata = 0)
  ## The VRT's member is a striped GeoTIFF, so it is not a mosaic of COGs
  ## drawn in place (#41): a message says so, then GDAL reads it.
  seen <- gdal_temp_seen(expect_message(v <- view(r, name = "img", file = html()),
                                        "not a tiled GeoTIFF with overviews"))
  expect_identical(v$scene$layers[[1]]$rgb, list(bands = 1:3, alpha = 4L))
  expect_equal(seen$cog$samples_per_pixel, 4L)
  expect_equal(mean(seen$values[, 4] == 0), 1 / 16, tolerance = 0.01)
  ## `layer` or `palette` takes one band through the palette instead.
  seen <- gdal_temp_seen(v2 <- view(r, palette = "gray", file = html()))
  expect_identical(seen$gs$bands, 1L)
  expect_identical(v2$scene$layers[[1]]$palette$name, "gray")
})

test_that("the CCAMLR GeoJSON by its path draws as the sf data frame does", {
  skip_if_no_gdalraster()
  gj <- ccamlr_path()
  expect_identical(view_crs(gj), "EPSG:6932")
  pop <- c("GAR_Name", "GAR_Long_Label")
  v <- view(gj, crs = "EPSG:3031", zcol = "GAR_Size", popup = pop, name = "areas",
            file = html())
  expect_identical(v$scene$view$crs, "EPSG:3031")
  expect_identical(v$scene$version, "0.5")
  expect_identical(layer_kinds(v), "polygon")
  expect_identical(v$scene$layers[[1]]$popup, list(columns = as.list(pop)))
  expect_length(v$scene$legends, 1L)
  expect_identical(v$scene$legends[[1]]$title, "GAR_Size")
  expect_identical(blob_names(v, "areas"), c(pop, "geometry", "color"))
  ## 19 polygons, in EPSG:3031 metres, from the stream GDAL reprojected.
  g <- blob_geometry(v, "areas")
  expect_length(g, 19L)
  expect_true(all(abs(wk::wk_coords(g)$x) < 6e6))
  ref <- as.data.frame(aobcore::gdal_vector_stream(gj, "EPSG:3031"))
  expect_identical(blob_df(v, "areas")$GAR_Name, ref$GAR_Name)
  ## The source kept for selection() is the data frame read, 19 rows.
  expect_s3_class(v$sources[[1]]$object, "data.frame")
  expect_identical(nrow(v$sources[[1]]$object), 19L)
  expect_identical(v$sources[[1]]$layers$areas, 1:19)
  expect_valid_scene(v)
  ## Its own projected CRS by default; the layer by name or number.
  v2 <- view(gj, layer = "ccamlr_statistical_areas", file = html())
  expect_identical(v2$scene$view$crs, "EPSG:6932")
  expect_identical(v2$name, "gj")
  expect_identical(view(gj, layer = 1, name = "a", file = html())$scene$view$crs, "EPSG:6932")
  expect_error(view(gj, palette = "ocean", file = html()), "give `zcol` too")
})

test_that("a lon/lat vector source is densified in GDAL before the polar view", {
  skip_if_no_gdalraster()
  coast <- extdata("coastline_south_40s.geojson")
  expect_identical(view_crs(coast), "EPSG:3031")
  v <- view(coast, file = html())
  expect_identical(v$scene$view$crs, "EPSG:3031")
  expect_identical(v$name, "coast")
  expect_identical(layer_kinds(v), "path")
  n <- nrow(wk::wk_coords(blob_geometry(v, "coast")))
  raw <- as.data.frame(aobcore::gdal_vector_stream(coast, "OGC:CRS84"))
  n0 <- nrow(wk::wk_coords(wk::as_wkb(raw$geometry)))
  expect_gt(n, n0)
  v2 <- view(coast, densify = FALSE, file = html())
  expect_identical(nrow(wk::wk_coords(blob_geometry(v2, "coast"))), n0)
  ## In the file's own (geographic) CRS nothing is densified or transformed.
  v3 <- view(coast, crs = "EPSG:4326", file = html())
  expect_identical(nrow(wk::wk_coords(blob_geometry(v3, "coast"))), n0)
  expect_true(all(abs(wk::wk_coords(blob_geometry(v3, "coast"))$x) <= 180))
})

test_that("strings mix with other inputs in a list and in view_add()", {
  skip_if_no_gdalraster()
  sst <- extdata("polar_3031.tif")
  coast <- extdata("coastline_south_40s.geojson")
  v <- view(list(sst = sst, coast = coast, areas = ccamlr_path()), file = html())
  expect_identical(v$scene$view$crs, "EPSG:3031")
  expect_identical(layer_kinds(v), c("tiled_raster", "path", "polygon"))
  expect_identical(view_ids(v), c("sst", "coast", "areas"))
  ## Unnamed elements are named by their expressions, a string literal
  ## by its text.
  v2 <- view(list(sst, "SRID=4326;POINT (0 -70)"), file = html())
  expect_identical(view_labels(v2), c("sst", "SRID=4326;POINT (0 -70)"))
  expect_identical(list_labels(list("a", "b"), quote(list("/data/a.tif", "s3://b/c.gpkg"))),
                   c("a", "c"))
  areas <- ccamlr_path()
  v3 <- view_add(view(sst, file = html()), areas, zcol = "GAR_Size", legend = FALSE,
                 file = html())
  expect_identical(layer_kinds(v3), c("tiled_raster", "polygon"))
  expect_identical(view_labels(v3)[2], "areas")
  expect_error(view(list(1:3), file = html()), "and strings")
})
