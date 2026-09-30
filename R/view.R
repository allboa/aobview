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
#' geometries are dropped, as are Z and M values. The split layers share
#' the view's name, with the kind appended to each label, as in
#' `"mixed (polygons)"`.
#'
#' 'aobcore' does not reproject, so `x` is transformed to the view CRS here
#' with [sf::st_transform()]. When `x` is in lon/lat and the view CRS
#' differs, lines and polygon edges are first densified in lon/lat (every
#' `densify` degrees, 0.25 by default), so an edge along a parallel curves
#' as it should in a polar view instead of cutting across it.
#'
#' **Colour by attribute.** `zcol` names a column of `x` whose values
#' colour each feature: the fill of polygons and points, the stroke of
#' lines. Numbers take a continuous palette over their range (or one colour
#' per class with `breaks`), factors, character and logical values one
#' colour per level; `NA` takes `na_colour`. The colours are computed in R
#' by [view_colours()] and travel to the page as one RGBA column beside the
#' geometry; no other attribute does. With `zcol`, polygons get a grey
#' outline (change it with `stroke`) and `fill` is not used.
#'
#' @param x A spatial object: an `sf` data frame or an `sfc` geometry column
#'   (with the 'sf' package installed); a 'terra' object ([view-terra]); or
#'   a list of them ([view-layers]).
#' @param ... Not used by the `sf` and `sfc` methods: an argument caught
#'   here (a misspelled one, say) is an error.
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
#' @param zcol The name of a column of `x` to colour features by, or `NULL`
#'   (the default) for one colour. Not for an `sfc`, which has no columns.
#' @param palette With `zcol`: a palette name (from
#'   [grDevices::hcl.pals()] or [grDevices::palette.pals()]) or a function
#'   of `n` returning `n` colours, such as [grDevices::hcl.colors()]; see
#'   [view_colours()]. `NULL` is `"viridis"` for numbers and `"Tableau 10"`
#'   for levels.
#' @param breaks With a numeric `zcol`: increasing break points that bin
#'   the values into classes, one colour each; see [view_colours()].
#' @param na_colour With `zcol`: the colour for `NA` values.
#' @param stroke_width_px Line or outline width in pixels.
#' @param radius_px Point radius in pixels.
#' @param name The layer name, shown as the page title. Defaults to the
#'   expression passed as `x`.
#' @param file Path of the HTML file to write. Defaults to a new file in the
#'   session's temporary directory.
#' @param theme `"auto"` follows the browser's light or dark preference;
#'   `"light"` or `"dark"` fixes it.
#' @return A view: a list of class `"aob_view"` with the `scene` (an
#'   [aobcore::scene()]), the `file` it was written to, its `name` (the
#'   page title), `theme`, and `extents`, each layer's extent in the view
#'   CRS (from which the initial view is set). Add to it with
#'   [view_add()]. Printing it opens
#'   the page when the session is interactive.
#' @seealso [view_crs()] for the default view CRS; [view-terra] for 'terra'
#'   rasters and vectors; [view-layers] for several layers in one view.
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
#' v3 <- view(nc, zcol = "BIR74", palette = "YlOrRd")
#' v4 <- view(nc, zcol = "SID74", breaks = c(0, 5, 10, 20, 50))
#' \dontrun{
#' v2
#' v3
#' }
view <- function(x, ...) {
  UseMethod("view")
}

#' @export
view.default <- function(x, ...) {
  stop(no_method_message(x), call. = FALSE)
}

#' @rdname view
#' @export
view.sf <- function(x, ..., crs = NULL, densify = NULL, fill = NULL, stroke = NULL,
                    stroke_width_px = NULL, radius_px = NULL, zcol = NULL, palette = NULL,
                    breaks = NULL, na_colour = "#999999", name = NULL, file = NULL,
                    theme = c("auto", "light", "dark")) {
  check_dots(..., what = "sf data")
  need_sf()
  name <- name %||% deparse_name(substitute(x))
  theme <- match.arg(theme)
  v <- new_view(crs %||% view_crs(x))
  v <- add_layers(x, v, name, densify = densify, fill = fill, stroke = stroke,
                  stroke_width_px = stroke_width_px, radius_px = radius_px, zcol = zcol,
                  palette = palette, breaks = breaks, na_colour = na_colour)
  finish_view(v, name, file, theme)
}

