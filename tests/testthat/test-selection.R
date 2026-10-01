# Row maps and the selection functions (decision 0007, items 3, 4, 5 and 8;
# aobview#22). The page is scripted: a raw websocket client in this process
# (helper-ws.R) sends what the renderer sends.

pt <- function(x, y) sf::st_point(c(x, y))

test_that("the row map skips empty and untransformable geometries", {
  skip_if_not_installed("sf")
  ## A point north of the equator has no place in a south polar
  ## orthographic view.
  x <- sf::st_sf(id = 11:16, geometry = lonlat(list(
    pt(0, -70), sf::st_point(), pt(10, -70), pt(0, 60), pt(20, -70), pt(30, -70))))
  ortho <- "+proj=ortho +lat_0=-90 +lon_0=0"
  expect_warning(v <- view(x, crs = ortho, popup = "id", file = html()),
                 "1 of 5 geometries could not be transformed")
  expect_length(v$sources, 1L)
  s <- v$sources[[1]]
  expect_identical(s$name, "x")
  expect_identical(s$object, x)
  expect_identical(names(s$layers), "x")
  expect_identical(s$layers$x, c(1L, 3L, 5L, 6L))
  ## Layer row i of the Arrow data is row s$layers$x[i] of x.
  expect_identical(blob_column(v, "x", "id"), x$id[s$layers$x])
  expect_null(v$serial)
})

test_that("mixed geometry and a geometry collection map each layer row to its source row", {
  skip_if_not_installed("sf")
  gc <- sf::st_geometrycollection(list(ring(0, 10, -80, -75), ring(20, 30, -80, -75),
                                       pt(5, -60)))
  x <- sf::st_sf(id = 1:4, geometry = lonlat(list(
    ring(40, 50, -80, -75), sf::st_linestring(rbind(c(0, -60), c(10, -62))), gc,
    pt(100, -70))))
  v <- view(x, crs = "EPSG:3031", popup = "id", file = html())
  expect_identical(layer_kinds(v), c("polygon", "path", "point"))
  m <- v$sources[[1]]$layers
  expect_identical(names(m), c("x_polygon", "x_path", "x_point"))
  expect_identical(m$x_polygon, c(1L, 3L, 3L))
  expect_identical(m$x_path, 2L)
  expect_identical(m$x_point, c(4L, 3L))
  for (id in names(m)) expect_identical(blob_column(v, id, "id"), x$id[m[[id]]])
})

test_that("an sfc and a SpatVector are kept as they were given", {
  skip_if_no_terra()
  g <- lonlat(list(pt(0, -70), pt(10, -70)))
  expect_identical(view(g, file = html())$sources[[1]]$object, g)
  sv <- terra::vect(sf::st_sf(id = 1:2, geometry = g))
  v <- view(sv, file = html())
  expect_s4_class(v$sources[[1]]$object, "SpatVector")
  expect_identical(v$sources[[1]]$layers[[1]], 1:2)
})

test_that("view_add() appends a source; a raster adds none; names are made unique", {
  skip_if_no_terra()
  a <- sf::st_sf(id = 1:2, geometry = lonlat(list(pt(0, -70), pt(10, -70))))
  v <- view(list(a = a, a = a), file = html())
  expect_identical(vapply(v$sources, `[[`, "", "name"), c("a", "a_2"))
  expect_identical(names(v$sources[[2]]$layers), "a_2")
  sst <- terra::rast(extdata("polar_3031.tif"))
  v2 <- view_add(v, sst, file = html())
  expect_length(v2$sources, 2L)
})

test_that("selection() and selected() map a served page's selection to rows of an sf", {
  skip_if_not_installed("sf")
  skip_if_no_httpuv()
  on.exit(aobcore::stop_scene_servers(), add = TRUE)
  x <- sf::st_sf(id = 11:16, name = letters[1:6], geometry = lonlat(list(
    pt(0, -70), sf::st_point(), pt(10, -70), pt(20, -70), pt(30, -70), pt(40, -70))))
  v <- serve(x, crs = "EPSG:3031", popup = FALSE)
  skip_if_no_socket(v)
  expect_identical(v$serial, 1L)
  sel <- selection(v)
  expect_identical(nrow(sel), 0L)
  expect_identical(names(sel), c("source", "layer", "row"))
  expect_identical(nrow(selected(v)), 0L)
  expect_s3_class(selected(v), "sf")
  page <- page_connect(v)
  expect_match(page$status, "^HTTP/1.1 101")
  ## Every vector layer is selectable, popup or not (select = NULL).
  expect_true(any(grepl('"select":["x"]', page$received, fixed = TRUE)))
  ## Layer rows 0 and 2 (0-based) are rows 1 and 4 of x (row 2 is empty).
  page_select(page, list(x = c(0, 2)), scene = v$serial, at = c(5, 6), srv = v$server)
  sel <- selection(v)
  expect_identical(sel$source, c("x", "x"))
  expect_identical(sel$layer, c("x", "x"))
  expect_identical(sel$row, c(1L, 4L))
  expect_identical(attr(sel, "at"), c(5, 6))
  expect_identical(attr(sel, "trigger"), "click")
  expect_identical(attr(sel, "connection"), 1L)
  rows <- selected(v)
  expect_s3_class(rows, "sf")
  expect_identical(rows$id, c(11L, 14L))
  expect_identical(names(rows), names(x))
  ## A clear.
  page_select(page, list(), scene = v$serial, trigger = "clear", srv = v$server)
  expect_identical(nrow(selection(v)), 0L)
  page_close(page)
})

