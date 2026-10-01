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
* `view(x, zcol = )` colours `sf` and `SpatVector` features by an
  attribute, also through `view_add()`: the fill of polygons and points,
  the stroke of lines. Numbers take a continuous palette (or classes with
  `breaks =`), factor, character and logical values one colour per level,
  `NA` the `na_colour`. `palette` is a `grDevices` palette name or a
  function of `n`. The colours are computed by the new `view_colours()`
  and travel as one RGBA column (`FixedSizeList<uint8, 4>`) beside the
  geometry (#5).
* Legends (#6): `view(x, zcol = )` adds a scene spec 0.5 legend built from
  the same `view_colours()` result as the features: a colour-stop ramp over
  the range for numbers (33 stops), one class per interval with `breaks`
  (labelled as in `"(5, 10]"`), or one class per level (no legend, with a
  message, above 30 levels), plus an `"NA"` entry only when a drawn
  feature took `na_colour`. `legend = FALSE` leaves it out. A palette
  `SpatRaster` keeps its ramp: drawn by the renderer in a scene that needs
  nothing from 0.5, and written with `aobcore::scene_add_legend()` once the
  scene is 0.5 (where the renderer draws only the scene's legends);
  `view(r, legend = FALSE)` leaves it out, which makes the scene 0.5.
* Popups (#7): `popup = TRUE` (the default for `sf` and `SpatVector` data)
  carries the first 20 attribute columns in the page, with a message when
  there are more, and names them as the layer's popup (scene spec 0.5), so
  selecting a feature shows its values. `popup = c(...)` chooses columns
  (no cap) and `popup = FALSE` carries none. Factors travel as character
  (aobcore's IPC writer cannot write dictionaries), `Date`, `POSIXct` and
  `POSIXlt` as ISO 8601 text; list, raw and matrix columns are left out with a message.
  A view with no legend and no popup keeps its earlier scene spec version.
* `tools/write-views.R` also writes each scene as JSON; CI validates them
  with the scenespec validator (pinned to scenespec 9f8df26) and runs
  `tools/popup-check.mjs`, which clicks a station in an EPSG:3031 view
  headless and checks its popup's text.
