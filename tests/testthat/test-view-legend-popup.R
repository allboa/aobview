## Legends (scene spec 0.5) from the zcol colours, and popups from the
## attribute columns.

pols <- function() {
  sf::st_sf(
    num = c(1, NA, 3),
    fac = factor(c("x", "y", NA), levels = c("x", "y", "unused")),
    chr = c("q", "p", "q"),
    lgl = c(TRUE, NA, FALSE),
    geometry = lonlat(list(ring(0, 20, -80, -70), ring(40, 60, -80, -70), ring(80, 100, -80, -70)))
  )
}

## A version before 0.5: 0.4 with the view's domain as bounds, 0.1 where
## PROJ cannot give a domain (some binary builds).
expect_before_05 <- function(v) expect_true(v$scene$version %in% c("0.1", "0.4"))

legend_labels <- function(lg) vapply(lg$classes, function(cl) cl$label, "")
legend_colours <- function(lg) do.call(rbind, lapply(lg$classes, function(cl) cl$color))

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

test_that("a numeric zcol gets a ramp legend from the same colours", {
  skip_if_not_installed("sf")
  x <- pols()
  x$num[2] <- 2
  v <- view(x, zcol = "num", palette = "YlGnBu", popup = FALSE, file = html())
  expect_identical(v$scene$version, "0.5")
  expect_length(v$scene$legends, 1L)
  lg <- v$scene$legends[[1]]
  expect_identical(lg$layer, "x")
  expect_identical(lg$title, "num")
  expect_identical(lg$ramp$range, c(1, 3))
  key <- attr(view_colours(x$num, palette = "YlGnBu"), "key")
  stops <- do.call(rbind, lapply(lg$ramp$stops, function(s) s$color))
  expect_identical(stops, unname(t(grDevices::col2rgb(key$colours, alpha = TRUE))))
  expect_identical(vapply(lg$ramp$stops, function(s) s$at, 0), seq(0, 1, length.out = 33))
  ## The ends of the ramp are the colours of the lowest and highest values.
  rgba <- blob_rgba(v, "x")
  expect_identical(stops[1, ], unname(rgba[1, ]))
  expect_identical(stops[33, ], unname(rgba[3, ]))
  ## No NA among the values: no NA entry.
  expect_null(lg$na)
  expect_valid_scene(v)
})

test_that("an NA entry is added only when a value took the NA colour", {
  skip_if_not_installed("sf")
  v <- view(pols(), zcol = "num", na_colour = "red", popup = FALSE, file = html())
  expect_identical(v$scene$legends[[1]]$na, list(label = "NA", color = c(255L, 0L, 0L, 255L)))
  ## Binned: values outside the breaks take the NA colour too.
  x <- pols()
  x$num <- c(1, 2, 30)
  v <- view(x, zcol = "num", breaks = c(0, 1, 5), popup = FALSE, file = html())
  expect_identical(v$scene$legends[[1]]$na$label, "NA")
  v <- view(x, zcol = "num", breaks = c(0, 1, 50), popup = FALSE, file = html())
  expect_null(v$scene$legends[[1]]$na)
  expect_valid_scene(v)
})

test_that("breaks give one class per interval, levels one class per level", {
  skip_if_not_installed("sf")
  x <- pols()
  pal <- function(n) c("red", "green", "blue")[seq_len(n)]
  v <- view(x, zcol = "num", breaks = c(0, 1.5, 5, 10), palette = pal, popup = FALSE,
            file = html())
  lg <- v$scene$legends[[1]]
  expect_null(lg$ramp)
  expect_identical(legend_labels(lg), c("[0, 1.5]", "(1.5, 5]", "(5, 10]"))
  expect_identical(legend_colours(lg)[, 1:3], rbind(c(255L, 0L, 0L), c(0L, 255L, 0L),
                                                     c(0L, 0L, 255L)))
  expect_identical(lg$na$label, "NA")
  expect_valid_scene(v)

  ## A factor keeps every level, unused ones included, in level order.
  v <- view(x, zcol = "fac", palette = pal, popup = FALSE, file = html())
  lg <- v$scene$legends[[1]]
  expect_identical(legend_labels(lg), c("x", "y", "unused"))
  rgba <- blob_rgba(v, "x")
  expect_identical(legend_colours(lg)[1:2, ], unname(rgba[1:2, ]))
  expect_false(is.null(lg$na))
  ## Character levels sort; logical is FALSE, TRUE.
  v <- view(x, zcol = "chr", popup = FALSE, file = html())
  expect_identical(legend_labels(v$scene$legends[[1]]), c("p", "q"))
  expect_null(v$scene$legends[[1]]$na)
  v <- view(x, zcol = "lgl", popup = FALSE, file = html())
  expect_identical(legend_labels(v$scene$legends[[1]]), c("FALSE", "TRUE"))
  expect_valid_scene(v)
})

