#' View a stars raster
#'
#' `view()` of a 'stars' object draws one attribute of a regular grid as a
#' raster (allboa/aobview#38, allboa/design decision 0011). A `stars_proxy`
#' carries file paths, so it routes as a `SpatRaster` read from a file does:
#' a proxy over a Cloud Optimized GeoTIFF, local or remote, is planned from
#' that file with [aobcore::cog_plan()] and never copied (a remote one is
#' referenced by URL); a proxy over another raster GDAL opens is read
#' through GDAL into a temporary COG (see Strings in [view()]). An
#' in-memory `stars` object is a matrix with an extent and CRS, and takes
#' the route of [view-matrix]: a grid of at most 512 by 512 cells in the
#' view CRS goes into the page untiled, and a larger or reprojected one
#' (a lon/lat grid south of 40S, say, which [view_crs()] draws in
#' EPSG:3031) is written to a temporary COG with 'gdalraster' and tiled.
#' Palettes, range and legend work as for a one-layer `SpatRaster` (see
#' [view-terra]); `...` goes to [aobcore::cog_plan()] on the tiled routes,
#' and is an error on the untiled one. No 'terra' is needed.
#'
#' **Which proxy is drawn from its file.** A proxy whose attribute is one
#' file, read whole (its `x` and `y` dimensions are the file's, with no
#' pending operation such as `x * 2`) in the file's own CRS, is drawn from
#' that file, exactly as the file's path would be (see Strings in
#' [view()]): a COG as it is, any other raster through GDAL. A proxy
#' sliced to one band (`x[, , , 2]`) draws that band. Any other proxy (a
#' crop, a computation, several files along a dimension, a changed CRS) is
#' read into memory with [stars::st_as_stars()] and drawn as an in-memory
#' object is, as a computed or cropped `SpatRaster` goes to a temporary
#' COG. A proxy over a colour COG (3 or 4 Byte bands with red, green, blue
#' colour interpretation) draws as a colour image unless `layer` or
#' `palette` is given.
#'
#' **Attributes and bands.** One band is drawn through the palette. An
#' object with several attributes draws the first, or the one `layer`
#' names or numbers. An object with one attribute and one dimension beyond
#' `x` and `y` (`band`, `time`, ...) draws the first slice along it, or the
#' one `layer` picks by number, or by name among that dimension's values.
#' An object with several attributes and such a dimension draws the first
#' slice of the chosen attribute; with more than one dimension beyond `x`
#' and `y` of more than one element, slice it first (`x[, , , 1, 2]`, or
#' `dplyr::slice()`; a dimension of one element is not counted). A factor
#' attribute draws its codes, a `units` attribute its numbers.
#'
#' **Orientation.** 'stars' stores an attribute as an array with `x` first
#' and `y` second, and the grid's `y` `delta` is usually negative (the
#' offset is the top edge). The matrix route takes rows from the top, so
#' the array is transposed here, and flipped when `delta` is positive (or
#' negative for `x`): `x[[1]][i, j]` is the cell at column `i` from the
#' left and row `j` from the `y` offset, as 'stars' means it, whichever
#' way the offsets run.
#'
#' **Out of scope for now.** Curvilinear grids (`x` and `y` as matrices),
#' rectilinear grids (an `x` or `y` dimension with explicit cell edges
#' rather than one `delta`), sheared or rotated grids (a non-zero affine),
#' and vector data cubes (a dimension of simple features) are not drawn
#' (allboa/design decision 0010, item 5); each is an error that says so.
#' Warp a curvilinear or rectilinear grid to a regular one with
#' [stars::st_warp()] first, or draw a vector cube's geometries with
#' `view(sf::st_as_sf(x))`.
#'
#' **CRS.** The view CRS follows [view_crs()]'s rule from the object's own
#' CRS ([sf::st_crs()]), as for a `SpatRaster`: a projected CRS is kept, a
#' lon/lat grid south of 40S or north of 60N is drawn in a polar view. An
#' object with no CRS is an error. A `stars` object has an extent and CRS
#' of its own, so it can be an element of `view(list(...))` and added to a
#' view with [view_add()] with no further argument.
#'
#' @inheritParams view
#' @param x A 'stars' object: a regular raster grid in memory, or a
#'   `stars_proxy` over one or more files ([stars::read_stars()] with
#'   `proxy = TRUE`).
#' @param ... Passed to [aobcore::cog_plan()] when `x` is tiled (a proxy
#'   drawn from its file, or an in-memory grid larger than 512 by 512 or
#'   not in the view CRS): `max_tiles`, `max_stretch`, `tolerance`, ... An
#'   argument caught here when `x` is drawn untiled is an error.
#' @param layer The attribute to draw when `x` has several, else the slice
#'   along its dimension beyond `x` and `y`, as a name or a number (see
#'   Attributes and bands). `NULL` (the default) draws the first.
#' @param palette A palette name the renderer knows: `"viridis"` (the
#'   default), `"ocean"`, `"ice"` or `"gray"`.
#' @param range `c(low, high)`: the values at the ends of the palette; by
#'   default the range of the values (of the COG's coarsest level for a
#'   proxy drawn from its file).
#' @param legend `TRUE` (the default) keys the palette with a ramp and
#'   `FALSE` leaves it out (see Legend in [view-terra]).
#' @return A view, as for [view()].
#' @seealso [view-matrix] for the in-memory route and its orientation;
#'   [view-terra] for the tiled route; [view_crs()] for the view CRS.
#' @name view-stars
#' @examplesIf requireNamespace("stars", quietly = TRUE) && requireNamespace("gdalraster", quietly = TRUE) && !inherits(try(gdalraster::srs_to_wkt("EPSG:3031"), silent = TRUE), "try-error")
#' # A proxy over a COG: planned from the file, never copied.
#' f <- system.file("extdata", "polar_3031.tif", package = "aobcore")
#' p <- stars::read_stars(f, proxy = TRUE)
#' v <- view(p, palette = "ocean")
#' v$scene$layers[[1]]$kind
#' v$scene$data[[1]]$url
#'
#' # A small grid in memory, in EPSG:3031: untiled, in the page.
#' bb <- sf::st_bbox(c(xmin = -3e6, xmax = 3e6, ymin = -2e6, ymax = 2e6),
#'                   crs = sf::st_crs(3031))
#' s <- stars::st_as_stars(bb, nx = 30, ny = 20, values = seq_len(600))
#' v2 <- view(s)
#' v2$scene$layers[[1]]$kind
NULL

