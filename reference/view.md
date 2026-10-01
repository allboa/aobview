# View spatial data in its own CRS

Draws `x` in a self-contained HTML page, in the CRS chosen by
[`view_crs()`](https://allboa.github.io/aobview/reference/view_crs.md)
unless `crs` is given, and returns the view. Printing the view in an
interactive session opens the page in the IDE's viewer or the browser.
The page is written by
[`aobcore::write_scene_html()`](https://rdrr.io/pkg/aobcore/man/write_scene_html.html)
and needs no server and no network: the data travel in the page as
native 'GeoArrow'.

## Usage

``` r
view(x, ...)

# S3 method for class 'sf'
view(
  x,
  ...,
  crs = NULL,
  densify = NULL,
  fill = NULL,
  stroke = NULL,
  stroke_width_px = NULL,
  radius_px = NULL,
  zcol = NULL,
  palette = NULL,
  breaks = NULL,
  na_colour = "#999999",
  legend = TRUE,
  popup = TRUE,
  name = NULL,
  file = NULL,
  theme = c("auto", "light", "dark")
)

# S3 method for class 'sfc'
view(
  x,
  ...,
  crs = NULL,
  densify = NULL,
  fill = NULL,
  stroke = NULL,
  stroke_width_px = NULL,
  radius_px = NULL,
  name = NULL,
  file = NULL,
  theme = c("auto", "light", "dark")
)
```

## Arguments

- x:

  A spatial object: an `sf` data frame or an `sfc` geometry column (with
  the 'sf' package installed); a 'terra' object
  ([view-terra](https://allboa.github.io/aobview/reference/view-terra.md));
  or a list of them
  ([view-layers](https://allboa.github.io/aobview/reference/view-layers.md)).

- ...:

  Not used by the `sf` and `sfc` methods: an argument caught here (a
  misspelled one, say) is an error.

- crs:

  The view CRS: anything
  [`sf::st_crs()`](https://r-spatial.github.io/sf/reference/st_crs.html)
  and
  [`aobcore::scene_crs()`](https://rdrr.io/pkg/aobcore/man/scene_crs.html)
  read, such as `"EPSG:3031"`, `3031` or a PROJ string. `NULL` (the
  default) uses
  [`view_crs()`](https://allboa.github.io/aobview/reference/view_crs.md).

- densify:

  Maximum edge length, in the units of `x`'s CRS, for lines and polygon
  edges before they are transformed. `NULL` (the default) densifies
  lon/lat data every 0.25 degrees when the view CRS differs, and nothing
  else; `FALSE` or `0` never densifies; a number densifies whenever the
  view CRS differs from `x`'s.

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
  default) for one colour. Not for an `sfc`, which has no columns.

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

  `TRUE` (the default) shows the attribute columns (the first 20) for a
  selected feature, a character vector names the columns to show, and
  `FALSE` shows none. See Popups.

- name:

  The layer name, shown as the page title. Defaults to the expression
  passed as `x`.

- file:

  Path of the HTML file to write. Defaults to a new file in the
  session's temporary directory.

- theme:

  `"auto"` follows the browser's light or dark preference; `"light"` or
  `"dark"` fixes it.

## Value

A view: a list of class `"aob_view"` with the `scene` (an
[`aobcore::scene()`](https://rdrr.io/pkg/aobcore/man/scene.html)), the
`file` it was written to, its `name` (the page title), `theme`, and
`extents`, each layer's extent in the view CRS (from which the initial
view is set). Add to it with
[`view_add()`](https://allboa.github.io/aobview/reference/view-layers.md).
Printing it opens the page when the session is interactive.

## Details

Points, lines and polygons (single or multi) are drawn as one layer
each. A mixed `GEOMETRY` or `GEOMETRYCOLLECTION` column is split into up
to three layers, polygons at the bottom, then lines, then points. Empty
geometries are dropped, as are Z and M values. The split layers share
the view's name, with the kind appended to each label, as in
`"mixed (polygons)"`.

'aobcore' does not reproject, so `x` is transformed to the view CRS here
with
[`sf::st_transform()`](https://r-spatial.github.io/sf/reference/st_transform.html).
When `x` is in lon/lat and the view CRS differs, lines and polygon edges
are first densified in lon/lat (every `densify` degrees, 0.25 by
default), so an edge along a parallel curves as it should in a polar
view instead of cutting across it.

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

# CCAMLR statistical areas (simplified, illustrative; see the extdata
# README) in EPSG:6932, coloured by area with popups, viewed in EPSG:3031
areas <- sf::st_read(system.file("extdata", "ccamlr_statistical_areas.geojson",
                                 package = "aobview"), quiet = TRUE)
areas$area <- paste0("Area ", substr(areas$GAR_Long_Label, 1, 2))
v6 <- view(areas, crs = "EPSG:3031", zcol = "area",
           popup = c("GAR_Name", "GAR_Long_Label", "GAR_Start_Date", "GAR_Size"))
v6 <- view_add(v6, coast, popup = FALSE)
vapply(v6$scene$legends[[1]]$classes, function(cl) cl$label, "")
#> [1] "Area 48" "Area 58" "Area 88"
if (FALSE) { # \dontrun{
v2
v3
} # }
```
