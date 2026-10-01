#' View a terra raster or vector
#'
#' `view()` of a 'terra' `SpatRaster` draws it as a tiled Cloud Optimized
#' GeoTIFF (COG) through 'aobcore': [aobcore::cog_info()] reads the COG's
#' structure, [aobcore::cog_plan()] plans its tiles with a mesh already
#' projected to the view CRS, and [aobcore::scene_add_tiled_raster()] adds
#' them to the scene. The raster is never resampled in R; reprojection
#' happens in the mesh.
#'
#' **Which COG.** When `x` is read unchanged from one tiled GeoTIFF with
#' overviews (a COG, or an image small enough for one tile), local or
#' remote (an `http(s)` URL or a `/vsicurl/` path), that file is used. A remote COG is referenced by URL and the browser fetches its tiles
#' by HTTP range requests (the server must allow them, and CORS): the page
#' carries the recipe, not the data. A local COG's planned tiles are
#' embedded in the page, unless the view is served (see Transport in
#' [view()]): then the server delivers the file. Anything else (a raster in
#' memory, a file that is
#' striped or has no overviews, several sources, a computed, cropped or
#' windowed raster, or one given another `terra::NAflag()`) is
#' written to a temporary COG in `file.path(tempdir(), "aobview-cogs")`
#' with `terra::writeRaster(filetype = "COG")`. When its planned tiles are
#' embedded, so the page opens from disk with no server, the temporary COG
#' is deleted once the layer is added; when the view is served, the server
#' keeps it until it stops.
#'
#' **Colour or palette.** A raster of 3 or 4 layers with values 0 to 255
#' (Byte) and colour interpretation red, green, blue (and alpha), set with
#' `terra::RGB()` (in its order) or else from the file, is drawn as a
#' colour image. Otherwise
#' one layer (`layer`, the first by default) is drawn through a palette over
#' the range of its values.
#'
#' **Legend.** A palette raster is keyed by a ramp of its palette over its
#' range. In a scene with no legends or popups otherwise (scene spec 0.4 or
#' earlier) the renderer draws that ramp itself and the scene stays at the
#' lowest version that expresses it; in a scene spec 0.5 scene (a legend or
#' popup on another layer) the ramp is written as the raster's legend with
#' [aobcore::scene_add_legend()]. `legend = FALSE` leaves the ramp out,
#' which needs scene spec 0.5. A colour image has no legend.
#'
#' A `SpatVector` is read from terra's own WKB (`terra::geom(x, wkb =
#' TRUE)`) with its attributes, and drawn as any vector data is (see
#' [view()]), coloured by an attribute with `zcol` (with a legend) and with
#' its attributes as popups. It does not need 'sf'.
#'
#' @inheritParams view
#' @param x A 'terra' `SpatRaster` or `SpatVector`.
#' @param ... For a `SpatRaster`, passed to [aobcore::cog_plan()]
#'   (`max_tiles`, `max_stretch`, `tolerance`, ...). Not used for a
#'   `SpatVector`: an argument caught there (a misspelled one, say) is an
#'   error.
#' @param layer The layer to draw through the palette (a number or name).
#'   Giving it draws that layer even when `x` is a colour image.
#' @param rgb `NULL` (colour when `x` is a Byte red, green, blue raster and
#'   neither `layer` nor `palette` is given), `TRUE` to draw a colour image
#'   of the layers `terra::RGB()` names (layers 1 to 3, and 4 as alpha,
#'   when it names none), or `FALSE` for the palette.
#' @param palette For a `SpatRaster`, a palette name the renderer knows:
#'   `"viridis"` (the default), `"ocean"`, `"ice"` or `"gray"`. For a
#'   `SpatVector` with `zcol`, a palette as for [view()]: a name from
#'   [grDevices::hcl.pals()] or [grDevices::palette.pals()], or a function
#'   of `n`.
#' @param legend For a palette `SpatRaster`, `TRUE` (the default) keys the
#'   palette with a ramp and `FALSE` leaves it out (see Legend). For a
#'   `SpatVector`, as for [view()].
#' @param range `c(low, high)`: the values at the ends of the palette. By
#'   default the range of the COG's coarsest level. For a colour image of a
#'   type other than Byte, the values drawn as zero and full intensity.
#' @return A view, as for [view()].
#' @seealso [view_crs()] for the default view CRS.
#' @name view-terra
#' @examplesIf requireNamespace("terra", quietly = TRUE) && requireNamespace("gdalraster", quietly = TRUE) && !inherits(try(gdalraster::srs_to_wkt("EPSG:3031"), silent = TRUE), "try-error")
#' r <- terra::rast(system.file("extdata", "polar_lonlat.tif", package = "aobcore"))
#' v <- view(r, palette = "ocean")
#' v$scene$view$crs
#'
#' m <- terra::rast(ncols = 72, nrows = 20, xmin = -180, xmax = 180, ymin = -90, ymax = -40,
#'                  vals = 1:1440, crs = "OGC:CRS84")
#' view(m)
NULL

