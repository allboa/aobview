#' Colours for attribute values
#'
#' Maps values to RGBA colours, as [view()] does for `zcol`: a continuous
#' palette for numbers, one colour per level for factors, character and
#' logical values. Colours are computed in R and travel to the page as a
#' per-feature RGBA column (styling is data, scene spec 0.1), so this is
#' all the colouring there is; legends can be drawn from the same result.
#'
#' **Numbers** (integer or double) are coloured along the palette from the
#' lowest finite value to the highest, or, with `breaks`, one colour per
#' interval (closed on the right, the lowest closed on both sides; values
#' outside the breaks get `na_colour`). A column of one value takes the
#' palette's middle colour.
#'
#' **Levels.** A factor's levels in their order (unused levels keep their
#' colour, so a subset colours alike), the sorted unique values of a
#' character vector, and `FALSE`, `TRUE` for a logical. When a palette has
#' fewer colours than there are levels, its colours are recycled, with a
#' message.
#'
#' `NA` (and `NaN`, `Inf`, `-Inf` for numbers) gets `na_colour`.
#'
#' @param values A numeric, factor, character or logical vector.
#' @param palette A palette name or a function. A name is one of
#'   [grDevices::palette.pals()] (fixed sets such as `"Tableau 10"` or
#'   `"Okabe-Ito"`, stretched by interpolation for numbers) or of
#'   [grDevices::hcl.pals()] (such as `"viridis"` or `"Dark 3"`), matched
#'   ignoring case, spaces and hyphens. A function takes a number `n` and
#'   returns `n` colours [grDevices::col2rgb()] reads, such as
#'   [grDevices::hcl.colors()] or `function(n) hcl.colors(n, "Blues 3",
#'   alpha = 0.7)`. `NULL` (the default) is `"viridis"` for numbers and
#'   `"Tableau 10"` for levels.
#' @param breaks For numbers only: increasing break points (at least two)
#'   that bin the values into classes, one colour each. `NULL` colours
#'   continuously.
#' @param na_colour The colour for `NA`: anything [grDevices::col2rgb()]
#'   reads, or `c(r, g, b, a)` integers 0 to 255.
#' @return An integer matrix with one row per value and columns `r`, `g`,
#'   `b`, `a` (0 to 255). Its `"key"` attribute describes the mapping for a
#'   legend: a list with `type` (`"continuous"`, `"binned"` or
#'   `"categorical"`), `colours` (hex strings: 33 evenly spaced along the
#'   palette for continuous, else one per class or level), `na_colour`, and
#'   `range`
#'   (continuous), `breaks` (binned) or `levels` (categorical).
#' @seealso [view()], whose `zcol` argument uses this.
#' @export
#' @examples
#' view_colours(c(1, 5, NA, 10))
#' view_colours(c("b", "a", "b"), palette = "Okabe-Ito")
#' view_colours(c(0.1, 2.5, 7), palette = grDevices::terrain.colors, breaks = c(0, 1, 5, 10))
#' attr(view_colours(c(TRUE, FALSE, NA)), "key")$levels
view_colours <- function(values, palette = NULL, breaks = NULL, na_colour = "#999999") {
  na <- as_rgba(na_colour, "na_colour")
  n <- length(values)
  out <- matrix(rep(na, each = n), nrow = n, ncol = 4L,
                dimnames = list(NULL, c("r", "g", "b", "a")))
  if (is.numeric(values) && !is.factor(values)) {
    key <- colour_numbers(values, palette, breaks, out)
  } else if (is.factor(values) || is.character(values) || is.logical(values)) {
    if (!is.null(breaks)) {
      stop("`breaks` applies only to numeric values.", call. = FALSE)
    }
    key <- colour_levels(values, palette, out)
  } else {
    stop("Cannot colour values of class ", paste(class(values), collapse = "/"),
         "; `values` must be numeric, factor, character or logical.", call. = FALSE)
  }
  out <- key$rgba
  storage.mode(out) <- "integer"
  key$rgba <- NULL
  key$na_colour <- rgba_hex(matrix(na, nrow = 1L))
  attr(out, "key") <- key
  out
}

## ---- internals -------------------------------------------------------------

colour_numbers <- function(values, palette, breaks, out) {
  values <- as.numeric(values)
  ok <- is.finite(values)
  if (!is.null(breaks)) {
    if (!is.numeric(breaks) || length(breaks) < 2L || anyNA(breaks) ||
        any(!is.finite(breaks)) || is.unsorted(breaks, strictly = TRUE)) {
      stop("`breaks` must be at least two increasing, finite numbers.", call. = FALSE)
    }
    k <- length(breaks) - 1L
    cols <- palette_rgba(palette %||% "viridis", k, recycle = FALSE)
    bin <- rep(NA_integer_, length(values))
    inside <- ok & values >= breaks[1] & values <= breaks[k + 1L]
    bin[inside] <- findInterval(values[inside], breaks, left.open = TRUE,
                                rightmost.closed = TRUE, all.inside = TRUE)
    hit <- !is.na(bin)
    out[hit, ] <- cols[bin[hit], , drop = FALSE]
    return(list(type = "binned", rgba = out, breaks = as.numeric(breaks),
                colours = rgba_hex(cols)))
  }
  cols <- palette_rgba(palette %||% "viridis", 256L, recycle = FALSE)
  range <- if (any(ok)) range(values[ok]) else c(NA_real_, NA_real_)
  if (any(ok)) {
    t <- if (range[1] == range[2]) rep(0.5, sum(ok)) else (values[ok] - range[1]) / diff(range)
    ramp <- grDevices::colorRamp(rgba_hex(cols), alpha = TRUE)
    out[ok, ] <- round(ramp(t))
  }
  list(type = "continuous", rgba = out, range = range,
       colours = rgba_hex(cols[round(seq(1, 256, length.out = legend_stops)), , drop = FALSE]))
}

