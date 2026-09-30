# aobview

Convenience front end for allonboard: a mapview-style `view(x)` for sf and terra, with palettes, legends and popups. The package name is a placeholder.

Read the org agent brief first: [allboa/design AGENTS.md](https://github.com/allboa/design/blob/main/AGENTS.md). It covers the design principles, how work flows, and when to stop and ask.

## Status

Early (phase 3). `view()` draws sf and sfc points, lines and polygons in their own CRS, or in a polar view chosen for them, in a self-contained HTML page written by [aobcore](https://github.com/allboa/aobcore). terra, colour by attribute, legends, popups and several layers in one view are planned in the [issues](https://github.com/allboa/aobview/issues).

```r
library(aobview)
coast <- sf::st_read(system.file("extdata", "coastline_south_40s.geojson", package = "aobcore"), quiet = TRUE)
view(coast)                       # lon/lat south of 40S: drawn in EPSG:3031
view(coast, crs = "+proj=laea +lat_0=-90 +lon_0=140 +datum=WGS84")

nc <- sf::st_read(system.file("shape", "nc.shp", package = "sf"), quiet = TRUE)
v <- view(nc)                     # lon/lat elsewhere: drawn flat in its own CRS
v$file                            # the page; printing v opens it
```

`view()` returns a view with the `scene` and the `file` it wrote. Printing it in an interactive session opens the page in the IDE's viewer or the browser. The page needs no server and no network.

### The view CRS

`view_crs(x)` is the default, and `crs =` overrides it:

- A projected CRS is kept.
- Lon/lat data entirely south of 40S is drawn in EPSG:3031 (Antarctic Polar Stereographic), and entirely north of 60N in EPSG:3413 (NSIDC Polar Stereographic North). The northern threshold is stricter because much mid-latitude land lies between 40N and 60N.
- Other lon/lat data is drawn flat in its own CRS. Web Mercator is not used: it cannot show the poles.

aobcore does not reproject, so aobview transforms with `sf::st_transform()`. Lon/lat lines and polygon edges are densified every 0.25 degrees first (`densify =`), so parallels curve in a polar view.

![Lon/lat polygons, lines and points in EPSG:3031, light](tools/screenshots/mixed-lonlat-in-3031-light.png)

The cap over the pole is a lon/lat ring that runs up the 180 meridian to the pole, so its outline shows that edge.

`tools/write-views.R` writes the example pages; screenshots are taken with aobcore's `js/screenshots.mjs`.

## Install

```r
# install.packages("remotes")
remotes::install_github("allboa/aobview")   # installs aobcore from GitHub too
```

Imports: aobcore, wk and utils. sf is suggested: `view()` dispatches on its classes. A view CRS given with no authority code (a PROJ string, say) also needs gdalraster, which aobcore suggests.