#' @rdname view-terra
#' @export
view.SpatRaster <- function(x, ..., crs = NULL, layer = NULL, rgb = NULL, palette = NULL,
                            range = NULL, legend = TRUE, name = NULL, file = NULL,
                            theme = c("auto", "light", "dark"),
                            transport = getOption("aobview.transport", "auto")) {
  need_terra()
  need_gdalraster()
  name <- name %||% deparse_name(substitute(x))
  theme <- match.arg(theme)
  transport <- check_transport(transport)
  check_raster(x)
  v <- new_view(crs %||% view_crs(x), transport)
  v <- add_layers(x, v, name, ..., layer = layer, rgb = rgb, palette = palette, range = range,
                  legend = legend)
  finish_view(v, name, file, theme)
}

#' @rdname view-terra
#' @export
view.SpatVector <- function(x, ..., crs = NULL, densify = NULL, fill = NULL, stroke = NULL,
                            stroke_width_px = NULL, radius_px = NULL, zcol = NULL,
                            palette = NULL, breaks = NULL, na_colour = "#999999",
                            legend = TRUE, popup = TRUE, name = NULL, file = NULL,
                            theme = c("auto", "light", "dark"),
                            transport = getOption("aobview.transport", "auto")) {
  check_dots(..., what = "a SpatVector")
  need_terra()
  name <- name %||% deparse_name(substitute(x))
  theme <- match.arg(theme)
  transport <- check_transport(transport)
  check_terra_crs(x)
  v <- new_view(crs %||% view_crs(x), transport)
  v <- add_layers(x, v, name, densify = densify, fill = fill, stroke = stroke,
                  stroke_width_px = stroke_width_px, radius_px = radius_px, zcol = zcol,
                  palette = palette, breaks = breaks, na_colour = na_colour,
                  legend = legend, popup = popup)
  finish_view(v, name, file, theme)
}

#' @export
add_layers.SpatVector <- function(x, v, name, ..., densify = NULL, fill = NULL, stroke = NULL,
                                  stroke_width_px = NULL, radius_px = NULL, zcol = NULL,
                                  palette = NULL, breaks = NULL, na_colour = "#999999",
                                  legend = TRUE, popup = TRUE) {
  check_dots(..., what = "a SpatVector")
  need_terra()
  check_terra_crs(x)
  add_record(vector_record(x), v, name, densify = densify, fill = fill, stroke = stroke,
             stroke_width_px = stroke_width_px, radius_px = radius_px, zcol = zcol,
             palette = palette, breaks = breaks, na_colour = na_colour, legend = legend,
             popup = popup, source = x)
}

