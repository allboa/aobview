# aobview

Convenience front end for allonboard: a mapview-style `view(x)` for sf and terra, with palettes, legends and popups. The package name is a placeholder.

Read the org agent brief first: [allboa/design AGENTS.md](https://github.com/allboa/design/blob/main/AGENTS.md). It covers the design principles, how work flows, and when to stop and ask.

## Status

Early (phase 3). `view()` draws sf and sfc points, lines and polygons, and terra rasters and vectors, in their own CRS, or in a polar view chosen for them, in a self-contained HTML page written by [aobcore](https://github.com/allboa/aobcore). Several objects draw in one view, as a list or by adding to a view. Colour by attribute, legends and popups are planned in the [issues](https://github.com/allboa/aobview/issues).

```r
library(aobview)
coast <- sf::st_read(system.file("extdata", "coastline_south_40s.geojson", package = "aobcore"), quiet = TRUE)
view(coast)                       # lon/lat south of 40S: drawn in EPSG:3031
view(coast, crs = "+proj=laea +lat_0=-90 +lon_0=140 +datum=WGS84")

nc <- sf::st_read(system.file("shape", "nc.shp", package = "sf"), quiet = TRUE)
v <- view(nc)                     # lon/lat elsewhere: drawn flat in its own CRS
v$file                            # the page; printing v opens it
```

```r
r <- terra::rast(system.file("extdata", "polar_lonlat.tif", package = "aobcore"))
view(r, palette = "ocean")        # lon/lat raster over the pole: drawn in EPSG:3031
u <- terra::rast("/vsicurl/https://example.org/some.tif")
view(u)                           # a remote COG: the page references it by URL
```

`view()` returns a view with the `scene` and the `file` it wrote. Printing it in an interactive session opens the page in the IDE's viewer or the browser. The page needs no server, and no network unless it references a remote COG.

### Several layers

The v1 target, a polar COG with vector overlays in EPSG:3031, in one call:

```r
sst <- terra::rast(system.file("extdata", "polar_3031.tif", package = "aobcore"))
view(list(sst = sst, coastline = coast))   # one scene in EPSG:3031, sst at the bottom
view(sst) |> view_add(coast, stroke = c(40, 40, 40, 255))   # the same scene, with a style
```

A list draws in list order, first at the bottom; its names become layer labels and (made valid and unique) layer ids. The view CRS is `crs =`, or the first projected CRS in the list, or, when everything is in lon/lat, the rule below applied to the combined extent. `view_add()` keeps the view's CRS. Every object is reprojected to it: vectors in R, rasters through aobcore's tile planner. The initial view is the layers' combined extent, clipped to the view's domain.

![A polar COG with the lon/lat coastline and stations in EPSG:3031, light](tools/screenshots/cog-with-overlays-in-3031-light.png)

### The view CRS

`view_crs(x)` is the default, and `crs =` overrides it:

- A projected CRS is kept.
- Lon/lat data entirely south of 40S is drawn in EPSG:3031 (Antarctic Polar Stereographic), and entirely north of 60N in EPSG:3413 (NSIDC Polar Stereographic North). The northern threshold is stricter because much mid-latitude land lies between 40N and 60N.
- Other lon/lat data is drawn flat in its own CRS. Web Mercator is not used: it cannot show the poles.

aobcore does not reproject, so aobview transforms with `sf::st_transform()`. Lon/lat lines and polygon edges are densified every 0.25 degrees first (`densify =`), so parallels curve in a polar view.

![Lon/lat polygons, lines and points in EPSG:3031, light](tools/screenshots/mixed-lonlat-in-3031-light.png)

The cap over the pole is a lon/lat ring that runs up the 180 meridian to the pole, so its outline shows that edge.

### terra

A `SpatRaster` reaches the page as a Cloud Optimized GeoTIFF, planned into tiles by aobcore with meshes projected to the view CRS, so the raster is never resampled in R. A raster read unchanged from one COG uses that file: a remote COG is referenced by URL and the browser fetches its tiles by range request (the server must allow CORS), and a local one has its planned tiles embedded. Any other raster (in memory, computed, cropped, not tiled) is written to a temporary COG with `terra::writeRaster(filetype = "COG")` and embedded. Three or four Byte layers with red, green, blue (and alpha) colour interpretation draw as a colour image; otherwise one layer draws through a palette. A `SpatVector` goes through `sf::st_as_sf()` and the sf path.

Raster views need gdalraster with a working PROJ database, since aobcore plans tiles with it. On macOS, CRAN's gdalraster binary currently cannot find its `proj.db` ("GDAL cannot resolve the CRS EPSG:3031"); gdalraster from conda-forge works.

![A computed lon/lat SpatRaster in EPSG:3031, light](tools/screenshots/terra-lonlat-field-in-3031-light.png)

`tools/write-views.R` writes the example pages; screenshots are taken with aobcore's `js/screenshots.mjs`.

## Install

```r
# install.packages("remotes")
remotes::install_github("allboa/aobview")   # installs aobcore from GitHub too
```

Imports: aobcore, wk and utils. sf and terra are suggested: `view()` dispatches on their classes (a `SpatVector` needs sf too). A `SpatRaster` needs gdalraster, for aobcore's COG reader. A view CRS given with no authority code (a PROJ string, say) also needs gdalraster, which aobcore suggests.
