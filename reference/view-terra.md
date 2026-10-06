# View a terra raster or vector

[`view()`](https://allboa.github.io/aobview/reference/view.md) of a
'terra' `SpatRaster` draws it as a tiled Cloud Optimized GeoTIFF (COG)
through 'aobcore':
[`aobcore::cog_info()`](https://rdrr.io/pkg/aobcore/man/cog_info.html)
reads the COG's structure,
[`aobcore::cog_plan()`](https://rdrr.io/pkg/aobcore/man/cog_plan.html)
plans its tiles with a mesh already projected to the view CRS, and
[`aobcore::scene_add_tiled_raster()`](https://rdrr.io/pkg/aobcore/man/scene_add_tiled_raster.html)
adds them to the scene. The raster is never resampled in R; reprojection
happens in the mesh.

## Usage

``` r
# S3 method for class 'SpatRaster'
view(
  x,
  ...,
  crs = NULL,
  layer = NULL,
  rgb = NULL,
  palette = NULL,
  range = NULL,
  legend = TRUE,
  name = NULL,
  file = NULL,
  theme = c("auto", "light", "dark"),
  transport = getOption("aobview.transport", "auto")
)

# S3 method for class 'SpatVector'
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
```

## Arguments

- x:

  A 'terra' `SpatRaster` or `SpatVector`.

- ...:

  For a `SpatRaster`, passed to
  [`aobcore::cog_plan()`](https://rdrr.io/pkg/aobcore/man/cog_plan.html)
  (`max_tiles`, `max_stretch`, `tolerance`, ...). Not used for a
  `SpatVector`: an argument caught there (a misspelled one, say) is an
  error.

- crs:

  The view CRS: anything
  [`aobcore::scene_crs()`](https://rdrr.io/pkg/aobcore/man/scene_crs.html)
  and 'PROJ' read, such as `"EPSG:3031"`, `3031` or a PROJ string.
  `NULL` (the default) uses
  [`view_crs()`](https://allboa.github.io/aobview/reference/view_crs.md).
  A stream whose geometry has no CRS in its GeoArrow metadata is taken
  to be in `crs` (see Arrow streams).

- layer:

  The layer to draw through the palette (a number or name). Giving it
  draws that layer even when `x` is a colour image.

- rgb:

  `NULL` (colour when `x` is a Byte red, green, blue raster and neither
  `layer` nor `palette` is given), `TRUE` to draw a colour image of the
  layers
  [`terra::RGB()`](https://rspatial.github.io/terra/reference/RGB.html)
  names (layers 1 to 3, and 4 as alpha, when it names none), or `FALSE`
  for the palette.

- palette:

  For a `SpatRaster`, a palette name the renderer knows: `"viridis"`
  (the default), `"ocean"`, `"ice"` or `"gray"`. For a `SpatVector` with
  `zcol`, a palette as for
  [`view()`](https://allboa.github.io/aobview/reference/view.md): a name
  from
  [`grDevices::hcl.pals()`](https://rdrr.io/r/grDevices/palettes.html)
  or
  [`grDevices::palette.pals()`](https://rdrr.io/r/grDevices/palette.html),
  or a function of `n`.

- range:

  `c(low, high)`: the values at the ends of the palette. By default the
  range of the COG's coarsest level. For a colour image of a type other
  than Byte, the values drawn as zero and full intensity.

- legend:

  For a palette `SpatRaster`, `TRUE` (the default) keys the palette with
  a ramp and `FALSE` leaves it out (see Legend). For a `SpatVector`, as
  for [`view()`](https://allboa.github.io/aobview/reference/view.md).

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

- densify:

  Maximum edge length, in the units of `x`'s CRS, for lines and polygon
  edges before they are transformed. `NULL` (the default) densifies
  lon/lat data every 0.25 degrees when the view CRS differs, and nothing
  else; `FALSE` or `0` never densifies; a number densifies whenever the
  view CRS differs from `x`'s.

- style:

  `"default"` or `"minimal"`, the starting point that `fill`, `stroke`,
  `stroke_width_px` and `radius_px` change. See Minimal style in
  [`view()`](https://allboa.github.io/aobview/reference/view.md).

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

- breaks:

  With a numeric `zcol`: increasing break points that bin the values
  into classes, one colour each; see
  [`view_colours()`](https://allboa.github.io/aobview/reference/view_colours.md).

- na_colour:

  With `zcol`: the colour for `NA` values.

- popup:

  `TRUE` shows the attribute columns (the first 20) for a selected
  feature, a character vector names the columns to show, and `FALSE`
  shows none. See Popups. `NULL` (the default) is `TRUE`, or `FALSE`
  with `style = "minimal"`.

## Value

A view, as for
[`view()`](https://allboa.github.io/aobview/reference/view.md).

## Details

**Which COG.** When `x` is read unchanged from one tiled GeoTIFF with
overviews (a COG, or an image small enough for one tile), local or
remote (an `http(s)` URL or a `/vsicurl/` path), that file is used. A
remote COG is referenced by URL and the browser fetches its tiles by
HTTP range requests (the server must allow them, and CORS): the page
carries the recipe, not the data. A local COG's planned tiles are
embedded in the page, unless the view is served (see Transport in
[`view()`](https://allboa.github.io/aobview/reference/view.md)): then
the server delivers the file. Anything else (a raster in memory, a file
that is striped or has no overviews, several sources, a computed,
cropped or windowed raster, or one given another
[`terra::NAflag()`](https://rspatial.github.io/terra/reference/NAflag.html))
is written to a temporary COG in `file.path(tempdir(), "aobview-cogs")`
with `terra::writeRaster(filetype = "COG")`. When its planned tiles are
embedded, so the page opens from disk with no server, the temporary COG
is deleted once the layer is added; when the view is served, the server
keeps it until it stops.

**Datasets too large to write whole.** When `x` is read unchanged from
one GDAL dataset that is not such a COG (a tile service such as WMS or
TMS, a VRT, any huge virtual grid) and its full grid, as a COG, would
hold more tiles than the plan's `max_tiles` (1024 by default) can draw,
terra does not write it. GDAL reads the dataset itself
([`gdalraster::translate()`](https://firelab.github.io/gdalraster/reference/translate.html),
in the dataset's own grid and CRS) into the temporary COG, at the finest
power-of-two reduction whose COG fits `max_tiles`; GDAL takes the
dataset's overviews or zoom levels for that. With `extent` (in the view
CRS, passed to
[`aobcore::cog_plan()`](https://rdrr.io/pkg/aobcore/man/cog_plan.html))
only that part of the grid is read, so a smaller extent shows more
detail, and with `units_per_pixel` as well, no finer than that view
needs. A message says how much was read. The choice is made from the
dataset's size, before any cell is read, and no cell is scanned: a
colour image's transparency is the dataset's mask (its no-data value,
mask band or alpha band), written as an alpha band. A service whose mask
says every cell is valid (as a WMS or TMS of three bands usually does)
draws a missing tile as black (zero), not transparent. A dataset whose
full grid fits is written by terra as above.

**Colour or palette.** A raster of 3 or 4 layers with values 0 to 255
(Byte) and colour interpretation red, green, blue (and alpha), set with
[`terra::RGB()`](https://rspatial.github.io/terra/reference/RGB.html)
(in its order) or else from the file, is drawn as a colour image.
Otherwise one layer (`layer`, the first by default) is drawn through a
palette over the range of its values.

**Legend.** A palette raster is keyed by a ramp of its palette over its
range. In a scene with no legends or popups otherwise (scene spec 0.4 or
earlier) the renderer draws that ramp itself and the scene stays at the
lowest version that expresses it; in a scene spec 0.5 scene (a legend or
popup on another layer) the ramp is written as the raster's legend with
[`aobcore::scene_add_legend()`](https://rdrr.io/pkg/aobcore/man/scene_add_legend.html).
`legend = FALSE` leaves the ramp out, which needs scene spec 0.5. A
colour image has no legend.

A `SpatVector` is read from terra's own WKB
(`terra::geom(x, wkb = TRUE)`) with its attributes, and drawn as any
vector data is (see
[`view()`](https://allboa.github.io/aobview/reference/view.md)),
coloured by an attribute with `zcol` (with a legend) and with its
attributes as popups. It does not need 'sf'.

## See also

[`view_crs()`](https://allboa.github.io/aobview/reference/view_crs.md)
for the default view CRS.

## Examples

``` r
r <- terra::rast(system.file("extdata", "polar_lonlat.tif", package = "aobcore"))
v <- view(r, palette = "ocean")
v$scene$view$crs
#> [1] "EPSG:3031"

m <- terra::rast(ncols = 72, nrows = 20, xmin = -180, xmax = 180, ymin = -90, ymax = -40,
                 vals = 1:1440, crs = "OGC:CRS84")
view(m)
#> <view> m: 1 layer in EPSG:3031
#>   /tmp/RtmpsZkkVc/view-1d075418d99b.html
```
