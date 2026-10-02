# A scripted page for a served view's websocket (decision 0007): a raw
# client on a socket in this process, which runs httpuv's event loop while
# it waits, as http_get() does. It speaks protocol 1 as the renderer does,
# with JSON written by hand (aobview does not use jsonlite itself).

# Skip unless the view's server takes a websocket (it needs jsonlite).
skip_if_no_socket <- function(v) {
  skip_if_not(isTRUE(v$server$status()$socket), "the server has no websocket (no jsonlite)")
}

# A masked client text frame (RFC 6455 5.2).
ws_frame <- function(text) {
  p <- charToRaw(enc2utf8(text))
  n <- length(p)
  len <- if (n < 126) as.raw(0x80 + n) else as.raw(c(0x80 + 126, n %/% 256, n %% 256))
  mask <- as.raw(c(0x12, 0x34, 0x56, 0x78))
  c(as.raw(0x81), len, mask, xor(p, rep(mask, length.out = n)))
}

# Server frames (unmasked) at the start of `buf`: list(frames, rest).
ws_frames <- function(buf) {
  out <- list()
  i <- 1L
  while (i + 1L <= length(buf)) {
    op <- as.integer(buf[i]) %% 16L
    n <- as.integer(buf[i + 1L]) %% 128L
    h <- 2L
    if (n == 126L) {
      if (i + 3L > length(buf)) break
      n <- as.integer(buf[i + 2L]) * 256L + as.integer(buf[i + 3L])
      h <- 4L
    }
    if (i + h + n - 1L > length(buf)) break
    p <- buf[seq_len(n) + i + h - 1L]
    out[[length(out) + 1L]] <- list(opcode = op, text = if (op == 1L) rawToChar(p) else "")
    i <- i + h + n
  }
  list(frames = out, rest = if (i <= length(buf)) buf[i:length(buf)] else raw())
}

# Run the loop and read for up to `wait` seconds, or until `until(page)`.
page_pump <- function(page, wait = 2, until = function(page) FALSE) {
  t0 <- Sys.time()
  repeat {
    httpuv::service(10)
    chunk <- readBin(page$con, "raw", 1e6)
    if (length(chunk)) {
      fr <- ws_frames(c(page$buf, chunk))
      page$buf <- fr$rest
      page$received <- c(page$received,
                         vapply(Filter(function(f) f$opcode == 1L, fr$frames), `[[`, "", "text"))
      page$closed <- page$closed || any(vapply(fr$frames, function(f) f$opcode == 8L, TRUE))
    }
    if (until(page) || as.numeric(Sys.time() - t0, units = "secs") > wait) break
  }
  invisible(page)
}

# Open a page's socket on view v's server and say hello; R's hello arrives.
page_connect <- function(v, scene = v$serial) {
  srv <- v$server
  con <- socketConnection("127.0.0.1", srv$port, blocking = FALSE, open = "r+b", timeout = 5)
  page <- new.env(parent = emptyenv())
  page$con <- con
  page$buf <- raw()
  page$received <- character()
  page$closed <- FALSE
  page$seq <- 0L
  writeBin(charToRaw(paste0(
    "GET /", srv$token, "/ws HTTP/1.1\r\nHost: 127.0.0.1:", srv$port, "\r\n",
    "Upgrade: websocket\r\nConnection: Upgrade\r\nOrigin: http://127.0.0.1:", srv$port, "\r\n",
    "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n")), con)
  head <- raw()
  t0 <- Sys.time()
  repeat {
    httpuv::service(10)
    head <- c(head, readBin(con, "raw", 1e6))
    end <- grepRaw(charToRaw("\r\n\r\n"), head, fixed = TRUE)
    if (length(end)) break
    if (as.numeric(Sys.time() - t0, units = "secs") > 10) stop("No answer to the upgrade.")
  }
  page$status <- rawToChar(head[seq_len(end - 1L)])
  page$buf <- head[-seq_len(end + 3L)]
  page_send(page, sprintf(
    '{"type":"hello","protocol":1,"renderer":"0.0.5","specs":["0.1","0.2","0.3","0.4","0.5"],"scene":%d}',
    as.integer(scene)))
  page_pump(page, until = function(p) any(grepl('"type":"hello"', p$received, fixed = TRUE)))
}

page_send <- function(page, text) {
  writeBin(ws_frame(text), page$con)
  invisible(page)
}

# Send the page's whole selection: `items` a named list of 0-based rows per
# layer id. With `srv`, run the loop until R has taken it in (or 3 s, for one
# R drops): R reads only what httpuv's thread has received, and a frame just
# written may not be there yet. Without it, nothing is run, so the message
# waits for whatever runs the loop next.
page_select <- function(page, items, scene, trigger = "click", at = c(1, 2), srv = NULL) {
  on.exit(if (!is.null(srv)) page_until_received(page, srv, "select", before))
  before <- if (!is.null(srv)) srv$status()$received[["select"]]
  page$seq <- page$seq + 1L
  it <- vapply(names(items), function(id) {
    sprintf('{"layer":"%s","rows":[%s]}', id, paste(items[[id]], collapse = ","))
  }, "")
  page_send(page, sprintf(
    '{"type":"select","scene":%d,"seq":%d,"trigger":"%s","items":[%s],"at":[%s]}',
    as.integer(scene), page$seq, trigger, paste(it, collapse = ","),
    paste(at, collapse = ",")))
}

page_until_received <- function(page, srv, type, before, wait = 3) {
  page_pump(page, wait = wait, until = function(p) srv$status()$received[[type]] > before)
}

page_view <- function(page, scene, extent = c(-1, 1, -2, 2), srv = NULL) {
  on.exit(if (!is.null(srv)) page_until_received(page, srv, "view", before))
  before <- if (!is.null(srv)) srv$status()$received[["view"]]
  page$seq <- page$seq + 1L
  page_send(page, sprintf(
    '{"type":"view","scene":%d,"seq":%d,"extent":[%s],"zoom":-3.5,"units_per_pixel":12.5,"size_px":[800,600]}',
    as.integer(scene), page$seq, paste(extent, collapse = ",")))
}

page_close <- function(page) {
  try(close(page$con), silent = TRUE)
  for (i in 1:5) httpuv::service(10)
  invisible()
}

# A served view, in a test (not interactive): muffles serve_scene()'s
# warning that the session is not interactive.
serve <- function(x, ...) served(view(x, ..., transport = "serve"))

# The value of a column of layer `id`'s Arrow data in v's scene.
blob_column <- function(v, id, column) {
  as.data.frame(nanoarrow::read_nanoarrow(aobcore::scene_blobs(v$scene)[[id]]))[[column]]
}
