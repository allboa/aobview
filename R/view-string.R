## ---- a string: WKT text, or a path, URL or data source name ----------------
## (allboa/aobview#39, allboa/design decision 0011)
##
## A single string is WKT text or the name of a data source, by the rule in
## ?view (Strings): a string that names a file that exists, or starts with a
## URL scheme or /vsi, is a data source; any other string wk parses as WKT
## is geometry; a string that is neither is probed as a data source. A data
## source is probed with gdalraster, in this order: a COG (tiled, with
## overviews: aobcore::cog_info()) is planned as a SpatRaster read from one
## is (view-terra.R), a remote one by URL; another raster is read through
## GDAL into a temporary COG (view-gdal.R); a vector source is read with
## aobcore::gdal_vector_stream(), which reprojects and densifies in GDAL,
## and drawn as any vector input is (view.R). The probe gives an
## `aob_source` (kind, dsn, the structure read, the band or layer), which
## add_source() draws; WKT text gives a wk::wkt().

#' @rdname view
#' @export
view.character <- function(x, ..., layer = NULL, crs = NULL, name = NULL, file = NULL,
                           theme = c("auto", "light", "dark"),
                           transport = getOption("aobview.transport", "auto")) {
  theme <- match.arg(theme)
  transport <- check_transport(transport)
  name <- name %||% string_name(x, substitute(x), layer)
  src <- string_input(x, layer)
  if (!inherits(src, "aob_source")) {
    return(view_vector(src, NULL, name, crs = crs, ..., file = file, theme = theme,
                       transport = transport))
  }
  v <- new_view(crs %||% combined_view_crs(list(source_crs_facts(src))), transport)
  on.exit(drop_pending(v), add = TRUE)
  v <- add_source(src, v, name, ...)
  finish_view(v, name, file, theme)
}

#' @export
add_layers.character <- function(x, v, name, ..., layer = NULL) {
  src <- string_input(x, layer)
  if (!inherits(src, "aob_source")) {
    return(add_record(vector_record(src), v, name, ..., source = src))
  }
  add_source(src, v, name, ...)
}

#' @export
crs_facts.character <- function(x) {
  src <- string_input(x)
  if (!inherits(src, "aob_source")) return(record_crs_facts(vector_record(src)))
  source_crs_facts(src)
}

## ---- internals -------------------------------------------------------------

is_string <- function(x) is.character(x) && length(x) == 1L && !is.na(x)

## A string as the geometry or the data source it names: a wk::wkt() (with
## its SRID as CRS when the text has one) or an aob_source (probe_source()).
string_input <- function(x, layer = NULL) {
  if (!is_string(x) || !nzchar(trimws(x))) {
    stop("view() takes one string: WKT text, or a path, URL or GDAL data source name. ",
         "For several WKT strings, use wk::wkt(x, crs = ).", call. = FALSE)
  }
  if (!looks_like_source(x)) {
    g <- wkt_text(x)
    if (!is.null(g)) {
      if (!is.null(layer)) {
        stop("`layer` picks a band or layer of a data source; `x` is WKT text.",
             call. = FALSE)
      }
      if (is.null(wk::wk_crs(g))) {
        stop("`x` is WKT text with no CRS. Give it one as an SRID prefix ",
             "(\"SRID=4326;POINT (0 -70)\") or as wk::wkt(x, crs = ).", call. = FALSE)
      }
      return(g)
    }
  }
  probe_source(x, layer)
}

## Does the string name a data source, before any probe: a file or
## directory that exists, a URL (any scheme), or a GDAL /vsi path?
looks_like_source <- function(x) {
  file.exists(x) || grepl("^[A-Za-z][A-Za-z0-9+.-]*://", x) || startsWith(x, "/vsi")
}

## The string as wk::wkt() when wk parses it, else NULL. An EWKT prefix
## ("SRID=4326;POINT (0 -70)") gives the geometry its CRS; plain WKT has
## none.
wkt_text <- function(x) {
  g <- tryCatch(wk::wkt(x), error = function(e) NULL)
  if (is.null(g)) return(NULL)
  srid <- wk::wk_meta(g)$srid
  if (!is.na(srid)) g <- wk::wk_set_crs(g, paste0("EPSG:", srid))
  g
}

