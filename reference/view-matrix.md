# View a matrix or array as a raster

[`view()`](https://allboa.github.io/aobview/reference/view.md) of a
matrix draws it as a raster on a regular grid: `extent` gives the outer
edges of its cells, `c(xmin, xmax, ymin, ymax)`, and `crs` the CRS those
edges are in. That is what holders of a plain matrix (from 'tidync',
'ncdf4', 'vaster', or any array computation) already know, and no raster
package is needed. A numeric or logical matrix is drawn as one band
through a palette; a three-dimensional array of 3 or 4 bands as a colour
image. Palettes, range and legend work as for a one-layer `SpatRaster`
(see
[view-terra](https://allboa.github.io/aobview/reference/view-terra.md)).

## Usage

``` r
# S3 method for class 'matrix'
view(
  x,
  ...,
  extent,
  crs,
  palette = NULL,
  range = NULL,
  legend = TRUE,
  name = NULL,
  file = NULL,
  theme = c("auto", "light", "dark"),
  transport = getOption("aobview.transport", "auto")
)

# S3 method for class 'array'
view(
  x,
  ...,
  extent,
  crs,
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

  A numeric or logical matrix (rows from the top, see Orientation), or a
  three-dimensional array of 1, 3 or 4 bands.

- ...:

  Passed to
  [`aobcore::cog_plan()`](https://rdrr.io/pkg/aobcore/man/cog_plan.html)
  when `x` takes the tiled path (see Untiled or tiled). An argument
  caught here when `x` is drawn untiled is an error.

- extent:

  The outer edges of the grid, `c(xmin, xmax, ymin, ymax)`, in `crs`
  units. Required.

- crs:

  The CRS of `extent` (the grid's CRS, not the view's): anything
  [`aobcore::scene_crs()`](https://rdrr.io/pkg/aobcore/man/scene_crs.html)
  reads. Required.

- palette:

  A palette name the renderer knows: `"viridis"` (the default),
  `"ocean"`, `"ice"` or `"gray"`. Not for a colour image.

- range:

  `c(low, high)`: the values at the ends of the palette; by default the
  range of the values. For a colour image of a type other than Byte, the
  values drawn as zero and full intensity.

- legend:

  `TRUE` (the default) keys the palette with a ramp and `FALSE` leaves
  it out (see Legend in
  [view-terra](https://allboa.github.io/aobview/reference/view-terra.md)).
  A colour image has no legend.

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

**Orientation.** Row 1 of the matrix is the top of the grid (the row at
`ymax`) and column 1 its left edge (at `xmin`), as in 'terra' and
'vaster': `x[1, 1]` is the top-left cell, as the matrix prints. A matrix
built from a column-major source (a NetCDF variable read with `ncdf4`,
where the first dimension is often longitude and the first row the
southernmost) needs transposing or flipping first, as it would for
[`terra::rast()`](https://rspatial.github.io/terra/reference/rast.html).

**Untiled or tiled.** A matrix of at most 512 by 512 cells (one tile of
a temporary COG, the threshold
[view-terra](https://allboa.github.io/aobview/reference/view-terra.md)
applies) whose `crs` is the view CRS goes into the page as an untiled
scene spec 0.1 `raster` layer: the grid descriptor (its extent,
dimensions and CRS) and the cell values as one Arrow column, row by row
from the top. Above that size, or when the view CRS differs from `crs`
(a lon/lat matrix south of 40S, say, which
[`view_crs()`](https://allboa.github.io/aobview/reference/view_crs.md)
draws in EPSG:3031), the matrix is written to a temporary COG with
'gdalraster' (one Float32 band, missing cells as the no-data value) in
`file.path(tempdir(), "aobview-cogs")` and takes the tiled path of
[view-terra](https://allboa.github.io/aobview/reference/view-terra.md):
[`aobcore::cog_plan()`](https://rdrr.io/pkg/aobcore/man/cog_plan.html)
plans its tiles with a mesh projected to the view CRS, and the tiles are
embedded in the page or served (see Transport in
[`view()`](https://allboa.github.io/aobview/reference/view.md)). A
colour image always takes the tiled path, since the untiled layer draws
one band. `...` goes to
[`aobcore::cog_plan()`](https://rdrr.io/pkg/aobcore/man/cog_plan.html)
on the tiled path (`max_tiles`, `max_stretch`, `tolerance`, ...); on the
untiled path there is no plan, so an argument there is an error.

**Colour.** An array with `dim(x)[3]` of 3 or 4 is drawn as red, green,
blue (and alpha): as Byte when every value is a whole number from 0 to
255, with missing cells transparent (an alpha band is added when one is
missing), else as Float32 over `range` (the values drawn as zero and
full intensity; by default the range of the three colour bands). A
colour image has no legend. An array with one band is drawn as the
matrix `x[, , 1]`.

**CRS.** `crs` is the CRS of `extent`, read as
[`aobcore::scene_crs()`](https://rdrr.io/pkg/aobcore/man/scene_crs.html)
reads it: `"EPSG:3031"`, `3031`, WKT or a PROJ string. The view CRS
follows
[`view_crs()`](https://allboa.github.io/aobview/reference/view_crs.md)'s
rule from it: a projected `crs` is kept, and a lon/lat one is drawn in
EPSG:3031 or EPSG:3413 when the extent lies south of 40S or north of
60N, else flat. A matrix has no CRS of its own, so it cannot be an
element of `view(list(...))`; add it to a view with
[`view_add()`](https://allboa.github.io/aobview/reference/view-layers.md),
where `crs` is the grid's, as here, and the view's CRS stays what it
was.

## See also

[view-terra](https://allboa.github.io/aobview/reference/view-terra.md)
for the tiled path;
[`view_crs()`](https://allboa.github.io/aobview/reference/view_crs.md)
for the view CRS.

## Examples

``` r
# A 20 x 30 field in EPSG:3031 around the pole: row 1 is the north edge.
m <- outer(seq(-1, 1, length.out = 20), seq(-1, 1, length.out = 30),
           function(y, x) cos(3 * x) * sin(2 * y))
v <- view(m, extent = c(-3e6, 3e6, -2e6, 2e6), crs = "EPSG:3031")
v$scene$layers[[1]]$kind
#> [1] "raster"
v$scene$layers[[1]]$grid$dim
#> [1] 30 20

# A mask: a logical matrix draws as 0 and 1.
v2 <- view(m > 0, extent = c(-3e6, 3e6, -2e6, 2e6), crs = 3031, palette = "gray")
v2$scene$layers[[1]]$palette$range
#> [1] 0 1
# A colour image: three bands, 0 to 255, through a temporary COG.
img <- array(0, c(20, 30, 3))
img[, , 1] <- 255 * (m + 1) / 2
img[, , 2] <- 255 * (1 - (m + 1) / 2)
img[, , 3] <- 120
v3 <- view(img, extent = c(-3e6, 3e6, -2e6, 2e6), crs = "EPSG:3031")
v3$scene$layers[[1]]$kind
#> [1] "tiled_raster"
v3$scene$layers[[1]]$rgb
#> $bands
#> [1] 1 2 3
#> 
#> $range
#> [1]   0.6858282 254.3142000
#> 
```
