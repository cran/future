#' Resolve one or more futures synchronously
#'
#' This function provides an efficient mechanism for waiting for multiple
#' futures in a container (e.g. list or environment) to be resolved while in
#' the meanwhile retrieving values of already resolved futures.
#' 
#' @param x A [Future] to be resolved, or a list, an environment, or a
#' list environment of futures to be resolved.
#' 
#' @param idxs (optional) integer or logical index specifying the subset of
#' elements to check.
#' 
#' @param recursive A non-negative number specifying how deep of a recursion
#' should be done.  If TRUE, an infinite recursion is used.  If FALSE or zero,
#' no recursion is performed.
#' 
#' @param result (internal) If TRUE, the results are _retrieved_, otherwise not.
#' Note that this only collects the results from the parallel worker, which
#' can help lower the overall latency if there are multiple concurrent futures.
#' This does _not_ return the collected results.
#' 
#' @param stdout (internal) If TRUE, captured standard output is relayed, otherwise not.
#' 
#' @param signal (internal) If TRUE, captured \link[base]{conditions} are relayed,
#' otherwise not.
#' 
#' @param force (internal) If TRUE, captured standard output and captured
#' \link[base]{conditions} already relayed is relayed again, otherwise not.
#' 
#' @param sleep Number of seconds to wait before checking if futures have been
#' resolved since last time.
#'
#' @param \ldots Not used.
#'
#' @return Returns `x` (regardless of subsetting or not).
#' If `signal` is TRUE and one of the futures produces an error, then
#' that error is produced.
#'
#' @details
#' This function is resolves synchronously, i.e. it blocks until `x` and
#' any containing futures are resolved.
#' 
#' @seealso To resolve a future _variable_, first retrieve its
#' [Future] object using [futureOf()], e.g.
#' `resolve(futureOf(x))`.
#'
#' @export
resolve <- function(x, idxs = NULL, recursive = 0, result = FALSE, stdout = FALSE, signal = FALSE, force = FALSE, sleep = getOption("future.wait.interval", 0.01), ...) UseMethod("resolve")

#' @export
resolve.default <- function(x, ...) x

#' @export
resolve.Future <- function(x, idxs = NULL, recursive = 0, result = FALSE, stdout = FALSE, signal = FALSE, force = FALSE, sleep = getOption("future.wait.interval", 0.01), ...) {
  future <- x
  
  debug <- isTRUE(getOption("future.debug"))
  if (debug) {
    mdebugf_push("resolve() for %s ...", class(future)[1])
    on.exit(mdebugf_pop())
  }
  
  ## Automatically update journal entries for Future object
  if (inherits(future, "Future") &&
      inherits(future[[".journal"]], "FutureJournal")) {
    t_start <- Sys.time()
    on.exit({
      appendToFutureJournal(future,
        event = "resolve",
        category = "overhead",
        start = t_start,
        stop = Sys.time(),
        skip = FALSE
      )
    })
  }

  if (is.logical(recursive)) {
    if (recursive) recursive <- getOption("future.resolve.recursive", 99)
  }
  recursive <- as.numeric(recursive)
  
  ## Nothing to do?
  if (recursive < 0) return(future)

  stop_if_not(
    length(stdout) == 1L, is.logical(stdout), !is.na(stdout),
    length(signal) == 1L, is.logical(signal), !is.na(signal),
    length(result) == 1L, is.logical(result), !is.na(result)
  )
  relay <- (stdout || signal)
  result <- result || relay

  ## Lazy future that is not yet launched?
  if (future[["state"]] == 'created') future <- run(future)

  ## Poll for the Future to finish
  while (!resolved(future)) {
    Sys.sleep(sleep)
  }

  msg <- sprintf("A %s was resolved", class(future)[1])

  ## Retrieve results?
  if (result) {
    if (is.null(future[["result"]])) {
      future[["result"]] <- result(future)
      msg <- sprintf("%s and its result was collected", msg)
    } else {
      sprintf("%s and its result was already collected", msg)
    }
    
    ## Recursively resolve result value?
    if (recursive > 0) {
      value <- future[["result"]][["value"]]
      if (!is.atomic(value)) {
        resolve(value, recursive = recursive - 1, result = TRUE, stdout = stdout, signal = signal, sleep = sleep, ...)
        msg <- sprintf("%s (and resolved itself)", msg)
      }
      value <- NULL  ## Not needed anymore
    }
    result <- NULL     ## Not needed anymore

    if (stdout) value(future, stdout = TRUE, signal = FALSE)
    if (signal) {
      ## Always signal immediateCondition:s and as soon as possible.
      ## They will always be signaled if they exist.
      conditionClasses <- future[["conditions"]]
      immediateConditionClasses <- attr(conditionClasses, "immediateConditionClasses", exact = TRUE)
      if (is.null(immediateConditionClasses)) {
        immediateConditionClasses <- "immediateCondition"
      }

      signalImmediateConditions(future, include = immediateConditionClasses)

      ## Signal all other types of condition
      signalConditions(future, exclude = immediateConditionClasses, resignal = TRUE, force = TRUE)
    }
  } else {
    msg <- sprintf("%s (result was not collected)", msg)
  }

  if (debug) mdebug(msg)

  future
} ## resolve() for Future



