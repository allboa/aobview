# Served views (decision 0006). Tests run non-interactively, so "auto" only
# serves when is_interactive() is mocked, and aobcore::serve_scene() warns
# that the session is not interactive: served() muffles that one warning by
# its class, and nothing else.
skip_if_no_httpuv <- function() skip_if_not_installed("httpuv")

served <- function(expr) {
  withCallingHandlers(expr, aobcore_serve_noninteractive = function(w) {
    invokeRestart("muffleWarning")
  })
}

# Fetch `path` under a running server, running httpuv's event loop until the
# response is complete (the server is in this process). Returns the status
# and body.
http_get <- function(url, timeout = 20) {
  m <- regmatches(url, regexec("^http://127\\.0\\.0\\.1:([0-9]+)(/.*)$", url))[[1]]
  port <- as.integer(m[2])
  con <- socketConnection("127.0.0.1", port, blocking = FALSE, open = "r+b", timeout = timeout)
  on.exit(close(con))
  writeBin(charToRaw(paste0("GET ", m[3], " HTTP/1.1\r\nHost: 127.0.0.1:", port,
                            "\r\nConnection: close\r\n\r\n")), con)
  buf <- raw()
  t0 <- Sys.time()
  repeat {
    httpuv::service(10)
    buf <- c(buf, readBin(con, "raw", 1e7))
    end <- grepRaw(charToRaw("\r\n\r\n"), buf, fixed = TRUE)
    if (length(end)) {
      head <- rawToChar(buf[seq_len(end - 1L)])
      n <- as.numeric(sub("(?is).*\r\ncontent-length: *([0-9]+).*", "\\1", head, perl = TRUE))
      body <- buf[-seq_len(end + 3L)]
      if (length(body) >= n) {
        return(list(status = as.integer(strsplit(head, " ", fixed = TRUE)[[1]][2]),
                    body = body[seq_len(n)]))
      }
    }
    if (as.numeric(Sys.time() - t0, units = "secs") > timeout) stop("No response from ", url)
  }
}
