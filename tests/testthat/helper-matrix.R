# Shared by the matrix and stars tests (view-matrix.R: the untiled raster
# layer and the temporary COG an in-memory grid is written to).

ext31 <- c(-3e6, 3e6, -2e6, 2e6)

# The values column of an untiled raster layer's blob, as written.
raster_values <- function(v, i = 1L) {
  l <- v$scene$layers[[i]]
  as.data.frame(nanoarrow::read_nanoarrow(aobcore::scene_blobs(v$scene)[[l$values]]))$value
}

# Run view() and return what grid_temp_cog() wrote: the COG's structure and
# its cell values by band (the file itself is deleted once the page is
# written).
# The matrix COG route needs gdalraster and a PROJ database, not terra
# (skip_if_no_gdalraster() in helper-terra.R).
grid_temp_seen <- function(expr) {
  seen <- new.env()
  real <- grid_temp_cog
  local_mocked_bindings(grid_temp_cog = function(g, rgb) {
    cog <- real(g, rgb)
    seen$cog <- cog
    ds <- gdalraster::GDALRaster$new(cog$dsn)
    d <- ds$dim()
    seen$values <- lapply(seq_len(d[3]), function(b) ds$read(b, 0L, 0L, d[1], d[2], d[1], d[2]))
    seen$nodata <- ds$getNoDataValue(1L)
    ds$close()
    cog
  }, .env = parent.frame())
  seen$value <- force(expr)
  expect_false(file.exists(seen$cog$dsn))
  seen
}
