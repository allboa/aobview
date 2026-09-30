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

# terra, all in EPSG:3031 (the default for lon/lat data south of 40S and
# for a raster already in 3031).
if (requireNamespace("terra", quietly = TRUE)) {
  # A computed lon/lat field over the South Pole, 1 degree, 90S to 40S: in
  # memory, so written to a temporary COG whose tiles are embedded.
  field <- terra::rast(ncols = 360, nrows = 50, xmin = -180, xmax = 180, ymin = -90, ymax = -40,
                       crs = "OGC:CRS84")
  xy <- terra::xyFromCell(field, seq_len(terra::ncell(field)))
  terra::values(field) <- cos(xy[, 2] * pi / 25) + 0.5 * sin(xy[, 1] * pi / 30)
  view(field, palette = "ocean", file = file.path(out, "terra-lonlat-field-in-3031.html"))

  # A SpatRaster read from a local COG in EPSG:3031: that COG, embedded.
  sst <- terra::rast(system.file("extdata", "polar_3031.tif", package = "aobcore"))
  view(sst, file = file.path(out, "terra-cog-file-in-3031.html"))

  # A 3-band Byte RGB SpatRaster in memory, with a hole of missing cells,
  # drawn as a colour image (the hole transparent).
  img <- terra::rast(nrows = 200, ncols = 200, nlyrs = 3, xmin = -3e6, xmax = 3e6,
                     ymin = -3e6, ymax = 3e6, crs = "EPSG:3031")
  xy <- terra::xyFromCell(img, seq_len(terra::ncell(img)))
  r <- round(255 * (xy[, 1] + 3e6) / 6e6)
  g <- round(255 * (xy[, 2] + 3e6) / 6e6)
  b <- ifelse(sqrt(rowSums(xy^2)) < 1.5e6, 255, 60)
  hole <- sqrt((xy[, 1] - 1.5e6)^2 + (xy[, 2] - 1.5e6)^2) < 6e5
  r[hole] <- NA
  terra::values(img) <- cbind(r, g, b)
  terra::RGB(img) <- 1:3
  view(img, file = file.path(out, "terra-rgb-in-3031.html"))

  # A SpatVector read by terra: the lon/lat coastline south of 40S.
  coastline <- terra::vect(system.file("extdata", "coastline_south_40s.geojson", package = "aobcore"))
  view(coastline, file = file.path(out, "terra-vector-in-3031.html"))
}
