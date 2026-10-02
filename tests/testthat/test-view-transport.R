# Embed or serve (allboa/design decision 0006, item 4; aobview#17).

in_memory <- function() {
  terra::rast(ncols = 72, nrows = 20, xmin = -180, xmax = 180, ymin = -90, ymax = -40,
              vals = 1:1440, crs = "OGC:CRS84")
}

test_that("transport is checked, and serve needs httpuv", {
  skip_if_not_installed("sf")
  p <- sf::st_sfc(sf::st_point(c(0, 0)), crs = "EPSG:3031")
  expect_error(view(p, transport = "post"), "must be \"auto\", \"embed\" or \"serve\"")
  expect_error(view(p, transport = c("auto", "embed")), "must be")
  local_mocked_bindings(has_httpuv = function() FALSE)
  expect_error(view(p, transport = "serve"), "needs the 'httpuv' package")
  op <- options(aobview.transport = "serve")
  on.exit(options(op), add = TRUE)
  expect_error(view(p), "needs the 'httpuv' package")
  options(aobview.transport = "nope")
  expect_error(view(p), "aobview.transport")
})

test_that("a small raster is embedded as before, with \"auto\" or \"embed\"", {
  skip_if_no_terra()
  sst <- terra::rast(extdata("polar_3031.tif"))
  a <- view(sst, file = html())
  e <- view(sst, file = html(), transport = "embed")
  expect_null(a$server)
  expect_true(file.exists(a$file))
  expect_gt(length(tile_blobs(a)), 0L)
  expect_null(attr(a$scene, "files"))
  expect_identical(page_text(a), page_text(e))
  expect_gt(a$local_bytes, 0)
  expect_identical(a$local_bytes, plan_bytes(list(plan = a$scene$layers[[1]]$plan)))
})

test_that("over the threshold and not interactive, the raster is embedded with a warning", {
  skip_if_no_terra()
  sst <- terra::rast(extdata("polar_3031.tif"))
  op <- options(aobview.embed_max = 100)
  on.exit(options(op), add = TRUE)
  expect_warning(v <- view(sst, file = html()),
                 paste0("over getOption\\(\"aobview.embed_max\"\\) \\(100 bytes\\).*",
                        if (has_httpuv()) "not interactive" else "needs the 'httpuv' package"))
  expect_null(v$server)
  expect_true(file.exists(v$file))
  expect_gt(length(tile_blobs(v)), 0L)
  ## Without httpuv the warning names it.
  local_mocked_bindings(is_interactive = function() TRUE, has_httpuv = function() FALSE)
  expect_warning(v <- view(sst, file = html()), "needs the 'httpuv' package")
  expect_null(v$server)
  expect_gt(length(tile_blobs(v)), 0L)
})

test_that("over the threshold in an interactive session, a local COG is served", {
  skip_if_no_terra()
  skip_if_no_httpuv()
  sst <- terra::rast(extdata("polar_3031.tif"))
  op <- options(aobview.embed_max = 100)
  on.exit(options(op), add = TRUE)
  on.exit(aobcore::stop_scene_servers(), add = TRUE)
  local_mocked_bindings(is_interactive = function() TRUE)
  expect_message(v <- served(view(sst)),
                 "over getOption.*served from a local server.*left running")
  expect_null(v$file)
  expect_s3_class(v$server, "aob_server")
  expect_true(v$server$running())
  expect_length(tile_blobs(v), 0L)
  files <- attr(v$scene, "files")
  expect_length(files, 1L)
  expect_identical(files$sst$path, normalizePath(extdata("polar_3031.tif"), winslash = "/"))
  expect_output(print(v), "served at http://127.0.0.1:[0-9]+/[0-9a-f]{32}/", perl = TRUE)
  ## The page and the file are delivered.
  page <- http_get(v$server$url)
  expect_identical(page$status, 200L)
  expect_match(rawToChar(page$body), "files/sst/polar_3031.tif", fixed = TRUE)
  f <- http_get(paste0(v$server$url, "files/sst/polar_3031.tif"))
  expect_identical(f$status, 200L)
  expect_identical(length(f$body), as.integer(file.size(extdata("polar_3031.tif"))))
  v$server$stop()
  expect_false(v$server$running())
  expect_output(print(v), "(stopped)", fixed = TRUE)
})

