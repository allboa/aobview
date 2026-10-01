#' View spatial data in its own CRS
#'
#' Draws `x` in a self-contained HTML page, in the CRS chosen by
#' [view_crs()] unless `crs` is given, and returns the view. Printing the
#' view in an interactive session opens the page in the IDE's viewer or the
#' browser. The page is written by [aobcore::write_scene_html()] and needs
#' no server and no network: the data travel in the page as native
#' 'GeoArrow'. A view with large local rasters is served from a local
#' server instead (see Transport).
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
#' geometry (with the popup columns, below). With `zcol`, polygons get a grey
#' outline (change it with `stroke`); `fill`, and `stroke` for lines, are
#' errors, since `zcol` sets those colours.
#'
#' **Legend.** With `zcol`, the view carries a legend for the colours, built
#' from the same [view_colours()] result as the features, so the two agree:
#' a ramp over the range for numbers, one entry per interval with `breaks`
#' (labelled as in `"(5, 10]"`), or one entry per level. An `"NA"` entry is
#' added only when some drawn feature took `na_colour`. A column with more
#' than 30 levels gets no legend (with a message), since a key that long is
#' not readable; the features are still coloured. `legend = FALSE` leaves it
#' out. A legend is scene spec 0.5 data (see [aobcore::scene_add_legend()]).
#'
#' **Popups.** `popup = TRUE` (the default) carries `x`'s attribute columns
#' in the page and declares them as the layer's popup (scene spec 0.5):
#' selecting a feature (a click, tap or key press) shows its values. Only
#' the first 20 columns are carried, with a message, since every column adds
#' bytes to the page; choose columns with `popup = c("a", "b")`, which has
#' no cap, or carry none with `popup = FALSE`. A data frame with no
#' attribute columns gets no popup. Numbers, character and logical columns
#' are carried as they are; factors as their labels, `Date` as
#' `"YYYY-MM-DD"`, `POSIXct` and `POSIXlt` as ISO 8601 text in UTC, and
#' other atomic classes as their `as.character()` text. List, raw and matrix columns
#' cannot be shown and are left out with a message.
#'
#' **Minimal style.** `style = "minimal"` draws with the least the page
#' carries and the renderer builds per feature, for exploring how much data
#' a view can take (like `pch = "."` in base graphics): opaque one-pixel
#' lines and polygon outlines, polygons not filled (so not triangulated),
#' points as two-pixel dots with no outline, and no popup columns unless
#' `popup` asks for them. Without `zcol`, each colour is one constant for
#' the layer, not a value per feature. `fill`, `stroke`, `stroke_width_px`
#' and `radius_px` still apply on top (a `fill` fills polygons again). With
#' `zcol`, the column colours polygon outlines rather than fills. An
#' unfilled polygon is selected (in a popup or from a served page) only by
#' its outline, not by a click inside it; give `fill` for that. The geometry itself
#' is unchanged: every vertex still travels in the page as 16 bytes (two
#' doubles), plus a third for base64.
#'
#' **Transport.** A view is embedded (the page above, on disk) or served
#' from a local HTTP server by [aobcore::serve_scene()], which the browser
#' reads a local COG from tile by tile instead of carrying its bytes in the
#' page (allboa/design decision 0006). `transport = "embed"` always embeds,
#' `"serve"` always serves (it needs the 'httpuv' package), and `"auto"`
#' (the default, or `getOption("aobview.transport")`) embeds unless the
#' view's local raster tiles, counted from each layer's tile plan before
#' any byte is read, come to more than `getOption("aobview.embed_max")`
#' bytes (32 MiB by default). Then, in an interactive session with 'httpuv'
#' installed, that layer and any added later are served, with a message
#' naming the size; otherwise the tiles are embedded with a warning. Vector
#' data and remote COGs never make a view served by themselves. A served
#' view keeps its server running until `v$server$stop()`,
#' [aobcore::stop_scene_servers()] or the end of the R session; the server
#' answers only while R is idle. A temporary COG (see [view-terra]) of a
#' served layer is kept in `file.path(tempdir(), "aobview-cogs")` until
#' the server stops.
#'
#' **Selections.** A served view's page sends the features the viewer
#' selects (a click, Shift-click to add or remove) back to R: every vector
#' layer can be selected. Read them with [selection()], [selected()] and
#' [wait_for_selection()]; an embedded page cannot send them.
#'
#' **Spec version.** The scene is written at the lowest scene spec version
#' that can express it ([aobcore::scene_spec_version()]): a view with no
#' legend and no popup is unchanged by these features.
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
#' @param style `"default"` or `"minimal"`, the starting point that `fill`,
#'   `stroke`, `stroke_width_px` and `radius_px` change. See Minimal style
#'   in [view()].
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
#' @param legend With `zcol`: `TRUE` (the default) adds a legend for the
#'   colours, `FALSE` leaves it out. Without `zcol` there is nothing to key.
#' @param popup `TRUE` shows the attribute columns (the first 20) for a
#'   selected feature, a character vector names the columns to show, and
#'   `FALSE` shows none. See Popups. `NULL` (the default) is `TRUE`, or
#'   `FALSE` with `style = "minimal"`.
#' @param stroke_width_px Line or outline width in pixels.
#' @param radius_px Point radius in pixels.
#' @param name The layer name, shown as the page title. Defaults to the
#'   expression passed as `x`.
#' @param file Path of the HTML file to write. Defaults to a new file in the
#'   session's temporary directory.
#'   Not used by a served view (with a warning).
#' @param theme `"auto"` follows the browser's light or dark preference;
#'   `"light"` or `"dark"` fixes it.
#' @param transport `"auto"`, `"embed"` or `"serve"`: whether the view is
#'   written to a page or served from a local server (see Transport).
#'   Defaults to `getOption("aobview.transport", "auto")`.
#' @return A view: a list of class `"aob_view"` with the `scene` (an
#'   [aobcore::scene()]), the `file` it was written to (`NULL` when served),
#'   the `server` serving it (an `"aob_server"` from
#'   [aobcore::serve_scene()], or `NULL` when embedded), its `name` (the
#'   page title), `theme`, `extents`, each layer's extent in the view
#'   CRS (from which the initial view is set), `sources`, each vector
#'   object viewed with its name and the map from its layers' rows to its
#'   own rows, and `serial`, the scene serial the server gave the scene
#'   (`NULL` when embedded). Add to it with [view_add()]. Printing it opens
#'   the page when the session is interactive; a served view's URL is
#'   opened only when no page is connected to its server, since an open
#'   page follows the view (see [selection()]).
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
#' v4$scene$legends[[1]]$classes[[1]]$label
#' v5 <- view(nc, zcol = "BIR74", popup = c("NAME", "BIR74"))
#' v5$scene$layers[[1]]$popup
#' v6 <- view(nc, style = "minimal")
#' v6$scene$layers[[1]][c("stroke", "stroke_width_px", "fill")]
#'
#' # CCAMLR statistical areas (simplified, illustrative; see the extdata
#' # README) in EPSG:6932, coloured by area with popups, viewed in EPSG:3031
#' areas <- sf::st_read(system.file("extdata", "ccamlr_statistical_areas.geojson",
#'                                  package = "aobview"), quiet = TRUE)
#' areas$area <- paste0("Area ", substr(areas$GAR_Long_Label, 1, 2))
#' v7 <- view(areas, crs = "EPSG:3031", zcol = "area",
#'            popup = c("GAR_Name", "GAR_Long_Label", "GAR_Start_Date", "GAR_Size"))
#' v7 <- view_add(v7, coast, popup = FALSE)
#' vapply(v7$scene$legends[[1]]$classes, function(cl) cl$label, "")
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
view.sf <- function(x, ..., crs = NULL, densify = NULL, style = "default", fill = NULL,
                    stroke = NULL, stroke_width_px = NULL, radius_px = NULL, zcol = NULL,
                    palette = NULL, breaks = NULL, na_colour = "#999999", legend = TRUE,
                    popup = NULL, name = NULL, file = NULL,
                    theme = c("auto", "light", "dark"),
                    transport = getOption("aobview.transport", "auto")) {
  check_dots(..., what = "sf data")
  need_sf()
  name <- name %||% deparse_name(substitute(x))
  theme <- match.arg(theme)
  transport <- check_transport(transport)
  v <- new_view(crs %||% view_crs(x), transport)
  v <- add_layers(x, v, name, densify = densify, style = style, fill = fill, stroke = stroke,
                  stroke_width_px = stroke_width_px, radius_px = radius_px, zcol = zcol,
                  palette = palette, breaks = breaks, na_colour = na_colour,
                  legend = legend, popup = popup)
  finish_view(v, name, file, theme)
}

