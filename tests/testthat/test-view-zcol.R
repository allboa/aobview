ramp_grey <- function(n) grDevices::grey(seq(0, 1, length.out = n))

test_that("view_colours() maps numbers along a palette, NA to the NA colour", {
  m <- view_colours(c(0, 5, 10, NA, Inf), palette = ramp_grey)
  expect_identical(dim(m), c(5L, 4L))
  expect_identical(colnames(m), c("r", "g", "b", "a"))
  expect_true(is.integer(m))
  expect_identical(unname(m[1, ]), c(0L, 0L, 0L, 255L))
  expect_identical(unname(m[3, ]), c(255L, 255L, 255L, 255L))
  expect_true(all(m[2, 1:3] > 100 & m[2, 1:3] < 155))
  expect_identical(unname(m[4, ]), c(153L, 153L, 153L, 255L))
  expect_identical(unname(m[5, ]), c(153L, 153L, 153L, 255L))
  key <- attr(m, "key")
  expect_identical(key$type, "continuous")
  expect_identical(key$range, c(0, 10))
  ## One value: the palette's middle.
  one <- view_colours(c(3, 3), palette = ramp_grey)
  expect_true(all(one[, 1] %in% 127:128))
})

test_that("view_colours() bins numbers with breaks", {
  pal <- function(n) c("red", "green", "blue")[seq_len(n)]
  m <- view_colours(c(0, 1, 1.5, 5, 10, 11, NA), palette = pal, breaks = c(0, 1, 5, 10))
  expect_identical(unname(m[, 1:3]), rbind(c(255L, 0L, 0L), c(255L, 0L, 0L), c(0L, 255L, 0L),
                                           c(0L, 255L, 0L), c(0L, 0L, 255L),
                                           c(153L, 153L, 153L), c(153L, 153L, 153L)))
  expect_identical(attr(m, "key")$type, "binned")
  expect_error(view_colours(1:3, breaks = c(2, 1)), "increasing")
  expect_error(view_colours("a", breaks = 1:2), "numeric")
})

test_that("view_colours() gives one colour per level: factor, character, logical", {
  pal <- function(n) c("red", "green", "blue", "black")[seq_len(n)]
  f <- factor(c("b", "a", NA, "b"), levels = c("b", "a", "unused"))
  m <- view_colours(f, palette = pal)
  expect_identical(unname(m[, 1:3]), rbind(c(255L, 0L, 0L), c(0L, 255L, 0L),
                                           c(153L, 153L, 153L), c(255L, 0L, 0L)))
  expect_identical(attr(m, "key")$levels, c("b", "a", "unused"))
  ## Character levels sort.
  ch <- view_colours(c("b", "a", "b"), palette = pal)
  expect_identical(unname(ch[, 1:3]), rbind(c(0L, 255L, 0L), c(255L, 0L, 0L), c(0L, 255L, 0L)))
  lg <- view_colours(c(TRUE, FALSE, NA), palette = pal)
  expect_identical(unname(lg[, 1:3]), rbind(c(0L, 255L, 0L), c(255L, 0L, 0L), c(153L, 153L, 153L)))
  expect_identical(attr(lg, "key")$levels, c("FALSE", "TRUE"))
})

test_that("palette takes a name or a function, and recycles with a message", {
  a <- view_colours(letters[1:3], palette = "Okabe-Ito")
  expect_identical(attr(a, "key")$colours,
                   paste0(unname(grDevices::palette.colors(3, "Okabe-Ito")), "FF"))
  expect_identical(view_colours(letters[1:3], palette = "okabe ito"), a)
  h <- view_colours(1:3, palette = "Blues 3")
  expect_identical(attr(h, "key")$colours[1], paste0(grDevices::hcl.colors(256, "Blues 3")[1], "FF"))
  f <- view_colours(1:3, palette = grDevices::terrain.colors)
  expect_identical(unname(f[1, ]), as.integer(grDevices::col2rgb(grDevices::terrain.colors(256)[1],
                                                                 alpha = TRUE)))
  expect_message(r <- view_colours(letters[1:12]), "10 colours for 12 levels")
  expect_identical(r[11, ], r[1, ])
  ## A palette's alpha is kept.
  al <- view_colours(1:2, palette = function(n) grDevices::hcl.colors(n, alpha = 0.5))
  expect_true(all(al[, "a"] == 128L))
  expect_error(view_colours(1:3, palette = "not a palette"), "Unknown palette")
  expect_error(view_colours(1:3, palette = 1), "palette name or a function")
  expect_error(view_colours(list(1, 2)), "numeric, factor, character or logical")
  expect_identical(unname(view_colours(NA_real_, na_colour = c(1, 2, 3, 4))[1, ]), 1:4)
  expect_error(view_colours(1, na_colour = "nope"), "one colour")
})

