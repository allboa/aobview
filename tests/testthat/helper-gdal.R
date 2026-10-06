# Datasets for view() of a SpatRaster read through GDAL (view-gdal.R): small
# local files behind a huge virtual grid, the shape of a planetary tile
# service, so nothing here needs the internet.

merc <- 20037508.342789244

# A small Byte GeoTIFF in EPSG:3857 over the whole Mercator square: `nb`
# bands of 256 x 256 cells (band 1 a diagonal ramp, the others shifted), with
# a no-data value when `nodata` is given (the top-left 64 x 64 cells take it).
small_merc_tif <- function(nb = 1L, nodata = NULL) {
  f <- tempfile(fileext = ".tif")
  gdalraster::create("GTiff", f, 256, 256, nb, "Byte", return_obj = FALSE)
  ds <- gdalraster::GDALRaster$new(f, FALSE)
  ds$setGeoTransform(c(-merc, 2 * merc / 256, 0, merc, 0, -2 * merc / 256))
  ds$setProjection(gdalraster::srs_to_wkt("EPSG:3857"))
  i <- rep(0:255, 256)
  j <- rep(0:255, each = 256)
  for (b in seq_len(nb)) {
    v <- (i + j + 60L * (b - 1L)) %% 250L + 1L
    if (!is.null(nodata)) {
      v[i < 64 & j < 64] <- nodata
      ds$setNoDataValue(b, nodata)
    }
    ds$write(b, 0, 0, 256, 256, as.integer(v))
  }
  ds$close()
  f
}

# A VRT of n x n cells (2^24 by default: Web Mercator zoom 16) over the same
# square, drawing every band of `src` stretched over it, with the colour
# interpretation `interp` and no-data value `nodata` per band when given.
huge_vrt <- function(src, nb = 1L, n = 2^24, interp = NULL, nodata = NULL) {
  f <- tempfile(fileext = ".vrt")
  band <- function(b) {
    paste0(
      '<VRTRasterBand dataType="Byte" band="', b, '">',
      if (!is.null(interp)) paste0("<ColorInterp>", interp[b], "</ColorInterp>"),
      if (!is.null(nodata)) paste0("<NoDataValue>", nodata, "</NoDataValue>"),
      '<SimpleSource><SourceFilename relativeToVRT="0">', src, "</SourceFilename>",
      "<SourceBand>", b, "</SourceBand>",
      '<SrcRect xOff="0" yOff="0" xSize="256" ySize="256"/>',
      '<DstRect xOff="0" yOff="0" xSize="', n, '" ySize="', n, '"/>',
      "</SimpleSource></VRTRasterBand>")
  }
  writeLines(c(
    paste0('<VRTDataset rasterXSize="', n, '" rasterYSize="', n, '">'),
    "<SRS>EPSG:3857</SRS>",
    sprintf("<GeoTransform>%.10f, %.17g, 0, %.10f, 0, %.17g</GeoTransform>",
            -merc, 2 * merc / n, merc, -2 * merc / n),
    vapply(seq_len(nb), band, ""),
    "</VRTDataset>"), f)
  f
}

# XYZ tiles (z/x/y.png, 256 x 256 RGB) for zooms 0 to `zmax` in a new
# directory, with tile `missing` (z, x, y) left out so the server answers
# 404 for it. Red ramps west to east, green north to south; blue is 50 + 100
# times the zoom.
xyz_tiles <- function(zmax = 2L, missing = c(2L, 3L, 3L)) {
  dir <- tempfile("tiles-")
  i <- rep(0:255, 256)
  j <- rep(0:255, each = 256)
  for (z in 0:zmax) for (x in 0:(2^z - 1)) for (y in 0:(2^z - 1)) {
    if (identical(as.integer(c(z, x, y)), as.integer(missing))) next
    d <- file.path(dir, z, x)
    dir.create(d, recursive = TRUE, showWarnings = FALSE)
    m <- tempfile(fileext = ".tif")
    gdalraster::create("GTiff", m, 256, 256, 3, "Byte", return_obj = FALSE)
    ds <- gdalraster::GDALRaster$new(m, FALSE)
    w <- 2^z * 256 - 1
    ds$write(1, 0, 0, 256, 256, as.integer(round((x * 256 + i) * 255 / w)))
    ds$write(2, 0, 0, 256, 256, as.integer(round((y * 256 + j) * 255 / w)))
    ds$write(3, 0, 0, 256, 256, rep(as.integer(50 + 100 * z), 256 * 256))
    ds$close()
    gdalraster::translate(m, file.path(d, paste0(y, ".png")), c("-of", "PNG"), quiet = TRUE)
    unlink(m)
  }
  dir
}

