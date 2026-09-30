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