subset_list <- function(x, idxs = NULL) {
  if (length(idxs) == 0) return(NULL)

  ## Multi-dimensional indices?
  if (is.matrix(idxs)) {
    idxs <- whichIndex(idxs, dim = dim(x), dimnames = dimnames(x))
  }
  if (length(idxs) > 1L) idxs <- unique(idxs)

  if (is.numeric(idxs)) {
    idxs <- as.numeric(idxs)
    nx <- .length(x)
    if (any(idxs < 1 | idxs > nx)) {
      stopf("Indices out of range [1,%d]: %s", nx, hpaste(idxs))
    }
  } else {
    names <- names(x)
    if (is.null(names)) {
      stop("Named subsetting not possible. Elements are not named")
    }

    idxs <- as.character(idxs)
    unknown <- idxs[!is.element(idxs, names)]
    if (length(unknown) > 0) {
      stopf("Unknown elements: %s", hpaste(sQuote(unknown)))
    }
  }

  idxs
} ## subset_list()


#' @export
resolve.list <- function(x, idxs = NULL, recursive = 0, result = FALSE, stdout = FALSE, signal = FALSE, force = FALSE, sleep = getOption("future.wait.interval", 0.01), ...) {
  debug <- isTRUE(getOption("future.debug"))
  if (debug) {
    mdebugf_push("resolve() for %s ...", class(x)[1])
    on.exit(mdebugf_pop())
  }
  
  if (is.logical(recursive)) {
    if (recursive) recursive <- getOption("future.resolve.recursive", 99)
  }
  recursive <- as.numeric(recursive)
  if (debug) mdebugf("recursive: %s", recursive)
  
  ## Nothing to do?
  if (recursive < 0) return(x)
  
  nx <- .length(x)
  if (debug) mdebugf("Number of elements: %d", nx)

  ## Nothing to do?
  if (nx == 0) return(x)

  stop_if_not(
    length(stdout) == 1L, is.logical(stdout), !is.na(stdout),
    length(signal) == 1L, is.logical(signal), !is.na(signal),
    length(result) == 1L, is.logical(result), !is.na(result)
  )
  relay <- (stdout || signal)
  result <- result || relay

  x0 <- x

  ## Subset?
  if (!is.null(idxs)) {
    idxs <- subset_list(x, idxs = idxs)
    
    ## Nothing do to?
    if (is.null(idxs)) return(x)
    
    x <- x[idxs]
    nx <- .length(x)
    idxs <- NULL
  }
  
  ## NOTE: Everything is considered non-resolved by default

  ## Total number of values to resolve
  total <- nx
  remaining <- seq_len(nx)

  ## Relay?
  signalConditionsASAP <- make_signalConditionsASAP(nx, stdout = stdout, signal = signal, force = force, debug = debug)

  if (debug) {
    mdebugf("elements: %s", hpaste(sQuote(names(x))))
  }

  ## Resolve all elements
  while (length(remaining) > 0) {
    for (ii in remaining) {
      obj <- x[[ii]]

      if (is.atomic(obj)) {
        if (debug) mdebug("'obj' is atomic")
        if (relay) signalConditionsASAP(obj, resignal = FALSE, pos = ii)
      } else {
        if (debug) mdebugf("'obj' is %s", class(obj)[1])      
        ## If an unresolved future, move on to the next object
        ## so that future can be resolved in the asynchronously
        if (inherits(obj, "Future")) {
          ## Lazy future that is not yet launched?
          if (obj[["state"]] == 'created') obj <- run(obj)
          if (!resolved(obj)) next
          if (debug) mdebugf("Future #%d", ii)
          if (result) {
            if (debug) mdebug_push("value(obj, ...) ...")
            value(obj, stdout = FALSE, signal = FALSE)
            if (debug) mdebug_pop()
          }
        }

        relay_ok <- relay && signalConditionsASAP(obj, resignal = FALSE, pos = ii)

        ## In all other cases, try to resolve
        if (debug) mdebug_push("resolve(obj, ...) ...")
        resolve(obj,
                recursive = recursive - 1,
                result = result,
                stdout = stdout && relay_ok,
                signal = signal && relay_ok,
                sleep = sleep, ...)
        if (debug) mdebug_pop()
      }

      ## Check if resolved
      ## Note, here 'obj' can be anything (e.g. list()), meaning
      ## resolved() may return a logical vector of any length including
      ## an empty vector. That's why we wrap it in all()
      if (all(resolved(obj))) remaining <- setdiff(remaining, ii)
      if (debug) mdebugf("length: %d (resolved future %s)", length(remaining), ii)
      stop_if_not(!anyNA(remaining))
    } # for (ii ...)

    ## Wait a bit before checking again
    if (length(remaining) > 0) Sys.sleep(sleep)
  } # while (...)

  if (relay || force) {
    if (debug) mdebug_push("Relaying remaining futures ...")
    signalConditionsASAP(resignal = FALSE, pos = 0L)
    if (debug) mdebug_pop()
  }
  
  x0
} ## resolve() for list



