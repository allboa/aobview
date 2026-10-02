# Changelog

## aobview 0.0.0.9000

- [`view()`](https://allboa.github.io/aobview/reference/view.md) of a
  `SpatRaster` read unchanged from a GDAL dataset that is not a usable
  COG and whose full grid is more than the tile plan can draw (a WMS or
  TMS tile service, a VRT, any huge virtual grid) no longer has terra
  write the whole grid
  ([\#21](https://github.com/allboa/aobview/issues/21)). GDAL reads only
  the planned extent, at the finest power-of-two reduction whose
  temporary COG fits `max_tiles`
  ([`gdalraster::translate()`](https://firelab.github.io/gdalraster/reference/translate.html),
  which takes the dataset’s overviews or zoom levels), with a message
  saying how much was read; `extent` reads part of the grid in more
  detail. The choice is made from the dataset’s size, and no cell is
  scanned: a colour image’s alpha is the dataset’s mask. Smaller
  datasets are written by terra as before. Pointing the renderer at a
  service’s own tile pyramid is left for later.

- The server’s state is read through aobcore’s `serve_scene()` handle
  methods `running()` and `status()` rather than its internal `state`
  ([\#20](https://github.com/allboa/aobview/issues/20)).

- Transport and selection follow-ups
  ([\#20](https://github.com/allboa/aobview/issues/20),
  [\#24](https://github.com/allboa/aobview/issues/24)). A temporary COG
  written while a view is built is deleted when anything fails before a
  server owns it (a later list element, a port that will not bind), and
  [`view_add()`](https://allboa.github.io/aobview/reference/view-layers.md)
  on a stopped view whose registered file is gone errors before it
  writes anything. That error calls the file a temporary COG only when
  it was one. A `/vsi` COG over `aobview.embed_max` under `"auto"` warns
  that the page may be slow (a server cannot deliver it), and on a
  served view no longer adds to `local_bytes`, now documented with the
  view object.
  [`wait_for_selection()`](https://allboa.github.io/aobview/reference/selection.md)
  on a view with no vector layers errors before waiting, and with no
  page counted it first runs the event loop briefly, so a page that
  connected (or selected) while R was busy is taken in rather than
  refused in a non-interactive session. The docs say a geometry
  collection’s parts give one
  [`selection()`](https://allboa.github.io/aobview/reference/selection.md)
  row per layer, and what
  [`view_add()`](https://allboa.github.io/aobview/reference/view-layers.md)
  on an already replaced view does. `tools/selection-check.R`/`.mjs`
  wait for the page’s selection to change instead of sleeping, and also
  check a click on empty map, one `view` message per settled pan, and
  that [`print()`](https://rdrr.io/r/base/print.html) opens no new tab.

- Vector input is wk first (allboa/design decision 0008):
  [`view()`](https://allboa.github.io/aobview/reference/view.md),
  [`view_add()`](https://allboa.github.io/aobview/reference/view-layers.md),
  [`view_crs()`](https://allboa.github.io/aobview/reference/view_crs.md)
  and lists take any geometry wk can read (sfc, wkb, wkt, xy, rct, geos,
  a geoarrow vector, …) or a data frame with such a column, whose other
  columns are the attributes for `zcol` and popups (`geometry =` names
  the column when it is not the sf one or the first). `sf` is one such
  input, no longer the engine: reprojection is PROJ’s
  ([`wk::wk_transform()`](https://paleolimbot.github.io/wk/reference/wk_transform.html)
  with
  [`PROJ::proj_trans_create()`](https://hypertidy.github.io/PROJ/reference/proj_trans_create.html),
  PROJ in Imports), lon/lat densifying is
  [`aobcore::vector_densify()`](https://rdrr.io/pkg/aobcore/man/vector_densify.html),
  and sf is only suggested. A `SpatVector` is read from terra’s own WKB,
  without sf. A wk `grd` is refused for now (it belongs on the raster
  path). The transform is point by point, so features crossing the
  antimeridian or a pole are not cut (as before). Changes: a CRS with no
  code is passed on as PROJ’s WKT (it was the sf `crs`); the members of
  a geometry collection keep their row’s place in the layer (they came
  after the other rows); a feature with any vertex PROJ cannot transform
  is left out with the existing warning (GDAL, through sf, kept the
  visible part of a feature that crosses an orthographic view’s
  horizon). A geometry collection holding an empty member is now drawn
  (it was left out as untransformable). Geometries with non-finite input
  coordinates are left out with their own warning. When PROJ cannot find
  its database (proj.db), as with CRAN’s macOS binary of the PROJ
  package, aobview points PROJ_DATA at the proj folder shipped with
  PROJ, sf, terra or gdalraster, the first that works, or says what to
  set.

- Package skeleton, with R CMD check on Linux, macOS and Windows.
  aobcore is installed from GitHub (`Remotes: allboa/aobcore`)
  ([\#2](https://github.com/allboa/aobview/issues/2)).

- [`view()`](https://allboa.github.io/aobview/reference/view.md) draws
  `sf` and `sfc` points, lines and polygons in a self-contained page
  written by
  [`aobcore::write_scene_html()`](https://rdrr.io/pkg/aobcore/man/write_scene_html.html),
  one layer per kind; mixed geometry is split by kind. Printing the view
  opens it in an interactive session
  ([\#2](https://github.com/allboa/aobview/issues/2)).

- [`view_crs()`](https://allboa.github.io/aobview/reference/view_crs.md)
  is the default view CRS: a projected CRS is kept; lon/lat data
  entirely south of 40S are drawn in EPSG:3031 and entirely north of 60N
  in EPSG:3413; other lon/lat data are drawn flat in their own CRS.
  Lon/lat lines and polygon edges are densified every 0.25 degrees
  before they are transformed
  ([\#2](https://github.com/allboa/aobview/issues/2)).

- [`view()`](https://allboa.github.io/aobview/reference/view.md) draws a
  terra `SpatRaster` as a tiled COG through aobcore (`cog_info()`,
  `cog_plan()`, `scene_add_tiled_raster()`): a raster read unchanged
  from one COG uses that file (a remote COG by URL, fetched by the
  browser; a local one embedded), and any other raster is written to a
  temporary COG and embedded. Reprojection is in aobcore’s mesh, so the
  raster is never resampled in R. 3 or 4 Byte red, green, blue (alpha)
  layers draw as a colour image, others one layer through a palette. A
  `SpatVector` draws through the sf path.
  [`view_crs()`](https://allboa.github.io/aobview/reference/view_crs.md)
  has methods for both. terra and gdalraster are suggested
  ([\#3](https://github.com/allboa/aobview/issues/3)).

- `view(x, zcol = )` colours `sf` and `SpatVector` features by an
  attribute, also through
  [`view_add()`](https://allboa.github.io/aobview/reference/view-layers.md):
  the fill of polygons and points, the stroke of lines. Numbers take a
  continuous palette (or classes with `breaks =`), factor, character and
  logical values one colour per level, `NA` the `na_colour`. `palette`
  is a `grDevices` palette name or a function of `n`. The colours are
  computed by the new
  [`view_colours()`](https://allboa.github.io/aobview/reference/view_colours.md)
  and travel as one RGBA column (`FixedSizeList<uint8, 4>`) beside the
  geometry ([\#5](https://github.com/allboa/aobview/issues/5)).

- Legends ([\#6](https://github.com/allboa/aobview/issues/6)):
  `view(x, zcol = )` adds a scene spec 0.5 legend built from the same
  [`view_colours()`](https://allboa.github.io/aobview/reference/view_colours.md)
  result as the features: a colour-stop ramp over the range for numbers
  (33 stops), one class per interval with `breaks` (labelled as in
  `"(5, 10]"`), or one class per level (no legend, with a message, above
  30 levels), plus an `"NA"` entry only when a drawn feature took
  `na_colour`. `legend = FALSE` leaves it out. A palette `SpatRaster`
  keeps its ramp: drawn by the renderer in a scene that needs nothing
  from 0.5, and written with
  [`aobcore::scene_add_legend()`](https://rdrr.io/pkg/aobcore/man/scene_add_legend.html)
  once the scene is 0.5 (where the renderer draws only the scene’s
  legends); `view(r, legend = FALSE)` leaves it out, which makes the
  scene 0.5.

- Popups ([\#7](https://github.com/allboa/aobview/issues/7)):
  `popup = TRUE` (the default for `sf` and `SpatVector` data) carries
  the first 20 attribute columns in the page, with a message when there
  are more, and names them as the layer’s popup (scene spec 0.5), so
  selecting a feature shows its values. `popup = c(...)` chooses columns
  (no cap) and `popup = FALSE` carries none. Factors travel as character
  (aobcore’s IPC writer cannot write dictionaries), `Date`, `POSIXct`
  and `POSIXlt` as ISO 8601 text; list, raw and matrix columns are left
  out with a message. A view with no legend and no popup keeps its
  earlier scene spec version.

- `tools/write-views.R` also writes each scene as JSON; CI validates
  them with the scenespec validator (pinned to scenespec 9f8df26) and
  runs `tools/popup-check.mjs`, which clicks a station in an EPSG:3031
  view headless and checks its popup’s text.

- `inst/extdata/ccamlr_statistical_areas.geojson`: the CCAMLR
  statistical areas of Areas 48, 58 and 88 (CCAMLR GIS,
  <https://gis.ccamlr.org>), 19 polygons in EPSG:6932 simplified at 2
  km, illustrative only, for examples and tests of a projected CRS that
  is not the view’s. Made by `tools/make-ccamlr-fixture.R`; provenance
  in `inst/extdata/README`.

- A pkgdown site at <https://allboa.github.io/aobview/>, deployed from
  main by GitHub Actions: a home page that says the project is in
  development, a Get started article with live maps written by
  [`view()`](https://allboa.github.io/aobview/reference/view.md), and
  articles on how the allonboard pieces fit together and how to get
  involved.

- [`view()`](https://allboa.github.io/aobview/reference/view.md) and
  [`view_add()`](https://allboa.github.io/aobview/reference/view-layers.md)
  choose between embedding the view in a page and serving it from a
  local server with
  [`aobcore::serve_scene()`](https://rdrr.io/pkg/aobcore/man/serve_scene.html)
  (allboa/design decision 0006). `transport = "auto"` (the default, or
  `getOption("aobview.transport")`) embeds unless the view’s local
  raster tiles, counted from each tile plan, pass
  `getOption("aobview.embed_max")` (32 MiB): then, in an interactive
  session with httpuv, the view is served with a message (a server is
  left running), and otherwise embedded with a warning. `"embed"` and
  `"serve"` force one. A served view has `v$server` and `v$file = NULL`;
  printing it opens the URL, and
  [`view_add()`](https://allboa.github.io/aobview/reference/view-layers.md)
  replaces its scene on the same server. A served layer’s temporary COG
  is kept in `tempdir()/aobview-cogs` and deleted when the server stops.
  httpuv is suggested
  ([\#17](https://github.com/allboa/aobview/issues/17)).

- Served views send selections back to R (allboa/design decision 0007):
  `selection(v)` gives the selected rows as indices into the objects
  that were viewed, `selected(v)` the rows themselves (`sf`, `sfc` or
  `SpatVector`; `source =` picks one of several),
  `wait_for_selection(v)` waits for the next selection, and
  `view_state(v)` gives the page’s settled view. A view keeps each
  vector object with the map from its layers’ rows to its own rows
  (empty and untransformable geometries dropped, mixed geometry split,
  geometry collection parts), and the scene serial of its server. Every
  vector layer of a served view is selectable. The functions are errors
  on an embedded view, a stopped server and a view that
  [`view_add()`](https://allboa.github.io/aobview/reference/view-layers.md)
  has replaced.
  [`view_add()`](https://allboa.github.io/aobview/reference/view-layers.md)
  on a served view reloads the open page and clears the selection, and
  printing a served view opens the page only when none is connected
  ([\#22](https://github.com/allboa/aobview/issues/22)).

- [`view()`](https://allboa.github.io/aobview/reference/view.md) and
  [`view_add()`](https://allboa.github.io/aobview/reference/view-layers.md)
  take `style = "minimal"` for sf, sfc and SpatVector data, for
  exploring how large a view can be (like `pch = "."`): opaque one-pixel
  lines and polygon outlines, polygons not filled (no triangulation or
  fill layer in the page), points as two-pixel dots with no outline, and
  no popup columns unless `popup` asks for them. `popup` now defaults to
  `NULL`, which is `TRUE` except in the minimal style.

- A layer name is no longer deparsed from the whole data when `x` is
  passed by value, as in `do.call(view, list(x))`; that deparse took
  longer than the view itself for large data.
