# Write example view() pages for headless screenshots.
#
#   Rscript tools/write-views.R <outdir>
#
# Polar first: lon/lat polygons, lines and points viewed in EPSG:3031 (the
# default for lon/lat data south of 40S), then the same in a view CRS given
# by the caller, and lon/lat data away from the poles in its own CRS.
library(aobview)
library(sf)

out <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(out)) stop("usage: Rscript tools/write-views.R <outdir>")
dir.create(out, showWarnings = FALSE, recursive = TRUE)

# Lon/lat polygons: 30-degree sectors from 65S to 50S, whose parallels must
# curve, and a cap over the pole from 78S, which crosses the antimeridian.
# The cap's lon/lat ring runs up the 180 meridian to the pole and back, so
# its outline shows that edge as a line from the pole: the ring's topology,
# not a drawing error (design post, "topology depends on purpose").
sector <- function(lon0, lon1, lat0, lat1) {
  lon <- c(seq(lon0, lon1, length.out = 7), seq(lon1, lon0, length.out = 7))
  lat <- c(rep(lat0, 7), rep(lat1, 7))
  st_polygon(list(cbind(c(lon, lon0), c(lat, lat0))))
}
sectors <- st_sf(
  name = paste("sector", 1:6),
  geometry = st_sfc(lapply(seq(-165, 135, by = 60), function(l) sector(l, l + 30, -65, -50)),
                    crs = "OGC:CRS84")
)
cap <- st_sf(name = "cap", geometry = st_sfc(sector(-180, 180, -90, -78), crs = "OGC:CRS84"))
polys <- rbind(sectors, cap)

coast <- st_read(system.file("extdata", "coastline_south_40s.geojson", package = "aobcore"), quiet = TRUE)
stations <- st_sf(
  name = c("Casey", "Davis", "Mawson", "McMurdo", "Rothera", "South Pole"),
  geometry = st_sfc(lapply(list(c(110.53, -66.28), c(77.97, -68.58), c(62.87, -67.6),
                                c(166.67, -77.85), c(-68.13, -67.57), c(0, -90)), st_point),
                    crs = "OGC:CRS84")
)
mixed <- st_sf(geometry = c(st_geometry(polys), st_geometry(coast), st_geometry(stations)))

view(polys, file = file.path(out, "polygons-lonlat-in-3031.html"))
view(mixed, file = file.path(out, "mixed-lonlat-in-3031.html"))
view(mixed, crs = "+proj=laea +lat_0=-90 +lon_0=140 +datum=WGS84",
     file = file.path(out, "mixed-lonlat-in-laea.html"))
nc <- st_read(system.file("shape", "nc.shp", package = "sf"), quiet = TRUE)
view(nc, file = file.path(out, "nc-own-crs.html"))
