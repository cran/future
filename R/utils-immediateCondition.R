#' @importFrom utils file_test
#' @keywords internal
immediateConditionsPath <- local({
  .cache <- list()
  
  function(rootPath = tempdir()) {
    rootPath <- normalizePath(rootPath, mustWork = FALSE)
    path <- .cache[[rootPath]]
    if (is.null(path)) {
      path <- file.path(rootPath, ".future", "immediateConditions")
      dir.create(path, recursive = TRUE, showWarnings = FALSE)
      stop_if_not(file_test("-d", path))
      .cache[[rootPath]] <<- path
    }
    path
  }
})


#' Writes and Reads 'immediateCondition' RDS Files
#'
#' @param path (character string) The folder where the RDS files are.
#'
#' @param pattern (character string) A regular expression selecting
#' the RDS files to be read.
#'
#' @param include (character vector) The class or classes of the objects
#' to be kept.
#'
#' @param signal (logical) If TRUE, the condition read are signaled.
#'
#' @param remove (logical) If TRUE, the RDS files used are removed on exit.
#'
#' @return
#' `readImmediateConditions()` returns a [base::list] of
#' `immediateCondition` objects.
#'
#' @importFrom utils file_test
#' @keywords internal
readImmediateConditions <- function(path = immediateConditionsPath(rootPath = rootPath), rootPath = tempdir(), pattern = "[.]rds$", include = getOption("future.relay.immediate", "immediateCondition"), signal = FALSE, remove = TRUE) {
  stop_if_not(is.logical(remove), length(remove) == 1L, !is.na(remove))

  debug <- isTRUE(getOption("future.debug"))
  if (debug) {
    mdebug("readImmediateCondition() ...")
    mdebugf("  - path: %s", sQuote(path))
    on.exit(mdebug("readImmediateCondition() ... DONE"))
  }

  ## Nothing to do?
  if (!file_test("-d", path)) return(list())
  
  files <- dir(path = path, pattern = "[.]rds$", full.names = TRUE)
  if (debug) {
    mdebugf(" - Number of RDS files: %d", length(files))
  }

  ## Nothing to do?
  if (length(files) == 0L) return(list())

  ## Read objects from file
  objs <- lapply(files, FUN = tryCatch(readRDS, error = identity))

  ## Drop the ones that failed to be read
  keep <- !vapply(objs, FUN = inherits, "error", FUN.VALUE = FALSE)
  objs <- objs[keep]        
  files <- files[keep]

  ## Nothing to do?
  if (length(files) == 0L) return(list())

  ## Default for argument 'include'
  if (missing(include)) {
    include <- getOption("future.relay.immediate")
    if (is.null(include)) include <- "immediateCondition"
  }
  stop_if_not(is.character(include), !anyNA(include))
  
  ## Drop the ones that does not contain 'time' and 'condition' of the
  ## required class 'include'
  keep <- vapply(objs, FUN = function(x) {
    if (!all(is.element(c("time", "condition"), names(x)))) return(FALSE)
    if (length(include) == 0L) return(TRUE)
    inherits(x[["condition"]], include)
  }, FUN.VALUE = FALSE)
  objs <- objs[keep]        
  files <- files[keep]
  
  ## Nothing to do?
  if (length(files) == 0L) return(list())

  ## Re-order by timestamp
  times <- vapply(objs, FUN = .subset2, "time", FUN.VALUE = NA_real_)
  objs <- objs[order(times, na.last = TRUE)]
  times <- NULL

  ## Get conditions
  conds <- lapply(objs, FUN = .subset2, "condition")
  objs <- NULL

  if (debug) {
    mdebugf(" - Number of conditions: %d", length(conds))
    classes <- lapply(conds, FUN = function(x) commaq(class(x)))
    t <- table(classes)
    t <- sprintf("%d:%s", t, names(t))
    mdebugf(" - Condition class sets: %s", paste(t, collapse = "; "))
  }

  ## Resignal conditions
  mdebugf(" - Resignal conditions ...")
  conds <- lapply(conds, FUN = function(condition) {
    signalCondition(condition)
    ## Increment signal count
    signaled <- condition[["signaled"]]
    if (is.null(signaled)) signaled <- 0L
    condition[["signaled"]] <- signaled + 1L
    condition
  })
  mdebugf(" - Resignal conditions ... done")

  ## Remove files?
  if (remove && length(files) > 0L) file.remove(files)

  conds
}


#' @param cond A condition of class `immediateCondition`.
#'
#' @return
#' `saveImmediateCondition()` returns, invisibly, the pathname of
#' the RDS written.
#'
#' @rdname readImmediateConditions
saveImmediateCondition <- function(cond, path = immediateConditionsPath(rootPath = rootPath), rootPath = tempdir()) {
  ## Wrap condition in an object with a timestamp
  obj <- list(time = Sys.time(), condition = cond)
  file <- tempfile(
    pattern = class(cond)[1],
     tmpdir = path,
    fileext = ".rds"
  )
  save_rds(obj, file)
}


#' Robustly Saves an Object to RDS File Atomically
#'
#' @param object The \R object to be save.
#'
#' @param pathname RDS file to written.
#'
#' @param \ldots (optional) Additional arguments passed to [base::saveRDS()].
#'
#' @return The pathname of the RDS written.
#'
#' @details
#' Uses [base::saveRDS] internally but writes the object atomically by first
#' writing to a temporary file which is then renamed.
#'
#' @importFrom utils file_test
#' @keywords internal
save_rds <- function(object, pathname, ...) {
  pathname_tmp <- sprintf("%s.tmp", pathname)
  if (file_test("-f", pathname_tmp)) {
    fi_tmp <- file.info(pathname_tmp)
    stopf("Cannot save RDS file because a temporary save file already exists: %s (%0.f bytes; last modified on %s)", sQuote(pathname_tmp), fi_tmp[["size"]], fi_tmp[["mtime"]])
  }
  
  tryCatch({
    saveRDS(object, file = pathname_tmp, ...)
  }, error = function(ex) {
    msg <- conditionMessage(ex)
    fi_tmp <- file.info(pathname_tmp)
    msg <- sprintf("saveRDS() failed to save to temporary file %s (%.0f bytes; last modified on %s). The reason was: %s", sQuote(pathname_tmp), fi_tmp[["size"]], fi_tmp[["mtime"]], msg)
    ex[["message"]] <- msg
    stop(ex)
  })
  stop_if_not(file_test("-f", pathname_tmp))

  res <- file.rename(from = pathname_tmp, to = pathname)

  ## IMPORTANT: Although, it is valid to also check that the 'pathname_tmp'
  ## file no longer exists, we cannot assume that 'pathname' will still exist
  ## here; it could be that another file already picked it up and moved,
  ## renamed, or deleted it.
  if (!res || file_test("-f", pathname_tmp)) {
    fi_tmp <- file.info(pathname_tmp)
    fi <- file.info(pathname)
    msg <- sprintf("save_rds() failed to rename temporary save file %s (%0.f bytes; last modified on %s) to %s (%0.f bytes; last modified on %s)", sQuote(pathname_tmp), fi_tmp[["size"]], fi_tmp[["mtime"]], sQuote(pathname), fi[["size"]], fi[["mtime"]])
    stop(msg)
  }

  pathname
}


fileImmediateConditionHandler <- function(cond, ...) {
  saveImmediateCondition(cond, ...)
}
