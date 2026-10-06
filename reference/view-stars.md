# View a stars raster

[`view()`](https://allboa.github.io/aobview/reference/view.md) of a
'stars' object draws one attribute of a regular grid as a raster
(allboa/aobview#38, allboa/design decision 0011). A `stars_proxy`
carries file paths, so it routes as a `SpatRaster` read from a file
does: a proxy over a Cloud Optimized GeoTIFF, local or remote, is
planned from that file with
[`aobcore::cog_plan()`](https://rdrr.io/pkg/aobcore/man/cog_plan.html)
and never copied (a remote one is referenced by URL); a proxy over
another raster GDAL opens is read through GDAL into a temporary COG (see
Strings in
[`view()`](https://allboa.github.io/aobview/reference/view.md)). An
in-memory `stars` object is a matrix with an extent and CRS, and takes
the route of
[view-matrix](https://allboa.github.io/aobview/reference/view-matrix.md):
a grid of at most 512 by 512 cells in the view CRS goes into the page
untiled, and a larger or reprojected one (a lon/lat grid south of 40S,
say, which
[`view_crs()`](https://allboa.github.io/aobview/reference/view_crs.md)
draws in EPSG:3031) is written to a temporary COG with 'gdalraster' and
tiled. Palettes, range and legend work as for a one-layer `SpatRaster`
(see
[view-terra](https://allboa.github.io/aobview/reference/view-terra.md));
`...` goes to
[`aobcore::cog_plan()`](https://rdrr.io/pkg/aobcore/man/cog_plan.html)
on the tiled routes, and is an error on the untiled one. No 'terra' is
needed.

## Usage

``` r
# S3 method for class 'stars'
view(
  x,
  ...,
  crs = NULL,
  layer = NULL,
  palette = NULL,
  range = NULL,
  legend = TRUE,
  name = NULL,
  file = NULL,
  theme = c("auto", "light", "dark"),
  transport = getOption("aobview.transport", "auto")
)

# S3 method for class 'stars_proxy'
view(
  x,
  ...,
  crs = NULL,
  layer = NULL,
  palette = NULL,
  range = NULL,
  legend = TRUE,
  name = NULL,
  file = NULL,
  theme = c("auto", "light", "dark"),
  transport = getOption("aobview.transport", "auto")
)
```

## Arguments

- x:

  A 'stars' object: a regular raster grid in memory, or a `stars_proxy`
  over one or more files
  ([`stars::read_stars()`](https://r-spatial.github.io/stars/reference/read_stars.html)
  with `proxy = TRUE`).

- ...:

  Passed to
  [`aobcore::cog_plan()`](https://rdrr.io/pkg/aobcore/man/cog_plan.html)
  when `x` is tiled (a proxy drawn from its file, or an in-memory grid
  larger than 512 by 512 or not in the view CRS): `max_tiles`,
  `max_stretch`, `tolerance`, ... An argument caught here when `x` is
  drawn untiled is an error.

- crs:

  The view CRS: anything
  [`aobcore::scene_crs()`](https://rdrr.io/pkg/aobcore/man/scene_crs.html)
  and 'PROJ' read, such as `"EPSG:3031"`, `3031` or a PROJ string.
  `NULL` (the default) uses
  [`view_crs()`](https://allboa.github.io/aobview/reference/view_crs.md).
  A stream whose geometry has no CRS in its GeoArrow metadata is taken
  to be in `crs` (see Arrow streams).

- layer:

  The attribute to draw when `x` has several, else the slice along its
  dimension beyond `x` and `y`, as a name or a number (see Attributes
  and bands). `NULL` (the default) draws the first.

- palette:

  A palette name the renderer knows: `"viridis"` (the default),
  `"ocean"`, `"ice"` or `"gray"`.

- range:

  `c(low, high)`: the values at the ends of the palette; by default the
  range of the values (of the COG's coarsest level for a proxy drawn
  from its file).

- legend:

  `TRUE` (the default) keys the palette with a ramp and `FALSE` leaves
  it out (see Legend in
  [view-terra](https://allboa.github.io/aobview/reference/view-terra.md)).

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

## Value

A view, as for
[`view()`](https://allboa.github.io/aobview/reference/view.md).

## Details

**Which proxy is drawn from its file.** A proxy whose attribute is one
file, read whole (its `x` and `y` dimensions are the file's, with no
pending operation such as `x * 2`) in the file's own CRS, is drawn from
that file, exactly as the file's path would be (see Strings in
[`view()`](https://allboa.github.io/aobview/reference/view.md)): a COG
as it is, any other raster through GDAL. A proxy sliced to one band
(`x[, , , 2]`) draws that band. Any other proxy (a crop, a computation,
several files along a dimension, a changed CRS) is read into memory with
[`stars::st_as_stars()`](https://r-spatial.github.io/stars/reference/st_as_stars.html)
and drawn as an in-memory object is, as a computed or cropped
`SpatRaster` goes to a temporary COG. A proxy over a colour COG (3 or 4
Byte bands with red, green, blue colour interpretation) draws as a
colour image unless `layer` or `palette` is given.

**Attributes and bands.** One band is drawn through the palette. An
object with several attributes draws the first, or the one `layer` names
or numbers. An object with one attribute and one dimension beyond `x`
and `y` (`band`, `time`, ...) draws the first slice along it, or the one
`layer` picks by number, or by name among that dimension's values. An
object with several attributes and such a dimension draws the first
slice of the chosen attribute; with more than one dimension beyond `x`
and `y` of more than one element, slice it first (`x[, , , 1, 2]`, or
`dplyr::slice()`; a dimension of one element is not counted). A factor
attribute draws its codes, a `units` attribute its numbers.

**Orientation.** 'stars' stores an attribute as an array with `x` first
and `y` second, and the grid's `y` `delta` is usually negative (the
offset is the top edge). The matrix route takes rows from the top, so
the array is transposed here, and flipped when `delta` is positive (or
negative for `x`): `x[[1]][i, j]` is the cell at column `i` from the
left and row `j` from the `y` offset, as 'stars' means it, whichever way
the offsets run.

**Out of scope for now.** Curvilinear grids (`x` and `y` as matrices),
rectilinear grids (an `x` or `y` dimension with explicit cell edges
rather than one `delta`), sheared or rotated grids (a non-zero affine),
and vector data cubes (a dimension of simple features) are not drawn
(allboa/design decision 0010, item 5); each is an error that says so.
Warp a curvilinear or rectilinear grid to a regular one with
[`stars::st_warp()`](https://r-spatial.github.io/stars/reference/st_warp.html)
first, or draw a vector cube's geometries with `view(sf::st_as_sf(x))`.

**CRS.** The view CRS follows
[`view_crs()`](https://allboa.github.io/aobview/reference/view_crs.md)'s
rule from the object's own CRS
([`sf::st_crs()`](https://r-spatial.github.io/sf/reference/st_crs.html)),
as for a `SpatRaster`: a projected CRS is kept, a lon/lat grid south of
40S or north of 60N is drawn in a polar view. An object with no CRS is
an error. A `stars` object has an extent and CRS of its own, so it can
be an element of `view(list(...))` and added to a view with
[`view_add()`](https://allboa.github.io/aobview/reference/view-layers.md)
with no further argument.

## See also

[view-matrix](https://allboa.github.io/aobview/reference/view-matrix.md)
for the in-memory route and its orientation;
[view-terra](https://allboa.github.io/aobview/reference/view-terra.md)
for the tiled route;
[`view_crs()`](https://allboa.github.io/aobview/reference/view_crs.md)
for the view CRS.

## Examples

``` r
# A proxy over a COG: planned from the file, never copied.
f <- system.file("extdata", "polar_3031.tif", package = "aobcore")
p <- stars::read_stars(f, proxy = TRUE)
v <- view(p, palette = "ocean")
v$scene$layers[[1]]$kind
#> [1] "tiled_raster"
v$scene$data[[1]]$url
#> [1] "polar_3031.tif"

# A small grid in memory, in EPSG:3031: untiled, in the page.
bb <- sf::st_bbox(c(xmin = -3e6, xmax = 3e6, ymin = -2e6, ymax = 2e6),
                  crs = sf::st_crs(3031))
s <- stars::st_as_stars(bb, nx = 30, ny = 20, values = seq_len(600))
v2 <- view(s)
v2$scene$layers[[1]]$kind
#> [1] "raster"
```
