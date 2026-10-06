#' Selections from a served view
#'
#' A served view (`transport = "serve"`, see Transport in [view()]) lets the
#' viewer select features in the page, and sends the selection and the
#' settled view back to R over a websocket (allboa/design decision 0007). A
#' click on a feature selects it and only it; a click with Shift (or Cmd)
#' adds or removes it; a click on nothing, or Escape, clears. Every vector
#' layer of a served view can be selected, popup or not; rasters cannot.
#' These functions read what the page sent. They need the 'httpuv' and
#' 'jsonlite' packages.
#'
#' `selection(v)` gives the selected rows as indices into the objects that
#' were viewed: a data frame with columns `source` (the name an object was
#' viewed under, as the layer label; a name used twice in one view gets
#' `_2`, `_3`, ...), `layer` (the layer id) and `row` (1-based, into that
#' object), with one row per selected row of each layer, ordered by source,
#' layer and row. A feature drawn in pieces (the parts of a geometry
#' collection) is one row per layer: a collection with polygon and point
#' parts, both selected, gives a row under each of the two layers, with the
#' same `source` and `row` (`selected()` returns it once). Attributes `at` (the pressed point, in view CRS
#' units, or `NULL`), `trigger` (`"click"`, `"toggle"` or `"clear"`),
#' `connection` (which page), `seq` and `time` say where it came from. It
#' has zero rows when nothing is selected.
#'
#' `selected(v)` gives the selected rows themselves: `x[rows, ]` of the
#' data frame (`sf` included) or `SpatVector` that was viewed, or `x[rows]`
#' of a bare geometry vector, with every column of `x`, not only those of
#' the popup. A stream (an Arrow stream or table, a DuckDB result; see Arrow
#' streams in [view()]) cannot be read again, so the view keeps the data
#' frame it was read into, every column with the geometry as [wk::wkb()] in
#' its CRS, and `selected()` gives rows of that: the selected rows' indices
#' into the stream are their row names, and `selection(v)$row`. `source`
#' names the object when the view has several: it defaults to the only one
#' with selected rows, and is an error naming them when several have
#' selected rows. With nothing selected it gives zero rows of the view's
#' only object, or `NULL` when the view has several.
#'
#' `wait_for_selection(v)` waits until the page sends its next selection (a
#' click, a toggle or a clear), then returns `selected(v)`. It services R's
#' event loop itself, so call it at the prompt or in a script and click in
#' the page; an interrupt (Esc, Ctrl-C) ends it. After `timeout` seconds it
#' returns `NULL` with a message. With no page connected it first takes in
#' what has arrived: a page that connected while R was busy counts, and a
#' selection it sent then is returned at once. With still no page connected
#' it says it is waiting for one; in a non-interactive session it is then an
#' error unless `timeout` is finite, so a script cannot hang on a page
#' nobody will open. On a view with no vector layers it is an error at once.
#'
#' `view_state(v)` gives the page's last settled view (sent 250 ms after the
#' camera stops): a list with `extent` (`c(xmin, xmax, ymin, ymax)` in view
#' CRS units), `zoom`, `units_per_pixel` and `size_px` (or `center` and
#' `zoom` for a globe), with `connection`, `seq`, `time` and `scene`; `NULL`
#' before the page has sent one.
#'
#' **When the selection is current.** R reads the page's messages only when
#' it is idle at the prompt or servicing its event loop. Each of these
#' functions first takes in every message that has arrived, so a selection
#' made just before the call is counted; inside a long computation the page
#' waits. With several tabs on one view, the last message wins.
#'
#' **Errors.** An embedded view (a page on disk) cannot send anything back
#' to R, so these functions are errors on one: view the data with
#' `transport = "serve"`. They are errors too once the view's server has
#' stopped (`v$server$stop()`, [aobcore::stop_scene_servers()]), since the
#' selection lived in the server, and on a view that [view_add()] has
#' replaced: `view_add()` serves its new scene on the same server, which
#' clears the selection and reloads the open page, and only the view it
#' returned knows the new scene's rows.
#'
#' **Memory.** A view keeps each vector object it was given (without a
#' copy: R copies on change), so `selected()` can return its rows; the
#' object stays in memory as long as the view does.
#'
#' @param v A view from [view()] or [view_add()].
#' @param source With several objects in the view, the name of the one to
#'   return rows of (a `source` value of `selection(v)`). `NULL` picks the
#'   only one with selected rows.
#' @param timeout Seconds to wait; `Inf` (the default) waits until a
#'   selection arrives.
#' @return `selection()`: a data frame. `selected()` and
#'   `wait_for_selection()`: rows of the viewed object, or `NULL`.
#'   `view_state()`: a list, or `NULL`.
#' @seealso [aobcore::serve_scene_socket] for the server's side and its
#'   messages.
#' @name selection
#' @examplesIf interactive() && requireNamespace("sf", quietly = TRUE) && requireNamespace("httpuv", quietly = TRUE) && nzchar(system.file(package = "jsonlite"))
#' nc <- sf::st_read(system.file("shape", "nc.shp", package = "sf"), quiet = TRUE)
#' v <- view(nc, transport = "serve")
#' v
#' ## Click a county in the page, then:
#' wait_for_selection(v, timeout = 60)
#' selection(v)
#' selected(v)
#' view_state(v)
#' v$server$stop()
NULL

