#' View a matrix or array as a raster
#'
#' `view()` of a matrix draws it as a raster on a regular grid: `extent`
#' gives the outer edges of its cells, `c(xmin, xmax, ymin, ymax)`, and
#' `crs` the CRS those edges are in. That is what holders of a plain matrix
#' (from 'tidync', 'ncdf4', 'vaster', or any array computation) already
#' know, and no raster package is needed. A numeric or logical matrix is
#' drawn as one band through a palette; a three-dimensional array of 3 or 4
#' bands as a colour image. Palettes, range and legend work as for a
#' one-layer `SpatRaster` (see [view-terra]).
#'
#' **Orientation.** Row 1 of the matrix is the top of the grid (the row at
#' `ymax`) and column 1 its left edge (at `xmin`), as in 'terra' and
#' 'vaster': `x[1, 1]` is the top-left cell, as the matrix prints. A matrix
#' built from a column-major source (a NetCDF variable read with `ncdf4`,
#' where the first dimension is often longitude and the first row the
#' southernmost) needs transposing or flipping first, as it would for
#' `terra::rast()`.
#'
#' **Untiled or tiled.** A matrix of at most 512 by 512 cells (one tile of a
#' temporary COG, the threshold [view-terra] applies) whose `crs` is the
#' view CRS goes into the page as an untiled scene spec 0.1 `raster` layer:
#' the grid descriptor (its extent, dimensions and CRS) and the cell values
#' as one Arrow column, row by row from the top. Above that size, or when
#' the view CRS differs from `crs` (a lon/lat matrix south of 40S, say,
#' which [view_crs()] draws in EPSG:3031), the matrix is written to a
#' temporary COG with 'gdalraster' (one Float32 band, missing cells as the
#' no-data value) in `file.path(tempdir(), "aobview-cogs")` and takes the
#' tiled path of [view-terra]: [aobcore::cog_plan()] plans its tiles with a
#' mesh projected to the view CRS, and the tiles are embedded in the page
#' or served (see Transport in [view()]). A colour image always takes the
#' tiled path, since the untiled layer draws one band. `...` goes to
#' [aobcore::cog_plan()] on the tiled path (`max_tiles`, `max_stretch`,
#' `tolerance`, ...); on the untiled path there is no plan, so an argument
#' there is an error.
#'
#' **Colour.** An array with `dim(x)[3]` of 3 or 4 is drawn as red, green,
#' blue (and alpha): as Byte when every value is a whole number from 0 to
#' 255, with missing cells transparent (an alpha band is added when one is
#' missing), else as Float32 over `range` (the values drawn as zero and
#' full intensity; by default the range of the three colour bands). A
#' colour image has no legend. An array with one band is drawn as the
#' matrix `x[, , 1]`.
#'
#' **CRS.** `crs` is the CRS of `extent`, read as [aobcore::scene_crs()]
#' reads it: `"EPSG:3031"`, `3031`, WKT or a PROJ string. The view CRS
#' follows [view_crs()]'s rule from it: a projected `crs` is kept, and a
#' lon/lat one is drawn in EPSG:3031 or EPSG:3413 when the extent lies
#' south of 40S or north of 60N, else flat. A matrix has no CRS of its own,
#' so it cannot be an element of `view(list(...))`; add it to a view with
#' [view_add()], where `crs` is the grid's, as here, and the view's CRS
#' stays what it was.
#'
#' @inheritParams view
#' @param x A numeric or logical matrix (rows from the top, see
#'   Orientation), or a three-dimensional array of 1, 3 or 4 bands.
#' @param ... Passed to [aobcore::cog_plan()] when `x` takes the tiled
#'   path (see Untiled or tiled). An argument caught here when `x` is drawn
#'   untiled is an error.
#' @param extent The outer edges of the grid, `c(xmin, xmax, ymin, ymax)`,
#'   in `crs` units. Required.
#' @param crs The CRS of `extent` (the grid's CRS, not the view's): anything
#'   [aobcore::scene_crs()] reads. Required.
#' @param palette A palette name the renderer knows: `"viridis"` (the
#'   default), `"ocean"`, `"ice"` or `"gray"`. Not for a colour image.
#' @param range `c(low, high)`: the values at the ends of the palette; by
#'   default the range of the values. For a colour image of a type other
#'   than Byte, the values drawn as zero and full intensity.
#' @param legend `TRUE` (the default) keys the palette with a ramp and
#'   `FALSE` leaves it out (see Legend in [view-terra]). A colour image has
#'   no legend.
#' @return A view, as for [view()].
#' @seealso [view-terra] for the tiled path; [view_crs()] for the view CRS.
#' @name view-matrix
#' @examples
#' # A 20 x 30 field in EPSG:3031 around the pole: row 1 is the north edge.
#' m <- outer(seq(-1, 1, length.out = 20), seq(-1, 1, length.out = 30),
#'            function(y, x) cos(3 * x) * sin(2 * y))
#' v <- view(m, extent = c(-3e6, 3e6, -2e6, 2e6), crs = "EPSG:3031")
#' v$scene$layers[[1]]$kind
#' v$scene$layers[[1]]$grid$dim
#'
#' # A mask: a logical matrix draws as 0 and 1.
#' v2 <- view(m > 0, extent = c(-3e6, 3e6, -2e6, 2e6), crs = 3031, palette = "gray")
#' v2$scene$layers[[1]]$palette$range
#' @examplesIf requireNamespace("gdalraster", quietly = TRUE) && !inherits(try(gdalraster::srs_to_wkt("EPSG:3031"), silent = TRUE), "try-error")
#' # A colour image: three bands, 0 to 255, through a temporary COG.
#' img <- array(0, c(20, 30, 3))
#' img[, , 1] <- 255 * (m + 1) / 2
#' img[, , 2] <- 255 * (1 - (m + 1) / 2)
#' img[, , 3] <- 120
#' v3 <- view(img, extent = c(-3e6, 3e6, -2e6, 2e6), crs = "EPSG:3031")
#' v3$scene$layers[[1]]$kind
#' v3$scene$layers[[1]]$rgb
NULL

