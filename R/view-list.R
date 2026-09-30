#' View several layers in one page
#'
#' `view()` of a list draws each element as one or more layers of a single
#' scene, in one view CRS, in list order: the first element at the bottom.
#' `view_add()` adds a layer to a view already made, on top, and writes a
#' new page, so `view(a) |> view_add(b)` gives the same scene as
#' `view(list(a = a, b = b))`.
#'
#' Elements may be `sf` or `sfc` objects and 'terra' `SpatRaster` or
#' `SpatVector` objects, in any mix of CRSs. Each is drawn as [view()] or
#' [view-terra] draws it on its own, with its default style, and reprojected
#' to the view CRS: vectors with [sf::st_transform()] (lon/lat edges
#' densified first), rasters by [aobcore::cog_plan()]'s meshes.
#'
#' **View CRS.** `crs` when given; otherwise [view_crs()] of the whole list:
#' the CRS of the first element with a projected CRS, or, when every element
#' is in lon/lat, the lon/lat rule applied once to their combined latitude
#' range. `view_add()` keeps the view's CRS and reprojects `x` to it.
#'
#' **Names.** List names become layer labels and, made valid and unique,
#' layer ids. An unnamed element takes the expression that gave it in a
#' call such as `view(list(coast, r))`, else `x[[i]]`. When an id is taken,
#' `_2`, `_3`, ... is appended.
#'
#' **Initial view.** The union of the layers' extents in the view CRS,
#' clipped to the view's domain ([aobcore::crs_domain()], carried as the
#' scene's `view.bounds`, allboa/design decision 0005). The scene's spec
#' version is the highest any of its layers or its view needs.
#'
#' For a style of your own on one layer, start with [view()] of it or add it
#' with `view_add()`, which take each kind's arguments.
#'
#' @param x For `view()`, a list of spatial objects. For `view_add()`, one
#'   spatial object (or a list of them) to add.
#' @param ... For `view()` of a list, nothing (per-layer arguments go to
#'   `view_add()`). For `view_add()`, the arguments [view()] or
#'   [view-terra] take for `x`'s class, such as `fill` for `sf` data or
#'   `palette` for a `SpatRaster`.
#' @param crs The view CRS, as for [view()]. `NULL` uses [view_crs()] of
#'   the list.
#' @param name The page title. For a list, defaults to the layer labels
#'   joined by commas. For `view_add()`, the new layer's name, which
#'   defaults to the expression passed as `x`; the page title becomes the
#'   view's name and this one, joined by a comma.
#' @param file Path of the HTML file to write. Defaults to a new file in the
#'   session's temporary directory. `view_add()` leaves `v`'s page as it is.
#' @param theme As for [view()]. `view_add()` defaults to `v`'s theme.
#' @param v A view from [view()] or `view_add()`.
#' @return A view, as for [view()].
#' @seealso [view()], [view-terra], [view_crs()].
#' @name view-layers
#' @examplesIf requireNamespace("sf", quietly = TRUE)
#' coast <- sf::st_read(system.file("extdata", "coastline_south_40s.geojson",
#'                                  package = "aobcore"), quiet = TRUE)
#' stations <- sf::st_sfc(sf::st_point(c(110.53, -66.28)), sf::st_point(c(77.97, -68.58)),
#'                        crs = "OGC:CRS84")
#' v <- view(list(coast = coast, stations = stations))
#' vapply(v$scene$layers, function(l) l$id, "")
#'
#' v2 <- view_add(view(coast), stations, fill = c(220, 60, 40, 255))
#' v2$scene$layers[[2]]$fill
#' @examplesIf requireNamespace("sf", quietly = TRUE) && requireNamespace("terra", quietly = TRUE) && requireNamespace("gdalraster", quietly = TRUE) && !inherits(try(gdalraster::srs_to_wkt("EPSG:3031"), silent = TRUE), "try-error")
#' sst <- terra::rast(system.file("extdata", "polar_3031.tif", package = "aobcore"))
#' v3 <- view(list(sst = sst, coast = coast))
#' v3$scene$view$crs
NULL

#' @rdname view-layers
#' @export
view.list <- function(x, ..., crs = NULL, name = NULL, file = NULL,
                      theme = c("auto", "light", "dark")) {
  check_dots(..., what = "a list")
  theme <- match.arg(theme)
  labels <- list_labels(x, substitute(x))
  v <- new_view(crs %||% view_crs_list(x, labels))
  v <- add_list(x, v, labels)
  finish_view(v, name %||% paste(labels, collapse = ", "), file, theme)
}

#' @rdname view-layers
#' @export
view_add <- function(v, x, ..., name = NULL, file = NULL, theme = NULL) {
  if (!inherits(v, "aob_view") || is.null(v$scene)) {
    stop("`v` must be a view from view().", call. = FALSE)
  }
  theme <- match.arg(theme %||% v$theme %||% "auto", c("auto", "light", "dark"))
  if (is_plain_list(x)) {
    check_dots(..., what = "a list")
    labels <- list_labels(x, substitute(x))
    v <- add_list(x, v, labels)
    name <- name %||% paste(labels, collapse = ", ")
  } else {
    name <- name %||% deparse_name(substitute(x))
    v <- add_layers(x, v, name, ...)
  }
  finish_view(v, paste(c(v$name, name), collapse = ", "), file, theme)
}

#' @export
view_crs.list <- function(x) {
  view_crs_list(x, list_labels(x, substitute(x)))
}

## ---- internals -------------------------------------------------------------

is_plain_list <- function(x) is.list(x) && identical(class(x), "list")

view_crs_list <- function(x, labels) {
  check_list(x, labels)
  facts <- lapply(seq_along(x), function(i) in_element(i, labels[i], crs_facts(x[[i]])))
  combined_view_crs(facts)
}

add_list <- function(x, v, labels) {
  check_list(x, labels)
  for (i in seq_along(x)) {
    v <- in_element(i, labels[i], add_layers(x[[i]], v, labels[i]))
  }
  v
}

check_list <- function(x, labels) {
  if (!length(x)) stop("The list has nothing to view.", call. = FALSE)
  ok <- vapply(x, function(el) inherits(el, c("sf", "sfc", "SpatRaster", "SpatVector")), TRUE)
  if (!all(ok)) {
    i <- which(!ok)[1]
    stop("List element ", i, " (", labels[i], ") is a ", paste(class(x[[i]]), collapse = "/"),
         "; a list for view() holds sf and sfc objects, and terra SpatRaster and ",
         "SpatVector objects.", call. = FALSE)
  }
  invisible(x)
}

## Evaluate expr, naming the list element in any error.
in_element <- function(i, label, expr) {
  tryCatch(expr, error = function(e) {
    stop("List element ", i, " (", label, "): ", conditionMessage(e), call. = FALSE)
  })
}

## Layer names for a list's elements: its names; else, for an element of a
## call such as list(coast, r), the argument's expression; else "x[[i]]".
list_labels <- function(x, expr) {
  n <- length(x)
  nms <- names(x) %||% rep("", n)
  nms[is.na(nms)] <- ""
  args <- NULL
  if (is.call(expr) && identical(expr[[1]], quote(list))) {
    args <- as.list(expr)[-1L]
    if (length(args) != n) args <- NULL
  }
  whole <- deparse_name(expr)
  vapply(seq_len(n), function(i) {
    if (nzchar(nms[i])) return(nms[i])
    if (!is.null(args)) return(deparse_name(args[[i]]))
    paste0(whole, "[[", i, "]]")
  }, "")
}