# A GDAL WMS description (TMS minidriver) of XYZ tiles under `url`: the
# whole Web Mercator square to zoom 18 (2^26 cells on a side), 3 bands,
# with a 404 read as an empty (zero) tile, as tile services are described,
# and a 10 s timeout so a stalled server cannot hang the tests.
tms_xml <- function(url) {
  paste0(
    '<GDAL_WMS><Service name="TMS"><ServerUrl>', url, "/${z}/${x}/${y}.png</ServerUrl></Service>",
    "<DataWindow><UpperLeftX>", -merc, "</UpperLeftX><UpperLeftY>", merc, "</UpperLeftY>",
    "<LowerRightX>", merc, "</LowerRightX><LowerRightY>", -merc, "</LowerRightY>",
    "<TileLevel>18</TileLevel><TileCountX>1</TileCountX><TileCountY>1</TileCountY>",
    "<YOrigin>top</YOrigin></DataWindow>",
    "<Projection>EPSG:3857</Projection><BlockSizeX>256</BlockSizeX><BlockSizeY>256</BlockSizeY>",
    "<BandsCount>3</BandsCount><ZeroBlockHttpCodes>204,404</ZeroBlockHttpCodes>",
    "<Timeout>10</Timeout></GDAL_WMS>")
}

# Run view() and record what gdal_temp_cog() wrote: its path, structure,
# file size and cell values (the file itself is deleted once the page is
# written), and fail if terra's raster_temp_cog() is reached instead.
gdal_temp_seen <- function(expr) {
  seen <- new.env()
  real <- gdal_temp_cog
  local_mocked_bindings(
    gdal_temp_cog = function(gs, bands, rgb, name) {
      cog <- real(gs, bands, rgb, name)
      seen$gs <- gs
      seen$cog <- cog
      seen$bytes <- file.size(cog$dsn)
      seen$dim <- cog$levels[[1]]$dim
      seen$values <- terra::values(terra::rast(cog$dsn))
      cog
    },
    raster_temp_cog = function(x, rgb) stop("terra would write the whole grid"),
    .env = parent.frame()
  )
  seen$value <- force(expr)
  expect_false(file.exists(seen$cog$dsn))
  seen
}

# polar_3031.tif as two COG halves (west and east, 200 x 400 cells each,
# 128 x 128 tiles) in a new directory, with a VRT gdalraster builds over
# them (view-mosaic.R): list(dir, a, b, vrt).
cog_halves <- function() {
  dir <- tempfile("mosaic-")
  dir.create(dir)
  ## Members come back as normalizePath() gives them (on Windows, the long
  ## name with forward slashes), so the files are named that way too.
  dir <- normalizePath(dir, winslash = "/")
  f <- extdata("polar_3031.tif")
  a <- file.path(dir, "west.tif")
  b <- file.path(dir, "east.tif")
  opts <- c("-of", "COG", "-co", "BLOCKSIZE=128")
  gdalraster::translate(f, a, c(opts, "-srcwin", "0", "0", "200", "400"), quiet = TRUE)
  gdalraster::translate(f, b, c(opts, "-srcwin", "200", "0", "200", "400"), quiet = TRUE)
  vrt <- file.path(dir, "halves.vrt")
  gdalraster::buildVRT(vrt, c(a, b), quiet = TRUE)
  list(dir = dir, a = a, b = b, vrt = vrt)
}

# A GTI index of the two halves, written with GDAL's `raster index`
# (gdalraster::gdal_run(), GDAL >= 3.11), or NULL when that is not here.
gti_index <- function(h) {
  if (!"gdal_run" %in% getNamespaceExports("gdalraster")) return(NULL)
  if (!nrow(gdalraster::gdal_formats("GTI"))) return(NULL)
  idx <- file.path(h$dir, "halves.gti.gpkg")
  ok <- tryCatch({
    gdalraster::gdal_run("raster index", c("--input", h$a, "--input", h$b, "--output", idx),
                         close = TRUE, quiet = TRUE)
    file.exists(idx)
  }, error = function(e) FALSE)
  if (!isTRUE(ok)) return(NULL)
  idx
}
