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
* `inst/extdata/ccamlr_statistical_areas.geojson`: the CCAMLR statistical
  areas of Areas 48, 58 and 88 (CCAMLR GIS, https://gis.ccamlr.org), 19
  polygons in EPSG:6932 simplified at 2 km, illustrative only, for
  examples and tests of a projected CRS that is not the view's. Made by
  `tools/make-ccamlr-fixture.R`; provenance in `inst/extdata/README`.
* A pkgdown site at https://allboa.github.io/aobview/, deployed from main
  by GitHub Actions: a home page that says the project is in development,
  a Get started article with live maps written by `view()`, and articles
  on how the allonboard pieces fit together and how to get involved.
* `view()` and `view_add()` choose between embedding the view in a page
  and serving it from a local server with `aobcore::serve_scene()`
  (allboa/design decision 0006). `transport = "auto"` (the default, or
  `getOption("aobview.transport")`) embeds unless the view's local raster
  tiles, counted from each tile plan, pass
  `getOption("aobview.embed_max")` (32 MiB): then, in an interactive
  session with httpuv, the view is served with a message (a server is left
  running), and otherwise embedded with a warning. `"embed"` and `"serve"`
  force one. A served view has `v$server` and `v$file = NULL`; printing it
  opens the URL, and `view_add()` replaces its scene on the same server.
  A served layer's temporary COG is kept in `tempdir()/aobview-cogs` and
  deleted when the server stops. httpuv is suggested (#17).
* Served views send selections back to R (allboa/design decision 0007):
  `selection(v)` gives the selected rows as indices into the objects that
  were viewed, `selected(v)` the rows themselves (`sf`, `sfc` or
  `SpatVector`; `source =` picks one of several), `wait_for_selection(v)`
  waits for the next selection, and `view_state(v)` gives the page's
  settled view. A view keeps each vector object with the map from its
  layers' rows to its own rows (empty and untransformable geometries
  dropped, mixed geometry split, geometry collection parts), and the scene
  serial of its server. Every vector layer of a served view is selectable.
  The functions are errors on an embedded view, a stopped server and a view
  that `view_add()` has replaced. `view_add()` on a served view reloads the
  open page and clears the selection, and printing a served view opens the
  page only when none is connected (#22).