test_that("zcol travels as an RGBA column: numeric, factor, character, logical", {
  skip_if_not_installed("sf")
  pol <- sf::st_sf(
    num = c(1, NA, 3),
    fac = factor(c("x", "y", NA)),
    chr = c("q", "p", "q"),
    lgl = c(TRUE, NA, FALSE),
    geometry = lonlat(list(ring(0, 20, -80, -70), ring(40, 60, -80, -70), ring(80, 100, -80, -70)))
  )
  for (col in c("num", "fac", "chr", "lgl")) {
    v <- view(pol, zcol = col, popup = FALSE, file = tempfile(fileext = ".html"))
    expect_identical(v$scene$layers[[1]]$fill, list(column = "color"))
    expect_identical(blob_names(v, "pol"), c("geometry", "color"))
    expect_identical(blob_rgba(v, "pol"), plain_rgba(pol[[col]]), label = col)
  }
  ## NA values get the NA colour.
  v <- view(pol, zcol = "num", na_colour = "red", file = tempfile(fileext = ".html"))
  expect_identical(unname(blob_rgba(v, "pol")[2, ]), c(255L, 0L, 0L, 255L))
  ## Palette by name and by function.
  v <- view(pol, zcol = "chr", palette = "Set 1", file = tempfile(fileext = ".html"))
  expect_identical(blob_rgba(v, "pol"), plain_rgba(pol$chr, palette = "Set 1"))
  v <- view(pol, zcol = "num", palette = grDevices::heat.colors, breaks = c(0, 2, 4),
            file = tempfile(fileext = ".html"))
  expect_identical(blob_rgba(v, "pol"),
                   plain_rgba(pol$num, palette = grDevices::heat.colors, breaks = c(0, 2, 4)))
})

test_that("zcol colours lines by stroke, points and polygons by fill", {
  skip_if_not_installed("sf")
  lns <- sf::st_sf(z = 1:2, geometry = lonlat(list(sf::st_linestring(rbind(c(0, -60), c(90, -60))),
                                                   sf::st_linestring(rbind(c(0, -65), c(90, -65))))))
  v <- view(lns, zcol = "z", file = tempfile(fileext = ".html"))
  expect_identical(v$scene$layers[[1]]$stroke, list(column = "color"))
  expect_null(v$scene$layers[[1]]$fill)
  pts <- sf::st_sf(z = c("a", "b"), geometry = lonlat(list(sf::st_point(c(0, -70)),
                                                           sf::st_point(c(90, -70)))))
  v <- view(pts, zcol = "z", file = tempfile(fileext = ".html"))
  expect_identical(v$scene$layers[[1]]$fill, list(column = "color"))
  expect_identical(v$scene$layers[[1]]$stroke, c(255L, 255L, 255L, 255L))
  pol <- sf::st_sf(z = 1, geometry = lonlat(list(ring(0, 20, -80, -70))))
  v <- view(pol, zcol = "z", stroke = c(0, 0, 0, 255), file = tempfile(fileext = ".html"))
  expect_identical(v$scene$layers[[1]]$stroke, c(0L, 0L, 0L, 255L))
})

test_that("zcol colours stay with their rows through dropping and splitting", {
  skip_if_not_installed("sf")
  m <- sf::st_sf(
    z = c("pt", "empty", "line", "poly", "gc"),
    geometry = lonlat(list(
      sf::st_point(c(0, -70)),
      sf::st_point(),
      sf::st_linestring(rbind(c(0, -60), c(90, -60))),
      ring(-40, 40, -80, -70),
      sf::st_geometrycollection(list(sf::st_point(c(10, -75)), ring(50, 60, -80, -75)))
    ))
  )
  pal <- function(n) c("red", "green", "blue", "black", "white")[seq_len(n)]
  all <- plain_rgba(m$z, palette = pal)
  v <- view(m, zcol = "z", palette = pal, file = tempfile(fileext = ".html"))
  expect_identical(layer_kinds(v), c("polygon", "path", "point"))
  expect_identical(blob_rgba(v, "m_polygon"), all[c(4, 5), ])
  expect_identical(blob_rgba(v, "m_path"), all[3, , drop = FALSE])
  expect_identical(blob_rgba(v, "m_point"), all[c(1, 5), ])
  expect_identical(v$scene$layers[[2]]$stroke, list(column = "color"))
})