#' @rdname view-stars
#' @export
view.stars <- function(x, ..., crs = NULL, layer = NULL, palette = NULL, range = NULL,
                       legend = TRUE, name = NULL, file = NULL,
                       theme = c("auto", "light", "dark"),
                       transport = getOption("aobview.transport", "auto")) {
  need_stars()
  name <- name %||% deparse_name(substitute(x))
  theme <- match.arg(theme)
  transport <- check_transport(transport)
  v <- new_view(crs %||% view_crs(x), transport)
  on.exit(drop_pending(v), add = TRUE)
  v <- add_layers(x, v, name, ..., layer = layer, palette = palette, range = range,
                  legend = legend)
  finish_view(v, name, file, theme)
}

#' @rdname view-stars
#' @export
view.stars_proxy <- function(x, ..., crs = NULL, layer = NULL, palette = NULL, range = NULL,
                             legend = TRUE, name = NULL, file = NULL,
                             theme = c("auto", "light", "dark"),
                             transport = getOption("aobview.transport", "auto")) {
  need_stars()
  name <- name %||% deparse_name(substitute(x))
  theme <- match.arg(theme)
  transport <- check_transport(transport)
  v <- new_view(crs %||% view_crs(x), transport)
  on.exit(drop_pending(v), add = TRUE)
  v <- add_layers(x, v, name, ..., layer = layer, palette = palette, range = range,
                  legend = legend)
  finish_view(v, name, file, theme)
}

## An in-memory object through the matrix route (add_grid(): untiled or a
## temporary COG).
#' @export
add_layers.stars <- function(x, v, name, ..., layer = NULL, palette = NULL, range = NULL,
                             legend = TRUE) {
  need_stars()
  add_grid(stars_grid(x, layer), v, name, ..., palette = palette, range = range,
           legend = legend)
}

## A proxy from its file when it is one file read whole (the string route,
## view-string.R: a COG as it is, another raster through GDAL), else read
## into memory and drawn as an in-memory object.
#' @export
add_layers.stars_proxy <- function(x, v, name, ..., layer = NULL, palette = NULL,
                                   range = NULL, legend = TRUE) {
  need_stars()
  src <- proxy_source(x, layer)
  if (is.null(src)) {
    return(add_layers(stars::st_as_stars(x), v, name, ..., layer = layer, palette = palette,
                      range = range, legend = legend))
  }
  add_source_raster(src, v, name, ..., palette = palette, range = range, legend = legend)
}

## The CRS facts of a stars object or proxy (both inherit "stars"), from
## its dimensions alone: no cell is read.
#' @export
crs_facts.stars <- function(x) {
  need_stars()
  f <- stars_facts(x)
  list(crs = f$crs, lonlat = f$lonlat, ylim = if (f$lonlat) f$extent[3:4])
}

## ---- internals -------------------------------------------------------------