#' @rdname view
#' @export
view.sfc <- function(x, ..., crs = NULL, densify = NULL, style = "default", fill = NULL,
                     stroke = NULL, stroke_width_px = NULL, radius_px = NULL, name = NULL,
                     file = NULL, theme = c("auto", "light", "dark"),
                     transport = getOption("aobview.transport", "auto")) {
  no_zcol_for_sfc(...)
  check_dots(..., what = "sf data")
  need_sf()
  name <- name %||% deparse_name(substitute(x))
  theme <- match.arg(theme)
  transport <- check_transport(transport)
  v <- new_view(crs %||% view_crs(x), transport)
  v <- add_layers(x, v, name, densify = densify, style = style, fill = fill, stroke = stroke,
                  stroke_width_px = stroke_width_px, radius_px = radius_px)
  finish_view(v, name, file, theme)
}

#' @export
print.aob_view <- function(x, ...) {
  cat("<view> ", x$name, ": ", length(x$scene$layers), " layer",
      if (length(x$scene$layers) != 1L) "s", " in ", crs_text(x$scene$view$crs), "\n", sep = "")
  if (!is.null(x$server)) {
    running <- isTRUE(x$server$state$running)
    cat("  served at ", x$server$url, if (!running) " (stopped)", "\n", sep = "")
    ## A page already showing the server follows a changed scene by reload
    ## (decision 0007, item 5), so open one only when none is connected.
    if (can_open() && running && page_count(x$server) == 0L) open_url(x$server$url)
  } else {
    cat("  ", x$file, "\n", sep = "")
    if (interactive()) open_page(x$file)
  }
  invisible(x)
}