test_that("one value is one class; no values is no legend", {
  skip_if_not_installed("sf")
  x <- pols()
  x$num <- c(4, 4, NA)
  v <- view(x, zcol = "num", popup = FALSE, file = html())
  lg <- v$scene$legends[[1]]
  expect_identical(legend_labels(lg), "4")
  expect_identical(legend_colours(lg), unname(blob_rgba(v, "x")[1, , drop = FALSE]))
  x$num <- NA_real_
  v <- view(x, zcol = "num", popup = FALSE, file = html())
  expect_null(v$scene$legends)
  expect_before_05(v)
})

test_that("legend = FALSE leaves the legend out and the version as it was", {
  skip_if_not_installed("sf")
  v <- view(pols(), zcol = "num", legend = FALSE, popup = FALSE, file = html())
  expect_null(v$scene$legends)
  expect_before_05(v)
  ## No zcol, no attributes: nothing from 0.5.
  v <- view(sf::st_geometry(pols()), file = html())
  expect_before_05(v)
  v <- view(pols(), popup = FALSE, file = html())
  expect_before_05(v)
  expect_null(v$scene$legends)
  expect_error(view(pols(), zcol = "num", legend = NA, file = html()), "TRUE or FALSE")
})

test_that("mixed geometry has one legend, on its first layer, and popups on each", {
  skip_if_not_installed("sf")
  g <- c(sf::st_geometry(pols())[1],
         lonlat(list(sf::st_point(c(10, -60)), sf::st_linestring(rbind(c(0, -60), c(90, -60))))))
  x <- sf::st_sf(kind = c("a", "b", "c"), geometry = g)
  v <- view(x, zcol = "kind", name = "mixed", file = html())
  expect_identical(layer_kinds(v), c("polygon", "path", "point"))
  expect_length(v$scene$legends, 1L)
  expect_identical(v$scene$legends[[1]]$layer, "mixed_polygon")
  for (l in v$scene$layers) expect_identical(l$popup, list(columns = list("kind")))
  expect_identical(blob_df(v, "mixed_point")$kind, "b")
  expect_identical(blob_df(v, "mixed_path")$kind, "c")
  expect_valid_scene(v)
})

test_that("popup = TRUE carries the attribute columns, readable in the blob", {
  skip_if_not_installed("sf")
  x <- pols()
  x$when <- as.Date(c("2026-01-02", NA, "2026-10-01"))
  x$at <- as.POSIXct(c("2026-01-02 03:04:05", "2026-01-02 00:00:00", NA), tz = "UTC")
  x$n <- 1:3
  v <- view(x, file = html())
  cols <- c("num", "fac", "chr", "lgl", "when", "at", "n")
  expect_identical(v$scene$layers[[1]]$popup, list(columns = as.list(cols)))
  expect_identical(v$scene$version, "0.5")
  df <- blob_df(v, "x")
  expect_identical(blob_names(v, "x"), c(cols, "geometry"))
  expect_identical(df$num, x$num)
  ## A factor as its labels (the IPC writer cannot write dictionaries).
  expect_identical(df$fac, c("x", "y", NA))
  expect_identical(df$chr, x$chr)
  expect_identical(df$lgl, x$lgl)
  expect_identical(df$when, c("2026-01-02", NA, "2026-10-01"))
  expect_identical(df$at, c("2026-01-02T03:04:05Z", "2026-01-02T00:00:00Z", NA))
  expect_identical(df$n, 1:3)
  ## No legend without zcol.
  expect_null(v$scene$legends)
  expect_valid_scene(v)
})

