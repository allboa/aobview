## ---- a SpatRaster read through GDAL (allboa/aobview#21) ---------------------
##
## A SpatRaster read unchanged from one GDAL dataset that is not a usable COG
## (a tile service such as WMS or TMS, a VRT, any huge virtual grid) can have
## a full-resolution grid far larger than a view can draw: a planetary WMS is
## millions of cells on a side. terra would write all of it to a temporary
## COG (and, for a colour image, scan every cell for missing values). A tile
## plan never draws more than `max_tiles` tiles, so when the dataset's own
## pyramid would hold more, GDAL is handed the dataset instead: it reads only
## the planned extent, at the finest power-of-two reduction whose COG fits
## the plan, into a temporary COG (gdalraster::translate(); GDAL picks the
## dataset's overviews or zoom levels itself). The decision is made from the
## dataset's size, before any cell is read. A smaller dataset goes to
## raster_temp_cog() as before.

## The block size of a temporary COG (GDAL's COG default, which terra uses
## too).
temp_cog_block <- 512L

## When x is read unchanged from one GDAL dataset whose full grid makes more
## tiles than the plan can take, how to read it: list(dsn, bands, cog, window,
## size, factor), where `cog` holds the dataset's facts in the shape of
## aobcore::cog_info() that the colour and grid checks read, `window` is the
## source window (xoff, yoff, xsize, ysize) and `size` the size it is read
## at. Else NULL. `crs` is the view CRS; `plan_args` are the arguments for
## aobcore::cog_plan() (`extent`, `units_per_pixel` and `max_tiles` are
## used).
raster_gdal_source <- function(x, crs, plan_args) {
  if (any(terra::inMemory(x))) return(NULL)
  src <- terra::sources(x, bands = TRUE)
  if (!nrow(src) || length(unique(src$sid)) != 1L || !nzchar(src$source[1])) return(NULL)
  dsn <- sub("^file://", "", src$source[1])
  bands <- as.integer(src$bands)
  info <- tryCatch(gdal_facts(dsn, bands), error = function(e) NULL)
  if (is.null(info) || !same_grid(x, info) || !same_nodata(x, info)) return(NULL)
  max_tiles <- plan_arg(plan_args, "max_tiles")
  if (!is.numeric(max_tiles) || length(max_tiles) != 1L || is.na(max_tiles) ||
      !(max_tiles >= 1)) {
    return(NULL)  # aobcore::cog_plan() says what is wrong with it
  }
  dim <- info$levels[[1]]$dim
  if (cog_tiles(dim[1], dim[2]) <= max_tiles) return(NULL)
  window <- gdal_window(info, crs, plan_args$extent)
  factor <- read_factor(info, window, crs, plan_args, max_tiles)
  size <- pmax(1, ceiling(window[3:4] / factor))
  list(dsn = dsn, bands = bands, cog = info, window = window, size = size, factor = factor,
       max_tiles = max_tiles, extent_given = !is.null(plan_args$extent))
}

## A cog_plan() argument as given, or its default.
plan_arg <- function(args, name) {
  if (!is.null(args[[name]])) return(args[[name]])
  eval(formals(aobcore::cog_plan)[[name]])
}

## The facts of GDAL dataset `dsn` (bands `bands`) that same_grid(),
## same_nodata(), raster_is_rgb() and rgb_order() read from a cog_info(), in
## its shape. Errors when the dataset cannot be opened or its grid is
## rotated.
gdal_facts <- function(dsn, bands) {
  ds <- gdalraster::GDALRaster$new(dsn, TRUE)
  on.exit(ds$close())
  gt <- ds$getGeoTransform()
  if (gt[3] != 0 || gt[5] != 0) stop("A rotated grid.")
  nx <- ds$getRasterXSize()
  ny <- ds$getRasterYSize()
  b <- bands[1]
  scale <- ds$getScale(b)
  offset <- ds$getOffset(b)
  nb <- ds$getRasterCount()
  dtype <- ds$getDataTypeName(b)
  mask <- ds$getMaskFlags(b)
  nodata <- ds$getNoDataValue(b)
  list(
    dsn = dsn,
    band = b,
    wkt = ds$getProjection(),
    levels = list(list(
      dim = c(nx, ny),
      extent = c(gt[1], gt[1] + nx * gt[2], gt[4] + ny * gt[6], gt[4]),
      encoding = list(dtype = if (identical(dtype, "Byte")) "uint8" else dtype)
    )),
    scale = if (is.na(scale)) 1 else scale,
    offset = if (is.na(offset)) 0 else offset,
    nodata = if (!is.na(nodata)) nodata,
    color_interp = vapply(seq_len(nb), function(i) ds$getRasterColorInterp(i), ""),
    all_valid = isTRUE(mask$ALL_VALID),
    gt = gt
  )
}

## The tiles of a temporary COG of nx by ny cells, with the overviews GDAL's
## COG driver adds (halving until one tile holds the image): what a plan of
## every level would draw.
cog_tiles <- function(nx, ny, block = temp_cog_block) {
  n <- 0
  repeat {
    n <- n + ceiling(nx / block) * ceiling(ny / block)
    if (nx <= block && ny <= block) return(n)
    nx <- ceiling(nx / 2)
    ny <- ceiling(ny / 2)
  }
}

