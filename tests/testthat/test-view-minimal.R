minimal_data <- function() {
  sf::st_sf(
    a = c(1, 2, 3), b = c("x", "y", "z"),
    geometry = lonlat(list(ring(-40, 40, -80, -70),
                           sf::st_linestring(rbind(c(0, -60), c(90, -60))),
                           sf::st_point(c(0, -70))))
  )
}

style_of <- function(l) l[intersect(names(l), c("fill", "stroke", "stroke_width_px", "radius_px"))]

test_that("style = \"minimal\" draws one-pixel outlines, unfilled polygons and dots", {
  skip_if_not_installed("sf")
  x <- minimal_data()
  v <- view(x, style = "minimal", file = tempfile(fileext = ".html"))
  ly <- v$scene$layers
  expect_identical(layer_kinds(v), c("polygon", "path", "point"))
  blue <- c(51L, 102L, 204L, 255L)
  expect_identical(style_of(ly[[1]]), list(stroke = blue, stroke_width_px = 1))
  expect_identical(style_of(ly[[2]]), list(stroke = blue, stroke_width_px = 1))
  expect_identical(style_of(ly[[3]]), list(fill = blue, radius_px = 1))
  ## No popup, so no attribute columns in the page.
  for (l in ly) {
    expect_null(l$popup)
    expect_identical(blob_names(v, l$id), "geometry")
  }
  expect_valid_scene(v)
})

test_that("the minimal style takes popup, colours and widths when they are given", {
  skip_if_not_installed("sf")
  x <- minimal_data()
  v <- view(x, style = "minimal", popup = "a", fill = c(200, 0, 0, 80), stroke_width_px = 2,
            radius_px = 0.5, file = tempfile(fileext = ".html"))
  ly <- v$scene$layers
  expect_identical(ly[[1]]$fill, c(200L, 0L, 0L, 80L))
  expect_identical(ly[[1]]$stroke_width_px, 2)
  expect_identical(ly[[3]]$radius_px, 0.5)
  expect_null(ly[[3]][["stroke"]])
  expect_identical(unlist(ly[[1]]$popup$columns), "a")
  expect_identical(blob_names(v, ly[[1]]$id), c("a", "geometry"))
})

test_that("with zcol, the minimal style colours polygon outlines", {
  skip_if_not_installed("sf")
  x <- minimal_data()
  v <- view(x, style = "minimal", zcol = "b", file = tempfile(fileext = ".html"))
  ly <- v$scene$layers
  expect_null(ly[[1]]$fill)
  expect_identical(ly[[1]]$stroke, list(column = "color"))
  expect_identical(ly[[2]]$stroke, list(column = "color"))
  expect_identical(ly[[3]]$fill, list(column = "color"))
  expect_error(view(x, style = "minimal", zcol = "b", stroke = c(0, 0, 0, 255),
                    file = tempfile(fileext = ".html")),
               "`stroke` and `zcol`")
})

test_that("the default style is unchanged and popups stay on by default", {
  skip_if_not_installed("sf")
  x <- minimal_data()
  v <- view(x, file = tempfile(fileext = ".html"))
  expect_identical(v$scene$layers[[1]]$fill, c(51L, 102L, 204L, 90L))
  expect_identical(v$scene$layers[[3]]$stroke, c(255L, 255L, 255L, 255L))
  expect_identical(unlist(v$scene$layers[[1]]$popup$columns), c("a", "b"))
})

test_that("view_add() and sfc take the minimal style; a bad style is an error", {
  skip_if_not_installed("sf")
  x <- minimal_data()
  v <- view_add(view(x[1, ], file = tempfile(fileext = ".html")), sf::st_geometry(x)[3],
                style = "minimal", file = tempfile(fileext = ".html"))
  expect_identical(v$scene$layers[[2]]$radius_px, 1)
  expect_error(view(x, style = "tiny"), "`style` must be one of")
  expect_error(view(x, style = c("minimal", "default")), "`style` must be one of")
})

test_that("a name is not deparsed from a whole data set passed by do.call()", {
  skip_if_not_installed("sf")
  n <- 2e5
  x <- sf::st_as_sf(data.frame(x = seq_len(n), y = seq_len(n)), coords = 1:2, crs = 3031)
  t <- system.time(nm <- deparse_name(x))[["elapsed"]]
  expect_lt(t, 1)
  expect_lte(nchar(nm), 60L)
})