test_that("zcol is checked", {
  skip_if_not_installed("sf")
  pol <- sf::st_sf(z = 1, geometry = lonlat(list(ring(0, 20, -80, -70))))
  expect_error(view(pol, zcol = "nope", file = tempfile()), "not a column")
  expect_error(view(pol, zcol = "geometry", file = tempfile()), "not a column")
  expect_error(view(pol, zcol = c("z", "z"), file = tempfile()), "one column")
  expect_error(view(pol, zcol = "z", fill = c(1, 2, 3, 4), file = tempfile()), "use one")
  expect_error(view(pol, palette = "viridis", file = tempfile()), "give `zcol`")
  expect_error(view(sf::st_geometry(pol), zcol = "z", file = tempfile()), "sfc has none")
})

test_that("zcol works through view_add() and for a SpatVector", {
  skip_if_not_installed("sf")
  pol <- sf::st_sf(z = c(2, 4), geometry = lonlat(list(ring(0, 20, -80, -70), ring(40, 60, -80, -70))))
  v <- view_add(view(pol, file = tempfile(fileext = ".html")), pol, zcol = "z",
                palette = "Blues 3", name = "coloured", file = tempfile(fileext = ".html"))
  expect_true(is.numeric(v$scene$layers[[1]]$fill))
  expect_identical(v$scene$layers[[2]]$fill, list(column = "color"))
  expect_identical(blob_rgba(v, "coloured"), plain_rgba(pol$z, palette = "Blues 3"))

  skip_if_not_installed("terra")
  tv <- terra::vect(pol)
  v <- view(tv, zcol = "z", file = tempfile(fileext = ".html"))
  expect_identical(v$scene$layers[[1]]$fill, list(column = "color"))
  expect_identical(blob_rgba(v, "tv"), plain_rgba(pol$z))
  v <- view_add(view(pol, file = tempfile(fileext = ".html")), tv, zcol = "z",
                file = tempfile(fileext = ".html"))
  expect_identical(blob_rgba(v, "tv"), plain_rgba(pol$z))
})

test_that("zcol colours stay with their rows when a row cannot be transformed", {
  skip_if_not_installed("sf")
  ## The South Pole is the antipode of North Pole Lambert azimuthal equal
  ## area's centre, so PROJ cannot transform it. (An authority code, not a
  ## PROJ string: with macOS CRAN gdalraster's missing proj.db a PROJ string
  ## view CRS crashes R in aobcore::crs_domain().)
  laea <- "ESRI:102017"
  x <- sf::st_sf(z = c("a", "b", "c"),
                 geometry = lonlat(list(sf::st_point(c(0, 60)), sf::st_point(c(0, -90)),
                                        sf::st_point(c(90, 70)))))
  res <- sf::st_transform(sf::st_geometry(x), laea)
  skip_if(!identical(sf::st_is_empty(res), c(FALSE, TRUE, FALSE)))
  pal <- function(n) c("red", "green", "blue")[seq_len(n)]
  expect_warning(v <- view(x, zcol = "z", palette = pal, crs = laea,
                           file = tempfile(fileext = ".html")), "1 of 3 geometries")
  expect_identical(blob_rgba(v, "x"), plain_rgba(x$z, palette = pal)[c(1, 3), ])
})

test_that("zcol and a stroke for lines are refused together", {
  skip_if_not_installed("sf")
  lns <- sf::st_sf(z = 1, geometry = lonlat(list(sf::st_linestring(rbind(c(0, -60), c(90, -60))))))
  expect_error(view(lns, zcol = "z", stroke = c(0, 0, 0, 255), file = tempfile()),
               "`stroke` and `zcol`")
})

test_that("view_colours() edge cases: no values, long palettes, level order", {
  e <- view_colours(numeric())
  expect_identical(dim(e), c(0L, 4L))
  expect_silent(view_colours(character()))
  ## A palette function returning more than 256 colours is spread evenly,
  ## so its last colour still colours the maximum.
  long <- function(n) grDevices::grey(seq(0, 1, length.out = 1000))
  m <- view_colours(c(0, 1), palette = long)
  expect_identical(unname(m[2, ]), c(255L, 255L, 255L, 255L))
  ## Character levels sort by code point, whatever the locale.
  expect_identical(attr(view_colours(c("b", "B", "a", "A")), "key")$levels, c("A", "B", "a", "b"))
})

test_that("an unknown zcol lists at most ten columns", {
  skip_if_not_installed("sf")
  df <- as.data.frame(matrix(1, 1, 12, dimnames = list(NULL, paste0("c", 1:12))))
  x <- sf::st_sf(df, geometry = lonlat(list(sf::st_point(c(0, -70)))))
  expect_error(view(x, zcol = "nope", file = tempfile()), "\"c10\" and 2 more\\.$")
})