## Colours kept in a continuous key, evenly spaced along the 256 the
## features are coloured from: a legend ramp interpolates linearly between
## them, so 33 keeps it close to the features' colours (within about 20 of
## 255 per channel for the hcl.pals() palettes, whose channels bend where
## they clip at the edge of the gamut; 51 for viridis with 9 stops).
legend_stops <- 33L

colour_levels <- function(values, palette, out) {
  levels <- if (is.factor(values)) {
    levels(values)
  } else if (is.logical(values)) {
    c("FALSE", "TRUE")
  } else {
    sort(unique(values[!is.na(values)]), method = "radix")
  }
  k <- length(levels)
  cols <- if (k) palette_rgba(palette %||% "Tableau 10", k, recycle = TRUE) else out[0, , drop = FALSE]
  idx <- match(as.character(values), levels)
  hit <- !is.na(idx)
  out[hit, ] <- cols[idx[hit], , drop = FALSE]
  list(type = "categorical", rgba = out, levels = levels, colours = rgba_hex(cols))
}

## n colours from a palette name or function, as an n x 4 integer matrix.
## recycle = TRUE (levels) repeats a short palette with a message;
## recycle = FALSE (numbers) interpolates one.
palette_rgba <- function(palette, n, recycle) {
  if (is.function(palette)) {
    cols <- palette(n)
    what <- "The palette function"
  } else if (is.character(palette) && length(palette) == 1L && !is.na(palette)) {
    cols <- named_palette(palette, n)
    what <- paste0("Palette \"", palette, "\"")
  } else {
    stop("`palette` must be a palette name or a function of n that returns n colours.",
         call. = FALSE)
  }
  rgba <- tryCatch(t(grDevices::col2rgb(cols, alpha = TRUE)), error = function(e) {
    stop(what, " did not return colours: ", conditionMessage(e), call. = FALSE)
  })
  if (!nrow(rgba)) stop(what, " returned no colours.", call. = FALSE)
  if (nrow(rgba) < n) {
    if (recycle) {
      message(what, " has ", nrow(rgba), " colours for ", n, " levels; its colours are recycled.")
      rgba <- rgba[rep_len(seq_len(nrow(rgba)), n), , drop = FALSE]
    } else {
      ramp <- grDevices::colorRamp(rgba_hex(rgba), alpha = TRUE)
      rgba <- round(ramp(if (n == 1L) 0.5 else seq(0, 1, length.out = n)))
    }
  }
  ## More colours than asked for: the first n levels, or n spread evenly
  ## along a continuous palette.
  keep <- if (recycle || n == 1L) seq_len(n) else round(seq(1, nrow(rgba), length.out = n))
  rgba <- rgba[keep, , drop = FALSE]
  storage.mode(rgba) <- "integer"
  dimnames(rgba) <- list(NULL, c("r", "g", "b", "a"))
  rgba
}

## A named palette's colours: all of a fixed set from palette.pals(), or n
## from hcl.pals().
named_palette <- function(palette, n) {
  key <- function(x) tolower(gsub("[-_ .]", "", x))
  fixed <- grDevices::palette.pals()
  i <- match(key(palette), key(fixed))
  if (!is.na(i)) return(unname(grDevices::palette.colors(NULL, fixed[i])))
  hcl <- grDevices::hcl.pals()
  i <- match(key(palette), key(hcl))
  if (!is.na(i)) return(grDevices::hcl.colors(n, hcl[i]))
  stop("Unknown palette \"", palette, "\": use a name from grDevices::palette.pals() or ",
       "grDevices::hcl.pals(), or a function of n.", call. = FALSE)
}

## One colour as c(r, g, b, a) integers.
as_rgba <- function(x, arg) {
  if (is.numeric(x) && length(x) == 4L && !anyNA(x) && all(x >= 0 & x <= 255)) {
    return(as.integer(round(x)))
  }
  if (length(x) == 1L && !is.na(x) && (is.character(x) || is.numeric(x))) {
    rgba <- tryCatch(grDevices::col2rgb(x, alpha = TRUE), error = function(e) NULL)
    if (!is.null(rgba)) return(as.integer(rgba))
  }
  stop("`", arg, "` must be one colour: a name or hex string, or c(r, g, b, a) ",
       "integers 0 to 255.", call. = FALSE)
}

rgba_hex <- function(m) {
  grDevices::rgb(m[, 1], m[, 2], m[, 3], m[, 4], maxColorValue = 255)
}
