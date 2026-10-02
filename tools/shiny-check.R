# Headless check of a view in Shiny (allboa/design decision 0009): an app
# with aobviewOutput()/renderAobview() and outputs that show what
# aobview_selected() and aobview_view_state() read from the page's input
# values. tools/shiny-check.mjs drives it in headless Chromium.
#
#   Rscript tools/shiny-check.R <port> &
#   node tools/shiny-check.mjs http://127.0.0.1:<port> [screenshot.png]
suppressPackageStartupMessages(library(aobview))
port <- as.integer(commandArgs(TRUE)[1])
if (is.na(port)) stop("usage: Rscript tools/shiny-check.R <port>")

bases <- data.frame(base = c("Casey", "Davis", "Mawson"), staff = c(70L, 70L, 60L))
bases$geom <- wk::xy(c(110.53, 77.97, 62.87), c(-66.28, -68.58, -67.60), crs = "OGC:CRS84")
coast <- wk::wkt("LINESTRING (60 -66, 80 -68.5, 100 -66, 115 -66.5)", crs = "OGC:CRS84")
# The stations in the view CRS, for the page side to click on.
xy <- wk::wk_coords(wk::wk_transform(bases$geom, PROJ::proj_trans_create("OGC:CRS84", "EPSG:3031")))
targets <- paste0("[", paste0("[", xy$x, ",", xy$y, "]", collapse = ","), "]")

ui <- shiny::fluidPage(
  shiny::tags$h3("A view in Shiny"),
  shiny::actionButton("again", "Render again"),
  aobviewOutput("map", height = "420px"),
  shiny::tags$pre(id = "targets", targets),
  shiny::tags$p("Selected:"),
  shiny::verbatimTextOutput("picked"),
  shiny::verbatimTextOutput("camera")
)
server <- function(input, output, session) {
  output$map <- renderAobview({
    input$again
    v <- view(bases, crs = "EPSG:3031", zcol = "base", theme = "light")
    view_add(v, coast, popup = FALSE)
  })
  output$picked <- shiny::renderText({
    s <- aobview_selection("map")
    rows <- aobview_selected("map", source = "bases")
    paste0("trigger=", attr(s, "trigger") %||% "none", "; layers=",
           paste(unique(s$layer), collapse = ","), "; bases=",
           paste(rows$base, collapse = ","))
  })
  output$camera <- shiny::renderText({
    st <- aobview_view_state("map")
    if (is.null(st)) "camera=none" else paste0("camera=", length(st$extent), " extent values")
  })
}
`%||%` <- function(x, y) if (is.null(x)) y else x
shiny::runApp(shiny::shinyApp(ui, server), port = port, host = "127.0.0.1", launch.browser = FALSE)
