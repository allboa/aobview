## ---- transport: embed or serve (allboa/design decision 0006, item 4) ------
##
## A view is embedded (a self-contained page on disk, v$file) or served
## (aobcore::serve_scene() on 127.0.0.1, v$server). The choice is made per
## local COG layer, after aobcore::cog_plan() and before
## aobcore::scene_add_tiled_raster(), from the plan's tile byte lengths:
## choose_embed() below. While the layers are added the view carries its
## requested `transport`, whether it is to be served (`serve`, with the
## reason and the bytes that decided it), the temporary COGs a server is to
## own (`pending$own`, in an environment so that the caller can delete them
## if anything fails before a server owns them: drop_pending()), and the
## running total of embedded local tile bytes (`local_bytes`). finish_view()
## starts the server or writes the page.

transports <- c("auto", "embed", "serve")

## The transport asked for: one of transports, from the argument or
## getOption("aobview.transport"). "serve" needs httpuv, so say so before
## any work is done.
check_transport <- function(transport) {
  if (!is.character(transport) || length(transport) != 1L || is.na(transport) ||
      !transport %in% transports) {
    stop("`transport` (or getOption(\"aobview.transport\")) must be \"auto\", \"embed\" or ",
         "\"serve\".", call. = FALSE)
  }
  if (transport == "serve" && !has_httpuv()) {
    stop("`transport = \"serve\"` needs the 'httpuv' package; install it with ",
         "install.packages(\"httpuv\"), or use `transport = \"embed\"`.", call. = FALSE)
  }
  transport
}

## The threshold of local tile bytes above which "auto" serves.
embed_max <- function() {
  x <- getOption("aobview.embed_max", 32 * 2^20)
  if (!is.numeric(x) || length(x) != 1L || is.na(x) || x < 0) {
    stop("getOption(\"aobview.embed_max\") must be a single number of bytes, 0 or more.",
         call. = FALSE)
  }
  x
}

## Wrapped so tests can stand in for an interactive session or a missing
## httpuv.
is_interactive <- function() interactive()
has_httpuv <- function() requireNamespace("httpuv", quietly = TRUE)

## Is the view served, or to be served once its layers are added?
is_served <- function(v) !is.null(v$server) || isTRUE(v$serve$on)

## Start adding layers to v with transport `transport` ("auto", "embed" or
## "serve", checked).
begin_transport <- function(v, transport) {
  v$transport <- transport
  v$local_bytes <- v$local_bytes %||% 0
  v$pending <- new.env(parent = emptyenv())
  v$pending$own <- character()
  if (transport == "serve" && !is_served(v)) v$serve <- list(on = TRUE, reason = "asked")
  v
}

## The bytes of a plan's distinct tiles: what embedding would copy into the
## page (aobcore's tile_blobs() reads each distinct range once).
plan_bytes <- function(plan) {
  ranges <- do.call(rbind, lapply(plan$plan$levels, function(l) {
    if (!length(l$tiles)) return(NULL)
    cbind(vapply(l$tiles, function(t) as.numeric(t$byte_offset), 0),
          vapply(l$tiles, function(t) as.numeric(t$byte_length), 0))
  }))
  if (is.null(ranges)) return(0)
  sum(unique(ranges)[, 2])
}

## Embed this local COG layer (TRUE) or register its file for the server
## (FALSE)? Returns list(v, embed). A remote COG is never embedded and never
## counts; a /vsi COG (in memory, or not a plain file) can only be embedded.
## `local_bytes` counts the local tiles embedded in a page, so it grows only
## while the view is not served, as for "embed".
choose_embed <- function(v, cog, plan, name) {
  if (!isTRUE(cog$local)) return(list(v = v, embed = NULL))
  servable <- !startsWith(cog$dsn, "/vsi")
  transport <- v$transport %||% "auto"
  bytes <- plan_bytes(plan)
  if (!servable) {
    if (is_served(v)) {
      warning("\"", name, "\" is a COG GDAL reads from \"", cog$dsn, "\", which a server ",
              "cannot deliver, so its ", format_bytes(bytes), " of tiles are embedded.",
              call. = FALSE)
      return(list(v = v, embed = TRUE))
    }
    total <- v$local_bytes + bytes
    max <- embed_max()
    if (transport == "auto" && total > max) {
      warning("The view's local raster tiles come to ", format_bytes(total), ", over ",
              "getOption(\"aobview.embed_max\") (", format_bytes(max), "), but they are ",
              "embedded in the page, because \"", name, "\" is a COG GDAL reads from \"",
              cog$dsn, "\", which a server cannot deliver. The page may be slow to open.",
              call. = FALSE)
    }
    v$local_bytes <- total
    return(list(v = v, embed = TRUE))
  }
  if (transport == "embed") {
    if (!is_served(v)) v$local_bytes <- v$local_bytes + bytes
    return(list(v = v, embed = TRUE))
  }
  if (is_served(v)) return(list(v = v, embed = FALSE))
  ## "auto" on a view that is still embedded.
  total <- v$local_bytes + bytes
  max <- embed_max()
  if (total <= max) {
    v$local_bytes <- total
    return(list(v = v, embed = TRUE))
  }
  if (is_interactive() && has_httpuv()) {
    v$serve <- list(on = TRUE, reason = "auto", bytes = total, max = max)
    return(list(v = v, embed = FALSE))
  }
  warning("The view's local raster tiles come to ", format_bytes(total), ", over ",
          "getOption(\"aobview.embed_max\") (", format_bytes(max), "), but they are embedded ",
          "in the page, because ",
          if (!has_httpuv()) {
            "serving them needs the 'httpuv' package (install.packages(\"httpuv\"))"
          } else {
            "the session is not interactive, and a server would stop when it ends"
          },
          ". The page may be slow to open.", call. = FALSE)
  v$local_bytes <- total
  list(v = v, embed = TRUE)
}

