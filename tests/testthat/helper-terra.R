# Shared by the terra and several-layer tests.
# terra, and gdalraster whose GDAL can resolve EPSG codes (aobcore plans
# tiles with it). Some binary builds of gdalraster (CRAN's macOS one, for
# now) cannot find their PROJ database; skip there, as aobcore's tests do,
# since that is an installation problem.
skip_if_no_terra <- function() {
  skip_if_not_installed("terra")
  skip_if_not_installed("gdalraster")
  ok <- !inherits(try(gdalraster::srs_to_wkt("EPSG:3031"), silent = TRUE), "try-error")
  skip_if_not(ok, "gdalraster cannot resolve EPSG:3031 (PROJ database not found)")
}

# Run view() and return the cell values of the temporary COG it wrote (the
# file itself is deleted once the page is written).
temp_cog_values <- function(expr) {
  seen <- new.env()
  real <- raster_temp_cog
  local_mocked_bindings(raster_temp_cog = function(x, rgb) {
    cog <- real(x, rgb)
    seen$dsn <- cog$dsn
    seen$values <- terra::values(terra::rast(cog$dsn))
    cog
  }, .env = parent.frame())
  force(expr)
  expect_false(file.exists(seen$dsn))
  seen$values
}

extdata <- function(f) system.file("extdata", f, package = "aobcore")
html <- function() tempfile(fileext = ".html")
page_text <- function(v) paste(readLines(v$file, warn = FALSE), collapse = "\n")
tile_blobs <- function(v) grep("@", names(aobcore::scene_blobs(v$scene)), value = TRUE, fixed = TRUE)
