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

## The RGBA colour column of a view's data blob, as an n x 4 integer matrix.
blob_rgba <- function(v, id, column = "color") {
  df <- as.data.frame(nanoarrow::read_nanoarrow(aobcore::scene_blobs(v$scene)[[id]]))
  m <- do.call(rbind, lapply(df[[column]], as.integer))
  dimnames(m) <- list(NULL, c("r", "g", "b", "a"))
  m
}

## view_colours() without its legend key.
plain_rgba <- function(...) {
  m <- view_colours(...)
  attr(m, "key") <- NULL
  m
}