#' @rdname view-matrix
#' @export
view.matrix <- function(x, ..., extent, crs, palette = NULL, range = NULL, legend = TRUE,
                        name = NULL, file = NULL, theme = c("auto", "light", "dark"),
                        transport = getOption("aobview.transport", "auto")) {
  name <- name %||% deparse_name(substitute(x))
  theme <- match.arg(theme)
  transport <- check_transport(transport)
  g <- grid_input(x, extent, crs, "a matrix")
  v <- new_view(combined_view_crs(list(grid_crs_facts(g))), transport)
  on.exit(drop_pending(v), add = TRUE)
  v <- add_grid(g, v, name, ..., palette = palette, range = range, legend = legend)
  finish_view(v, name, file, theme)
}

#' @rdname view-matrix
#' @export
view.array <- function(x, ..., extent, crs, palette = NULL, range = NULL, legend = TRUE,
                       name = NULL, file = NULL, theme = c("auto", "light", "dark"),
                       transport = getOption("aobview.transport", "auto")) {
  name <- name %||% deparse_name(substitute(x))
  theme <- match.arg(theme)
  transport <- check_transport(transport)
  g <- grid_input(x, extent, crs, "an array")
  v <- new_view(combined_view_crs(list(grid_crs_facts(g))), transport)
  on.exit(drop_pending(v), add = TRUE)
  v <- add_grid(g, v, name, ..., palette = palette, range = range, legend = legend)
  finish_view(v, name, file, theme)
}

#' @export
add_layers.matrix <- function(x, v, name, ..., extent, crs, palette = NULL, range = NULL,
                              legend = TRUE) {
  add_grid(grid_input(x, extent, crs, "a matrix"), v, name, ..., palette = palette,
           range = range, legend = legend)
}

#' @export
add_layers.array <- function(x, v, name, ..., extent, crs, palette = NULL, range = NULL,
                             legend = TRUE) {
  add_grid(grid_input(x, extent, crs, "an array"), v, name, ..., palette = palette,
           range = range, legend = legend)
}

