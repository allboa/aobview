# Get started

aobview is in early development. This page shows what works today; the
[home page](https://allboa.github.io/aobview/index.md) lists what is
still being worked out.

## Install

aobview and its core package, aobcore, are installed from GitHub:

``` r

# install.packages("remotes")
remotes::install_github("allboa/aobview")
```

Vector data can be any geometry wk can read (sf, wkb, wkt, xy, geos, …)
or a data frame with such a column; PROJ reprojects it. terra and
gdalraster are needed for rasters.

## A first view

[`view()`](https://allboa.github.io/aobview/reference/view.md) takes
vector data (here an sf object) and draws it in a page. aobcore ships a
coastline south of 40S in longitude and latitude; aobview sees that it
lies entirely in the far south and draws it in Antarctic Polar
Stereographic (EPSG:3031), densifying edges first so that parallels
curve.

``` r

library(aobview)
coast <- sf::st_read(
  system.file("extdata", "coastline_south_40s.geojson", package = "aobcore"),
  quiet = TRUE
)
v <- view(coast)
```

In an interactive session, printing the view opens the page in the IDE’s
viewer or the browser. `v$file` is the page and `v$scene` the scene it
draws. The page needs no server, and no network unless it references a
remote COG.

## Colour, legends and popups

`zcol` colours features by an attribute and adds a legend; clicking or
tapping a feature shows its attributes. Here are the CCAMLR statistical
areas (a small, simplified copy shipped with aobview, in EPSG:6932),
coloured by area and drawn in EPSG:3031 with the coastline on top.

``` r

areas <- sf::st_read(
  system.file("extdata", "ccamlr_statistical_areas.geojson", package = "aobview"),
  quiet = TRUE
)
areas$area <- paste0("Area ", substr(areas$GAR_Long_Label, 1, 2))
v <- view(areas, crs = "EPSG:3031", zcol = "area",
          popup = c("GAR_Name", "GAR_Long_Label", "GAR_Start_Date", "GAR_Size")) |>
  view_add(coast, popup = FALSE)
```

Numeric columns take a continuous palette, or classes with `breaks =`;
`palette` is any `grDevices` palette name.

``` r

v <- view(areas, zcol = "GAR_Size", palette = "Viridis")
```

That view is in the data’s own CRS, EPSG:6932, because a projected CRS
is kept as it is.

## Any CRS

`crs =` draws the same data in any projected CRS, given as an authority
code, a PROJ string or WKT. A Lambert azimuthal equal-area view centred
on the pole, with 140E at the top:

``` r

v <- view(coast, crs = "+proj=laea +lat_0=-90 +lon_0=140 +datum=WGS84")
```

## Rasters

A terra raster is planned into tiles by aobcore and drawn on meshes in
the view CRS, so it is never resampled in R. A remote Cloud Optimized
GeoTIFF is referenced by URL and the browser fetches its tiles; a local
or in-memory raster is embedded. This one is a small polar field in
EPSG:3031 shipped with aobcore, with the coastline over it: the v1
target of a polar raster with vector overlays, in one call.

``` r

sst <- terra::rast(system.file("extdata", "polar_3031.tif", package = "aobcore"))
v <- view(list(sst = sst, coastline = coast))
```

Raster views need gdalraster with a working PROJ database. On macOS,
CRAN’s gdalraster binary cannot currently find its `proj.db`; gdalraster
from conda-forge works.

## Where next

- [`view()`](https://allboa.github.io/aobview/reference/view.md),
  [`view_add()`](https://allboa.github.io/aobview/reference/view-layers.md)
  and
  [`view_crs()`](https://allboa.github.io/aobview/reference/view_crs.md)
  in the reference.
- [How it fits
  together](https://allboa.github.io/aobview/articles/how-it-fits-together.md):
  aobcore, the scene spec, and where lonboard comes in.
- [Get
  involved](https://allboa.github.io/aobview/articles/get-involved.md):
  what to try, and where to report it.
