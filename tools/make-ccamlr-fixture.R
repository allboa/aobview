# Regenerate inst/extdata/ccamlr_statistical_areas.geojson, a small
# simplified copy of the CCAMLR statistical areas used in examples and tests.
#
#   Rscript tools/make-ccamlr-fixture.R [source]
#
# Source: CCAMLR statistical areas (Areas 48, 58 and 88; 19 polygons) as
# GeoParquet in EPSG:6932 (WGS 84 / NSIDC EASE-Grid 2.0 South), from CCAMLR
# GIS (https://gis.ccamlr.org). The copy used was uploaded by Michael Sumner
# on 2026-10-01 to the project files, at the default path below (a file with
# no extension); reading it needs GDAL's Parquet driver.
#
# Made 2026-10-01: each polygon simplified on its own with
# sf::st_simplify(preserveTopology = TRUE, dTolerance = 2000) (2 km), so the
# shared edges of neighbouring areas no longer match exactly; only the popup
# columns kept; written as GeoJSON in its own CRS (EPSG:6932, which GDAL
# writes as a "crs" member, RFC7946=NO) with coordinates rounded to the
# metre. GeoJSON needs no optional GDAL driver, so every sf, terra and
# gdalraster build reads it, and its CRS is not lon/lat, which tests want.
library(sf)

src <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(src)) src <- "/mnt/project-files/uploads/hearth/6e8bcd31-8753-4399-8e11-1ab400190a6a"
tolerance <- 2000 # metres, in EPSG:6932
out <- "inst/extdata/ccamlr_statistical_areas.geojson"

x <- st_read(src, quiet = TRUE)
stopifnot(nrow(x) == 19L, identical(st_crs(x)$epsg, 6932L))
y <- st_simplify(x, preserveTopology = TRUE, dTolerance = tolerance)
y <- y[, c("GAR_ID", "GAR_Name", "GAR_Short_Label", "GAR_Long_Label", "GAR_Start_Date",
           "GAR_Size")]
stopifnot(all(st_is_valid(y)))

unlink(out)
st_write(y, out, layer = "ccamlr_statistical_areas", driver = "GeoJSON", quiet = TRUE,
         layer_options = c("COORDINATE_PRECISION=0", "RFC7946=NO", "WRITE_BBOX=NO"))
z <- st_read(out, quiet = TRUE)
stopifnot(nrow(z) == 19L, identical(st_crs(z)$epsg, 6932L), all(st_is_valid(z)))
nv <- sum(vapply(st_geometry(z), function(g) nrow(st_coordinates(g)), 0L))
cat(out, ":", nrow(z), "polygons,", nv, "vertices,", file.size(out), "bytes\n")
