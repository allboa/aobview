#' View spatial data in its own CRS
#'
#' Draws `x` in a self-contained HTML page, in the CRS chosen by
#' [view_crs()] unless `crs` is given, and returns the view. Printing the
#' view in an interactive session opens the page in the IDE's viewer or the
#' browser. The page is written by [aobcore::write_scene_html()] and needs
#' no server and no network: the data travel in the page as native
#' 'GeoArrow'.
#'
#' Points, lines and polygons (single or multi) are drawn as one layer
#' each. A mixed `GEOMETRY` or `GEOMETRYCOLLECTION` column is split into up
#' to three layers, polygons at the bottom, then lines, then points. Empty
#' geometries are dropped, as are Z and M values.
#'
#' 'aobcore' does not reproject, so `x` is transformed to the view CRS here
#' with [sf::st_transform()]. When `x` is in lon/lat and the view CRS
#' differs, lines and polygon edges are first densified in lon/lat (every
#' `densify` degrees, 0.25 by default), so an edge along a parallel curves
#' as it should in a polar view instead of cutting across it.
#'
#' Only the geometry travels to the page for now; attributes (for colour,
#' legends and popups) follow in later versions.
#'
#' @param x A spatial object: an `sf` data frame or an `sfc` geometry column
#'   (with the 'sf' package installed).
#' @param ... Passed to methods.
#' @param crs The view CRS: anything [sf::st_crs()] and
#'   [aobcore::scene_crs()] read, such as `"EPSG:3031"`, `3031` or a PROJ
#'   string. `NULL` (the default) uses [view_crs()].
#' @param densify Maximum edge length, in the units of `x`'s CRS, for lines
#'   and polygon edges before they are transformed. `NULL` (the default)
#'   densifies lon/lat data every 0.25 degrees when the view CRS differs,
#'   and nothing else; `FALSE` or `0` never densifies; a number densifies
#'   whenever the view CRS differs from `x`'s.
#' @param fill,stroke Colours as `c(r, g, b, a)`, integers 0 to 255. `NULL`
#'   keeps the defaults: a translucent blue fill with a blue outline for
#'   polygons, blue lines, and blue points with a white outline. `fill` is
#'   ignored for lines.
#' @param stroke_width_px Line or outline width in pixels.
#' @param radius_px Point radius in pixels.
#' @param name The layer name, shown as the page title. Defaults to the
#'   expression passed as `x`.
#' @param file Path of the HTML file to write. Defaults to a new file in the
#'   session's temporary directory.
#' @param theme `"auto"` follows the browser's light or dark preference;
#'   `"light"` or `"dark"` fixes it.
#' @return A view: a list of class `"aob_view"` with the `scene` (an
#'   [aobcore::scene()]) and the `file` it was written to. Printing it opens
#'   the page when the session is interactive.
#' @seealso [view_crs()] for the default view CRS; [view-terra] for 'terra'
#'   rasters and vectors.
#' @export
#' @examplesIf requireNamespace("sf", quietly = TRUE)
#' coast <- sf::st_read(system.file("extdata", "coastline_south_40s.geojson",
#'                                  package = "aobcore"), quiet = TRUE)
#' v <- view(coast)
#' v$scene$view$crs
#' file.exists(v$file)
#'
#' nc <- sf::st_read(system.file("shape", "nc.shp", package = "sf"), quiet = TRUE)
#' v2 <- view(nc, crs = "EPSG:26717", fill = c(200, 120, 40, 160))
#' \dontrun{
#' v2
#' }
view <- function(x, ...) {
  UseMethod("view")
}

#' @export
view.default <- function(x, ...) {
  stop("view() has no method for class ", paste(class(x), collapse = "/"),
       "; it draws sf and sfc objects, and terra SpatRaster and SpatVector objects.", call. = FALSE)
}

