#' The default view CRS for spatial data
#'
#' The CRS [view()] draws in when `crs` is not given. The project is polar
#' first, and a view in the data's own CRS is preferred to a reprojection,
#' so the rule is:
#'
#' 1. A **projected** CRS is kept: the data are drawn in their own CRS.
#' 2. **Lon/lat** data lying entirely south of 40S (the bounding box's
#'    northern edge at or below -40) are drawn in EPSG:3031, Antarctic Polar
#'    Stereographic. This covers Antarctica, the Southern Ocean south of the
#'    Subtropical Front, and circumpolar data such as a coastline south of
#'    40S, all of which a lon/lat view tears apart at the pole.
#' 3. Lon/lat data lying entirely north of 60N are drawn in EPSG:3413, NSIDC
#'    Sea Ice Polar Stereographic North. The northern threshold is stricter
#'    than the southern one because much mid-latitude land lies between 40N
#'    and 60N, where a polar view turns the map away from north-up; south of
#'    40S there is little land other than Antarctica.
#' 4. Other lon/lat data are drawn in their own lon/lat CRS, flat (plate
#'    carree), which the scene spec allows. Web Mercator is not used: it
#'    cannot show the poles, and a tiled Mercator basemap is a non-goal.
#'
#' For a raster the bounding box is the grid's extent, so a lon/lat grid
#' from 90S to 40S, whose northern edge is at 40S, is drawn in EPSG:3031.
#'
#' For a list of objects (see [view-layers]) the rule is applied once to
#' the whole list: the CRS of the first object with a projected CRS is kept;
#' when every object is in lon/lat, rules 2 to 4 apply to their combined
#' latitude range, and rule 4 keeps the first object's CRS.
#'
#' Data with no CRS is an error: set one first (for example
#' `sf::st_set_crs()` or `terra::crs<-`), or pass `crs` to [view()].
#'
#' @param x An `sf` or `sfc` object, a 'terra' `SpatRaster` or
#'   `SpatVector`, or a list of them.
#' @return A CRS for [aobcore::scene()]: an `"authority:code"` string such
#'   as `"EPSG:3031"`, or, when the data's CRS has no code, the `sf` `crs`
#'   object (for `sf` data) or its WKT (for 'terra' data).
#' @export
#' @examplesIf requireNamespace("sf", quietly = TRUE)
#' coast <- sf::st_read(system.file("extdata", "coastline_south_40s.geojson",
#'                                  package = "aobcore"), quiet = TRUE)
#' view_crs(coast)
#' nc <- sf::st_read(system.file("shape", "nc.shp", package = "sf"), quiet = TRUE)
#' view_crs(nc)
view_crs <- function(x) {
  UseMethod("view_crs")
}

#' @export
view_crs.default <- function(x) combined_view_crs(list(crs_facts(x)))

#' @export
view_crs.SpatRaster <- function(x) combined_view_crs(list(crs_facts(x)))

#' @export
view_crs.SpatVector <- function(x) combined_view_crs(list(crs_facts(x)))

## What the view CRS rule needs to know of one object: its own CRS (as
## view_crs() returns it), whether that is lon/lat, and the latitudes it
## spans (lon/lat only).
crs_facts <- function(x) {
  UseMethod("crs_facts")
}

#' @export
crs_facts.default <- function(x) {
  need_sf()
  crs <- sf::st_crs(x)
  if (is.na(crs)) {
    stop("`x` has no CRS. Set one with sf::st_set_crs(), or pass `crs` to view().",
         call. = FALSE)
  }
  lonlat <- isTRUE(sf::st_is_longlat(x))
  bb <- if (lonlat) sf::st_bbox(x) else NULL
  list(crs = sf_crs_code(crs), lonlat = lonlat,
       ylim = if (lonlat) c(bb[["ymin"]], bb[["ymax"]]))
}

#' @export
crs_facts.SpatRaster <- function(x) terra_crs_facts(x)

#' @export
crs_facts.SpatVector <- function(x) terra_crs_facts(x)

terra_crs_facts <- function(x) {
  need_terra()
  if (!nzchar(terra::crs(x))) {
    stop("`x` has no CRS. Set one with terra::crs(x) <- \"EPSG:...\", or pass `crs` to view().",
         call. = FALSE)
  }
  lonlat <- isTRUE(terra::is.lonlat(x))
  e <- if (lonlat) as.vector(terra::ext(x)) else NULL
  list(crs = terra_crs_code(x), lonlat = lonlat,
       ylim = if (lonlat) c(e[["ymin"]], e[["ymax"]]))
}

## The view CRS of several objects (rules 1 to 4 above): the first
## projected CRS, else the lon/lat rule on the combined latitude range, else
## the first object's own lon/lat CRS.
combined_view_crs <- function(facts) {
  for (f in facts) if (!f$lonlat) return(f$crs)
  lat <- unlist(lapply(facts, function(f) f$ylim))
  lat <- lat[is.finite(lat)]
  polar <- if (length(lat)) lonlat_view_crs(min(lat), max(lat))
  polar %||% facts[[1]]$crs
}

## The polar view for lon/lat data between latitudes ymin and ymax, or NULL
## to keep the data's own CRS (rules 2 to 4 above).
lonlat_view_crs <- function(ymin, ymax) {
  if (anyNA(c(ymin, ymax))) return(NULL)
  if (ymax <= south_limit) return("EPSG:3031")
  if (ymin >= north_limit) return("EPSG:3413")
  NULL
}

south_limit <- -40
north_limit <- 60

## An sf crs as "authority:code" when it has one (no 'gdalraster' needed
## downstream), else the crs object, which aobcore::scene_crs() resolves.
sf_crs_code <- function(crs) {
  code <- crs$srid
  if (is.character(code) && length(code) == 1L && !is.na(code) &&
      grepl("^[A-Za-z][A-Za-z0-9_]*:[A-Za-z0-9_.-]+$", code)) {
    return(code)
  }
  crs
}

## A terra object's CRS as "authority:code" when it has one, else its WKT.
terra_crs_code <- function(x) {
  d <- terra::crs(x, describe = TRUE)
  auth <- d$authority[1]
  code <- d$code[1]
  if (!is.na(auth) && !is.na(code) && nzchar(auth) && nzchar(code)) {
    return(paste0(auth, ":", code))
  }
  terra::crs(x)
}
