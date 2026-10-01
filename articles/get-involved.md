# Get involved

allonboard is early, and the most useful help right now is people trying
it on their own data and saying what happened. You do not need to know
the internals to do that.

## Try it

``` r

# install.packages("remotes")
remotes::install_github("allboa/aobview")
library(aobview)
view(your_sf_object)
```

[Get started](https://allboa.github.io/aobview/articles/aobview.md) has
examples to copy. Some things worth trying:

- Polar data, in the south or the north, in longitude and latitude or
  already projected.
- A remote Cloud Optimized GeoTIFF read with
  `terra::rast("/vsicurl/...")` (the server must allow CORS for the
  browser to fetch tiles).
- A CRS you care about, with `crs =`.
- Large vector data, to see where it slows down.

## Report what you find

Open an issue in the repository that fits, with the code you ran, your
platform, and a screenshot if it is about drawing:

- [aobview issues](https://github.com/allboa/aobview/issues):
  [`view()`](https://allboa.github.io/aobview/reference/view.md),
  palettes, legends, popups, choosing the view CRS.
- [aobcore issues](https://github.com/allboa/aobcore/issues): reading
  data, COG tiles, the page and the renderer.
- [scenespec issues](https://github.com/allboa/scenespec/issues): what a
  scene can describe.
- [design issues](https://github.com/allboa/design/issues): the
  direction of the project and its decisions.

Warnings about tile budgets or tiles that cannot be projected are left
noisy on purpose while the planner’s trade-offs are evaluated; reports
of when they appear are welcome.

## Contribute

Read the brief first:
[AGENTS.md](https://github.com/allboa/design/blob/main/AGENTS.md) in the
design repository. It is written for coding agents, and people are
welcome to follow the same flow. In short:

- Work starts from an issue with acceptance criteria; comment to claim
  it.
- One issue, one branch, one pull request that says how the criteria
  were checked.
- Rendering changes come with a screenshot, tested in EPSG:3031 first.
- Keep dependencies lean and package sources ASCII.

Much of the day-to-day work in these repositories is done by AI coding
agents working from issues, with the maintainer setting direction and
making the gate decisions. Human contributions follow the same flow and
are very welcome.

## Known gaps

- Package names are placeholders, and nothing is on CRAN.
- On macOS, CRAN’s gdalraster binary cannot find its PROJ database, so
  raster views need gdalraster from conda-forge.
- Seams and the antimeridian in some projections are open work.