## ---- internals -------------------------------------------------------------

## A view is built in three steps, shared by every method, view.list() and
## view_add(): new_view() starts an empty scene in the view CRS,
## add_layers() appends one object's layers (reprojected to that CRS), and
## finish_view() sets the initial view and writes the page.

## An unwritten view: an empty scene in `crs`, with the view's domain as
## its bounds (aobcore::scene()'s default, decision 0005).
new_view <- function(crs, transport = "auto") {
  v <- structure(list(scene = aobcore::scene(aobcore::scene_crs(crs)), extents = list()),
                 class = "aob_view")
  begin_transport(v, transport)
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
add_layers.sf <- function(x, v, name, ..., densify = NULL, style = "default", fill = NULL,
                          stroke = NULL, stroke_width_px = NULL, radius_px = NULL, zcol = NULL,
                          palette = NULL, breaks = NULL, na_colour = "#999999",
                          legend = TRUE, popup = NULL) {
  check_dots(..., what = "sf data")
  need_sf()
  add_sf(x, v, name, densify,
         style = list(preset = check_style(style), fill = fill, stroke = stroke,
                      stroke_width_px = stroke_width_px, radius_px = radius_px),
         zcol = zcol, palette = palette, breaks = breaks, na_colour = na_colour,
         legend = legend, popup = popup)
}

#' @export
add_layers.sfc <- function(x, v, name, ..., densify = NULL, style = "default", fill = NULL,
                           stroke = NULL, stroke_width_px = NULL, radius_px = NULL) {
  no_zcol_for_sfc(...)
  check_dots(..., what = "sf data")
  need_sf()
  add_sfc(x, v, name, densify,
          style = list(preset = check_style(style), fill = fill, stroke = stroke,
                       stroke_width_px = stroke_width_px, radius_px = radius_px))
}

## An sf data frame's layers: its geometry, coloured by column `zcol` when
## given, with a legend for those colours and popup attribute columns.
## Shared by the sf and SpatVector methods.
add_sf <- function(x, v, name, densify, style, zcol = NULL, palette = NULL, breaks = NULL,
                   na_colour = "#999999", legend = TRUE, popup = NULL, source = x) {
  force(source)
  check_flag(legend, "legend")
  ## The minimal style carries no attribute columns unless asked to.
  popup <- popup %||% !identical(style$preset, "minimal")
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
  attrs <- popup_attributes(x, popup)
  before <- layer_ids(v$scene)
  v <- add_sfc(sf::st_geometry(x), v, name, densify, style, rgba = rgba, attrs = attrs,
               source = source)
  drawn <- v$drawn
  v$drawn <- NULL
  if (!is.null(rgba) && legend) {
    args <- legend_args(attr(rgba, "key"), values, rgba, zcol, drawn)
    ## One legend for the object: on its first (bottom) layer when mixed
    ## geometry was split into several.
    if (!is.null(args)) {
      v$keys <- c(v$keys, list(list(layer = setdiff(layer_ids(v$scene), before)[1L],
                                    args = args)))
    }
  }
  v
}

layer_ids <- function(s) vapply(s$layers, function(l) l$id, "")

check_flag <- function(x, arg) {
  if (!isTRUE(x) && !isFALSE(x)) stop("`", arg, "` must be TRUE or FALSE.", call. = FALSE)
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
                                  if (length(cols) > 10L) paste0(" and ", length(cols) - 10L,
                                                                 " more"))
         else "; it has no attribute columns",
         ".", call. = FALSE)
  }
  x[[zcol]]
}