## `...` goes to aobcore::cog_plan(), which refuses arguments it does not
## take.
#' @export
add_layers.SpatRaster <- function(x, v, name, ..., layer = NULL, rgb = NULL, palette = NULL,
                                  range = NULL, legend = TRUE) {
  check_flag(legend, "legend")
  need_terra()
  need_gdalraster()
  check_raster(x)
  if (!is.null(rgb) && !(isTRUE(rgb) || isFALSE(rgb))) {
    stop("`rgb` must be NULL, TRUE or FALSE.", call. = FALSE)
  }
  if (!is.null(palette) &&
      (!is.character(palette) || length(palette) != 1L || is.na(palette) || !nzchar(palette))) {
    stop("`palette` must be a single palette name.", call. = FALSE)
  }
  if (isTRUE(rgb) && !terra::nlyr(x) %in% 3:4) {
    stop("`rgb = TRUE` needs 3 or 4 layers; `x` has ", terra::nlyr(x), ".", call. = FALSE)
  }

  src <- raster_cog_source(x)
  colour <- if (!is.null(rgb)) rgb else {
    is.null(layer) && is.null(palette) && raster_is_rgb(x, src)
  }
  temp <- NULL
  if (colour) {
    ## Layers in red, green, blue (alpha) order.
    ord <- rgb_order(x, src)
    if (!is.null(src) && identical(src$cog$planar, "interleaved")) {
      cog <- src$cog
      bands <- src$bands[ord]
    } else {
      cog <- temp <- raster_temp_cog(x[[ord]], rgb = TRUE)
      bands <- seq_len(cog$samples_per_pixel)
    }
  } else {
    i <- raster_layer(x, layer)
    cog <- if (is.null(src)) {
      temp <- raster_temp_cog(x[[i]], rgb = FALSE)
    } else if (src$bands[i] == src$cog$band) {
      src$cog
    } else {
      aobcore::cog_info(src$dsn, band = src$bands[i])
    }
  }

  ## An embedded layer carries its planned tiles' bytes in the scene, so a
  ## temporary COG is not needed once the layer is added. A served layer's
  ## temporary COG is kept, for the server to own and delete when it stops.
  keep <- FALSE
  if (!is.null(temp)) on.exit(if (!keep) unlink(temp$dsn), add = TRUE)
  s <- v$scene
  plan <- aobcore::cog_plan(cog, s$view$crs, ...)
  ## Embed or serve, from the plan's tile byte lengths, before any tile
  ## byte is read (decision 0006).
  chosen <- choose_embed(v, cog, plan, name)
  v <- chosen$v
  id <- unique_id(layer_id(name), s, c("", "_vertices", "_indices"))
  s <- aobcore::scene_add_tiled_raster(s, id, plan,
                                       palette = palette %||% "viridis", range = range,
                                       rgb = if (colour) bands else FALSE,
                                       embed = chosen$embed, label = name)
  if (!is.null(temp) && isFALSE(chosen$embed)) {
    keep <- TRUE
    v$own <- c(v$own, temp$dsn)
  }
  v$scene <- s
  v$extents[[id]] <- plan_extent(s$layers[[length(s$layers)]]$plan)
  ## A palette raster's ramp: written as a legend only when the scene is
  ## 0.5 (see add_legends()).
  if (!colour) v$keys <- c(v$keys, list(list(layer = id, palette = TRUE, legend = legend)))
  v
}

## ---- internals -------------------------------------------------------------

## The COG `x` is read from, unchanged, as list(dsn, bands, cog), or NULL.
## `x` qualifies when all its layers come from one file GDAL gives tile
## offsets for, that file is cloud optimized enough to plan (see
## cog_ready()), and its grid, CRS, scaling and no-data value are the
## file's: a cropped, windowed, rescaled or re-flagged raster, or one with
## values in memory, does not.
raster_cog_source <- function(x) {
  if (any(terra::inMemory(x))) return(NULL)
  src <- terra::sources(x, bands = TRUE)
  if (!nrow(src) || length(unique(src$sid)) != 1L || !nzchar(src$source[1])) return(NULL)
  dsn <- raster_dsn(src$source[1])
  cog <- tryCatch(aobcore::cog_info(dsn, band = src$bands[1]), error = function(e) NULL)
  if (is.null(cog) || !cog_ready(cog) || !same_grid(x, cog) || !same_nodata(x, cog)) {
    return(NULL)
  }
  list(dsn = dsn, bands = as.integer(src$bands), cog = cog)
}

