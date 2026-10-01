# Selections from a served view

A served view (`transport = "serve"`, see Transport in
[`view()`](https://allboa.github.io/aobview/reference/view.md)) lets the
viewer select features in the page, and sends the selection and the
settled view back to R over a websocket (allboa/design decision 0007). A
click on a feature selects it and only it; a click with Shift (or Cmd)
adds or removes it; a click on nothing, or Escape, clears. Every vector
layer of a served view can be selected, popup or not; rasters cannot.
These functions read what the page sent. They need the 'httpuv' and
'jsonlite' packages.

## Usage

``` r
selection(v)

selected(v, source = NULL)

wait_for_selection(v, timeout = Inf, source = NULL)

view_state(v)
```

## Arguments

- v:

  A view from
  [`view()`](https://allboa.github.io/aobview/reference/view.md) or
  [`view_add()`](https://allboa.github.io/aobview/reference/view-layers.md).

- source:

  With several objects in the view, the name of the one to return rows
  of (a `source` value of `selection(v)`). `NULL` picks the only one
  with selected rows.

- timeout:

  Seconds to wait; `Inf` (the default) waits until a selection arrives.

## Value

`selection()`: a data frame. `selected()` and `wait_for_selection()`:
rows of the viewed object, or `NULL`. `view_state()`: a list, or `NULL`.

## Details

`selection(v)` gives the selected rows as indices into the objects that
were viewed: a data frame with columns `source` (the name an object was
viewed under, as the layer label; a name used twice in one view gets
`_2`, `_3`, ...), `layer` (the layer id) and `row` (1-based, into that
object), with one row per selected row of each layer, ordered by source,
layer and row. A feature drawn in pieces (the parts of a geometry
collection) is one row. Attributes `at` (the pressed point, in view CRS
units, or `NULL`), `trigger` (`"click"`, `"toggle"` or `"clear"`),
`connection` (which page), `seq` and `time` say where it came from. It
has zero rows when nothing is selected.

`selected(v)` gives the selected rows themselves: `x[rows, ]` of the
data frame (`sf` included) or `SpatVector` that was viewed, or `x[rows]`
of a bare geometry vector, with every column of `x`, not only those of
the popup. `source` names the object when the view has several: it
defaults to the only one with selected rows, and is an error naming them
when several have selected rows. With nothing selected it gives zero
rows of the view's only object, or `NULL` when the view has several.

`wait_for_selection(v)` waits until the page sends its next selection (a
click, a toggle or a clear), then returns `selected(v)`. It services R's
event loop itself, so call it at the prompt or in a script and click in
the page; an interrupt (Esc, Ctrl-C) ends it. After `timeout` seconds it
returns `NULL` with a message. With no page connected it says it is
waiting for one; in a non-interactive session with no page connected it
is an error unless `timeout` is finite, so a script cannot hang on a
page nobody will open.

`view_state(v)` gives the page's last settled view (sent 250 ms after
the camera stops): a list with `extent` (`c(xmin, xmax, ymin, ymax)` in
view CRS units), `zoom`, `units_per_pixel` and `size_px` (or `center`
and `zoom` for a globe), with `connection`, `seq`, `time` and `scene`;
`NULL` before the page has sent one.

**When the selection is current.** R reads the page's messages only when
it is idle at the prompt or servicing its event loop. Each of these
functions first takes in every message that has arrived, so a selection
made just before the call is counted; inside a long computation the page
waits. With several tabs on one view, the last message wins.

**Errors.** An embedded view (a page on disk) cannot send anything back
to R, so these functions are errors on one: view the data with
`transport = "serve"`. They are errors too once the view's server has
stopped (`v$server$stop()`,
[`aobcore::stop_scene_servers()`](https://rdrr.io/pkg/aobcore/man/scene_servers.html)),
since the selection lived in the server, and on a view that
[`view_add()`](https://allboa.github.io/aobview/reference/view-layers.md)
has replaced:
[`view_add()`](https://allboa.github.io/aobview/reference/view-layers.md)
serves its new scene on the same server, which clears the selection and
reloads the open page, and only the view it returned knows the new
scene's rows.

**Memory.** A view keeps each vector object it was given (without a
copy: R copies on change), so `selected()` can return its rows; the
object stays in memory as long as the view does.

## See also

[aobcore::serve_scene_socket](https://rdrr.io/pkg/aobcore/man/serve_scene_socket.html)
for the server's side and its messages.

## Examples

``` r
if (FALSE) { # interactive() && requireNamespace("sf", quietly = TRUE) && requireNamespace("httpuv", quietly = TRUE) && nzchar(system.file(package = "jsonlite"))
nc <- sf::st_read(system.file("shape", "nc.shp", package = "sf"), quiet = TRUE)
v <- view(nc, transport = "serve")
v
## Click a county in the page, then:
wait_for_selection(v, timeout = 60)
selection(v)
selected(v)
view_state(v)
v$server$stop()
}
```