## The grid of a stars object or proxy, from its dimensions: its x and y
## dimension names, their positions in the attribute array, the extent
## c(xmin, xmax, ymin, ymax), whether each axis runs backwards from the
## array's order (a positive y delta, a negative x delta), its CRS as
## view_crs() gives it, whether that is lon/lat, and the dimensions beyond
## x and y. An irregular grid (curvilinear, rectilinear, sheared), a vector
## cube and an object with no CRS are errors here.
stars_facts <- function(x) {
  d <- attr(x, "dimensions")
  r <- attr(d, "raster")
  xy <- r$dimensions
  cube <- vapply(d, function(dm) inherits(dm$values, "sfc"), TRUE)
  if (any(cube)) {
    stop("`x` is a stars vector data cube (its \"", names(d)[cube][1], "\" dimension holds ",
         "simple features), which view() does not draw: vector data cubes are out of scope ",
         "for now (allboa/design decision 0010, item 5). Draw its geometries with ",
         "view(sf::st_as_sf(x)).", call. = FALSE)
  }
  if (is.null(xy) || length(xy) != 2L || anyNA(xy) || !all(xy %in% names(d))) {
    stop("`x` has no x and y raster dimensions, so there is no grid to draw.", call. = FALSE)
  }
  if (isTRUE(r$curvilinear)) {
    stop("`x` is a curvilinear stars grid (its x and y are matrices), which view() does not ",
         "draw: curvilinear and rectilinear grids are out of scope for now (allboa/design ",
         "decision 0010, item 5). Warp it to a regular grid first, stars::st_warp(x, ...).",
         call. = FALSE)
  }
  dx <- unclass(d[[xy[1]]])
  dy <- unclass(d[[xy[2]]])
  if (!is.null(dx$values) || !is.null(dy$values) || is.na(dx$delta) || is.na(dy$delta)) {
    stop("`x` is a rectilinear stars grid (its x or y dimension lists cell edges rather than ",
         "one delta), which view() does not draw: curvilinear and rectilinear grids are out ",
         "of scope for now (allboa/design decision 0010, item 5). Warp it to a regular grid ",
         "first, stars::st_warp(x, ...).", call. = FALSE)
  }
  if (!is.null(r$affine) && any(r$affine != 0)) {
    stop("`x` is a sheared or rotated stars grid (a non-zero affine), which view() does not ",
         "draw: with curvilinear grids it is out of scope for now (allboa/design decision ",
         "0010, item 5). Warp it to a regular grid first, stars::st_warp(x, ...).",
         call. = FALSE)
  }
  crs <- sf::st_crs(x)
  if (is.na(crs)) {
    stop("`x` has no CRS. Set one with sf::st_set_crs(x, \"EPSG:...\"), or pass `crs` to ",
         "view().", call. = FALSE)
  }
  def <- crs$wkt
  ## The outer edges of the cells from `from` to `to`, whichever way the
  ## offsets run.
  ex <- dx$offset + c(dx$from - 1, dx$to) * dx$delta
  ey <- dy$offset + c(dy$from - 1, dy$to) * dy$delta
  ## The dimensions beyond x and y with more than one element: one of
  ## length 1 (left by a slice, x[, , , 2]) needs no picking.
  other <- setdiff(names(d), xy)
  other <- other[vapply(other, function(nm) {
    dm <- unclass(d[[nm]])
    isTRUE(dm$to - dm$from + 1 > 1)
  }, TRUE)]
  list(xy = xy, at = match(xy, names(d)), extent = c(sort(ex), sort(ey)),
       flip_x = dx$delta < 0, flip_y = dy$delta > 0,
       crs = crs_code(def) %||% view_crs_definition(def), lonlat = crs_is_lonlat(def),
       wkt = def, other = other)
}

## Which attribute and which slice `layer` picks: list(attr, slice), both
## indices, with `slice` NULL when there is no dimension beyond x and y
## (see Attributes and bands in ?view-stars).
stars_pick <- function(x, layer, f) {
  d <- attr(x, "dimensions")
  if (length(f$other) > 1L) {
    stop("`x` has ", length(f$other), " dimensions beyond x and y (",
         paste0("\"", f$other, "\"", collapse = ", "), "); view() draws one slice of one. ",
         "Slice it first (x[, , , i, j], or dplyr::slice()).", call. = FALSE)
  }
  na <- length(x)
  if (!na) stop("`x` has no attributes to view.", call. = FALSE)
  attr_i <- 1L
  slice <- if (length(f$other)) 1L
  if (is.null(layer)) return(list(attr = attr_i, slice = slice))
  if (na > 1L) {
    return(list(attr = pick_index(layer, names(x), na, "attribute"), slice = slice))
  }
  if (is.null(slice)) {
    if (is.numeric(layer) && length(layer) == 1L && isTRUE(layer == 1)) {
      return(list(attr = 1L, slice = NULL))
    }
    stop("`x` has one attribute and no dimension beyond x and y, so `layer` picks nothing.",
         call. = FALSE)
  }
  dm <- unclass(d[[f$other]])
  n <- dm$to - dm$from + 1
  vals <- tryCatch(as.character(stars::st_get_dimension_values(x, f$other)),
                   error = function(e) NULL)
  list(attr = 1L, slice = pick_index(layer, vals, n, paste0("\"", f$other, "\" slice")))
}