#' @rdname view_crs
#' @param extent,crs For a matrix or array, which has no CRS of its own:
#'   the grid's extent and CRS, as for [view-matrix].
#' @export
view_crs.matrix <- function(x, ..., extent, crs) {
  combined_view_crs(list(grid_crs_facts(grid_input(x, extent, crs, "a matrix"))))
}

#' @rdname view_crs
#' @export
view_crs.array <- function(x, ..., extent, crs) {
  combined_view_crs(list(grid_crs_facts(grid_input(x, extent, crs, "an array"))))
}

## ---- internals -------------------------------------------------------------

## The largest grid (cells on a side) drawn untiled: one tile of a
## temporary COG (temp_cog_block, view-gdal.R), the size below which
## view-terra.R takes a file as it is.
untiled_max <- function() temp_cog_block

## A matrix or array checked as a grid: list(x, extent, crs, colour), where
## x is a numeric nrow x ncol x nbands array (a logical matrix as 0 and 1),
## extent c(xmin, xmax, ymin, ymax), crs the scene CRS of that extent (see
## aobcore::scene_crs()) and colour whether x is a colour image (3 or 4
## bands). `what` names the input in errors.
grid_input <- function(x, extent, crs, what) {
  if (missing(extent) || is.null(extent)) {
    stop("view() of ", what, " needs `extent = c(xmin, xmax, ymin, ymax)`, the outer edges ",
         "of its cells, and `crs`, the CRS those edges are in.", call. = FALSE)
  }
  if (missing(crs) || is.null(crs)) {
    stop("view() of ", what, " needs `crs`, the CRS of its `extent` (such as \"EPSG:3031\").",
         call. = FALSE)
  }
  if (!is.numeric(extent) || length(extent) != 4L || anyNA(extent) || any(!is.finite(extent)) ||
      !(extent[1] < extent[2] && extent[3] < extent[4])) {
    stop("`extent` must be c(xmin, xmax, ymin, ymax) with xmin < xmax and ymin < ymax.",
         call. = FALSE)
  }
  if (!(is.numeric(x) || is.logical(x))) {
    stop("`x` must be a numeric or logical ", sub("^an? ", "", what), "; it is ",
         paste(class(x), collapse = "/"), ".", call. = FALSE)
  }
  d <- dim(x)
  if (length(d) == 2L) d <- c(d, 1L)
  if (length(d) != 3L) {
    stop("`x` must have 2 dimensions (a matrix) or 3 (an array of bands); it has ",
         length(d), ".", call. = FALSE)
  }
  if (!d[3] %in% c(1L, 3L, 4L)) {
    stop("An array for view() has 1 band (a matrix), or 3 or 4 bands for red, green, blue ",
         "and alpha; `x` has ", d[3], ".", call. = FALSE)
  }
  if (any(d[1:2] < 1L)) stop("`x` has no cells.", call. = FALSE)
  x <- array(as.numeric(x), d)
  if (!any(is.finite(x))) stop("`x` has no values to view: every cell is missing.", call. = FALSE)
  list(x = x, extent = as.numeric(extent), crs = aobcore::scene_crs(crs), colour = d[3] >= 3L)
}

## crs_facts() of a grid (see view-crs.R): its CRS, whether that is
## lon/lat, and the latitudes its extent spans.
grid_crs_facts <- function(g) {
  lonlat <- crs_is_lonlat(as.character(g$crs))
  list(crs = g$crs, lonlat = lonlat, ylim = if (lonlat) g$extent[3:4])
}