## Can a tile plan use this file as it is? Its full-resolution image must
## fit in one tile, or be tiled (not striped: a strip is as wide as the
## image) and have overviews. Otherwise a plan has one level of many
## full-width strips or tiles, and the page carries every one.
cog_ready <- function(cog) {
  l0 <- cog$levels[[1]]
  if (all(l0$tile_size >= l0$dim)) return(TRUE)
  l0$tile_size[1] < l0$dim[1] && length(cog$levels) > 1L
}

## Does x treat as missing what the file does? terra::NAflag() is NaN
## unless it was set on x, and a flag other than the file's no-data value
## makes cells missing that the file (and so the page) would draw.
same_nodata <- function(x, cog) {
  flag <- terra::NAflag(x)
  flag <- flag[!is.nan(flag)]
  if (!length(flag)) return(TRUE)
  !is.null(cog$nodata) && !is.nan(cog$nodata) && all(flag == cog$nodata)
}

## A terra source as a dsn for aobcore::cog_info(). terra gives a remote
## file as its URL or as a GDAL /vsicurl/ path; aobcore reads both, and
## gives the renderer the http(s) URL.
raster_dsn <- function(source) {
  if (grepl("^[A-Za-z0-9_]+:", source) && !grepl("^(https?|file):", source) &&
      !grepl("^[A-Za-z]:[/\\\\]", source)) {
    ## A GDAL driver prefix such as NETCDF:"f.nc":var is not one COG.
    return(NA_character_)
  }
  sub("^file://", "", source)
}

## Is x's grid the COG's full-resolution grid, in its CRS, with the file's
## scale and offset?
same_grid <- function(x, cog) {
  l0 <- cog$levels[[1]]
  e <- as.vector(terra::ext(x))
  tol <- 1e-6 * max(abs(terra::res(x)))
  sc <- terra::scoff(x)
  terra::ncol(x) == l0$dim[1] && terra::nrow(x) == l0$dim[2] &&
    all(abs(e - l0$extent) <= tol) &&
    isTRUE(terra::same.crs(x, cog$wkt)) &&
    all(abs(sc[, "scale"] - cog$scale) <= 1e-12 * abs(cog$scale)) &&
    all(sc[, "offset"] == cog$offset)
}

## Is x a colour image: 3 or 4 Byte layers, red, green, blue (and alpha),
## by terra::RGB() or, without it, the file's colour interpretation?
raster_is_rgb <- function(x, src = NULL) {
  nl <- terra::nlyr(x)
  if (!nl %in% 3:4) return(FALSE)
  byte <- if (!is.null(src)) identical(src$cog$levels[[1]]$encoding$dtype, "uint8") else
    is_byte(x)
  if (!byte) return(FALSE)
  if (!is.null(rgb_layers(x))) return(TRUE)
  want <- c("Red", "Green", "Blue", "Alpha")[seq_len(nl)]
  !is.null(src) && identical(unname(src$cog$color_interp[src$bands]), want)
}

## The layers terra::RGB() names, red, green, blue (and alpha), or NULL.
rgb_layers <- function(x) {
  if (!terra::has.RGB(x)) return(NULL)
  i <- as.integer(terra::RGB(x))
  if (!length(i) %in% 3:4 || anyNA(i) || anyDuplicated(i) || any(i < 1L | i > terra::nlyr(x))) {
    return(NULL)
  }
  i
}

## x's layers in red, green, blue (alpha) order: terra::RGB()'s, with the
## remaining layer of four as alpha when the file says it is; else the
## layers as they are.
rgb_order <- function(x, src = NULL) {
  i <- rgb_layers(x)
  if (is.null(i)) return(seq_len(terra::nlyr(x)))
  rest <- setdiff(seq_len(terra::nlyr(x)), i)
  if (length(i) == 3L && length(rest) == 1L && !is.null(src) &&
      identical(unname(src$cog$color_interp[src$bands[rest]]), "Alpha")) {
    i <- c(i, rest)
  }
  i
}

## Are all of x's values whole numbers from 0 to 255?
is_byte <- function(x) {
  dt <- terra::datatype(x)
  if (all(dt == "INT1U")) return(TRUE)
  if (!all(terra::inMemory(x))) return(FALSE)
  v <- terra::values(x, mat = FALSE)
  v <- v[!is.na(v)]
  length(v) > 0L && all(v >= 0 & v <= 255 & v == round(v))
}