#' @rdname view
#' @export
view.sf <- function(x, ..., crs = NULL, densify = NULL, fill = NULL, stroke = NULL,
                    stroke_width_px = NULL, radius_px = NULL, name = NULL,
                    file = NULL, theme = c("auto", "light", "dark")) {
  need_sf()
  name <- name %||% deparse_name(substitute(x))
  view_sfc(sf::st_geometry(x), crs = crs, densify = densify,
           style = list(fill = fill, stroke = stroke, stroke_width_px = stroke_width_px,
                        radius_px = radius_px),
           name = name, file = file, theme = match.arg(theme))
}

#' @rdname view
#' @export
view.sfc <- function(x, ..., crs = NULL, densify = NULL, fill = NULL, stroke = NULL,
                     stroke_width_px = NULL, radius_px = NULL, name = NULL,
                     file = NULL, theme = c("auto", "light", "dark")) {
  need_sf()
  name <- name %||% deparse_name(substitute(x))
  view_sfc(x, crs = crs, densify = densify,
           style = list(fill = fill, stroke = stroke, stroke_width_px = stroke_width_px,
                        radius_px = radius_px),
           name = name, file = file, theme = match.arg(theme))
}

#' @export
print.aob_view <- function(x, ...) {
  cat("<view> ", x$name, ": ", length(x$scene$layers), " layer",
      if (length(x$scene$layers) != 1L) "s", " in ", crs_text(x$scene$view$crs), "\n",
      "  ", x$file, "\n", sep = "")
  if (interactive()) open_page(x$file)
  invisible(x)
}

## ---- internals -------------------------------------------------------------

view_sfc <- function(g, crs, densify, style, name, file, theme) {
  if (length(g) == 0L) stop("`x` has no geometries to view.", call. = FALSE)
  g <- g[!sf::st_is_empty(g)]
  if (length(g) == 0L) stop("Every geometry in `x` is empty.", call. = FALSE)
  view <- if (is.null(crs)) view_crs(g) else crs
  view <- aobcore::scene_crs(view)
  g <- to_view_crs(g, view, densify)
  lost <- sf::st_is_empty(g)
  if (all(lost)) {
    stop("No geometry in `x` could be transformed to the view CRS ", crs_text(view),
         " (is a datum grid PROJ needs missing?).", call. = FALSE)
  }
  if (any(lost)) {
    warning(sum(lost), " of ", length(g), " geometries could not be transformed to the ",
            "view CRS ", crs_text(view), " and are left out.", call. = FALSE)
    g <- g[!lost]
  }

  s <- aobcore::scene(view)
  base <- layer_id(name)
  parts <- split_kinds(g)
  for (kind in names(parts)) {
    id <- if (length(parts) == 1L) base else paste0(base, "_", kind)
    geom <- wk::wk_set_crs(wk::as_wkb(parts[[kind]]), NULL)
    geom <- wk::wk_set_crs(geom, view)
    args <- c(list(s, id, geom, label = name), layer_style(kind, style))
    s <- do.call(aobcore::scene_add_vector, args)
  }
  write_view(s, name, file, theme)
}

## Write a scene's page and return the view.
write_view <- function(s, name, file, theme) {
  file <- file %||% tempfile("view-", fileext = ".html")
  aobcore::write_scene_html(s, file = file, title = name, theme = theme)
  structure(list(scene = s, file = file, name = name), class = "aob_view")
}

## Transform to the view CRS, densifying first (see ?view).
to_view_crs <- function(g, view, densify) {
  src <- sf::st_crs(g)
  if (is.na(src)) {
    stop("`x` has no CRS. Set one with sf::st_set_crs() before viewing it in ",
         crs_text(view), ".", call. = FALSE)
  }
  target <- sf::st_crs(as.character(view))
  if (isTRUE(src == target)) return(g)
  step <- densify_step(densify, isTRUE(sf::st_is_longlat(g)))
  if (step > 0) {
    ## Planar segmentize in the source units: an edge in lon/lat is straight
    ## in lon/lat (as GDAL's -segmentize), not a great circle.
    sf::st_crs(g) <- NA
    g <- sf::st_segmentize(g, step)
    sf::st_crs(g) <- src
  }
  sf::st_transform(g, target)
}

