# Views in Shiny apps

`aobviewOutput()` places a view in a Shiny app's UI and
`renderAobview()` draws one there from the server: its expression
returns a view from
[`view()`](https://allboa.github.io/aobview/reference/view.md) or
[`view_add()`](https://allboa.github.io/aobview/reference/view-layers.md)
(or `NULL` for none). The scene and its data travel to the browser over
the Shiny session's own connection, and the renderer is loaded once for
every view in the app (allboa/design decision 0009). The 'shiny' package
is needed (it is suggested, not imported).

## Usage

``` r
aobviewOutput(outputId, width = "100%", height = "480px")

renderAobview(expr, env = parent.frame(), quoted = FALSE)

aobview_selection(outputId, session = shiny::getDefaultReactiveDomain())

aobview_selected(
  outputId,
  source = NULL,
  session = shiny::getDefaultReactiveDomain()
)

aobview_view_state(outputId, session = shiny::getDefaultReactiveDomain())
```

## Arguments

- outputId:

  The output's id.

- width, height:

  CSS sizes, such as `"100%"` or `"480px"`; a number is pixels.

- expr:

  An expression that returns a view (an `"aob_view"`) or `NULL`.

- env:

  The environment in which to evaluate `expr`.

- quoted:

  Is `expr` a quoted expression (with
  [`quote()`](https://rdrr.io/r/base/substitute.html))?

- session:

  The Shiny session.

- source:

  With several objects in the view, the name of the one to return rows
  of, as for
  [`selected()`](https://allboa.github.io/aobview/reference/selection.md).

## Value

`aobviewOutput()`: a UI element. `renderAobview()`: a render function
for `output$<outputId>`. `aobview_selection()`: a data frame (`source`,
`layer`, `row`) with attributes `at` and `trigger`, or `NULL` until the
output has rendered a view. `aobview_selected()`: rows of the viewed
object, or `NULL`. `aobview_view_state()`: a list, or `NULL`.

## Details

**Transport.** A browser can reach only the Shiny app's server, so a
view in Shiny is embedded: while Shiny runs, `transport = "auto"` never
serves (over `getOption("aobview.embed_max")` the tiles are embedded
with a warning), and rendering a served view is an error.

**Selections.** Every vector layer of a rendered view can be selected,
as in a served view: a click on a feature selects it and only it, Shift
(or Cmd) and click adds or removes it, and a click on nothing or Escape
clears. The page sends each change as the input value
`input$<outputId>_aob_select` and the settled camera as
`input$<outputId>_aob_view` (protocol 1 messages, decision 0007). A
select message is a list with `scene` (the serial of the render it was
made on), `seq`, `trigger` (`"click"`, `"toggle"` or `"clear"`), `at`
(the pressed point in view CRS units) and `items`, one per layer with
its `layer` id and `rows`, which are 0-based row indices into that
layer's data, not rows of your object: read them through the functions
below. `aobview_selection()`, `aobview_selected()` and
`aobview_view_state()` read those inputs, so they are reactive, and
return what
[`selection()`](https://allboa.github.io/aobview/reference/selection.md),
[`selected()`](https://allboa.github.io/aobview/reference/selection.md)
and
[`view_state()`](https://allboa.github.io/aobview/reference/selection.md)
return for a served view: the selected rows of the objects that were
viewed, mapped through the rendered view. A new render (a `NULL` one
too) clears the selection, and the functions re-run when it happens; a
message from an older render is ignored. They return `NULL` until the
output has rendered a view (and after a `NULL` render). They work inside
a module (`outputId` as given to the module's `output`); a module's
output is never confused with an output of the same id elsewhere in the
app.

**Files.**
[`view()`](https://allboa.github.io/aobview/reference/view.md) writes a
page to the temporary directory as usual; for a view rendered here that
page is deleted when the output renders again and when the session ends,
since the scene travels as the render value. A page written to a `file`
you named is left alone.

## Examples

``` r
if (FALSE) { # interactive() && requireNamespace("shiny", quietly = TRUE)
bases <- data.frame(base = c("Casey", "Davis", "Mawson"))
bases$geom <- wk::xy(c(110.53, 77.97, 62.87), c(-66.28, -68.58, -67.60),
                     crs = "OGC:CRS84")
ui <- shiny::fluidPage(aobviewOutput("map"), shiny::tableOutput("picked"))
server <- function(input, output, session) {
  output$map <- renderAobview(view(bases, zcol = "base"))
  output$picked <- shiny::renderTable(aobview_selected("map"))
}
shiny::shinyApp(ui, server)
}
```