#' @rdname view
#' @export
view.sfc <- function(x, ..., crs = NULL, densify = NULL, fill = NULL, stroke = NULL,
                     stroke_width_px = NULL, radius_px = NULL, name = NULL,
                     file = NULL, theme = c("auto", "light", "dark")) {
  no_zcol_for_sfc(...)
  check_dots(..., what = "sf data")
  need_sf()
  name <- name %||% deparse_name(substitute(x))
  theme <- match.arg(theme)
  v <- new_view(crs %||% view_crs(x))
  v <- add_layers(x, v, name, densify = densify, fill = fill, stroke = stroke,
                  stroke_width_px = stroke_width_px, radius_px = radius_px)
  finish_view(v, name, file, theme)
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

## A view is built in three steps, shared by every method, view.list() and
## view_add(): new_view() starts an empty scene in the view CRS,
## add_layers() appends one object's layers (reprojected to that CRS), and
## finish_view() sets the initial view and writes the page.

## An unwritten view: an empty scene in `crs`, with the view's domain as
## its bounds (aobcore::scene()'s default, decision 0005).
new_view <- function(crs) {
  structure(list(scene = aobcore::scene(aobcore::scene_crs(crs)), extents = list()),
            class = "aob_view")
}

## Append x's layers to view v, above those already there. Methods: sf and
## sfc here, SpatRaster and SpatVector in view-terra.R. Each returns v with
## its scene extended and the layers' extents (view CRS units) recorded.
add_layers <- function(x, v, name, ...) {
  UseMethod("add_layers")
}

#' @export
add_layers.default <- function(x, v, name, ...) {
  stop(no_method_message(x), call. = FALSE)
}

#' @export
add_layers.sf <- function(x, v, name, ..., densify = NULL, fill = NULL, stroke = NULL,
                          stroke_width_px = NULL, radius_px = NULL, zcol = NULL,
                          palette = NULL, breaks = NULL, na_colour = "#999999") {
  check_dots(..., what = "sf data")
  need_sf()
  add_sf(x, v, name, densify,
         style = list(fill = fill, stroke = stroke, stroke_width_px = stroke_width_px,
                      radius_px = radius_px),
         zcol = zcol, palette = palette, breaks = breaks, na_colour = na_colour)
}

#' @export
add_layers.sfc <- function(x, v, name, ..., densify = NULL, fill = NULL, stroke = NULL,
                           stroke_width_px = NULL, radius_px = NULL) {
  no_zcol_for_sfc(...)
  check_dots(..., what = "sf data")
  need_sf()
  add_sfc(x, v, name, densify,
          style = list(fill = fill, stroke = stroke, stroke_width_px = stroke_width_px,
                       radius_px = radius_px))
}

## An sf data frame's layers: its geometry, coloured by column `zcol` when
## given. Shared by the sf and SpatVector methods.
add_sf <- function(x, v, name, densify, style, zcol = NULL, palette = NULL, breaks = NULL,
                   na_colour = "#999999") {
  rgba <- NULL
  if (!is.null(zcol)) {
    values <- zcol_values(x, zcol)
    if (!is.null(style$fill)) {
      stop("`fill` and `zcol` both set the fill colour; use one.", call. = FALSE)
    }
    rgba <- view_colours(values, palette = palette, breaks = breaks, na_colour = na_colour)
  } else if (!is.null(palette) || !is.null(breaks)) {
    stop("`palette` and `breaks` colour a column: give `zcol` too.", call. = FALSE)
  }
  add_sfc(sf::st_geometry(x), v, name, densify, style, rgba = rgba)
}

no_zcol_for_sfc <- function(...) {
  if ("zcol" %in% names(list(...))) {
    stop("`zcol` needs a column to colour by; an sfc has none. Use an sf data frame.",
         call. = FALSE)
  }
}

## The values of column `zcol` of x (sf, or any data frame).
zcol_values <- function(x, zcol) {
  if (!is.character(zcol) || length(zcol) != 1L || is.na(zcol) || !nzchar(zcol)) {
    stop("`zcol` must be the name of one column.", call. = FALSE)
  }
  cols <- setdiff(names(x), attr(x, "sf_column"))
  if (!zcol %in% cols) {
    stop("`zcol` \"", zcol, "\" is not a column of `x`",
         if (length(cols)) paste0("; it has ", paste0("\"", utils::head(cols, 10L), "\"",
                                                      collapse = ", "),
                                  if (length(cols) > 10L) ", ...")
         else "; it has no attribute columns",
         ".", call. = FALSE)
  }
  x[[zcol]]
}

## `rgba`, when given, is an n x 4 matrix of colours, one row per element
## of g, carried beside the geometry as the layer's colour column.
add_sfc <- function(g, v, name, densify, style, rgba = NULL) {
  if (length(g) == 0L) stop("`x` has no geometries to view.", call. = FALSE)
  rows <- seq_along(g)
  keep <- !sf::st_is_empty(g)
  g <- g[keep]
  rows <- rows[keep]
  if (length(g) == 0L) stop("Every geometry in `x` is empty.", call. = FALSE)
  s <- v$scene
  view <- s$view$crs
  warn_geographic_view(g, view)
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
    rows <- rows[!lost]
  }

  split <- split_kinds(g)
  parts <- split$parts
  multi <- length(parts) > 1L
  base <- unique_id(layer_id(name), s, if (multi) paste0("_", names(parts)) else "")
  for (kind in names(parts)) {
    id <- if (multi) paste0(base, "_", kind) else base
    label <- if (multi) paste0(name, " (", kind_label[[kind]], ")") else name
    geom <- wk::wk_set_crs(wk::as_wkb(parts[[kind]]), NULL)
    geom <- wk::wk_set_crs(geom, view)
    style_k <- layer_style(kind, style)
    if (!is.null(rgba)) {
      geom <- rgba_stream(geom, view, rgba[rows[split$rows[[kind]]], , drop = FALSE])
      style_k <- zcol_style(kind, style_k, style)
    }
    args <- c(list(s, id, geom, label = label), style_k)
    s <- do.call(aobcore::scene_add_vector, args)
    v$extents[[id]] <- bbox_extent(parts[[kind]])
  }
  v$scene <- s
  v
}