test_that("popup names columns, or none; bad names are errors", {
  skip_if_not_installed("sf")
  x <- pols()
  v <- view(x, popup = c("chr", "num"), file = html())
  expect_identical(v$scene$layers[[1]]$popup, list(columns = list("chr", "num")))
  expect_identical(blob_names(v, "x"), c("chr", "num", "geometry"))
  v <- view(x, popup = FALSE, file = html())
  expect_null(v$scene$layers[[1]]$popup)
  expect_identical(blob_names(v, "x"), "geometry")
  expect_error(view(x, popup = "nope", file = html()), "not in `x`: \"nope\"")
  expect_error(view(x, popup = "geometry", file = html()), "geometry column")
  expect_error(view(x, popup = c("chr", "chr"), file = html()), "more than once")
  expect_error(view(x, popup = 1, file = html()), "TRUE, FALSE or a character")
})

test_that("popup with zcol carries both, and a column named color is kept apart", {
  skip_if_not_installed("sf")
  x <- pols()
  x$color <- c("red", "green", "blue")
  v <- view(x, zcol = "num", file = html())
  l <- v$scene$layers[[1]]
  expect_identical(l$fill, list(column = "color_2"))
  expect_true("color" %in% unlist(l$popup$columns))
  df <- blob_df(v, "x")
  expect_identical(df$color, x$color)
  expect_identical(blob_rgba(v, "x", column = "color_2"), plain_rgba(x$num))
  expect_valid_scene(v)
})

test_that("unwritable columns are left out with a message; TRUE is capped", {
  skip_if_not_installed("sf")
  x <- pols()
  x$lst <- I(list(1, 2:3, "a"))
  expect_message(v <- view(x, file = html()), "\"lst\" cannot be shown")
  expect_false("lst" %in% unlist(v$scene$layers[[1]]$popup$columns))
  expect_false("lst" %in% blob_names(v, "x"))
  expect_message(v <- view(x, popup = c("lst", "num"), file = html()), "left out")
  expect_identical(v$scene$layers[[1]]$popup, list(columns = list("num")))
  ## Only unwritable columns: no popup.
  expect_message(v <- view(x, popup = "lst", file = html()), "left out")
  expect_null(v$scene$layers[[1]]$popup)

  wide <- sf::st_sf(as.data.frame(matrix(1:75, nrow = 3, dimnames = list(NULL, paste0("c", 1:25)))),
                    geometry = sf::st_geometry(pols()))
  expect_message(v <- view(wide, file = html()), "first 20 of 25 columns")
  expect_identical(unlist(v$scene$layers[[1]]$popup$columns), paste0("c", 1:20))
  ## Named columns are not capped.
  v <- view(wide, popup = paste0("c", 1:25), file = html())
  expect_length(v$scene$layers[[1]]$popup$columns, 25L)
})

test_that("view_add() of a popup layer gives a palette raster its legend", {
  skip_if_not_installed("sf")
  skip_if_no_terra()
  sst <- terra::rast(extdata("polar_3031.tif"))
  v <- view(sst, file = html())
  ## Alone, the renderer draws the ramp itself: no legend, not 0.5.
  expect_null(v$scene$legends)
  expect_false(v$scene$version == "0.5")
  v2 <- view_add(v, pols(), zcol = "num", file = html())
  expect_identical(v2$scene$version, "0.5")
  expect_identical(vapply(v2$scene$legends, function(l) l$layer, ""), c("sst", "pols_"))
  expect_identical(v2$scene$legends[[1]]$ramp,
                   list(range = v2$scene$layers[[1]]$palette$range, palette = "viridis"))
  expect_valid_scene(v2)
  ## legend = FALSE on the raster: no ramp, which needs 0.5.
  v3 <- view(sst, legend = FALSE, file = html())
  expect_identical(v3$scene$version, "0.5")
  expect_null(v3$scene$legends)
  expect_valid_scene(v3)
  v4 <- view_add(view(sst, legend = FALSE, file = html()), pols(), zcol = "num", file = html())
  expect_identical(vapply(v4$scene$legends, function(l) l$layer, ""), "pols_")
  expect_error(view(sst, legend = "yes", file = html()), "TRUE or FALSE")
  ## A colour image has no key.
  rgba <- terra::rast(extdata("polar_rgba.tif"))
  v5 <- view(list(rgba = rgba, land = pols()), file = html())
  expect_null(v5$scene$legends)
  expect_identical(v5$scene$version, "0.5")
})

