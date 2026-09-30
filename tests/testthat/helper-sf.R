lonlat <- function(geom) sf::st_sfc(geom, crs = "OGC:CRS84")

ring <- function(lon0, lon1, lat0, lat1) {
  sf::st_polygon(list(cbind(c(lon0, lon1, lon1, lon0, lon0), c(lat0, lat0, lat1, lat1, lat0))))
}

layer_kinds <- function(v) vapply(v$scene$layers, function(l) l$kind, "")

## The geometry of a view's data blob, read back from its Arrow IPC bytes.
blob_geometry <- function(v, id) {
  df <- as.data.frame(nanoarrow::read_nanoarrow(aobcore::scene_blobs(v$scene)[[id]]))
  df[[v$scene$data[[id]]$geometry$column]]
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