## `rgba`, when given, is an n x 4 matrix of colours, one row per element
## of g, carried beside the geometry as the layer's colour column. `attrs`,
## when given, is a data frame of popup columns, one row per element of g,
## carried beside the geometry and named as each layer's popup.
##
## `source` is the object the user passed (an sf, sfc or SpatVector, whose
## rows are the elements of g). The view keeps it, under a name, with the
## row map of each layer made from it: layer row i (1-based, in the layer's
## Arrow data) came from row idx[i] of the source. Empty and untransformable
## geometries have no layer row; a geometry collection's parts can give one
## source row several (decision 0007, item 3). See selection().
add_sfc <- function(g, v, name, densify, style, rgba = NULL, attrs = NULL, source = g) {
  force(source)
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
  colour_col <- unique_name(colour_column, names(attrs))
  row_maps <- list()
  for (kind in names(parts)) {
    id <- if (multi) paste0(base, "_", kind) else base
    label <- if (multi) paste0(name, " (", kind_label[[kind]], ")") else name
    geom <- wk::wk_set_crs(wk::as_wkb(parts[[kind]]), NULL)
    geom <- wk::wk_set_crs(geom, view)
    style_k <- layer_style(kind, style)
    idx <- rows[split$rows[[kind]]]
    row_maps[[id]] <- as.integer(idx)
    if (!is.null(attrs)) {
      geom <- attribute_stream(geom, view, attrs[idx, , drop = FALSE])
      style_k$popup <- names(attrs)
    }
    if (!is.null(rgba)) {
      geom <- rgba_stream(geom, view, rgba[idx, , drop = FALSE], colour_col)
      style_k <- zcol_style(kind, style_k, style, colour_col)
    }
    args <- c(list(s, id, geom, label = label), style_k)
    s <- do.call(aobcore::scene_add_vector, args)
    v$extents[[id]] <- bbox_extent(parts[[kind]])
  }
  v$scene <- s
  v$sources <- c(v$sources, list(list(name = unique_name(name, source_names(v)),
                                      object = source, layers = row_maps)))
  ## The rows of x drawn (not empty, transformed), for the legend.
  v$drawn <- sort(unique(rows))
  v
}

## The column of per-feature colours in a layer's data.
colour_column <- "color"

