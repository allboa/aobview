#' View a terra raster or vector
#'
#' `view()` of a 'terra' `SpatRaster` draws it as a tiled Cloud Optimized
#' GeoTIFF (COG) through 'aobcore': [aobcore::cog_info()] reads the COG's
#' structure, [aobcore::cog_plan()] plans its tiles with a mesh already
#' projected to the view CRS, and [aobcore::scene_add_tiled_raster()] adds
#' them to the scene. The raster is never resampled in R; reprojection
#' happens in the mesh.
#'
#' **Which COG.** When `x` is read unchanged from one tiled GeoTIFF (a COG),
#' local or remote (an `http(s)` URL or a `/vsicurl/` path), that file is
#' used. A remote COG is referenced by URL and the browser fetches its tiles
#' by HTTP range requests (the server must allow them, and CORS): the page
#' carries the recipe, not the data. A local COG's planned tiles are
#' embedded in the page. Anything else (a raster in memory, a file that is
#' not tiled, several sources, or a computed, cropped or windowed raster) is
#' written to a temporary COG with `terra::writeRaster(filetype = "COG")`,
#' whose planned tiles are embedded, so the page opens from disk with no
#' server.
#'
#' **Colour or palette.** A raster of 3 or 4 layers with values 0 to 255
#' (Byte) and colour interpretation red, green, blue (and alpha), from the
#' file or set with `terra::RGB()`, is drawn as a colour image. Otherwise
#' one layer (`layer`, the first by default) is drawn through a palette over
#' the range of its values.
#'
#' A `SpatVector` is converted with [sf::st_as_sf()] and drawn as `sf` data
#' is (see [view()]); it needs the 'sf' package.
#'
#' @inheritParams view
#' @param x A 'terra' `SpatRaster` or `SpatVector`.
#' @param ... For a `SpatRaster`, passed to [aobcore::cog_plan()]
#'   (`max_tiles`, `max_stretch`, `tolerance`, ...).
#' @param layer The layer to draw through the palette (a number or name).
#'   Giving it draws that layer even when `x` is a colour image.
#' @param rgb `NULL` (colour when `x` is a Byte red, green, blue raster and
#'   neither `layer` nor `palette` is given), `TRUE` to draw layers 1 to 3
#'   (and 4 as alpha) as a colour image, or `FALSE` for the palette.
#' @param palette A palette name the renderer knows: `"viridis"` (the
#'   default), `"ocean"`, `"ice"` or `"gray"`.
#' @param range `c(low, high)`: the values at the ends of the palette. By
#'   default the range of the COG's coarsest level. For a colour image of a
#'   type other than Byte, the values drawn as zero and full intensity.
#' @return A view, as for [view()].
#' @seealso [view_crs()] for the default view CRS.
#' @name view-terra
#' @examplesIf requireNamespace("terra", quietly = TRUE) && requireNamespace("gdalraster", quietly = TRUE)
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
                            range = NULL, name = NULL, file = NULL,
                            theme = c("auto", "light", "dark")) {
  need_terra()
  need_gdalraster()
  name <- name %||% deparse_name(substitute(x))
  theme <- match.arg(theme)
  if (!nzchar(terra::crs(x))) {
    stop("`x` has no CRS. Set one with terra::crs(x) <- \"EPSG:...\", or pass `crs` to view().",
         call. = FALSE)
  }
  if (!terra::hasValues(x)) stop("`x` has no values to view.", call. = FALSE)
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
  if (colour) {
    bands <- seq_len(terra::nlyr(x))
    if (!is.null(src) && identical(src$cog$planar, "interleaved")) {
      cog <- src$cog
      bands <- src$bands
    } else {
      ## In terra::RGB()'s order: red, green, blue (and alpha).
      if (terra::has.RGB(x) && setequal(terra::RGB(x), bands)) x <- x[[terra::RGB(x)]]
      cog <- raster_temp_cog(x, rgb = TRUE)
      bands <- seq_len(cog$samples_per_pixel)
    }
  } else {
    i <- raster_layer(x, layer)
    cog <- if (is.null(src)) {
      raster_temp_cog(x[[i]], rgb = FALSE)
    } else if (src$bands[i] == src$cog$band) {
      src$cog
    } else {
      aobcore::cog_info(src$dsn, band = src$bands[i])
    }
  }

  view <- aobcore::scene_crs(if (is.null(crs)) view_crs(x) else crs)
  plan <- aobcore::cog_plan(cog, view, ...)
  s <- aobcore::scene(view)
  s <- aobcore::scene_add_tiled_raster(s, layer_id(name), plan,
                                       palette = palette %||% "viridis", range = range,
                                       rgb = if (colour) bands else FALSE, label = name)
  extent <- plan_extent(s$layers[[length(s$layers)]]$plan)
  if (!is.null(extent)) s$view$extent <- extent
  write_view(s, name, file, theme)
}

#' @rdname view-terra
#' @export
view.SpatVector <- function(x, ..., crs = NULL, densify = NULL, fill = NULL, stroke = NULL,
                            stroke_width_px = NULL, radius_px = NULL, name = NULL,
                            file = NULL, theme = c("auto", "light", "dark")) {
  need_terra()
  need_sf()
  name <- name %||% deparse_name(substitute(x))
  if (!nzchar(terra::crs(x))) {
    stop("`x` has no CRS. Set one with terra::crs(x) <- \"EPSG:...\", or pass `crs` to view().",
         call. = FALSE)
  }
  view_sfc(sf::st_geometry(sf::st_as_sf(x)), crs = crs, densify = densify,
           style = list(fill = fill, stroke = stroke, stroke_width_px = stroke_width_px,
                        radius_px = radius_px),
           name = name, file = file, theme = match.arg(theme))
}

## ---- internals -------------------------------------------------------------

## The COG `x` is read from, unchanged, as list(dsn, bands, cog), or NULL.
## `x` qualifies when all its layers come from one file GDAL gives tile
## offsets for, and its grid, CRS and scaling are the file's: a cropped,
## windowed or rescaled raster, or one with values in memory, does not.
raster_cog_source <- function(x) {
  if (any(terra::inMemory(x))) return(NULL)
  src <- terra::sources(x, bands = TRUE)
  if (!nrow(src) || length(unique(src$sid)) != 1L || !nzchar(src$source[1])) return(NULL)
  dsn <- raster_dsn(src$source[1])
  cog <- tryCatch(aobcore::cog_info(dsn, band = src$bands[1]), error = function(e) NULL)
  if (is.null(cog) || !same_grid(x, cog)) return(NULL)
  list(dsn = dsn, bands = as.integer(src$bands), cog = cog)
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
## by the file's colour interpretation or terra::RGB()?
raster_is_rgb <- function(x, src = NULL) {
  nl <- terra::nlyr(x)
  if (!nl %in% 3:4) return(FALSE)
  want <- c("Red", "Green", "Blue", "Alpha")[seq_len(nl)]
  if (!is.null(src)) {
    return(identical(unname(src$cog$color_interp[src$bands]), want) &&
             identical(src$cog$levels[[1]]$encoding$dtype, "uint8"))
  }
  if (!terra::has.RGB(x) || !setequal(terra::RGB(x), seq_len(nl))) return(FALSE)
  is_byte(x)
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
  f <- tempfile("view-", fileext = ".tif")
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
                         gdal = "INTERLEAVE=PIXEL")
    } else {
      terra::writeRaster(x, f, filetype = "COG", datatype = "FLT4S",
                         gdal = "INTERLEAVE=PIXEL")
    }
  } else {
    terra::writeRaster(x, f, filetype = "COG")
  }
  aobcore::cog_info(f)
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