#' @rdname selection
#' @export
selection <- function(v) {
  srv <- selectable_server(v)
  sel <- srv$selection()
  check_current(v)
  map_selection(v, sel)
}

#' @rdname selection
#' @export
selected <- function(v, source = NULL) {
  check_source_arg(source)
  rows_of(v, selection(v), source)
}

#' @rdname selection
#' @export
wait_for_selection <- function(v, timeout = Inf, source = NULL) {
  check_source_arg(source)
  if (!is.numeric(timeout) || length(timeout) != 1L || is.na(timeout) || timeout < 0) {
    stop("`timeout` must be a number of seconds (Inf to wait until a selection arrives).",
         call. = FALSE)
  }
  srv <- selectable_server(v)
  if (!length(v$sources)) {
    stop("This view has no vector layers, so nothing in it can be selected.", call. = FALSE)
  }
  ## Count the pages without running the loop: a selection already queued
  ## (made while R was busy) is then taken in by the wait, as the next one.
  if (pages_now(srv) == 0L) {
    ## A page may have connected (and even selected) while R was busy, and
    ## not been taken in yet: its socket opens over several turns of the
    ## loop. Run the loop briefly, until a page is connected; a selection
    ## that arrived meanwhile is the next one.
    before <- received_selects(srv)
    t0 <- Sys.time()
    grace <- min(1, timeout)
    while (pages_now(srv) == 0L && received_selects(srv) == before &&
           as.numeric(Sys.time() - t0, units = "secs") < grace) {
      httpuv::service(20)
    }
    if (received_selects(srv) > before) {
      check_current(v)
      return(rows_of(v, map_selection(v, srv$selection()), source))
    }
    timeout <- max(0, timeout - as.numeric(Sys.time() - t0, units = "secs"))
  }
  if (pages_now(srv) == 0L) {
    if (!is_interactive() && !is.finite(timeout)) {
      stop("No page is connected to this view's server, and the session is not ",
           "interactive, so a selection may never come. Open ", srv$url, " in a browser ",
           "first, or give a finite `timeout`.", call. = FALSE)
    }
    tell_waiting(srv)
  }
  sel <- srv$wait("select", timeout = timeout)
  if (is.null(sel)) return(invisible(NULL))
  check_current(v)
  rows_of(v, map_selection(v, sel), source)
}

#' @rdname selection
#' @export
view_state <- function(v) {
  srv <- selectable_server(v)
  out <- srv$view_state()
  check_current(v)
  out
}

## ---- internals -------------------------------------------------------------

## The view's server, when the page can send it selections; else an error
## that says why not and what to do.
selectable_server <- function(v) {
  if (!inherits(v, "aob_view") || is.null(v$scene)) {
    stop("`v` must be a view from view().", call. = FALSE)
  }
  srv <- v$server
  if (is.null(srv)) {
    stop("This view is embedded in a page on disk, which cannot send selections back to R. ",
         "View it with `transport = \"serve\"` (needs the 'httpuv' and 'jsonlite' packages).",
         call. = FALSE)
  }
  if (!isTRUE(srv$running())) {
    stop("This view's server has stopped, and its selection and view went with it. ",
         "View the data again with `transport = \"serve\"`.", call. = FALSE)
  }
  check_current(v)
  if (!isTRUE(srv$status()$socket)) {
    stop("This view's page cannot send selections back to R without the 'jsonlite' ",
         "package. Install it with install.packages(\"jsonlite\") and view the data again.",
         call. = FALSE)
  }
  srv
}