## Write x to a temporary COG (GDAL's default LZW compression) and read its
## structure. Colour images are written pixel interleaved, as Byte when
## their values allow, with an alpha band added when cells are missing.
raster_temp_cog <- function(x, rgb) {
  f <- tempfile("view-", tmpdir = temp_cog_dir(), fileext = ".tif")
  if (rgb) {
    ## The layer carries its bands itself (scene_add_tiled_raster(rgb =)),
    ## so the file needs no colour interpretation, only pixel interleaving.
    ## (terra asks the COG driver's MEM stage for PHOTOMETRIC=RGB otherwise,
    ## with a warning.)
    if (terra::has.RGB(x)) {
      x <- terra::deepcopy(x)
      terra::RGB(x) <- NULL
    }
    if (is_byte(x)) {
      ## Byte has no spare value for NA (terra would take 255, so white
      ## would vanish): missing cells get an alpha of 0 instead.
      miss <- anyNA(x)  # terra S4 method: per cell, over layers
      if (isTRUE(terra::global(miss, "max", na.rm = TRUE)[[1]] > 0)) {
        alpha <- if (terra::nlyr(x) == 4L) x[[4]] else x[[1]] * 0 + 255
        alpha <- terra::ifel(miss, 0, alpha)
        rgb3 <- x[[1:3]]
        x <- c(terra::ifel(is.na(rgb3), 0, rgb3), alpha)
      }
      terra::writeRaster(x, f, filetype = "COG", datatype = "INT1U", NAflag = NA,
                         gdal = interleave_pixel())
    } else {
      terra::writeRaster(x, f, filetype = "COG", datatype = "FLT4S",
                         gdal = interleave_pixel())
    }
  } else {
    terra::writeRaster(x, f, filetype = "COG")
  }
  aobcore::cog_info(f)
}

## GDAL's COG driver takes INTERLEAVE from 3.11 (and there copies terra's
## band interleaved in-memory stage unless told); before, it is always pixel
## interleaved and warns about the option.
interleave_pixel <- function() {
  if (utils::compareVersion(terra::gdal(), "3.11") >= 0) "INTERLEAVE=PIXEL" else character()
}

raster_layer <- function(x, layer) {
  if (is.null(layer)) return(1L)
  nl <- terra::nlyr(x)
  if (is.character(layer) && length(layer) == 1L && !is.na(layer)) {
    i <- match(layer, names(x))
    if (is.na(i)) stop("`x` has no layer \"", layer, "\".", call. = FALSE)
    return(i)
  }
  if (!is.numeric(layer) || length(layer) != 1L || is.na(layer) || layer != round(layer) ||
      layer < 1 || layer > nl) {
    stop("`layer` must be one layer name or number from 1 to ", nl, ".", call. = FALSE)
  }
  as.integer(layer)
}

## Union of the finest planned level's tile footprints, the initial view.
plan_extent <- function(plan) {
  lv <- plan$levels[[length(plan$levels)]]
  fp <- do.call(rbind, lapply(lv$tiles, `[[`, "footprint"))
  if (is.null(fp)) return(NULL)
  as.numeric(c(min(fp[, 1]), max(fp[, 2]), min(fp[, 3]), max(fp[, 4])))
}

check_raster <- function(x) {
  check_terra_crs(x)
  if (!terra::hasValues(x)) stop("`x` has no values to view.", call. = FALSE)
}

check_terra_crs <- function(x) {
  if (!nzchar(terra::crs(x))) {
    stop("`x` has no CRS. Set one with terra::crs(x) <- \"EPSG:...\", or pass `crs` to view().",
         call. = FALSE)
  }
}

need_terra <- function() {
  if (!requireNamespace("terra", quietly = TRUE)) {
    stop("view() of terra data needs the 'terra' package.", call. = FALSE)
  }
}

need_gdalraster <- function() {
  if (!requireNamespace("gdalraster", quietly = TRUE)) {
    stop("view() of a SpatRaster needs the 'gdalraster' package (for aobcore's COG reader).",
         call. = FALSE)
  }
}