## The column of per-feature colours in a layer's data.
colour_column <- "color"

## A layer coloured by column: fill for polygons and points, stroke for
## lines. Polygons get a grey outline unless `stroke` was given.
zcol_style <- function(kind, out, style) {
  if (kind == "path") {
    out$stroke <- colour_column
  } else {
    out$fill <- colour_column
    if (kind == "polygon" && is.null(style$stroke)) out$stroke <- zcol_outline
  }
  out
}

zcol_outline <- c(128L, 128L, 128L, 200L)

## A native GeoArrow stream of geom (already in the view CRS) with an RGBA
## column, FixedSizeList<uint8, 4>, one row per feature (scene spec 0.1).
rgba_stream <- function(geom, view, rgba) {
  stream <- aobcore::vector_stream(geom, view)
  schema <- stream$get_schema()
  batches <- nanoarrow::collect_array_stream(stream, validate = FALSE)
  geom_col <- names(schema$children)[1L]
  fields <- list(schema$children[[1L]], nanoarrow::na_fixed_size_list(nanoarrow::na_uint8(), 4L))
  names(fields) <- c(geom_col, colour_column)
  out_schema <- nanoarrow::na_struct(fields)
  start <- 0L
  arrays <- lapply(batches, function(b) {
    i <- start + seq_len(b$length)
    start <<- start + b$length
    children <- list(b$children[[1L]], rgba_array(rgba[i, , drop = FALSE]))
    names(children) <- c(geom_col, colour_column)
    nanoarrow::nanoarrow_array_modify(nanoarrow::nanoarrow_array_init(out_schema),
                                      list(length = b$length, children = children))
  })
  nanoarrow::basic_array_stream(arrays)
}

## A FixedSizeList<uint8, 4> array from an n x 4 integer matrix.
rgba_array <- function(m) {
  child <- nanoarrow::nanoarrow_array_modify(
    nanoarrow::nanoarrow_array_init(nanoarrow::na_uint8()),
    list(length = length(m), buffers = list(NULL, nanoarrow::as_nanoarrow_buffer(as.raw(t(m)))))
  )
  nanoarrow::nanoarrow_array_modify(
    nanoarrow::nanoarrow_array_init(nanoarrow::na_fixed_size_list(nanoarrow::na_uint8(), 4L)),
    list(length = nrow(m), children = list(child))
  )
}

kind_label <- list(polygon = "polygons", path = "lines", point = "points")

## Set the initial view and the scene version, write the page, and return
## the view.
finish_view <- function(v, name, file, theme) {
  s <- v$scene
  s$view$extent <- view_extent(v$extents, s$view$bounds)
  s$version <- aobcore::scene_spec_version(s)
  file <- file %||% tempfile("view-", fileext = ".html")
  aobcore::write_scene_html(s, file = file, title = name, theme = theme)
  structure(list(scene = s, file = file, name = name, theme = theme, extents = v$extents),
            class = "aob_view")
}

## The initial view (decision 0005): the union of the layers' extents,
## clipped to the view's bounds (the whole bounds when they do not meet),
## or NULL (the renderer's default) when the union has no area.
view_extent <- function(extents, bounds) {
  e <- do.call(rbind, extents)
  if (is.null(e)) return(NULL)
  e <- e[apply(e, 1L, function(r) all(is.finite(r))), , drop = FALSE]
  if (!nrow(e)) return(bounds)
  u <- c(min(e[, 1]), max(e[, 2]), min(e[, 3]), max(e[, 4]))
  ## A single point or a straight line along an axis has no area: leave the
  ## initial view to the renderer rather than open on the whole domain.
  if (!(u[1] < u[2] && u[3] < u[4])) return(NULL)
  if (!is.null(bounds)) {
    clip <- c(max(u[1], bounds[1]), min(u[2], bounds[2]), max(u[3], bounds[3]), min(u[4], bounds[4]))
    ## Data wholly outside the domain: open on the domain.
    u <- if (clip[1] < clip[2] && clip[3] < clip[4]) clip else bounds
  }
  as.numeric(u)
}