test_that("transport = \"serve\" serves any view, and \"embed\" never serves", {
  skip_if_no_terra()
  skip_if_no_httpuv()
  skip_if_not_installed("sf")
  on.exit(aobcore::stop_scene_servers(), add = TRUE)
  sst <- terra::rast(extdata("polar_3031.tif"))
  v <- served(view(sst, transport = "serve"))
  expect_null(v$file)
  expect_true(v$server$running())
  expect_length(tile_blobs(v), 0L)
  expect_length(attr(v$scene, "files"), 1L)
  v$server$stop()
  ## Vectors alone are served when asked.
  p <- sf::st_sfc(sf::st_point(c(0, 0)), sf::st_point(c(1e6, 1e6)), crs = "EPSG:3031")
  vp <- served(view(p, transport = "serve"))
  expect_true(vp$server$running())
  expect_null(attr(vp$scene, "files"))
  vp$server$stop()
  ## A file given to a served view is not written.
  f <- html()
  expect_warning(vf <- served(view(p, file = f, transport = "serve")), "`file` is not written")
  expect_false(file.exists(f))
  vf$server$stop()
  ## "embed" over the threshold: embedded, no warning.
  op <- options(aobview.embed_max = 0, aobview.transport = "embed")
  on.exit(options(op), add = TRUE)
  local_mocked_bindings(is_interactive = function() TRUE)
  expect_no_warning(ve <- view(sst, file = html()))
  expect_null(ve$server)
  expect_gt(length(tile_blobs(ve)), 0L)
})

test_that("an in-memory raster's temporary COG is deleted when embedded, kept when served", {
  skip_if_no_terra()
  skip_if_no_httpuv()
  on.exit(aobcore::stop_scene_servers(), add = TRUE)
  m <- in_memory()
  ## Embedded: deleted at add time (temp_cog_values() checks).
  vals <- temp_cog_values(v <- view(m, file = html()))
  expect_equal(as.vector(vals), 1:1440)
  expect_null(v$server)
  ## Served: kept in the session directory until the server stops.
  vs <- served(view(m, transport = "serve"))
  path <- attr(vs$scene, "files")[[1]]$path
  expect_identical(normalizePath(dirname(path), winslash = "/"),
                   normalizePath(file.path(tempdir(), "aobview-cogs"), winslash = "/"))
  expect_true(file.exists(path))
  expect_length(tile_blobs(vs), 0L)
  expect_true(vs$server$running())
  vs$server$stop()
  expect_false(file.exists(path))
})

test_that("view_add() keeps a served view on the same server", {
  skip_if_no_terra()
  skip_if_no_httpuv()
  skip_if_not_installed("sf")
  on.exit(aobcore::stop_scene_servers(), add = TRUE)
  sst <- terra::rast(extdata("polar_3031.tif"))
  v <- served(view(sst, transport = "serve"))
  url <- v$server$url
  ## A new raster on a served view is served too, under "auto".
  v2 <- view_add(v, in_memory(), name = "m")
  expect_identical(v2$server$url, url)
  expect_null(v2$file)
  expect_length(v2$scene$layers, 2L)
  expect_length(tile_blobs(v2), 0L)
  expect_named(attr(v2$scene, "files"), c("sst", "m"))
  m_path <- attr(v2$scene, "files")$m$path
  expect_true(file.exists(m_path))
  page <- rawToChar(http_get(url)$body)
  expect_match(page, "files/m/", fixed = TRUE)
  ## Vectors too.
  p <- sf::st_sfc(sf::st_point(c(0, 0)), crs = "EPSG:3031")
  v3 <- view_add(v2, p)
  expect_identical(v3$server$url, url)
  expect_length(v3$scene$layers, 3L)
  ## "embed" on a served view embeds the new tiles, served as blobs.
  v4 <- view_add(v3, sst, name = "sst2", transport = "embed")
  expect_identical(v4$server$url, url)
  expect_gt(length(tile_blobs(v4)), 0L)
  expect_named(attr(v4$scene, "files"), c("sst", "m"))
  key <- tile_blobs(v4)[1]
  b <- http_get(paste0(url, "blob/", utils::URLencode(key, reserved = TRUE)))
  expect_identical(b$status, 200L)
  expect_identical(b$body, aobcore::scene_blobs(v4$scene)[[key]])
  ## The temporary COG lives until the server stops.
  v4$server$stop()
  expect_false(file.exists(m_path))
  ## A stopped server whose temporary COG is gone cannot be served again.
  expect_error(view_add(v4, p, name = "q"), "was stopped, and the file of layer `m` is gone")
  ## Otherwise view_add() starts a new one, and says so.
  expect_message(v5 <- served(view_add(v, p, name = "q")), "was stopped")
  expect_false(identical(v5$server$url, url))
  expect_true(v5$server$running())
  v5$server$stop()
})

test_that("view_add() on an embedded view serves once the threshold is crossed", {
  skip_if_no_terra()
  skip_if_no_httpuv()
  on.exit(aobcore::stop_scene_servers(), add = TRUE)
  sst <- terra::rast(extdata("polar_3031.tif"))
  v <- view(sst, file = html())
  n <- v$local_bytes
  expect_gt(n, 0)
  ## Under the threshold view_add() embeds and writes a page, as before.
  op <- options(aobview.embed_max = 2 * n + 1)
  on.exit(options(op), add = TRUE)
  v2 <- view_add(v, sst, name = "again", file = html())
  expect_null(v2$server)
  expect_true(file.exists(v2$file))
  expect_identical(v2$local_bytes, 2 * n)
  ## A third crosses it: served, the earlier embedded tiles as blobs.
  local_mocked_bindings(is_interactive = function() TRUE)
  expect_message(v3 <- served(view_add(v2, sst, name = "third")), "served from a local server")
  expect_null(v3$file)
  expect_true(file.exists(v2$file))
  expect_true(v3$server$running())
  expect_named(attr(v3$scene, "files"), "third")
  expect_identical(length(tile_blobs(v3)), length(tile_blobs(v2)))
  expect_identical(http_get(v3$server$url)$status, 200L)
  v3$server$stop()
})