## The default layer name for a string: the expression when `x` was a
## variable; for a literal, the layer picked by name, else the source's
## base name without its extension, else the WKT text.
string_name <- function(x, expr, layer = NULL) {
  if (!is.character(expr)) return(deparse_name(expr))
  if (is_string(layer)) return(short_name(layer))
  if (!looks_like_source(x) && !is.null(wkt_text(x))) return(short_name(x))
  nm <- sub("[.][A-Za-z0-9]+$", "", basename(x))
  short_name(if (nzchar(nm)) nm else x)
}

short_name <- function(nm) if (nchar(nm) > 60L) paste0(substr(nm, 1L, 57L), "...") else nm

## Probe `dsn` with gdalraster: a COG (kind "cog", with its cog_info()),
## another raster (kind "raster", with its gdal_facts()), or a vector
## source (kind "vector", with the layer's name, CRS and bounds). GDAL's
## own messages are quiet while the kinds it cannot open are tried.
probe_source <- function(dsn, layer = NULL) {
  need_gdalraster_source(dsn)
  gdalraster::push_error_handler("quiet")
  on.exit(gdalraster::pop_error_handler(), add = TRUE)
  ## cog_info() reads a URL through /vsicurl/ itself; GDAL's other readers
  ## are given that form.
  gdal <- if (grepl("^https?://", dsn)) paste0("/vsicurl/", dsn) else dsn
  cog <- tryCatch(aobcore::cog_info(dsn), error = function(e) NULL)
  if (!is.null(cog) && cog_ready(cog)) return(new_source("cog", dsn, gdal, cog, layer))
  info <- tryCatch(gdal_facts(gdal, 1L), error = function(e) NULL)
  if (!is.null(info)) return(new_source("raster", dsn, gdal, info, layer))
  if (isTRUE(gdalraster::ogr_ds_exists(dsn))) return(vector_source(dsn, layer))
  stop("GDAL cannot open \"", dsn, "\" as a raster or a vector data source",
       if (!looks_like_source(dsn)) ", and wk cannot read it as WKT", ".", call. = FALSE)
}

new_source <- function(kind, dsn, gdal, info, layer) {
  structure(list(kind = kind, dsn = dsn, gdal = gdal, info = info, layer = layer),
            class = "aob_source")
}

## A vector source's layer (by name; `layer` may be its number, the first
## by default), with its CRS as GDAL's WKT and, for lon/lat, its bounds.
vector_source <- function(dsn, layer) {
  names <- gdalraster::ogr_ds_layer_names(dsn)
  if (!length(names)) stop("\"", dsn, "\" has no vector layers.", call. = FALSE)
  n <- length(names)
  if (is.null(layer)) {
    layer <- names[1]
  } else if (is.numeric(layer) && length(layer) == 1L && !is.na(layer) &&
             layer == round(layer) && layer >= 1 && layer <= n) {
    layer <- names[layer]
  } else if (!is_string(layer) || !layer %in% names) {
    stop("`layer` must name one layer of \"", dsn, "\": ",
         paste0("\"", utils::head(names, 10L), "\"", collapse = ", "),
         if (n > 10L) paste0(" and ", n - 10L, " more"), ".", call. = FALSE)
  }
  lyr <- gdalraster::GDALVector$new(dsn, layer)
  on.exit(lyr$close(), add = TRUE)
  def <- lyr$getSpatialRef()
  if (!nzchar(def)) {
    stop("Layer \"", layer, "\" of \"", dsn, "\" has no CRS, so it cannot be drawn.",
         call. = FALSE)
  }
  lonlat <- crs_is_lonlat(def)
  ## The bounds (xmin, ymin, xmax, ymax) only when the lon/lat rule needs
  ## them: GDAL may scan the layer for them.
  info <- list(wkt = def, lonlat = lonlat, bbox = if (lonlat) lyr$bbox())
  new_source("vector", dsn, dsn, info, layer)
}

## crs_facts() of a data source: its CRS (GDAL's WKT, read by PROJ as any
## other), whether that is lon/lat, and the latitudes it spans.
source_crs_facts <- function(src) {
  def <- src$info$wkt
  if (!is_string(def) || !nzchar(def)) {
    stop("\"", src$dsn, "\" has no CRS, so it cannot be drawn.", call. = FALSE)
  }
  lonlat <- src$info$lonlat %||% crs_is_lonlat(def)
  ylim <- if (lonlat) {
    if (src$kind == "vector") src$info$bbox[c(2, 4)] else src$info$levels[[1]]$extent[3:4]
  }
  list(crs = crs_code(def) %||% view_crs_definition(def), lonlat = lonlat, ylim = ylim)
}

