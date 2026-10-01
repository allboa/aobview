## The CCAMLR statistical areas fixture in inst/extdata: a projected,
## non-lon/lat CRS (EPSG:6932) viewed in EPSG:3031.

ccamlr <- function() {
  sf::read_sf(system.file("extdata", "ccamlr_statistical_areas.geojson", package = "aobview"))
}

test_that("the fixture reads as 19 polygons in EPSG:6932", {
  skip_if_not_installed("sf")
  x <- ccamlr()
  expect_identical(nrow(x), 19L)
  expect_identical(sf::st_crs(x)$epsg, 6932L)
  expect_true(all(sf::st_geometry_type(x) == "POLYGON"))
  expect_identical(setdiff(names(x), attr(x, "sf_column")),
                   c("GAR_ID", "GAR_Name", "GAR_Short_Label", "GAR_Long_Label",
                     "GAR_Start_Date", "GAR_Size"))
})

test_that("the fixture views in EPSG:3031 as a 0.5 scene with a 3-class legend", {
  skip_if_not_installed("sf")
  x <- ccamlr()
  x$area <- paste0("Area ", substr(x$GAR_Long_Label, 1, 2))
  pop <- c("GAR_Name", "GAR_Long_Label", "GAR_Start_Date", "GAR_Size")
  v <- view(x, crs = "EPSG:3031", zcol = "area", popup = pop, name = "areas", file = html())
  expect_identical(v$scene$version, "0.5")
  expect_identical(layer_kinds(v), "polygon")
  expect_identical(v$scene$layers[[1]]$popup, list(columns = as.list(pop)))
  expect_length(v$scene$legends, 1L)
  lg <- v$scene$legends[[1]]
  expect_identical(lg$title, "area")
  expect_identical(legend_labels(lg), c("Area 48", "Area 58", "Area 88"))
  expect_null(lg$na)
  expect_identical(blob_df(v, "areas")$GAR_Name, x$GAR_Name)
  expect_valid_scene(v)
})