## `layer` as an index from 1 to n: a number, or a name among `names`.
pick_index <- function(layer, names, n, what) {
  if (is.character(layer) && length(layer) == 1L && !is.na(layer)) {
    i <- match(layer, names)
    if (is.na(i)) stop("`x` has no ", what, " \"", layer, "\".", call. = FALSE)
    return(i)
  }
  if (!is.numeric(layer) || length(layer) != 1L || is.na(layer) || layer != round(layer) ||
      layer < 1 || layer > n) {
    stop("`layer` must be one ", what, " name or number from 1 to ", n, ".", call. = FALSE)
  }
  as.integer(layer)
}

## An in-memory stars object as a grid for add_grid() (grid_input()'s
## shape): the picked attribute's slice as a matrix with rows from the top
## (see Orientation in ?view-stars), with the object's extent and CRS.
stars_grid <- function(x, layer) {
  f <- stars_facts(x)
  p <- stars_pick(x, layer, f)
  a <- x[[p$attr]]
  ## Factor codes and units as plain numbers.
  a <- array(as.numeric(unclass(a)), dim(a))
  other <- setdiff(seq_along(dim(a)), f$at)
  a <- aperm(a, c(f$at, other))
  dim(a) <- c(dim(a)[1:2], prod(dim(a)[-(1:2)]))
  m <- t(a[, , p$slice %||% 1L])
  if (f$flip_y) m <- m[rev(seq_len(nrow(m))), , drop = FALSE]
  if (f$flip_x) m <- m[, rev(seq_len(ncol(m))), drop = FALSE]
  grid_input(m, f$extent, f$crs, "a stars object")
}

## The file a proxy is drawn from, as the string route's aob_source
## (probe_source()), with the band `layer` picks, or NULL when the proxy is
## not one file read whole in its own CRS (then it is read into memory).
proxy_source <- function(x, layer) {
  f <- stars_facts(x)
  p <- stars_pick(x, layer, f)
  files <- x[[p$attr]]
  if (!is.character(files) || length(files) != 1L || length(attr(x, "call_list"))) return(NULL)
  ## The file's dimensions, one row per file of the proxy: whole when x and
  ## y run from 1 to the file's size.
  fd <- attr(x, "file_dim")
  i <- sum(lengths(unclass(x))[seq_len(p$attr - 1L)]) + 1L
  if (!is.matrix(fd) || nrow(fd) < i || is.null(colnames(fd)) || !all(f$xy %in% colnames(fd))) {
    return(NULL)
  }
  d <- attr(x, "dimensions")
  whole <- all(vapply(f$xy, function(nm) {
    dm <- unclass(d[[nm]])
    isTRUE(dm$from == 1) && isTRUE(dm$to == fd[i, nm])
  }, TRUE))
  if (!whole) return(NULL)
  ## The band: the slice's place in the proxy's band range, when the file
  ## has bands; a proxy with no band dimension over a file of several is
  ## read into memory, since which band it means is not known here.
  band <- NULL
  nb <- if ("band" %in% colnames(fd)) fd[i, "band"] else 1L
  if ("band" %in% names(d)) {
    if (length(f$other) && !identical(f$other, "band")) return(NULL)
    dm <- unclass(d[["band"]])
    band <- as.integer(dm$from + (p$slice %||% 1L) - 1L)
    ## An unsliced band range with no `layer` lets the file choose (a colour
    ## image, else band 1), as a path would.
    if (is.null(layer) && dm$from == 1 && dm$to == nb) band <- NULL
  } else if (length(f$other) || nb > 1L) {
    return(NULL)
  }
  if (!has_gdalraster()) {
    stop("view() of a stars_proxy reads its file with the 'gdalraster' package (for ",
         "aobcore's COG reader), which is not installed: install.packages(\"gdalraster\").",
         call. = FALSE)
  }
  src <- probe_source(files, band)
  if (src$kind == "vector" || !same_crs(src$info$wkt, f$wkt)) return(NULL)
  src
}

need_stars <- function() {
  if (!requireNamespace("stars", quietly = TRUE)) {
    stop("view() of stars data needs the 'stars' package.", call. = FALSE)
  }
}