## Append the layers of data source src to view v (add_layers() for a
## string).
add_source <- function(src, v, name, ...) {
  if (src$kind == "vector") {
    add_source_vector(src, v, name, ...)
  } else {
    add_source_raster(src, v, name, ...)
  }
}

## A vector source through aobcore::gdal_vector_stream(): GDAL densifies
## (in source units, before it reprojects) by the rule of to_view_crs(),
## lon/lat edges every 0.25 degrees by default when the view CRS differs,
## and reprojects to the view CRS. The stream arrives as a data frame
## whose geometry is already in that CRS, and is drawn as any data frame
## is.
add_source_vector <- function(src, v, name, ..., densify = NULL) {
  crs <- v$scene$view$crs
  step <- if (same_crs(src$info$wkt, crs)) 0 else densify_step(densify, src$info$lonlat)
  stream <- aobcore::gdal_vector_stream(src$dsn, crs, layer = src$layer,
                                        densify = if (step > 0) step)
  df <- as.data.frame(stream)
  df$geometry <- wk::wk_set_crs(wk::as_wkb(df$geometry), crs)
  add_record(vector_record(df, "geometry"), v, name, ..., densify = FALSE, source = df)
}

## A raster source as a tiled COG layer: the COG itself, or a temporary COG
## GDAL reads the dataset into (gdal_temp_cog(), whatever its size). `...`
## goes to aobcore::cog_plan(), as for a SpatRaster.
add_source_raster <- function(src, v, name, ..., rgb = NULL, palette = NULL, range = NULL,
                              legend = TRUE) {
  check_flag(legend, "legend")
  check_raster_style(rgb, palette)
  info <- src$info
  nb <- length(info$color_interp)
  if (isTRUE(rgb) && !nb %in% 3:4) {
    stop("`rgb = TRUE` needs 3 or 4 bands; \"", src$dsn, "\" has ", nb, ".", call. = FALSE)
  }
  colour <- if (!is.null(rgb)) rgb else {
    is.null(src$layer) && is.null(palette) && source_is_rgb(info)
  }
  crs <- v$scene$view$crs
  temp <- NULL
  if (colour) {
    ## Bands red, green, blue (alpha), as the file orders them.
    bands <- seq_len(nb)
    if (src$kind == "cog" && identical(info$planar, "interleaved")) {
      cog <- info
    } else {
      gs <- gdal_source(source_facts(src), bands, crs, list(...), whole = TRUE)
      cog <- temp <- gdal_temp_cog(gs, bands, rgb = TRUE, name = name)
      bands <- seq_len(cog$samples_per_pixel)
    }
  } else {
    band <- source_band(src$layer, nb)
    cog <- if (src$kind == "cog") {
      if (band == info$band) info else aobcore::cog_info(src$dsn, band = band)
    } else {
      gs <- gdal_source(info, band, crs, list(...), whole = TRUE)
      temp <- gdal_temp_cog(gs, band, rgb = FALSE, name = name)
    }
  }
  add_cog_layer(v, cog, name, ..., palette = palette, range = range,
                rgb = if (colour) bands else FALSE, legend = legend, temp = temp)
}

## The dataset's facts in the shape gdal_source() reads (gdal_facts()).
source_facts <- function(src) {
  if (src$kind == "raster") src$info else gdal_facts(src$gdal, 1L)
}

## The band a raster source draws: `layer` as a band number, 1 by default.
source_band <- function(layer, nb) {
  if (is.null(layer)) return(1L)
  if (!is.numeric(layer) || length(layer) != 1L || is.na(layer) || layer != round(layer) ||
      layer < 1 || layer > nb) {
    stop("`layer` must be a band number from 1 to ", nb, " for a raster.", call. = FALSE)
  }
  as.integer(layer)
}

## Is the dataset a colour image: 3 or 4 Byte bands whose colour
## interpretation is Red, Green, Blue (and Alpha)?
source_is_rgb <- function(info) {
  nb <- length(info$color_interp)
  nb %in% 3:4 && identical(info$levels[[1]]$encoding$dtype, "uint8") &&
    identical(unname(info$color_interp), c("Red", "Green", "Blue", "Alpha")[seq_len(nb)])
}

need_gdalraster_source <- function(dsn) {
  if (!has_gdalraster()) {
    stop("view() of a path, URL or data source name (here \"", crs_short(dsn), "\") reads ",
         "it with the 'gdalraster' package, which is not installed: ",
         "install.packages(\"gdalraster\"). WKT text needs no package.", call. = FALSE)
  }
}
