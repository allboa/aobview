## ---- a VRT or GTI mosaic of COGs, planned across its members ---------------
## (allboa/aobview#41, allboa/design decisions 0010 and 0011)
##
## A VRT or GDAL Tile Index whose members are COGs is not read into a
## temporary COG: aobcore::mosaic_members() lists its members without
## opening any, aobcore::mosaic_plan() probes those the view touches and
## plans each as the COG it is, and the view gets one tiled_raster layer
## per member, each referenced by the member's own file or URL, nothing
## copied. R downloads nothing it could plan instead (decision 0010). When
## a member the view touches cannot be drawn in place (it is not a COG, the
## VRT stretches, windows or rescales it, or it is in another CRS) the
## routes that read the dataset through GDAL take over, with a message that
## names the member.

## When SpatRaster x is read unchanged from one VRT or GTI (the conditions
## of raster_gdal_source()), its mosaic: list(dsn, bands, cog (the
## dataset's facts, in the shape raster_is_rgb() and rgb_order() read),
## mosaic), else NULL.
raster_mosaic_source <- function(x) {
  if (any(terra::inMemory(x))) return(NULL)
  src <- terra::sources(x, bands = TRUE)
  if (!nrow(src) || length(unique(src$sid)) != 1L || !nzchar(src$source[1])) return(NULL)
  dsn <- sub("^file://", "", src$source[1])
  bands <- as.integer(src$bands)
  info <- tryCatch(gdal_facts(dsn, bands), error = function(e) NULL)
  if (is.null(info) || !same_grid(x, info) || !same_nodata(x, info)) return(NULL)
  mosaic <- source_mosaic(dsn)
  if (is.null(mosaic)) return(NULL)
  list(dsn = dsn, bands = bands, cog = info, mosaic = mosaic)
}

## The mosaic dsn names, or NULL when it is not a VRT or GTI (or cannot be
## read as one: GDAL says why when it is then read the usual way).
source_mosaic <- function(dsn) {
  tryCatch(aobcore::mosaic_members(dsn), error = function(e) NULL)
}

## Plan mosaic `mosaic` across its members for view v and add one tiled
## raster layer per member, named `name` for one member and `<name>_<i>`
## for several (labelled with the member's base name). `bands` is FALSE
## for one band (`band`) through the palette, or the mosaic's bands of a
## colour image in red, green, blue (alpha) order. Returns NULL, after a
## message naming the member, when a member the view touches cannot be
## drawn in place, or no member meets `extent`: the caller then reads the
## dataset through GDAL as before. `...` goes to aobcore::cog_plan() for
## each member.
add_mosaic_layers <- function(v, mosaic, name, ..., band = 1L, bands = FALSE, palette = NULL,
                              range = NULL, legend = TRUE) {
  kind <- toupper(mosaic$kind)
  fallback <- function(...) {
    message("\"", name, "\" is a ", kind, " ", ..., ", so it is not planned across its ",
            "members; it is read through GDAL into a temporary COG instead.")
    NULL
  }
  crs <- v$scene$view$crs
  colour <- !isFALSE(bands)
  mp <- aobcore::mosaic_plan(mosaic, crs, band = if (colour) bands[1] else band, ...)
  bad <- mp$members[mp$members$status == "unplanned", , drop = FALSE]
  if (nrow(bad)) {
    return(fallback("whose member \"", member_label(bad$dsn[1]), "\" ", bad$reason[1],
                    if (nrow(bad) > 1L) paste0(" (and ", nrow(bad) - 1L, " more)")))
  }
  if (!length(mp$plans)) return(fallback("none of whose members meets `extent`"))
  if (colour) {
    for (dsn in names(mp$plans)) {
      why <- mosaic_rgb_ok(mp$plans[[dsn]]$cog, bands, mosaic, dsn)
      if (!is.null(why)) return(fallback("whose member \"", member_label(dsn), "\" ", why))
    }
  }
  n <- length(mp$plans)
  base <- layer_id(name)
  for (i in seq_len(n)) {
    dsn <- names(mp$plans)[i]
    v <- add_cog_layer(v, mp$plans[[i]], name, palette = palette, range = range,
                       rgb = if (colour) bands else FALSE, legend = legend,
                       id = if (n == 1L) base else paste0(base, "_", i),
                       label = if (n == 1L) name else paste0(name, ": ", member_label(dsn)),
                       key = i == 1L, only = n > 1L)
    ## One range across the members, so their colours agree: the first
    ## member's (its coarsest level's values, as for one COG) when none
    ## was given.
    if (is.null(range)) {
      last <- v$scene$layers[[length(v$scene$layers)]]
      range <- last$palette$range %||% last$rgb$range
    }
  }
  v
}

## Why member COG `cog` cannot draw a colour image of the mosaic's `bands`
## (red, green, blue, alpha), or NULL: it needs those bands, pixel
## interleaved, and (for a VRT) its band b must feed mosaic band b.
mosaic_rgb_ok <- function(cog, bands, mosaic, dsn) {
  if (cog$samples_per_pixel < max(bands)) {
    return(paste0("has ", cog$samples_per_pixel, " band", if (cog$samples_per_pixel != 1L) "s",
                  ", fewer than a colour image of bands ", paste(bands, collapse = ", "), " needs"))
  }
  if (!identical(cog$planar, "interleaved")) {
    return("stores its bands separately (INTERLEAVE=BAND); a colour image needs pixel interleaved bands")
  }
  m <- mosaic$members[mosaic$members$dsn == dsn & !is.na(mosaic$members$band), , drop = FALSE]
  for (b in bands) {
    sb <- m$source_band[m$band == b]
    if (length(sb) && !all(sb == b)) {
      return(paste0("feeds band ", b, " from its band ", sb[1], "; a colour image needs each ",
                    "band from the member's band of the same number"))
    }
  }
  NULL
}

## A member in a message or label: its base name (a URL's last segment).
member_label <- function(dsn) {
  nm <- basename(sub("[?#].*$", "", dsn))
  if (nzchar(nm)) nm else dsn
}