subset_env <- function(x, idxs = NULL) {
  if (is.null(idxs)) {
    ## names(x) is only supported in R (>= 3.2.0)
    idxs <- ls(envir = x, all.names = TRUE)
  } else {
    ## Nothing to do?
    if (length(idxs) == 0) return(NULL)

    ## names(x) is only supported in R (>= 3.2.0)
    names <- ls(envir = x, all.names = TRUE)

    ## Sanity check (because nx == 0 returns early above)
    stop_if_not(length(names) > 0)

    if (length(idxs) > 1L) idxs <- unique(idxs)

    idxs <- as.character(idxs)
    unknown <- idxs[!is.element(idxs, names)]
    if (length(unknown) > 0) {
      stopf("Unknown elements: %s", hpaste(sQuote(unknown)))
    }
  }
  
  idxs
} ## subset_env()



#' @export
resolve.environment <- function(x, idxs = NULL, recursive = 0, result = FALSE, stdout = FALSE, signal = FALSE, force = FALSE, sleep = getOption("future.wait.interval", 0.01), ...) {
  debug <- isTRUE(getOption("future.debug"))
  if (debug) {
    mdebugf_push("resolve() for %s ...", class(x)[1])
    on.exit(mdebugf_pop())
  }
  
  if (is.logical(recursive)) {
    if (recursive) recursive <- getOption("future.resolve.recursive", 99)
  }
  recursive <- as.numeric(recursive)
  if (debug) mdebugf("recursive: %s", recursive)
  
  ## Nothing to do?
  if (recursive < 0) return(x)

  nx <- .length(x)
  if (debug) mdebugf("Number of elements: %d", nx)

  ## Nothing to do?
  if (nx == 0) return(x)

  ## Subset?
  if (is.null(idxs)) {
    ## names(x) is only supported in R (>= 3.2.0)
    idxs <- ls(envir = x, all.names = TRUE)
  } else {
    idxs <- subset_env(x, idxs = idxs)
  }

  ## Nothing to do?
  nx <- length(idxs)
  if (nx == 0) return(x)

  stop_if_not(
    length(stdout) == 1L, is.logical(stdout), !is.na(stdout),
    length(signal) == 1L, is.logical(signal), !is.na(signal),
    length(result) == 1L, is.logical(result), !is.na(result)
  )
  relay <- (stdout || signal)
  result <- result || relay

  ## Coerce future promises into Future objects
  x0 <- x
  x <- futures(x)
  nx <- .length(x)
  names <- ls(envir = x, all.names = TRUE)
  stop_if_not(length(names) == nx)

  ## Everything is considered non-resolved by default
  remaining <- seq_len(nx)
  
  ## Relay?
  signalConditionsASAP <- make_signalConditionsASAP(nx, stdout = stdout, signal = signal, force = force, debug = debug)

  if (debug) mdebugf("elements: [%d] %s", nx, hpaste(sQuote(idxs)))

  ## Resolve all elements
  while (length(remaining) > 0) {
    for (ii in remaining) {
      name <- names[ii]
      obj <- x[[name]]

      if (is.atomic(obj)) {
        if (relay) signalConditionsASAP(obj, resignal = FALSE, pos = ii)
      } else {
        ## If an unresolved future, move on to the next object
        ## so that future can be resolved in the asynchronously
        if (inherits(obj, "Future")) {
          ## Lazy future that is not yet launched?
          if (obj[["state"]] == 'created') obj <- run(obj)
          if (!resolved(obj)) next
          if (debug) mdebugf("Future #%d", ii)
          if (result) value(obj, stdout = FALSE, signal = FALSE)
        }

        relay_ok <- relay && signalConditionsASAP(obj, resignal = FALSE, pos = ii)

        ## In all other cases, try to resolve
        resolve(obj,
                recursive = recursive - 1,
                result = result,
                stdout = stdout && relay_ok,
                signal = signal && relay_ok,
                sleep = sleep, ...)
      }

      ## Assume resolved at this point
      remaining <- setdiff(remaining, ii)
      if (debug) mdebugf("length: %d (resolved future %s)", length(remaining), ii)
      stop_if_not(!anyNA(remaining))
    } # for (ii ...)

    ## Wait a bit before checking again
    if (length(remaining) > 0) Sys.sleep(sleep)
  } # while (...)

  if (relay || force) {
    if (debug) mdebug_push("Relaying remaining futures ...")
    signalConditionsASAP(resignal = FALSE, pos = 0L)
    if (debug) mdebug_pop()
  }
  
  x0
} ## resolve() for environment




