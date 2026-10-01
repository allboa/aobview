# Colours for attribute values

Maps values to RGBA colours, as
[`view()`](https://allboa.github.io/aobview/reference/view.md) does for
`zcol`: a continuous palette for numbers, one colour per level for
factors, character and logical values. Colours are computed in R and
travel to the page as a per-feature RGBA column (styling is data, scene
spec 0.1), so this is all the colouring there is; legends can be drawn
from the same result.

## Usage

``` r
view_colours(values, palette = NULL, breaks = NULL, na_colour = "#999999")
```

## Arguments

- values:

  A numeric, factor, character or logical vector.

- palette:

  A palette name or a function. A name is one of
  [`grDevices::palette.pals()`](https://rdrr.io/r/grDevices/palette.html)
  (fixed sets such as `"Tableau 10"` or `"Okabe-Ito"`, stretched by
  interpolation for numbers) or of
  [`grDevices::hcl.pals()`](https://rdrr.io/r/grDevices/palettes.html)
  (such as `"viridis"` or `"Dark 3"`), matched ignoring case, spaces and
  hyphens. A function takes a number `n` and returns `n` colours
  [`grDevices::col2rgb()`](https://rdrr.io/r/grDevices/col2rgb.html)
  reads, such as
  [`grDevices::hcl.colors()`](https://rdrr.io/r/grDevices/palettes.html)
  or `function(n) hcl.colors(n, "Blues 3", alpha = 0.7)`. `NULL` (the
  default) is `"viridis"` for numbers and `"Tableau 10"` for levels.

- breaks:

  For numbers only: increasing break points (at least two) that bin the
  values into classes, one colour each. `NULL` colours continuously.

- na_colour:

  The colour for `NA`: anything
  [`grDevices::col2rgb()`](https://rdrr.io/r/grDevices/col2rgb.html)
  reads, or `c(r, g, b, a)` integers 0 to 255.

## Value

An integer matrix with one row per value and columns `r`, `g`, `b`, `a`
(0 to 255). Its `"key"` attribute describes the mapping for a legend: a
list with `type` (`"continuous"`, `"binned"` or `"categorical"`),
`colours` (hex strings: 33 evenly spaced along the palette for
continuous, else one per class or level), `na_colour`, and `range`
(continuous), `breaks` (binned) or `levels` (categorical).

## Details

**Numbers** (integer or double) are coloured along the palette from the
lowest finite value to the highest, or, with `breaks`, one colour per
interval (closed on the right, the lowest closed on both sides; values
outside the breaks get `na_colour`). A column of one value takes the
palette's middle colour.

**Levels.** A factor's levels in their order (unused levels keep their
colour, so a subset colours alike), the sorted unique values of a
character vector, and `FALSE`, `TRUE` for a logical. When a palette has
fewer colours than there are levels, its colours are recycled, with a
message.

`NA` (and `NaN`, `Inf`, `-Inf` for numbers) gets `na_colour`.

## See also

[`view()`](https://allboa.github.io/aobview/reference/view.md), whose
`zcol` argument uses this.

## Examples

``` r
view_colours(c(1, 5, NA, 10))
#>        r   g   b   a
#> [1,]  75   0  85 255
#> [2,]   0 141 152 255
#> [3,] 153 153 153 255
#> [4,] 253 227  51 255
#> attr(,"key")
#> attr(,"key")$type
#> [1] "continuous"
#> 
#> attr(,"key")$range
#> [1]  1 10
#> 
#> attr(,"key")$colours
#>  [1] "#4B0055FF" "#4A085DFF" "#481965FF" "#45266CFF" "#403173FF" "#383B7AFF"
#>  [7] "#2D4580FF" "#1A4F86FF" "#00588BFF" "#00618FFF" "#006A92FF" "#007395FF"
#> [13] "#007C97FF" "#008498FF" "#008C98FF" "#009497FF" "#009B95FF" "#00A293FF"
#> [19] "#00A98FFF" "#00B08BFF" "#00B686FF" "#00BC7FFF" "#00C278FF" "#2CC770FF"
#> [25] "#52CC67FF" "#6ED15DFF" "#87D553FF" "#9DD947FF" "#B2DC3CFF" "#C6DF32FF"
#> [31] "#D9E12CFF" "#ECE32CFF" "#FDE333FF"
#> 
#> attr(,"key")$na_colour
#> [1] "#999999FF"
#> 
view_colours(c("b", "a", "b"), palette = "Okabe-Ito")
#>        r   g b   a
#> [1,] 230 159 0 255
#> [2,]   0   0 0 255
#> [3,] 230 159 0 255
#> attr(,"key")
#> attr(,"key")$type
#> [1] "categorical"
#> 
#> attr(,"key")$levels
#> [1] "a" "b"
#> 
#> attr(,"key")$colours
#> [1] "#000000FF" "#E69F00FF"
#> 
#> attr(,"key")$na_colour
#> [1] "#999999FF"
#> 
view_colours(c(0.1, 2.5, 7), palette = grDevices::terrain.colors, breaks = c(0, 1, 5, 10))
#>        r   g   b   a
#> [1,]   0 166   0 255
#> [2,] 236 177 118 255
#> [3,] 242 242 242 255
#> attr(,"key")
#> attr(,"key")$type
#> [1] "binned"
#> 
#> attr(,"key")$breaks
#> [1]  0  1  5 10
#> 
#> attr(,"key")$colours
#> [1] "#00A600FF" "#ECB176FF" "#F2F2F2FF"
#> 
#> attr(,"key")$na_colour
#> [1] "#999999FF"
#> 
attr(view_colours(c(TRUE, FALSE, NA)), "key")$levels
#> [1] "FALSE" "TRUE" 
```