## Add grid g (from grid_input()) to view v as one layer: untiled when it
## is one band, no larger than untiled_max() on a side and in the view CRS
## (no mesh is needed, and the renderer draws an untiled grid in the view
## CRS as it is); else through a temporary COG, as a SpatRaster is.
add_grid <- function(g, v, name, ..., palette = NULL, range = NULL, legend = TRUE) {
  check_flag(legend, "legend")
  if (!is.null(palette) &&
      (!is.character(palette) || length(palette) != 1L || is.na(palette) || !nzchar(palette))) {
    stop("`palette` must be a single palette name.", call. = FALSE)
  }
  if (!is.null(range) && (!is.numeric(range) || length(range) != 2L || anyNA(range) ||
                          range[1] == range[2])) {
    stop("`range` must be c(low, high) with low and high different.", call. = FALSE)
  }
  if (g$colour && !is.null(palette)) {
    stop("`palette` colours one band; `x` is a colour image of ", dim(g$x)[3], " bands. ",
         "Give one band, x[, , i], to draw it through a palette.", call. = FALSE)
  }
  view <- v$scene$view$crs
  untiled <- !g$colour && all(dim(g$x)[1:2] <= untiled_max()) &&
    same_crs(as.character(g$crs), as.character(view))
  if (untiled) {
    if (...length() > 0L) {
      exprs <- as.list(substitute(list(...)))[-1L]
      nms <- names(exprs) %||% rep("", length(exprs))
      shown <- ifelse(nzchar(nms), paste0("`", nms, "`"),
                      paste0("an unnamed argument (", vapply(exprs, deparse_name, ""), ")"))
      stop("\"", name, "\" is drawn untiled (at most ", untiled_max(), " x ", untiled_max(),
           " cells, in the view CRS), with no tile plan, so ", paste(shown, collapse = ", "),
           if (length(shown) > 1L) " are" else " is", " not used: those arguments go to ",
           "aobcore::cog_plan() for a grid drawn as a tiled raster. Is an argument misspelled?",
           call. = FALSE)
    }
    return(add_untiled_raster(g, v, name, palette = palette, range = range, legend = legend))
  }
  need_gdalraster()
  ## The palette range from the values held here, not from the COG's
  ## coarsest overview as a file's is.
  cog <- grid_temp_cog(g, rgb = g$colour)
  if (!g$colour || cog$levels[[1]]$encoding$dtype != "uint8") {
    range <- range %||% value_range(if (g$colour) g$x[, , 1:3] else g$x)
  }
  add_tiled_layer(v, cog, name, ..., bands = if (g$colour) seq_len(cog$samples_per_pixel),
                  palette = palette, range = range, legend = legend, temp = TRUE)
}

## Add one-band grid g to v as an untiled scene spec 0.1 raster layer: the
## grid descriptor in the layer, the cell values as an Arrow table of one
## column, row-major from the top row (row 0 at ymax, as the spec says and
## as the matrix prints), carried beside the scene as blob `<id>_values`.
## Missing cells are Arrow nulls, which always mean no data.
add_untiled_raster <- function(g, v, name, palette, range, legend) {
  s <- v$scene
  id <- unique_id(layer_id(name), s, c("", "_values"))
  vid <- paste0(id, "_values")
  vals <- as.numeric(t(g$x[, , 1L]))
  vals[!is.finite(vals)] <- NA_real_
  range <- range %||% value_range(vals)
  s$data[[vid]] <- list(format = "arrow-ipc-stream", blob = vid)
  layer <- list(
    id = id, kind = "raster", label = name,
    grid = list(crs = s$view$crs, extent = g$extent, dim = rev(dim(g$x)[1:2])),
    values = vid, values_column = "value",
    palette = list(name = palette %||% "viridis", range = as.numeric(range))
  )
  s$layers[[length(s$layers) + 1L]] <- layer
  blobs <- attr(s, "blobs") %||% list()
  blobs[[vid]] <- table_ipc(data.frame(value = vals))
  attr(s, "blobs") <- blobs
  v$scene <- s
  v$extents[[id]] <- g$extent
  ## A palette raster's ramp: written as a legend only when the scene is
  ## 0.5 (see add_legends()).
  v$keys <- c(v$keys, list(list(layer = id, palette = TRUE, legend = legend)))
  v
}

## The palette range of values v: their range to 7 significant figures,
## widened by a half each way when every value is the same, as
## aobcore::cog_plan() takes it from a COG.
value_range <- function(v) {
  v <- v[is.finite(v)]
  if (!length(v)) return(c(0, 1))
  r <- signif(range(v), 7)
  if (r[1] == r[2]) r + c(-0.5, 0.5) else r
}

