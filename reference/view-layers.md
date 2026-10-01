# View several layers in one page

[`view()`](https://allboa.github.io/aobview/reference/view.md) of a list
draws each element as one or more layers of a single scene, in one view
CRS, in list order: the first element at the bottom. `view_add()` adds a
layer to a view already made, on top, and writes a new page, or, for a
served view (see Transport in
[`view()`](https://allboa.github.io/aobview/reference/view.md)), serves
the new scene on the same server, at the same URL: a page open on it
reloads itself with the new scene and keeps its camera, the selection is
cleared, and the view given to `view_add()` is replaced (the selection
functions,
[`selection()`](https://allboa.github.io/aobview/reference/selection.md),
are errors on it; use the view returned). An embedded view whose local
raster tiles pass the threshold with the new layer becomes served (its
earlier page stays on disk). `view(a) |> view_add(b)` gives the same
scene as `view(list(a = a, b = b))` when the two have the same view CRS,
that is when `view_crs(a)` equals `view_crs(list(a, b))`, as it does
whenever `a` is projected, or `a` and `b` are both lon/lat south of 40S
(or both north of 60N). Otherwise they differ: `view_add()` keeps `a`'s
view CRS, while the list's CRS is chosen from every element (below).
Pass `crs =` to either form to fix it.

## Usage

``` r
# S3 method for class 'list'
view(
  x,
  ...,
  crs = NULL,
  name = NULL,
  file = NULL,
  theme = c("auto", "light", "dark"),
  transport = getOption("aobview.transport", "auto")
)

view_add(
  v,
  x,
  ...,
  name = NULL,
  file = NULL,
  theme = NULL,
  transport = getOption("aobview.transport", "auto")
)
```

## Arguments

- x:

  For [`view()`](https://allboa.github.io/aobview/reference/view.md), a
  list of spatial objects. For `view_add()`, one spatial object (or a
  list of them) to add.

- ...:

  For [`view()`](https://allboa.github.io/aobview/reference/view.md) of
  a list, nothing (per-layer arguments go to `view_add()`). For
  `view_add()`, the arguments
  [`view()`](https://allboa.github.io/aobview/reference/view.md) or
  [view-terra](https://allboa.github.io/aobview/reference/view-terra.md)
  take for `x`'s class, such as `fill` or `zcol` for `sf` data or
  `palette` for a `SpatRaster`.

- crs:

  The view CRS, as for
  [`view()`](https://allboa.github.io/aobview/reference/view.md). `NULL`
  uses
  [`view_crs()`](https://allboa.github.io/aobview/reference/view_crs.md)
  of the list.

- name:

  The page title. For a list, defaults to the layer labels joined by
  commas. For `view_add()`, the new layer's name, which defaults to the
  expression passed as `x`; the page title becomes the view's name and
  this one, joined by a comma.

- file:

  Path of the HTML file to write. Defaults to a new file in the
  session's temporary directory. `view_add()` leaves `v`'s page as it
  is. Not used by a served view (with a warning).

- theme:

  As for [`view()`](https://allboa.github.io/aobview/reference/view.md).
  `view_add()` defaults to `v`'s theme.

- transport:

  As for [`view()`](https://allboa.github.io/aobview/reference/view.md).
  For `view_add()`, how the new layers are carried: on a served view,
  `"embed"` embeds a new local COG's tiles (the server delivers them as
  blobs) and `"auto"` or `"serve"` serve its file; the view stays served
  either way.

- v:

  A view from
  [`view()`](https://allboa.github.io/aobview/reference/view.md) or
  `view_add()`.

## Value

A view, as for
[`view()`](https://allboa.github.io/aobview/reference/view.md).

## Details

Elements may be any vector input
[`view()`](https://allboa.github.io/aobview/reference/view.md) takes
(geometry 'wk' can handle, or a data frame with such a column, `sf`
included) and 'terra' `SpatRaster` or `SpatVector` objects, in any mix
of CRSs. Each is drawn as
[`view()`](https://allboa.github.io/aobview/reference/view.md) or
[view-terra](https://allboa.github.io/aobview/reference/view-terra.md)
draws it on its own, with its default style, and reprojected to the view
CRS: vectors by 'PROJ' (lon/lat edges densified first), rasters by
[`aobcore::cog_plan()`](https://rdrr.io/pkg/aobcore/man/cog_plan.html)'s
meshes.

**View CRS.** `crs` when given; otherwise
[`view_crs()`](https://allboa.github.io/aobview/reference/view_crs.md)
of the whole list: the CRS of the first element with a projected CRS,
or, when every element is in lon/lat, the lon/lat rule applied once to
their combined latitude range. `view_add()` keeps the view's CRS and
reprojects `x` to it; it warns when that puts projected vector data into
a geographic view (decision 0004 rules out that per-coordinate
transform), and a `crs` argument to it is an error.

**Names.** List names become layer labels and, made valid and unique,
layer ids. An unnamed element takes the expression that gave it in a
call such as `view(list(coast, r))`, else `x[[i]]`. When an id is taken,
`_2`, `_3`, ... is appended.

**Initial view.** The union of the layers' extents in the view CRS,
clipped to the view's domain
([`aobcore::crs_domain()`](https://rdrr.io/pkg/aobcore/man/crs_domain.html),
carried as the scene's `view.bounds`, allboa/design decision 0005). The
scene's spec version is the highest any of its layers or its view needs.

For a style of your own on one layer, such as colour by attribute
(`zcol`), start with
[`view()`](https://allboa.github.io/aobview/reference/view.md) of it or
add it with `view_add()`, which take each kind's arguments.

## See also

[`view()`](https://allboa.github.io/aobview/reference/view.md),
[view-terra](https://allboa.github.io/aobview/reference/view-terra.md),
[`view_crs()`](https://allboa.github.io/aobview/reference/view_crs.md).

## Examples

``` r
coast <- sf::st_read(system.file("extdata", "coastline_south_40s.geojson",
                                 package = "aobcore"), quiet = TRUE)
stations <- sf::st_sfc(sf::st_point(c(110.53, -66.28)), sf::st_point(c(77.97, -68.58)),
                       crs = "OGC:CRS84")
v <- view(list(coast = coast, stations = stations))
vapply(v$scene$layers, function(l) l$id, "")
#> [1] "coast"    "stations"

v2 <- view_add(view(coast), stations, fill = c(220, 60, 40, 255))
v2$scene$layers[[2]]$fill
#> [1] 220  60  40 255

sites <- sf::st_sf(base = c("Casey", "Davis"), geometry = stations)
v3 <- view_add(view(coast), sites, zcol = "base")
v3$scene$layers[[2]]$fill
#> $column
#> [1] "color"
#> 
sst <- terra::rast(system.file("extdata", "polar_3031.tif", package = "aobcore"))
v3 <- view(list(sst = sst, coast = coast))
v3$scene$view$crs
#> [1] "EPSG:3031"
```
