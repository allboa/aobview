# A VRT or GTI mosaic of COGs is planned across its members, one
# tiled_raster layer per member, with no temporary COG (allboa/aobview#41,
# allboa/design decisions 0010 and 0011).

view_ids <- function(v) vapply(v$scene$layers, function(l) l$id, "")
view_labels <- function(v) vapply(v$scene$layers, function(l) l$label, "")

## Run expr with both temporary-COG writers refused (for that call only).
no_temp_cog <- function(expr) {
  local_mocked_bindings(
    gdal_temp_cog = function(...) stop("a temporary COG was written through GDAL"),
    raster_temp_cog = function(...) stop("terra wrote a temporary COG")
  )
  force(expr)
}

test_that("a VRT over two local COGs gives one layer per member, referenced by their files", {
  skip_if_no_terra()
  h <- cog_halves()
  r <- terra::rast(h$vrt)
  expect_null(raster_cog_source(r))
  v <- no_temp_cog(expect_silent(view(r, file = html())))
  expect_identical(layer_kinds(v), c("tiled_raster", "tiled_raster"))
  expect_identical(view_ids(v), c("r_1", "r_2"))
  expect_identical(view_labels(v), c("r: west.tif", "r: east.tif"))
  expect_identical(v$scene$data$r_1, list(format = "cog", url = "west.tif"))
  expect_identical(v$scene$data$r_2, list(format = "cog", url = "east.tif"))
  ## Each member's tiles come from its own file, embedded; no temporary COG.
  blobs <- tile_blobs(v)
  expect_true(any(startsWith(blobs, "r_1@")) && any(startsWith(blobs, "r_2@")))
  expect_false(any(grepl("view-.*[.]tif", unlist(v$scene$data))))
  ## One palette and one range across the members, and one legend.
  l <- v$scene$layers
  expect_identical(l[[1]]$palette$name, "viridis")
  expect_identical(l[[1]]$palette, l[[2]]$palette)
  expect_identical(v$scene$version, "0.5")
  expect_length(v$scene$legends, 1L)
  expect_identical(v$scene$legends[[1]]$layer, "r_1")
  ## Titled with the mosaic's name, not headed by the first member's label.
  expect_identical(v$scene$legends[[1]]$title, "r")
  expect_equal(v$scene$view$extent, c(-6400000, 6400000, -6400000, 6400000))
  expect_valid_scene(v)
  ## A range given applies to every member; legend = FALSE leaves the legend out.
  v2 <- no_temp_cog(view(r, palette = "ocean", range = c(-2, 10), legend = FALSE, file = html()))
  expect_identical(lapply(v2$scene$layers, function(l) l$palette),
                   rep(list(list(name = "ocean", range = c(-2, 10))), 2L))
  expect_null(v2$scene$legends)
  ## The string route gives the same layers.
  vs <- no_temp_cog(view(h$vrt, name = "r", file = html()))
  expect_identical(vs$scene$layers, v$scene$layers)
  expect_identical(vs$scene$data, v$scene$data)
  expect_identical(vs$scene$legends, v$scene$legends)
  expect_identical(view_crs(h$vrt), "EPSG:3031")
})

test_that("only the members a view touches are planned; one member keeps the layer's name", {
  skip_if_no_terra()
  h <- cog_halves()
  r <- terra::rast(h$vrt)
  probed <- character()
  real <- aobcore::cog_info
  local_mocked_bindings(cog_info = function(dsn, band = 1L) {
    probed <<- c(probed, dsn)
    real(dsn, band = band)
  }, .package = "aobcore")
  v <- no_temp_cog(view(r, extent = c(1e6, 5e6, -3e6, 3e6), units_per_pixel = 70000,
                        file = html()))
  expect_identical(view_ids(v), "r")
  expect_identical(view_labels(v), "r")
  expect_identical(v$scene$data$r$url, "east.tif")
  expect_identical(v$scene$layers[[1]]$plan$coverage, "view")
  ## The member paths are those cog_info() is given (cog_halves() names
  ## them as normalizePath() does), so this is not vacuous on Windows.
  expect_true(h$b %in% probed)
  expect_false(h$a %in% probed)
  ## The same by name.
  vs <- no_temp_cog(view(h$vrt, extent = c(1e6, 5e6, -3e6, 3e6), units_per_pixel = 70000,
                         name = "r", file = html()))
  expect_identical(vs$scene$layers, v$scene$layers)
  ## No member meets the extent: the dataset is read as before, with a message.
  expect_message(temp_cog_values(view(r, extent = c(7e6, 8e6, 7e6, 8e6), file = html())),
                 "none of whose members meets `extent`")
})

