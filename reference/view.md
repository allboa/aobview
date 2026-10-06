# View spatial data in its own CRS

Draws `x` in a self-contained HTML page, in the CRS chosen by
[`view_crs()`](https://allboa.github.io/aobview/reference/view_crs.md)
unless `crs` is given, and returns the view. Printing the view in an
interactive session opens the page in the IDE's viewer or the browser.
The page is written by
[`aobcore::write_scene_html()`](https://rdrr.io/pkg/aobcore/man/write_scene_html.html)
and needs no server and no network: the data travel in the page as
native 'GeoArrow'. A view with large local rasters is served from a
local server instead (see Transport).

## Usage

``` r
view(x, ...)

# Default S3 method
view(
  x,
  ...,
  crs = NULL,
  densify = NULL,
  style = "default",
  fill = NULL,
  stroke = NULL,
  stroke_width_px = NULL,
  radius_px = NULL,
  zcol = NULL,
  palette = NULL,
  breaks = NULL,
  na_colour = "#999999",
  legend = TRUE,
  popup = NULL,
  name = NULL,
  file = NULL,
  theme = c("auto", "light", "dark"),
  transport = getOption("aobview.transport", "auto")
)

# S3 method for class 'nanoarrow_array_stream'
view(
  x,
  ...,
  geometry = NULL,
  crs = NULL,
  densify = NULL,
  style = "default",
  fill = NULL,
  stroke = NULL,
  stroke_width_px = NULL,
  radius_px = NULL,
  zcol = NULL,
  palette = NULL,
  breaks = NULL,
  na_colour = "#999999",
  legend = TRUE,
  popup = NULL,
  name = NULL,
  file = NULL,
  theme = c("auto", "light", "dark"),
  transport = getOption("aobview.transport", "auto")
)

# S3 method for class 'data.frame'
view(
  x,
  ...,
  geometry = NULL,
  crs = NULL,
  densify = NULL,
  style = "default",
  fill = NULL,
  stroke = NULL,
  stroke_width_px = NULL,
  radius_px = NULL,
  zcol = NULL,
  palette = NULL,
  breaks = NULL,
  na_colour = "#999999",
  legend = TRUE,
  popup = NULL,
  name = NULL,
  file = NULL,
  theme = c("auto", "light", "dark"),
  transport = getOption("aobview.transport", "auto")
)
```

## Arguments

- x:

  A spatial object: a geometry vector 'wk' can handle, or a data frame
  with such a column (an `sf` data frame, say); an Arrow stream, or an
  object with an
  [`nanoarrow::as_nanoarrow_array_stream()`](https://arrow.apache.org/nanoarrow/latest/r/reference/as_nanoarrow_array_stream.html)
  method (an 'arrow' `Table`, a 'duckdb' result fetched as Arrow, ...);
  an `OGRFeatureSet` from 'gdalraster'; a 'terra' object
  ([view-terra](https://allboa.github.io/aobview/reference/view-terra.md));
  or a list of them
  ([view-layers](https://allboa.github.io/aobview/reference/view-layers.md)).

- ...:

  Not used by the vector methods: an argument caught here (a misspelled
  one, say) is an error.

- crs:

  The view CRS: anything
  [`aobcore::scene_crs()`](https://rdrr.io/pkg/aobcore/man/scene_crs.html)
  and 'PROJ' read, such as `"EPSG:3031"`, `3031` or a PROJ string.
  `NULL` (the default) uses
  [`view_crs()`](https://allboa.github.io/aobview/reference/view_crs.md).
  A stream whose geometry has no CRS in its GeoArrow metadata is taken
  to be in `crs` (see Arrow streams).

- densify:

  Maximum edge length, in the units of `x`'s CRS, for lines and polygon
  edges before they are transformed. `NULL` (the default) densifies
  lon/lat data every 0.25 degrees when the view CRS differs, and nothing
  else; `FALSE` or `0` never densifies; a number densifies whenever the
  view CRS differs from `x`'s.

- style:

  `"default"` or `"minimal"`, the starting point that `fill`, `stroke`,
  `stroke_width_px` and `radius_px` change. See Minimal style in
  `view()`.

- fill, stroke:

  Colours as `c(r, g, b, a)`, integers 0 to 255. `NULL` keeps the
  defaults: a translucent blue fill with a blue outline for polygons,
  blue lines, and blue points with a white outline. `fill` is ignored
  for lines.

- stroke_width_px:

  Line or outline width in pixels.

- radius_px:

  Point radius in pixels.

- zcol:

  The name of a column of `x` to colour features by, or `NULL` (the
  default) for one colour. Not for a bare geometry vector, which has no
  columns.

- palette:

  With `zcol`: a palette name (from
  [`grDevices::hcl.pals()`](https://rdrr.io/r/grDevices/palettes.html)
  or
  [`grDevices::palette.pals()`](https://rdrr.io/r/grDevices/palette.html))
  or a function of `n` returning `n` colours, such as
  [`grDevices::hcl.colors()`](https://rdrr.io/r/grDevices/palettes.html);
  see
  [`view_colours()`](https://allboa.github.io/aobview/reference/view_colours.md).
  `NULL` is `"viridis"` for numbers and `"Tableau 10"` for levels.

- breaks:

  With a numeric `zcol`: increasing break points that bin the values
  into classes, one colour each; see
  [`view_colours()`](https://allboa.github.io/aobview/reference/view_colours.md).

- na_colour:

  With `zcol`: the colour for `NA` values.

- legend:

  With `zcol`: `TRUE` (the default) adds a legend for the colours,
  `FALSE` leaves it out. Without `zcol` there is nothing to key.

- popup:

  `TRUE` shows the attribute columns (the first 20) for a selected
  feature, a character vector names the columns to show, and `FALSE`
  shows none. See Popups. `NULL` (the default) is `TRUE`, or `FALSE`
  with `style = "minimal"`.

- name:

  The layer name, shown as the page title. Defaults to the expression
  passed as `x`.

- file:

  Path of the HTML file to write. Defaults to a new file in the
  session's temporary directory. Not used by a served view (with a
  warning).

- theme:

  `"auto"` follows the browser's light or dark preference; `"light"` or
  `"dark"` fixes it.

- transport:

  `"auto"`, `"embed"` or `"serve"`: whether the view is written to a
  page or served from a local server (see Transport). Defaults to
  `getOption("aobview.transport", "auto")`.

- geometry:

  For a data frame, the name of its geometry column. `NULL` (the
  default) takes the `sf` geometry column, else the first column 'wk'
  can handle. For a stream, the column to draw (GeoArrow, WKB bytes or
  WKT text); `NULL` takes the first column with a GeoArrow extension
  type, else GDAL's `ogc.wkb` column. For an `OGRFeatureSet` with
  several geometry columns, the one to draw.

## Value

A view: a list of class `"aob_view"` with the `scene` (an
[`aobcore::scene()`](https://rdrr.io/pkg/aobcore/man/scene.html)), the
`file` it was written to (`NULL` when served), the `server` serving it
(an `"aob_server"` from
[`aobcore::serve_scene()`](https://rdrr.io/pkg/aobcore/man/serve_scene.html),
or `NULL` when embedded), its `name` (the page title), `theme`,
`extents`, each layer's extent in the view CRS (from which the initial
view is set), `sources`, each vector object viewed with its name and the
map from its layers' rows to its own rows, `serial`, the scene serial
the server gave the scene (`NULL` when embedded), and `local_bytes`, the
bytes of local raster tiles embedded in the page so far, which
[`view_add()`](https://allboa.github.io/aobview/reference/view-layers.md)
adds to when it chooses between embedding and serving (see Transport).
Add to it with
[`view_add()`](https://allboa.github.io/aobview/reference/view-layers.md).
Printing it opens the page when the session is interactive; a served
view's URL is opened only when no page is connected to its server, since
an open page follows the view (see
[`selection()`](https://allboa.github.io/aobview/reference/selection.md)).

## Details

Points, lines and polygons (single or multi) are drawn as one layer
each. A mixed `GEOMETRY` or `GEOMETRYCOLLECTION` column is split into up
to three layers, polygons at the bottom, then lines, then points. Empty
geometries are dropped, as are Z and M values. The split layers share
the view's name, with the kind appended to each label, as in
`"mixed (polygons)"`.

**Inputs.** Vector data are read through 'wk' (allboa/design decision
0008): `x` can be any geometry vector 'wk' can handle (an `sfc`,
[`wk::wkb()`](https://paleolimbot.github.io/wk/reference/wkb.html),
[`wk::wkt()`](https://paleolimbot.github.io/wk/reference/wkt.html),
[`wk::xy()`](https://paleolimbot.github.io/wk/reference/xy.html),
[`wk::rct()`](https://paleolimbot.github.io/wk/reference/rct.html), a
'geos' geometry, a 'geoarrow' vector, ...), or a data frame with such a
column, whose other columns are the attributes (for `zcol` and popups).
An `sf` data frame is one; for any other data frame the geometry column
is the first that 'wk' can handle, or the one named by `geometry`. The
CRS travels with the geometry
([`wk::wk_crs()`](https://paleolimbot.github.io/wk/reference/wk_crs.html)).
A terra `SpatVector` is read from terra's own WKB (see
[view-terra](https://allboa.github.io/aobview/reference/view-terra.md)).
A [`wk::grd()`](https://paleolimbot.github.io/wk/reference/grd.html) is
not drawn yet: a grid belongs on the raster path.

**Arrow streams** (allboa/design decision 0011). `x` can be a
'nanoarrow' array stream, or anything with an
[`nanoarrow::as_nanoarrow_array_stream()`](https://arrow.apache.org/nanoarrow/latest/r/reference/as_nanoarrow_array_stream.html)
method: an 'arrow' `Table`, `RecordBatchReader` or `Dataset`, a 'duckdb'
result fetched as Arrow
([`duckdb::duckdb_fetch_arrow()`](https://r.duckdb.org/reference/duckdb_result-class.html)
or `duckdb_fetch_record_batch()` on a query sent with `arrow = TRUE`), a
layer's `GDALVector$getArrowStream()` from 'gdalraster', an ADBC result.
The stream is read once, batch by batch, into a data frame of its rows,
which is then viewed as a data frame: its other columns are the
attributes. The geometry column is the first with a GeoArrow extension
type (`geoarrow.point`, `geoarrow.wkb`, ...), else GDAL's `ogc.wkb`
column, else the one `geometry` names, which holds WKB bytes (a binary
column) or WKT text. Its CRS comes from the GeoArrow extension metadata;
a column with none (a DuckDB blob, GDAL's WKB) is taken to be in `crs`,
which must then be given (in
[`view_add()`](https://allboa.github.io/aobview/reference/view-layers.md),
or in a list given `crs`, it is the view's CRS). A stream read before
has no rows left and is an error.
[`selected()`](https://allboa.github.io/aobview/reference/selection.md)
on a stream gives rows of the data frame it was read into, since the
stream itself cannot be read again.

**GDALVector\$fetch().** An `OGRFeatureSet` from 'gdalraster' (a data
frame whose geometry column holds WKB bytes, or WKT text, with the
layer's SRS and the column's name in its `gis` attribute) is viewed as a
data frame: the geometry column is wrapped as
[`wk::wkb()`](https://paleolimbot.github.io/wk/reference/wkb.html) with
the layer's SRS, and
[`selected()`](https://allboa.github.io/aobview/reference/selection.md)
gives its rows as fetched. A set fetched without geometry
(`returnGeomAs = "NONE"`) or as bounding boxes is an error.

'aobcore' does not reproject, so `x` is transformed to the view CRS here
by 'PROJ'
([`wk::wk_transform()`](https://paleolimbot.github.io/wk/reference/wk_transform.html)
with
[`PROJ::proj_trans_create()`](https://hypertidy.github.io/PROJ/reference/proj_trans_create.html)).
When `x` is in lon/lat and the view CRS differs, lines and polygon edges
are first densified in lon/lat (every `densify` degrees, 0.25 by
default, with
[`aobcore::vector_densify()`](https://rdrr.io/pkg/aobcore/man/vector_densify.html)),
so an edge along a parallel curves as it should in a polar view instead
of cutting across it. The transform is point by point: nothing is cut at
the antimeridian or the poles, so the view is right in any CRS but the
topology of features that cross a seam is not guaranteed. A point PROJ
cannot transform (one beyond an orthographic view's horizon, say) leaves
its feature out, with a warning.

**Colour by attribute.** `zcol` names a column of `x` whose values
colour each feature: the fill of polygons and points, the stroke of
lines. Numbers take a continuous palette over their range (or one colour
per class with `breaks`), factors, character and logical values one
colour per level; `NA` takes `na_colour`. The colours are computed in R
by
[`view_colours()`](https://allboa.github.io/aobview/reference/view_colours.md)
and travel to the page as one RGBA column beside the geometry (with the
popup columns, below). With `zcol`, polygons get a grey outline (change
it with `stroke`); `fill`, and `stroke` for lines, are errors, since
`zcol` sets those colours.

**Legend.** With `zcol`, the view carries a legend for the colours,
built from the same
[`view_colours()`](https://allboa.github.io/aobview/reference/view_colours.md)
result as the features, so the two agree: a ramp over the range for
numbers, one entry per interval with `breaks` (labelled as in
`"(5, 10]"`), or one entry per level. An `"NA"` entry is added only when
some drawn feature took `na_colour`. A column with more than 30 levels
gets no legend (with a message), since a key that long is not readable;
the features are still coloured. `legend = FALSE` leaves it out. A
legend is scene spec 0.5 data (see
[`aobcore::scene_add_legend()`](https://rdrr.io/pkg/aobcore/man/scene_add_legend.html)).

**Popups.** `popup = TRUE` (the default) carries `x`'s attribute columns
in the page and declares them as the layer's popup (scene spec 0.5):
selecting a feature (a click, tap or key press) shows its values. Only
the first 20 columns are carried, with a message, since every column
adds bytes to the page; choose columns with `popup = c("a", "b")`, which
has no cap, or carry none with `popup = FALSE`. A data frame with no
attribute columns gets no popup. Numbers, character and logical columns
are carried as they are; factors as their labels, `Date` as
`"YYYY-MM-DD"`, `POSIXct` and `POSIXlt` as ISO 8601 text in UTC, and
other atomic classes as their
[`as.character()`](https://rdrr.io/r/base/character.html) text. List,
raw and matrix columns cannot be shown and are left out with a message.

**Minimal style.** `style = "minimal"` draws with the least the page
carries and the renderer builds per feature, for exploring how much data
a view can take (like `pch = "."` in base graphics): opaque one-pixel
lines and polygon outlines, polygons not filled (so not triangulated),
points as two-pixel dots with no outline, and no popup columns unless
`popup` asks for them. Without `zcol`, each colour is one constant for
the layer, not a value per feature. `fill`, `stroke`, `stroke_width_px`
and `radius_px` still apply on top (a `fill` fills polygons again). With
`zcol`, the column colours polygon outlines rather than fills. An
unfilled polygon is selected (in a popup or from a served page) only by
its outline, not by a click inside it; give `fill` for that. The
geometry itself is unchanged: every vertex still travels in the page as
16 bytes (two doubles), plus a third for base64.

**Transport.** A view is embedded (the page above, on disk) or served
from a local HTTP server by
[`aobcore::serve_scene()`](https://rdrr.io/pkg/aobcore/man/serve_scene.html),
which the browser reads a local COG from tile by tile instead of
carrying its bytes in the page (allboa/design decision 0006).
`transport = "embed"` always embeds, `"serve"` always serves (it needs
the 'httpuv' package), and `"auto"` (the default, or
`getOption("aobview.transport")`) embeds unless the view's local raster
tiles, counted from each layer's tile plan before any byte is read, come
to more than `getOption("aobview.embed_max")` bytes (32 MiB by default).
Then, in an interactive session with 'httpuv' installed, that layer and
any added later are served, with a message naming the size; otherwise
the tiles are embedded with a warning. Vector data and remote COGs never
make a view served by themselves. A served view keeps its server running
until `v$server$stop()`,
[`aobcore::stop_scene_servers()`](https://rdrr.io/pkg/aobcore/man/scene_servers.html)
or the end of the R session; the server answers only while R is idle. A
temporary COG (see
[view-terra](https://allboa.github.io/aobview/reference/view-terra.md))
of a served layer is kept in `file.path(tempdir(), "aobview-cogs")`
until the server stops.

**Documents.** A view printed in a chunk of an R Markdown or Quarto
document is drawn in the document, always embedded: while knitr runs,
`"auto"` never serves (see
[knit_print.aob_view](https://allboa.github.io/aobview/reference/knit_print.aob_view.md)).
In a Shiny app, draw a view with
[`renderAobview()`](https://allboa.github.io/aobview/reference/aobview-shiny.md)
and
[`aobviewOutput()`](https://allboa.github.io/aobview/reference/aobview-shiny.md).

**Selections.** A served view's page sends the features the viewer
selects (a click, Shift-click to add or remove) back to R: every vector
layer can be selected. Read them with
[`selection()`](https://allboa.github.io/aobview/reference/selection.md),
[`selected()`](https://allboa.github.io/aobview/reference/selection.md)
and
[`wait_for_selection()`](https://allboa.github.io/aobview/reference/selection.md);
an embedded page cannot send them.

**Spec version.** The scene is written at the lowest scene spec version
that can express it
([`aobcore::scene_spec_version()`](https://rdrr.io/pkg/aobcore/man/scene_spec_version.html)):
a view with no legend and no popup is unchanged by these features.

## See also

[`view_crs()`](https://allboa.github.io/aobview/reference/view_crs.md)
for the default view CRS;
[view-terra](https://allboa.github.io/aobview/reference/view-terra.md)
for 'terra' rasters and vectors;
[view-layers](https://allboa.github.io/aobview/reference/view-layers.md)
for several layers in one view.

## Examples

``` r
# Any geometry 'wk' can read, with its CRS: no 'sf' needed.
line <- wk::wkt("LINESTRING (0 -60, 90 -60)", crs = "OGC:CRS84")
v0 <- view(line)
v0$scene$view$crs
#> [1] "EPSG:3031"

# A data frame with a geometry column.
bases <- data.frame(base = c("Casey", "Davis"))
bases$geom <- wk::xy(c(110.53, 77.97), c(-66.28, -68.58), crs = "OGC:CRS84")
v1 <- view(bases, zcol = "base")

# An Arrow stream with a GeoArrow geometry column (the CRS travels in its
# metadata); an arrow Table or a DuckDB result fetched as Arrow go the
# same way.
stream <- nanoarrow::as_nanoarrow_array_stream(bases)
v2 <- view(stream, popup = "base")
v2$scene$view$crs
#> [1] "EPSG:3031"
coast <- sf::st_read(system.file("extdata", "coastline_south_40s.geojson",
                                 package = "aobcore"), quiet = TRUE)
v <- view(coast)
v$scene$view$crs
#> [1] "EPSG:3031"
file.exists(v$file)
#> [1] TRUE

nc <- sf::st_read(system.file("shape", "nc.shp", package = "sf"), quiet = TRUE)
v2 <- view(nc, crs = "EPSG:26717", fill = c(200, 120, 40, 160))
v3 <- view(nc, zcol = "BIR74", palette = "YlOrRd")
v4 <- view(nc, zcol = "SID74", breaks = c(0, 5, 10, 20, 50))
v4$scene$legends[[1]]$classes[[1]]$label
#> [1] "[0, 5]"
v5 <- view(nc, zcol = "BIR74", popup = c("NAME", "BIR74"))
v5$scene$layers[[1]]$popup
#> $columns
#> $columns[[1]]
#> [1] "NAME"
#> 
#> $columns[[2]]
#> [1] "BIR74"
#> 
#> 
v6 <- view(nc, style = "minimal")
v6$scene$layers[[1]][c("stroke", "stroke_width_px", "fill")]
#> $stroke
#> [1]  51 102 204 255
#> 
#> $stroke_width_px
#> [1] 1
#> 
#> $<NA>
#> NULL
#> 

# CCAMLR statistical areas (simplified, illustrative; see the extdata
# README) in EPSG:6932, coloured by area with popups, viewed in EPSG:3031
areas <- sf::st_read(system.file("extdata", "ccamlr_statistical_areas.geojson",
                                 package = "aobview"), quiet = TRUE)
areas$area <- paste0("Area ", substr(areas$GAR_Long_Label, 1, 2))
v7 <- view(areas, crs = "EPSG:3031", zcol = "area",
           popup = c("GAR_Name", "GAR_Long_Label", "GAR_Start_Date", "GAR_Size"))
v7 <- view_add(v7, coast, popup = FALSE)
vapply(v7$scene$legends[[1]]$classes, function(cl) cl$label, "")
#> [1] "Area 48" "Area 58" "Area 88"
if (FALSE) { # \dontrun{
v2
v3
} # }
```