## Arrow IPC stream bytes of a plain table (no geometry column): a scene
## carries an untiled raster's values this way.
table_ipc <- function(df) {
  con <- rawConnection(raw(), open = "wb")
  on.exit(close(con))
  nanoarrow::write_nanoarrow(nanoarrow::as_nanoarrow_array_stream(df), con)
  rawConnectionValue(con)
}

## The no-data value of the matrix route's temporary Float32 COG, so a
## missing cell is the file's no-data value, not NaN: -2^127, exact in
## Float32 and well inside its range. terra's -FLT_MAX sits on the edge of
## that range, and the double-to-float conversion on the way through GDAL
## 3.8 with gdalraster 2.7 (CRAN's macOS binaries) turns it into -Inf.
float_nodata <- -(2^127)
## The largest magnitude Float32 holds; a double beyond it is no data.
float_max <- 3.4028234663852886e+38

## Write grid g (from grid_input()) to a temporary COG with GDAL and read
## its structure. One band is written as Float32 with missing cells as
## float_nodata. A colour image (rgb) is written pixel interleaved: as Byte
## when every value is a whole number from 0 to 255, with the three colour
## bands' missing cells as 0 and an alpha band of 0 there (added when the
## image has none), as raster_temp_cog() writes it; else as Float32 with
## float_nodata. The grid's top row is the file's first row.
grid_temp_cog <- function(g, rgb) {
  x <- g$x
  d <- dim(x)
  nb <- d[3]
  byte <- rgb && all(is_byte_value(x) | is.na(x))
  if (byte) {
    miss <- is.na(x[, , 1L]) | is.na(x[, , 2L]) | is.na(x[, , 3L])
    if (nb == 4L) miss <- miss | is.na(x[, , 4L])
    if (any(miss)) {
      alpha <- if (nb == 4L) x[, , 4L] else matrix(255, d[1], d[2])
      alpha[miss] <- 0
      x <- array(c(x[, , 1:3], alpha), c(d[1:2], 4L))
      x[is.na(x)] <- 0
      nb <- 4L
    }
  }
  src <- tempfile("grid-", tmpdir = temp_cog_dir(), fileext = ".tif")
  on.exit(unlink(src), add = TRUE)
  f <- tempfile("view-", tmpdir = temp_cog_dir(), fileext = ".tif")
  e <- g$extent
  ds <- gdalraster::create("GTiff", src, d[2], d[1], nb, if (byte) "Byte" else "Float32",
                           return_obj = TRUE)
  ds$setGeoTransform(c(e[1], (e[2] - e[1]) / d[2], 0, e[4], 0, -(e[4] - e[3]) / d[1]))
  ds$setProjection(gdalraster::srs_to_wkt(as.character(g$crs)))
  for (b in seq_len(nb)) {
    v <- as.numeric(t(x[, , b]))
    if (!byte) {
      ds$setNoDataValue(b, float_nodata)
      v[!is.finite(v) | abs(v) > float_max] <- float_nodata
    }
    ds$write(b, 0L, 0L, d[2], d[1], v)
  }
  ds$close()
  args <- c("-of", "COG", "-co", paste0("BLOCKSIZE=", temp_cog_block))
  if (rgb && gdal_at_least("3.11")) args <- c(args, "-co", "INTERLEAVE=PIXEL")
  ok <- tryCatch(gdalraster::translate(src, f, args, quiet = TRUE), error = function(e) {
    unlink(f)
    stop("GDAL could not write `x` to a temporary COG: ", conditionMessage(e), call. = FALSE)
  })
  if (!isTRUE(ok) || !file.exists(f)) {
    unlink(f)
    stop("GDAL could not write `x` to a temporary COG.", call. = FALSE)
  }
  tryCatch(aobcore::cog_info(f), error = function(e) {
    unlink(f)
    stop(e)
  })
}

## Is each value a whole number from 0 to 255 (NA is not)?
is_byte_value <- function(x) !is.na(x) & x >= 0 & x <= 255 & x == round(x)