test_that("a SpatVector takes legend and popup", {
  skip_if_not_installed("sf")
  skip_if_no_terra()
  x <- terra::vect(pols())
  v <- view(x, zcol = "chr", popup = "num", file = html())
  expect_identical(legend_labels(v$scene$legends[[1]]), c("p", "q"))
  expect_identical(v$scene$layers[[1]]$popup, list(columns = list("num")))
  expect_valid_scene(v)
})

test_that("the ramp's 33 stops stay close to the features' colours", {
  skip_if_not_installed("sf")
  x <- sf::st_sf(num = seq(0, 1, length.out = 101),
                 geometry = lonlat(lapply(0:100, function(i) sf::st_point(c(i * 3.5, -70)))))
  for (pal in c("viridis", "YlGnBu", "Spectral")) {
    v <- view(x, zcol = "num", palette = pal, popup = FALSE, file = html())
    ramp <- v$scene$legends[[1]]$ramp
    expect_length(ramp$stops, 33L)
    stops <- do.call(rbind, lapply(ramp$stops, function(s) s$color))
    at <- vapply(ramp$stops, function(s) s$at, 0)
    ## The legend as a renderer draws it: linear between stops.
    drawn <- apply(stops, 2, function(ch) stats::approx(at, ch, xout = x$num)$y)
    ## About 18 at most: where an HCL palette clips at the edge of the
    ## gamut (viridis's red reaches 0), a channel has a corner between two
    ## stops. With 9 stops it was 51 for viridis.
    err <- max(abs(drawn - blob_rgba(v, "x")))
    expect_lt(err, 20, label = paste(pal, "max error", err))
  }
})

test_that("a column with more than 30 levels gets no legend, with a message", {
  skip_if_not_installed("sf")
  n <- 31L
  x <- sf::st_sf(id = sprintf("s%02d", seq_len(n)),
                 geometry = lonlat(lapply(seq_len(n), function(i) sf::st_point(c(i * 10, -70)))))
  expect_message(v <- view(x, zcol = "id", popup = FALSE, file = html()),
                 "31 levels, more than a legend shows \\(30\\)")
  expect_null(v$scene$legends)
  expect_identical(v$scene$layers[[1]]$fill, list(column = "color"))
  ## 30 levels: a legend.
  expect_length(suppressMessages(view(x[-1, ], zcol = "id", popup = FALSE,
                                      file = html()))$scene$legends[[1]]$classes, 30L)
})

test_that("the NA entry counts only drawn features", {
  skip_if_not_installed("sf")
  g <- c(sf::st_geometry(pols())[1:2], lonlat(list(sf::st_polygon())))
  x <- sf::st_sf(num = c(1, 3, NA), geometry = g)
  v <- view(x, zcol = "num", popup = FALSE, file = html())
  expect_null(v$scene$legends[[1]]$na)
  x$num <- c(1, NA, 3)
  v <- view(x, zcol = "num", popup = FALSE, file = html())
  expect_identical(v$scene$legends[[1]]$na$label, "NA")
})

test_that("POSIXlt, difftime, units and other classes travel as popup text or numbers", {
  skip_if_not_installed("sf")
  x <- pols()["num"]
  x$lt <- as.POSIXlt(c("2026-01-02 03:04:05", NA, "2026-10-01 00:00:00"), tz = "UTC")
  x$dt <- as.difftime(c(1.5, 2, NA), units = "hours")
  x$u <- structure(c(10, 20, 30), units = list(numerator = "m", denominator = character()),
                   class = "units")
  x$hex <- as.hexmode(c(10L, 255L, 16L))
  v <- view(x, file = html())
  expect_identical(unlist(v$scene$layers[[1]]$popup$columns), c("num", "lt", "dt", "u", "hex"))
  df <- blob_df(v, "x")
  expect_identical(df$lt, c("2026-01-02T03:04:05Z", NA, "2026-10-01T00:00:00Z"))
  expect_identical(df$dt, c(1.5, 2, NA))
  expect_identical(df$u, c(10, 20, 30))
  expect_identical(df$hex, as.character(as.hexmode(c(10L, 255L, 16L))))
  expect_valid_scene(v)
})