test_that("a non-numeric aobview.embed_max is an error", {
  skip_if_no_terra()
  op <- options(aobview.embed_max = "big")
  on.exit(options(op), add = TRUE)
  expect_error(view(terra::rast(extdata("polar_3031.tif")), file = html()), "aobview.embed_max")
})

cogs <- function() list.files(file.path(tempdir(), "aobview-cogs"), full.names = TRUE)

test_that("view_add() on a stopped view whose file is gone writes no temporary COG", {
  skip_if_no_terra()
  skip_if_no_httpuv()
  on.exit(aobcore::stop_scene_servers(), add = TRUE)
  v <- served(view(in_memory(), transport = "serve"))
  v$server$stop()
  before <- cogs()
  expect_error(view_add(v, in_memory(), name = "m2"),
               "is gone \\(a temporary COG is deleted when its server stops\\)")
  expect_identical(cogs(), before)
})

test_that("a temporary COG is deleted when building a served view fails", {
  skip_if_no_terra()
  skip_if_no_httpuv()
  on.exit(aobcore::stop_scene_servers(), add = TRUE)
  before <- cogs()
  ## A later list element fails.
  expect_error(served(view(list(m = in_memory(), bad = data.frame(a = 1)), crs = "EPSG:3031",
                           transport = "serve")), "List element 2")
  expect_identical(cogs(), before)
  ## The server will not start.
  local_mocked_bindings(serve_scene = function(...) stop("Could not bind port"),
                        .package = "aobcore")
  expect_error(view(in_memory(), transport = "serve"), "Could not bind")
  expect_identical(cogs(), before)
  sst <- terra::rast(extdata("polar_3031.tif"))
  v <- view(sst, file = html())
  expect_error(view_add(v, in_memory(), name = "m", transport = "serve"), "Could not bind")
  expect_identical(cogs(), before)
})

test_that("a stopped view's missing COG of the user's own is not called temporary", {
  skip_if_no_terra()
  skip_if_no_httpuv()
  skip_if_not_installed("sf")
  on.exit(aobcore::stop_scene_servers(), add = TRUE)
  f <- tempfile(fileext = ".tif")
  file.copy(extdata("polar_3031.tif"), f)
  v <- served(view(terra::rast(f), name = "own", transport = "serve"))
  expect_named(attr(v$scene, "files"), "own")
  v$server$stop()
  unlink(f)
  p <- sf::st_sfc(sf::st_point(c(0, 0)), crs = "EPSG:3031")
  err <- tryCatch(view_add(v, p), error = conditionMessage)
  expect_match(err, "the file of layer `own` is gone", fixed = TRUE)
  expect_match(err, "no longer exists", fixed = TRUE)
  expect_no_match(err, "temporary COG", fixed = TRUE)
})

test_that("a /vsi COG warns over the threshold, and counts only while embedded", {
  local_mocked_bindings(plan_bytes = function(plan) 1000)
  cog <- list(local = TRUE, dsn = "/vsimem/a.tif")
  op <- options(aobview.embed_max = 100)
  on.exit(options(op), add = TRUE)
  v <- new_view("EPSG:3031")
  expect_warning(r <- choose_embed(v, cog, NULL, "a"),
                 "over getOption\\(\"aobview.embed_max\"\\).*\"a\" is a COG GDAL reads from \"/vsimem/a.tif\"")
  expect_true(r$embed)
  expect_identical(r$v$local_bytes, 1000)
  ## Under the threshold, or with "embed": no warning.
  options(aobview.embed_max = 2000)
  expect_no_warning(r <- choose_embed(v, cog, NULL, "a"))
  expect_identical(r$v$local_bytes, 1000)
  options(aobview.embed_max = 100)
  expect_no_warning(r <- choose_embed(new_view("EPSG:3031", "embed"), cog, NULL, "a"))
  expect_identical(r$v$local_bytes, 1000)
  ## On a served view: embedded with the warning that a server cannot
  ## deliver it, and not counted, as for "embed" there.
  for (tr in c("auto", "serve", "embed")) {
    vs <- v
    vs$transport <- tr
    vs$serve <- list(on = TRUE, reason = "asked")
    expect_warning(r <- choose_embed(vs, cog, NULL, "a"), "which a server cannot deliver")
    expect_true(r$embed)
    expect_identical(r$v$local_bytes, 0)
  }
})
