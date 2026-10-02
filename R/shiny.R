#' Views in Shiny apps
#'
#' `aobviewOutput()` places a view in a Shiny app's UI and `renderAobview()`
#' draws one there from the server: its expression returns a view from
#' [view()] or [view_add()] (or `NULL` for none). The scene and its data
#' travel to the browser over the Shiny session's own connection, and the
#' renderer is loaded once for every view in the app (allboa/design decision
#' 0009). The 'shiny' package is needed (it is suggested, not imported).
#'
#' **Transport.** A browser can reach only the Shiny app's server, so a view
#' in Shiny is embedded: while Shiny runs, `transport = "auto"` never serves
#' (over `getOption("aobview.embed_max")` the tiles are embedded with a
#' warning), and rendering a served view is an error.
#'
#' **Selections.** Every vector layer of a rendered view can be selected, as
#' in a served view: a click on a feature selects it and only it, Shift (or
#' Cmd) and click adds or removes it, and a click on nothing or Escape
#' clears. The page sends each change as the input value
#' `input$<outputId>_aob_select` and the settled camera as
#' `input$<outputId>_aob_view` (protocol 1 messages, decision 0007).
#' `aobview_selection()`, `aobview_selected()` and `aobview_view_state()`
#' read those inputs, so they are reactive, and return what [selection()],
#' [selected()] and [view_state()] return for a served view: the selected
#' rows of the objects that were viewed, mapped through the rendered view.
#' A new render clears the selection; a message from an older render is
#' ignored.
#'
#' @param outputId The output's id.
#' @param width,height CSS sizes, such as `"100%"` or `"480px"`; a number
#'   is pixels.
#' @param expr An expression that returns a view (an `"aob_view"`) or
#'   `NULL`.
#' @param env The environment in which to evaluate `expr`.
#' @param quoted Is `expr` a quoted expression (with `quote()`)?
#' @param source With several objects in the view, the name of the one to
#'   return rows of, as for [selected()].
#' @param session The Shiny session.
#' @return `aobviewOutput()`: a UI element. `renderAobview()`: a render
#'   function for `output$<outputId>`. `aobview_selection()`: a data frame
#'   (`source`, `layer`, `row`) with attributes `at` and `trigger`.
#'   `aobview_selected()`: rows of the viewed object, or `NULL`.
#'   `aobview_view_state()`: a list, or `NULL`.
#' @name aobview-shiny
#' @examplesIf interactive() && requireNamespace("shiny", quietly = TRUE)
#' bases <- data.frame(base = c("Casey", "Davis", "Mawson"))
#' bases$geom <- wk::xy(c(110.53, 77.97, 62.87), c(-66.28, -68.58, -67.60),
#'                      crs = "OGC:CRS84")
#' ui <- shiny::fluidPage(aobviewOutput("map"), shiny::tableOutput("picked"))
#' server <- function(input, output, session) {
#'   output$map <- renderAobview(view(bases, zcol = "base"))
#'   output$picked <- shiny::renderTable(aobview_selected("map"))
#' }
#' shiny::shinyApp(ui, server)
NULL

#' @rdname aobview-shiny
#' @export
aobviewOutput <- function(outputId, width = "100%", height = "480px") {
  check_shiny()
  size <- function(x, what) {
    if (is.numeric(x) && length(x) == 1L && !is.na(x)) return(paste0(x, "px"))
    if (is.character(x) && length(x) == 1L && !is.na(x)) return(shiny::validateCssUnit(x))
    stop("`", what, "` must be a number of pixels or a CSS size.", call. = FALSE)
  }
  el <- shiny::div(id = outputId, class = "aobview-output aob-fragment",
                   style = paste0("width:", size(width, "width"), ";height:",
                                  size(height, "height"), ";"))
  htmltools::attachDependencies(el, list(aobcore::renderer_dependency(), binding_dependency()))
}

#' @rdname aobview-shiny
#' @export
renderAobview <- function(expr, env = parent.frame(), quoted = FALSE) {
  check_shiny()
  if (!quoted) expr <- substitute(expr)
  func <- shiny::exprToFunction(expr, env, quoted = TRUE)
  shiny::createRenderFunction(func, function(value, session, name, ...) {
    shiny_value(value, session, name)
  }, aobviewOutput, list())
}

