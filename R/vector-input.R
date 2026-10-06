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
## column (an sf data frame is one); a terra SpatVector, whose geometry
## comes from terra's own WKB; an OGRFeatureSet from gdalraster's
## GDALVector$fetch(), whose WKB column is wrapped with its layer's SRS; and
## an Arrow stream (or anything with an as_nanoarrow_array_stream() method),
## read once into a data frame by stream_frame(). Everything after this is
## wk, with PROJ for the transform: sf is an input type, not a dependency.
vector_record <- function(x, geometry = NULL) {
  if (inherits(x, "SpatVector")) {
    need_terra()
    check_terra_crs(x)
    geom <- wk::wkb(terra::geom(x, wkb = TRUE), crs = terra::crs(x))
    attrs <- as.data.frame(x)
    rownames(attrs) <- NULL
    return(list(geom = geom, attrs = attrs))
  }
  if (inherits(x, "OGRFeatureSet")) {
    ogr <- ogr_feature_frame(x, geometry)
    x <- ogr$x
    geometry <- ogr$geometry
  }
  if (is_stream_input(x)) {
    rows <- stream_frame(x, geometry)
    x <- rows$x
    geometry <- rows$geometry
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

## ---- Arrow streams ---------------------------------------------------------

## Is x an Arrow stream, or something with an as_nanoarrow_array_stream()
## method (an arrow Table, RecordBatchReader or Dataset, a nanoarrow array
## or vctr, ...) that is not already a vector input in its own right (a
## geoarrow vector is handleable; a data frame has a method too)?
is_stream_input <- function(x) {
  if (inherits(x, "nanoarrow_array_stream")) return(TRUE)
  if (is.data.frame(x) || wk::is_handleable(x) || inherits(x, c("SpatRaster", "SpatVector"))) {
    return(FALSE)
  }
  for (cl in class(x)) {
    m <- utils::getS3method("as_nanoarrow_array_stream", cl, optional = TRUE,
                            envir = asNamespace("nanoarrow"))
    if (!is.null(m)) return(TRUE)
  }
  FALSE
}

## A stream read into R as one data frame (allboa/design decision 0011):
## nanoarrow reads its batches, however many, into one frame. The geometry
## column is the first with a GeoArrow extension type (a geoarrow vector
## once read), else GDAL's "ogc.wkb" column, else the column `geometry`
## names (WKB bytes or WKT text); it becomes wkb with the CRS from its
## GeoArrow metadata, or `crs` when it has none (an error with neither).
## Returns the frame, which the view keeps as the stream's rows, and the
## geometry column's name.
stream_frame <- function(x, geometry = NULL, crs = NULL) {
  stream <- nanoarrow::as_nanoarrow_array_stream(x)
  schema <- stream$get_schema()
  if (!identical(schema$format, "+s")) {
    stream$release()
    stop("`x` is a stream of ", schema$format, " values, not of rows with named columns.",
         call. = FALSE)
  }
  cols <- names(schema$children)
  ext <- vapply(schema$children, function(ch) {
    ch$metadata[["ARROW:extension:name"]] %||% ""
  }, "")
  col <- tryCatch(stream_geometry_column(cols, ext, geometry), error = function(e) {
    stream$release()
    stop(e)
  })
  ## A column of an extension type nanoarrow does not know (GDAL's
  ## "ogc.wkb") is read as its storage type, the WKB bytes, without the
  ## warning nanoarrow gives for that.
  old <- options(nanoarrow.warn_unregistered_extension = FALSE)
  on.exit(options(old), add = TRUE)
  df <- nanoarrow::convert_array_stream(stream)
  if (!nrow(df)) {
    stop("`x` has no rows: the query gave none, or the stream was already read. ",
         "A stream is read once, so one already read (by view(), as.data.frame() ",
         "or a collect, say) has nothing left.", call. = FALSE)
  }
  class(df) <- "data.frame"
  rownames(df) <- NULL
  df[[col]] <- stream_geometry(df[[col]], col, crs)
  list(x = df, geometry = col)
}

stream_geometry_column <- function(cols, ext, geometry) {
  shown <- paste0("\"", cols, "\"", collapse = ", ")
  if (!is.null(geometry)) {
    if (!is.character(geometry) || length(geometry) != 1L || !geometry %in% cols) {
      stop("`geometry` must name a column of `x`; it has ", shown, ".", call. = FALSE)
    }
    return(geometry)
  }
  geo <- which(startsWith(ext, "geoarrow."))
  if (!length(geo)) geo <- which(ext == "ogc.wkb")
  if (length(geo)) return(cols[geo[1L]])
  stop("`x` has no column with a GeoArrow extension type. Name its geometry column ",
       "(WKB bytes or WKT text) with `geometry =`; the columns are ", shown, ".",
       call. = FALSE)
}

## A stream's geometry column, read, as wkb with a CRS: a geoarrow vector
## as it is, WKB bytes (a list of raw) through wk::wkb(), WKT text through
## wk::wkt(). With no CRS in the GeoArrow metadata the geometry is taken to
## be in `crs`.
stream_geometry <- function(g, col, crs) {
  if (wk::is_handleable(g)) {
    g <- as_geom(g)
  } else if (is.list(g) && all(vapply(g, function(el) is.null(el) || is.raw(el), TRUE))) {
    g <- unclass(g)
    attributes(g) <- NULL
    g <- wk::wkb(g)
  } else if (is.character(g)) {
    g <- tryCatch(wk::as_wkb(wk::wkt(g)), error = function(e) {
      stop("Column \"", col, "\" of `x` is not WKT text: ", conditionMessage(e),
           call. = FALSE)
    })
  } else {
    stop("Column \"", col, "\" of `x` is not geometry: it is read as ",
         paste(class(g), collapse = "/"), ", not WKB bytes, WKT text or a GeoArrow type.",
         call. = FALSE)
  }
  src <- wk::wk_crs(g)
  if (is.null(src) || inherits(src, "wk_crs_inherit")) {
    if (is.null(crs)) {
      stop("The geometry column \"", col, "\" of `x` has no CRS in its GeoArrow metadata. ",
           "Pass `crs` to view() to say which CRS it is in; the view is drawn in that CRS.",
           call. = FALSE)
    }
    g <- wk::wk_set_crs(g, as.character(aobcore::scene_crs(crs)))
  }
  g
}

## A list's elements that are streams (see is_stream_input()), each read
## once into its data frame, so that the view CRS rule and the layers both
## see its rows. A stream with no CRS is taken to be in `crs`.
materialise_streams <- function(x, labels, crs = NULL) {
  for (i in seq_along(x)) {
    if (is_stream_input(x[[i]])) {
      x[[i]] <- in_element(i, labels[i], stream_frame(x[[i]], crs = crs))$x
    }
  }
  x
}

## ---- gdalraster's GDALVector$fetch() ---------------------------------------

## An OGRFeatureSet (gdalraster 2.x) is a data frame whose geometry column
## holds what the layer's returnGeomAs field asked for, with the column's
## name, type, SRS and format in its "gis" attribute. The WKB (a list of
## raw) or WKT column becomes wkb with the layer's SRS; the rest are the
## attributes. Returns the frame and the geometry column's name.
ogr_feature_frame <- function(x, geometry = NULL) {
  gis <- attr(x, "gis")
  cols <- as.character(gis$geom_column)
  cols <- cols[cols %in% names(x)]
  if (!length(cols)) {
    stop("`x` was fetched without geometry (returnGeomAs = \"NONE\"); set ",
         "returnGeomAs to \"WKB\" on the layer and fetch again.", call. = FALSE)
  }
  col <- geometry %||% cols[1L]
  i <- match(col, cols)
  if (is.na(i)) {
    stop("`geometry` must name a geometry column of `x`; it has ",
         paste0("\"", cols, "\"", collapse = ", "), ".", call. = FALSE)
  }
  fmt <- toupper(as.character(gis$geom_format %||% "WKB"))
  g <- x[[col]]
  if (fmt %in% c("WKB", "WKB_ISO")) {
    g <- unclass(g)
    attributes(g) <- NULL
    g <- wk::wkb(g)
  } else if (fmt %in% c("WKT", "WKT_ISO")) {
    g <- wk::as_wkb(wk::wkt(as.character(g)))
  } else {
    stop("`x` was fetched with returnGeomAs = \"", fmt, "\", which is not geometry; set ",
         "returnGeomAs to \"WKB\" on the layer and fetch again.", call. = FALSE)
  }
  srs <- as.character(gis$geom_col_srs)[i]
  if (length(srs) == 1L && !is.na(srs) && nzchar(srs)) g <- wk::wk_set_crs(g, srs)
  x[[col]] <- g
  list(x = x, geometry = col)
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

## Can PROJ find its database (proj.db)? CRAN's macOS binary of the PROJ
## package does not set one up, so when PROJ cannot read OGC:CRS84 the
## proj folder that ships with PROJ, sf, terra or gdalraster is tried, by
## setting PROJ_DATA (and PROJ_LIB, for PROJ before 9.1) for the session.
## The first that works is kept; success is remembered.
proj_state <- new.env(parent = emptyenv())

proj_ready <- function() {
  if (isTRUE(proj_state$ready)) return(invisible(TRUE))
  works <- function() {
    !inherits(try(PROJ::proj_trans_create("OGC:CRS84", "EPSG:4326"), silent = TRUE),
              "try-error")
  }
  if (!works()) {
    old <- Sys.getenv(c("PROJ_DATA", "PROJ_LIB"), unset = NA)
    found <- FALSE
    for (pkg in c("PROJ", "sf", "terra", "gdalraster")) {
      dir <- system.file("proj", package = pkg)
      if (!nzchar(dir) || !file.exists(file.path(dir, "proj.db"))) next
      Sys.setenv(PROJ_DATA = dir, PROJ_LIB = dir)
      if (works()) {
        found <- TRUE
        break
      }
    }
    if (!found) {
      for (nm in names(old)) {
        if (is.na(old[[nm]])) Sys.unsetenv(nm) else do.call(Sys.setenv, as.list(old[nm]))
      }
      stop("PROJ cannot find its database (proj.db), so no CRS can be read. ",
           "Set the PROJ_DATA environment variable to a folder holding proj.db, ",
           "or install sf or terra, whose binaries carry one.", call. = FALSE)
    }
  }
  proj_state$ready <- TRUE
  invisible(TRUE)
}

## PROJ's WKT2 for a definition, or an error. PROJ 0.7.0's proj_crs_text()
## crashes R on a definition PROJ cannot read, so the definition is first
## checked by creating a transform from it, which fails as an R error.
proj_wkt <- function(def) {
  proj_ready()
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
  proj_ready()
  trans <- PROJ::proj_trans_create(as.character(from), as.character(view))
  wk::wk_transform(g, trans)
}

## Which geometries have any coordinates? Not wk_meta()'s is_empty, which
## is TRUE for a multi geometry or polygon whose first part or ring is
## empty, whatever follows.
has_coords <- function(g) wk::wk_count(g)$n_coord > 0