bbox_extent <- function(g) {
  bb <- sf::st_bbox(g)
  as.numeric(bb[c("xmin", "xmax", "ymin", "ymax")])
}

## A layer id from `base` that, with each of `suffixes`, is neither a layer
## id nor a data id in scene s: base, else base_2, base_3, ...
unique_id <- function(base, s, suffixes = "") {
  taken <- c(names(s$data), vapply(s$layers, function(l) l$id, ""))
  id <- base
  i <- 1L
  while (any(paste0(id, suffixes) %in% taken)) {
    i <- i + 1L
    id <- paste0(base, "_", i)
  }
  id
}

## Stop when a method's `...` caught arguments it does not use, such as a
## misspelled one.
check_dots <- function(..., what) {
  if (...length() == 0L) return(invisible())
  exprs <- as.list(substitute(list(...)))[-1L]
  nms <- names(exprs) %||% rep("", length(exprs))
  shown <- ifelse(nzchar(nms), paste0("`", nms, "`"),
                  paste0("an unnamed argument (", vapply(exprs, deparse_name, ""), ")"))
  stop("view() of ", what, " does not use ", paste(shown, collapse = ", "),
       ". Is an argument misspelled?", call. = FALSE)
}

no_method_message <- function(x) {
  paste0("view() has no method for class ", paste(class(x), collapse = "/"),
         "; it draws sf and sfc objects, terra SpatRaster and SpatVector objects, ",
         "and lists of them.")
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

## Decision 0004 rules out a per-coordinate transform of projected data into
## a geographic view: nothing cuts it at the antimeridian or the poles.
## (#9, item 2.) Warn, and say how to get a projected view.
warn_geographic_view <- function(g, view) {
  src <- sf::st_crs(g)
  if (is.na(src) || isTRUE(sf::st_is_longlat(g))) return(invisible())
  target <- tryCatch(sf::st_crs(as.character(view)), error = function(e) NULL)
  if (is.null(target) || !isTRUE(target$IsGeographic)) return(invisible())
  warning("`x` is in a projected CRS but the view CRS ", crs_text(view), " is geographic: ",
          "its coordinates are transformed point by point, with nothing cut at the ",
          "antimeridian or the poles, so lines and polygons that cross them are drawn wrongly. ",
          "Use a projected view: pass `crs =`, or view(list(...)), which keeps the first ",
          "projected CRS in the list.", call. = FALSE)
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
## Returns the parts and, for each, the index into g of each part's row (a
## collection's members share its row).
split_kinds <- function(g) {
  rows <- seq_along(g)
  type <- as.character(sf::st_geometry_type(g, by_geometry = TRUE))
  if (any(type == "GEOMETRYCOLLECTION")) {
    is_gc <- type == "GEOMETRYCOLLECTION"
    gc <- sf::st_sf(.row = rows[is_gc], geometry = g[is_gc])
    parts <- lapply(c("POLYGON", "LINESTRING", "POINT"), function(t) {
      suppressWarnings(sf::st_collection_extract(gc, t))
    })
    g <- do.call(c, c(list(g[!is_gc]), lapply(parts, sf::st_geometry)))
    rows <- c(rows[!is_gc], unlist(lapply(parts, function(p) p$.row)))
    keep <- !sf::st_is_empty(g)
    g <- g[keep]
    rows <- rows[keep]
    type <- as.character(sf::st_geometry_type(g, by_geometry = TRUE))
  }
  kinds <- c(polygon = "POLYGON", path = "LINESTRING", point = "POINT")
  out <- list()
  out_rows <- list()
  for (k in names(kinds)) {
    keep <- type %in% c(kinds[[k]], paste0("MULTI", kinds[[k]]))
    if (any(keep)) {
      out[[k]] <- g[keep]
      out_rows[[k]] <- rows[keep]
    }
  }
  other <- setdiff(unique(type), c(kinds, paste0("MULTI", kinds)))
  if (length(other)) {
    stop("view() draws points, lines and polygons; `x` also has ",
         paste(other, collapse = ", "), ". Convert those first (for example sf::st_cast()).",
         call. = FALSE)
  }
  list(parts = out, rows = out_rows)
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