test_that("a geometry collection's parts select one row, across split layers", {
  skip_if_not_installed("sf")
  skip_if_no_httpuv()
  on.exit(aobcore::stop_scene_servers(), add = TRUE)
  gc <- sf::st_geometrycollection(list(ring(0, 10, -80, -75), ring(20, 30, -80, -75),
                                       pt(5, -60)))
  x <- sf::st_sf(id = 1:3, geometry = lonlat(list(ring(40, 50, -80, -75), gc, pt(100, -70))))
  v <- serve(x, crs = "EPSG:3031")
  skip_if_no_socket(v)
  page <- page_connect(v)
  page_select(page, list(x_polygon = c(1, 2), x_point = c(0, 1)), scene = v$serial,
              trigger = "toggle", srv = v$server)
  sel <- selection(v)
  expect_identical(sel$layer, c("x_polygon", "x_point", "x_point"))
  expect_identical(sel$row, c(2L, 2L, 3L))
  expect_identical(selected(v)$id, 2:3)
  page_close(page)
})

test_that("selected() gives sfc and SpatVector rows, and asks which of several sources", {
  skip_if_no_terra()
  skip_if_no_httpuv()
  on.exit(aobcore::stop_scene_servers(), add = TRUE)
  g <- lonlat(list(pt(0, -70), pt(10, -70), pt(20, -70)))
  sv <- terra::vect(sf::st_sf(id = 1:3, geometry = g))
  v <- served(view(list(pts = g, sv = sv), transport = "serve"))
  skip_if_no_socket(v)
  page <- page_connect(v)
  page_select(page, list(pts = 2, sv = c(0, 1)), scene = v$serial, srv = v$server)
  sel <- selection(v)
  expect_identical(sel$source, c("pts", "sv", "sv"))
  expect_identical(sel$row, c(3L, 1L, 2L))
  expect_error(selected(v), "Rows of several objects are selected: \"pts\", \"sv\"")
  expect_error(selected(v, source = "nope"), "has \"pts\", \"sv\"")
  expect_error(selected(v, source = 1), "`source` must be")
  p <- selected(v, source = "pts")
  expect_s3_class(p, "sfc")
  expect_identical(p, g[3])
  s <- selected(v, source = "sv")
  expect_s4_class(s, "SpatVector")
  expect_identical(s$id, 1:2)
  ## Rows of one source only: it is the default.
  page_select(page, list(sv = 2), scene = v$serial, srv = v$server)
  expect_identical(selected(v)$id, 3L)
  ## Nothing selected, several sources: NULL.
  page_select(page, list(), scene = v$serial, trigger = "clear", srv = v$server)
  expect_null(selected(v))
  expect_identical(length(selected(v, source = "pts")), 0L)
  page_close(page)
})

test_that("view_state() gives the settled view", {
  skip_if_not_installed("sf")
  skip_if_no_httpuv()
  on.exit(aobcore::stop_scene_servers(), add = TRUE)
  v <- serve(lonlat(list(pt(0, -70), pt(10, -70))))
  skip_if_no_socket(v)
  expect_null(view_state(v))
  page <- page_connect(v)
  page_view(page, v$serial, extent = c(-10, 10, -20, 20), srv = v$server)
  st <- view_state(v)
  expect_identical(st$extent, c(-10, 10, -20, 20))
  expect_identical(st$zoom, -3.5)
  expect_identical(st$size_px, c(800, 600))
  page_close(page)
})

test_that("embedded and stopped views are errors that say why", {
  skip_if_not_installed("sf")
  skip_if_no_httpuv()
  on.exit(aobcore::stop_scene_servers(), add = TRUE)
  g <- lonlat(list(pt(0, -70), pt(10, -70)))
  e <- view(g, file = html())
  for (f in list(selection, selected, wait_for_selection, view_state)) {
    expect_error(f(e), "embedded in a page on disk.*transport = \"serve\".*'jsonlite'")
  }
  v <- serve(g)
  v$server$stop()
  for (f in list(selection, selected, wait_for_selection, view_state)) {
    expect_error(f(v), "server has stopped")
  }
  expect_error(selection(list()), "must be a view")
})