format_bytes <- function(n) {
  if (n >= 2^20) return(paste0(format(round(n / 2^20, 1), nsmall = 1), " MiB"))
  if (n >= 2^10) return(paste0(format(round(n / 2^10, 1), nsmall = 1), " KiB"))
  paste0(format(n, scientific = FALSE), " bytes")
}

## The directory a served layer's temporary COG is written to; R removes it
## with its temporary directory at exit.
temp_cog_dir <- function() {
  d <- file.path(tempdir(), "aobview-cogs")
  dir.create(d, showWarnings = FALSE, recursive = TRUE)
  d
}

## Is `path` one of the temporary COGs aobview writes for a served layer?
is_temp_cog <- function(path) {
  dir <- function(p) normalizePath(p, winslash = "/", mustWork = FALSE)
  identical(dir(dirname(path)), dir(file.path(tempdir(), "aobview-cogs")))
}

## A view whose server was stopped can be served again on a new one only
## while its registered files (`files`, as a scene carries them) exist;
## else an error naming the first that is gone. Called before view_add()
## writes anything, and again by serve_view().
check_stopped_files <- function(srv, files) {
  if (is.null(srv) || isTRUE(srv$state$running)) return(invisible())
  gone <- Filter(function(f) !file.exists(f$path), files)
  if (!length(gone)) return(invisible())
  path <- gone[[1]]$path
  stop("The view's server at ", srv$url, " was stopped, and the file of layer `",
       names(gone)[1], "` is gone",
       if (is_temp_cog(path)) {
         " (a temporary COG is deleted when its server stops)"
       } else {
         paste0(" (\"", path, "\" no longer exists)")
       },
       ". Make the view again with view().", call. = FALSE)
}

## Delete the temporary COGs written for a view being built that no server
## owns yet: on.exit() in each function that builds one, so a failure
## anywhere before serve_scene() takes them leaves none behind.
drop_pending <- function(v) {
  p <- v$pending
  if (is.environment(p) && length(p$own)) {
    unlink(p$own)
    p$own <- character()
  }
  invisible()
}

## Serve scene s for view v (finish_view()): on v's running server when it
## has one, else on a new server. Returns the handle. The server then owns
## the view's pending temporary COGs.
serve_view <- function(v, s, name, theme) {
  srv <- v$server
  if (!is.null(srv) && !isTRUE(srv$state$running)) {
    check_stopped_files(srv, attr(s, "files"))
    message("The view's server at ", srv$url, " was stopped; serving the view on a new one.")
    srv <- NULL
  }
  new <- is.null(srv)
  srv <- aobcore::serve_scene(s, title = name, theme = theme, server = srv,
                              own = v$pending$own, open = FALSE)
  v$pending$own <- character()
  if (new && identical(v$serve$reason, "auto")) {
    message("The view's local raster tiles come to ", format_bytes(v$serve$bytes),
            ", over getOption(\"aobview.embed_max\") (", format_bytes(v$serve$max),
            "), so the view is served from a local server instead of embedded in a page: ",
            srv$url, "\nThe server is left running until `v$server$stop()`, ",
            "aobcore::stop_scene_servers() or the end of the R session.")
  }
  srv
}

open_url <- function(url) {
  viewer <- getOption("viewer")
  ## IDE viewers take http://127.0.0.1 URLs (decision 0006).
  if (is.function(viewer)) viewer(url) else utils::browseURL(url)
  invisible(url)
}
