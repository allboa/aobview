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
#' Data with no CRS is an error: set one first (for example
#' `sf::st_set_crs()`), or pass `crs` to [view()].
#'
#' @param x An `sf` or `sfc` object.
#' @return A CRS for [aobcore::scene()]: an `"authority:code"` string such
#'   as `"EPSG:3031"`, or the data's own `sf` `crs` object when it has no
#'   code.
#' @export
#' @examplesIf requireNamespace("sf", quietly = TRUE)
#' coast <- sf::read_sf(system.file("extdata", "coastline_south_40s.geojson",
#'                                  package = "aobcore"))
#' view_crs(coast)
#' nc <- sf::read_sf(system.file("shape", "nc.shp", package = "sf"))
#' view_crs(nc)
view_crs <- function(x) {
  need_sf()
  crs <- sf::st_crs(x)
  if (is.na(crs)) {
    stop("`x` has no CRS. Set one with sf::st_set_crs(), or pass `crs` to view().",
         call. = FALSE)
  }
  if (!isTRUE(sf::st_is_longlat(x))) return(sf_crs_code(crs))
  bb <- sf::st_bbox(x)
  if (anyNA(bb)) return(sf_crs_code(crs))
  if (bb[["ymax"]] <= south_limit) return("EPSG:3031")
  if (bb[["ymin"]] >= north_limit) return("EPSG:3413")
  sf_crs_code(crs)
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