#' @rdname aobview-shiny
#' @export
aobview_selection <- function(outputId, session = shiny::getDefaultReactiveDomain()) {
  rendered <- rendered_view(outputId, session)
  msg <- session$input[[paste0(outputId, "_aob_select")]]
  if (is.null(rendered)) return(NULL)
  map_selection(rendered$view, shiny_selection(msg, rendered$serial))
}

#' @rdname aobview-shiny
#' @export
aobview_selected <- function(outputId, source = NULL,
                             session = shiny::getDefaultReactiveDomain()) {
  check_source_arg(source)
  sel <- aobview_selection(outputId, session)
  if (is.null(sel)) return(NULL)
  rows_of(rendered_view(outputId, session)$view, sel, source)
}

#' @rdname aobview-shiny
#' @export
aobview_view_state <- function(outputId, session = shiny::getDefaultReactiveDomain()) {
  rendered <- rendered_view(outputId, session)
  msg <- session$input[[paste0(outputId, "_aob_view")]]
  if (is.null(rendered) || is.null(msg) || !identical(as.integer(msg$scene), rendered$serial)) {
    return(NULL)
  }
  msg[setdiff(names(msg), "type")]
}

## ---- internals -------------------------------------------------------------

check_shiny <- function() {
  if (!requireNamespace("shiny", quietly = TRUE)) {
    stop("Views in Shiny need the 'shiny' package; install it with ",
         "install.packages(\"shiny\").", call. = FALSE)
  }
  invisible()
}

## Is a Shiny app running in this session (decision 0009)? Asked only when
## shiny is already loaded, so aobview never loads it.
in_shiny <- function() isNamespaceLoaded("shiny") && isTRUE(shiny::isRunning())

binding_dependency <- function() {
  htmltools::htmlDependency(
    name = "aobview-binding", version = as.character(utils::packageVersion("aobview")),
    src = system.file("www", package = "aobview"), script = "aobview-binding.js",
    all_files = FALSE
  )
}

## The render value for a view, and the view kept for the selection
## functions under the output's name, with the serial of this render.
shiny_value <- function(value, session, name) {
  key <- paste0("aobview_", name)
  if (is.null(value)) {
    session$userData[[key]] <- NULL
    return(NULL)
  }
  if (!inherits(value, "aob_view")) {
    stop("renderAobview() needs a view from view() or view_add(), or NULL.", call. = FALSE)
  }
  if (!is.null(value$server)) {
    stop("A served view cannot be shown in a Shiny app, whose browser reaches only the ",
         "app's server. Make the view with `transport = \"embed\"`.", call. = FALSE)
  }
  serial <- (session$userData[[key]]$serial %||% 0L) + 1L
  session$userData[[key]] <- list(view = value, serial = serial)
  s <- value$scene
  blobs <- attr(s, "blobs") %||% list()
  vector <- vapply(s$layers, function(l) l$kind %in% c("polygon", "path", "point"), TRUE)
  ids <- vapply(s$layers, function(l) l$id, "")
  list(scene = aobcore::scene_json(s), blobs = blobs, theme = value$theme %||% "auto",
       select = I(ids[vector]), serial = serial)
}

rendered_view <- function(outputId, session) {
  if (is.null(session)) {
    stop("No Shiny session: call this inside a Shiny server function.", call. = FALSE)
  }
  session$userData[[paste0("aobview_", outputId)]]
}

## A select message from the page (as Shiny parsed it) as the server's
## selection: layer ids and 1-based rows. Nothing selected when there is no
## message or it was made on an older render.
shiny_selection <- function(msg, serial) {
  sel <- data.frame(layer = character(), row = integer(), stringsAsFactors = FALSE)
  if (is.null(msg) || !identical(as.integer(msg$scene), serial)) return(sel)
  items <- msg$items
  if (is.data.frame(items)) items <- split(items, seq_len(nrow(items)))
  pieces <- lapply(items, function(it) {
    rows <- as.integer(unlist(it$rows)) + 1L
    data.frame(layer = rep(as.character(unlist(it$layer)), length(rows)), row = rows,
               stringsAsFactors = FALSE)
  })
  if (length(pieces)) sel <- do.call(rbind, pieces)
  attr(sel, "at") <- if (!is.null(msg$at)) as.numeric(unlist(msg$at))
  attr(sel, "trigger") <- msg$trigger
  sel
}