## A view whose server now serves another scene (view_add() replaced it)
## has row maps for the old one: never map through them.
check_current <- function(v) {
  if (!identical(v$serial, v$server$status()$serial)) {
    stop("This view was replaced by view_add(); use the view it returned.", call. = FALSE)
  }
  invisible(v)
}

## Pages connected to a server; 0 for a stopped one or one with no socket.
page_count <- function(srv) {
  tryCatch(as.integer(srv$connections()), error = function(e) 0L)
}

pages_now <- function(srv) {
  tryCatch(srv$status()$connections, error = function(e) 0L)
}

## How many selections the server has taken in (aobcore's count, which
## srv$wait() also compares against).
received_selects <- function(srv) {
  n <- srv$status()$received[["select"]]
  if (is.null(n)) 0 else n
}

## Said once per server: wait_for_selection() is waiting for a page to
## connect. A message, not a warning, since a warning would show only
## after the wait has ended.
waiting_told <- new.env(parent = emptyenv())

tell_waiting <- function(srv) {
  if (isTRUE(waiting_told[[srv$token]])) return(invisible())
  assign(srv$token, TRUE, envir = waiting_told)
  message("No page is connected to this view yet; waiting for one to connect and ",
          "send a selection. Open ", srv$url, " if it is not open.")
  invisible()
}

source_names <- function(v) vapply(v$sources, function(s) s$name, "")

## The server's selection (1-based Arrow rows per layer id) as rows of the
## viewed objects, through the row maps the view kept.
map_selection <- function(v, sel) {
  out <- data.frame(source = character(), layer = character(), row = integer(),
                    stringsAsFactors = FALSE)
  pieces <- list()
  for (i in seq_along(v$sources)) {
    s <- v$sources[[i]]
    for (id in names(s$layers)) {
      r <- sel$row[sel$layer == id]
      if (!length(r)) next
      idx <- s$layers[[id]][r[r >= 1 & r <= length(s$layers[[id]])]]
      idx <- sort(unique(idx[!is.na(idx)]))
      if (!length(idx)) next
      pieces[[length(pieces) + 1L]] <- data.frame(source = s$name, layer = id, row = idx,
                                                  stringsAsFactors = FALSE)
    }
  }
  if (length(pieces)) out <- do.call(rbind, pieces)
  rownames(out) <- NULL
  for (a in c("at", "trigger", "connection", "seq", "time")) attr(out, a) <- attr(sel, a)
  out
}

check_source_arg <- function(source) {
  if (!is.null(source) && (!is.character(source) || length(source) != 1L || is.na(source))) {
    stop("`source` must be NULL or the name of one object in the view.", call. = FALSE)
  }
  invisible(source)
}

## The rows of one viewed object that `sel` (from map_selection()) selects.
rows_of <- function(v, sel, source = NULL) {
  nms <- source_names(v)
  if (!length(nms)) {
    stop("This view has no vector layers, so nothing in it can be selected.", call. = FALSE)
  }
  shown <- function(x) paste0("\"", x, "\"", collapse = ", ")
  if (is.null(source)) {
    with <- unique(sel$source)
    if (length(with) > 1L) {
      stop("Rows of several objects are selected: ", shown(with), ". Choose one with ",
           "`source = `.", call. = FALSE)
    }
    if (length(with) == 1L) {
      source <- with
    } else if (length(nms) == 1L) {
      source <- nms
    } else {
      return(NULL)
    }
  } else if (!source %in% nms) {
    stop("`source` \"", source, "\" is not an object in the view; it has ", shown(nms), ".",
         call. = FALSE)
  }
  x <- v$sources[[match(source, nms)]]$object
  rows <- sort(unique(sel$row[sel$source == source]))
  if (is.data.frame(x) || inherits(x, "SpatVector")) x[rows, ] else x[rows]
}
