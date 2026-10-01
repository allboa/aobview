## ---- vector input: wk first ------------------------------------------------

## Every vector input becomes one record before anything else is done with
## it (allboa/design decision 0008):
##
##   geom   the geometry as wk::wkb(), with its CRS (wk::wk_crs())
##   attrs  a plain data frame of the other columns, one row per geometry,
##          or NULL for a bare geometry vector
##   geometry  the name of a data frame's geometry column (for messages)
##
## The inputs: a bare wk-handleable vector (sfc, wkb, wkt, xy, crc, rct,
## geos_geometry, a geoarrow vector, ...); a data frame with a handleable
## column (an sf data frame is one); and a terra SpatVector, whose geometry
## comes from terra's own WKB. Everything after this is wk, with PROJ for
## the transform: sf is an input type, not a dependency.
vector_record <- function(x, geometry = NULL) {
  if (inherits(x, "SpatVector")) {
    need_terra()
    check_terra_crs(x)
    geom <- wk::wkb(terra::geom(x, wkb = TRUE), crs = terra::crs(x))
    attrs <- as.data.frame(x)
    rownames(attrs) <- NULL
    return(list(geom = geom, attrs = attrs))
  }
  if (is.data.frame(x)) {
    col <- geometry %||% geometry_column(x)
    if (!is.character(col) || length(col) != 1L || !col %in% names(x)) {
      stop("`geometry` must name a column of `x`.", call. = FALSE)
    }
    geom <- x[[col]]
    if (!wk::is_handleable(geom)) {
      stop("Column \"", col, "\" of `x` is not geometry that wk can read (class ",
           paste(class(geom), collapse = "/"), ").", call. = FALSE)
    }
    keep <- setdiff(names(x), col)
    attrs <- structure(unclass(x)[keep], names = keep, class = "data.frame",
                       row.names = c(NA_integer_, -nrow(x)))
    return(list(geom = as_geom(geom), attrs = attrs, geometry = col))
  }
  if (!is.null(geometry)) {
    stop("`geometry` names a column of a data frame; `x` is not one.", call. = FALSE)
  }
  if (wk::is_handleable(x)) return(list(geom = as_geom(x), attrs = NULL))
  stop(no_method_message(x), call. = FALSE)
}

## Geometry as wkb with its CRS. A wk grd is a grid, not features: it is
## left for the raster path rather than drawn as a polygon per cell.
as_geom <- function(x) {
  if (inherits(x, "wk_grd")) {
    stop("view() does not draw a wk grd yet: a grid belongs on the raster path. ",
         "For its cells as polygons, view wk::as_wkb() of it.", call. = FALSE)
  }
  g <- wk::as_wkb(x)
  wk::wk_set_crs(g, wk::wk_crs(x))
}

## The geometry column of a data frame: sf's, else the first column wk can
## read.
geometry_column <- function(x) {
  sf_col <- attr(x, "sf_column")
  if (is.character(sf_col) && length(sf_col) == 1L && sf_col %in% names(x)) return(sf_col)
  for (nm in names(x)) {
    if (wk::is_handleable(x[[nm]])) return(nm)
  }
  stop("`x` is a data frame with no geometry column that wk can read.", call. = FALSE)
}

## ---- CRS, through PROJ -----------------------------------------------------

## The PROJ definition of a geometry's CRS ("EPSG:4326", WKT, a PROJ
## string, ...), or an error when it has none.
source_crs <- function(g, view = NULL) {
  crs <- wk::wk_crs(g)
  def <- if (!is.null(crs) && !inherits(crs, "wk_crs_inherit")) {
    tryCatch(wk::wk_crs_proj_definition(crs), error = function(e) NULL)
  }
  if (is.null(def) || is.na(def) || !nzchar(def)) {
    stop("`x` has no CRS. Set one (wk::wk_set_crs(), sf::st_set_crs() or ",
         "terra::crs<-) before viewing it",
         if (is.null(view)) ", or pass `crs` to view()" else paste0(" in ", crs_text(view)),
         ".", call. = FALSE)
  }
  def
}

## PROJ's WKT2 for a definition, or an error. PROJ 0.7.0's proj_crs_text()
## crashes R on a definition PROJ cannot read, so the definition is first
## checked by creating a transform from it, which fails as an R error.
proj_wkt <- function(def) {
  def <- as.character(def)
  ok <- length(def) == 1L && !is.na(def) && nzchar(def) &&
    !inherits(try(PROJ::proj_trans_create(def, "OGC:CRS84"), silent = TRUE), "try-error")
  if (!ok) stop("PROJ cannot read the CRS \"", crs_short(def), "\".", call. = FALSE)
  wkt <- PROJ::proj_crs_text(def, 0L)
  if (is.na(wkt) || !nzchar(wkt)) {
    stop("PROJ cannot read the CRS \"", crs_short(def), "\".", call. = FALSE)
  }
  wkt
}

## Is the CRS geographic (lon/lat)? Read from the root of PROJ's WKT2: a
## GEOGCRS (a BOUNDCRS is read through to its source CRS).
crs_is_lonlat <- function(def) {
  wkt <- proj_wkt(def)
  wkt <- sub("^\\s*BOUNDCRS\\s*\\[\\s*SOURCECRS\\s*\\[", "", wkt)
  grepl("^\\s*GEOGCRS\\s*\\[", wkt)
}

## A definition as "authority:code" when it is one, or when PROJ's WKT2
## carries a root ID; otherwise NULL.
crs_code <- function(def) {
  def <- as.character(def)
  if (grepl(code_pattern, def)) return(def)
  wkt <- tryCatch(proj_wkt(def), error = function(e) NULL)
  if (is.null(wkt)) return(NULL)
  m <- regmatches(wkt, regexec("ID\\[\"([^\"]+)\",[[:space:]]*\"?([^]\",]+)\"?\\][[:space:]]*\\][[:space:]]*$", wkt))[[1]]
  if (length(m) == 3L) paste0(m[2], ":", m[3]) else NULL
}

code_pattern <- "^[A-Za-z][A-Za-z0-9_]*:[A-Za-z0-9_.-]+$"

## The same CRS? The same code, else the same WKT from PROJ.
same_crs <- function(a, b) {
  ca <- crs_code(a)
  cb <- crs_code(b)
  if (!is.null(ca) && !is.null(cb)) return(identical(toupper(ca), toupper(cb)))
  identical(tryCatch(proj_wkt(a), error = function(e) "a"),
            tryCatch(proj_wkt(b), error = function(e) "b"))
}

crs_short <- function(x) {
  x <- as.character(x)
  if (nchar(x) > 60) paste0(substr(x, 1, 57), "...") else x
}

## Transform wkb g from CRS `from` to the view CRS with PROJ.
proj_transform <- function(g, from, view) {
  trans <- PROJ::proj_trans_create(as.character(from), as.character(view))
  wk::wk_transform(g, trans)
}
