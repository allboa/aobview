lonlat <- function(geom) sf::st_sfc(geom, crs = "OGC:CRS84")

ring <- function(lon0, lon1, lat0, lat1) {
  sf::st_polygon(list(cbind(c(lon0, lon1, lon1, lon0, lon0), c(lat0, lat0, lat1, lat1, lat0))))
}

layer_kinds <- function(v) vapply(v$scene$layers, function(l) l$kind, "")

## The geometry of a view's data blob, read back from its Arrow IPC bytes as
## a wk::wkb() vector. Only that column is converted: a data frame of the
## whole stream needs vctrs for a list column such as the colours.
blob_geometry <- function(v, id) {
  stream <- nanoarrow::read_nanoarrow(aobcore::scene_blobs(v$scene)[[id]])
  column <- v$scene$data[[id]]$geometry$column
  parts <- lapply(nanoarrow::collect_array_stream(stream), function(b) {
    wk::wk_handle(nanoarrow::convert_array(b$children[[column]]), wk::wkb_writer())
  })
  wk::wkb(unlist(lapply(parts, unclass), recursive = FALSE), crs = wk::wk_crs(parts[[1L]]))
}

## The RGBA colour column of a view's data blob, as an n x 4 integer matrix,
## read from the arrays (a list<int> column in a data frame needs vctrs).
blob_rgba <- function(v, id, column = "color") {
  stream <- nanoarrow::read_nanoarrow(aobcore::scene_blobs(v$scene)[[id]])
  batches <- nanoarrow::collect_array_stream(stream)
  vals <- unlist(lapply(batches, function(b) {
    nanoarrow::convert_array(b$children[[column]]$children[[1L]])
  }))
  matrix(as.integer(vals), ncol = 4L, byrow = TRUE, dimnames = list(NULL, c("r", "g", "b", "a")))
}

## The column names of a view's data blob.
blob_names <- function(v, id) {
  names(nanoarrow::read_nanoarrow(aobcore::scene_blobs(v$scene)[[id]])$get_schema()$children)
}

## view_colours() without its legend key.
plain_rgba <- function(...) {
  m <- view_colours(...)
  attr(m, "key") <- NULL
  m
}

## The class labels of a legend.
legend_labels <- function(lg) vapply(lg$classes, function(cl) cl$label, "")

## The attribute columns of a view's data blob (not its geometry or colour
## columns), as a list, converted column by column (a data frame of the
## whole stream needs vctrs for the list columns).
blob_df <- function(v, id) {
  stream <- nanoarrow::read_nanoarrow(aobcore::scene_blobs(v$scene)[[id]])
  schema <- stream$get_schema()
  batches <- nanoarrow::collect_array_stream(stream)
  geom <- v$scene$data[[id]]$geometry$column
  cols <- names(schema$children)
  keep <- cols[cols != geom & !startsWith(vapply(schema$children, function(ch) ch$format, ""), "+w")]
  out <- lapply(keep, function(nm) {
    do.call(c, lapply(batches, function(b) nanoarrow::convert_array(b$children[[nm]])))
  })
  names(out) <- keep
  out
}

## The scene's JSON, checked by the scenespec validator when a checkout of
## allboa/scenespec (with its node modules) is named by AOB_SCENESPEC.
expect_valid_scene <- function(v) {
  spec <- Sys.getenv("AOB_SCENESPEC")
  if (!nzchar(spec) || !nzchar(Sys.which("node"))) return(invisible())
  f <- tempfile(fileext = ".json")
  writeLines(aobcore::scene_json(v$scene), f)
  out <- suppressWarnings(system2("node", c(file.path(spec, "scripts", "validate.js"), f),
                                  stdout = TRUE, stderr = TRUE))
  expect_null(attr(out, "status"), label = paste(out, collapse = "\n"))
}
