# Changelog

## aobview 0.0.0.9000

- [`view()`](https://allboa.github.io/aobview/reference/view.md) plans a
  VRT or GDAL Tile Index (GTI) whose members are COGs across its members
  instead of reading it into a temporary COG
  ([\#41](https://github.com/allboa/aobview/issues/41), allboa/design
  decisions 0010 and 0011): a `SpatRaster` read from such a mosaic, or
  its path or URL as a string, gets one `tiled_raster` layer per member
  (`<name>` for one, else `<name>_<i>`, labelled with the member’s base
  name), each referenced by the member’s own file or URL, with one
  palette, range and legend across them (the first member’s range when
  none is given), through
  [`aobcore::mosaic_members()`](https://rdrr.io/pkg/aobcore/man/mosaic_members.html)
  and
  [`aobcore::mosaic_plan()`](https://rdrr.io/pkg/aobcore/man/mosaic_plan.html);
  only the members the view touches are opened, and nothing is copied. A
  member that cannot be drawn in place (not a tiled GeoTIFF with
  overviews, in another CRS, or stretched, windowed or rescaled by the
  VRT, given a VRT no-data value it lacks, or one of several colour
  bands drawn from different members) sends the mosaic to the
  temporary-COG routes as before, with a message naming the member, so a
  VRT that stretches a small file over a planetary grid now says so
  before it is read. Needs aobcore with `mosaic_plan()`.

- [`view()`](https://allboa.github.io/aobview/reference/view.md) takes
  stars objects and proxies
  ([\#38](https://github.com/allboa/aobview/issues/38), allboa/design
  decision 0011). A `stars_proxy` whose attribute is one file read
  whole, in the file’s CRS, is drawn from that file exactly as the
  file’s path is: a COG, local or remote, is planned with
  [`aobcore::cog_plan()`](https://rdrr.io/pkg/aobcore/man/cog_plan.html)
  and never copied (a remote one referenced by URL), and another raster
  is read through GDAL into a temporary COG; a proxy sliced to one band
  draws that band, and any other proxy (a crop, a computation, several
  files, a changed CRS) is read into memory with
  [`stars::st_as_stars()`](https://r-spatial.github.io/stars/reference/st_as_stars.html).
  An in-memory `stars` object takes the matrix route: one attribute, one
  band, with rows from the top whichever way its offsets run, untiled in
  the page at up to 512 x 512 cells in the view CRS, else through a
  temporary COG written with gdalraster and tiled. `layer` picks the
  attribute when there are several, else the slice along the dimension
  beyond x and y (band, time), by name or number; `palette`, `range` and
  `legend` are as for a one-layer `SpatRaster`, and `...` goes to
  [`aobcore::cog_plan()`](https://rdrr.io/pkg/aobcore/man/cog_plan.html)
  on the tiled routes. The view CRS follows
  [`view_crs()`](https://allboa.github.io/aobview/reference/view_crs.md)
  from the object’s own CRS, read from its dimensions, so a stars object
  goes in a list for
  [`view()`](https://allboa.github.io/aobview/reference/view.md) and to
  [`view_add()`](https://allboa.github.io/aobview/reference/view-layers.md)
  as a `SpatRaster` does. Curvilinear, rectilinear and sheared grids and
  vector data cubes are errors that say they are out of scope for now
  (allboa/design decision 0010, item 5). stars joins Suggests; no terra
  is needed.

- [`view()`](https://allboa.github.io/aobview/reference/view.md) takes
  Arrow streams and tables, DuckDB results and `GDALVector$fetch()`
  output ([\#40](https://github.com/allboa/aobview/issues/40),
  allboa/design decision 0011). A `nanoarrow_array_stream`, or anything
  with an `as_nanoarrow_array_stream()` method (an arrow `Table`,
  `RecordBatchReader` or `Dataset`, a duckdb result fetched as Arrow, a
  gdalraster layer’s `getArrowStream()`), is read once, batch by batch,
  into a data frame of its rows and viewed as one: the geometry column
  is the first with a GeoArrow extension type, else GDAL’s `ogc.wkb`
  column, else the WKB or WKT column `geometry` names, and its CRS comes
  from the GeoArrow metadata, or `crs` when it has none.
  [`selected()`](https://allboa.github.io/aobview/reference/selection.md)
  on a stream gives rows of the data frame it was read into, their
  stream row indices as row names. An `OGRFeatureSet` from gdalraster’s
  `GDALVector$fetch()` is viewed as a data frame, its WKB (or WKT)
  column wrapped as
  [`wk::wkb()`](https://paleolimbot.github.io/wk/reference/wkb.html)
  with the layer’s SRS.
  [`view_add()`](https://allboa.github.io/aobview/reference/view-layers.md)
  and lists take the same inputs. No new Imports: arrow, DBI, duckdb and
  geoarrow join Suggests for the tests.

- [`view()`](https://allboa.github.io/aobview/reference/view.md) takes a
  string ([\#39](https://github.com/allboa/aobview/issues/39),
  allboa/design decision 0011): WKT text, or the path, URL or GDAL data
  source name of a raster or vector source. A string that names a file
  that exists, or starts with a URL scheme or `/vsi`, is a data source;
  any other string wk parses as WKT is geometry (an `SRID=code;` prefix
  gives it that CRS); a string that is neither is probed as a data
  source. A data source is read with gdalraster (still in Suggests; a
  clear error names it when it is missing): a COG, local or remote, is
  planned as a `SpatRaster` read from one is, a remote one referenced by
  URL and never copied; another raster is read through GDAL into a
  temporary COG by the `view-gdal.R` route, whatever its size; a vector
  source is read with
  [`aobcore::gdal_vector_stream()`](https://rdrr.io/pkg/aobcore/man/gdal_vector_stream.html),
  which densifies and reprojects in GDAL, and drawn with its attributes
  as any data frame is. `layer` picks the band or the vector layer; the
  other arguments are those of the route taken. Strings also go in a
  list for
  [`view()`](https://allboa.github.io/aobview/reference/view.md) and to
  [`view_add()`](https://allboa.github.io/aobview/reference/view-layers.md),
  and
  [`view_crs()`](https://allboa.github.io/aobview/reference/view_crs.md)
  reads them. A string literal is named by its base name (or the WKT
  text).

- [`view()`](https://allboa.github.io/aobview/reference/view.md) of a
  matrix or array with an `extent` and `crs`
  ([\#37](https://github.com/allboa/aobview/issues/37), allboa/design
  decision 0011):
  `view(m, extent = c(xmin, xmax, ymin, ymax), crs = "EPSG:3031")` draws
  a numeric or logical matrix as a raster, row 1 at the top as in terra
  and vaster, and a 3- or 4-band array as a colour image. A matrix of at
  most 512 x 512 cells (one tile of a temporary COG) in the view CRS
  goes into the page as an untiled scene spec 0.1 `raster` layer, its
  values as one Arrow column; a larger one, or one whose CRS is not the
  view’s, is written to a temporary COG with gdalraster and takes the
  tiled path a `SpatRaster` does, with `...` to
  [`aobcore::cog_plan()`](https://rdrr.io/pkg/aobcore/man/cog_plan.html).
  `palette`, `range` and `legend` are as for a one-layer `SpatRaster`.
  `view_add(v, m, extent = , crs = )` adds one to a view (`crs` is the
  grid’s), and `view_crs(m, extent = , crs = )` gives the view CRS the
  lon/lat rule chooses for it. No terra needed.

- Views in Shiny apps (allboa/design decision 0009):
  [`aobviewOutput()`](https://allboa.github.io/aobview/reference/aobview-shiny.md)
  and
  [`renderAobview()`](https://allboa.github.io/aobview/reference/aobview-shiny.md)
  (shiny in Suggests), with aobview’s own output binding. The scene
  travels as the render value over the Shiny session, and the renderer
  is loaded once per app. Every vector layer can be selected; the page
  sends each selection and settled camera as the input values
  `input$<id>_aob_select` and `input$<id>_aob_view` (protocol 1
  messages), and
  [`aobview_selection()`](https://allboa.github.io/aobview/reference/aobview-shiny.md),
  [`aobview_selected()`](https://allboa.github.io/aobview/reference/aobview-shiny.md)
  and
  [`aobview_view_state()`](https://allboa.github.io/aobview/reference/aobview-shiny.md)
  read them reactively, mapped through the rendered view as
  [`selection()`](https://allboa.github.io/aobview/reference/selection.md),
  [`selected()`](https://allboa.github.io/aobview/reference/selection.md)
  and
  [`view_state()`](https://allboa.github.io/aobview/reference/selection.md)
  are for a served view. They work inside modules. A new render (a
  `NULL` one too) clears the selection and re-runs them. The temporary
  page [`view()`](https://allboa.github.io/aobview/reference/view.md)
  writes for a rendered view is deleted on the output’s next render and
  when the session ends. While Shiny runs, `transport = "auto"` never
  serves, and a served view cannot be rendered (an error).

- A view printed in a chunk of an R Markdown or Quarto document is drawn
  in the document (allboa/design decision 0009): `knit_print()` is
  registered for views when knitr is loaded (knitr in Suggests) and
  prints
  [`aobcore::scene_tag()`](https://rdrr.io/pkg/aobcore/man/scene_tag.html),
  so each view’s data are embedded and the document carries the renderer
  once. The view is `"100%"` wide (or the chunk’s `out.width`) and
  `fig.height` inches tall at 96 pixels per inch (or `out.height`), in
  the view’s `theme`. While knitr runs, `transport = "auto"` never
  serves: over `getOption("aobview.embed_max")` the tiles are embedded
  with a warning naming the document. A served view cannot be knitted
  (an error). An explicit `print(v)` in a chunk opens no page while
  knitr renders the document.

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