test_that("view_add() replaces the scene: the page reloads, the old view is an error", {
  skip_if_not_installed("sf")
  skip_if_no_httpuv()
  on.exit(aobcore::stop_scene_servers(), add = TRUE)
  x <- sf::st_sf(id = 1:2, geometry = lonlat(list(pt(0, -70), pt(10, -70))))
  v <- serve(x)
  skip_if_no_socket(v)
  page <- page_connect(v)
  page_select(page, list(x = 1), scene = v$serial, srv = v$server)
  expect_identical(selection(v)$row, 2L)
  y <- lonlat(list(pt(20, -70)))
  v2 <- served(view_add(v, y))
  expect_identical(v2$server$url, v$server$url)
  expect_identical(v2$serial, v$serial + 1L)
  page_pump(page, until = function(p) any(grepl('"type":"reload"', p$received, fixed = TRUE)))
  expect_true(any(grepl(sprintf('{"type":"reload","scene":%d}', v2$serial), page$received,
                        fixed = TRUE)))
  msg <- "This view was replaced by view_add\\(\\); use the view it returned"
  for (f in list(selection, selected, wait_for_selection, view_state)) {
    expect_error(f(v), msg)
  }
  ## The selection was cleared.
  expect_identical(nrow(selection(v2)), 0L)
  expect_identical(vapply(v2$sources, `[[`, "", "name"), c("x", "y"))
  ## A select for the old scene is dropped; one for the new one maps.
  page_select(page, list(x = 0), scene = v$serial, srv = v$server)
  expect_identical(nrow(selection(v2)), 0L)
  page_select(page, list(y = 0), scene = v2$serial, srv = v2$server)
  expect_identical(selected(v2), y[1])
  page_close(page)
})

test_that("wait_for_selection() returns the next selection, and refuses to hang", {
  skip_if_not_installed("sf")
  skip_if_no_httpuv()
  on.exit(aobcore::stop_scene_servers(), add = TRUE)
  x <- sf::st_sf(id = 1:3, geometry = lonlat(list(pt(0, -70), pt(10, -70), pt(20, -70))))
  v <- serve(x)
  skip_if_no_socket(v)
  expect_error(wait_for_selection(v), "No page is connected.*not interactive.*finite `timeout`")
  expect_error(wait_for_selection(v, timeout = -1), "`timeout` must be")
  expect_message(expect_message(out <- wait_for_selection(v, timeout = 0.2),
                                "No select message"), "waiting for one to connect")
  expect_null(out)
  ## The note is given once per server.
  expect_message(expect_no_message(wait_for_selection(v, timeout = 0.1), message = "waiting"),
                 "No select message")
  page <- page_connect(v)
  ## Not run: the message waits until wait_for_selection() runs the loop.
  page_select(page, list(x = 2), scene = v$serial)
  rows <- wait_for_selection(v, timeout = 10)
  expect_identical(rows$id, 3L)
  ## Once taken in, a selection is not the next one.
  expect_message(expect_null(wait_for_selection(v, timeout = 0.2)), "No select message")
  page_close(page)
})

test_that("printing a served view opens the page only when none is connected", {
  skip_if_not_installed("sf")
  skip_if_no_httpuv()
  on.exit(aobcore::stop_scene_servers(), add = TRUE)
  v <- serve(lonlat(list(pt(0, -70), pt(10, -70))))
  skip_if_no_socket(v)
  opened <- character()
  local_mocked_bindings(can_open = function() TRUE,
                        open_url = function(url) opened <<- c(opened, url))
  expect_output(print(v), "served at")
  expect_identical(opened, v$server$url)
  page <- page_connect(v)
  expect_output(print(v), "served at")
  expect_identical(opened, v$server$url)
  page_close(page)
  expect_output(print(v), "served at")
  expect_identical(opened, rep(v$server$url, 2L))
})

test_that("without jsonlite the functions say what is missing", {
  skip_if_not_installed("sf")
  skip_if_no_httpuv()
  on.exit(aobcore::stop_scene_servers(), add = TRUE)
  local_mocked_bindings(has_jsonlite = function() FALSE, .package = "aobcore")
  v <- suppressMessages(serve(lonlat(list(pt(0, -70)))))
  expect_false(isTRUE(v$server$state$socket))
  expect_error(selection(v), "without the 'jsonlite' package")
})
