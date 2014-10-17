#' @export
lint_file <- function(filename, linters = default_linters) {
  source_file <- srcfile(filename)
  lines <- readLines(filename)
  source_file$content <- paste0(collapse = '\n', lines)

  source_file$num_lines <- length(lines)

  lint_error <- function(e) {

    message_info <- re_matches(e$message,
      rex(except_some_of(":"),
        ":",
        capture(name = "line",
          digits),
        ":",
        capture(name = "column",
          digits),
        ":",
        space,
        capture(name = "message",
          anything),
        "\n")
      )

    line_number <- as.integer(message_info$line)
    column_number <- as.integer(message_info$column)

    # If the column number is zero it means the error really occurred at the
    # end of the previous line
    if(column_number == 0L){
      line_number <- line_number - 1L
      line <- getSrcLines(source_file, line_number, line_number)
      column_number <- nchar(line)
    }

    lint(
      filename = source_file$filename,
      line_number = line_number,
      column_number = column_number,
      type = "error",
      message = message_info$message,
      line = getSrcLines(source_file, line_number, line_number)
      )
  }

  e <- tryCatch(parse(text=source_file$content, srcfile=source_file),
    error = lint_error)

  source_file$parsed_content <- getParseData(source_file)

  structure(
    c(
      # get lints from all the linters
      Filter(is_empty_list,
        lapply(linters,
          function(linter) {
            structure(
              Filter(Negate(is.null),
                linter(source_file)),
              class = "lints")
          })),

      # append any errors
      if(inherits(e, 'lint')) { list(e) }
      ),
    class = "lints")
}

is_empty_list <- function(x) {
  is.list(x) && length(x) == 1L
}

#' @export
lint <- function(filename, line_number = 1L, column_number = NULL, type = "style", message = "", line = "", ranges = NULL) {
  structure(
    list(
      filename = filename,
      line_number = as.integer(line_number),
      column_number = as.integer(column_number) %||% 1L,
      type = type,
      message = message,
      line = line,
      ranges = ranges
      ),
    class="lint")
}

#' @export
print.lint <- function(x, ...) {

  color <- switch(x$type,
    "warning" = crayon::magenta,
    "error" = crayon::red,
    "style" = crayon::blue,
    crayon::bold
  )

  message(
    crayon::bold(x$filename, ":",
    as.character(x$line_number), ":",
    as.character(x$column_number), ": ", sep = ""),
    color(x$type, ": ", sep = ""),
    crayon::bold(x$message), "\n",
    x$line, "\n",
    highlight_string(x$column_number, x$ranges)
    )
  invisible(x)
}

#' @export
print.lints <- function(x, ...) {
  lapply(x, print, ...)
  invisible(x)
}

highlight_string <- function(column_number = NULL, ranges = NULL) {
  maximum <- max(column_number, unlist(ranges))

  line <- fill_with(" ", maximum)

  lapply(ranges, function(range) {
    substr(line, range[1], range[2]) <<- fill_with("~", range[2] - range[1] + 1L)
    })

  substr(line, column_number, column_number + 1L) <- "^"

  line
}

fill_with <- function(character = " ", length = 1L) {
  paste0(collapse = "", rep.int(character, length))
}