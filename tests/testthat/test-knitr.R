# Views in knitted documents (allboa/design decision 0009).

bases_df <- function() {
  d <- data.frame(base = c("Casey", "Davis", "Mawson"))
  d$geom <- wk::xy(c(110.53, 77.97, 62.87), c(-66.28, -68.58, -67.6), crs = "OGC:CRS84")
  d
}

knit_md <- function(rmd_lines) {
  d <- tempfile("knit-")
  dir.create(d)
  rmd <- file.path(d, "doc.Rmd")
  writeLines(rmd_lines, rmd)
  out <- knitr::knit(rmd, output = file.path(d, "doc.md"), quiet = TRUE, envir = new.env())
  list(md = paste(readLines(out, warn = FALSE), collapse = "\n"),
       meta = knitr::knit_meta(clean = TRUE))
}

test_that("a view in a chunk is embedded in the document, the renderer as a dependency", {
  skip_if_not_installed("knitr")
  k <- knit_md(c(
    "```{r, echo = FALSE}",
    "library(aobview)",
    "d <- data.frame(base = c('Casey', 'Davis'))",
    "d$geom <- wk::xy(c(110.53, 77.97), c(-66.28, -68.58), crs = 'OGC:CRS84')",
    "view(d, theme = 'light')",
    "```",
    "",
    "Text between.",
    "",
    "```{r, echo = FALSE, fig.height = 3}",
    "view(d, zcol = 'base', crs = 'EPSG:3031')",
    "```"
  ))
  divs <- regmatches(k$md, gregexpr("<div class=\"aob-fragment\"[^>]*>", k$md))[[1]]
  expect_length(divs, 2L)
  expect_match(divs[1], "style=\"width:100%;height:672px;\" data-theme=\"light\"", fixed = TRUE) # knitr: 7 in
  expect_match(divs[2], "style=\"width:100%;height:288px;\" data-aob-scene=", fixed = TRUE)
  ids <- sub(".*data-aob-scene=\"([^\"]+)\".*", "\\1", divs)
  expect_false(ids[1] == ids[2])
  for (id in ids) {
    expect_true(grepl(paste0("<script type=\"application/json\" id=\"", id, "\">"), k$md, fixed = TRUE))
  }
  # The data are in the document; the renderer is not inlined in it, but
  # handed to the host as a dependency (rmarkdown and Quarto keep one).
  expect_match(k$md, "data-aob-blob=", fixed = TRUE)
  expect_false(grepl("aob-renderer", k$md, fixed = TRUE))
  deps <- Filter(function(m) inherits(m, "html_dependency"), k$meta)
  expect_identical(unique(vapply(deps, function(m) m$name, "")), "aob-renderer")
  expect_false(grepl("<view>", k$md, fixed = TRUE))
})

test_that("chunk options size the view, and its theme is kept", {
  skip_if_not_installed("knitr")
  skip_if_not_installed("htmltools")
  v <- view(bases_df(), file = html(), theme = "dark")
  out <- knit_print.aob_view(v, options = list(out.width = "80%", out.height = "300px"))
  expect_s3_class(out, "knit_asis")
  expect_match(out, "style=\"width:80%;height:300px;\" data-theme=\"dark\"", fixed = TRUE)
  # knitr's own numeric out.width (fig.width * dpi under fig.retina) is not used.
  out <- knit_print.aob_view(v, options = list(fig.height = 4, out.width = 672))
  expect_match(out, "style=\"width:100%;height:384px;\"", fixed = TRUE)
  out <- knit_print.aob_view(v, options = list())
  expect_match(out, "height:480px;", fixed = TRUE)
  expect_error(knit_print.aob_view(v, options = list(out.width = "\\linewidth")), "CSS size")
})

test_that("a served view cannot be knitted", {
  skip_if_not_installed("knitr")
  skip_if_no_httpuv()
  on.exit(aobcore::stop_scene_servers(), add = TRUE)
  v <- served(view(bases_df(), transport = "serve"))
  expect_error(knit_print.aob_view(v, options = list()),
               "served view cannot be shown in a knitted document.*transport = \"embed\"")
})

test_that("while knitting, \"auto\" embeds over the threshold with a warning naming the document", {
  skip_if_no_terra()
  sst <- terra::rast(extdata("polar_3031.tif"))
  op <- options(aobview.embed_max = 100, knitr.in.progress = TRUE)
  on.exit(options(op), add = TRUE)
  local_mocked_bindings(is_interactive = function() TRUE, has_httpuv = function() TRUE)
  expect_warning(v <- view(sst, file = html()),
                 "over getOption.*knitted into a document")
  expect_null(v$server)
  expect_gt(length(tile_blobs(v)), 0L)
})

test_that("rmarkdown renders two views with one copy of the renderer", {
  skip_if_not_installed("knitr")
  skip_if_not_installed("rmarkdown")
  skip_if_not(rmarkdown::pandoc_available("2.0"), "pandoc is not available")
  d <- tempfile("render-")
  dir.create(d)
  rmd <- file.path(d, "doc.Rmd")
  writeLines(c(
    "---", "title: Two views", "output: html_document", "---", "",
    "```{r, echo = FALSE}",
    "d <- data.frame(base = c('Casey', 'Davis'))",
    "d$geom <- wk::xy(c(110.53, 77.97), c(-66.28, -68.58), crs = 'OGC:CRS84')",
    "aobview::view(d)",
    "aobview::view(d, crs = 'EPSG:3031', theme = 'dark')",
    "```"
  ), rmd)
  out <- rmarkdown::render(rmd, quiet = TRUE, envir = new.env())
  page <- readChar(out, file.size(out), useBytes = TRUE)
  expect_length(regmatches(page, gregexpr("<div class=\"aob-fragment\"", page, fixed = TRUE))[[1]], 2L)
  # As wide as the document's column, whatever fig.retina makes of out.width.
  expect_match(page, "<div class=\"aob-fragment\" style=\"width:100%;height:480px;\" data-aob-scene=",
               fixed = TRUE)
  # The bundle's banner, once: inlined as text, or (by pandoc's
  # self-contained mode) in a data URI, base64 or percent-encoded.
  forms <- c("/* aob-renderer ", "LyogYW9iLXJlbmRlcmVy", "/*%20aob-renderer%20")
  n <- vapply(forms, function(f) lengths(regmatches(page, gregexpr(f, page, fixed = TRUE))), 0L)
  expect_identical(sum(n), 1L, info = paste(names(n), n, sep = ": ", collapse = "; "))
})

test_that("print(v) opens no page while knitr renders a document", {
  v <- view(bases_df(), file = html())
  opened <- character()
  local_mocked_bindings(in_document = function() TRUE,
                        open_page = function(file) opened <<- c(opened, file))
  expect_false(can_open())
  expect_output(print(v), "<view>", fixed = TRUE)
  expect_length(opened, 0L)
})
