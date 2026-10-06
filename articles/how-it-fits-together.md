# How it fits together

aobview is the friendly front end of **allonboard**, a project to give R
a fast map viewer that draws data in its own coordinate reference system
(CRS), polar views included. This page explains the pieces, so you can
tell where a question or a contribution belongs. All of it is early and
still being worked out.

## The idea

The classic R route to an interactive map turned data into GeoJSON text,
which the browser parsed into objects and drew on a Web Mercator
basemap. Two things have changed:

- **GeoArrow.** Coordinates can travel to the browser as Arrow buffers
  that become typed arrays with no parsing, and deck.gl can bind them
  straight into GPU memory.
- **The GPU does not care about Web Mercator.** Only tiled basemaps do.
  Drawn in projected metres, data can be shown in any CRS: polar
  stereographic, equal-area, or the data’s own.

So R prepares a *scene* (the view CRS, the layers, the data references
and styling as data) and the browser draws it. Where it can, R sends a
recipe, such as the URL of a Cloud Optimized GeoTIFF and a tile plan,
rather than the data itself.

## The repositories

| Repository | What it holds |
|----|----|
| [aobview](https://github.com/allboa/aobview) | `view(x)` for sf and terra, palettes, legends and popups. This site. |
| [aobcore](https://github.com/allboa/aobcore) | The lean core: producers to GeoArrow and grid descriptors, COG tile planning, scene building, the self-contained page, and the bundled renderer. |
| [scenespec](https://github.com/allboa/scenespec) | The scene spec: a JSON Schema with fixtures, a validator and conformance scenes. It has no renderer-specific terms, so another renderer can implement it. |
| [design](https://github.com/allboa/design) | The origin post and charter, decision records, and the brief every contributor reads first. |
| [spikes](https://github.com/allboa/spikes) | Throwaway experiments; each ends in a decision record. |

The package names are placeholders until a naming decision.

## How a view is made

1.  `view(x)` picks a view CRS
    ([`view_crs()`](https://allboa.github.io/aobview/reference/view_crs.md)),
    reprojects vectors with sf (densifying lon/lat edges), and computes
    colours, legends and popup columns in R.
2.  aobcore turns vectors into native GeoArrow streams, and plans raster
    tiles from a COG: which tiles each part of the view needs, with
    meshes projected to the view CRS (decision 0003).
3.  aobcore writes the scene and its data into one HTML page with the
    bundled deck.gl renderer. A remote COG stays remote: the page
    fetches its tiles by range request.

The core depends on nanoarrow, geoarrow, wk and htmltools, and little
else. gdalraster is the suggested producer for GDAL sources and COGs.

## Where lonboard comes in

[lonboard](https://developmentseed.org/lonboard/) puts deck.gl and
GeoArrow behind a Python notebook widget, and it moves in step with the
deck.gl-geoarrow and deck.gl-raster libraries. It does not draw in a
custom CRS today: layers are reprojected to longitude and latitude.
aobcore’s renderer uses plain deck.gl layers for now.

allonboard keeps the door to that stack open. The scene spec is
renderer-neutral, so an R front end could later share lonboard’s
JavaScript stack (the “go large” option in the design post), and the
renderer work needed for polar and other projected views, such as
non-Mercator tile loading in deck.gl-raster, is meant to go upstream
where Python users benefit too. A Python front end is not a goal of v1.

## Where the raster approach comes from

Texture mapping has a long history, and so does using textures to carry
an image through different coordinate systems: world, index, the surface
of a solid, a new CRS. None of that is new; it just was not available in
R as a thing. After working with texture mapping in commercial software
in the late 2000s, Michael Sumner carried the idea into R through the
packages gris, then [silicate](https://github.com/hypertidy/silicate),
then [anglr](https://github.com/hypertidy/anglr), which builds meshes
from spatial data and draws them with rgl, textured images included. rgl
already did the texture mapping; it needed only light helpers, such as
mapping values to colours, to make it geospatial. anglr was partly an
effort to show what this could do.

deck.gl-raster draws reprojected tiles the same way, as a projected mesh
with uv coordinates and the tile as its texture, and aobcore uses that
approach for rasters in polar and other projected views (decision 0003).

## Decisions so far

The design repository records each decision. Most are still proposed; an
accepted one has been settled by the maintainer.

- [0001](https://github.com/allboa/design/blob/main/decisions/0001-rasterlayer-3031.md):
  deck.gl-raster’s RasterLayer draws in EPSG:3031; lon/lat over the pole
  needs a fix (proposed).
- [0002](https://github.com/allboa/design/blob/main/decisions/0002-gdalraster-geoarrow.md):
  gdalraster streams native GeoArrow from Arrow layers only (proposed).
- [0003](https://github.com/allboa/design/blob/main/decisions/0003-tiled-cog-polar.md):
  tiled COGs reach a polar view as R-planned tiles, for v1 (accepted,
  gate A).
- [0004](https://github.com/allboa/design/blob/main/decisions/0004-vector-reprojection.md):
  GDAL reprojects what it reads; wk and PROJ for data already in R
  (proposed).
- [0005](https://github.com/allboa/design/blob/main/decisions/0005-view-domain.md):
  a default view domain from the projection’s centre (accepted).
- [0006](https://github.com/allboa/design/blob/main/decisions/0006-local-server-transport.md):
  a local server transport for large local data (proposed).
- [0007](https://github.com/allboa/design/blob/main/decisions/0007-websocket-selections.md):
  selections and events from the page to R over a websocket (proposed).
- [0008](https://github.com/allboa/design/blob/main/decisions/0008-wk-first-vector-input.md):
  wk-first vector input, PROJ as the reprojection engine (accepted).
- [0009](https://github.com/allboa/design/blob/main/decisions/0009-documents-and-shiny.md):
  views in knitted documents and in Shiny (proposed).
- [0010](https://github.com/allboa/design/blob/main/decisions/0010-input-layer-stance.md):
  where grid input comes from and what to add next: R sends recipes,
  R-planned where GDAL can, rangefinder’s readers in the browser
  otherwise (accepted).
- [0011](https://github.com/allboa/design/blob/main/decisions/0011-input-surface-and-currencies.md):
  what [`view()`](https://allboa.github.io/aobview/reference/view.md)
  takes next (strings, Arrow streams, matrices, stars) and the two
  contracts scenespec writes down, a GeoArrow stream and a
  chunk-reference table (accepted).

The full list is in the [decisions
folder](https://github.com/allboa/design/tree/main/decisions).
