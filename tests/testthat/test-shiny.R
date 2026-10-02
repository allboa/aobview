# Views in Shiny (allboa/design decision 0009). The browser side is
# tools/shiny-check.R and tools/shiny-check.mjs.

shiny_bases <- function() {
  d <- data.frame(base = c("Casey", "Davis", "Mawson"))
  d$geom <- wk::xy(c(110.53, 77.97, 62.87), c(-66.28, -68.58, -67.6), crs = "OGC:CRS84")
  d
}

test_that("aobviewOutput() is a sized element with the renderer and the binding", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("htmltools")
  ui <- aobviewOutput("map", height = 300)
  r <- htmltools::renderTags(ui)
  expect_match(r$html, "<div id=\"map\" class=\"aobview-output aob-fragment\" style=\"width:100%;height:300px;\"></div>",
               fixed = TRUE)
  expect_identical(vapply(r$dependencies, function(d) d$name, ""), c("aob-renderer", "aobview-binding"))
  b <- r$dependencies[[2]]
  expect_true(file.exists(file.path(b$src$file, b$script)))
  expect_error(aobviewOutput("map", width = TRUE), "CSS size")
})

test_that("renderAobview() sends the scene, and the selection functions map the page's input", {
  skip_if_not_installed("shiny")
  d <- shiny_bases()
  server <- function(input, output, session) {
    output$map <- renderAobview(view(d, crs = "EPSG:3031", theme = "dark"))
  }
  shiny::testServer(server, {
    value <- output$map
    expect_type(value, "list")
    expect_identical(value$scene, aobcore::scene_json(session$userData$aobview_map$view$scene))
    expect_identical(value$theme, "dark")
    expect_identical(value$serial, 1L)
    expect_identical(as.character(value$select), "d")
    expect_true(all(vapply(value$blobs, is.raw, TRUE)))
    expect_identical(names(value$blobs), "d")

    expect_identical(nrow(aobview_selection("map")), 0L)
    expect_identical(nrow(aobview_selected("map")), 0L)
    expect_null(aobview_view_state("map"))

    # The page's select message, as Shiny hands it over (0-based rows).
    session$setInputs(map_aob_select = list(type = "select", scene = 1L, seq = 3L, trigger = "toggle",
                                            items = list(list(layer = "d", rows = list(0L, 2L))),
                                            at = list(1, 2)))
    s <- aobview_selection("map")
    expect_identical(s$row, c(1L, 3L))
    expect_identical(unique(s$source), "d")
    expect_identical(attr(s, "trigger"), "toggle")
    expect_identical(attr(s, "at"), c(1, 2))
    expect_identical(aobview_selected("map")$base, c("Casey", "Mawson"))
    expect_error(aobview_selected("map", source = "nope"), "not an object in the view")

    # A message from an older render is nothing selected.
    session$setInputs(map_aob_select = list(type = "select", scene = 0L, seq = 4L, trigger = "click",
                                            items = list(list(layer = "d", rows = list(1L)))))
    expect_identical(nrow(aobview_selection("map")), 0L)

    session$setInputs(map_aob_view = list(type = "view", scene = 1L, seq = 5L,
                                          extent = list(-1, 1, -1, 1), zoom = -12))
    st <- aobview_view_state("map")
    expect_identical(st$zoom, -12)
    expect_null(st$type)
  })
})

test_that("renderAobview() refuses a served view and anything not a view", {
  skip_if_not_installed("shiny")
  skip_if_no_httpuv()
  on.exit(aobcore::stop_scene_servers(), add = TRUE)
  v <- served(view(shiny_bases(), transport = "serve"))
  shiny::testServer(function(input, output, session) {
    output$a <- renderAobview(v)
    output$b <- renderAobview(42)
    output$c <- renderAobview(NULL)
  }, {
    expect_error(output$a, "served view cannot be shown in a Shiny app")
    expect_error(output$b, "needs a view")
    expect_null(output$c)
    expect_null(aobview_selection("c"))
  })
})

test_that("while Shiny runs, \"auto\" embeds over the threshold with a warning naming Shiny", {
  skip_if_no_terra()
  skip_if_not_installed("shiny")
  sst <- terra::rast(extdata("polar_3031.tif"))
  op <- options(aobview.embed_max = 100)
  on.exit(options(op), add = TRUE)
  local_mocked_bindings(is_interactive = function() TRUE, has_httpuv = function() TRUE,
                        in_shiny = function() TRUE)
  expect_warning(v <- view(sst, file = html()), "over getOption.*made in a Shiny app")
  expect_null(v$server)
})
