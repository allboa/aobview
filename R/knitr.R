#' Views in knitted documents
#'
#' A view printed in a chunk of an R Markdown or Quarto document (or any
#' document knitr renders to HTML) is drawn in the document itself: its
#' scene and data are embedded, as in the page [view()] writes, and the
#' renderer is carried once however many views the document shows
#' (allboa/design decision 0009). The document needs no server and no
#' network. knitr calls this method; there is nothing to call yourself.
#'
#' **Size.** The view is as wide as the chunk's `out.width` when that is a
#' string such as `"80%"` or `"600px"`, else `"100%"` (a number there is
#' knitr's own, from `fig.width` when `fig.retina` is set, as in R Markdown,
#' and is not used), and as tall as its `out.height`, or else `fig.height` inches
#' at 96 pixels per inch (480 pixels for R Markdown's default of 5, 672 for
#' plain knitr's 7).
#'
#' **Theme.** The view's `theme`: `view(x, theme = "light")` keeps a view
#' light in a light document whatever the reader's browser prefers;
#' `"auto"` (the default) follows the browser.
#'
#' **Transport.** A document has no R session behind it, so a view in it is
#' always embedded. While knitr runs, `transport = "auto"` never serves: a
#' view whose local raster tiles come to more than
#' `getOption("aobview.embed_max")` is embedded with a warning, which shows
#' in the document. A served view (`transport = "serve"`, or one served
#' before knitting) cannot be shown in a document, and printing it is an
#' error. No selection is sent from a document.
#'
#' **Other formats.** For a PDF or Word document knitr's own rule for HTML
#' output applies.
#'
#' @param x A view from [view()] or [view_add()].
#' @param options The chunk options, from knitr.
#' @param ... Passed on to knitr.
#' @return A `knit_asis` object, for knitr.
#' @name knit_print.aob_view
#' @keywords internal
#' @exportS3Method knitr::knit_print
knit_print.aob_view <- function(x, options = list(), ...) {
  if (!is.null(x$server)) {
    stop("A served view cannot be shown in a knitted document, which has no R session ",
         "behind it. Make the view with `transport = \"embed\"`.", call. = FALSE)
  }
  width <- options$out.width
  if (!is.character(width)) width <- "100%"
  tag <- aobcore::scene_tag(x$scene, width = width,
                            height = options$out.height %||% knit_height(options$fig.height),
                            theme = x$theme %||% "auto")
  knitr::knit_print(tag, options = options, ...)
}

## fig.height inches as CSS pixels, at 96 per inch.
knit_height <- function(inches) {
  inches <- inches %||% 5
  if (!is.numeric(inches) || length(inches) != 1L || is.na(inches) || inches <= 0) inches <- 5
  paste0(round(inches * 96), "px")
}