test_that("a VRT with a member that is not a COG falls back to the temporary COG, naming it", {
  skip_if_no_terra()
  h <- cog_halves()
  striped <- file.path(h$dir, "striped.tif")
  gdalraster::translate(extdata("polar_3031.tif"), striped, c("-of", "GTiff"), quiet = TRUE)
  vrt <- file.path(h$dir, "mixed.vrt")
  gdalraster::buildVRT(vrt, c(h$a, striped), quiet = TRUE)
  ## As a SpatRaster: terra writes it, as before.
  r <- terra::rast(vrt)
  expect_message(vals <- temp_cog_values(view(r, file = html())), "member \"striped.tif\"")
  expect_equal(nrow(vals), 400 * 400)
  ## A COG stretched over a grid that is not its own is not drawn in place.
  stretch <- file.path(h$dir, "stretch.vrt")
  x <- readLines(h$vrt)
  x <- sub('rasterXSize="400" rasterYSize="400"', 'rasterXSize="2000" rasterYSize="2000"', x)
  x <- sub('<DstRect xOff="200"', '<DstRect xOff="1000"', x)
  x <- sub('(<DstRect [^/]*)xSize="200" ySize="400"', '\\1xSize="1000" ySize="2000"', x)
  writeLines(x, stretch)
  expect_message(temp_cog_values(view(terra::rast(stretch), file = html())),
                 "is not placed in the mosaic by its own georeferencing")
  ## By name: GDAL reads the whole mosaic into a temporary COG.
  seen <- gdal_temp_seen(expect_message(
    v <- view(vrt, name = "mixed", file = html()),
    "\"mixed\" is a VRT whose member \"striped.tif\" is not a tiled GeoTIFF with overviews"
  ))
  expect_identical(view_ids(v), "mixed")
  expect_match(v$scene$data$mixed$url, "^view-.*[.]tif$")
  expect_equal(seen$dim, c(400, 400))
  ## A huge VRT over a small striped file is read through GDAL as before
  ## (its member is placed by its own georeferencing, but is no COG).
  big <- terra::rast(huge_vrt(small_merc_tif()))
  seen <- gdal_temp_seen(expect_message(view(big, max_tiles = 64, file = html()),
                                        "is not a tiled GeoTIFF with overviews"))
  expect_equal(seen$gs$factor, 2^13)
})

test_that("a VRT of a colour COG draws a colour image from the member", {
  skip_if_no_terra()
  dir <- tempfile("rgba-")
  dir.create(dir)
  vrt <- file.path(dir, "rgba.vrt")
  gdalraster::buildVRT(vrt, extdata("polar_rgba.tif"), quiet = TRUE)
  v <- no_temp_cog(view(terra::rast(vrt), name = "img", file = html()))
  expect_identical(view_ids(v), "img")
  expect_identical(v$scene$layers[[1]]$rgb, list(bands = 1:3, alpha = 4L))
  expect_identical(v$scene$data$img$url, "polar_rgba.tif")
  expect_null(v$scene$legends)
  ## By name too, and band 2 through a palette.
  vs <- no_temp_cog(view(vrt, name = "img", file = html()))
  expect_identical(vs$scene$layers, v$scene$layers)
  v2 <- no_temp_cog(view(vrt, layer = 2, name = "g", file = html()))
  expect_identical(v2$scene$layers[[1]]$plan$levels[[1]]$encoding$band, 2L)
  expect_identical(v2$scene$layers[[1]]$palette$name, "viridis")
  ## A VRT that reorders the bands cannot draw a colour image in place.
  swapped <- file.path(dir, "bgr.vrt")
  gdalraster::buildVRT(swapped, extdata("polar_rgba.tif"), cl_arg = c("-b", "3", "-b", "2", "-b", "1"),
                       quiet = TRUE)
  seen <- gdal_temp_seen(expect_message(view(swapped, rgb = TRUE, name = "bgr", file = html()),
                                        "feeds band 1 from its band 3"))
  expect_equal(seen$cog$samples_per_pixel, 3L)
})

