# Browser check of selections (allboa/design decision 0007, aobview#22): R
# serves views and waits with wait_for_selection() while
# tools/selection-check.mjs clicks in headless Chromium. Polar first: the
# CCAMLR fixture in EPSG:3031 (click, Shift-click adds and removes, Escape
# clears, view_state(), view_add() reloading the open page with no new tab,
# the old view an error, the page's note after the server stops), then
# North Carolina in Web Mercator. The two hand steps over by JSON files in
# <dir>. Needs aobcore with the renderer's socket client (aobcore#41).
#
#   Rscript tools/selection-check.R <dir> &
#   node tools/selection-check.mjs <dir> <screenshot-dir>
suppressPackageStartupMessages({ library(aobview); library(sf) })
dir <- commandArgs(TRUE)[1]
if (is.na(dir)) stop("usage: Rscript tools/selection-check.R <dir>")
unlink(dir, recursive = TRUE)
dir.create(dir, recursive = TRUE)
log <- function(...) cat(format(Sys.time(), "%H:%M:%OS2"), ..., "\n", sep = "")
fails <- 0L
check <- function(ok, what) {
  log(if (isTRUE(ok)) "ok   " else "FAIL ", what)
  if (!isTRUE(ok)) fails <<- fails + 1L
}
say <- function(name, x) writeLines(jsonlite::toJSON(x, auto_unbox = TRUE, digits = NA),
                                    file.path(dir, paste0(name, ".json")))
# Run the loop until the page writes `name`.
hear <- function(name, timeout = 90) {
  f <- file.path(dir, paste0(name, ".json"))
  t0 <- Sys.time()
  while (!file.exists(f)) {
    httpuv::service(50)
    if (as.numeric(Sys.time() - t0, units = "secs") > timeout) stop("no ", name)
  }
  Sys.sleep(0.1)
  jsonlite::fromJSON(f)
}
# A point inside feature i, in the view CRS.
inside <- function(v, x, i) {
  crs <- sf::st_crs(as.character(v$scene$view$crs))
  p <- sf::st_point_on_surface(sf::st_transform(sf::st_geometry(x)[i], crs))
  as.numeric(sf::st_coordinates(p))
}
wait_sel <- function(v) withCallingHandlers(wait_for_selection(v, timeout = 60),
                                            message = function(m) log("message: ", conditionMessage(m)))

ccamlr <- sf::st_read(system.file("extdata", "ccamlr_statistical_areas.geojson",
                                  package = "aobview"), quiet = TRUE)
ccamlr$area <- paste0("Area ", substr(ccamlr$GAR_Long_Label, 1, 2))
coast <- sf::st_read(system.file("extdata", "coastline_south_40s.geojson", package = "aobcore"),
                     quiet = TRUE)
nc <- sf::st_read(system.file("shape", "nc.shp", package = "sf"), quiet = TRUE)
## NAD27 to WGS 84 needs a datum grid this sandbox cannot fetch: relabel the
## lon/lat (an illustration; the shift is tens of metres).
nc <- suppressWarnings(sf::st_set_crs(nc, "OGC:CRS84"))

run <- function(tag, x, crs, label_col, i, j) {
  v <- suppressWarnings(view(x, crs = crs, zcol = if (tag == "3031") "area",
                             popup = label_col, transport = "serve", name = tag))
  say(paste0(tag, "-1"), list(url = v$server$url, click = inside(v, x, i), shift = FALSE))
  rows <- wait_sel(v)
  pg <- hear(paste0(tag, "-1-page"))
  check(identical(selection(v)$row, as.integer(i)), paste(tag, "click: selection(v)$row is", i))
  check(nrow(rows) == 1L && identical(rows[[label_col]], x[[label_col]][i]) &&
          identical(as.character(rows[[label_col]]), pg$popup),
        paste0(tag, " click: wait_for_selection() row ", rows[[label_col]],
               " is the popup's ", pg$popup))
  ## Shift-click adds.
  say(paste0(tag, "-2"), list(click = inside(v, x, j), shift = TRUE))
  rows <- wait_sel(v)
  check(identical(sort(selection(v)$row), sort(as.integer(c(i, j)))),
        paste(tag, "shift-click adds: rows", paste(selection(v)$row, collapse = ",")))
  check(identical(attr(selection(v), "trigger"), "toggle"), paste(tag, "trigger toggle"))
  ## Shift-click again removes.
  say(paste0(tag, "-3"), list(click = inside(v, x, j), shift = TRUE))
  rows <- wait_sel(v)
  check(identical(selection(v)$row, as.integer(i)), paste(tag, "shift-click removes"))
  ## Escape clears.
  say(paste0(tag, "-4"), list(key = "Escape"))
  rows <- wait_sel(v)
  check(nrow(rows) == 0L && nrow(selection(v)) == 0L, paste(tag, "Escape clears"))
  hear(paste0(tag, "-4-page"))
  v
}

v <- run("3031", ccamlr, "EPSG:3031", "GAR_Long_Label", 3L, 9L)
st <- view_state(v)
check(!is.null(st$extent), paste("3031 view_state extent", paste(signif(st$extent, 4), collapse = " ")))
## view_add(): the open page reloads, no new page, the old view is an error.
n_before <- v$server$connections()
v2 <- suppressWarnings(view_add(v, coast, popup = FALSE))
say("3031-5", list(expect = "reload"))
pg <- hear("3031-5-page")
check(identical(v2$server$connections(), n_before) && identical(n_before, 1L),
      paste("view_add: still", n_before, "page connected, after reload; camera kept:", pg$cameraKept))
check(inherits(try(selection(v), silent = TRUE), "try-error") &&
        grepl("replaced by view_add", attr(try(selection(v), silent = TRUE), "condition")$message),
      "old view is an error after view_add")
say("3031-6", list(click = inside(v2, ccamlr, 3L), shift = FALSE))
rows <- wait_sel(v2)
check(identical(rows$GAR_Long_Label, ccamlr$GAR_Long_Label[3]), "after reload a click selects on v2")
v2$server$stop()
say("3031-7", list(expect = "closed"))
pg <- hear("3031-7-page")
check(identical(pg$link, "closed"), paste("after stop the page link is", pg$link, "note:", pg$note))

invisible(run("3857", nc, "EPSG:3857", "NAME", 50L, 1L))
say("done", list(done = TRUE))
aobcore::stop_scene_servers()
log(if (fails) paste(fails, "FAILED") else "ALL OK")
quit(status = if (fails) 1L else 0L)
