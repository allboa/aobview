# The default view CRS for spatial data

The CRS [`view()`](https://allboa.github.io/aobview/reference/view.md)
draws in when `crs` is not given. The project is polar first, and a view
in the data's own CRS is preferred to a reprojection, so the rule is:

## Usage

``` r
view_crs(x)
```

## Arguments

- x:

  Geometry 'wk' can handle or a data frame with such a column (an `sf`
  object, say), an Arrow stream or table (read once, here: see Arrow
  streams in
  [`view()`](https://allboa.github.io/aobview/reference/view.md)), an
  `OGRFeatureSet`, a 'terra' `SpatRaster` or `SpatVector`, or a list of
  them.

## Value

A CRS for
[`aobcore::scene()`](https://rdrr.io/pkg/aobcore/man/scene.html): an
`"authority:code"` string such as `"EPSG:3031"`, or, when the data's CRS
has no code, its WKT.

## Details

1.  A **projected** CRS is kept: the data are drawn in their own CRS.

2.  **Lon/lat** data lying entirely south of 40S (the bounding box's
    northern edge at or below -40) are drawn in EPSG:3031, Antarctic
    Polar Stereographic. This covers Antarctica, the Southern Ocean
    south of the Subtropical Front, and circumpolar data such as a
    coastline south of 40S, all of which a lon/lat view tears apart at
    the pole.

3.  Lon/lat data lying entirely north of 60N are drawn in EPSG:3413,
    NSIDC Sea Ice Polar Stereographic North. The northern threshold is
    stricter than the southern one because much mid-latitude land lies
    between 40N and 60N, where a polar view turns the map away from
    north-up; south of 40S there is little land other than Antarctica.

4.  Other lon/lat data are drawn in their own lon/lat CRS, flat (plate
    carree), which the scene spec allows. Web Mercator is not used: it
    cannot show the poles, and a tiled Mercator basemap is a non-goal.

For a raster the bounding box is the grid's extent, so a lon/lat grid
from 90S to 40S, whose northern edge is at 40S, is drawn in EPSG:3031.

For a list of objects (see
[view-layers](https://allboa.github.io/aobview/reference/view-layers.md))
the rule is applied once to the whole list: the CRS of the first object
with a projected CRS is kept; when every object is in lon/lat, rules 2
to 4 apply to their combined latitude range, and rule 4 keeps the first
object's CRS.

Data with no CRS is an error: set one first (for example
[`wk::wk_set_crs()`](https://paleolimbot.github.io/wk/reference/wk_crs.html),
[`sf::st_set_crs()`](https://r-spatial.github.io/sf/reference/st_crs.html)
or `terra::crs<-`), or pass `crs` to
[`view()`](https://allboa.github.io/aobview/reference/view.md). Whether
a CRS is lon/lat is read by 'PROJ'.

## Examples

``` r
coast <- sf::st_read(system.file("extdata", "coastline_south_40s.geojson",
                                 package = "aobcore"), quiet = TRUE)
view_crs(coast)
#> [1] "EPSG:3031"
nc <- sf::st_read(system.file("shape", "nc.shp", package = "sf"), quiet = TRUE)
view_crs(nc)
#> [1] "EPSG:4267"
```