test_that("a colour VRT whose bands come from different files is not drawn from one of them", {
  skip_if_no_terra()
  dir <- normalizePath(tempfile("rgb-"), winslash = "/", mustWork = FALSE)
  dir.create(dir)
  f <- extdata("polar_rgba.tif")
  files <- file.path(dir, c("r.tif", "g.tif", "b.tif"))
  file.copy(f, files)
  ds <- gdalraster::GDALRaster$new(f)
  gt <- ds$getGeoTransform()
  nx <- ds$getRasterXSize()
  ny <- ds$getRasterYSize()
  ds$close()
  ## Band b of the mosaic from band `src[b]` of file `file[b]`.
  rgb_vrt <- function(out, file, src = c(1, 1, 1)) {
    band <- function(b) {
      paste0('<VRTRasterBand dataType="Byte" band="', b, '"><ColorInterp>',
             c("Red", "Green", "Blue")[b], "</ColorInterp>",
             '<SimpleSource><SourceFilename relativeToVRT="0">', file[b], "</SourceFilename>",
             "<SourceBand>", src[b], "</SourceBand>",
             sprintf('<SrcRect xOff="0" yOff="0" xSize="%d" ySize="%d"/>', nx, ny),
             sprintf('<DstRect xOff="0" yOff="0" xSize="%d" ySize="%d"/>', nx, ny),
             "</SimpleSource></VRTRasterBand>")
    }
    writeLines(c(sprintf('<VRTDataset rasterXSize="%d" rasterYSize="%d">', nx, ny),
                 "<SRS>EPSG:3031</SRS>",
                 paste0("<GeoTransform>", paste(format(gt, digits = 17), collapse = ", "),
                        "</GeoTransform>"),
                 vapply(1:3, band, ""), "</VRTDataset>"), out)
    out
  }
  ## Red, green and blue from band 1 of three files: read through GDAL,
  ## never drawn as bands 1 to 3 of the first file.
  sep <- rgb_vrt(file.path(dir, "sep.vrt"), files)
  seen <- gdal_temp_seen(expect_message(
    v <- view(sep, name = "img", file = html()),
    "\"img\" is a VRT whose bands are not drawn from the same members \\(\"g.tif\" feeds band 2"
  ))
  expect_identical(v$scene$layers[[1]]$rgb, list(bands = 1:3))
  expect_match(v$scene$data$img$url, "^view-.*[.]tif$")
  expect_false(any(vapply(v$scene$data, function(d) identical(d$url, "r.tif"), TRUE)))
  ## The same file for every band, each from its own band: drawn in place.
  same <- rgb_vrt(file.path(dir, "same.vrt"), rep(files[1], 3), src = 1:3)
  vs <- no_temp_cog(view(same, name = "img", file = html()))
  expect_identical(vs$scene$data$img$url, "r.tif")
  expect_identical(vs$scene$layers[[1]]$rgb, list(bands = 1:3))
  ## The checks alone, on member tables.
  mos <- function(dsn, band, source_band) {
    list(members = data.frame(dsn = dsn, band = band, source_band = source_band,
                              stringsAsFactors = FALSE))
  }
  expect_null(mosaic_rgb_bands(mos(rep(c("a", "b"), 3), rep(1:3, each = 2), rep(1:3, each = 2)),
                               1:3))
  expect_match(mosaic_rgb_bands(mos(c("a", "b", "a", "a"), c(1, 1, 2, 3), c(1, 1, 2, 3)), 1:3),
               "\"b\" feeds band 1 but not band 2")
  ## A GTI's members (no band) feed every band from their own.
  expect_null(mosaic_rgb_bands(mos(c("a", "b"), NA_integer_, NA_integer_), 1:3))
})

test_that("a GTI over the halves is planned like the VRT", {
  skip_if_no_terra()
  h <- cog_halves()
  idx <- gti_index(h)
  skip_if(is.null(idx), "GDAL cannot write a GTI index here (gdal raster index)")
  v <- no_temp_cog(view(idx, name = "g", file = html()))
  expect_identical(layer_kinds(v), c("tiled_raster", "tiled_raster"))
  expect_setequal(vapply(v$scene$data[c("g_1", "g_2")], `[[`, "", "url"), c("west.tif", "east.tif"))
  expect_length(v$scene$legends, 1L)
  vr <- no_temp_cog(view(terra::rast(idx), name = "g", file = html()))
  expect_identical(vr$scene$layers, v$scene$layers)
  expect_identical(vr$scene$data, v$scene$data)
})

test_that("a VRT over a remote COG references the member by URL, nothing copied", {
  skip_if_no_gdalraster()
  skip_on_cran()
  url <- paste0("https://raw.githubusercontent.com/allboa/aobcore/",
                "5ecd9b0c5a877491d1da534a0454f52650d346d1/inst/extdata/polar_3031.tif")
  reach <- tryCatch(aobcore::cog_info(url), error = function(e) NULL)
  skip_if(is.null(reach), "the COG URL is not reachable")
  vrt <- tempfile(fileext = ".vrt")
  gdalraster::buildVRT(vrt, paste0("/vsicurl/", url), quiet = TRUE)
  v <- no_temp_cog(view(vrt, name = "remote", file = html()))
  expect_identical(v$scene$data$remote, list(format = "cog", url = url))
  expect_length(tile_blobs(v), 0L)
  expect_equal(v$local_bytes, 0)
})