## A layer coloured by column: fill for polygons and points, stroke for
## lines (so a `stroke` for lines is an error, as `fill` is for the rest).
## Polygons get a grey outline unless `stroke` was given. In the minimal
## style polygons have no fill, so the column colours their outline.
zcol_style <- function(kind, out, style, colour_col = colour_column) {
  if (kind == "polygon" && identical(style$preset, "minimal")) {
    if (!is.null(style$stroke)) {
      stop("`stroke` and `zcol` both set the colour of minimal-style polygon outlines; ",
           "use one.", call. = FALSE)
    }
    out$stroke <- colour_col
    return(out)
  }
  if (kind == "path") {
    if (!is.null(style$stroke)) {
      stop("`stroke` and `zcol` both set the colour of lines; use one.", call. = FALSE)
    }
    out$stroke <- colour_col
  } else {
    out$fill <- colour_col
    if (kind == "polygon" && is.null(style$stroke)) out$stroke <- zcol_outline
  }
  out
}

zcol_outline <- c(128L, 128L, 128L, 200L)

## A native GeoArrow stream of geom (already in the view CRS, or a stream
## from attribute_stream()) with an RGBA column, FixedSizeList<uint8, 4>,
## one row per feature (scene spec 0.1), appended after its columns.
rgba_stream <- function(geom, view, rgba, colour_col = colour_column) {
  stream <- if (inherits(geom, "nanoarrow_array_stream")) geom else
    aobcore::vector_stream(geom, view)
  schema <- stream$get_schema()
  batches <- nanoarrow::collect_array_stream(stream, validate = FALSE)
  cols <- names(schema$children)
  fields <- c(schema$children,
              list(nanoarrow::na_fixed_size_list(nanoarrow::na_uint8(), 4L)))
  names(fields) <- c(cols, colour_col)
  out_schema <- nanoarrow::na_struct(fields)
  start <- 0L
  arrays <- lapply(batches, function(b) {
    i <- start + seq_len(b$length)
    start <<- start + b$length
    children <- c(b$children, list(rgba_array(rgba[i, , drop = FALSE])))
    names(children) <- c(cols, colour_col)
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

## Set the initial view, the legends and the scene version, write the
## page, and return the view.
finish_view <- function(v, name, file, theme) {
  s <- v$scene
  s$view$extent <- view_extent(v$extents, s$view$bounds)
  s <- add_legends(s, v$keys)
  s$version <- aobcore::scene_spec_version(s)
  server <- NULL
  if (is_served(v)) {
    if (!is.null(file)) {
      warning("`file` is not written: the view is served from a local server, not ",
              "embedded in a page. Use `transport = \"embed\"` for a page on disk.",
              call. = FALSE)
    }
    file <- NULL
    server <- serve_view(v, s, name, theme)
  } else {
    file <- file %||% tempfile("view-", fileext = ".html")
    aobcore::write_scene_html(s, file = file, title = name, theme = theme)
  }
  structure(list(scene = s, file = file, server = server, name = name, theme = theme,
                 extents = v$extents, keys = v$keys, local_bytes = v$local_bytes %||% 0,
                 sources = v$sources, serial = if (!is.null(server)) server$state$serial),
            class = "aob_view")
}

## The scene's legends, rebuilt from the view's keys (one per keyed layer,
## in the order the layers were added) each time a page is written, so
## view_add() can change what the scene needs.
##
## A key is list(layer, args) for a layer coloured by column, or
## list(layer, palette = TRUE, legend = TRUE/FALSE) for a palette raster.
## Before scene spec 0.5 the renderer draws a ramp for each palette raster
## itself and the spec has no legends, so a scene that needs nothing from
## 0.5 is left as it is: the lowest version that expresses it. A 0.5 scene
## (any legend or popup) draws only its own legends, so then each palette
## raster gets its ramp as a legend. A palette raster with legend = FALSE
## can only go without its ramp in 0.5, so it makes the scene 0.5.
add_legends <- function(s, keys) {
  s$legends <- NULL
  palette <- vapply(keys, function(k) isTRUE(k$palette), TRUE)
  wanted <- vapply(keys, function(k) !isTRUE(k$palette) || isTRUE(k$legend), TRUE)
  popups <- any(vapply(s$layers, function(l) !is.null(l$popup), TRUE))
  hide_ramp <- any(palette & !wanted)
  if (!any(!palette) && !popups && !hide_ramp) return(s)
  for (k in keys[wanted]) {
    s <- do.call(aobcore::scene_add_legend, c(list(s, k$layer), k$args))
  }
  if (hide_ramp) s$version <- "0.5"
  s
}

## Levels above which a categorical legend is left out.
legend_max_levels <- 30L

## scene_add_legend() arguments for a zcol key (see view_colours()), or
## NULL when there is nothing to key (no value took a colour, or too many
## levels to read). `drawn` indexes the rows actually drawn, which decide
## whether an NA entry is needed.
legend_args <- function(key, values, rgba, title, drawn = seq_along(values)) {
  na <- as.integer(grDevices::col2rgb(key$na_colour, alpha = TRUE))
  colours <- hex_rgba(key$colours)
  out <- list(title = title)
  if (key$type == "continuous") {
    r <- key$range
    if (anyNA(r)) return(NULL)
    if (r[1] == r[2]) {
      ## One value: one class, in the colour view_colours() gave it.
      one <- unname(rgba[which(is.finite(as.numeric(values)))[1L], ])
      out$classes <- stats_names(list(one), format_num(r[1]))
    } else {
      out$ramp <- list(range = r, stops = colours)
    }
  } else if (key$type == "binned") {
    b <- format_num(key$breaks)
    k <- length(b) - 1L
    labels <- paste0(c("[", rep("(", k - 1L)), b[-(k + 1L)], ", ", b[-1L], "]")
    out$classes <- stats_names(lapply(seq_len(k), function(i) colours[i, ]), labels)
  } else {
    if (!length(key$levels)) return(NULL)
    if (length(key$levels) > legend_max_levels) {
      message("`", title, "` has ", length(key$levels), " levels, more than a legend shows (",
              legend_max_levels, "); the view has no legend for it.")
      return(NULL)
    }
    out$classes <- stats_names(lapply(seq_along(key$levels), function(i) colours[i, ]),
                               key$levels)
  }
  if (na_present(key, values[drawn])) {
    out$na <- list(label = "NA", color = na)
  }
  out
}

## Did any value take the NA colour? view_colours() gives it to NA (and
## non-finite numbers), to values outside `breaks`, and to values with no
## level.
na_present <- function(key, values) {
  if (key$type == "categorical") return(anyNA(match(as.character(values), key$levels)))
  v <- as.numeric(values)
  out <- !is.finite(v)
  if (key$type == "binned") {
    b <- key$breaks
    out <- out | (is.finite(v) & (v < b[1] | v > b[length(b)]))
  }
  any(out)
}

stats_names <- function(x, nms) {
  names(x) <- nms
  x
}

format_num <- function(x) vapply(x, function(z) format(z, digits = 6), "")

hex_rgba <- function(hex) {
  m <- t(grDevices::col2rgb(hex, alpha = TRUE))
  storage.mode(m) <- "integer"
  unname(m)
}

## A name not in `taken`: name, else name_2, name_3, ...
unique_name <- function(name, taken) {
  out <- name
  i <- 1L
  while (out %in% taken) {
    i <- i + 1L
    out <- paste0(name, "_", i)
  }
  out
}

## ---- popups ----------------------------------------------------------------

## Columns carried for popup = TRUE; more are left out with a message.
popup_max <- 20L

## The popup columns of x as a data frame of writable columns, or NULL for
## none. popup is TRUE (the first popup_max attribute columns), FALSE, or a
## character vector of column names.
popup_attributes <- function(x, popup) {
  if (isFALSE(popup) || is.null(popup)) return(NULL)
  geom <- attr(x, "sf_column")
  cols <- setdiff(names(x), geom)
  if (isTRUE(popup)) {
    if (!length(cols)) return(NULL)
    if (length(cols) > popup_max) {
      message("The popup shows the first ", popup_max, " of ", length(cols), " columns; ",
              "choose them with `popup = c(...)`.")
      cols <- cols[seq_len(popup_max)]
    }
  } else if (is.character(popup) && length(popup) && !anyNA(popup)) {
    if (anyDuplicated(popup)) stop("`popup` names a column more than once.", call. = FALSE)
    if (any(popup %in% geom)) {
      stop("\"", geom, "\" is the geometry column; `popup` names attribute columns.",
           call. = FALSE)
    }
    miss <- setdiff(popup, cols)
    if (length(miss)) {
      stop("`popup` column", if (length(miss) > 1L) "s", " not in `x`: ",
           paste0("\"", miss, "\"", collapse = ", "), ".", call. = FALSE)
    }
    cols <- popup
  } else {
    stop("`popup` must be TRUE, FALSE or a character vector of column names.", call. = FALSE)
  }
  df <- sf::st_drop_geometry(x)
  out <- lapply(cols, function(nm) popup_column(df[[nm]]))
  names(out) <- cols
  bad <- vapply(out, is.null, TRUE)
  if (any(bad)) {
    message("Popup column", if (sum(bad) > 1L) "s", " ",
            paste0("\"", cols[bad], "\"", collapse = ", "),
            " cannot be shown as text and ", if (sum(bad) > 1L) "are" else "is", " left out.")
    out <- out[!bad]
  }
  if (!length(out)) return(NULL)
  structure(out, class = "data.frame", row.names = c(NA_integer_, -nrow(df)))
}

## One column as a vector the Arrow writer takes (numbers, text, logical),
## or NULL when it cannot be shown. Factors become their labels (aobcore's
## IPC writer cannot write dictionaries), dates and times ISO 8601 text.
popup_column <- function(x) {
  ## POSIXlt is a list: convert it before list columns are dropped.
  if (inherits(x, "POSIXt")) {
    x <- format(as.POSIXct(x), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  }
  if (is.list(x) || is.raw(x) || !is.null(dim(x))) return(NULL)
  if (is.factor(x)) {
    x <- as.character(x)
  } else if (inherits(x, "Date")) {
    x <- format(x, "%Y-%m-%d")
  } else if (inherits(x, c("units", "difftime"))) {
    x <- as.numeric(unclass(x))
  } else if (is.object(x) || is.complex(x)) {
    x <- tryCatch(as.character(x), error = function(e) NULL)
    if (is.null(x)) return(NULL)
  }
  if (is.character(x)) x <- enc2utf8(x)
  if (!is.character(x) && !is.numeric(x) && !is.logical(x)) return(NULL)
  attributes(x) <- NULL
  ok <- tryCatch({
    nanoarrow::as_nanoarrow_array(x)
    TRUE
  }, error = function(e) FALSE)
  if (ok) x else NULL
}

## A native GeoArrow stream of geom (already in the view CRS) with the
## columns of data frame `attrs` before it, one row per feature.
attribute_stream <- function(geom, view, attrs) {
  gcol <- unique_name("geometry", names(attrs))
  df <- attrs
  rownames(df) <- NULL
  df[[gcol]] <- geom
  aobcore::vector_stream(df, view, geometry = gcol)
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

## style = "minimal" (like pch = "." in base graphics): the least the
## renderer has to build per feature. Opaque one-pixel lines and outlines,
## polygons unfilled (no triangulation, no fill layer), points as two-pixel
## dots with no outline, and no popup columns (see add_sf()).
minimal_style <- list(
  polygon = list(stroke = c(default_blue, 255L), stroke_width_px = 1),
  path = list(stroke = c(default_blue, 255L), stroke_width_px = 1),
  point = list(fill = c(default_blue, 255L), radius_px = 1)
)

styles <- c("default", "minimal")

check_style <- function(style) {
  if (!is.character(style) || length(style) != 1L || is.na(style) || !style %in% styles) {
    stop("`style` must be one of ", paste0("\"", styles, "\"", collapse = ", "), ".",
         call. = FALSE)
  }
  style
}

layer_style <- function(kind, style) {
  out <- if (identical(style$preset, "minimal")) minimal_style[[kind]] else default_style[[kind]]
  style$preset <- NULL
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
  ## Only the first few lines: do.call(view, list(x)) passes the data itself,
  ## whose full deparse can take longer than the view.
  nm <- paste(deparse(expr, width.cutoff = 60L, nlines = 5L), collapse = " ")
  if (nchar(nm) > 60L) nm <- paste0(substr(nm, 1L, 57L), "...")
  nm
}

crs_text <- function(crs) {
  if (inherits(crs, "aob_json")) "a PROJJSON CRS" else as.character(crs)
}

## Whether print() opens the page: wrapped so tests can stand in for an
## interactive session.
can_open <- function() interactive()

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
