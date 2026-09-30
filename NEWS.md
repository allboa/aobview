# aobview 0.0.0.9000

* Package skeleton, with R CMD check on Linux, macOS and Windows. aobcore
  is installed from GitHub (`Remotes: allboa/aobcore`) (#2).
* `view()` draws `sf` and `sfc` points, lines and polygons in a
  self-contained page written by `aobcore::write_scene_html()`, one layer
  per kind; mixed geometry is split by kind. Printing the view opens it in
  an interactive session (#2).
* `view_crs()` is the default view CRS: a projected CRS is kept; lon/lat
  data entirely south of 40S are drawn in EPSG:3031 and entirely north of
  60N in EPSG:3413; other lon/lat data are drawn flat in their own CRS.
  Lon/lat lines and polygon edges are densified every 0.25 degrees before
  they are transformed (#2).
* `view()` draws a terra `SpatRaster` as a tiled COG through aobcore
  (`cog_info()`, `cog_plan()`, `scene_add_tiled_raster()`): a raster read
  unchanged from one COG uses that file (a remote COG by URL, fetched by
  the browser; a local one embedded), and any other raster is written to a
  temporary COG and embedded. Reprojection is in aobcore's mesh, so the
  raster is never resampled in R. 3 or 4 Byte red, green, blue (alpha)
  layers draw as a colour image, others one layer through a palette. A
  `SpatVector` draws through the sf path. `view_crs()` has methods for
  both. terra and gdalraster are suggested (#3).