## The source window to read, c(xoff, yoff, xsize, ysize) in cells: the whole
## grid, or the part that `extent` (view CRS) covers. A window that cannot
## be found (the extent does not transform, or misses the grid) is the
## whole grid, and the plan then says what it can draw.
gdal_window <- function(info, crs, extent) {
  dim <- info$levels[[1]]$dim
  whole <- c(0, 0, dim)
  if (is.null(extent)) return(whole)
  bb <- extent_in_source(info, crs, extent)
  if (is.null(bb)) return(whole)
  gt <- info$gt
  ## Cell edges within a millionth of a cell of the extent are taken as on it.
  x0 <- max(0, floor((bb[1] - gt[1]) / gt[2] + 1e-6))
  x1 <- min(dim[1], ceiling((bb[2] - gt[1]) / gt[2] - 1e-6))
  y0 <- max(0, floor((bb[4] - gt[4]) / gt[6] + 1e-6))
  y1 <- min(dim[2], ceiling((bb[3] - gt[4]) / gt[6] - 1e-6))
  if (!(x1 > x0 && y1 > y0)) return(whole)
  c(x0, y0, x1 - x0, y1 - y0)
}

## `extent` (c(xmin, xmax, ymin, ymax) in the view CRS) as the same in the
## source CRS, or NULL.
extent_in_source <- function(info, crs, extent) {
  if (!is.numeric(extent) || length(extent) != 4L || any(!is.finite(extent))) return(NULL)
  view_wkt <- tryCatch(gdalraster::srs_to_wkt(as.character(crs)), error = function(e) "")
  if (!nzchar(view_wkt)) return(NULL)
  if (isTRUE(gdalraster::srs_is_same(view_wkt, info$wkt))) return(as.numeric(extent))
  bb <- tryCatch(gdalraster::transform_bounds(extent[c(1, 3, 2, 4)], view_wkt, info$wkt),
                 error = function(e) NULL)
  if (length(bb) != 4L || any(!is.finite(bb)) || bb[3] <= bb[1] || bb[4] <= bb[2]) {
    return(NULL)
  }
  bb[c(1, 3, 2, 4)]
}

## The reduction (a power of two: 1, 2, 4, ...) the window is read at: the
## least whose COG fits `max_tiles`, and, for a plan of one view
## (`units_per_pixel`), as coarse as that view's pixel allows.
read_factor <- function(info, window, crs, plan_args, max_tiles) {
  f <- 1
  while (cog_tiles(ceiling(window[3] / f), ceiling(window[4] / f)) > max_tiles) f <- f * 2
  upp <- plan_args$units_per_pixel
  extent <- plan_args$extent
  if (is.numeric(upp) && length(upp) == 1L && is.finite(upp) && upp > 0 && !is.null(extent)) {
    bb <- extent_in_source(info, crs, extent)
    if (!is.null(bb)) {
      ## View units per source unit, across the extent.
      k <- (extent[2] - extent[1]) / (bb[2] - bb[1])
      res <- max(abs(info$gt[c(2, 6)]))
      while (f * 2 * res * k <= upp) f <- f * 2
    }
  }
  f
}

## Read gs (from raster_gdal_source()) bands `bands` through GDAL into a
## temporary COG and return its structure. A colour image's three bands get
## the dataset's mask as an alpha band when it has missing cells (a mask
## that is not "all valid": no-data, a mask band or an alpha band), so no
## cell is scanned.
gdal_temp_cog <- function(gs, bands, rgb, name) {
  f <- tempfile("view-", tmpdir = temp_cog_dir(), fileext = ".tif")
  full <- gs$cog$levels[[1]]$dim
  n <- function(x) paste(format(x, scientific = FALSE, trim = TRUE), collapse = " x ")
  part <- any(gs$window[3:4] < full)
  hint <- if (part) {
    "A smaller `extent` (or a larger `max_tiles`) shows more detail."
  } else if (isTRUE(gs$extent_given)) {
    ## The extent covers the whole grid, or missed it and the whole grid was read.
    "A larger `max_tiles` shows more detail."
  } else {
    "Passing `extent` (or a larger `max_tiles`) shows more detail."
  }
  message("\"", name, "\" is read through GDAL from a dataset of ", n(full), " cells, ",
          if (gs$factor > 1) paste0("at 1/", n(gs$factor), " resolution ") else "",
          if (part) paste0("over ", n(gs$window[3:4]), " cells ") else "",
          "(", n(gs$size), "): its full grid is more than `max_tiles` ",
          "(", gs$max_tiles, ") can draw. ", hint)
  args <- c("-of", "COG", "-co", paste0("BLOCKSIZE=", temp_cog_block),
            "-srcwin", format(gs$window, scientific = FALSE, trim = TRUE),
            "-outsize", format(gs$size, scientific = FALSE, trim = TRUE),
            as.vector(rbind("-b", bands)))
  if (rgb) {
    byte <- identical(gs$cog$levels[[1]]$encoding$dtype, "uint8")
    if (byte && length(bands) == 3L && !gs$cog$all_valid) {
      ## Transparency comes from the alpha band alone, as raster_temp_cog()
      ## writes it.
      args <- c(args, "-b", paste0("mask,", bands[1]), "-a_nodata", "none")
    }
    if (gdal_at_least("3.11")) args <- c(args, "-co", "INTERLEAVE=PIXEL")
  }
  ok <- tryCatch(gdalraster::translate(gs$dsn, f, args, quiet = TRUE), error = function(e) {
    unlink(f)
    stop("GDAL could not read \"", name, "\" from its dataset: ", conditionMessage(e),
         call. = FALSE)
  })
  if (!isTRUE(ok) || !file.exists(f)) {
    unlink(f)
    stop("GDAL could not read \"", name, "\" from its dataset.", call. = FALSE)
  }
  tryCatch(aobcore::cog_info(f), error = function(e) {
    unlink(f)
    stop(e)
  })
}

## Is gdalraster's GDAL at least version `v`?
gdal_at_least <- function(v) {
  utils::compareVersion(gdalraster::gdal_version()[4L], v) >= 0
}