densify_step <- function(densify, longlat) {
  if (is.null(densify)) return(if (longlat) 0.25 else 0)
  if (isFALSE(densify)) return(0)
  if (!is.numeric(densify) || length(densify) != 1L || is.na(densify) || densify < 0) {
    stop("`densify` must be NULL, FALSE or a single number, 0 or more.", call. = FALSE)
  }
  as.numeric(densify)
}

## Split geometry into point, line and polygon parts, bottom to top.
split_kinds <- function(g) {
  type <- as.character(sf::st_geometry_type(g, by_geometry = TRUE))
  if (any(type == "GEOMETRYCOLLECTION")) {
    gc <- g[type == "GEOMETRYCOLLECTION"]
    rest <- g[type != "GEOMETRYCOLLECTION"]
    parts <- lapply(c("POLYGON", "LINESTRING", "POINT"), function(t) {
      suppressWarnings(sf::st_collection_extract(gc, t))
    })
    g <- do.call(c, c(list(rest), parts))
    g <- g[!sf::st_is_empty(g)]
    type <- as.character(sf::st_geometry_type(g, by_geometry = TRUE))
  }
  kinds <- c(polygon = "POLYGON", path = "LINESTRING", point = "POINT")
  out <- list()
  for (k in names(kinds)) {
    keep <- type %in% c(kinds[[k]], paste0("MULTI", kinds[[k]]))
    if (any(keep)) out[[k]] <- g[keep]
  }
  other <- setdiff(unique(type), c(kinds, paste0("MULTI", kinds)))
  if (length(other)) {
    stop("view() draws points, lines and polygons; `x` also has ",
         paste(other, collapse = ", "), ". Convert those first (for example sf::st_cast()).",
         call. = FALSE)
  }
  out
}

default_blue <- c(51L, 102L, 204L)
default_style <- list(
  polygon = list(fill = c(default_blue, 90L), stroke = c(default_blue, 255L), stroke_width_px = 1),
  path = list(stroke = c(default_blue, 255L), stroke_width_px = 2),
  point = list(fill = c(default_blue, 220L), stroke = c(255L, 255L, 255L, 255L),
               stroke_width_px = 1, radius_px = 4)
)

layer_style <- function(kind, style) {
  out <- default_style[[kind]]
  for (nm in names(style)) {
    v <- style[[nm]]
    if (is.null(v)) next
    if (nm == "fill" && kind == "path") next
    if (nm == "radius_px" && kind != "point") next
    out[[nm]] <- v
  }
  out
}

## A valid scene id from a name: letters, digits, '_', '.', '-', starting
## with a letter.
layer_id <- function(name) {
  id <- gsub("[^A-Za-z0-9_.-]+", "_", name)
  id <- sub("^_+", "", id)
  if (!grepl("^[A-Za-z]", id)) id <- paste0("x", id)
  substr(id, 1L, 100L)
}

deparse_name <- function(expr) {
  nm <- paste(deparse(expr, width.cutoff = 60L), collapse = " ")
  if (nchar(nm) > 60L) nm <- paste0(substr(nm, 1L, 57L), "...")
  nm
}

crs_text <- function(crs) {
  if (inherits(crs, "aob_json")) "a PROJJSON CRS" else as.character(crs)
}

open_page <- function(file) {
  viewer <- getOption("viewer")
  ## IDE viewers show only files under the session's temporary directory.
  in_tmp <- startsWith(normalizePath(file, mustWork = FALSE),
                       normalizePath(tempdir(), mustWork = FALSE))
  if (is.function(viewer) && in_tmp) viewer(file) else utils::browseURL(file)
  invisible(file)
}

need_sf <- function() {
  if (!requireNamespace("sf", quietly = TRUE)) {
    stop("view() of sf data needs the 'sf' package.", call. = FALSE)
  }
}

`%||%` <- function(x, y) if (is.null(x)) y else x