subset_listenv <- function(x, idxs = NULL) {
  if (is.null(idxs)) {
    idxs <- seq_along(x)
  } else {
    ## Nothing to do?
    if (length(idxs) == 0) return(NULL)

    ## Multi-dimensional indices?
    if (is.matrix(idxs)) {
      idxs <- whichIndex(idxs, dim = dim(x), dimnames = dimnames(x))
    }
    if (length(idxs) > 1L) idxs <- unique(idxs)

    if (is.numeric(idxs)) {
      nx <- length(x)
      if (any(idxs < 1 | idxs > nx)) {
        stopf("Indices out of range [1,%d]: %s", nx, hpaste(idxs))
      }
    } else {
      names <- names(x)
      
      ## Sanity check (because nx == 0 returns early above)
      stop_if_not(length(names) > 0)

      idxs <- as.character(idxs)
      unknown <- idxs[!is.element(idxs, names)]
      if (length(unknown) > 0) {
        stopf("Unknown elements: %s", hpaste(sQuote(unknown)))
      }
    }
  }
  idxs
} ## subset_listenv()



#' @export
resolve.listenv <- function(x, idxs = NULL, recursive = 0, result = FALSE, stdout = FALSE, signal = FALSE, force = FALSE, sleep = getOption("future.wait.interval", 0.01), ...) {
  if (is.logical(recursive)) {
    if (recursive) recursive <- getOption("future.resolve.recursive", 99)
  }
  recursive <- as.numeric(recursive)
  
  ## Nothing to do?
  if (recursive < 0) return(x)

  ## NOTE: Contrary to other implementations that use .length(x), we here
  ## do need to use generic length() that dispatches on class.
  nx <- length(x)
  
  ## Nothing to do?
  if (nx == 0) return(x)

  ## Subset?
  if (is.null(idxs)) {
    idxs <- seq_along(x)
  } else {
    idxs <- subset_listenv(x, idxs = idxs)
  }

  ## Nothing to do?
  nx <- length(idxs)
  if (nx == 0) return(x)

  stop_if_not(
    length(stdout) == 1L, is.logical(stdout), !is.na(stdout),
    length(signal) == 1L, is.logical(signal), !is.na(signal),
    length(result) == 1L, is.logical(result), !is.na(result)
  )
  relay <- (stdout || signal)
  result <- result || relay

  debug <- isTRUE(getOption("future.debug"))
  if (debug) {
    mdebugf_push("resolve() on %s ...", class(x))
    mdebugf("recursive: %s", recursive)
    on.exit(mdebug_pop())
  }

  ## Coerce future promises into Future objects
  x0 <- x
  x <- futures(x)
  nx <- length(x)

  ## Everything is considered non-resolved by default
  remaining <- seq_len(nx)

  ## Relay?
  signalConditionsASAP <- make_signalConditionsASAP(nx, stdout = stdout, signal = signal, force = force, debug = debug)

  if (debug) {
    mdebugf("length: %d", nx)
    mdebugf("elements: %s", hpaste(sQuote(names(x))))
  }

  ## Resolve all elements
  while (length(remaining) > 0) {
    for (ii in remaining) {
      obj <- x[[ii]]

      if (is.atomic(obj)) {
        if (relay) signalConditionsASAP(obj, resignal = FALSE, pos = ii)
      } else {
        ## If an unresolved future, move on to the next object
        ## so that future can be resolved in the asynchronously
        if (inherits(obj, "Future")) {
          ## Lazy future that is not yet launched?
          if (obj[["state"]] == 'created') obj <- run(obj)
          if (!resolved(obj)) next
          if (debug) mdebugf("Future #%d", ii)
          if (result) value(obj, stdout = FALSE, signal = FALSE)
        }

        relay_ok <- relay && signalConditionsASAP(obj, resignal = FALSE, pos = ii)

        ## In all other cases, try to resolve
        resolve(obj,
                recursive = recursive - 1,
                result = result,
                stdout = stdout && relay_ok,
                signal = signal && relay_ok,
                sleep = sleep, ...)
      }

      ## Assume resolved at this point
      remaining <- setdiff(remaining, ii)
      if (debug) mdebugf("length: %d (resolved future %s)", length(remaining), ii)
      stop_if_not(!anyNA(remaining))
    } # for (ii ...)

    ## Wait a bit before checking again
    if (length(remaining) > 0) Sys.sleep(sleep)
  } # while (...)

  if (relay || force) {
    if (debug) mdebug("Relaying remaining futures")
    signalConditionsASAP(resignal = FALSE, pos = 0L)
  }

  x0
} ## resolve() for list environment
